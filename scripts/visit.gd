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
const Regulars = preload("res://scripts/regulars.gd")
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
## Test hook: false keeps people from walking past in the street.
static var strollers := true
## Test hooks: false gives a new bar (or an older one) no founding regulars (they'd use up
## tests' scripted replies); and a fixed roll for whether someone becomes a regular.
static var founding_regulars := true
static var regular_roll_override := -1.0
## Test hook: false skips the after-visit memory (an AI call that would use up scripted
## replies), so the game's own verdict is used; memory tests turn it on.
static var memories := true
## Test hook: false shows no speech bubbles (lines then come as fast as the AI writes them).
static var bubbles := true
## Test hook: true offers a new bar every colour and shape (so a scripted look always fits).
static var offer_every_look := false

## When the owner's free and nothing's urgent: how often customers chat to each other
## instead of the owner chatting to someone. Mostly it's customer and owner.
const CHAT_CHANCE := 0.5
## ...and when it's busy (Rules.BUSY_COUNTER or more in), when there are most people to talk to.
const BUSY_CHAT_CHANCE := 0.75
const JOIN_CHANCE := 0.4  # how often another customer joins an ongoing chat
const OWNER_JOINS_CHANCE := 0.35  # how often the owner joins a customer chat
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
	var chatted := false  # they've had a chat with another customer
	var chat_lines: Array = []  # {"speaker", "text"}: what was said in their chats at the counter
	var first_order: Array = []  # what they ordered as they sat down (for a regular's usual)
	var arrived_minutes := 0  # when they came in (game minutes), for a new regular's usual hour
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
var _waiting_who: Array = []  # ...and who they are: a regular's id, or "" for someone new
var _regulars_due: Array = []  # {"time", "id"}: regulars coming in tonight, soonest first
var _skip_arrivals := 0  # a regular came in instead of someone new
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
var _ambience: Ambience  # the tent's background sound
var _bubble_layer: Control  # speech bubbles, over everything on the stage
var _bubbles_shown: Array = []  # Bubble: the newest last
var _bubbles_toggle: CheckBox
var _sound_toggle: CheckBox
var _music: Music  # Arirang, now and then
var _loading: LoadingScreen  # the loading screen while a new bar is set up
var _look_offer: Dictionary = {}  # the colours and shapes a new bar is offered
var _tent: Array[CanvasItem] = []  # the tent's pieces: hidden until its look is known
var _strollers := 0  # people walking along the street, not coming in (also names their nodes)
var _stroll_next := 0.0  # game minutes until the next one
const STROLL_Y := CUSTOMER_Y + 38  # the pavement: a little lower (nearer to us) than the stools
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
# The look of the tent and the night (placeholder art, drawn in code)
var _sky: ColorRect  # behind everything: dusk to deep night
var _glow: ColorRect  # the tent's warm glow
var _bulbs: Array = []  # the hanging bulbs (they swing)
var _bulb_lights: Array = []
var _sways: Array = []  # the bulbs' swinging (replaced each night)
var _weather_back: Control  # rain or snow falling behind the tent
var _weather_front: Control  # fog, haze and drips, in front
var _weather_kind := ""
var _roof: Polygon2D
var _roof_edge: ColorRect
var _roof_stripes: Control
var _decor_back: Control  # the bar's touches: on the poles and back wall...
var _decor_counter: Control  # ...on the counter...
var _decor_roof: Control  # ...and hanging from the tarp
var _sign: Control
var _sign_board: ColorRect
var _sign_hangul: Label
var _sign_english: Label
var _drinks_rows: Array = []  # one per stool
var _food_rows: Array = []


func _ready() -> void:
	if random_seed != 0:
		seed(random_seed)
	_ai = Ai.new()
	add_child(_ai)
	_ambience = Ambience.new()
	_ambience.name = "Ambience"
	add_child(_ambience)
	_music = Game.start_music()
	_build_ui()
	_build_loading()
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
	_show_look()
	_dress(_owner_node, _owner_look())
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up %s again for the night." % [_owner_display(), Game.bar["name"]])
	_owner_working = true  # busy until it's done (it may ask the AI)
	await _fill_in_hangul()  # bars saved before names had Hangul, or whose first try didn't fit
	if founding_regulars and not Game.bar.has("regulars") and not _stopped:
		await _make_founding_regulars()  # a bar saved before regulars: its two, once
	_owner_working = false
	if _stopped or Game.bar.is_empty():
		return
	if not Game.bar.get("cat", {}).is_empty():  # bars saved before cats have none, for now
		_show_cat()
	_update_info()
	_end_loading()
	_start_night()


## The owner's and cat's names in Hangul, if they haven't got one (a bar saved before names had
## Hangul, or the AI's first try didn't fit): a known cat name from the game's list, or a
## quick ask of the AI just for that, checked like any other, and saved.
func _fill_in_hangul() -> void:
	var people: Array = [Game.bar["owner"]]
	if not Game.bar.get("cat", {}).is_empty():
		people.append(Game.bar["cat"])
	var changed := false
	for person in people:
		if str(person.get("hangul", "")) != "":
			continue
		var person_name := str(person["name"])
		var hangul := str(Rules.CAT_HANGUL.get(person_name, ""))
		if hangul == "":
			_typing_label.text = "The AI is writing %s in Hangul..." % person_name
			var reply: Dictionary = await _ai.ask_json(Prompts.hangul_messages(person_name), _validate_hangul.bind(person_name),
				{"temperature": 0.2}, {"purpose": "hangul", "name": person_name})
			_typing_label.text = ""
			if _stopped or Game.bar.is_empty():
				return  # the bar was closed while the AI was thinking
			hangul = str(reply.get("hangul", ""))
			if hangul == "":
				print("No Hangul for %s: %s" % [person_name, _ai.last_error])
		person["hangul"] = hangul  # "" if the AI couldn't: it's left off for now
		changed = changed or hangul != ""
	if changed:
		_owner["hangul"] = Game.bar["owner"]["hangul"]
		_owner_tag.text = _owner_label()
		Game.save()


func _validate_hangul(data: Variant, person_name: String) -> String:
	var problem := Rules.check_fields(data, ["hangul"])
	if problem != "":
		return problem
	var fitted := Rules.fit_hangul(person_name, data["hangul"])
	if fitted == "":
		return "\"hangul\" must be %s written in Korean letters (Hangul)" % person_name
	data["hangul"] = fitted
	return ""


## A loading screen over everything while a new bar is invented and the tent goes up.
func _build_loading() -> void:
	_loading = LoadingScreen.new()
	_loading.name = "Loading"
	_loading.z_index = 10
	add_child(_loading)


## The bar's ready (or something went wrong): fade the loading screen out.
func _end_loading() -> void:
	if _loading == null or not _loading.visible:
		return
	var fade := _loading.create_tween()
	fade.tween_property(_loading, "modulate:a", 0.0, 0.4)
	fade.tween_callback(func(): _loading.visible = false)


## Back to the loading screen (trying again after the AI failed).
func _start_loading() -> void:
	_loading.modulate.a = 1.0
	_loading.visible = true


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
		_start_loading()
		_invent_owner()


# --- The owner -------------------------------------------------------------

func _invent_owner() -> void:
	_owner_working = true
	_narrate("Somewhere under a Seoul overpass, someone is unrolling a tarp...")
	_typing_label.text = "The AI is inventing the tent's owner..."
	var gender: String = ["woman", "man"].pick_random()
	# The game decides their age range and how they look; the AI invents who they are.
	var look := Rules.pick_look(gender, Rules.pick_age_range(randf(), true), "", true)
	var result: Dictionary = await _ai.ask_json(Prompts.owner_messages(gender, look), _validate_owner.bind(gender, str(look["age_range"])), {"temperature": 0.9},
		{"purpose": "owner", "gender": gender, "look": look})
	_typing_label.text = ""
	if result.is_empty():
		_narrate("Couldn't invent the owner: %s" % _ai.last_error)
		_try_again.visible = true
		_end_loading()  # so the player can see why, and try again
		_owner_working = false
		return
	_owner = result
	_owner["gender"] = gender
	_owner["title"] = Prompts.OWNER_ADDRESS[gender]["title"]
	_owner["look"] = look
	_dress(_owner_node, look)
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Rules.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	await _name_cat()
	await _choose_look()
	if founding_regulars:
		await _make_founding_regulars()
	_show_look()
	_show_cat()
	await get_tree().process_frame  # let the tent draw before the loading screen fades
	_end_loading()
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


## A new bar's look: the AI chooses the tarp, the sign's style and Hangul, and a touch or
## two, from the game's options, to suit the owner and the name (plain, if it can't).
func _choose_look() -> void:
	_typing_label.text = "The AI is putting up the tarp..."
	_look_offer = {} if offer_every_look else Rules.look_offer()
	var look: Dictionary = await _ai.ask_json(
		Prompts.bar_look_messages(_owner, str(Game.bar["name"]), str(Game.bar.get("name_meaning", "")), _look_offer),
		_validate_bar_look, {"temperature": 0.8}, {"purpose": "bar_look", "bar_name": Game.bar["name"],
			"tarps": _look_offer.get("tarp", Rules.BAR_TARPS.keys()), "shapes": _look_offer.get("shape", Rules.TENT_SHAPES.keys())})
	_typing_label.text = ""
	if look.is_empty():
		look = Rules.default_bar_look()
	Game.bar["look"] = {"hangul": look["hangul"], "tarp": look["tarp"], "sign": look["sign"], "shape": look.get("shape", "classic"), "touches": look["touches"]}
	Game.save()
	var touches := PackedStringArray()
	for id in look["touches"]:
		touches.append(Rules.BAR_TOUCHES.get(id, id))
	var colour := str(look["tarp"]).replace("_", " and white ").replace("striped", "orange and cream stripes")
	var shape: String = Rules.TENT_SHAPES.get(look.get("shape", "classic"), "a tarp")
	_narrate("The tent: %s, in %s. A %s sign reading %s, and %s." % [shape, colour, look["sign"], look["hangul"],
		" and ".join(touches) if not touches.is_empty() else "not much else"])


func _validate_bar_look(data: Variant) -> String:
	return Rules.validate_bar_look(data, _look_offer)


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
	var cat_name := str(named["name"]) if not named.is_empty() else Rules.fallback_cat_name(randf(), taken)
	var cat_hangul := str(named.get("hangul", "")) if not named.is_empty() else str(Rules.CAT_HANGUL.get(cat_name, ""))
	_new_cat(cat_name, coat, personality, sex, cat_hangul)


func _new_cat(cat_name: String, coat: String, personality: String, sex: String, hangul: String = "") -> void:
	Game.bar["cat"] = {"name": cat_name, "coat": coat, "personality": personality, "sex": sex, "hangul": hangul}
	Game.save()


