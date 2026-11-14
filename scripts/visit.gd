extends Control
## A night at the tent.
##
## When the scene starts, the AI invents the tent's owner (or a saved bar's owner comes back
## to work). Then the night runs from 6pm to 3am: customers turn up on their own, take one
## of five stools, order, eat, drink, chat with the
## owner, pay and leave. Grey boxes for now; real art comes in a later stage.
##
## There's one owner, who is also the only cook. Drinks and banchan come straight away;
## cooked dishes queue at the stove, and the owner carries each over as soon as it's ready,
## even mid-conversation (their hands are free while the AI thinks of what to say next).
## The owner talks to one customer at a time, for a line or
## two, then moves to whatever's most urgent: greeting someone new, carrying food over,
## settling a bill, or else whoever's been left alone longest. Now and then, instead,
## customers chat to each other (and sometimes the owner or another customer joins in).
## Everyone stays a while (a game fact), then says goodbye and pays. And the tent has a cat,
## which goes where it likes (the game decides), and everyone talks about it as it really is.
##
## The game owns the facts (time, menu, prices, seats, the bill, what's been served);
## the AI owns the flavour (who the people are and what they say).

const Ai = preload("res://scripts/ai.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")
const Rules = preload("res://scripts/rules.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")

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
const STATS_WIDTH := 460.0  # the debug stats panel, between the transcript and the info panel

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
## pause_scale_override >= 0 scales every pause and the clock (e.g. 0.01 runs a visit in a blink);
## random_seed != 0 makes every run pick the same moments, customers and orders.
static var pause_scale_override := -1.0
static var random_seed := 0
## Test hook: false stops the night clock, so no customers arrive by themselves and the
## night never ends (tests that only want to click Next customer turn it off). The stove
## keeps cooking either way.
static var run_clock := true
## Test hooks for customers: stay_minutes_override >= 0 gives everyone that stay;
## company_override ("chatty", "quiet" or "owner") gives everyone that mood for company;
## chat_chance_override >= 0 replaces CHAT_CHANCE and BUSY_CHAT_CHANCE.
static var stay_minutes_override := -1
static var company_override := ""
static var chat_chance_override := -1.0
## Test hook: a gender for every new customer instead of the game's roll ("non-binary").
static var gender_override := ""
## Test hook: false keeps the cat where it is (tests move it with _move_cat).
static var cat_wanders := true
## Where night transcripts go (see _start_transcript). "" means the default: logs/transcripts/
## in the project folder when running from the editor, or the user data folder otherwise.
## Tests point it at their own folder.
static var transcript_folder := ""

## When the owner's free and nothing's urgent: how often customers chat to each other
## instead of the owner chatting to someone. Mostly it's customer and owner.
const CHAT_CHANCE := 0.4
## ...and when it's busy (Rules.BUSY_COUNTER or more in), when there are most people to talk to.
const BUSY_CHAT_CHANCE := 0.6
const JOIN_CHANCE := 0.25  # how often another customer joins an ongoing chat
const OWNER_JOINS_CHANCE := 0.2  # how often the owner joins a customer chat
const CHAT_LINES := Vector2i(3, 5)  # lines in a spell of customer chat
const CHAT_MIN_STAY_LEFT := 10.0  # game minutes
const CHAT_LINES_BEFORE_INTERRUPTING := 3  # a chat gets this many lines before anything can cut in
const COMPANY_LABEL := {"chatty": "chatty", "quiet": "keeps to themselves", "owner": "here to talk"}

## Real seconds per game minute at normal speed. The clock always runs, whatever's
## happening; at normal speed a night (6pm to 3am, 540 game minutes) would take about five
## minutes, but time runs faster when the tent's quiet (Rules.TIME_SPEEDS), so it's less.
const REAL_SECONDS_PER_GAME_MINUTE := 0.56
## How quickly the speed changes when people come and go (speed per real second), so it
## eases rather than jumps.
const SPEED_CHANGE_RATE := 4.0


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
	var line := 0  # the next line of their conversation with the owner (even: the owner's turn)
	var extra_turns: Array = []  # lines that become later orders instead
	var attended := 0  # when the owner last saw to them (a running count)
	var company := "chatty"  # their mood for company (see Rules.company)
	var topic := ""  # what their chat with the owner is turning to (see Rules.pick_owner_topic)
	var food_news := false  # something's been served since the last topic was picked
	## Bumped whenever something they can see changes (a dish arrives, the cat comes or goes),
	## so a line the AI wrote before it happened can be asked for again.
	var version := 0
	var quick_greeting := false  # greeted in a rush: the owner's first proper word comes later
	var stay_left := 0.0  # game minutes until they want to go
	var node: Control
	var walk: Tween  # walking in or out
	var drinks_row: HBoxContainer
	var food_row: HBoxContainer

	func time_up() -> bool:
		return stay_left <= 0.0


## Customers chatting to each other at the counter (the owner sometimes joins in).
class Chat:
	extends RefCounted
	var people: Array = []  # Guest
	var owner_in := false
	var transcript: Array = []  # what's been said in this chat, and what happened
	var last_speaker := ""  # a name
	var topic := ""  # what it's turning to this spell (see Rules.pick_chat_topic)


var _ai: Ai
var _owner := {}
var _takings := 0

# Who's here and what the owner's doing
var _guests: Array = []  # Guest: whoever's on a stool
var _chats: Array = []  # Chat: customer conversations going on at the counter
var _names_tonight: Array = []
var _jobs_tonight: Array = []  # tonight's customers' jobs and looks, so newcomers are different
var _looks_tonight: Array = []
const VARIETY_LOOKS := 5  # how many recent looks the AI is shown
# The cat: who it is (saved with the bar) and where it is now.
var _cat := {}  # name, coat, personality
var _cat_spot := "stove"
var _cat_with: Guest = null  # the customer it's on, at the feet of, or begging from
var _cat_next := 0.0  # game minutes until it moves on
var _cat_node: Control
var _cat_tween: Tween
const CAT_MOVE_MINUTES := Vector2(25, 60)  # how long the cat stays put
## How often a move that's just the cat pottering about (not with a customer, not in or out
## of the tent) is narrated, so the transcript isn't a log of the cat's every step.
const CAT_POTTER_NARRATED := 0.35  # every customer's name so far tonight (the AI is asked to avoid them)
var _waiting: Array = []  # when each person waiting for a stool (or to be greeted) turned up
var _kitchen: Array = []  # {"guest", "id", "left"}: the first is on the stove, the rest queue
var _ready_dishes: Array = []  # {"guest", "id"}: cooked, waiting to be carried over
## The owner's voice: one AI call at a time, so one conversation task at a time.
var _owner_working := false
var _greeting := false  # the owner's greeting someone who isn't on their stool yet
## The owner's hands: carrying a dish over, which happens whatever the voice is doing.
var _carrying := false
var _owner_tween: Tween
var _attending: Guest = null  # who the owner saw to last
var _attention := 0
var _last_orders := false
var _leave_requested := false
var _passers_by := 0  # how many have walked past tonight (also names their nodes)
## When the last line shown will have been read (Time.get_ticks_msec()). The AI works on the
## next line while you read; it's shown once you've had time to read this one.
var _read_until := 0
## Tonight's debug stats (see night_stats.gd), shown in the stats panel and logged at the end.
var _stats := NightStats.new()
var _stats_refresh := 0.0
## Tonight's transcript file, written line by line as the night goes (see _start_transcript).
var _transcript_file: FileAccess
var _tags := RegEx.create_from_string("\\[[^\\]]*\\]")  # BBCode tags, stripped for the file
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
var _try_again: Button  # only shown if the owner couldn't be invented
var _leave_button: Button
var _time_speed := Rules.time_speed(0)  # how fast game time is running now (eases to the target)
var _reading_toggle: CheckBox
var _stats_toggle: CheckBox
var _stats_panel: PanelContainer
var _stats_text: RichTextLabel
var _log_panel: PanelContainer
var _moment_label: Label
var _mode_label: Label
var _takings_label: Label
var _title_label: Label
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
	_ai.answered.connect(func(purpose, seconds, problems, ok): _stats.record_ai(seconds, problems, ok, purpose))
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
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up %s again for the night." % [_owner_display(), Game.bar["name"]])
	if not Game.bar.get("cat", {}).is_empty():  # bars saved before cats have none, for now
		_show_cat()
	_update_info()
	_start_night()


