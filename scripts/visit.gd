extends Control
## A night at the tent.
##
## When the scene starts, the AI invents the tent's owner (or a saved bar's owner comes back
## to work). Then the night runs from 6pm to 3am: customers turn up on their own (or when
## you press "Next customer"), take one of five stools, order, eat, drink, chat with the
## owner, pay and leave. Grey boxes for now; real art comes in a later stage.
##
## There's one owner, who is also the only cook. Drinks and banchan come straight away;
## cooked dishes queue at the stove. The owner talks to one customer at a time, for a line or
## two, then moves to whatever's most urgent: greeting someone new, carrying food over,
## settling a bill, or else whoever's been left alone longest.
##
## The game owns the facts (time, menu, prices, seats, the bill, what's been served);
## the AI owns the flavour (who the people are and what they say).

const Ai = preload("res://scripts/ai.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")
const Rules = preload("res://scripts/rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")

const HUNGRY_CHANCE := 0.15  # How often a customer is hungry enough to order two main dishes.
const ROUGH_NIGHT_CHANCE := 0.2  # How often a customer is having a rough enough night to order two drinks.
## Free side dishes served with every first order, as at a real pojangmacha. Not on the bill.
const BANCHAN := "kimchi and pickled radish"

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

# Screen layout (pixels, at the project's 1920x1080; Godot scales it to the window).
const SCREEN := Vector2(1920, 1080)
const PANELS_TOP := 452.0  # The transcript and info panels fill the screen below the tent.
const INFO_WIDTH := 520.0

# Where things stand in the tent (pixels, inside the stage area, which is nearly full width).
const STAGE_SIZE := Vector2(1872, 380)
const SEAT_X := [470.0, 760.0, 1050.0, 1340.0, 1630.0]  # the middle of each stool
const PERSON_WIDTH := 80.0
const CUSTOMER_Y := 190.0
const OWNER_Y := 150.0
const OWNER_HOME_X := 180.0  # by the stove
const OWNER_BESIDE_X := -165.0  # where the owner stands to see to a stool (just to its left)
# Off-stage spots either side (far enough out that the name tag is hidden too).
const OFFSCREEN_LEFT_X := -200.0
const OFFSCREEN_RIGHT_X := 2072.0
const PEEK_X := 865.0  # where a passer-by stops to look in: the gap between the second and third stools

## Test hooks (set by tests before loading the scene; leave alone otherwise).
## pause_scale_override >= 0 replaces the Fast toggle (e.g. 0.01 runs a visit in a blink);
## random_seed != 0 makes every run pick the same moments, customers and orders.
static var pause_scale_override := -1.0
static var random_seed := 0
## Test hook: false stops the night clock, so no customers arrive by themselves and the
## night never ends (tests that only want to click Next customer turn it off). The stove
## keeps cooking either way.
static var run_clock := true

## Real seconds per game minute. The clock always runs, whatever's happening, so a night
## (6pm to 3am, 540 game minutes) takes about five minutes; Fast makes it about one.
const REAL_SECONDS_PER_GAME_MINUTE := 0.56


## One customer at the counter: who they are, which stool, what they've ordered and what's in
## front of them, and how far their conversation with the owner has got.
class Guest:
	extends RefCounted
	var seat := 0
	var customer := {}
	var color := Color.WHITE
	var arrived := ""  # the time they arrived, as text
	var moment := {}  # day, time (kept up to date) and weather, for the AI
	var order: Array = []  # everything they've ordered: the bill
	var served: Array = []  # what's on their table (the banchan aside)
	var transcript: Array = []  # their conversation with the owner, plus what happened
	var line := 0  # the next line of their conversation (even: the owner's turn)
	var total_lines := 0
	var extra_turns: Array = []  # lines that become later orders instead
	var attended := 0  # when the owner last saw to them (a running count)
	var node: Control
	var drinks_row: HBoxContainer
	var food_row: HBoxContainer

	func done_talking() -> bool:
		return line >= total_lines


var _ai: Ai
var _owner := {}
var _takings := 0

