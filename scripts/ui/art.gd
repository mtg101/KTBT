extends RefCounted
## The game's art, arriving a piece at a time (ART.md, "The art folder"). art/manifest.json maps
## the game's facts to images ("touch/lucky_cat": a bar's lucky-cat figurine), each with where
## it came from and its licence. Whatever has an image is drawn from it, in pixels (scaled up a
## whole number of times, never smoothed); whatever hasn't, or whose image won't load, is drawn
## in code as before. So any piece can be swapped in on its own, and nothing breaks while most
## of it is still shapes.
## What was drawn which way is kept (used, summary()) for the night's stats; an image that won't
## load is an error (in the log, and in an autoplay batch's summary), and drawn in code instead.

const BarLook = preload("res://scripts/rules/bar_look.gd")
const Looks = preload("res://scripts/rules/looks.gd")

## Each pixel of an image is this many on the stage (the stage's pixel scale: ART.md).
const SCALE := 3

## The kinds of thing that can have art, and the ids each can have: what the game decides.
## More kinds come with their stage of the art (the street, people, food: PLAN.md).
static func ids(kind: String) -> Array:
	match kind:
		"touch":
			return BarLook.BAR_TOUCHES.keys()
		"person":  # the people's layers (drawn in code by tools/art/people.py; people_art.gd stacks them)
			var layers: Array = ["front_head_old", "front_glasses", "front_tote", "front_briefcase"]
			for view in ["front", "back"]:
				for clothes in Looks.CLOTHES:
					layers.append("%s_body_%s" % [view, clothes])
				for hair in Looks.HAIR_STYLES:
					layers.append("%s_hair_%s" % [view, hair])
				layers.append_array(["%s_head" % view, "%s_hairback_long" % view, "%s_apron" % view, "%s_backpack" % view])
			# From the side, walking: a body for each kind of clothes, every hairstyle, the head (and
			# an older one), the extras, and the legs and arms by frame of the stride.
			for clothes in Looks.CLOTHES:
				layers.append("side_body_" + clothes)
			for hair in Looks.HAIR_STYLES:
				layers.append("side_hair_" + hair)
			layers.append_array(["side_head", "side_head_old", "side_glasses", "side_apron", "side_tote", "side_backpack"])
			for frame in 4:
				for limb in ["side_legs_%d", "side_arm_%d", "side_arm_far_%d", "side_arm_bare_%d", "side_arm_bare_far_%d"]:
					layers.append(limb % frame)
			return layers
		"tent":  # the tent's own pieces (drawn in code by tools/art/tent.py)
			return ["counter", "stool_red", "stool_blue", "fridge", "odeng_pot", "stove", "bulb", "neon_board"]
		"menu":  # the menu board, in each of its styles (menu_board.gd STYLE_ORDER; drawn in code by tools/art/fittings.py)
			return ["wall", "floor", "paper", "lightbox"]
		"sign":  # the sign's board, in each style (drawn in code by tools/art/fittings.py; its words stay text)
			return BarLook.SIGN_STYLES.keys()
		"tarp":  # the tent's cover, one for each colour and shape (drawn in code by tools/art/tent.py)
			var tarps: Array = []
			for tarp in BarLook.BAR_TARPS:
				for shape in BarLook.TENT_SHAPES:
					tarps.append("%s_%s" % [tarp, shape])
			return tarps
		"street":  # the pieces of the street behind the tent (street_art.gd's SLOTS: a few of each, so bars differ)
			return ["overpass", "overpass_2", "apartments", "apartments_2", "apartments_3", "apartments_4", "apartments_5", "apartments_6",
				"shops", "shops_2", "shops_3", "shops_4", "karaoke", "karaoke_2", "karaoke_3", "karaoke_4",
				"corner_shop", "corner_shop_2", "corner_shop_3", "corner_shop_4"]
	return []

## Where the art is (tests point it at their own).
static var folder := "res://art/"
static var used := {}  # key -> "image", "drawn" (in code) or "broken" (its image wouldn't load)
static var _manifest = null  # (read once)
static var _textures := {}


