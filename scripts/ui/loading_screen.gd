class_name LoadingScreen
extends Control
## The loading screen while a bar is set up or reopened: the game's name, done up like a
## K-drama or variety-show title card, over the bar's own tent glowing in the night.

const SIZE := Vector2(1920, 1080)
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const TARP := Ktv.ORANGE
const CREAM := Ktv.CREAM
const PINK := Ktv.PINK
const MINT := Ktv.MINT
const YELLOW := Ktv.YELLOW
const NIGHT_TOP := Ktv.NIGHT_TOP
const NIGHT_BOTTOM := Ktv.NIGHT_BOTTOM
const CaptionReel = preload("res://scripts/ui/caption_reel.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")
const Text = preload("res://scripts/rules/text.gd")

## Captions popping up while the AI works, as a variety show teases what's coming.
const LINES := [
	["오늘의 포차는?!", "TONIGHT'S POCHA IS…?!", "❓", "ffd27f"],
	["두근두근", "DUGEUN DUGEUN! HEART POUNDING", "💓", "ff7eb6"],
	["개봉박두!", "COMING UP NEXT!", "🎬", "7ee8c8"],
	["사장님 섭외 중", "CASTING THE OWNER…", "📋", "ffd27f"],
	["간판 제작 중", "PAINTING THE SIGN…", "🎨", "7fd8ff"],
	["고양이 오디션", "CAT AUDITIONS IN PROGRESS", "🐈", "ffc46b"],
	["포차 오픈 임박!", "OPENING ANY MINUTE!", "⏰", "ff9a4f"],
	["잠시만요~", "JAMSIMANYO~ ONE MOMENT!", "🙏", "c79bff"],
	["기대하세요!", "GIDAEHASEYO! GET EXCITED!", "✨", "8cf05a"],
	["소주 냉장 중", "SOJU CHILLING…", "🍶", "7fd8ff"],
]

## Captions for reopening a bar: tonight's episode, not a new one (no casting the owner or cat
## auditions: they're already here).
const REOPEN_LINES := [
	["지난 이야기", "PREVIOUSLY ON… LOADING", "📺", "ffd27f"],
	["두근두근", "DUGEUN DUGEUN! HEART POUNDING", "💓", "ff7eb6"],
	["개봉박두!", "TONIGHT'S EPISODE, COMING UP!", "🎬", "7ee8c8"],
	["다시 오픈!", "OPENING UP AGAIN!", "⏰", "ff9a4f"],
	["단골 대기 중", "THE REGULARS ARE ON THEIR WAY…", "⭐", "ffd27f"],
	["육수 끓이는 중", "THE BROTH'S ON THE BOIL…", "🍲", "ffc46b"],
	["잠시만요~", "JAMSIMANYO~ ONE MOMENT!", "🙏", "c79bff"],
	["기대하세요!", "GIDAEHASEYO! GET EXCITED!", "✨", "8cf05a"],
	["소주 냉장 중", "SOJU CHILLING…", "🍶", "7fd8ff"],
]

## Reopening a saved bar, not setting up a new one: REOPEN_LINES.
var reopening := false

## The bar being set up or reopened (Game.bar): its tent's drawn with its own look. Empty for a
## new bar: a placeholder tent until its look's chosen (show_bar).
var bar: Dictionary = {}

## As the title screen's backdrop: no big title, caption or status (the title screen has
## its own), just the night, the tent, the rays and the sparkles, with captions at the sides.
var backdrop := false

## What the AI is doing right now, shown along the bottom.
var status := "":
	set(value):
		status = value
		if _status != null:
			_status.text = value