# Who's here and what the owner's doing
var _guests: Array = []  # Guest: whoever's on a stool
var _waiting: Array = []  # when each person waiting for a stool (or to be greeted) turned up
var _kitchen: Array = []  # {"guest", "id", "left"}: the first is on the stove, the rest queue
var _ready_dishes: Array = []  # {"guest", "id"}: cooked, waiting to be carried over
var _owner_working := false  # one thing at a time: the owner is in the middle of something
var _attending: Guest = null  # who the owner saw to last
var _attention := 0
var _last_orders := false
var _leave_requested := false
var _passers_by := 0  # how many have walked past tonight (also names their nodes)
var _stopped := false
## The most recent customer to pay, and everything they ordered.
var _customer := {}
var _order: Array = []

## Something's happening: the owner's working, someone's at the counter, or someone's waiting.
## (Public, as the tests watch it.)
var busy: bool:
	get:
		return _owner_working or not _guests.is_empty() or not _waiting.is_empty()

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
var _stage: Control
var _owner_node: Control
var _owner_tag: Label
var _stove_row: HBoxContainer
var _drinks_rows: Array = []  # one per stool
var _food_rows: Array = []


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
	_start_night()


## Ollama couldn't be reached partway through, so the AI switched to canned replies.
func _on_offline_started(reason: String) -> void:
	_show_offline_mode()
	_narrate("(Couldn't reach the local AI, so the game switched to offline mode: %s.)" % reason)


func _show_offline_mode() -> void:
	_mode_label.text = "OFFLINE MODE"
	_mode_label.tooltip_text = "Characters and lines are pre-written, not from the AI (%s). Change it in ai_settings.cfg." % _ai.offline_reason
	_mode_label.visible = true


## Before the owner exists this is "Try again"; during the night, someone turns up now.
func _on_button_pressed() -> void:
	if _owner.is_empty():
		if not _owner_working:
			_invent_owner()
	elif _night_open and _clock < Rules.CLOSE_MINUTES:
		_waiting.append(_clock)
		_update_info()


# --- The owner -------------------------------------------------------------

func _invent_owner() -> void:
	_owner_working = true
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
		_owner_working = false
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
	_owner_working = false
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


## Close the bar: straight away if the owner's free, otherwise once they've finished what
## they're doing (an AI call can't be stopped halfway).
func _on_leave_pressed() -> void:
	if _stopped:
		return
	if _owner_working:
		_leave_requested = true
		_leave_button.disabled = true
		_typing_label.text = "Closing up as soon as %s is free..." % _owner_display()
		return
	_leave()


func _leave() -> void:
	_stopped = true
	_night_open = false
	Game.back_to_title()


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
	_waiting.clear()
	_last_orders = false
	_attending = null
	_night_open = true
	_next_arrival = _clock + Rules.next_arrival_gap(int(_clock), randf())
	_update_clock_label()
	_log.append_text("\n[center][color=#%s]· · ·  Night %d  · · ·[/color][/center]\n\n" % [ACCENT.to_html(false), _night_number])
	_narrate("%s, %s. %s. The tarp goes up and the first pots go on." % [_night_day, Rules.clock_text(Rules.OPEN_MINUTES), Rules.sentence_case(_night_weather)])
	_button.disabled = false
	_leave_button.disabled = false


## Every frame: the clock and the stove move on, people turn up (or give up waiting), and if
## the owner's free, they get on with whatever's most urgent. At 3am the owner calls last
## orders; the night ends once the last customer has gone.
func _process(delta: float) -> void:
	if not _night_open or _stopped:
		return
	var seconds_per_minute := _scaled(REAL_SECONDS_PER_GAME_MINUTE)
	var minutes := delta / seconds_per_minute if seconds_per_minute > 0.0 else 60.0
	_cook(minutes)
	if run_clock:
		# After 3am the clock runs on while the last customers finish up.
		_clock += minutes
		_update_clock_label()
		while _clock >= _next_arrival and _next_arrival < Rules.LAST_ARRIVAL_MINUTES:
			_waiting.append(_next_arrival)
			_next_arrival += Rules.next_arrival_gap(int(_next_arrival), randf())
	_give_up_waiting()
	if _clock >= Rules.CLOSE_MINUTES and not _last_orders:
		_call_last_orders()
	if _owner_working:
		return
	if _leave_requested:
		_leave()
	elif _clock >= Rules.CLOSE_MINUTES and _guests.is_empty():
		_end_night()
	else:
		_next_task()


