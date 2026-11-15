extends Control
## "Previously on…": a K-drama recap before a night, full screen, played as over the top as the
## shows do it. A title card (지난 이야기, PREVIOUSLY ON) slams in; each beat slams onto the
## screen with a white flash and a shake, over turning rays and drifting petals (or snow), with
## the name of whoever it's about in a pink tag (in Hangul too) and, for a big moment, its TV
## reaction stuck on beside it (충격!); the last beat gets the dramatic triple zoom, one jolt for
## each "dun" of the sting. Then the teaser throbs like a heartbeat (두근두근), and the episode
## card (제12화) sweeps in on ribbons. Skip ends it any time. (See visit.gd _play_recap.)

signal finished

const CaptionPopup = preload("res://scripts/caption.gd")
const Rules = preload("res://scripts/rules.gd")

const NIGHT_TOP := Color("0d0b24")
const NIGHT_BOTTOM := Color("2a1a40")
const CREAM := Color("fff4e0")
const PINK := Color("ff7eb6")
const YELLOW := Color("ffd27f")
const MINT := Color("7ee8c8")
const INK := Color("1a1840")
const SIZE := Vector2(1920, 1080)
const BEAT_SECONDS := 3.6
const TEASER_SECONDS := 3.4
const CARD_SECONDS := 2.8
const ZOOMS := [0.0, 0.28, 0.56]  # the "dun dun DUN" sting's three hits (see Ambience: "dun")

var time_scale := 1.0  # tests run it in a blink
var sting := Callable()  # plays a sound sting by name (the bar's Ambience.sting)
var _stage: Control  # everything that shakes
var _burst: Node2D
var _subtitle: Label
var _who: PanelContainer
var _who_text: Label
var _teaser: Label
var _heart: Label
var _card: Control
var _episode_ko: Label
var _episode_en: Label
var _title: PanelContainer
var _flash: ColorRect
var _vignette: Polygon2D
var _sticker: Control
var _sky: Polygon2D
var _overlay: ColorRect
var _scratches: Array = []
var _style: Dictionary = {}
var _side := 1.0  # beats slide in from alternate sides
var _done := false


