extends RefCounted
## The debug stats panel's contents: a tab for each section of tonight's stats (and All),
## showing one at a time and opening on the highlights (their times dimmed, so the moments
## stand out). The tent's scene builds the panel, places it and says when to refresh.
## (Part 11 of splitting visit.gd: see PLAN.md, "A proper refactor".)

const NightStats = preload("res://scripts/bar/night_stats.gd")

var text: RichTextLabel  # the section showing
var tabs: HFlowContainer  # one button per section, and All
var tab := "HIGHLIGHTS"  # the section showing (or "ALL")
var accent: Color
var muted: Color
var _last: Array = []  # what it was last shown with (a tab clicked shows the same, in that section)
var _times := RegEx.create_from_string("(?m)^(\\d{1,2}:\\d\\dam|\\d{1,2}:\\d\\dpm)  ")


func _init(text_label: RichTextLabel, tab_row: HFlowContainer, accent_colour: Color, muted_colour: Color) -> void:
	text = text_label
	tabs = tab_row
	accent = accent_colour
	muted = muted_colour


## Shows tonight's stats (seated and cooking: how many now) in the section chosen.
func refresh(stats: NightStats, seated: int, cooking: int, night: int) -> void:
	_last = [stats, seated, cooking, night]
	var sections: Array = stats.sections(seated, cooking)
	var all_tabs: Array = sections.map(func(s): return [str(s["title"]), str(s["tab"])])
	all_tabs.append(["ALL", "All"])
	if not all_tabs.any(func(t): return t[0] == tab):
		tab = "HIGHLIGHTS"
	_show_tabs(all_tabs)
	var body := ""
	if tab == "ALL":
		body = stats.panel_text(seated, cooking)
	else:
		for section in sections:
			if section["title"] == tab:
				body = "[b]%s[/b]\n%s" % [section["title"], section["text"] if str(section["text"]) != "" else "(nothing yet)"]
	if tab == "HIGHLIGHTS":  # (the times dimmed, so the moments stand out)
		body = _times.sub(body, "[color=#%s]$1[/color]  " % muted.to_html(false), true)
	text.text = "[color=#%s][b]STATS (debug)[/b][/color]  [color=#%s]Night %d · F3 hides[/color]\n\n%s" % [
		accent.to_html(false), muted.to_html(false), night, body]


## The tab buttons ([title, label] each), remade only when they change.
func _show_tabs(all_tabs: Array) -> void:
	var labels := ",".join(PackedStringArray(all_tabs.map(func(t): return "%s=%s" % t)))
	if tabs.has_meta("tabs") and str(tabs.get_meta("tabs")) == labels:
		return
	tabs.set_meta("tabs", labels)
	for old in tabs.get_children():
		tabs.remove_child(old)  # (now, so the new ones get their names)
		old.queue_free()
	for each in all_tabs:
		var button := Button.new()
		button.name = "StatsTab_" + str(each[0]).replace(" ", "_")
		button.text = str(each[1])
		button.toggle_mode = true
		button.button_pressed = each[0] == tab
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.set_meta("tab", str(each[0]))
		button.pressed.connect(func():
			tab = str(each[0])
			for other in tabs.get_children():
				(other as Button).set_pressed_no_signal(str(other.get_meta("tab")) == tab)
			refresh.callv(_last))
		tabs.add_child(button)
