extends VBoxContainer
## The transcript on screen (bottom left), easier to use when you want to check on something or
## find a line to pin: a slim toolbar over it (search, with how many lines match and Enter to go
## through them; All, Talk or Events; text size; Compact) and, when you've scrolled up to read,
## a "↓ 7 new lines" button back to the latest. It keeps the night's chunks as visit.gd adds
## them ({"text", "pin": a line said, or -1, "at": game minutes, or -1}) and draws them again
## when something changes (a pin, the search, the filter); visit.gd says how a chunk's drawn
## (render: a line said ends in its 📌). Text size and Compact are remembered (settings.cfg,
## beside the sound's). What you do with it is said (used), for the stats and the log.

const Text = preload("res://scripts/rules/text.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

signal used(what: String, detail: String)  # "search" (the query · how many lines), "jump", "filter" (all, talk, events), "catch_up" (how many new), "size", "compact" (on, off)

const SIZES := [12, 13, 15, 17, 19, 22]  # the text sizes A− and A+ step through
const DEFAULT_SIZE := 15  # (the side panel's: more of the night on screen, scrolling by slower)
const FILTERS := {"all": "All", "talk": "Talk", "events": "Events"}
const FILTER_TIPS := {"all": "Everything: what's said, what happens, the captions.",
	"talk": "Only what people say (the lines you can pin with their 📌).",
	"events": "Only what happens: arrivals, orders, the PD's cards, captions, the owner's notes."}
const MATCH := Color(1.0, 0.82, 0.5, 0.35)  # a line matching the search
const CURRENT := Color(1.0, 0.82, 0.5, 0.75)  # ...and the one it's on
const SEARCH_SETTLES := 0.8  # seconds without typing before a search counts (the stats)
const FOLLOW_SLACK := 8.0  # pixels from the bottom that still count as at the latest

var transcript: RichTextLabel  # "Transcript": the lines themselves
var search: LineEdit
var count_label: Label
var filter_buttons := {}  # "all", "talk", "events" -> Button
var compact_button: Button
var new_button: Button  # "↓ 7 new lines"
var render: Callable  # (chunk) -> its BBCode as shown (visit.gd: a line said gets its 📌)
var chunks: Array = []
var filter := "all"
var query := ""
var font_size := DEFAULT_SIZE
var compact := false
var unseen := 0  # lines added while scrolled up
var matches: Array = []  # indexes into chunks of the shown lines matching the search
var current := -1  # which match it's on (an index into matches)
var _paragraphs := {}  # chunk index -> the paragraph it starts on, as drawn now
var _settle: Timer
var _tag := RegEx.create_from_string("\\[[^\\]]*\\]")


func build() -> void:
	add_theme_constant_override("separation", 6)
	var bar := HFlowContainer.new()
	bar.name = "TranscriptTools"
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 4)
	add_child(bar)
	search = LineEdit.new()
	search.name = "TranscriptSearch"
	search.placeholder_text = "🔍 Search (Ctrl+F)"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(230, 0)
	search.tooltip_text = Text.tip("Find lines tonight: words, or someone's name. Enter for the next, Shift+Enter the one before, Esc to clear.")
	search.text_changed.connect(_on_search_changed)
	search.text_submitted.connect(func(_t): next_match(1))
	search.gui_input.connect(_on_search_key)
	bar.add_child(search)
	count_label = Label.new()
	count_label.name = "TranscriptMatches"
	count_label.custom_minimum_size = Vector2(70, 0)
	count_label.add_theme_color_override("font_color", Ktv.MUTED)
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(count_label)
	for step in [[-1, "▲", "The match before (Shift+Enter)"], [1, "▼", "The next match (Enter)"]]:
		var button := _tool_button("TranscriptMatch%s" % ("Up" if step[0] < 0 else "Down"), str(step[1]), str(step[2]))
		button.pressed.connect(next_match.bind(int(step[0])))
		bar.add_child(button)
	var group := ButtonGroup.new()
	for kind in FILTERS:
		var button := _tool_button("TranscriptShow_" + kind, FILTERS[kind], FILTER_TIPS[kind])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = kind == "all"
		button.pressed.connect(set_filter.bind(kind))
		filter_buttons[kind] = button
		bar.add_child(button)
	var smaller := _tool_button("TranscriptSmaller", "A−", "Smaller text")
	smaller.pressed.connect(step_size.bind(-1))
	bar.add_child(smaller)
	var bigger := _tool_button("TranscriptBigger", "A+", "Bigger text")
	bigger.pressed.connect(step_size.bind(1))
	bar.add_child(bigger)
	compact_button = _tool_button("TranscriptCompact", "Compact", "Lines closer together, each with the time it was said: easier to scan.")
	compact_button.toggle_mode = true
	compact_button.toggled.connect(set_compact)
	bar.add_child(compact_button)

	transcript = RichTextLabel.new()
	transcript.name = "Transcript"
	transcript.bbcode_enabled = true
	transcript.scroll_following = true
	transcript.selection_enabled = true
	transcript.meta_underlined = false  # (a line's 📌 is a link)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(transcript)
	transcript.get_v_scroll_bar().value_changed.connect(func(_v):
		if unseen > 0 and following():
			unseen = 0
			_show_unseen())

	new_button = Button.new()
	new_button.name = "TranscriptCatchUp"
	new_button.focus_mode = Control.FOCUS_NONE
	new_button.visible = false
	new_button.tooltip_text = Text.tip("Back to the latest line, following it again (End).")
	new_button.pressed.connect(catch_up)
	add_child(new_button)

	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SEARCH_SETTLES
	_settle.timeout.connect(func():
		if query != "":
			used.emit("search", "«%s» · %d line%s" % [query, matches.size(), "" if matches.size() == 1 else "s"]))
	add_child(_settle)

	var settings := ConfigFile.new()
	if settings.load(Ambience.settings_path) == OK:
		font_size = int(settings.get_value("transcript", "font_size", DEFAULT_SIZE))
		compact = bool(settings.get_value("transcript", "compact", false))
	if not SIZES.has(font_size):
		font_size = DEFAULT_SIZE
	compact_button.set_pressed_no_signal(compact)
	_apply_size()
	_update_count()