var _status: Label


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_sky()
	_build_burst()
	_build_ribbons()
	_build_tent()
	if not backdrop:
		_build_title()
	_build_sparkles()
	_build_on_air()
	var reel := CaptionReel.new()
	reel.name = "CaptionReel"
	reel.size = SIZE
	add_child(reel)
	if backdrop:
		reel.lines = TITLE_LINES
		reel.areas = [Rect2(190, 260, 50, 640), Rect2(1680, 260, 50, 640)]  # either side of the menu
	else:
		reel.lines = REOPEN_LINES if reopening else LINES
		reel.areas = [Rect2(80, 520, 420, 380), Rect2(1420, 520, 420, 380), Rect2(560, 470, 800, 60)]
	_status = Label.new()
	_status.name = "LoadingStatus"
	_status.position = Vector2(0, 1010)
	_status.size = Vector2(SIZE.x, 40)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # (never off the screen)
	_status.clip_text = true
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color("c9c6e2"))
	_status.text = status
	_status.visible = not backdrop
	add_child(_status)


## Captions for the title screen.
const TITLE_LINES := [
	["어서오세요!", "EOSEO OSEYO! WELCOME!", "👋", "7ee8c8"],
	["오늘 밤도 영업 중", "OPEN AGAIN TONIGHT", "🏮", "ff9a4f"],
	["단골 환영", "REGULARS WELCOME ★", "★", "4fd2ff"],
	["신장개업!", "GRAND OPENING!", "🎉", "ffd27f"],
	["소주 한잔?", "SOJU HANJAN? JUST ONE?", "🍶", "7fd8ff"],
	["강추!", "GANGCHU! HIGHLY RECOMMENDED", "👍", "8cf05a"],
	["실화냐?!", "SILHWANYA?! IS THIS REAL?!", "😱", "ff7eb6"],
	["오늘의 주인공은?", "WHO'S TONIGHT'S STAR?", "🌟", "ffd27f"],
	["포차 감성", "POCHA GAMSEONG: THE VIBE", "✨", "c79bff"],
	["안주 추천", "ANJU CHUCHEON: TRY THE ODENG", "🍢", "ffc46b"],
]


## Diagonal ribbons in the corners, like a variety show's title card.
func _build_ribbons() -> void:
	for corner in [[Vector2(0, 0), 1.0, PINK], [Vector2(SIZE.x, SIZE.y), -1.0, MINT]]:
		var at: Vector2 = corner[0]
		var way: float = corner[1]
		for k in 3:
			var near := 120.0 + k * 70.0
			var far := near + 40.0
			var ribbon := Polygon2D.new()
			ribbon.polygon = PackedVector2Array([at + Vector2(near * way, 0), at + Vector2(far * way, 0), at + Vector2(0, far * way), at + Vector2(0, near * way)])
			ribbon.color = Color(corner[2] if k != 1 else YELLOW, 0.55 - k * 0.12)
			add_child(ribbon)


## An "ON AIR" light by the channel bug, blinking.
func _build_on_air() -> void:
	var light := PanelContainer.new()
	light.name = "OnAir"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e8263a")
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	light.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.text = "● ON AIR"
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color.WHITE)
	light.add_child(text)
	light.position = Vector2(SIZE.x - 190, 44)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(light)
	var blink := light.create_tween().set_loops()
	blink.tween_property(light, "modulate:a", 0.35, 0.6)
	blink.tween_property(light, "modulate:a", 1.0, 0.6)


## The night sky, fading down to a warm haze over the street.
func _build_sky() -> void:
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	sky.vertex_colors = PackedColorArray([NIGHT_TOP, NIGHT_TOP, NIGHT_BOTTOM, NIGHT_BOTTOM])
	add_child(sky)
	for _star_number in 60:  # a few city stars
		var star := ColorRect.new()
		star.position = Vector2(randf() * SIZE.x, randf() * 520)
		star.size = Vector2(3, 3)
		star.color = Color(1, 1, 1, randf_range(0.2, 0.7))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
	var street := ColorRect.new()
	street.position = Vector2(0, 960)
	street.size = Vector2(SIZE.x, 120)
	street.color = Color("17152c")
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(street)


## Slowly turning rays behind the title, like a variety show's.
func _build_burst() -> void:
	var burst := Node2D.new()
	burst.name = "Burst"
	burst.position = Vector2(SIZE.x / 2, 300)
	add_child(burst)
	var rays := 24
	for k in rays:
		var a: float = TAU * k / rays
		var b: float = TAU * (k + 0.5) / rays
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 1400, Vector2(cos(b), sin(b)) * 1400])
		ray.color = Color(PINK if k % 2 == 0 else YELLOW, 0.07)
		burst.add_child(ray)
	var spin := burst.create_tween().set_loops()
	spin.tween_property(burst, "rotation", TAU, 90.0).from(0.0)


