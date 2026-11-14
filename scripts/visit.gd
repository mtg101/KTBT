extends Control
## One visit.
##
## When the scene starts, the AI invents the tent's owner. Press "Next customer" and
## one customer arrives, orders from the menu, is served, chats with the owner,
## pays and leaves. Grey boxes for now; real art comes in a later stage.
##
## The game owns the facts (time, menu, prices, the bill, how a visit runs);
## the AI owns the flavour (who the people are and what they say).

const Ai = preload("res://scripts/ai.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")
const Rules = preload("res://scripts/rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")

const HUNGRY_CHANCE := 0.15  # How often a customer is hungry enough to order two main dishes.
const ROUGH_NIGHT_CHANCE := 0.2  # How often a customer is having a rough enough night to order two drinks.
## Free side dishes served with every order, as at a real pojangmacha. Not on the bill.
const BANCHAN := "kimchi and pickled radish"

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const WEATHER := [
	"light drizzle",
	"heavy rain drumming on the tarp",
	"clear, bitterly cold air",
	"the first snow of winter",
	"a muggy summer heat",
	"thick fog",
	"a warm spring breeze",
]

const ACCENT := Color("e8833a")
const MUTED := Color("a9a6c2")
const OWNER_COLOR := Color("8f8aa8")
const OWNER_TEXT := Color("ffd27f")
const CUSTOMER_COLORS := [Color("6fa8c7"), Color("8fc79a"), Color("c78fb5"), Color("c7b06f"), Color("9a8fc7"), Color("c7836f")]

# Where things stand in the scene (pixels, inside the stage area).
# Screen layout (pixels, at the project's 1920x1080; Godot scales it to the window).
const SCREEN := Vector2(1920, 1080)
const PANELS_TOP := 452.0  # The transcript and info panels fill the screen below the tent.
const INFO_WIDTH := 520.0

const CUSTOMER_SEAT_X := 785.0
const CUSTOMER_Y := 190.0
# Off-stage spots either side (far enough out that the name tag is hidden too).
const OFFSCREEN_LEFT_X := -200.0
const OFFSCREEN_RIGHT_X := 1400.0

## Test hooks (set by tests before loading the scene; leave alone otherwise).
## pause_scale_override >= 0 replaces the Fast toggle (e.g. 0.01 runs a visit in a blink);
## random_seed != 0 makes every run pick the same moments, customers and orders.
static var pause_scale_override := -1.0
static var random_seed := 0
## Test hook: false stops the night clock, so no customers arrive by themselves and the
## night never ends (tests that only want to click Next customer turn it off).
static var run_clock := true

## Real seconds per game minute. The clock always runs, visits or not, so a night (6pm to
## 3am, 540 game minutes) takes about five minutes; Fast makes it about one.
const REAL_SECONDS_PER_GAME_MINUTE := 0.56

var _ai: Ai
var _owner := {}
var _customer := {}
var _order: Array = []
var _moment := {}
var _transcript: Array = []
var _takings := 0
var _busy := false
var _customer_color := Color.WHITE

# The night
var _night_open := false
var _night_number := 0
var _night_day := ""
var _night_weather := ""
var _clock := float(Rules.OPEN_MINUTES)  # game minutes since midnight at the start of the night
var _next_arrival := 0.0
var _night_visits := 0
var _night_takings := 0
var _night_lines: Array = []  # what customers said tonight, for the summary
var _summary: PanelContainer
var _summary_text: RichTextLabel

# UI
var _button: Button
var _fast_toggle: CheckBox
var _moment_label: Label
var _mode_label: Label
var _takings_label: Label
var _title_label: Label
var _leave_button: Button
var _log: RichTextLabel
var _typing_label: Label
var _info: RichTextLabel

# Scene pieces
var _owner_node: Control
var _owner_tag: Label
var _customer_node: Control
var _customer_body: ColorRect
var _customer_head: ColorRect
var _customer_tag: Label
var _items_row: HBoxContainer