func _show_cat() -> void:
	_cat = Game.bar["cat"].duplicate()
	_paint_cat()
	_cat_node.tooltip_text = "%s, the tent's %s cat (%s)" % [_with_hangul(_cat), _cat["coat"], Rules.CAT_PERSONALITIES.get(_cat["personality"], "")]
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
	_waiting_who.clear()
	_skip_arrivals = 0
	_plan_regulars_tonight()
	_count_regulars()
	_chats.clear()
	_names_tonight.clear()
	_jobs_tonight.clear()
	_looks_tonight.clear()
	_last_orders = false
	_attending = null
	_night_open = true
	_next_arrival = _clock + Rules.next_arrival_gap(int(_clock), randf())
	_show_weather(Rules.weather_kind(_night_weather))
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
	_update_light()
	if _loading != null and _loading.visible:
		_loading.status = _typing_label.text
	_ambience.set_scene({"weather": _weather_kind, "people": _guests.size(), "cooking": not _kitchen.is_empty(),
		"open": _night_open, "minutes": int(_clock)})
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
	if strollers:
		_stroll_next -= minutes
		if _stroll_next <= 0.0:
			_stroll()
			_stroll_next = Rules.stroll_gap(int(_clock), randf())
	if cat_wanders and not _cat.is_empty():
		_cat_next -= minutes
		if _cat_next <= 0.0:
			_move_cat()
	if run_clock:
		# After 3am the clock runs on while the last customers finish up.
		_clock += minutes
		_update_clock_label()
		while not _regulars_due.is_empty() and _clock >= float(_regulars_due[0]["time"]):
			var due: Dictionary = _regulars_due.pop_front()
			_arrive(float(due["time"]), str(due["id"]))
			_skip_arrivals += 1  # a regular instead of a newcomer: the night stays as busy
		while _clock >= _next_arrival and _next_arrival < Rules.LAST_ARRIVAL_MINUTES:
			if _skip_arrivals > 0:
				_skip_arrivals -= 1
			else:
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
func _arrive(when: float, regular_id: String = "") -> void:
	_waiting.append(when)
	_waiting_who.append(regular_id)
	_stats.arrived += 1
	_update_info()


## Someone who's waited too long with every stool taken gives up and walks on.
func _give_up_waiting() -> void:
	var gone := 0
	while not _waiting.is_empty() and _free_seats().is_empty() and _clock - float(_waiting[0]) > Rules.GIVE_UP_MINUTES:
		_waiting.pop_front()
		_waiting_who.pop_front()
		_stats.walked_past += 1
		_narrate("Someone peeks under the tarp, sees every stool taken, and walks on.")
		_walk_past(gone * 1.5)  # if several give up at once, they don't walk in a clump
		gone += 1
		_update_info()


## Someone walking along the street, not coming in: a dark figure on the pavement in front
## of the tent, at their own pace, with an umbrella if it's raining or snowing.
func _stroll() -> void:
	_strollers += 1
	var from_left := randi() % 2 == 0
	var shade: Color = CUSTOMER_COLORS.pick_random().darkened(0.55)
	var person := _person(_stage, Vector2(OFFSCREEN_LEFT_X if from_left else OFFSCREEN_RIGHT_X, STROLL_Y), shade)
	person.name = "Stroller%d" % _strollers
	_dress(person, _street_look())
	person.z_index = 1  # in front of the counter and stools
	person.modulate = Color(0.42, 0.42, 0.5, 0.92)  # darker: out in the street, in front of the light
	if _weather_kind in ["drizzle", "rain", "snow"]:
		_umbrella(person)
	var tween := person.create_tween()
	tween.tween_property(person, "position:x", OFFSCREEN_RIGHT_X if from_left else OFFSCREEN_LEFT_X, _scaled(randf_range(6.0, 10.0)))
	tween.tween_callback(person.queue_free)


## An umbrella held over someone's head: a domed canopy on a shaft (lots of Seoul's are clear).
const UMBRELLA_COLOURS := [Color(0.85, 0.9, 1.0, 0.35), Color("26252e"), Color("2c3a5c"), Color("7a2a2a"), Color("8a7a2a")]

func _umbrella(person: Control) -> void:
	_rect(person, Vector2(39, -40), Vector2(2, 50), Color("55536b"))  # the shaft, down to the hand
	var canopy := Polygon2D.new()
	canopy.name = "Umbrella"
	var points := PackedVector2Array()
	for step in 13:
		var angle: float = PI + PI * step / 12.0
		points.append(Vector2(40 + cos(angle) * 64, -18 + sin(angle) * 30))
	for rib in range(3, -1, -1):  # back along a scalloped rim, dipping between the ribs
		points.append(Vector2(-24 + rib * 32 + 16, -12))
		if rib > 0:
			points.append(Vector2(-24 + rib * 32, -18))
	canopy.polygon = points
	canopy.color = UMBRELLA_COLOURS.pick_random()
	person.add_child(canopy)
	_rect(person, Vector2(38, -52), Vector2(4, 6), Color("55536b"))  # the tip


## A passer-by in the street: they slow down at the tent, look in, and carry on. Runs by
## itself; the owner doesn't stop for it.
func _walk_past(delay: float) -> void:
	_passers_by += 1
	var from_left := randi() % 2 == 0
	var person := _person(_stage, Vector2(OFFSCREEN_LEFT_X if from_left else OFFSCREEN_RIGHT_X, CUSTOMER_Y), CUSTOMER_COLORS.pick_random().darkened(0.35))
	person.name = "PasserBy%d" % _passers_by
	_dress(person, _street_look())
	person.modulate = Color(0.7, 0.7, 0.78)
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
	_fade_regulars()
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
	var lonely := _left_alone_longest()
	if lonely != null or _chat_possible():
		_stats.free_turns += 1  # (counted only when there's someone to talk to, not every idle frame)
	if _chat_possible():
		_stats.chat_chances += 1
		if randf() < chance:
			_counter_chat()
			return
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
	var regular := _regular(str(_waiting_who.pop_front()) if not _waiting_who.is_empty() else "")
	_greeting = true
	_stats.greet_waits.append(_clock - turned_up)  # how long they waited for the owner
	var guest := Guest.new()
	guest.quick_greeting = Rules.quick_greeting(_waiting.size(), _guests.size())
	guest.seat = _free_seats().pick_random()
	guest.arrived = Rules.clock_text(int(_clock))
	guest.arrived_minutes = int(_clock)
	guest.moment = {"day": _night_day, "time": guest.arrived, "weather": _night_weather}
	_show("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	var customer := {}
	var look := {}
	if not regular.is_empty():
		# A regular: they're known, so not reinvented.
		_narrate("%s. %s" % [guest.arrived, _back_text(regular)])
		customer = await _regular_tonight(regular, guest)
		look = customer["look"]
	else:
		_narrate("%s. Someone ducks under the tarp." % guest.arrived)
		customer = await _new_customer(guest)
		look = customer.get("look", {})
	if customer.is_empty():
		_narrate("Nobody came in after all. (%s)" % _ai.last_error)
		_greeting = false
		_task_done()
		return
	_names_tonight.append(str(customer["name"]))
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
	_dress(guest.node, look)
	(guest.node.get_node("Tag") as Label).text = _name_label(customer)
	_guests.append(guest)
	_refresh_tags()
	_ambience.play("scrape", 1.0, 1.0)  # pulling up a stool
	_greeting = false
	_stats.peak_seated = maxi(_stats.peak_seated, _guests.size())
	_update_info()
	if regular.is_empty():  # a regular's look is known by now
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
	guest.first_order = items.duplicate()
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


## Someone new: the AI invents them, in two steps (name and gender, then the rest), to fit the
## look and age range the game decides. {} if the AI couldn't.
func _new_customer(guest: Guest) -> Dictionary:
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
	var look := {}
	if not who.is_empty():
		_typing_label.text = "%s is coming down the street..." % who["name"]
		# The game decides their age range and look (by the weather); the AI invents someone
		# who'd look like that.
		look = Rules.pick_look(str(who["gender"]), Rules.pick_age_range(randf()), _weather_kind)
		customer = await _ai.ask_json(
			Prompts.customer_messages(_night_day, guest.arrived, _night_weather, false, str(who["name"]), str(who["gender"]), _jobs_tonight, _looks_tonight.slice(-VARIETY_LOOKS), look),
			_validate_customer_details.bind(str(look["age_range"])), {"temperature": 0.9},
			{"purpose": "customer", "name": who["name"], "gender": who["gender"], "look": look})
	_typing_label.text = ""
	if customer.is_empty():
		return {}
	customer["name"] = who["name"]
	customer["hangul"] = str(who.get("hangul", ""))
	customer["gender"] = who["gender"]
	customer["look"] = look
	return customer


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
	if now.any(func(id): return Menu.find(id).get("kind", "") == "drink"):
		_ambience.play("pour")
		_ambience.play("clink", 1.0, 0.8)
	elif not now.is_empty():
		_ambience.play("clink", 0.55)  # a bowl of odeng or rice set down
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
	_ambience.play("clink", 0.55)  # a bowl set down
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
	_ambience.play("cash")
	_ambience.play("scrape", 0.9, 0.5)
	_clear_table(guest)
	_walk_out(guest)  # off they go; the owner gets on with the next thing
	_guests.erase(guest)
	_refresh_tags()
	_leave_chats(guest)
	if _attending == guest:
		_attending = null
	if _cat_with == guest:
		_move_cat()  # they got up, so the cat's off
	await _after_visit(guest)  # what they'll remember, and whether they'll be back
	_task_done()


## A spell of conversation with one guest: an exchange or two, cut short if something more
## urgent comes up (but never between the owner's line and the customer's reply).
func _talk(guest: Guest) -> void:
	_owner_working = true
	_attend(guest, true)
	var remembered: bool = not guest.customer.get("regular", {}).get("memories", []).is_empty()
	guest.topic = Rules.pick_owner_topic(randf(), guest.food_news or not _food_coming(guest).is_empty(), _cat_here(guest), guest.topic, remembered)
	guest.food_news = false
	# When it's busy, a single exchange, so the voice comes round to everyone (and leaves room
	# for customers to chat) sooner.
	await _converse(guest, 1 if _guests.size() >= Rules.BUSY_COUNTER else randi_range(1, 2), true)
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
	direction = (direction + " " + _address_note(guest)).strip_edges()
	var address := _address(null, guest) if owner_speaks else _address(guest, null)
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := guest.version
		reply = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, owner_speaks, direction, _cat_prompt()),
			_validate_line.bind(speaker, alias, guest.order, [str(_owner["name"]), str(guest.customer["name"])], _cat_fact(), address), {"temperature": 0.85},
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
				"The customer is getting up to go: see them off. " + _address_note(guest), _cat_prompt()),
			_validate_line.bind(owner_name, str(_owner["title"]), guest.order, [owner_name, speaker], _cat_fact(), _address(null, guest)), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": true, "first": false, "last": false})
		if not send_off.is_empty():
			await _say(guest, true, str(send_off["line"]))
			guest.line += 1
	# Someone they were chatting with gets a goodbye too.
	var chat := _chat_of(guest)
	var still_here: Array = [] if chat == null else chat.people.filter(func(g): return g != guest and _guests.has(g))
	var partners: Array = still_here.map(func(g): return str(g.customer["name"]))
	var direction := "This is the customer's last line: they're paying up and heading back out into the night."
	if not still_here.is_empty():
		# By name only if it was said in their chat: otherwise as they look.
		direction += " They also say goodbye to %s, who they were chatting with." % " and ".join(PackedStringArray(still_here.map(func(g): return _known_as(g, chat))))
	_typing_label.text = "%s is reaching for their wallet..." % speaker
	var reply: Dictionary = await _ai.ask_json(
		Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, false, direction + " " + _address_note(guest), _cat_prompt()),
		_validate_line.bind(speaker, "", guest.order, [owner_name, speaker] + partners, _cat_fact(), _address(guest, null)), {"temperature": 0.85},
		{"purpose": "line", "title": _owner["title"], "owner_speaks": false, "first": false, "last": true})
	_typing_label.text = ""
	if not reply.is_empty():
		await _say(guest, false, str(reply["line"]))
		guest.line += 1
	for other in (chat.people if chat != null else []):
		if other != guest and _guests.has(other):
			var leaver := _known_as(guest, chat)
			other.transcript.append({"action": "%s, who they were chatting with, says goodbye and leaves." % (leaver.substr(0, 1).to_upper() + leaver.substr(1))})


