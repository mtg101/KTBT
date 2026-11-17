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

const Ai = preload("res://scripts/ai/ai.gd")
const TentView = preload("res://scripts/bar/tent_view.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const Street = preload("res://scripts/bar/street.gd")
const Night = preload("res://scripts/bar/night.gd")
const Layout = preload("res://scripts/bar/layout.gd")
const Cat = preload("res://scripts/bar/cat.gd")
const Kitchen = preload("res://scripts/bar/kitchen.gd")
const CaptionsOnScreen = preload("res://scripts/bar/captions_on_screen.gd")
const StoryKeeper = preload("res://scripts/bar/story_keeper.gd")
const RegularsTonight = preload("res://scripts/bar/regulars_tonight.gd")
const CounterChats = preload("res://scripts/bar/counter_chats.gd")
const Friendliness = preload("res://scripts/bar/friendliness.gd")
const Conversation = preload("res://scripts/bar/conversation.gd")
const Scenery = preload("res://scripts/bar/scenery.gd")
const StatsPanel = preload("res://scripts/bar/stats_panel.gd")
const PdCamera = preload("res://scripts/bar/camera.gd")
const Plants = preload("res://scripts/rules/plants.gd")
const SaveUpgrades = preload("res://scripts/save/save_upgrades.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")
const Menu = preload("res://scripts/rules/menu.gd")
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
const SkylineView = preload("res://scripts/ui/skyline_view.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Signatures = preload("res://scripts/rules/signatures.gd")
const Specials = preload("res://scripts/rules/specials.gd")
const MenuChanges = preload("res://scripts/rules/menu_changes.gd")
const MenuBoard = preload("res://scripts/ui/menu_board.gd")
const DishView = preload("res://scripts/ui/dish_view.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const People = preload("res://scripts/rules/people.gd")
const Story = preload("res://scripts/rules/story.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Regulars = preload("res://scripts/rules/regulars.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const CaptionPopup = preload("res://scripts/ui/caption.gd")
const DiaryPage = preload("res://scripts/ui/diary_page.gd")
const DiaryBook = preload("res://scripts/ui/diary_book.gd")
const RecapScreen = preload("res://scripts/ui/recap_screen.gd")
const Hooks = preload("res://scripts/test_hooks.gd")
const NightEvents = preload("res://scripts/bar/night_events.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

const HUNGRY_CHANCE := 0.15  # How often a customer is hungry enough to order two main dishes.
const ROUGH_NIGHT_CHANCE := 0.2  # How often a customer is having a rough enough night to order two drinks.
## Free side dishes served with every first order, as at a real pojangmacha. Not on the bill.
const BANCHAN := Kitchen.BANCHAN


const ACCENT := Ktv.ORANGE
const MUTED := Ktv.MUTED
const OWNER_COLOR := Color("8f8aa8")
const OWNER_TEXT := Ktv.YELLOW

# Screen layout (pixels, at the project's 1920x1080; Godot scales it to the window).
const SCREEN := Vector2(1920, 1080)
const PANELS_TOP := 452.0  # The transcript, the PD's desk and the side panel fill the screen below the tent.
const SIDE_WIDTH := 520.0  # the side panel on the right: who's here now, and the debug stats
const DESK_WIDTH := 460.0  # the PD's desk, between the transcript and the side panel

# Where things stand in the tent (pixels, inside the stage area, which is nearly full width).
const STAGE_SIZE := Vector2(1872, 380)
const SEAT_X := Layout.SEAT_X
const PERSON_WIDTH := 80.0
const CUSTOMER_Y := Layout.CUSTOMER_Y
const OWNER_Y := 150.0
const OWNER_HOME_X := 180.0  # by the stove
const OWNER_BESIDE_X := -165.0  # where the owner stands to see to a stool (just to its left)
# Off-stage spots either side (far enough out that the name tag is hidden too).
const OFFSCREEN_LEFT_X := Layout.OFFSCREEN_LEFT_X
const OFFSCREEN_RIGHT_X := Layout.OFFSCREEN_RIGHT_X

## The test hooks are in test_hooks.gd (as Hooks.<name>): tests set them; the game only reads them.

## When the owner's free and nothing's urgent: how often customers chat to each other
## instead of the owner chatting to someone. Mostly it's customer and owner.
const CHAT_CHANCE := 0.5
## ...and when it's busy (People.BUSY_COUNTER or more in), when there are most people to talk to.
const BUSY_CHAT_CHANCE := 0.75
const JOIN_CHANCE := CounterChats.JOIN_CHANCE
const OWNER_JOINS_CHANCE := 0.35  # how often the owner joins a customer chat
const CHAT_LINES := Vector2i(3, 5)  # lines in a spell of customer chat
const CHAT_MIN_STAY_LEFT := CounterChats.CHAT_MIN_STAY_LEFT
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
	var camera_moment := ""  # a Talk.camera_moment for their next line: the PD's camera has just turned to them
	var plant_moment := ""  # a Plants.moment for their next line: a PD's plant card has just happened to them...
	var plant_card := ""  # ... which card
	var plant_happened := ""  # ... and what happened, for whichever conversation they speak in next
	var pd_topic := ""  # the PD's cue card, the topic of their talk with the owner...
	var pd_topic_lines := 0  # ... for this many more lines
	var to_camera := false  # their next line's an interview cut: answered straight to camera
	var kya_done := false  # had their "Kya~!" after the first drink
	var turned_away := false  # turned away to drink in front of an elder (once a night)
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
const Chat = CounterChats.Chat  # (a conversation between customers at the counter: see scripts/bar/counter_chats.gd)


## Every frame, while the tent's open: a wait for the next frame waits on this, so it's dropped
## when the tent goes (rather than coming back to a scene that's gone).
signal _frame_done

var _ai: Ai
var _owner := {}
var _takings := 0

# Who's here and what the owner's doing
var _guests: Array = []  # Guest: whoever's on a stool
var _camera := PdCamera.new()  # the PD's camera: who the show's following tonight (scripts/bar/camera.gd)
const CAMERA_RED := Color("ff4f6d")  # the camera's REC (the shock caption's red)
var _camera_rec: Label  # "● REC" and who, in the stage's top corner, while the camera's on someone
var _hand: Array = []  # tonight's plant cards (Plants.CARDS ids), dealt as the night opens
var _played: Array = []  # ... and the ones played
var _planted_regular := ""  # the regular the PD rang tonight, until they're in (their id)
var _plant_dice := RandomNumberGenerator.new()  # the cards' own (dealing them never shifts anything else's rolls)
var _plant_cards: VBoxContainer  # the cards on the PD's desk
var _writing_box: VBoxContainer  # the box the PD writes a write-in card in (on the desk, never a pop-up)
var _writing_label: Label
var _writing_text: LineEdit
var _writing_problem: Label
var _writing_card := ""  # the write-in card being written ("": none)
var _edit := {}  # the PD's edit up on the desk: {"spins", "reply", "lines", "names", "roll"} ({}: none)
var _edit_box: VBoxContainer
var _edit_buttons: VBoxContainer
var _edit_bar: ProgressBar
var _edit_tween: Tween
var _picked := {}  # card -> the Guest the game picked for it (with nobody on camera), until it's played
var _card_what := {}  # card -> what it is tonight (its variant), picked as it's dealt, so a write-in says it before you type
var _lights_out := 0.0  # real seconds left of the lights being out (the lights-flicker card)
const LIGHTS_OUT_SECONDS := 2.5
const PLANT_KIND_COLOURS := {"event": Ktv.MINT, "write": Ktv.PINK, "sponsor": Ktv.YELLOW}  # (the desk's card stripes and tags)
const PLANT_STAY_LEFT := 20.0  # game minutes someone needs left for a card picked for them (a pair: both)
const PLANT_REGULAR_MINUTES := 15.0  # how long a regular the PD rang takes to get here
var _counter_chats := CounterChats.new()  # customers chatting: who's in which chat, choosing the next spell (scripts/bar/counter_chats.gd)
var _chats: Array:  # Chat: customer conversations going on at the counter
	get:
		return _counter_chats.chats
var _names_tonight: Array = []
var _jobs_tonight: Array = []  # tonight's customers' jobs and looks, so newcomers are different
var _looks_tonight: Array = []
const VARIETY_LOOKS := 5  # how many recent looks the AI is shown
## A customer invented ahead (see _prepare_customer) is used if they arrive within this many
## game minutes; any later, they're from another hour (a 7pm salaryman isn't a 2am one).
const PREPARED_FRESH_MINUTES := 60.0
# The cat: who it is (saved with the bar) and where it is now.
var _tent_cat: Cat  # the cat itself: who, where, drawing it (scripts/bar/cat.gd); these pass through to it
var _cat: Dictionary:  # name, coat, personality
	get:
		return _tent_cat.info
	set(value):
		_tent_cat.info = value
var _cat_spot: String:
	get:
		return _tent_cat.spot
	set(value):
		_tent_cat.spot = value
var _cat_with: Guest:  # the customer it's on, at the feet of, or begging from
	get:
		return _tent_cat.with_guest
	set(value):
		_tent_cat.with_guest = value
var _cat_next: float:  # game minutes until it moves on
	get:
		return _tent_cat.next_move
	set(value):
		_tent_cat.next_move = value
var _cat_node: Control:
	get:
		return _tent_cat.node
const CAT_MOVE_MINUTES := Cat.MOVE_MINUTES
## How often a move that's just the cat pottering about (not with a customer, not in or out
## of the tent) is narrated, so the transcript isn't a log of the cat's every step.
const CAT_POTTER_NARRATED := 0.35  # every customer's name so far tonight (the AI is asked to avoid them)
var _waiting: Array = []  # when each person waiting for a stool (or to be greeted) turned up
var _waiting_who: Array = []  # ...and who they are: a regular's id, or "" for someone new
var _regulars_due: Array = []  # {"time", "id"}: regulars coming in tonight, soonest first
var _skip_arrivals := 0  # a regular came in instead of someone new
var _kitchen_part := Kitchen.new()  # the stove: what's cooking, waiting and ready (scripts/bar/kitchen.gd)
var _kitchen: Array:  # (the stove's queue: the first is on, the rest wait)
	get:
		return _kitchen_part.queue
var _ready_dishes: Array:  # (cooked, waiting to be carried over)
	get:
		return _kitchen_part.ready
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
var _ambience: Ambience  # the tent's background sound
var _bubble_layer: Control  # speech bubbles, over everything on the stage
var _bubbles_shown: Array = []  # Bubble: the newest last
var _caption_layer: Control  # TV captions, over everything
var _captions_toggle: CheckBox
var _music_toggle: CheckBox
var _options_button: Button  # the top bar's Options button...
var _options_panel: PanelContainer  # ...and the panel it drops down
var _captions_part: CaptionsOnScreen  # TV captions on screen: pacing, popping, the red light (scripts/bar/captions_on_screen.gd)
var _caption_shown: Control:  # the one up now
	get:
		return _captions_part.shown
var _rush_shown := false  # tonight's after-work rush has been and gone
var _dawn_shown := false  # ...and 2am feelings
var _red_flashes: int:  # emergencies flashed (for tests)
	get:
		return _captions_part.red_flashes
## Tonight's specials (menu ids, rules/specials.gd): marked on the menu customers see. (What's
## sold out tonight is Menu.sold_out.)
var _specials: Array = []
var _menu_change := {}  # tonight's menu change, if there was one (MenuChanges): for the diary
## A CatRules.cat_moment for the owner's next line (the cat's up on the counter again...).
var _owner_cat_moment: String:  # (kept by the night)
	get:
		return _night.owner_cat_moment
	set(value):
		_night.owner_cat_moment = value
var _owner_stunned: String:  # a Talk.stunned_moment for the owner's next line (kept by the night)
	get:
		return _night.owner_stunned
	set(value):
		_night.owner_stunned = value
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
const STROLL_Y := Layout.STROLL_Y
## When the last line shown will have been read (Time.get_ticks_msec()). The AI works on the
## next line while you read; it's shown once you've had time to read this one.
var _read_until := 0
## Tonight: what the tent's parts share (scripts/bar/night.gd).
var _night := Night.new()
## Tonight's debug stats (see night_stats.gd), shown in the stats panel and logged at the end (kept by the night).
var _stats: NightStats:
	get:
		return _night.stats
	set(value):
		_night.stats = value
var _stats_refresh := 0.0
## Tonight's transcript file, written line by line as the night goes (see _start_transcript).
var _story := StoryKeeper.new()  # tonight's transcript file, and what "Previously on…" is written from (scripts/bar/story_keeper.gd)
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
var _recap_said := ""  # tonight's "Previously on…"
var _setup_ai: Array = []  # the AI's answers while a night's being got ready (the bar opening: its menu, own dishes, recap), counted in that night's stats
var _getting_ready := true  # the bar's opening, or the next night's being got ready (not yet open)
## Its cliffhanger (Story.CLIFFHANGERS): {"kind", "who", "teaser", "answered"}, if tonight can answer it.
var _cliffhanger := {}
var _summary: PanelContainer
var _summary_text: RichTextLabel

# UI
var _try_again: Button  # only shown if the owner couldn't be invented
var _leave_button: Button
var _time_speed := NightRules.time_speed(0)  # how fast game time is running now (eases to the target)
var _reading_toggle: CheckBox
var _stats_panel: PanelContainer  # the side panel: who's here now, then the debug stats, in tabs
var _stats_text: RichTextLabel
var _stats_tabs: HFlowContainer  # one tab per section of the stats, and All
var _stats_view: StatsPanel  # what the stats panel shows, in its tabs (scripts/bar/stats_panel.gd)
var _log_panel: PanelContainer
var _moment_label: Label
var _mode_label: Label
var _takings_label: Label
var _title_label: Label
var _log: RichTextLabel
var _typing_label: Label
var _here_text := ""  # who's here now, for the side panel's first tab (see _update_info)
var _desk_panel: PanelContainer  # the PD's desk: the camera (and the plant cards, to come)
var _desk: RichTextLabel

# Scene pieces
var _stage: Control
var _owner_node: Control
var _owner_tag: Label
# The look of the tent and the night (placeholder art, drawn in code)
## Its own dice for scenery that comes and goes by itself (the neon sign, steam, the cat
## prowling), so it never shifts the game's own rolls (tests fix those with a seed).
var _scenery_dice := RandomNumberGenerator.new()
var _scenery: Scenery  # the tent's fixtures: the fridge, the odeng pot, the neon, steam (scripts/bar/scenery.gd)
var _skyline: SkylineView  # the city behind the tent
var _menu_board: MenuBoard  # the menu, taped up on the back wall
## Tonight's weather, as NightRules.weather_kind says it (kept by the night).
var _weather_kind: String:
	get:
		return _night.weather_kind
	set(value):
		_night.weather_kind = value
var _street: Street  # the street in front: strollers, passers-by, rain gear (scripts/bar/street.gd)
var _tent_view := TentView.new(STAGE_SIZE)  # the tent's look: tarp, sign, touches, sky, light, bulbs, weather (scripts/bar/tent_view.gd)
var _people_view: PeopleView  # drawing people: dressed, facing, phones, umbrellas, running for it (scripts/bar/people_view.gd)
var _drinks_rows: Array = []  # one per stool
var _food_rows: Array = []


func _ready() -> void:
	_people_view = PeopleView.new(_scenery_dice, _night)  # (the same dice as the rest of the scenery)
	_tent_cat = Cat.new(_scenery_dice, STAGE_SIZE.x)
	_scenery = Scenery.new(_scenery_dice, STAGE_SIZE.x)
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
	_ai.answered.connect(_on_ai_answered)
	if _ai.offline:
		_show_offline_mode()
	Menu.use(Menu.for_bar(Game.bar))  # this bar's own menu (the classic one if it has none)
	if Game.bar.is_empty():
		_invent_owner()  # A new bar: invent the owner, then name the tent and save it.
	else:
		_open_saved_bar()


## A bar from a save: its owner is back behind the counter, and the takings carry on.
func _open_saved_bar() -> void:
	if not SaveUpgrades.upgrade(Game.bar).is_empty():  # a bar saved by an older version: what the game fills in itself, once
		Game.save()
	_owner = Game.bar["owner"].duplicate(true)
	_takings = int(Game.bar.get("takings", 0))
	_takings_label.text = "Takings: %s" % Menu.format_won(_takings)
	_show_bar_name()
	_show_look()
	_people_view.dress(_owner_node, _owner_look())
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Text.as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up %s again for the night." % [_owner_display(), Game.bar["name"]])
	_owner_working = true  # busy until it's done (it may ask the AI)
	# What an older bar still needs the AI for, once (see SaveUpgrades).
	var needs := SaveUpgrades.ai_needs(Game.bar, Hooks.bar_menus, Hooks.founding_regulars)
	if needs.has("hangul"):
		await _fill_in_hangul()  # names from before they had Hangul, or whose first try didn't fit
	if needs.has("founding_regulars") and not _stopped:
		await _make_founding_regulars()  # a bar from before regulars: its two
	if needs.has("signatures") and not _stopped:
		await _invent_signatures()  # a menu from before signature dishes: the owner's own
	if Hooks.bar_menus and not Game.bar.get("menu", []).is_empty() and not _stopped:
		await _change_menu()  # now and then, something new on the board
	if _closed():
		_owner_working = false
		return
	if not Game.bar.get("cat", {}).is_empty():  # bars saved before cats have none, for now
		_show_cat()
	_update_info()
	if Hooks.recaps and int(Game.bar.get("nights", 0)) > 0:
		_loading_note = "The editors are cutting \"Previously on…\""
		var recap := await _write_recap()
		_loading_note = ""
		if _closed():
			_owner_working = false
			return
		_end_loading()
		await _play_recap(recap, false)
	else:
		_end_loading()
	_owner_working = false
	if _closed():
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
			_typing_label.text = "The subtitle team are writing %s in Hangul..." % person_name
			var reply: Dictionary = await _ai.ask_json(Prompts.hangul_messages(person_name), _validate_hangul.bind(person_name),
				{"temperature": 0.2}, {"purpose": "hangul", "name": person_name})
			_typing_label.text = ""
			if _closed():
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
	return "%s  (%ds: the writers' room may be waking up: the AI can take a minute after it's been idle)" % [text, waited]


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
	_typing_label.text = "The casting team are finding the tent's owner..."
	var gender: String = ["woman", "man"].pick_random()
	# The game decides their age range and how they look; the AI invents who they are.
	var look := Looks.pick_look(gender, Looks.pick_age_range(randf(), true), "", true)
	var result: Dictionary = await _ai.ask_json(Prompts.owner_messages(gender, look), _validate_owner.bind(gender, str(look["age_range"])), {"temperature": 0.9},
		{"purpose": "owner", "gender": gender, "look": look})
	_typing_label.text = ""
	if _stopped:  # (the bar closed while it was waiting)
		return
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
	_people_view.dress(_owner_node, look)
	_owner_tag.text = _owner_label()
	_owner_node.visible = true
	_narrate(Text.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	await _name_cat()
	await _choose_look()
	if Hooks.bar_menus:
		await _choose_menu()
	if Hooks.founding_regulars:
		await _make_founding_regulars()
	_show_look()
	_show_cat()
	await _frame_done  # let the tent draw before the loading screen fades
	_end_loading()
	if Hooks.recaps:
		_before_night["recap_by"] = "game"  # (a series opener's always the game's)
		await _play_recap(Story.series_opener(_recap_facts()), true)  # a new series: its first episode
		if _closed():
			return
	_narrate("%s opens up for the night." % _owner_display())
	_update_info()
	_owner_working = false
	_start_night()


## A new bar: the AI names the tent (the game names it if the AI can't), and it's saved.
func _name_bar() -> void:
	_typing_label.text = "The owner's painting the sign..."
	var named: Dictionary = await _ai.ask_json(Prompts.bar_name_messages(_owner), _validate_bar_name, {"temperature": 0.9},
		{"purpose": "bar_name", "owner_name": _owner["name"]})
	_typing_label.text = ""
	if _stopped:  # (the bar closed while it was waiting)
		return
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
	_typing_label.text = "The owner's putting up the tarp..."
	_look_offer = {} if Hooks.offer_every_look else BarLook.look_offer()
	var look: Dictionary = await _ai.ask_json(
		Prompts.bar_look_messages(_owner, str(Game.bar["name"]), str(Game.bar.get("name_meaning", "")), _look_offer),
		_validate_bar_look, {"temperature": 0.8}, {"purpose": "bar_look", "bar_name": Game.bar["name"],
			"tarps": _look_offer.get("tarp", BarLook.BAR_TARPS.keys()), "shapes": _look_offer.get("shape", BarLook.TENT_SHAPES.keys())})
	_typing_label.text = ""
	if _closed():  # (the bar closed while it was waiting)
		return
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


## Tonight's board, in the transcript: the specials, and anything sold out.
func _narrate_board() -> void:
	var said := PackedStringArray()
	if not _specials.is_empty():
		said.append("Tonight's special%s, chalked on the board: %s." % ["s" if _specials.size() > 1 else "", " and ".join(PackedStringArray(_specials.map(func(id): return str(Menu.find(str(id)).get("name", id)))))])
	for id in Menu.sold_out:
		said.append("%s is crossed out: sold out." % Menu.find(str(id)).get("name", id))
	if not said.is_empty():
		_narrate(" ".join(said))


## The menu board, in the bar's style: tonight's menu (click it to read it), with tonight's
## specials and the house favourite.
func _put_up_menu() -> void:
	_menu_board.show_menu(Menu.board_order(_specials), _specials, Menu.sold_out, Menu.favourite(Game.bar.get("history", [])), str(Game.bar.get("id", "")), str(Game.bar.get("name", "")))


## A new bar's menu: the owner chooses it, from the catalogue, within the house rules (the
## game builds one by the same rules if the AI can't). Saved with the bar, and in use.
func _choose_menu() -> void:
	_typing_label.text = "The owner's writing out the menu..."
	var chosen: Dictionary = await _ai.ask_json(Prompts.menu_messages(_owner, str(Game.bar["name"]), str(Game.bar.get("name_meaning", ""))),
		Catalogue.validate_menu, {"temperature": 0.8}, {"purpose": "menu", "bar_name": Game.bar["name"]})
	_typing_label.text = ""
	if _closed():  # (the bar closed while it was waiting)
		return
	var menu: Array = chosen.get("menu", [])
	if menu.is_empty():
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(str(Game.bar.get("id", "")))  # (its own dice: the game's rolls don't shift)
		menu = Catalogue.fallback_menu(dice)
	Game.bar["menu"] = menu
	Game.bar["menu_why"] = str(chosen.get("why", ""))
	_before_night["menu_by"] = "ai" if chosen.has("menu") else "game"  # (for the stats)
	Game.save()
	Menu.use(menu)
	_put_up_menu()
	var own: Array = menu.filter(func(item): return Catalogue.layer(str(item["id"])) == "own").map(func(item): return str(item["name"]))
	_before_night["menu_own"] = own.duplicate()
	_narrate("On the menu: the pocha classics, and %s.%s" % [", ".join(PackedStringArray(own.slice(0, -1))) + (" and " if own.size() > 1 else "") + str(own[-1]) if not own.is_empty() else "nothing else", (" " + Text.as_sentence(str(chosen["why"]))) if chosen.has("why") else ""])
	await _invent_signatures()


## Every few weeks of nights, maybe (see MenuChanges): a dish of the bar's own that hardly anyone
## orders comes off the board, and the AI chooses what goes on instead, from a few the game
## offers (the game's first pick if it can't). Saved, on the board, told in the transcript, and
## in tonight's stats, highlights and diary.
func _change_menu() -> void:
	var night := int(Game.bar.get("nights", 0)) + 1
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(str(Game.bar.get("id", "")) + "menu" + str(night))  # (its own dice: the game's rolls don't shift)
	if not MenuChanges.due(night - int(Game.bar.get("menu_changed_night", 0)), Hooks.menu_change_roll if Hooks.menu_change_roll >= 0.0 else dice.randf()):
		return
	var menu: Array = Game.bar["menu"]
	var protected: Array = []
	for regular in _regulars():
		protected.append_array(Regulars.usual_of(regular))
	var out_id := MenuChanges.going(menu, Game.bar.get("history", []), protected)
	if out_id == "":
		return
	var season := Seasons.season(Seasons.day_of_year(int(Game.bar.get("first_date", Seasons.today())), night))
	var choices := MenuChanges.offered(menu, out_id, season, dice)
	if choices.is_empty():
		return
	var out_name := str(Menu.find(out_id).get("name", out_id))
	_typing_label.text = "The owner's rubbing something off the menu board..."
	var reply: Dictionary = await _ai.ask_json(Prompts.menu_change_messages(_owner, str(Game.bar["name"]), out_name, choices),
		MenuChanges.validate_change.bind(choices), {"temperature": 0.8}, {"purpose": "menu_change", "choices": choices})
	_typing_label.text = ""
	if _closed():
		return
	var in_id := str(reply.get("dish", choices[0]))
	var change := {"night": night, "out": out_id, "in": in_id, "why": str(reply.get("why", "")), "by": "game" if reply.is_empty() else "ai"}
	Game.bar["menu"] = MenuChanges.swapped(menu, out_id, in_id)
	Game.bar["menu_changed_night"] = night
	var changes: Array = Game.bar.get("menu_changes", [])
	changes.append(change)
	Game.bar["menu_changes"] = changes
	Game.save()
	Menu.use(Game.bar["menu"])
	_put_up_menu()
	_before_night["menu_change"] = change.duplicate()  # (for the stats, the highlights and the diary)
	var dish := Menu.find(in_id)
	_narrate("%s's rubbed off the menu board: hardly anyone ordered it. New tonight: %s %s, %s.%s" % [out_name, dish.get("hangul", ""), dish.get("name", in_id),
		Menu.format_won(int(dish.get("price", 0))), (" " + Text.as_sentence(change["why"])) if change["why"] != "" else ""])


## The owner's own dishes, one or two, from their story (the AI's, or one of the game's own if
## it can't): added to the bar's menu, saved, on the board, and told in the transcript.
## A bar whose menu was chosen before there were signature dishes gets them once, when it opens.
func _invent_signatures() -> void:
	var menu: Array = Game.bar.get("menu", [])
	var names: Array = menu.filter(func(item): return not bool(item.get("mixed", false))).map(func(item): return str(item["name"]))
	_typing_label.text = "The owner's thinking about what only they make..."
	var reply: Dictionary = await _ai.ask_json(Prompts.signature_messages(_owner, str(Game.bar["name"]), str(Game.bar.get("name_meaning", "")), names),
		Signatures.validate_signatures.bind(menu), {"temperature": 0.9}, {"purpose": "signatures", "bar_name": Game.bar["name"]})
	_typing_label.text = ""
	if _closed():
		return
	var dishes: Array = reply.get("items", [])
	Game.bar["signatures_by"] = "ai"
	if dishes.is_empty():
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(str(Game.bar.get("id", ""))) + 1  # (its own dice: the game's rolls don't shift)
		dishes = Signatures.fallback(dice, menu)
		Game.bar["signatures_by"] = "game"
	Game.bar["menu"] = menu.filter(func(item): return not Signatures.is_signature(item)) + dishes
	Game.save()
	Menu.use(Game.bar["menu"])
	_put_up_menu()
	_before_night["signatures_by"] = str(Game.bar["signatures_by"])  # (for the stats)
	_before_night["signatures"] = dishes.map(func(item): return str(item["name"]))
	for dish in dishes:
		_narrate("The house's own: %s %s (\"%s\"), %s. %s" % [dish["hangul"], dish["name"], dish["meaning"], Menu.format_won(int(dish["price"])), Text.as_sentence(str(dish["desc"]))])


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
		_validate_cat_name.bind(taken), {"temperature": 0.9}, {"purpose": "cat_name", "taken": taken, "coat": coat})
	_typing_label.text = ""
	if _closed():  # (the bar closed while it was waiting)
		return
	var cat_name := str(named["name"]) if not named.is_empty() else CatRules.fallback_cat_name(randf(), taken, coat)
	var cat_hangul := str(named.get("hangul", "")) if not named.is_empty() else str(Names.CAT_HANGUL.get(cat_name, ""))
	_new_cat(cat_name, coat, personality, sex, cat_hangul)


func _new_cat(cat_name: String, coat: String, personality: String, sex: String, hangul: String = "") -> void:
	Game.bar["cat"] = {"name": cat_name, "coat": coat, "personality": personality, "sex": sex, "hangul": hangul}
	Game.save()


func _show_cat() -> void:
	_cat = Game.bar["cat"].duplicate()
	_tent_cat.paint(_cat_label())
	_cat_node.tooltip_text = _cat_tooltip()
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
		_street.walk_past(gone * 1.5)
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
		Story.validate_closing.bind(owner_name, str(_owner["title"]), [owner_name] + seated, _tent_cat.fact()), {"temperature": 0.9},
		{"purpose": "closing", "title": _owner["title"], "weather": _weather_kind})
	_typing_label.text = ""
	if _closed():
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
	if not _tent_view.bulb_lights.is_empty():
		var bulb: ColorRect = _tent_view.bulb_lights[-1]
		var off := bulb.create_tween()
		for k in 2:
			off.tween_property(bulb, "modulate:a", 0.25, 0.06)
			off.tween_property(bulb, "modulate:a", 1.0, 0.08 + 0.05 * k)
		off.tween_callback(_update_light.bind(true))


func _leave() -> void:
	if _night_open:
		_save_stats(false)  # a night cut short still gets a log
	elif _story.is_writing():
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
		_skyline.show_city(Skyline.plan(STAGE_SIZE.x, hash(bar_id)), bar_id, Skyline.hills(STAGE_SIZE.x, hash(bar_id)))  # (its own dice: the game's rolls don't shift)
	var board_dice := RandomNumberGenerator.new()
	board_dice.seed = hash([randf(), randf()])  # (two rolls of the game's dice, as before: its other rolls don't shift)
	var board := Specials.tonight(Menu.items(), NightRules.weather_kind(_night_weather), str(_night_date.get("season", "")),
		Game.bar.get("last_specials", []), board_dice)
	_specials = board["specials"]
	Menu.sold_out = board["sold_out"]
	Game.bar["last_specials"] = _specials.duplicate()  # (not the same again tomorrow; saved with the night)
	_put_up_menu()  # (with tonight's specials, and anything sold out)
	_narrate_board()
	_clock = float(NightRules.OPEN_MINUTES)
	_night_visits = 0
	_night_takings = 0
	_night_lines = []
	_stats = NightStats.new()
	_camera = PdCamera.new()
	_camera.cat = _tent_cat
	_plant_dice.seed = hash("%s night %d" % [Game.bar.get("id", ""), _night_number])
	_hand = Plants.deal(_plant_dice, _plant_tonight(), Game.bar.get("last_hand", []))
	Game.bar["last_hand"] = _hand.duplicate()  # (not the same cards tomorrow; saved with the night)
	_played = []
	_picked = {}
	_card_what = {}
	if not _edit.is_empty():
		_air_edit(0)
	for card in _hand:
		_what_for(str(card))
	_close_writing()
	_planted_regular = ""
	_lights_out = 0.0
	_show_camera()
	_events = NightEvents.new()
	_events.happened.connect(_stats.record_event)
	_events.happened.connect(_caption_for_event)
	_events.happened.connect(_watch_cliffhanger)
	_stats.events = _events.timeline  # (saved in the night's log, so a night's timeline can be looked back over)
	for answer in _setup_ai:  # (the AI's answers before tonight opened: the menu, the recap...)
		_stats.record_ai(float(answer[1]), answer[2], bool(answer[3]), str(answer[0]))
	_setup_ai = []
	_getting_ready = false
	_stats.specials = _specials.duplicate()
	_stats.sold_out = Menu.sold_out.duplicate()
	_stats.story = _before_night.duplicate()  # (how it opened: only the first night after opening has any)
	_menu_change = {}
	if _before_night.has("menu_change"):
		_menu_change = _before_night["menu_change"].duplicate()
		_event("menu_changed", _menu_change)
	_stats.story["date"] = str(_night_date.get("text", ""))
	_stats.story["weather"] = _night_weather
	_stats.story["season"] = _date_words().get_slice(", ", 1)
	if not _cliffhanger.is_empty():
		_stats.story["cliffhanger"] = "%s (%s)" % [_cliffhanger["kind"], ", ".join(PackedStringArray(_cliffhanger["who"].map(func(p): return Names.given_name(str(p)))))]
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
	_cat_next = _camera.cat_stay(randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y))
	_tent_cat.place()
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
	_frame_done.emit()  # (first: whatever's waiting a frame carries on)
	_update_light()
	if _lights_out > 0.0:  # (a plant card: the lights flicker and go out for a moment)
		_lights_out -= delta
		_tent_view.lights_out(int(_lights_out * 8.0) % 3 != 0)  # (stuttering back on)
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
	if _kitchen_part.cook(minutes):
		_update_info()
	# Everyone's stay runs down, even when tests hold the clock.
	for guest in _guests:
		guest.stay_left -= minutes
	if Hooks.strollers:
		_street.tick(minutes, _clock)
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
		_street.walk_past(0.0)
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
		_street.walk_past(gone * 1.5)  # if several give up at once, they don't walk in a clump
		gone += 1
		_update_info()


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
	if str(Game.bar.get("id", "")) == "":  # (the bar's gone: a test tidied it away mid-night, on a slow machine)
		_night_open = false
		return
	# "Will she stay away again?": answered at closing, if she has.
	if not _cliffhanger.is_empty() and not bool(_cliffhanger["answered"]) and _cliffhanger["kind"] == "stays_away" \
			and not _cliffhanger["who"].any(func(person): return _names_tonight.has(person)):
		_cliffhanger["answered"] = true
		_stats.story["cliffhanger_answered"] = true
		_narrate("Last time's cliffhanger, answered: \"%s\" No sign of %s tonight." % [_cliffhanger["teaser"], Names.given_name(str(_cliffhanger["who"][0]))])
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
	_cliffhanger = {}  # (answered or not, it was last time's: the diary has it)
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
		if _closed():
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
		"menu_change": _menu_change.duplicate(),
		"cliffhanger": {} if _cliffhanger.is_empty() else {"teaser": _cliffhanger["teaser"], "kind": _cliffhanger["kind"], "answered": _cliffhanger["answered"]},
	})


## "Previously on…": what the recap's written from (see StoryKeeper.recap_facts).
func _recap_facts() -> Dictionary:
	return StoryKeeper.recap_facts(Game.bar, _owner, _regulars(), _scenery_dice)


## The recap for tonight: the AI's, checked, or the game's own from the same facts.
func _write_recap() -> Dictionary:
	var facts := _recap_facts()
	var reply: Dictionary = await _ai.ask_json(Prompts.recap_messages(facts), _validate_recap.bind(facts), {"temperature": 0.85},
		{"purpose": "recap", "facts": facts, "tries": 2})  # (two goes, then the game's own: it's on the loading screen)
	if _closed():  # (the bar closed while it was waiting)
		return {}
	_before_night["recap_by"] = "game" if reply.is_empty() else "ai"
	if reply.is_empty():
		reply = Story.stitched_recap(facts)
	return reply


func _validate_recap(data: Variant, facts: Dictionary) -> String:
	return Story.validate_recap(data, facts)


## Plays a recap full screen and waits for it to finish (or be skipped).
func _play_recap(recap: Dictionary, opener: bool) -> void:
	var cliff: Dictionary = recap.get("cliffhanger", {})
	_cliffhanger = {} if opener or str(cliff.get("kind", "other")) == "other" else {"kind": cliff["kind"], "who": cliff.get("who", []), "teaser": str(recap.get("teaser", "")), "answered": false}
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


## Every answer from the AI, for the stats: tonight's (and its diary, after), or, while the next
## night's being got ready, kept for its stats, so the menu, the signature dishes and the
## recap's rejected tries are counted too.
func _on_ai_answered(purpose: String, seconds: float, problems: Array, ok: bool) -> void:
	if _getting_ready:
		_setup_ai.append([purpose, seconds, problems.duplicate(), ok])
	else:
		_stats.record_ai(seconds, problems, ok, purpose)


func _on_next_night_pressed() -> void:
	_summary.visible = false
	_story.forget_before()  # (the end of last night, the diary: not tonight's)
	_getting_ready = true
	if Hooks.bar_menus and not Game.bar.get("menu", []).is_empty():
		_owner_working = true
		await _change_menu()  # now and then, something new on the board
		_owner_working = false
		if _closed():
			return
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
		if guest.time_up() and _kitchen_part.food_coming(guest).is_empty():
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
	var base := guest.attended - (3 if guest.company == "owner" else 0)
	if guest.plant_moment != "":
		base -= PdCamera.PULL  # (something's just happened to them: the owner turns to them sooner)
	return _camera.neediness(guest, base)


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


## The stats panel, shown in its tabs (see StatsPanel).
func _update_stats_panel() -> void:
	if _stats_view == null:
		_stats_view = StatsPanel.new(_stats_text, _stats_tabs, ACCENT, MUTED)
	_stats_view.refresh(_stats, _guests.size(), _kitchen.size() + _ready_dishes.size(), _night_number, _here_text)


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


## Adds to the transcript on screen and, during a night, to tonight's transcript file (before
## it, kept for the top of it: see StoryKeeper).
func _show(bbcode: String) -> void:
	_log.append_text(Glossary.explain_hangul(bbcode))  # (any Hangul explains itself on hover)
	_story.record(bbcode)


## Tonight's transcript file, written as the night goes (see StoryKeeper): a header saying which
## bar and night, and with what AI settings, how the bar opened, then everything said and done.
func _start_transcript() -> void:
	var model := " / " + str(_ai.settings.get("model", "")) if not _ai.offline else ""
	var path := _story.start(str(Game.bar.get("id", "bar")), _night_number, [
		"KTBT transcript: %s, night %d" % [Game.bar.get("name", ""), _night_number],
		"%s, %s. Started %s." % [_night_day, _night_weather, Time.get_datetime_string_from_system(false, true)],
		"AI: %s%s (%s), reading pauses %s." % [_ai.settings.get("backend", ""), model, "offline" if _ai.offline else "online",
			"on" if _reading_toggle.button_pressed else "off"],
	])
	_recap_said = ""
	if path != "" and Hooks.print_paths:
		print("Night transcript: ", ProjectSettings.globalize_path(path))


## The end of the night (or the bar closed early): how it ended, and the night's stats.
func _finish_transcript(context: Dictionary) -> void:
	_story.finish(bool(context["finished"]), str(context["clock"]), _stats.panel_text(_guests.size(), _kitchen.size() + _ready_dishes.size()).replace("[b]", "").replace("[/b]", ""))


## Esc opens or closes the Options panel; 1, 2 and 3 pick the edit's spin while it's up.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and not _edit.is_empty() and key.keycode >= KEY_1 and key.keycode <= KEY_3:
		_air_edit(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_options_button.button_pressed = not _options_button.button_pressed


## The panels under the tent: the transcript, the PD's desk, then the side panel (who's here
## now, and the stats).
func _layout_panels() -> void:
	var height := SCREEN.y - PANELS_TOP - 24
	var side_x := SCREEN.x - SIDE_WIDTH - 24
	var desk_x := side_x - 24 - DESK_WIDTH
	_log_panel.size = Vector2(desk_x - 48, height)
	_desk_panel.position = Vector2(desk_x, PANELS_TOP)
	_desk_panel.size = Vector2(DESK_WIDTH, height)
	_stats_panel.position = Vector2(side_x, PANELS_TOP)
	_stats_panel.size = Vector2(SIDE_WIDTH, height)


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
		if _closed():  # (the bar closed while it was waiting)
			return
		look = customer["look"]
		if str(regular.get("id", "")) == _planted_regular:  # (the PD rang them: they know why they're here)
			guest.plant_moment = Plants.moment("regular_in", str(regular["name"]), "", "", str(regular.get("gender", "")))
			guest.plant_card = "regular_in"
			guest.plant_happened = Plants.happened("regular_in", str(regular["name"]), "", "", str(regular.get("gender", "")))
			_planted_regular = ""
			_narrate("(%s)" % guest.plant_happened)
	else:
		_narrate("%s. Someone ducks under the tarp." % guest.arrived)
		customer = _take_prepared()
		if customer.is_empty():
			customer = await _new_customer(guest.arrived)
			if _closed():  # (the bar closed while it was waiting)
				return
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
	guest.node = _people_view.new_person(_stage, Vector2(_random_offscreen_x(), CUSTOMER_Y), guest.color)
	guest.node.name = "Customer%d" % guest.seat
	_people_view.dress(guest.node, look)
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
	if _closed():  # (the bar closed while it was waiting)
		return
	var items: Array = Orders.fallback_order()
	if order.is_empty():
		_narrate("(The AI couldn't come up with a valid order, so the game served %s: %s.)" % [" and ".join(PackedStringArray(items.map(func(id): return str(Menu.find(str(id))["name"]).to_lower()))), _ai.last_error])
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
		_typing_label.text = "The casting team are finding the next customer..."
	var taken: Array = [str(_owner["name"])]  # nobody at the counter shares a name
	for other in _guests:
		taken.append(str(other.customer["name"]))
	var used: Array = _names_tonight.filter(func(n): return not taken.has(n))
	# About one in a hundred is non-binary: the game decides; otherwise the AI chooses.
	var gender := Hooks.gender_override if Hooks.gender_override != "" else People.game_gender(randf())
	var who: Dictionary = await _ai.ask_json(
		Prompts.customer_name_messages(_night_day, arrived, _night_weather, taken, used, gender),
		_validate_customer_name.bind(taken, gender), {"temperature": 1.0}, {"purpose": "customer_name", "taken": taken, "gender": gender})
	if _closed():  # (the bar closed while it was waiting)
		return {}
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
		if _closed():  # (the bar closed while it was waiting)
			return {}
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
		guest.drinks_row.add_child(_kitchen_part.banchan_shape())
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
	_kitchen_part.put_on(guest, later, _clock)
	if not was_backed and _kitchen.size() >= Captions.STOVE_BACKED:
		_event("stove_backed", {"dishes": _kitchen.size()})
	_typing_label.text = ""
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
	var dish: Dictionary = _kitchen_part.take_ready()
	var guest: Guest = dish["guest"]
	var id := str(dish["id"])
	if not _guests.has(guest):
		_carrying = false
		return
	_move_owner(_beside(guest))
	await _pause(_scaled(0.4))
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
	if _closed():
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
	if _camera.is_on(guest):
		_camera_off("left")
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
	guest.topic = Talk.pick_owner_topic(randf(), guest.food_news or not _kitchen_part.food_coming(guest).is_empty(), _cat_here(guest), guest.topic, remembered,
		not guest.customer.get("regular", {}).is_empty(), _late())
	# The cat's just come to them (or it's up to something): the talk turns to it. (Given only as
	# a situation, the AI let it go by every time: 0 of 4 one night.)
	if guest.cat_moment != "" or _owner_cat_moment != "":
		guest.topic = "the_cat"
	_stats.record_topic(guest.topic, false)
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
	_plant_in(guest.transcript, guest)
	var given := Conversation.owner_line(_night, guest, i, _late(), Looks.wet(_weather_kind))  # (what this line's given: see Conversation)
	var direction := str(given["direction"])
	var hint := str(given["hint"])  # what kind of hint this line was given, for the stats
	if bool(given["opener"]):
		_stats.opener_situations += 1
	var speaker := str(_owner["name"]) if owner_speaks else str(guest.customer["name"])
	var alias := str(_owner["title"]) if owner_speaks else ""
	direction = (direction + " " + _address_note(guest) + (" " + Talk.TO_CAMERA if not owner_speaks and guest.to_camera else "")).strip_edges()
	var address := _address(null, guest) if owner_speaks else _address(guest, null)
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := guest.version
		reply = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, owner_speaks, direction, _tent_cat.prompt()),
			_validate_line.bind(speaker, alias, guest.order, [str(_owner["name"]), str(guest.customer["name"])], _tent_cat.fact(), address), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": owner_speaks, "first": i == 0, "last": false})
		if _closed():  # (the bar closed while it was waiting)
			return
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
	_stats.record_hint(hint, str(reply["line"]), _tent_cat.tells())
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
				"The customer is getting up to go: see them off. " + _address_note(guest), _tent_cat.prompt()),
			_validate_line.bind(owner_name, str(_owner["title"]), guest.order, [owner_name, speaker], _tent_cat.fact(), _address(null, guest)), {"temperature": 0.85},
			{"purpose": "line", "title": _owner["title"], "owner_speaks": true, "first": false, "last": false})
		if _closed():  # (the bar closed while it was waiting)
			return
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
		Prompts.dialogue_messages(_owner, guest.customer, guest.moment, _table_text(guest), guest.transcript, false, direction + " " + _address_note(guest), _tent_cat.prompt()),
		_validate_line.bind(speaker, "", guest.order, [owner_name, speaker] + partners, _tent_cat.fact(), _address(guest, null)), {"temperature": 0.85},
		{"purpose": "line", "title": _owner["title"], "owner_speaks": false, "first": false, "last": true})
	_typing_label.text = ""
	if _closed():  # (the bar closed while it was waiting)
		return
	if not reply.is_empty():
		await _say(guest, false, str(reply["line"]))
		guest.line += 1
	for other in (chat.people if chat != null else []):
		if other != guest and _guests.has(other):
			var leaver := _known_as(guest, chat)
			other.transcript.append({"action": "%s, who they were chatting with, says goodbye and leaves." % (leaver.substr(0, 1).to_upper() + leaver.substr(1))})