func _ready() -> void:
	if random_seed != 0:
		seed(random_seed)
	_ai = Ai.new()
	add_child(_ai)
	_build_ui()
	_ai.offline_started.connect(_on_offline_started)
	if _ai.offline:
		_show_offline_mode()
	if Game.bar.is_empty():
		_invent_owner()  # A new bar: invent the owner, then name the tent and save it.
	else:
		_open_saved_bar()


## A bar from a save: its owner is back behind the counter, and the takings carry on.
func _open_saved_bar() -> void:
	_owner = Game.bar["owner"].duplicate(true)
	_takings = int(Game.bar.get("takings", 0))
	_takings_label.text = "Takings: %s" % Menu.format_won(_takings)
	_show_bar_name()
	_owner_tag.text = _owner_display()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up %s again for the night." % [_owner_display(), Game.bar["name"]])
	_update_info()
	_button.text = "Next customer"
	_button.disabled = false
	_leave_button.disabled = false
	_start_night()


## Ollama couldn't be reached partway through, so the AI switched to canned replies.
func _on_offline_started(reason: String) -> void:
	_show_offline_mode()
	_narrate("(Couldn't reach the local AI, so the game switched to offline mode: %s.)" % reason)


func _show_offline_mode() -> void:
	_mode_label.text = "OFFLINE MODE"
	_mode_label.tooltip_text = "Characters and lines are pre-written, not from the AI (%s). Change it in ai_settings.cfg." % _ai.offline_reason
	_mode_label.visible = true


func _on_button_pressed() -> void:
	if _busy:
		return
	if _owner.is_empty():
		_invent_owner()
	elif _night_open:
		_run_visit()


# --- The owner -------------------------------------------------------------

func _invent_owner() -> void:
	_busy = true
	_button.disabled = true
	_narrate("Somewhere under a Seoul overpass, someone is unrolling an orange tarp...")
	_typing_label.text = "The AI is inventing the tent's owner..."
	var gender: String = ["woman", "man"].pick_random()
	var result: Dictionary = await _ai.ask_json(Prompts.owner_messages(gender), _validate_owner.bind(gender), {"temperature": 0.9},
		{"purpose": "owner", "gender": gender})
	_typing_label.text = ""
	if result.is_empty():
		_narrate("Couldn't invent the owner: %s" % _ai.last_error)
		_button.text = "Try again"
		_button.disabled = false
		_leave_button.disabled = false
		_busy = false
		return
	_owner = result
	_owner["gender"] = gender
	_owner["title"] = Prompts.OWNER_ADDRESS[gender]["title"]
	_owner_tag.text = _owner_display()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	_narrate("%s opens up for the night." % _owner_display())
	_update_info()
	_button.text = "Next customer"
	_button.disabled = false
	_leave_button.disabled = false
	_busy = false
	_start_night()


## A new bar: the AI names the tent (the game names it if the AI can't), and it's saved.
func _name_bar() -> void:
	_typing_label.text = "The AI is painting the sign..."
	var named: Dictionary = await _ai.ask_json(Prompts.bar_name_messages(_owner), _validate_bar_name, {"temperature": 0.9},
		{"purpose": "bar_name", "owner_name": _owner["name"]})
	_typing_label.text = ""
	if named.is_empty():
		named = Rules.fallback_bar_name(str(_owner["name"]))
	Game.bar = SaveStore.new_bar(str(named["name"]), str(named["meaning"]), _owner)
	Game.bar["first_day"] = randi() % Rules.DAYS.size()
	Game.save()
	_show_bar_name()
	_narrate("The sign over the tarp reads %s (%s)." % [named["name"], named["meaning"]])


func _show_bar_name() -> void:
	_title_label.text = "KTBT  ·  %s" % Game.bar["name"]
	_title_label.tooltip_text = str(Game.bar.get("name_meaning", ""))


func _on_leave_pressed() -> void:
	if not _busy:
		Game.back_to_title()


# --- One visit, start to finish ---------------------------------------------