## Ollama couldn't be reached partway through, so the AI switched to canned replies.
func _on_offline_started(reason: String) -> void:
	_show_offline_mode()
	_narrate("(Couldn't reach the local AI, so the game switched to offline mode: %s.)" % reason)


func _show_offline_mode() -> void:
	_mode_label.text = "OFFLINE MODE"
	_mode_label.tooltip_text = "Characters and lines are pre-written, not from the AI (%s). Change it in ai_settings.cfg." % _ai.offline_reason
	_mode_label.visible = true


## The owner couldn't be invented (the AI failed): have another go.
func _on_try_again_pressed() -> void:
	if _owner.is_empty() and not _owner_working:
		_try_again.visible = false
		_invent_owner()


# --- The owner -------------------------------------------------------------

func _invent_owner() -> void:
	_owner_working = true
	_narrate("Somewhere under a Seoul overpass, someone is unrolling an orange tarp...")
	_typing_label.text = "The AI is inventing the tent's owner..."
	var gender: String = ["woman", "man"].pick_random()
	var result: Dictionary = await _ai.ask_json(Prompts.owner_messages(gender), _validate_owner.bind(gender), {"temperature": 0.9},
		{"purpose": "owner", "gender": gender})
	_typing_label.text = ""
	if result.is_empty():
		_narrate("Couldn't invent the owner: %s" % _ai.last_error)
		_try_again.visible = true
		_owner_working = false
		return
	_owner = result
	_owner["gender"] = gender
	_owner["title"] = Prompts.OWNER_ADDRESS[gender]["title"]
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	await _name_cat()
	_show_cat()
	_narrate("%s opens up for the night." % _owner_display())
	_update_info()
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


## A new bar's cat: the game picks its coat and personality, and the AI names it (from a
## short list if it can't).
func _name_cat() -> void:
	var coat: String = Rules.CAT_COATS.keys().pick_random()
	var personality: String = Rules.CAT_PERSONALITIES.keys().pick_random()
	var sex: String = Rules.CAT_SEXES.pick_random()
	var taken: Array = []  # every bar's cat has its own name
	for bar in SaveStore.list_bars():
		var name_taken := str(bar.get("cat", {}).get("name", ""))
		if name_taken != "" and bar.get("id", "") != Game.bar.get("id", ""):
			taken.append(name_taken)
	_typing_label.text = "Something furry is watching from under the counter..."
	var named: Dictionary = await _ai.ask_json(Prompts.cat_name_messages(_owner, str(Game.bar["name"]), coat, personality, sex, taken),
		_validate_cat_name.bind(taken), {"temperature": 0.9}, {"purpose": "cat_name", "taken": taken})
	_typing_label.text = ""
	_new_cat(str(named["name"]) if not named.is_empty() else Rules.fallback_cat_name(randf(), taken), coat, personality, sex)


func _new_cat(cat_name: String, coat: String, personality: String, sex: String) -> void:
	Game.bar["cat"] = {"name": cat_name, "coat": coat, "personality": personality, "sex": sex}
	Game.save()


func _show_cat() -> void:
	_cat = Game.bar["cat"].duplicate()
	_paint_cat()
	_cat_node.tooltip_text = "%s, the tent's %s cat (%s)" % [_cat["name"], _cat["coat"], Rules.CAT_PERSONALITIES.get(_cat["personality"], "")]
	_narrate("%s, the tent's %s cat, is %s." % [_cat["name"], _cat["coat"], Rules.CAT_PERSONALITIES.get(_cat["personality"], _cat["personality"]).get_slice(":", 0)])


func _show_bar_name() -> void:
	_title_label.text = "KTBT  ·  %s" % Game.bar["name"]
	_title_label.tooltip_text = str(Game.bar.get("name_meaning", ""))


## Close the bar (the top bar's button, or the night summary's) and go back to the title
## screen, saved: straight away
## if the owner's free, otherwise once they've finished what they're doing (an AI call
## can't be stopped halfway).
func _on_leave_pressed() -> void:
	if _stopped:
		return
	if _owner_working:
		_leave_requested = true
		_leave_button.disabled = true
		_typing_label.text = "Closing up as soon as %s is free..." % _owner_display()
		return
	_leave()


## Closing the window: the bar's saved anyway (see game.gd); a night cut short gets its log.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _night_open and not _stopped:
		_save_stats(false)


func _leave() -> void:
	if _night_open:
		_save_stats(false)  # a night cut short still gets a log
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
	_stats = NightStats.new()
	_waiting.clear()
	_chats.clear()
	_names_tonight.clear()
	_jobs_tonight.clear()
	_looks_tonight.clear()
	_last_orders = false
	_attending = null
	_night_open = true
	_next_arrival = _clock + Rules.next_arrival_gap(int(_clock), randf())
	_cat_spot = "stove"  # every night starts with the cat asleep by the stove
	_cat_with = null
	_cat_next = randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y)
	_place_cat()
	_update_clock_label()
	_start_transcript()
	_show("\n[center][color=#%s]· · ·  Night %d  · · ·[/color][/center]\n\n" % [ACCENT.to_html(false), _night_number])
	_narrate("%s, %s. %s. The tarp goes up and the first pots go on." % [_night_day, Rules.clock_text(Rules.OPEN_MINUTES), Rules.sentence_case(_night_weather)])


## Every frame: the clock and the stove move on, people turn up (or give up waiting), and if
## the owner's free, they get on with whatever's most urgent. At 3am the owner calls last
## orders; the night ends once the last customer has gone.
func _process(delta: float) -> void:
	if not _night_open or _stopped:
		return
	var seconds_per_minute := _scaled(REAL_SECONDS_PER_GAME_MINUTE)
	_time_speed = move_toward(_time_speed, Rules.time_speed(_people_in()), delta * SPEED_CHANGE_RATE)
	var minutes := delta * _time_speed / seconds_per_minute if seconds_per_minute > 0.0 else 60.0
	_count_time(delta)
	_cook(minutes)
	# Everyone's stay runs down, even when tests hold the clock.
	for guest in _guests:
		guest.stay_left -= minutes
	if cat_wanders and not _cat.is_empty():
		_cat_next -= minutes
		if _cat_next <= 0.0:
			_move_cat()
	if run_clock:
		# After 3am the clock runs on while the last customers finish up.
		_clock += minutes
		_update_clock_label()
		while _clock >= _next_arrival and _next_arrival < Rules.LAST_ARRIVAL_MINUTES:
			_arrive(_next_arrival)
			_next_arrival += Rules.next_arrival_gap(int(_next_arrival), randf())
	_give_up_waiting()
	if _clock >= Rules.CLOSE_MINUTES and not _last_orders:
		_call_last_orders()
	if not _carrying and not _ready_dishes.is_empty():
		_carry_dish()
	if _owner_working:
		return
	if _leave_requested:
		_leave()
	elif _clock >= Rules.CLOSE_MINUTES and _guests.is_empty():
		_end_night()
	else:
		_next_task()