## How someone in a chat is known to the others: by name if it's been said there (their full
## name or their given name), otherwise as anyone can see them ("the woman in the beige
## trench coat"), since nobody knows a stranger's name.
func _known_as(guest: Guest, chat: Chat) -> String:
	var full := str(guest.customer["name"])
	# Founding regulars have known each other for years.
	if chat != null and bool(guest.customer.get("regular", {}).get("founding", false)):
		for other in chat.people:
			if other != guest and bool(other.customer.get("regular", {}).get("founding", false)):
				return full
	var parts := full.split(" ", false)
	var given := " ".join(parts.slice(1)) if parts.size() > 1 else full
	if chat != null:
		for entry in chat.transcript:
			var text := str(entry.get("text", "")).to_lower()
			if text.contains(full.to_lower()) or text.contains(given.to_lower()):
				return full
	return Rules.seen_as(guest.customer)


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
	var said := ""  # the last line said in the chat, and who by
	var said_by := ""
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
		said = line
		said_by = speaker
		lines -= 1
		lines_said += 1
		for person in chat.people:
			person.chatted = true
			person.chat_lines.append({"speaker": speaker, "text": line})
		# Something more urgent can cut the chat short, but only once it's had a few lines.
		if _urgent() and lines_said >= CHAT_LINES_BEFORE_INTERRUPTING:
			break
	if said != "":
		_remember_chat(chat, said)
	# Each person's own conversation with the owner hears about it, so the owner can pick it up.
	if said != "":
		for guest in chat.people:
			# Named only if names were said in the chat: otherwise as they look.
			var others: Array = chat.people.filter(func(g): return g != guest).map(func(g): return _known_as(g, chat))
			var by := "they"
			if said_by == str(_owner["name"]):
				by = said_by
			elif said_by != str(guest.customer["name"]):
				for g in chat.people:
					if str(g.customer["name"]) == said_by:
						by = _known_as(g, chat)
			guest.transcript.append({"action": "%s has been chatting with %s at the counter. The last thing said there (by %s): \"%s\"" % [guest.customer["name"], " and ".join(PackedStringArray(others)), by, said]})
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
	var speaking: Guest = _guest_named(speaker)
	var listening: Guest = _guest_named(addressee)
	if first and speaking != null and listening != null and not _friend(speaking, listening).is_empty():
		direction = "They've met here before: they pick up where they left off."
	# Two regulars who've got to know each other: is it time for "can I call you eonni?"
	var moment_term := _friendly_moment(speaking, listening)
	if moment_term != "":
		direction = "%s has got to know %s over their chats here, and asks if they can drop the formalities: can they call them %s?" % [speaker, addressee, moment_term.capitalize()]
	var close := moment_term != "" or (speaking != null and listening != null and _close(speaking, listening))
	direction += " " + _chat_notes(chat) + " " + Rules.address_text(speaker, _addressee(speaking), addressee, _addressee(listening), close)
	var address := _address(speaking, listening, close)
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := _chat_version(chat)
		tables = chat.people.map(func(person): return _table_text(person))
		reply = await _ai.ask_json(
			Prompts.counter_chat_messages(_owner, chat.owner_in, people, tables, moment, chat.transcript, speaker, addressee, direction, _cat_prompt()),
			_validate_line.bind(speaker, str(_owner["title"]) if owner_speaks else "", items, names, _cat_fact(), address), {"temperature": 0.85},
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
	_show("[color=#%s][b]%s to %s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(to), Rules.colour_terms(_esc(line), names)])
	var listener_colour := OWNER_TEXT if addressed == null else addressed.color.lightened(0.35)
	_give_time_to_read(line, _say_in_bubble(_owner_node if guest == null else guest.node, _owner_node if addressed == null else addressed.node,
		_to_label(line, guest, addressed, to), listener_colour, colour, line))
	if moment_term != "" and guest != null and addressed != null:
		_make_close(guest, addressed, moment_term)
	return line


## What the game knows about the chatters who've met before, for the chat's prompt.
func _chat_notes(chat: Chat) -> String:
	var notes := PackedStringArray()
	for i in chat.people.size():
		for j in range(i + 1, chat.people.size()):
			var friend := _friend(chat.people[i], chat.people[j])
			if friend.is_empty():
				continue
			var note := "%s and %s have chatted here before (%d %s)" % [chat.people[i].customer["name"], chat.people[j].customer["name"],
				int(friend.get("meetings", 1)), "time" if int(friend.get("meetings", 1)) == 1 else "times"]
			note += ", and know each other's names." if bool(friend.get("names", false)) else ", but haven't swapped names."
			if str(friend.get("last", "")) != "":
				note += " The last thing said between them: \"%s\"" % friend["last"]
			if bool(friend.get("close", false)):
				note += " They're close now."
			notes.append(note)
	return " ".join(notes)


## The bubble's header: the term the line used for its listener, then who they are
## ("이모 Imo (박미숙 Park Mi-sook ♀ (Ajumma))"), or just who they are.
func _to_label(line: String, speaker: Guest, listener: Guest, label: String) -> String:
	var term := _term_used(line, speaker, listener)
	if term == "":
		return label
	return "%s %s (%s)" % [Rules.TERMS[term]["hangul"], term.capitalize(), label]


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
	if randf() < 0.25:
		_ambience.play("meow")
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
		(_cat_node.get_node("Tag") as Label).scale.x = _cat_node.scale.x  # turned back, so the name still reads
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
	var tag := Label.new()  # its name, above it (centred on the cat, so it stays put when it turns)
	tag.name = "Tag"
	tag.position = Vector2(-77, -24)
	tag.size = Vector2(200, 18)
	tag.pivot_offset = tag.size / 2
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	_cat_node.add_child(tag)


func _paint_cat() -> void:
	(_cat_node.get_node("Tag") as Label).text = _cat_label()
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
	_face(guest.node, true)
	guest.walk = create_tween()
	guest.walk.tween_property(guest.node, "position:x", SEAT_X[guest.seat] - PERSON_WIDTH / 2, _scaled(1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	guest.walk.tween_callback(_face.bind(guest.node, false))  # sat down: facing the counter


func _walk_out(guest: Guest) -> void:
	if guest.walk != null and guest.walk.is_valid():
		guest.walk.kill()  # if they hadn't quite sat down yet
	_face(guest.node, true)  # up, and turning to go
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
	_show("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), Rules.colour_terms(_esc(text), [_owner["name"], guest.customer["name"]])])
	if owner_speaks:
		_give_time_to_read(text, _say_in_bubble(_owner_node, guest.node, _to_label(text, null, guest, _name_label(guest.customer)), guest.color.lightened(0.35), colour, text))
	else:
		_give_time_to_read(text, _say_in_bubble(guest.node, _owner_node, _to_label(text, guest, null, _owner_label()), OWNER_TEXT, colour, text))


func _narrate(text: String) -> void:
	_show("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(text)])


## After a line is shown, the next one waits until there's been time to read it (longer
## lines, longer). Meanwhile everything else carries on, including the AI writing the next
## line, so the gap is whichever is longer, the reading or the AI's thinking, not both.
## With "Reading pauses" off (the default for now), lines come as fast as the AI writes them.
## bubble_seconds: how long the line's speech bubble takes to page through. Bubbles don't hold
## the next line up: with one voice for the whole tent, waiting to read every bubble left no
## time for customers to chat (and doubled the wait for the owner), so only Reading pauses do.
func _give_time_to_read(text: String, _bubble_seconds: float = 0.0) -> void:
	if not _reading_toggle.button_pressed:
		_read_until = 0
		return
	var seconds := clampf(1.0 + text.length() * 0.035, 1.5, 7.0)
	_read_until = Time.get_ticks_msec() + int(_scaled(seconds) * 1000.0)


## Shows a line in a speech bubble over the speaker, a page at a time, with who it's to and
## a line to them. Returns how long it'll take (already scaled), or 0 with bubbles off.
func _say_in_bubble(speaker: Control, listener: Control, to_label: String, to_colour: Color, colour: Color, text: String) -> float:
	if not bubbles or not _bubbles_toggle.button_pressed or speaker == null or not is_instance_valid(speaker):
		return 0.0
	# A speaker's new line replaces their last bubble; others' recent lines stay up, dimmed, so
	# an exchange reads like a comic (and two conversations can show at once); older ones go.
	_bubbles_shown = _bubbles_shown.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	for old in _bubbles_shown:
		if old.speaker == speaker:
			old.queue_free()
	_bubbles_shown = _bubbles_shown.filter(func(b): return not b.is_queued_for_deletion())
	while _bubbles_shown.size() > MAX_BUBBLES - 1:
		_bubbles_shown.pop_front().queue_free()
	for old in _bubbles_shown:
		old.dim()
	var bubble := Bubble.new()
	bubble.name = "Bubble"
	bubble.speaker = speaker
	bubble.listener = listener if listener != null and is_instance_valid(listener) else null
	bubble.colour = colour
	bubble.stage_width = STAGE_SIZE.x
	_bubble_layer.add_child(bubble)
	var pages := Rules.bubble_pages(text)
	var longest := 0
	for page in pages:
		longest = maxi(longest, page.length())
	bubble.setup("→ %s" % to_label, to_colour, longest > Rules.BUBBLE_SHORT)
	_bubbles_shown.append(bubble)
	var total := 0.0
	for page in pages:
		total += _scaled(Rules.page_seconds(page))
	_page_through(bubble, pages)
	return total


const MAX_BUBBLES := 3  # the newest bright, the two before it dimmed


func _page_through(bubble: Bubble, pages: PackedStringArray) -> void:
	for page in pages:
		if not is_instance_valid(bubble):
			return
		bubble.show_page(page)
		await get_tree().create_timer(_scaled(Rules.page_seconds(page))).timeout
	# Left up a while after the last page (dimmed once someone else speaks), then it fades.
	await get_tree().create_timer(_scaled(6.0)).timeout
	if is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
		var fade := bubble.create_tween()
		fade.tween_property(bubble, "modulate:a", 0.0, 0.6)
		fade.tween_callback(bubble.queue_free)


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
	var named := _with_hangul(customer)
	var label := named if symbol == "" else "%s %s" % [named, symbol]
	var mark := Regulars.closeness_mark(customer.get("regular", {}))  # ☆ ★ ★★ for regulars
	return label if mark == "" else "%s %s" % [label, mark]


## The cat's name as shown on screen, like everyone's: "나비 Nabi ♀".
func _cat_label() -> String:
	var symbol := "♀" if str(_cat.get("sex", "")) == "she" else ("♂" if str(_cat.get("sex", "")) == "he" else "")
	var named := _with_hangul(_cat)
	return named if symbol == "" else "%s %s" % [named, symbol]


## A name with its Hangul first, like the sign: "김지호 Kim Ji-ho" (just the name if there's none).
func _with_hangul(person: Dictionary) -> String:
	var hangul := str(person.get("hangul", ""))
	return str(person["name"]) if hangul == "" else "%s %s" % [hangul, person["name"]]


## The owner's name as shown on screen: "Park Mi-sook ♀ (Ajumma)".
func _owner_label() -> String:
	if _owner.is_empty():
		return "The owner"
	var symbol := gender_symbol(_owner.get("gender", ""))
	if symbol == "":
		return _owner_display()
	return "%s %s (%s)" % [_with_hangul(_owner), symbol, _owner["title"]]


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
		t += "[b]%s[/b], %s, %s\n" % [_esc(_cat_label()), _cat["coat"], _cat["personality"]]
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(Rules.cat_text(str(_cat["name"]), _cat_spot, _cat_with_name()))]
	var seated := _guests.duplicate()
	seated.sort_custom(func(a, b): return a.seat < b.seat)
	if not seated.is_empty():
		t += "\n[color=#%s][b]AT THE COUNTER[/b][/color]\n" % accent
	for guest in seated:
		var c: Dictionary = guest.customer
		var hover := _remembered_text(c.get("regular", {}))
		var named := "[b]%s[/b]" % _esc(_name_label(c))
		if hover != "":
			named = "[hint=%s]%s[/hint]" % [hover, named]  # hover: what the owner remembers
		t += "[color=#%s]%s[/color], %s, %s  [color=#%s](stool %d)[/color]\n" % [guest.color.lightened(0.35).to_html(false), named, c["age"], _esc(c["job"]), muted, guest.seat + 1]
		var known: Dictionary = c.get("regular", {})
		if not known.is_empty():
			var status := "%s %s · %s visit" % [Regulars.closeness_mark(known), Regulars.closeness_word(known), Regulars.ordinal(int(known["visits"]) + 1)]
			if str(known.get("since", "")) != "":
				status = "%s %s · coming %s, %s" % [Regulars.closeness_mark(known), Regulars.closeness_word(known), known["since"], known.get("habit", "")]
			elif known.has("nights_ago"):
				status += " · last in %s" % Regulars.nights_ago_text(int(known["nights_ago"]))
			if not known.get("usual", []).is_empty():
				status += " · usual: %s" % Rules.item_names(known["usual"])
			t += "[color=#%s]%s[/color]\n" % [OWNER_TEXT.to_html(false), _esc(status)]
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

func _validate_owner(data: Variant, gender: String, age_range: String = "") -> String:
	return Rules.validate_owner(data, gender, age_range)


func _validate_bar_name(data: Variant) -> String:
	return Rules.validate_bar_name(data)


func _validate_customer_name(data: Variant, taken: Array, gender: String) -> String:
	return Rules.validate_customer_name(data, taken, gender)


func _validate_customer_details(data: Variant, age_range: String = "") -> String:
	return Rules.validate_customer_details(data, age_range)


func _validate_order(data: Variant, max_mains: int, max_drinks: int) -> String:
	return Rules.validate_order(data, max_mains, max_drinks)


func _validate_extra_order(data: Variant, table: Array) -> String:
	return Rules.validate_extra_order(data, table)


func _validate_line(data: Variant, speaker: String, alias: String, items: Array, names: Array, cat: Dictionary, address: Dictionary = {}) -> String:
	return Rules.validate_line(data, speaker, alias, items, names, cat, address)


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

	_bubbles_toggle = CheckBox.new()
	_bubbles_toggle.name = "BubblesToggle"
	_bubbles_toggle.text = "Bubbles"
	_bubbles_toggle.button_pressed = true
	_bubbles_toggle.tooltip_text = "Speech bubbles over whoever's talking, with a line to who they're talking to."
	bar.add_child(_bubbles_toggle)

	_sound_toggle = CheckBox.new()
	_sound_toggle.name = "SoundToggle"
	_sound_toggle.text = "Sound"
	_sound_toggle.button_pressed = _ambience.enabled  # on unless it was turned off last time
	_sound_toggle.tooltip_text = "The tent's background sound: the street, the weather, the stove and the counter."
	_sound_toggle.toggled.connect(_ambience.set_enabled)
	bar.add_child(_sound_toggle)
	var volume := HSlider.new()
	volume.name = "SoundVolume"
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = _ambience.volume
	volume.custom_minimum_size = Vector2(120, 0)
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.tooltip_text = "How loud the background sound is."
	volume.value_changed.connect(_ambience.set_volume)
	bar.add_child(volume)
	var music_label := Label.new()
	music_label.text = "Music"
	music_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(music_label)
	var music := HSlider.new()
	music.name = "MusicVolume"
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = _music.volume
	music.custom_minimum_size = Vector2(120, 0)
	music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music.tooltip_text = "Arirang, now and then through the night (all the way down for none)."
	music.value_changed.connect(_music.set_volume)
	bar.add_child(music)

	# Godot's default tick boxes are dark: on this background an empty one disappears.
	for toggle in [_reading_toggle, _stats_toggle, _sound_toggle, _bubbles_toggle]:
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
	_sky = _rect(stage, Vector2.ZERO, STAGE_SIZE, Color("3c3a72"))  # the night sky, changing with the hour
	_sky.name = "Sky"
	_weather_back = _layer(stage, "WeatherBack")
	_rect(stage, Vector2(0, 0), Vector2(w, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(40, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(w - 84, 36), Vector2(44, 344), Color("1f1e36"))
	_glow = _rect(stage, Vector2(110, 110), Vector2(w - 220, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_glow.name = "Glow"
	_rect(stage, Vector2(0, 372), Vector2(w, 8), Color("2a2840"))  # wet street
	var tent_from := stage.get_child_count()  # from here on is the tent (the cat and sign aside)

	for bulb_x in [620.0, 1250.0]:
		var bulb := Control.new()  # hung from the top of its wire, so it swings from there
		bulb.position = Vector2(bulb_x, 110)
		bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bulb)
		_rect(bulb, Vector2(-1, 0), Vector2(2, 36), Color("55536b"))  # bulb wire
		_bulb_lights.append(_rect(bulb, Vector2(-8, 36), Vector2(16, 16), OWNER_TEXT))  # the bulb
		_bulbs.append(bulb)
	_decor_back = _layer(stage, "DecorBack")
	_build_fridge(stage)

	_owner_node = _person(stage, Vector2(OWNER_HOME_X, OWNER_Y), OWNER_COLOR)
	_owner_node.name = "Owner"
	_owner_tag = _owner_node.get_node("Tag") as Label
	_owner_tag.z_index = 3  # their head is just under the tarp: the name goes in front of it
	_owner_node.visible = false

	_rect(stage, Vector2(100, 250), Vector2(w - 182, 18), Color("8a5a33"))  # counter top
	_rect(stage, Vector2(120, 268), Vector2(w - 222, 104), Color("5c3820"))  # counter front
	_rect(stage, Vector2(104, 244), Vector2(236, 6), Color("3a3946"))  # the stove
	_rect(stage, Vector2(130, 241), Vector2(40, 3), Color("e8833a"))  # a flame
	_build_odeng_pot(stage)
	_decor_counter = _layer(stage, "DecorCounter")

	# What's cooking (and what's ready to carry over), at the stove.
	_stove_row = HBoxContainer.new()
	_stove_row.name = "Stove"
	_stove_row.position = Vector2(176, 207)  # beside the odeng pot
	_stove_row.size = Vector2(160, 34)
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

	_roof = Polygon2D.new()
	_roof.name = "Tarp"
	_roof.polygon = PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])
	_roof.color = ACCENT
	_build_cat(stage)
	stage.add_child(_roof)
	_roof_stripes = _layer(stage, "TarpStripes")
	_roof_edge = _rect(stage, Vector2(22, 112), Vector2(w - 44, 10), Color("c8612a"))
	_decor_roof = _layer(stage, "DecorRoof")
	for k in range(tent_from, stage.get_child_count()):
		var piece := stage.get_child(k) as CanvasItem
		if piece != _owner_node and piece != _cat_node:
			_tent.append(piece)
	_glow.visible = false
	for piece in _tent:
		piece.visible = false  # until the bar's look is known: no template tent while the AI thinks
	_build_sign(stage)
	_weather_front = _layer(stage, "WeatherFront")
	_weather_front.z_index = 2  # in front of everyone
	_bubble_layer = _layer(stage, "Bubbles")
	_bubble_layer.z_index = 4  # in front of the tarp, the weather and the owner's name


## The drinks fridge at the back, by the stove (the owner's station), behind the owner: a
## glass door lit from inside, with shelves of soju, beer and makgeolli (only what's on the
## menu). Its shelves sit high, so the odeng pot in front doesn't hide them.
func _build_fridge(stage: Control) -> void:
	var fridge := Control.new()
	fridge.name = "Fridge"
	fridge.position = Vector2(186, 116)  # just right of the odeng pot
	fridge.size = Vector2(92, 134)
	fridge.mouse_filter = Control.MOUSE_FILTER_STOP
	fridge.tooltip_text = "The drinks fridge: soju, beer and makgeolli, ice cold."
	stage.add_child(fridge)
	_rect(fridge, Vector2.ZERO, Vector2(92, 134), Color("d8dce4"))  # the cabinet
	_rect(fridge, Vector2.ZERO, Vector2(92, 14), Color("c8443a"))  # the header strip
	_rect(fridge, Vector2(6, 18), Vector2(80, 112), Color("23344a"))  # inside
	_rect(fridge, Vector2(6, 18), Vector2(80, 112), Color(0.9, 0.96, 1.0, 0.18))  # its light
	var shelves := [
		["soju", Vector2(7, 20), 6],  # green bottles
		["beer", Vector2(10, 16), 5],  # gold cans
		["makgeolli", Vector2(9, 20), 5],  # white bottles
	]
	for row in shelves.size():
		var drink: String = shelves[row][0]
		var shape: Vector2 = shelves[row][1]
		var count: int = shelves[row][2]
		var floor_y := 18.0 + (row + 1) * 26.0
		var colour := Color(str(Menu.find(drink)["color"]))
		var gap := (80.0 - count * shape.x) / (count + 1)
		for k in count:
			var x := 6.0 + gap + k * (shape.x + gap)
			_rect(fridge, Vector2(x, floor_y - shape.y), shape, colour)
			if drink != "beer":  # a neck and a cap on the bottles
				_rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 6), Vector2(4, 6), colour)
				_rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 8), Vector2(4, 2), Color("2e7a44") if drink == "makgeolli" else Color("d8dce4"))
		_rect(fridge, Vector2(6, floor_y), Vector2(80, 2), Color("9aa6b4"))  # the shelf
	var sheen := Polygon2D.new()  # light catching the glass
	sheen.polygon = PackedVector2Array([Vector2(14, 18), Vector2(34, 18), Vector2(16, 130), Vector2(6, 130), Vector2(6, 60)])
	sheen.color = Color(1, 1, 1, 0.1)
	fridge.add_child(sheen)
	_rect(fridge, Vector2(80, 40), Vector2(3, 40), Color("8a8c96"))  # the handle


## The odeng pot, simmering on the stove all night: fish cake skewers poking out of the
## broth, and steam curling up off it.
func _build_odeng_pot(stage: Control) -> void:
	var pot := Control.new()
	pot.name = "OdengPot"
	pot.position = Vector2(108, 212)
	pot.mouse_filter = Control.MOUSE_FILTER_STOP
	pot.size = Vector2(60, 32)
	pot.tooltip_text = "Odeng: %s" % Menu.find("odeng")["desc"]
	stage.add_child(pot)
	for k in 4:  # skewers, at a slant
		var skewer := _rect(pot, Vector2(10 + k * 12, -14 + (k % 2) * 4), Vector2(2, 22), Color("d8c49a"))
		skewer.rotation = -0.2 + k * 0.12
		_rect(pot, Vector2(7 + k * 12, -2 + (k % 2) * 4), Vector2(9, 8), Color("c9a26b"))  # a folded fish cake
	_rect(pot, Vector2(0, 6), Vector2(60, 26), Color("8a8c96"))  # the pot (a square metal one)
	_rect(pot, Vector2(-3, 4), Vector2(66, 4), Color("b0b2bc"))  # its rim
	_rect(pot, Vector2(2, 8), Vector2(56, 3), Color("c9a26b", 0.8))  # the broth
	for k in 3:  # steam, rising and fading, one puff after another
		var puff := _rect(pot, Vector2(20 + k * 10, 0), Vector2(10, 10), Color(1, 1, 1, 0.0))
		var rise := puff.create_tween().set_loops()
		rise.tween_interval(k * 0.9)
		rise.tween_property(puff, "position", Vector2(14 + k * 12, -46), 2.7).from(Vector2(20 + k * 10, 0))
		rise.parallel().tween_property(puff, "color:a", 0.0, 2.7).from(0.3)


## An empty full-stage layer for things added later (weather, the bar's touches).
func _layer(stage: Control, layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.size = STAGE_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(layer)
	return layer


# --- How the tent and the night look ------------------------------------------------

## The sign over the tarp: the name in Hangul, big, with the romanised name under it.
func _build_sign(stage: Control) -> void:
	_sign = Control.new()
	_sign.name = "Sign"
	_sign.position = Vector2(STAGE_SIZE.x / 2 - 210, 46)
	_sign.size = Vector2(420, 62)
	_sign.mouse_filter = Control.MOUSE_FILTER_STOP
	_sign.visible = false
	stage.add_child(_sign)
	_sign_board = _rect(_sign, Vector2.ZERO, _sign.size, Color("7a5230"))
	_sign_hangul = Label.new()
	_sign_hangul.name = "SignHangul"
	_sign_hangul.position = Vector2(0, 2)
	_sign_hangul.size = Vector2(420, 38)
	_sign_hangul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign_hangul.add_theme_font_size_override("font_size", 28)
	_sign.add_child(_sign_hangul)
	_sign_english = Label.new()
	_sign_english.name = "SignEnglish"
	_sign_english.position = Vector2(0, 38)
	_sign_english.size = Vector2(420, 20)
	_sign_english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign_english.add_theme_font_size_override("font_size", 13)
	_sign.add_child(_sign_english)


## The bar's look (saved with it): tarp, sign and touches. Bars from before looks get a
## plain one.
func _show_look() -> void:
	var look: Dictionary = Game.bar.get("look", {})
	if look.is_empty():
		look = Rules.default_bar_look()
	_glow.visible = true
	for piece in _tent:
		piece.visible = true
	var tarp: Array = Rules.BAR_TARPS.get(look["tarp"], Rules.BAR_TARPS["orange"])
	var colour := Color(tarp[0])
	var shape := str(look.get("shape", "classic"))
	_roof.polygon = _tent_shape(shape)
	_roof.color = colour
	_roof_edge.color = colour.darkened(0.2)
	_roof_edge.visible = shape != "awning"
	_clear(_roof_stripes)
	var w := STAGE_SIZE.x
	if str(tarp[1]) != "":  # stripes, cut to the shape of the cover
		var stripes := 14
		for k in stripes:
			var a := 22 + (k + 0.25) / stripes * (w - 44)
			var b := 22 + (k + 0.6) / stripes * (w - 44)
			var band := PackedVector2Array([Vector2(a, 0), Vector2(b, 0), Vector2(b, 140), Vector2(a, 140)])
			for piece in Geometry2D.intersect_polygons(band, _roof.polygon):
				var stripe := Polygon2D.new()
				stripe.polygon = piece
				stripe.color = Color(tarp[1])
				_roof_stripes.add_child(stripe)
	match shape:
		"scalloped":  # a row of scallops hanging from the front edge
			for x in range(22, int(w) - 22, 52):
				var scallop := Polygon2D.new()
				var points := PackedVector2Array()
				for step in 9:
					var t: float = step / 8.0
					points.append(Vector2(x + t * 52, 122 + sin(t * PI) * 14))
				scallop.polygon = points
				scallop.color = colour.darkened(0.2)
				_roof_stripes.add_child(scallop)
		"awning":  # a zigzag valance under the flat awning
			for x in range(22, int(w) - 22, 40):
				var tooth := Polygon2D.new()
				tooth.polygon = PackedVector2Array([Vector2(x, 112), Vector2(x + 40, 112), Vector2(x + 20, 130)])
				tooth.color = Color(tarp[1]) if str(tarp[1]) != "" else colour.darkened(0.25)
				_roof_stripes.add_child(tooth)
	var style: Array = Rules.SIGN_STYLES.get(look["sign"], Rules.SIGN_STYLES["wood"])
	_sign_board.color = Color(style[0])
	for label in [_sign_hangul, _sign_english]:
		label.add_theme_color_override("font_color", Color(style[1]))
		if look["sign"] == "neon":  # a glowing tube: a soft halo round the letters
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_color_override("font_outline_color", Color(style[1]).darkened(0.5))
		else:
			label.add_theme_constant_override("outline_size", 0)
	_sign_hangul.text = str(look["hangul"])
	_sign_english.text = str(Game.bar.get("name", "")).to_upper()
	_sign.tooltip_text = "%s · %s (%s)" % [look["hangul"], Game.bar.get("name", ""), Game.bar.get("name_meaning", "")]
	_sign.visible = true
	for layer in [_decor_back, _decor_counter, _decor_roof]:
		_clear(layer)
	for id in look["touches"]:
		_add_touch(str(id))


## The outline of the tent's cover, by shape (the front edge is always at y = 112).
func _tent_shape(shape: String) -> PackedVector2Array:
	var w := STAGE_SIZE.x
	match shape:
		"peaked":
			return PackedVector2Array([Vector2(22, 112), Vector2(160, 62), Vector2(w / 2, 26), Vector2(w - 160, 62), Vector2(w - 22, 112)])
		"awning":
			return PackedVector2Array([Vector2(22, 72), Vector2(w - 22, 72), Vector2(w - 22, 112), Vector2(22, 112)])
		"rounded":
			var points := PackedVector2Array()
			for step in 25:
				var t: float = step / 24.0
				points.append(Vector2(22 + t * (w - 44), 112 - sin(t * PI) * 80))
			return points
	return PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## One of the bar's little touches, as simple shapes.
func _add_touch(id: String) -> void:
	var w := STAGE_SIZE.x
	match id:
		"string_lights":
			var colours := ["ffd27f", "ff7aa8", "7ad3ff", "a8ff7a"]
			var i := 0
			for x in range(40, int(w) - 40, 56):
				_rect(_decor_roof, Vector2(x, 120), Vector2(6, 6), Color(colours[i % colours.size()]))
				i += 1
		"lanterns":
			for x in [330.0, w / 2, w - 330.0]:
				_rect(_decor_roof, Vector2(x - 1, 122), Vector2(2, 8), Color("55536b"))
				_rect(_decor_roof, Vector2(x - 11, 130), Vector2(22, 28), Color("d8352f"))
				_rect(_decor_roof, Vector2(x - 11, 142), Vector2(22, 3), Color("f2c14a"))
		"radio":
			_rect(_decor_counter, Vector2(w - 270, 226), Vector2(42, 24), Color("6b4a2e"))
			_rect(_decor_counter, Vector2(w - 262, 232), Vector2(12, 12), Color("2b2a33"))
			_rect(_decor_counter, Vector2(w - 244, 234), Vector2(10, 4), Color("e0c48a"))
			_rect(_decor_counter, Vector2(w - 236, 208), Vector2(2, 18), Color("9a9ab0"))
		"plants":
			for x in [92.0, w - 128.0]:
				_rect(_decor_back, Vector2(x + 6, 352), Vector2(24, 20), Color("8a5a33"))
				_rect(_decor_back, Vector2(x, 318), Vector2(36, 36), Color("3f8f4a"))
				_rect(_decor_back, Vector2(x + 8, 304), Vector2(20, 18), Color("4fa85a"))
		"calendar":
			_rect(_decor_back, Vector2(49, 160), Vector2(26, 34), Color("f2ead8"))
			_rect(_decor_back, Vector2(49, 160), Vector2(26, 7), Color("c8443a"))
		"lucky_cat":
			_rect(_decor_counter, Vector2(w - 205, 230), Vector2(18, 20), Color("f5f2ea"))
			_rect(_decor_counter, Vector2(w - 203, 222), Vector2(14, 10), Color("f5f2ea"))
			_rect(_decor_counter, Vector2(w - 188, 216), Vector2(5, 12), Color("f5f2ea"))  # the waving paw
			_rect(_decor_counter, Vector2(w - 205, 233), Vector2(18, 3), Color("c8443a"))
		"photos":
			for k in 3:
				_rect(_decor_back, Vector2(w - 78, 150 + k * 30), Vector2(16, 20), Color("c9a87a").darkened(k * 0.1))
		"fishing_net":
			for k in 8:
				_rect(_decor_back, Vector2(w - 300 + k * 22, 128), Vector2(1, 80), Color(0.85, 0.78, 0.6, 0.45))
			for k in 5:
				_rect(_decor_back, Vector2(w - 300, 130 + k * 16), Vector2(156, 1), Color(0.85, 0.78, 0.6, 0.45))
		"knife_rack":
			_rect(_decor_back, Vector2(200, 172), Vector2(76, 12), Color("3a2a1e"))
			for k in 5:
				_rect(_decor_back, Vector2(208 + k * 14, 184), Vector2(3, 18), Color("c8c8d8"))


## The sky, the tent's glow and the bulbs, by the hour. Cold nights look bluer, fog greys
## everything, and a muggy night's a little warmer.
func _update_light() -> void:
	var light := Rules.night_light(_clock)
	var sky: Color = light["sky"]
	match _weather_kind:
		"cold": sky = sky.lerp(Color("1c2c4c"), 0.35)
		"fog": sky = sky.lerp(Color("4a4a58"), 0.35)
		"muggy": sky = sky.lerp(Color("4a2e2a"), 0.25)
	_sky.color = sky
	_glow.color = Color(0.91, 0.51, 0.23, light["glow"])
	for bulb in _bulb_lights:
		bulb.color = light["bulb"]


## Tonight's weather, as you'd see it: rain or snow falling, fog drifting, a warm haze, and
## the bulbs swinging (more in a breeze).
func _show_weather(kind: String) -> void:
	_weather_kind = kind
	_clear(_weather_back)
	_clear(_weather_front)
	var w := STAGE_SIZE.x
	match kind:
		"drizzle", "rain":
			var heavy := kind == "rain"
			var rain := _particles("Rain", _weather_back, _dot_texture(2, 16 if heavy else 12, Color(0.75, 0.82, 1.0, 0.55)))
			rain.amount = 260 if heavy else 70
			rain.lifetime = 0.55
			rain.direction = Vector2(0.12, 1)
			rain.spread = 2.0
			rain.initial_velocity_min = 800.0 if heavy else 600.0
			rain.initial_velocity_max = 950.0 if heavy else 700.0
			if heavy:  # drips off the edge of the tarp, in front
				var drips := _particles("Drips", _weather_front, _dot_texture(2, 6, Color(0.75, 0.82, 1.0, 0.7)))
				drips.position = Vector2(w / 2, 124)
				drips.emission_rect_extents = Vector2(w / 2 - 30, 1)
				drips.amount = 40
				drips.lifetime = 0.45
				drips.direction = Vector2(0, 1)
				drips.initial_velocity_min = 200.0
				drips.initial_velocity_max = 260.0
				drips.gravity = Vector2(0, 900)
		"snow":
			var snow := _particles("Snow", _weather_back, _dot_texture(4, 4, Color(1, 1, 1, 0.85)))
			snow.amount = 140
			snow.lifetime = 8.0
			snow.direction = Vector2(0.2, 1)
			snow.spread = 25.0
			snow.initial_velocity_min = 35.0
			snow.initial_velocity_max = 60.0
			snow.scale_amount_min = 0.6
			snow.scale_amount_max = 1.3
			_rect(_weather_front, Vector2(0, 368), Vector2(w, 4), Color(0.95, 0.96, 1.0, 0.7))  # settling on the street
		"fog":
			for k in 4:
				var band := _rect(_weather_front, Vector2(-400 + k * 300, 70 + k * 80), Vector2(1200, 70), Color(0.75, 0.75, 0.85, 0.10))
				band.name = "Fog%d" % k
				var drift := band.create_tween().set_loops()
				drift.tween_property(band, "position:x", band.position.x + 500, 30.0 + k * 6).set_trans(Tween.TRANS_SINE)
				drift.tween_property(band, "position:x", band.position.x, 30.0 + k * 6).set_trans(Tween.TRANS_SINE)
		"muggy":
			_rect(_weather_front, Vector2.ZERO, STAGE_SIZE, Color(1.0, 0.6, 0.3, 0.05)).name = "Haze"
	var swing := 7.0 if kind == "breeze" else (3.0 if kind == "rain" else 1.5)
	for old in _sways:
		if old.is_valid():
			old.kill()
	_sways.clear()
	for bulb in _bulbs:
		bulb.rotation = 0.0
		var sway: Tween = bulb.create_tween().set_loops()
		_sways.append(sway)
		sway.tween_property(bulb, "rotation_degrees", swing, 1.6 + randf()).set_trans(Tween.TRANS_SINE)
		sway.tween_property(bulb, "rotation_degrees", -swing, 1.6 + randf()).set_trans(Tween.TRANS_SINE)


func _particles(node_name: String, layer: Control, texture: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.texture = texture
	p.position = Vector2(STAGE_SIZE.x / 2, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(STAGE_SIZE.x / 2 + 60, 4)
	p.gravity = Vector2.ZERO
	p.preprocess = 4.0  # already falling when the night opens
	layer.add_child(p)
	return p


func _dot_texture(width: int, height: int, colour: Color) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return ImageTexture.create_from_image(image)


func _rect(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A grey-box person: a head, a body and a name tag, grouped so they move together.
## A plain person: a head and a body (dressed in their look by _dress), and a name tag.
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


# --- Drawing people -----------------------------------------------------------------------

## Dresses a person (from _person) in their look: hair, clothes and their colour, glasses,
## a bag, and the owner's apron. Still simple shapes, layered back to front, in two views:
## "Front" (facing us: walking along the street, coming in, leaving, and the owner behind the
## counter) and "Back" (sitting at the counter, facing their food and the owner). _face
## switches between them.
func _dress(person: Control, look: Dictionary) -> void:
	for part in ["Head", "Body", "Look"]:
		var old := person.get_node_or_null(part)
		if old != null:
			person.remove_child(old)
			old.queue_free()
	var tag := person.get_node_or_null("Tag")
	var outfit := _layer_in(person, "Look")
	var skin := Color(Rules.SKIN_TONES[clampi(int(look.get("skin", 0)), 0, Rules.SKIN_TONES.size() - 1)])
	var hair_colour := Color(str(Rules.HAIR_COLOURS.get(look.get("hair_colour", "black"), Rules.HAIR_COLOURS["black"])[0]))
	var cloth := Color(str(Rules.CLOTHES_COLOURS.get(look.get("colour", "black"), Rules.CLOTHES_COLOURS["black"])[0]))
	var dark := cloth.darkened(0.25)
	var light := cloth.lightened(0.2)
	var hair := str(look.get("hair", "short"))
	var clothes := str(look.get("clothes", "knit"))
	var bag := str(look.get("bag", ""))
	var front := _layer_in(outfit, "Front")
	var back := _layer_in(outfit, "Back")
	back.visible = false

	# --- Facing us ---
	match hair:  # hair behind the head
		"long":
			_rect(front, Vector2(12, 4), Vector2(56, 66), hair_colour)
		"ponytail":
			_rect(front, Vector2(60, 10), Vector2(12, 36), hair_colour)
		"bun":
			_blob(front, Vector2(40, -8), 12.0, hair_colour)
	if clothes == "hoodie":
		_rect(front, Vector2(10, 22), Vector2(60, 30), dark)  # the hood, behind the head
	if bag == "backpack":
		_rect(front, Vector2(-6, 52), Vector2(12, 60), Color("3a3946"))
	var body := _rect(front, Vector2(0, 44), Vector2(80, 106), cloth)
	body.name = "Body"
	match clothes:
		"suit", "blazer":
			_poly(front, [Vector2(28, 44), Vector2(52, 44), Vector2(40, 80)], Color("eef0f2") if clothes == "suit" else Color("cfe0ee"))
			_poly(front, [Vector2(24, 44), Vector2(30, 44), Vector2(40, 86), Vector2(36, 92)], dark)  # lapels
			_poly(front, [Vector2(50, 44), Vector2(56, 44), Vector2(44, 92), Vector2(40, 86)], dark)
			if clothes == "suit":
				_poly(front, [Vector2(38, 48), Vector2(42, 48), Vector2(44, 76), Vector2(40, 82), Vector2(36, 76)], Color("8a2a35"))  # the tie
		"trench":
			_poly(front, [Vector2(20, 44), Vector2(40, 44), Vector2(30, 66)], light)  # collar
			_poly(front, [Vector2(40, 44), Vector2(60, 44), Vector2(50, 66)], light)
			_rect(front, Vector2(0, 98), Vector2(80, 6), dark)  # belt
			for y in [60, 76, 112]:
				_rect(front, Vector2(30, y), Vector2(4, 4), dark)
				_rect(front, Vector2(46, y), Vector2(4, 4), dark)
		"padded":
			_rect(front, Vector2(14, 40), Vector2(52, 10), cloth)  # a high collar
			for y in range(58, 150, 16):
				_rect(front, Vector2(0, y), Vector2(80, 2), dark)  # quilting
			_rect(front, Vector2(39, 50), Vector2(2, 100), dark)  # zip
		"hoodie":
			_rect(front, Vector2(16, 104), Vector2(48, 22), dark)  # pocket
			_rect(front, Vector2(32, 46), Vector2(2, 20), light)  # drawstrings
			_rect(front, Vector2(46, 46), Vector2(2, 20), light)
		"cardigan":
			_rect(front, Vector2(30, 44), Vector2(20, 106), Color("e8e4da") if look.get("colour", "") != "white" else Color("9a9aa4"))
			for y in [62, 82, 102, 122]:
				_rect(front, Vector2(26, y), Vector2(3, 3), dark)
		"scrubs":
			_poly(front, [Vector2(28, 44), Vector2(52, 44), Vector2(40, 64)], skin.darkened(0.05))
			_rect(front, Vector2(48, 74), Vector2(16, 14), dark)  # chest pocket
		"work_jacket":
			_rect(front, Vector2(0, 100), Vector2(80, 5), Color("e8e8e8", 0.85))  # reflective stripes
			_rect(front, Vector2(0, 116), Vector2(80, 5), Color("e8e8e8", 0.85))
			_rect(front, Vector2(16, 44), Vector2(48, 8), dark)  # collar
		"tshirt":
			_poly(front, [Vector2(30, 44), Vector2(50, 44), Vector2(40, 52)], skin)
		"knit":
			_rect(front, Vector2(26, 44), Vector2(28, 6), dark)  # ribbed neck
			for x in range(4, 80, 8):
				_rect(front, Vector2(x, 140), Vector2(3, 10), dark)  # ribbed hem
	if bool(look.get("apron", false)):  # the owner's apron
		_rect(front, Vector2(26, 44), Vector2(4, 22), Color("f0e8d8"))
		_rect(front, Vector2(50, 44), Vector2(4, 22), Color("f0e8d8"))
		_rect(front, Vector2(18, 64), Vector2(44, 86), Color("f0e8d8"))
		_rect(front, Vector2(24, 104), Vector2(32, 16), Color("e2d8c4"))  # its pocket
	var face := _rect(front, Vector2(17, 0), Vector2(46, 44), skin)
	face.name = "Head"
	match hair:  # hair on the head, and the fringe
		"long", "bob":
			_rect(front, Vector2(14, -6), Vector2(52, 16), hair_colour)
			_rect(front, Vector2(12, 0), Vector2(9, 60 if hair == "long" else 34), hair_colour)
			_rect(front, Vector2(59, 0), Vector2(9, 60 if hair == "long" else 34), hair_colour)
			_rect(front, Vector2(20, 8), Vector2(26, 6), hair_colour)
		"ponytail", "bun":
			_rect(front, Vector2(15, -5), Vector2(50, 13), hair_colour)
			_rect(front, Vector2(15, 4), Vector2(5, 12), hair_colour)
			_rect(front, Vector2(60, 4), Vector2(5, 12), hair_colour)
		"pixie":
			_rect(front, Vector2(15, -4), Vector2(50, 13), hair_colour)
			_rect(front, Vector2(15, 4), Vector2(7, 16), hair_colour)
			_rect(front, Vector2(58, 4), Vector2(7, 10), hair_colour)
		"perm":
			for x in range(18, 66, 9):
				_blob(front, Vector2(x, -2 + (x % 2) * 3), 7.0, hair_colour)
			_blob(front, Vector2(16, 10), 6.0, hair_colour)
			_blob(front, Vector2(64, 10), 6.0, hair_colour)
		"short":
			_rect(front, Vector2(15, -4), Vector2(50, 12), hair_colour)
			_rect(front, Vector2(15, 4), Vector2(5, 10), hair_colour)
			_rect(front, Vector2(60, 4), Vector2(5, 10), hair_colour)
		"side_part":
			_rect(front, Vector2(15, -5), Vector2(50, 13), hair_colour)
			_poly(front, [Vector2(30, 8), Vector2(64, 8), Vector2(64, 14)], hair_colour)
			_rect(front, Vector2(28, -5), Vector2(2, 9), hair_colour.lightened(0.25))  # the parting
		"buzz":
			_rect(front, Vector2(17, -2), Vector2(46, 7), Color(hair_colour, 0.8))
		"two_block":
			_rect(front, Vector2(14, -7), Vector2(52, 14), hair_colour)
			_rect(front, Vector2(22, 6), Vector2(30, 9), hair_colour)  # the long fringe
			_rect(front, Vector2(17, 6), Vector2(4, 10), Color(hair_colour, 0.6))  # shaved sides
			_rect(front, Vector2(59, 6), Vector2(4, 10), Color(hair_colour, 0.6))
		"balding":
			_rect(front, Vector2(15, 8), Vector2(6, 14), hair_colour)
			_rect(front, Vector2(59, 8), Vector2(6, 14), hair_colour)
	if bool(look.get("glasses", false)):
		_frame(front, Vector2(23, 17), Vector2(14, 9), Color("1a1a20"))
		_frame(front, Vector2(43, 17), Vector2(14, 9), Color("1a1a20"))
		_rect(front, Vector2(37, 20), Vector2(6, 2), Color("1a1a20"))
	if bag == "backpack":  # its straps over the shoulders
		_rect(front, Vector2(14, 44), Vector2(6, 46), Color("3a3946"))
		_rect(front, Vector2(60, 44), Vector2(6, 46), Color("3a3946"))

	# --- From behind ---
	_rect(back, Vector2(0, 44), Vector2(80, 106), cloth)
	match clothes:
		"trench":
			_rect(back, Vector2(0, 98), Vector2(80, 6), dark)  # belt
			_rect(back, Vector2(38, 104), Vector2(4, 46), dark)  # the back vent
		"padded":
			_rect(back, Vector2(14, 40), Vector2(52, 10), cloth)
			for y in range(58, 150, 16):
				_rect(back, Vector2(0, y), Vector2(80, 2), dark)
		"suit", "blazer":
			_rect(back, Vector2(38, 110), Vector2(4, 40), dark)  # the back seam
			_rect(back, Vector2(28, 40), Vector2(24, 6), Color("eef0f2"))  # shirt collar
		"work_jacket":
			_rect(back, Vector2(0, 100), Vector2(80, 5), Color("e8e8e8", 0.85))
			_rect(back, Vector2(0, 116), Vector2(80, 5), Color("e8e8e8", 0.85))
		"knit":
			for x in range(4, 80, 8):
				_rect(back, Vector2(x, 140), Vector2(3, 10), dark)
	if bool(look.get("apron", false)):
		_rect(back, Vector2(0, 96), Vector2(80, 4), Color("f0e8d8"))  # apron strings, tied behind
	var neck := _rect(back, Vector2(17, 0), Vector2(46, 44), skin)
	neck.name = "Head"
	match hair:  # the back of the head
		"long":
			_rect(back, Vector2(14, -6), Vector2(52, 50), hair_colour)
			_rect(back, Vector2(12, 40), Vector2(56, 34), hair_colour)  # down the back
		"bob":
			_rect(back, Vector2(13, -6), Vector2(54, 46), hair_colour)
		"ponytail":
			_rect(back, Vector2(15, -5), Vector2(50, 40), hair_colour)
			_rect(back, Vector2(35, 26), Vector2(10, 36), hair_colour)  # the ponytail
		"bun":
			_rect(back, Vector2(15, -5), Vector2(50, 40), hair_colour)
			_blob(back, Vector2(40, 12), 11.0, hair_colour.darkened(0.15))
		"perm":
			for x in range(18, 66, 9):
				for y in [0, 12, 24]:
					_blob(back, Vector2(x, y + (x % 2) * 3), 7.0, hair_colour)
		"balding":
			_rect(back, Vector2(15, 16), Vector2(50, 18), hair_colour)  # a fringe of hair round the back
		"buzz":
			_rect(back, Vector2(17, -2), Vector2(46, 34), Color(hair_colour, 0.8))
		_:  # short, side-parted, two-block, pixie: hair down to the nape
			_rect(back, Vector2(15, -5), Vector2(50, 36), hair_colour)
	if clothes == "hoodie":
		_rect(back, Vector2(14, 40), Vector2(52, 24), dark)  # the hood, hanging down the back
	match bag:
		"backpack":
			_rect(back, Vector2(14, 56), Vector2(52, 56), Color("3a3946"))
		"tote":
			_rect(back, Vector2(8, 50), Vector2(3, 46), Color("cdb894").darkened(0.2))
			_rect(back, Vector2(-10, 92), Vector2(24, 30), Color("e6dcc6"))
	if bag in ["tote", "briefcase"]:  # carried at their side, either way
		if bag == "tote":
			_rect(front, Vector2(70, 50), Vector2(3, 50), Color("cdb894").darkened(0.2))
			_rect(front, Vector2(66, 96), Vector2(24, 30), Color("e6dcc6"))
		else:
			_rect(front, Vector2(70, 120), Vector2(30, 22), Color("4a3020"))
			_frame(front, Vector2(79, 114), Vector2(12, 7), Color("4a3020"))
			_rect(back, Vector2(-20, 120), Vector2(30, 22), Color("4a3020"))
	if tag != null:
		person.move_child(tag, -1)  # the name stays on top


## Which way someone's facing: toward us (walking, coming in, leaving, the owner), or away
## (sitting at the counter, facing their food and the owner).
func _face(person: Control, toward_us: bool) -> void:
	var front := person.get_node_or_null("Look/Front") as Control
	var back := person.get_node_or_null("Look/Back") as Control
	if front != null and back != null:
		front.visible = toward_us
		back.visible = not toward_us


func _layer_in(parent: Control, layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _poly(parent: Control, points: Array, colour: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = colour
	parent.add_child(shape)
	return shape


func _blob(parent: Control, centre: Vector2, radius: float, colour: Color) -> Polygon2D:
	var points: Array = []
	for k in 12:
		points.append(centre + Vector2.from_angle(TAU * k / 12.0) * radius)
	return _poly(parent, points, colour)


## A rectangle's outline (glasses, a handle).
func _frame(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> void:
	_rect(parent, pos, Vector2(rect_size.x, 2), colour)
	_rect(parent, pos + Vector2(0, rect_size.y - 2), Vector2(rect_size.x, 2), colour)
	_rect(parent, pos, Vector2(2, rect_size.y), colour)
	_rect(parent, pos + Vector2(rect_size.x - 2, 0), Vector2(2, rect_size.y), colour)


## A look for someone the AI never hears about (passers-by): the game picks it all.
func _street_look() -> Dictionary:
	var gender := "woman" if randf() < 0.5 else "man"
	return Rules.pick_look(gender, Rules.pick_age_range(randf()), _weather_kind)


## The owner's look: chosen with the bar and saved; bars from before looks get one now,
## from the owner's age, without asking the AI.
func _owner_look() -> Dictionary:
	if not _owner.has("look"):
		var range_id := Rules.age_range_of(int(_owner.get("age", 55)))
		_owner["look"] = Rules.pick_look(str(_owner.get("gender", "woman")), range_id, "", true)
		if not Game.bar.is_empty():
			Game.bar["owner"]["look"] = _owner["look"]
			Game.save()
	return _owner["look"]


# --- Regulars --------------------------------------------------------------------------------

## The bar's regulars (saved with it).
func _regulars() -> Array:
	if not Game.bar.has("regulars"):
		Game.bar["regulars"] = []
	return Game.bar["regulars"]


func _regular(id: String) -> Dictionary:
	if id == "":
		return {}
	for regular in _regulars():
		if str(regular["id"]) == id:
			return regular
	return {}


func _day_index() -> int:
	return maxi(0, Rules.DAYS.find(_night_day))


## A new bar's two founding regulars: the game decides who they'll be (gender, look, role,
## how long and how often, their usual), and the AI invents them. Saved with the bar.
func _make_founding_regulars() -> void:
	var roles: Array = Regulars.ROLES.keys()
	roles.shuffle()
	var taken: Array = [str(_owner["name"])]
	var made: Array = []
	for i in 2:
		var gender := Rules.game_gender(randf())
		var look := Rules.pick_look(gender if gender != "non-binary" else ["woman", "man"].pick_random(), Rules.pick_age_range(randf()), "")
		var habit: Array = Regulars.HABITS.pick_random()
		var years := randi_range(2, 12)
		var since := "for %d years" % years
		var usual: Array = [_menu_pick("drink"), _menu_pick("main")]
		_typing_label.text = "Someone's been coming here for years..."
		var reply: Dictionary = await _ai.ask_json(
			Prompts.founding_regular_messages(_owner, str(Game.bar["name"]), gender, look, str(roles[i]), since, str(habit[0]), usual, taken),
			_validate_founding.bind(taken, gender, str(look["age_range"])), {"temperature": 0.9},
			{"purpose": "founding_regular", "taken": taken.duplicate(), "gender": gender, "look": look})
		_typing_label.text = ""
		if _stopped:
			return
		if reply.is_empty():
			continue  # one fewer: the bar still opens
		var days: Array = range(7)
		days.shuffle()
		var regular := {
			"id": "%s-founding" % str(reply["name"]).to_lower().replace(" ", "-"),
			"founding": true, "role": roles[i], "since": since, "habit": habit[0],
			"history": reply["history"], "owner_knows": reply["owner_knows"], "knows_of_owner": reply["knows_of_owner"],
			"visits": roundi(years * 52 * float(habit[2])), "first_night": 0, "last_night": 0,
			"pull": Regulars.FOUNDING_PULL, "favourite_days": days.slice(0, int(habit[1])),
			"usual_hour": randi_range(19 * 60, 23 * 60), "orders": [], "usual": usual,
			"owner_knows_name": true, "knows_owner_name": true, "look": look, "introduced": false,
		}
		for key in ["name", "hangul", "gender", "age", "job", "speech_style", "appearance"]:
			regular[key] = reply.get(key, "")
		made.append(regular)
		taken.append(str(reply["name"]))
	# Founding regulars have known each other for years (on first-name terms, not yet close).
	for regular in made:
		for other in made:
			if other != regular:
				var friends: Dictionary = regular.get("friends", {})
				friends[other["id"]] = {"meetings": 20, "names": true, "close": false, "night": -1, "name": other["name"]}
				regular["friends"] = friends
	Game.bar["regulars"] = made
	Game.save()  # (they're introduced when they first come in: see _back_text)


func _validate_regular_tonight(data: Variant) -> String:
	return Rules.validate_regular_tonight(data)


func _validate_founding(data: Variant, taken: Array, gender: String, age_range: String) -> String:
	return Rules.validate_founding_regular(data, taken, gender, age_range)


func _menu_pick(kind: String) -> String:
	var choices: Array = Menu.ITEMS.filter(func(item): return (item.get("kind", "") == "drink") if kind == "drink" else (item.get("portion", "") == "main"))
	return str(choices.pick_random()["id"])


## Who's coming in tonight, from their pull and habits: each regular at most once, around
## their usual hour.
func _plan_regulars_tonight() -> void:
	_regulars_due.clear()
	for regular in _regulars():
		# A founding regular always comes in the first night the bar has them, to meet them.
		var first := bool(regular.get("founding", false)) and not bool(regular.get("introduced", false))
		if first or randf() < Regulars.visit_chance(float(regular["pull"]), _day_index(), regular.get("favourite_days", []), Regulars.keen(regular, _night_number)):
			_regulars_due.append({"time": Regulars.arrival_time(int(regular.get("usual_hour", 21 * 60)), randf()), "id": regular["id"]})
	_regulars_due.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))


## A regular's facts, for the prompts (see Prompts.describe_regular).
func _regular_facts(regular: Dictionary) -> Dictionary:
	var facts := {
		"visits": int(regular.get("visits", 0)), "founding": bool(regular.get("founding", false)),
		"role": regular.get("role", ""), "since": regular.get("since", ""), "habit": regular.get("habit", ""), "history": regular.get("history", ""),
		"owner_knows": regular.get("owner_knows", ""), "knows_of_owner": regular.get("knows_of_owner", ""),
		"usual": Regulars.usual_of(regular), "owner_knows_name": bool(regular.get("owner_knows_name", false)),
		"knows_owner_name": bool(regular.get("knows_owner_name", false)),
		"memories": regular.get("memories", []), "impression": regular.get("impression", ""), "facts": regular.get("facts", {}),
		"warmth": int(regular.get("warmth", 0)),
	}
	if int(regular.get("last_night", 0)) > 0:
		facts["nights_ago"] = _night_number - int(regular["last_night"])
	return facts


## A regular comes in: not reinvented, just asked what sort of night they're having.
func _regular_tonight(regular: Dictionary, guest: Guest) -> Dictionary:
	var customer := {}
	for key in ["name", "hangul", "gender", "age", "job", "speech_style", "appearance"]:
		customer[key] = regular.get(key, "")
	customer["look"] = Regulars.dressed_for(regular.get("look", {}), _weather_kind)
	customer["regular"] = _regular_facts(regular)
	customer["regular_id"] = regular["id"]
	_typing_label.text = "%s is back..." % regular["name"]
	var tonight: Dictionary = await _ai.ask_json(
		Prompts.regular_tonight_messages(_night_day, guest.arrived, _night_weather, customer),
		_validate_regular_tonight, {"temperature": 0.9}, {"purpose": "regular_tonight", "name": regular["name"]})
	_typing_label.text = ""
	if tonight.is_empty():
		tonight = {"mood": "glad to be back", "reason": "It's been a while, and this is where they unwind."}
	customer["mood"] = tonight["mood"]
	customer["reason"] = tonight["reason"]
	return customer


## "Kim Ji-ho is back, for her 4th visit (last time: 9 nights ago)." or, for a founding
## regular, "Choi Young-ja ducks in and takes her usual stool: she's been coming for six
## years, most Fridays."
func _back_text(regular: Dictionary) -> String:
	var her: String = {"woman": "her", "man": "his"}.get(str(regular.get("gender", "")), "their")
	var she: String = {"woman": "she's", "man": "he's"}.get(str(regular.get("gender", "")), "they've")
	if bool(regular.get("founding", false)):
		var text := "%s ducks in and takes %s usual stool: %s been coming %s, %s." % [regular["name"], her, she, regular.get("since", ""), regular.get("habit", "")]
		if not bool(regular.get("introduced", false)):
			# The first time we see them: who they are to the tent.
			regular["introduced"] = true
			Game.save()
			var who: String = {"woman": "She's", "man": "He's"}.get(str(regular.get("gender", "")), "They're")
			text += " %s %s. %s" % [who, str(Regulars.ROLES.get(regular.get("role", ""), "a regular")).get_slice(":", 0), Rules.as_sentence(str(regular.get("history", "")))]
		return text
	var text := "%s is back, for %s %s visit" % [regular["name"], her, Regulars.ordinal(int(regular.get("visits", 0)) + 1)]
	if int(regular.get("last_night", 0)) > 0:
		text += " (last time: %s)" % Regulars.nights_ago_text(_night_number - int(regular["last_night"]))
	return text + "."


## After someone pays: a regular's visit is added to their record; anyone else might become
## a regular, from how the visit went. Saved with the bar.
func _after_visit(guest: Guest) -> void:
	var owner_lines := guest.transcript.filter(func(e): return e.has("text")).size()
	var verdict := Regulars.game_verdict(owner_lines, guest.chatted, guest.quick_greeting, guest.company)
	var rushed := Regulars.rushed(guest.quick_greeting, owner_lines)
	# What each of them will remember, and how the night went for them: the AI's verdict, from
	# the dialogue (the game's own is the fallback).
	var memory := {}
	if memories:
		memory = await _remember(guest, verdict)
		if _stopped or Game.bar.is_empty():
			return
		if not memory.is_empty():
			verdict = str(memory["night"])
	_stats.verdicts[verdict] = int(_stats.verdicts.get(verdict, 0)) + 1
	var said := " ".join(PackedStringArray(guest.transcript.filter(func(e): return e.has("text")).map(func(e): return str(e["text"])))).to_lower()
	var regular := _regular(str(guest.customer.get("regular_id", "")))
	if not regular.is_empty():
		regular["visits"] = int(regular.get("visits", 0)) + 1
		regular["last_night"] = _night_number
		var orders: Array = regular.get("orders", [])
		orders.append(guest.first_order.duplicate())
		regular["orders"] = orders.slice(-5)
		regular["pull"] = Regulars.pull_after_visit(float(regular["pull"]), verdict, rushed)
		if str(memory.get("towards_owner", "")) == "warmer":
			regular["warmth"] = int(regular.get("warmth", 0)) + 1  # (for friendlier terms, in step 3)
		_stats.regulars_in += 1
	else:
		var roll := regular_roll_override if regular_roll_override >= 0.0 else randf()
		if not Regulars.becomes_regular(verdict, rushed, roll):
			return
		regular = Regulars.new_regular(guest.customer, guest.customer.get("look", {}), guest.first_order, _night_number, _day_index(), guest.arrived_minutes, randf())
		_regulars().append(regular)
		_stats.became_regulars += 1
		if str(memory.get("towards_owner", "")) == "warmer":
			regular["warmth"] = 1
		var they: String = {"woman": "she'll", "man": "he'll"}.get(str(guest.customer.get("gender", "")), "they'll")
		_narrate("%s looks like %s be back." % [guest.customer["name"], they])
	if not memory.is_empty():
		Regulars.remember(regular, _night_number, memory)
	# Names, once they've been said (the full name, or the given name).
	if _name_said(str(guest.customer["name"]), said):
		regular["owner_knows_name"] = true
	if _name_said(str(_owner["name"]), said):
		regular["knows_owner_name"] = true
	Game.save()
	_count_regulars()


## The after-visit AI call: what the owner and the customer will each remember, the things
## about them that stick (only from what they actually said), and the verdict. {} if the AI
## couldn't.
func _remember(guest: Guest, game_verdict: String) -> Dictionary:
	var who := str(guest.customer["name"])
	var theirs := PackedStringArray()
	for entry in guest.transcript + guest.chat_lines:
		if entry.has("text") and str(entry.get("speaker", "")) == who:
			theirs.append(str(entry["text"]))
	var said := " ".join(theirs).to_lower()
	var memory: Dictionary = await _ai.ask_json(
		Prompts.memory_messages(_owner, guest.customer, guest.transcript, guest.chat_lines),
		_validate_memory.bind(said), {"temperature": 0.4}, {"purpose": "memory", "verdict": game_verdict})
	if memory.is_empty():
		_stats.memories_failed += 1
	return memory


func _validate_memory(data: Variant, said: String) -> String:
	return Rules.validate_memory(data, said)


func _name_said(full: String, said: String) -> bool:
	var parts := full.split(" ", false)
	var given := " ".join(parts.slice(1)) if parts.size() > 1 else full
	return said.contains(full.to_lower()) or said.contains(given.to_lower())


## The night's over: regulars who didn't come drift a little further away; anyone who's
## drifted too far isn't a regular any more.
func _fade_regulars() -> void:
	var kept: Array = []
	for regular in _regulars():
		if int(regular.get("last_night", 0)) != _night_number:
			regular["pull"] = Regulars.pull_after_absence(float(regular["pull"]), bool(regular.get("founding", false)))
		if Regulars.still_regular(float(regular["pull"])):
			kept.append(regular)
		else:
			_stats.faded_regulars += 1
			_narrate("%s hasn't been in for a long while." % regular["name"])
	Game.bar["regulars"] = kept
	_count_regulars()


## The regulars, for the stats panel and log.
func _count_regulars() -> void:
	_stats.regular_pulls = {}
	_stats.founding_regulars = 0
	for regular in _regulars():
		_stats.regular_pulls[str(regular["name"])] = snappedf(float(regular["pull"]), 0.01)
		if bool(regular.get("founding", false)):
			_stats.founding_regulars += 1


## What the owner remembers about a regular, for the info panel's hover ("" if nothing yet).
func _remembered_text(known: Dictionary) -> String:
	var parts := PackedStringArray()
	if str(known.get("impression", "")) != "":
		parts.append(str(known["impression"]))
	for memory in known.get("memories", []):
		parts.append(str(memory["owner"]))
	var facts: Dictionary = known.get("facts", {})
	for key in Rules.STICKING:
		if str(facts.get(key, "")) != "":
			parts.append("%s: %s" % [{"job": "Job", "family": "Family", "home": "From", "other": "Also"}[key], facts[key]])
	if str(known.get("owner_knows", "")) != "" and parts.is_empty():
		parts.append(str(known["owner_knows"]))
	# (No square brackets: it goes inside a BBCode tag.)
	return " · ".join(parts).replace("[", "(").replace("]", ")").replace("\n", " ")


# --- Who calls whom, and friendliness ------------------------------------------------------

const FRIENDLY_AFTER := 4  # meetings before two regulars might ask "can I call you eonni?"


## Someone, as far as address goes (see Rules.allowed_terms). null: the owner.
func _addressee(guest: Guest) -> Dictionary:
	if guest == null:
		return {"gender": str(_owner.get("gender", "woman")), "age": int(_owner.get("age", 55)), "owner": true}
	return {"gender": str(guest.customer.get("gender", "")), "age": int(guest.customer.get("age", 30)), "owner": false}


func _who(guest: Guest) -> String:
	return str(_owner["name"]) if guest == null else str(guest.customer["name"])


## For the checks: who's speaking to whom. null: the owner.
func _address(speaker: Guest, listener: Guest, close: bool = false) -> Dictionary:
	return {"speaker": _addressee(speaker), "listener": _addressee(listener), "close": close, "listener_name": _who(listener)}


## For the prompts: how the owner and a customer address each other (and, for a regular the
## owner's got to know, their given name).
func _address_note(guest: Guest) -> String:
	var text := "HOW THEY ADDRESS EACH OTHER: %s %s" % [
		Rules.address_text(_who(guest), _addressee(guest), _who(null), _addressee(null), false),
		Rules.address_text(_who(null), _addressee(null), _who(guest), _addressee(guest), false)]
	var known: Dictionary = guest.customer.get("regular", {})
	if bool(known.get("owner_knows_name", false)):
		var parts := str(guest.customer["name"]).split(" ", false)
		var given := " ".join(parts.slice(1)) if parts.size() > 1 else str(guest.customer["name"])
		if bool(known.get("founding", false)) or int(known.get("warmth", 0)) >= 2 or int(known.get("visits", 0)) >= 6:
			text += " The owner knows them well, and calls them by their given name, %s." % given
		else:
			text += " The owner knows their name, %s." % guest.customer["name"]
	return text


## Two regulars' record of each other (from the first one's side), or {}.
func _friend(a: Guest, b: Guest) -> Dictionary:
	var mine := _regular(str(a.customer.get("regular_id", "")))
	if mine.is_empty() or str(b.customer.get("regular_id", "")) == "":
		return {}
	return mine.get("friends", {}).get(str(b.customer["regular_id"]), {})


func _close(a: Guest, b: Guest) -> bool:
	return bool(_friend(a, b).get("close", false))


## After a spell of chat: regulars who chatted remember it (once a night per pair): how many
## times they've met, whether they know each other's names, and the last thing said.
func _remember_chat(chat: Chat, last: String) -> void:
	var said := " ".join(PackedStringArray(chat.transcript.filter(func(e): return e.has("text")).map(func(e): return str(e["text"])))).to_lower()
	for a in chat.people:
		for b in chat.people:
			if a == b:
				continue
			var mine := _regular(str(a.customer.get("regular_id", "")))
			var their_id := str(b.customer.get("regular_id", ""))
			if mine.is_empty() or their_id == "":
				continue
			var friends: Dictionary = mine.get("friends", {})
			var friend: Dictionary = friends.get(their_id, {"meetings": 0, "names": false, "close": false, "night": -1})
			if int(friend.get("night", -1)) != _night_number:
				friend["meetings"] = int(friend.get("meetings", 0)) + 1
				friend["night"] = _night_number
			if _name_said(str(b.customer["name"]), said):
				friend["names"] = true
			friend["name"] = str(b.customer["name"])
			friend["last"] = last
			friends[their_id] = friend
			mine["friends"] = friends
	_refresh_tags()


## The "can I call you eonni?" moment, if it's time: the younger of two regulars who've met
## enough asks the older; "" if not. Marks them close once asked (the game's call).
func _friendly_moment(speaker: Guest, addressee: Guest) -> String:
	if speaker == null or addressee == null:
		return ""
	var friend := _friend(speaker, addressee)
	if friend.is_empty() or bool(friend.get("close", false)) or int(friend.get("meetings", 0)) < FRIENDLY_AFTER:
		return ""
	var term := Rules.sibling_term(_addressee(speaker), _addressee(addressee))
	if term == "":
		return ""
	return term


func _make_close(a: Guest, b: Guest, term: String) -> void:
	for pair in [[a, b], [b, a]]:
		var mine := _regular(str(pair[0].customer.get("regular_id", "")))
		if mine.is_empty():
			continue
		var friends: Dictionary = mine.get("friends", {})
		var friend: Dictionary = friends.get(str(pair[1].customer["regular_id"]), {})
		friend["close"] = true
		friends[str(pair[1].customer["regular_id"])] = friend
		mine["friends"] = friends
	_stats.friendlier_moments += 1
	_narrate("%s and %s are on \"%s\" terms now." % [a.customer["name"], b.customer["name"], term])
	Game.save()


## Name tags: a regular whose friend is at the counter too gets a matching ∞.
func _refresh_tags() -> void:
	for guest in _guests:
		var tag: Label = null
		if guest.node != null:
			tag = guest.node.get_node_or_null("Tag") as Label
		if tag == null:
			continue
		var label := _name_label(guest.customer)
		for other in _guests:
			if other != guest and not _friend(guest, other).is_empty():
				label += " ∞"
				break
		tag.text = label


## The term a line actually used for its listener, for the bubble's header ("" if none).
func _term_used(line: String, speaker: Guest, listener: Guest) -> String:
	var allowed := Rules.allowed_terms(_addressee(speaker), _addressee(listener), speaker != null and listener != null and _close(speaker, listener))
	for term in Rules.terms_in(line, [_who(speaker), _who(listener)]):
		if allowed.has(term):
			return term
	return ""
