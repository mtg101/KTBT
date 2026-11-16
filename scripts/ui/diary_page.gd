extends Control
## A page of the owner's diary: cream paper with ruled lines and a red margin, the episode and
## the day (in Hangul and English) at the top, the entry in ink, and a stamp in the corner
## (Story.DIARY_STAMPS). Used at 3am (see visit.gd _end_night) and for the diary book. While the
## owner's still writing, a pen moves across the page instead.

const Story = preload("res://scripts/rules/story.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const PAPER := Ktv.PAPER
const RULE := Color(0.45, 0.6, 0.85, 0.28)
const MARGIN := Color(0.85, 0.3, 0.3, 0.45)
const INK := Color("2b3a67")
const WORD_INK := "a8326e"  # Korean words with a hover hint (Glossary.explain): a second pen, pink
const PINK := Ktv.PINK
const PAGE := Vector2(780, 600)
const LINE_GAP := 38.0  # the ruled lines, matched to the entry's lines
const BODY_TOP := 150.0
const LEFT := 80.0  # the margin

var _episode: Label
var _day: Label
var _whose: Label
var _body: RichTextLabel  # BBCode, for the Korean words' hover hints
var _writing: Label
var _pen: Polygon2D
var _pen_tween: Tween
var _stamp: Control


func _init() -> void:
	custom_minimum_size = PAGE
	size = PAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = PAGE / 2
	rotation = -0.012  # not quite straight, like a real notebook

	var pill := PanelContainer.new()
	pill.position = Vector2(LEFT + 10, 36)
	var style := Ktv.pill(PINK, 14, 3, 14, false)
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	add_child(pill)
	_episode = _label(26, Ktv.INK)
	_episode.name = "Episode"
	pill.add_child(_episode)
	_day = _label(24, INK)
	_day.name = "Day"
	_day.position = Vector2(LEFT + 150, 38)
	_day.size = Vector2(PAGE.x - LEFT - 180, 40)
	_day.clip_text = true
	add_child(_day)
	_whose = _label(18, INK.lightened(0.3))
	_whose.position = Vector2(LEFT + 12, 92)
	add_child(_whose)

	_body = RichTextLabel.new()
	_body.name = "Entry"
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_PASS  # (for the hover hints; clicks still go through)
	_body.add_theme_font_size_override("normal_font_size", 23)
	_body.add_theme_color_override("default_color", INK)
	_body.position = Vector2(LEFT + 12, BODY_TOP - 30)
	_body.size = Vector2(PAGE.x - LEFT - 60, PAGE.y - BODY_TOP - 20)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_separation", int(LINE_GAP) - 30)
	add_child(_body)

	_writing = _label(24, INK.lightened(0.2))
	_writing.name = "Writing"
	_writing.position = Vector2(LEFT + 12, BODY_TOP + 60)
	_writing.size = Vector2(PAGE.x - LEFT - 60, 40)
	_writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_writing.visible = false
	add_child(_writing)
	_pen = Polygon2D.new()
	_pen.polygon = PackedVector2Array([Vector2(0, 0), Vector2(8, -6), Vector2(46, -44), Vector2(38, -52), Vector2(0, -14), Vector2(-4, 4)])
	_pen.color = Ktv.INK
	_pen.visible = false
	add_child(_pen)

	_stamp = Control.new()
	_stamp.name = "Stamp"
	_stamp.position = Vector2(PAGE.x - 190, PAGE.y - 190)
	_stamp.size = Vector2(160, 160)
	_stamp.pivot_offset = Vector2(80, 80)
	_stamp.rotation = -0.22
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp)


## The owner's still writing: the page header, and a pen moving across the page.
func show_writing(episode: int, day: String, weather: String, who: String) -> void:
	_set_header(episode, day, weather, who)
	_body.visible = false
	_stamp.visible = false
	_writing.text = "✎ %s is writing in the diary…" % who
	_writing.visible = true
	_pen.visible = true
	_pen.position = Vector2(LEFT + 60, BODY_TOP + 160)
	if _pen_tween != null:
		_pen_tween.kill()
	_pen_tween = create_tween().set_loops()
	_pen_tween.tween_property(_pen, "position:x", PAGE.x - 120, 1.4).set_trans(Tween.TRANS_SINE)
	_pen_tween.tween_property(_pen, "position:y", _pen.position.y + LINE_GAP, 0.2)
	_pen_tween.tween_property(_pen, "position:x", LEFT + 60, 0.4)
	_pen_tween.tween_property(_pen, "position:y", BODY_TOP + 160, 0.2)