## Everyone in the tent: on a stool, waiting, or being greeted right now (they've left the
## queue but aren't on their stool until the AI has invented them).
func _people_in() -> int:
	return _guests.size() + _waiting.size() + (1 if _greeting else 0)


## Someone turns up, at this time (game minutes), and waits to be greeted. (Tests call this
## too, to bring customers in.)
func _arrive(when: float) -> void:
	_waiting.append(when)
	_stats.arrived += 1
	_update_info()


## Someone who's waited too long with every stool taken gives up and walks on.
func _give_up_waiting() -> void:
	var gone := 0
	while not _waiting.is_empty() and _free_seats().is_empty() and _clock - float(_waiting[0]) > Rules.GIVE_UP_MINUTES:
		_waiting.pop_front()
		_stats.walked_past += 1
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


## 3am: nobody new, no more orders, and everyone's time is up.
func _call_last_orders() -> void:
	_last_orders = true
	_waiting.clear()
	if _guests.is_empty():
		return
	_narrate("%s. %s calls last orders and starts stacking the spare stools." % [Rules.clock_text(int(_clock)), _owner_display()])
	for guest in _guests:
		guest.stay_left = 0.0
		guest.transcript.append({"action": "It's 3am: %s calls last orders and starts stacking the spare stools." % _owner["name"]})
	_update_info()


## The night's over: the owner closes up, the night is saved, and a summary appears.
func _end_night() -> void:
	_night_open = false
	_move_owner(OWNER_HOME_X)
	_update_stats_panel()
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
	_save_stats(true)  # after the closing line, so the transcript runs right to the end
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
	if _night_open and _time_speed > 1.05:
		_moment_label.text += "  ·  ▶▶ %.0f×" % _time_speed  # time's running fast: the tent's quiet


# --- What the owner does next ------------------------------------------------

## What the owner's voice does next, most urgent first: greet someone new; settle up with
## someone whose time is up; otherwise chat with whoever's been left alone longest (or, now
## and then, let customers chat to each other). Each starts a task that runs (with awaits)
## until it's done. (Carrying food over doesn't need the voice: see _carry_dish.)
func _next_task() -> void:
	if _can_greet():
		_greet()
		return
	var payer := _ready_to_pay()
	if payer != null:
		_settle_up(payer)
		return
	var chance := BUSY_CHAT_CHANCE if _guests.size() >= Rules.BUSY_COUNTER else CHAT_CHANCE
	if chat_chance_override >= 0.0:
		chance = chat_chance_override
	if _chat_possible():
		_stats.chat_chances += 1
		if randf() < chance:
			_counter_chat()
			return
	var lonely := _left_alone_longest()
	if lonely != null:
		_talk(lonely)


## Something more urgent than chatting needs the owner.
func _urgent() -> bool:
	return _can_greet() or _ready_to_pay() != null


func _can_greet() -> bool:
	return not _waiting.is_empty() and not _free_seats().is_empty() and not _last_orders


func _free_seats() -> Array:
	var free := range(Rules.SEATS)
	for guest in _guests:
		free.erase(guest.seat)
	return free


## Someone whose time is up and isn't waiting for any food.
func _ready_to_pay() -> Guest:
	for guest in _guests:
		if guest.time_up() and _food_coming(guest).is_empty():
			return guest
	return null


## Whoever's waited longest for the owner. People here to talk get seen to sooner.
func _left_alone_longest() -> Guest:
	var best: Guest = null
	for guest in _guests:
		if not guest.time_up() and (best == null or _neediness(guest) < _neediness(best)):
			best = guest
	return best


func _neediness(guest: Guest) -> int:
	return guest.attended - (3 if guest.company == "owner" else 0)


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
	_move_owner(_beside(guest))


# --- Debug stats -----------------------------------------------------------------

## Real time for the stats: how much of it the owner's voice was busy, and whether anyone was
## waiting for it meanwhile. Also refreshes the stats panel a couple of times a second.
func _count_time(delta: float) -> void:
	_stats.real_seconds += delta
	_stats.seated_seconds += _guests.size() * delta
	if _guests.size() >= 2:
		_stats.together_seconds += delta
	if _owner_working:
		_stats.voice_busy_seconds += delta
		if _can_greet() or _ready_to_pay() != null:
			_stats.waiting_on_voice_seconds += delta
	_stats_refresh -= delta
	if _stats_refresh <= 0.0:
		_stats_refresh = 0.5
		_update_stats_panel()


func _update_stats_panel() -> void:
	if _stats_panel.visible:
		_stats_text.text = "[color=#%s][b]STATS (debug)[/b][/color]  [color=#%s]Night %d · F3 hides[/color]\n\n%s" % [
			ACCENT.to_html(false), MUTED.to_html(false), _night_number, _stats.panel_text(_guests.size(), _kitchen.size() + _ready_dishes.size())]


## Writes tonight's log (stats/ in the user data folder).
func _save_stats(finished: bool) -> void:
	var context := {
		"bar": str(Game.bar.get("name", "")), "night": _night_number, "day": _night_day, "weather": _night_weather,
		"finished": finished, "clock": Rules.clock_text(int(_clock)),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"ai_backend": str(_ai.settings.get("backend", "")), "ai_model": str(_ai.settings.get("model", "")),
		"offline": _ai.offline, "time_speeds": Rules.TIME_SPEEDS, "reading_pauses": _reading_toggle.button_pressed,
	}
	var path := _stats.save(context, str(Game.bar.get("id", "bar")), _night_number)
	if path != "":
		print("Night stats saved: ", ProjectSettings.globalize_path(path))
	_finish_transcript(context)


## Adds to the transcript on screen and, during a night, to tonight's transcript file.
func _show(bbcode: String) -> void:
	_log.append_text(bbcode)
	if _transcript_file != null:
		# As plain text: tags stripped ([lb] is how a "[" in the AI's text is escaped).
		_transcript_file.store_string(_tags.sub(bbcode.replace("[lb]", "\u0001"), "", true).replace("\u0001", "["))
		_transcript_file.flush()


## Tonight's transcript file, written as the night goes, so it's there even if the game
## closes mid-night: a header saying which bar and night, and with what AI settings, then
## everything said and done, and (see _finish_transcript) the night's stats. In the
## project's logs/transcripts/ folder when running from the editor (handy for reading and
## sharing; .gitignore keeps them out of commits).
func _start_transcript() -> void:
	_transcript_file = null
	var folder := transcript_folder
	if folder == "":
		folder = "res://logs/transcripts/" if OS.has_feature("editor") else "user://logs/transcripts/"
	DirAccess.make_dir_recursive_absolute(folder)
	var now := Time.get_datetime_string_from_system(false, true)
	var stamp := now.replace(":", "").replace(" ", "_").left(15)
	var path := folder.path_join("%s_%s_night%d.txt" % [stamp, str(Game.bar.get("id", "bar")), _night_number])
	_transcript_file = FileAccess.open(path, FileAccess.WRITE)
	if _transcript_file == null:
		return
	var model := " / " + str(_ai.settings.get("model", "")) if not _ai.offline else ""
	_transcript_file.store_string("\n".join(PackedStringArray([
		"KTBT transcript: %s, night %d" % [Game.bar.get("name", ""), _night_number],
		"%s, %s. Started %s." % [_night_day, _night_weather, now],
		"AI: %s%s (%s), reading pauses %s." % [_ai.settings.get("backend", ""), model, "offline" if _ai.offline else "online",
			"on" if _reading_toggle.button_pressed else "off"],
		"=".repeat(70),
	])) + "\n")
	_transcript_file.flush()
	print("Night transcript: ", ProjectSettings.globalize_path(path))