func _run_visit() -> void:
	_busy = true
	_schedule_next_arrival()  # the next customer's time, counted from this one's arrival
	_button.disabled = true
	_leave_button.disabled = true
	_transcript.clear()
	_order.clear()
	_customer = {}
	_moment = {"day": _night_day, "time": Rules.clock_text(int(_clock)), "weather": _night_weather}
	_update_clock_label()
	_update_info()
	_log.append_text("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	_narrate("%s, %s. %s." % [_moment["day"], _moment["time"], Rules.sentence_case(_moment["weather"])])

	# 1. Who walks in?
	_typing_label.text = "Someone is coming down the street..."
	var customer: Dictionary = await _ai.ask_json(
		Prompts.customer_messages(_moment["day"], _moment["time"], _moment["weather"], false),
		_validate_customer, {"temperature": 0.9}, {"purpose": "customer"})
	_typing_label.text = ""
	if customer.is_empty():
		_narrate("Nobody came in after all. (%s)" % _ai.last_error)
		_finish_visit()
		return
	_customer = customer
	_customer_color = CUSTOMER_COLORS.pick_random()
	_update_info()
	_narrate(Rules.as_sentence(str(_customer["appearance"])))
	await _walk_in()

	# 2. They sit down, say hello and order in one line, so what they say matches
	# what they get. The menu and the bill belong to the game.
	_typing_label.text = "%s is looking at the menu..." % _customer["name"]
	# The game decides who's extra hungry (two mains) or having a rough night (two drinks).
	var hungry := randf() < HUNGRY_CHANCE
	var rough_night := randf() < ROUGH_NIGHT_CHANCE
	var order: Dictionary = await _ai.ask_json(
		Prompts.order_messages(_owner, _customer, _moment, Menu.prompt_list(), _transcript, hungry, rough_night),
		_validate_order.bind(2 if hungry else 1, 2 if rough_night else 1), {"temperature": 0.7},
		{"purpose": "order", "title": _owner["title"], "max_mains": 2 if hungry else 1, "max_drinks": 2 if rough_night else 1})
	_typing_label.text = ""
	if order.is_empty():
		_order = ["soju", "odeng"]
		_narrate("(The AI couldn't come up with a valid order, so the game served soju and odeng: %s.)" % _ai.last_error)
	else:
		_order = order["items"]
		await _say(false, str(order["line"]))
	_update_info()

	# 3. Served automatically.
	await _serve(_order)

	# 4. The conversation: owner and customer take turns; the customer has the last word.
	# The game decides how many times they order more partway through (often none, sometimes
	# once, rarely twice). Each later order adds an exchange, so it doesn't eat into the talk,
	# and the rules space them out (never their first reply or last line).
	var extra_count := Rules.extra_order_count(randf())
	var exchanges := randi_range(3, 5) + extra_count
	var total_lines := exchanges * 2
	var extra_turns := Rules.extra_order_turns(exchanges, extra_count)
	for i in total_lines:
		if extra_turns.has(i):
			var ordered: bool = await _extra_order()
			if ordered:
				continue
		var owner_speaks := i % 2 == 0
		var direction := ""
		if i == 0:
			direction = "They've just set down the order: %s." % Rules.item_names(_order)
		elif i == total_lines - 2:
			direction = "The customer is nearly ready to leave."
		elif i == total_lines - 1:
			direction = "This is the customer's last line: they're paying up and heading back out into the night."
		var speaker := str(_owner["name"]) if owner_speaks else str(_customer["name"])
		var alias := str(_owner["title"]) if owner_speaks else ""
		_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
		var reply: Dictionary = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, _customer, _moment, _table_text(), _transcript, owner_speaks, direction),
			_validate_line.bind(speaker, alias, _order), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": owner_speaks, "first": i == 0, "last": i == total_lines - 1})
		_typing_label.text = ""
		if reply.is_empty():
			_narrate("(The conversation fizzled out: %s.)" % _ai.last_error)
			break
		await _say(owner_speaks, str(reply["line"]))

	# 5. Pay and leave. The game works out the bill, and the bar is saved.
	var bill := Rules.bill(_order)
	SaveStore.record_visit(Game.bar, {
		"customer": _customer["name"], "job": _customer["job"],
		"day": _moment["day"], "time": _moment["time"], "weather": _moment["weather"],
		"order": _order.duplicate(), "bill": bill,
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_takings = int(Game.bar["takings"])
	_takings_label.text = "Takings: %s" % Menu.format_won(_takings)
	_night_visits += 1
	_night_takings += bill
	_narrate("%s pays %s and heads back out into the night." % [_customer["name"], Menu.format_won(bill)])
	await _walk_out()
	_clear_items()
	_finish_visit()


func _finish_visit() -> void:
	_typing_label.text = ""
	_button.disabled = false
	_leave_button.disabled = false
	if _night_open and _next_arrival <= _clock:
		# Someone was due while the stool was taken. If they've waited too long, they've gone.
		if _clock - _next_arrival > Rules.GIVE_UP_MINUTES:
			_narrate("Someone peeked under the tarp a while ago, saw the stool taken, and walked on.")
			_schedule_next_arrival()
	_busy = false


# --- The night -------------------------------------------------------------

## The tent opens at 6pm: a new night number, its day and its weather.
func _start_night() -> void:
	_night_number = int(Game.bar.get("nights", 0)) + 1
	_night_day = Rules.night_day(int(Game.bar.get("first_day", 4)), _night_number)
	_night_weather = WEATHER.pick_random()
	_clock = float(Rules.OPEN_MINUTES)
	_night_visits = 0
	_night_takings = 0
	_night_lines = []
	_night_open = true
	_schedule_next_arrival()
	_update_clock_label()
	_log.append_text("\n[center][color=#%s]· · ·  Night %d  · · ·[/color][/center]\n\n" % [ACCENT.to_html(false), _night_number])
	_narrate("%s, %s. %s. The tarp goes up and the first pots go on." % [_night_day, Rules.clock_text(Rules.OPEN_MINUTES), Rules.sentence_case(_night_weather)])
	_button.disabled = false


func _schedule_next_arrival() -> void:
	_next_arrival = _clock + Rules.next_arrival_gap(int(_clock), randf())


## The clock always runs, in real time, whatever's happening. When a customer is due and the
## stool is free, they arrive (if it's taken, they wait: see _finish_visit). At 3am, once
## nobody's still drinking, the night ends.
func _process(delta: float) -> void:
	if not _night_open:
		return
	if run_clock and _clock < Rules.CLOSE_MINUTES:
		var seconds_per_minute := _scaled(REAL_SECONDS_PER_GAME_MINUTE)
		if seconds_per_minute > 0.0:
			_clock = minf(_clock + delta / seconds_per_minute, float(Rules.CLOSE_MINUTES))
		_update_clock_label()
	if _busy:
		return
	if _clock >= Rules.CLOSE_MINUTES:
		_end_night()
	elif run_clock and _clock >= _next_arrival and _clock < Rules.LAST_ARRIVAL_MINUTES:
		_run_visit()


## 3am: the owner closes up, the night is saved, and a summary appears.
func _end_night() -> void:
	_night_open = false
	_button.disabled = true
	var line := Rules.memorable_line(_night_lines)
	SaveStore.record_night(Game.bar, {
		"night": _night_number, "day": _night_day, "weather": _night_weather,
		"customers": _night_visits, "takings": _night_takings,
		"line": line.duplicate(),
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_narrate("%s. %s pulls down the tarp and counts the takings." % [Rules.clock_text(Rules.CLOSE_MINUTES), _owner_display()])
	_update_clock_label()
	var t := "[center][font_size=34][b]Night %d at %s[/b][/font_size]\n" % [_night_number, _esc(Game.bar["name"])]
	t += "[color=#%s]%s, %s[/color]\n\n" % [MUTED.to_html(false), _night_day, _esc(_night_weather)]
	t += "%d %s  ·  %s tonight\n" % [_night_visits, "customer" if _night_visits == 1 else "customers", Menu.format_won(_night_takings)]
	t += "[color=#%s]%s in total[/color]" % [MUTED.to_html(false), Menu.format_won(_takings)]
	if not line.is_empty():
		t += "\n\n[i][color=#%s]\"%s\"[/color][/i]\n[color=#%s]%s[/color]" % [OWNER_TEXT.to_html(false), _esc(line["text"]), MUTED.to_html(false), _esc(line["speaker"])]
	t += "[/center]"
	_summary_text.text = t
	_summary.visible = true


func _on_next_night_pressed() -> void:
	_summary.visible = false
	_start_night()


func _update_clock_label() -> void:
	if _night_number == 0:
		return
	_moment_label.text = "Night %d  ·  %s  ·  %s  ·  %s" % [_night_number, _night_day, Rules.clock_text(int(_clock)), _night_weather]


# --- Things happening in the scene -----------------------------------------

func _walk_in() -> void:
	_customer_body.color = _customer_color
	_customer_head.color = _customer_color.lightened(0.25)
	_customer_tag.text = str(_customer["name"])
	# They arrive from either end of the street, picked at random.
	_customer_node.position = Vector2(_random_offscreen_x(), CUSTOMER_Y)
	_customer_node.visible = true
	var tween := create_tween()
	tween.tween_property(_customer_node, "position:x", CUSTOMER_SEAT_X, _scaled(1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _walk_out() -> void:
	var tween := create_tween()
	# ...and leave in whichever direction they're heading home, also at random.
	tween.tween_property(_customer_node, "position:x", _random_offscreen_x(), _scaled(1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_customer_node.visible = false


func _random_offscreen_x() -> float:
	return OFFSCREEN_LEFT_X if randi() % 2 == 0 else OFFSCREEN_RIGHT_X


func _serve(items: Array) -> void:
	_typing_label.text = "%s is cooking..." % _owner_display()
	for id in items:
		await get_tree().create_timer(_scaled(0.9)).timeout
		_add_item_visual(Menu.find(id))
	await get_tree().create_timer(_scaled(0.9)).timeout
	_add_item_visual({"name": "Banchan", "color": "8fae6a"})
	_typing_label.text = ""
	_narrate("Served: %s, with the free banchan (%s)." % [Rules.item_names(items), BANCHAN])
	# Record it in the transcript too, so the AI knows the food has arrived.
	_transcript.append({"action": "%s serves: %s, with the free banchan (%s)." % [_owner["name"], Rules.item_names(items), BANCHAN]})


## The customer orders more partway through. Returns false if the AI couldn't manage it,
## in which case the conversation just carries on with a normal line.
func _extra_order() -> bool:
	_typing_label.text = "%s is eyeing the menu again..." % _customer["name"]
	var extra: Dictionary = await _ai.ask_json(
		Prompts.extra_order_messages(_owner, _customer, _moment, Menu.prompt_list(), _transcript, _table_text()),
		_validate_extra_order.bind(_order.duplicate()), {"temperature": 0.7},
		{"purpose": "extra_order", "title": _owner["title"], "table": _order.duplicate()})
	_typing_label.text = ""
	if extra.is_empty():
		return false
	var items: Array = extra["items"]
	await _say(false, str(extra["line"]))
	_typing_label.text = "%s is getting it..." % _owner_display()
	for id in items:
		await get_tree().create_timer(_scaled(0.9)).timeout
		_add_item_visual(Menu.find(id))
	_typing_label.text = ""
	_order.append_array(items)
	_narrate("Served: %s." % Rules.item_names(items))
	_transcript.append({"action": "%s brings: %s." % [_owner["name"], Rules.item_names(items)]})
	_update_info()
	return true


## What's on the table, as the AI is told it.
func _table_text() -> String:
	return "%s, plus free banchan (%s)" % [Rules.item_names(_order), BANCHAN]


func _add_item_visual(item: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = str(item["name"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var dish := ColorRect.new()
	dish.color = Color(str(item["color"]))
	dish.custom_minimum_size = Vector2(34, 22)
	dish.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(dish)
	_items_row.add_child(box)


func _clear_items() -> void:
	for child in _items_row.get_children():
		child.queue_free()


## Shows a line of dialogue, adds it to the transcript, then pauses long enough to read it.
func _say(owner_speaks: bool, text: String) -> void:
	var who := _owner_display() if owner_speaks else str(_customer["name"])
	var colour := OWNER_TEXT if owner_speaks else _customer_color.lightened(0.35)
	_transcript.append({"speaker": str(_owner["name"]) if owner_speaks else who, "text": text})
	if not owner_speaks:
		_night_lines.append({"speaker": who, "text": text})
	_log.append_text("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(text)])
	await _pause_for(text)


func _narrate(text: String) -> void:
	_log.append_text("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(text)])


func _pause_for(text: String) -> void:
	var seconds := clampf(1.0 + text.length() * 0.035, 1.5, 7.0)
	await get_tree().create_timer(_scaled(seconds)).timeout


func _scaled(seconds: float) -> float:
	if pause_scale_override >= 0.0:
		return seconds * pause_scale_override
	return seconds * (0.3 if _fast_toggle.button_pressed else 1.0)


# --- Small helpers -----------------------------------------------------------

func _owner_display() -> String:
	if _owner.is_empty():
		return "The owner"
	return "%s (%s)" % [_owner["name"], _owner["title"]]


## Stop anything the AI writes from being read as BBCode formatting.
func _esc(value: Variant) -> String:
	return str(value).replace("[", "[lb]")


func _update_info() -> void:
	var accent := ACCENT.to_html(false)
	var muted := MUTED.to_html(false)
	var t := ""
	if not _owner.is_empty():
		t += "[color=#%s][b]THE OWNER[/b][/color]\n" % accent
		t += "[b]%s[/b], %s\n" % [_esc(_owner_display()), _owner["age"]]
		t += "%s\n" % _esc(_owner["archetype"])
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(_owner["personality"])]
		t += "[i][color=#%s]Secret: %s[/color][/i]\n" % [muted, _esc(_owner["secret"])]
	if not _customer.is_empty():
		t += "\n[color=#%s][b]CUSTOMER[/b][/color]\n" % accent
		t += "[b]%s[/b], %s, %s\n" % [_esc(_customer["name"]), _customer["age"], _esc(_customer["job"])]
		t += "Mood: %s\n" % _esc(_customer["mood"])
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(_customer["reason"])]
		if not _order.is_empty():
			t += "Ordered: %s (%s)\n" % [_esc(Rules.item_names(_order)), Menu.format_won(Rules.bill(_order))]
	_info.text = t


# --- Checking the AI's replies (the rules live in scripts/rules.gd) -----------

func _validate_owner(data: Variant, gender: String) -> String:
	return Rules.validate_owner(data, gender)


func _validate_bar_name(data: Variant) -> String:
	return Rules.validate_bar_name(data)


func _validate_customer(data: Variant) -> String:
	return Rules.validate_customer(data)


func _validate_order(data: Variant, max_mains: int, max_drinks: int) -> String:
	return Rules.validate_order(data, max_mains, max_drinks)


func _validate_extra_order(data: Variant, table: Array) -> String:
	return Rules.validate_extra_order(data, table)


func _validate_line(data: Variant, speaker: String, alias: String, items: Array) -> String:
	return Rules.validate_line(data, speaker, alias, items)


# --- Building the screen ------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14132a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top bar
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 10)
	bar.size = Vector2(SCREEN.x - 48, 44)
	bar.add_theme_constant_override("separation", 18)
	add_child(bar)

	_title_label = Label.new()
	_title_label.name = "BarName"
	_title_label.text = "KTBT  ·  A new bar"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", ACCENT)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(_title_label)

	# Shown only in offline mode, so canned characters are never mistaken for the AI.
	_mode_label = Label.new()
	_mode_label.name = "ModeLabel"
	_mode_label.add_theme_color_override("font_color", Color.BLACK)
	_mode_label.add_theme_stylebox_override("normal", _badge(OWNER_TEXT))
	_mode_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mode_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_mode_label.visible = false
	bar.add_child(_mode_label)

	_moment_label = Label.new()
	_moment_label.name = "MomentLabel"
	_moment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moment_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_moment_label.clip_text = true
	bar.add_child(_moment_label)

	_takings_label = Label.new()
	_takings_label.name = "TakingsLabel"
	_takings_label.text = "Takings: %s" % Menu.format_won(0)
	_takings_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_takings_label)

	_fast_toggle = CheckBox.new()
	_fast_toggle.name = "FastToggle"
	_fast_toggle.text = "Fast"
	_fast_toggle.button_pressed = true  # On by default while we're testing a lot.
	_fast_toggle.tooltip_text = "Shorter pauses between lines, for testing."
	bar.add_child(_fast_toggle)

	_button = Button.new()
	_button.name = "NextButton"
	_button.text = "Next customer"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.disabled = true
	_button.pressed.connect(_on_button_pressed)
	bar.add_child(_button)

	_leave_button = Button.new()
	_leave_button.name = "LeaveButton"
	_leave_button.text = "Close the bar"
	_leave_button.tooltip_text = "Saves and goes back to the title screen."
	_leave_button.custom_minimum_size = Vector2(150, 40)
	_leave_button.disabled = true
	_leave_button.pressed.connect(_on_leave_pressed)
	bar.add_child(_leave_button)

	# The tent
	var stage := Control.new()
	# The grey-box tent is 1280 wide; centre it, and give the rest of the height to the dialogue.
	stage.position = Vector2((SCREEN.x - 1280) / 2, 60)
	stage.size = Vector2(1280, 380)
	stage.clip_contents = true
	add_child(stage)
	_build_stage(stage)

	# Bottom left: what's being said
	var log_panel := _panel(Vector2(24, PANELS_TOP), Vector2(SCREEN.x - INFO_WIDTH - 72, SCREEN.y - PANELS_TOP - 24))
	add_child(log_panel)
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	_log = RichTextLabel.new()
	_log.name = "Transcript"
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 19)
	_log.add_theme_font_size_override("bold_font_size", 19)
	_log.add_theme_font_size_override("italics_font_size", 18)
	log_box.add_child(_log)
	_typing_label = Label.new()
	_typing_label.name = "Status"
	_typing_label.add_theme_color_override("font_color", MUTED)
	log_box.add_child(_typing_label)

	# Bottom right: who's who
	var info_panel := _panel(Vector2(SCREEN.x - INFO_WIDTH - 24, PANELS_TOP), Vector2(INFO_WIDTH, SCREEN.y - PANELS_TOP - 24))
	add_child(info_panel)
	_info = RichTextLabel.new()
	_info.name = "Info"
	_info.bbcode_enabled = true
	_info.selection_enabled = true
	_info.add_theme_font_size_override("normal_font_size", 17)
	_info.add_theme_font_size_override("bold_font_size", 17)
	_info.add_theme_font_size_override("italics_font_size", 17)
	info_panel.add_child(_info)

	# End-of-night summary, shown over everything at 3am.
	_summary = _panel(Vector2((SCREEN.x - 760) / 2, 180), Vector2(760, 520))
	_summary.name = "NightSummary"
	_summary.visible = false
	add_child(_summary)
	var summary_col := VBoxContainer.new()
	summary_col.add_theme_constant_override("separation", 20)
	_summary.add_child(summary_col)
	_summary_text = RichTextLabel.new()
	_summary_text.name = "SummaryText"
	_summary_text.bbcode_enabled = true
	_summary_text.fit_content = true
	_summary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_text.add_theme_font_size_override("normal_font_size", 22)
	_summary_text.add_theme_font_size_override("bold_font_size", 22)
	_summary_text.add_theme_font_size_override("italics_font_size", 22)
	summary_col.add_child(_summary_text)
	var summary_buttons := HBoxContainer.new()
	summary_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_buttons.add_theme_constant_override("separation", 20)
	summary_col.add_child(summary_buttons)
	var next_night := Button.new()
	next_night.name = "NextNightButton"
	next_night.text = "Open for another night"
	next_night.custom_minimum_size = Vector2(260, 48)
	next_night.pressed.connect(_on_next_night_pressed)
	summary_buttons.add_child(next_night)
	var summary_leave := Button.new()
	summary_leave.name = "SummaryLeaveButton"
	summary_leave.text = "Close the bar"
	summary_leave.custom_minimum_size = Vector2(200, 48)
	summary_leave.pressed.connect(_on_leave_pressed)
	summary_buttons.add_child(summary_leave)


func _badge(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(6)
	box.set_content_margin_all(6)
	return box


func _panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var box := StyleBoxFlat.new()
	box.bg_color = Color("22203a")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Grey-box tent: overpass, glow, bulb, owner, counter, stool, customer, roof.
## Children are drawn in the order they're added, so later things sit in front.
func _build_stage(stage: Control) -> void:
	_rect(stage, Vector2(0, 0), Vector2(1280, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(80, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(1156, 36), Vector2(44, 344), Color("1f1e36"))
	_rect(stage, Vector2(140, 110), Vector2(1000, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_rect(stage, Vector2(0, 372), Vector2(1280, 8), Color("2a2840"))  # wet street

	_rect(stage, Vector2(639, 110), Vector2(2, 36), Color("55536b"))  # bulb wire
	_rect(stage, Vector2(632, 146), Vector2(16, 16), OWNER_TEXT)  # the bulb

	_owner_node = _person(stage, Vector2(560, 150), OWNER_COLOR)
	_owner_node.name = "Owner"
	_owner_tag = _owner_node.get_node("Tag") as Label
	_owner_node.visible = false

	_rect(stage, Vector2(300, 250), Vector2(680, 18), Color("8a5a33"))  # counter top
	_rect(stage, Vector2(320, 268), Vector2(640, 104), Color("5c3820"))  # counter front

	_items_row = HBoxContainer.new()
	_items_row.name = "Counter"
	_items_row.position = Vector2(400, 198)
	_items_row.size = Vector2(370, 52)
	_items_row.alignment = BoxContainer.ALIGNMENT_END
	_items_row.add_theme_constant_override("separation", 8)
	stage.add_child(_items_row)

	_rect(stage, Vector2(790, 340), Vector2(70, 12), Color("9a9ab0"))  # stool
	_rect(stage, Vector2(819, 352), Vector2(12, 20), Color("6e6e86"))

	_customer_node = _person(stage, Vector2(OFFSCREEN_RIGHT_X, CUSTOMER_Y), Color.WHITE)
	_customer_node.name = "Customer"
	_customer_body = _customer_node.get_node("Body") as ColorRect
	_customer_head = _customer_node.get_node("Head") as ColorRect
	_customer_tag = _customer_node.get_node("Tag") as Label
	_customer_node.visible = false

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(120, 40), Vector2(1160, 40), Vector2(1250, 112), Vector2(30, 112)])
	roof.color = ACCENT
	stage.add_child(roof)
	_rect(stage, Vector2(30, 112), Vector2(1220, 10), Color("c8612a"))


func _rect(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A grey-box person: a head, a body and a name tag, grouped so they move together.
func _person(parent: Control, pos: Vector2, colour: Color) -> Control:
	var root := Control.new()
	root.position = pos
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var head := _rect(root, Vector2(17, 0), Vector2(46, 44), colour.lightened(0.25))
	head.name = "Head"
	var body := _rect(root, Vector2(0, 44), Vector2(80, 106), colour)
	body.name = "Body"
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-110, -30)
	tag.size = Vector2(300, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(tag)
	return root
