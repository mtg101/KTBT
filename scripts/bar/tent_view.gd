extends RefCounted
## How the tent and the night look: the tarp (its colour, stripes and shape), the sign, the
## bar's little touches, the sky and the light by the hour, the bulbs (and their swinging),
## and tonight's weather (rain, snow, fog, a haze). The tent's scene builds the stage in order
## (what's in front of what) and hands this the pieces that change; this only draws.
## (Part 1 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const BarLook = preload("res://scripts/rules/bar_look.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Text = preload("res://scripts/rules/text.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Art = preload("res://scripts/ui/art.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")

const BULB_OFF := Color("3a3546")  # a bulb switched off (closing up early)
const BULB_GLASS := Vector2(0, 44)  # the middle of a bulb's glass, from the top of its wire
const CLOSING_GLOW := 0.6  # the tent's glow with one bulb off

var stage_size: Vector2
var sky: ColorRect  # behind everything: dusk to deep night
var glow: ColorRect  # the tent's warm glow
var bulbs: Array = []  # the hanging bulbs (they swing)
var bulb_lights: Array = []
var sways: Array = []  # the bulbs' swinging (replaced each night)
var weather_back: Control  # rain or snow falling behind the tent
var weather_front: Control  # fog, haze and drips, in front
var roof: Polygon2D
var roof_edge: ColorRect
var roof_stripes: Control
var roof_art: Control  # the cover in pixel art, when there is some (art/tarps: tools/art/tent.py), in place of the shapes
var decor_back: Control  # the bar's touches: on the poles and back wall...
var decor_counter: Control  # ...on the counter...
var decor_roof: Control  # ...and hanging from the tarp
var tent: Array = []  # every piece of the tent (hidden until the bar's look is known)
var sign_node: Control
var sign_board: ColorRect
var sign_hangul: Label
var sign_english: Label


func _init(size_of_stage: Vector2) -> void:
	stage_size = size_of_stage


## The sign over the tarp: the name in Hangul, big, with the romanised name under it.
func build_sign(stage: Control) -> void:
	sign_node = Control.new()
	sign_node.name = "Sign"
	sign_node.position = Vector2(stage_size.x / 2 - 210, 46)
	sign_node.size = Vector2(420, 62)
	sign_node.mouse_filter = Control.MOUSE_FILTER_STOP
	sign_node.visible = false
	stage.add_child(sign_node)
	sign_board = Draw.rect(sign_node, Vector2.ZERO, sign_node.size, Color("7a5230"))
	sign_hangul = Label.new()
	sign_hangul.name = "SignHangul"
	sign_hangul.position = Vector2(0, 2)
	sign_hangul.size = Vector2(420, 38)
	sign_hangul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_hangul.add_theme_font_size_override("font_size", 28)
	PixelFont.apply(sign_hangul, "sign_hangul")  # (in pixels, on the grid: pixel_font.gd)
	sign_node.add_child(sign_hangul)
	sign_english = Label.new()
	sign_english.name = "SignEnglish"
	sign_english.position = Vector2(0, 38)
	sign_english.size = Vector2(420, 20)
	sign_english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_english.add_theme_font_size_override("font_size", 13)
	PixelFont.apply(sign_english, "sign_english")
	sign_node.add_child(sign_english)


