extends Control
## The season, looked back on (시즌 결산): at 3am after the finale, in place of the diary page
## (see visit.gd _end_season), a K-TV board with an episode a row (its title, a bar for its
## ratings, the line pinned that night) and, at the bottom, the channel's verdict stamped on
## (ShowSeasons.verdict), with its hover saying how it was decided. The best episode's in yellow.

const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

const PAGE := Vector2(780, 600)  # the diary page's size, so the summary's buttons stay put
const ROW_HEIGHT := 51.0
const ROWS_TOP := 94.0
const TEXT_LEFT := 96.0  # where the titles and lines start, after "S1 · EP 3"
const BAR_WIDTH := 150.0  # a 15% episode fills it
const BAR_FULL := 15.0

var _heading: Label
var _sub: Label
var _rows: VBoxContainer
var _stamp: Label
var _words: Label
var _shown := 0
var _rung := ""  # the rung the season aired on (its numbers in its units)


func _init() -> void:
	custom_minimum_size = PAGE
	size = PAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading = Ktv.label(ShowSeasons.LOOKED_BACK_HANGUL, 34, Ktv.PINK, 8)
	_heading.name = "SeasonHeading"
	_heading.position = Vector2(30, 14)
	_heading.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_heading.tooltip_text = Text.tip(Glossary.hangul_tip(ShowSeasons.LOOKED_BACK_HANGUL))
	add_child(_heading)
	_sub = Ktv.label("", 20, Ktv.CREAM)
	_sub.name = "SeasonSub"
	_sub.position = Vector2(34, 62)
	_sub.size = Vector2(PAGE.x - 60, 28)
	_sub.clip_text = true
	add_child(_sub)
	_rows = VBoxContainer.new()
	_rows.name = "SeasonRows"
	_rows.position = Vector2(24, ROWS_TOP)
	_rows.size = Vector2(PAGE.x - 48, ROW_HEIGHT * ShowSeasons.EPISODES)
	_rows.add_theme_constant_override("separation", 0)
	add_child(_rows)
	_stamp = Ktv.label("", 36, Ktv.YELLOW, 8)
	_stamp.name = "SeasonVerdict"
	_stamp.position = Vector2(30, PAGE.y - 86)
	_stamp.rotation = -0.06
	_stamp.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_stamp)
	_words = Ktv.label("", 18, Ktv.LIGHT)
	_words.name = "SeasonWords"
	_words.position = Vector2(250, PAGE.y - 88)
	_words.size = Vector2(PAGE.x - 280, 76)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_words)


## The season: its rows (ShowSeasons.recap_rows), the verdict (ShowSeasons.verdict), the bar's
## name. The rows come in one after another, then the stamp thumps down.
func show_season(rows: Array, judged: Dictionary, bar_name: String) -> void:
	for child in _rows.get_children():
		child.queue_free()
	_rung = str(judged.get("rung", Ladder.OLDER))
	_sub.text = "SEASON %d, LOOKED BACK ON  ·  %s  ·  %s  ·  %s" % [int(judged.get("season", 1)), bar_name, str(Ladder.rung(_rung)["name"]).to_upper() + ((" (%s)" % judged["channel"]) if str(judged.get("channel", "")) != "" else ""),
		ShowSeasons.season_done(judged)]
	var best := 0.0
	for row in rows:
		best = maxf(best, float(row.get("rating", 0.0)))
	_shown = 0
	var tween := create_tween()
	for k in rows.size():
		var made := _row(rows[k], int(judged.get("season", 1)), k == rows.size() - 1, is_equal_approx(float(rows[k].get("rating", 0.0)), best))
		made.modulate.a = 0.0
		_rows.add_child(made)
		_shown += 1
		tween.tween_property(made, "modulate:a", 1.0, 0.18)
	var tip := Text.tip("%s: %s\n%s" % [judged.get("stamp", ""), Glossary.hangul_tip(str(judged.get("stamp", ""))), ShowSeasons.hover(judged)])
	_stamp.text = str(judged.get("stamp", ""))
	_stamp.tooltip_text = tip
	_words.text = str(judged.get("words", ""))
	_words.tooltip_text = tip
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(1.6, 1.6)
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## How many episodes are on the page.
func rows_shown() -> int:
	return _shown