## The tent: the bar's own look when it's known (a bar reopening, or a new one once its look's
## chosen), drawn from the same facts as the game's stage: its tarp, shape, sign and touches
## (rules/bar_look.gd), and a stool for every seat (NightRules.SEATS). A new bar, before its look's
## chosen, gets a placeholder: the plain tarp, and "?" on the sign.
func _build_tent() -> void:
	var tent := Node2D.new()
	tent.name = "Tent"
	tent.position = Vector2(SIZE.x / 2, 640)
	add_child(tent)
	var look := tent_look()
	var tarp: Array = BarLook.BAR_TARPS.get(str(look["tarp"]), BarLook.BAR_TARPS["orange"])
	var colour := Color(tarp[0])
	var shape := str(look.get("shape", "classic"))
	_poly(tent, [Vector2(-380, 40), Vector2(380, 40), Vector2(380, 330), Vector2(-380, 330)], Color(colour.lerp(Color(1.0, 0.62, 0.3), 0.6), 0.22))  # glow
	_poly(tent, [Vector2(-372, 60), Vector2(-356, 60), Vector2(-356, 320), Vector2(-372, 320)], Color("2a2840"))  # poles
	_poly(tent, [Vector2(356, 60), Vector2(372, 60), Vector2(372, 320), Vector2(356, 320)], Color("2a2840"))
	var roof := _poly(tent, Array(roof_shape(shape)), colour)  # the tarp
	roof.name = "Tarp"
	if str(tarp[1]) != "":  # stripes, cut to the shape of the cover
		for k in 9:
			var a: float = -410 + (k + 0.25) / 9.0 * 820
			var band := PackedVector2Array([Vector2(a, -150), Vector2(a + 36, -150), Vector2(a + 36, 60), Vector2(a, 60)])
			for piece in Geometry2D.intersect_polygons(band, roof.polygon):
				_poly(tent, Array(piece), Color(tarp[1]))
	if shape != "awning":
		_poly(tent, [Vector2(-410, 60), Vector2(410, 60), Vector2(410, 72), Vector2(-410, 72)], colour.darkened(0.25))
	match shape:
		"scalloped":  # scallops hanging from the front edge
			for x in range(-410, 410, 41):
				var points: Array = []
				for step in 9:
					var t: float = step / 8.0
					points.append(Vector2(x + t * 41, 70 + sin(t * PI) * 14))
				_poly(tent, points, colour.darkened(0.2))
		"awning":  # a zigzag valance under the flat awning
			for x in range(-410, 410, 41):
				_poly(tent, [Vector2(x, 60), Vector2(x + 41, 60), Vector2(x + 20.5, 78)], Color(tarp[1]) if str(tarp[1]) != "" else colour.darkened(0.25))
	_build_sign(tent, look)
	for x in [-170.0, 170.0]:  # bulbs, swinging gently
		var bulb := Node2D.new()
		bulb.position = Vector2(x, 72)
		tent.add_child(bulb)
		_poly(bulb, [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 40), Vector2(-1, 40)], Color("55536b"))
		_poly(bulb, _circle(Vector2(0, 50), 11), YELLOW)
		_poly(bulb, _circle(Vector2(0, 50), 26), Color(YELLOW, 0.18))
		var sway := bulb.create_tween().set_loops()
		sway.tween_property(bulb, "rotation", 0.06, 1.8).set_trans(Tween.TRANS_SINE)
		sway.tween_property(bulb, "rotation", -0.06, 1.8).set_trans(Tween.TRANS_SINE)
	_poly(tent, [Vector2(-330, 200), Vector2(330, 200), Vector2(330, 214), Vector2(-330, 214)], Color("8a5a33"))  # counter
	_poly(tent, [Vector2(-310, 214), Vector2(310, 214), Vector2(310, 320), Vector2(-310, 320)], Color("5c3820"))
	_poly(tent, _circle(Vector2(-230, 186), 24, true), Color("3a3946"))  # a pot on the stove
	for x in [-150.0, -40.0, 70.0]:  # green bottles (no labels)
		_poly(tent, [Vector2(x, 160), Vector2(x + 14, 160), Vector2(x + 14, 200), Vector2(x, 200)], Color("3f9e5a", 0.9))
		_poly(tent, [Vector2(x + 4, 148), Vector2(x + 10, 148), Vector2(x + 10, 160), Vector2(x + 4, 160)], Color("3f9e5a", 0.9))
	for touch in look.get("touches", []):
		_add_touch(tent, str(touch))
	var stools := Node2D.new()  # a stool for every seat, red and blue plastic
	stools.name = "Stools"
	tent.add_child(stools)
	for k in NightRules.SEATS:
		var x: float = -310 + (k + 0.5) * 620.0 / NightRules.SEATS
		var plastic := Color("c8443a") if k % 2 == 0 else Color("3a6ec8")
		_poly(stools, [Vector2(x - 28, 296), Vector2(x + 28, 296), Vector2(x + 28, 306), Vector2(x - 28, 306)], plastic)
		_poly(stools, [Vector2(x - 22, 306), Vector2(x + 22, 306), Vector2(x + 16, 330), Vector2(x - 16, 330)], plastic.darkened(0.3))
	for k in 3:  # steam off the pot
		var puff := Polygon2D.new()
		puff.polygon = _circle(Vector2.ZERO, 12)
		puff.color = Color(1, 1, 1, 0.0)
		puff.position = Vector2(-230, 160)
		tent.add_child(puff)
		var rise := puff.create_tween().set_loops()
		rise.tween_interval(k * 0.8)
		rise.tween_property(puff, "position", Vector2(-230 + (k - 1) * 14, 70), 2.4).from(Vector2(-230, 160))
		rise.parallel().tween_property(puff, "color:a", 0.0, 2.4).from(0.35)