## The end of the night (or the bar closed early): how it ended, and the night's stats.
func _finish_transcript(context: Dictionary) -> void:
	if _transcript_file == null:
		return
	var stats := _stats.panel_text(_guests.size(), _kitchen.size() + _ready_dishes.size()).replace("[b]", "").replace("[/b]", "")
	_transcript_file.store_string("\n%s\n%s at %s.\n\nSTATS\n\n%s\n" % ["=".repeat(70), "Finished" if context["finished"] else "Cut short", context["clock"], stats])
	_transcript_file.close()
	_transcript_file = null


func _on_stats_toggled(_on: bool) -> void:
	_layout_panels()
	_update_stats_panel()


## F3 shows or hides the stats panel.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_stats_toggle.button_pressed = not _stats_toggle.button_pressed


## The panels under the tent: the transcript, then the stats (when shown), then the info.
func _layout_panels() -> void:
	var height := SCREEN.y - PANELS_TOP - 24
	var info_x := SCREEN.x - INFO_WIDTH - 24
	var log_width := info_x - 48
	_stats_panel.visible = _stats_toggle.button_pressed
	if _stats_panel.visible:
		log_width -= STATS_WIDTH + 24
		_stats_panel.position = Vector2(24 + log_width + 24, PANELS_TOP)
		_stats_panel.size = Vector2(STATS_WIDTH, height)
	_log_panel.size = Vector2(log_width, height)


## Where the owner stands to see to someone.
func _beside(guest: Guest) -> float:
	return SEAT_X[guest.seat] - PERSON_WIDTH / 2 + OWNER_BESIDE_X


# --- Tasks: greeting, carrying food, settling up, chatting --------------------

## Someone new sits down: the AI invents them, they order, drinks and banchan come straight
## away, cooked dishes go on the stove, and they exchange a first word with the owner.
func _greet() -> void:
	_owner_working = true
	var turned_up: float = _waiting.pop_front()
	_greeting = true
	_stats.greet_waits.append(_clock - turned_up)  # how long they waited for the owner
	var guest := Guest.new()
	guest.quick_greeting = Rules.quick_greeting(_waiting.size(), _guests.size())
	guest.seat = _free_seats().pick_random()
	guest.arrived = Rules.clock_text(int(_clock))
	guest.moment = {"day": _night_day, "time": guest.arrived, "weather": _night_weather}
	_show("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	_narrate("%s. Someone ducks under the tarp." % guest.arrived)

	# 1. Who is it? First just a name and gender: a quick ask, so if the name's taken, asking
	# again costs little. Then the rest of that person.
	_typing_label.text = "Someone is coming down the street..."
	var taken: Array = [str(_owner["name"])]  # nobody at the counter shares a name
	for other in _guests:
		taken.append(str(other.customer["name"]))
	var used: Array = _names_tonight.filter(func(n): return not taken.has(n))
	# About one in a hundred is non-binary: the game decides; otherwise the AI chooses.
	var gender := gender_override if gender_override != "" else Rules.game_gender(randf())
	var who: Dictionary = await _ai.ask_json(
		Prompts.customer_name_messages(_night_day, guest.arrived, _night_weather, taken, used, gender),
		_validate_customer_name.bind(taken, gender), {"temperature": 1.0}, {"purpose": "customer_name", "taken": taken, "gender": gender})
	var customer := {}
	if not who.is_empty():
		_typing_label.text = "%s is coming down the street..." % who["name"]
		customer = await _ai.ask_json(
			Prompts.customer_messages(_night_day, guest.arrived, _night_weather, false, str(who["name"]), str(who["gender"]), _jobs_tonight, _looks_tonight.slice(-VARIETY_LOOKS)),
			_validate_customer_details, {"temperature": 0.9}, {"purpose": "customer", "name": who["name"], "gender": who["gender"]})
	_typing_label.text = ""
	if customer.is_empty():
		_narrate("Nobody came in after all. (%s)" % _ai.last_error)
		_greeting = false
		_task_done()
		return
	customer["name"] = who["name"]
	customer["gender"] = who["gender"]
	_names_tonight.append(str(who["name"]))
	if not _jobs_tonight.has(str(customer["job"])):
		_jobs_tonight.append(str(customer["job"]))
	_looks_tonight.append(str(customer["appearance"]))
	# The game decides their mood for company and how long they'll stay.
	guest.company = company_override if company_override != "" else Rules.company(randf())
	customer["company"] = guest.company
	var stay := stay_minutes_override if stay_minutes_override >= 0 else Rules.stay_minutes(guest.company, randf())
	guest.stay_left = 0.0 if _last_orders else float(stay)
	guest.customer = customer
	guest.color = _free_color()
	guest.drinks_row = _drinks_rows[guest.seat]
	guest.food_row = _food_rows[guest.seat]
	guest.node = _person(_stage, Vector2(_random_offscreen_x(), CUSTOMER_Y), guest.color)
	guest.node.name = "Customer%d" % guest.seat
	(guest.node.get_node("Tag") as Label).text = _name_label(customer)
	_guests.append(guest)
	_greeting = false
	_stats.peak_seated = maxi(_stats.peak_seated, _guests.size())
	_update_info()
	_narrate(Rules.as_sentence(str(customer["appearance"])))
	_attend(guest, false)
	_walk_in(guest)  # the owner doesn't wait for them to sit down: the AI's already on their order

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
	_serve(guest, items, true)
	_stats.serve_waits.append(_clock - turned_up)
	if guest.quick_greeting:
		_stats.quick_greetings += 1
	else:
		_stats.proper_greetings += 1

	# 3. Will they order more partway through? The game decides how often (often not,
	# sometimes once, rarely twice) and on which of their turns, spaced out by the rules.
	# If they leave before a turn comes round, that order never happens.
	var extra_count := Rules.extra_order_count(randf())
	guest.extra_turns = Rules.extra_order_turns(randi_range(3, 5) + extra_count, extra_count)
	# 4. On a quiet night, a first word with the owner straight away. When it's busy, that
	# waits until the owner has a moment.
	if not guest.quick_greeting:
		await _converse(guest, 1, false)
	_task_done()


## Drinks (and anything else that needs no cooking) go on the table now, with the free
## banchan for a first order; cooked dishes join the queue at the stove.
func _serve(guest: Guest, items: Array, first_order: bool) -> void:
	var now := Rules.instant_items(items)
	var later := Rules.cooked_items(items)
	_typing_label.text = "%s is pouring..." % _owner_display()
	for id in now:
		_add_dish(guest, id)
		guest.served.append(id)
	guest.version += 1
	guest.food_news = true
	if first_order:
		guest.drinks_row.add_child(_banchan_shape())
	for id in later:
		_kitchen.append({"guest": guest, "id": id, "left": float(Menu.cook_minutes(id)), "ordered": _clock})
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
## This uses the owner's hands, not their voice, so it happens straight away, even while
## the AI is thinking of someone's next line: over to the stool, down goes the dish, and back
## to whoever they were talking to.
func _carry_dish() -> void:
	_carrying = true
	var dish: Dictionary = _ready_dishes.pop_front()
	var guest: Guest = dish["guest"]
	var id := str(dish["id"])
	_update_stove()
	if not _guests.has(guest):
		_carrying = false
		return
	_move_owner(_beside(guest))
	await get_tree().create_timer(_scaled(0.4)).timeout
	if _stopped or not _guests.has(guest):
		_carrying = false
		return
	_add_dish(guest, id)
	guest.served.append(id)
	guest.version += 1
	guest.food_news = true
	_stats.dishes_cooked += 1
	_stats.food_waits.append(_clock - float(dish["ordered"]))
	var item_name := str(Menu.find(id)["name"])
	_narrate("%s brings the %s over to %s." % [_owner_display(), item_name, guest.customer["name"]])
	guest.transcript.append({"action": "%s brings over the %s, hot from the stove. It's on the table now." % [_owner["name"], item_name]})
	_update_info()
	if _attending != null and _attending != guest and _guests.has(_attending):
		_move_owner(_beside(_attending))
	_carrying = false


## Someone's time is up: they say goodbye, the game works out the bill, the bar is saved,
## and they leave.
func _settle_up(guest: Guest) -> void:
	_owner_working = true
	_attend(guest, false)
	await _goodbye(guest)
	await _wait_for_reader()  # let their goodbye sink in before they go
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
	_stats.served += 1
	_stats.owner_lines_each.append(guest.transcript.filter(func(e): return e.has("text")).size())
	_customer = guest.customer
	_order = guest.order.duplicate()
	_narrate("%s pays %s and heads back out into the night." % [guest.customer["name"], Menu.format_won(bill)])
	_clear_table(guest)
	_walk_out(guest)  # off they go; the owner gets on with the next thing
	_guests.erase(guest)
	_leave_chats(guest)
	if _attending == guest:
		_attending = null
	if _cat_with == guest:
		_move_cat()  # they got up, so the cat's off
	_task_done()


## A spell of conversation with one guest: an exchange or two, cut short if something more
## urgent comes up (but never between the owner's line and the customer's reply).
func _talk(guest: Guest) -> void:
	_owner_working = true
	_attend(guest, true)
	guest.topic = Rules.pick_owner_topic(randf(), guest.food_news or not _food_coming(guest).is_empty(), _cat_here(guest), guest.topic)
	guest.food_news = false
	await _converse(guest, randi_range(1, 2), true)
	_task_done()


## Where the cat is, as far as a guest's conversation goes: "none" (no cat, or it's out in
## the street), "with_them" (on their lap, at their feet, eyeing their food) or "tent".
func _cat_here(guest: Guest) -> String:
	if _cat.is_empty() or _cat_spot == "street":
		return "none"
	return "with_them" if guest != null and _cat_with == guest else "tent"


func _converse(guest: Guest, exchanges: int, interruptible: bool) -> void:
	while not guest.time_up() and not _leave_requested:
		await _next_line(guest)
		if guest.line % 2 == 0:  # an exchange finished: the customer has just replied
			exchanges -= 1
			if exchanges <= 0 or (interruptible and _urgent()):
				return


## The next line of a guest's conversation with the owner (or a later order, when it's
## their turn for one).
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
	if i == 0 and guest.quick_greeting:
		direction = "It's been busy: this is the owner's first proper word with them since taking their order."
	elif i == 0:
		direction = "They've just been served: what's ready is on the table, and anything else is still cooking."
	elif guest.stay_left < 10.0:
		direction = "The customer is nearly ready to leave."
	elif guest.topic != "":
		direction = Rules.topic_hint(guest.topic)
	var speaker := str(_owner["name"]) if owner_speaks else str(guest.customer["name"])
	var alias := str(_owner["title"]) if owner_speaks else ""
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := guest.version
		reply = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, owner_speaks, direction, _cat_prompt()),
			_validate_line.bind(speaker, alias, guest.order, [str(_owner["name"]), str(guest.customer["name"])], _cat_fact()), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": owner_speaks, "first": i == 0, "last": false})
		# Out of date already (a dish arrived, or the cat came or went, while the AI was
		# writing it)? Ask again, with things as they are now.
		if reply.is_empty() or guest.version == version or attempt == 1:
			break
		_stats.stale_redone += 1
	_typing_label.text = ""
	if reply.is_empty():
		# Nothing more to say, so they'll finish up and go.
		_narrate("(The conversation with %s fizzled out: %s.)" % [guest.customer["name"], _ai.last_error])
		guest.stay_left = 0.0
		return
	await _say(guest, owner_speaks, str(reply["line"]))
	guest.line += 1