## The bar's look (saved with it): tarp, sign and touches. Bars from before looks get a
## plain one.
func show_look(bar: Dictionary) -> void:
	var look: Dictionary = bar.get("look", {})
	if look.is_empty():
		look = BarLook.default_bar_look()
	glow.visible = true
	for piece in tent:
		piece.visible = true
	var tarp: Array = BarLook.BAR_TARPS.get(look["tarp"], BarLook.BAR_TARPS["orange"])
	var colour := Color(tarp[0])
	var shape := str(look.get("shape", "classic"))
	roof.polygon = tent_shape(shape)
	roof.color = colour
	roof_edge.color = colour.darkened(0.2)
	roof_edge.visible = shape != "awning"
	Draw.clear(roof_stripes)
	var w := stage_size.x
	if str(tarp[1]) != "":  # stripes, cut to the shape of the cover
		var stripes := 14
		for k in stripes:
			var a := 22 + (k + 0.25) / stripes * (w - 44)
			var b := 22 + (k + 0.6) / stripes * (w - 44)
			var band := PackedVector2Array([Vector2(a, 0), Vector2(b, 0), Vector2(b, 140), Vector2(a, 140)])
			for piece in Geometry2D.intersect_polygons(band, roof.polygon):
				var stripe := Polygon2D.new()
				stripe.polygon = piece
				stripe.color = Color(tarp[1])
				roof_stripes.add_child(stripe)
	match shape:
		"scalloped":  # a row of scallops hanging from the front edge
			for x in range(22, int(w) - 22, 52):
				var scallop := Polygon2D.new()
				var points := PackedVector2Array()
				for step in 9:
					var t: float = step / 8.0
					points.append(Vector2(x + t * 52, 122 + sin(t * PI) * 14))
				scallop.polygon = points
				scallop.color = colour.darkened(0.2)
				roof_stripes.add_child(scallop)
		"awning":  # a zigzag valance under the flat awning
			for x in range(22, int(w) - 22, 40):
				var tooth := Polygon2D.new()
				tooth.polygon = PackedVector2Array([Vector2(x, 112), Vector2(x + 40, 112), Vector2(x + 20, 130)])
				tooth.color = Color(tarp[1]) if str(tarp[1]) != "" else colour.darkened(0.25)
				roof_stripes.add_child(tooth)
	var style: Array = BarLook.SIGN_STYLES.get(look["sign"], BarLook.SIGN_STYLES["wood"])
	sign_board.color = Color(style[0])
	_sign_art("sign/" + str(look["sign"]))
	for label in [sign_hangul, sign_english]:
		label.add_theme_color_override("font_color", Color(style[1]))
		if look["sign"] == "neon":  # a glowing tube: a soft halo round the letters
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_color_override("font_outline_color", Color(style[1]).darkened(0.5))
		else:
			label.add_theme_constant_override("outline_size", 0)
	sign_hangul.text = str(look["hangul"])
	Glossary.remember(str(look["hangul"]), "%s: the bar's name, %s%s" % [look["hangul"], bar.get("name", ""), (" (%s)" % bar["name_meaning"]) if str(bar.get("name_meaning", "")) != "" else ""])
	sign_english.text = str(bar.get("name", "")).to_upper()
	sign_node.tooltip_text = Text.tip("%s · %s (%s)" % [look["hangul"], bar.get("name", ""), bar.get("name_meaning", "")])
	sign_node.visible = true
	_cover_art("tarp/%s_%s" % [look["tarp"], shape])
	for layer in [decor_back, decor_counter, decor_roof]:
		Draw.clear(layer)
	for id in look["touches"]:
		add_touch(str(id))


## The cover in pixel art, if there's an image for this colour and shape: drawn on the street's
## grid (each pixel 3 on screen, from the stage's top), with its stripes, edge, scallops or
## valance; the shapes stand in where there isn't.
func _cover_art(key: String) -> void:
	if roof_art == null:
		return
	Draw.clear(roof_art)
	var art := Art.place(roof_art, key, Vector2(stage_size.x / 2, 0), "top", 3)
	if art == null:
		Art.drawn(key)
		roof.visible = true
		roof_stripes.visible = true
		return
	for piece in [roof, roof_edge, roof_stripes]:
		piece.visible = false


## The sign's board in pixel art, in its style, if there's art for it (its words stay text over
## it, to hover): just in front of the plain board, which is left out; one row up, so its pixels
## sit on the street's grid.
func _sign_art(key: String) -> void:
	for child in sign_node.get_children():
		if str(child.name).begins_with("Art_"):
			sign_node.remove_child(child)
			child.queue_free()
	var art := Art.place(sign_node, key, Vector2(0, -1), "topleft", 3)
	sign_board.visible = art == null
	if art == null:
		Art.drawn(key)
		return
	sign_node.move_child(art, sign_board.get_index() + 1)


