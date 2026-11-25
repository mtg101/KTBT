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
const DebugLog = preload("res://scripts/debug_log.gd")
const TentView = preload("res://scripts/bar/tent_view.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const Street = preload("res://scripts/bar/street.gd")
const Night = preload("res://scripts/bar/night.gd")
const Layout = preload("res://scripts/bar/layout.gd")
const Cat = preload("res://scripts/bar/cat.gd")
const Kitchen = preload("res://scripts/bar/kitchen.gd")
const CaptionsOnScreen = preload("res://scripts/bar/captions_on_screen.gd")
const PdDesk = preload("res://scripts/bar/pd_desk.gd")
const EditSuite = preload("res://scripts/ui/edit_suite.gd")
const Autopilot = preload("res://scripts/bar/autopilot.gd")
const CrewControls = preload("res://scripts/ui/crew_controls.gd")
const TranscriptView = preload("res://scripts/ui/transcript_view.gd")
const CaptionReel = preload("res://scripts/ui/caption_reel.gd")
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
const Bonds = preload("res://scripts/rules/bonds.gd")
const Groups = preload("res://scripts/rules/groups.gd")
const Names = preload("res://scripts/rules/names.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Seasons = preload("res://scripts/rules/seasons.gd")
const StreetLights = preload("res://scripts/bar/street_lights.gd")
const StreetArt = preload("res://scripts/bar/street_art.gd")
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
const Ratings = preload("res://scripts/rules/ratings.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Channels = preload("res://scripts/rules/channels.gd")
const SeasonPage = preload("res://scripts/ui/season_page.gd")
const ShowSetup = preload("res://scripts/ui/show_setup.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Art = preload("res://scripts/ui/art.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PortraitRules = preload("res://scripts/rules/portraits.gd")
const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")
const PortraitMaker = preload("res://scripts/ai/portrait_maker.gd")
const RecastScreen = preload("res://scripts/ui/recast_screen.gd")
const Keepsakes = preload("res://scripts/rules/keepsakes.gd")
const PortraitHover = preload("res://scripts/ui/portrait_hover.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")
const PixelFrame = preload("res://scripts/ui/pixel_frame.gd")
const Regulars = preload("res://scripts/rules/regulars.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const CaptionPopup = preload("res://scripts/ui/caption.gd")
const DiaryPage = preload("res://scripts/ui/diary_page.gd")
const DiaryBook = preload("res://scripts/ui/diary_book.gd")
const RecapScreen = preload("res://scripts/ui/recap_screen.gd")
const Hooks = preload("res://scripts/test_hooks.gd")
const NightEvents = preload("res://scripts/bar/night_events.gd")
const Snapshots = preload("res://scripts/bar/snapshots.gd")
const Socials = preload("res://scripts/rules/socials.gd")
const SocialFeed = preload("res://scripts/ui/social_feed.gd")
const Viewers = preload("res://scripts/rules/viewers.gd")
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
const COUNTER_ART_AT := Vector2(99, 249)  # the counter's pixel art's corner on the stage (tools/art/tent.py COUNTER: on the grid's lines)
const STAGE_ROOM := 81.0  # the street above the tent's stage (the overpass, the tops of the blocks: street_art.gd)
const PANELS_TOP := 533.0  # The transcript, the PD's desk and the side panel fill the screen below the tent (60 + STAGE_ROOM + 380 + 12).
const SIDE_WIDTH := 520.0  # the side panel on the right: who's here now, and the debug stats
const DESK_WIDTH := 460.0  # the PD's desk, between the transcript and the side panel

# Where things stand in the tent (pixels, inside the stage area, which is nearly full width).
const STAGE_SIZE := Vector2(1872, 380)
const SEAT_X := Layout.SEAT_X
const PERSON_WIDTH := Layout.PERSON_SIZE.x
const CUSTOMER_Y := Layout.CUSTOMER_Y
const OWNER_Y := Layout.CUSTOMER_Y  # (behind the counter, on the same ground)
const OWNER_HOME_X := 180.0  # by the stove
const OWNER_BESIDE_X := -165.0  # where the owner stands to see to a stool (just to its left)
# Off-stage spots either side (far enough out that the name tag is hidden too).
const OFFSCREEN_LEFT_X := Layout.OFFSCREEN_LEFT_X
const OFFSCREEN_RIGHT_X := Layout.OFFSCREEN_RIGHT_X

## The test hooks are in test_hooks.gd (as Hooks.<name>): tests set them; the game only reads them.

## When the owner's free and nothing's urgent: how often customers chat to each other
## instead of the owner chatting to someone. Mostly it's customer and owner.
const CHAT_CHANCE := 0.5
const CAT_HEARS_EVERY := 10.0  # game minutes: the cat answers (or ignores) its name at most this often
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
	var kept_by_cat := false  # their time was up, but the cat was asleep on their lap (once a visit: CatRules.LAP_KEEPS_MINUTES)
	var stunned := ""  # a Talk.stunned_moment for their next line, after a shock they heard
	var camera_moment := ""  # a Talk.camera_moment for their next line: the PD's camera has just turned to them
	var plant_moment := ""  # a Plants.moment for their next line: a PD's plant card has just happened to them...
	var plant_card := ""  # ... which card
	var plant_happened := ""  # ... and what happened, for whichever conversation they speak in next
	var pd_topic := ""  # the PD's cue card, or a card's moment lingering: the direction for their talk...
	var pd_topic_lines := 0  # ... for this many more lines
	var to_camera := false  # their next line's an interview cut: answered straight to camera
	var cat_talk_done := false  # the cat's taken over their talk with the owner once tonight (only once: it's a tent bar, not a cat cafe)
	var kya_done := false  # had their "Kya~!" after the first drink
	var turned_away := false  # turned away to drink in front of an elder (once a night)
	var card_turn := false  # the owner's already turned to them for the card that's just happened to them
	var heard_from_stove := false
	var regular := {}  # their regular's record, if they are one (as they came in)
	var together := {}  # came in with someone (Groups): {"kind", "pay", "names", "seated", "settled", "payer"}, the same for both
	var thread_moment := ""  # something they mentioned last time, for the owner to ask about (once)  # told the owner's talking to them from the stove (once, till they come over)
	var next_gesture := -1.0  # seconds until they next raise their glass or take a mouthful (-1: not counting yet)
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

# Who's here and what the owner's doing
var _guests: Array = []  # Guest: whoever's on a stool
var _camera := PdCamera.new()  # the PD's camera: who the show's following tonight (scripts/bar/camera.gd)
const CAMERA_RED := PdDesk.CAMERA_RED  # the camera's REC (the shock caption's red)
# The edit: the PD stepping in to cut last night's episode (see _step_in).
## Setting up the show (ui/show_setup.gd): offered while a new bar's being made; the bar waits
## while the PD's in there; what they chose ({"rung"}), applied once the bar's saved.
var _setup_open := false
var _setting_up := false
var _setup := {}
var _setup_screen: Control  # (while it's open: the casting photos are shown on it as they come)
## Faces of their own (ai/portrait_maker.gd): a new bar's owner's casting photos, taken in the gap
## before the first night when the GPU's free. The bar waits for them as for the setup.
var _maker: Node  # PortraitMaker, while ComfyUI's ours to use
var _comfy_open := false
var _casting := false  # photos being taken now
var _casting_photos: Array = []  # this round's: [{"seed", "picture", "split", "score"}]
var _casting_pick := -1  # which of them is the owner's face
var _casting_rounds := 0
var _faces_story := {}  # what happened, for the night's stats (_before_night["faces"])
var _casting_regulars := false  # the regulars' photos being taken now (the bar, and the next night, wait)
var _recast: Control  # RecastScreen, while the PD's recasting a regular's face (3am)
var _recast_button: Button
var _recast_photos: Array = []  # the regular's three: [{"seed", "picture", "split", "score"}]
var _recast_id := ""  # whose
var _recast_shooting := false
var _recast_story := {}  # what the PD did, for the next night's stats (_before_night["faces_recast"])
var _step_in_open := false  # they can, now: from the loading screen until the first customer arrives
var _step_in_wanted := false  # ...and have (it opens as soon as it can)
var _step_in_when := ""  # when they did: "loading", "recap" or "night" (for the stats)
var _editing := false  # the edit suite's open
var _recap_screen: Control  # "Previously on…", while it's playing
var _writers_recap := {}  # last night's recap as the writers cut it (the PD's cut is made from it)
var _said: Array = []  # the lines said, as said: {"id", "speaker", "text", "at", "night"} (a line's 📌 pins it: see _said_line)
var _pd: PdDesk  # the PD's desk: tonight's hand, the writing box, the edit, the REC corner (scripts/bar/pd_desk.gd)
var _planted_regular := ""  # the regular the PD rang tonight, until they're in (their id)
var _lights_out := 0.0  # real seconds left of the lights being out (the lights-flicker card)
const LIGHTS_OUT_SECONDS := 2.5
const PLANT_STAY_LEFT := PdDesk.STAY_LEFT  # game minutes someone needs left for a card picked for them (a pair: both)
const PLANT_REGULAR_MINUTES := 15.0  # how long a regular the PD rang takes to get here
var _counter_chats := CounterChats.new()  # customers chatting: who's in which chat, choosing the next spell (scripts/bar/counter_chats.gd)
var _chats: Array:  # Chat: customer conversations going on at the counter
	get:
		return _counter_chats.chats
var _names_tonight: Array = []
var _night_chats := {}
var _waiting_group: Array = []  # (alongside _waiting) {} for someone on their own, or the pair they came with
var _night_groups: Array = []  # tonight's pairs who came in together (for their bond, at closing)  # tonight's chats (by the chat): {"names", "lines", "owner_in"}, for regulars remembering each other at closing
var _jobs_tonight: Array = []  # tonight's customers' jobs and looks, so newcomers are different
var _looks_tonight: Array = []
var _voices_tonight := {}  # name -> who they are, as the game made them (Socials.voice): their posts' voice at 3am
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
var _greeting_regular := ""  # ...a regular's id, if it's one of them
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
var _rush_shown := false  # tonight's after-work rush has been and gone
var _dawn_shown := false  # ...and 2am feelings
## Tonight's specials (menu ids, rules/specials.gd): marked on the menu customers see. (What's
## sold out tonight is Menu.sold_out.)
var _specials: Array = []
var _menu_change := {}  # tonight's menu change, if there was one (MenuChanges): for the diary
## A CatRules.cat_moment for the owner's next line (the cat's up on the counter again...).
var _cat_heard_at := -999.0  # (game minutes) when the cat last heard its name: once in a while (CAT_HEARS_EVERY)
var _owner_camera_moment := ""  # a Talk.camera_moment for the owner's next line: the camera's just turned on them (once a night)
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
var _night_lines: Array = []  # what customers said tonight, for the summary
## Tonight's events (see night_events.gd): announced once each, and listened to by the stats,
## the TV captions and (from its list) the owner's diary.
var _events: NightEvents
var _diary_page: Control  # the 3am diary page (see diary_page.gd)
var _summary_buttons: Array = []  # disabled while the owner writes
var _stats_button: Button
var _recap_said := ""  # tonight's "Previously on…"
var _setup_ai: Array = []  # the AI's answers while a night's being got ready (the bar opening: its menu, own dishes, recap), counted in that night's stats; [purpose, problem, reply] for a rejected reply
var _getting_ready := true  # the bar's opening, or the next night's being got ready (not yet open)
## Its cliffhanger (Story.CLIFFHANGERS): {"kind", "who", "teaser", "answered"}, if tonight can answer it.
var _cliffhanger := {}
var _summary: PanelContainer
var _summary_text: RichTextLabel

# UI
var _try_again: Button  # only shown if the owner couldn't be invented
var _leave_button: Button
var _menu_buttons: HBoxContainer  # in the menu: the diary, closing the bar
const MENU_WIDTH := 600.0
var _ratings_result := {}  # the top bar's numbers, as last worked out (for the side panel's The show)
var _time_speed := NightRules.time_speed(0)  # how fast game time is running now (eases to the target)
var _reading_toggle: CheckBox
var _stats_panel: PanelContainer  # the side panel: who's here now, then the debug stats, in tabs
var _stats_text: RichTextLabel
var _stats_tabs: HFlowContainer  # one tab per section of the stats, and All
var _stats_view: StatsPanel  # what the stats panel shows, in its tabs (scripts/bar/stats_panel.gd)
var _log_panel: PanelContainer
var _moment_label: Label
var _mode_label: Label
## The autopilot PD (an autoplay batch only: see autopilot.gd), or null: a player's at the desk.
var _autopilot: Autopilot = null
var _crew: CrewControls  # "Let the crew run it" (autoplay in the game): the top bar's badge, the menu's row, Stop's question
var _summary_leave: Button  # the summary page's "Close the bar" (hidden while the crew are running it)
var _crew_between_nights := false  # the crew's pause on the summary page, before they open the next night
var _writing_up := false  # the owner's writing tonight up (the summary page's buttons wait)
var _night_written := false  # tonight's over and written up (the diary, the stats): the crew can take over from the summary page
var _ratings_label: Label  # 시청률: tonight's so far, the final at 3am, or last time's (see _update_ratings)
var _title_label: Label
var _log: RichTextLabel  # the transcript's lines (_transcript_view's)
var _transcript_view: TranscriptView  # the transcript on screen: its toolbar (search, All/Talk/Events, size, Compact) and catching up to the latest
var _typing_label: Label
var _here_text := ""  # who's here now, for the side panel's first tab (see _update_info)
var _desk_panel: PanelContainer  # the PD's desk: the camera (and the plant cards, to come)

# Scene pieces
var _stage: Control
var _owner_node: Control
var _owner_tag: Label
# The look of the tent and the night (placeholder art, drawn in code)
## Its own dice for scenery that comes and goes by itself (the neon sign, steam, the cat
## prowling), so it never shifts the game's own rolls (tests fix those with a seed).
var _scenery_dice := RandomNumberGenerator.new()
## Its own dice for the ratings' luck, so it never shifts the game's own rolls either.
var _ratings_dice := RandomNumberGenerator.new()
var _snaps: Snapshots  # tonight's snapshots of the stage, for the customers' posts (bar/snapshots.gd)
var _feed: Control  # the posts round the 3am diary page (ui/social_feed.gd)
## How much busier tonight is, from the last few nights' ratings (Ratings.busier), and tonight's
## rating once it's in (Ratings.score, with "banner" and "record").
var _busier := 1.0
var _night_ratings := {}
## Tonight's place in the show's seasons (ShowSeasons.tonight), and, after a finale, the season
## just ended: its verdict, nights and ratings (ShowSeasons.verdict), for the season page.
var _show_place := {}
var _season_ended := {}
var _season_page: Control  # the season looked back on, after a finale (ui/season_page.gd)
var _season_button: Button  # on the summary after a finale: the season page or the diary
var _scenery: Scenery  # the tent's fixtures: the fridge, the odeng pot, the neon, steam (scripts/bar/scenery.gd)
var _street_lights: StreetLights  # the street's lamps, cables, stars, moon and wet road (street_lights.gd)
var _street_for := ""  # the bar whose street is drawn
var _road: Control  # the wet road in front of the tent, on the stage (its reflections)
var _street_art: StreetArt  # the street behind the tent, in pixel art (street_art.gd)
var _light_hour := -1  # the hour the light was last logged
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
	if Game.autoplay != null:  # (a batch playing itself: the PD's desk is played too)
		_autopilot = Autopilot.new("%s nights %d" % [Game.bar.get("id", "new"), int(Game.bar.get("nights", 0))])
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
	_update_crew()
	_ai.offline_started.connect(_on_offline_started)
	_ai.answered.connect(_on_ai_answered)
	_ai.rejected.connect(_on_ai_rejected)
	if _ai.offline:
		_show_offline_mode()
	Menu.use(Menu.for_bar(Game.bar))  # this bar's own menu (the classic one if it has none)
	if Game.bar.is_empty():
		_invent_owner()  # A new bar: invent the owner, then name the tent and save it.
	else:
		_open_saved_bar()


## A bar from a save: its owner is back behind the counter.
func _open_saved_bar() -> void:
	if not SaveUpgrades.upgrade(Game.bar).is_empty():  # a bar saved by an older version: what the game fills in itself, once
		Game.save()
	_owner = Game.bar["owner"].duplicate(true)
	_own_face(_owner)  # (a face of their own, read in before anything draws it: "Previously on…"'s polaroids too)
	for regular in Game.bar.get("regulars", []):  # (not _regulars(): that fills the list in, and an older bar's founding regulars are made from it being missing)
		_own_face(regular)
	_show_bar_name()
	_show_look()
	_people_view.dress(_owner_node, _owner_look())
	_people_view.ready_gestures(_owner_node)  # (their hands' pictures made now, while the tent opens, not mid-night)
	_owner_tag.text = _owner_label()
	_update_owner_hover()
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
	if not _stopped:
		await _book_channel()  # (a bar from before channels, or the show's moved since)
	if _closed():
		_owner_working = false
		return
	if not Game.bar.get("cat", {}).is_empty():  # bars saved before cats have none, for now
		_show_cat()
	_update_info()
	if Hooks.recaps and int(Game.bar.get("nights", 0)) > 0:
		_loading_note = "The editors are cutting \"Previously on…\""
		_offer_step_in()
		await _ensure_titles()
		var recap := await _write_recap()
		_loading_note = ""
		if _closed():
			_owner_working = false
			return
		_end_loading()
		await _air_episode(recap)
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
				DebugLog.say("AI", "No Hangul for %s: %s" % [person_name, _ai.last_error])
		person["hangul"] = hangul  # "" if the AI couldn't: it's left off for now
		changed = changed or hangul != ""
	if changed:
		_owner["hangul"] = Game.bar["owner"]["hangul"]
		_owner_tag.text = _owner_label()
		_update_owner_hover()
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
	_loading.bar = Game.bar  # (the bar's own tent; a placeholder for a new bar, until its look's chosen)
	_before_night["loading_tent"] = "placeholder" if _loading.is_placeholder() else "the bar's"
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
	return "%s  (%ds: %s)" % [text, waited, Text.wait_aside(text.contains("photo"), waited)]  # (in the show's words, never "the AI")


const LOADING_PATIENCE := 5  # seconds before the status counts them
const LOADING_WAKING := 15  # ...and before it says why it might be slow


func _end_loading() -> void:
	if _loading == null or not _loading.visible:
		return
	_before_night["loading_seconds"] = Time.get_ticks_msec() / 1000.0 - _loading_opened
	if not Game.warmed.is_empty():  # (the title screen's warm-up of the model, for the stats)
		_before_night["warm_up"] = Game.warmed.duplicate()
		Game.warmed = {}
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
	if Game.autoplay != null:
		Game.autoplay.stop("the AI stopped answering (%s)" % reason)  # (at the end of tonight)
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
	_offer_setup()
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
	_people_view.ready_gestures(_owner_node)
	_owner_tag.text = _owner_label()
	_update_owner_hover()
	_owner_node.visible = true
	_narrate(Text.as_sentence(str(_owner["appearance"])))
	await _name_bar()
	_apply_setup()  # (if the PD set the show up before the bar was saved)
	await _name_cat()
	await _choose_look()
	if Hooks.bar_menus:
		await _choose_menu()
	if Hooks.founding_regulars:
		await _make_founding_regulars()
	_show_look()
	_show_cat()
	await _cast_owner_face()  # (the AI's done with the bar for now: the GPU's free for the image model)
	await _frame_done  # let the tent draw before the loading screen fades
	while (_setting_up or _casting or _casting_regulars) and not _closed():  # (the PD's setting the show up, or a reshoot: it starts when they're done)
		await get_tree().process_frame
	_setup_open = false
	await _close_casting()
	if _closed():
		return
	await _book_channel()  # (who's filming, and where it goes out: after the setup, which may have moved it)
	if _closed():
		return
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
	if _loading != null and _loading.visible:  # the placeholder tent becomes the bar's, as the tarp goes up
		_loading.show_bar(Game.bar)
		_before_night["loading_tent"] = "placeholder, then the bar's"
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
	var hover := _cat_node as PortraitHover
	if not hover.shown.is_connected(_cat_face_seen):
		hover.shown.connect(_cat_face_seen)
	_narrate("%s, the tent's %s cat, is %s." % [_cat["name"], _cat["coat"], CatRules.CAT_PERSONALITIES.get(_cat["personality"], _cat["personality"]).get_slice(":", 0)])


func _show_bar_name() -> void:
	_title_label.text = "KTBT  ·  %s" % Game.bar["name"]
	_title_label.tooltip_text = Text.tip(str(Game.bar.get("name_meaning", "")))


## Close the bar: during a night, the owner closes up early (see _close_early); after it (the
## night summary's button), back to the title screen, saved: straight away if the owner's
## free, otherwise once they've finished what they're doing (an AI call can't be stopped
## halfway).
func _on_leave_pressed() -> void:
	if Game.autoplay != null:  # (the crew are running it: stop them first, which asks how)
		_crew.ask_stop()
		return
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
	_closed_sign.position = Vector2(STAGE_SIZE.x - 210, 291)  # (on the grid's lines: a pixel to 3)
	_closed_sign.size = Vector2(84, 81)
	_closed_sign.pivot_offset = Vector2(42, 81)  # (it pops up from the pavement)
	_closed_sign.z_index = 4
	_closed_sign.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	_closed_sign.tooltip_text = Text.tip("마감 magam: closed. The owner's closing up early tonight: nobody new, and everyone here finishes at their own pace.")
	_stage.add_child(_closed_sign)
	var board := TextureRect.new()  # a little A-frame chalkboard, in pixel art (scenery.gd)
	board.name = "Board"
	board.texture = Scenery.closed_board()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.size = _closed_sign.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelLight.light(board, "tent")
	_closed_sign.add_child(board)
	for line in [["마감", 22, 4.0], ["CLOSED", 12, 34.0]]:
		var label := Ktv.label(str(line[0]), int(line[1]), Ktv.CREAM)
		label.position = Vector2(0, float(line[2]))
		label.size = Vector2(84, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelFont.apply(label, "closed_hangul" if line[0] == "마감" else "closed_english")  # (in pixels: pixel_font.gd)
		_closed_sign.add_child(label)
	_closed_sign.scale = Vector2(1.0, 0.0)
	var pop := _closed_sign.create_tween()
	pop.tween_property(_closed_sign, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The far bulb flickers, and goes off.
	if not _tent_view.bulb_lights.is_empty():
		var bulb: CanvasItem = _tent_view.bulb_lights[-1]
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
	if not Game.bar.has("show"):
		Game.bar["show"] = ShowSeasons.fresh()
	_show_place = ShowSeasons.tonight(Game.bar["show"])
	_remember_channels()
	_season_ended = {}
	_pick_weather()
	var bar_id := str(Game.bar.get("id", ""))
	if _street_for != bar_id:
		_street_for = bar_id
		_street_art.show_street(bar_id)  # (this bar's own street, from the art there is: its own dice, so the game's rolls don't shift)
		_street_lights.build(_street_art, _road, bar_id)  # (its lamps, cables and stars)
	_street_lights.tonight(Seasons.day_of_year(int(Game.bar.get("first_date", 0)), _night_number), NightRules.weather_kind(_night_weather))
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
	_night_lines = []
	_stats = NightStats.new()
	_zoomed_tonight = false
	var owner_hover := (_owner_node.get_node_or_null("Hover") as PortraitHover) if is_instance_valid(_owner_node) else null
	if owner_hover != null and owner_hover.picked_how != "":  # (their face came as the bar opened, before tonight's stats: counted in them too)
		_stats.portraits[owner_hover.picked_how] = int(_stats.portraits.get(owner_hover.picked_how, 0)) + 1
		DebugLog.say("Portraits", "the owner's face counted in tonight's stats (%s)" % owner_hover.picked_how)
	_count_cat_face()
	_stats.transcript_use = {"size": _transcript_view.font_size, "compact": _transcript_view.compact}  # (how it's set as the night opens)
	if Game.autoplay != null:  # (a night the crew open: in its stats)
		_stats.crew_run = {"from": Game.autoplay.started_from(), "nights": Game.autoplay.nights, "night": Game.autoplay.progress_text()}
	_camera = PdCamera.new()
	_camera.crew = Channels.camera_crew(Game.bar.get("show", {}))  # (who's filming: the niece or nephew, on the phone stream)
	_camera.cat = _tent_cat
	_pd.camera = _camera
	var hand := _pd.deal("%s night %d" % [Game.bar.get("id", ""), _night_number], _plant_tonight(), Game.bar.get("last_hand", []))
	Game.bar["last_hand"] = hand.duplicate()  # (not the same cards tomorrow; saved with the night)
	if _autopilot != null:
		_autopilot.plan(hand, _clock)
	_planted_regular = ""
	_lights_out = 0.0
	_show_camera()
	_events = NightEvents.new()
	_events.happened.connect(_stats.record_event)
	_events.happened.connect(_caption_for_event)
	_events.happened.connect(_watch_cliffhanger)
	_events.happened.connect(_snap_for_posts)
	_snaps = Snapshots.new()
	_snaps.host = self
	_snaps.stage = _stage
	_snaps.keep_out = _kept_out_of_shots
	_stats.events = _events.timeline  # (saved in the night's log, so a night's timeline can be looked back over)
	for answer in _setup_ai:  # (the AI's answers before tonight opened: the menu, the recap...)
		if answer.size() == 3:  # (a rejected reply: purpose, problem, what it said)
			_stats.record_rejected(str(answer[0]), str(answer[1]), str(answer[2]))
		else:
			_stats.record_ai(float(answer[1]), answer[2], bool(answer[3]), str(answer[0]))
	_setup_ai = []
	_getting_ready = false
	_stats.specials = _specials.duplicate()
	_stats.sold_out = Menu.sold_out.duplicate()
	_stats.story = _before_night.duplicate()  # (how it opened: only the first night after opening has any)
	_stats.art = Art.summary()  # (what's drawn from images so far, and what in code)
	_stats.art["lit"] = PixelLight.count_lit(self)  # (pieces lit by the hour: pixel_light.gd)
	_stats.art["pixel_words"] = PixelFont.count_in(self)  # (words on the stage in the pixel font: pixel_font.gd)
	_stats.art["street"] = _street_lights.summary()  # (its lamps, stars, the moon and the road: street_lights.gd)
	_menu_change = {}
	if _before_night.has("menu_change"):
		_menu_change = _before_night["menu_change"].duplicate()
		_event("menu_changed", _menu_change)
	_stats.story["date"] = str(_night_date.get("text", ""))
	_stats.story["weather"] = _night_weather
	_stats.story["season"] = _date_words().get_slice(", ", 1)
	_busier = Ratings.busier(Ratings.from_log(Game.bar.get("night_log", [])))
	_night_ratings = {}
	_stats.story["busier"] = _busier
	_stats.story["show"] = {"place": ShowSeasons.label(_show_place), "rung": _rung(), "finale": bool(_show_place["finale"]), "so_far": ShowSeasons.so_far(Game.bar["show"]),
		"on_air": _on_air_text(), "crew": Channels.camera_crew(Game.bar["show"]).trim_suffix(",")}
	_stats.ratings_before = Ratings.from_log(Game.bar.get("night_log", []))
	_events.happened.connect(func(_kind, _facts, _about, _spot): _update_ratings())
	_update_ratings()
	if not is_equal_approx(_busier, 1.0):
		DebugLog.say("Ratings", "night %d is %d%% %s, from the last few nights' ratings" % [_night_number, roundi(absf(_busier - 1.0) * 100.0), "busier" if _busier > 1.0 else "quieter"])
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
	_night_chats.clear()
	_night_groups.clear()
	_jobs_tonight.clear()
	_looks_tonight.clear()
	_voices_tonight.clear()
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
	_night_written = false
	_update_desk()  # (open now: the desk offers the edit again, until the first customer)
	_next_arrival = _clock + NightRules.next_arrival_gap(int(_clock), randf(), _busier)
	_show_weather(NightRules.weather_kind(_night_weather))
	_cat_spot = "stove"  # every night starts with the cat asleep by the stove
	_cat_with = null
	_cat_next = _camera.cat_stay(randf_range(CAT_MOVE_MINUTES.x, CAT_MOVE_MINUTES.y))
	_tent_cat.place()
	_update_clock_label()
	_start_transcript()
	_show("\n[center][color=#%s]· · ·  Night %d  ·  %s  ·  %s  · · ·[/color][/center]\n\n" % [ACCENT.to_html(false), _night_number, ShowSeasons.label(_show_place), _on_air_text()])
	var moved := ShowSeasons.season_news(Game.bar.get("show", {}), _show_place)  # (moved up or down, or renewed by name)
	if moved != "":
		_narrate(moved)
		_stats.story["show"]["moved"] = moved
		DebugLog.say("Season", "A new season: " + moved)
	if bool(_show_place["finale"]):
		_narrate("Tonight's the finale of season %d: at 3am, %s decides what happens to the show." % [int(_show_place["season"]), "the audience" if Ladder.is_floor(_rung()) else str(Ladder.rung(_rung())["the"])])
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
	_street_lights.set_minutes(_clock)
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
	_gestures(delta)
	_count_owner(delta)
	_place_owner()
	_stir(delta)
	if Hooks.cat_wanders and not _cat.is_empty():
		_cat_next -= minutes
		if _cat_next <= 0.0:
			_move_cat()
	if _autopilot != null:
		_autopilot_tick()
	if Hooks.run_clock:
		# After 3am the clock runs on while the last customers finish up.
		_clock += minutes
		_update_clock_label()
		_regulars_arrive()
		while _clock >= _next_arrival and _next_arrival < NightRules.LAST_ARRIVAL_MINUTES:
			if _skip_arrivals > 0:
				_skip_arrivals -= 1
			elif Hooks.groups and randf() < Groups.PAIR_CHANCE:
				_arrive_together(_next_arrival, Groups.pick(randf()))
				_skip_arrivals += 1  # (two at once: the night stays about as busy)
			else:
				_arrive(_next_arrival)
			_next_arrival += NightRules.next_arrival_gap(int(_next_arrival), randf(), _busier)
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
func _arrive(when: float, regular_id: String = "", group: Dictionary = {}) -> void:
	if _closing_early:
		_narrate("Someone comes up to the tarp, sees the 마감 sign, and walks on.")
		_street.walk_past(0.0)
		return
	_waiting.append(when)
	_waiting_who.append(regular_id)
	_waiting_group.append(group)
	if _step_in_open:  # (the first customer: last night's episode has aired)
		_step_in_open = false
		_update_desk()
	_event("arrived", {"regular": regular_id != ""})
	_update_info()


## Regulars whose time has come duck in (two close friends due together come in as a pair).
func _regulars_arrive() -> void:
	while not _regulars_due.is_empty() and _clock >= float(_regulars_due[0]["time"]):
		var due: Dictionary = _regulars_due.pop_front()
		if _regular_in(str(due["id"])):  # (already here, or on their way in: a PD's call brought them sooner)
			DebugLog.say("Regulars", "%s's already here: not coming in twice" % str(due["id"]))
			continue
		var partner: Array = _regulars_due.filter(func(d): return str(d.get("with", "")) == str(due["id"])) if Hooks.groups else []
		if not partner.is_empty() and not _regular_in(str(partner[0]["id"])):  # (close friends coming in together)
			_regulars_due.erase(partner[0])
			_arrive_together(float(due["time"]), "regulars", [str(due["id"]), str(partner[0]["id"])])
			_skip_arrivals += 2
			continue
		_arrive(float(due["time"]), str(due["id"]))
		_skip_arrivals += 1  # a regular instead of a newcomer: the night stays as busy


## Two people coming in together (Groups): kind, what they are to each other ("regulars": two
## close regulars, their ids); they wait for two stools together, and are greeted one after
## the other. How they'll pay is decided now.
func _arrive_together(when: float, kind: String, regular_ids: Array = ["", ""]) -> void:
	var group := {"kind": kind, "pay": Groups.pay_style(kind, randf()), "names": [], "seated": 0, "settled": false, "payer": ""}
	_stats.record_group(kind)
	DebugLog.say("Together", "two people coming in together (%s; they'll pay: %s)" % [kind, group["pay"]])
	for id in regular_ids:
		_arrive(when, str(id), group)


## Someone who's waited too long with every stool taken gives up and walks on.
func _give_up_waiting() -> void:
	var gone := 0
	while not _waiting.is_empty() and _seats_for_next() > _free_seats().size() and _clock - float(_waiting[0]) > NightRules.GIVE_UP_MINUTES:
		_waiting.pop_front()
		_waiting_who.pop_front()
		_waiting_group.pop_front()
		_narrate("Someone peeks under the tarp, sees every stool taken, and walks on.")
		_event("walked_on", {"first": gone == 0})
		_street.walk_past(gone * 1.5)  # if several give up at once, they don't walk in a clump
		gone += 1
		_update_info()


## 3am: nobody new, no more orders, and everyone's time is up.
func _call_last_orders() -> void:
	_last_orders = true
	_waiting.clear()
	_waiting_who.clear()
	_waiting_group.clear()
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
	_errands = {}
	_move_owner(OWNER_HOME_X)
	_fade_regulars()
	_update_stats_panel()
	var line := _night_quote()
	_rate_night()
	SaveStore.record_night(Game.bar, {
		"night": _night_number, "day": _night_day, "weather": _night_weather,
		"customers": _night_visits,
		"ratings": float(_night_ratings["rating"]),
		"season": int(_show_place["season"]), "season_episode": int(_show_place["episode"]),
		"line": line.duplicate(),
		"when": int(Time.get_unix_time_from_system()),
	})
	if ShowSeasons.record(Game.bar["show"], _night_number, float(_night_ratings["rating"])):
		_end_season()
	Game.save()
	_narrate("%s. %s pulls down the tarp and stacks the stools." % [NightRules.clock_text(int(_clock)), _owner_display()])
	_update_clock_label()
	var t := "[center][font_size=34][b]Night %d at %s[/b][/font_size]\n" % [_night_number, _esc(Game.bar["name"])]
	t += "[color=#%s]%s, %s[/color]\n\n" % [MUTED.to_html(false), _night_day, _esc(_night_weather)]
	t += "%d %s tonight\n" % [_night_visits, "customer" if _night_visits == 1 else "customers"]
	t += "[b]%s[/b]  ·  %s\n" % [Ladder.headline(float(_night_ratings["rating"]), str(_night_ratings["rung"]), int(_night_ratings.get("subscribers", -1))), _night_ratings["band"]]  # (the night's score, in its rung's units: takings aren't kept)
	t += "[color=#%s]%s, %s[/color]" % [MUTED.to_html(false), ShowSeasons.label(_show_place), _esc(_on_air_text())]
	if not _season_ended.is_empty():
		t += "\n[b]%s[/b]  %s" % [Glossary.explain_hangul(_esc(str(_season_ended["stamp"]))), _esc(str(_season_ended["words"]))]  # (the stamp explains itself on hover)
	if not line.is_empty():
		t += "\n\n[i][color=#%s]\"%s\"[/color][/i]\n[color=#%s]%s[/color]" % [OWNER_TEXT.to_html(false), _esc(line["text"]), MUTED.to_html(false), _esc(line["speaker"])]
	t += "[/center]\n\n" + _stats.panel_text(0, 0)
	_summary_text.text = t
	_summary_text.visible = false  # the numbers are behind the Stats button: the diary's the thing
	_stats_button.button_pressed = false
	_season_page.visible = false
	_season_button.visible = false
	_summary.visible = true
	_end_card()  # (over the whole window, while the owner starts writing: the page is under it)
	await _regulars_remember_each_other()
	await _write_diary()
	if not _season_ended.is_empty() and not _closed():
		_show_season_page()
	await _faces_after_closing()  # (the GPU's free until the next night's first AI call)
	_cliffhanger = {}  # (answered or not, it was last time's: the diary has it)
	_save_stats(true)  # after the diary, so the transcript runs right to the end (and has it)
	_night_written = true
	_update_recast_button()  # (the 📷 button: the GPU's free until the next night)
	if Game.autoplay != null:
		_autoplay_next()
	if _closing_early:  # (written up: the button's for leaving again)
		_closing_early = false
		_leave_button.disabled = false
		_leave_button.text = "Close the bar"


## 3am after a finale: the channel's verdict on the season (ShowSeasons.verdict: its average
## ratings, with a bonus for a new best or a hit, against today's targets), kept with the bar,
## and the next season begins. Counted in the stats (THE STORY), logged and in the transcript;
## the season page comes after the diary (_show_season_page).
func _end_season() -> void:
	var the_show: Dictionary = Game.bar["show"]
	var this_season: Array = the_show.get("nights", [])
	var before := Ratings.from_log(Game.bar.get("night_log", []).filter(func(n): return not this_season.has(int(n.get("night", 0)))))
	var judged := ShowSeasons.verdict(int(the_show.get("season", 1)), the_show.get("ratings", []), before, the_show.get("seasons", []), ShowSeasons.rung_of(the_show), int(the_show.get("subscribers", 0)))
	_season_ended = judged.duplicate()
	_season_ended["channel"] = Channels.full_name(the_show.get("channel", {}))  # (where the season went out)
	_season_ended["nights"] = this_season.duplicate()
	_season_ended["ratings"] = the_show.get("ratings", []).duplicate()
	ShowSeasons.end_season(the_show, judged)
	_stats.story["show"]["verdict"] = ShowSeasons.log_text(judged)
	_stats.story["show"]["verdict_words"] = str(judged["words"])
	DebugLog.say("Season", "%s" % ShowSeasons.log_text(judged))
	_narrate("That's season %d. %s" % [int(judged["season"]), str(judged["words"])])


## After the finale's diary: the season looked back on (ui/season_page.gd) in its place, an
## episode a row from the diary, and the verdict; the button beside Stats flips back to the diary.
func _show_season_page() -> void:
	var rows := ShowSeasons.recap_rows(_season_ended["nights"], _season_ended["ratings"], Game.bar.get("diary", []))
	_season_page.show_season(rows, _season_ended, str(Game.bar.get("name", "")))
	_season_button.text = "Diary"
	_season_button.visible = true
	_stats_button.button_pressed = false
	_diary_page.visible = false
	_season_page.visible = true
	_ambience.sting("sparkle")
	var said := PackedStringArray()
	for row in rows:
		var quote: Dictionary = row["quote"]
		said.append("EP %d %s%s%s" % [int(row["episode"]), Ladder.short(float(row["rating"]), str(_season_ended["rung"])), (" «%s»" % str(row["title"])) if str(row["title"]) != "" else "",
			(" \"%s\" (%s)" % [quote["text"], quote["speaker"]]) if not quote.is_empty() else ""])
	_stats.story["show"]["looked_back"] = rows.size()
	_show("[i][color=#%s]Season %d, looked back on: %s. %s %s[/color][/i]\n\n" % [MUTED.to_html(false), int(_season_ended["season"]), _esc(" · ".join(said)),
		_esc(str(_season_ended["stamp"])), _esc(str(_season_ended["words"]))])


## The summary's season button (after a finale): the season page or the diary, and back.
func _on_season_toggled() -> void:
	var to_season := not _season_page.visible
	_stats_button.button_pressed = false
	_summary_text.visible = false
	_season_page.visible = to_season
	_diary_page.visible = not to_season
	_season_button.text = "Diary" if to_season else "Season %d" % int(_season_ended.get("season", 1))


## Last time's ratings, for "Previously on…" ("RATINGS 6.4%"), or "" before the show had them.
func _last_ratings_text() -> String:
	var diary: Array = Game.bar.get("diary", [])
	if diary.is_empty() or not diary[-1].get("ratings", {}).has("rating"):
		return ""
	return Ladder.card_text(float(diary[-1]["ratings"]["rating"]), str(diary[-1]["ratings"].get("rung", Ladder.OLDER)), int(diary[-1]["ratings"].get("subscribers", -1)))


# --- The autopilot PD (an autoplay batch: see autopilot.gd) ------------------------------------

## Each frame of a night: a card that's due, and the camera now and then.
func _autopilot_tick() -> void:
	var due := _autopilot.card_due(_clock)
	if not due.is_empty():
		var card := str(due["card"])
		var text := str(due["text"])
		var played := false
		if text != "":
			var checked := Plants.check_written(card, text)  # (checked like a player's)
			text = str(checked["text"]) if str(checked["problem"]) == "" else ""
		if (text != "" or not Plants.is_write(card)) and _pd.can_play(card):
			_autopilot_did("plays %s%s" % [Plants.CARDS[card]["title"], (" «%s»" % text) if text != "" else ""])  # (first: then what happens)
			_pd.play(card, text)
			played = _pd.played.has(card)
		_autopilot.card_tried(card, played, _clock)
	var move := _autopilot.camera_due(_clock, _guests.size(), _camera.following != null)
	match str(move.get("do", "")):
		"follow":
			var who: Guest = _guests[int(move["who"])]
			if _camera.following != who:
				_camera_on(who)
		"stop":
			_camera_off("pd")
	_stats.autopilot = _autopilot.counts.duplicate(true)


## In the edit suite: the autopilot's picks, then "Cut it" (or, if that won't go, the writers').
func _autopilot_cuts(suite: EditSuite, titles: int, options: int, scenes: int) -> void:
	if not is_instance_valid(suite):
		return
	var chosen := _autopilot.cut_choices(titles, options, scenes)
	if int(chosen["title"]) >= 0:
		suite.pick_title(int(chosen["title"]))
	suite.pick_cliffhanger(int(chosen["cliffhanger"]))
	for k in chosen["scenes"]:
		suite.tick_scene(int(k))
	_autopilot_did("cuts the episode: title %d, cliffhanger %d, %d scenes ticked" % [int(chosen["title"]), int(chosen["cliffhanger"]), chosen["scenes"].size()])
	suite.cut()
	if is_instance_valid(suite) and not suite.is_queued_for_deletion():
		suite.leave_it()


## What the autopilot did, in the transcript (so it's told apart from a player's) and the stats.
func _autopilot_did(what: String) -> void:
	_show("[i][color=#%s](Autopilot PD %s.)[/color][/i]\n\n" % [MUTED.to_html(false), _esc(what)])
	if _stats != null:
		_stats.autopilot = _autopilot.counts.duplicate(true)


## The 시청률 in the top bar: tonight's so far (worked out as at 3am, before the luck, as
## things happen), tonight's once it's rated, or, before a night, last time's. Its hover says what
## ratings are and where the number comes from; the stats panel's RATINGS section has the rest.
func _update_ratings() -> void:
	if _ratings_label == null:
		return
	var result := {}
	var when := ""
	if not _night_ratings.is_empty():
		result = _night_ratings
	elif _events != null:
		var cards: int = _stats.plants().values().filter(func(p): return int(p[2]) > 0).size()
		result = Ratings.score(_events.timeline, {"cards_taken_up": cards}, 0.5)
		result["parts"] = result["parts"].filter(func(p): return not is_zero_approx(float(p[1])))
		if Ladder.counts_subscribers(_rung()):  # (the channel's total, with tonight's so far)
			result["subscribers"] = Ladder.subscribers_after(int(Game.bar.get("show", {}).get("subscribers", 0)), float(result["rating"]), _rung())
		_stats.ratings_so_far = result
		when = " so far"
	else:
		var before := Ratings.from_log(Game.bar.get("night_log", []))
		if before.is_empty():
			_ratings_label.visible = false
			return
		var last_rung := _last_rung()
		result = {"rating": float(before[-1]), "band": Ladder.band(float(before[-1]), last_rung), "parts": [], "rung": last_rung,
			"subscribers": int(Game.bar.get("diary", [{}])[-1].get("ratings", {}).get("subscribers", -1)) if not Game.bar.get("diary", []).is_empty() else -1}
		when = " last time"
	var rung := str(result.get("rung", _rung()))  # (on the rung it aired on)
	_ratings_label.visible = true
	_ratings_label.text = "%s%s  ·  %s" % [Ladder.label(float(result["rating"]), rung, int(result.get("subscribers", -1))), when, Ladder.rung(rung)["short"]]  # (the Korean, and the English beside it)
	var the_show: Dictionary = Game.bar.get("show", {})
	_ratings_result = result.duplicate()
	_ratings_result["rung"] = rung
	_ratings_result["when"] = when
	# The hover's a short summary; a click opens the whole story (the side panel's The show tab).
	var short := PackedStringArray(["%s%s, %s" % [Ladder.text(float(result["rating"]), rung, int(result.get("subscribers", -1))), when, _on_air_text() if rung == _rung() else "on " + str(Ladder.rung(rung)["name"])]])
	if rung == _rung():
		short.append("To move on: %s %s" % [Ladder.rule(rung), Ladder.progress(rung, the_show.get("ratings", []), int(the_show.get("subscribers", 0)))])
	short.append("Click for the whole story.")
	_ratings_label.tooltip_text = Text.tip("\n".join(short))


## The side panel's The show tab, opened (a click on the top bar's numbers).
func _show_the_show() -> void:
	if _stats_view == null:
		_update_stats_panel()
	_stats_view.show_tab(StatsPanel.SHOW)


## The side panel's The show: who films it, where it goes out, how it's doing and what moves it
## on, the last few episodes, and the channels it's been on. A heading each.
func _show_text() -> String:
	var the_show: Dictionary = Game.bar.get("show", {})
	if the_show.is_empty():
		return ""
	var rung := ShowSeasons.rung_of(the_show)
	var head := func(title: String) -> String: return "[color=#%s][b]%s[/b][/color]" % [ACCENT.to_html(false), title]
	var lines := PackedStringArray()
	var relative: Dictionary = the_show.get("pd", {})
	lines.append(head.call("BEHIND THE CAMERA"))
	if not relative.is_empty():
		lines.append("%s%s, the owner's %s %s" % [(str(relative.get("hangul", "")) + " ") if str(relative.get("hangul", "")) != "" else "", relative["name"], relative.get("relation", "niece"),
			"♀" if str(relative.get("relation", "")) == "niece" else "♂"])
		lines.append("The show's PD. On the phone stream, it's their own: @%s." % relative.get("handle", ""))
	lines.append("Filming now: %s." % Channels.camera_crew(the_show).trim_suffix(","))
	lines.append("")
	lines.append(head.call("ON AIR"))
	lines.append("%s, %s" % [ShowSeasons.label(ShowSeasons.tonight(the_show)) if _show_place.is_empty() else ShowSeasons.label(_show_place), _on_air_text()])
	var channel: Dictionary = the_show.get("channel", {})
	if str(channel.get("rung", "")) == rung:
		lines.append(Channels.hover(channel))
	lines.append(str(Ladder.rung(rung)["about"]))
	lines.append("")
	lines.append(head.call("MOVING ON"))
	lines.append(Ladder.rule(rung))
	lines.append("This season: " + Ladder.progress(rung, the_show.get("ratings", []), int(the_show.get("subscribers", 0))))
	if not _ratings_result.is_empty():
		var result_rung := str(_ratings_result.get("rung", rung))
		lines.append("")
		lines.append(head.call("TONIGHT" if str(_ratings_result.get("when", "")) != " last time" else "LAST TIME"))
		lines.append("%s%s: %s" % [Ladder.text(float(_ratings_result["rating"]), result_rung, int(_ratings_result.get("subscribers", -1))), _ratings_result.get("when", ""),
			Ladder.band(float(_ratings_result["rating"]), result_rung)])
		for part in _ratings_result.get("parts", []):
			lines.append("  %s%.1f  %s" % ["+" if float(part[1]) >= 0.0 else "", float(part[1]), part[0]])
		if str(_ratings_result.get("when", "")) == " so far":
			lines.append("[color=#%s]So far, before luck (what else is on): the final numbers are at 3am.[/color]" % MUTED.to_html(false))
	var episodes: Array = Game.bar.get("diary", []).filter(func(e): return e.get("ratings", {}).has("rating")).slice(-5)
	if not episodes.is_empty():
		lines.append("")
		lines.append(head.call("THE LAST EPISODES"))
		for entry in episodes:
			var ratings: Dictionary = entry["ratings"]
			lines.append("%s  %s" % [ShowSeasons.tag(ShowSeasons.of(entry)), Ladder.text(float(ratings["rating"]), str(ratings.get("rung", Ladder.OLDER)), int(ratings.get("subscribers", -1)))])
	var history: Array = the_show.get("channels", [])
	if not history.is_empty():
		lines.append("")
		lines.append(head.call("WHERE IT'S BEEN"))
		for each in history:
			lines.append("From season %d: %s, %s" % [int(each.get("from_season", 1)), Channels.full_name(each), Ladder.rung(str(each.get("rung", "")))["short"]])
	return Glossary.explain_hangul("\n".join(lines))


## Where the show is on the ladder now (rules/ladder.gd).
func _rung() -> String:
	return ShowSeasons.rung_of(Game.bar.get("show", {}))


## The rung last night's episode aired on (its diary entry's ratings say; before the ladder, network TV).
func _last_rung() -> String:
	var diary: Array = Game.bar.get("diary", [])
	if diary.is_empty() or not diary[-1].get("ratings", {}).has("rating"):
		return _rung()
	return str(diary[-1]["ratings"].get("rung", Ladder.OLDER))


## 3am: tonight's episode gets its ratings (Ratings.score), from what happened, the PD's cards
## taken up and a little luck from its own dice; a new best or a hit gets a banner on the diary
## page. Counted in the stats and logged.
func _rate_night() -> void:
	var cards: int = _stats.plants().values().filter(func(p): return int(p[2]) > 0).size()
	var before := Ratings.from_log(Game.bar.get("night_log", []))
	_night_ratings = Ratings.score(_events.timeline, {"cards_taken_up": cards}, _ratings_dice.randf())
	var rating := float(_night_ratings["rating"])
	var rung := _rung()
	_night_ratings["rung"] = rung  # (shown in its rung's units, wherever it's shown later)
	if Ladder.counts_subscribers(rung):  # (the online video channel: its subscribers grow, episode by episode)
		var total := Ladder.subscribers_after(int(Game.bar["show"].get("subscribers", 0)), rating, rung)  # (won and lost: they go down as well as up)
		Game.bar["show"]["subscribers"] = total
		_night_ratings["subscribers"] = total
	_night_ratings["band"] = Ladder.band(rating, rung)
	_night_ratings["banner"] = Ladder.banner(rating, before, rung)
	_night_ratings["record"] = Ratings.is_record(rating, before)
	_stats.story["ratings"] = rating
	_stats.story["ratings_text"] = Ratings.log_text(_night_ratings)
	_stats.story["ratings_shown"] = "%s on %s" % [Ladder.text(rating, rung, int(_night_ratings.get("subscribers", -1))), Ladder.rung(rung)["name"]]
	if str(_night_ratings["banner"]) != "":
		_stats.story["ratings_banner"] = Glossary.hangul_tip(str(_night_ratings["banner"]))  # (in words: the panel has no hovers)
	DebugLog.say("Ratings", "night %d, %s%s · %s" % [_night_number, Ratings.log_text(_night_ratings), (" · " + str(_night_ratings["banner"])) if str(_night_ratings["banner"]) != "" else "", _stats.story["ratings_shown"]])
	_update_ratings()


## 3am: the owner writes tonight up in their diary (the AI, from the facts the game picks, or
## the game itself if it can't), shown as the end-of-night page and kept with the bar.
func _write_diary() -> void:
	_writing_up = true
	for button in _summary_buttons:
		button.disabled = true
	var facts := _diary_facts()
	_diary_page.visible = true
	_feed.show_posts([], "")  # (last night's come down: tonight's go up with the entry)
	_diary_page.show_writing(ShowSeasons.tag(_show_place), _night_day, _night_weather, _owner_display())
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
		"text": text, "stamp": Story.diary_stamp(facts), "by": by, "facts": facts, "when": int(Time.get_unix_time_from_system()),
		"ratings": _night_ratings.duplicate(true),
		"season": int(_show_place["season"]), "season_episode": int(_show_place["episode"]), "finale": bool(_show_place["finale"])}
	_keep_faces(entry)
	await _post_socials(entry)
	if _closed():
		return
	await _viewers_comment(entry)
	if _closed():
		return
	SaveStore.record_diary(Game.bar, entry)
	if _season_ended.is_empty():
		_draft_titles(Game.bar["diary"][-1])  # (in the background: for the edit, next time)
	else:  # a finale: the season page comes next, and needs its title for the last row
		await _draft_titles(Game.bar["diary"][-1])
		if _closed():
			return
	Game.save()
	_stats.story["diary_by"] = "ai" if by == "owner" else "game"
	_stats.story["diary_stamp"] = str(entry["stamp"])
	_diary_page.show_entry(entry, "%s's diary" % _owner["name"])
	_feed.show_posts(entry.get("socials", []), str(Game.bar.get("id", "")), entry.get("viewers", {}))
	_sync_feed()
	_show("[i][color=#%s]%s's diary, %s: %s[/color][/i]\n\n" % [MUTED.to_html(false), _owner["name"], ShowSeasons.words(_show_place), _esc(text)])
	if not entry.get("socials", []).is_empty():
		_show("[i][color=#%s]On %s %s tonight: %s[/color][/i]\n\n" % [MUTED.to_html(false), Socials.APP, Socials.APP_ENGLISH,
			_esc(" · ".join(PackedStringArray(entry["socials"].map(func(post): return "%s %s %s" % [post["handle"], post["text"], " ".join(PackedStringArray(post["tags"]))]))))])
	var viewers: Dictionary = entry.get("viewers", {})
	if not (viewers.get("comments", []) as Array).is_empty():
		_show("[i][color=#%s]Viewers, %s: %s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(Viewers.title(viewers)),
			_esc(" · ".join(PackedStringArray(viewers["comments"].map(func(comment): return "%s: %s (%s)" % [comment["viewer"], comment["text"], Viewers.likes_text(viewers, comment)]))))])
	_writing_up = false
	for button in _summary_buttons:
		button.disabled = Game.autoplay != null  # (the crew open the next night, while they're running it)


## 3am, before the diary page: a TV-style end card, the night's biggest moment again
## (Keepsakes.biggest_moment) with the Hangul it aired with, its face slapped on at the zoom's
## size over the whole window, under "오늘의 명장면" (captions_on_screen.gd end_card). No moment
## tonight, or no face for whoever it was about: no card. Counted and noted.
func _end_card() -> void:
	var moment := Keepsakes.biggest_moment(_events.timeline)
	if moment.is_empty():
		DebugLog.say("Keepsakes", "no end card: no big moment tonight")
		return
	var mood := str(moment.get("mood", ""))
	var face := _tv_face(str(moment.get("who", "")), mood) if Captions.REACTIONS.has(mood) else {}
	if face.is_empty():
		_stats.keepsakes["end_card_faceless"] = 1
		DebugLog.say("Keepsakes", "no end card: no face for %s (%s)" % [moment.get("who", "?"), mood])
		return
	face["node"] = null  # (the end card's: no clipart stuck on anyone on stage at closing)
	var data: Dictionary = Captions.REACTIONS[mood]
	var words := Captions.reaction_words(mood, str(moment.get("caption", "")))
	if str(moment.get("hangul", "")) != "":
		words["hangul"] = str(moment["hangul"])
	_captions_part.end_card(words, str(data["icon"]), str(data["colour"]), str(data["sound"]), [face], Keepsakes.END_CARD_SECONDS)
	_stats.keepsakes["end_card"] = "%s, %s (size %d)" % [face["name"], mood, int(moment.get("size", 0))]
	DebugLog.say("Keepsakes", "end card: %s's %s moment, size %d, «%s» (%s face)" % [face["name"], mood, int(moment.get("size", 0)), words["english"], face["how"]])


## The diary entry's faces: the polaroids (Keepsakes.polaroids: the biggest moment's, then a
## regular or whoever stayed longest) and everyone tonight's portrait and colours, so the
## diary book (and later "Previously on…") can show them after the night's gone. Counted and noted.
func _keep_faces(entry: Dictionary) -> void:
	var here: Array = [str(_owner.get("name", ""))]
	for event in _events.of_kind("sat_down"):
		here.append(str(event.get("name", "")))
	var faces := {}
	for person_name in here:
		if _faces_kept.has(person_name):
			faces[person_name] = (_faces_kept[person_name] as Dictionary).duplicate(true)
	var photos: Array = []
	for photo in Keepsakes.polaroids(_events.timeline, faces, int(_clock), str(_owner.get("name", ""))):
		var kept: Dictionary = faces[photo["name"]]
		photos.append({"name": photo["name"], "mood": photo["mood"], "key": kept["key"], "look": kept["look"].duplicate(true)})
	entry["faces"] = faces
	entry["photos"] = photos
	_stats.keepsakes["polaroids"] = photos.size()
	_stats.keepsakes["faces_kept"] = faces.size()
	DebugLog.say("Keepsakes", "polaroids: %s; %d faces kept with the entry" % [", ".join(PackedStringArray(photos.map(func(p): return "%s (%s)" % [p["name"], p["mood"]]))) if not photos.is_empty() else "none", faces.size()])


## 3am: the customers post about their night (Socials.pick, from tonight's events), the AI writing
## the words, one call for all of them, each in its poster's voice (_write_socials: the game's own
## where it's offline or its words fail the check); each checked again (Socials.check: one that
## fails isn't posted); the snapshots of the ones picked (bar/snapshots.gd) kept beside the bar's
## save, named in the posts; a picture that wasn't taken is drawn. Kept with the entry, counted, logged.
func _post_socials(entry: Dictionary) -> void:
	var posts_dice := RandomNumberGenerator.new()
	posts_dice.seed = hash("%s night %d posts" % [Game.bar.get("id", ""), _night_number])
	var plants := _stats.plants()
	var taken: Array = plants.keys().filter(func(card): return int(plants[card][2]) > 0)
	var faces: Dictionary = entry.get("faces", {})
	var posts := Socials.pick(_events.timeline, {"owner": str(_owner.get("name", "")), "cat": str(_cat.get("name", "")), "faces": faces,
		"taken_cards": taken, "seats": NightRules.SEATS}, posts_dice)
	var still_in := {}  # (whoever's not settled up yet: what's on their table)
	for guest in _guests:
		still_in[str(guest.customer["name"])] = guest.served.duplicate()
	var served := Socials.served_tonight(_events.timeline, still_in)
	var posters: Array = faces.keys()
	for event in _events.timeline:
		var who := str(event.get("name", ""))
		if str(event.get("kind", "")) == "sat_down" and not posters.has(who):
			posters.append(who)
	var facts := {"posters": posters, "served": served, "known": posters + [str(_owner.get("name", "")), str(_cat.get("name", ""))]}
	var counts := {"posts": 0, "pictures": 0, "drawn": 0, "text": 0, "dropped": 0, "viewer_comments": 0, "picked": posts.size(),
		"words_ai": 0, "words_game": 0, "ai_turned_down": 0}
	await _write_socials(posts, facts, counts)
	if _closed():
		return
	var kept: Array = []
	for post in posts:
		var problem := Socials.check(post, facts)
		if problem != "":
			counts["dropped"] += 1
			DebugLog.say("Socials", "not posted (%s): %s" % [problem, Socials.log_text(post)])
			continue
		var shot := str(post["shot"])
		var image: Image = _snaps.shots.get(str(post["snap"])) if _snaps != null else null
		if image != null:
			var file := "night%d_%d.png" % [_night_number, kept.size()]
			if SaveStore.save_picture(str(Game.bar.get("id", "")), file, image) == OK:
				post["picture"] = file
			else:
				DebugLog.say("Socials", "couldn't keep the snapshot %s (as %s)" % [post["snap"], file])
		if str(post["picture"]) != "":
			counts["pictures"] += 1
		elif Socials.PICTURED.has(shot):
			counts["drawn"] += 1
		else:
			counts["text"] += 1
		post.erase("snap")
		post.erase("what")
		kept.append(post)
		DebugLog.say("Socials", "posted: %s" % Socials.log_text(post))
	counts["posts"] = kept.size()
	if _snaps != null:
		counts["snapshots"] = _snaps.counts.duplicate()
	entry["socials"] = kept
	_stats.socials = counts
	if kept.is_empty():
		DebugLog.say("Socials", "a quiet feed tonight: no posts (%d picked, %d not posted)" % [posts.size(), int(counts["dropped"])])


## The posts' words: the AI's, one call for them all (Prompts.socials_messages), each in its
## poster's voice and checked (Socials.validate_reply); offline, or where a post's words were
## turned down, the game's own (as Socials.pick stitched them; offline, the canned AI answers
## with the same templates). Each post's "by" says whose: "ai", or "game" (offline counts as the game's).
func _write_socials(posts: Array, facts: Dictionary, counts: Dictionary) -> void:
	var words := {}
	var by := "ai"
	if Hooks.socials and not posts.is_empty():
		var ai_facts := Socials.ai_facts(posts, {"owner": str(_owner.get("name", "")), "cat": str(_cat.get("name", "")),
			"weather": _night_weather, "voices": _voices_tonight})
		var reply: Dictionary = await _ai.ask_json(Prompts.socials_messages(ai_facts), Socials.validate_reply.bind(posts, facts), {"temperature": 0.9},
			{"purpose": "socials", "facts": ai_facts, "tries": 2})
		if _closed():
			return
		words = reply.get("words", {})
		by = "game" if _ai.offline else "ai"  # (offline: the canned AI's words are the game's own)
		for why in reply.get("turned_down", []):
			DebugLog.say("Socials", "the AI's words turned down, the game's instead: %s" % why)
		counts["ai_turned_down"] = (reply.get("turned_down", []) as Array).size() if not reply.is_empty() else posts.size()
		if reply.is_empty():
			DebugLog.say("Socials", "the AI's posts couldn't be used (%s): the game's own words" % _ai.last_error)
	for post in posts:
		var written: Dictionary = words.get(str(post["handle"]), {})
		if not written.is_empty():
			post["text"] = str(written["text"])
			post["tags"] = (written["tags"] as Array).duplicate()
		post["by"] = by if not written.is_empty() else "game"
		counts["words_ai" if post["by"] == "ai" else "words_game"] += 1
	DebugLog.say("Socials", "words: the AI's %d, the game's %d%s" % [int(counts["words_ai"]), int(counts["words_game"]),
		" (offline)" if _ai.offline else ("" if Hooks.socials else " (the AI's posts are off)")])


## 3am, after the posts: viewers comment on tonight's episode, where the show's rung has them
## (Viewers.pick: what about, how many, and their hearts, likes or recommends, all from the
## night's score), the AI writing the words in one call (Viewers.validate_reply checks each one;
## offline, or turned down, the game's own); each checked again (one that fails isn't shown).
## Kept with the entry ("viewers"), counted, logged. They talk about the ratings, never change them.
func _viewers_comment(entry: Dictionary) -> void:
	var ratings: Dictionary = entry.get("ratings", {})
	if ratings.is_empty():
		return
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("%s night %d viewers" % [Game.bar.get("id", ""), _night_number])
	var plants := _stats.plants()
	var taken: Array = plants.keys().filter(func(card): return int(plants[card][2]) > 0)
	var info := {"rung": str(ratings.get("rung", _rung())), "score": float(ratings.get("rating", 0.0)), "record": bool(ratings.get("record", false)),
		"owner": str(_owner.get("name", "")), "cat": str(_cat.get("name", "")), "taken_cards": taken}
	var board := Viewers.pick(_events.timeline, info, dice)
	var still_in := {}
	for guest in _guests:
		still_in[str(guest.customer["name"])] = guest.served.duplicate()
	var facts := Viewers.check_facts(_events.timeline, info, Socials.served_tonight(_events.timeline, still_in))
	var counts := {"words_ai": 0, "words_game": 0, "ai_turned_down": 0, "dropped": 0}
	var words := {}
	var by := "game"
	if Hooks.viewers and not board["comments"].is_empty():
		var ai_facts := Viewers.ai_facts(board, info)
		var reply: Dictionary = await _ai.ask_json(Prompts.viewers_messages(ai_facts), Viewers.validate_reply.bind(board["comments"], facts), {"temperature": 0.9},
			{"purpose": "viewers", "facts": ai_facts, "tries": 2})
		if _closed():
			return
		words = reply.get("words", {})
		by = "game" if _ai.offline else "ai"  # (offline: the canned AI's words are the game's own)
		for why in reply.get("turned_down", []):
			DebugLog.say("Viewers", "the AI's comment turned down, the game's instead: %s" % why)
		counts["ai_turned_down"] = (reply.get("turned_down", []) as Array).size() if not reply.is_empty() else board["comments"].size()
		if reply.is_empty():
			DebugLog.say("Viewers", "the AI's comments couldn't be used (%s): the game's own words" % _ai.last_error)
	var kept: Array = []
	for comment in board["comments"]:
		if words.has(str(comment["viewer"])):
			comment["text"] = str(words[str(comment["viewer"])])
			comment["by"] = by
		var problem := Viewers.check(comment, facts)
		if problem != "":
			counts["dropped"] += 1
			DebugLog.say("Viewers", "not shown (%s): %s" % [problem, Viewers.log_text(board, comment)])
			continue
		comment.erase("said")
		counts["words_ai" if comment["by"] == "ai" else "words_game"] += 1
		kept.append(comment)
		DebugLog.say("Viewers", "%s: %s" % [board["place"], Viewers.log_text(board, comment)])
	board["comments"] = kept
	entry["viewers"] = board
	_stats.socials["viewer_comments"] = kept.size()
	for key in counts:
		_stats.socials["viewer_" + str(key)] = counts[key]
	DebugLog.say("Viewers", "%d on %s's %s (%s, tonight's figure %s); words: the AI's %d, the game's %d%s" % [kept.size(), Ladder.rung(str(board["rung"]))["name"],
		Viewers.place_of(str(board["rung"]))["english"], board["crowd"], board["figure"], int(counts["words_ai"]), int(counts["words_game"]),
		" (offline)" if _ai.offline else ("" if Hooks.viewers else " (the AI's comments are off)")])


## A snapshot for the posts, if what just happened could be one (Socials.wants_snap): of whoever
## it's about, the dish set down, or the cat, a moment after (so they're in the shot).
func _snap_for_posts(kind: String, facts: Dictionary, _about: Variant, _spot: Vector2) -> void:
	if _snaps == null:
		return
	var event := facts.duplicate()
	event["at"] = int(_clock)
	var wanted := Socials.wants_snap(kind, event, str(_owner.get("name", "")))
	if wanted.is_empty():
		return
	_snaps.take(str(wanted["key"]), _snap_aim.bind(str(wanted["aim"]), str(wanted["name"])), float(SNAP_DELAY.get(str(wanted["aim"]), 0.0)))


const SNAP_DELAY := {"person": 0.3, "food": 0.2, "cat": 0.0}  # seconds after it happens: the dish down, the cat still at the table


## Where a snapshot points (global): someone at their stool, their dish, or the cat; null if
## they've gone.
func _snap_aim(aim: String, who: String) -> Variant:
	if aim == "cat":
		if is_instance_valid(_cat_node) and _cat_node.visible:
			return _cat_node.get_global_rect().get_center()
		return null
	var guest: Guest = _guest_named(who)
	if guest == null:
		for here in _guests:
			if Names.given_name(str(here.customer["name"])) == who:
				guest = here
	if guest == null or not is_instance_valid(guest.node):
		return null
	if aim == "food" and is_instance_valid(guest.food_row):
		return guest.food_row.get_global_rect().get_center()
	return guest.node.get_global_rect().get_center()


## What's never in a snapshot: the bubbles, captions, REC and name tags on the stage, and every
## panel and overlay on the window (bar/snapshots.gd keeps them out).
func _kept_out_of_shots() -> Array:
	var out: Array = [_bubble_layer, _caption_layer]
	if _pd != null and is_instance_valid(_pd.rec):
		out.append(_pd.rec)
	out.append_array(_stage.find_children("Tag", "", true, false))
	for child in get_children():
		if child != _stage and child != _street_art and child != _street_lights and child is CanvasItem:
			out.append(child)
	return out


## The posts are up while the diary page is: not over the stats or the season page.
func _sync_feed() -> void:
	if _feed != null:
		_feed.visible = _summary.visible and _diary_page.visible


func _validate_diary(data: Variant, facts: Dictionary) -> String:
	return Story.validate_diary(data, facts)


## What the owner's diary is written from: the game's facts about tonight. Kept with the entry,
## for the diary book and "Previously on…".
func _diary_facts() -> Dictionary:
	return Story.diary_facts(_events.timeline, {
		"episode": _night_number, "episode_label": ShowSeasons.words(_show_place), "season": int(_show_place["season"]), "season_episode": int(_show_place["episode"]),
		"day": _night_day, "weather": _night_weather, "owner": str(_owner["name"]), "date": _date_words(),
		"owner_gender": str(_owner.get("gender", "")), "customers": _night_visits,
		"before": Game.bar.get("night_log", []).slice(0, -1).map(func(n): return int(n.get("customers", 0))),
		"regulars": _regulars().map(func(r): return {"name": str(r["name"]), "founding": bool(r.get("founding", false)), "gender": str(r.get("gender", ""))}),
		"cat": str(_cat.get("name", "")), "line": _night_quote(), "specials": _specials.duplicate(),
		"pinned": [] if _pd == null else _pd.pins.map(func(p): return {"speaker": str(p["speaker"]), "text": str(p["text"]), "at": int(p.get("at", -1))}),
		"closed_early": NightRules.clock_text(int(_closed_early_at)) if _closing_early else "",
		"closed_said": _closing_said if _closing_early else "",
		"menu_change": _menu_change.duplicate(),
		"cliffhanger": {} if _cliffhanger.is_empty() else {"teaser": _cliffhanger["teaser"], "kind": _cliffhanger["kind"], "answered": _cliffhanger["answered"]},
	})


## "Previously on…": what the recap's written from (see StoryKeeper.recap_facts), and the post
## or comment the writers end on ("online": Story.online_pick, from dice of last night's own, so
## it's the same each time it's asked for).
func _recap_facts() -> Dictionary:
	var facts := StoryKeeper.recap_facts(Game.bar, _owner, _regulars(), _scenery_dice)
	var diary: Array = Game.bar.get("diary", [])
	var last: Dictionary = diary[-1] if not diary.is_empty() else {}
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("%s night %d online" % [Game.bar.get("id", ""), int(last.get("night", 0))])
	var roll := dice.randf()
	facts["online"] = Story.online_pick(last, Hooks.online_roll if Hooks.online_roll >= 0.0 else roll, dice.randi())
	return facts


## The recap for tonight: the AI's, checked, or the game's own from the same facts.
## scenes: the PD's, from the edit suite (Story.scene_options): the beats are those, one each.
func _write_recap(scenes: Array = []) -> Dictionary:
	var facts := _recap_facts()
	facts["scenes"] = scenes
	if not scenes.is_empty():
		facts["online"] = {}  # (the PD's scenes are the beats: any post or comment is one of them)
	var reply: Dictionary = await _ai.ask_json(Prompts.recap_messages(facts), _validate_recap.bind(facts), {"temperature": 0.85},
		{"purpose": "recap", "facts": facts, "tries": 2})  # (two goes, then the game's own: it's on the loading screen)
	if _closed():  # (the bar closed while it was waiting)
		return {}
	_before_night["recap_by"] = "game" if reply.is_empty() else "ai"
	if reply.is_empty():
		reply = Story.stitched_recap(facts)
	reply["online"] = Story.online_beats(reply.get("beats", []), scenes, facts.get("online", {}))  # (each beat's post or comment, for its card)
	return reply


func _validate_recap(data: Variant, facts: Dictionary) -> String:
	return Story.validate_recap(data, facts)


# --- The edit: the PD steps in -------------------------------------------------------------

## The show's niece or nephew, if it hasn't one yet: the game decides which (from the bar, so
## no dice are rolled), the AI names them and their stream's handle (Channels.validate_relative),
## or the game does. Kept with the show ("pd"), logged and in the transcript.
func _cast_relative() -> void:
	var the_show: Dictionary = Game.bar["show"]
	if not the_show.get("pd", {}).is_empty():
		return
	var relation := Channels.relation(fposmod(float(hash(str(Game.bar.get("id", "")))) / 997.0, 1.0))
	var by := "game"
	var reply: Dictionary = {}
	if Hooks.channels:
		_typing_label.text = "The owner's %s is setting up their phone..." % relation
		reply = await _ai.ask_json(Prompts.relative_messages(_owner, str(Game.bar.get("name", "")), relation), Channels.validate_relative, {"temperature": 0.9},
			{"purpose": "relative", "relation": relation, "owner_name": str(_owner.get("name", ""))})
		_typing_label.text = ""
		if _closed():
			return
		by = "ai" if not reply.is_empty() else "game"
	if reply.is_empty():
		reply = Channels.fallback_relative(relation, fposmod(float(hash(str(_owner.get("name", "")))) / 1000.0, 1.0))
	reply["relation"] = relation
	reply["gender"] = Channels.gender_of(relation)
	the_show["pd"] = reply
	_before_night["relative"] = {"name": str(reply["name"]), "relation": relation, "handle": str(reply["handle"]), "by": by}
	if str(reply.get("hangul", "")) != "":
		Glossary.remember(str(reply["hangul"]), "%s %s: the owner's %s, who films the show" % [reply["hangul"], reply["name"], relation])
	_narrate("Behind the camera: %s, %s's %s, filming on %s phone as @%s." % [reply["name"], Names.given_name(str(_owner.get("name", ""))), relation,
		"her" if relation == "niece" else "his", reply["handle"]])
	DebugLog.say("Crew", "%s, the owner's %s (@%s, by the %s)" % [reply["name"], relation, reply["handle"], by])
	Game.save()


## Books the show on a channel for its rung, if it needs one (none yet, or it's moved): on the
## phone stream, the niece or nephew's own handle; otherwise the AI names the channel
## (Channels.validate_channel: made up, never the show's earlier ones), or the game does. Kept
## with the show ("channel", and the history), logged, said in the transcript.
func _book_channel() -> void:
	if not Game.bar.has("show"):
		Game.bar["show"] = ShowSeasons.fresh()
	var the_show: Dictionary = Game.bar["show"]
	await _cast_relative()  # (every show has one: they film the stream, and go with it as it climbs)
	if _closed() or not Channels.needs_booking(the_show):
		return
	var rung := ShowSeasons.rung_of(the_show)
	var channel: Dictionary = {}
	var by := "game"
	if rung == "phone":
		channel = Channels.stream_channel(the_show["pd"])
	else:
		var taken := Channels.taken_names(the_show)
		if Hooks.channels:
			_typing_label.text = "The show's being booked on %s..." % Ladder.rung(rung)["name"]
			channel = await _ai.ask_json(Prompts.channel_messages(rung, str(Game.bar.get("name", "")), taken), func(data): return Channels.validate_channel(data, taken),
				{"temperature": 0.9}, {"purpose": "channel", "rung": rung, "taken": taken})
			_typing_label.text = ""
			if _closed():
				return
			by = "ai" if not channel.is_empty() else "game"
		if channel.is_empty():
			channel = Channels.fallback_channel(rung, taken)
	Channels.book(the_show, rung, channel, int(the_show.get("season", 1)))
	_remember_channels()
	_before_night["booked"] = {"channel": Channels.full_name(the_show["channel"]), "rung": rung, "by": by}
	DebugLog.say("Booked", "%s on %s (by the %s)" % [Channels.full_name(the_show["channel"]), rung, by])
	Game.save()


## The show's channels' Hangul, explained on hover wherever it's shown.
func _remember_channels() -> void:
	for channel in Game.bar.get("show", {}).get("channels", []):
		if str(channel.get("hangul", "")) != "":
			Glossary.remember(str(channel["hangul"]), "%s %s" % [channel["hangul"], Channels.hover(channel)])


## Where the show goes out, in words: "on a phone stream (@jiwoo_pocha_live)", "on network TV (달빛TV, Moonlight TV)".
func _on_air_text() -> String:
	var the_show: Dictionary = Game.bar.get("show", {})
	var channel: Dictionary = the_show.get("channel", {})
	var where := "on %s" % Ladder.rung(ShowSeasons.rung_of(the_show))["name"]
	if channel.is_empty() or str(channel.get("rung", "")) != ShowSeasons.rung_of(the_show):
		return where
	return "%s (%s)" % [where, Channels.full_name(channel).replace(" (", ", ").trim_suffix(")")]


## A new bar: the PD can set the show up (where it starts on the ladder, for now) while the bar's
## being made, from the loading screen's button or Enter. Never waits on them: not stepping in,
## the game's defaults (the phone stream).
func _offer_setup() -> void:
	_setup_open = true
	if _loading != null and _loading.visible:
		var button: Button = _loading.show_step_in("📋  The PD sets up the show…  (Enter)", "LoadingSetUp")
		button.pressed.connect(_open_setup)


## The setup screen, over everything; the bar waits for it (see _invent_owner).
func _open_setup() -> void:
	if not _setup_open or _setting_up:
		return
	_setting_up = true
	var screen := ShowSetup.new()
	add_child(screen)
	screen.open(_setup if not _setup.is_empty() else {"rung": Ladder.FIRST})
	_setup_screen = screen
	screen.face_picked.connect(_pd_picks_owner_face)
	screen.reshoot_wanted.connect(_reshoot_owner_face)
	_tell_setup_casting()
	_setup = await screen.finished
	_setup_screen = null
	_setting_up = false
	if _closed():
		return
	_before_night["setup"] = {"rung": str(_setup["rung"]), "by": "pd"}
	_show("[i][color=#%s]📋 The PD sets up the show: it starts on %s.[/color][/i]\n\n" % [CAMERA_RED.to_html(false), Ladder.rung(str(_setup["rung"]))["name"]])
	_apply_setup()


## What the PD chose, onto the bar once it's saved (before its first night only).
func _apply_setup() -> void:
	if _setup.is_empty() or not Game.bar.has("show") or int(Game.bar.get("nights", 0)) > 0:
		return
	Game.bar["show"]["rung"] = str(_setup["rung"])
	Game.save()
	DebugLog.say("Setup", "the show starts on %s" % Ladder.rung(str(_setup["rung"]))["name"])


## The PD can step in and cut last night's episode, from now until the first customer
## arrives: said on the loading screen (and, as it plays, on "Previously on…", and on the desk).
func _offer_step_in() -> void:
	_step_in_open = true
	_step_in_wanted = false
	_step_in_when = ""
	if _loading != null and _loading.visible:
		var crew := Game.autoplay != null
		var button: Button = _loading.show_step_in(("✂  The writers are cutting %s…  (the crew decide whether to step in)" if crew else "✂  The writers are cutting %s…  Step in as the PD (Enter)") % _last_episode_words())
		button.disabled = crew
		button.pressed.connect(func():
			if Game.autoplay == null:
				_step_in())
	if _autopilot != null and _autopilot.steps_in():
		_autopilot.counts["stepped_in"] = "yes"
		_step_in.call_deferred()


## The PD steps in (Enter, or a click): the edit suite opens as soon as it can (once loading's
## done; at once mid-recap, which stops to play again once it's cut; or during the night).
## Never waits on them: not stepping in, everything runs straight through.
func _step_in() -> void:
	if not _step_in_open or _editing or _step_in_wanted:
		return
	_step_in_wanted = true
	if _recap_screen != null and is_instance_valid(_recap_screen):
		_step_in_when = "recap"
		_recap_screen.end()  # (it plays again with the cut: see _air_episode)
	elif _loading != null and _loading.visible:
		_step_in_when = "loading"
	else:
		_step_in_when = "night"
		_recut_tonight()


## "Previously on…" goes out: the writers' cut, unless the PD steps in (before, or while it
## plays: then it plays again with theirs).
func _air_episode(recap: Dictionary) -> void:
	_writers_recap = Story.apply_cut(recap, {"title": _writers_title()})
	var airing := _writers_recap
	while true:
		if _step_in_wanted:
			airing = await _cut_episode()
			if _closed():
				return
		await _play_recap(airing, false)
		if not _step_in_wanted:
			break


## Stepped in once the night's going (before the first customer): cut it, then it airs again.
func _recut_tonight() -> void:
	var airing := await _cut_episode()
	if not _closed():
		await _play_recap(airing, false)


## The edit suite on last night's episode; returns the recap with the PD's cut in (the
## writers', if they leave it). Kept with the episode's diary entry, and counted.
func _cut_episode() -> Dictionary:
	_step_in_wanted = false
	_editing = true
	var entry: Dictionary = Game.bar.get("diary", [])[-1]
	var suite := EditSuite.new()
	add_child(suite)
	var offered := Story.scene_options(entry.get("facts", {}), entry.get("socials", []), entry.get("viewers", {}))  # (with last night's posts and comments)
	suite.open(ShowSeasons.words(ShowSeasons.of(entry)), entry.get("titles", []), str(_writers_recap.get("teaser", "")), Story.cliffhanger_options(entry.get("facts", {})),
		offered, entry.get("faces", {}))
	var scene_faces := [suite.scenes_with_faces, offered.size()]  # (scenes with faces, of all: for the stats)
	DebugLog.say("Keepsakes", "the edit suite: %d of %d scenes with faces (%d faces kept with the entry)" % [suite.scenes_with_faces, offered.size(), (entry.get("faces", {}) as Dictionary).size()])
	DebugLog.say("Socials", "the edit suite offers %s as scenes" % (Story.online_counts(offered) if Story.online_counts(offered) != "" else "no posts or comments"))
	if _autopilot != null:
		_autopilot_cuts.call_deferred(suite, entry.get("titles", []).size(), Story.cliffhanger_options(entry.get("facts", {})).size(), offered.size())
	var cut: Dictionary = await suite.finished
	var base := _writers_recap
	var rewrite := {}
	if cut.has("scenes"):  # (the PD's scenes: the recap's rewritten from them, with the show going on meanwhile)
		var started := Time.get_ticks_msec()
		var screen := _editing_screen()
		var scenes: Array = cut["scenes"]
		base = await _write_recap(scenes)
		if is_instance_valid(screen):
			screen.queue_free()
		if _closed():
			_editing = false
			return {}
		base["quotes"] = scenes.map(func(s): return s.get("quote", {}))  # (a pinned line, quoted under its beat)
		rewrite = {"scenes": scenes.size(), "kept": Story.scenes_kept(base.get("beats", []), scenes), "seconds": snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1),
			"online": Story.online_counts(scenes)}
		entry["scenes"] = scenes.map(func(s): return {"kind": s["kind"], "at": s["at"], "text": s["text"]})
	_editing = false
	if not cut.has("title"):
		cut["title"] = _writers_title()
	var airing := Story.apply_cut(base, cut)
	entry["title"] = airing.get("title", {}).duplicate()
	entry["cut_by"] = {"title": str(cut.get("title_by", "writers")), "cliffhanger": str(cut.get("cliffhanger_by", "writers")), "scenes": str(cut.get("scenes_by", "writers"))}
	Game.save()
	var noted := {"stepped_in": _step_in_when, "title_by": str(cut.get("title_by", "writers")), "cliffhanger_by": str(cut.get("cliffhanger_by", "writers")),
		"scenes_by": str(cut.get("scenes_by", "writers")), "rewrite": rewrite,
		"own_teaser": bool(cut.get("own_teaser", false)), "left_to_writers": not cut.has("title_by"), "title": Story.title_text(airing.get("title", {})),
		"scene_faces": scene_faces}
	if _night_open:
		_stats.story["edit"] = noted
	else:
		_before_night["edit"] = noted
	_show("[i][color=#%s]✂ The PD steps in: %s, %s%s.[/color][/i]\n\n" % [CAMERA_RED.to_html(false), ShowSeasons.words(ShowSeasons.of(entry)),
		_esc("\"%s\"" % Story.title_text(airing.get("title", {}))), " (left to the writers)" if not cut.has("title_by") else (", cliffhanger «%s»" % _esc(airing.get("teaser", "")))])
	return airing


## While the recap's rewritten from the PD's scenes: the show goes on, TV pop-ups about the
## edit drifting over the night, never a dead screen.
const EDIT_LINES := [
	["편집 중…", "PYEONJIP JUNG… EDITING", "✂", "ff4f6d"],
	["재편집!", "JAEPYEONJIP! RE-CUT!", "🎬", "ffd27f"],
	["PD 등판!", "THE PD STEPS IN", "📣", "7ee8c8"],
	["작가 멘붕", "JAKGA MENBUNG: THE WRITERS PANIC", "😱", "ff7eb6"],
	["밤샘 편집", "BAMSAEM PYEONJIP: AN ALL-NIGHT EDIT", "☕", "c79bff"],
]


func _editing_screen() -> Control:
	var screen := Control.new()
	screen.name = "EditingScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.z_index = 40
	var dim := ColorRect.new()
	dim.color = Color(Ktv.BACKGROUND, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var note := Ktv.label("✂  Cutting your episode…  the writers are on it", 34, Ktv.CREAM, 8)
	note.position = Vector2(0, 500)
	note.size = Vector2(SCREEN.x, 60)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(note)
	var reel := CaptionReel.new()
	reel.size = SCREEN
	reel.lines = EDIT_LINES
	reel.areas = [Rect2(120, 140, 600, 300), Rect2(1200, 140, 600, 300), Rect2(300, 640, 1300, 300)]
	screen.add_child(reel)
	add_child(screen)
	return screen


## The title the writers give last night's episode: the first drafted.
func _writers_title() -> Dictionary:
	var diary: Array = Game.bar.get("diary", [])
	var titles: Array = [] if diary.is_empty() else diary[-1].get("titles", [])
	return {} if titles.is_empty() else titles[0]


## Last night's episode's titles, if it hasn't any yet (the game closed before they were
## drafted at 3am, or a bar from before titles): drafted now, on the loading screen.
func _ensure_titles() -> void:
	var diary: Array = Game.bar.get("diary", [])
	for entry in diary:  # (titles' Korean explains itself, as it did when they were drafted)
		for title in entry.get("titles", []):
			if str(title.get("hangul", "")) != "":
				Glossary.remember(str(title["hangul"]), "%s: %s" % [title["hangul"], title["english"]])
	if diary.is_empty() or not diary[-1].get("titles", []).is_empty():
		return
	await _draft_titles(diary[-1])


## Three titles for an episode (its diary entry): the AI's, checked, or the game's own. Their
## Korean is told to the glossary, so it explains itself on screen. Kept with the entry.
func _draft_titles(entry: Dictionary) -> void:
	var facts: Dictionary = entry.get("facts", {})
	var titles: Array = []
	var dropped: Array = []  # Korean the AI wrote that isn't Korean the game knows (Story.korean_title_problem)
	if Hooks.titles:
		var reply: Dictionary = await _ai.ask_json(Prompts.title_messages(facts), Story.validate_titles.bind(facts), {"temperature": 0.9},
			{"purpose": "titles", "facts": facts, "tries": 2})
		titles = reply.get("titles", [])
		dropped = reply.get("dropped_hangul", [])
		if not dropped.is_empty():  # (Korean that wasn't: those titles go out in English only)
			DebugLog.say("Titles", "dropped Korean that isn't words the game knows: %s" % ", ".join(PackedStringArray(dropped)))
	var by := "ai" if not titles.is_empty() else "game"
	if titles.is_empty():
		titles = Story.stitched_titles(facts)
	_stats.story["titles"] = {"titles": titles.map(func(t): return Story.title_text(t)), "by": by, "dropped_hangul": dropped.duplicate()}
	for title in titles:
		if str(title.get("hangul", "")) != "":
			Glossary.remember(str(title["hangul"]), "%s: %s" % [title["hangul"], title["english"]])
	entry["titles"] = titles
	entry["title"] = titles[0]
	Game.save()


## Plays a recap full screen and waits for it to finish (or be skipped).
func _play_recap(recap: Dictionary, opener: bool) -> void:
	var cliff: Dictionary = recap.get("cliffhanger", {})
	_cliffhanger = {} if opener or str(cliff.get("kind", "other")) == "other" else {"kind": cliff["kind"], "who": cliff.get("who", []), "teaser": str(recap.get("teaser", "")), "answered": false}
	var screen := RecapScreen.new()
	screen.time_scale = _scaled(1.0)
	screen.sting = _ambience.sting
	add_child(screen)
	_recap_screen = screen
	screen.step_in.connect(_step_in)
	var facts := _recap_facts()
	# A different K-TV style each time (Story.RECAP_STYLES), from last time's biggest moment.
	var style := Story.pick_recap_style(facts["last"], str(Game.bar.get("last_recap_style", "")), randf())
	Game.bar["last_recap_style"] = style
	_before_night["recap_style"] = style
	var extras := {"people": facts["hangul"], "moments": facts["last"].get("moments", []), "weather": str(facts["last"].get("weather", "")), "style": style,
		"quotes": [] if opener else recap.get("quotes", facts["last"].get("pinned", [])),
		"episode_title": "" if opener or recap.get("title", {}).is_empty() else "%s · %s" % [ShowSeasons.tag(ShowSeasons.of(Game.bar.get("diary", [{}])[-1])), Story.title_text(recap["title"])],
		"step_in": not opener and _step_in_open,
		"ratings": "" if opener else _last_ratings_text(),
		"place": ShowSeasons.tonight(Game.bar.get("show", ShowSeasons.fresh())),
		"online": [] if opener else recap.get("online", []), "bar_id": str(Game.bar.get("id", ""))}
	var last_entry: Dictionary = Game.bar.get("diary", [{}])[-1] if not Game.bar.get("diary", []).is_empty() else {}
	if not opener:  # (last night's faces, as its diary entry kept them: none from before 22 Nov)
		extras["faces"] = last_entry.get("faces", {})
		extras["photos"] = last_entry.get("photos", [])
	else:  # (a new show: the owner's face, just made for them (or the library's), beside their beat and on the card)
		var owner_name := str(_owner.get("name", ""))
		if _faces_kept.has(owner_name):
			var kept: Dictionary = _faces_kept[owner_name]
			extras["faces"] = {owner_name: kept.duplicate(true)}
			extras["photos"] = [{"name": owner_name, "mood": "calm", "key": str(kept["key"]), "look": (kept["look"] as Dictionary).duplicate(true)}]
	if not opener and not facts["last"].get("pinned", []).is_empty():
		_before_night["recap_pins"] = Story.pins_in_recap(facts["last"]["pinned"], recap.get("beats", []))  # (for the stats: tonight's start in them)
	screen.play(recap.get("beats", []), str(recap.get("teaser", "")), int(extras["place"]["episode"]), str(Game.bar.get("name", "")), opener, extras)
	await screen.finished
	_recap_screen = null
	# (the faces shown, the series opener's too: the owner's)
	var shown := {"beats": screen.beat_faces.duplicate(), "card": screen.card_faces.duplicate(), "kept": (extras.get("faces", {}) as Dictionary).size()}
	if opener:
		shown["own"] = PortraitRules.is_own(str(extras.get("photos", [{}])[0].get("key", ""))) if not extras.get("photos", []).is_empty() else false
	var online := ", ".join(PackedStringArray(screen.online_shown))  # (the posts and comments it cut to: "post minji_eats")
	if _night_open:  # (recut early in the night)
		_stats.story["recap_faces"] = shown
		_stats.story["recap_online"] = online
	else:
		_before_night["recap_faces"] = shown
		_before_night["recap_online"] = online
	if online != "":
		DebugLog.say("Socials", "Previously on…: cut to %s" % online)
	DebugLog.say("Keepsakes", "%s: faces beside the beats %s; on the card %s (%d faces %s)" % ["Series opener" if opener else "Previously on…",
		", ".join(PackedStringArray(screen.beat_faces)) if not screen.beat_faces.is_empty() else "none",
		", ".join(PackedStringArray(screen.card_faces)) if not screen.card_faces.is_empty() else "none", (extras.get("faces", {}) as Dictionary).size(),
		("given: the owner's, %s" % ("their own" if shown.get("own", false) else "the library's")) if opener else "kept with last night's entry"])
	if _step_in_wanted:
		return  # (stopped for the PD to cut it: what airs is logged when it plays again)
	var titled := "" if recap.get("title", {}).is_empty() else " (%s)" % Story.title_text(recap["title"])
	_recap_said = "%s%s %s %s" % ["Series opener:" if opener else "Previously on…", titled, " ".join(PackedStringArray(recap.get("beats", []))), recap.get("teaser", "")]
	_show("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(_recap_said)])


## Last night's episode in words, for cutting it: "season 1, episode 4" (from its diary entry).
func _last_episode_words() -> String:
	var diary: Array = Game.bar.get("diary", [])
	return ShowSeasons.words(ShowSeasons.of(diary[-1])) if not diary.is_empty() else "last night's episode"


## The owner's diary as a book, full size over everything (the night carries on behind it): the
## side panel's Diary tab opens it.
func _open_diary() -> void:
	if find_child("DiaryBook", false, false) != null:
		return
	var book := DiaryBook.new()
	add_child(book)
	book.open(Game.bar.get("diary", []), "%s's diary" % _owner.get("name", ""), -1, str(Game.bar.get("id", "")))


## The end-of-night Stats button: the numbers instead of the diary page, and back.
func _on_summary_stats_toggled(on: bool) -> void:
	var season_up := _season_button.visible and _season_button.text == "Diary"  # (the season page was showing)
	_summary_text.visible = on
	_diary_page.visible = not on and not season_up
	_season_page.visible = not on and season_up
	_stats_button.text = ("Season" if season_up else "Diary") if on else "Stats"  # (and back)


## Every answer from the AI, for the stats: tonight's (and its diary, after), or, while the next
## night's being got ready, kept for its stats, so the menu, the signature dishes and the
## recap's rejected tries are counted too.
func _on_ai_answered(purpose: String, seconds: float, problems: Array, ok: bool) -> void:
	if _getting_ready:
		_setup_ai.append([purpose, seconds, problems.duplicate(), ok])
	else:
		_stats.record_ai(seconds, problems, ok, purpose)


## A reply the AI gave that was turned down, kept (a few of each kind) in the night's log.
func _on_ai_rejected(purpose: String, problem: String, reply: String) -> void:
	if _getting_ready:
		_setup_ai.append([purpose, problem, reply])
	else:
		_stats.record_rejected(purpose, problem, reply)


func _on_next_night_pressed() -> void:
	_summary.visible = false
	_recast_button.visible = false
	_season_page.visible = false
	_season_button.visible = false
	_story.forget_before()  # (the end of last night, the diary: not tonight's)
	_getting_ready = true
	if Hooks.bar_menus and not Game.bar.get("menu", []).is_empty():
		_owner_working = true
		await _change_menu()  # now and then, something new on the board
		_owner_working = false
		if _closed():
			return
	_owner_working = true
	await _book_channel()  # (the show's moved: a new channel, before the new season's first night)
	_owner_working = false
	if _closed():
		return
	_start_night()


## Autoplay (see autoplay.gd): tonight's logged and written up, so note it in the batch's
## summary, then, after a pause on the summary page, open the bar again for the next night, as
## coming back the next day does (so "Previously on…", the episode's titles and the chance to
## step in as the PD all happen, as they don't going straight on); or, when the batch is done
## (or the AI stopped answering), quit.
func _autoplay_next() -> void:
	var auto = Game.autoplay
	if auto.bar_id == "" and not bool(Game.bar.get("autoplay", false)):
		Game.bar["autoplay"] = true  # (its own bar: marked as a test bar on the title screen)
		Game.save()
	auto.night_done(_night_number, _night_visits, _ai.offline, _stats.rejected, _stats.gave_up, float(_night_ratings.get("rating", -1.0)),
		"%s · %s%s" % [ShowSeasons.short_label(_show_place), str(_night_ratings.get("rung", _rung())), (" · " + ShowSeasons.log_text(_season_ended)) if not _season_ended.is_empty() else ""])
	var path: String = auto.save_summary(str(Game.bar.get("name", "")), str(Game.bar.get("id", "bar")))
	if auto.from_command_line:
		auto.write_running(str(Game.bar.get("name", "")))
	DebugLog.say("Autoplay", "night %d done (%s). Summary: %s" % [_night_number, auto.progress_text(), ProjectSettings.globalize_path(path)])
	if auto.finished():
		if auto.quits_when_done():
			Game.quit()
		else:
			_crew_hand_back(auto)  # (started in the game, or stopped by hand: the bar's the player's again)
		return
	_autoplay_open_next(auto)


## After the summary page's pause, the crew open the next night (as coming back the next day).
func _autoplay_open_next(auto) -> void:
	_crew_between_nights = true
	_update_crew()
	if auto.pause_seconds > 0.0:
		await get_tree().create_timer(auto.pause_seconds).timeout
	_crew_between_nights = false
	if _closed() or Game.autoplay != auto:
		return
	if not Game.open_bar(str(Game.bar.get("id", ""))):
		_on_next_night_pressed()  # (the save won't load: carry straight on instead)


# --- Let the crew run it (autoplay in the game: autoplay.gd, crew_controls.gd) ---------------

## Whether the crew can take over now: while a night's open (not closing up), or once it's
## written up, on the summary page; and why not, if not.
func _crew_can_start() -> String:
	if Game.autoplay != null:
		return "The crew are running it already."
	if _night_open and not _closing_early and not _stopped:
		return ""
	if _summary != null and _summary.visible and _night_written and not _night_open:
		return ""
	return "Once the night's open, or once it's written up."


## The crew's badge, menu row and the controls they'd lock, as things are now.
func _update_crew() -> void:
	if _crew == null or _crew.badge == null:
		return
	var auto = Game.autoplay
	var running: bool = auto != null
	var why := _crew_can_start()
	_crew.show_state(running, auto.progress_text() if running else "", running and auto.stop_reason != "", why == "", why)
	_leave_button.visible = not running  # (Stop's in the same menu, and asks)
	if _summary_leave != null:
		_summary_leave.visible = not running
	if not _summary_buttons.is_empty():
		var next_night: Button = _summary_buttons[0]
		if running:
			next_night.disabled = true
			next_night.text = "The crew open the next night…" if _crew_between_nights else "The crew are running it"
		elif next_night.text != "Open for another night":
			next_night.text = "Open for another night"
			next_night.disabled = _writing_up
	_reading_toggle.disabled = running
	if _pd != null and _pd.crew_running != running:
		_pd.crew_running = running
		if running:
			_pd.close_writing()
		if _night_number > 0 and not Game.bar.is_empty():  # (not while a new bar's being made: the desk's cards look the bar's regulars up, which fills in its list)
			_pd.refresh()


## The menu's Start: the crew take over for so many nights, from now (tonight, if it's open, is
## the first; on the summary page, the next).
func _on_crew_start(nights: int) -> void:
	if _crew_can_start() != "":
		return
	var auto = Game.start_autoplay(nights)
	if auto == null:
		return
	_options_button.button_pressed = false
	var when := NightRules.clock_text(int(_clock)) if _night_open else "after night %d" % _night_number
	_stats.crew_run = {"from": auto.started_from(), "nights": auto.nights, "night": auto.progress_text(), "took_over": when}
	_show("[i][color=#%s](The crew take over for %d night%s, %s.)[/color][/i]\n\n" % [MUTED.to_html(false), auto.nights, "" if auto.nights == 1 else "s", ("at " + when) if _night_open else when])
	DebugLog.say("Autoplay", "the crew run it for %d nights, from %s (night %d)." % [auto.nights, when, _night_number])
	if _night_open:  # the PD's desk is theirs for the rest of tonight: what's left of the hand, from now
		_autopilot = Autopilot.new("%s nights %d" % [Game.bar.get("id", "new"), int(Game.bar.get("nights", 0))])
		_autopilot.plan(_pd.hand.filter(func(card): return not _pd.played.has(card)), _clock)
		_update_crew()
	else:  # tonight's written up: they open the next one
		_update_crew()
		_autoplay_open_next(auto)


## Stop's question answered: after tonight (the night played out and written up, then the bar
## back; at once if tonight's done already), or now (tonight's the player's from here).
func _on_crew_stop(how: String) -> void:
	var auto = Game.autoplay
	if auto == null:
		return
	var tonight_to_finish: bool = (_night_open or not _night_written) and not _crew_between_nights
	if how == CrewControls.STOP_AFTER and tonight_to_finish:
		auto.stop_by_hand("stopped by hand, after night %d" % _night_number)
		_stats.crew_run["stopped"] = "after tonight (asked at %s)" % NightRules.clock_text(int(_clock))
		DebugLog.say("Autoplay", "the crew stop after tonight (asked at %s, night %d)." % [NightRules.clock_text(int(_clock)), _night_number])
		_update_crew()
		return
	if _night_open:
		auto.stop_by_hand("taken over by hand at %s, night %d" % [NightRules.clock_text(int(_clock)), _night_number])
		_stats.crew_run["stopped"] = "taken over at %s" % NightRules.clock_text(int(_clock))
	else:
		auto.stop_by_hand("stopped by hand after night %d" % _night_number)
		_stats.crew_run["stopped"] = "by hand, between nights"
	_crew_hand_back(auto)


## The crew hand the bar back (their nights done, or stopped): the run's summary written, the
## controls the player's again, and tonight's desk theirs from here.
func _crew_hand_back(auto) -> void:
	if Game.autoplay != auto:
		return
	var path: String = auto.save_summary(str(Game.bar.get("name", "")), str(Game.bar.get("id", "bar")))
	var why: String = auto.stop_reason if auto.stop_reason != "" else "all %d nights done" % auto.nights
	if _stats != null:
		if not _stats.crew_run.has("stopped"):
			_stats.crew_run["stopped"] = why
		_stats.crew_run["handed_back"] = NightRules.clock_text(int(_clock)) if _night_open else "after night %d" % _night_number
	_show("[i][color=#%s](The crew hand the bar back: %s.)[/color][/i]\n\n" % [MUTED.to_html(false), _esc(why)])
	DebugLog.say("Autoplay", "the crew hand the bar back (%s, %d of %d nights played). Summary: %s" % [why, auto.played.size(), auto.nights, ProjectSettings.globalize_path(path)])
	Game.end_autoplay()
	_autopilot = null
	_crew_between_nights = false
	_update_crew()


func _update_clock_label() -> void:
	_update_crew()
	if _night_number == 0:
		return
	_moment_label.text = "Night %d  ·  %s  ·  %s %s  ·  %s  ·  %s" % [_night_number, ShowSeasons.short_label(_show_place), _night_day, _short_date(), NightRules.clock_text(int(_clock)), _night_weather]
	if _night_open and _time_speed > 1.05:
		_moment_label.text += "  ·  ▶▶ %.0f×" % _time_speed  # time's running fast: the tent's quiet


# --- What the owner does next ------------------------------------------------

## What the owner's voice does next, most urgent first: greet someone new; settle up with
## someone whose time is up; otherwise chat with whoever's been left alone longest (or, now
## and then, let customers chat to each other). Each starts a task that runs (with awaits)
## until it's done. (Carrying food over doesn't need the voice: see _carry_dish.)
func _next_task() -> void:
	# A card's just happened to someone (a text, a call, the ex walking past): they get the next
	# turn, before a greeting or a chat (19 Nov: 0 of 5 texts taken up; a newcomer arrived, and by
	# the time the owner turned back, the moment had gone).
	var struck := _struck_by_card()
	if struck != null:
		struck.card_turn = true
		_stats.record_card_turn()
		_talk(struck)
		return
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
	chance *= _camera.chat_share()  # (the camera on the owner: the turns are theirs)
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
	return not _waiting.is_empty() and _free_seats().size() >= _seats_for_next() and not _last_orders and not _closing_early


## Stools the next one waiting needs: two for the first of a pair who came in together (they wait
## for two), one for anyone else.
func _seats_for_next() -> int:
	if _waiting_group.is_empty() or _waiting_group[0].is_empty():
		return 1
	return 2 if int(_waiting_group[0].get("called", 0)) == 0 else 1


# --- Coming in together ------------------------------------------------------------------

## Who the second of a pair came in with, for inventing them: {"kind", "name", "gender", "age_range"}.
func _with_whom(group: Dictionary, first_one: Guest) -> Dictionary:
	return {"kind": str(group["kind"]), "name": str(first_one.customer["name"]), "gender": str(first_one.customer.get("gender", "")),
		"age_range": str(first_one.customer.get("look", {}).get("age_range", "30s"))}


## The second of a pair has sat down: both their conversations know they came in together.
func _came_in_together(guest: Guest, group: Dictionary) -> void:
	var first_one := _guest_named(str(group["names"][0]))
	var kind := str(group["kind"])
	guest.transcript.append({"action": "%s came in with %s: %s." % [guest.customer["name"], group["names"][0], Groups.info(kind)["text"]]})
	if first_one != null:
		first_one.transcript.append({"action": "%s came in with %s, their %s." % [first_one.customer["name"], guest.customer["name"], Groups.is_to(kind)]})
	_night_groups.append({"kind": kind, "names": group["names"].duplicate()})
	DebugLog.say("Together", "%s and %s are in (%s)" % [group["names"][0], guest.customer["name"], kind])


## What someone pays as they leave: their own bill, or, for two who came in together, both
## bills or none (one pays for both, or they fight over it and kawi-bawi-bo decides: Groups),
## decided as the first of them goes. Said in the transcript, the fight on TV.
func _bill_for(guest: Guest) -> int:
	var own := Orders.bill(guest.order)
	var group := guest.together
	if not group.is_empty() and group["names"].size() < 2:  # (the other never got a stool: they go too, and each pays their own)
		_drop_waiting(group)
		return own
	if group.is_empty() or str(group["pay"]) == "split":
		if not group.is_empty() and not bool(group["settled"]):
			group["settled"] = true
			_stats.record_group_bill("split")
			_narrate("%s and %s split the bill." % [group["names"][0], group["names"][-1]])
		return own
	var names: Array = group["names"]
	var other: Guest = null
	for each in names:
		if each != str(guest.customer["name"]):
			other = _guest_named(each)
	if not bool(group["settled"]):
		group["settled"] = true
		var payer := Groups.payer(str(group["kind"]), randf())
		if str(group["pay"]) == "fight":
			payer = Groups.bill_fight_loser(randf())
			_narrate("%s and %s both grab for the bill. The bill fight! Kawi, bawi, bo... %s loses, and pays for both." % [names[0], names[-1], names[payer]])
			_event("bill_fight", {"name": str(names[0]), "friend": str(names[-1]), "loser": str(names[payer])}, guest.node)
		else:
			_narrate("%s pays for both of them." % names[payer])
		group["payer"] = str(names[payer])
		_stats.record_group_bill(str(group["pay"]))
		DebugLog.say("Together", "%s and %s's bill: %s, %s pays" % [names[0], names[-1], group["pay"], names[payer]])
	if other != null:
		other.stay_left = minf(other.stay_left, 0.0)  # (they go together)
	if str(group["payer"]) == str(guest.customer["name"]):  # (theirs, and the other's: carried from when they went, or still to come)
		group["payer_paid"] = true
		var theirs := 0 if other == null or bool(group.get("carried_for", false)) else Orders.bill(other.order)
		return own + int(group.get("carried", 0)) + theirs
	if not bool(group.get("payer_paid", false)):
		group["carried"] = int(group.get("carried", 0)) + own  # (the payer pays it as they go)
		group["carried_for"] = true  # (19 Nov, on GitHub: counted again while they were still at the counter)
	return 0


## Whoever's still waiting with someone who's going (they came in together) goes with them.
func _drop_waiting(group: Dictionary) -> void:
	for i in range(_waiting_group.size() - 1, -1, -1):
		if _waiting_group[i] == group and not _waiting_group[i].is_empty():
			_waiting.remove_at(i)
			_waiting_who.remove_at(i)
			_waiting_group.remove_at(i)
			_narrate("Their friend, still waiting at the tarp for a stool, goes with them.")


## At closing: two who came in together tonight and are both regulars now have a bond that says
## so (how they know each other, their names, close if they're close, and that they come in
## together).
func _bond_tonights_pairs() -> void:
	for pair in _night_groups:
		var ids: Array = pair["names"].map(func(n): return str(_regular_named(str(n)).get("id", "")))
		if ids.size() < 2 or ids.has(""):
			continue
		var bond := Bonds.between(Game.bar, ids[0], ids[1], "came in together (%s)" % Groups.is_to(str(pair["kind"])))
		Bonds.meet(bond, _night_number)
		Bonds.learn_name(bond, ids[0])
		Bonds.learn_name(bond, ids[1])
		bond["together"] = true
		if bool(Groups.info(str(pair["kind"])).get("close", false)):
			bond["close"] = true
		DebugLog.say("Together", "%s and %s, both regulars, come in together now" % [pair["names"][0], pair["names"][1]])


func _regular_named(who: String) -> Dictionary:
	for regular in RegularsTonight.all(Game.bar):
		if str(regular["name"]) == who:
			return regular
	return {}


# --- Closeness paying off ---------------------------------------------------------------

const SAVED_FOR_THEM := 0.35  # the chance the owner's kept something back for a close regular
const SAVED_DISH := "odeng"  # ...the last of the odeng, from the pot


## A stool for someone coming in: a regular takes one next to a friend at the counter if they
## can (the closest friend first), anyone else any free one.
func _seat_for(regular: Dictionary, group: Dictionary = {}, with: Guest = null) -> int:
	var free := _free_seats()
	if with != null:  # (the second of a pair: next to the first, if there's room)
		for seat in [with.seat + 1, with.seat - 1]:
			if free.has(seat):
				return seat
		return free.pick_random()
	if not group.is_empty():  # (the first of a pair: a stool with a free one beside it)
		var pairs: Array = free.filter(func(s): return free.has(s + 1) or free.has(s - 1))
		if not pairs.is_empty():
			return pairs.pick_random()
	if not regular.is_empty():
		var friends: Array = _guests.filter(func(g): return str(g.customer.get("regular_id", "")) != "" and Bonds.level(Bonds.find(Game.bar, str(regular["id"]), str(g.customer["regular_id"]))) >= 2)
		friends.sort_custom(func(x, y): return Bonds.level(Bonds.find(Game.bar, str(regular["id"]), str(x.customer["regular_id"]))) > Bonds.level(Bonds.find(Game.bar, str(regular["id"]), str(y.customer["regular_id"]))))
		for friend in friends:
			for seat in [friend.seat - 1, friend.seat + 1]:
				if free.has(seat):
					_stats.closeness["sat_by_a_friend"] = int(_stats.closeness.get("sat_by_a_friend", 0)) + 1
					DebugLog.say("Regulars", "%s takes the stool next to %s" % [regular["name"], friend.customer["name"]])
					return seat
	return free.pick_random()


## A regular coming in to a friend at the counter: the friend waves them over (no words: the
## game's), and both their conversations know.
func _waved_over(guest: Guest) -> void:
	var id := str(guest.customer.get("regular_id", ""))
	if id == "":
		return
	for friend in _guests:
		var theirs := str(friend.customer.get("regular_id", ""))
		var bond := Bonds.find(Game.bar, id, theirs)
		if friend == guest or theirs == "" or Bonds.level(bond) < 2 or _came_together(guest, friend):  # (no waving over someone you came in with)
			continue
		var called := Names.given_name(str(guest.customer["name"])) if Bonds.knows_name(bond, theirs) else "them"
		_narrate("%s spots %s ducking in and waves %s over." % [friend.customer["name"], guest.customer["name"], called])
		friend.transcript.append({"action": "%s spots %s coming in and waves them over." % [friend.customer["name"], guest.customer["name"]]})
		guest.transcript.append({"action": "%s, a friend from the counter, waves you over as you come in." % friend.customer["name"]})
		_stats.closeness["waved_over"] = int(_stats.closeness.get("waved_over", 0)) + 1
		return


## A close regular's first order: now and then the owner's kept something back for them (the last
## of the odeng), on the house: on their table, not their bill.
func _saved_for_them(guest: Guest) -> void:
	var id := str(guest.customer.get("regular_id", ""))
	if id == "" or Bonds.level(Bonds.with_owner(Game.bar, id)) < 3 or Menu.find(SAVED_DISH).is_empty() or _scenery_dice.randf() >= SAVED_FOR_THEM:
		return
	_add_dish(guest, SAVED_DISH)
	guest.served.append(SAVED_DISH)
	guest.version += 1
	var given := Names.given_name(str(guest.customer["name"]))
	_narrate("%s slides a skewer of odeng over to %s: the last of the pot, kept back for them. On the house." % [_owner_display(), given])
	guest.transcript.append({"action": "%s slides you a skewer of odeng, the last of the pot, kept back just for you: on the house." % _owner["name"]})
	_stats.closeness["saved_for_them"] = int(_stats.closeness.get("saved_for_them", 0)) + 1
	_event("saved_for_them", {"name": str(guest.customer["name"])}, guest.node)


func _free_seats() -> Array:
	var free := range(NightRules.SEATS)
	for guest in _guests:
		free.erase(guest.seat)
	return free


## Someone whose time is up and isn't waiting for any food.
func _ready_to_pay() -> Guest:
	for guest in _guests:
		if guest.time_up() and _kitchen_part.food_coming(guest).is_empty():
			if _cat_keeps(guest):
				continue
			return guest
	return null


## Their time's up, but the cat's asleep on their lap: they can't get up yet (once a visit, not
## at last orders or closing up). A little longer, a moment for their next line, and the cat
## moves on before then. Whether it kept them.
func _cat_keeps(guest: Guest) -> bool:
	if _cat.is_empty() or _cat_with != guest or _cat_spot != "lap" or guest.kept_by_cat or _last_orders or _closing_early:
		return false
	guest.kept_by_cat = true
	guest.stay_left = maxf(guest.stay_left, 0.0) + CatRules.LAP_KEEPS_MINUTES
	var cat_name := str(_cat["name"])
	var named := str(guest.customer["name"])
	guest.cat_moment = CatRules.LAP_MOMENT.replace("{cat}", cat_name)
	var text := CatRules.LAP_TEXT.replace("{name}", named).replace("{cat}", cat_name)
	_narrate(text)
	guest.transcript.append({"action": text})
	guest.version += 1
	_cat_next = minf(_cat_next, CatRules.LAP_KEEPS_MINUTES * 0.75)  # (it gets up before they have to)
	_event("cat_kept", {"cat": cat_name, "name": named}, guest.node)
	DebugLog.say("Cat", "%s keeps %s on their stool a little longer" % [cat_name, named])
	return true


## Whoever's waited longest for the owner. People here to talk get seen to sooner.
func _left_alone_longest() -> Guest:
	var best: Guest = null
	for guest in _guests:
		if not guest.time_up() and (best == null or _neediness(guest) < _neediness(best)):
			best = guest
	return best


## Someone a card's just happened to who hasn't had the owner's turn for it yet, and isn't in a
## chat (a chat gives it them itself), or null.
func _struck_by_card() -> Guest:
	for guest in _guests:
		if guest.plant_moment != "" and not guest.card_turn and not guest.time_up() and _chat_of(guest) == null:
			return guest
	return null


## How far ahead of everyone else someone a card's just happened to is, for the owner's next
## turn: first, whatever else is waiting (18 Nov: a text that changed everything, on a busy night,
## and she never spoke again; a head start of 3 turns wasn't one).
const PLANT_PULL := 1000


func _neediness(guest: Guest) -> int:
	var base := guest.attended - (3 if guest.company == "owner" else 0)
	if guest.plant_moment != "":
		base -= PLANT_PULL  # (something's just happened to them: the owner turns to them next)
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
			_narrate("%s turns back to %s%s." % [_owner_display(), guest.customer["name"], ", from the stove" if _at_stove() else ""])
			guest.transcript.append({"action": ("%s turns back to you from the stove after seeing to other customers." if _at_stove() else "%s comes back over after seeing to other customers.") % _owner["name"]})
		else:
			_narrate("%s turns to %s%s." % [_owner_display(), guest.customer["name"], ", from the stove" if _at_stove() else ""])
	_attending = guest
	_attention += 1
	guest.attended = _attention
	_place_owner()
	_from_the_stove(guest)


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
		_stats_view.on_diary = _open_diary
	_stats_view.refresh(_stats, _guests.size(), _kitchen.size() + _ready_dishes.size(), _night_number, _here_text, _show_text())


## Writes tonight's log (stats/ in the user data folder).
func _save_stats(finished: bool) -> void:
	var context := {
		"bar": str(Game.bar.get("name", "")), "night": _night_number, "day": _night_day, "weather": _night_weather,
		"finished": finished, "clock": NightRules.clock_text(int(_clock)),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"ai_backend": str(_ai.settings.get("backend", "")), "ai_model": str(_ai.settings.get("model", "")),
		"offline": _ai.offline, "time_speeds": NightRules.TIME_SPEEDS, "reading_pauses": _reading_toggle.button_pressed,
		"autoplay": Game.autoplay.progress_text() if Game.autoplay != null else "",
	}
	var path := _stats.save(context, str(Game.bar.get("id", "bar")), _night_number)
	if path != "" and Hooks.print_paths:
		DebugLog.say("Night stats saved", ProjectSettings.globalize_path(path))
	_finish_transcript(context)


## Adds to the transcript on screen and, during a night, to tonight's transcript file (before
## it, kept for the top of it: see StoryKeeper).
## pin: a line said (see _said_line), shown with its 📌: only on screen, not in the transcript file.
func _show(bbcode: String, pin: int = -1) -> void:
	var chunk := {"text": Glossary.explain_hangul(bbcode), "pin": pin, "at": int(_clock) if _night_number > 0 else -1}  # (any Hangul explains itself on hover)
	_transcript_view.add(chunk)
	_story.record(bbcode)


## A line said, kept so the PD can pin it for the episode (see _on_transcript_link). Its id.
func _said_line(speaker: String, text: String) -> int:
	_said.append({"id": _said.size(), "speaker": speaker, "text": text, "at": int(_clock), "night": _night_number})
	if _autopilot != null and _night_open and _autopilot.pins_it():
		_on_transcript_link.call_deferred("pin:%d" % (_said.size() - 1))  # (once it's on screen)
	return _said.size() - 1


## A chunk of the transcript as shown: a line said ends in its 📌 (a link), and once it's
## pinned the line's tinted and its 📌 lit, so you can see what's kept.
func _render(chunk: Dictionary) -> String:
	var pin := int(chunk["pin"])
	if pin < 0:
		return str(chunk["text"])
	var pinned := _pd != null and _pd.pins.any(func(p): return int(p["id"]) == pin)
	var body := str(chunk["text"]).trim_suffix("\n\n")
	if pinned:
		body = "[bgcolor=#%s]%s[/bgcolor]" % [Color(CAMERA_RED, 0.22).to_html(true), body]
	var tip := "Pinned for the episode: click to let it go" if pinned else "Pin this line for the episode: three a night, for \"Previously on…\" (a fourth drops the oldest; click again to unpin)"
	return "%s  [url=pin:%d][color=#%s]%s[/color][/url]\n\n" % [body, pin, (CAMERA_RED if pinned else MUTED.darkened(0.25)).to_html(false), Text.hint(tip, "📌")]


## The transcript drawn again from its chunks (a pin's changed how a line looks), keeping
## where it's scrolled to (unless it was following the latest line).
func _redraw_transcript() -> void:
	_transcript_view.redraw()


## The transcript's toolbar used (transcript_view.gd): counted in the stats, and logged.
func _on_transcript_used(what: String, detail: String) -> void:
	DebugLog.say("Transcript", "%s %s" % [what.replace("_", " "), detail])
	if _stats != null:
		_stats.note_transcript(what, detail)


## A link clicked in the transcript: a line's 📌 pins it (or unpins it) for the episode.
func _on_transcript_link(meta: Variant) -> void:
	var link := str(meta)
	if link == "edit":
		_step_in()
		return
	if not link.begins_with("pin:") or _pd == null:
		return
	var k := int(link.trim_prefix("pin:"))
	if k < 0 or k >= _said.size() or int(_said[k]["night"]) != _night_number:
		return  # (not a line, or one from an earlier night: the episode's tonight's)
	var happened := _pd.pin(_said[k])
	_redraw_transcript()
	var line: Dictionary = happened.get("pinned", happened.get("unpinned", {}))
	var said := "%s: «%s»" % [line["speaker"], Text.shorten(str(line["text"]), 80)]
	if happened.has("pinned"):
		var dropped: Dictionary = happened.get("dropped", {})
		_show("[i][color=#%s]📌 Pinned for the episode: %s%s[/color][/i]\n\n" % [CAMERA_RED.to_html(false), _esc(said),
			(_esc(" (%s's line drops off: three a night)" % dropped["speaker"])) if not dropped.is_empty() else ""])
	else:
		_show("[i][color=#%s]📌 Unpinned: %s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(said)])


## The night's quote, for the summary and the diary: the first line the PD pinned, or (with
## none pinned) the longest thing a customer said.
func _night_quote() -> Dictionary:
	if _pd != null and not _pd.pins.is_empty():
		return {"speaker": str(_pd.pins[0]["speaker"]), "text": str(_pd.pins[0]["text"])}
	return NightRules.memorable_line(_night_lines)


## Tonight's transcript file, written as the night goes (see StoryKeeper): a header saying which
## bar and night, and with what AI settings, how the bar opened, then everything said and done.
func _start_transcript() -> void:
	var model := " / " + str(_ai.settings.get("model", "")) if not _ai.offline else ""
	var path := _story.start(str(Game.bar.get("id", "bar")), _night_number, [
		"KTBT transcript: %s, night %d" % [Game.bar.get("name", ""), _night_number],
		"%s, %s. Started %s." % [_night_day, _night_weather, Time.get_datetime_string_from_system(false, true)],
		"AI: %s%s (%s), reading pauses %s%s." % [_ai.settings.get("backend", ""), model, "offline" if _ai.offline else "online",
			"on" if _reading_toggle.button_pressed else "off", "; autoplay, " + Game.autoplay.progress_text() if Game.autoplay != null else ""],
	])
	_recap_said = ""
	var debug_path := DebugLog.start_night(str(Game.bar.get("id", "bar")), _night_number)  # (tonight's notes: debug_log.gd)
	if path != "" and Hooks.print_paths:
		DebugLog.say("Night transcript", ProjectSettings.globalize_path(path))
	if debug_path != "" and Hooks.print_paths:
		DebugLog.say("Debug log", ProjectSettings.globalize_path(debug_path))


## The end of the night (or the bar closed early): how it ended, and the night's stats.
func _finish_transcript(context: Dictionary) -> void:
	_story.finish(bool(context["finished"]), str(context["clock"]), _stats.panel_text(_guests.size(), _kitchen.size() + _ready_dishes.size()).replace("[b]", "").replace("[/b]", ""))


## Esc opens or closes the Options panel; 1, 2 and 3 pick the edit's spin while it's up.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and _setup_open and not _setting_up:
		_open_setup()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and _step_in_open and not _editing and Game.autoplay == null:
		_step_in()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo and _pd != null and _pd.edit_up() and key.keycode >= KEY_1 and key.keycode <= KEY_3 and Game.autoplay == null:
		_pd.air_edit(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_options_button.button_pressed = not _options_button.button_pressed  # (the menu)


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
	_owner_gesture("wave", 1.5)  # (come in, come in)
	var turned_up: float = _waiting.pop_front()
	var regular := _regular(str(_waiting_who.pop_front()) if not _waiting_who.is_empty() else "")
	var group: Dictionary = _waiting_group.pop_front() if not _waiting_group.is_empty() else {}
	# Two who came in together: the other one's off the queue too, invented before either walks
	# in, so they come in side by side and sit down together (19 Nov: the second came in a whole
	# order later, and was easy to miss).
	var other_regular := {}
	var pair := false
	if not group.is_empty():
		group["called"] = 2
		for i in _waiting_group.size():
			if _waiting_group[i] == group:
				other_regular = _regular(str(_waiting_who[i]))
				_waiting.remove_at(i)
				_waiting_who.remove_at(i)
				_waiting_group.remove_at(i)
				pair = true
				break
	_greeting = true
	_greeting_regular = str(regular.get("id", ""))
	_stats.greet_waits.append(_clock - turned_up)  # how long they waited for the owner
	_show("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	var first := await _comes_in(regular, group if pair else {}, null)
	if first == null:
		return
	var second: Guest = null
	if pair:
		second = await _comes_in(other_regular, group, first)
		if _closed():
			return
	var from_x := _random_offscreen_x()
	_sits_down(first, from_x, null)
	if second != null:
		_sits_down(second, from_x + (-PERSON_WIDTH if from_x > SEAT_X[first.seat] else PERSON_WIDTH) * 0.8, first)  # (a step behind, the same way)
		_narrate("%s and %s: %s." % [first.customer["name"], second.customer["name"], Groups.info(str(group["kind"]))["text"]])
	elif not group.is_empty():
		group["names"] = [str(first.customer["name"])]  # (the other never came in after all)
	_greeting = false
	_greeting_regular = ""
	_attend(first, false)
	await _takes_order(first, turned_up)
	if second != null and not _closed() and _guests.has(second):
		await _takes_order(second, turned_up)
	if _closed():
		return
	# On a quiet night, a first word with the owner straight away. When it's busy, that
	# waits until the owner has a moment.
	if not first.quick_greeting and _guests.has(first):
		await _converse(first, 1, false)
	_task_done()


## Someone at the tarp, before they sit down: a regular (known, not reinvented) or someone new
## (the AI invents them; with: the one they came in with, for the second of a pair). Their
## Guest, not yet seated (null if nobody came in after all, or the bar closed: the greeting's
## finished either way).
func _comes_in(regular: Dictionary, group: Dictionary, with: Guest) -> Guest:
	if not regular.is_empty() and _regular_in(str(regular["id"]), false):  # (19 Nov: Lee Ho-jin got talking to Lee Ho-jin)
		DebugLog.say("Regulars", "%s's already at the counter: someone new instead" % str(regular["id"]))
		regular = {}
	var guest := Guest.new()
	guest.quick_greeting = People.quick_greeting(_waiting.size(), _guests.size()) or not group.is_empty()  # (a pair: both seen to quickly, then they talk to each other)
	guest.together = group
	guest.arrived = NightRules.clock_text(int(_clock))
	guest.arrived_minutes = int(_clock)
	guest.moment = {"day": _night_day, "time": guest.arrived, "weather": _night_weather, "date": _date_words()}
	var customer := {}
	var look := {}
	if not regular.is_empty():
		# A regular: they're known, so not reinvented.
		if with == null:
			_narrate("%s. %s" % [guest.arrived, _back_text(regular)])
		else:
			_narrate("%s comes in with them." % regular["name"])
		customer = await _regular_tonight(regular, guest)
		if _closed():  # (the bar closed while it was waiting)
			return null
		look = customer["look"]
		if str(regular.get("id", "")) == _planted_regular:  # (the PD rang them: they know why they're here)
			guest.plant_moment = Plants.moment("regular_in", str(regular["name"]), "", "", str(regular.get("gender", "")))
			guest.plant_card = "regular_in"
			guest.plant_happened = Plants.happened("regular_in", str(regular["name"]), "", "", str(regular.get("gender", "")))
			_planted_regular = ""
			_narrate("(%s)" % guest.plant_happened)
	else:
		if group.is_empty():
			_narrate("%s. Someone ducks under the tarp." % guest.arrived)
		elif with == null:
			_narrate("%s. Two people duck under the tarp together." % guest.arrived)
		customer = _take_prepared() if group.is_empty() else {}  # (one invented ahead didn't come with anyone)
		if customer.is_empty():
			customer = await _new_customer(guest.arrived, false, _with_whom(group, with) if with != null else {})
			if _closed():  # (the bar closed while it was waiting)
				return null
		look = customer.get("look", {})
	if customer.is_empty():
		if with == null:
			_narrate("Nobody came in after all. (%s)" % _ai.last_error)
			_greeting = false
			_greeting_regular = ""
			_task_done()
		else:
			_narrate("(%s's friend changes their mind at the tarp: %s.)" % [with.customer["name"], _ai.last_error])
		return null
	customer["look"] = look
	guest.customer = customer
	guest.regular = regular
	return guest


## Someone sits down: their stool (the second of a pair next to the first), how long they'll
## stay (a pair leaves together), drawn walking in from from_x, and everyone told.
func _sits_down(guest: Guest, from_x: float, with: Guest) -> void:
	var customer := guest.customer
	var look: Dictionary = customer.get("look", {})
	var regular := guest.regular
	var group := guest.together
	guest.seat = _seat_for(regular, group, with)
	_names_tonight.append(str(customer["name"]))
	if not group.is_empty():
		group["names"].append(str(customer["name"]))
		group["seated"] = int(group["seated"]) + 1
	if not _jobs_tonight.has(str(customer["job"])):
		_jobs_tonight.append(str(customer["job"]))
	_looks_tonight.append(str(customer["appearance"]))
	_voices_tonight[str(customer["name"])] = Socials.voice(customer)
	# The game decides their mood for company and how long they'll stay.
	guest.company = Hooks.company_override if Hooks.company_override != "" else People.company(randf())
	customer["company"] = guest.company
	var stay := Hooks.stay_minutes_override if Hooks.stay_minutes_override >= 0 else People.stay_minutes(guest.company, randf())
	guest.stay_left = 0.0 if _last_orders else float(stay)
	if with != null:
		guest.stay_left = with.stay_left  # (they'll leave together)
	guest.color = _free_color()
	guest.drinks_row = _drinks_rows[guest.seat]
	guest.food_row = _food_rows[guest.seat]
	guest.node = _people_view.new_person(_stage, Vector2(from_x, CUSTOMER_Y), guest.color)
	guest.node.name = "Customer%d" % guest.seat
	_people_view.dress(guest.node, look)
	(guest.node.get_node("Tag") as Label).text = _name_label(customer)
	_guests.append(guest)
	if with != null:
		_came_in_together(guest, group)
	_refresh_tags()
	_ambience.play("scrape", 1.0, 1.0)  # pulling up a stool
	_update_info()
	var friends_in: Array = _guests.filter(func(g): return g != guest and not regular.is_empty() and not _friend(guest, g).is_empty())
	var sat := {"name": str(customer["name"]), "gender": str(customer.get("gender", "")), "job": str(customer.get("job", "")),
		"age_range": str(look.get("age_range", "")), "company": guest.company,
		"seat": guest.seat, "seated": _guests.size(), "minutes": int(_clock),
		"regular": "" if regular.is_empty() else ("founding" if bool(regular.get("founding", false)) else "regular"),
		"friend": str(friends_in[0].customer["name"]) if not friends_in.is_empty() else "",
		"visit": int(regular.get("visits", 0)) + 1, "years": str(regular.get("since", "")),
		"together": str(group["kind"]) if with != null else "", "with": str(with.customer["name"]) if with != null else ""}
	# (The rush is about the tent, not them: its caption goes in the middle.)
	var at_stool := Vector2(SEAT_X[guest.seat], CUSTOMER_Y - 60)  # (they're still walking to it)
	var rushing: bool = regular.is_empty() and not _rush_shown and _guests.size() >= Captions.RUSH_SEATED
	_event("sat_down", sat, null, Vector2(-1, -1) if rushing else at_stool)
	_welcome_at_door(guest)
	_waved_over(guest)
	if regular.is_empty():  # a regular's look is known by now
		_narrate(Text.as_sentence(str(customer["appearance"])))
	_walk_in(guest)  # the owner doesn't wait for them to sit down: the AI's already on their order


## They say hello and order in one line, so what they say matches what they get, and it's
## served. The game decides who's extra hungry (two mains) or having a rough night (two drinks),
## and whether (and when) they'll order more later.
func _takes_order(guest: Guest, turned_up: float) -> void:
	var customer := guest.customer
	var regular := guest.regular
	_attend(guest, false)
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
	_saved_for_them(guest)
	_stats.serve_waits.append(_clock - turned_up)
	_event("greeted", {"name": str(guest.customer["name"]), "quick": guest.quick_greeting}, _owner_node)
	# Will they order more partway through? The game decides how often (often not, sometimes
	# once, rarely twice) and on which of their turns, spaced out by the rules. If they leave
	# before a turn comes round, that order never happens.
	var extra_count := Orders.extra_order_count(randf())
	guest.extra_turns = Orders.extra_order_turns(randi_range(3, 5) + extra_count, extra_count)


## Someone new: the AI invents them, in two steps (name and gender, then the rest), to fit the
## look and age range the game decides. {} if the AI couldn't.
## Invents a new customer arriving at this time (as text): {} if the AI can't. ahead: being
## invented before they arrive (see _prepare_customer), so nothing's shown while it thinks.
func _new_customer(arrived: String, ahead: bool = false, with: Dictionary = {}) -> Dictionary:
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
	if not with.is_empty():  # (came in with someone: the game decides what goes with them)
		gender = Groups.second_gender(str(with["kind"]), str(with["gender"]), randf(), randf())
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
		var age_range := Looks.pick_age_range(randf()) if with.is_empty() else Groups.second_age_range(str(with["kind"]), str(with["age_range"]), randf())
		look = Looks.pick_look(str(who["gender"]), age_range, _weather_kind)
		customer = await _ai.ask_json(
			Prompts.customer_messages(_night_day, arrived, _night_weather, false, str(who["name"]), str(who["gender"]), _jobs_tonight, _looks_tonight.slice(-VARIETY_LOOKS), look,
				Groups.note(str(with["kind"]), str(with["name"])) if not with.is_empty() else ""),
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
	if not now.is_empty():  # (over to their stool to pour or set it down, then back: PLAN, "the owner works the stove")
		_errand(guest, "pour" if now.any(func(id): return Menu.find(id).get("kind", "") == "drink") else "serve", _scaled(ERRAND_SECONDS))
	if now.any(func(id): return Menu.find(id).get("kind", "") == "drink"):
		_owner_gesture("pour", 1.0)  # (the bottle tipped over their glass)
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
	_errand(guest, "carry")
	_owner_gesture("carry", _scaled(0.8))  # (the bowl held out, over to them)
	await _pause(_scaled(0.4))
	if _stopped or not _guests.has(guest):
		_errand_done("carry")
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
	_errand_done("carry")  # (back to the stove, or to whoever they were talking to)
	_carrying = false


## Someone's time is up: they say goodbye, the game works out the bill, the bar is saved,
## and they leave.
func _settle_up(guest: Guest) -> void:
	_owner_working = true
	_errand(guest, "settle")  # (over for the money and the goodbye)
	_attend(guest, false)
	await _goodbye(guest)
	await _wait_for_reader()  # let their goodbye sink in before they go
	if _closed():
		return  # the bar was closed while they said goodbye: nothing to record it in
	var bill := _bill_for(guest)
	SaveStore.record_visit(Game.bar, {
		"customer": guest.customer["name"], "job": guest.customer["job"],
		"day": guest.moment["day"], "time": guest.arrived, "weather": guest.moment["weather"],
		"order": guest.order.duplicate(), "bill": bill,
		"when": int(Time.get_unix_time_from_system()),
	})
	Game.save()
	_night_visits += 1
	var standing := ""
	var known := _regular(str(guest.customer.get("regular_id", "")))
	if not known.is_empty():
		standing = "a founding regular" if bool(known.get("founding", false)) else "a regular"
	_stats.owner_lines_each.append(guest.transcript.filter(func(e): return e.has("text")).size())
	_customer = guest.customer
	_order = guest.order.duplicate()
	_narrate("%s pays %s and heads back out into the night." % [guest.customer["name"], Menu.format_won(bill)])
	_goodbye_at_door(guest)
	_errand_done("settle")
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
	if (guest.cat_moment != "" or _owner_cat_moment != "") and not guest.cat_talk_done:
		guest.topic = "the_cat"
		guest.cat_talk_done = true
	_stats.record_topic(guest.topic, false)
	guest.food_news = false
	# When it's busy, a single exchange, so the voice comes round to everyone (and leaves room
	# for customers to chat) sooner.
	await _converse(guest, 1 if _guests.size() >= People.BUSY_COUNTER else randi_range(1, 2), true)
	# Every few lines, was anything a big moment? (A TV reaction.)
	if _guests.has(guest) and guest.line - guest.reacted_at >= Captions.REACT_EVERY:
		guest.reacted_at = guest.line
		var spoken: Array = guest.transcript.filter(func(e): return e.has("text")).slice(-Captions.REACT_EVERY)
		await _react(spoken, [str(_owner["name"]), str(guest.customer["name"])], guest.order, guest.topic)
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


## Something's just happened to them (a PD's card: a phone ringing, the interview's question),
## and it's the owner's turn: they speak first, so their line is what it's about (night 27: the
## owner asked about work in between, and the interview answer answered her instead). Returns
## whether their turn came first (their line counter moves on past the owner's).
func _their_turn_first(guest: Guest) -> bool:
	if guest.line > 0 and guest.line % 2 == 0 and guest.plant_moment != "":
		guest.line += 1
		return true
	return false


## The next line of a guest's conversation with the owner (or a later order, when it's
## their turn for one).
func _next_line(guest: Guest) -> void:
	var i := guest.line
	guest.moment["time"] = NightRules.clock_text(int(_clock))
	if guest.extra_turns.has(i) and not _last_orders and guest.plant_moment != "":
		guest.extra_turns.erase(i)  # (something's just happened to them: that comes first, the order a turn later)
		guest.extra_turns.append(i + 2)
	if guest.extra_turns.has(i) and not _last_orders:
		var ordered: bool = await _extra_order(guest)
		if ordered:
			guest.line += 1
			return
	if _their_turn_first(guest):
		i = guest.line
	var owner_speaks := i % 2 == 0
	_plant_in(guest.transcript, guest)
	var given := Conversation.owner_line(_night, guest, i, _late(), Looks.wet(_weather_kind))  # (what this line's given: see Conversation)
	var direction := str(given["direction"])
	if owner_speaks:
		direction = _owner_on_camera(direction, guest)  # (the camera's on the owner: they notice, or show a little more of themselves)
	var hint := str(given["hint"])  # what kind of hint this line was given, for the stats
	if not owner_speaks:
		direction = (direction + " " + _who_you_know(guest, [])).strip_edges()  # (what they've said about themselves before)
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
	_log_card_line(_owner_label() if owner_speaks else str(guest.customer["name"]), hint, _stats.record_hint(hint, str(reply["line"]), _tent_cat.tells()), str(reply["line"]),
		"to %s" % (guest.customer["name"] if owner_speaks else _owner_label()))
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


## Who speaks next in a chat (voices: the names in it): someone something's just happened to (a
## PD's card), even if they spoke last (18 Nov: a text came, the other one answered, and the
## moment was lost); otherwise not whoever spoke last (the first line: the one who started it).
func _chat_speaker(chat: Chat, voices: Array, first: bool) -> String:
	var happened_to: Array = voices.filter(func(v): return _guest_named(v) != null and _guest_named(v).plant_moment != "")
	if not happened_to.is_empty():
		return str(happened_to[0])
	return str(voices[0]) if first else str(voices.filter(func(v): return v != chat.last_speaker).pick_random())


## Someone with something still on their mind (a PD's card that lingers, or a cue card) starts
## or joins a chat: it comes with them (17 Nov: the ex walked past, Yeon-mi got talking to
## Joon-hyung, and two lines on they were arguing about ramyeon).
func _bring_into_chat(chat: Chat, people: Array) -> void:
	for person in people:
		if person.pd_topic_lines > 0 and chat.pd_topic_lines == 0:
			chat.pd_topic = person.pd_topic
			chat.pd_topic_lines = person.pd_topic_lines
		person.pd_topic_lines = 0


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
		var together := _came_together(a, b)
		_narrate(("%s turns to %s, who they came in with." if together else "%s gets talking to %s.") % [a.customer["name"], b.customer["name"]])
		_bring_into_chat(chat, [a, b])
		var quiet := bool(spell.get("drawn_in", false))  # (b keeps to themselves: a turns to them anyway)
		_event("chat_started", {"name": str(a.customer["name"]), "friend": str(b.customer["name"]), "drawn_in": quiet}, a.node)
		if together:
			chat.transcript.append({"action": "%s and %s came in together (%s), and talk as people who know each other well do." % [a.customer["name"], b.customer["name"], Groups.info(str(a.together["kind"]))["text"]]})
		else:
			chat.transcript.append({"action": ("%s turns to %s, a stranger a few stools along who's been keeping to themselves, and starts a conversation." if quiet else "%s turns to %s, a stranger a few stools along, and starts a conversation.") % [a.customer["name"], b.customer["name"]]})
	elif chat != null:
		_event("chat_continued", {"people": chat.people.filter(func(g): return g != joiner).map(func(g): return str(g.customer["name"]))})
		if joiner != null:
			_narrate("%s joins in." % joiner.customer["name"])
			_bring_into_chat(chat, [joiner])
			_event("joined_chat", {"gender": str(joiner.customer.get("gender", "")), "name": str(joiner.customer["name"])}, joiner.node)
			chat.transcript.append({"action": "%s, from further along the counter, joins the conversation." % joiner.customer["name"]})
	if chat == null:
		_task_done()
		return
	if not chat.owner_in and randf() < OWNER_JOINS_CHANCE:
		chat.owner_in = true
		var where := "calls over from the stove" if _at_stove() else "leans over the counter"
		_narrate("%s %s and joins in." % [_owner_display(), where])
		_event("owner_joined", {}, _owner_node)
		chat.transcript.append({"action": "%s, the owner, %s and joins in." % [_owner["name"], where]})
	if chat.owner_in:
		# Talking with the owner counts as being seen to.
		for guest in chat.people:
			_attention += 1
			guest.attended = _attention
		_attending = chat.people[0]
		_place_owner()
	var cat_with_them := "none" if _cat_here(null) == "none" else ("with_them" if chat.people.has(_cat_with) else "tent")
	chat.topic = Talk.pick_chat_topic(randf(), cat_with_them, chat.topic, Friendliness.know_each_other(Game.bar, chat.people) or (chat.people.size() == 2 and _came_together(chat.people[0], chat.people[1])), _late())
	if (chat.people.any(func(g): return g.cat_moment != "") or (chat.owner_in and _owner_cat_moment != "")) and not chat.cat_talk_done:
		chat.topic = "the_cat"  # (the cat's just come to one of them: see _talk; once a chat)
		chat.cat_talk_done = true
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
		var speaker := _chat_speaker(chat, voices, first)
		var others: Array = voices.filter(func(v): return v != speaker)
		if others.is_empty():  # (nobody else left to talk to: two of them with the same name, or someone gone)
			push_warning("Chat: %s has nobody else to talk to (voices: %s): the chat ends" % [speaker, voices])
			break
		var addressee: String = chat.last_speaker if voices.has(chat.last_speaker) and chat.last_speaker != speaker else str(others.pick_random())
		var line := await _chat_line(chat, speaker, addressee, first)
		if line == "":
			_narrate("(The conversation at the counter fizzled out: %s.)" % _ai.last_error)
			_chats.erase(chat)
			break
		said = line
		said_by = speaker
		lines -= 1
		lines_said += 1
		var heard_by: Array = chat.people.filter(func(p): return str(p.customer.get("regular_id", "")) != "").map(func(p): return str(p.customer["regular_id"]))
		if chat.owner_in:
			heard_by.append(Bonds.OWNER)
		for person in chat.people:
			person.chatted = true
			person.chat_lines.append({"speaker": speaker, "text": line, "heard_by": heard_by.filter(func(w): return w != str(person.customer.get("regular_id", "")))})
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
		await _react(spoken, talking, ordered, chat.topic)
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
		both and (not _friend(speaking, listening).is_empty() or _came_together(speaking, listening)), food, fewest, _clock >= Talk.TABLE_GAME_FROM, _scenery_dice)  # (what this line's given: see Conversation)
	var direction := str(given["direction"])
	var hint := str(given["hint"])  # what kind of hint this line was given, for the stats
	if str(given["game"]) != "":
		# The makings of a game, there at the table (shown, and in the chat as something that happened).
		var scene := str(Talk.TABLE_GAMES[str(given["game"])]["scene"])
		_narrate(scene)
		chat.transcript.append({"action": scene})
		_event("table_game_offered", {"game": str(given["game"]), "name": speaker})
	direction += " " + _chat_notes(chat) + " " + _who_you_know(speaking, chat.people) + " " + (Talk.TO_CAMERA if speaking != null and speaking.to_camera else Address.address_text(speaker, _addressee(speaking), addressee, _addressee(listening), close))
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
	_stats.record_camera_line(_camera.on_camera(chat.people, chat.owner_in))
	_stats.record_written_line(speaker, chat.people.map(func(g): return str(g.customer["name"])), line)
	_log_card_line(speaker, hint, _stats.record_hint(hint, line, _tent_cat.tells()), line,
		"in a chat with %s" % ", ".join(PackedStringArray(chat.people.map(func(g): return str(g.customer["name"])).filter(func(n): return n != speaker) + ([_owner_label()] if chat.owner_in and not owner_speaks else []))))
	_stats.record_line(line, names)
	if guest != null:
		_night_lines.append({"speaker": speaker, "text": line})
	if guest != null and guest.to_camera:  # (the PD's interview cut: straight to camera)
		guest.to_camera = false
		_show_to_camera(guest, line)
	else:
		_show("[color=#%s][b]%s to %s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(to), Glossary.explain(_esc(line), names)], _said_line(speaker, line))
	_cheer_along(guest, line, names)
	_cat_hears(line, chat.transcript)
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
## For a line's prompt: who the speaker knows among the others here, from their side only (the
## owner's, or a regular's: RegularsTonight.known_of), and, for a regular, what they've said
## about themselves before (to anyone), so they keep to it. "" if nothing. speaking: null for the
## owner. (Counted in the night's stats.)
func _who_you_know(speaking: Guest, others: Array) -> String:
	var me := Bonds.OWNER if speaking == null else str(speaking.customer.get("regular_id", ""))
	if me == "":
		return ""
	var who := str(_owner["name"]) if speaking == null else str(speaking.customer["name"])
	var notes := PackedStringArray()
	if speaking != null:
		var own := RegularsTonight.own_facts_text(_regular(me))
		if own != "":
			notes.append("What %s has said about themselves before (keep to it): %s." % [who, own])
	var known := PackedStringArray()
	for other in others:
		if other == speaking or str(other.customer.get("regular_id", "")) == "":
			continue
		var note := RegularsTonight.known_of(Game.bar, me, _regular(str(other.customer["regular_id"])))
		if note != "":
			known.append(note)
	if not known.is_empty():
		notes.append("WHO %s KNOWS HERE (only from their own side: nothing else is known): %s." % [who.to_upper(), " / ".join(known)])
	if not notes.is_empty():
		_stats.who_you_know += 1
	return " ".join(notes)


func _chat_notes(chat: Chat) -> String:
	var notes := PackedStringArray()
	for i in chat.people.size():
		for j in range(i + 1, chat.people.size()):
			if _came_together(chat.people[i], chat.people[j]):
				notes.append("%s and %s came in together: %s, so they know each other well, by name." % [chat.people[i].customer["name"], chat.people[j].customer["name"], Groups.info(str(chat.people[i].together["kind"]))["text"]])
				continue
			var friend := _friend(chat.people[i], chat.people[j])
			if friend.is_empty():
				continue
			var note := "%s and %s have chatted here before (%d %s)" % [chat.people[i].customer["name"], chat.people[j].customer["name"],
				int(friend.get("meetings", 1)), "time" if int(friend.get("meetings", 1)) == 1 else "times"]
			note += ", and know each other's names." if Friendliness.knows_name(Game.bar, chat.people[i], chat.people[j]) and Friendliness.knows_name(Game.bar, chat.people[j], chat.people[i]) else ", but haven't swapped names."
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


## What's known about someone's family, for the contradiction check: the owner's (a game fact),
## or a regular's (everything they've said); "" for anyone else.
func _family_of(who: String) -> String:
	if who == str(_owner.get("name", "")):
		return str(_owner.get("family", ""))
	var guest := _guest_named(who)
	if guest == null:
		return ""
	return str(guest.customer.get("regular", {}).get("own_facts", {}).get("family", ""))


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
	elif spot == "food" and with != null and CatRules.shares(str(_cat["personality"]), randf()):
		_cat_fed(with)  # (the friendly way: a bit from their plate)


## Someone slips the cat a bit of what's on their plate (it's still theirs: a bit). A moment for
## them and the owner (who may have something to say about feeding it).
func _cat_fed(guest: Guest) -> void:
	var food: Array = guest.served.filter(func(id): return Menu.find(id).get("kind", "") == "food")
	if food.is_empty():
		return
	var cat_name := str(_cat["name"])
	var named := str(guest.customer["name"])
	var dish := str(Menu.find(str(food.pick_random())).get("name", "food"))
	var fill := func(words: String) -> String: return words.replace("{cat}", cat_name).replace("{name}", named).replace("{dish}", dish)
	var text: String = fill.call(CatRules.SHARE_TEXT)
	_narrate(text)
	guest.transcript.append({"action": text})
	guest.version += 1
	guest.cat_moment = fill.call(CatRules.SHARE_MOMENT)
	_owner_cat_moment = fill.call(CatRules.SHARE_MOMENT_OWNER)
	_event("cat_fed", {"cat": cat_name, "name": named, "dish": dish}, guest.node)
	DebugLog.say("Cat", "%s gives %s a bit of their %s" % [named, cat_name, dish])


## A line said: if it names the cat (and it's in the tent), now and then it answers (야옹), more
## often it ignores them; never more than once in a while. transcript: the conversation it's in.
func _cat_hears(line: String, transcript: Array) -> void:
	if _cat.is_empty() or _cat_spot == "street" or _clock - _cat_heard_at < CAT_HEARS_EVERY:
		return
	var cat_name := str(_cat["name"])
	var heard := CatRules.hears_its_name(line, cat_name, randf())
	if heard == "":
		return
	_cat_heard_at = _clock
	if heard == "answer":
		_narrate(CatRules.ANSWER_TEXT.replace("{cat}", cat_name))
		transcript.append({"action": "%s meows back." % cat_name})
		_ambience.play("meow")
	else:
		var text := str(CatRules.IGNORE_TEXTS.pick_random()).replace("{cat}", cat_name)
		_narrate(text)
		transcript.append({"action": text})
	_event("cat_answered" if heard == "answer" else "cat_ignored", {"cat": cat_name}, _cat_node)
	DebugLog.say("Cat", "%s hears its name, and %s" % [cat_name, "answers" if heard == "answer" else "ignores it"])


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
		guest.node.pivot_offset = Vector2(Layout.PERSON_SIZE.x / 2, Layout.PERSON_SIZE.y)
		var wobble := guest.node.create_tween().set_loops()
		_people_view.lean_step(wobble, guest.node, -0.08, 0.1, _scaled(0.28)).set_trans(Tween.TRANS_SINE)
		wobble.parallel().tween_property(guest.node, "position:y", CUSTOMER_Y + 5, _scaled(0.28))
		_people_view.lean_step(wobble, guest.node, 0.1, -0.08, _scaled(0.32)).set_trans(Tween.TRANS_SINE)
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
	guest.node.pivot_offset = Vector2(Layout.PERSON_SIZE.x / 2, Layout.PERSON_SIZE.y)  # swaying from where they sit
	_stop_swaying(guest.node)
	var sway := guest.node.create_tween().set_loops()
	_people_view.lean_step(sway, guest.node, -lean * 0.6, lean, _scaled(1.6)).set_trans(Tween.TRANS_SINE)
	_people_view.lean_step(sway, guest.node, lean, -lean * 0.6, _scaled(1.8)).set_trans(Tween.TRANS_SINE)
	guest.node.set_meta("sway", sway)


## Now and then, everyone at the counter with something in front of them raises their glass or
## takes a few mouthfuls (people_view.gd gesture: an arm up, seated from behind), each in their
## own time (the scenery's dice: the game's own rolls never shift).
const GESTURE_SECONDS := Vector2(8.0, 22.0)

func _gestures(delta: float) -> void:
	for guest in _guests:
		if guest.served.is_empty() or not is_instance_valid(guest.node) or (guest.walk != null and guest.walk.is_running()):
			continue
		if guest.next_gesture < 0.0:
			guest.next_gesture = _scenery_dice.randf_range(GESTURE_SECONDS.x, GESTURE_SECONDS.y)
			continue
		guest.next_gesture -= delta
		if guest.next_gesture > 0.0:
			continue
		guest.next_gesture = _scenery_dice.randf_range(GESTURE_SECONDS.x, GESTURE_SECONDS.y)
		var drinks: Array = guest.served.filter(func(id): return Menu.find(id).get("kind", "") == "drink")
		var food: Array = guest.served.filter(func(id): return Menu.find(id).get("kind", "") == "food")
		var kind := "drink" if food.is_empty() or (not drinks.is_empty() and _scenery_dice.randf() < 0.5) else "eat"
		if _people_view.gesture(guest.node, kind):
			_stats.gestures[kind] = int(_stats.gestures.get(kind, 0)) + 1


## The owner's hands, for a moment (people_view.gd gesture: pouring, carrying, stirring, waving),
## counted in the stats.
func _owner_gesture(kind: String, seconds: float) -> void:
	if is_instance_valid(_owner_node) and _people_view.gesture(_owner_node, kind, seconds):
		_stats.gestures[kind] = int(_stats.gestures.get(kind, 0)) + 1


## While something's cooking and the owner's at the stove (not walking anywhere), a stir of the
## pot every few seconds.
const STIR_SECONDS := Vector2(3.0, 6.0)
var _next_stir := 0.0

func _stir(delta: float) -> void:
	if _kitchen.is_empty() or not is_instance_valid(_owner_node) or absf(_owner_node.position.x - OWNER_HOME_X) > 30.0 \
			or (_owner_tween != null and _owner_tween.is_running()):
		return
	_next_stir -= delta
	if _next_stir <= 0.0:
		_next_stir = _scenery_dice.randf_range(STIR_SECONDS.x, STIR_SECONDS.y)
		_owner_gesture("cook", 1.5)


func _drinks_had(guest: Guest) -> int:
	return guest.order.filter(func(id): return Menu.find(id).get("kind", "") == "drink").size()


func _stop_swaying(person: Control) -> void:
	if not person.has_meta("sway"):  # (get_meta with a null default still errors when it's missing)
		return
	var sway: Tween = person.get_meta("sway")
	if sway != null and sway.is_valid():
		sway.kill()
	person.remove_meta("sway")
	_people_view.lean(person, 0.0)


# --- Where the owner stands --------------------------------------------------------
## Their hands first, talk second (PLAN, 19 Nov: they'd walked over to whoever they talked to,
## every time, bouncing along the counter, and never stirred the pot): an errand takes them to a
## stool and back (pouring or setting something down, carrying a dish, settling up, a big
## moment worth the walk); with something on the stove they stay at it and talk from there;
## with nothing to cook or carry, they go over to whoever they're talking to. Checked every
## frame; they only move when where they should be changes.
const ERRAND_ORDER := ["carry", "pour", "serve", "settle", "moment"]  # (the first that's on wins)
const ERRAND_SECONDS := 1.2  # pouring or setting something down
const MOMENT_SECONDS := 4.0  # over for a big moment, then back
const MOMENTS_WORTH_THE_WALK := ["sad", "sweet", "warm"]  # (tears, a confession, a kindness: not a laugh)
const AT_STOVE := 30.0  # stage pixels from the stove that count as at it
var _errands := {}  # why -> {"x", "left" (real seconds, or INF till it's done), "who"}
var _owner_heading := OWNER_HOME_X  # where they're going (or are)
var _owner_why := "stove"  # and why


## An errand to someone's stool: for so long, or (INF) until _errand_done.
func _errand(guest: Guest, why: String, seconds: float = INF) -> void:
	_errands[why] = {"x": _beside(guest), "left": seconds, "who": str(guest.customer["name"])}
	_stats.record_owner_trip(why)
	_place_owner()


func _errand_done(why: String) -> void:
	_errands.erase(why)
	_place_owner()


## Where the owner should be, and why: [x, why, who].
func _owner_spot() -> Array:
	for why in ERRAND_ORDER:
		if _errands.has(why):
			return [float(_errands[why]["x"]), why, str(_errands[why]["who"])]
	if not _kitchen.is_empty():
		return [OWNER_HOME_X, "stove", ""]
	if _attending != null and _guests.has(_attending):
		return [_beside(_attending), "talk", str(_attending.customer["name"])]
	return [OWNER_HOME_X, "home", ""]


## Talking from the stove (something's cooking, and nothing's taking them over).
func _at_stove() -> bool:
	return _owner_spot()[1] == "stove"


## Whether the owner's the one talking with someone (them, or a chat they've joined).
func _owner_with(guest: Guest) -> bool:
	if _attending == guest:
		return true
	var chat := _chat_of(guest)
	return chat != null and chat.owner_in


func _place_owner() -> void:
	if not is_instance_valid(_owner_node) or not _night_open or _stopped:
		return
	var spot := _owner_spot()
	if absf(float(spot[0]) - _owner_heading) < 1.0:
		_owner_why = str(spot[1])
		return
	if spot[1] == "talk":
		_stats.record_owner_trip("talk")
		if _attending != null:
			_attending.heard_from_stove = false  # (over with them now)
	_owner_why = str(spot[1])
	_move_owner(float(spot[0]))


## Told once (till the owner comes over) that they're talking to them from the stove, so the AI
## can work it in ("hang on, the pancake's about to catch").
func _from_the_stove(guest: Guest) -> void:
	if not _at_stove() or guest.heard_from_stove or _kitchen.is_empty():
		return
	guest.heard_from_stove = true
	var dish := str(Menu.find(str(_kitchen[0]["id"])).get("name", "food"))
	guest.transcript.append({"action": "%s is at the stove keeping an eye on the %s, and talks to you from there." % [_owner["name"], dish]})
	_stats.from_the_stove += 1


## The errands' time running down, and where the owner's been (for the night's stats).
func _count_owner(delta: float) -> void:
	for why in _errands.keys():
		_errands[why]["left"] = float(_errands[why]["left"]) - delta
		if float(_errands[why]["left"]) <= 0.0:
			_errands.erase(why)
	if is_instance_valid(_owner_node):
		if absf(_owner_node.position.x - OWNER_HOME_X) <= AT_STOVE:
			_stats.owner_stove_seconds += delta
		else:
			_stats.owner_front_seconds += delta


func _move_owner(x: float) -> void:
	_owner_heading = x
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
	_stats.record_camera_line(_camera.on_camera([guest], true))  # (the owner's conversation)
	if not owner_speaks:
		_night_lines.append({"speaker": str(guest.customer["name"]), "text": text})
	if not owner_speaks and guest.to_camera:  # (the PD's interview cut: straight to camera)
		guest.to_camera = false
		_show_to_camera(guest, text)
	else:
		_show("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), Glossary.explain(_esc(text), [_owner["name"], guest.customer["name"]])],
			_said_line(str(_owner["name"]) if owner_speaks else str(guest.customer["name"]), text))
	_cheer_along(null if owner_speaks else guest, text, [_owner["name"], guest.customer["name"]])
	_cat_hears(text, guest.transcript)
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
	_captions_part.show_caption(kind, fill, about, spot, _tv_faces(kind, fill, about))


## The faces slapped onto a caption (Captions.faces_for: whose, in what mood): the owner's, the one or
## two people it names, or whoever it's over; [] for a kind with none, or nobody here with a
## face (counted as "none").
func _tv_faces(kind: String, fill: Dictionary, about: Variant) -> Array:
	var wanted := Captions.faces_for(kind, fill)
	if wanted.is_empty():
		return []
	var names: Array = wanted["names"]
	if bool(wanted["owner"]):
		names = [str(_owner.get("name", ""))]
	elif names.is_empty() and not bool(wanted["cat"]):
		names = [_name_of_node(about)]
	var faces: Array = []
	if bool(wanted["cat"]):
		var cat_face := _cat_face(str(wanted["mood"]))
		if not cat_face.is_empty():
			faces.append(cat_face)
	for person_name in names:
		var face := _tv_face(str(person_name), str(wanted["mood"]))
		if not face.is_empty():
			faces.append(face)
	if faces.is_empty():
		_stats.stings["none"] = int(_stats.stings.get("none", 0)) + 1
		DebugLog.say("Sting", "no face for the %s caption (%s)" % [kind, ", ".join(PackedStringArray(names))])
	return faces


## Someone's face for a caption, in a mood ("calm": their plain portrait): {"texture", "name", "mood",
## "how": "mood", "calm", or "stood_in" (the plain one, without a face for that mood)}, or {}
## without a portrait (or nobody by that name here: a full name or a given name will do).
func _tv_face(person_name: String, mood: String) -> Dictionary:
	if person_name == "":
		return {}
	var person: Dictionary = {}
	var node: Control = null
	if person_name == str(_owner.get("name", "")):
		person = _owner
		node = _owner_node
	else:
		var guest: Guest = _guest_named(person_name)
		if guest == null:
			for g in _guests:
				if Names.given_name(str(g.customer["name"])) == person_name:
					guest = g
		if guest == null:
			return _face_kept(person_name, mood)  # (gone home: their face kept from tonight)
		person = guest.customer
		node = guest.node
	var hover := (node.get_node_or_null("Hover") as PortraitHover) if is_instance_valid(node) else null
	if hover == null or hover.portrait == null or hover.picked_key == "":
		return {}
	var how := "calm"
	var texture: Texture2D = hover.portrait
	if mood != "calm":
		var moody := PeopleArt.portrait(person.get("look", {}), hover.picked_key, mood)
		how = "mood" if moody != null else "stood_in"
		if moody != null:
			texture = moody
	return {"texture": texture, "name": str(person.get("name", "")), "mood": mood, "how": how, "node": node}  # (node: for the clipart on stage)


## The cat's face for a caption (CAT_FACES): its one portrait, whatever the mood ("how": "cat"), no node
## (the edit's clipart is for people); {} without a cat, or a portrait for its coat.
func _cat_face(mood: String) -> Dictionary:
	if _cat.is_empty() or _tent_cat.node == null:
		return {}
	var hover := _cat_node as PortraitHover
	if hover == null or hover.portrait == null:
		return {}
	return {"texture": hover.portrait, "name": str(_cat["name"]), "mood": mood, "how": "cat", "node": null}


## The cat's face in tonight's stats (it came as the bar opened, before them): "cat_face" or "cat_none".
func _count_cat_face() -> void:
	if _cat.is_empty() or _tent_cat.node == null:
		return
	var hover := _cat_node as PortraitHover
	var key := "cat_face" if hover != null and hover.portrait != null else "cat_none"
	_stats.portraits[key] = 1
	DebugLog.say("Portraits", "the cat's face counted in tonight's stats (%s)" % key)


## The cat's hover opened with its face: counted.
func _cat_face_seen() -> void:
	_stats.portraits["cat_seen"] = int(_stats.portraits.get("cat_seen", 0)) + 1


## The face of someone who's left, from the portraits kept tonight (_faces_kept: a full name or
## a given name will do), in a mood as _tv_face's, without a node; {} for nobody kept.
func _face_kept(person_name: String, mood: String) -> Dictionary:
	var whose := Keepsakes.whose(person_name, _faces_kept)
	if whose == "":
		return {}
	var kept: Dictionary = _faces_kept[whose]
	var texture := PeopleArt.portrait(kept["look"], str(kept["key"]), "" if mood == "calm" else mood)
	var how := "calm" if mood == "calm" else ("mood" if texture != null else "stood_in")
	if texture == null:
		texture = PeopleArt.portrait(kept["look"], str(kept["key"]))
	if texture == null:
		return {}
	return {"texture": texture, "name": whose, "mood": mood, "how": how, "node": null}


## Whose node it is: the owner's or a customer's name ("" for anyone else, or nobody).
func _name_of_node(node: Variant) -> String:
	if not (node is Control) or not is_instance_valid(node):
		return ""
	if node == _owner_node:
		return str(_owner.get("name", ""))
	for guest in _guests:
		if guest.node == node:
			return str(guest.customer["name"])
	return ""


## A TV reaction: asks the AI whether anything in the latest lines was a big moment (usually
## not), and if so pops up its caption over whoever it's about, with the Hangul, look and
## sound from its mood (Captions.REACTIONS). If someone's waiting for the owner, it's put off
## until she's free, not skipped (the AI's one voice is hers: a busy night used to lose almost
## every check). An answer that fails the checks is dropped, not retried. names: who's talking;
## items: what they've ordered (a caption can't mention anything else).
func _react(lines: Array, names: Array, items: Array, topic: String = "") -> void:
	if not Hooks.reactions or not Hooks.captions or _captions_toggle == null or not _captions_toggle.button_pressed or lines.is_empty():
		return
	if _urgent():
		if not _reaction_pending.is_empty():
			_stats.reactions_skipped += 1  # (a newer one replaces it: only the latest waits)
		_reaction_pending = {"lines": lines.duplicate(true), "names": names.duplicate(), "items": items.duplicate(), "topic": topic, "at": _clock}
		_stats.reactions_put_off += 1
		return
	if not _captions_part.reaction_ready():
		return
	_stats.reactions_asked += 1
	var reply: Dictionary = await _ai.ask_json(Prompts.reaction_messages(lines.slice(-Captions.REACTION_LINES), names, Talk.reaction_note(topic)),
		_validate_reaction.bind(names, items), {"temperature": 0.7}, {"purpose": "reaction", "names": names, "tries": 1})
	if _stopped:
		return
	if reply.is_empty():
		_stats.reactions_dropped += 1
		return
	reply["topic"] = topic  # (for the stats: light talk, and the moments it made)
	var how_big := str(clampi(int(reply.get("size", 0)), 1, 5))
	_stats.reaction_sizes[how_big] = int(_stats.reaction_sizes.get(how_big, 0)) + 1
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
	if spins.size() > 1 and _pd != null and _pd.panel != null:
		_pd.offer_edit(spins, reply, lines, names, roll)
		if _autopilot != null:
			var k := _autopilot.spin_for(spins.size())
			if k >= 0:
				_autopilot_did("picks the edit's spin: %s, «%s»" % [spins[k]["mood"], spins[k]["caption"]])
				_pd.air_edit.call_deferred(k)
	else:
		_air_moment(0, [spins[0]], reply, lines, names, roll)


## A big moment goes out: its event (the mood the AI judged, for the diary, and what aired), the
## caption over whoever it's about, and a shock's double-take.
func _air_moment(k: int, spins: Array, reply: Dictionary, lines: Array, names: Array, roll: float) -> void:
	if _stopped:
		return
	var mood := str(spins[k]["mood"])
	var caption := str(spins[k]["caption"])
	var who := str(reply["who"])
	var theirs: Array = lines.filter(func(e): return str(e.get("speaker", "")) == who)
	var words := Captions.reaction_words(mood, caption, roll)
	# (its size, and the Hangul it aired with: for 3am's end card, Keepsakes.biggest_moment)
	_event("big_moment", {"who": who, "mood": mood, "ai_mood": str(spins[0]["mood"]), "edited": k > 0, "caption": caption, "topic": str(reply.get("topic", "")),
		"said": str(theirs[-1]["text"]) if not theirs.is_empty() else "", "size": clampi(int(reply.get("size", 0)), 0, 5), "hangul": str(words.get("hangul", ""))})  # (its caption's popped here, below: the AI's words)
	var about: Variant = _owner_node  # (untyped: someone's node may be gone by now)
	if who != str(_owner["name"]):
		var guest: Guest = _guest_named(who)
		about = guest.node if guest != null else null
	if mood == "shock":
		_stun_listeners(who, names)
	if about is Control and is_instance_valid(about):
		var guest_here: Guest = _guest_named(who) if who != str(_owner["name"]) else null
		if guest_here != null and MOMENTS_WORTH_THE_WALK.has(mood) and _owner_with(guest_here):
			_errand(guest_here, "moment", _scaled(MOMENT_SECONDS))  # (over for this one, then back)
		_people_view.pose(about, mood)  # (laughing, slumped, jolted, a nod, a fidget)
		_stats.poses += 1
	var data: Dictionary = Captions.REACTIONS[mood]
	var face := _tv_face(who, mood)
	var zoom := not face.is_empty() and not _zoomed_tonight  # (the night's first big moment: over the whole window)
	if face.is_empty():
		_stats.stings["none"] = int(_stats.stings.get("none", 0)) + 1
		DebugLog.say("Sting", "no face for %s's big moment" % who)
	_zoomed_tonight = _zoomed_tonight or zoom
	_captions_part.pop(words, str(data["icon"]), str(data["colour"]), str(data["sound"]), false, about, Vector2(-1, -1), Captions.REACTION_SECONDS,
		[] if face.is_empty() else [face], zoom)


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
	_people_view.lean_step(turn, node, 0.0, -0.12, 0.25)
	turn.tween_interval(_scaled(1.2))
	_people_view.lean_step(turn, node, -0.12, 0.0, 0.3)


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
		await _react(pending["lines"], pending["names"], pending["items"], str(pending.get("topic", "")))
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
		area = PortraitHover.new()
		area.name = "Hover"
		area.position = Vector2(15, 0)  # (their body: the shoulders' width, so the dishes beside them keep their own hovers)
		area.size = Vector2(Layout.PERSON_SIZE.x - 30, Layout.PERSON_SIZE.y)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.gui_input.connect(_on_guest_clicked.bind(guest))
		guest.node.add_child(area)
	_give_portrait(area, guest.customer)
	area.tooltip_text = _hover_text(guest)


## Portraits: someone's face in their hover, once they have a look (rules/portraits.gd picks it
## from the library, the same for the same look; people_art.gd paints it onto their colours),
## counted in the night's stats and noted, once each (again only if their look changes: a new owner).
func _give_portrait(area: Control, person: Dictionary) -> void:
	var hover := area as PortraitHover
	if hover == null or person.get("look", {}).is_empty() or hover.picked_for == person["look"]:
		return
	hover.picked_for = person["look"]
	var look: Dictionary = person["look"]
	var own := _own_face(person)
	var picked := {"key": own, "how": "own"} if own != "" else PortraitRules.pick(str(person.get("gender", "")), look, _library_portraits(), int(person.get("age", 0)))
	var how := str(picked["how"])
	hover.portrait = PeopleArt.portrait(look, str(picked["key"]))
	if hover.portrait == null:
		how = "none"
	hover.picked_how = how
	hover.picked_key = str(picked["key"]) if how != "none" else ""
	if how != "none":  # (kept by name, for 3am once they've gone: the end card, the polaroids, the entry)
		_faces_kept[str(person.get("name", ""))] = {"key": hover.picked_key, "look": look.duplicate(true)}
	_stats.portraits[how] = int(_stats.portraits.get(how, 0)) + 1
	hover.shown.connect(func(): _stats.portraits["seen"] = int(_stats.portraits.get("seen", 0)) + 1)
	DebugLog.say("Portraits", "%s: %s (%s%s)" % [str(person.get("name", "?")), str(picked["key"]) if how != "none" else "no portrait", how,
		"" if how != "fallback" else ", wanted " + PortraitRules.ideal(str(person.get("gender", "")), look, int(person.get("age", 0)))])


var _portraits_here: Array = []  # the portraits in the library (Art.has), and "" once looked


## The library's portraits (looked over once).
func _library_portraits() -> Array:
	if _portraits_here.is_empty():
		_portraits_here = Art.ids("portrait").filter(func(id): return Art.has("portrait/" + str(id)))
		_portraits_here.append("")  # (and never looked over again, even with none there)
	return _portraits_here
var _own_missing := {}  # faces of their own whose pictures weren't with the bar (noted once)


## A face of their own (ai/portrait_maker.gd: person["face"]), its portrait id once its layer's
## read from the bar's pictures into Art.own (and its moods': _own_moods); "" for none, or if its
## picture's gone (the library's then).
func _own_face(person: Dictionary) -> String:
	var face = person.get("face", {})
	if not face is Dictionary or str(face.get("key", "")) == "":
		return ""
	var key := str(face["key"])
	if not Art.own.has("portrait/" + key):
		var layer := SaveStore.load_picture(str(Game.bar.get("id", "")), str(face.get("file", "")))
		if layer == null:
			if not _own_missing.has(key):
				_own_missing[key] = true
				DebugLog.say("Faces", "%s's own face (%s) isn't with the bar: the library's instead" % [str(person.get("name", "?")), face.get("file", "?")])
			return ""
		Art.own["portrait/" + key] = layer
	_own_moods(person, face, key)  # (and their moods, any made: the calm face stands in for the rest)
	return key


# --- Faces of their own ----------------------------------------------------------------------------
# PLAN.md: the image model makes the owner a face of their own as a new bar's made (ai/portrait_maker.gd,
# in the gap when the GPU's free: Ollama lets go, ComfyUI starts, three casting photos, each split by
# rules/portrait_split.gd and the best picked, ComfyUI stops); the PD can step in on the setup screen
# (pick another, or reshoot). Offline, off in the settings, without ComfyUI, or when every picture
# fails, the owner keeps the library's face.

## Why there'll be no face of their own ("" if there can be one): the owner's, or the regulars'.
func _why_no_faces(for_regulars: bool = false) -> String:
	var setting := str(_ai.settings.get("faces", "owner_and_regulars"))
	if setting == "off":
		return "off in the AI settings"
	if for_regulars and setting != "owner_and_regulars":
		return "the AI settings make the owner's only"
	if not Hooks.fake_comfy.is_empty():
		return ""
	if _ai.offline:
		return "offline: %s" % _ai.offline_reason
	return ""


## The owner's casting photos (see above). Never stops the bar: anything wrong, the library's face.
func _cast_owner_face() -> void:
	var why := _why_no_faces()
	if why != "":
		_faces_story = {"owner": "library", "why": why}
		DebugLog.say("Faces", "the owner keeps the library's face: %s" % why)
		_tell_setup_casting()
		return
	_casting = true
	_tell_setup_casting()
	_typing_label.text = "The casting photographer's setting up..."
	var let_go: bool = await _ai.let_go()
	DebugLog.say("Faces", "Ollama let go of the model" if let_go else "Ollama didn't let go of the model (it may not have had it loaded)")
	if _closed():
		_casting = false
		return
	_maker = PortraitMaker.new()
	add_child(_maker)
	var problem: String = await _maker.open()
	_comfy_open = problem == ""
	if _comfy_open and not _closed():
		await _shoot_owner()
	_typing_label.text = ""
	if _casting_photos.is_empty():
		var reason := problem if problem != "" else "every picture failed (%s)" % _maker.last_error
		_faces_story = {"owner": "library", "why": reason}
		DebugLog.say("Faces", "the owner keeps the library's face: %s" % reason)
	_faces_story.merge(_maker.counts, true)
	_casting = false
	_tell_setup_casting()
	if _why_no_faces(true) == "" and not _closed():  # (then the first regulars, while ComfyUI's ours)
		var people := _regulars_without_faces()
		if not people.is_empty():
			if _comfy_open:
				_faces_story["regulars"] = await _cast_regulars(people)
			else:
				_faces_story["regulars"] = {"why": problem, "waiting": people.size()}
				DebugLog.say("Faces", "the regulars keep the library's faces for now: %s" % problem)
			if _maker != null:
				_faces_story.merge(_maker.counts, true)


## A round of three casting photos of the owner; the best split's their face (by the game), unless
## none came out (the face they had stays).
func _shoot_owner() -> void:
	_typing_label.text = "The casting photographer's taking the owner's photos..."
	var prompt := PortraitRules.prompt_for(str(_owner.get("gender", "")), _owner.get("look", {}), int(_owner.get("age", 0)), str(_owner.get("appearance", "")))
	DebugLog.say("Faces", "the owner's casting photos: %s" % prompt)
	var photos: Array = await _maker.make(prompt, "owner", 3, _casting_seed(), PortraitRules.split_name("owner", _owner.get("look", {})))
	if _closed() or photos.is_empty():
		return
	_casting_rounds += 1
	_casting_photos = photos
	_use_owner_face(PortraitSplit.best(photos), "game")


## The owner's face from this round's photo k, by "game" or "pd": kept with the bar (the layer, and
## the model's picture for the moods to come), on them from now on.
func _use_owner_face(k: int, by: String) -> void:
	if k < 0 or k >= _casting_photos.size() or not Game.bar.has("id"):
		return
	var photo: Dictionary = _casting_photos[k]
	var pic_seed := int(photo["seed"])
	var face := _keep_face("owner", photo, by)
	if face.is_empty():
		DebugLog.say("Faces", "couldn't keep the owner's face with the bar: the library's instead")
		return
	_casting_pick = k
	_owner["face"] = face
	Game.bar["owner"]["face"] = face.duplicate()
	Game.save()
	_faces_story.erase("why")
	_faces_story.merge({"owner": "own", "by": by, "score": face["score"], "rounds": _casting_rounds}, true)
	if _maker != null:
		_faces_story.merge(_maker.counts, true)
	DebugLog.say("Faces", "the owner's face: seed %d (score %.3f), picked by the %s" % [pic_seed, float(photo["score"]), by])
	var hover: PortraitHover = _owner_node.get_node_or_null("Hover") as PortraitHover if is_instance_valid(_owner_node) else null
	if hover != null:
		hover.picked_for = {}  # (picked again, now with their own)
	_update_owner_hover()


## The PD picks another of the photos on the setup screen.
func _pd_picks_owner_face(k: int) -> void:
	if _casting or k == _casting_pick:
		return
	_use_owner_face(k, "pd")
	_tell_setup_casting()


## The PD wants three more photos (ComfyUI's still ours until the setup's closed).
func _reshoot_owner_face() -> void:
	if _casting or _casting_regulars or not _comfy_open or _maker == null or _closed():
		return
	_casting = true
	_faces_story["reshoots"] = int(_faces_story.get("reshoots", 0)) + 1
	DebugLog.say("Faces", "the PD wants the owner's photos reshot")
	_tell_setup_casting()
	await _shoot_owner()
	_typing_label.text = ""
	if _closed():
		return
	if _faces_story.get("owner", "") == "own":
		_faces_story["by"] = "pd"  # (the PD's call to reshoot, the game's pick of the three)
	_faces_story.merge(_maker.counts, true)
	_casting = false
	_tell_setup_casting()


## Done with the image model: ComfyUI stopped (if it was ours), and what happened for the stats.
func _close_casting() -> void:
	if _maker != null:
		await _maker.close()
		if not is_instance_valid(_maker):
			return  # (the bar closed meanwhile)
		_faces_story.merge(_maker.counts, true)
		_maker.queue_free()
		_maker = null
	_comfy_open = false
	if not _faces_story.is_empty():
		_before_night["faces"] = _faces_story.duplicate()


## The setup screen's casting photos, as they are now.
func _tell_setup_casting() -> void:
	if _setup_screen == null or not is_instance_valid(_setup_screen):
		return
	var faces: Array = []
	for photo in _casting_photos:
		faces.append({"texture": PeopleArt.paint_portrait(_owner.get("look", {}), photo["split"]["layer"]), "score": float(photo["score"])})
	var status := "shooting" if _casting else ("ready" if not faces.is_empty() else ("none" if not _faces_story.is_empty() else "waiting"))
	_setup_screen.show_casting({"status": status, "why": str(_faces_story.get("why", "")), "faces": faces, "pick": _casting_pick,
		"can_reshoot": _comfy_open and not _casting and not _casting_regulars, "owner": _owner_display() if not _owner.is_empty() else "the owner",
		"regulars": "Now the regulars' photos (the game picks theirs: you can recast them at 3am)..." if _casting_regulars else ""})


## A new seed for a round of casting photos (three in a row from it).
func _casting_seed() -> int:
	return (randi() % 90000 + 10000) * 10


## A face of their own from a casting photo, kept with the bar (the split's layer, and the model's
## picture, for the moods to come) and read into Art.own: its record (a person's "face"), or {} if
## it couldn't be kept. tag: whose ("owner", or a regular's _face_tag).
func _keep_face(tag: String, photo: Dictionary, by: String) -> Dictionary:
	if not Game.bar.has("id"):
		return {}
	var pic_seed := int(photo["seed"])
	var id := str(Game.bar["id"])
	var file := "portrait_%s_%d.png" % [tag, pic_seed]
	var picture_file := "portrait_%s_%d_picture.png" % [tag, pic_seed]
	var layer: Image = photo["split"]["layer"]
	if SaveStore.save_picture(id, file, layer) != OK:
		return {}
	SaveStore.save_picture(id, picture_file, photo["picture"])
	var key := PortraitRules.own_key(id, tag, pic_seed)
	Art.own["portrait/" + key] = ImageTexture.create_from_image(layer)
	return {"key": key, "file": file, "picture": picture_file, "seed": pic_seed, "score": snappedf(float(photo["score"]), 0.001), "by": by}


## A regular's name in the bar's pictures and their portrait ids.
func _face_tag(regular: Dictionary) -> String:
	return str(regular.get("id", "regular")).replace("/", "_").replace(" ", "-")


## The regulars still to get a face of their own: no "face" yet. (One whose photos didn't come
## out keeps the library's, {"key": "", "why"}, and isn't tried again: the PD can recast them.)
func _regulars_without_faces() -> Array:
	return _regulars().filter(func(regular): return not (regular.get("face", {}) is Dictionary and not (regular.get("face", {}) as Dictionary).is_empty()))


## Casting photos of these regulars, up to REGULARS_A_GAP of them (the rest next time), each
## auto-picked (_shoot_regular). After _maker.open(). What happened, for the stats: {"own",
## "library", "left" (still to do), "names"}.
func _cast_regulars(people: Array) -> Dictionary:
	_casting_regulars = true
	_tell_setup_casting()
	var story := {"own": 0, "library": 0, "left": maxi(0, people.size() - REGULARS_A_GAP), "names": []}
	for regular in people.slice(0, REGULARS_A_GAP):
		if _closed() or _maker == null:
			break
		var got := await _shoot_regular(regular)
		story[got] = int(story[got]) + 1
		story["names"].append(str(regular.get("name", "?")) + ("" if got == "own" else " (the library's)"))
	_typing_label.text = ""
	_casting_regulars = false
	_tell_setup_casting()
	return story


const REGULARS_A_GAP := 3  # regulars' faces made in one gap (each about 20 seconds: three pictures and their splits)


## Three casting photos of a regular, the cleanest split their face if it's clean enough
## (PortraitRules.CLEAN_ENOUGH), else the library's for good (noted with why). "own" or "library".
func _shoot_regular(regular: Dictionary) -> String:
	var who := str(regular.get("name", "a regular"))
	var look: Dictionary = regular.get("look", {})
	_typing_label.text = "The casting photographer's taking %s's photos..." % who
	var prompt := PortraitRules.prompt_for(str(regular.get("gender", "")), look, int(regular.get("age", 0)), str(regular.get("appearance", "")))
	DebugLog.say("Faces", "%s's casting photos: %s" % [who, prompt])
	var photos: Array = await _maker.make(prompt, _face_tag(regular), 3, _casting_seed(), PortraitRules.split_name(_face_tag(regular), look))
	if _closed():
		return "library"
	var k := PortraitSplit.best(photos) if not photos.is_empty() else -1
	var most: float = PortraitRules.CLEAN_ENOUGH if is_nan(Hooks.clean_enough) else Hooks.clean_enough
	var why := ""
	if k < 0:
		why = "every picture failed (%s)" % (_maker.last_error if _maker != null else "?")
	elif float(photos[k]["score"]) > most:
		why = "none split cleanly enough (the best scored %.3f, over %.2f)" % [float(photos[k]["score"]), most]
	var face := _keep_face(_face_tag(regular), photos[k], "game") if why == "" else {}
	if why == "" and face.is_empty():
		why = "couldn't keep it with the bar"
	if why != "":
		regular["face"] = {"key": "", "why": why, "night": _night_number}
		Game.save()
		DebugLog.say("Faces", "%s keeps the library's face: %s" % [who, why])
		return "library"
	regular["face"] = face
	Game.save()
	DebugLog.say("Faces", "%s's face: seed %d (score %.3f), picked by the game" % [who, int(face["seed"]), float(face["score"])])
	return "own"


## 3am, once the diary's written: faces of their own for the regulars without one (tonight's new
## regulars, or ones from before the setting allowed it), then the TV moods for the faces of their
## own without them (_make_moods), in the gap before the next night, the summary page's buttons
## waiting: Ollama lets go, ComfyUI starts, and it's stopped again before the next night's first AI
## call. Counted in tonight's stats ("faces_after") and noted.
func _faces_after_closing() -> void:
	var setting := str(_ai.settings.get("faces", "owner_and_regulars"))
	var people := _regulars_without_faces() if setting == "owner_and_regulars" else []
	if (people.is_empty() and _faces_wanting_moods().is_empty()) or _closed():
		return
	var why := _why_no_faces()
	if why != "":
		_stats.story["faces_after"] = {"why": why, "waiting": people.size(), "moods_waiting": _faces_wanting_moods().size()}
		DebugLog.say("Faces", "%d %s keep the library's faces, %d faces of their own their calm one, for now: %s" % [people.size(), "regular" if people.size() == 1 else "regulars", _faces_wanting_moods().size(), why])
		return
	_writing_up = true
	for button in _summary_buttons:
		button.disabled = true
	var let_go: bool = await _ai.let_go()
	DebugLog.say("Faces", "after closing: Ollama let go of the model" if let_go else "after closing: Ollama didn't let go of the model (it may not have had it loaded)")
	var story := {}
	if not _closed():
		_maker = PortraitMaker.new()
		add_child(_maker)
		var problem: String = await _maker.open()
		if problem == "" and not _closed():
			if not people.is_empty():
				story = await _cast_regulars(people)
			var moody := _faces_wanting_moods()  # (tonight's new faces too, once they're made)
			if not moody.is_empty() and not _closed() and _maker != null:
				story["moods"] = await _make_moods(moody)
		else:
			story = {"why": problem if problem != "" else "the bar closed", "waiting": people.size(), "moods_waiting": _faces_wanting_moods().size()}
			DebugLog.say("Faces", "after closing, the regulars keep the library's faces and their own faces their calm one, for now: %s" % story["why"])
		if _maker != null:
			await _maker.close()
			if _maker != null:
				story.merge(_maker.counts, true)
				_maker.queue_free()
				_maker = null
	_stats.story["faces_after"] = story
	_writing_up = false
	for button in _summary_buttons:
		button.disabled = Game.autoplay != null
	_update_recast_button()


# --- Their moods (a face of their own in each TV mood, made after closing) ------------------------
# PLAN.md: a face of their own is redrawn in each TV mood (captions.gd REACTIONS) from its calm
# picture (ai/portrait_maker.gd redraw), MOOD_SEEDS seeds each, the best seed of each kept with the
# bar (portrait_<tag>_<seed>_<mood>.png, the face's "moods") and read into Art.own as
# reaction/<own key>_<mood> (_own_moods), so PeopleArt.portrait(look, key, mood) and the TV boxes
# find it. A mood that failed, or scored worse than MOOD_CLEAN_ENOUGH, has the calm face standing in
# (noted with why) and is tried again another night. A recast's a new key: its moods start again.

const MOODS_A_GAP := 2  # people whose moods are made in one gap (each about 14 pictures: a minute and a half)
const MOOD_SEEDS := 2  # pictures of each mood, the best kept (as the library's)
## A mood's best seed is kept only if it scored at least this well (react_score: lower is better).
## The art tool's own line for "looks like someone else"; the library's 882 picks all scored
## under it (median about 0.1, the worst 0.56: shock).
const MOOD_CLEAN_ENOUGH := 0.6


## The moods a face of their own hasn't got yet (all of REACTIONS for a new one).
func _moods_wanting(face: Dictionary) -> Array:
	var got = face.get("moods", {})
	return Captions.REACTIONS.keys().filter(func(mood): return not (got is Dictionary and (got as Dictionary).has(mood)))


## Who's got a face of their own still without some of its moods: the owner first, then the
## regulars (as the setting allows). [{"person", "tag", "owner": bool}]. A face without its model's
## picture (nothing to redraw from) is left out, and noted once.
func _faces_wanting_moods() -> Array:
	var setting := str(_ai.settings.get("faces", "owner_and_regulars"))
	if setting == "off" or not Hooks.own_moods:
		return []
	var out: Array = []
	var people: Array = [{"person": _owner, "tag": "owner", "owner": true}]
	if setting == "owner_and_regulars":
		for regular in _regulars():
			people.append({"person": regular, "tag": _face_tag(regular), "owner": false})
	for each in people:
		var face = (each["person"] as Dictionary).get("face", {})
		if not face is Dictionary or str(face.get("key", "")) == "" or _moods_wanting(face).is_empty():
			continue
		if str(face.get("picture", "")) == "":
			if not _own_missing.has(str(face["key"]) + "|picture"):
				_own_missing[str(face["key"]) + "|picture"] = true
				DebugLog.say("Faces", "%s's own face has no picture of the model's to redraw: no moods (the calm face stands in)" % str(each["person"].get("name", "?")))
			continue
		out.append(each)
	return out


## The moods of up to MOODS_A_GAP of these (the rest next time). After _maker.open(). What
## happened, for the stats: {"people": made for, "kept", "stood_in" (moods), "left" (people still
## to do), "names": ["Kim Mi-ra 7", "Lee Jun 5 (2 the calm face's)"]}.
func _make_moods(people: Array) -> Dictionary:
	var story := {"people": 0, "kept": 0, "stood_in": 0, "left": maxi(0, people.size() - MOODS_A_GAP), "names": []}
	for each in people.slice(0, MOODS_A_GAP):
		if _closed() or _maker == null:
			break
		var got := await _make_moods_for(each["person"], str(each["tag"]), bool(each["owner"]))
		story["people"] = int(story["people"]) + 1
		story["kept"] = int(story["kept"]) + int(got["kept"])
		story["stood_in"] = int(story["stood_in"]) + int(got["stood_in"])
		story["names"].append("%s %d%s" % [str(each["person"].get("name", "?")), int(got["kept"]), (" (%d the calm face's)" % int(got["stood_in"])) if int(got["stood_in"]) > 0 else ""])
	_typing_label.text = ""
	if int(story["left"]) > 0:
		DebugLog.say("Faces", "moods: %d more %s next time" % [int(story["left"]), "face" if int(story["left"]) == 1 else "faces"])
	return story


## One person's moods still wanted, redrawn from their calm picture: each mood's best seed kept
## (if it's clean enough), the rest the calm face's for now. {"kept", "stood_in"}.
func _make_moods_for(person: Dictionary, tag: String, is_owner: bool) -> Dictionary:
	var who := str(person.get("name", "someone"))
	var face: Dictionary = person["face"]
	var key := str(face["key"])
	var wanted := _moods_wanting(face)
	var id := str(Game.bar.get("id", ""))
	_typing_label.text = "The make-up artist's doing %s's faces for the TV..." % who
	DebugLog.say("Faces", "%s's moods (%s): redrawn from their calm picture" % [who, ", ".join(PackedStringArray(wanted))])
	var calm := SaveStore.load_picture(id, str(face.get("picture", "")))
	var made: Dictionary = await _maker.redraw(calm.get_image() if calm != null else null, tag, bool(person.get("look", {}).get("glasses", false)), wanted, MOOD_SEEDS, _casting_seed())
	if _closed():
		return {"kept": 0, "stood_in": wanted.size()}
	var most: float = MOOD_CLEAN_ENOUGH if is_nan(Hooks.mood_clean_enough) else Hooks.mood_clean_enough
	var moods: Dictionary = (face.get("moods", {}) as Dictionary).duplicate() if face.get("moods", {}) is Dictionary else {}
	var got := {"kept": 0, "stood_in": 0}
	for mood in wanted:
		var pick: Dictionary = made.get(mood, {})
		var why := ""
		if pick.is_empty():
			why = "nothing could be tried (%s)" % (_maker.last_error if _maker != null else "?")
		elif pick.has("failed"):
			why = "no picture came out (%s)" % str(pick["failed"])
		elif float(pick["score"]) > most:
			why = "the best scored %.3f, over %.2f (another face, perhaps)" % [float(pick["score"]), most]
		var file := "portrait_%s_%d_%s.png" % [tag, int(face.get("seed", 0)), mood]
		if why == "":
			var layer: Image = pick["split"]["layer"]
			if SaveStore.save_picture(id, file, layer) != OK:
				why = "couldn't keep it with the bar"
			else:
				Art.own["reaction/%s_%s" % [key, mood]] = ImageTexture.create_from_image(layer)
				moods[mood] = {"file": file, "seed": int(pick["seed"]), "score": snappedf(float(pick["score"]), 0.001)}
				got["kept"] = int(got["kept"]) + 1
				DebugLog.say("Faces", "%s, %s: seed %d kept (score %.3f)" % [who, mood, int(pick["seed"]), float(pick["score"])])
				continue
		got["stood_in"] = int(got["stood_in"]) + 1
		DebugLog.say("Faces", "%s, %s: the calm face stands in, tried again another night: %s" % [who, mood, why])
	face["moods"] = moods
	if is_owner and Game.bar.get("owner", {}) is Dictionary:
		Game.bar["owner"]["face"] = face.duplicate(true)  # (the bar's copy of the owner)
	PeopleArt.forget_moods(key)  # (any mood looked up before it was made: null, kept)
	Game.save()
	return got


## A face of their own's moods (person["face"]["moods"]) read from the bar's pictures into
## Art.own (as reaction/<key>_<mood>), the ones not there yet; a missing picture noted once (the
## calm face stands in for it).
func _own_moods(person: Dictionary, face: Dictionary, key: String) -> void:
	var moods = face.get("moods", {})
	if not moods is Dictionary:
		return
	var read := 0
	for mood in moods:
		var art_id := "reaction/%s_%s" % [key, mood]
		if Art.own.has(art_id) or _own_missing.has(art_id):
			continue
		var layer := SaveStore.load_picture(str(Game.bar.get("id", "")), str(moods[mood].get("file", "")))
		if layer == null:
			_own_missing[art_id] = true
			DebugLog.say("Faces", "%s's own %s face (%s) isn't with the bar: the calm face stands in" % [str(person.get("name", "?")), mood, moods[mood].get("file", "?")])
			continue
		Art.own[art_id] = layer
		read += 1
	if read > 0:
		PeopleArt.forget_moods(key)
		DebugLog.say("Faces", "%s's own moods read in: %d" % [str(person.get("name", "?")), read])


# --- Recasting a regular's face (3am: the summary page's 📷 button) -------------------------------
# The PD picks a regular, three new casting photos are taken (ComfyUI started for it, and stopped
# when they're done), and they click one to use it (by "pd"), or keep the face they have. Only
# while the GPU's free: the night's written up, and before the next one opens.

## Whether the PD can recast now: the setting, not offline, regulars, and not the crew's night.
func _can_recast() -> bool:
	return _why_no_faces(true) == "" and not _regulars().is_empty() and Game.autoplay == null


func _update_recast_button() -> void:
	if _recast_button != null:
		_recast_button.visible = _night_written and _can_recast()


## The 📷 button: the recasting screen over the summary.
func _open_recast() -> void:
	if _recast != null or _writing_up or not _can_recast():
		return
	_recast = RecastScreen.new()
	add_child(_recast)
	_recast.open(_regulars().map(func(regular): return {"id": str(regular["id"]), "name": str(regular.get("name", "?")), "texture": _face_texture(regular),
		"own": _own_face(regular) != ""}))
	_recast.chosen.connect(_recast_regular)
	_recast.face_picked.connect(_recast_pick)
	_recast.finished.connect(_close_recast)
	_recast_story = {"shot": 0, "picked": []}
	DebugLog.say("Faces", "the PD opens the recasting")


## Someone's face as it is now: their own, or the library's (as _give_portrait picks it).
func _face_texture(person: Dictionary) -> Texture2D:
	var own := _own_face(person)
	if own != "":
		return PeopleArt.portrait(person.get("look", {}), own)
	var picked := PortraitRules.pick(str(person.get("gender", "")), person.get("look", {}), _library_portraits(), int(person.get("age", 0)))
	return PeopleArt.portrait(person.get("look", {}), str(picked["key"]))


## The PD picks whose face to recast: three new photos of them.
func _recast_regular(id: String) -> void:
	var regular := _regular(id)
	if _recast_shooting or regular.is_empty() or _recast == null:
		return
	_recast_shooting = true
	_recast_id = id
	_recast_photos = []
	var who := str(regular.get("name", "?"))
	_recast.show_state({"status": "shooting", "who": who})
	DebugLog.say("Faces", "the PD recasts %s's face" % who)
	var problem := ""
	if _maker == null:
		var let_go: bool = await _ai.let_go()
		DebugLog.say("Faces", "Ollama let go of the model" if let_go else "Ollama didn't let go of the model (it may not have had it loaded)")
		if _recast == null:
			_recast_shooting = false
			return
		_maker = PortraitMaker.new()
		add_child(_maker)
		problem = await _maker.open()
	var photos: Array = []
	if problem == "" and _maker != null:
		var look: Dictionary = regular.get("look", {})
		var prompt := PortraitRules.prompt_for(str(regular.get("gender", "")), look, int(regular.get("age", 0)), str(regular.get("appearance", "")))
		DebugLog.say("Faces", "%s's casting photos: %s" % [who, prompt])
		photos = await _maker.make(prompt, _face_tag(regular), 3, _casting_seed(), PortraitRules.split_name(_face_tag(regular), look))
		_recast_story["shot"] = int(_recast_story.get("shot", 0)) + 1
	_recast_shooting = false
	if _recast == null or not is_instance_valid(_recast):
		return
	_recast_photos = photos
	if photos.is_empty():
		var why := problem if problem != "" else "every picture failed (%s)" % (_maker.last_error if _maker != null else "?")
		DebugLog.say("Faces", "no photos of %s to recast with: %s" % [who, why])
		_recast.show_state({"status": "none", "who": who, "why": why})
		return
	_show_recast(regular, -1)


func _show_recast(regular: Dictionary, pick: int) -> void:
	var faces: Array = []
	for photo in _recast_photos:
		faces.append({"texture": PeopleArt.paint_portrait(regular.get("look", {}), photo["split"]["layer"]), "score": float(photo["score"])})
	_recast.show_state({"status": "ready", "who": str(regular.get("name", "?")), "faces": faces, "pick": pick, "now": _face_texture(regular)})


## The PD clicks one of the three: it's their face now.
func _recast_pick(k: int) -> void:
	var regular := _regular(_recast_id)
	if regular.is_empty() or k < 0 or k >= _recast_photos.size() or _recast_shooting:
		return
	var face := _keep_face(_face_tag(regular), _recast_photos[k], "pd")
	if face.is_empty():
		DebugLog.say("Faces", "couldn't keep %s's new face with the bar" % regular.get("name", "?"))
		return
	regular["face"] = face
	Game.save()
	(_recast_story["picked"] as Array).append(str(regular.get("name", "?")))
	DebugLog.say("Faces", "%s's face: seed %d (score %.3f), picked by the PD" % [regular.get("name", "?"), int(face["seed"]), float(face["score"])])
	_show_recast(regular, k)
	_recast.update_regular(_recast_id, _face_texture(regular))


## Done recasting: ComfyUI stopped (if it was ours), and what the PD did for the next night's stats.
func _close_recast() -> void:
	_recast = null
	while _recast_shooting:
		await get_tree().process_frame
	if _maker != null:
		await _maker.close()
		if _maker != null:
			_recast_story.merge(_maker.counts, true)
			_maker.queue_free()
			_maker = null
	if int(_recast_story.get("shot", 0)) > 0:
		_before_night["faces_recast"] = _recast_story.duplicate(true)
	DebugLog.say("Faces", "the PD's done recasting: %d rounds of photos, %d %s" % [int(_recast_story.get("shot", 0)), (_recast_story.get("picked", []) as Array).size(),
		"new face" if (_recast_story.get("picked", []) as Array).size() == 1 else "new faces"])
var _faces_kept := {}  # name -> {"key", "look"}: everyone's portrait as given (_give_portrait), kept after they've gone
var _zoomed_tonight := false  # the night's first big moment's had the zoom (its caption and face over the whole window)


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


## Clicking the owner: the camera follows them (the airtime goes to the owner: see camera.gd).
func _on_owner_clicked(event: InputEvent) -> void:
	if not _left_click(event) or _owner.is_empty():
		return
	if _camera.on_owner:
		_camera_off("pd")
	else:
		_camera_on_owner()


## The camera turns to the owner: the viewfinder on them, and the first time tonight they notice
## (a moment for their next line, and in the conversation it's said in).
func _camera_on_owner() -> void:
	var previous: Variant = _camera.follow_owner()
	_viewfinder_off(previous)
	var named := str(_owner["name"])
	var noticing := _camera.owner_notices()
	if noticing:
		_owner_camera_moment = Talk.camera_moment(named, _camera.crew)
	PdDesk.viewfinder(_owner_node, Rect2(-4, -8, 88, 166))
	_narrate("The camera follows %s, the owner." % _owner_display())
	_event("camera_on", {"name": named, "owner": true, "from": _camera_name(previous), "noticing": noticing}, _owner_node)
	DebugLog.say("Camera", "on the owner%s" % (" (they notice)" if noticing else ""))
	_show_camera()


## The owner's line, with the camera on them: the moment they notice it (once), or now and then
## a little more of themselves (Talk.OWNER_ON_CAMERA). guest: who they're talking to (whose
## conversation hears the camera turn).
func _owner_on_camera(direction: String, guest: Guest) -> String:
	if not _camera.on_owner:
		_owner_camera_moment = ""
		return direction
	if _owner_camera_moment != "":
		direction = (_owner_camera_moment + " " + direction).strip_edges()
		_owner_camera_moment = ""
		if guest != null:
			guest.transcript.append({"action": Talk.camera_happened(str(_owner["name"]), _camera.crew)})
		_event("owner_noticed_camera", {"name": str(_owner["name"])}, _owner_node)
	elif randf() < PdCamera.OWNER_SHOWS:
		direction = (direction + " " + Talk.OWNER_ON_CAMERA).strip_edges()
		_event("owner_on_camera", {"name": str(_owner["name"])}, _owner_node)
		DebugLog.say("Camera", "the owner shows a little more of themselves (to %s)" % (str(guest.customer["name"]) if guest != null else "the counter"))
	return direction


## Hovering over the owner: who they are, and what a click does.
func _update_owner_hover() -> void:
	var area: Control = null
	if is_instance_valid(_owner_node):
		area = _owner_node.get_node_or_null("Hover") as Control
	if area == null or _owner.is_empty():
		return
	var text := "%s, the owner of %s" % [_owner_label(), str(Game.bar.get("name", "the tent"))]
	text += "\n" + ("● The camera's on them: click to stop" if _camera != null and _camera.on_owner else "Click to follow them with the camera")
	_give_portrait(area, _owner)
	area.tooltip_text = Text.tip(text)


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
		PdDesk.viewfinder(guest.node, Rect2(-4, -8, 88, 166))
		_plant_in(guest.transcript, guest)  # (they've noticed: it's in their conversation)
		_narrate("The camera follows %s." % named)
	else:
		PdDesk.viewfinder(_cat_node, Rect2(-6, -6, 58, 40))
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
	_event("camera_off", {"name": _camera_name(was), "why": why}, _camera_node(was))
	_show_camera()


## A Guest's name, the cat's ("cat"), the owner's ("owner"), or "".
func _camera_name(who: Variant) -> String:
	if who == null:
		return ""
	if who is String:
		return str(_owner.get("name", "the owner")) if who == "owner" else str(_cat.get("name", "the cat"))
	return str(who.customer["name"])


## Whoever the camera was on, as drawn: a Guest's node, the cat's, the owner's (or null).
func _camera_node(who: Variant) -> Control:
	if who == null:
		return null
	if who is String:
		return _owner_node if who == "owner" else _cat_node
	return who.node if is_instance_valid(who.node) else null


## Takes the viewfinder off whoever it was on (a Guest, "cat", "owner", or null).
func _viewfinder_off(who: Variant) -> void:
	var node := _camera_node(who)
	if node != null:
		PdDesk.viewfinder_off(node)


## The corner's "● REC" and who, and the hovers saying what a click does.
func _show_camera() -> void:
	if _pd != null:
		if _camera.on_cat:
			_pd.show_rec("%s (the cat)" % _cat.get("name", ""), _cat_tooltip())
		elif _camera.on_owner:
			_pd.show_rec("%s (the owner)" % _owner_display(), Text.tip("The show's camera is following %s, the owner. Click them to stop." % _owner_display()))
		elif _camera.following != null:
			var who := str(_camera.following.customer["name"])
			_pd.show_rec(who, Text.tip("The show's camera is following %s. Click them to stop." % who))
		else:
			_pd.show_rec("", "")
	for guest in _guests:
		_update_hover(guest)
	_update_owner_hover()
	_update_desk()
	if not _cat.is_empty() and _tent_cat != null and _tent_cat.node != null:
		_cat_node.tooltip_text = _cat_tooltip()


## The PD's desk, brought up to date (who the camera's on, tonight's cards).
func _update_desk() -> void:
	if _pd != null:
		_pd.recut = ("✂ Step in: re-cut %s (Enter)" % _last_episode_words()) if _step_in_open and _night_open and not Game.bar.get("diary", []).is_empty() else ""
		_pd.refresh()


# --- The PD's plant cards -------------------------------------------------------------------

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


## Whether a regular's at the counter (or, waiting too, waiting to come in or being greeted).
func _regular_in(regular_id: String, waiting_too: bool = true) -> bool:
	if regular_id == "":
		return false
	if _guests.any(func(g): return str(g.customer.get("regular_id", "")) == regular_id):
		return true
	return waiting_too and (_waiting_who.has(regular_id) or _greeting_regular == regular_id)


## The bar's regulars who aren't here tonight and aren't waiting to come in.
func _regulars_away() -> Array:
	# (Not someone who's been and gone tonight either: 19 Nov, the PD rang one back two hours after he'd paid.)
	return RegularsTonight.all(Game.bar).filter(func(r): return not _regular_in(str(r["id"])) and str(r["id"]) != _planted_regular and not _names_tonight.has(str(r["name"])))


## A card's been played on the desk (see PdDesk.play): it happens, now, to whoever it's for
## (aimed: told in the conversation they speak in next, and as a moment for their line), and a
## fact card makes its fact true. text: what the PD wrote, for a write-in; what: the card's
## variant tonight ("" for a card without them). Never pauses anything.
func _card_happens(card: String, text: String, aimed: Array, what: String) -> void:
	var data: Dictionary = Plants.CARDS[card]
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
						_plant_on(other, card, Plants.others_moment(card, who, for_ai), Plants.happened(card, who, "", what, gender, for_ai))
			about = target.node
			if text != "":
				_show("[color=#%s][b]%s[/b][/color] [i]%s[/i]\n\n" % [CAMERA_RED.to_html(false), _esc("[PD]"), Glossary.explain(_esc(Plants.shown(card, who, what, gender, text)), _names_here())])
			else:
				_narrate(Plants.shown(card, who, what, gender))
			# A cue card is their conversation's topic for a while; a big moment (the ex walking past)
			# stays on their minds for a few lines, for the talk to come back to.
			var steers := int(data.get("write", {}).get("steers", 0))
			var steer := Talk.cue_hint(for_ai) if steers > 0 else ""
			if steers == 0 and Plants.lingers(card) > 0:
				steers = Plants.lingers(card)
				steer = Talk.aftermath_hint(Plants.happened(card, who, "", what, gender, for_ai))
			if steers > 0:
				var chat := _chat_of(target)
				if chat != null:
					chat.pd_topic = steer
					chat.pd_topic_lines = steers
				else:
					target.pd_topic = steer
					target.pd_topic_lines = steers
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
			var pair_chat := _chat_of(a)
			if Plants.lingers(card) > 0 and pair_chat != null:  # (it's what they talk about for a while)
				pair_chat.pd_topic = Talk.aftermath_hint(said)
				pair_chat.pd_topic_lines = Plants.lingers(card)
		"tent":
			for guest in _guests:
				_plant_on(guest, card, Plants.moment(card, str(guest.customer["name"]), "", what), Plants.happened(card, "", "", what))
			for chat in _chats:
				chat.transcript.append({"action": Plants.happened(card, "", "", what)})
			# The owner's in the tent too, and talks most: their next line reacts (18 Nov: the song and
			# the power cut went by with nobody but the customers told, and they talked on).
			_night.owner_plant_moment = Plants.moment(card, str(_owner["name"]), "", what)
			_night.owner_plant_card = card
			if Plants.lingers(card) > 0:  # (and it stays on everyone's minds for a few lines)
				var steer := Talk.aftermath_hint(Plants.happened(card, "", "", what))
				for guest in _guests:
					if _chat_of(guest) == null:
						guest.pd_topic = steer
						guest.pd_topic_lines = Plants.lingers(card)
				for chat in _chats:
					chat.pd_topic = steer
					chat.pd_topic_lines = Plants.lingers(card)
			if str(data.get("fact", "")) == "":
				_narrate(Plants.happened(card, "", "", what))
	# The facts: what the game makes true.
	match str(data.get("fact", "")):
		"regular_in":
			var away := _regulars_away()
			var regular: Dictionary = away[_pd.dice.randi_range(0, away.size() - 1)]
			who = str(regular["name"])
			_planted_regular = str(regular["id"])
			for due in _regulars_due.duplicate():
				if str(due["id"]) == _planted_regular:
					_regulars_due.erase(due)  # (coming anyway, later: the call brings them sooner)
			_regulars_due.append({"time": _clock + PLANT_REGULAR_MINUTES, "id": _planted_regular})
			_regulars_due.sort_custom(func(x, y): return float(x["time"]) < float(y["time"]))
			_narrate("The PD rings %s: could they come down to the tent tonight?" % who)
		"weather":
			_change_weather(what if what != "" else str(data["weather"]))  # (wild weather: this time's)
			_narrate("Out of nowhere, the heavens open: rain drums on the tarp." if what == "" else Plants.happened(card, "", "", what))
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
		colour.to_html(false), _esc(_name_label(guest.customer)), Glossary.explain(_esc(line), _names_here())], _said_line(str(guest.customer["name"]), line))


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

## A card happens to someone: their moment, and what happened for the conversation they speak in next.
func _plant_on(guest: Variant, card: String, moment: String, what: String) -> void:
	guest.plant_moment = moment
	guest.plant_card = card
	guest.plant_happened = what
	guest.card_turn = false
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
		said.append(Talk.camera_happened(str(guest.customer["name"]), _camera.crew))
	if guest.plant_moment != "" and guest.plant_happened != "":
		said.append(guest.plant_happened)
	for what in said:
		if not transcript.any(func(entry): return str(entry.get("action", "")) == what):
			transcript.append({"action": what})


## A line given a PD's card (hint "plant_…"), in the notes: who said it, where, whether it
## seems to have taken the card up, and the line, so a card that went by unmentioned shows.
## where: "to Kim Soo-ok", "in a chat with Kang Tae-oh".
func _log_card_line(who: String, hint: String, taken: bool, line: String, where: String) -> void:
	if not hint.begins_with("plant_"):
		return
	DebugLog.say("Plants", "%s's line on the %s card, %s: %s «%s»" % [who, hint.trim_prefix("plant_"), where, "taken up" if taken else "not taken up (by the words)", Text.shorten(line, 90)])


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


const HOVER_REMEMBERED := 60  # ...and at most this much of what the owner remembers


## One short thing the owner remembers about them, for the hover: a fact that sticks (short by
## nature: "From: Busan"), or the owner's impression, cut short at a word. (The memories are
## whole sentences: all of them are in who's here now, over their name.)
func _remembered_briefly(known: Dictionary) -> String:
	var facts: Dictionary = known.get("facts", {})
	var brief := ""
	for key in Memories.STICKING:
		if str(facts.get(key, "")) != "":
			brief = "%s: %s" % [str(Memories.FACT_LABELS[key]).capitalize(), Memories.fact_text(facts[key])]
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
	if problem == "":
		problem = Talk.served_already(str(data["line"]), items, _kitchen_part.all_coming())
	if problem == "":
		problem = Memories.contradiction(str(data["line"]), speaker, _family_of(speaker))
	if problem == "" and not _ai.offline:  # (offline, the pre-written lines repeat by design)
		var worn := _stats.worn_out_in(str(data["line"]), names)
		if worn != "" and _worn_strikes >= WORN_STRIKES:  # (asked twice already: better said again than the chat given up)
			DebugLog.say("Worn out", "«%s» let through after %d tries" % [worn, _worn_strikes])
			_stats.worn_let_through += 1
			worn = ""
		if worn != "":
			_worn_strikes += 1
			problem = "the line says «%s», and that's been said a lot tonight already: say it another way" % worn
	if problem == "":
		_worn_strikes = 0
	return problem


## A line sent back this many times for a phrase said too often lets it through the next time
## (19 Nov: three chats fizzled out in ten nights, the AI saying «a long night» three times over).
const WORN_STRIKES := 2
var _worn_strikes := 0


func _validate_cat_name(data: Variant, taken: Array) -> String:
	return CatRules.validate_cat_name(data, str(_owner["name"]), taken)


# --- Building the screen ------------------------------------------------------

func _build_ui() -> void:
	# The PD's desk (built into its panel below, and its REC into the stage's corner).
	_pd = PdDesk.new(_night)
	_pd.now = _plant_now
	_pd.guests = func(): return _guests
	_pd.pair_partner = _pair_partner
	_pd.cat = func(): return _cat
	_pd.owner_called = func(): return _owner_display()
	_pd.happens = _card_happens
	_pd.airs = _air_moment
	_pd.camera = _camera
	_pd.link = _on_transcript_link  # (a pinned line clicked on the desk: let it go)
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
	_mode_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	_ratings_label = Label.new()
	_ratings_label.name = "RatingsLabel"
	_ratings_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ratings_label.mouse_filter = Control.MOUSE_FILTER_STOP  # (for its hover, and a click: the side panel's The show)
	_ratings_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ratings_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_the_show())
	_ratings_label.visible = false
	bar.add_child(_ratings_label)

	# The menu (Esc, or the top bar's one button) drops down over the tent: the diary, closing
	# the bar, the ladder's rules, and the settings, so they don't crowd the top bar (see
	# _build_options_panel; more settings will go there).
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
	_leave_button.pressed.connect(func(): _options_button.button_pressed = false)
	_leave_button.pressed.connect(_on_leave_pressed)
	_menu_buttons.add_child(_leave_button)

	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "☰ Menu (Esc)"
	_options_button.tooltip_text = Text.tip("The options (sound, music, speech bubbles, TV captions, reading pauses, the stats panel) and closing the bar.")
	_options_button.toggle_mode = true
	_options_button.custom_minimum_size = Vector2(140, 40)
	_options_button.toggled.connect(_on_menu_toggled)
	bar.add_child(_options_button)

	# "Let the crew run it" (autoplay in the game): a badge on the top bar while they are, and its
	# row at the top of the menu (crew_controls.gd).
	_crew = CrewControls.new()
	_crew.name = "Crew"
	add_child(_crew)
	_crew.build(bar, _options_panel.get_child(0), _badge(Ktv.MINT))
	_crew.start_asked.connect(_on_crew_start)
	_crew.stop_chosen.connect(_on_crew_stop)

	# The street behind it all, in pixel art, reaching above the tent (street_art.gd).
	_street_art = StreetArt.new()
	_street_art.position = Vector2((SCREEN.x - STAGE_SIZE.x) / 2, 60)
	add_child(_street_art)

	# The tent: nearly the full width, with five stools.
	_stage = Control.new()
	_stage.name = "Tent"
	_stage.position = Vector2((SCREEN.x - STAGE_SIZE.x) / 2, 60 + STAGE_ROOM)
	_stage.size = STAGE_SIZE
	_stage.clip_contents = true
	add_child(_stage)
	_street = Street.new(_night, _people_view, _stage)  # (people walk along in front of the tent)
	_build_stage(_stage)

	# Bottom left: what's being said
	_log_panel = _panel(Vector2(24, PANELS_TOP), Vector2(400, SCREEN.y - PANELS_TOP - 24))  # (sized in _layout_panels)
	add_child(_log_panel)
	var log_box := TranscriptView.new()  # (its toolbar, the lines, and "↓ new lines": transcript_view.gd)
	log_box.name = "TranscriptView"
	_log_panel.add_child(log_box)
	log_box.render = _render
	log_box.build()
	log_box.used.connect(_on_transcript_used)
	_transcript_view = log_box
	_log = log_box.transcript
	_log.meta_clicked.connect(func(meta):
		if Game.autoplay == null:  # (pinning and stepping in are the crew's while they're running it)
			_on_transcript_link(meta))
	_typing_label = Label.new()
	_typing_label.name = "Status"
	_typing_label.add_theme_color_override("font_color", MUTED)
	log_box.add_child(_typing_label)

	# Beside it, the PD's desk: the camera (and, to come, the plant cards).
	_desk_panel = _panel(Vector2.ZERO, Vector2(DESK_WIDTH, 100))
	_desk_panel.name = "PdDesk"
	add_child(_desk_panel)
	_pd.build(_desk_panel)

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
	_feed = SocialFeed.new()  # (the posts round the page: over the whole window)
	_feed.z_index = 25  # (as the summary: the page and its posts together)
	_feed.visible = false
	add_child(_feed)
	_summary.visibility_changed.connect(_sync_feed)
	_diary_page.visibility_changed.connect(_sync_feed)
	_season_page = SeasonPage.new()  # (after a finale, in the diary's place)
	_season_page.name = "SeasonPage"
	_season_page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_season_page.visible = false
	summary_col.add_child(_season_page)
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
	_season_button = Button.new()
	_season_button.name = "SeasonButton"
	_season_button.custom_minimum_size = Vector2(140, 48)
	_season_button.tooltip_text = Text.tip("The season looked back on, or the diary.")
	_season_button.visible = false
	_season_button.pressed.connect(_on_season_toggled)
	summary_buttons.add_child(_season_button)
	_recast_button = Button.new()
	_recast_button.name = "RecastButton"
	_recast_button.text = "📷  Recast a face"
	_recast_button.custom_minimum_size = Vector2(220, 48)
	_recast_button.tooltip_text = Text.tip("Have new casting photos taken of a regular (about half a minute), and pick one for their face on the show. Only now, while the image model has the GPU between nights.")
	_recast_button.visible = false
	_recast_button.pressed.connect(_open_recast)
	summary_buttons.add_child(_recast_button)
	summary_buttons.add_child(next_night)
	_summary_buttons = [next_night, _recast_button]
	_summary_leave = Button.new()
	_summary_leave.name = "SummaryLeaveButton"
	_summary_leave.text = "Close the bar"
	_summary_leave.custom_minimum_size = Vector2(200, 48)
	_summary_leave.pressed.connect(_on_leave_pressed)
	summary_buttons.add_child(_summary_leave)


func _badge(colour: Color) -> StyleBoxTexture:
	return PixelFrame.style([colour, colour.darkened(0.35), colour.lightened(0.15), colour.darkened(0.12)], Vector2(9, 6))  # (in pixels: pixel_frame.gd)


## The menu (Esc, or the top bar's button): a window over the bar, its actions along the top
## (closing the bar; more to come), then the options. (The diary and the show are in the side
## panel's tabs.) Returns the Options column, for the settings.
func _build_options_panel() -> VBoxContainer:
	_options_panel = _panel(Vector2((SCREEN.x - MENU_WIDTH) / 2, 60), Vector2(MENU_WIDTH, 0))
	_options_panel.name = "OptionsPanel"
	_options_panel.z_index = 20  # over the tent, the bubbles and the captions
	_options_panel.visible = false
	_options_panel.add_theme_stylebox_override("panel", PixelFrame.style([Ktv.PANEL, ACCENT, PixelFrame.PANEL[2], PixelFrame.PANEL[3]]))  # (its edge in the accent: it's over the tent)
	add_child(_options_panel)
	# Clicks go to whatever's last in the tree, whatever's drawn on top: the panel's built
	# before the tent and the other panels, so it's moved to the end once they're all in.
	(func(): move_child(_options_panel, get_child_count() - 1)).call_deferred()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_options_panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	var heading := Label.new()
	heading.text = "Menu"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", ACCENT)
	top.add_child(heading)
	_menu_buttons = HBoxContainer.new()  # the actions (closing the bar: added in _build_ui)
	_menu_buttons.name = "MenuButtons"
	_menu_buttons.add_theme_constant_override("separation", 12)
	top.add_child(_menu_buttons)
	var close_menu := Button.new()
	close_menu.name = "MenuClose"
	close_menu.text = "✕ (Esc)"
	close_menu.custom_minimum_size = Vector2(100, 40)
	close_menu.pressed.connect(func(): _options_button.button_pressed = false)
	top.add_child(close_menu)
	var settings := Label.new()
	settings.text = "⚙ Options"
	settings.add_theme_font_size_override("font_size", 20)
	settings.add_theme_color_override("font_color", ACCENT)
	column.add_child(settings)
	var options := VBoxContainer.new()
	options.name = "Options"
	options.add_theme_constant_override("separation", 10)
	column.add_child(options)
	return options


## The menu opens (Esc, or the top bar's button) or closes.
func _on_menu_toggled(on: bool) -> void:
	_options_panel.visible = on
	if on:
		_update_crew()  # (whether the crew can take over now)
		_options_panel.reset_size()


func _panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", PixelFrame.style(PixelFrame.PANEL))  # (a frame in pixels, as the stage: pixel_frame.gd)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return panel


## Grey-box tent: overpass, glow, bulbs, owner, stove, counter, stools and roof.
## Children are drawn in the order they're added, so later things sit in front (customers
## are added as they arrive, so they stand in front of the counter).
func _build_stage(stage: Control) -> void:
	var w := STAGE_SIZE.x
	_tent_view.sky = _rect(stage, Vector2.ZERO, STAGE_SIZE, Color("3c3a72"))  # the night sky, changing with the hour
	_tent_view.sky.name = "Sky"
	_tent_view.weather_back = _layer(stage, "WeatherBack")
	var city: Array = [_tent_view.sky]  # (the stage's own sky and overpass, in shapes: left out when the street's art shows through)
	city.append(_rect(stage, Vector2(0, 0), Vector2(w, 36), Color("0c0b1a")))  # the overpass
	city.append(_rect(stage, Vector2(40, 36), Vector2(44, 344), Color("1f1e36")))  # pillars
	city.append(_rect(stage, Vector2(w - 84, 36), Vector2(44, 344), Color("1f1e36")))
	if StreetArt.has_art():
		for piece in city:
			piece.visible = false
	_scenery.build_neon(stage)
	_tent_view.glow = _rect(stage, Vector2(110, 110), Vector2(w - 220, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_tent_view.glow.name = "Glow"
	_rect(stage, Vector2(0, 372), Vector2(w, 8), Color("2a2840"))  # wet street
	_road = Control.new()  # its reflections, on a wet night (street_lights.gd)
	_road.name = "Road"
	_road.position = StreetLights.ROAD
	_road.size = Vector2(w, 8)
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_road)
	_street_lights = StreetLights.new()
	_street_lights.name = "StreetLights"
	add_child(_street_lights)
	var tent_from := stage.get_child_count()  # from here on is the tent (the cat and sign aside)

	for bulb_x in [621.0, 1251.0]:  # (on the street's grid: a pixel to 3)
		var bulb := Control.new()  # hung from the top of its wire, so it swings from there
		bulb.position = Vector2(bulb_x, 111)
		bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bulb)
		var wire := Control.new()  # its wire, in the grid's pixels, leaning as it swings (tent_view.gd draw_wire)
		wire.name = "Wire"
		wire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wire.draw.connect(TentView.draw_wire.bind(wire))
		bulb.add_child(wire)
		var glass: Control = Art.place(bulb, "tent/bulb", Vector2(-9, 36), "topleft", 3)  # the bulb, in pixel art (tinted by the hour: tent_view.gd)
		if glass == null:
			Art.drawn("tent/bulb")
			glass = _rect(bulb, Vector2(-8, 36), Vector2(16, 16), OWNER_TEXT)
		_tent_view.bulb_lights.append(glass)
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
	var owner_area := PortraitHover.new()  # (who they are, with their portrait, and a click: the camera follows them, as a customer)
	owner_area.name = "Hover"
	owner_area.position = Vector2(15, 0)
	owner_area.size = Vector2(Layout.PERSON_SIZE.x - 30, Layout.PERSON_SIZE.y)
	owner_area.mouse_filter = Control.MOUSE_FILTER_STOP
	owner_area.gui_input.connect(_on_owner_clicked)
	_owner_node.add_child(owner_area)

	var counter: Array = [_rect(stage, Vector2(100, 250), Vector2(w - 182, 18), Color("8a5a33"))]  # counter top
	counter.append(_rect(stage, Vector2(120, 268), Vector2(w - 222, 104), Color("5c3820")))  # counter front
	_pixel_piece(stage, "tent/counter", COUNTER_ART_AT, counter)
	var stove: Array = [_rect(stage, Vector2(104, 244), Vector2(236, 6), Color("3a3946"))]  # the stove
	stove.append(_rect(stage, Vector2(130, 241), Vector2(40, 3), Color("e8833a")))  # a flame
	_pixel_piece(stage, "tent/stove", Vector2(102, 240), stove)
	_scenery.build_odeng_pot(stage)
	_tent_view.decor_counter = _layer(stage, "DecorCounter")

	# What's cooking (and what's ready to carry over), at the stove.
	_kitchen_part.stove_row = HBoxContainer.new()
	_kitchen_part.stove_row.name = "Stove"
	_kitchen_part.stove_row.position = Vector2(176, 207)  # beside the odeng pot
	_kitchen_part.stove_row.size = Vector2(160, 34)
	_kitchen_part.stove_row.add_theme_constant_override("separation", 4)
	_kitchen_part.stove_row.clip_contents = true
	_kitchen_part.stove_row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (the row lets clicks through to the owner behind it; its dishes keep their hovers)
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
		drinks.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (so the owner, standing behind it, can be clicked: 20 Nov)
		stage.add_child(drinks)
		_drinks_rows.append(drinks)
		var food := HBoxContainer.new()
		food.name = "Food%d" % seat
		food.position = Vector2(x + 46, 216)
		food.size = Vector2(104, 34)
		food.add_theme_constant_override("separation", 4)
		food.clip_contents = true
		food.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(food)
		_food_rows.append(food)
		var stool: Array = [_rect(stage, Vector2(x - 35, 312), Vector2(70, 12), Color("9a9ab0"))]  # stool (its seat a person's knee high)
		stool.append(_rect(stage, Vector2(x - 6, 324), Vector2(12, 48), Color("6e6e86")))
		_pixel_piece(stage, "tent/stool_red" if seat % 2 == 0 else "tent/stool_blue", Vector2(snappedf(x - 39, 3), 312), stool)

	_tent_view.roof = Polygon2D.new()
	_tent_view.roof.name = "Tarp"
	_tent_view.roof.polygon = PackedVector2Array([Vector2(100, 40), Vector2(w - 100, 40), Vector2(w - 22, 112), Vector2(22, 112)])
	_tent_view.roof.color = ACCENT
	_tent_cat.build(stage)
	_tent_cat.node.gui_input.connect(_on_cat_clicked)
	stage.add_child(_tent_view.roof)
	_tent_view.roof_stripes = _layer(stage, "TarpStripes")
	_tent_view.roof_edge = _rect(stage, Vector2(22, 112), Vector2(w - 44, 10), Color("c8612a"))
	_tent_view.roof_art = _layer(stage, "TarpArt")
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
	_pd.build_rec(stage)  # ("● REC" in the stage's corner, never hidden)
	_captions_part.layer = _caption_layer
	_captions_part.zoom_layer = self  # (a zoom: over the whole window)
	_captions_part.screen = SCREEN
	_captions_part.bubble_layer = _bubble_layer
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
## One of the tent's pieces in pixel art, if there's art for it (art/tents: tools/art/tent.py):
## drawn at at (its top-left corner, on the street's grid: each pixel 3 on screen), just in
## front of the shapes it stands in for, which go (freed: hidden, the tent's look showed them
## again, drawn behind the art every frame). Without it, the shapes stay.
func _pixel_piece(stage: Control, key: String, at: Vector2, shapes: Array) -> void:
	var art := Art.place(stage, key, at, "topleft", 3)
	if art == null:
		Art.drawn(key)
		return
	stage.move_child(art, shapes[-1].get_index() + 1)
	for shape in shapes:
		stage.remove_child(shape)
		shape.queue_free()


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
	_street_art.set_sky(_tent_view.sky.color)
	# The pixels' light (pixel_light.gd), in the stage's coordinates: the tent's and people's
	# pieces are drawn on the screen, the street's on its grid (a pixel to 3).
	var stage_at := _stage.get_global_transform().origin
	PixelLight.place_kind("tent", 1.0, -stage_at)
	PixelLight.place_kind("people", 1.0, -stage_at)
	PixelLight.place_kind("tarp", 1.0, -stage_at)
	PixelLight.place_kind("street", StreetArt.SCALE, _street_art.get_global_transform().origin - stage_at)
	var hour := floori(_clock / 60.0)
	if _night_open and hour != _light_hour:  # (logged on the hour: how dark, under the bulbs and out in the street)
		_light_hour = hour
		# Under the first bulb (on the counter below it) against the counter's far end: its pool of
		# light (pixel_light.gd), the brightest it's been tonight in the stats.
		var under := PixelLight.ambient_steps
		if not PixelLight.bulbs.is_empty():
			var bulb: Vector4 = PixelLight.bulbs[0]
			under = PixelLight.light_at(Vector2(bulb.x, 250))
		var far_end := PixelLight.light_at(Vector2(120, 250))
		_stats.art["pools"] = maxf(float(_stats.art.get("pools", 0.0)), under - far_end)
		DebugLog.say("Light", "%s · the night %.1f steps · at the counter %.1f · under a bulb %.1f · the counter's end %.1f · out front %.1f · the street %.1f" % [NightRules.clock_text(hour * 60),
			PixelLight.ambient_steps, PixelLight.light_at(Vector2(STAGE_SIZE.x / 2, 250)), under, far_end, PixelLight.light_at(Vector2(80, 360), "people"),
			PixelLight.light_at(Vector2(STAGE_SIZE.x / 2, -40), "street")])


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
			"look": look, "introduced": false,
		}
		for key in ["name", "hangul", "gender", "age", "job", "speech_style", "appearance"]:
			regular[key] = reply.get(key, "")
		made.append(regular)
		taken.append(str(reply["name"]))
	# Founding regulars and the owner go back years (old friends, on first-name terms); the two of
	# them have known each other for years too (first names, not yet close).
	for regular in made:
		var bond := Bonds.between(Game.bar, Bonds.OWNER, str(regular["id"]), "founding")
		bond["meetings"] = int(regular["visits"])
		Bonds.learn_name(bond, Bonds.OWNER)
		Bonds.learn_name(bond, str(regular["id"]))
	for i in made.size():
		for j in range(i + 1, made.size()):
			var bond := Bonds.between(Game.bar, str(made[i]["id"]), str(made[j]["id"]), "regulars for years")
			bond["meetings"] = 20
			Bonds.learn_name(bond, str(made[i]["id"]))
			Bonds.learn_name(bond, str(made[j]["id"]))
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
	for due in _regulars_due:
		if due.has("with"):
			_stats.closeness["together"] = int(_stats.closeness.get("together", 0)) + 1
			DebugLog.say("Regulars", "%s's coming in around the same time as their friend %s" % [_regular(str(due["id"])).get("name", due["id"]), _regular(str(due["with"])).get("name", due["with"])])


## A regular's facts, for the prompts (see RegularsTonight.facts).
func _regular_facts(regular: Dictionary) -> Dictionary:
	return RegularsTonight.facts(Game.bar, regular, _night_number)


## A regular comes in: not reinvented, just asked what sort of night they're having.
func _regular_tonight(regular: Dictionary, guest: Guest) -> Dictionary:
	var customer := {}
	for key in ["name", "hangul", "gender", "age", "job", "speech_style", "appearance"]:
		customer[key] = regular.get(key, "")
	if regular.get("face", {}) is Dictionary and not (regular.get("face", {}) as Dictionary).is_empty():
		customer["face"] = (regular["face"] as Dictionary).duplicate()  # (a face of their own: _own_face)
	customer["look"] = Regulars.dressed_for(regular.get("look", {}), _weather_kind)
	customer["regular"] = _regular_facts(regular)
	customer["regular_id"] = regular["id"]
	DebugLog.say("Carried in", "%s: %s" % [regular["name"], RegularsTonight.carried_in(Game.bar, regular)])
	var thread := Memories.open_thread(regular)
	if not thread.is_empty():  # (something they mentioned last time: the owner asks how it went)
		guest.thread_moment = Memories.thread_note(thread, _night_number)
		thread["asked"] = int(thread["asked"]) + 1
		_stats.threads["asked"] = int(_stats.threads.get("asked", 0)) + 1
		DebugLog.say("Threads", "%s mentioned %s on night %d: the owner might ask" % [regular["name"], thread["text"], int(thread["night"])])
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
		_stats.regulars_in += 1
	else:
		var roll := Hooks.regular_roll_override if Hooks.regular_roll_override >= 0.0 else randf()
		if not Regulars.becomes_regular(verdict, rushed, roll):
			return
		regular = Regulars.new_regular(guest.customer, guest.customer.get("look", {}), guest.first_order, _night_number, _day_index(), guest.arrived_minutes, randf())
		_regulars().append(regular)
		var they: String = {"woman": "she'll", "man": "he'll"}.get(str(guest.customer.get("gender", "")), "they'll")
		_narrate("%s looks like %s be back." % [guest.customer["name"], they])
		_event("became_regular", {"gender": str(guest.customer.get("gender", "")), "name": str(guest.customer["name"])}, guest.node)
	var bond := Bonds.between(Game.bar, Bonds.OWNER, str(regular["id"]))
	Bonds.meet(bond, _night_number)
	if str(memory.get("towards_owner", "")) == "warmer":
		bond["warmth"] = int(bond.get("warmth", 0)) + 1  # (for friendlier terms)
	if not memory.is_empty():
		var changed := RegularsTonight.remember(Game.bar, regular, _night_number, memory, _heard(guest))
		for key in changed["facts"]:
			var fact: Dictionary = regular["facts"][key]
			_stats.record_fact(key, fact["known_by"])
			DebugLog.say("Facts", "%s's %s, \"%s\" (known by %s)" % [guest.customer["name"], key, fact["text"], ", ".join(PackedStringArray(fact["known_by"].map(func(w): return "the owner" if w == Bonds.OWNER else str(_regular(str(w)).get("name", w))))) if not fact["known_by"].is_empty() else "only them"])
		if changed["thread_closed"]:
			_stats.threads["closed"] = int(_stats.threads.get("closed", 0)) + 1
			DebugLog.say("Threads", "%s said how it went: %s" % [guest.customer["name"], memory["followed_up"]])
		if changed["thread_opened"]:
			_stats.threads["opened"] = int(_stats.threads.get("opened", 0)) + 1
			DebugLog.say("Threads", "%s has something coming up: %s" % [guest.customer["name"], memory["coming_up"]])
	_stats.threads["dropped"] = int(_stats.threads.get("dropped", 0)) + Memories.drop_stale(regular, _night_number)
	# Names, once they've been said (the full name, or the given name).
	if _name_said(str(guest.customer["name"]), said):
		Bonds.learn_name(bond, Bonds.OWNER)
	if _name_said(str(_owner["name"]), said):
		Bonds.learn_name(bond, str(regular["id"]))
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
		Prompts.memory_messages(_owner, guest.customer, guest.transcript, guest.chat_lines, str(guest.customer.get("regular", {}).get("thread", ""))),
		_validate_memory.bind(said, _not_facts()), {"temperature": 0.4}, {"purpose": "memory", "verdict": game_verdict})
	if _closed():  # (the bar closed while it was waiting)
		return {}
	if memory.is_empty():
		_stats.memories_failed += 1
	return memory


## Where the things a customer said tonight were heard, and by whom (for who knows which facts:
## Memories.who_heard): their talk with the owner (the owner), and each of their chat lines
## (whoever else was in that chat: regulars by id, the owner if they'd joined in).
func _heard(guest: Guest) -> Array:
	var who := str(guest.customer["name"])
	var heard: Array = [{"text": " ".join(PackedStringArray(guest.transcript.filter(func(e): return e.has("text") and str(e.get("speaker", "")) == who).map(func(e): return str(e["text"])))).to_lower(), "by": [Bonds.OWNER]}]
	for entry in guest.chat_lines:
		if str(entry.get("speaker", "")) == who:
			heard.append({"text": str(entry["text"]).to_lower(), "by": entry.get("heard_by", [])})
	return heard


## At closing (so it never takes the owner's voice mid-night): each pair of regulars who chatted
## tonight (newcomers who became regulars included) remember each other, from what was said: a
## memory each in their bond, a fact each (known by whoever heard it), anything coming up.
func _regulars_remember_each_other() -> void:
	_bond_tonights_pairs()
	if not Hooks.memories:
		return
	for pair in RegularsTonight.chat_pairs(Game.bar, _night_chats.values()):
		var a: Dictionary = pair["a"]
		var b: Dictionary = pair["b"]
		_typing_label.text = "%s and %s remember the night..." % [a["name"], b["name"]]
		var memory: Dictionary = await _ai.ask_json(Prompts.pair_memory_messages(a, b, pair["lines"]),
			_validate_pair_memory.bind(RegularsTonight.said_by(pair, a), RegularsTonight.said_by(pair, b), _not_facts()), {"temperature": 0.4},
			{"purpose": "pair_memory", "first": str(a["name"]), "second": str(b["name"])})
		_typing_label.text = ""
		if _stopped or str(Game.bar.get("id", "")) == "":
			return
		if memory.is_empty():
			_stats.pair_memories["failed"] = int(_stats.pair_memories.get("failed", 0)) + 1
			continue
		_stats.pair_memories["saved"] = int(_stats.pair_memories.get("saved", 0)) + 1
		var changed := RegularsTonight.remember_pair(Game.bar, pair, _night_number, memory)
		DebugLog.say("Regulars remember each other", "%s: \"%s\" · %s: \"%s\"" % [a["name"], memory["first_remembers"], b["name"], memory["second_remembers"]])
		for learned in changed["facts"]:
			var fact: Dictionary = learned[0]["facts"][learned[1]]
			_stats.record_fact(learned[1], fact["known_by"])
			DebugLog.say("Facts", "%s's %s, \"%s\" (known by %s, from a chat)" % [learned[0]["name"], learned[1], fact["text"], ", ".join(PackedStringArray(fact["known_by"].map(func(w): return "the owner" if w == Bonds.OWNER else str(_regular(str(w)).get("name", w)))))])
		for opened in changed["threads"]:
			_stats.threads["between"] = int(_stats.threads.get("between", 0)) + 1
			DebugLog.say("Threads", "%s has something coming up (said in a chat): %s" % [opened[0]["name"], opened[1]])
	Game.save()


func _validate_pair_memory(data: Variant, first_said: String, second_said: String, not_facts: Array) -> String:
	return Memories.validate_pair_memory(data, first_said, second_said, not_facts)


func _validate_memory(data: Variant, said: String, not_facts: Array = []) -> String:
	return Memories.validate_memory(data, said, not_facts)


## Words that make a "fact" not one about their life: the show (a PD's call isn't a worry of
## theirs), and the tent's cat (not their pet). See Memories.NOT_FACTS for the rest.
func _not_facts() -> Array:
	var words: Array = ["pd", "the show", "camera", "producer", "episode"]
	if not _cat.is_empty():
		words.append(str(_cat.get("name", "")).to_lower())
	return words


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
	_stats.bonds = Bonds.count_by_level(Game.bar)


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
	return Friendliness.are_close(Game.bar, a, b) or (_came_together(a, b) and bool(Groups.info(str(a.together["kind"])).get("close", false)))


## Whether two at the counter came in together (Groups).
func _came_together(a: Guest, b: Guest) -> bool:
	return a != null and b != null and a != b and not a.together.is_empty() and a.together.get("names", []).has(str(b.customer["name"])) and b.together.get("names", []).has(str(a.customer["name"]))


## After a spell of chat: regulars who chatted remember it (see Friendliness.remember_chat).
func _remember_chat(chat: Chat, last: String) -> void:
	Friendliness.remember_chat(Game.bar, chat.people, chat.transcript, last, _night_number)
	var names: Array = chat.people.map(func(g): return str(g.customer["name"]))  # (kept for closing: see _regulars_remember_each_other)
	var record: Dictionary = _night_chats.get(chat.get_instance_id(), {"names": [], "lines": [], "owner_in": false})
	for person in names:
		if not record["names"].has(person):
			record["names"].append(person)
	record["lines"] = chat.transcript.filter(func(e): return e.has("text") and e.has("speaker")).map(func(e): return {"speaker": str(e["speaker"]), "text": str(e["text"])})
	record["owner_in"] = bool(record["owner_in"]) or chat.owner_in
	_night_chats[chat.get_instance_id()] = record
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