## Someone who's waited too long with every stool taken gives up and walks on.
func _give_up_waiting() -> void:
	var gone := 0
	while not _waiting.is_empty() and _free_seats().is_empty() and _clock - float(_waiting[0]) > Rules.GIVE_UP_MINUTES:
		_waiting.pop_front()
		_narrate("Someone peeks under the tarp, sees every stool taken, and walks on.")
		_walk_past(gone * 1.5)  # if several give up at once, they don't walk in a clump
		gone += 1
		_update_info()


## A passer-by in the street: they slow down at the tent, look in, and carry on. Runs by
## itself; the owner doesn't stop for it.
func _walk_past(delay: float) -> void:
	_passers_by += 1
	var from_left := randi() % 2 == 0
	var person := _person(_stage, Vector2(OFFSCREEN_LEFT_X if from_left else OFFSCREEN_RIGHT_X, CUSTOMER_Y), CUSTOMER_COLORS.pick_random().darkened(0.35))
	person.name = "PasserBy%d" % _passers_by
	var tween := create_tween()
	tween.tween_interval(_scaled(delay))
	tween.tween_property(person, "position:x", PEEK_X, _scaled(2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(_scaled(0.9))  # a look at the full stools...
	tween.tween_property(person, "position:x", OFFSCREEN_RIGHT_X if from_left else OFFSCREEN_LEFT_X, _scaled(2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(person.queue_free)


## 3am: nobody new, no more orders, and every conversation wraps up.
func _call_last_orders() -> void:
	_last_orders = true
	_waiting.clear()
	if _guests.is_empty():
		return
	_narrate("%s. %s calls last orders and starts stacking the spare stools." % [Rules.clock_text(int(_clock)), _owner_display()])
	for guest in _guests:
		guest.total_lines = Rules.last_orders_total(guest.line, guest.total_lines)
		guest.transcript.append({"action": "It's 3am: %s calls last orders and starts stacking the spare stools." % _owner["name"]})
	_update_info()


## The night's over: the owner closes up, the night is saved, and a summary appears.
func _end_night() -> void:
	_night_open = false
	_button.disabled = true
	_move_owner(OWNER_HOME_X)
	var line := Rules.memorable_line(_night_lines)
	SaveStore.record_night(Game.bar, {
		"night": _night_number, "day": _night_day, "weather": _night_weather,
		"customers": _night_visits, "takings": _night_takings,
		"line": line.duplicate(),
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_narrate("%s. %s pulls down the tarp and counts the takings." % [Rules.clock_text(int(_clock)), _owner_display()])
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


# --- What the owner does next ------------------------------------------------

## The owner's priorities, most urgent first: greet someone new; carry over food that's
## ready; settle up with someone who's finished; otherwise chat with whoever's been left
## alone longest. Each starts a task that runs (with awaits) until it's done.
func _next_task() -> void:
	if _can_greet():
		_greet()
		return
	if not _ready_dishes.is_empty():
		_carry_dish()
		return
	var payer := _ready_to_pay()
	if payer != null:
		_settle_up(payer)
		return
	var lonely := _left_alone_longest()
	if lonely != null:
		_talk(lonely)


## Something more urgent than chatting needs the owner.
func _urgent() -> bool:
	return _can_greet() or not _ready_dishes.is_empty() or _ready_to_pay() != null


func _can_greet() -> bool:
	return not _waiting.is_empty() and not _free_seats().is_empty() and not _last_orders


func _free_seats() -> Array:
	var free := range(Rules.SEATS)
	for guest in _guests:
		free.erase(guest.seat)
	return free


## Someone who's finished talking and isn't waiting for any food.
func _ready_to_pay() -> Guest:
	for guest in _guests:
		if guest.done_talking() and _food_coming(guest).is_empty():
			return guest
	return null


func _left_alone_longest() -> Guest:
	var best: Guest = null
	for guest in _guests:
		if not guest.done_talking() and (best == null or guest.attended < best.attended):
			best = guest
	return best


## A guest's dishes that are on the stove, queued, or ready to carry over.
func _food_coming(guest: Guest) -> Array:
	var ids: Array = []
	for dish in _kitchen + _ready_dishes:
		if dish["guest"] == guest:
			ids.append(dish["id"])
	return ids


func _task_done() -> void:
	_typing_label.text = ""
	_owner_working = false
	_update_info()


## The owner goes over to a guest. If they've come from someone else, the transcript says
## so (and, for a conversation already going, the guest's AI context does too).
func _attend(guest: Guest, say_so: bool) -> void:
	if say_so and _attending != null and _attending != guest:
		if guest.line > 0:
			_narrate("%s turns back to %s." % [_owner_display(), guest.customer["name"]])
			guest.transcript.append({"action": "%s comes back over after seeing to other customers." % _owner["name"]})
		else:
			_narrate("%s turns to %s." % [_owner_display(), guest.customer["name"]])
	_attending = guest
	_attention += 1
	guest.attended = _attention
	_move_owner(SEAT_X[guest.seat] - PERSON_WIDTH / 2 + OWNER_BESIDE_X)


# --- Tasks: greeting, carrying food, settling up, chatting --------------------

## Someone new sits down: the AI invents them, they order, drinks and banchan come straight
## away, cooked dishes go on the stove, and they exchange a first word with the owner.
func _greet() -> void:
	_owner_working = true
	_waiting.pop_front()
	var guest := Guest.new()
	guest.seat = _free_seats().pick_random()
	guest.arrived = Rules.clock_text(int(_clock))
	guest.moment = {"day": _night_day, "time": guest.arrived, "weather": _night_weather}
	_log.append_text("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	_narrate("%s. Someone ducks under the tarp." % guest.arrived)

	# 1. Who is it?
	_typing_label.text = "Someone is coming down the street..."
	var customer: Dictionary = await _ai.ask_json(
		Prompts.customer_messages(_night_day, guest.arrived, _night_weather, false),
		_validate_customer, {"temperature": 0.9}, {"purpose": "customer"})
	_typing_label.text = ""
	if customer.is_empty():
		_narrate("Nobody came in after all. (%s)" % _ai.last_error)
		_task_done()
		return
	guest.customer = customer
	guest.color = _free_color()
	guest.drinks_row = _drinks_rows[guest.seat]
	guest.food_row = _food_rows[guest.seat]
	guest.node = _person(_stage, Vector2(_random_offscreen_x(), CUSTOMER_Y), guest.color)
	guest.node.name = "Customer%d" % guest.seat
	(guest.node.get_node("Tag") as Label).text = str(customer["name"])
	_guests.append(guest)
	_update_info()
	_narrate(Rules.as_sentence(str(customer["appearance"])))
	_attend(guest, false)
	await _walk_in(guest)

	# 2. They say hello and order in one line, so what they say matches what they get.
	# The game decides who's extra hungry (two mains) or having a rough night (two drinks).
	_typing_label.text = "%s is looking at the menu..." % customer["name"]
	var hungry := randf() < HUNGRY_CHANCE
	var rough_night := randf() < ROUGH_NIGHT_CHANCE
	var order: Dictionary = await _ai.ask_json(
		Prompts.order_messages(_owner, customer, guest.moment, Menu.prompt_list(), guest.transcript, hungry, rough_night),
		_validate_order.bind(2 if hungry else 1, 2 if rough_night else 1), {"temperature": 0.7},
		{"purpose": "order", "title": _owner["title"], "max_mains": 2 if hungry else 1, "max_drinks": 2 if rough_night else 1})
	_typing_label.text = ""
	var items: Array = ["soju", "odeng"]
	if order.is_empty():
		_narrate("(The AI couldn't come up with a valid order, so the game served soju and odeng: %s.)" % _ai.last_error)
	else:
		items = order["items"]
		await _say(guest, false, str(order["line"]))
	guest.order = items.duplicate()
	await _serve(guest, items, true)

	# 3. How their conversation will go. The game decides how many times they order more
	# partway through (often none, sometimes once, rarely twice). Each later order adds an
	# exchange, so it doesn't eat into the talk, and the rules space them out.
	var extra_count := Rules.extra_order_count(randf())
	var exchanges := randi_range(3, 5) + extra_count
	guest.total_lines = exchanges * 2
	guest.extra_turns = Rules.extra_order_turns(exchanges, extra_count)
	if _last_orders:  # 3am struck while they were sitting down
		guest.total_lines = Rules.last_orders_total(guest.line, guest.total_lines)
	await _converse(guest, 1, false)
	_task_done()


## Drinks (and anything else that needs no cooking) go on the table now, with the free
## banchan for a first order; cooked dishes join the queue at the stove.
func _serve(guest: Guest, items: Array, first_order: bool) -> void:
	var now := Rules.instant_items(items)
	var later := Rules.cooked_items(items)
	_typing_label.text = "%s is pouring..." % _owner_display()
	for id in now:
		await get_tree().create_timer(_scaled(0.6)).timeout
		_add_dish(guest, id)
		guest.served.append(id)
	if first_order:
		await get_tree().create_timer(_scaled(0.6)).timeout
		guest.drinks_row.add_child(_banchan_shape())
	for id in later:
		_kitchen.append({"guest": guest, "id": id, "left": float(Menu.cook_minutes(id))})
	_typing_label.text = ""
	_update_stove()
	var said := ""
	var done := ""
	if first_order:
		said = "Served: %s, with the free banchan (%s)." % [Rules.item_names(now), BANCHAN]
		done = "%s serves: %s, with the free banchan (%s)." % [_owner["name"], Rules.item_names(now), BANCHAN]
	elif not now.is_empty():
		said = "Served: %s." % Rules.item_names(now)
		done = "%s brings: %s." % [_owner["name"], Rules.item_names(now)]
	if not later.is_empty():
		said += " On the stove: %s." % Rules.item_names(later)
		done += " %s puts %s on the stove; it isn't ready yet." % [_owner["name"], Rules.item_names(later)]
	_narrate(said.strip_edges())
	# Record it in their transcript too, so the AI knows what's arrived and what hasn't.
	guest.transcript.append({"action": done.strip_edges()})
	_update_info()


## A dish is ready: the owner carries it over to whoever ordered it.
func _carry_dish() -> void:
	_owner_working = true
	var dish: Dictionary = _ready_dishes.pop_front()
	var guest: Guest = dish["guest"]
	var id := str(dish["id"])
	_update_stove()
	if not _guests.has(guest):
		_task_done()
		return
	_attend(guest, false)
	_typing_label.text = "%s is carrying it over..." % _owner_display()
	await get_tree().create_timer(_scaled(0.6)).timeout
	_add_dish(guest, id)
	guest.served.append(id)
	var item_name := str(Menu.find(id)["name"])
	_narrate("%s brings the %s over to %s." % [_owner_display(), item_name, guest.customer["name"]])
	guest.transcript.append({"action": "%s brings over the %s, hot from the stove. It's on the table now." % [_owner["name"], item_name]})
	_task_done()


## Someone's finished: the game works out the bill, the bar is saved, and they leave.
func _settle_up(guest: Guest) -> void:
	_owner_working = true
	_attend(guest, false)
	var bill := Rules.bill(guest.order)
	SaveStore.record_visit(Game.bar, {
		"customer": guest.customer["name"], "job": guest.customer["job"],
		"day": guest.moment["day"], "time": guest.arrived, "weather": guest.moment["weather"],
		"order": guest.order.duplicate(), "bill": bill,
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_takings = int(Game.bar["takings"])
	_takings_label.text = "Takings: %s" % Menu.format_won(_takings)
	_night_visits += 1
	_night_takings += bill
	_customer = guest.customer
	_order = guest.order.duplicate()
	_narrate("%s pays %s and heads back out into the night." % [guest.customer["name"], Menu.format_won(bill)])
	await _walk_out(guest)
	_clear_table(guest)
	guest.node.queue_free()
	_guests.erase(guest)
	if _attending == guest:
		_attending = null
	_task_done()


## A spell of conversation with one guest: an exchange or two, cut short if something more
## urgent comes up (but never between the owner's line and the customer's reply).
func _talk(guest: Guest) -> void:
	_owner_working = true
	_attend(guest, true)
	await _converse(guest, randi_range(1, 2), true)
	_task_done()


func _converse(guest: Guest, exchanges: int, interruptible: bool) -> void:
	while not guest.done_talking() and not _leave_requested:
		await _next_line(guest)
		if guest.line % 2 == 0:  # an exchange finished: the customer has just replied
			exchanges -= 1
			if exchanges <= 0 or (interruptible and _urgent()):
				return


## The next line of a guest's conversation (or a later order, when it's their turn for one).
## The customer has the last word.
func _next_line(guest: Guest) -> void:
	var i := guest.line
	guest.moment["time"] = Rules.clock_text(int(_clock))
	if guest.extra_turns.has(i) and not _last_orders:
		var ordered: bool = await _extra_order(guest)
		if ordered:
			guest.line += 1
			return
	var owner_speaks := i % 2 == 0
	var direction := ""
	if i == 0:
		direction = "They've just been served: what's ready is on the table, and anything else is still cooking."
	elif i == guest.total_lines - 2:
		direction = "The customer is nearly ready to leave."
	elif i == guest.total_lines - 1:
		direction = "This is the customer's last line: they're paying up and heading back out into the night."
	var speaker := str(_owner["name"]) if owner_speaks else str(guest.customer["name"])
	var alias := str(_owner["title"]) if owner_speaks else ""
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply: Dictionary = await _ai.ask_json(
		Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, owner_speaks, direction),
		_validate_line.bind(speaker, alias, guest.order), {"temperature": 0.85},
		{"purpose": "line", "title": _owner["title"], "owner_speaks": owner_speaks, "first": i == 0, "last": i == guest.total_lines - 1})
	_typing_label.text = ""
	if reply.is_empty():
		_narrate("(The conversation with %s fizzled out: %s.)" % [guest.customer["name"], _ai.last_error])
		guest.line = guest.total_lines
		return
	await _say(guest, owner_speaks, str(reply["line"]))
	guest.line += 1


## The customer orders more partway through. Returns false if the AI couldn't manage it,
## in which case the conversation just carries on with a normal line.
func _extra_order(guest: Guest) -> bool:
	_typing_label.text = "%s is eyeing the menu again..." % guest.customer["name"]
	var extra: Dictionary = await _ai.ask_json(
		Prompts.extra_order_messages(_owner, guest.customer, guest.moment, Menu.prompt_list(), guest.transcript, _table_text(guest)),
		_validate_extra_order.bind(guest.order.duplicate()), {"temperature": 0.7},
		{"purpose": "extra_order", "title": _owner["title"], "table": guest.order.duplicate()})
	_typing_label.text = ""
	if extra.is_empty():
		return false
	var items: Array = extra["items"]
	await _say(guest, false, str(extra["line"]))
	guest.order.append_array(items)
	await _serve(guest, items, false)
	return true


## What's on a guest's table, as the AI is told it, including what's still cooking.
func _table_text(guest: Guest) -> String:
	return Rules.table_text(guest.served, _food_coming(guest), BANCHAN)


# --- The stove ---------------------------------------------------------------

## One cook: the first dish in the queue cooks; when it's done it waits to be carried over
## and the next one goes on.
func _cook(minutes: float) -> void:
	if _kitchen.is_empty():
		return
	var changed := false
	_kitchen[0]["left"] -= minutes
	while not _kitchen.is_empty() and float(_kitchen[0]["left"]) <= 0.0:
		var spare := -float(_kitchen[0]["left"])
		var done: Dictionary = _kitchen.pop_front()
		_ready_dishes.append({"guest": done["guest"], "id": done["id"]})
		if not _kitchen.is_empty():
			_kitchen[0]["left"] -= spare
		changed = true
	if changed:
		_update_stove()
		_update_info()


func _update_stove() -> void:
	for child in _stove_row.get_children():
		_stove_row.remove_child(child)
		child.queue_free()
	for dish in _ready_dishes:
		var shape := _dish_shape(str(dish["id"]))
		shape.tooltip_text += " for %s (ready)" % dish["guest"].customer["name"]
		_stove_row.add_child(shape)
	for i in _kitchen.size():
		var dish: Dictionary = _kitchen[i]
		var shape := _dish_shape(str(dish["id"]))
		shape.tooltip_text += " for %s (%s)" % [dish["guest"].customer["name"], "cooking" if i == 0 else "waiting"]
		if i > 0:
			shape.modulate = Color(1, 1, 1, 0.5)
		_stove_row.add_child(shape)


# --- Things happening in the scene -----------------------------------------

func _walk_in(guest: Guest) -> void:
	var tween := create_tween()
	tween.tween_property(guest.node, "position:x", SEAT_X[guest.seat] - PERSON_WIDTH / 2, _scaled(1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _walk_out(guest: Guest) -> void:
	var tween := create_tween()
	# ...and leave in whichever direction they're heading home, at random.
	tween.tween_property(guest.node, "position:x", _random_offscreen_x(), _scaled(1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


func _move_owner(x: float) -> void:
	var tween := create_tween()
	tween.tween_property(_owner_node, "position:x", x, _scaled(0.4)).set_trans(Tween.TRANS_SINE)


func _random_offscreen_x() -> float:
	return OFFSCREEN_LEFT_X if randi() % 2 == 0 else OFFSCREEN_RIGHT_X


## A colour nobody at the counter is wearing.
func _free_color() -> Color:
	var free := CUSTOMER_COLORS.duplicate()
	for guest in _guests:
		free.erase(guest.color)
	return free.pick_random() if not free.is_empty() else CUSTOMER_COLORS.pick_random()


## Drinks go to the left of the customer, food to the right.
func _add_dish(guest: Guest, id: String) -> void:
	var row := guest.drinks_row if Menu.find(id)["kind"] == "drink" else guest.food_row
	row.add_child(_dish_shape(id))


func _clear_table(guest: Guest) -> void:
	for row in [guest.drinks_row, guest.food_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()


## How many things are on all the tables (for tests).
func _table_item_count() -> int:
	var count := 0
	for row in _drinks_rows + _food_rows:
		count += row.get_child_count()
	return count


## A small unlabelled shape for a menu item (a bottle for a drink, a bowl for food), with
## its name on hover.
func _dish_shape(id: String) -> Control:
	var item := Menu.find(id)
	var colour := Color(str(item["color"]))
	var shape := Control.new()
	shape.tooltip_text = str(item["name"])
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	if item["kind"] == "drink":
		shape.custom_minimum_size = Vector2(14, 34)
		_rect(shape, Vector2(4, 0), Vector2(6, 9), colour.darkened(0.25))  # the neck
		_rect(shape, Vector2(0, 9), Vector2(14, 25), colour)  # the bottle
	else:
		shape.custom_minimum_size = Vector2(30, 34)
		_rect(shape, Vector2(3, 17), Vector2(24, 11), colour)  # the food
		_rect(shape, Vector2(0, 26), Vector2(30, 8), Color("d9d6e8"))  # the bowl
	return shape


## The free banchan: three little dishes.
func _banchan_shape() -> Control:
	var shape := Control.new()
	shape.tooltip_text = "Banchan: %s (free)" % BANCHAN
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	shape.custom_minimum_size = Vector2(26, 34)
	for i in 3:
		_rect(shape, Vector2(i * 9, 25), Vector2(8, 9), Color("c8452f") if i != 1 else Color("efe9cf"))
	return shape


## Shows a line of dialogue, adds it to the guest's transcript, then pauses long enough to
## read it. With more than one customer in, the owner's lines say who they're talking to.
func _say(guest: Guest, owner_speaks: bool, text: String) -> void:
	var who := _owner_display() if owner_speaks else str(guest.customer["name"])
	if owner_speaks and _guests.size() > 1:
		who += " to %s" % guest.customer["name"]
	var colour := OWNER_TEXT if owner_speaks else guest.color.lightened(0.35)
	guest.transcript.append({"speaker": str(_owner["name"]) if owner_speaks else str(guest.customer["name"]), "text": text})
	if not owner_speaks:
		_night_lines.append({"speaker": str(guest.customer["name"]), "text": text})
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


## The info panel: the owner, then everyone at the counter and what's on their table.
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
	var seated := _guests.duplicate()
	seated.sort_custom(func(a, b): return a.seat < b.seat)
	if not seated.is_empty():
		t += "\n[color=#%s][b]AT THE COUNTER[/b][/color]\n" % accent
	for guest in seated:
		var c: Dictionary = guest.customer
		t += "[color=#%s][b]%s[/b][/color], %s, %s  [color=#%s](stool %d)[/color]\n" % [guest.color.lightened(0.35).to_html(false), _esc(c["name"]), c["age"], _esc(c["job"]), muted, guest.seat + 1]
		t += "[color=#%s]%s · %s[/color]\n" % [muted, _esc(c["mood"]), _esc(c["reason"])]
		if not guest.order.is_empty():
			t += "Table: %s" % _esc(Rules.item_names(guest.served) if not guest.served.is_empty() else "banchan")
			var coming := _food_coming(guest)
			if not coming.is_empty():
				t += "  ·  [color=#%s]cooking: %s[/color]" % [accent, _esc(Rules.item_names(coming))]
			t += "  ·  %s\n" % Menu.format_won(Rules.bill(guest.order))
	var queueing := _waiting.size() - _free_seats().size()
	if queueing > 0:
		t += "\n[color=#%s]Waiting for a stool: %d[/color]\n" % [muted, queueing]
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

	# The tent: nearly the full width, with five stools.
	_stage = Control.new()
	_stage.name = "Tent"
	_stage.position = Vector2((SCREEN.x - STAGE_SIZE.x) / 2, 60)
	_stage.size = STAGE_SIZE
	_stage.clip_contents = true
	add_child(_stage)
	_build_stage(_stage)

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


## Grey-box tent: overpass, glow, bulbs, owner, stove, counter, stools and roof.
## Children are drawn in the order they're added, so later things sit in front (customers
## are added as they arrive, so they stand in front of the counter).
func _build_stage(stage: Control) -> void:
	var w := STAGE_SIZE.x
	_rect(stage, Vector2(0, 0), Vector2(w, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(40, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(w - 84, 36), Vector2(44, 344), Color("1f1e36"))
	_rect(stage, Vector2(110, 110), Vector2(w - 220, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_rect(stage, Vector2(0, 372), Vector2(w, 8), Color("2a2840"))  # wet street

	for bulb_x in [620.0, 1250.0]:
		_rect(stage, Vector2(bulb_x - 1, 110), Vector2(2, 36), Color("55536b"))  # bulb wire
		_rect(stage, Vector2(bulb_x - 8, 146), Vector2(16, 16), OWNER_TEXT)  # the bulb

	_owner_node = _person(stage, Vector2(OWNER_HOME_X, OWNER_Y), OWNER_COLOR)
	_owner_node.name = "Owner"
	_owner_tag = _owner_node.get_node("Tag") as Label
	_owner_node.visible = false

	_rect(stage, Vector2(100, 250), Vector2(w - 182, 18), Color("8a5a33"))  # counter top
	_rect(stage, Vector2(120, 268), Vector2(w - 222, 104), Color("5c3820"))  # counter front
	_rect(stage, Vector2(104, 244), Vector2(236, 6), Color("3a3946"))  # the stove
	_rect(stage, Vector2(130, 241), Vector2(40, 3), Color("e8833a"))  # a flame

	# What's cooking (and what's ready to carry over), at the stove.
	_stove_row = HBoxContainer.new()
	_stove_row.name = "Stove"
	_stove_row.position = Vector2(110, 207)
	_stove_row.size = Vector2(226, 34)
	_stove_row.add_theme_constant_override("separation", 4)
	_stove_row.clip_contents = true
	stage.add_child(_stove_row)

	# Each stool's place at the counter: drinks and banchan to the customer's left, food to the right.
	for seat in Rules.SEATS:
		var x: float = SEAT_X[seat]
		var drinks := HBoxContainer.new()
		drinks.name = "Drinks%d" % seat
		drinks.position = Vector2(x - 150, 216)
		drinks.size = Vector2(104, 34)
		drinks.alignment = BoxContainer.ALIGNMENT_END
		drinks.add_theme_constant_override("separation", 4)
		drinks.clip_contents = true
		stage.add_child(drinks)
		_drinks_rows.append(drinks)
		var food := HBoxContainer.new()
		food.name = "Food%d" % seat
		food.position = Vector2(x + 46, 216)
		food.size = Vector2(104, 34)
		food.add_theme_constant_override("separation", 4)
		food.clip_contents = true
		stage.add_child(food)
		_food_rows.append(food)
		_rect(stage, Vector2(x - 35, 340), Vector2(70, 12), Color("9a9ab0"))  # stool
		_rect(stage, Vector2(x - 6, 352), Vector2(12, 20), Color("6e6e86"))

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])
	roof.color = ACCENT
	stage.add_child(roof)
	_rect(stage, Vector2(22, 112), Vector2(w - 44, 10), Color("c8612a"))


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