func _init() -> void:
	name = "RecapScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# (Full screen by its anchors: no size set here, or Godot warns it will be overridden.)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	_sky = Polygon2D.new()
	_sky.polygon = PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	_sky.vertex_colors = PackedColorArray([NIGHT_TOP, NIGHT_TOP, NIGHT_BOTTOM, NIGHT_BOTTOM])
	add_child(_sky)
	_burst = Node2D.new()  # slowly turning rays, like a variety show's
	_burst.position = SIZE / 2
	add_child(_burst)
	for k in 28:
		var a := TAU * k / 28.0
		var b := TAU * (k + 0.5) / 28.0
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a) * 1500, Vector2.from_angle(b) * 1500])
		ray.color = Color(PINK if k % 2 == 0 else Color("b48cff"), 0.07)
		_burst.add_child(ray)
	var spin := _burst.create_tween().set_loops()
	spin.tween_property(_burst, "rotation", TAU, 60.0).from(0.0)

	_stage = Control.new()
	_stage.size = SIZE
	_stage.pivot_offset = SIZE / 2
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_title = PanelContainer.new()
	_title.name = "RecapTitle"
	_title.add_theme_stylebox_override("panel", _pill(PINK, 30))
	_title.position = Vector2(90, 150)
	_title.rotation = -0.05
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_title)
	_title.add_child(_label("지난 이야기 · PREVIOUSLY ON…", 42, INK, 0))

	_who = PanelContainer.new()  # who the beat's about, in a name tag
	_who.add_theme_stylebox_override("panel", _pill(MINT, 20))
	_who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_who.visible = false
	_stage.add_child(_who)
	_who_text = _label("", 32, INK, 0)
	_who_text.name = "RecapWho"
	_who.add_child(_who_text)

	_subtitle = _label("", 54, CREAM, 16)
	_subtitle.name = "RecapBeat"
	# Narrower than the screen, so the triple zoom (up to 1.3x) keeps it on screen.
	_subtitle.position = Vector2(240, 400)
	_subtitle.size = Vector2(SIZE.x - 480, 300)
	_subtitle.pivot_offset = _subtitle.size / 2
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_subtitle.add_theme_constant_override("shadow_offset_x", 5)
	_subtitle.add_theme_constant_override("shadow_offset_y", 6)
	_stage.add_child(_subtitle)

	_heart = _label("두근두근 DUGEUN DUGEUN", 34, PINK, 10)
	_heart.position = Vector2(0, 330)
	_heart.size = Vector2(SIZE.x, 50)
	_heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heart.modulate.a = 0.0
	_stage.add_child(_heart)
	_teaser = _label("", 84, YELLOW, 24)
	_teaser.name = "RecapTeaser"
	_teaser.position = Vector2(200, 390)
	_teaser.size = Vector2(SIZE.x - 400, 320)
	_teaser.pivot_offset = _teaser.size / 2
	_teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teaser.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teaser.modulate.a = 0.0
	_stage.add_child(_teaser)

	_card = Control.new()
	_card.name = "RecapCard"
	_card.size = SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_stage.add_child(_card)
	for k in 3:  # ribbons sweeping across behind the episode number
		var ribbon := Polygon2D.new()
		ribbon.name = "Ribbon%d" % k
		var y := 430.0 + k * 70.0
		ribbon.polygon = PackedVector2Array([Vector2(-200, y), Vector2(SIZE.x + 200, y - 120), Vector2(SIZE.x + 200, y - 80), Vector2(-200, y + 40)])
		ribbon.color = Color([PINK, YELLOW, MINT][k], 0.75)
		_card.add_child(ribbon)
	_episode_ko = _label("", 150, CREAM, 34)
	_episode_ko.name = "RecapEpisode"
	_episode_ko.position = Vector2(0, 360)
	_episode_ko.size = Vector2(SIZE.x, 200)
	_episode_ko.pivot_offset = _episode_ko.size / 2
	_episode_ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_episode_ko.add_theme_color_override("font_outline_color", PINK.darkened(0.2))
	_card.add_child(_episode_ko)
	_episode_en = _label("", 40, YELLOW, 12)
	_episode_en.position = Vector2(0, 570)
	_episode_en.size = Vector2(SIZE.x, 60)
	_episode_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_episode_en)

	_vignette = Polygon2D.new()  # a red glow round the edges for the teaser
	var ring := PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	_vignette.polygon = ring
	_vignette.vertex_colors = PackedColorArray([Color(1, 0.1, 0.3, 0.35), Color(1, 0.1, 0.3, 0.35), Color(1, 0.1, 0.3, 0.35), Color(1, 0.1, 0.3, 0.35)])
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_overlay = ColorRect.new()  # the nostalgic style's old-film tint, with scratches
	_overlay.size = SIZE
	_overlay.color = Color(0.55, 0.38, 0.15, 0.22)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)
	for k in 3:
		var scratch := ColorRect.new()
		scratch.size = Vector2(2, SIZE.y)
		scratch.color = Color(1, 0.95, 0.8, 0.25)
		scratch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scratch.visible = false
		add_child(scratch)
		_scratches.append(scratch)
	for bar_y in [0.0, SIZE.y - 110.0]:  # letterbox bars, like a film
		var bar := ColorRect.new()
		bar.position = Vector2(0, bar_y)
		bar.size = Vector2(SIZE.x, 110)
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	_flash = ColorRect.new()  # the white camera flash between beats
	_flash.size = SIZE
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var skip := Button.new()
	skip.name = "RecapSkip"
	skip.text = "Skip ▶▶"
	skip.custom_minimum_size = Vector2(160, 52)
	skip.position = Vector2(SIZE.x - 220, SIZE.y - 90)
	skip.pressed.connect(end)
	add_child(skip)


