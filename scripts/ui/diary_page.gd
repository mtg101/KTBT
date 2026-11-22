extends Control
## A page of the owner's diary: cream paper with ruled lines and a red margin, the episode (its
## season and its episode in it, "S2 · EP 3": never a running count) and
## the day (in Hangul and English) at the top, the entry in ink, and a stamp in the corner
## (Story.DIARY_STAMPS), and the episode's TV ratings by the owner's name. Used at 3am (see visit.gd _end_night) and for the diary book. While the
## owner's still writing, a pen moves across the page instead. With the entry's polaroids
## (rules/keepsakes.gd: kept with it, so the diary book shows them too), one or two stuck down the
## right edge, half over it, the writing narrowed beside them; older entries have none.

const Story = preload("res://scripts/rules/story.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Names = preload("res://scripts/rules/names.gd")
const Polaroid = preload("res://scripts/ui/polaroid.gd")

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
const WHOSE_WIDTH := 270.0  # whose diary it is, left of the ratings
const PILL_MOST := PAGE.x - LEFT - 50.0  # the episode's pill, at its widest
const PHOTOS_AT := Vector2(PAGE.x - 120, 128)  # the polaroids, down the right edge (half over it)
const PHOTO_DROP := 196.0  # the second below the first, a little over it
const PHOTO_TILTS := [0.07, -0.09]
const PHOTO_ROOM := 110.0  # the writing narrowed by this, with polaroids
const STAMP_AT := Vector2(PAGE.x - 190, PAGE.y - 190)
const STAMP_BESIDE := Vector2(PAGE.x - 340, PAGE.y - 190)  # (with polaroids: clear of them)

var _episode: Label
var _pill: PanelContainer
var _day: Label
var _whose: Label
var _ratings: Label  # "시청률 6.4%", and a banner for a hit or a new best (Ratings), with its hover
var _body: RichTextLabel  # BBCode, for the Korean words' hover hints
var _writing: Label
var _pen: Polygon2D
var _pen_tween: Tween
var _stamp: Control
var _photos: Control  # the polaroids (ui/polaroid.gd), if the entry has any


func _init() -> void:
	custom_minimum_size = PAGE
	size = PAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = PAGE / 2
	rotation = -0.012  # not quite straight, like a real notebook

	# The header, a row each so nothing overlaps: the episode and its title in a pink pill (as
	# wide as it needs, never past the page: a long title trimmed with "…"); the day and weather,
	# the whole row; whose diary it is, with the ratings beside it.
	_pill = PanelContainer.new()
	var pill := _pill
	pill.name = "EpisodePill"
	pill.position = Vector2(LEFT + 10, 18)
	var style := Ktv.pill(PINK, 14, 3, 14, false)
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)
	add_child(pill)
	_episode = _label(26, Ktv.INK)
	_episode.name = "Episode"
	_episode.clip_text = true
	_episode.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pill.add_child(_episode)
	_day = _label(22, INK)
	_day.name = "Day"
	_day.clip_text = true
	_day.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_day.position = Vector2(LEFT + 12, 64)
	_day.size = Vector2(PAGE.x - 40 - (LEFT + 12), 30)  # (the whole row: the weather's never cut short)
	add_child(_day)
	_whose = _label(16, INK.lightened(0.3))
	_whose.name = "Whose"
	_whose.clip_text = true
	_whose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_whose.position = Vector2(LEFT + 12, 98)
	_whose.size = Vector2(WHOSE_WIDTH, 24)
	add_child(_whose)
	_ratings = _label(18, PINK.darkened(0.25))
	_ratings.name = "Ratings"
	_ratings.clip_text = true
	_ratings.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ratings.position = Vector2(LEFT + 12 + WHOSE_WIDTH + 10, 97)  # (beside whose diary it is)
	_ratings.size = Vector2(PAGE.x - 40 - (LEFT + 12 + WHOSE_WIDTH + 10), 26)
	_ratings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ratings.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_ratings.visible = false
	add_child(_ratings)

	_body = RichTextLabel.new()
	_body.name = "Entry"
	_body.bbcode_enabled = true
	_body.scroll_active = true  # (an entry longer than the page, from before the limit or a long one let through: the wheel scrolls it)
	_body.scroll_following = false
	_body.mouse_filter = Control.MOUSE_FILTER_PASS  # (for the hover hints and the wheel; clicks still go through)
	_body.add_theme_font_size_override("normal_font_size", 23)
	_body.add_theme_color_override("default_color", INK)
	_body.position = Vector2(LEFT + 12, BODY_TOP - 30)
	_body.size = Vector2(PAGE.x - LEFT - 60, PAGE.y - BODY_TOP - 10)  # (11 ruled lines)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := _body.get_v_scroll_bar()  # a thin bar in the margin, only when there's more to read
	bar.custom_minimum_size.x = 6
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(INK, 0.35)
	grabber.set_corner_radius_all(3)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, grabber)
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
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
	_stamp.position = STAMP_AT
	_stamp.size = Vector2(160, 160)
	_stamp.pivot_offset = Vector2(80, 80)
	_stamp.rotation = -0.22
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp)
	_photos = Control.new()
	_photos.name = "Photos"
	_photos.position = PHOTOS_AT
	_photos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_photos)