## How someone in a chat is known to the others (see Conversation.known_as).
func _known_as(guest: Guest, chat: Chat) -> String:
	return Conversation.known_as(guest, chat)


## Who spoke last in a transcript ("" if nobody has).
static func _last_speaker(transcript: Array) -> String:
	return Conversation.last_speaker(transcript)


## The customer orders more partway through. Returns false if the AI couldn't manage it,
## in which case the conversation just carries on with a normal line.
func _extra_order(guest: Guest) -> bool:
	_typing_label.text = "%s is eyeing the menu again..." % guest.customer["name"]
	var extra: Dictionary = await _ai.ask_json(
		Prompts.extra_order_messages(_owner, guest.customer, guest.moment, Menu.prompt_list(Menu.shuffled_ids(), _specials), guest.transcript, _table_text(guest)),
		_validate_extra_order.bind(guest.order.duplicate()), {"temperature": 0.7},
		{"purpose": "extra_order", "title": _owner["title"], "table": guest.order.duplicate()})
	_typing_label.text = ""
	if _closed():  # (the bar closed while it was waiting)
		return false
	if extra.is_empty():
		return false
	var items: Array = extra["items"]
	_stats.sides_added += int(extra.get("added_sides", 0))
	await _say(guest, false, str(extra["line"]))
	guest.order.append_array(items)
	_serve(guest, items, false)
	return true