## Plays it: the title, the beats, the teaser, the episode card. Emits finished at the end (or
## when skipped). extras: "people" (name -> Hangul), "moments" (the TV reactions, with who and
## mood) and "weather" (snow, or petals otherwise).
func play(beats: Array, teaser: String, episode: int, bar_name: String, opener: bool = false, extras: Dictionary = {}) -> void:
	_apply_style(str(extras.get("style", "melodrama")))
	(_title.get_child(0) as Label).text = "제1화 · THE FIRST EPISODE" if opener else str(_style["title"])
	_episode_ko.text = "제%d화" % episode
	_episode_en.text = "EP. %d · %s" % [episode, bar_name]
	var drift := str(_style["drift"])
	if str(extras.get("weather", "")).to_lower().contains("snow"):
		drift = "snow"
	_drift(drift)
	_slam(_title, -0.05)
	_sting("whoosh")
	await _wait(0.9)
	for k in beats.size():
		if _done:
			return
		var beat := str(beats[k])
		_subtitle.text = beat
		_subtitle.add_theme_font_size_override("font_size", 54 if beat.length() <= 70 else (46 if beat.length() <= 110 else 40))  # long ones smaller, to fit
		_show_who(beat, extras)
		var last := k == beats.size() - 1
		var how := str(_style["last"]) if last else str(_style["beats"])
		if how != "typewriter":
			_flash_white()
			_shake()
		_bring_on(_subtitle, how)
		_sting("dun" if last and how == "zoom" else str(_style["sting"]))
		await _wait(BEAT_SECONDS)
		if _done:
			return
		_clear_beat()
		await _wait(0.3)
	if _done:
		return
	_teaser.text = teaser
	_teaser.add_theme_font_size_override("font_size", 84 if teaser.length() <= 40 else (68 if teaser.length() <= 80 else 56))
	match str(_style["teaser"]):
		"glitch":
			_glitch()
		"bounce":
			_bounce()
		_:
			_heart_beat()
	_sting("dun" if str(_style["teaser"]) != "bounce" else "boing")
	await _wait(TEASER_SECONDS)
	if _done:
		return
	_fade(_teaser, 0.0)
	_fade(_heart, 0.0)
	_fade(_vignette, 0.0)
	_title.visible = false
	_card.visible = true
	_flash_white()
	_slam(_episode_ko, -0.06)
	for k in 3:
		var ribbon := _card.get_node("Ribbon%d" % k) as Polygon2D
		ribbon.position.x = -2400.0 if k % 2 == 0 else 2400.0
		create_tween().tween_property(ribbon, "position:x", 0.0, (0.35 + k * 0.08) * time_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_sting("sparkle")
	await _wait(CARD_SECONDS)
	end()


## Done (the end, or Skip): fades out and frees itself.
func end() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4 * time_scale)
	fade.tween_callback(queue_free)


func beat_text() -> String:
	return _subtitle.text


func who_text() -> String:
	return _who_text.text if _who.visible else ""


func style_name() -> String:
	return str(_style.get("name", ""))