## A customer's last line to the owner, as they pay up and go. If the AI can't manage one,
## they just pay.
func _goodbye(guest: Guest) -> void:
	var speaker := str(guest.customer["name"])
	var owner_name := str(_owner["name"])
	guest.moment["time"] = Rules.clock_text(int(_clock))
	# If they had the last word, the owner sees them off first, so they don't speak twice running.
	if _last_speaker(guest.transcript) == speaker:
		_typing_label.text = "%s is thinking..." % _owner_display()
		var send_off: Dictionary = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, true,
				"The customer is getting up to go: see them off.", _cat_prompt()),
			_validate_line.bind(owner_name, str(_owner["title"]), guest.order, [owner_name, speaker], _cat_fact()), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": true, "first": false, "last": false})
		if not send_off.is_empty():
			await _say(guest, true, str(send_off["line"]))
			guest.line += 1
	# Someone they were chatting with gets a goodbye too.
	var chat := _chat_of(guest)
	var partners: Array = [] if chat == null else chat.people.filter(func(g): return g != guest and _guests.has(g)).map(func(g): return str(g.customer["name"]))
	var direction := "This is the customer's last line: they're paying up and heading back out into the night."
	if not partners.is_empty():
		direction += " They also say goodbye to %s, who they were chatting with." % " and ".join(PackedStringArray(partners))
	_typing_label.text = "%s is reaching for their wallet..." % speaker
	var reply: Dictionary = await _ai.ask_json(
		Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, false, direction, _cat_prompt()),
		_validate_line.bind(speaker, "", guest.order, [owner_name, speaker] + partners, _cat_fact()), {"temperature": 0.85},
		{"purpose": "line", "title": _owner["title"], "owner_speaks": false, "first": false, "last": true})
	_typing_label.text = ""
	if not reply.is_empty():
		await _say(guest, false, str(reply["line"]))
		guest.line += 1
	for other in (chat.people if chat != null else []):
		if other != guest and _guests.has(other):
			other.transcript.append({"action": "%s, who they were chatting with, says goodbye and leaves." % speaker})


## Who spoke last in a transcript ("" if nobody has).
static func _last_speaker(transcript: Array) -> String:
	for i in range(transcript.size() - 1, -1, -1):
		if transcript[i].has("text"):
			return str(transcript[i]["speaker"])
	return ""


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
	_serve(guest, items, false)
	return true


# --- Customers chatting to each other -------------------------------------------

## Someone who can be drawn into a chat right now: not keeping to themselves, settled in
## (served), and not about to leave (nobody starts a chat with ten minutes to go).
func _can_chat(guest: Guest) -> bool:
	return Rules.joins_chats(guest.company) and guest.stay_left >= CHAT_MIN_STAY_LEFT and not guest.order.is_empty()


func _chat_of(guest: Guest) -> Chat:
	for chat in _chats:
		if chat.people.has(guest):
			return chat
	return null


