extends RefCounted
## The portrait split, in Godot: an image model's head-and-shoulders picture (black hair, a bright
## red top, a flat green background: tools/art/portraits.py's PROMPT) into a portrait layer in the
## people's own encoding, so a face made during the game is painted onto someone's hair, skin and
## clothes the way the library's are (ui/people_art.gd portrait()). It's portraits.py's split
## (cut_background, parts, steps_of, to_grid, layer, score) ported line for line, to give the same
## answer: tests/test_portrait_split.gd checks it against the Python's on the library's pictures.
## And the reaction split (react_split: a face redrawn in a TV mood, cut to a close-up, with its own
## colours, the eye whites, tears and a blush, kept as fixed ones; react_score and best() to pick
## between seeds), ported the same way and checked in tests/test_reaction_split.gd.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const W := 64  # the portrait on the grid (as portraits.py and people_art.gd PORTRAIT_SIZE)
const H := 80
const SAMPLE := 12  # picture pixels per game pixel: the model's picture is 768x960
const EMPTY := -1
const SKIN := 1  # the parts, as people.py's slots
const HAIR := 2
const CLOTH := 3
const FIXED_SLOT := 0
const LINE := 9  # (a part of its own while working: drawn as the fixed ink)
const WHITE := 10  # the reaction faces' own colours, drawn as fixed ones
const TEAR := 11
const BLUSH := 12
const EXTRAS := [WHITE, TEAR, BLUSH]
const FIXED_OF := {LINE: 1, WHITE: 2, TEAR: 14, BLUSH: 15}  # people_art.gd FIXED: ink, white_shirt, tear, blush
const EXTRA_SHARE := 0.3  # one of them wins a game pixel it's this much of (after the lines)
const STEP_L := 11.0  # Lab lightness per light step, from a part's median
const LINE_SHARE := 0.22  # a line wins a game pixel it's this much of
const HAIR_MIN := 0.003  # a dark area this much of the picture (after the opening) is hair, not a line
const BG_CLOSE := 45.0  # pixelate.py: this close (Lab) to the edges' colour, and joined to an edge, is background
const EYES := [0.32, 0.52]  # the band of the portrait (top to bottom) the eyes and glasses are in
const CLOSE_UP := [0.56, 0.08]  # a reaction face's close-up: the middle 56% across, from 8% down, 4:5
const CLOSE_SCALE := 7  # picture pixels per game pixel while splitting a close-up
const MOOD_NEEDS := {"sad": [TEAR, 3], "sweet": [BLUSH, 6], "shock": [WHITE, 6]}  # a mood's own colour, and how many pixels of it
const NO_MOOD := 0.3  # a candidate without its mood's colour scores this much worse

static var _linear := PackedFloat64Array()  # sRGB 0..255 to linear light, worked out once


## A picture to its portrait: {"part", "step": the grid (W x H, row by row: a part or EMPTY, and its
## light step), "layer": the Image in people.py's encoding, "shares": {hair, skin, cloth, lines},
## "score": how cleanly it split (lower is better; name, the portrait's id, says if it's balding
## or has glasses), "resized": whether the picture wasn't the model's 768x960 (Godot's Lanczos isn't
## PIL's, so then it's only near the Python's), "ms": how long it took}.
static func split(picture: Image, name: String = "") -> Dictionary:
	var started := Time.get_ticks_msec()
	var image := picture.duplicate() as Image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var resized := image.get_width() != W * SAMPLE or image.get_height() != H * SAMPLE
	if resized:
		image.resize(W * SAMPLE, H * SAMPLE, Image.INTERPOLATE_LANCZOS)
	var found := parts_of(image)
	var steps := steps_of(found["part"], found["L"])
	var grid := to_grid(found["part"], steps, image.get_width(), image.get_height())
	return {"part": grid["part"], "step": grid["step"], "layer": layer(grid["part"], grid["step"]),
		"shares": shares(grid["part"]), "score": score(grid["part"], name), "resized": resized,
		"ms": Time.get_ticks_msec() - started}


