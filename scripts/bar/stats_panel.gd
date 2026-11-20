extends RefCounted
## The tent's side panel, in four tabs: Here now (who's here: the owner, the cat, the counter, as
## the tent's scene writes it); The show (where it goes out and who films it, how it's doing and
## what moves it on: the tent's scene writes it too); Diary (a button: it pops the owner's diary
## up full size over the screen); and Stats (tonight's debug stats, every section, chosen from a
## dropdown: Highlights first, All at the end; the highlights' times dimmed, so the moments stand
## out). The tab and the section are kept from night to night. The tent's scene builds the
## panel, places it, writes who's here and the show, and says when to refresh.
## (Part 11 of splitting visit.gd: see DEVLOG.md, 16 November 2026; its tabs 20 November.)

const NightStats = preload("res://scripts/bar/night_stats.gd")

const HERE := "HERE NOW"  # the tabs
const SHOW := "THE SHOW"
const STATS := "STATS"
const TABS := [[HERE, "Here now"], [SHOW, "📺 The show"], ["DIARY", "📖 Diary"], [STATS, "Stats"]]

var text: RichTextLabel  # the tab showing
var tabs: HFlowContainer  # the four tabs, and the stats' dropdown
var section_pick: OptionButton  # in the Stats tab: which section (or All)
var tab := HERE  # the tab showing (HERE, SHOW or STATS)
var section := "HIGHLIGHTS"  # the stats section showing (a section's title, or "ALL")
var accent: Color
var muted: Color
var on_diary: Callable  # the Diary tab: pops the book up (the tent's scene)
var _last: Array = []  # what it was last shown with (a tab or section chosen shows the same, there)
var _times := RegEx.create_from_string("(?m)^(\\d{1,2}:\\d\\dam|\\d{1,2}:\\d\\dpm)  ")


func _init(text_label: RichTextLabel, tab_row: HFlowContainer, accent_colour: Color, muted_colour: Color) -> void:
	text = text_label
	tabs = tab_row
	accent = accent_colour
	muted = muted_colour
	for each in TABS:
		var button := Button.new()
		button.name = "PanelTab_" + str(each[0]).replace(" ", "_")
		button.text = str(each[1])
		button.toggle_mode = str(each[0]) != "DIARY"
		button.button_pressed = each[0] == tab
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 16)
		button.set_meta("tab", str(each[0]))
		button.pressed.connect(_on_tab.bind(str(each[0])))
		tabs.add_child(button)
	section_pick = OptionButton.new()
	section_pick.name = "StatsSection"
	section_pick.focus_mode = Control.FOCUS_NONE
	section_pick.add_theme_font_size_override("font_size", 15)
	section_pick.visible = false
	section_pick.item_selected.connect(func(index: int):
		section = str(section_pick.get_item_metadata(index))
		_redo())
	tabs.add_child(section_pick)


## A tab chosen (as clicking it does): Here now, The show, Stats, or the Diary (popped up).
func show_tab(chosen: String) -> void:
	_on_tab(chosen)


## A stats section chosen (as picking it from the dropdown does): its title, or "ALL".
func show_section(title: String) -> void:
	section = title
	tab = STATS
	_redo()


func _on_tab(chosen: String) -> void:
	if chosen == "DIARY":
		if on_diary.is_valid():
			on_diary.call()
	else:
		tab = chosen
	for button in tabs.get_children():
		if button is Button and (button as Button).toggle_mode:
			(button as Button).set_pressed_no_signal(str(button.get_meta("tab", "")) == tab)
	_redo()


func _redo() -> void:
	if not _last.is_empty():
		refresh.callv(_last)


## Shows the tab chosen: who's here (here: the tent's text), the show (show: the tent's text), or
## tonight's stats (seated and cooking: how many now) in the section chosen.
func refresh(stats: NightStats, seated: int, cooking: int, night: int, here: String = "", show: String = "") -> void:
	_last = [stats, seated, cooking, night, here, show]
	for button in tabs.get_children():
		if button is Button and (button as Button).toggle_mode:
			(button as Button).set_pressed_no_signal(str(button.get_meta("tab", "")) == tab)
	section_pick.visible = tab == STATS
	if tab == HERE:
		text.text = "[color=#%s][b]HERE NOW[/b][/color]  [color=#%s]Night %d[/color]\n\n%s" % [accent.to_html(false), muted.to_html(false), night, here]
		return
	if tab == SHOW:
		text.text = "[color=#%s][b]THE SHOW[/b][/color]  [color=#%s]Night %d[/color]\n\n%s" % [accent.to_html(false), muted.to_html(false), night, show if show != "" else "(nothing yet)"]
		return
	var sections: Array = stats.sections(seated, cooking)
	_fill_sections(sections)
	if section != "ALL" and not sections.any(func(s): return s["title"] == section):
		section = "ALL" if sections.is_empty() else str(sections[0]["title"])
	var body := ""
	if section == "ALL":
		body = stats.panel_text(seated, cooking)
	else:
		for each in sections:
			if each["title"] == section:
				body = "[b]%s[/b]\n%s" % [each["title"], each["text"] if str(each["text"]) != "" else "(nothing yet)"]
	if section == "HIGHLIGHTS":  # (the times dimmed, so the moments stand out)
		body = _times.sub(body, "[color=#%s]$1[/color]  " % muted.to_html(false), true)
	text.text = "[color=#%s][b]STATS (debug)[/b][/color]  [color=#%s]Night %d[/color]\n\n%s" % [
		accent.to_html(false), muted.to_html(false), night, body]


## The dropdown's sections (each with its tab's short name, then All), remade only when they change.
func _fill_sections(sections: Array) -> void:
	var all: Array = sections.map(func(s): return [str(s["title"]), str(s["tab"])])
	all.append(["ALL", "All"])
	var labels := ",".join(PackedStringArray(all.map(func(t): return "%s=%s" % t)))
	if section_pick.has_meta("sections") and str(section_pick.get_meta("sections")) == labels:
		_select(section)
		return
	section_pick.set_meta("sections", labels)
	section_pick.clear()
	for k in all.size():
		section_pick.add_item(str(all[k][1]), k)
		section_pick.set_item_metadata(k, str(all[k][0]))
	_select(section)


func _select(title: String) -> void:
	for k in section_pick.item_count:
		if str(section_pick.get_item_metadata(k)) == title:
			section_pick.select(k)
