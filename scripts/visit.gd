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
const Glossary = preload("res://scripts/rules/glossary.gd")
const Address = preload("res://scripts/rules/address.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Memories = preload("res://scripts/rules/memories.gd")
const Names = preload("res://scripts/rules/names.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Seasons = preload("res://scripts/rules/seasons.gd")
const Skyline = preload("res://scripts/rules/skyline.gd")
const SkylineView = preload("res://scripts/skyline_view.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const DishView = preload("res://scripts/dish_view.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const People = preload("res://scripts/rules/people.gd")
const Story = preload("res://scripts/rules/story.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Regulars = preload("res://scripts/regulars.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")
const CaptionPopup = preload("res://scripts/caption.gd")
const DiaryPage = preload("res://scripts/diary_page.gd")
const DiaryBook = preload("res://scripts/diary_book.gd")
const RecapScreen = preload("res://scripts/recap_screen.gd")
const Hooks = preload("res://scripts/test_hooks.gd")
const NightEvents = preload("res://scripts/night_events.gd")
const Ktv = preload("res://scripts/ktv_style.gd")

const HUNGRY_CHANCE := 0.15  # How often a customer is hungry enough to order two main dishes.
const ROUGH_NIGHT_CHANCE := 0.2  # How often a customer is having a rough enough night to order two drinks.
## Free side dishes served with every first order, as at a real pojangmacha. Not on the bill.
const BANCHAN := "kimchi and pickled radish"


const ACCENT := Ktv.ORANGE
const MUTED := Ktv.MUTED
const OWNER_COLOR := Color("8f8aa8")
const OWNER_TEXT := Ktv.YELLOW
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
const BULB_OFF := Color("3a3546")  # a bulb switched off (closing up early)
const CLOSING_GLOW := 0.6  # the tent's glow with one bulb off
const PEEK_X := 865.0  # where a passer-by stops to look in: the gap between the second and third stools

## The test hooks are in test_hooks.gd (as Hooks.<name>): tests set them; the game only reads them.

## When the owner's free and nothing's urgent: how often customers chat to each other
## instead of the owner chatting to someone. Mostly it's customer and owner.
const CHAT_CHANCE := 0.5
## ...and when it's busy (People.BUSY_COUNTER or more in), when there are most people to talk to.
const BUSY_CHAT_CHANCE := 0.75
const JOIN_CHANCE := 0.4  # how often another customer joins an ongoing chat
const OWNER_JOINS_CHANCE := 0.35  # how often the owner joins a customer chat
const CHAT_LINES := Vector2i(3, 5)  # lines in a spell of customer chat
const CHAT_MIN_STAY_LEFT := 10.0  # game minutes
const CHAT_LINES_BEFORE_INTERRUPTING := 3  # a chat gets this many lines before anything can cut in
const COMPANY_LABEL := {"chatty": "chatty", "quiet": "keeps to themselves", "owner": "here to talk"}

## Real seconds per game minute at normal speed. The clock always runs, whatever's
## happening; at normal speed a night (6pm to 3am, 540 game minutes) would take about five
## minutes, but time runs faster when the tent's quiet (NightRules.TIME_SPEEDS), so it's less.
const REAL_SECONDS_PER_GAME_MINUTE := 0.56
## How quickly the speed changes when people come and go (speed per real second), so it
## eases rather than jumps.
const SPEED_CHANGE_RATE := 4.0


## One customer at the counter: who they are, which stool, what they've ordered and what's in
## front of them, and how far their conversation with the owner has got.
class Guest:
	extends RefCounted
	var seat := 0
	var reacted_at := 0  # the line of their conversation with the owner last checked for a TV reaction
	var customer := {}
	var color := Color.WHITE
	var arrived := ""  # the time they arrived, as text
	var moment := {}  # day, time (kept up to date) and weather, for the AI
	var order: Array = []  # everything they've ordered: the bill
	var served: Array = []  # what's on their table (the banchan aside)
	var transcript: Array = []  # their conversation with the owner, plus what happened
	var line := 0  # the next line of their conversation with the owner (even: the owner's turn)
	var extra_turns: Array = []  # lines that become later orders instead
	var rain_gear := {}  # what they came in with (Looks.rain_gear), to go back out with
	var attended := 0  # when the owner last saw to them (a running count)
	var company := "chatty"  # their mood for company (see People.company)
	var topic := ""  # what their chat with the owner is turning to (see Talk.pick_owner_topic)
	var food_news := false  # something's been served since the last topic was picked
	var food_moment := ""  # a Talk.served_moment direction for their next line, now and then after something arrives
	var cat_moment := ""  # a CatRules.cat_moment for their next line, now and then when the cat comes to them
	var stunned := ""  # a Talk.stunned_moment for their next line, after a shock they heard
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
	var topic := ""  # what it's turning to this spell (see Talk.pick_chat_topic)
	var shared := false  # had its sharing moment (see Talk.sharing_moment)


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
## A customer invented ahead (see _prepare_customer) is used if they arrive within this many
## game minutes; any later, they're from another hour (a 7pm salaryman isn't a 2am one).
const PREPARED_FRESH_MINUTES := 60.0
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
## The next new customer, invented ahead while the owner was free ({"customer", "at"}: game
## minutes), so when someone ducks under the tarp only their order waits for the AI. {}: none.
var _prepared := {}
## The owner's hands: carrying a dish over, which happens whatever the voice is doing.
var _carrying := false
var _owner_tween: Tween
var _attending: Guest = null  # who the owner saw to last
var _attention := 0
var _last_orders := false
var _leave_requested := false
## Close the bar, during a night: the owner closes up early (nobody new, everyone settles up),
## and once the tent's empty the night ends as at 3am, diary and all. (Closing the window
## just saves and quits, and the night doesn't count.)
var _closing_early := false
var _closed_early_at := 0.0  # game minutes
var _closing_to_say := false  # the owner's still to tell the counter why (once they're free)
var _closing_said := ""  # what they said
var _closed_sign: Control  # the 마감 CLOSED board out front
var _passers_by := 0  # how many have walked past tonight (also names their nodes)
var _ambience: Ambience  # the tent's background sound
var _bubble_layer: Control  # speech bubbles, over everything on the stage
var _bubbles_shown: Array = []  # Bubble: the newest last
var _caption_layer: Control  # TV captions, over everything
var _captions_toggle: CheckBox
var _music_toggle: CheckBox
var _options_button: Button  # the top bar's Options button...
var _options_panel: PanelContainer  # ...and the panel it drops down
var _caption_shown: Control  # the one up now (a new one replaces it)
var _red_frame: Panel  # flashes round the tent for an emergency
var _caption_last := -1.0  # real seconds when the last caption showed (-1: none yet)
var _caption_last_kind := {}  # kind -> real seconds when one of those last showed
var _rush_shown := false  # tonight's after-work rush has been and gone
var _dawn_shown := false  # ...and 2am feelings
var _red_flashes := 0  # emergencies flashed (for tests)
var _reaction_last := -1.0  # real seconds when the last reaction showed
var _reaction_until := -1.0  # ...and until when it's up
## Tonight's specials (menu ids, Orders.pick_specials): marked on the menu customers see.
var _specials: Array = []
## A CatRules.cat_moment for the owner's next line (the cat's up on the counter again...).
var _owner_cat_moment := ""
var _owner_stunned := ""  # a Talk.stunned_moment for the owner's next line
## A reaction check put off because the owner was needed ({lines, names, items, at}: the latest
## one only), asked as soon as she's free (see _next_task).
var _reaction_pending := {}
var _bubbles_toggle: CheckBox
var _sound_toggle: CheckBox
var _music: Music  # Arirang, now and then
var _loading: LoadingScreen  # the loading screen while a bar is set up (a new one, or reopened)
var _loading_note := ""  # what it's waiting on when the typing label says nothing ("Previously on…")
var _loading_said := ""  # ...and what the status said last, and since when (real seconds)
var _loading_since := 0.0
var _loading_opened := 0.0  # real seconds when the loading screen went up (for the stats)
## How tonight opened (loading time, the recap's style and who wrote it), noted before the
## night's stats exist, and handed to them when it starts (NightStats.story).
var _before_night := {}
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
var _night_date := {}  # Seasons.date: the day, month, its text ("14 November") and the season
var _night_weather := ""
var _clock := float(NightRules.OPEN_MINUTES)  # game minutes since midnight at the start of the night
var _next_arrival := 0.0
var _night_visits := 0
var _night_takings := 0
var _night_lines: Array = []  # what customers said tonight, for the summary
## Tonight's events (see night_events.gd): announced once each, and listened to by the stats,
## the TV captions and (from its list) the owner's diary.
var _events: NightEvents
var _diary_page: Control  # the 3am diary page (see diary_page.gd)
var _summary_buttons: Array = []  # disabled while the owner writes
var _stats_button: Button
var _recap_said := ""  # tonight's "Previously on…", for the top of the night's transcript
var _summary: PanelContainer
var _summary_text: RichTextLabel

# UI
var _try_again: Button  # only shown if the owner couldn't be invented
var _leave_button: Button
var _time_speed := NightRules.time_speed(0)  # how fast game time is running now (eases to the target)
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
## Its own dice for scenery that comes and goes by itself (the neon sign, steam, the cat
## prowling), so it never shifts the game's own rolls (tests fix those with a seed).
var _scenery_dice := RandomNumberGenerator.new()
var _neon: Label  # the karaoke sign on the pillar
var _glow: ColorRect  # the tent's warm glow
var _skyline: SkylineView  # the city behind the tent
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
	if Hooks.random_seed != 0:
		seed(Hooks.random_seed)
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
	_narrate(Text.as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up %s again for the night." % [_owner_display(), Game.bar["name"]])
	_owner_working = true  # busy until it's done (it may ask the AI)
	if People.fill_owner_life(Game.bar["owner"], randf()):  # a bar saved before owners had a fixed life: the game picks one, once
		_owner = Game.bar["owner"].duplicate(true)
		Game.save()
	await _fill_in_hangul()  # bars saved before names had Hangul, or whose first try didn't fit
	if Hooks.founding_regulars and not Game.bar.has("regulars") and not _stopped:
		await _make_founding_regulars()  # a bar saved before regulars: its two, once
	if _stopped or Game.bar.is_empty():
		_owner_working = false
		return
	if not Game.bar.get("cat", {}).is_empty():  # bars saved before cats have none, for now
		_show_cat()
	_update_info()
	if Hooks.recaps and int(Game.bar.get("nights", 0)) > 0:
		_loading_note = "Writing \"Previously on…\""
		var recap := await _write_recap()
		_loading_note = ""
		if _stopped or Game.bar.is_empty():
			_owner_working = false
			return
		_end_loading()
		await _play_recap(recap, false)
	else:
		_end_loading()
	_owner_working = false
	if _stopped or Game.bar.is_empty():
		return
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
		var hangul := str(Names.CAT_HANGUL.get(person_name, ""))
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
	var problem := Text.check_fields(data, ["hangul"])
	if problem != "":
		return problem
	var fitted := Names.fit_hangul(person_name, data["hangul"])
	if fitted == "":
		return "\"hangul\" must be %s written in Korean letters (Hangul)" % person_name
	data["hangul"] = fitted
	return ""


## A loading screen over everything while a new bar is invented and the tent goes up.
func _build_loading() -> void:
	_loading = LoadingScreen.new()
	_loading.reopening = not Game.bar.is_empty()  # (its captions tease a new bar, or tonight's episode)
	_loading_opened = Time.get_ticks_msec() / 1000.0
	_loading.name = "Loading"
	_loading.z_index = 10
	add_child(_loading)


## The bar's ready (or something went wrong): fade the loading screen out.
## The loading screen's status: what the AI's doing, and, if it's taking a while, for how long,
## so a slow reply doesn't look like the game's stuck. (Ollama can take up to a minute for the
## first reply after it's been idle, while it loads the model back into the GPU.)
func _loading_status() -> String:
	var text := _typing_label.text if _typing_label.text != "" else _loading_note
	var now := Time.get_ticks_msec() / 1000.0
	if text != _loading_said:
		_loading_said = text
		_loading_since = now
	var waited := int(now - _loading_since)
	if text == "" or waited < LOADING_PATIENCE:
		return text
	if waited < LOADING_WAKING:
		return "%s  (%ds)" % [text, waited]
	return "%s  (%ds: the AI may be waking up, which can take a minute after it's been idle)" % [text, waited]


const LOADING_PATIENCE := 5  # seconds before the status counts them
const LOADING_WAKING := 15  # ...and before it says why it might be slow


func _end_loading() -> void:
	if _loading == null or not _loading.visible:
		return
	_before_night["loading_seconds"] = Time.get_ticks_msec() / 1000.0 - _loading_opened
	var fade := _loading.create_tween()
	fade.tween_property(_loading, "modulate:a", 0.0, 0.4)
	fade.tween_callback(func(): _loading.visible = false)


## Back to the loading screen (trying again after the AI failed).
func _start_loading() -> void:
	_loading_opened = Time.get_ticks_msec() / 1000.0
	_loading.modulate.a = 1.0
	_loading.visible = true


## Ollama couldn't be reached partway through, so the AI switched to canned replies.
func _on_offline_started(reason: String) -> void:
	_show_offline_mode()
	_narrate("(Couldn't reach the local AI, so the game switched to offline mode: %s.)" % reason)


func _show_offline_mode() -> void:
	_mode_label.text = "OFFLINE MODE"
	_mode_label.tooltip_text = Text.tip("Characters and lines are pre-written, not from the AI (%s). Change it in ai_settings.cfg." % _ai.offline_reason)
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
	var look := Looks.pick_look(gender, Looks.pick_age_range(randf(), true), "", true)
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
	People.fill_owner_life(_owner, randf())  # (anything the AI left out)
	_dress(_owner_node, look)
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Text.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	await _name_cat()
	await _choose_look()
	if Hooks.founding_regulars:
		await _make_founding_regulars()
	_show_look()
	_show_cat()
	await get_tree().process_frame  # let the tent draw before the loading screen fades
	_end_loading()
	if Hooks.recaps:
		_before_night["recap_by"] = "game"  # (a series opener's always the game's)
		await _play_recap(Story.series_opener(_recap_facts()), true)  # a new series: its first episode
		if _stopped or Game.bar.is_empty():
			return
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
		named = BarLook.fallback_bar_name(str(_owner["name"]))
	Game.bar = SaveStore.new_bar(str(named["name"]), str(named["meaning"]), _owner)
	Game.bar["first_day"] = randi() % NightRules.DAYS.size()
	Game.save()
	_show_bar_name()
	_narrate("The sign over the tarp reads %s (%s)." % [named["name"], named["meaning"]])


## A new bar's look: the AI chooses the tarp, the sign's style and Hangul, and a touch or
## two, from the game's options, to suit the owner and the name (plain, if it can't).
func _choose_look() -> void:
	_typing_label.text = "The AI is putting up the tarp..."
	_look_offer = {} if Hooks.offer_every_look else BarLook.look_offer()
	var look: Dictionary = await _ai.ask_json(
		Prompts.bar_look_messages(_owner, str(Game.bar["name"]), str(Game.bar.get("name_meaning", "")), _look_offer),
		_validate_bar_look, {"temperature": 0.8}, {"purpose": "bar_look", "bar_name": Game.bar["name"],
			"tarps": _look_offer.get("tarp", BarLook.BAR_TARPS.keys()), "shapes": _look_offer.get("shape", BarLook.TENT_SHAPES.keys())})
	_typing_label.text = ""
	if look.is_empty():
		look = BarLook.default_bar_look()
	Game.bar["look"] = {"hangul": look["hangul"], "tarp": look["tarp"], "sign": look["sign"], "shape": look.get("shape", "classic"), "touches": look["touches"]}
	Game.save()
	var touches := PackedStringArray()
	for id in look["touches"]:
		touches.append(BarLook.BAR_TOUCHES.get(id, id))
	var colour := str(look["tarp"]).replace("_", " and white ").replace("striped", "orange and cream stripes")
	var shape: String = BarLook.TENT_SHAPES.get(look.get("shape", "classic"), "a tarp")
	_narrate("The tent: %s, in %s. A %s sign reading %s, and %s." % [shape, colour, look["sign"], look["hangul"],
		" and ".join(touches) if not touches.is_empty() else "not much else"])


func _validate_bar_look(data: Variant) -> String:
	return BarLook.validate_bar_look(data, _look_offer)


## A new bar's cat: the game picks its coat and personality, and the AI names it (from a
## short list if it can't).
func _name_cat() -> void:
	var coat: String = CatRules.CAT_COATS.keys().pick_random()
	var personality: String = CatRules.CAT_PERSONALITIES.keys().pick_random()
	var sex: String = CatRules.CAT_SEXES.pick_random()
	var taken: Array = []  # every bar's cat has its own name
	for bar in SaveStore.list_bars():
		var name_taken := str(bar.get("cat", {}).get("name", ""))
		if name_taken != "" and bar.get("id", "") != Game.bar.get("id", ""):
			taken.append(name_taken)
	_typing_label.text = "Something furry is watching from under the counter..."
	var named: Dictionary = await _ai.ask_json(Prompts.cat_name_messages(_owner, str(Game.bar["name"]), coat, personality, sex, taken),
		_validate_cat_name.bind(taken), {"temperature": 0.9}, {"purpose": "cat_name", "taken": taken})
	_typing_label.text = ""
	var cat_name := str(named["name"]) if not named.is_empty() else CatRules.fallback_cat_name(randf(), taken)
	var cat_hangul := str(named.get("hangul", "")) if not named.is_empty() else str(Names.CAT_HANGUL.get(cat_name, ""))
	_new_cat(cat_name, coat, personality, sex, cat_hangul)


func _new_cat(cat_name: String, coat: String, personality: String, sex: String, hangul: String = "") -> void:
	Game.bar["cat"] = {"name": cat_name, "coat": coat, "personality": personality, "sex": sex, "hangul": hangul}
	Game.save()


func _show_cat() -> void:
	_cat = Game.bar["cat"].duplicate()
	_paint_cat()
	_cat_node.tooltip_text = Text.tip("%s, the tent's %s cat (%s)" % [_with_hangul(_cat), _cat["coat"], CatRules.CAT_PERSONALITIES.get(_cat["personality"], "")])
	_narrate("%s, the tent's %s cat, is %s." % [_cat["name"], _cat["coat"], CatRules.CAT_PERSONALITIES.get(_cat["personality"], _cat["personality"]).get_slice(":", 0)])


func _show_bar_name() -> void:
	_title_label.text = "KTBT  ·  %s" % Game.bar["name"]
	_title_label.tooltip_text = Text.tip(str(Game.bar.get("name_meaning", "")))


## Close the bar: during a night, the owner closes up early (see _close_early); after it (the
## night summary's button), back to the title screen, saved: straight away if the owner's
## free, otherwise once they've finished what they're doing (an AI call can't be stopped
## halfway).
func _on_leave_pressed() -> void:
	if _stopped or _closing_early:
		return
	if _night_open:
		_close_early()
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


## Closing up early: the sign goes out front and a bulb goes off, nobody new comes in (anyone
## waiting, or turning up, sees the sign and walks on), and the owner tells the counter why as
## soon as they're free (see _say_closing). Whoever's here finishes their night as usual, at
## their own pace (orders, chats, goodbyes), and once the tent's empty the night ends.
func _close_early() -> void:
	_closing_early = true
	_closing_to_say = true
	_closing_said = ""
	_closed_early_at = _clock
	_leave_button.disabled = true
	_leave_button.text = "Closing up..."
	_narrate("%s. %s decides to close up early tonight, and turns the sign round: 마감, closed." % [NightRules.clock_text(int(_clock)), _owner_display()])
	_prepared = {}
	var gone := 0
	while not _waiting.is_empty():
		_waiting.pop_front()
		_waiting_who.pop_front()
		_walk_past(gone * 1.5)
		gone += 1
	if gone > 0:
		_narrate("%s at the tarp %s the sign and %s on." % ["Someone" if gone == 1 else "The people", "sees" if gone == 1 else "see", "walks" if gone == 1 else "walk"])
	_show_closing_up()
	_update_info()


## The owner tells the counter why they're closing early (the AI's reason, or the game's), and
## it's on TV: the closed_early event, with the reason as its caption.
func _say_closing() -> void:
	_closing_to_say = false
	_owner_working = true
	var seated: Array = _guests.map(func(g): return str(g.customer["name"]))
	var owner_name := str(_owner["name"])
	_typing_label.text = "%s is thinking..." % _owner_display()
	var reply: Dictionary = await _ai.ask_json(
		Prompts.closing_messages(_owner, {"time": NightRules.clock_text(int(_clock)), "weather": _night_weather, "seated": seated, "customers": _night_visits}),
		Story.validate_closing.bind(owner_name, str(_owner["title"]), [owner_name] + seated, _cat_fact()), {"temperature": 0.9},
		{"purpose": "closing", "title": _owner["title"], "weather": _weather_kind})
	_typing_label.text = ""
	if _stopped or Game.bar.is_empty():
		return
	if reply.is_empty():
		reply = Story.closing_reason(_weather_kind, randf())
	_closing_said = str(reply["line"])
	await _wait_for_reader()
	var to := "" if _guests.is_empty() else " to everyone"
	_show("[color=#%s][b]%s%s:[/b][/color] %s\n\n" % [OWNER_TEXT.to_html(false), _esc(_owner_label()), to, Glossary.explain(_esc(_closing_said), _names_here())])
	_stats.record_line(_closing_said, [owner_name])
	var listener: Control = null
	for guest in _guests:
		if is_instance_valid(guest.node):
			listener = guest.node
			break
	_give_time_to_read(_closing_said, _say_in_bubble(_owner_node, listener, "→ everyone" if listener != null else "", OWNER_TEXT, OWNER_TEXT, _closing_said))
	for guest in _guests:
		guest.transcript.append({"speaker": owner_name, "text": _closing_said})
		guest.transcript.append({"action": "%s is closing up early: nobody new tonight, but there's no hurry for anyone already here." % owner_name})
	_event("closed_early", {"at": int(_clock), "seated": _guests.size(), "reason": str(reply.get("caption", ""))}, _owner_node)
	_owner_working = false


## Closing up, as you'd see it: a 마감 CLOSED board out front (it pops up), and the bulb at the
## far end switched off, so the tent's glow dims.
func _show_closing_up() -> void:
	if is_instance_valid(_closed_sign):
		_closed_sign.queue_free()
	_closed_sign = Control.new()
	_closed_sign.name = "ClosedSign"
	_closed_sign.position = Vector2(STAGE_SIZE.x - 210, 292)
	_closed_sign.size = Vector2(84, 80)
	_closed_sign.pivot_offset = Vector2(42, 80)  # (it pops up from the pavement)
	_closed_sign.rotation_degrees = -4.0
	_closed_sign.z_index = 4
	_closed_sign.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_closed_sign.tooltip_text = Text.tip("마감 magam: closed. The owner's closing up early tonight: nobody new, and everyone here finishes at their own pace.")
	_stage.add_child(_closed_sign)
	for leg_x in [14.0, 64.0]:
		_rect(_closed_sign, Vector2(leg_x, 50), Vector2(5, 30), Color("4a3524"))  # the A-frame's legs
	_rect(_closed_sign, Vector2(0, 0), Vector2(84, 56), Color("2c2a26"))  # a little chalkboard
	_rect(_closed_sign, Vector2(4, 4), Vector2(76, 48), Color("3d4a3f"))
	for line in [["마감", 22, 4.0], ["CLOSED", 12, 34.0]]:
		var label := Ktv.label(str(line[0]), int(line[1]), Ktv.CREAM)
		label.position = Vector2(0, float(line[2]))
		label.size = Vector2(84, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_closed_sign.add_child(label)
	_closed_sign.scale = Vector2(1.0, 0.0)
	var pop := _closed_sign.create_tween()
	pop.tween_property(_closed_sign, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The far bulb flickers, and goes off.
	if not _bulb_lights.is_empty():
		var bulb: ColorRect = _bulb_lights[-1]
		var off := bulb.create_tween()
		for k in 2:
			off.tween_property(bulb, "modulate:a", 0.25, 0.06)
			off.tween_property(bulb, "modulate:a", 1.0, 0.08 + 0.05 * k)
		off.tween_callback(_update_light.bind(true))


func _leave() -> void:
	if _night_open:
		_save_stats(false)  # a night cut short still gets a log
	elif _transcript_file != null and _transcript_file.is_open():
		_save_stats(true)  # closed while the owner was still writing the diary
	_stopped = true
	_night_open = false
	Game.back_to_title()


# --- The night -------------------------------------------------------------

## Tonight's date and weather: each bar's nights run a day at a time through the year (from
## its first_date: a new bar's is today's date), and the weather follows on from last night's
## (see Seasons.next_weather), with one roll of the dice, as when it was picked at random.
func _pick_weather() -> void:
	if not Game.bar.has("first_date"):
		# A new bar starts tonight's date (a bar from before the calendar too: tonight's today).
		var today := Hooks.first_date if Hooks.first_date >= 0 else Seasons.today()
		Game.bar["first_date"] = posmod(today - (_night_number - 1), Seasons.YEAR_DAYS)
	var first_date := int(Game.bar["first_date"])
	var doy := Seasons.day_of_year(first_date, _night_number)
	_night_date = Seasons.date(doy)
	var winter := Seasons.winter_number(first_date, _night_number)
	var snowed := int(Game.bar.get("snowed_winter", -1)) == winter
	_night_weather = Seasons.next_weather(doy, str(Game.bar.get("last_weather", "")), randf(), snowed)
	if _night_weather.contains("snow"):
		Game.bar["snowed_winter"] = winter
	Game.bar["last_weather"] = _night_weather


## Tonight's date as the prompts say it: "14 November, late autumn".
func _date_words() -> String:
	if _night_date.is_empty():
		return ""
	return "%s, %s" % [_night_date["text"], Seasons.season_words(Seasons.day_of_year(int(Game.bar.get("first_date", 0)), _night_number))]


## "14 Nov", for the top bar.
func _short_date() -> String:
	return "" if _night_date.is_empty() else "%d %s" % [int(_night_date["day"]), str(Seasons.MONTHS[int(_night_date["month"]) - 1]).substr(0, 3)]


## The tent opens at 6pm: a new night number, its day and its weather.
func _start_night() -> void:
	_night_number = int(Game.bar.get("nights", 0)) + 1
	_night_day = NightRules.night_day(int(Game.bar.get("first_day", 4)), _night_number)
	_pick_weather()
	var bar_id := str(Game.bar.get("id", ""))
	if _skyline.seed_for != bar_id:
		_skyline.show_city(Skyline.plan(STAGE_SIZE.x, hash(bar_id)), bar_id)  # (its own dice: the game's rolls don't shift)
	_specials = Orders.pick_specials(NightRules.weather_kind(_night_weather), randf(), randf())
	_clock = float(NightRules.OPEN_MINUTES)
	_night_visits = 0
	_night_takings = 0
	_night_lines = []
	_stats = NightStats.new()
	_events = NightEvents.new()
	_events.happened.connect(_stats.record_event)
	_events.happened.connect(_caption_for_event)
	_stats.events = _events.timeline  # (saved in the night's log, so a night's timeline can be looked back over)
	_stats.specials = _specials.duplicate()
	_stats.story = _before_night.duplicate()  # (how it opened: only the first night after opening has any)
	_stats.story["date"] = str(_night_date.get("text", ""))
	_stats.story["season"] = _date_words().get_slice(", ", 1)
	_before_night = {}
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
	_closing_early = false
	_closing_to_say = false
	_closing_said = ""
	if is_instance_valid(_closed_sign):
		_closed_sign.queue_free()
	_leave_button.disabled = false
	_leave_button.text = "Close the bar"
	_rush_shown = false
	_dawn_shown = false
	_attending = null
	_owner_stunned = ""
	_night_open = true
	_next_arrival = _clock + NightRules.next_arrival_gap(int(_clock), randf())
	_show_weather(NightRules.weather_kind(_night_weather))
	_cat_spot = "stove"  # every night starts with the cat asleep by the stove
	_cat_with = null
	_cat_next = randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y)
	_place_cat()
	_update_clock_label()
	_start_transcript()
	_show("\n[center][color=#%s]· · ·  Night %d  · · ·[/color][/center]\n\n" % [ACCENT.to_html(false), _night_number])
	_narrate("%s %s, %s. %s. The tarp goes up and the first pots go on." % [_night_day, _night_date.get("text", ""), NightRules.clock_text(NightRules.OPEN_MINUTES), Text.sentence_case(_night_weather)])
	if _night_weather == Seasons.FIRST_SNOW:
		_event("first_snow")


## Every frame: the clock and the stove move on, people turn up (or give up waiting), and if
## the owner's free, they get on with whatever's most urgent. At 3am the owner calls last
## orders; the night ends once the last customer has gone.
func _process(delta: float) -> void:
	_update_light()
	_skyline.set_minutes(_clock)
	if _loading != null and _loading.visible:
		_loading.status = _loading_status()
	_ambience.set_scene({"weather": _weather_kind, "people": _guests.size(), "cooking": not _kitchen.is_empty(),
		"open": _night_open, "minutes": int(_clock)})
	if not _night_open or _stopped:
		return
	var seconds_per_minute := _scaled(REAL_SECONDS_PER_GAME_MINUTE)
	_time_speed = move_toward(_time_speed, NightRules.time_speed(_people_in()), delta * SPEED_CHANGE_RATE)
	var minutes := delta * _time_speed / seconds_per_minute if seconds_per_minute > 0.0 else 60.0
	_count_time(delta)
	_cook(minutes)
	# Everyone's stay runs down, even when tests hold the clock.
	for guest in _guests:
		guest.stay_left -= minutes
	if Hooks.strollers:
		_stroll_next -= minutes
		# Catch up on everyone due (a slow frame, or time running fast, can cover several),
		# so how many walk by doesn't depend on the frame rate; a few at most, so no crowd.
		var due := 0
		while _stroll_next <= 0.0 and due < 3:
			_stroll()
			_stroll_next += NightRules.stroll_gap(int(_clock), randf())
			due += 1
		_stroll_next = maxf(_stroll_next, 0.0)
	if Hooks.cat_wanders and not _cat.is_empty():
		_cat_next -= minutes
		if _cat_next <= 0.0:
			_move_cat()
	if Hooks.run_clock:
		# After 3am the clock runs on while the last customers finish up.
		_clock += minutes
		_update_clock_label()
		while not _regulars_due.is_empty() and _clock >= float(_regulars_due[0]["time"]):
			var due: Dictionary = _regulars_due.pop_front()
			_arrive(float(due["time"]), str(due["id"]))
			_skip_arrivals += 1  # a regular instead of a newcomer: the night stays as busy
		while _clock >= _next_arrival and _next_arrival < NightRules.LAST_ARRIVAL_MINUTES:
			if _skip_arrivals > 0:
				_skip_arrivals -= 1
			else:
				_arrive(_next_arrival)
			_next_arrival += NightRules.next_arrival_gap(int(_next_arrival), randf())
	_give_up_waiting()
	if not _dawn_shown and _clock >= Captions.DAWN_AT and not _guests.is_empty():
		_dawn_shown = true
		_event("dawn")
	if _clock >= NightRules.CLOSE_MINUTES and not _last_orders:
		_call_last_orders()
	if not _carrying and not _ready_dishes.is_empty():
		_carry_dish()
	if _owner_working:
		return
	if _leave_requested:
		_leave()
	elif (_clock >= NightRules.CLOSE_MINUTES or (_closing_early and not _closing_to_say)) and _guests.is_empty() and not _greeting:
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
	if _closing_early:
		_narrate("Someone comes up to the tarp, sees the 마감 sign, and walks on.")
		_walk_past(0.0)
		return
	_waiting.append(when)
	_waiting_who.append(regular_id)
	_event("arrived", {"regular": regular_id != ""})
	_update_info()


## Someone who's waited too long with every stool taken gives up and walks on.
func _give_up_waiting() -> void:
	var gone := 0
	while not _waiting.is_empty() and _free_seats().is_empty() and _clock - float(_waiting[0]) > NightRules.GIVE_UP_MINUTES:
		_waiting.pop_front()
		_waiting_who.pop_front()
		_narrate("Someone peeks under the tarp, sees every stool taken, and walks on.")
		_event("walked_on", {"first": gone == 0})
		_walk_past(gone * 1.5)  # if several give up at once, they don't walk in a clump
		gone += 1
		_update_info()


## Someone walking along the street, not coming in: a dark figure on the pavement in front
## of the tent, at their own pace. Some are in twos or threes, walking together; plenty are on
## their phones. If it's raining or snowing they have an umbrella (of their own shape and
## size), or now and then none, and run for it (see Looks.rain_gear); a pair sometimes
## shares one. gear and company: instead of the dice (for tests; company 0: the dice).
func _stroll(gear: Dictionary = {}, company: int = 0) -> void:
	var from_left := randi() % 2 == 0
	var count := company if company > 0 else Looks.street_company(randf())
	var shared := count == 2 and gear.is_empty() and Looks.wet(_weather_kind) and randf() < Looks.SHARED_UMBRELLA_CHANCE
	var seconds := randf_range(6.0, 10.0)
	var gap := 46.0 if shared else 62.0  # (closer under one umbrella)
	_stats.record_street({1: "alone", 2: "in twos", 3: "in threes"}.get(count, "in a group"))
	if shared:
		_stats.record_street("sharing an umbrella")
	for i in count:
		var own := gear
		if shared:
			# One big umbrella, held by the first, out over the space between them.
			own = {"umbrella": true, "shape": "wide", "size": 1.12, "tilt": 0.0, "reach": gap / 2.0 * (-1.0 if from_left else 1.0)} if i == 0 else {"none": true}
		elif own.is_empty():
			own = Looks.rain_gear(_weather_kind, randf(), randf(), randf())
		if count > 1 and not own.is_empty() and not own.has("none") and not bool(own["umbrella"]):
			own = Looks.rain_gear(_weather_kind, 1.0, randf(), randf())  # (friends don't run off and leave each other)
		# Following on behind (from where they're walking from), a little up or down the pavement.
		var behind := gap * i * (-1.0 if from_left else 1.0)
		_stroller(from_left, behind, (-6.0 if i % 2 == 1 else 4.0) * signf(i), own, count == 1, seconds)


func _stroller(from_left: bool, behind: float, up: float, gear: Dictionary, alone: bool, seconds: float) -> void:
	_strollers += 1
	var shade: Color = CUSTOMER_COLORS.pick_random().darkened(0.55)
	var start_x := (OFFSCREEN_LEFT_X if from_left else OFFSCREEN_RIGHT_X) + behind
	var person := _person(_stage, Vector2(start_x, STROLL_Y + up), shade)
	person.name = "Stroller%d" % _strollers
	_dress(person, _street_look())
	person.z_index = 1  # in front of the counter and stools
	person.modulate = Color(0.42, 0.42, 0.5, 0.92)  # darker: out in the street, in front of the light
	if not gear.has("none"):
		_gear_up(person, gear, from_left)
	var running := _is_running(person)
	_stats.record_street("walked by")
	if Looks.on_phone(alone, running, randf()):
		_phone(person)
		_stats.record_street("on a phone")
	var tween := person.create_tween()
	tween.tween_property(person, "position:x", (OFFSCREEN_RIGHT_X if from_left else OFFSCREEN_LEFT_X) + behind,
		_scaled(randf_range(2.4, 3.4) if running else seconds))
	tween.tween_callback(person.queue_free)


## A phone held up in front of them, its screen lighting their face, glancing up now and then.
func _phone(person: Control) -> void:
	person.set_meta("on_phone", true)
	var glow := _rect(person, Vector2(30, 14), Vector2(26, 26), Color(0.55, 0.75, 1.0, 0.18))  # the screen's light on their face
	glow.name = "PhoneGlow"
	var phone := _rect(person, Vector2(36, 34), Vector2(12, 20), Color("1c1c24"))
	phone.name = "Phone"
	var screen := _rect(phone, Vector2(1.5, 2), Vector2(9, 15), Color(0.7, 0.85, 1.0))
	screen.name = "Screen"
	var flicker := screen.create_tween().set_loops()  # scrolling: the light changes a little
	flicker.tween_property(screen, "color", Color(0.85, 0.9, 1.0), _scaled(randf_range(0.6, 1.4)))
	flicker.tween_property(screen, "color", Color(0.65, 0.8, 1.0), _scaled(randf_range(0.6, 1.4)))


## An umbrella held over someone's head: a canopy on a shaft (lots of Seoul's are clear), in
## the shape, size and tilt Looks.rain_gear picked. It's held at the hand, so it tilts and
## scales from there.
const UMBRELLA_COLOURS := [Color(0.85, 0.9, 1.0, 0.35), Color("26252e"), Color("2c3a5c"), Color("7a2a2a"), Color("8a7a2a")]
const UMBRELLA_CLEAR := Color(0.85, 0.9, 1.0, 0.3)
const UMBRELLA_HAND := Vector2(40, 10)
## Each shape's canopy: half-width, height, how far the rim hangs below its middle, how many ribs.
const UMBRELLA_CANOPIES := {
	"dome": {"across": 64.0, "high": 30.0, "rim": 6.0, "ribs": 4, "middle": -18.0},
	"wide": {"across": 78.0, "high": 22.0, "rim": 5.0, "ribs": 5, "middle": -20.0},
	"bubble": {"across": 50.0, "high": 46.0, "rim": 14.0, "ribs": 4, "middle": -6.0},
	"compact": {"across": 54.0, "high": 26.0, "rim": 6.0, "ribs": 3, "middle": -16.0},
}

func _umbrella(person: Control, gear: Dictionary = {"umbrella": true, "shape": "dome", "size": 1.0, "tilt": 0.0}) -> void:
	var holder := Node2D.new()
	holder.name = "Umbrella"
	holder.position = UMBRELLA_HAND + Vector2(float(gear.get("reach", 0.0)), 0)  # (reach: held out over a friend too)
	holder.rotation = float(gear.get("tilt", 0.0))
	holder.scale = Vector2.ONE * float(gear.get("size", 1.0))
	holder.set_meta("shape", str(gear.get("shape", "dome")))
	person.add_child(holder)
	var shape: Dictionary = UMBRELLA_CANOPIES.get(str(gear.get("shape", "dome")), UMBRELLA_CANOPIES["dome"])
	var middle := Vector2(0, float(shape["middle"]) - UMBRELLA_HAND.y)  # (from the hand)
	var across := float(shape["across"])
	var high := float(shape["high"])
	var metal := Color("55536b")
	holder.add_child(_bar(Vector2(-1, middle.y - high + 8), Vector2(2, high - 8 - middle.y), metal))  # the shaft, down to the hand
	var canopy := Polygon2D.new()
	canopy.name = "Canopy"
	var points := PackedVector2Array()
	for step in 13:
		var angle: float = PI + PI * step / 12.0
		points.append(middle + Vector2(cos(angle) * across, sin(angle) * high))
	var ribs := int(shape["ribs"])
	for rib in range(ribs - 1, -1, -1):  # back along a scalloped rim, dipping between the ribs
		points.append(middle + Vector2(-across + 2.0 * across * (rib + 0.5) / ribs, float(shape["rim"])))
		if rib > 0:
			points.append(middle + Vector2(-across + 2.0 * across * rib / ribs, 0))
	canopy.polygon = points
	canopy.color = UMBRELLA_CLEAR if str(gear.get("shape", "")) == "bubble" else UMBRELLA_COLOURS.pick_random()
	holder.add_child(canopy)
	holder.add_child(_bar(Vector2(-2, middle.y - high - 4), Vector2(4, 6), metal))  # the tip
	# The weather lands on it (unlike some K-drama umbrellas): snow builds up on top, and
	# rain runs off the rim in drops.
	holder.set_meta("middle", middle)
	holder.set_meta("across", across)
	if _weather_kind == "snow":
		_snow_cap(holder, middle, across, high)
	elif _weather_kind in ["rain", "drizzle"]:
		for k in (5 if _weather_kind == "rain" else 3):
			_drip(holder, middle + Vector2(_scenery_dice.randf_range(-across, across) * 0.95, float(shape["rim"])))


## Snow settling on an umbrella: a white cap over the top, building up while they walk.
func _snow_cap(holder: Node2D, middle: Vector2, across: float, high: float) -> void:
	var cap := Polygon2D.new()
	cap.name = "SnowCap"
	var points := PackedVector2Array()
	for step in 11:  # along the top, a little above the canopy...
		var angle: float = PI * 1.12 + PI * 0.76 * step / 10.0
		points.append(middle + Vector2(cos(angle) * across * 0.98, sin(angle) * (high + 4.0)))
	for step in range(10, -1, -1):  # ...and back along it, lower in the middle: thicker on top
		var angle: float = PI * 1.12 + PI * 0.76 * step / 10.0
		points.append(middle + Vector2(cos(angle) * across * 0.95, sin(angle) * high * 0.82))
	cap.polygon = points
	cap.color = Color(1, 1, 1, 0.92)
	cap.modulate.a = 0.0
	holder.add_child(cap)
	cap.create_tween().tween_property(cap, "modulate:a", 1.0, _scaled(5.0))  # building up


## A raindrop running off the umbrella's rim, again and again.
func _drip(holder: Node2D, from: Vector2) -> void:
	var drop := _bar(Vector2(-1, 0), Vector2(2, 5), Color(0.7, 0.82, 1.0, 0.85))
	drop.name = "Drip"
	drop.position = from
	drop.modulate.a = 0.0
	holder.add_child(drop)
	var fall := drop.create_tween().set_loops()
	fall.tween_interval(_scaled(_scenery_dice.randf_range(0.2, 1.4)))
	fall.tween_property(drop, "modulate:a", 1.0, 0.01).from(0.0)
	fall.tween_property(drop, "position", from + Vector2(0, 34), _scaled(0.35)).from(from).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(drop, "modulate:a", 0.0, _scaled(0.35))


## Under the tarp, the umbrella gets a shake before it's folded: the snow (or the rain) flies off.
func _shake_off(person: Control, holder: Node2D) -> void:
	var snowy := holder.get_node_or_null("SnowCap") != null
	var wet := holder.get_node_or_null("Drip") != null
	if not snowy and not wet:
		return
	var middle: Vector2 = holder.get_meta("middle", Vector2.ZERO)
	var across := float(holder.get_meta("across", 50.0))
	var start := holder.position + middle * holder.scale
	for k in 7:
		var bit := _bar(Vector2(-2, -2), Vector2(4, 4) if snowy else Vector2(2, 5), Color(1, 1, 1, 0.9) if snowy else Color(0.7, 0.82, 1.0, 0.8))
		bit.name = "ShakenOff"
		bit.position = start + Vector2(_scenery_dice.randf_range(-across, across), _scenery_dice.randf_range(-10.0, 4.0))
		person.add_child(bit)
		var fly := bit.create_tween()
		fly.tween_property(bit, "position", bit.position + Vector2(_scenery_dice.randf_range(-40.0, 40.0), _scenery_dice.randf_range(40.0, 90.0)), _scaled(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(bit, "modulate:a", 0.0, _scaled(0.5))
		fly.tween_callback(bit.queue_free)


## A rectangle for something that isn't a Control (the umbrella's shaft and tip).
func _bar(pos: Vector2, bar_size: Vector2, colour: Color) -> Polygon2D:
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([pos, pos + Vector2(bar_size.x, 0), pos + bar_size, pos + Vector2(0, bar_size.y)])
	bar.color = colour
	return bar


## No umbrella: a bag (or a jacket) held over their head, leaning into it, bobbing as they run.
func _running_for_it(person: Control, going_right: bool) -> void:
	var ground := person.position.y
	person.set_meta("running", true)
	person.set_meta("ground", ground)
	var cover := Polygon2D.new()
	cover.name = "OverHead"
	cover.polygon = PackedVector2Array([Vector2(8, -4), Vector2(72, -8), Vector2(70, 4), Vector2(10, 6)])
	cover.color = CUSTOMER_COLORS.pick_random().darkened(0.4)
	person.add_child(cover)
	person.pivot_offset = Vector2(40, 150)  # leaning from the feet
	person.rotation = 0.1 if going_right else -0.1
	var bob := person.create_tween().set_loops()
	bob.tween_property(person, "position:y", ground - 6, _scaled(0.14)).set_trans(Tween.TRANS_SINE)
	bob.tween_property(person, "position:y", ground, _scaled(0.14)).set_trans(Tween.TRANS_SINE)
	person.set_meta("bob", bob)


## A passer-by in the street: they slow down at the tent, look in, and carry on. Runs by
## itself; the owner doesn't stop for it.
func _walk_past(delay: float) -> void:
	_passers_by += 1
	var from_left := randi() % 2 == 0
	var person := _person(_stage, Vector2(OFFSCREEN_LEFT_X if from_left else OFFSCREEN_RIGHT_X, CUSTOMER_Y), CUSTOMER_COLORS.pick_random().darkened(0.35))
	person.name = "PasserBy%d" % _passers_by
	_dress(person, _street_look())
	person.modulate = Color(0.7, 0.7, 0.78)
	_gear_up(person, _pick_rain_gear(), from_left)  # (they wanted in, so they're dressed for the weather like anyone)
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
	_narrate("%s. %s calls last orders and starts stacking the spare stools." % [NightRules.clock_text(int(_clock)), _owner_display()])
	_event("last_orders", {}, _owner_node)
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
	var line := NightRules.memorable_line(_night_lines)
	SaveStore.record_night(Game.bar, {
		"night": _night_number, "day": _night_day, "weather": _night_weather,
		"customers": _night_visits, "takings": _night_takings,
		"line": line.duplicate(),
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_narrate("%s. %s pulls down the tarp and counts the takings." % [NightRules.clock_text(int(_clock)), _owner_display()])
	_update_clock_label()
	var t := "[center][font_size=34][b]Night %d at %s[/b][/font_size]\n" % [_night_number, _esc(Game.bar["name"])]
	t += "[color=#%s]%s, %s[/color]\n\n" % [MUTED.to_html(false), _night_day, _esc(_night_weather)]
	t += "%d %s  ·  %s tonight\n" % [_night_visits, "customer" if _night_visits == 1 else "customers", Menu.format_won(_night_takings)]
	t += "[color=#%s]%s in total[/color]" % [MUTED.to_html(false), Menu.format_won(_takings)]
	if not line.is_empty():
		t += "\n\n[i][color=#%s]\"%s\"[/color][/i]\n[color=#%s]%s[/color]" % [OWNER_TEXT.to_html(false), _esc(line["text"]), MUTED.to_html(false), _esc(line["speaker"])]
	t += "[/center]\n\n" + _stats.panel_text(0, 0)
	_summary_text.text = t
	_summary_text.visible = false  # the numbers are behind the Stats button: the diary's the thing
	_stats_button.button_pressed = false
	_summary.visible = true
	await _write_diary()
	_save_stats(true)  # after the diary, so the transcript runs right to the end (and has it)
	if _closing_early:  # (written up: the button's for leaving again)
		_closing_early = false
		_leave_button.disabled = false
		_leave_button.text = "Close the bar"


## 3am: the owner writes tonight up in their diary (the AI, from the facts the game picks, or
## the game itself if it can't), shown as the end-of-night page and kept with the bar.
func _write_diary() -> void:
	for button in _summary_buttons:
		button.disabled = true
	var facts := _diary_facts()
	_diary_page.visible = true
	_diary_page.show_writing(_night_number, _night_day, _night_weather, _owner_display())
	var text := ""
	var by := "game"
	if Hooks.diaries:
		var reply: Dictionary = await _ai.ask_json(Prompts.diary_messages(_owner, facts), _validate_diary.bind(facts), {"temperature": 0.8},
			{"purpose": "diary", "facts": facts})
		if _stopped or Game.bar.is_empty():
			return
		text = str(reply.get("entry", ""))
		by = "owner" if text != "" else "game"
	if text == "":
		text = Story.stitched_diary(facts)
	var entry := {"episode": _night_number, "night": _night_number, "day": _night_day, "weather": _night_weather,
		"text": text, "stamp": Story.diary_stamp(facts), "by": by, "facts": facts, "when": int(Time.get_unix_time_from_system())}
	SaveStore.record_diary(Game.bar, entry)
	Game.save()
	_stats.story["diary_by"] = "ai" if by == "owner" else "game"
	_stats.story["diary_stamp"] = str(entry["stamp"])
	_diary_page.show_entry(entry, "%s's diary" % _owner["name"])
	_show("[i][color=#%s]%s's diary, episode %d: %s[/color][/i]\n\n" % [MUTED.to_html(false), _owner["name"], _night_number, _esc(text)])
	for button in _summary_buttons:
		button.disabled = false


func _validate_diary(data: Variant, facts: Dictionary) -> String:
	return Story.validate_diary(data, facts)


## What the owner's diary is written from: the game's facts about tonight. Kept with the entry,
## for the diary book and "Previously on…".
func _diary_facts() -> Dictionary:
	return Story.diary_facts(_events.timeline, {
		"episode": _night_number, "day": _night_day, "weather": _night_weather, "owner": str(_owner["name"]), "date": _date_words(),
		"owner_gender": str(_owner.get("gender", "")), "customers": _night_visits, "takings": _night_takings,
		"before": Game.bar.get("night_log", []).slice(0, -1).map(func(n): return int(n.get("takings", 0))),
		"regulars": _regulars().map(func(r): return {"name": str(r["name"]), "founding": bool(r.get("founding", false)), "gender": str(r.get("gender", ""))}),
		"cat": str(_cat.get("name", "")), "line": NightRules.memorable_line(_night_lines), "specials": _specials.duplicate(),
		"closed_early": NightRules.clock_text(int(_closed_early_at)) if _closing_early else "",
		"closed_said": _closing_said if _closing_early else "",
	})


## "Previously on…": what the recap's written from: the last diary entry and its facts, the
## regulars (and each one's latest memory, for a bar from before diaries), and who may be named.
func _recap_facts() -> Dictionary:
	var diary: Array = Game.bar.get("diary", [])
	var last: Dictionary = diary[-1] if not diary.is_empty() else {}
	var regulars: Array = _regulars()
	var names: Array = [str(_owner.get("name", ""))]
	for regular in regulars:
		names.append(str(regular["name"]))
	var latest_memories: Array = []
	if last.is_empty():
		for regular in regulars:
			var kept: Array = regular.get("memories", [])
			if not kept.is_empty():
				latest_memories.append("%s, a regular: %s" % [regular["name"], kept[-1].get("owner", "")])
	var last_facts: Dictionary = last.get("facts", {})
	var hangul := {str(_owner.get("name", "")): str(_owner.get("hangul", ""))}  # for the recap's name tags
	for regular in regulars:
		hangul[str(regular["name"])] = str(regular.get("hangul", ""))
	for person in last_facts.get("people", []):
		names.append(str(person["name"]))
		if not hangul.has(str(person["name"])) or str(hangul[str(person["name"])]) == "":
			hangul[str(person["name"])] = str(person.get("hangul", ""))
	return {
		"episode": int(Game.bar.get("nights", 0)) + 1, "bar": str(Game.bar.get("name", "")), "owner": str(_owner.get("name", "")),
		"archetype": str(_owner.get("archetype", "")), "owner_data": _owner.duplicate(true), "cat": str(Game.bar.get("cat", {}).get("name", "")),
		"regulars": regulars.map(func(r): return str(r["name"])), "names": names,
		"last": last_facts, "last_entry": str(last.get("text", "")), "memories": latest_memories, "hangul": hangul,
		"teaser_example": Story.RECAP_TEASER_EXAMPLES[_scenery_dice.randi() % Story.RECAP_TEASER_EXAMPLES.size()],
	}


## The recap for tonight: the AI's, checked, or the game's own from the same facts.
func _write_recap() -> Dictionary:
	var facts := _recap_facts()
	var reply: Dictionary = await _ai.ask_json(Prompts.recap_messages(facts), _validate_recap.bind(facts), {"temperature": 0.85},
		{"purpose": "recap", "facts": facts, "tries": 2})  # (two goes, then the game's own: it's on the loading screen)
	_before_night["recap_by"] = "game" if reply.is_empty() else "ai"
	if reply.is_empty():
		reply = Story.stitched_recap(facts)
	return reply


func _validate_recap(data: Variant, facts: Dictionary) -> String:
	return Story.validate_recap(data, facts)


## Plays a recap full screen and waits for it to finish (or be skipped).
func _play_recap(recap: Dictionary, opener: bool) -> void:
	var screen := RecapScreen.new()
	screen.time_scale = _scaled(1.0)
	screen.sting = _ambience.sting
	add_child(screen)
	var facts := _recap_facts()
	# A different K-TV style each time (Story.RECAP_STYLES), from last time's biggest moment.
	var style := Story.pick_recap_style(facts["last"], str(Game.bar.get("last_recap_style", "")), randf())
	Game.bar["last_recap_style"] = style
	_before_night["recap_style"] = style
	var extras := {"people": facts["hangul"], "moments": facts["last"].get("moments", []), "weather": str(facts["last"].get("weather", "")), "style": style}
	screen.play(recap.get("beats", []), str(recap.get("teaser", "")), int(Game.bar.get("nights", 0)) + 1, str(Game.bar.get("name", "")), opener, extras)
	await screen.finished
	_recap_said = "%s %s %s" % ["Series opener:" if opener else "Previously on…", " ".join(PackedStringArray(recap.get("beats", []))), recap.get("teaser", "")]
	_show("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(_recap_said)])


## The owner's diary as a book, over everything (the night carries on behind it).
func _open_diary() -> void:
	if find_child("DiaryBook", false, false) != null:
		return
	var book := DiaryBook.new()
	add_child(book)
	book.open(Game.bar.get("diary", []), "%s's diary" % _owner.get("name", ""))


## The end-of-night Stats button: the numbers instead of the diary page, and back.
func _on_summary_stats_toggled(on: bool) -> void:
	_summary_text.visible = on
	_diary_page.visible = not on
	_stats_button.text = "Diary" if on else "Stats"  # (and back)


func _on_next_night_pressed() -> void:
	_summary.visible = false
	_start_night()


func _update_clock_label() -> void:
	if _night_number == 0:
		return
	_moment_label.text = "Night %d  ·  %s %s  ·  %s  ·  %s" % [_night_number, _night_day, _short_date(), NightRules.clock_text(int(_clock)), _night_weather]
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
	if _closing_to_say:  # (first: anyone settling up hears why before they go)
		_say_closing()
		return
	var payer := _ready_to_pay()
	if payer != null:
		_settle_up(payer)
		return
	if not _reaction_pending.is_empty():
		_ask_pending_reaction()
		return
	var chance := BUSY_CHAT_CHANCE if _guests.size() >= People.BUSY_COUNTER else CHAT_CHANCE
	if Hooks.chat_chance_override >= 0.0:
		chance = Hooks.chat_chance_override
	var lonely := _left_alone_longest()
	if lonely != null or _chat_possible():
		_stats.free_turns += 1  # (counted only when there's someone to talk to, not every idle frame)
	if _chat_possible():
		_stats.chat_chances += 1
		if randf() < chance:
			_counter_chat()
			return
	# Inventing the next customer comes after customers' chances to chat (which don't need
	# the owner), so it only ever takes a turn the owner would have spent talking. (Before
	# them, chats fell from about 15% of lines to 6%.)
	if _should_prepare():
		_prepare_customer()
		return
	if lonely != null:
		_talk(lonely)


## After midnight (for the order and opener situations).
func _late() -> bool:
	return _clock >= 24 * 60


## Something more urgent than chatting needs the owner.
func _urgent() -> bool:
	return _can_greet() or _ready_to_pay() != null


func _can_greet() -> bool:
	return not _waiting.is_empty() and not _free_seats().is_empty() and not _last_orders and not _closing_early


func _free_seats() -> Array:
	var free := range(NightRules.SEATS)
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
		"finished": finished, "clock": NightRules.clock_text(int(_clock)),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"ai_backend": str(_ai.settings.get("backend", "")), "ai_model": str(_ai.settings.get("model", "")),
		"offline": _ai.offline, "time_speeds": NightRules.TIME_SPEEDS, "reading_pauses": _reading_toggle.button_pressed,
	}
	var path := _stats.save(context, str(Game.bar.get("id", "bar")), _night_number)
	if path != "" and Hooks.print_paths:
		print("Night stats saved: ", ProjectSettings.globalize_path(path))
	_finish_transcript(context)


## Adds to the transcript on screen and, during a night, to tonight's transcript file.
func _show(bbcode: String) -> void:
	_log.append_text(Glossary.explain_hangul(bbcode))  # (any Hangul explains itself on hover)
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
	var folder := Hooks.transcript_folder
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
	if _recap_said != "":
		_transcript_file.store_string(_recap_said + "\n\n")
		_recap_said = ""
	_transcript_file.flush()
	if Hooks.print_paths:
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_options_button.button_pressed = not _options_button.button_pressed


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
	guest.quick_greeting = People.quick_greeting(_waiting.size(), _guests.size())
	guest.seat = _free_seats().pick_random()
	guest.arrived = NightRules.clock_text(int(_clock))
	guest.arrived_minutes = int(_clock)
	guest.moment = {"day": _night_day, "time": guest.arrived, "weather": _night_weather, "date": _date_words()}
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
		customer = _take_prepared()
		if customer.is_empty():
			customer = await _new_customer(guest.arrived)
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
	guest.company = Hooks.company_override if Hooks.company_override != "" else People.company(randf())
	customer["company"] = guest.company
	var stay := Hooks.stay_minutes_override if Hooks.stay_minutes_override >= 0 else People.stay_minutes(guest.company, randf())
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
	_update_info()
	var friends_in: Array = _guests.filter(func(g): return g != guest and not regular.is_empty() and not _friend(guest, g).is_empty())
	var sat := {"name": str(customer["name"]), "gender": str(customer.get("gender", "")), "job": str(customer.get("job", "")),
		"age_range": str(look.get("age_range", "")), "company": guest.company,
		"seat": guest.seat, "seated": _guests.size(), "minutes": int(_clock),
		"regular": "" if regular.is_empty() else ("founding" if bool(regular.get("founding", false)) else "regular"),
		"friend": str(friends_in[0].customer["name"]) if not friends_in.is_empty() else "",
		"visit": int(regular.get("visits", 0)) + 1, "years": str(regular.get("since", ""))}
	# (The rush is about the tent, not them: its caption goes in the middle.)
	var at_stool := Vector2(SEAT_X[guest.seat], CUSTOMER_Y - 60)  # (they're still walking to it)
	var rushing: bool = regular.is_empty() and not _rush_shown and _guests.size() >= Captions.RUSH_SEATED
	_event("sat_down", sat, null, Vector2(-1, -1) if rushing else at_stool)
	_welcome_at_door(guest)
	if regular.is_empty():  # a regular's look is known by now
		_narrate(Text.as_sentence(str(customer["appearance"])))
	_attend(guest, false)
	_walk_in(guest)  # the owner doesn't wait for them to sit down: the AI's already on their order

	# 2. They say hello and order in one line, so what they say matches what they get.
	# The game decides who's extra hungry (two mains) or having a rough night (two drinks).
	_typing_label.text = "%s is looking at the menu..." % customer["name"]
	var hungry := randf() < HUNGRY_CHANCE
	var rough_night := randf() < ROUGH_NIGHT_CHANCE
	var craving := Talk.craving(NightRules.weather_kind(_night_weather), rough_night, guest.company == "chatty", randf(), randf())
	var situation := (Talk.order_moment(not regular.get("usual", []).is_empty(), regular.is_empty(), _late(), randf(), randf()) + " " + craving).strip_edges()
	var order: Dictionary = await _ai.ask_json(
		Prompts.order_messages(_owner, customer, guest.moment, Menu.prompt_list(Menu.shuffled_ids(), _specials), guest.transcript, hungry, rough_night, situation),
		_validate_order.bind(2 if hungry else 1, 2 if rough_night else 1), {"temperature": 0.7},
		{"purpose": "order", "title": _owner["title"], "max_mains": 2 if hungry else 1, "max_drinks": 2 if rough_night else 1})
	_typing_label.text = ""
	var items: Array = ["soju", "odeng"]
	if order.is_empty():
		_narrate("(The AI couldn't come up with a valid order, so the game served soju and odeng: %s.)" % _ai.last_error)
	else:
		items = order["items"]
		_stats.sides_added += int(order.get("added_sides", 0))
		_stats.unsaid_dropped += int(order.get("dropped_unsaid", 0))
		_stats.record_opening("order", str(order["line"]))
		if situation != "":
			_stats.order_situations += 1
		if craving != "":
			_stats.cravings += 1
		await _say(guest, false, str(order["line"]))
	guest.order = items.duplicate()
	guest.first_order = items.duplicate()
	_serve(guest, items, true)
	_stats.serve_waits.append(_clock - turned_up)
	_event("greeted", {"name": str(guest.customer["name"]), "quick": guest.quick_greeting}, _owner_node)

	# 3. Will they order more partway through? The game decides how often (often not,
	# sometimes once, rarely twice) and on which of their turns, spaced out by the rules.
	# If they leave before a turn comes round, that order never happens.
	var extra_count := Orders.extra_order_count(randf())
	guest.extra_turns = Orders.extra_order_turns(randi_range(3, 5) + extra_count, extra_count)
	# 4. On a quiet night, a first word with the owner straight away. When it's busy, that
	# waits until the owner has a moment.
	if not guest.quick_greeting:
		await _converse(guest, 1, false)
	_task_done()


## Someone new: the AI invents them, in two steps (name and gender, then the rest), to fit the
## look and age range the game decides. {} if the AI couldn't.
## Invents a new customer arriving at this time (as text): {} if the AI can't. ahead: being
## invented before they arrive (see _prepare_customer), so nothing's shown while it thinks.
func _new_customer(arrived: String, ahead: bool = false) -> Dictionary:
	# 1. Who is it? First just a name and gender: a quick ask, so if the name's taken, asking
	# again costs little. Then the rest of that person.
	if not ahead:
		_typing_label.text = "Someone is coming down the street..."
	var taken: Array = [str(_owner["name"])]  # nobody at the counter shares a name
	for other in _guests:
		taken.append(str(other.customer["name"]))
	var used: Array = _names_tonight.filter(func(n): return not taken.has(n))
	# About one in a hundred is non-binary: the game decides; otherwise the AI chooses.
	var gender := Hooks.gender_override if Hooks.gender_override != "" else People.game_gender(randf())
	var who: Dictionary = await _ai.ask_json(
		Prompts.customer_name_messages(_night_day, arrived, _night_weather, taken, used, gender),
		_validate_customer_name.bind(taken, gender), {"temperature": 1.0}, {"purpose": "customer_name", "taken": taken, "gender": gender})
	var customer := {}
	var look := {}
	if not who.is_empty():
		if not ahead:
			_typing_label.text = "%s is coming down the street..." % who["name"]
		# The game decides their age range and look (by the weather); the AI invents someone
		# who'd look like that.
		look = Looks.pick_look(str(who["gender"]), Looks.pick_age_range(randf()), _weather_kind)
		customer = await _ai.ask_json(
			Prompts.customer_messages(_night_day, arrived, _night_weather, false, str(who["name"]), str(who["gender"]), _jobs_tonight, _looks_tonight.slice(-VARIETY_LOOKS), look),
			_validate_customer_details.bind(str(look["age_range"])), {"temperature": 0.9},
			{"purpose": "customer", "name": who["name"], "gender": who["gender"], "look": look})
	if not ahead:
		_typing_label.text = ""
	if customer.is_empty():
		return {}
	customer["name"] = who["name"]
	customer["hangul"] = str(who.get("hangul", ""))
	customer["gender"] = who["gender"]
	customer["look"] = look
	return customer


## Whether to invent the next customer now: the owner's free (this comes after greeting,
## settling up and a put-off reaction), the tent's open for new people, and there's nobody
## ready yet (or the one ready is too old to use).
func _should_prepare() -> bool:
	if not Hooks.prepare_customers or not _night_open or _last_orders or _closing_early or _clock >= NightRules.CLOSE_MINUTES:
		return false
	if not _prepared.is_empty() and _clock - float(_prepared["at"]) > PREPARED_FRESH_MINUTES:
		_prepared = {}
		_stats.prepared_stale += 1
	return _prepared.is_empty()


## Invents the next new customer ahead, while the owner's free: the same AI asks as when they
## arrive, just not while they're standing at the tarp waiting.
func _prepare_customer() -> void:
	_owner_working = true
	var at := _clock
	var customer := await _new_customer(NightRules.clock_text(int(_clock)), true)
	if _stopped:
		return
	if not customer.is_empty():
		_prepared = {"customer": customer, "at": at}
		_stats.prepared += 1
	_task_done()


## The customer invented ahead, if there is one fit to come in now (not too old, and nobody
## at the counter has their name), or {}. Either way, there's none ready after this.
func _take_prepared() -> Dictionary:
	if _prepared.is_empty():
		return {}
	var ready_one: Dictionary = _prepared["customer"]
	var at := float(_prepared["at"])
	_prepared = {}
	var taken: Array = [str(_owner["name"])] + _guests.map(func(g): return str(g.customer["name"]))
	if _clock - at > PREPARED_FRESH_MINUTES or taken.has(str(ready_one["name"])):
		_stats.prepared_stale += 1
		return {}
	_stats.prepared_used += 1
	return ready_one


## Drinks (and anything else that needs no cooking) go on the table now, with the free
## banchan for a first order; cooked dishes join the queue at the stove.
func _serve(guest: Guest, items: Array, first_order: bool) -> void:
	_event("ordered", {"name": str(guest.customer["name"]), "items": items.duplicate(), "first": first_order})
	var now := Orders.instant_items(items)
	var later := Orders.cooked_items(items)
	_typing_label.text = "%s is pouring..." % _owner_display()
	for id in now:
		_add_dish(guest, id)
		guest.served.append(id)
	guest.version += 1
	guest.food_news = true
	if first_order:
		guest.drinks_row.add_child(_banchan_shape())
	if guest.food_moment == "":
		guest.food_moment = Talk.served_moment(now, randf(), randf())
	if now.any(func(id): return Menu.find(id).get("kind", "") == "drink"):
		_ambience.play("pour")
		_ambience.play("clink", 1.0, 0.8)
		var drink: String = str(Menu.find(now.filter(func(id): return Menu.find(id).get("kind", "") == "drink")[0]).get("name", ""))
		var poured := {"name": str(guest.customer["name"]), "first": first_order, "drink": drink,
			"drinks": guest.order.filter(func(id): return Menu.find(id).get("kind", "") == "drink").size()}
		if first_order:  # (they may still be walking to their stool)
			_event("drinks_poured", poured, null, Vector2(SEAT_X[guest.seat], CUSTOMER_Y - 60))
		else:
			_event("drinks_poured", poured, guest.node)
		_tipsy(guest)
	elif not now.is_empty():
		_ambience.play("clink", 0.55)  # a bowl of odeng or rice set down
	var was_backed := _kitchen.size() >= Captions.STOVE_BACKED
	for id in later:
		_kitchen.append({"guest": guest, "id": id, "left": float(Menu.cook_minutes(id)), "ordered": _clock})
	if not was_backed and _kitchen.size() >= Captions.STOVE_BACKED:
		_event("stove_backed", {"dishes": _kitchen.size()})
	_typing_label.text = ""
	_update_stove()
	var said := ""
	var done := ""
	if first_order:
		said = "Served: %s, with the free banchan (%s)." % [Orders.item_names(now), BANCHAN]
		done = "%s serves: %s, with the free banchan (%s)." % [_owner["name"], Orders.item_names(now), BANCHAN]
	elif not now.is_empty():
		said = "Served: %s." % Orders.item_names(now)
		done = "%s brings: %s." % [_owner["name"], Orders.item_names(now)]
	if not later.is_empty():
		said += " On the stove: %s." % Orders.item_names(later)
		done += " %s puts %s on the stove; it isn't ready yet." % [_owner["name"], Orders.item_names(later)]
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
	var item_name := str(Menu.find(id)["name"])
	_narrate("%s brings the %s over to %s." % [_owner_display(), item_name, guest.customer["name"]])
	if guest.food_moment == "":
		guest.food_moment = Talk.served_moment([id], randf(), randf())
	var food_served := guest.served.filter(func(served_id): return Menu.find(served_id).get("kind", "") == "food").size()
	_event("dish_served", {"name": str(guest.customer["name"]), "dish": item_name, "food_served": food_served,
		"wait": _clock - float(dish["ordered"])}, guest.node)
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
	if _stopped or Game.bar.is_empty():
		return  # the bar was closed while they said goodbye: nothing to record it in
	var bill := Orders.bill(guest.order)
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
	var standing := ""
	var known := _regular(str(guest.customer.get("regular_id", "")))
	if not known.is_empty():
		standing = "a founding regular" if bool(known.get("founding", false)) else "a regular"
	_stats.owner_lines_each.append(guest.transcript.filter(func(e): return e.has("text")).size())
	_customer = guest.customer
	_order = guest.order.duplicate()
	_narrate("%s pays %s and heads back out into the night." % [guest.customer["name"], Menu.format_won(bill)])
	_goodbye_at_door(guest)
	_ambience.play("cash")
	_ambience.play("scrape", 0.9, 0.5)
	_event("paid", {"name": str(guest.customer["name"]), "hangul": str(guest.customer.get("hangul", "")), "job": str(guest.customer.get("job", "")),
		"gender": str(guest.customer.get("gender", "")),
		"regular": standing, "ordered": ", ".join(PackedStringArray(guest.order.map(func(id): return str(Menu.find(id).get("name", id))))),
		"order_ids": guest.order.duplicate(), "bill": bill, "amount": Menu.format_won(bill)}, guest.node)
	_clear_table(guest)
	_walk_out(guest)  # off they go; the owner gets on with the next thing
	_guests.erase(guest)
	_refresh_tags()
	_event("left", {"name": str(guest.customer["name"]), "seated": _guests.size(), "waiting": _waiting.size(),
		"last_orders": _last_orders, "minutes": int(_clock)})
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
	guest.topic = Talk.pick_owner_topic(randf(), guest.food_news or not _food_coming(guest).is_empty(), _cat_here(guest), guest.topic, remembered)
	# The cat's just come to them (or it's up to something): the talk turns to it. (Given only as
	# a situation, the AI let it go by every time: 0 of 4 one night.)
	if guest.cat_moment != "" or _owner_cat_moment != "":
		guest.topic = "the_cat"
	guest.food_news = false
	# When it's busy, a single exchange, so the voice comes round to everyone (and leaves room
	# for customers to chat) sooner.
	await _converse(guest, 1 if _guests.size() >= People.BUSY_COUNTER else randi_range(1, 2), true)
	# Every few lines, was anything a big moment? (A TV reaction.)
	if _guests.has(guest) and guest.line - guest.reacted_at >= Captions.REACT_EVERY:
		guest.reacted_at = guest.line
		var spoken: Array = guest.transcript.filter(func(e): return e.has("text")).slice(-Captions.REACT_EVERY)
		await _react(spoken, [str(_owner["name"]), str(guest.customer["name"])], guest.order)
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
	guest.moment["time"] = NightRules.clock_text(int(_clock))
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
		var known: Dictionary = guest.customer.get("regular", {})
		var opener := Talk.opener_moment(not known.is_empty(), known.is_empty(), _late(), Looks.wet(_weather_kind), randf(), randf())
		if opener != "" and owner_speaks:
			direction += " " + opener
			_stats.opener_situations += 1
	elif guest.stay_left < 10.0:
		direction = "The customer is nearly ready to leave."
	elif guest.topic != "":
		direction = Talk.topic_hint(guest.topic)
	var hint := ""  # what kind of hint this line was given, for the stats
	var stunned := _owner_stunned if owner_speaks else guest.stunned
	if stunned != "":  # (first: they've just heard something they can't believe)
		direction = (stunned + " " + direction).strip_edges()
		hint = "stunned"
		if owner_speaks:
			_owner_stunned = ""
		else:
			guest.stunned = ""
	elif i > 0 and guest.food_moment != "":
		direction = (guest.food_moment + " " + direction).strip_edges()
		hint = Talk.moment_kind(guest.food_moment)
		guest.food_moment = ""  # once
	elif i > 0 and (_owner_cat_moment if owner_speaks else guest.cat_moment) != "":
		direction = ((_owner_cat_moment if owner_speaks else guest.cat_moment) + " " + direction).strip_edges()
		hint = "cat"
		if owner_speaks:
			_owner_cat_moment = ""
		else:
			guest.cat_moment = ""
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
	_stats.record_hint(hint, str(reply["line"]), _cat_tells())
	if i == 0 and owner_speaks:
		_stats.record_opening("owner", str(reply["line"]))
	await _say(guest, owner_speaks, str(reply["line"]))
	guest.line += 1


## A customer's last line to the owner, as they pay up and go. If the AI can't manage one,
## they just pay.
func _goodbye(guest: Guest) -> void:
	var speaker := str(guest.customer["name"])
	var owner_name := str(_owner["name"])
	guest.moment["time"] = NightRules.clock_text(int(_clock))
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
	return Looks.seen_as(guest.customer)


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
		Prompts.extra_order_messages(_owner, guest.customer, guest.moment, Menu.prompt_list(Menu.shuffled_ids(), _specials), guest.transcript, _table_text(guest)),
		_validate_extra_order.bind(guest.order.duplicate()), {"temperature": 0.7},
		{"purpose": "extra_order", "title": _owner["title"], "table": guest.order.duplicate()})
	_typing_label.text = ""
	if extra.is_empty():
		return false
	var items: Array = extra["items"]
	_stats.sides_added += int(extra.get("added_sides", 0))
	await _say(guest, false, str(extra["line"]))
	guest.order.append_array(items)
	_serve(guest, items, false)
	return true


# --- Customers chatting to each other -------------------------------------------

## Someone who can be drawn into a chat right now: not keeping to themselves, settled in
## (served), and not about to leave (nobody starts a chat with ten minutes to go).
func _can_chat(guest: Guest) -> bool:
	return People.joins_chats(guest.company) and guest.stay_left >= CHAT_MIN_STAY_LEFT and not guest.order.is_empty()


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
		_event("chat_continued", {"people": chat.people.map(func(g): return str(g.customer["name"]))})
		if not free.is_empty() and randf() < JOIN_CHANCE:
			var joiner: Guest = free.pick_random()
			chat.people.append(joiner)
			_narrate("%s joins in." % joiner.customer["name"])
			_event("joined_chat", {"gender": str(joiner.customer.get("gender", "")), "name": str(joiner.customer["name"])}, joiner.node)
			chat.transcript.append({"action": "%s, from further along the counter, joins the conversation." % joiner.customer["name"]})
	elif free.size() >= 2:
		free.shuffle()
		chat = Chat.new()
		chat.people = [free[0], free[1]]
		_chats.append(chat)
		_narrate("%s gets talking to %s." % [free[0].customer["name"], free[1].customer["name"]])
		_event("chat_started", {"name": str(free[0].customer["name"]), "friend": str(free[1].customer["name"])}, free[0].node)
		chat.transcript.append({"action": "%s turns to %s, a stranger a few stools along, and starts a conversation." % [free[0].customer["name"], free[1].customer["name"]]})
	if chat == null:
		_task_done()
		return
	if not chat.owner_in and randf() < OWNER_JOINS_CHANCE:
		chat.owner_in = true
		_narrate("%s leans over the counter and joins in." % _owner_display())
		_event("owner_joined", {}, _owner_node)
		chat.transcript.append({"action": "%s, the owner, leans over the counter and joins in." % _owner["name"]})
	if chat.owner_in:
		# Talking with the owner counts as being seen to.
		for guest in chat.people:
			_attention += 1
			guest.attended = _attention
		_attending = chat.people[0]
		_move_owner(_beside(chat.people[0]))
	var cat_with_them := "none" if _cat_here(null) == "none" else ("with_them" if chat.people.has(_cat_with) else "tent")
	chat.topic = Talk.pick_chat_topic(randf(), cat_with_them, chat.topic)
	if chat.people.any(func(g): return g.cat_moment != "") or (chat.owner_in and _owner_cat_moment != ""):
		chat.topic = "the_cat"  # (the cat's just come to one of them: see _talk)
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
	# Was anything in that spell a big moment? (A TV reaction.)
	if lines_said > 0:
		var spoken: Array = chat.transcript.filter(func(e): return e.has("text")).slice(-lines_said)
		var talking: Array = chat.people.map(func(g): return str(g.customer["name"]))
		if spoken.any(func(e): return str(e["speaker"]) == str(_owner["name"])):
			talking.append(str(_owner["name"]))
		var ordered: Array = []
		for guest in chat.people:
			ordered.append_array(guest.order)
		await _react(spoken, talking, ordered)
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
	var moment := {"day": _night_day, "time": NightRules.clock_text(int(_clock)), "weather": _night_weather, "date": _date_words()}
	var direction := "This is the first thing they've ever said to each other." if first else Talk.topic_hint(chat.topic, true)
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
	var hint := ""  # what kind of hint this line was given, for the stats
	# Now and then, once a chat: something to share (a bite, a refill).
	if not first and moment_term == "" and not chat.shared and speaking != null and listening != null \
			and _served_of(speaking, "food") > 0:
		var sharing := Talk.sharing_moment(speaker, addressee, close, _served_of(speaking, "food") > _served_of(listening, "food"),
			_served_of(speaking, "drink") > 0 and _served_of(listening, "drink") > 0, randf(), randf())
		if sharing != "":
			direction = sharing + " " + direction
			hint = Talk.moment_kind(sharing)
			chat.shared = true
	# Something just said has stunned them.
	var heard := _owner_stunned if owner_speaks else (speaking.stunned if speaking != null else "")
	if heard != "" and not first:
		direction = heard + " " + direction
		hint = "stunned"
		if owner_speaks:
			_owner_stunned = ""
		else:
			speaking.stunned = ""
	# The cat's come to the speaker (or it's up to something the owner has to deal with).
	if hint == "" and not first:
		var with_cat := _owner_cat_moment if owner_speaks else (speaking.cat_moment if speaking != null else "")
		if with_cat != "":
			direction = with_cat + " " + direction
			hint = "cat"
			if owner_speaks:
				_owner_cat_moment = ""
			else:
				speaking.cat_moment = ""
	direction += " " + _chat_notes(chat) + " " + Address.address_text(speaker, _addressee(speaking), addressee, _addressee(listening), close)
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
	_stats.record_hint(hint, line, _cat_tells())
	_stats.record_line(line, names)
	if guest != null:
		_night_lines.append({"speaker": speaker, "text": line})
	_show("[color=#%s][b]%s to %s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(to), Glossary.explain(_esc(line), names)])
	_cheer_along(guest, line, names)
	var listener_colour := OWNER_TEXT if addressed == null else addressed.color.lightened(0.35)
	_give_time_to_read(line, _say_in_bubble(_owner_node if guest == null else guest.node, _owner_node if addressed == null else addressed.node,
		_to_label(line, guest, addressed, to), listener_colour, colour, line))
	if moment_term != "" and guest != null and addressed != null:
		_make_close(guest, addressed, moment_term)
	return line


## Everyone's names tonight (the owner and whoever's at the counter): left alone by Glossary.explain.
func _names_here() -> Array:
	var names: Array = [str(_owner.get("name", ""))]
	for guest in _guests:
		names.append(str(guest.customer["name"]))
	return names


## How many things of this kind ("food" or "drink") are on their table.
func _served_of(guest: Guest, kind: String) -> int:
	return guest.served.filter(func(id): return Menu.find(id).get("kind", "") == kind).size()


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
	return "%s %s (%s)" % [Address.TERMS[term]["hangul"], term.capitalize(), label]


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
		spot = CatRules.pick_cat_spot(str(_cat["personality"]), not people.is_empty(), not eating.is_empty(), randf(), _cat_spot)
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
	# Now and then, a moment for whoever it's with now (people talk to cats); any older one's gone.
	for guest in _guests:
		guest.cat_moment = ""
	_owner_cat_moment = ""
	var moment := CatRules.cat_moment(str(_cat["name"]), spot, randf())
	if moment != "" and CatRules.owner_spot(spot):
		_owner_cat_moment = moment
	elif moment != "" and with != null:
		with.cat_moment = moment
	_cat_next = randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y)
	var cat_name := str(_cat["name"])
	var was_out := _cat_node.visible == false
	if before != null and before != with and _guests.has(before):
		before.transcript.append({"action": "%s jumps down and wanders off." % cat_name})
		before.version += 1
	var text := CatRules.cat_move_text(cat_name, spot, _cat_with_name())
	# Moves that matter (with a customer, leaving them, going out or coming in) are always
	# narrated; just pottering about only sometimes.
	if with != null or before != null or spot == "street" or was_out or randf() < CAT_POTTER_NARRATED:
		_narrate(text)
	if with != null:
		with.transcript.append({"action": text})
		with.version += 1
	_place_cat()
	var moved := {"cat": cat_name, "spot": spot, "with": str(with.customer["name"]) if with != null else "",
		"new_lap": spot == "lap" and with != null and with != before, "was_out": was_out}
	_event("cat_moved", moved, with.node if bool(moved["new_lap"]) else _cat_node)
	_update_info()
	# Sat by someone's food, with a fish cake on the table: a greedy cat may help itself.
	if spot == "food" and with != null and CatRules.steals(str(_cat["personality"]), with.served.has(CatRules.STEALABLE), randf()):
		_cat_steals(with)


## The cat grabs a fish cake skewer off someone's table and bolts into the street. It's gone
## from their table (still on the bill), and the owner and they each get a moment for their
## next line.
func _cat_steals(guest: Guest) -> void:
	var cat_name := str(_cat["name"])
	var robbed := str(guest.customer["name"])
	var dish_name := str(Menu.find(CatRules.STEALABLE)["name"])
	guest.served.erase(CatRules.STEALABLE)
	for shape in guest.food_row.get_children():
		if shape.tooltip_text == dish_name:
			guest.food_row.remove_child(shape)
			shape.queue_free()
			break
	guest.version += 1
	var text := "%s snatches an odeng skewer off %s's plate and bolts!" % [cat_name, robbed]
	_narrate(text)
	guest.transcript.append({"action": text})
	_ambience.play("meow")
	_event("cat_stole", {"cat": cat_name, "name": robbed, "dish": dish_name}, guest.node)
	_move_cat("street")  # (off with it)
	_owner_cat_moment = CatRules.THEFT_MOMENT_OWNER.replace("{cat}", cat_name).replace("{name}", robbed)
	if _guests.has(guest):
		guest.cat_moment = CatRules.THEFT_MOMENT_ROBBED.replace("{cat}", cat_name)
	_update_info()


## The cat's name, for counting lines that talk to it (Talk.hint_taken).
func _cat_tells() -> Array:
	return [] if _cat.is_empty() else [str(_cat["name"]).to_lower()]


func _cat_with_name() -> String:
	return str(_cat_with.customer["name"]) if _cat_with != null else ""


## Where the cat is, for the AI's prompts.
func _cat_prompt() -> String:
	if _cat.is_empty():
		return ""
	return Prompts.describe_cat(_cat, CatRules.cat_text(str(_cat["name"]), _cat_spot, _cat_with_name()))


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
		"stools": target = Vector2(randf_range(SEAT_X[0] - 120, SEAT_X[NightRules.SEATS - 1] + 60), 348)
		"street": target = Vector2(STAGE_SIZE.x + 80, 348)
		"lap": target = Vector2(SEAT_X[_cat_with.seat] - 20, 282)
		"feet": target = Vector2(SEAT_X[_cat_with.seat] + 18, 348)
		"food": target = Vector2(SEAT_X[_cat_with.seat] + 48, 318)
	_cat_node.visible = true
	_face_cat(target.x)
	if _cat_tween != null and _cat_tween.is_valid():
		_cat_tween.kill()
	_cat_tween = create_tween()
	_cat_tween.tween_property(_cat_node, "position", target, _scaled(1.0)).set_trans(Tween.TRANS_SINE)
	if _cat_spot == "street":
		_cat_tween.tween_callback(func(): _cat_node.visible = _cat_spot != "street")
	elif _cat_spot in ["stools", "feet"]:
		_cat_tween.tween_callback(_prowl)  # it doesn't just sit there


## Faces the cat the way it's going (it's drawn facing right; flipped, it faces left).
func _face_cat(to_x: float) -> void:
	if absf(to_x - _cat_node.position.x) > 1.0:
		_cat_node.scale.x = 1.0 if to_x > _cat_node.position.x else -1.0
		(_cat_node.get_node("Tag") as Label).scale.x = _cat_node.scale.x  # turned back, so the name still reads


## Prowling under the stools: a pause to sniff about, then padding off somewhere else along
## the floor, again and again until it goes somewhere new. Winding round someone's ankles,
## the same but back and forth around their feet. (Scenery dice: see _scenery_dice.)
func _prowl() -> void:
	if not is_instance_valid(_cat_node) or not (_cat_spot in ["stools", "feet"]):
		return
	var to: Vector2
	if _cat_spot == "feet" and _cat_with != null:
		var feet_x: float = SEAT_X[_cat_with.seat] + 18
		to = Vector2(feet_x + _scenery_dice.randf_range(-34.0, 34.0), 348)
	else:
		to = Vector2(_scenery_dice.randf_range(SEAT_X[0] - 120, SEAT_X[NightRules.SEATS - 1] + 60), 348)
	var pause := _scenery_dice.randf_range(0.6, 2.4) if _cat_spot == "stools" else _scenery_dice.randf_range(0.2, 0.7)
	var pace := 110.0 if _cat_spot == "stools" else 60.0  # pixels a second: ambling, or slow and close
	_cat_tween = create_tween()
	_cat_tween.tween_interval(_scaled(pause))
	_cat_tween.tween_callback(_face_cat.bind(to.x))
	_cat_tween.tween_property(_cat_node, "position", to, _scaled(maxf(0.3, _cat_node.position.distance_to(to) / pace))).set_trans(Tween.TRANS_SINE)
	_cat_tween.tween_callback(_prowl)


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
	var coat := Color(str(CatRules.CAT_COATS.get(_cat["coat"], "9c7a52")))
	for part in ["Tail", "Body", "Head", "EarLeft", "EarRight"]:
		(_cat_node.get_node(part) as ColorRect).color = coat
	var patch := _cat_node.get_node("Patch") as ColorRect
	patch.visible = _cat["coat"] in ["calico", "tabby"]
	patch.color = Color("d9883a") if _cat["coat"] == "calico" else coat.darkened(0.35)


## What's on a guest's table, as the AI is told it, including what's still cooking.
func _table_text(guest: Guest) -> String:
	return Orders.table_text(guest.served, _food_coming(guest), BANCHAN)


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

## Walking in and out runs by itself: nobody waits for it. In the rain or snow they come in
## under an umbrella (or running for it, with no umbrella), the same as anyone in the street,
## and put it down under the tarp.
func _walk_in(guest: Guest) -> void:
	_face(guest.node, true)
	var stool_x: float = SEAT_X[guest.seat] - PERSON_WIDTH / 2
	guest.rain_gear = _pick_rain_gear()
	_gear_up(guest.node, guest.rain_gear, guest.node.position.x < stool_x)
	if not guest.rain_gear.is_empty():
		_stats.record_street("customers in under an umbrella" if bool(guest.rain_gear["umbrella"]) else "customers running in")
	guest.walk = create_tween()
	guest.walk.tween_property(guest.node, "position:x", stool_x, _scaled(1.1 if _is_running(guest.node) else 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	guest.walk.tween_callback(_gear_down.bind(guest.node))  # under the tarp
	guest.walk.tween_callback(_face.bind(guest.node, false))  # sat down: facing the counter


## ...and back out: the umbrella goes up again (or, if it's started raining since, whatever
## the dice say).
func _walk_out(guest: Guest) -> void:
	if guest.walk != null and guest.walk.is_valid():
		guest.walk.kill()  # if they hadn't quite sat down yet
	_gear_down(guest.node)  # (if they hadn't put it down yet)
	_face(guest.node, true)  # up, and turning to go
	# ...and leave in whichever direction they're heading home, at random.
	var away := _random_offscreen_x()
	var gear: Dictionary = {}
	if Looks.wet(_weather_kind):
		gear = guest.rain_gear if not guest.rain_gear.is_empty() else _pick_rain_gear()
	_stop_swaying(guest.node)
	_gear_up(guest.node, gear, guest.node.position.x < away, guest.rain_gear.is_empty())  # (counted only if it's new)
	# A few drinks in, they wobble home (slower, zigzagging), unless they're running for it.
	var wobbly := _drinks_had(guest) >= TIPSY_DRINKS and not _is_running(guest.node)
	if wobbly:
		guest.node.pivot_offset = Vector2(40, 150)
		var wobble := guest.node.create_tween().set_loops()
		wobble.tween_property(guest.node, "rotation", 0.1, _scaled(0.28)).set_trans(Tween.TRANS_SINE)
		wobble.parallel().tween_property(guest.node, "position:y", CUSTOMER_Y + 5, _scaled(0.28))
		wobble.tween_property(guest.node, "rotation", -0.08, _scaled(0.32)).set_trans(Tween.TRANS_SINE)
		wobble.parallel().tween_property(guest.node, "position:y", CUSTOMER_Y - 3, _scaled(0.32))
		guest.node.set_meta("wobbly", true)
		_stats.record_street("wobbled home")
	guest.walk = create_tween()
	guest.walk.tween_property(guest.node, "position:x", away, _scaled(1.0 if _is_running(guest.node) else (2.2 if wobbly else 1.4))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	guest.walk.tween_callback(guest.node.queue_free)


## A second bottle and they start to sway on their stool, a little more with each one after
## (facing away from us, so it's in how they sit, not their cheeks).
const TIPSY_DRINKS := 2

func _tipsy(guest: Guest) -> void:
	var drinks := _drinks_had(guest)
	if drinks < TIPSY_DRINKS or not is_instance_valid(guest.node):
		return
	var lean := minf(0.022 * (drinks - TIPSY_DRINKS + 1), 0.07)
	if not guest.node.has_meta("counted_tipsy"):
		guest.node.set_meta("counted_tipsy", true)
		_stats.tipsy += 1
	guest.node.pivot_offset = Vector2(40, 150)  # swaying from where they sit
	_stop_swaying(guest.node)
	var sway := guest.node.create_tween().set_loops()
	sway.tween_property(guest.node, "rotation", lean, _scaled(1.6)).set_trans(Tween.TRANS_SINE)
	sway.tween_property(guest.node, "rotation", -lean * 0.6, _scaled(1.8)).set_trans(Tween.TRANS_SINE)
	guest.node.set_meta("sway", sway)


func _drinks_had(guest: Guest) -> int:
	return guest.order.filter(func(id): return Menu.find(id).get("kind", "") == "drink").size()


func _stop_swaying(person: Control) -> void:
	if not person.has_meta("sway"):  # (get_meta with a null default still errors when it's missing)
		return
	var sway: Tween = person.get_meta("sway")
	if sway != null and sway.is_valid():
		sway.kill()
	person.remove_meta("sway")
	person.rotation = 0.0


## Rain gear for someone out in tonight's weather (Looks.rain_gear; {} when it's dry).
func _pick_rain_gear() -> Dictionary:
	if not Looks.wet(_weather_kind):
		return {}
	if not Hooks.rain_gear.is_empty():
		return Hooks.rain_gear.duplicate()
	return Looks.rain_gear(_weather_kind, randf(), randf(), randf())


## Out into the weather with this gear: the umbrella up, or running for it ({}: nothing).
## counted: in the street stats (not when a customer puts theirs back up to go).
func _gear_up(person: Control, gear: Dictionary, going_right: bool, counted: bool = true) -> void:
	if gear.is_empty():
		return
	if bool(gear["umbrella"]):
		_umbrella(person, gear)
	else:
		_running_for_it(person, going_right)
	if counted:
		_stats.record_street(("umbrella: %s" % str(gear.get("shape", "dome"))) if bool(gear["umbrella"]) else "ran for it")


## In out of the weather: the umbrella folds down and goes, and anyone running stops.
func _gear_down(person: Control) -> void:
	if not is_instance_valid(person):
		return
	var umbrella := person.get_node_or_null("Umbrella") as Node2D
	if umbrella != null:
		umbrella.name = "UmbrellaDown"  # (so it's gone straight away, as far as anyone looking is concerned)
		_shake_off(person, umbrella)
		var fold := umbrella.create_tween()
		var tilt := umbrella.rotation
		fold.tween_property(umbrella, "rotation", tilt + 0.3, _scaled(0.06))  # a shake...
		fold.tween_property(umbrella, "rotation", tilt - 0.3, _scaled(0.08))
		fold.tween_property(umbrella, "rotation", tilt, _scaled(0.06))
		fold.tween_property(umbrella, "scale:x", umbrella.scale.x * 0.15, _scaled(0.2)).set_trans(Tween.TRANS_SINE)  # ...and folded
		fold.parallel().tween_property(umbrella, "modulate:a", 0.0, _scaled(0.25))
		fold.tween_callback(umbrella.queue_free)
	var cover := person.get_node_or_null("OverHead")
	if cover != null:
		person.remove_child(cover)  # (gone now, not at the end of the frame)
		cover.queue_free()
	if _is_running(person):
		var bob: Tween = person.get_meta("bob")
		if bob != null and bob.is_valid():
			bob.kill()
		person.rotation = 0.0
		person.position.y = float(person.get_meta("ground"))
		person.remove_meta("running")


func _is_running(person: Control) -> bool:
	return is_instance_valid(person) and bool(person.get_meta("running", false))


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
	var shape := _dish_shape(id)
	row.add_child(shape)
	if HOT_DISHES.has(id):
		_steam(shape)


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


## A menu item on the table, drawn from its "art" (what it comes in and what's in it: see
## rules/dish_art.gd), with its name on hover. (Without art: a bottle for a drink, a bowl for
## food, in its colour.)
func _dish_shape(id: String) -> Control:
	var item := Menu.find(id)
	var colour := Color(str(item["color"]))
	var art: Dictionary = item.get("art", {"vessel": "bottle"} if item["kind"] == "drink" else {"vessel": "bowl", "fill": str(item["color"])})
	var shape := DishView.new()
	shape.tooltip_text = str(item["name"])
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	shape.custom_minimum_size = DishArt.size(art)
	shape.shapes = DishArt.shapes(art, colour, id)
	return shape


## The free banchan: three little dishes.
func _banchan_shape() -> Control:
	var shape := Control.new()
	shape.tooltip_text = Text.tip("Banchan: %s (free)" % BANCHAN)
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
	_stats.record_line(text, [_owner["name"], guest.customer["name"]])
	if not owner_speaks:
		_night_lines.append({"speaker": str(guest.customer["name"]), "text": text})
	_show("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), Glossary.explain(_esc(text), [_owner["name"], guest.customer["name"]])])
	_cheer_along(null if owner_speaks else guest, text, [_owner["name"], guest.customer["name"]])
	# (Their node may have gone while the line was on its way, e.g. they've walked off: a freed
	# node can't be passed as a Control, so it's null then, and the bubble skips or points nowhere.)
	var them: Control = guest.node if is_instance_valid(guest.node) else null
	if owner_speaks:
		_give_time_to_read(text, _say_in_bubble(_owner_node, them, _to_label(text, null, guest, _name_label(guest.customer)), guest.color.lightened(0.35), colour, text))
	else:
		_give_time_to_read(text, _say_in_bubble(them, _owner_node, _to_label(text, guest, null, _owner_label()), OWNER_TEXT, colour, text))


func _narrate(text: String) -> void:
	_show("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), Glossary.explain(_esc(text), _names_here())])


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


## Announces something that happened tonight (see night_events.gd), with its facts; about and
## spot say where on screen, for its caption.
func _event(kind: String, facts: Dictionary = {}, about: Variant = null, spot: Vector2 = Vector2(-1, -1)) -> void:
	if _events != null:
		_events.emit_event(kind, _clock, facts, about, spot)


## The captions' listener: the caption an event gets (Captions.for_event), if any.
func _caption_for_event(kind: String, facts: Dictionary, about: Variant, spot: Vector2) -> void:
	var asked := facts
	if kind == "sat_down":
		asked = facts.duplicate()
		asked["rush_open"] = not _rush_shown
	var caption := Captions.for_event(kind, asked)
	if caption.is_empty():
		return
	if str(caption["kind"]) == "rush":
		_rush_shown = true  # (once a night)
	_caption(str(caption["kind"]), about, caption["fill"], spot)


## A TV caption (Captions.CAPTIONS) for something noteworthy: popped up over whoever it's about
## (or the middle of the tent), with its sound sting, and for an emergency the red border
## flashing. Paced so they stay a treat (Captions.caption_allowed); each one shown goes in the
## transcript and the stats. fill: the words' blanks (gender, term, cat).
## spot: where to put it instead (stage coordinates), e.g. the stool someone's walking to.
## about is untyped: whoever it's about may have walked off (and their node been freed) by
## the time it's called, and then it goes in the middle.
func _caption(kind: String, about: Variant = null, fill: Dictionary = {}, spot: Vector2 = Vector2(-1, -1)) -> void:
	if not Hooks.captions or _captions_toggle == null or not _captions_toggle.button_pressed or not Captions.CAPTIONS.has(kind):
		return
	var always := bool(Captions.CAPTIONS[kind].get("always", false))  # (closing early: never held back)
	if Hooks.caption_pacing and not always and randf() >= float(Captions.CAPTIONS[kind].get("chance", 1.0)):
		return  # a kind that comes up all night: only now and then
	var now := Time.get_ticks_msec() / 1000.0
	var reaction_up := now < _reaction_until and not bool(Captions.CAPTIONS[kind]["emergency"])  # a reaction's up: routine ones wait
	if Hooks.caption_pacing and not always and (reaction_up or not Captions.caption_allowed(kind, now, _caption_last, float(_caption_last_kind.get(kind, -1.0)), _scaled(Captions.CAPTION_GAP), _scaled(Captions.CAPTION_SAME_GAP))):
		_stats.captions_held_back += 1
		return
	_caption_last = now
	_caption_last_kind[kind] = now
	_stats.captions[kind] = int(_stats.captions.get(kind, 0)) + 1
	var data: Dictionary = Captions.CAPTIONS[kind]
	var roll := randf()  # which of its words, for a kind with several
	fill = fill.duplicate()
	if not fill.has("owner") and not _owner.is_empty():
		fill["owner"] = _owner["name"]
	if not fill.has("seated"):
		fill["seated"] = _guests.size()
	if not fill.has("cat") and not _cat.is_empty():
		fill["cat"] = _cat["name"]
	if _weather_kind in ["drizzle", "rain"]:
		fill["weather"] = "rain"
	_pop_caption(Captions.caption_words(kind, fill, roll), str(data["icon"]), str(data["colour"]), str(data["sound"]), bool(data["emergency"]), about, spot, Captions.CAPTION_SECONDS)


## Puts a caption up (see _caption and _react): in the transcript, popped up on the stage
## (replacing the last), with its sting, and the red light for an emergency.
func _pop_caption(words: Dictionary, icon: String, colour: String, sound: String, emergency: bool, about: Variant, spot: Vector2, hold: float) -> void:
	_show("[center][b][color=#%s]%s[/color][/b][/center]\n\n" % [colour, _esc("[TV] %s %s" % [words["hangul"], words["english"]])])
	if is_instance_valid(_caption_shown):
		_caption_shown.name = "OldCaption"  # (so it's never mistaken for the new one while it goes)
		_caption_shown.queue_free()
	var caption := CaptionPopup.new()
	caption.name = "Caption"
	caption.time_scale = _scaled(1.0)
	caption.stage_width = STAGE_SIZE.x
	if spot.x >= 0.0:
		caption.at = spot
	elif is_instance_valid(about):
		caption.at = (about as Control).position + Vector2(40, -60)
	else:
		caption.at = Vector2(STAGE_SIZE.x / 2, 150)
	caption.setup(words, icon, Color(colour))
	_caption_layer.add_child(caption)
	caption.pop(hold)
	_caption_shown = caption
	_ambience.sting(sound)
	if emergency:
		_flash_red()


## A TV reaction: asks the AI whether anything in the latest lines was a big moment (usually
## not), and if so pops up its caption over whoever it's about, with the Hangul, look and
## sound from its mood (Captions.REACTIONS). If someone's waiting for the owner, it's put off
## until she's free, not skipped (the AI's one voice is hers: a busy night used to lose almost
## every check). An answer that fails the checks is dropped, not retried. names: who's talking;
## items: what they've ordered (a caption can't mention anything else).
func _react(lines: Array, names: Array, items: Array) -> void:
	if not Hooks.reactions or not Hooks.captions or _captions_toggle == null or not _captions_toggle.button_pressed or lines.is_empty():
		return
	if _urgent():
		if not _reaction_pending.is_empty():
			_stats.reactions_skipped += 1  # (a newer one replaces it: only the latest waits)
		_reaction_pending = {"lines": lines.duplicate(true), "names": names.duplicate(), "items": items.duplicate(), "at": _clock}
		_stats.reactions_put_off += 1
		return
	var now := Time.get_ticks_msec() / 1000.0
	if Hooks.caption_pacing and _reaction_last >= 0.0 and now - _reaction_last < _scaled(Captions.REACTION_GAP):
		return
	_stats.reactions_asked += 1
	var reply: Dictionary = await _ai.ask_json(Prompts.reaction_messages(lines.slice(-Captions.REACTION_LINES), names),
		_validate_reaction.bind(names, items), {"temperature": 0.7}, {"purpose": "reaction", "names": names, "tries": 1})
	if _stopped:
		return
	if reply.is_empty():
		_stats.reactions_dropped += 1
		return
	var mood := str(reply["mood"])
	if mood == "none":
		_stats.reactions_none += 1
		return
	now = Time.get_ticks_msec() / 1000.0
	_reaction_last = now
	_reaction_until = now + _scaled(Captions.REACTION_SECONDS)
	_caption_last = now  # (routine captions wait their usual gap after it)
	var who := str(reply["who"])
	var theirs: Array = lines.filter(func(e): return str(e.get("speaker", "")) == who)
	_event("big_moment", {"who": who, "mood": mood, "caption": str(reply["caption"]),
		"said": str(theirs[-1]["text"]) if not theirs.is_empty() else ""})  # (its caption's popped here, below: the AI's words)
	var about: Variant = _owner_node  # (untyped: someone's node may be gone by now)
	if who != str(_owner["name"]):
		var guest: Guest = _guest_named(who)
		about = guest.node if guest != null else null
	if mood == "shock":
		_stun_listeners(who, names)
	var data: Dictionary = Captions.REACTIONS[mood]
	_pop_caption(Captions.reaction_words(mood, str(reply["caption"]), randf()), str(data["icon"]), str(data["colour"]), str(data["sound"]), false, about, Vector2(-1, -1), Captions.REACTION_SECONDS)


## The door: as someone ducks in, the owner calls out to them, polite for a stranger and casual
## for an old friend (Talk.door_welcome): a quick bubble and a line in the transcript, and
## their conversation knows they've been welcomed.
func _welcome_at_door(guest: Guest) -> void:
	var welcome := Talk.door_welcome(Regulars.closeness_mark(guest.customer.get("regular", {})))
	_narrate("\"%s\" %s calls out%s." % [welcome, _owner_display(), " from the stove" if _owner_working else ""])
	_say_in_bubble(_owner_node, guest.node, "", guest.color.lightened(0.35), OWNER_TEXT, welcome)
	guest.transcript.append({"action": "%s called out \"%s\" as they came in." % [_owner["name"], welcome]})


## And on the way out: their thanks now and then (잘 먹었습니다!), and the owner's goodbye.
func _goodbye_at_door(guest: Guest) -> void:
	var goodbye := Talk.door_goodbye(Regulars.closeness_mark(guest.customer.get("regular", {})))
	if _scenery_dice.randf() < Talk.DOOR_THANKS_CHANCE:  # (scenery's dice: the game's rolls don't shift)
		_say_in_bubble(guest.node, _owner_node, "", OWNER_TEXT, guest.color.lightened(0.35), Talk.DOOR_THANKS)
		_narrate("\"%s\" says %s. \"%s\" says %s." % [Talk.DOOR_THANKS, Names.given_name(str(guest.customer["name"])), goodbye, _owner_display()])
	else:
		_narrate("\"%s\" says %s." % [goodbye, _owner_display()])
	_say_in_bubble(_owner_node, guest.node, "", guest.color.lightened(0.35), OWNER_TEXT, goodbye)


## Someone said hwaiting (go for it!): the counter joins in, a few of them at once, with a TV
## caption. The game's own (no AI), and only when it's actually said, so it stays a treat.
## speaker: who said it (null for the owner).
func _cheer_along(speaker: Variant, line: String, names: Array) -> void:
	if not Talk.says_hwaiting(line, names):
		return
	var joining: Array = _guests.filter(func(g): return g != speaker).slice(0, Talk.CHORUS_MOST)
	if speaker != null and joining.size() < Talk.CHORUS_MOST:
		joining.append(null)  # (the owner joins in too)
	if joining.is_empty():
		return
	for each in joining:
		var node: Variant = _owner_node if each == null else each.node
		_say_in_bubble(node, null, "", OWNER_TEXT, OWNER_TEXT if each == null else each.color.lightened(0.35), Talk.CHORUS)
	_narrate("Everyone at the counter joins in: \"%s\"" % Talk.CHORUS)
	for guest in _guests:
		guest.transcript.append({"action": "Everyone at the counter joined in: \"Hwaiting!\""})
	_event("cheered_on", {"seated": _guests.size()})


## A shock (a TV reaction said so): everyone else who heard it is stunned, for their next line.
func _stun_listeners(who: String, names: Array) -> void:
	var stunned := Talk.stunned_moment(who)
	for person in names:
		if str(person) == who:
			continue
		if not _owner.is_empty() and str(person) == str(_owner["name"]):
			_owner_stunned = stunned
		else:
			var guest: Guest = _guest_named(str(person))
			if guest != null:
				guest.stunned = stunned


## The owner's free: the reaction check that was put off, if it's still fresh.
func _ask_pending_reaction() -> void:
	_owner_working = true
	var pending := _reaction_pending
	_reaction_pending = {}
	if _clock - float(pending["at"]) <= Captions.REACTION_STALE_MINUTES:
		await _react(pending["lines"], pending["names"], pending["items"])
	else:
		_stats.reactions_skipped += 1  # too late: the moment's gone
	_task_done()


func _validate_reaction(data: Variant, names: Array, items: Array) -> String:
	return Captions.validate_reaction(data, names, items)


## The emergency light: the red border flashing three times round the tent.
func _flash_red() -> void:
	_red_flashes += 1
	_red_frame.visible = true
	_red_frame.modulate.a = 0.0
	var tween := _red_frame.create_tween()
	for _flash in 3:
		tween.tween_property(_red_frame, "modulate:a", 1.0, _scaled(0.18))
		tween.tween_property(_red_frame, "modulate:a", 0.0, _scaled(0.3))
	tween.tween_callback(func(): _red_frame.visible = false)


## Shows a line in a speech bubble over the speaker, a page at a time, with who it's to and
## a line to them. Returns how long it'll take (already scaled), or 0 with bubbles off.
## speaker and listener are untyped: either may have walked off (and been freed) while the line
## was on its way, and a freed node can't be passed as a Control. Checked here instead.
func _say_in_bubble(speaker: Variant, listener: Variant, to_label: String, to_colour: Color, colour: Color, text: String) -> float:
	if not Hooks.bubbles or not _bubbles_toggle.button_pressed or speaker == null or not is_instance_valid(speaker):
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
	var pages := Talk.bubble_pages(text)
	var longest := 0
	for page in pages:
		longest = maxi(longest, page.length())
	bubble.setup("→ %s" % to_label, to_colour, longest > Talk.BUBBLE_SHORT)
	_bubbles_shown.append(bubble)
	var total := 0.0
	for page in pages:
		total += _scaled(Talk.page_seconds(page))
	_page_through(bubble, pages)
	return total


const MAX_BUBBLES := 3  # the newest bright, the two before it dimmed


func _page_through(bubble: Bubble, pages: PackedStringArray) -> void:
	for page in pages:
		if not is_instance_valid(bubble):
			return
		bubble.show_page(page)
		await get_tree().create_timer(_scaled(Talk.page_seconds(page))).timeout
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
	if Hooks.pause_scale_override >= 0.0:
		return seconds * Hooks.pause_scale_override
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
	Glossary.remember(hangul, "%s: %s's name, in Hangul" % [hangul, person["name"]])
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


## Hovering over a customer: who they are and how their night's going, from what the game
## knows (the same as the info panel's), kept up to date. An invisible area over their body
## (people are drawn ignoring the mouse), short of the drinks and food beside them, which have
## tooltips of their own.
func _update_hover(guest: Guest) -> void:
	if not is_instance_valid(guest.node):
		return
	var area := guest.node.get_node_or_null("Hover") as Control
	if area == null:
		area = Control.new()
		area.name = "Hover"
		area.position = Vector2(4, 0)
		area.size = Vector2(72, 150)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		guest.node.add_child(area)
	area.tooltip_text = _hover_text(guest)


func _hover_text(guest: Guest) -> String:
	var c: Dictionary = guest.customer
	var lines := PackedStringArray()
	lines.append("%s, %s" % [_name_label(c), c.get("age", "")])
	var who := str(c.get("job", ""))
	var known: Dictionary = c.get("regular", {})
	if not known.is_empty():
		who += " · %s %s (%s visit)" % [Regulars.closeness_mark(known), Regulars.closeness_word(known), Regulars.ordinal(int(known.get("visits", 0)) + 1)]
	else:
		who += " · first time here"
	lines.append(who)
	if str(c.get("mood", "")) != "":
		lines.append("Mood: %s" % c["mood"])
	lines.append("Company: %s" % COMPANY_LABEL.get(guest.company, guest.company))
	if not guest.served.is_empty():
		lines.append("On the table: %s" % Orders.item_names(guest.served))
	var coming := _food_coming(guest)
	if not coming.is_empty():
		lines.append("Cooking: %s" % Orders.item_names(coming))
	if _drinks_had(guest) >= TIPSY_DRINKS:
		lines.append("A bit tipsy (%d drinks)" % _drinks_had(guest))
	if _cat_with == guest:
		lines.append("%s is %s" % [_cat["name"], {"lap": "on their lap", "feet": "round their ankles", "food": "eyeing their food"}.get(_cat_spot, "with them")])
	var remembered := _remembered_briefly(known)
	if remembered != "":
		lines.append("The owner remembers: %s" % remembered)
	# (Tooltips don't wrap: a long mood or memory would stretch it across the screen.)
	return "\n".join(PackedStringArray(Array(lines).map(func(each): return Text.wrap(str(each), HOVER_WIDTH))))


const HOVER_WIDTH := 44  # characters per line in a customer's hover
const HOVER_REMEMBERED := 60  # ...and at most this much of what the owner remembers


## One short thing the owner remembers about them, for the hover: a fact that sticks (short by
## nature: "From: Busan"), or the owner's impression, cut short at a word. (The memories are
## whole sentences: all of them are in the info panel, over their name.)
func _remembered_briefly(known: Dictionary) -> String:
	var facts: Dictionary = known.get("facts", {})
	var brief := ""
	for key in Memories.STICKING:
		if str(facts.get(key, "")) != "":
			brief = "%s: %s" % [{"job": "Job", "family": "Family", "home": "From", "other": "Also"}[key], facts[key]]
			break
	if brief == "":
		brief = str(known.get("impression", ""))
	return Text.shorten(brief, HOVER_REMEMBERED)


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
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(CatRules.cat_text(str(_cat["name"]), _cat_spot, _cat_with_name()))]
	var seated := _guests.duplicate()
	seated.sort_custom(func(a, b): return a.seat < b.seat)
	if not seated.is_empty():
		t += "\n[color=#%s][b]AT THE COUNTER[/b][/color]\n" % accent
	for guest in seated:
		_update_hover(guest)
		var c: Dictionary = guest.customer
		var hover := _remembered_text(c.get("regular", {}))
		var named := "[b]%s[/b]" % _esc(_name_label(c))
		if hover != "":
			named = Text.hint(hover, named)  # hover: what the owner remembers
		t += "[color=#%s]%s[/color], %s, %s  [color=#%s](stool %d)[/color]\n" % [guest.color.lightened(0.35).to_html(false), named, c["age"], _esc(c["job"]), muted, guest.seat + 1]
		var known: Dictionary = c.get("regular", {})
		if not known.is_empty():
			var status := "%s %s · %s visit" % [Regulars.closeness_mark(known), Regulars.closeness_word(known), Regulars.ordinal(int(known["visits"]) + 1)]
			if str(known.get("since", "")) != "":
				status = "%s %s · coming %s, %s" % [Regulars.closeness_mark(known), Regulars.closeness_word(known), known["since"], known.get("habit", "")]
			elif known.has("nights_ago"):
				status += " · last in %s" % Regulars.nights_ago_text(int(known["nights_ago"]))
			if not known.get("usual", []).is_empty():
				status += " · usual: %s" % Orders.item_names(known["usual"])
			t += "[color=#%s]%s[/color]\n" % [OWNER_TEXT.to_html(false), Glossary.explain(_esc(status))]
		t += "[color=#%s]%s · %s · %s[/color]\n" % [muted, COMPANY_LABEL.get(guest.company, ""), _esc(c["mood"]), _esc(c["reason"])]
		var chat := _chat_of(guest)
		if chat != null:
			var others: Array = chat.people.filter(func(g): return g != guest).map(func(g): return str(g.customer["name"]))
			t += "[color=#%s]Talking with %s[/color]\n" % [muted, _esc(", ".join(PackedStringArray(others)))]
		if not guest.order.is_empty():
			t += "Table: %s" % Glossary.explain(_esc(Orders.item_names(guest.served) if not guest.served.is_empty() else "banchan"))
			var coming := _food_coming(guest)
			if not coming.is_empty():
				t += "  ·  [color=#%s]cooking: %s[/color]" % [accent, Glossary.explain(_esc(Orders.item_names(coming)))]
			t += "  ·  %s\n" % Menu.format_won(Orders.bill(guest.order))
	var queueing := _waiting.size() - _free_seats().size()
	if queueing > 0:
		t += "\n[color=#%s]Waiting for a stool: %d[/color]\n" % [muted, queueing]
	_info.text = Glossary.explain_hangul(t)


# --- Checking the AI's replies (the rules live in scripts/rules/) ------------

func _validate_owner(data: Variant, gender: String, age_range: String = "") -> String:
	return People.validate_owner(data, gender, age_range)


func _validate_bar_name(data: Variant) -> String:
	return BarLook.validate_bar_name(data)


func _validate_customer_name(data: Variant, taken: Array, gender: String) -> String:
	return Names.validate_customer_name(data, taken, gender)


func _validate_customer_details(data: Variant, age_range: String = "") -> String:
	return People.validate_customer_details(data, age_range)


func _validate_order(data: Variant, max_mains: int, max_drinks: int) -> String:
	return Orders.validate_order(data, max_mains, max_drinks)


func _validate_extra_order(data: Variant, table: Array) -> String:
	return Orders.validate_extra_order(data, table)


func _validate_line(data: Variant, speaker: String, alias: String, items: Array, names: Array, cat: Dictionary, address: Dictionary = {}) -> String:
	return Talk.validate_line(data, speaker, alias, items, names, cat, address)


func _validate_cat_name(data: Variant, taken: Array) -> String:
	return CatRules.validate_cat_name(data, str(_owner["name"]), taken)


# --- Building the screen ------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Ktv.BACKGROUND
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

	# The settings live in an Options panel that drops down from the top bar, so they don't
	# crowd it (see _build_options_panel; more settings will go there).
	var opts := _build_options_panel()

	_reading_toggle = CheckBox.new()
	_reading_toggle.name = "ReadingToggle"
	_reading_toggle.text = "Reading pauses"
	_reading_toggle.button_pressed = false  # Off while we try the bar without them.
	_reading_toggle.tooltip_text = Text.tip("Wait after each line so there's time to read it. Off: lines come as fast as the AI writes them.")
	opts.add_child(_reading_toggle)

	_stats_toggle = CheckBox.new()
	_stats_toggle.name = "StatsToggle"
	_stats_toggle.text = "Stats"
	_stats_toggle.button_pressed = true  # Shown by default while we're testing.
	_stats_toggle.tooltip_text = Text.tip("Debug stats for tonight (F3). A log of them is saved at the end of each night.")
	_stats_toggle.toggled.connect(_on_stats_toggled)
	opts.add_child(_stats_toggle)

	_bubbles_toggle = CheckBox.new()
	_bubbles_toggle.name = "BubblesToggle"
	_bubbles_toggle.text = "Bubbles"
	_bubbles_toggle.button_pressed = true
	_bubbles_toggle.tooltip_text = Text.tip("Speech bubbles over whoever's talking, with a line to who they're talking to.")
	opts.add_child(_bubbles_toggle)

	_captions_toggle = CheckBox.new()
	_captions_toggle.name = "CaptionsToggle"
	_captions_toggle.text = "Captions"
	_captions_toggle.button_pressed = true
	_captions_toggle.tooltip_text = Text.tip("Korean TV-style captions when something noteworthy happens.")
	opts.add_child(_captions_toggle)

	_sound_toggle = CheckBox.new()
	_sound_toggle.name = "SoundToggle"
	_sound_toggle.text = "Sound"
	_sound_toggle.button_pressed = _ambience.enabled  # on unless it was turned off last time
	_sound_toggle.tooltip_text = Text.tip("The tent's background sound: the street, the weather, the stove and the counter.")
	_sound_toggle.toggled.connect(_ambience.set_enabled)
	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 12)
	opts.add_child(sound_row)
	_sound_toggle.custom_minimum_size = Vector2(150, 0)
	sound_row.add_child(_sound_toggle)
	var volume := HSlider.new()
	volume.name = "SoundVolume"
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = _ambience.volume
	volume.custom_minimum_size = Vector2(120, 0)
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.tooltip_text = Text.tip("How loud the background sound is.")
	volume.value_changed.connect(_ambience.set_volume)
	volume.custom_minimum_size = Vector2(180, 0)
	sound_row.add_child(volume)
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	opts.add_child(music_row)
	_music_toggle = CheckBox.new()
	_music_toggle.name = "MusicToggle"
	_music_toggle.text = "Music"
	_music_toggle.button_pressed = _music.enabled  # on unless it was turned off last time
	_music_toggle.tooltip_text = Text.tip("Arirang, now and then through the night.")
	_music_toggle.toggled.connect(_music.set_enabled)
	_music_toggle.custom_minimum_size = Vector2(150, 0)
	music_row.add_child(_music_toggle)
	var music := HSlider.new()
	music.name = "MusicVolume"
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = _music.volume
	music.custom_minimum_size = Vector2(120, 0)
	music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music.tooltip_text = Text.tip("Arirang, now and then through the night (all the way down for none).")
	music.value_changed.connect(_music.set_volume)
	music.custom_minimum_size = Vector2(180, 0)
	music_row.add_child(music)

	# Godot's default tick boxes are dark: on this background an empty one disappears.
	for toggle in [_reading_toggle, _stats_toggle, _sound_toggle, _music_toggle, _bubbles_toggle, _captions_toggle]:
		Ktv.light_ticks(toggle)

	_try_again = Button.new()
	_try_again.name = "TryAgainButton"
	_try_again.text = "Try again"
	_try_again.tooltip_text = Text.tip("Ask the AI for the owner again.")
	_try_again.custom_minimum_size = Vector2(150, 40)
	_try_again.visible = false
	_try_again.pressed.connect(_on_try_again_pressed)
	bar.add_child(_try_again)

	_leave_button = Button.new()
	_leave_button.name = "LeaveButton"
	_leave_button.text = "Close the bar"
	_leave_button.tooltip_text = Text.tip("Closes up early: nobody new comes in, whoever's here finishes at their own pace, and the owner writes up the night. Then you can open the next night, or go back to the title screen. (Closing the window just saves and quits.)")
	_leave_button.custom_minimum_size = Vector2(150, 40)
	_leave_button.pressed.connect(_on_leave_pressed)
	bar.add_child(_leave_button)

	var diary := Button.new()
	diary.name = "DiaryButton"
	diary.text = "📖 Diary"
	diary.tooltip_text = Text.tip("The owner's diary: every night so far, a page at a time.")
	diary.custom_minimum_size = Vector2(130, 40)
	diary.pressed.connect(_open_diary)
	bar.add_child(diary)

	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "⚙ Options"
	_options_button.tooltip_text = Text.tip("Sound, music, speech bubbles, TV captions, reading pauses and the stats panel (Esc).")
	_options_button.toggle_mode = true
	_options_button.custom_minimum_size = Vector2(140, 40)
	_options_button.toggled.connect(func(on): _options_panel.visible = on)
	bar.add_child(_options_button)

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
	_summary = _panel(Vector2((SCREEN.x - 880) / 2, 110), Vector2(880, 0))
	_summary.name = "NightSummary"
	_summary.z_index = 25  # over everything on the stage (the cat, name tags, bubbles, captions), under Options
	_summary.visible = false
	add_child(_summary)
	var summary_col := VBoxContainer.new()
	summary_col.add_theme_constant_override("separation", 20)
	_summary.add_child(summary_col)
	# The owner's diary is the end of the night; the numbers are behind the Stats button.
	_diary_page = DiaryPage.new()
	_diary_page.name = "DiaryPage"
	_diary_page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	summary_col.add_child(_diary_page)
	_summary_text = RichTextLabel.new()
	_summary_text.name = "SummaryText"
	_summary_text.bbcode_enabled = true
	_summary_text.fit_content = true
	_summary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_text.add_theme_font_size_override("normal_font_size", 22)
	_summary_text.add_theme_font_size_override("bold_font_size", 22)
	_summary_text.add_theme_font_size_override("italics_font_size", 22)
	summary_col.add_child(_summary_text)
	# The same size as the diary page, scrolling (there are lots of numbers), so the buttons
	# underneath stay where they are.
	_summary_text.custom_minimum_size = Vector2(780, 600)
	_summary_text.fit_content = false
	_summary_text.scroll_active = true
	var summary_buttons := HBoxContainer.new()
	summary_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_buttons.add_theme_constant_override("separation", 20)
	summary_col.add_child(summary_buttons)
	var next_night := Button.new()
	next_night.name = "NextNightButton"
	next_night.text = "Open for another night"
	next_night.custom_minimum_size = Vector2(260, 48)
	next_night.pressed.connect(_on_next_night_pressed)
	_stats_button = Button.new()
	_stats_button.name = "SummaryStatsButton"
	_stats_button.text = "Stats"
	_stats_button.toggle_mode = true
	_stats_button.custom_minimum_size = Vector2(140, 48)
	_stats_button.tooltip_text = Text.tip("Tonight's numbers, instead of the diary.")
	_stats_button.toggled.connect(_on_summary_stats_toggled)
	summary_buttons.add_child(_stats_button)
	summary_buttons.add_child(next_night)
	_summary_buttons = [next_night]
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


## The Options panel: dropping down under the top bar's Options button, over the tent.
## Returns the column the settings go in.
func _build_options_panel() -> VBoxContainer:
	_options_panel = _panel(Vector2(SCREEN.x - 24 - 400, 58), Vector2(400, 0))
	_options_panel.name = "OptionsPanel"
	_options_panel.z_index = 20  # over the tent, the bubbles and the captions
	_options_panel.visible = false
	var style := _options_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	_options_panel.add_theme_stylebox_override("panel", style)
	add_child(_options_panel)
	# Clicks go to whatever's last in the tree, whatever's drawn on top: the panel's built
	# before the tent and the other panels, so it's moved to the end once they're all in.
	(func(): move_child(_options_panel, get_child_count() - 1)).call_deferred()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_options_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Options"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", ACCENT)
	column.add_child(heading)
	return column


func _panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var box := StyleBoxFlat.new()
	box.bg_color = Ktv.PANEL
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
	_skyline = SkylineView.new()
	_skyline.name = "Skyline"
	_skyline.size = STAGE_SIZE
	stage.add_child(_skyline)
	_weather_back = _layer(stage, "WeatherBack")
	_rect(stage, Vector2(0, 0), Vector2(w, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(40, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(w - 84, 36), Vector2(44, 344), Color("1f1e36"))
	_build_neon(stage)
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
	for seat in NightRules.SEATS:
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
	_caption_layer = _layer(stage, "Captions")
	_caption_layer.z_index = 5  # in front of everything, bubbles included
	_red_frame = Panel.new()
	_red_frame.name = "RedFrame"
	_red_frame.size = STAGE_SIZE
	_red_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Color(1.0, 0.1, 0.1, 0.12)
	red.border_color = Color("ff2a2a")
	red.set_border_width_all(10)
	_red_frame.add_theme_stylebox_override("panel", red)
	_red_frame.visible = false
	_caption_layer.add_child(_red_frame)


## The drinks fridge at the back, by the stove (the owner's station), behind the owner: a
## glass door lit from inside, with shelves of soju, beer and makgeolli (only what's on the
## menu). Its shelves sit high, so the odeng pot in front doesn't hide them.
func _build_fridge(stage: Control) -> void:
	var fridge := Control.new()
	fridge.name = "Fridge"
	fridge.position = Vector2(186, 116)  # just right of the odeng pot
	fridge.size = Vector2(92, 134)
	fridge.mouse_filter = Control.MOUSE_FILTER_STOP
	fridge.tooltip_text = Text.tip("The drinks fridge: soju, beer and makgeolli, ice cold.")
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
	pot.tooltip_text = Text.tip("Odeng: %s" % Menu.find("odeng")["desc"])
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


## A neon sign on the pillar across from the tent: 노래방, karaoke (a kind of place, not a
## name: see CONCEPT.md, "Real people, brands and shows"), flickering now and then.
func _build_neon(stage: Control) -> void:
	_neon = Ktv.label("노\n래\n방", 22, Color("ff5fa2"), 6, Color("ff5fa2", 0.35))
	_neon.name = "Neon"
	_neon.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_neon.tooltip_text = Text.tip("노래방 noraebang: a karaoke room across the street, where the night carries on after the pocha.")
	_neon.position = Vector2(STAGE_SIZE.x - 36, 122)
	_neon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(_neon)
	_scenery_dice.randomize()
	_flicker_neon()


## Now and then the neon stutters, the way old signs do, then comes back.
func _flicker_neon() -> void:
	if not is_instance_valid(_neon):
		return
	var stutter := _neon.create_tween()
	stutter.tween_interval(_scenery_dice.randf_range(4.0, 14.0))
	for k in _scenery_dice.randi_range(2, 4):
		stutter.tween_property(_neon, "modulate:a", _scenery_dice.randf_range(0.15, 0.5), 0.05)
		stutter.tween_property(_neon, "modulate:a", 1.0, _scenery_dice.randf_range(0.04, 0.12))
	stutter.tween_callback(_flicker_neon)


## A little steam off a hot dish just set down, for a while.
const HOT_DISHES := ["tteokbokki", "odeng", "sundae", "dakgalbi", "pajeon", "ramyeon", "gonggibap", "bokkeumbap"]

func _steam(shape: Control) -> void:
	for k in 2:
		var puff := _rect(shape, Vector2(9 + k * 7, 12), Vector2(7, 7), Color(1, 1, 1, 0.0))
		puff.name = "Steam"
		var rise := puff.create_tween().set_loops(4)  # (it cools down)
		rise.tween_interval(k * 0.8 + _scenery_dice.randf_range(0.0, 0.4))
		rise.tween_property(puff, "position", Vector2(6 + k * 9, -18), 2.2).from(Vector2(9 + k * 7, 12))
		rise.parallel().tween_property(puff, "color:a", 0.0, 2.2).from(0.28)


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
		look = BarLook.default_bar_look()
	_glow.visible = true
	for piece in _tent:
		piece.visible = true
	var tarp: Array = BarLook.BAR_TARPS.get(look["tarp"], BarLook.BAR_TARPS["orange"])
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
	var style: Array = BarLook.SIGN_STYLES.get(look["sign"], BarLook.SIGN_STYLES["wood"])
	_sign_board.color = Color(style[0])
	for label in [_sign_hangul, _sign_english]:
		label.add_theme_color_override("font_color", Color(style[1]))
		if look["sign"] == "neon":  # a glowing tube: a soft halo round the letters
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_color_override("font_outline_color", Color(style[1]).darkened(0.5))
		else:
			label.add_theme_constant_override("outline_size", 0)
	_sign_hangul.text = str(look["hangul"])
	Glossary.remember(str(look["hangul"]), "%s: the bar's name, %s%s" % [look["hangul"], Game.bar.get("name", ""), (" (%s)" % Game.bar["name_meaning"]) if str(Game.bar.get("name_meaning", "")) != "" else ""])
	_sign_english.text = str(Game.bar.get("name", "")).to_upper()
	_sign.tooltip_text = Text.tip("%s · %s (%s)" % [look["hangul"], Game.bar.get("name", ""), Game.bar.get("name_meaning", "")])
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
func _update_light(closing_dim: bool = false) -> void:
	var light := NightRules.night_light(_clock)
	var sky: Color = light["sky"]
	match _weather_kind:
		"cold": sky = sky.lerp(Color("1c2c4c"), 0.35)
		"fog": sky = sky.lerp(Color("4a4a58"), 0.35)
		"muggy": sky = sky.lerp(Color("4a2e2a"), 0.25)
	_sky.color = sky
	var closing := closing_dim or (_closing_early and _night_open)  # (the far bulb's off: see _show_closing_up)
	_glow.color = Color(0.91, 0.51, 0.23, float(light["glow"]) * (CLOSING_GLOW if closing else 1.0))
	for bulb in _bulb_lights:
		bulb.color = light["bulb"]
	if closing and not _bulb_lights.is_empty():
		_bulb_lights[-1].color = BULB_OFF


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
	var skin := Color(Looks.SKIN_TONES[clampi(int(look.get("skin", 0)), 0, Looks.SKIN_TONES.size() - 1)])
	var hair_colour := Color(str(Looks.HAIR_COLOURS.get(look.get("hair_colour", "black"), Looks.HAIR_COLOURS["black"])[0]))
	var cloth := Color(str(Looks.CLOTHES_COLOURS.get(look.get("colour", "black"), Looks.CLOTHES_COLOURS["black"])[0]))
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
	return Looks.pick_look(gender, Looks.pick_age_range(randf()), _weather_kind)


## The owner's look: chosen with the bar and saved; bars from before looks get one now,
## from the owner's age, without asking the AI.
func _owner_look() -> Dictionary:
	if not _owner.has("look"):
		var range_id := Looks.age_range_of(int(_owner.get("age", 55)))
		_owner["look"] = Looks.pick_look(str(_owner.get("gender", "woman")), range_id, "", true)
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
	return maxi(0, NightRules.DAYS.find(_night_day))


## A new bar's two founding regulars: the game decides who they'll be (gender, look, role,
## how long and how often, their usual), and the AI invents them. Saved with the bar.
func _make_founding_regulars() -> void:
	var roles: Array = Regulars.ROLES.keys()
	roles.shuffle()
	var taken: Array = [str(_owner["name"])]
	var made: Array = []
	for i in 2:
		var gender := People.game_gender(randf())
		var look := Looks.pick_look(gender if gender != "non-binary" else ["woman", "man"].pick_random(), Looks.pick_age_range(randf()), "")
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
	return People.validate_regular_tonight(data)


func _validate_founding(data: Variant, taken: Array, gender: String, age_range: String) -> String:
	return People.validate_founding_regular(data, taken, gender, age_range)


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
		var arrives := "%s ducks in and takes %s usual stool: %s been coming %s, %s." % [regular["name"], her, she, regular.get("since", ""), regular.get("habit", "")]
		if not bool(regular.get("introduced", false)):
			# The first time we see them: who they are to the tent.
			regular["introduced"] = true
			Game.save()
			var who: String = {"woman": "She's", "man": "He's"}.get(str(regular.get("gender", "")), "They're")
			arrives += " %s %s. %s" % [who, str(Regulars.ROLES.get(regular.get("role", ""), "a regular")).get_slice(":", 0), Text.as_sentence(str(regular.get("history", "")))]
		return arrives
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
	if Hooks.memories:
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
		var roll := Hooks.regular_roll_override if Hooks.regular_roll_override >= 0.0 else randf()
		if not Regulars.becomes_regular(verdict, rushed, roll):
			return
		regular = Regulars.new_regular(guest.customer, guest.customer.get("look", {}), guest.first_order, _night_number, _day_index(), guest.arrived_minutes, randf())
		_regulars().append(regular)
		if str(memory.get("towards_owner", "")) == "warmer":
			regular["warmth"] = 1
		var they: String = {"woman": "she'll", "man": "he'll"}.get(str(guest.customer.get("gender", "")), "they'll")
		_narrate("%s looks like %s be back." % [guest.customer["name"], they])
		_event("became_regular", {"gender": str(guest.customer.get("gender", "")), "name": str(guest.customer["name"])}, guest.node)
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
	return Memories.validate_memory(data, said)


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
	for key in Memories.STICKING:
		if str(facts.get(key, "")) != "":
			parts.append("%s: %s" % [{"job": "Job", "family": "Family", "home": "From", "other": "Also"}[key], facts[key]])
	if str(known.get("owner_knows", "")) != "" and parts.is_empty():
		parts.append(str(known["owner_knows"]))
	return " · ".join(parts)  # (Text.hint makes it safe to go inside the tag.)


# --- Who calls whom, and friendliness ------------------------------------------------------

const FRIENDLY_AFTER := 4  # meetings before two regulars might ask "can I call you eonni?"


## Someone, as far as address goes (see Address.allowed_terms). null: the owner.
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
		Address.address_text(_who(guest), _addressee(guest), _who(null), _addressee(null), false),
		Address.address_text(_who(null), _addressee(null), _who(guest), _addressee(guest), false)]
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
	var term := Address.sibling_term(_addressee(speaker), _addressee(addressee))
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
	_narrate("%s and %s are on \"%s\" terms now." % [a.customer["name"], b.customer["name"], term])
	_event("friendlier", {"a": str(a.customer["name"]), "b": str(b.customer["name"]), "term": term}, a.node)
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
	var allowed := Address.allowed_terms(_addressee(speaker), _addressee(listener), speaker != null and listener != null and _close(speaker, listener))
	for term in Address.terms_in(line, [_who(speaker), _who(listener)]):
		if allowed.has(term):
			return term
	return ""