func _tool_button(id: String, words: String, tip: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36, 0)
	button.tooltip_text = Text.tip(tip)
	return button


## A chunk added (visit.gd _show): drawn if it's shown, counted as new if you've scrolled up.
func add(chunk: Dictionary) -> void:
	chunks.append(chunk)
	var k := chunks.size() - 1
	if not shows(chunk):
		return
	var was_following := following()
	if query != "" and _matches(chunk):
		matches.append(k)
		_update_count()
	_append(k)
	if not was_following:
		unseen += 1
		_show_unseen()


## Whether a chunk's shown with the filter as it is.
func shows(chunk: Dictionary) -> bool:
	match filter:
		"talk":
			return int(chunk.get("pin", -1)) >= 0
		"events":
			return int(chunk.get("pin", -1)) < 0
	return true


## Whether it's at the latest line (following it).
func following() -> bool:
	var bar := transcript.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - FOLLOW_SLACK


## Everything drawn again (a pin changed, the search, the filter, Compact): where it's scrolled
## to kept, unless it was at the latest line.
func redraw() -> void:
	var bar := transcript.get_v_scroll_bar()
	var at := bar.value
	var was_following := following()
	transcript.clear()
	_paragraphs = {}
	for k in chunks.size():
		if shows(chunks[k]):
			_append(k)
	if not was_following:
		await get_tree().process_frame
		bar.value = at


func _append(k: int) -> void:
	_paragraphs[k] = maxi(transcript.get_paragraph_count() - 1, 0)
	transcript.append_text(_display(chunks[k], k))


## A chunk as shown: visit.gd's drawing of it, closer together with its time if Compact, and
## the search's matches marked.
func _display(chunk: Dictionary, k: int) -> String:
	var bb: String = render.call(chunk) if render.is_valid() else str(chunk.get("text", ""))
	if compact:
		while bb.contains("\n\n"):
			bb = bb.replace("\n\n", "\n")
		var at := int(chunk.get("at", -1))
		if at >= 0:
			bb = "[color=#%s]%s[/color]  %s" % [Ktv.MUTED.darkened(0.2).to_html(false), NightRules.clock_text(at), bb]
	if query != "" and matches.has(k):
		bb = highlighted(bb, query, CURRENT if current >= 0 and current < matches.size() and matches[current] == k else MATCH)
	return bb


## Where the query's found in some BBCode's words (never inside its tags), marked.
func highlighted(bb: String, words: String, colour: Color) -> String:
	var out := ""
	var at := 0
	for tag in _tag.search_all(bb):
		out += _mark(bb.substr(at, tag.get_start() - at), words, colour) + tag.get_string()
		at = tag.get_end()
	return out + _mark(bb.substr(at), words, colour)