# --- Customers chatting to each other -------------------------------------------

## Someone who can be drawn into a chat right now (see CounterChats.can_chat).
func _can_chat(guest: Guest) -> bool:
	return _counter_chats.can_chat(guest)


func _chat_of(guest: Guest) -> Chat:
	return _counter_chats.chat_of(guest)


## People free to start a new chat, or join one.
func _free_to_chat() -> Array:
	return _counter_chats.free_to_chat(_guests)


## The customers in a chat who can still take part.
func _chat_voices(chat: Chat) -> Array:
	return _counter_chats.voices(chat)


func _chat_possible() -> bool:
	return _counter_chats.possible(_guests, _last_orders)


func _leave_chats(guest: Guest) -> void:
	_counter_chats.leave(guest)


## A spell of customers chatting: carry on a chat already going (sometimes someone else
## joins in), or two strangers get talking. Sometimes the owner leans over and joins in.
## A few lines, cut short if something more urgent comes up.
func _counter_chat() -> void:
	_owner_working = true
	var spell := _counter_chats.choose_spell(_guests, _camera, _plant_waiting())  # (carry one on, someone joining in, or strangers getting talking)
	var chat: Chat = spell["chat"]
	var joiner: Guest = spell["joiner"]
	if chat != null and bool(spell["started"]):
		var a: Guest = chat.people[0]
		var b: Guest = chat.people[1]
		_narrate("%s gets talking to %s." % [a.customer["name"], b.customer["name"]])
		_event("chat_started", {"name": str(a.customer["name"]), "friend": str(b.customer["name"])}, a.node)
		chat.transcript.append({"action": "%s turns to %s, a stranger a few stools along, and starts a conversation." % [a.customer["name"], b.customer["name"]]})
	elif chat != null:
		_event("chat_continued", {"people": chat.people.filter(func(g): return g != joiner).map(func(g): return str(g.customer["name"]))})
		if joiner != null:
			_narrate("%s joins in." % joiner.customer["name"])
			_event("joined_chat", {"gender": str(joiner.customer.get("gender", "")), "name": str(joiner.customer["name"])}, joiner.node)
			chat.transcript.append({"action": "%s, from further along the counter, joins the conversation." % joiner.customer["name"]})
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
	chat.topic = Talk.pick_chat_topic(randf(), cat_with_them, chat.topic, _all_close(chat.people), _late())
	if chat.people.any(func(g): return g.cat_moment != "") or (chat.owner_in and _owner_cat_moment != ""):
		chat.topic = "the_cat"  # (the cat's just come to one of them: see _talk)
	_stats.record_topic(chat.topic, true)
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
		# Something's just happened to one of them (a PD's plant card): they speak next.
		var happened_to: Array = voices.filter(func(v): return v != chat.last_speaker and _guest_named(v) != null and _guest_named(v).plant_moment != "")
		if not happened_to.is_empty():
			speaker = happened_to[0]
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
	var owner_speaks := speaker == owner_name
	var speaking: Guest = _guest_named(speaker)
	var listening: Guest = _guest_named(addressee)
	var both := speaking != null and listening != null
	# Two regulars who've got to know each other: is it time for "can I call you eonni?"
	var moment_term := _friendly_moment(speaking, listening)
	var close := moment_term != "" or (both and _close(speaking, listening))
	var fewest := 99
	for drinker in chat.people:
		fewest = mini(fewest, _drinks_had(drinker))
	var food := [_served_of(speaking, "food") if speaking != null else 0, _served_of(listening, "food") if listening != null else 0,
		both and _served_of(speaking, "drink") > 0 and _served_of(listening, "drink") > 0]
	if listening == null:
		food[0] = 0  # (sharing's between two customers)
	if speaking != null:
		_plant_in(chat.transcript, speaking)
	var given := Conversation.chat_line(_night, chat, speaker, addressee, first, speaking, owner_speaks, close, moment_term,
		both and not _friend(speaking, listening).is_empty(), food, fewest, _clock >= Talk.TABLE_GAME_FROM, _scenery_dice)  # (what this line's given: see Conversation)
	var direction := str(given["direction"])
	var hint := str(given["hint"])  # what kind of hint this line was given, for the stats
	if str(given["game"]) != "":
		# The makings of a game, there at the table (shown, and in the chat as something that happened).
		var scene := str(Talk.TABLE_GAMES[str(given["game"])]["scene"])
		_narrate(scene)
		chat.transcript.append({"action": scene})
		_event("table_game_offered", {"game": str(given["game"]), "name": speaker})
	direction += " " + _chat_notes(chat) + " " + (Talk.TO_CAMERA if speaking != null and speaking.to_camera else Address.address_text(speaker, _addressee(speaking), addressee, _addressee(listening), close))
	var address := _address(speaking, listening, close)
	_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
	var reply := {}
	for attempt in 2:
		var version := _chat_version(chat)
		tables = chat.people.map(func(person): return _table_text(person))
		reply = await _ai.ask_json(
			Prompts.counter_chat_messages(_owner, chat.owner_in, people, tables, moment, chat.transcript, speaker, addressee, direction, _tent_cat.prompt()),
			_validate_line.bind(speaker, str(_owner["title"]) if owner_speaks else "", items, names, _tent_cat.fact(), address), {"temperature": 0.85},
			{"purpose": "chat_line", "owner_speaks": owner_speaks, "first": first})
		if _closed():  # (the bar closed while it was waiting)
			return ""
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
	if _closed():  # (the bar closed while it was waiting)
		return ""
	chat.transcript.append({"speaker": speaker, "text": line})
	chat.last_speaker = speaker
	_stats.chat_lines += 1
	_stats.record_camera_line(_camera.on_camera(chat.people))
	_stats.record_written_line(speaker, chat.people.map(func(g): return str(g.customer["name"])), line)
	_stats.record_hint(hint, line, _tent_cat.tells())
	_stats.record_line(line, names)
	if guest != null:
		_night_lines.append({"speaker": speaker, "text": line})
	if guest != null and guest.to_camera:  # (the PD's interview cut: straight to camera)
		guest.to_camera = false
		_show_to_camera(guest, line)
	else:
		_show("[color=#%s][b]%s to %s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(to), Glossary.explain(_esc(line), names)])
	_cheer_along(guest, line, names)
	_table_game_taken(chat, guest, line)
	_mind_your_elders(guest, addressed)
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
	return _counter_chats.version(chat)


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
	_cat_next = _camera.cat_stay(randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y))
	var cat_name := str(_cat["name"])
	var was_out := _cat_node.visible == false
	if before != null and before != with and _guests.has(before):
		before.transcript.append({"action": "%s jumps down and wanders off." % cat_name})
		before.version += 1
	var text := CatRules.cat_move_text(cat_name, spot, _tent_cat.with_name())
	# Moves that matter (with a customer, leaving them, going out or coming in) are always
	# narrated; just pottering about only sometimes.
	if with != null or before != null or spot == "street" or was_out or randf() < CAT_POTTER_NARRATED:
		_narrate(text)
	if with != null:
		with.transcript.append({"action": text})
		with.version += 1
	_tent_cat.place()
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