## A finished entry (as SaveStore.record_diary keeps it).
func show_entry(entry: Dictionary, whose: String) -> void:
	_set_header(int(entry.get("episode", entry.get("night", 1))), str(entry.get("day", "")), str(entry.get("weather", "")), whose)
	if _pen_tween != null:
		_pen_tween.kill()
	_pen.visible = false
	_writing.visible = false
	_body.text = Glossary.explain_hangul(Glossary.explain(str(entry.get("text", "")).replace("[", "[lb]"), _names_in(entry), WORD_INK))
	_body.visible = true
	_set_stamp(str(entry.get("stamp", "soju")))
	_stamp.visible = true
	_stamp.scale = Vector2(1.6, 1.6)  # thumped down onto the page
	_stamp.modulate.a = 0.0
	var thump := _stamp.create_tween()
	thump.tween_interval(0.3)
	thump.tween_property(_stamp, "modulate:a", 0.85, 0.05)
	thump.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The entry as written (without the hover hints).
func entry_text() -> String:
	return _body.get_parsed_text()


## The names in an entry's facts (the owner, who came, who didn't), left alone by the glossary.
func _names_in(entry: Dictionary) -> Array:
	var facts: Dictionary = entry.get("facts", {})
	var names: Array = [str(facts.get("owner", ""))]
	for person in facts.get("people", []) + facts.get("not_here", []) + facts.get("missing", []):
		names.append(str(person.get("name", "")) if person is Dictionary else str(person))
	return names


func _set_header(episode: int, day: String, weather: String, whose: String) -> void:
	_episode.text = "EP. %d" % episode
	_day.text = "%s %s · %s" % [Story.DAY_HANGUL.get(day, ""), day, weather]
	_day.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_day.tooltip_text = Text.tip(Glossary.hangul_tip(str(Story.DAY_HANGUL.get(day, ""))))
	_whose.text = whose


## A round seal, like an ink stamp: two rings, the Hangul big in the middle, the English small.
func _set_stamp(key: String) -> void:
	for child in _stamp.get_children():
		child.queue_free()
	var data: Dictionary = Story.DIARY_STAMPS.get(key, Story.DIARY_STAMPS["soju"])
	var colour := Color(str(data["colour"]))
	for ring in [[78.0, 6.0], [66.0, 2.5]]:
		var line := Line2D.new()
		line.width = float(ring[1])
		line.default_color = colour
		line.closed = true
		for k in 40:
			line.add_point(Vector2(80, 80) + Vector2.from_angle(TAU * k / 40.0) * float(ring[0]))
		_stamp.add_child(line)
	var hangul := _label(46 if str(data["hangul"]).length() <= 2 else 26, colour)
	hangul.position = Vector2(0, 46)
	hangul.size = Vector2(160, 60)
	hangul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hangul.text = str(data["hangul"])
	hangul.mouse_filter = Control.MOUSE_FILTER_STOP
	hangul.tooltip_text = Text.tip(Glossary.hangul_tip(str(data["hangul"])))
	_stamp.add_child(hangul)
	var english := _label(12, colour)
	english.position = Vector2(20, 104)
	english.size = Vector2(120, 20)
	english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	english.text = str(data["english"])
	_stamp.add_child(english)


func _draw() -> void:
	draw_rect(Rect2(Vector2(6, 8), PAGE), Color(0, 0, 0, 0.35))  # a shadow
	draw_rect(Rect2(Vector2.ZERO, PAGE), PAPER)
	var y := BODY_TOP + 8.0
	while y < PAGE.y - 20:
		draw_line(Vector2(20, y), Vector2(PAGE.x - 20, y), RULE, 2.0)
		y += LINE_GAP
	draw_line(Vector2(LEFT, 0), Vector2(LEFT, PAGE.y), MARGIN, 2.0)
	for hole in 3:  # punched holes down the side
		draw_circle(Vector2(36, PAGE.y * (0.2 + 0.3 * hole)), 10, Ktv.BACKGROUND)


func _label(font_size: int, colour: Color) -> Label:
	return Ktv.label("", font_size, colour)