## The colours and the overlay of a style (Rules.RECAP_STYLES).
func _apply_style(key: String) -> void:
	_style = Rules.RECAP_STYLES.get(key, Rules.RECAP_STYLES["melodrama"]).duplicate()
	_style["name"] = key if Rules.RECAP_STYLES.has(key) else "melodrama"
	var top := Color(str(_style["sky"][0]))
	var bottom := Color(str(_style["sky"][1]))
	_sky.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	for k in _burst.get_child_count():
		(_burst.get_child(k) as Polygon2D).color = Color(str(_style["rays"][k % 2]), 0.08)
	(_title.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(str(_style["pill"]))
	(_who.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(str(_style["tag"]))
	_teaser.add_theme_color_override("font_color", Color(str(_style["teaser_colour"])))
	for k in 3:
		(_card.get_node("Ribbon%d" % k) as Polygon2D).color = Color(str(_style["ribbons"][k]), 0.75)
	var sepia := str(_style["overlay"]) == "sepia"
	_overlay.visible = sepia
	for scratch: ColorRect in _scratches:
		scratch.visible = sepia
		if sepia:
			var flicker: Tween = scratch.create_tween().set_loops()
			flicker.tween_callback(_flicker.bind(scratch))
			flicker.tween_interval(randf_range(0.08, 0.3))
	if str(_style["beats"]) == "caption":
		_subtitle.add_theme_stylebox_override("normal", _pill(Color(str(_style["pill"])).darkened(0.1), 24))
		_subtitle.add_theme_color_override("font_color", INK)
		_subtitle.add_theme_constant_override("outline_size", 0)


## An old film's scratch, jumping about.
func _flicker(scratch: ColorRect) -> void:
	scratch.position.x = randf() * SIZE.x
	scratch.modulate.a = randf_range(0.2, 1.0)


## How a beat comes on: slammed down, slid in from the side, typed out, or popped up as a big
## variety caption with a tilt.
func _bring_on(node: Label, how: String) -> void:
	node.visible_ratio = 1.0
	match how:
		"zoom":
			_triple_zoom(node)  # the last beat: the dramatic zoom, one jolt per "dun"
		"slide":
			node.modulate.a = 1.0
			node.scale = Vector2.ONE
			node.rotation = 0.0
			var home := node.position
			node.position.x = home.x + SIZE.x * _side
			_side = -_side
			create_tween().tween_property(node, "position", home, 0.45 * time_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		"typewriter":
			node.modulate.a = 1.0
			node.scale = Vector2.ONE
			node.rotation = 0.0
			node.visible_ratio = 0.0
			create_tween().tween_property(node, "visible_ratio", 1.0, 1.4 * time_scale)
		"caption":
			_slam(node, randf_range(-0.06, 0.06))
		_:
			_slam(node, 0.0)


## The makjang teaser: it flickers and jumps like a bad signal, red and cyan.
func _glitch() -> void:
	_teaser.modulate.a = 1.0
	_teaser.scale = Vector2.ONE
	var tween := _teaser.create_tween()
	for k in 10:
		tween.tween_property(_teaser, "position", Vector2(200 + randf_range(-30, 30), 390 + randf_range(-12, 12)), 0.04 * time_scale)
		tween.tween_property(_teaser, "modulate", Color(1, 0.4, 0.4) if k % 2 == 0 else Color(0.5, 1, 1), 0.02 * time_scale)
	tween.tween_property(_teaser, "position", Vector2(200, 390), 0.05 * time_scale)
	tween.tween_property(_teaser, "modulate", Color.WHITE, 0.05 * time_scale)
	_fade(_vignette, 1.0)


## The variety teaser: it bounces in from above like a cartoon.
func _bounce() -> void:
	_teaser.modulate.a = 1.0
	_teaser.scale = Vector2.ONE
	_teaser.position.y = -400
	create_tween().tween_property(_teaser, "position:y", 390.0, 0.7 * time_scale).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_heart.text = "과연?! GWAYEON?! WILL THEY?!"
	_fade(_heart, 1.0)


## The beat's person, if it names one the game knows: their name tag (in Hangul too), and, if
## they had a big moment last time, its TV reaction stuck on beside the beat.
func _show_who(beat: String, extras: Dictionary) -> void:
	_who.visible = false
	if is_instance_valid(_sticker):
		_sticker.queue_free()
	var people: Dictionary = extras.get("people", {})
	for full in people:
		var given := Rules.given_name(str(full))
		if not (beat.contains(str(full)) or beat.contains(given)):
			continue
		var hangul := str(people[full])
		_who_text.text = ("%s %s" % [hangul, full]).strip_edges()
		_who.visible = true
		_who.position = Vector2(SIZE.x / 2 - 220, 330)
		_who.rotation = 0.04
		_slam(_who, 0.04)
		for moment in extras.get("moments", []):
			if str(moment.get("who", "")) != str(full) or not Rules.REACTIONS.has(str(moment.get("mood", ""))):
				continue
			var data: Dictionary = Rules.REACTIONS[str(moment["mood"])]
			var sticker := CaptionPopup.new()
			sticker.name = "RecapSticker"
			sticker.time_scale = time_scale
			sticker.stage_width = SIZE.x
			sticker.at = Vector2(SIZE.x - 330, 760)
			sticker.setup({"hangul": str(data["hangul"][0]), "english": str(moment.get("caption", ""))}, str(data["icon"]), Color(str(data["colour"])))
			_stage.add_child(sticker)
			sticker.pop(BEAT_SECONDS)
			_sticker = sticker
			break
		return


func _clear_beat() -> void:
	_fade(_subtitle, 0.0)
	_fade(_who, 0.0)


## Slams onto the screen: from big and tilted, down to size with a jolt.
func _slam(node: Control, tilt: float) -> void:
	if node.size.x > 0.0:
		node.pivot_offset = node.size / 2  # (from its middle)
	node.modulate.a = 1.0
	node.scale = Vector2(1.6, 1.6)
	node.rotation = tilt - 0.08
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.25 * time_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "rotation", tilt, 0.25 * time_scale)


## The K-drama triple zoom: three jolts closer, one on each hit of the sting.
func _triple_zoom(node: Control) -> void:
	node.pivot_offset = node.size / 2
	node.modulate.a = 1.0
	node.rotation = 0.0
	node.scale = Vector2.ONE
	var tween := create_tween()
	var at := 0.0
	for k in ZOOMS.size():
		tween.tween_interval(maxf(0.0, (float(ZOOMS[k]) - at)) * time_scale)
		tween.tween_property(node, "scale", Vector2.ONE * (1.08 + 0.11 * k), 0.06 * time_scale)  # to 1.3x at most.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		at = float(ZOOMS[k]) + 0.06
	tween.tween_callback(_shake)


## The teaser, throbbing like a heartbeat, with the red glow at the edges.
func _heart_beat() -> void:
	_teaser.modulate.a = 1.0
	_teaser.scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(_teaser, "scale", Vector2.ONE, 0.35 * time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var throb := _teaser.create_tween().set_loops(6)
	throb.tween_interval(0.35 * time_scale)
	throb.tween_property(_teaser, "scale", Vector2(1.07, 1.07), 0.12 * time_scale)
	throb.tween_property(_teaser, "scale", Vector2.ONE, 0.12 * time_scale)
	throb.tween_property(_teaser, "scale", Vector2(1.05, 1.05), 0.1 * time_scale)
	throb.tween_property(_teaser, "scale", Vector2.ONE, 0.2 * time_scale)
	_fade(_heart, 1.0)
	_fade(_vignette, 1.0)


func _flash_white() -> void:
	_flash.modulate.a = 0.85
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3 * time_scale)


func _shake() -> void:
	var tween := create_tween()
	for k in 6:
		tween.tween_property(_stage, "position", Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.035 * time_scale)
	tween.tween_property(_stage, "position", Vector2.ZERO, 0.05 * time_scale)


## Petals (or snow) drifting down through it all.
func _drift(kind: String) -> void:
	if kind == "none":
		return
	var snow := kind == "snow"
	for k in 26:
		var bit := Polygon2D.new()
		if kind == "sparks":
			var star := PackedVector2Array()
			for step in 8:
				star.append(Vector2.from_angle(TAU * step / 8.0 - PI / 2) * (9.0 if step % 2 == 0 else 3.0))
			bit.polygon = star
			bit.color = Color(YELLOW if k % 2 == 0 else Color("4fd2ff"), randf_range(0.6, 0.95))
		elif kind == "dust":
			bit.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
			bit.color = Color(1, 0.9, 0.7, randf_range(0.2, 0.5))
		elif snow:
			var points := PackedVector2Array()
			for step in 8:
				points.append(Vector2.from_angle(TAU * step / 8.0) * randf_range(3, 6))
			bit.polygon = points
			bit.color = Color(1, 1, 1, randf_range(0.4, 0.8))
		else:
			bit.polygon = PackedVector2Array([Vector2(0, -7), Vector2(5, 0), Vector2(0, 8), Vector2(-5, 0)])
			bit.color = Color(PINK.lightened(randf_range(0.0, 0.4)), randf_range(0.5, 0.85))
		bit.position = Vector2(randf() * SIZE.x, randf_range(-200, SIZE.y))
		add_child(bit)
		move_child(bit, 2)  # behind the text, in front of the sky
		var fall := bit.create_tween().set_loops()
		var seconds := randf_range(5.0, 9.0)
		fall.tween_property(bit, "position", bit.position + Vector2(randf_range(-160, 160), SIZE.y + 300), seconds)
		fall.parallel().tween_property(bit, "rotation", randf_range(-TAU, TAU), seconds)
		fall.tween_callback(func(): bit.position = Vector2(randf() * SIZE.x, -40))


func _fade(node: CanvasItem, to: float) -> void:
	create_tween().tween_property(node, "modulate:a", to, 0.3 * time_scale)


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds * time_scale).timeout


func _sting(sound: String) -> void:
	if sting.is_valid():
		sting.call(sound)


func _pill(colour: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = INK
	style.set_border_width_all(5)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_offset = Vector2(6, 6)
	return style


func _label(text: String, font_size: int, colour: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", INK)
	return label
