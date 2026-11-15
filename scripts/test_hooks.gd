extends RefCounted
## Every test hook in one place: switches the tests set to make the game quick, repeatable and
## quiet, and keep it off the real saves and logs. The game reads them (as Hooks.<name>) but
## never sets them; in a normal run they're all at their defaults, so it plays as it should.
##
## Tests call for_tests() before each test (it puts every hook into a known test state, so
## nothing one suite sets can leak into the next) and restore() after (back to the defaults).
## See tests/bar_test.gd.

const Ai = preload("res://scripts/ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")

# --- Time and chance ----------------------------------------------------------------------
## >= 0 scales every pause and the clock (0.01 runs a visit in a blink).
static var pause_scale_override := -1.0
## != 0 makes every run pick the same moments, customers and orders.
static var random_seed := 0
## false stops the night clock: no customers arrive by themselves and the night never ends
## (tests then bring people in themselves). The stove keeps cooking either way.
static var run_clock := true

# --- Customers ------------------------------------------------------------------------------
## >= 0 gives everyone that stay (game minutes).
static var stay_minutes_override := -1
## "chatty", "quiet" or "owner": everyone's mood for company.
static var company_override := ""
## >= 0 replaces the chance customers chat to each other.
static var chat_chance_override := -1.0
## A gender for every new customer instead of the game's roll ("non-binary").
static var gender_override := ""
## false: nobody walks past in the street.
static var strollers := true
## true offers a new bar every colour and shape (so a scripted look always fits).
static var offer_every_look := false
## false keeps the cat where it is (tests move it themselves).
static var cat_wanders := true
## false: the next new customer isn't invented ahead, while the owner's free, but when they
## arrive (as before: tests that script exact AI replies would have them used up early).
static var prepare_customers := true
## Rain gear for every customer coming and going in the rain or snow, instead of the dice
## (Looks.rain_gear: {"umbrella": false} runs for it). {}: the dice.
static var rain_gear := {}

# --- Things that would use up scripted AI replies -------------------------------------------
## false: a new (or older) bar gets no founding regulars.
static var founding_regulars := true
## >= 0: a fixed roll for whether someone becomes a regular (1.0 never, 0.0 whenever possible).
static var regular_roll_override := -1.0
## false: no after-visit memory (the game's own verdict is used).
static var memories := true
## false: no "was that a big moment?" after a spell of talk.
static var reactions := true
## false: the game writes the 3am diary itself.
static var diaries := true
## false: no "Previously on…" (or series opener) when a bar opens.
static var recaps := true

# --- On screen ---------------------------------------------------------------------------------
## false: no speech bubbles.
static var bubbles := true
## false: no TV captions.
static var captions := true
## false: every caption shows, however close together, and every time.
static var caption_pacing := true

# --- Files -----------------------------------------------------------------------------------
## false: don't print where each night's transcript and stats went (tests: less noise).
static var print_paths := true
## Where night transcripts go: "" for the default (logs/transcripts/ in the project folder
## when running from the editor, or the user data folder otherwise).
static var transcript_folder := ""


## The test state, before every test: quick, repeatable, quiet, offline (the canned AI with
## nothing scripted), and every extra AI call off (tests turn on what they test). Saves, night
## logs and transcripts go to the test's own folders.
static func for_tests(saves: String, stats: String, transcripts: String) -> void:
	restore()
	pause_scale_override = 0.01
	random_seed = 1234
	strollers = true
	offer_every_look = true
	founding_regulars = false
	prepare_customers = false
	regular_roll_override = 1.0  # nobody becomes a regular unless a test says so
	memories = false
	reactions = false
	diaries = false
	recaps = false
	bubbles = false
	caption_pacing = false  # (pacing has its own rule tests)
	transcript_folder = transcripts
	print_paths = false
	SaveStore.folder = saves
	NightStats.folder = stats
	AiSettings.override = {"backend": "canned"}
	CannedAi.scripted = []
	Ai.simulate_unreachable = false
	Ai.canned_think_seconds = 0.0
	Ambience.make_sound = false
	Ambience.settings_path = "user://test_settings.cfg"


## Everything back to how the game runs normally.
static func restore() -> void:
	pause_scale_override = -1.0
	random_seed = 0
	run_clock = true
	stay_minutes_override = -1
	company_override = ""
	chat_chance_override = -1.0
	gender_override = ""
	strollers = true
	offer_every_look = false
	cat_wanders = true
	rain_gear = {}
	prepare_customers = true
	founding_regulars = true
	regular_roll_override = -1.0
	memories = true
	reactions = true
	diaries = true
	recaps = true
	bubbles = true
	captions = true
	caption_pacing = true
	transcript_folder = ""
	print_paths = true
	SaveStore.folder = "user://saves/"
	NightStats.folder = "user://stats/"
	AiSettings.override = {}
	CannedAi.scripted = []
	Ai.simulate_unreachable = false
	Ai.canned_think_seconds = 0.0
	Ambience.make_sound = true
	Ambience.settings_path = "user://settings.cfg"