## People free to start a new chat, or join one.
func _free_to_chat() -> Array:
	return _guests.filter(func(guest): return _can_chat(guest) and _chat_of(guest) == null)


## The customers in a chat who can still take part.
func _chat_voices(chat: Chat) -> Array:
	return chat.people.filter(func(guest): return _can_chat(guest))


func _chat_possible() -> bool:
	if _last_orders:
		return false
	for chat in _chats:
		if _chat_voices(chat).size() >= 2:
			return true
	return _free_to_chat().size() >= 2


func _leave_chats(guest: Guest) -> void:
	for chat in _chats.duplicate():
		chat.people.erase(guest)
		if chat.people.size() < 2:
			_chats.erase(chat)


## A spell of customers chatting: carry on a chat already going (sometimes someone else
## joins in), or two strangers get talking. Sometimes the owner leans over and joins in.
## A few lines, cut short if something more urgent comes up.
func _counter_chat() -> void:
	_owner_working = true
	var chat: Chat = null
	var ongoing := _chats.filter(func(c): return _chat_voices(c).size() >= 2)
	var free := _free_to_chat()
	if not ongoing.is_empty() and (free.size() < 2 or randf() < 0.6):
		chat = ongoing.pick_random()
		_stats.chats_continued += 1
		if not free.is_empty() and randf() < JOIN_CHANCE:
			var joiner: Guest = free.pick_random()
			chat.people.append(joiner)
			_stats.customer_joins += 1
			_narrate("%s joins in." % joiner.customer["name"])
			chat.transcript.append({"action": "%s, from further along the counter, joins the conversation." % joiner.customer["name"]})
	elif free.size() >= 2:
		free.shuffle()
		chat = Chat.new()
		chat.people = [free[0], free[1]]
		_chats.append(chat)
		_stats.chats_started += 1
		_narrate("%s gets talking to %s." % [free[0].customer["name"], free[1].customer["name"]])
		chat.transcript.append({"action": "%s turns to %s, a stranger a few stools along, and starts a conversation." % [free[0].customer["name"], free[1].customer["name"]]})
	if chat == null:
		_task_done()
		return
	if not chat.owner_in and randf() < OWNER_JOINS_CHANCE:
		chat.owner_in = true
		_stats.owner_joins += 1
		_narrate("%s leans over the counter and joins in." % _owner_display())
		chat.transcript.append({"action": "%s, the owner, leans over the counter and joins in." % _owner["name"]})
	if chat.owner_in:
		# Talking with the owner counts as being seen to.
		for guest in chat.people:
			_attention += 1
			guest.attended = _attention
		_attending = chat.people[0]
		_move_owner(_beside(chat.people[0]))
	var cat_with_them := "none" if _cat_here(null) == "none" else ("with_them" if chat.people.has(_cat_with) else "tent")
	chat.topic = Rules.pick_chat_topic(randf(), cat_with_them, chat.topic)
	var said := ""
	var lines_said := 0
	var lines := randi_range(CHAT_LINES.x, CHAT_LINES.y)
	while lines > 0 and not _leave_requested:
		var voices: Array = _chat_voices(chat).map(func(guest): return str(guest.customer["name"]))
		if voices.size() < 2:
			break
		if chat.owner_in:
			voices.append(str(_owner["name"]))
		var first := said == "" and chat.last_speaker == ""
		var speaker: String = voices[0] if first else voices.filter(func(v): return v != chat.last_speaker).pick_random()
		var addressee: String = chat.last_speaker if voices.has(chat.last_speaker) and chat.last_speaker != speaker else voices.filter(func(v): return v != speaker).pick_random()
		var line := await _chat_line(chat, speaker, addressee, first)
		if line == "":
			_narrate("(The conversation at the counter fizzled out: %s.)" % _ai.last_error)
			_chats.erase(chat)
			break
		said = "%s: \"%s\"" % [speaker, line]
		lines -= 1
		lines_said += 1
		# Something more urgent can cut the chat short, but only once it's had a few lines.
		if _urgent() and lines_said >= CHAT_LINES_BEFORE_INTERRUPTING:
			break
	# Each person's own conversation with the owner hears about it, so the owner can pick it up.
	if said != "":
		for guest in chat.people:
			var others: Array = chat.people.filter(func(g): return g != guest).map(func(g): return str(g.customer["name"]))
			guest.transcript.append({"action": "%s has been chatting with %s at the counter. The last thing said there: %s" % [guest.customer["name"], " and ".join(PackedStringArray(others)), said]})
	chat.owner_in = false  # the owner goes back to work after the spell
	_task_done()


## Asks the AI for one line of a customer chat and shows it. Returns the line, or "" if the
## AI couldn't manage one.
func _chat_line(chat: Chat, speaker: String, addressee: String, first: bool) -> String:
	var owner_name := str(_owner["name"])
	var people: Array = chat.people.map(func(person): return person.customer)
	var tables: Array = chat.people.map(func(person): return _table_text(person))
	var items: Array = []
	var names: Array = [owner_name]
	for guest in chat.people:
		items.append_array(guest.order)
		names.append(str(guest.customer["name"]))
	var moment := {"day": _night_day, "time": Rules.clock_text(int(_clock)), "weather": _night_weather}
	var direction := "This is the first thing they've ever said to each other." if first else Rules.topic_hint(chat.topic, true)
	var owner_speaks := speaker == owner_name
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := _chat_version(chat)
		tables = chat.people.map(func(person): return _table_text(person))
		reply = await _ai.ask_json(
			Prompts.counter_chat_messages(_owner, chat.owner_in, people, tables, moment, chat.transcript, speaker, addressee, direction, _cat_prompt()),
			_validate_line.bind(speaker, str(_owner["title"]) if owner_speaks else "", items, names, _cat_fact()), {"temperature": 0.85},
			{"purpose": "chat_line", "owner_speaks": owner_speaks, "first": first})
		if reply.is_empty() or _chat_version(chat) == version or attempt == 1:
			break
		_stats.stale_redone += 1  # out of date already: ask again
	_typing_label.text = ""
	if reply.is_empty():
		return ""
	var line := str(reply["line"])
	var guest: Guest = _guest_named(speaker)
	var who := _owner_label() if owner_speaks else _name_label(guest.customer)
	var addressed: Guest = _guest_named(addressee)
	var to := _owner_label() if addressed == null else _name_label(addressed.customer)
	var colour := OWNER_TEXT if guest == null else guest.color.lightened(0.35)
	await _wait_for_reader()
	chat.transcript.append({"speaker": speaker, "text": line})
	chat.last_speaker = speaker
	_stats.chat_lines += 1
	if guest != null:
		_night_lines.append({"speaker": speaker, "text": line})
	_show("[color=#%s][b]%s to %s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(to), _esc(line)])
	_give_time_to_read(line)
	return line


## Changes anyone in a chat can see, added up (see Guest.version).
func _chat_version(chat: Chat) -> int:
	var total := 0
	for person in chat.people:
		total += person.version
	return total


func _guest_named(customer_name: String) -> Guest:
	for guest in _guests:
		if str(guest.customer["name"]) == customer_name:
			return guest
	return null


# --- The cat -------------------------------------------------------------------

## The cat moves on: somewhere new, chosen by its personality (spot: a test can choose). If
## it's with a customer, that customer's conversation hears about it, so the AI can react.
func _move_cat(spot: String = "") -> void:
	var people := _guests.filter(func(g): return not g.order.is_empty())
	var eating := people.filter(func(g): return g.served.any(func(id): return Menu.find(id).get("kind", "") == "food"))
	if spot == "":
		spot = Rules.pick_cat_spot(str(_cat["personality"]), not people.is_empty(), not eating.is_empty(), randf(), _cat_spot)
	var with: Guest = null
	if spot in ["lap", "feet"]:
		with = people.pick_random() if not people.is_empty() else null
	elif spot == "food":
		with = eating.pick_random() if not eating.is_empty() else null
	if spot in ["lap", "feet", "food"] and with == null:
		spot = "stove"
	var before := _cat_with
	_cat_spot = spot
	_cat_with = with
	_cat_next = randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y)
	var cat_name := str(_cat["name"])
	var was_out := _cat_node.visible == false
	if before != null and before != with and _guests.has(before):
		before.transcript.append({"action": "%s jumps down and wanders off." % cat_name})
		before.version += 1
	var text := Rules.cat_move_text(cat_name, spot, _cat_with_name())
	# Moves that matter (with a customer, leaving them, going out or coming in) are always
	# narrated; just pottering about only sometimes.
	if with != null or before != null or spot == "street" or was_out or randf() < CAT_POTTER_NARRATED:
		_narrate(text)
	if with != null:
		with.transcript.append({"action": text})
		with.version += 1
	_place_cat()
	_update_info()