## The outline of the tent's cover, by shape (the front edge is always at y = 112).
func tent_shape(shape: String) -> PackedVector2Array:
	var w := stage_size.x
	match shape:
		"peaked":
			return PackedVector2Array([Vector2(22, 112), Vector2(160, 62), Vector2(w / 2, 26), Vector2(w - 160, 62), Vector2(w - 22, 112)])
		"awning":
			return PackedVector2Array([Vector2(22, 72), Vector2(w - 22, 72), Vector2(w - 22, 112), Vector2(22, 112)])
		"rounded":
			var points := PackedVector2Array()
			for step in 25:
				var t: float = step / 24.0
				points.append(Vector2(22 + t * (w - 44), 112 - sin(t * PI) * 80))
			return points
	return PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])


## One of the bar's little touches: its image if it has one (art/manifest.json, "touch/<id>"),
## at each of its spots; otherwise as simple shapes.
func add_touch(id: String) -> void:
	var key := "touch/" + id
	if Art.has(key):
		for spot in touch_spots(id):
			Art.place(spot[0], key, spot[1], spot[2])
		return
	Art.drawn(key)
	var w := stage_size.x
	match id:
		"string_lights":
			var colours := ["ffd27f", "ff7aa8", "7ad3ff", "a8ff7a"]
			var i := 0
			for x in range(40, int(w) - 40, 56):
				Draw.rect(decor_roof, Vector2(x, 120), Vector2(6, 6), Color(colours[i % colours.size()]))
				i += 1
		"lanterns":
			for x in [330.0, w / 2, w - 330.0]:
				Draw.rect(decor_roof, Vector2(x - 1, 122), Vector2(2, 8), Color("55536b"))
				Draw.rect(decor_roof, Vector2(x - 11, 130), Vector2(22, 28), Color("d8352f"))
				Draw.rect(decor_roof, Vector2(x - 11, 142), Vector2(22, 3), Color("f2c14a"))
		"radio":
			Draw.rect(decor_counter, Vector2(w - 270, 226), Vector2(42, 24), Color("6b4a2e"))
			Draw.rect(decor_counter, Vector2(w - 262, 232), Vector2(12, 12), Color("2b2a33"))
			Draw.rect(decor_counter, Vector2(w - 244, 234), Vector2(10, 4), Color("e0c48a"))
			Draw.rect(decor_counter, Vector2(w - 236, 208), Vector2(2, 18), Color("9a9ab0"))
		"plants":
			for x in [92.0, w - 128.0]:
				Draw.rect(decor_back, Vector2(x + 6, 352), Vector2(24, 20), Color("8a5a33"))
				Draw.rect(decor_back, Vector2(x, 318), Vector2(36, 36), Color("3f8f4a"))
				Draw.rect(decor_back, Vector2(x + 8, 304), Vector2(20, 18), Color("4fa85a"))
		"calendar":
			Draw.rect(decor_back, Vector2(49, 160), Vector2(26, 34), Color("f2ead8"))
			Draw.rect(decor_back, Vector2(49, 160), Vector2(26, 7), Color("c8443a"))
		"lucky_cat":
			Draw.rect(decor_counter, Vector2(w - 205, 230), Vector2(18, 20), Color("f5f2ea"))
			Draw.rect(decor_counter, Vector2(w - 203, 222), Vector2(14, 10), Color("f5f2ea"))
			Draw.rect(decor_counter, Vector2(w - 188, 216), Vector2(5, 12), Color("f5f2ea"))  # the waving paw
			Draw.rect(decor_counter, Vector2(w - 205, 233), Vector2(18, 3), Color("c8443a"))
		"photos":
			for k in 3:
				Draw.rect(decor_back, Vector2(w - 78, 150 + k * 30), Vector2(16, 20), Color("c9a87a").darkened(k * 0.1))
		"fishing_net":
			for k in 8:
				Draw.rect(decor_back, Vector2(w - 300 + k * 22, 128), Vector2(1, 80), Color(0.85, 0.78, 0.6, 0.45))
			for k in 5:
				Draw.rect(decor_back, Vector2(w - 300, 130 + k * 16), Vector2(156, 1), Color(0.85, 0.78, 0.6, 0.45))
		"knife_rack":
			Draw.rect(decor_back, Vector2(200, 172), Vector2(76, 12), Color("3a2a1e"))
			for k in 5:
				Draw.rect(decor_back, Vector2(208 + k * 14, 184), Vector2(3, 18), Color("c8c8d8"))