## The owner's still writing: the page header, and a pen moving across the page. episode: its
## tag ("S2 · EP 3", ShowSeasons.tag).
func show_writing(episode: String, day: String, weather: String, who: String) -> void:
	_set_header(episode, day, weather, who)
	_body.visible = false
	_stamp.visible = false
	_ratings.visible = false
	_show_photos([])
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
	_set_header(ShowSeasons.tag(ShowSeasons.of(entry)), str(entry.get("day", "")), str(entry.get("weather", "")), whose)
	if not entry.get("title", {}).is_empty():  # (its title, once it has one: the writers' or the PD's)
		_episode.text += " · " + Story.title_text(entry["title"])
		_fit_episode()
		var hangul := str(entry["title"].get("hangul", ""))
		if hangul != "":
			_episode.mouse_filter = Control.MOUSE_FILTER_STOP
			_episode.tooltip_text = Text.tip("%s: %s" % [hangul, entry["title"].get("english", "")])
	if _pen_tween != null:
		_pen_tween.kill()
	_pen.visible = false
	_writing.visible = false
	_show_photos(entry.get("photos", []))
	_body.text = Glossary.explain_hangul(Glossary.explain(str(entry.get("text", "")).replace("[", "[lb]"), _names_in(entry), WORD_INK))
	_body.visible = true
	_body.scroll_to_line(0)
	_show_ratings(entry.get("ratings", {}))
	_set_stamp(str(entry.get("stamp", "soju")))
	_stamp.visible = true
	_stamp.scale = Vector2(1.6, 1.6)  # thumped down onto the page
	_stamp.modulate.a = 0.0
	var thump := _stamp.create_tween()
	thump.tween_interval(0.3)
	thump.tween_property(_stamp, "modulate:a", 0.85, 0.05)
	thump.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The entry's polaroids ([{"name", "mood", "key", "look"}], as visit.gd _keep_faces keeps
## them): each face painted onto its own colours, in its mood (calm if that face isn't there),
## the given name under it; the writing and the stamp make room. None, or none drawable: the
## page as ever.
func _show_photos(photos: Array) -> void:
	for old in _photos.get_children():
		_photos.remove_child(old)
		old.queue_free()
	for photo in photos:
		if not photo is Dictionary or _photos.get_child_count() >= PHOTO_TILTS.size():
			continue
		var picture := Polaroid.picture_of(photo)
		if picture == null:
			continue
		var polaroid := Polaroid.new()
		var k := _photos.get_child_count()
		polaroid.setup(picture, str(photo.get("name", "")), Names.given_name(str(photo.get("name", ""))), float(PHOTO_TILTS[k]))
		polaroid.position = Vector2(14.0 * k, PHOTO_DROP * k)
		_photos.add_child(polaroid)
	var with_photos := _photos.get_child_count() > 0
	_body.size.x = PAGE.x - LEFT - 60 - (PHOTO_ROOM if with_photos else 0.0)
	_stamp.position = STAMP_BESIDE if with_photos else STAMP_AT


## Whose polaroids are on the page, in order (their full names).
func photo_names() -> Array:
	return _photos.get_children().filter(func(p): return not p.is_queued_for_deletion()).map(func(p): return str(p.who))


## The episode's ratings (Ratings.score, as kept with the entry): nothing for nights from before
## the show had ratings.
func _show_ratings(ratings: Dictionary) -> void:
	_ratings.visible = ratings.has("rating")
	if not _ratings.visible:
		return
	var banner := str(ratings.get("banner", ""))
	var rung := str(ratings.get("rung", Ladder.OLDER))  # (in the units of the rung it aired on: before the ladder, network TV)
	_ratings.text = "%s%s" % [Ladder.label(float(ratings["rating"]), rung, int(ratings.get("subscribers", -1))), ("  ·  %s %s" % [banner, Ladder.banner_english(banner)]) if banner != "" else ""]  # (the Korean, and the English beside it)
	var tip := Ladder.hover(ratings, rung)
	if banner != "":
		tip = "%s: %s\n%s" % [banner, Glossary.hangul_tip(banner), tip]
	_ratings.tooltip_text = Text.tip(tip)


## The ratings as shown ("시청률 6.4%"), or "" if there are none.
func ratings_text() -> String:
	return _ratings.text if _ratings.visible else ""


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


func _set_header(episode: String, day: String, weather: String, whose: String) -> void:
	_episode.text = episode
	_fit_episode()
	_day.text = "%s %s · %s" % [Story.DAY_HANGUL.get(day, ""), day, weather]
	_day.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_day.tooltip_text = Text.tip(Glossary.hangul_tip(str(Story.DAY_HANGUL.get(day, ""))))
	_whose.text = whose


## The episode's pill as wide as its words, but never past the page (then trimmed with "…").
func _fit_episode() -> void:
	var font := _episode.get_theme_font("font")
	var wide := font.get_string_size(_episode.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _episode.get_theme_font_size("font_size")).x
	_episode.custom_minimum_size.x = minf(ceilf(wide) + 2.0, PILL_MOST - 28.0)  # (the pill's margins)
	_pill.reset_size()


## How wide the episode's pill is, for the tests.
func pill_width() -> float:
	return _pill.get_combined_minimum_size().x


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