func _cat_with_name() -> String:
	return str(_cat_with.customer["name"]) if _cat_with != null else ""


## Where the cat is, for the AI's prompts.
func _cat_prompt() -> String:
	if _cat.is_empty():
		return ""
	return Prompts.describe_cat(_cat, Rules.cat_text(str(_cat["name"]), _cat_spot, _cat_with_name()))


## Where the cat is, for checking the AI's lines.
func _cat_fact() -> Dictionary:
	if _cat.is_empty():
		return {}
	return {"name": _cat["name"], "spot": _cat_spot, "with": _cat_with_name()}


## Moves the cat's shape to its spot (it's hidden while it's out in the street).
func _place_cat() -> void:
	if _cat.is_empty():
		return
	var target := Vector2(150, 222)  # the stove end of the counter
	match _cat_spot:
		"counter": target = Vector2(STAGE_SIZE.x - 160, 222)
		"stools": target = Vector2(randf_range(SEAT_X[0] - 120, SEAT_X[Rules.SEATS - 1] + 60), 348)
		"street": target = Vector2(STAGE_SIZE.x + 80, 348)
		"lap": target = Vector2(SEAT_X[_cat_with.seat] - 20, 282)
		"feet": target = Vector2(SEAT_X[_cat_with.seat] + 18, 348)
		"food": target = Vector2(SEAT_X[_cat_with.seat] + 48, 318)
	_cat_node.visible = true
	# Face the way it's going (the cat's drawn facing right; flipped, it faces left).
	if absf(target.x - _cat_node.position.x) > 1.0:
		_cat_node.scale.x = 1.0 if target.x > _cat_node.position.x else -1.0
	if _cat_tween != null and _cat_tween.is_valid():
		_cat_tween.kill()
	_cat_tween = create_tween()
	_cat_tween.tween_property(_cat_node, "position", target, _scaled(1.0)).set_trans(Tween.TRANS_SINE)
	if _cat_spot == "street":
		_cat_tween.tween_callback(func(): _cat_node.visible = _cat_spot != "street")


## A grey-box cat: body, head, ears and tail, in its coat colour (calico and tabby get patches).
func _build_cat(stage: Control) -> void:
	_cat_node = Control.new()
	_cat_node.name = "Cat"
	_cat_node.position = Vector2(150, 222)
	_cat_node.size = Vector2(46, 28)
	_cat_node.z_index = 1  # in front of customers, so it shows on a lap
	_cat_node.pivot_offset = _cat_node.size / 2  # so flipping it to face left keeps it in place
	_cat_node.mouse_filter = Control.MOUSE_FILTER_STOP
	_cat_node.visible = false
	stage.add_child(_cat_node)
	for part in [["Tail", Vector2(-10, 10), Vector2(12, 4)], ["Body", Vector2(0, 10), Vector2(32, 16)], ["Head", Vector2(28, 2), Vector2(15, 14)],
			["EarLeft", Vector2(29, -2), Vector2(4, 5)], ["EarRight", Vector2(38, -2), Vector2(4, 5)], ["Patch", Vector2(8, 12), Vector2(10, 7)]]:
		_rect(_cat_node, part[1], part[2], Color.WHITE).name = part[0]


func _paint_cat() -> void:
	var coat := Color(str(Rules.CAT_COATS.get(_cat["coat"], "9c7a52")))
	for part in ["Tail", "Body", "Head", "EarLeft", "EarRight"]:
		(_cat_node.get_node(part) as ColorRect).color = coat
	var patch := _cat_node.get_node("Patch") as ColorRect
	patch.visible = _cat["coat"] in ["calico", "tabby"]
	patch.color = Color("d9883a") if _cat["coat"] == "calico" else coat.darkened(0.35)


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
		_ready_dishes.append({"guest": done["guest"], "id": done["id"], "ordered": done["ordered"]})
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