func _mark(text: String, words: String, colour: Color) -> String:
	var lower := text.to_lower()
	var find := words.to_lower()
	var out := ""
	var at := 0
	var hit := lower.find(find)
	while hit >= 0 and find != "":
		out += text.substr(at, hit - at) + "[bgcolor=#%s]%s[/bgcolor]" % [colour.to_html(true), text.substr(hit, find.length())]
		at = hit + find.length()
		hit = lower.find(find, at)
	return out + text.substr(at)


## A chunk's words, without its tags (what the search looks in: names included).
func plain(chunk: Dictionary) -> String:
	return _tag.sub(str(chunk.get("text", "")), "", true)


func _matches(chunk: Dictionary) -> bool:
	return query != "" and plain(chunk).to_lower().contains(query.to_lower())


func _on_search_changed(words: String) -> void:
	query = words.strip_edges()
	_find()
	redraw()
	_settle.start()


func _find() -> void:
	matches = []
	current = -1
	if query != "":
		for k in chunks.size():
			if shows(chunks[k]) and _matches(chunks[k]):
				matches.append(k)
	_update_count()


func _update_count() -> void:
	if count_label == null:
		return
	if query == "":
		count_label.text = ""
	elif matches.is_empty():
		count_label.text = "none"
	else:
		count_label.text = "%s of %d" % [str(current + 1) if current >= 0 else "–", matches.size()]


## On to the next match (step 1) or the one before (-1), round from the end, scrolled to.
func next_match(step: int) -> void:
	if matches.is_empty():
		return
	if current < 0:
		current = 0 if step > 0 else matches.size() - 1
	else:
		current = posmod(current + step, matches.size())
	_update_count()
	await redraw()
	await get_tree().process_frame  # (laid out first, so the paragraph's where it's drawn)
	transcript.scroll_to_paragraph(int(_paragraphs.get(matches[current], 0)))
	used.emit("jump", "%d of %d" % [current + 1, matches.size()])


func _on_search_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		search.clear()
		_on_search_changed("")
		search.release_focus()
		search.accept_event()
	elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and key.shift_pressed:
		next_match(-1)
		search.accept_event()


## Ctrl+F to search; End back to the latest line (not while typing in the search).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_F and key.ctrl_pressed:
		search.grab_focus()
		search.select_all()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_END and not search.has_focus() and unseen > 0:
		catch_up()
		get_viewport().set_input_as_handled()


## All, Talk (only lines said: the ones you can pin) or Events (only what happens).
func set_filter(kind: String) -> void:
	if not FILTERS.has(kind) or kind == filter:
		return
	filter = kind
	filter_buttons[kind].set_pressed_no_signal(true)
	_find()
	unseen = 0
	_show_unseen()
	redraw()
	used.emit("filter", kind)


## Text a size smaller (-1) or bigger (1), remembered.
func step_size(step: int) -> void:
	var k := clampi(SIZES.find(font_size) + step, 0, SIZES.size() - 1)
	if SIZES[k] == font_size:
		return
	font_size = SIZES[k]
	_apply_size()
	_save("font_size", font_size)
	used.emit("size", str(font_size))


func _apply_size() -> void:
	for kind in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		transcript.add_theme_font_size_override(kind, font_size)


## Compact on or off, remembered.
func set_compact(on: bool) -> void:
	if on == compact:
		return
	compact = on
	compact_button.set_pressed_no_signal(on)
	redraw()
	_save("compact", compact)
	used.emit("compact", "on" if on else "off")


## Back to the latest line, following it again.
func catch_up() -> void:
	var missed := unseen
	unseen = 0
	_show_unseen()
	transcript.scroll_to_line(maxi(transcript.get_line_count() - 1, 0))
	var bar := transcript.get_v_scroll_bar()
	bar.value = bar.max_value
	used.emit("catch_up", str(missed))


func _show_unseen() -> void:
	new_button.visible = unseen > 0
	new_button.text = "↓ %d new line%s" % [unseen, "" if unseen == 1 else "s"]


func _save(key: String, value: Variant) -> void:
	var settings := ConfigFile.new()
	settings.load(Ambience.settings_path)  # (keep the sound's, and anything else, in there)
	settings.set_value("transcript", key, value)
	settings.save(Ambience.settings_path)