## The look to draw: the bar's own; a plain one for a bar from before looks (as the stage does)
## and for the title screen; a placeholder for a new bar before its look's chosen.
func tent_look() -> Dictionary:
	var look: Dictionary = bar.get("look", {})
	if not look.is_empty():
		return look
	var plain := BarLook.default_bar_look()
	if not bar.is_empty() or backdrop:
		return plain
	plain["hangul"] = ""  # (a "?" on the sign: nothing in Korean made up)
	return plain


## Whether the tent's a placeholder (a new bar, its look not chosen yet).
func is_placeholder() -> bool:
	return str(tent_look()["hangul"]) == ""


## A new bar's look has been chosen (or a different bar's here): the tent redrawn as it is.
func show_bar(the_bar: Dictionary) -> void:
	bar = the_bar
	var old := get_node_or_null("Tent")
	if old == null:
		return
	var at := old.get_index()
	remove_child(old)
	old.queue_free()
	_build_tent()
	move_child(get_node("Tent"), at)


## The cover's outline, by shape, its front edge at y 60 (as tent_view.gd's, at this size).
func roof_shape(shape: String) -> PackedVector2Array:
	match shape:
		"peaked":
			return PackedVector2Array([Vector2(-410, 60), Vector2(-300, 8), Vector2(0, -44), Vector2(300, 8), Vector2(410, 60)])
		"awning":
			return PackedVector2Array([Vector2(-410, 14), Vector2(410, 14), Vector2(410, 60), Vector2(-410, 60)])
		"rounded":
			var points := PackedVector2Array()
			for step in 25:
				var t: float = step / 24.0
				points.append(Vector2(-410 + t * 820, 60 - sin(t * PI) * 88))
			return points
	return PackedVector2Array([Vector2(-330, -30), Vector2(330, -30), Vector2(410, 60), Vector2(-410, 60)])