## Walking in and out runs by itself: nobody waits for it.
func _walk_in(guest: Guest) -> void:
	guest.walk = create_tween()
	guest.walk.tween_property(guest.node, "position:x", SEAT_X[guest.seat] - PERSON_WIDTH / 2, _scaled(1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _walk_out(guest: Guest) -> void:
	if guest.walk != null and guest.walk.is_valid():
		guest.walk.kill()  # if they hadn't quite sat down yet
	guest.walk = create_tween()
	# ...and leave in whichever direction they're heading home, at random.
	guest.walk.tween_property(guest.node, "position:x", _random_offscreen_x(), _scaled(1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	guest.walk.tween_callback(guest.node.queue_free)


func _move_owner(x: float) -> void:
	if _owner_tween != null and _owner_tween.is_valid():
		_owner_tween.kill()  # wherever they were heading, this comes first
	_owner_tween = create_tween()
	_owner_tween.tween_property(_owner_node, "position:x", x, _scaled(0.4)).set_trans(Tween.TRANS_SINE)


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
	var who := _owner_label() if owner_speaks else _name_label(guest.customer)
	if owner_speaks and _guests.size() > 1:
		who += " to %s" % _name_label(guest.customer)
	var colour := OWNER_TEXT if owner_speaks else guest.color.lightened(0.35)
	await _wait_for_reader()
	guest.transcript.append({"speaker": str(_owner["name"]) if owner_speaks else str(guest.customer["name"]), "text": text})
	_stats.owner_lines += 1
	if not owner_speaks:
		_night_lines.append({"speaker": str(guest.customer["name"]), "text": text})
	_show("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(text)])
	_give_time_to_read(text)


func _narrate(text: String) -> void:
	_show("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(text)])


## After a line is shown, the next one waits until there's been time to read it (longer
## lines, longer). Meanwhile everything else carries on, including the AI writing the next
## line, so the gap is whichever is longer, the reading or the AI's thinking, not both.
## With "Reading pauses" off (the default for now), lines come as fast as the AI writes them.
func _give_time_to_read(text: String) -> void:
	if not _reading_toggle.button_pressed:
		_read_until = 0
		return
	var seconds := clampf(1.0 + text.length() * 0.035, 1.5, 7.0)
	_read_until = Time.get_ticks_msec() + int(_scaled(seconds) * 1000.0)


func _wait_for_reader() -> void:
	while Time.get_ticks_msec() < _read_until:
		await get_tree().process_frame


func _scaled(seconds: float) -> float:
	if pause_scale_override >= 0.0:
		return seconds * pause_scale_override
	return seconds


# --- Small helpers -----------------------------------------------------------

func _owner_display() -> String:
	if _owner.is_empty():
		return "The owner"
	return "%s (%s)" % [_owner["name"], _owner["title"]]


## Gender symbols for names on screen (name tags, who's speaking, the info panel), since
## Korean names don't make it obvious. The AI never sees these.
const GENDER_SYMBOL := {"woman": "♀", "man": "♂", "non-binary": "⚲"}


static func gender_symbol(gender: Variant) -> String:
	return GENDER_SYMBOL.get(str(gender), "")


## A customer's name as shown on screen: "Kim Ji-ho ♀".
func _name_label(customer: Dictionary) -> String:
	var symbol := gender_symbol(customer.get("gender", ""))
	return str(customer["name"]) if symbol == "" else "%s %s" % [customer["name"], symbol]


## The owner's name as shown on screen: "Park Mi-sook ♀ (Ajumma)".
func _owner_label() -> String:
	if _owner.is_empty():
		return "The owner"
	var symbol := gender_symbol(_owner.get("gender", ""))
	if symbol == "":
		return _owner_display()
	return "%s %s (%s)" % [_owner["name"], symbol, _owner["title"]]


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
		t += "[b]%s[/b], %s\n" % [_esc(_owner_label()), _owner["age"]]
		t += "%s\n" % _esc(_owner["archetype"])
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(_owner["personality"])]
		t += "[i][color=#%s]Secret: %s[/color][/i]\n" % [muted, _esc(_owner["secret"])]
	if not _cat.is_empty():
		t += "\n[color=#%s][b]THE CAT[/b][/color]\n" % accent
		t += "[b]%s[/b], %s, %s%s\n" % [_esc(_cat["name"]), _cat["coat"], _cat["personality"], (", " + str(_cat["sex"])) if _cat.has("sex") else ""]
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(Rules.cat_text(str(_cat["name"]), _cat_spot, _cat_with_name()))]
	var seated := _guests.duplicate()
	seated.sort_custom(func(a, b): return a.seat < b.seat)
	if not seated.is_empty():
		t += "\n[color=#%s][b]AT THE COUNTER[/b][/color]\n" % accent
	for guest in seated:
		var c: Dictionary = guest.customer
		t += "[color=#%s][b]%s[/b][/color], %s, %s  [color=#%s](stool %d)[/color]\n" % [guest.color.lightened(0.35).to_html(false), _esc(_name_label(c)), c["age"], _esc(c["job"]), muted, guest.seat + 1]
		t += "[color=#%s]%s · %s · %s[/color]\n" % [muted, COMPANY_LABEL.get(guest.company, ""), _esc(c["mood"]), _esc(c["reason"])]
		var chat := _chat_of(guest)
		if chat != null:
			var others: Array = chat.people.filter(func(g): return g != guest).map(func(g): return str(g.customer["name"]))
			t += "[color=#%s]Talking with %s[/color]\n" % [muted, _esc(", ".join(PackedStringArray(others)))]
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


func _validate_customer_name(data: Variant, taken: Array, gender: String) -> String:
	return Rules.validate_customer_name(data, taken, gender)


func _validate_customer_details(data: Variant) -> String:
	return Rules.validate_customer_details(data)


func _validate_order(data: Variant, max_mains: int, max_drinks: int) -> String:
	return Rules.validate_order(data, max_mains, max_drinks)


func _validate_extra_order(data: Variant, table: Array) -> String:
	return Rules.validate_extra_order(data, table)


func _validate_line(data: Variant, speaker: String, alias: String, items: Array, names: Array, cat: Dictionary) -> String:
	return Rules.validate_line(data, speaker, alias, items, names, cat)


func _validate_cat_name(data: Variant, taken: Array) -> String:
	return Rules.validate_cat_name(data, str(_owner["name"]), taken)


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

	_reading_toggle = CheckBox.new()
	_reading_toggle.name = "ReadingToggle"
	_reading_toggle.text = "Reading pauses"
	_reading_toggle.button_pressed = false  # Off while we try the bar without them.
	_reading_toggle.tooltip_text = "Wait after each line so there's time to read it. Off: lines come as fast as the AI writes them."
	bar.add_child(_reading_toggle)

	_stats_toggle = CheckBox.new()
	_stats_toggle.name = "StatsToggle"
	_stats_toggle.text = "Stats"
	_stats_toggle.button_pressed = true  # Shown by default while we're testing.
	_stats_toggle.tooltip_text = "Debug stats for tonight (F3). A log of them is saved at the end of each night."
	_stats_toggle.toggled.connect(_on_stats_toggled)
	bar.add_child(_stats_toggle)

	# Godot's default tick boxes are dark: on this background an empty one disappears.
	for toggle in [_reading_toggle, _stats_toggle]:
		toggle.add_theme_icon_override("unchecked", _tick_box(false))
		toggle.add_theme_icon_override("checked", _tick_box(true))

	_try_again = Button.new()
	_try_again.name = "TryAgainButton"
	_try_again.text = "Try again"
	_try_again.tooltip_text = "Ask the AI for the owner again."
	_try_again.custom_minimum_size = Vector2(150, 40)
	_try_again.visible = false
	_try_again.pressed.connect(_on_try_again_pressed)
	bar.add_child(_try_again)

	_leave_button = Button.new()
	_leave_button.name = "LeaveButton"
	_leave_button.text = "Close the bar"
	_leave_button.tooltip_text = "Saves and goes back to the title screen."
	_leave_button.custom_minimum_size = Vector2(150, 40)
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
	_log_panel = _panel(Vector2(24, PANELS_TOP), Vector2(SCREEN.x - INFO_WIDTH - 72, SCREEN.y - PANELS_TOP - 24))
	add_child(_log_panel)
	var log_box := VBoxContainer.new()
	_log_panel.add_child(log_box)
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

	# Between them, the debug stats (while we're testing).
	_stats_panel = _panel(Vector2.ZERO, Vector2(STATS_WIDTH, 100))
	_stats_panel.name = "StatsPanel"
	add_child(_stats_panel)
	_stats_text = RichTextLabel.new()
	_stats_text.name = "StatsText"
	_stats_text.bbcode_enabled = true
	_stats_text.selection_enabled = true
	_stats_text.add_theme_font_size_override("normal_font_size", 15)
	_stats_text.add_theme_font_size_override("bold_font_size", 15)
	_stats_panel.add_child(_stats_text)
	_layout_panels()

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


## A tick box that shows up on a dark background: a light outline, filled with the accent
## colour and a tick when on.
func _tick_box(on: bool) -> ImageTexture:
	var side := 18
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var edge := Color("d8d5ee")
	for i in side:
		for j in [0, 1, side - 2, side - 1]:
			image.set_pixel(i, j, edge)
			image.set_pixel(j, i, edge)
	if on:
		image.fill_rect(Rect2i(3, 3, side - 6, side - 6), ACCENT)
		# The tick: a short stroke down, then a long one up.
		for k in 4:
			image.fill_rect(Rect2i(5 + k, 8 + k, 2, 2), Color.WHITE)
		for k in 6:
			image.fill_rect(Rect2i(8 + k, 11 - k, 2, 2), Color.WHITE)
	return ImageTexture.create_from_image(image)


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
	_build_cat(stage)
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
