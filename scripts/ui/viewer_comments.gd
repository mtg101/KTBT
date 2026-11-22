extends PanelContainer
## The viewers' comments on tonight's episode (rules/viewers.gd), stuck by the 3am diary page with
## the posts (ui/social_feed.gd) and in the diary book, looking like where the show's rung has
## them: the phone stream's live chat (dark, a red LIVE, how many are watching, hearts), the
## online video channel's comments under the episode (white, likes), network TV's viewer board
## (a board's rows, each with its recommends). Korean explained on hover. Never takes a click;
## its hovers still show.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")
const Viewers = preload("res://scripts/rules/viewers.gd")

const WIDTH := 400.0
const RED := "e0413a"
## Each place's look: its card, ink, the handles' and likes' colours.
const LOOKS := {
	"live": {"card": Color(0.06, 0.05, 0.1, 0.88), "ink": Color("f4f1ff"), "handle": "9fd8ff", "likes": "ff7aa8", "word": "ffd36b"},
	"comments": {"card": Color("fdfcf8"), "ink": Color("23203f"), "handle": "1d1b33", "likes": "6b6880", "word": "a8326e"},
	"board": {"card": Color("eef2fa"), "ink": Color("1f2a44"), "handle": "4a5a7a", "likes": "2f62c8", "word": "a8326e"},
}

var place := ""  # "live", "comments" or "board", for the tests and the log
var rows := 0  # how many comments are up


## board: as Viewers.pick makes it (and the entry keeps it); tilt: radians.
func setup(board: Dictionary, tilt: float) -> void:
	name = "ViewerComments"
	place = str(board.get("place", "comments"))
	var look: Dictionary = LOOKS.get(place, LOOKS["comments"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = look["card"]
	style.set_corner_radius_all(4 if place == "board" else 14)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_offset = Vector2(5, 7)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(_title(board, look))
	for comment in board.get("comments", []):
		if comment is Dictionary:
			column.add_child(_row(board, comment, look))
			rows += 1
	rotation = tilt
	resized.connect(func(): pivot_offset = size / 2.0)


## Where they're commenting and the count ("● LIVE 실시간 채팅 live chat · 130 watching"), its Korean on hover.
func _title(board: Dictionary, look: Dictionary) -> Control:
	var data := Viewers.place_of(str(board.get("rung", "")))
	var title := RichTextLabel.new()
	title.name = "Title"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(WIDTH - 28.0, 0)
	title.mouse_filter = Control.MOUSE_FILTER_PASS  # (for the hovers; clicks go through)
	title.add_theme_font_size_override("normal_font_size", 15)
	title.add_theme_color_override("default_color", (look["ink"] as Color).lerp(look["card"], 0.3))
	var live := "[color=#%s]● LIVE[/color]  " % RED if place == "live" else ""
	title.text = live + Glossary.explain_hangul(Viewers.title(board).replace("[", "[lb]"))
	title.tooltip_text = Text.tip("%s %s: where the show's viewers comment on %s. %s" % [data["hangul"], data["english"],
		"the live stream" if place == "live" else ("each episode" if place == "board" else "each episode's video"), Glossary.hangul_tip(str(data["hangul"]))])
	return title


## A comment: its viewer, the words (Korean and the game's words explained on hover) and its likes.
func _row(board: Dictionary, comment: Dictionary, look: Dictionary) -> Control:
	var row := RichTextLabel.new()
	row.name = "Comment"
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.custom_minimum_size = Vector2(WIDTH - 28.0, 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_font_size_override("normal_font_size", 16)
	row.add_theme_color_override("default_color", look["ink"])
	var viewer := str(comment.get("viewer", "")).replace("[", "[lb]")
	var said := Glossary.explain(str(comment.get("text", "")).replace("[", "[lb]"), [], str(look["word"]))
	var likes := Viewers.likes_text(board, comment)
	if place == "board":
		row.text = Glossary.explain_hangul("%s\n[color=#%s][font_size=13]%s · %s[/font_size][/color]" % [said, look["handle"], viewer, likes])
	else:
		row.text = Glossary.explain_hangul("[color=#%s][b]%s[/b][/color]  %s  [color=#%s]%s[/color]" % [look["handle"], viewer, said, look["likes"], likes])
	return row
