class_name LoadingScreen
extends Control
## The loading screen while a new bar is set up: the game's name, done up like a K-drama
## or variety-show title card, over a little tent bar glowing in the night.

const SIZE := Vector2(1920, 1080)
const TARP := Color("e8833a")
const CREAM := Color("fff4e0")
const PINK := Color("ff7eb6")
const MINT := Color("7ee8c8")
const YELLOW := Color("ffd27f")
const NIGHT_TOP := Color("1a1840")
const NIGHT_BOTTOM := Color("3c2a5c")

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
	_build_tent()
	_build_title()
	_build_sparkles()
	_status = Label.new()
	_status.name = "LoadingStatus"
	_status.position = Vector2(0, 1010)
	_status.size = Vector2(SIZE.x, 40)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color("c9c6e2"))
	_status.text = status
	add_child(_status)


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


## A plain tent bar: orange tarp, warm light, bulbs, a counter, stools and a pot steaming.
func _build_tent() -> void:
	var tent := Node2D.new()
	tent.name = "Tent"
	tent.position = Vector2(SIZE.x / 2, 640)
	add_child(tent)
	_poly(tent, [Vector2(-380, 40), Vector2(380, 40), Vector2(380, 330), Vector2(-380, 330)], Color(1.0, 0.62, 0.3, 0.22))  # glow
	_poly(tent, [Vector2(-372, 60), Vector2(-356, 60), Vector2(-356, 320), Vector2(-372, 320)], Color("2a2840"))  # poles
	_poly(tent, [Vector2(356, 60), Vector2(372, 60), Vector2(372, 320), Vector2(356, 320)], Color("2a2840"))
	_poly(tent, [Vector2(-330, -30), Vector2(330, -30), Vector2(410, 60), Vector2(-410, 60)], TARP)  # the tarp
	for k in 9:  # cream stripes
		var x0: float = -330 + k * 82.5 + 20
		var x1: float = x0 + 30
		_poly(tent, [Vector2(x0, -30), Vector2(x1, -30), Vector2(x1 * 410.0 / 330.0, 60), Vector2(x0 * 410.0 / 330.0, 60)], Color(CREAM, 0.85))
	_poly(tent, [Vector2(-410, 60), Vector2(410, 60), Vector2(410, 72), Vector2(-410, 72)], TARP.darkened(0.25))
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
	for x in [-150.0, -40.0, 70.0, 180.0]:  # green soju bottles and a glass or two
		_poly(tent, [Vector2(x, 160), Vector2(x + 14, 160), Vector2(x + 14, 200), Vector2(x, 200)], Color("3f9e5a", 0.9))
		_poly(tent, [Vector2(x + 4, 148), Vector2(x + 10, 148), Vector2(x + 10, 160), Vector2(x + 4, 160)], Color("3f9e5a", 0.9))
	for x in [-240.0, -80.0, 80.0, 240.0]:  # stools
		_poly(tent, [Vector2(x - 30, 300), Vector2(x + 30, 300), Vector2(x + 30, 310), Vector2(x - 30, 310)], Color("9a9ab0"))
		_poly(tent, [Vector2(x - 5, 310), Vector2(x + 5, 310), Vector2(x + 5, 320), Vector2(x - 5, 320)], Color("6e6e86"))
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
	title.add_theme_constant_override("outline_size", 30)
	title.add_theme_color_override("font_outline_color", PINK.darkened(0.15))
	title.add_theme_color_override("font_shadow_color", Color("2a1840"))
	title.add_theme_constant_override("shadow_offset_x", 8)
	title.add_theme_constant_override("shadow_offset_y", 10)
	title.add_theme_constant_override("shadow_outline_size", 30)
	add_child(title)
	var bob := title.create_tween().set_loops()
	bob.tween_property(title, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	# A variety-show caption: a chunky pill with the Hangul in it.
	var pill := PanelContainer.new()
	pill.name = "Caption"
	var style := StyleBoxFlat.new()
	style.bg_color = MINT
	style.border_color = Color("1a1840")
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
	caption.add_theme_color_override("font_color", Color("1a1840"))
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
	tag.add_theme_color_override("font_outline_color", Color("1a1840"))
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