## The sign over the tarp, in the bar's style: its name in Hangul (explained on hover), the
## romanised name under it; "?" for a new bar not yet named.
func _build_sign(tent: Node2D, look: Dictionary) -> void:
	var style: Array = BarLook.SIGN_STYLES.get(str(look["sign"]), BarLook.SIGN_STYLES["wood"])
	var board := ColorRect.new()
	board.name = "Sign"
	board.position = Vector2(-160, -122)
	board.size = Vector2(320, 62)
	board.color = Color(style[0])
	tent.add_child(board)
	var hangul := str(look["hangul"])
	var bar_name := str(bar.get("name", ""))
	for line in [[hangul if hangul != "" else "?", 0, 36, 30, "SignHangul"], [bar_name.to_upper(), 38, 20, 14, "SignEnglish"]]:
		var label := Label.new()
		label.name = line[4]
		label.text = line[0]
		label.position = Vector2(0, line[1])
		label.size = Vector2(320, line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[3])
		label.add_theme_color_override("font_color", Color(style[1]))
		if str(look["sign"]) == "neon":  # a glowing tube: a soft halo round the letters
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_color_override("font_outline_color", Color(style[1]).darkened(0.5))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(label)
	if hangul == "":
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	board.mouse_filter = Control.MOUSE_FILTER_STOP  # (the Hangul explains itself on hover)
	var meaning := str(bar.get("name_meaning", ""))
	if bar_name == "":
		board.tooltip_text = Text.tip("%s: %s" % [hangul, Hangul.MEANINGS.get(hangul, "the bar's name")])
	else:
		board.tooltip_text = Text.tip("%s · %s%s: the bar's name" % [hangul, bar_name, (" (%s)" % meaning) if meaning != "" else ""])


## One of the bar's touches, where it'd catch the eye at this size (the small ones on the back
## wall, the calendar, photos, net and knives, are left to the stage).
func _add_touch(tent: Node2D, id: String) -> void:
	match id:
		"string_lights":
			var colours := ["ffd27f", "ff7aa8", "7ad3ff", "a8ff7a"]
			for k in 17:
				_poly(tent, _circle(Vector2(-400 + k * 50, 78), 5), Color(colours[k % colours.size()]))
		"lanterns":
			for x in [-260.0, 0.0, 260.0]:
				_poly(tent, [Vector2(x - 1, 72), Vector2(x + 1, 72), Vector2(x + 1, 84), Vector2(x - 1, 84)], Color("55536b"))
				_poly(tent, [Vector2(x - 14, 84), Vector2(x + 14, 84), Vector2(x + 14, 120), Vector2(x - 14, 120)], Color("d8352f"))
				_poly(tent, [Vector2(x - 14, 99), Vector2(x + 14, 99), Vector2(x + 14, 103), Vector2(x - 14, 103)], Color("f2c14a"))
		"radio":
			_poly(tent, [Vector2(150, 172), Vector2(204, 172), Vector2(204, 200), Vector2(150, 200)], Color("6b4a2e"))
			_poly(tent, _circle(Vector2(166, 186), 8), Color("2b2a33"))
			_poly(tent, [Vector2(180, 182), Vector2(196, 182), Vector2(196, 188), Vector2(180, 188)], Color("e0c48a"))
		"lucky_cat":
			_poly(tent, [Vector2(240, 174), Vector2(264, 174), Vector2(264, 200), Vector2(240, 200)], Color("f5f2ea"))
			_poly(tent, [Vector2(243, 160), Vector2(261, 160), Vector2(261, 174), Vector2(243, 174)], Color("f5f2ea"))
			_poly(tent, [Vector2(264, 152), Vector2(271, 152), Vector2(271, 168), Vector2(264, 168)], Color("f5f2ea"))  # the waving paw
			_poly(tent, [Vector2(240, 178), Vector2(264, 178), Vector2(264, 182), Vector2(240, 182)], Color("c8443a"))
		"plants":
			for x in [-400.0, 380.0]:
				_poly(tent, [Vector2(x, 296), Vector2(x + 26, 296), Vector2(x + 26, 322), Vector2(x, 322)], Color("8a5a33"))
				_poly(tent, _circle(Vector2(x + 13, 280), 22), Color("3f8f4a"))