## The verdict as shown: "재계약!  Renewed for season 2."
func verdict_text() -> String:
	return "%s  %s" % [_stamp.text, _words.text]


## One episode, on two lines: "S1 · EP 3", its title, a bar for its ratings and the number;
## then the line pinned that night, across the row (trimmed with "…" if it's long). A faint
## rule under it, unless it's the last.
func _row(row: Dictionary, season: int, finale: bool, best: bool) -> Control:
	var width := PAGE.x - 48
	var box := Control.new()
	box.name = "Episode%d" % int(row.get("episode", 0))
	box.custom_minimum_size = Vector2(width, ROW_HEIGHT)
	box.clip_contents = true  # (nothing drawn outside its row)
	box.mouse_filter = Control.MOUSE_FILTER_STOP  # (its hover: the whole line)
	var colour := Ktv.YELLOW if best else Ktv.CREAM
	var episode := Ktv.label(ShowSeasons.tag({"season": season, "episode": int(row.get("episode", 0))}), 16, Ktv.PINK)
	episode.position = Vector2(4, 4)
	box.add_child(episode)
	if finale:
		var last := Ktv.label(ShowSeasons.FINALE_HANGUL, 14, Ktv.PINK)
		last.position = Vector2(4, 27)
		last.mouse_filter = Control.MOUSE_FILTER_STOP
		last.tooltip_text = Text.tip(Glossary.hangul_tip(ShowSeasons.FINALE_HANGUL))
		box.add_child(last)
	var title := str(row.get("title", ""))
	var number_x := width - 66
	var bar_x := number_x - BAR_WIDTH - 12
	var heading := _clipped(title if title != "" else ("Tonight's finale" if finale else "(no title)"), 19, colour, Vector2(TEXT_LEFT, 1), Vector2(bar_x - TEXT_LEFT - 12, 26))
	heading.name = "Title"
	box.add_child(heading)
	var rating := float(row.get("rating", 0.0))
	var bar := ColorRect.new()
	bar.color = Ktv.YELLOW if best else Ktv.MINT
	bar.position = Vector2(bar_x, 7)
	bar.size = Vector2(maxf(4.0, BAR_WIDTH * minf(rating / BAR_FULL, 1.0)), 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var number := _clipped(Ladder.short(rating, _rung), 19, colour, Vector2(number_x, 1), Vector2(64, 26))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(number)
	var quote: Dictionary = row.get("quote", {})
	var said := "“%s”  — %s" % [str(quote.get("text", "")), str(quote.get("speaker", ""))] if str(quote.get("text", "")) != "" else ""
	var line := _clipped(said, 15, Ktv.MUTED, Vector2(TEXT_LEFT, 27), Vector2(width - TEXT_LEFT - 4, 22))
	line.name = "Quote"
	box.add_child(line)
	if not finale:
		var rule := ColorRect.new()
		rule.color = Color(Ktv.LIGHT, 0.08)
		rule.position = Vector2(4, ROW_HEIGHT - 1)
		rule.size = Vector2(width - 8, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rule)
	box.tooltip_text = Text.tip("Season %d, episode %d%s: %s, %s%s" % [season, int(row.get("episode", 0)), (", " + title) if title != "" else "", Ladder.text(rating, _rung), Ladder.band(rating, _rung),
		("\n" + said) if said != "" else ""])
	return box


## A one-line label kept to its box, trimmed with "…" (clipping set before its size, or it
## grows to fit the whole text).
func _clipped(text: String, font_size: int, colour: Color, at: Vector2, box_size: Vector2) -> Label:
	var made := Ktv.label("", font_size, colour)
	made.clip_text = true
	made.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	made.text = text
	made.position = at
	made.size = box_size
	return made


func _draw() -> void:
	var panel := Ktv.pill(Ktv.PANEL, 18, 4, 0, true)
	draw_style_box(panel, Rect2(Vector2.ZERO, PAGE))