## Where a touch's image goes: [layer, spot, "bottom" (standing on it) or "top" (hanging from
## it)], once for each (each lantern, each photo...), where the shapes are drawn.
func touch_spots(id: String) -> Array:
	var w := stage_size.x
	match id:
		"string_lights":  # (the whole string, one image)
			return [[decor_roof, Vector2(w / 2, 117), "top"]]
		"lanterns":
			return [330.0, w / 2, w - 330.0].map(func(x): return [decor_roof, Vector2(x, 122), "top"])
		"radio":
			return [[decor_counter, Vector2(w - 249, 250), "bottom"]]
		"plants":
			return [92.0, w - 128.0].map(func(x): return [decor_back, Vector2(x + 18, 372), "bottom"])
		"calendar":
			return [[decor_back, Vector2(62, 160), "top"]]
		"lucky_cat":
			return [[decor_counter, Vector2(w - 196, 250), "bottom"]]
		"photos":
			return range(3).map(func(k): return [decor_back, Vector2(w - 70, 150 + k * 30), "top"])
		"fishing_net":
			return [[decor_back, Vector2(w - 222, 128), "top"]]
		"knife_rack":
			return [[decor_back, Vector2(238, 172), "top"]]
	return []


## A bulb's colour: a plain one's own, or a pixel one's tint (its art is drawn pale).
static func tint(bulb: CanvasItem, colour: Color) -> void:
	if bulb is ColorRect:
		bulb.color = colour
	else:
		bulb.self_modulate = colour


## The colour a bulb is now (for the tests).
static func bulb_colour(bulb: CanvasItem) -> Color:
	return bulb.color if bulb is ColorRect else bulb.self_modulate


## The sky, the tent's glow and the bulbs, by the hour. Cold nights look bluer, fog greys
## everything, and a muggy night's a little warmer. And the light on the pixels (pixel_light.gd):
## the night's, and each bulb's that's on.
func update_light(minutes: float, weather_kind: String, closing: bool) -> void:
	var light := NightRules.night_light(minutes)
	var colour: Color = light["sky"]
	match weather_kind:
		"cold": colour = colour.lerp(Color("1c2c4c"), 0.35)
		"fog": colour = colour.lerp(Color("4a4a58"), 0.35)
		"muggy": colour = colour.lerp(Color("4a2e2a"), 0.25)
	sky.color = colour
	glow.color = Color(0.91, 0.51, 0.23, float(light["glow"]) * (CLOSING_GLOW if closing else 1.0))
	for bulb in bulb_lights:
		tint(bulb, light["bulb"])
	if closing and not bulb_lights.is_empty():
		tint(bulb_lights[-1], BULB_OFF)
	var strengths: Array = bulbs.map(func(_b): return PixelLight.BULB_STEPS)
	if closing and not strengths.is_empty():
		strengths[-1] = 0.0
	PixelLight.set_night(minutes, weather_kind, bulb_spots(), strengths)


## Where the bulbs' light comes from, on the stage: each bulb's glass, under its wire.
func bulb_spots() -> Array:
	return bulbs.map(func(bulb: Control): return bulb.position + BULB_GLASS)