## What's on a guest's table, as the AI is told it, including what's still cooking.
func _table_text(guest: Guest) -> String:
	return Orders.table_text(guest.served, _kitchen_part.food_coming(guest), BANCHAN)


# --- The stove ---------------------------------------------------------------


# --- Things happening in the scene -----------------------------------------

## Walking in and out runs by itself: nobody waits for it. In the rain or snow they come in
## under an umbrella (or running for it, with no umbrella), the same as anyone in the street,
## and put it down under the tarp.
func _walk_in(guest: Guest) -> void:
	_people_view.turn(guest.node, true)
	var stool_x: float = SEAT_X[guest.seat] - PERSON_WIDTH / 2
	guest.rain_gear = _street.pick_rain_gear()
	_street.gear_up(guest.node, guest.rain_gear, guest.node.position.x < stool_x)
	if not guest.rain_gear.is_empty():
		_stats.record_street("customers in under an umbrella" if bool(guest.rain_gear["umbrella"]) else "customers running in")
	guest.walk = create_tween()
	guest.walk.tween_property(guest.node, "position:x", stool_x, _scaled(1.1 if _people_view.is_running(guest.node) else 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	guest.walk.tween_callback(_people_view.gear_down.bind(guest.node))  # under the tarp
	guest.walk.tween_callback(_people_view.turn.bind(guest.node, false))  # sat down: facing the counter


## ...and back out: the umbrella goes up again (or, if it's started raining since, whatever
## the dice say).
func _walk_out(guest: Guest) -> void:
	if guest.walk != null and guest.walk.is_valid():
		guest.walk.kill()  # if they hadn't quite sat down yet
	_people_view.gear_down(guest.node)  # (if they hadn't put it down yet)
	_people_view.turn(guest.node, true)  # up, and turning to go
	# ...and leave in whichever direction they're heading home, at random.
	var away := _random_offscreen_x()
	var gear: Dictionary = {}
	if Looks.wet(_weather_kind):
		gear = guest.rain_gear if not guest.rain_gear.is_empty() else _street.pick_rain_gear()
	_stop_swaying(guest.node)
	_street.gear_up(guest.node, gear, guest.node.position.x < away, guest.rain_gear.is_empty())  # (counted only if it's new)
	# A few drinks in, they wobble home (slower, zigzagging), unless they're running for it.
	var wobbly := _drinks_had(guest) >= TIPSY_DRINKS and not _people_view.is_running(guest.node)
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
	guest.walk.tween_property(guest.node, "position:x", away, _scaled(1.0 if _people_view.is_running(guest.node) else (2.2 if wobbly else 1.4))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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


func _move_owner(x: float) -> void:
	if _owner_tween != null and _owner_tween.is_valid():
		_owner_tween.kill()  # wherever they were heading, this comes first
	_owner_tween = create_tween()
	_owner_tween.tween_property(_owner_node, "position:x", x, _scaled(0.4)).set_trans(Tween.TRANS_SINE)


func _random_offscreen_x() -> float:
	return OFFSCREEN_LEFT_X if randi() % 2 == 0 else OFFSCREEN_RIGHT_X


## A colour nobody at the counter is wearing.
func _free_color() -> Color:
	var free := PeopleView.CUSTOMER_COLORS.duplicate()
	for guest in _guests:
		free.erase(guest.color)
	return free.pick_random() if not free.is_empty() else PeopleView.CUSTOMER_COLORS.pick_random()


## Drinks go to the left of the customer, food to the right.
func _add_dish(guest: Guest, id: String) -> void:
	var row := guest.drinks_row if Menu.find(id)["kind"] == "drink" else guest.food_row
	var shape := _kitchen_part.dish_shape(id)
	row.add_child(shape)
	if id == "soju":
		_tornado(shape)
	if Menu.find(id)["kind"] == "drink" and not guest.kya_done:
		_kya(guest)
	if Scenery.HOT_DISHES.has(id) or ["stew", "pancake", "grill", "fried"].has(str(Catalogue.find(id).get("category", ""))):
		_scenery.steam(shape)


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
	_stats.record_written_line(str(_owner["name"]) if owner_speaks else str(guest.customer["name"]), [str(guest.customer["name"])], text)
	_stats.record_camera_line(_camera.on_camera([guest]))
	if not owner_speaks:
		_night_lines.append({"speaker": str(guest.customer["name"]), "text": text})
	if not owner_speaks and guest.to_camera:  # (the PD's interview cut: straight to camera)
		guest.to_camera = false
		_show_to_camera(guest, text)
	else:
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
	# Offline, the pre-written lines come back in a frame, so they always get time to be read:
	# with reading pauses off, a night that went offline ran 2,991 lines in 37 seconds.
	if not _reading_toggle.button_pressed and not _ai.offline:
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
	fill = fill.duplicate()
	if not fill.has("owner") and not _owner.is_empty():
		fill["owner"] = _owner["name"]
	if not fill.has("seated"):
		fill["seated"] = _guests.size()
	if not fill.has("cat") and not _cat.is_empty():
		fill["cat"] = _cat["name"]
	if _weather_kind in ["drizzle", "rain"]:
		fill["weather"] = "rain"
	_captions_part.show_caption(kind, fill, about, spot)


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
	if not _captions_part.reaction_ready():
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
	_captions_part.reaction_shown()  # (routine captions wait while it's up, and their usual gap after)
	# The PD's edit: a moment to pick its spin (the AI's own, the flip, or a roast); none
	# picked, the AI's goes out. Never pauses anything: the night runs on meanwhile.
	var spins: Array = [{"mood": mood, "caption": str(reply["caption"])}]
	if str(reply.get("flip_caption", "")) != "" and Captions.FLIPS.has(mood):
		spins.append({"mood": str(Captions.FLIPS[mood]), "caption": str(reply["flip_caption"])})
	if str(reply.get("roast_caption", "")) != "":
		spins.append({"mood": "roast", "caption": str(reply["roast_caption"])})
	var roll := randf()  # (the caption's Hangul: the game's dice, as ever)
	if spins.size() > 1 and _desk != null:
		_offer_edit(spins, reply, lines, names, roll)
	else:
		_air_moment(0, [spins[0]], reply, lines, names, roll)


## The PD's edit, on the desk: the spins as buttons (1, 2, 3), a bar running down, and whichever's
## picked (or the AI's, when time's up) goes out.
func _offer_edit(spins: Array, reply: Dictionary, lines: Array, names: Array, roll: float) -> void:
	if not _edit.is_empty():
		_air_edit(0)  # (an earlier one still up: the AI's goes out, and this one takes its place)
	_edit = {"spins": spins, "reply": reply, "lines": lines, "names": names, "roll": roll}
	_stats.edits_offered += 1
	_stats.edit_log.append({"spins": spins.duplicate(true), "aired": 0})
	for old in _edit_buttons.get_children():
		_edit_buttons.remove_child(old)
		old.queue_free()
	for k in spins.size():
		var spin: Dictionary = spins[k]
		var data: Dictionary = Captions.REACTIONS[str(spin["mood"])]
		var button := Button.new()
		button.name = "Edit_%d" % (k + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d  %s  %s" % [k + 1, str(spin["mood"]).to_upper(), spin["caption"]]
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(str(data["colour"])))
		button.tooltip_text = Text.tip("%s%s: %s" % ["The AI's pick, " if k == 0 else "", str(spin["mood"]), data["means"]])
		button.pressed.connect(_air_edit.bind(k))
		_edit_buttons.add_child(button)
	_edit_box.visible = true
	_edit_bar.value = 100.0
	var seconds := _scaled(Captions.EDIT_SECONDS)
	_edit_tween = _edit_bar.create_tween()
	_edit_tween.tween_property(_edit_bar, "value", 0.0, seconds)
	var token: Dictionary = _edit
	_timer(seconds).timeout.connect(func():
		if _edit == token:
			_air_edit(0))  # (time's up: the AI's own)


## The PD picked spin k (0: the AI's own, or time ran out): it goes out.
func _air_edit(k: int) -> void:
	if _edit.is_empty():
		return
	var pending := _edit
	_edit = {}
	_edit_box.visible = false
	if _edit_tween != null:
		_edit_tween.kill()
	var spins: Array = pending["spins"]
	k = clampi(k, 0, spins.size() - 1)
	if not _stats.edit_log.is_empty():
		_stats.edit_log[-1]["aired"] = k
	if k > 0:
		var change := "%s→%s" % [spins[0]["mood"], spins[k]["mood"]]
		_stats.edits_made[change] = int(_stats.edits_made.get(change, 0)) + 1
	_air_moment(k, spins, pending["reply"], pending["lines"], pending["names"], float(pending["roll"]))


## A big moment goes out: its event (the mood the AI judged, for the diary, and what aired), the
## caption over whoever it's about, and a shock's double-take.
func _air_moment(k: int, spins: Array, reply: Dictionary, lines: Array, names: Array, roll: float) -> void:
	if _stopped:
		return
	var mood := str(spins[k]["mood"])
	var caption := str(spins[k]["caption"])
	var who := str(reply["who"])
	var theirs: Array = lines.filter(func(e): return str(e.get("speaker", "")) == who)
	_event("big_moment", {"who": who, "mood": mood, "ai_mood": str(spins[0]["mood"]), "edited": k > 0, "caption": caption,
		"said": str(theirs[-1]["text"]) if not theirs.is_empty() else ""})  # (its caption's popped here, below: the AI's words)
	var about: Variant = _owner_node  # (untyped: someone's node may be gone by now)
	if who != str(_owner["name"]):
		var guest: Guest = _guest_named(who)
		about = guest.node if guest != null else null
	if mood == "shock":
		_stun_listeners(who, names)
	var data: Dictionary = Captions.REACTIONS[mood]
	_captions_part.pop(Captions.reaction_words(mood, caption, roll), str(data["icon"]), str(data["colour"]), str(data["sound"]), false, about, Vector2(-1, -1), Captions.REACTION_SECONDS)


## The door: as someone ducks in, the owner calls out to them, polite for a stranger and casual
## for an old friend (Talk.door_welcome): a quick bubble and a line in the transcript, and
## their conversation knows they've been welcomed.
func _welcome_at_door(guest: Guest) -> void:
	var mark := Regulars.closeness_mark(guest.customer.get("regular", {}))
	var welcome := Talk.door_welcome(mark)
	if mark != "" or _scenery_dice.randf() < Talk.DOOR_WELCOME_WRITTEN:  # (scenery's dice: the game's rolls don't shift)
		_narrate("\"%s\" %s calls out%s." % [welcome, _owner_display(), " from the stove" if not _kitchen.is_empty() else ""])
	_say_in_bubble(_owner_node, guest.node, "", guest.color.lightened(0.35), OWNER_TEXT, welcome)
	guest.transcript.append({"action": "%s called out \"%s\" as they came in." % [_owner["name"], welcome]})


## And on the way out: their thanks now and then (잘 먹었습니다!), and the owner's goodbye.
func _goodbye_at_door(guest: Guest) -> void:
	var goodbye := Talk.door_goodbye(Regulars.closeness_mark(guest.customer.get("regular", {})))
	if _scenery_dice.randf() < Talk.DOOR_THANKS_CHANCE:  # (scenery's dice: the game's rolls don't shift)
		_say_in_bubble(guest.node, _owner_node, "", OWNER_TEXT, guest.color.lightened(0.35), Talk.DOOR_THANKS)
		_narrate("\"%s\" says %s. \"%s\" says %s." % [Talk.DOOR_THANKS, Names.given_name(str(guest.customer["name"])), goodbye, _owner_display()])
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


## A table game offered to a chat, taken up in a line (its tells): on TV, and for the spoon mic,
## a spoon in the bottle and music notes over the singer.
func _table_game_taken(chat: Chat, speaker: Variant, line: String) -> void:
	if chat.game == "" or chat.game_on or not Talk.hint_taken("game_" + chat.game, line):
		return
	chat.game_on = true
	var node: Variant = _owner_node if speaker == null else speaker.node
	_event("table_game", {"game": chat.game}, node)
	if chat.game == "spoon_mic" and speaker != null:
		_spoon_mic(speaker)


func _spoon_mic(guest: Guest) -> void:
	if guest.drinks_row.get_child_count() > 0:  # (in the bottle: the row lays out its children itself)
		_rect(guest.drinks_row.get_child(0) as Control, Vector2(5, -14), Vector2(3, 16), Color("c9ccd6")).name = "SpoonMic"
	for k in 3:
		var note := Ktv.label("♪", 18, Ktv.PINK)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.position = Vector2(30 + k * 14, -10)
		note.modulate.a = 0.0
		if is_instance_valid(guest.node):
			guest.node.add_child(note)
		var rise := note.create_tween()
		rise.tween_interval(k * 0.4)
		rise.tween_property(note, "modulate:a", 1.0, 0.2)
		rise.parallel().tween_property(note, "position:y", -50.0, 1.6)
		rise.tween_property(note, "modulate:a", 0.0, 0.4)
		rise.tween_callback(note.queue_free)


## Turning away to drink, in front of someone much older (manners): now and then, once a night
## each, as a younger customer talks to an elder. listener: who they're talking to (null: the owner).
func _mind_your_elders(guest: Variant, listener: Variant) -> void:
	if guest == null or guest.turned_away or _drinks_had(guest) == 0 or not is_instance_valid(guest.node):
		return
	var elder_age := int(_owner.get("age", 0)) if listener == null else int(listener.customer.get("age", 0))
	if elder_age - int(guest.customer.get("age", 0)) < Talk.ELDER_YEARS or _scenery_dice.randf() >= Talk.TURN_AWAY_CHANCE:
		return
	guest.turned_away = true
	_stats.rituals["turned_away"] = int(_stats.rituals.get("turned_away", 0)) + 1
	_narrate("%s turns away to drink, the way you do in front of someone older." % Names.given_name(str(guest.customer["name"])))
	var node: Control = guest.node
	var turn := node.create_tween()
	turn.tween_property(node, "rotation_degrees", -7.0, 0.25)
	turn.tween_interval(_scaled(1.2))
	turn.tween_property(node, "rotation_degrees", 0.0, 0.3)


## A new bottle of soju: the tornado (회오리), swirled hard before it's opened.
func _tornado(shape: Control) -> void:
	_stats.rituals["tornado"] = int(_stats.rituals.get("tornado", 0)) + 1
	shape.pivot_offset = Vector2(7, 30)
	var swirl := shape.create_tween()
	for k in 3:
		swirl.tween_property(shape, "rotation_degrees", 14.0, 0.09)
		swirl.tween_property(shape, "rotation_degrees", -14.0, 0.12)
	swirl.tween_property(shape, "rotation_degrees", 0.0, 0.1)


## "Kya~!": the sigh after the first drink of someone's night (now and then), a moment after it arrives.
func _kya(guest: Guest) -> void:
	guest.kya_done = true
	if _scenery_dice.randf() >= Talk.KYA_CHANCE:
		return
	_stats.rituals["kya"] = int(_stats.rituals.get("kya", 0)) + 1
	var timer := _timer(_scaled(1.6))
	timer.timeout.connect(func():
		if _guests.has(guest) and is_instance_valid(guest.node):
			_say_in_bubble(guest.node, null, "", OWNER_TEXT, guest.color.lightened(0.35), "Kya~!")
			if _scenery_dice.randf() < 0.3:  # (now and then in the transcript too: it's mostly a bubble)
				_narrate("\"Kya~!\" %s sighs over the first glass." % Names.given_name(str(guest.customer["name"]))))


## Last time's cliffhanger, watched for all night: the event that answers it (Story.cliffhanger_answered)
## is the biggest moment a night can have, on TV with the red light and the siren.
func _watch_cliffhanger(kind: String, facts: Dictionary, about: Variant, _spot: Vector2) -> void:
	if _cliffhanger.is_empty() or bool(_cliffhanger["answered"]) or not Story.cliffhanger_answered(_cliffhanger, kind, facts):
		return
	_cliffhanger["answered"] = true
	_stats.story["cliffhanger_answered"] = true
	var who: Array = _cliffhanger["who"]
	_narrate("Last time's cliffhanger, answered: \"%s\"" % _cliffhanger["teaser"])
	for person in who:
		var guest: Guest = _guest_named(str(person))
		if guest != null:
			guest.transcript.append({"action": "Everyone's been wondering about this since last time (\"%s\"), and here it is." % _cliffhanger["teaser"]})
	_event("cliffhanger_answered", {"kind": _cliffhanger["kind"], "cliffhanger": _cliffhanger["kind"], "name": str(who[0]) if not who.is_empty() else ""}, about)


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
		await _pause(_scaled(Talk.page_seconds(page)))
	# Left up a while after the last page (dimmed once someone else speaks), then it fades.
	await _pause(_scaled(6.0))
	if is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
		var fade := bubble.create_tween()
		fade.tween_property(bubble, "modulate:a", 0.0, 0.6)
		fade.tween_callback(bubble.queue_free)


func _wait_for_reader() -> void:
	while Time.get_ticks_msec() < _read_until:
		await _frame_done


## Whether the bar's closed (or gone): anything that waited (on the AI, a pause, the reader)
## checks this before carrying on, and stops if so.
func _closed() -> bool:
	return _stopped or Game.bar.is_empty()


## A pause that belongs to the tent: if the tent goes (the bar's closed and the scene's
## freed), so does the wait, rather than coming back to a scene that's gone.
func _pause(seconds: float) -> void:
	await _timer(seconds).timeout


## A one-off timer that belongs to the tent (see _pause): connect to its timeout.
func _timer(seconds: float) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()
	return timer


func _scaled(seconds: float) -> float:
	if Hooks.pause_scale_override >= 0.0:
		return seconds * Hooks.pause_scale_override
	return seconds


# --- Small helpers -----------------------------------------------------------

func _owner_display() -> String:
	if _owner.is_empty():
		return "The owner"
	return "%s (%s)" % [_owner["name"], _owner["title"]]


## Gender symbols for names on screen (name tags, who's speaking, who's here now), since
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
## knows (the same as who's here now), kept up to date. An invisible area over their body
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
		area.gui_input.connect(_on_guest_clicked.bind(guest))
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
	var coming := _kitchen_part.food_coming(guest)
	if not coming.is_empty():
		lines.append("Cooking: %s" % Orders.item_names(coming))
	if _drinks_had(guest) >= TIPSY_DRINKS:
		lines.append("A bit tipsy (%d drinks)" % _drinks_had(guest))
	if _cat_with == guest:
		lines.append("%s is %s" % [_cat["name"], {"lap": "on their lap", "feet": "round their ankles", "food": "eyeing their food"}.get(_cat_spot, "with them")])
	var remembered := _remembered_briefly(known)
	if remembered != "":
		lines.append("The owner remembers: %s" % remembered)
	lines.append("● The camera's on them: click to stop" if _camera.is_on(guest) else "Click to follow them with the camera")
	# (Tooltips don't wrap: a long mood or memory would stretch it across the screen.)
	return "\n".join(PackedStringArray(Array(lines).map(func(each): return Text.wrap(str(each), HOVER_WIDTH))))


const HOVER_WIDTH := 44  # characters per line in a customer's hover


# --- The PD's camera ------------------------------------------------------------------------

## Clicking a customer: the camera follows them (or, if it already is, stops). Never pauses
## anything: it changes who gets the airtime from the next turn on (see bar/camera.gd).
func _on_guest_clicked(event: InputEvent, guest: Guest) -> void:
	if not _left_click(event) or not _guests.has(guest):
		return
	if _camera.is_on(guest):
		_camera_off("pd")
	else:
		_camera_on(guest)


## Clicking the cat: the camera follows it (the airtime goes to whoever it's with).
func _on_cat_clicked(event: InputEvent) -> void:
	if not _left_click(event) or _cat.is_empty():
		return
	if _camera.on_cat:
		_camera_off("pd")
	else:
		_camera_on(null)


func _left_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


## The camera turns to someone (null: the cat).
func _camera_on(guest: Guest) -> void:
	var previous: Variant = _camera.follow(guest) if guest != null else _camera.follow_cat()
	_viewfinder_off(previous)
	var named := str(guest.customer["name"]) if guest != null else str(_cat["name"])
	if guest != null:
		_viewfinder(guest.node, Rect2(-4, -8, 88, 166))
		_plant_in(guest.transcript, guest)  # (they've noticed: it's in their conversation)
		_narrate("The camera follows %s." % named)
	else:
		_viewfinder(_cat_node, Rect2(-6, -6, 58, 40))
		_cat_next *= PdCamera.CAT_RESTLESS
		_narrate("The camera follows %s, the cat." % named)
	_event("camera_on", {"name": named, "cat": guest == null, "from": _camera_name(previous),
		"noticing": guest != null and guest.camera_moment != ""}, guest.node if guest != null else _cat_node)
	_show_camera()


## why: "pd" (the player stopped it) or "left" (they went home).
func _camera_off(why: String) -> void:
	var was: Variant = _camera.stop()
	if was == null:
		return
	_viewfinder_off(was)
	if why == "pd":
		_narrate("The camera stops following %s." % _camera_name(was))
	_event("camera_off", {"name": _camera_name(was), "why": why}, _cat_node if str(was) == "cat" else was.node)
	_show_camera()


## A Guest's name, the cat's ("cat"), or "".
func _camera_name(who: Variant) -> String:
	if who == null:
		return ""
	if who is String:
		return str(_cat.get("name", "the cat"))
	return str(who.customer["name"])


## The corner's "● REC" and who, and the hovers saying what a click does.
func _show_camera() -> void:
	if _camera_rec != null:
		var who := ""
		if _camera.on_cat:
			who = "%s (the cat)" % _cat.get("name", "")
			_camera_rec.tooltip_text = _cat_tooltip()
		elif _camera.following != null:
			who = str(_camera.following.customer["name"])
			_camera_rec.tooltip_text = Text.tip("The show's camera is following %s. Click them to stop." % who)
		_camera_rec.text = "● REC  %s" % who
		_camera_rec.visible = who != ""
	for guest in _guests:
		_update_hover(guest)
	_update_desk()
	if not _cat.is_empty() and _tent_cat != null and _tent_cat.node != null:
		_cat_node.tooltip_text = _cat_tooltip()


## What a PD is, on the desk's title's hover.
const PD_MEANS := "PD: the producer-director, who makes a Korean TV show: picks whose story the camera follows, and sets things up to see what happens. That's you: the tent runs itself, and nothing you do here pauses it."


## The PD's desk: who the camera's on, and how to use it.
func _update_desk() -> void:
	if _desk == null:
		return
	var accent := ACCENT.to_html(false)
	var muted := MUTED.to_html(false)
	var t := "[color=#%s][b]%s[/b][/color]\n\n" % [accent, Text.hint(PD_MEANS, "PD CONTROLS")]
	t += "[b]Camera[/b]\n"
	if _camera.on_cat:
		var with: Variant = _camera.subject()
		t += "[color=#%s]● REC[/color] %s, the cat%s\n" % [CAMERA_RED.to_html(false), _esc(_cat.get("name", "")),
			(", with %s" % _esc(with.customer["name"])) if with != null else ", on its own"]
	elif _camera.following != null:
		t += "[color=#%s]● REC[/color] %s\n" % [CAMERA_RED.to_html(false), _esc(_camera.following.customer["name"])]
	else:
		t += "[color=#%s]Not on anyone.[/color]\n" % muted
	t += "[color=#%s]Click someone at the counter, or the cat, to follow them: their story gets the airtime. Click again to stop.[/color]\n" % muted
	t += "\n[b]Plants[/b]  [color=#%s]tonight's cards: play one, and see what comes of it[/color]" % muted
	_desk.text = Glossary.explain_hangul(t)
	_update_plant_cards()


# --- The PD's plant cards -------------------------------------------------------------------

## Tonight's cards on the desk: one button each, greyed out once played or while they can't be,
## the hover saying what it does, who it's for, and why not.
func _update_plant_cards() -> void:
	if _plant_cards == null:
		return
	var names := ",".join(PackedStringArray(_hand))
	if str(_plant_cards.get_meta("hand", "")) != names:
		_plant_cards.set_meta("hand", names)
		for old in _plant_cards.get_children():
			_plant_cards.remove_child(old)
			old.queue_free()
		for card in _hand:
			var button := Button.new()
			button.name = "Plant_" + str(card)
			button.focus_mode = Control.FOCUS_NONE
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 17)
			button.pressed.connect(_on_plant_pressed.bind(str(card)))
			_style_card(button, Plants.kind_of(str(card)))
			_plant_cards.add_child(button)
	var now := _plant_now()
	for button in _plant_cards.get_children():
		var card := str(button.name).trim_prefix("Plant_")
		var played := _played.has(card)
		var why := Plants.why_not(card, now)
		if why == "" and ["someone", "pair"].has(str(Plants.CARDS[card]["for"])) and _card_target(card).is_empty():
			why = "Nobody at the counter with time left for it."
		button.text = "%s%s" % [Plants.CARDS[card]["title"], "  (played)" if played else ""]  # (its tag says what kind)
		button.disabled = played or why != ""
		var tip := str(Plants.KINDS[Plants.kind_of(card)]["about"]) + "\n" + str(Plants.CARDS[card]["about"])
		var tag := button.get_node_or_null("Kind") as Label
		if tag != null:
			tag.modulate.a = 0.45 if button.disabled else 1.0
		if played:
			tip += "\nPlayed tonight."
		elif why != "":
			tip += "\n" + why
		else:
			tip += _aim_text(card)
			var aimed := _card_target(card)
			var from := _write_from(card, aimed[0] if not aimed.is_empty() else null)
			if from != "":
				tip += "\n(" + from + ")"
		button.tooltip_text = Text.tip(tip)


## A card's look on the desk, by its kind: a stripe down its side and a tag (EVENT, WRITE-IN,
## SPONSOR), in the kind's colour.
func _style_card(button: Button, kind: String) -> void:
	var colour: Color = PLANT_KIND_COLOURS[kind]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Ktv.PANEL.lightened(0.12 if state == "hover" else (0.02 if state == "disabled" else 0.06))
		box.border_color = colour if state != "disabled" else colour.darkened(0.5)
		box.border_width_left = 6
		box.set_corner_radius_all(4)
		box.content_margin_left = 14
		box.content_margin_right = 118
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, box)
	var tag := Ktv.label(str(Plants.KINDS[kind]["tag"]), 12, Ktv.INK)
	tag.name = "Kind"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_stylebox_override("normal", _badge(colour))
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.anchor_top = 0.5
	tag.anchor_bottom = 0.5
	tag.offset_left = -106
	tag.offset_right = -8
	tag.offset_top = -13
	tag.offset_bottom = 13
	button.add_child(tag)


## Who a card would happen to, for its hover: "→ Kim Ji-ho (the camera's on them)".
func _aim_text(card: String) -> String:
	var aimed := _card_target(card)
	if aimed.is_empty():
		return ""
	var named := " and ".join(PackedStringArray(aimed.map(func(g): return str(g.customer["name"]))))
	var on_camera: bool = _camera.subject() == aimed[0]
	var leaving: bool = not on_camera and _camera.subject() != null and _guests.has(_camera.subject())
	return "\n→ %s (%s)" % [named, "the camera's on them" if on_camera else ("picked: whoever the camera's on is about to go" if leaving else "picked: follow someone with the camera to choose")]


## What the deal needs to know about tonight (see Plants.dealable).
func _plant_tonight() -> Dictionary:
	var winter := Seasons.winter_number(int(Game.bar.get("first_date", 0)), _night_number)
	return {"winter": str(_night_date.get("season", "")) == "winter", "snowed": int(Game.bar.get("snowed_winter", -1)) == winter,
		"wet": ["rain", "drizzle", "snow"].has(NightRules.weather_kind(_night_weather))}


## What the cards need to know about right now (see Plants.why_not).
func _plant_now() -> Dictionary:
	return {"open": _night_open and not _closing_early and not _last_orders, "seated": _guests.size(), "online": not _ai.offline or Hooks.write_ins_offline,
		"pairable": _guests.any(func(g): return _pair_ok(g)),
		"regulars_away": _regulars_away().size(), "weather_kind": _weather_kind}


## Who a card happens to: [] for the tent's and nobody's; [someone] (whoever the camera's on,
## or someone the game picks and keeps to); a pair: [them, who they're chatting with].
func _card_target(card: String) -> Array:
	var kind := str(Plants.CARDS[card]["for"])
	if kind != "someone" and kind != "pair" or _guests.is_empty():
		return []
	var fits := func(g): return _guests.has(g) and g.stay_left >= PLANT_STAY_LEFT and (kind == "someone" or _pair_partner(g) != null)  # (not someone about to go)
	var who: Variant = _camera.subject()
	if who == null or not fits.call(who):
		who = _picked.get(card)
		if who == null or not fits.call(who):
			var choices: Array = _guests.filter(func(g): return fits.call(g))
			if choices.is_empty():
				return []
			who = choices[_plant_dice.randi_range(0, choices.size() - 1)]
			_picked[card] = who
	return [who] if kind == "someone" else [who, _pair_partner(who)]


## Who a pair's card would pair someone with, or null: who they're chatting with, or (if
## they're not chatting) someone free to get talking; both with time left (not a chat that's
## about to break up).
func _pair_partner(guest: Variant) -> Variant:
	if not _can_chat(guest) or guest.stay_left < PLANT_STAY_LEFT:
		return null
	var partner: Variant = _chat_partner(guest)
	if _chat_of(guest) != null:
		return partner if partner != null and partner.stay_left >= PLANT_STAY_LEFT else null
	var free: Array = _free_to_chat().filter(func(g): return g != guest and g.stay_left >= PLANT_STAY_LEFT)
	free.sort_custom(func(a, b): return a.seat < b.seat)
	return free[0] if not free.is_empty() else null


func _pair_ok(guest: Variant) -> bool:
	return _pair_partner(guest) != null


## Someone they're chatting with at the counter, or null.
func _chat_partner(guest: Variant) -> Variant:
	var chat := _chat_of(guest)
	if chat == null:
		return null
	var others: Array = _chat_voices(chat).filter(func(g): return g != guest)
	return others[0] if not others.is_empty() else null


## The bar's regulars who aren't here tonight and aren't waiting to come in.
func _regulars_away() -> Array:
	var here: Array = _guests.map(func(g): return str(g.customer.get("regular_id", "")))
	return RegularsTonight.all(Game.bar).filter(func(r): return not here.has(str(r["id"])) and not _waiting_who.has(str(r["id"])) and str(r["id"]) != _planted_regular)


## The PD plays a card: it happens, now, to whoever it's for (told in the conversation they
## speak in next, and as a moment for their line), and a fact card makes its fact true.
## Never pauses anything.
func _on_plant_pressed(card: String) -> void:
	if Plants.is_write(card):
		_open_writing(card)  # (the PD writes it first: see _on_written)
		return
	_play_card(card)


## Plays a card (text: what the PD wrote, for a write-in).
func _play_card(card: String, text: String = "") -> void:
	if _played.has(card) or not _hand.has(card) or Plants.why_not(card, _plant_now()) != "":
		return
	var data: Dictionary = Plants.CARDS[card]
	var aimed := _card_target(card)
	if ["someone", "pair"].has(str(data["for"])) and aimed.is_empty():
		return
	_played.append(card)
	_picked.erase(card)
	var what := _what_for(card)  # (what it is this time: "", for a card without variants)
	var who := ""
	var about: Variant = null  # (who the caption goes over: nobody in particular, unless it happened to someone)
	match str(data["for"]):
		"someone":
			var target: Variant = aimed[0]
			who = str(target.customer["name"])
			var gender := str(target.customer.get("gender", ""))
			var for_ai := text + Glossary.gloss(text, _names_here()) if text != "" else ""  # (what the PD typed, with any Korean in it explained)
			_plant_on(target, card, Plants.moment(card, who, "", what, gender, for_ai), Plants.happened(card, who, "", what, gender, for_ai))
			if str(data.get("others", "")) != "":
				for other in _guests:
					if other != target:
						_plant_on(other, card, Plants.others_moment(card, who), Plants.happened(card, who, "", what, gender))
			about = target.node
			if text != "":
				_show("[color=#%s][b]%s[/b][/color] [i]%s[/i]\n\n" % [CAMERA_RED.to_html(false), _esc("[PD]"), Glossary.explain(_esc(Plants.shown(card, who, what, gender, text)), _names_here())])
			else:
				_narrate(Plants.shown(card, who, what, gender))
			if int(data.get("write", {}).get("steers", 0)) > 0:  # (a cue card: their conversation's topic for a while)
				var chat := _chat_of(target)
				if chat != null:
					chat.pd_topic = for_ai
					chat.pd_topic_lines = int(data["write"]["steers"])
				else:
					target.pd_topic = for_ai
					target.pd_topic_lines = int(data["write"]["steers"])
			if card == "interview":
				target.to_camera = true
			if text != "":
				_stats.record_written(card, text, who, what, Plants.written_tells(text))
		"pair":
			var a: Variant = aimed[0]
			var b: Variant = aimed[1]
			who = "%s and %s" % [a.customer["name"], b.customer["name"]]
			if _chat_of(a) == null:  # (not chatting yet: this gets them talking)
				var chat := Chat.new()
				chat.people = [a, b]
				_chats.append(chat)
				_narrate("%s gets talking to %s." % [a.customer["name"], b.customer["name"]])
				_event("chat_started", {"name": str(a.customer["name"]), "friend": str(b.customer["name"])}, a.node)
				chat.transcript.append({"action": "%s turns to %s, a stranger a few stools along, and starts a conversation." % [a.customer["name"], b.customer["name"]]})
			var said := Plants.happened(card, str(a.customer["name"]), str(b.customer["name"]), what)
			_plant_on(a, card, Plants.moment(card, str(a.customer["name"]), str(b.customer["name"]), what), said)
			_plant_on(b, card, Plants.moment(card, str(b.customer["name"]), str(a.customer["name"]), what), said)
			about = a.node
			_narrate(said)
		"tent":
			for guest in _guests:
				_plant_on(guest, card, Plants.moment(card, str(guest.customer["name"]), "", what), Plants.happened(card, "", "", what))
			for chat in _chats:
				chat.transcript.append({"action": Plants.happened(card, "", "", what)})
			if str(data.get("fact", "")) == "":
				_narrate(Plants.happened(card, "", "", what))
	# The facts: what the game makes true.
	match str(data.get("fact", "")):
		"regular_in":
			var away := _regulars_away()
			var regular: Dictionary = away[_plant_dice.randi_range(0, away.size() - 1)]
			who = str(regular["name"])
			_planted_regular = str(regular["id"])
			for due in _regulars_due.duplicate():
				if str(due["id"]) == _planted_regular:
					_regulars_due.erase(due)  # (coming anyway, later: the call brings them sooner)
			_regulars_due.append({"time": _clock + PLANT_REGULAR_MINUTES, "id": _planted_regular})
			_regulars_due.sort_custom(func(x, y): return float(x["time"]) < float(y["time"]))
			_narrate("The PD rings %s: could they come down to the tent tonight?" % who)
		"weather":
			_change_weather(str(data["weather"]))
			_narrate("Out of nowhere, the heavens open: rain drums on the tarp.")
		"first_snow":
			_change_weather(Seasons.FIRST_SNOW)
			Game.bar["snowed_winter"] = Seasons.winter_number(int(Game.bar.get("first_date", 0)), _night_number)
			_narrate("It's started to snow: the first snow of winter.")
			_event("first_snow")
		"round":
			var buyer: Variant = aimed[0]
			buyer.order.append("soju")  # (on their bill)
			buyer.served.append("soju")
			_add_dish(buyer, "soju")
		"sponsor":  # (on their table, label to the camera; not on their bill: the sponsor's paying)
			_sponsor_on_table(aimed[0], Plants.sponsor_of(what))
		"lights":
			_lights_out = LIGHTS_OUT_SECONDS
			_narrate(Plants.happened(card, "", "", what))
	_event("plant_played", {"card": card, "name": who, "what": what, "text": text}, about)
	_update_desk()
	_update_info()


## A line said straight to camera (the PD's interview cut), set apart in the transcript like a
## variety show's interview insert.
func _show_to_camera(guest: Variant, line: String) -> void:
	var colour: Color = guest.color.lightened(0.35)
	_show("[indent][color=#%s][b]● INTERVIEW[/b][/color]  [color=#%s][b]%s[/b], to camera:[/color] [i]%s[/i][/indent]\n\n" % [CAMERA_RED.to_html(false),
		colour.to_html(false), _esc(_name_label(guest.customer)), Glossary.explain(_esc(line), _names_here())])


## What a card is tonight (its variant, picked once: "" for a card without them).
func _what_for(card: String) -> String:
	if not _card_what.has(card):
		_card_what[card] = Plants.variant(card, _plant_dice)
	return str(_card_what[card])


## What a write-in's PD is told before typing: "a text from her landlord" ("" if nothing).
func _write_from(card: String, guest: Variant) -> String:
	var from := str(Plants.CARDS[card].get("write", {}).get("from", ""))
	if from == "":
		return ""
	return Plants.gendered(from.replace("{what}", _what_for(card)), str(guest.customer.get("gender", "")) if guest != null else "")


## The sponsor's product on someone's table (the PPL card): drawn small, label out, with its hover.
func _sponsor_on_table(guest: Variant, sponsor: Dictionary) -> void:
	if sponsor.is_empty() or not is_instance_valid(guest.drinks_row):
		return
	var product := ColorRect.new()
	product.name = "Sponsor"
	product.custom_minimum_size = Vector2(12, 24)
	product.color = Color(str(sponsor["colour"]))
	product.mouse_filter = Control.MOUSE_FILTER_STOP
	product.tooltip_text = Text.tip("%s %s: %s. On the table for the camera (the sponsor's paying)." % [sponsor["hangul"], sponsor["name"], sponsor["means"]])
	var label := ColorRect.new()  # (the label, turned to the camera)
	label.position = Vector2(2, 9)
	label.size = Vector2(8, 7)
	label.color = Color("fff4e0")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product.add_child(label)
	guest.drinks_row.add_child(product)


# --- The PD writing a card ----------------------------------------------------------------

## A write-in card: the box on the desk opens (the night carries on while the PD types).
func _open_writing(card: String) -> void:
	if _writing_box == null or _played.has(card) or not _hand.has(card) or Plants.why_not(card, _plant_now()) != "":
		return
	_writing_card = card
	var write: Dictionary = Plants.CARDS[card]["write"]
	var aimed := _card_target(card)
	var target: Variant = aimed[0] if not aimed.is_empty() else null
	var from := _write_from(card, target)  # (who it's from, said before you type it)
	var who := ("for %s" % target.customer["name"]) if target != null else ""
	_writing_label.text = "%s  (%s)" % [write["label"], ", ".join(PackedStringArray([from, who].filter(func(part): return part != "")))]
	_writing_text.max_length = int(write["max"])
	_writing_text.placeholder_text = "e.g. %s" % write["hint"]
	_writing_text.text = ""
	_writing_problem.text = "Enter to play it, Esc to put it back."
	_writing_problem.add_theme_color_override("font_color", MUTED)
	_writing_box.visible = true
	_writing_text.grab_focus()


func _close_writing() -> void:
	_writing_card = ""
	if _writing_box != null:
		_writing_box.visible = false
		_writing_text.release_focus()


## Enter in the box: checked, then played (or why not, and the card stays in the hand).
func _on_written(typed: String) -> void:
	if _writing_card == "":
		return
	var checked := Plants.check_written(_writing_card, typed)
	var problem := str(checked["problem"])
	if problem == "" and Talk.real_brand(str(checked["text"])) != "":
		problem = "No real brands on the show (the sponsor's the only one we plug)."
	if problem == "" and Plants.why_not(_writing_card, _plant_now()) != "":
		problem = Plants.why_not(_writing_card, _plant_now())
	if problem == "" and _card_target(_writing_card).is_empty():
		problem = "Nobody at the counter with time left for it."
	if problem != "":
		_writing_problem.text = problem
		_writing_problem.add_theme_color_override("font_color", CAMERA_RED)
		_stats.written_refused += 1
		return
	var card := _writing_card
	_close_writing()
	_play_card(card, str(checked["text"]))


## Esc in the box puts the card back (and doesn't open Options).
func _on_writing_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_close_writing()
		_writing_text.accept_event()


## A card happens to someone: their moment, and what happened for the conversation they speak in next.
func _plant_on(guest: Variant, card: String, moment: String, what: String) -> void:
	guest.plant_moment = moment
	guest.plant_card = card
	guest.plant_happened = what
	_plant_in(guest.transcript, guest)


## Tonight's weather changes (a plant card): the tent, the sound, the street, the top bar and
## everyone's prompts from now on.
func _change_weather(weather: String) -> void:
	_night_weather = weather
	_show_weather(NightRules.weather_kind(_night_weather))
	_stats.story["weather_changed"] = _night_weather
	for guest in _guests:
		guest.moment["weather"] = _night_weather
	_update_clock_label()


## A plant card that's happened to someone (or the camera turning to them), in the conversation
## they're about to speak in (if it isn't there yet), so "what just happened" includes it, as
## well as their moment.
func _plant_in(transcript: Array, guest: Variant) -> void:
	if guest == null:
		return
	var said: Array = []
	if guest.camera_moment != "":
		said.append(Talk.camera_happened(str(guest.customer["name"])))
	if guest.plant_moment != "" and guest.plant_happened != "":
		said.append(guest.plant_happened)
	for what in said:
		if not transcript.any(func(entry): return str(entry.get("action", "")) == what):
			transcript.append({"action": what})


## Someone something's just happened to (a plant card) who's chatting at the counter, or null.
func _plant_waiting() -> Variant:
	for guest in _guests:
		if guest.plant_moment != "" and _chat_of(guest) != null:
			return guest
	return null


func _cat_tooltip() -> String:
	var text := "%s, the tent's %s cat (%s)" % [_with_hangul(_cat), _cat["coat"], CatRules.CAT_PERSONALITIES.get(_cat["personality"], "")]
	if CatRules.is_nickname(str(_cat["name"])):
		text += "\nA stray that moved in: the regulars' nickname for it, %s, means %s." % [_cat["name"], CatRules.CAT_NICKNAMES[str(_cat["name"])]["means"]]
	text += "\n" + ("● The camera's on it: click to stop" if _camera.on_cat else "Click to follow it with the camera")
	return Text.tip(text)


## The camera's viewfinder: corner marks round whoever it's on (round their body, clear of the
## speech bubbles over their heads).
func _viewfinder(node: Control, frame: Rect2) -> void:
	if not is_instance_valid(node) or node.get_node_or_null("CameraBadge") != null:
		return
	var marks := Control.new()
	marks.name = "CameraBadge"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arm := 14.0
	var thick := 3.0
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		var right: bool = corner.x > frame.position.x
		var down: bool = corner.y > frame.position.y
		var across := ColorRect.new()
		across.color = CAMERA_RED
		across.mouse_filter = Control.MOUSE_FILTER_IGNORE
		across.size = Vector2(arm, thick)
		across.position = Vector2(corner.x - (arm if right else 0.0), corner.y - (thick if down else 0.0))
		marks.add_child(across)
		var upright := ColorRect.new()
		upright.color = CAMERA_RED
		upright.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upright.size = Vector2(thick, arm)
		upright.position = Vector2(corner.x - (thick if right else 0.0), corner.y - (arm if down else 0.0))
		marks.add_child(upright)
	node.add_child(marks)


## Takes the viewfinder off whoever it was on (a Guest, "cat", or null).
func _viewfinder_off(who: Variant) -> void:
	if who == null:
		return
	var node: Variant = _cat_node if who is String else who.node
	if not is_instance_valid(node):
		return
	var marks: Node = node.get_node_or_null("CameraBadge")
	if marks != null:
		marks.queue_free()
const HOVER_REMEMBERED := 60  # ...and at most this much of what the owner remembers


## One short thing the owner remembers about them, for the hover: a fact that sticks (short by
## nature: "From: Busan"), or the owner's impression, cut short at a word. (The memories are
## whole sentences: all of them are in who's here now, over their name.)
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


## Who's here now (the side panel's first tab): the owner, the cat, then everyone at the counter and what's on their table; and the PD's desk with it.
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
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(CatRules.cat_text(str(_cat["name"]), _cat_spot, _tent_cat.with_name()))]
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
			var coming := _kitchen_part.food_coming(guest)
			if not coming.is_empty():
				t += "  ·  [color=#%s]cooking: %s[/color]" % [accent, Glossary.explain(_esc(Orders.item_names(coming)))]
			t += "  ·  %s\n" % Menu.format_won(Orders.bill(guest.order))
	var queueing := _waiting.size() - _free_seats().size()
	if queueing > 0:
		t += "\n[color=#%s]Waiting for a stool: %d[/color]\n" % [muted, queueing]
	_here_text = Glossary.explain_hangul(t)
	_update_stats_panel()
	_update_desk()