## The name, big and bold with a thick outline and a hard shadow, and a caption bubble.
func _build_title() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "Korean Tent Bar Tropes"
	title.position = Vector2(0, 170)
	title.size = Vector2(SIZE.x, 150)
	title.pivot_offset = title.size / 2
	title.rotation = -0.04
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 112)
	title.add_theme_color_override("font_color", CREAM)
	Ktv.title_card(title, 30, PINK.darkened(0.15), Vector2(8, 10))
	add_child(title)
	var bob := title.create_tween().set_loops()
	bob.tween_property(title, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	# A variety-show caption: a chunky pill with the Hangul in it.
	var pill := PanelContainer.new()
	pill.name = "Caption"
	var style := StyleBoxFlat.new()
	style.bg_color = MINT
	style.border_color = Ktv.INK
	style.set_border_width_all(6)
	style.set_corner_radius_all(40)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(6, 6)
	pill.add_theme_stylebox_override("panel", style)
	var caption := Label.new()
	caption.text = "포장마차 · 오늘 밤도 영업 중!"
	caption.add_theme_font_size_override("font_size", 40)
	caption.add_theme_color_override("font_color", Ktv.INK)
	pill.add_child(caption)
	add_child(pill)
	pill.position = Vector2(SIZE.x / 2 - 330, 340)
	pill.custom_minimum_size = Vector2(660, 0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.rotation = 0.03

	var tag := Label.new()  # the short name, like a channel bug in the corner
	tag.text = "KTBT"
	tag.position = Vector2(60, 40)
	tag.add_theme_font_size_override("font_size", 34)
	tag.add_theme_color_override("font_color", YELLOW)
	tag.add_theme_constant_override("outline_size", 10)
	tag.add_theme_color_override("font_outline_color", Ktv.INK)
	add_child(tag)


## Twinkling four-point stars and little hearts round the title.
func _build_sparkles() -> void:
	var spots := [Vector2(330, 150), Vector2(1600, 130), Vector2(250, 380), Vector2(1680, 400), Vector2(560, 470), Vector2(1380, 480), Vector2(960, 80)]
	for k in spots.size():
		var sparkle := Node2D.new()
		sparkle.position = spots[k]
		add_child(sparkle)
		var shape := Polygon2D.new()
		if k % 3 == 2:
			shape.polygon = _heart(18)
			shape.color = PINK
		else:
			shape.polygon = _star(26 if k % 2 == 0 else 18)
			shape.color = [YELLOW, MINT, CREAM][k % 3]
		sparkle.add_child(shape)
		var twinkle := sparkle.create_tween().set_loops()
		twinkle.tween_interval(randf() * 1.2)
		twinkle.tween_property(sparkle, "scale", Vector2(0.4, 0.4), 0.7).set_trans(Tween.TRANS_SINE)
		twinkle.tween_property(sparkle, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


func _poly(parent: Node, points: Array, colour: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = colour
	parent.add_child(shape)
	return shape


## A circle (or the bottom half of one, for a pot) as polygon points.
func _circle(centre: Vector2, radius: float, half := false) -> Array:
	var points: Array = []
	var steps := 20
	for k in steps + (1 if half else 0):
		var angle: float = (PI * k / steps) if half else (TAU * k / steps)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _star(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 8:
		var angle: float = TAU * k / 8.0 - PI / 2
		var r: float = radius if k % 2 == 0 else radius * 0.28
		points.append(Vector2(cos(angle), sin(angle)) * r)
	return points


func _heart(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 32:
		var t: float = TAU * k / 32.0
		points.append(Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * radius / 16.0)
	return points


## The PD can step in and cut last night's episode (see visit.gd _step_in), or set up a new
## bar's show (_open_setup): a button along the bottom, saying so. Returns it, for the tent to connect.
func show_step_in(text: String, button_name: String = "LoadingStepIn") -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("ff4f6d"))
	button.position = Vector2(SIZE.x - 760, 950)
	button.custom_minimum_size = Vector2(720, 48)
	button.size = Vector2(720, 48)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # (a long one wraps, rather than running off the screen)
	add_child(button)
	return button