## Which of several splits of the same person (or of one mood's seeds) to pre-pick: the index of the
## lowest score (the lowest seed if two tie, as portraits.py's min()). candidates: [{"score",
## "seed"}...]; -1 if none.
static func best(candidates: Array) -> int:
	var at := -1
	for k in candidates.size():
		var c: Dictionary = candidates[k]
		if at < 0:
			at = k
			continue
		var b: Dictionary = candidates[at]
		if float(c["score"]) < float(b["score"]) or (float(c["score"]) == float(b["score"]) and int(c["seed"]) < int(b["seed"])):
			at = k
	return at


# --- Colour ------------------------------------------------------------------------------------

static func _lin(v: float) -> float:
	var c := v / 255.0
	return pow((c + 0.055) / 1.055, 2.4) if c > 0.04045 else c / 12.92


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## sRGB (0..255, fractions allowed) to CIE Lab, as palette.py's to_lab: [L, a, b].
static func to_lab(r: float, g: float, b: float) -> PackedFloat64Array:
	return _lab_of_linear(_lin(r), _lin(g), _lin(b))


static func _lab_of_linear(r: float, g: float, b: float) -> PackedFloat64Array:
	var fx := _f((r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047)
	var fy := _f(r * 0.2126 + g * 0.7152 + b * 0.0722)
	var fz := _f((r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883)
	return PackedFloat64Array([116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)])


# --- The picture's parts -----------------------------------------------------------------------

## Each picture pixel's part (EMPTY for the background, SKIN, HAIR, CLOTH, LINE) and its Lab
## colour: {"part": PackedInt32Array, "L", "a", "b": PackedFloat64Array}. image: RGBA8. given_fg:
## the foreground (1s and 0s), if it's known already (a close-up's: react_parts()).
static func parts_of(image: Image, given_fg: PackedByteArray = PackedByteArray()) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var n := w * h
	var data := image.get_data()
	var lab := _lab_of(data, n)
	var light: PackedFloat64Array = lab[0]
	var aa: PackedFloat64Array = lab[1]
	var bb: PackedFloat64Array = lab[2]
	var fg := given_fg if not given_fg.is_empty() else cut_background(data, w, h, light, aa, bb)
	var cloth := PackedByteArray()
	var hairish := PackedByteArray()
	cloth.resize(n)
	hairish.resize(n)
	for i in n:
		if fg[i] == 0 or light[i] >= 62.0:
			continue
		var chroma := sqrt(aa[i] * aa[i] + bb[i] * bb[i])
		if aa[i] > 38.0 and chroma > 45.0:
			cloth[i] = 1
		elif chroma < 16.0:
			hairish[i] = 1
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	var size := maxi(5, w / 70) | 1  # (thicker than the model's outlines: 11 at 768 wide)
	var opened := _window(_window(hairish, w, h, size, true), w, h, size, false)
	var near_core := _window(big_areas(opened, w, h, HAIR_MIN), w, h, size + 2, false)
	var part := PackedInt32Array()
	part.resize(n)
	part.fill(EMPTY)
	for i in n:
		if fg[i] == 0:
			continue
		if cloth[i] == 1:
			part[i] = CLOTH
		elif hairish[i] == 1 and near_core[i] == 1:
			part[i] = HAIR
		elif light[i] < 40.0:
			part[i] = LINE
		else:
			part[i] = SKIN
	return {"part": part, "L": light, "a": aa, "b": bb}


## Every pixel's Lab colour (as palette.py's to_lab): [L, a, b], a PackedFloat64Array each.
static func _lab_of(data: PackedByteArray, n: int) -> Array:
	if _linear.is_empty():
		_linear.resize(256)
		for v in 256:
			_linear[v] = _lin(v)
	var light := PackedFloat64Array()
	var aa := PackedFloat64Array()
	var bb := PackedFloat64Array()
	light.resize(n)
	aa.resize(n)
	bb.resize(n)
	for i in n:
		var r := _linear[data[i * 4]]
		var g := _linear[data[i * 4 + 1]]
		var b := _linear[data[i * 4 + 2]]
		var fx := _f((r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047)
		var fy := _f(r * 0.2126 + g * 0.7152 + b * 0.0722)
		var fz := _f((r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883)
		light[i] = 116.0 * fy - 16.0
		aa[i] = 500.0 * (fx - fy)
		bb[i] = 200.0 * (fy - fz)
	return [light, aa, bb]


## The foreground (1) and background (0), as pixelate.py's cut_background: the picture's own
## transparency if it has any; otherwise flooded in from the edges through what's near the edges'
## colour, that colour anywhere, and the soft edge beside it.
static func cut_background(data: PackedByteArray, w: int, h: int, light: PackedFloat64Array,
		aa: PackedFloat64Array, bb: PackedFloat64Array) -> PackedByteArray:
	var n := w * h
	var fg := PackedByteArray()
	fg.resize(n)
	var lowest := 255
	for i in n:
		lowest = mini(lowest, data[i * 4 + 3])
	if lowest < 250:
		for i in n:
			fg[i] = 1 if data[i * 4 + 3] >= 128 else 0
		return fg
	var edge: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	var border := PackedInt32Array()  # (in the Python's order: the top row, the bottom, the left side, the right)
	for x in w:
		border.append(x)
	for x in w:
		border.append((h - 1) * w + x)
	for y in h:
		border.append(y * w)
	for y in h:
		border.append(y * w + w - 1)
	for i in border:
		for c in 3:
			edge[c].append(data[i * 4 + c])
	var bg := to_lab(_median(edge[0]), _median(edge[1]), _median(edge[2]))
	var distance := PackedFloat64Array()
	distance.resize(n)
	for i in n:
		var dl := light[i] - bg[0]
		var da := aa[i] - bg[1]
		var db := bb[i] - bg[2]
		distance[i] = sqrt(dl * dl + da * da + db * db)
	var background := PackedByteArray()
	background.resize(n)
	var stack := PackedInt32Array()
	stack.resize(n)
	var top := 0
	for i in border:  # (flooded in from the edges through the near-background pixels, so a white collar stays)
		if distance[i] < BG_CLOSE and background[i] == 0:
			background[i] = 1
			stack[top] = i
			top += 1
	while top > 0:
		top -= 1
		var i := stack[top]
		var x := i % w
		for j in [i + w if i + w < n else -1, i - w, i + 1 if x < w - 1 else -1, i - 1 if x > 0 else -1]:
			if j >= 0 and background[j] == 0 and distance[j] < BG_CLOSE:
				background[j] = 1
				stack[top] = j
				top += 1
	for i in n:  # (the background's own colour anywhere, even shut in, is background)
		if distance[i] < BG_CLOSE * 0.5:
			background[i] = 1
	var beside := _window(background, w, h, 7, false)
	for i in n:  # (the soft edge beside it, nearer its colour than the thing's, goes with it)
		fg[i] = 0 if background[i] == 1 or (beside[i] == 1 and distance[i] < BG_CLOSE * 1.8) else 1
	return fg


## The parts of mask that join up into areas at least share of the picture, as portraits.py's
## big_areas (worked on a quarter-size copy, picked nearest, as PIL's resize).
static func big_areas(mask: PackedByteArray, w: int, h: int, share: float) -> PackedByteArray:
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	var sw := maxi(1, w / 4)
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	var sh := maxi(1, h / 4)
	var small := PackedByteArray()
	small.resize(sw * sh)
	for y in sh:
		var from_y := int((y + 0.5) * h / sh) * w
		for x in sw:
			small[y * sw + x] = mask[from_y + int((x + 0.5) * w / sw)]
	var keep := PackedByteArray()
	var seen := PackedByteArray()
	keep.resize(sw * sh)
	seen.resize(sw * sh)
	var stack := PackedInt32Array()
	stack.resize(sw * sh)
	var area := PackedInt32Array()
	for start in sw * sh:
		if small[start] == 0 or seen[start] == 1:
			continue
		area.clear()
		var top := 1
		stack[0] = start
		seen[start] = 1
		while top > 0:
			top -= 1
			var i := stack[top]
			area.append(i)
			var x := i % sw
			for j in [i + sw if i + sw < sw * sh else -1, i - sw, i + 1 if x < sw - 1 else -1, i - 1 if x > 0 else -1]:
				if j >= 0 and small[j] == 1 and seen[j] == 0:
					seen[j] = 1
					stack[top] = j
					top += 1
		if area.size() >= share * sw * sh:
			for i in area:
				keep[i] = 1
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		var from_y := int((y + 0.5) * sh / h) * sw
		for x in w:
			out[y * w + x] = keep[from_y + int((x + 0.5) * sw / w)]
	return out


## A size x size square's minimum (every: true) or maximum over a mask of 0s and 1s, as PIL's
## MinFilter and MaxFilter (the edges repeated, which is the same as the square cut short there).
static func _window(mask: PackedByteArray, w: int, h: int, size: int, every: bool) -> PackedByteArray:
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	var r := size / 2
	var across := PackedByteArray()
	across.resize(w * h)
	var sums := PackedInt32Array()
	sums.resize(maxi(w, h) + 1)
	for y in h:
		var row := y * w
		for x in w:
			sums[x + 1] = sums[x] + mask[row + x]
		for x in w:
			var lo := maxi(0, x - r)
			var hi := mini(w - 1, x + r)
			var count := sums[hi + 1] - sums[lo]
			across[row + x] = 1 if (count == hi - lo + 1 if every else count > 0) else 0
	var out := PackedByteArray()
	out.resize(w * h)
	for x in w:
		for y in h:
			sums[y + 1] = sums[y] + across[y * w + x]
		for y in h:
			var lo := maxi(0, y - r)
			var hi := mini(h - 1, y + r)
			var count := sums[hi + 1] - sums[lo]
			out[y * w + x] = 1 if (count == hi - lo + 1 if every else count > 0) else 0
	return out


# --- Light steps, the grid, the layer ------------------------------------------------------------

## Each pixel's light step on its part's ramp: the part's median lightness is step 4, a step up or
## down for every STEP_L from it, 1 to 6 (so black hair keeps its shine on blonde too).
static func steps_of(part: PackedInt32Array, light: PackedFloat64Array) -> PackedInt32Array:
	var skin := PackedFloat64Array()  # (three of their own: a packed array in a Dictionary isn't appended to in place)
	var hair := PackedFloat64Array()
	var cloth := PackedFloat64Array()
	for i in part.size():
		match part[i]:
			SKIN:
				skin.append(light[i])
			HAIR:
				hair.append(light[i])
			CLOTH:
				cloth.append(light[i])
	var mid := {}
	for pair in [[SKIN, skin], [HAIR, hair], [CLOTH, cloth]]:
		if not (pair[1] as PackedFloat64Array).is_empty():
			mid[pair[0]] = _median(pair[1])
	var step := PackedInt32Array()
	step.resize(part.size())
	step.fill(4)
	for i in part.size():
		if mid.has(part[i]):
			step[i] = clampi(4 + int(_round_even((light[i] - float(mid[part[i]])) / STEP_L)), 1, 6)
	return step


## The game pixels from the picture's whole frame (w x h): each the part most of its samples are
## (a line wins if it's a fair share, then a reaction face's own colour), at that part's commonest
## step; EMPTY where most of it is background. {"part", "step": PackedInt32Array, W x H}.
static func to_grid(part: PackedInt32Array, step: PackedInt32Array, w: int, h: int,
		width: int = W, height: int = H) -> Dictionary:
	var out_part := PackedInt32Array()
	var out_step := PackedInt32Array()
	out_part.resize(width * height)
	out_part.fill(EMPTY)
	out_step.resize(width * height)
	var ys := _cuts(h, height)
	var xs := _cuts(w, width)
	var counts := PackedInt32Array()  # (by part + 1: the background's at 0)
	var step_counts := PackedInt32Array()  # (by (part + 1) x 8 + step)
	counts.resize(BLUSH + 2)
	step_counts.resize((BLUSH + 2) * 8)
	for j in height:
		for i in width:
			counts.fill(0)
			step_counts.fill(0)
			var total := 0
			for y in range(ys[j], ys[j + 1]):
				for x in range(xs[i], xs[i + 1]):
					var p := part[y * w + x] + 1
					counts[p] += 1
					step_counts[p * 8 + step[y * w + x]] += 1
					total += 1
			var drawn := total - counts[0]
			if drawn < total / 2.0:
				continue
			var at := j * width + i
			if counts[LINE + 1] >= LINE_SHARE * drawn:
				out_part[at] = LINE
				continue
			var extra: int = EXTRAS[0]
			for e in EXTRAS:
				if counts[e + 1] > counts[extra + 1]:
					extra = e
			if counts[extra + 1] >= EXTRA_SHARE * drawn:
				out_part[at] = extra
				out_step[at] = 4
				continue
			var best_part := EMPTY
			for p in [SKIN, HAIR, CLOTH]:  # (in order, so a tie goes to the lower, as numpy's argmax)
				if counts[p + 1] > 0 and (best_part == EMPTY or counts[p + 1] > counts[best_part + 1]):
					best_part = p
			if best_part == EMPTY:
				out_part[at] = LINE
				continue
			var best_step := 0
			for s in 8:
				if step_counts[(best_part + 1) * 8 + s] > step_counts[(best_part + 1) * 8 + best_step]:
					best_step = s
			out_part[at] = best_part
			out_step[at] = best_step
	return {"part": out_part, "step": out_step}


## The layer in people.py's encoding: red = step x 36, green = slot x 36, blue = fixed colour x 8,
## alpha where it's drawn (lines the ink, a reaction face's colours their fixed ones, both at step 4's slot 0).
static func layer(part: PackedInt32Array, step: PackedInt32Array, width: int = W, height: int = H) -> Image:
	var data := PackedByteArray()
	data.resize(width * height * 4)
	for i in width * height:
		var p := part[i]
		var fixed := FIXED_OF.has(p)
		data[i * 4] = (0 if p == LINE else (4 if fixed else step[i])) * 36
		data[i * 4 + 1] = (FIXED_SLOT if fixed else clampi(p, 0, 7)) * 36
		data[i * 4 + 2] = int(FIXED_OF[p]) * 8 if fixed else 0
		data[i * 4 + 3] = 255 if p >= 0 else 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


# --- The reaction faces: a mood's picture, its close-up and its own colours ----------------------

## A face redrawn in a TV mood to its close-up on the grid, as portraits.py's react_split (uncached):
## {"part", "step", "layer" (as split()'s), "face": the close-up it split (W x H at CLOSE_SCALE,
## the background cut away), "ms"}. The background's cut from the whole picture, at half size; a
## close-up's edges are face and hair, which the cut would take for the background. (Godot's
## Lanczos isn't PIL's, so this is near the Python's, not the same: react_grid() on the Python's
## own close-up is.)
static func react_split(picture: Image) -> Dictionary:
	var started := Time.get_ticks_msec()
	var grid := react_grid(react_face(picture))
	grid["ms"] = Time.get_ticks_msec() - started
	return grid


## A picture's close-up at the split's size, its background cut away (alpha), as portraits.py's react_face.
static func react_face(picture: Image) -> Image:
	var whole := picture.duplicate() as Image
	if whole.get_format() != Image.FORMAT_RGBA8:
		whole.convert(Image.FORMAT_RGBA8)
	var w := whole.get_width()
	var h := whole.get_height()
	var half := whole.duplicate() as Image
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	half.resize(w / 2, h / 2, Image.INTERPOLATE_LANCZOS)
	var half_data := half.get_data()
	var half_lab := _lab_of(half_data, half.get_width() * half.get_height())
	var half_fg := cut_background(half_data, half.get_width(), half.get_height(), half_lab[0], half_lab[1], half_lab[2])
	var data := whole.get_data()
	var sw := half.get_width()
	var sh := half.get_height()
	for y in h:  # (the half-size cut back to the whole picture, picked nearest, as PIL's resize)
		var from_y := int((y + 0.5) * sh / h) * sw
		for x in w:
			data[(y * w + x) * 4 + 3] = 255 if half_fg[from_y + int((x + 0.5) * sw / w)] == 1 else 0
	whole = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	var face := close_up(whole)
	face.resize(W * CLOSE_SCALE, H * CLOSE_SCALE, Image.INTERPOLATE_LANCZOS)
	return face


## The picture cut to the face (CLOSE_UP), still 4:5, as portraits.py's close_up.
static func close_up(picture: Image) -> Image:
	var w := picture.get_width()
	var h := picture.get_height()
	var cw := int(_round_even(w * float(CLOSE_UP[0])))
	var ch := int(_round_even(cw * float(H) / W))
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	var x := (w - cw) / 2
	var y := int(_round_even(h * float(CLOSE_UP[1])))
	return picture.get_region(Rect2i(x, y, cw, mini(h, y + ch) - y))


## A close-up (react_face()) on the grid: {"part", "step", "layer", "face"}.
static func react_grid(face: Image) -> Dictionary:
	var image := face
	if image.get_format() != Image.FORMAT_RGBA8:
		image = face.duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
	var found := react_parts(image)
	var grid := to_grid(found["part"], steps_of(found["part"], found["L"]), image.get_width(), image.get_height())
	grid["layer"] = layer(grid["part"], grid["step"])
	grid["face"] = image
	return grid


## parts_of() a close-up (its foreground its own alpha), and on the skin the reaction faces' own
## colours, as portraits.py's react_parts: the whites of the eyes and teeth (very light, no colour),
## tears (light and blue), a blush (light and pink, bluer than lips or a mouth); a later one wins.
static func react_parts(image: Image) -> Dictionary:
	var data := image.get_data()
	var n := image.get_width() * image.get_height()
	var fg := PackedByteArray()
	fg.resize(n)
	for i in n:
		fg[i] = 1 if data[i * 4 + 3] >= 128 else 0
	var found := parts_of(image, fg)
	var part: PackedInt32Array = found["part"]
	var light: PackedFloat64Array = found["L"]
	var aa: PackedFloat64Array = found["a"]
	var bb: PackedFloat64Array = found["b"]
	for i in n:
		if part[i] != SKIN:
			continue
		var l := light[i]
		var a := aa[i]
		var b := bb[i]
		if l > 60.0 and a > 28.0 and b < 0.4 * a:
			part[i] = BLUSH
		elif l > 70.0 and b < -3.0 and a < 2.0:
			part[i] = TEAR
		elif l > 92.0 and sqrt(a * a + b * b) < 6.0:
			part[i] = WHITE
	found["part"] = part
	return found


## How good a mood's candidate is (lower is better), as portraits.py's react_score: the same hair and
## outline as the calm close-up's (a different person's the risk), its mood's own colour there
## (MOOD_NEEDS), and not all lines. part, calm: grids (W x H) from react_split().
static func react_score(part: PackedInt32Array, calm: PackedInt32Array, mood: String) -> float:
	var hair_both := 0
	var hair_either := 0
	var drawn_both := 0
	var drawn_either := 0
	var lines := 0
	var drawn := 0
	var needed := -100
	var least := 0
	if MOOD_NEEDS.has(mood):
		needed = int(MOOD_NEEDS[mood][0])
		least = int(MOOD_NEEDS[mood][1])
	var own := 0
	for i in part.size():
		var p := part[i]
		var c := calm[i]
		if p == HAIR or c == HAIR:
			hair_either += 1
			if p == HAIR and c == HAIR:
				hair_both += 1
		if p >= 0 or c >= 0:
			drawn_either += 1
			if p >= 0 and c >= 0:
				drawn_both += 1
		if p >= 0:
			drawn += 1
		if p == LINE:
			lines += 1
		if p == needed:
			own += 1
	var bad := (1.0 - _overlap(hair_both, hair_either)) + (1.0 - _overlap(drawn_both, drawn_either))
	if MOOD_NEEDS.has(mood) and own < least:
		bad += NO_MOOD
	return bad + 6.0 * maxf(0.0, lines / float(maxi(1, drawn)) - 0.15)


## How many of a grid's game pixels are each of the reaction faces' own colours: {"white", "tear", "blush"}.
static func colours(part: PackedInt32Array) -> Dictionary:
	var out := {"white": 0, "tear": 0, "blush": 0}
	for p in part:
		match p:
			WHITE:
				out["white"] += 1
			TEAR:
				out["tear"] += 1
			BLUSH:
				out["blush"] += 1
	return out


## How much two masks are the same: shared over either (1 if neither has any), as portraits.py's overlap.
static func _overlap(both: int, either: int) -> float:
	return both / float(either) if either > 0 else 1.0


# --- Judging a split -----------------------------------------------------------------------------

## Each part's share of what's drawn: {"hair", "skin", "cloth", "lines"}.
static func shares(part: PackedInt32Array) -> Dictionary:
	var counted := {HAIR: 0, SKIN: 0, CLOTH: 0, LINE: 0}
	var drawn := 0
	for p in part:
		if p >= 0:
			drawn += 1
		if counted.has(p):
			counted[p] += 1
	drawn = maxi(1, drawn)
	return {"hair": counted[HAIR] / float(drawn), "skin": counted[SKIN] / float(drawn),
		"cloth": counted[CLOTH] / float(drawn), "lines": counted[LINE] / float(drawn)}


## How cleanly a portrait split (lower is better), as portraits.py's score: the parts in sensible
## shares, glasses only if its name asks for them ("_glasses" at the end), little hair if it's
## "balding", and not cut off at the top or filling the side.
static func score(part: PackedInt32Array, name: String = "", width: int = W, height: int = H) -> float:
	var share := shares(part)
	var bad := 0.0
	var hair_range := [0.01, 0.15] if name.contains("balding") else [0.10, 0.45]
	bad += 4.0 * _outside(share["hair"], hair_range[0], hair_range[1]) + 4.0 * _outside(share["skin"], 0.15, 0.45)
	bad += 4.0 * _outside(share["cloth"], 0.25, 0.55) + 6.0 * _outside(share["lines"], 0.0, 0.12)
	var lines := 0
	var band := 0
	for y in range(int(EYES[0] * height), int(EYES[1] * height)):  # (glasses' frames are lines: far more of them in the band)
		for x in width:
			band += 1
			if part[y * width + x] == LINE:
				lines += 1
	var in_band := lines / float(maxi(1, band))
	bad += (0.12 - in_band) * 3.0 if name.ends_with("_glasses") else in_band * 3.0
	var top_row := 0
	for x in width:
		if part[x] >= 0:
			top_row += 1
	var left := 0
	for y in height:
		if part[y * width] >= 0:
			left += 1
	if top_row > width * 0.6 or left > height * 0.9:
		bad += 1.0  # (cut off at the top, or filling the side: framed oddly)
	return bad


static func _outside(v: float, lo: float, hi: float) -> float:
	return maxf(0.0, maxf(lo - v, v - hi))


# --- Small sums ----------------------------------------------------------------------------------

## The median, as numpy's (the middle two averaged for an even count).
static func _median(values: PackedFloat64Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return 0.0
	@warning_ignore("integer_division")  # (whole numbers meant, as the Python's //)
	return sorted[n / 2] if n % 2 == 1 else (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0


## Rounded half to even, as numpy's round.
static func _round_even(v: float) -> float:
	var down := floorf(v)
	var rest := v - down
	if rest > 0.5:
		return down + 1.0
	if rest < 0.5:
		return down
	return down if posmod(int(down), 2) == 0 else down + 1.0


## Where each of count cells starts along size (and size at the end), as numpy's linspace cast to int.
static func _cuts(size: int, count: int) -> PackedInt32Array:
	var cuts := PackedInt32Array()
	var each := float(size) / count
	for k in count:
		cuts.append(int(k * each))
	cuts.append(size)
	return cuts