# --- Checking the AI's replies (the rules live in scripts/rules/) ------------

func _validate_owner(data: Variant, gender: String, age_range: String = "") -> String:
	return People.validate_owner(data, gender, age_range)


func _validate_bar_name(data: Variant) -> String:
	return BarLook.validate_bar_name(data)


func _validate_customer_name(data: Variant, taken: Array, gender: String) -> String:
	return Names.validate_customer_name(data, taken, gender)


func _validate_customer_details(data: Variant, age_range: String = "") -> String:
	return People.validate_customer_details(data, age_range)


## (And no made-up Korean in what they say as they order: "maesilju gajin, pajeon gajin".)
func _validate_order(data: Variant, max_mains: int, max_drinks: int) -> String:
	var problem := Orders.validate_order(data, max_mains, max_drinks)
	return problem if problem != "" else Talk.made_up_korean(str(data.get("line", "")), _names_here())


func _validate_extra_order(data: Variant, table: Array) -> String:
	var problem := Orders.validate_extra_order(data, table)
	return problem if problem != "" else Talk.made_up_korean(str(data.get("line", "")), _names_here())


## (Checked against the kitchen as it is when the reply comes, not when it was asked for.)
func _validate_line(data: Variant, speaker: String, alias: String, items: Array, names: Array, cat: Dictionary, address: Dictionary = {}) -> String:
	var problem := Talk.validate_line(data, speaker, alias, items, names, cat, address)
	return problem if problem != "" else Talk.served_already(str(data["line"]), items, _kitchen_part.all_coming())


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
	for toggle in [_reading_toggle, _sound_toggle, _music_toggle, _bubbles_toggle, _captions_toggle]:
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
	_street = Street.new(_night, _people_view, _stage)  # (people walk along in front of the tent)
	_build_stage(_stage)

	# Bottom left: what's being said
	_log_panel = _panel(Vector2(24, PANELS_TOP), Vector2(400, SCREEN.y - PANELS_TOP - 24))  # (sized in _layout_panels)
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

	# Beside it, the PD's desk: the camera (and, to come, the plant cards).
	_desk_panel = _panel(Vector2.ZERO, Vector2(DESK_WIDTH, 100))
	_desk_panel.name = "PdDesk"
	add_child(_desk_panel)
	var desk_box := VBoxContainer.new()
	desk_box.add_theme_constant_override("separation", 10)
	_desk_panel.add_child(desk_box)
	_desk = RichTextLabel.new()
	_desk.name = "PdDeskText"
	_desk.bbcode_enabled = true
	_desk.fit_content = true
	_desk.add_theme_font_size_override("normal_font_size", 17)
	_desk.add_theme_font_size_override("bold_font_size", 17)
	desk_box.add_child(_desk)
	_plant_cards = VBoxContainer.new()
	_plant_cards.name = "PlantCards"
	_plant_cards.add_theme_constant_override("separation", 8)
	desk_box.add_child(_plant_cards)
	# The edit: a big moment's spins, for a couple of seconds, over the cards.
	_edit_box = VBoxContainer.new()
	_edit_box.name = "PdEdit"
	_edit_box.visible = false
	var edit_label := Label.new()
	edit_label.text = "THE EDIT: pick its spin (1, 2, 3)"
	edit_label.add_theme_color_override("font_color", CAMERA_RED)
	_edit_box.add_child(edit_label)
	_edit_bar = ProgressBar.new()
	_edit_bar.name = "PdEditBar"
	_edit_bar.show_percentage = false
	_edit_bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()  # (the time left, in the camera's red)
	fill.bg_color = CAMERA_RED
	_edit_bar.add_theme_stylebox_override("fill", fill)
	_edit_box.add_child(_edit_bar)
	_edit_buttons = VBoxContainer.new()
	_edit_buttons.name = "PdEditSpins"
	_edit_box.add_child(_edit_buttons)
	desk_box.add_child(_edit_box)
	desk_box.move_child(_edit_box, 1)  # (just under the camera: where your eye is)
	_writing_box = VBoxContainer.new()
	_writing_box.name = "PlantWriting"
	_writing_box.visible = false
	desk_box.add_child(_writing_box)
	_writing_label = Label.new()
	_writing_label.name = "PlantWritingLabel"
	_writing_label.add_theme_color_override("font_color", ACCENT)
	_writing_box.add_child(_writing_label)
	_writing_text = LineEdit.new()
	_writing_text.name = "PlantWritingText"
	_writing_text.text_submitted.connect(_on_written)
	_writing_text.gui_input.connect(_on_writing_key)
	_writing_box.add_child(_writing_text)
	_writing_problem = Label.new()
	_writing_problem.name = "PlantWritingProblem"
	_writing_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_writing_box.add_child(_writing_problem)

	# Bottom right: who's here now, then tonight's debug stats, in tabs.
	_stats_panel = _panel(Vector2.ZERO, Vector2(SIDE_WIDTH, 100))
	_stats_panel.name = "StatsPanel"
	add_child(_stats_panel)
	_stats_text = RichTextLabel.new()
	_stats_text.name = "StatsText"
	_stats_text.bbcode_enabled = true
	_stats_text.selection_enabled = true
	_stats_text.add_theme_font_size_override("normal_font_size", 15)
	_stats_text.add_theme_font_size_override("bold_font_size", 15)
	_stats_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 10)
	_stats_panel.add_child(stats_box)
	_stats_tabs = HFlowContainer.new()
	_stats_tabs.name = "StatsTabs"
	stats_box.add_child(_stats_tabs)
	stats_box.add_child(_stats_text)
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
	_tent_view.sky = _rect(stage, Vector2.ZERO, STAGE_SIZE, Color("3c3a72"))  # the night sky, changing with the hour
	_tent_view.sky.name = "Sky"
	_skyline = SkylineView.new()
	_skyline.name = "Skyline"
	_skyline.size = STAGE_SIZE
	stage.add_child(_skyline)
	_tent_view.weather_back = _layer(stage, "WeatherBack")
	_rect(stage, Vector2(0, 0), Vector2(w, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(40, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(w - 84, 36), Vector2(44, 344), Color("1f1e36"))
	_scenery.build_neon(stage)
	_tent_view.glow = _rect(stage, Vector2(110, 110), Vector2(w - 220, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_tent_view.glow.name = "Glow"
	_rect(stage, Vector2(0, 372), Vector2(w, 8), Color("2a2840"))  # wet street
	var tent_from := stage.get_child_count()  # from here on is the tent (the cat and sign aside)

	for bulb_x in [620.0, 1250.0]:
		var bulb := Control.new()  # hung from the top of its wire, so it swings from there
		bulb.position = Vector2(bulb_x, 110)
		bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bulb)
		_rect(bulb, Vector2(-1, 0), Vector2(2, 36), Color("55536b"))  # bulb wire
		_tent_view.bulb_lights.append(_rect(bulb, Vector2(-8, 36), Vector2(16, 16), OWNER_TEXT))  # the bulb
		_tent_view.bulbs.append(bulb)
	_tent_view.decor_back = _layer(stage, "DecorBack")
	_menu_board = MenuBoard.new()
	_menu_board.name = "MenuBoard"
	stage.add_child(_menu_board)
	stage.move_child(_menu_board, _tent_view.bulbs[0].get_index())  # (behind the bulbs, which swing in front)
	_menu_board.opened.connect(func(): _stats.menu_opened += 1)
	_scenery.build_fridge(stage)

	_owner_node = _people_view.new_person(stage, Vector2(OWNER_HOME_X, OWNER_Y), OWNER_COLOR)
	_owner_node.name = "Owner"
	_owner_tag = _owner_node.get_node("Tag") as Label
	_owner_tag.z_index = 3  # their head is just under the tarp: the name goes in front of it
	_owner_node.visible = false

	_rect(stage, Vector2(100, 250), Vector2(w - 182, 18), Color("8a5a33"))  # counter top
	_rect(stage, Vector2(120, 268), Vector2(w - 222, 104), Color("5c3820"))  # counter front
	_rect(stage, Vector2(104, 244), Vector2(236, 6), Color("3a3946"))  # the stove
	_rect(stage, Vector2(130, 241), Vector2(40, 3), Color("e8833a"))  # a flame
	_scenery.build_odeng_pot(stage)
	_tent_view.decor_counter = _layer(stage, "DecorCounter")

	# What's cooking (and what's ready to carry over), at the stove.
	_kitchen_part.stove_row = HBoxContainer.new()
	_kitchen_part.stove_row.name = "Stove"
	_kitchen_part.stove_row.position = Vector2(176, 207)  # beside the odeng pot
	_kitchen_part.stove_row.size = Vector2(160, 34)
	_kitchen_part.stove_row.add_theme_constant_override("separation", 4)
	_kitchen_part.stove_row.clip_contents = true
	stage.add_child(_kitchen_part.stove_row)

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

	_tent_view.roof = Polygon2D.new()
	_tent_view.roof.name = "Tarp"
	_tent_view.roof.polygon = PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])
	_tent_view.roof.color = ACCENT
	_tent_cat.build(stage)
	_tent_cat.node.gui_input.connect(_on_cat_clicked)
	stage.add_child(_tent_view.roof)
	_tent_view.roof_stripes = _layer(stage, "TarpStripes")
	_tent_view.roof_edge = _rect(stage, Vector2(22, 112), Vector2(w - 44, 10), Color("c8612a"))
	_tent_view.decor_roof = _layer(stage, "DecorRoof")
	for k in range(tent_from, stage.get_child_count()):
		var piece := stage.get_child(k) as CanvasItem
		if piece != _owner_node and piece != _cat_node:
			_tent_view.tent.append(piece)
	_tent_view.glow.visible = false
	for piece in _tent_view.tent:
		piece.visible = false  # until the bar's look is known: no template tent while the AI thinks
	_tent_view.build_sign(stage)
	_tent_view.weather_front = _layer(stage, "WeatherFront")
	_tent_view.weather_front.z_index = 2  # in front of everyone
	_bubble_layer = _layer(stage, "Bubbles")
	_bubble_layer.z_index = 4  # in front of the tarp, the weather and the owner's name
	_captions_part = CaptionsOnScreen.new(_night, STAGE_SIZE.x, _show, _ambience.sting)
	_caption_layer = _layer(stage, "Captions")
	_caption_layer.z_index = 5  # in front of everything, bubbles included
	_camera_rec = Ktv.label("", 20, CAMERA_RED, 6)
	_camera_rec.name = "CameraRec"
	_camera_rec.position = Vector2(28, 16)
	_camera_rec.z_index = 6  # never hidden: over the bubbles and captions, in the stage's corner
	_camera_rec.mouse_filter = Control.MOUSE_FILTER_PASS
	_camera_rec.visible = false
	stage.add_child(_camera_rec)
	_captions_part.layer = _caption_layer
	var red_frame := Panel.new()
	red_frame.name = "RedFrame"
	red_frame.size = STAGE_SIZE
	red_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Color(1.0, 0.1, 0.1, 0.12)
	red.border_color = Color("ff2a2a")
	red.set_border_width_all(10)
	red_frame.add_theme_stylebox_override("panel", red)
	red_frame.visible = false
	_caption_layer.add_child(red_frame)
	_captions_part.red_frame = red_frame


## An empty full-stage layer for things added later (weather, the bar's touches).
func _layer(stage: Control, layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.size = STAGE_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(layer)
	return layer


# --- How the tent and the night look ------------------------------------------------

## The bar's look (saved with it): tarp, sign and touches (see TentView).
func _show_look() -> void:
	_tent_view.show_look(Game.bar)


## The sky, the tent's glow and the bulbs, by the hour and the weather; dimmer, with one bulb
## off, while closing up early (see _show_closing_up).
func _update_light(closing_dim: bool = false) -> void:
	_tent_view.update_light(_clock, _weather_kind, closing_dim or (_closing_early and _night_open))


## Tonight's weather, as you'd see it (see TentView).
func _show_weather(kind: String) -> void:
	_weather_kind = kind
	_tent_view.show_weather(kind)


func _rect(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


# --- Drawing people -----------------------------------------------------------------------


## The owner's look: chosen with the bar and saved (a bar from before looks gets one as it
## opens: see SaveUpgrades).
func _owner_look() -> Dictionary:
	return _owner.get("look", {})


# --- Regulars --------------------------------------------------------------------------------

## The bar's regulars (saved with it: see RegularsTonight).
func _regulars() -> Array:
	return RegularsTonight.all(Game.bar)


func _regular(id: String) -> Dictionary:
	return RegularsTonight.find(Game.bar, id)


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
		_typing_label.text = "The casting team are finding the regulars..."
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
	var choices: Array = Menu.items().filter(func(item): return (item.get("kind", "") == "drink") if kind == "drink" else (item.get("portion", "") == "main"))
	return str(choices.pick_random()["id"])


## Who's coming in tonight (see RegularsTonight.plan).
func _plan_regulars_tonight() -> void:
	_regulars_due.clear()
	_regulars_due.append_array(RegularsTonight.plan(Game.bar, _night_number, _day_index(), _cliffhanger, _scenery_dice))


## A regular's facts, for the prompts (see RegularsTonight.facts).
func _regular_facts(regular: Dictionary) -> Dictionary:
	return RegularsTonight.facts(regular, _night_number)


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
	if _closed():  # (the bar closed while it was waiting)
		return {}
	if tonight.is_empty():
		tonight = {"mood": "glad to be back", "reason": "It's been a while, and this is where they unwind."}
	customer["mood"] = tonight["mood"]
	customer["reason"] = tonight["reason"]
	return customer


## How a regular's announced as they duck in (see RegularsTonight.back_text): saved, if it's a
## founding regular's first time (they're introduced now).
func _back_text(regular: Dictionary) -> String:
	var introduced := bool(regular.get("introduced", false))
	var text := RegularsTonight.back_text(regular, _night_number)
	if bool(regular.get("introduced", false)) != introduced:
		Game.save()
	return text


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
		if _closed():
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
	if _closed():  # (the bar closed while it was waiting)
		return {}
	if memory.is_empty():
		_stats.memories_failed += 1
	return memory


func _validate_memory(data: Variant, said: String) -> String:
	return Memories.validate_memory(data, said)


func _name_said(full: String, said: String) -> bool:
	return RegularsTonight.name_said(full, said)


## The night's over: regulars who didn't come drift a little further away; anyone who's
## drifted too far isn't a regular any more (see RegularsTonight.fade).
func _fade_regulars() -> void:
	for gone in RegularsTonight.fade(Game.bar, _night_number):
		_stats.faded_regulars += 1
		_narrate("%s hasn't been in for a long while." % gone)
	_count_regulars()


## The regulars, for the stats panel and log.
func _count_regulars() -> void:
	var counted := RegularsTonight.pulls(Game.bar)
	_stats.regular_pulls = counted["pulls"]
	_stats.founding_regulars = int(counted["founding"])


## What the owner remembers about a regular, for the hover in who's here now (see RegularsTonight).
func _remembered_text(known: Dictionary) -> String:
	return RegularsTonight.remembered_text(known)


# --- Who calls whom, and friendliness ------------------------------------------------------

const FRIENDLY_AFTER := Friendliness.FRIENDLY_AFTER


## Someone, as far as address goes (see Friendliness). null: the owner.
func _addressee(guest: Guest) -> Dictionary:
	return Friendliness.person(_owner, guest)


func _who(guest: Guest) -> String:
	return Friendliness.name_of(_owner, guest)


## For the checks: who's speaking to whom. null: the owner.
func _address(speaker: Guest, listener: Guest, close: bool = false) -> Dictionary:
	return Friendliness.address_for(_owner, speaker, listener, close)


## For the prompts: how the owner and a customer address each other (see Friendliness).
func _address_note(guest: Guest) -> String:
	return Friendliness.address_note(_owner, guest)


## Two regulars' record of each other (from the first one's side), or {}.
func _friend(a: Guest, b: Guest) -> Dictionary:
	return Friendliness.friend_record(Game.bar, a, b)


func _close(a: Guest, b: Guest) -> bool:
	return Friendliness.are_close(Game.bar, a, b)


## Everyone in a chat is close to everyone else (only then can it turn to teasing).
func _all_close(people: Array) -> bool:
	for i in people.size():
		for j in range(i + 1, people.size()):
			if not _close(people[i], people[j]):
				return false
	return people.size() > 1


## After a spell of chat: regulars who chatted remember it (see Friendliness.remember_chat).
func _remember_chat(chat: Chat, last: String) -> void:
	Friendliness.remember_chat(Game.bar, chat.people, chat.transcript, last, _night_number)
	_refresh_tags()


## The "can I call you eonni?" moment, if it's time ("" if not: see Friendliness).
func _friendly_moment(speaker: Guest, addressee: Guest) -> String:
	return Friendliness.friendly_moment(Game.bar, _owner, speaker, addressee)


func _make_close(a: Guest, b: Guest, term: String) -> void:
	Friendliness.make_close(Game.bar, a, b)
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
	return Friendliness.term_used(Game.bar, _owner, line, speaker, listener)