## Forget everything read (after changing folder).
static func reset() -> void:
	_manifest = null
	_textures = {}
	used = {}


## The manifest: {key: {"file", "source", "licence"}}. None, or unreadable, is no art.
static func manifest() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		var path := folder + "manifest.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_manifest = parsed
			else:
				push_error("Art: %s isn't a JSON object: everything's drawn in code" % path)
	return _manifest


## Whether this has an image (one that loads).
static func has(key: String) -> bool:
	return texture(key) != null


## The image for a key, or null (none, or it wouldn't load: an error, once).
static func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var found: Texture2D = null
	var entry = manifest().get(key, {})
	if entry is Dictionary and str(entry.get("file", "")) != "":
		var path := folder + str(entry["file"])
		if ResourceLoader.exists(path):
			found = load(path) as Texture2D
		if found == null:
			push_error("Art: %s's image %s couldn't be loaded: drawn in code instead" % [key, path])
			used[key] = "broken"
	_textures[key] = found
	return found


## Puts a key's image on the stage, its pixels SCALE times over (or scale: 1 on a pixel grid
## of its own, like the street's): its bottom-centre at spot
## (anchor "bottom": things standing) or its top-centre (anchor "top": things hanging). The
## image ("topleft": spot is its top-left corner), or null if there's none (then draw it in code, and say so: drawn()).
static func place(parent: Control, key: String, spot: Vector2, anchor: String = "bottom", scale: int = SCALE) -> TextureRect:
	var image := texture(key)
	if image == null:
		return null
	var rect := TextureRect.new()
	rect.name = "Art_" + key.replace("/", "_")
	rect.texture = image
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = image.get_size() * scale
	rect.position = (spot - Vector2(rect.size.x / 2, rect.size.y if anchor == "bottom" else 0.0)).round()
	if anchor == "topleft":  # (spot is its top-left corner: on a grid's lines)
		rect.position = spot
	else:  # (onto the grid's lines, so its pixels line up with everything else's)
		rect.position = (rect.position / scale).round() * scale
	parent.add_child(rect, true)  # (readable names: a second lantern is Art_touch_lanterns2)
	used[key] = "image"
	return rect


## A key drawn in code (no image yet).
static func drawn(key: String) -> void:
	if not used.has(key):
		used[key] = "drawn"


## For the night's stats: {"images": [keys], "drawn": [keys], "broken": [keys]}, each sorted.
static func summary() -> Dictionary:
	var out := {"images": [], "drawn": [], "broken": []}
	for key in used:
		out[{"image": "images", "drawn": "drawn", "broken": "broken"}[used[key]]].append(key)
	for list in out.values():
		list.sort()
	return out


## What's wrong with a manifest, if anything: each key a kind and id the game has, its file
## there, and where it came from and its licence given, and in LICENSE-ASSETS.md (licences:
## that file's text).
static func check_manifest(entries: Dictionary, licences: String) -> Array:
	var problems: Array = []
	for key in entries:
		var parts := str(key).split("/")
		if parts.size() != 2 or ids(parts[0]).is_empty():
			problems.append("%s: no such kind of art (\"kind/id\", the kinds in art.gd's ids())" % key)
			continue
		if not ids(parts[0]).has(parts[1]):
			problems.append("%s: no %s called \"%s\"" % [key, parts[0], parts[1]])
		var entry = entries[key]
		if not entry is Dictionary:
			problems.append("%s: not {\"file\", \"source\", \"licence\"}" % key)
			continue
		var file := str(entry.get("file", ""))
		if file == "" or not FileAccess.file_exists(folder + file):
			problems.append("%s: its file \"%s\" isn't in %s" % [key, file, folder])
		for field in ["source", "licence"]:
			if str(entry.get(field, "")).strip_edges() == "":
				problems.append("%s: no %s" % [key, field])
		if file != "" and not licences.contains(file):
			problems.append("%s: %s isn't listed in LICENSE-ASSETS.md" % [key, file])
	return problems