## The lights going out for a moment (a plant card), over what update_light set this frame:
## off (true) or stuttering back on (false: as update_light left them).
func lights_out(off: bool) -> void:
	if not off:
		return
	glow.color.a = 0.02
	for bulb in bulb_lights:
		tint(bulb, BULB_OFF)
	PixelLight.bulbs_off()


## Tonight's weather, as you'd see it: rain or snow falling, fog drifting, a warm haze, and
## the bulbs swinging (more in a breeze).
func show_weather(kind: String) -> void:
	Draw.clear(weather_back)
	Draw.clear(weather_front)
	var w := stage_size.x
	match kind:
		"drizzle", "rain":
			var heavy := kind == "rain"
			var rain := _particles("Rain", weather_back, _dot_texture(2, 16 if heavy else 12, Color(0.75, 0.82, 1.0, 0.55)))
			rain.amount = 260 if heavy else 70
			rain.lifetime = 0.55
			rain.direction = Vector2(0.12, 1)
			rain.spread = 2.0
			rain.initial_velocity_min = 800.0 if heavy else 600.0
			rain.initial_velocity_max = 950.0 if heavy else 700.0
			if heavy:  # drips off the edge of the tarp, in front
				var drips := _particles("Drips", weather_front, _dot_texture(2, 6, Color(0.75, 0.82, 1.0, 0.7)))
				drips.position = Vector2(w / 2, 124)
				drips.emission_rect_extents = Vector2(w / 2 - 30, 1)
				drips.amount = 40
				drips.lifetime = 0.45
				drips.direction = Vector2(0, 1)
				drips.initial_velocity_min = 200.0
				drips.initial_velocity_max = 260.0
				drips.gravity = Vector2(0, 900)
		"snow":
			var snow := _particles("Snow", weather_back, _dot_texture(4, 4, Color(1, 1, 1, 0.85)))
			snow.amount = 140
			snow.lifetime = 8.0
			snow.direction = Vector2(0.2, 1)
			snow.spread = 25.0
			snow.initial_velocity_min = 35.0
			snow.initial_velocity_max = 60.0
			snow.scale_amount_min = 0.6
			snow.scale_amount_max = 1.3
			Draw.rect(weather_front, Vector2(0, 368), Vector2(w, 4), Color(0.95, 0.96, 1.0, 0.7))  # settling on the street
		"fog":
			for k in 4:
				var band := Draw.rect(weather_front, Vector2(-400 + k * 300, 70 + k * 80), Vector2(1200, 70), Color(0.75, 0.75, 0.85, 0.10))
				band.name = "Fog%d" % k
				var drift := band.create_tween().set_loops()
				drift.tween_property(band, "position:x", band.position.x + 500, 30.0 + k * 6).set_trans(Tween.TRANS_SINE)
				drift.tween_property(band, "position:x", band.position.x, 30.0 + k * 6).set_trans(Tween.TRANS_SINE)
		"muggy":
			Draw.rect(weather_front, Vector2.ZERO, stage_size, Color(1.0, 0.6, 0.3, 0.05)).name = "Haze"
	var swing := 7.0 if kind == "breeze" else (3.0 if kind == "rain" else 1.5)
	for old in sways:
		if old.is_valid():
			old.kill()
	sways.clear()
	for bulb in bulbs:
		bulb.rotation = 0.0
		var sway: Tween = bulb.create_tween().set_loops()
		sways.append(sway)
		sway.tween_property(bulb, "rotation_degrees", swing, 1.6 + randf()).set_trans(Tween.TRANS_SINE)
		sway.tween_property(bulb, "rotation_degrees", -swing, 1.6 + randf()).set_trans(Tween.TRANS_SINE)


func _particles(node_name: String, layer: Control, texture: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.texture = texture
	p.position = Vector2(stage_size.x / 2, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(stage_size.x / 2 + 60, 4)
	p.gravity = Vector2.ZERO
	p.preprocess = 4.0  # already falling when the night opens
	layer.add_child(p)
	return p


func _dot_texture(width: int, height: int, colour: Color) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return ImageTexture.create_from_image(image)
