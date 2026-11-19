extends GdUnitTestSuite
## Tests for scripts/bar/story_keeper.gd: tonight's transcript file, and what "Previously on…"
## is written from, on their own.

const StoryKeeper = preload("res://scripts/bar/story_keeper.gd")
const Bonds = preload("res://scripts/rules/bonds.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

const FOLDER := "user://test_story_keeper/"


func before_test() -> void:
	Hooks.transcript_folder = FOLDER


func after_test() -> void:
	Hooks.transcript_folder = ""
	for file in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file))


func test_the_transcript_has_the_opening_the_night_and_how_it_ended() -> void:
	var story := StoryKeeper.new()
	story.record("[i]The tent's own: 할머니 칼국수 Halmeoni Kalguksu.[/i]\n\n")  # (before the night: kept for the top)
	assert_bool(story.is_writing()).is_false()
	var path := story.start("golmok-pocha", 3, ["KTBT transcript: Golmok Pocha, night 3", "Friday, rain."])
	assert_str(path).is_not_empty()
	assert_bool(story.is_writing()).is_true()
	story.record("[b]Kim Ji-ho:[/b] A [lb]big[lb] soju, please.\n\n")
	story.finish(true, "3:12am", "HIGHLIGHTS\n9:58pm  hwaiting chorus")
	assert_bool(story.is_writing()).is_false()
	var written := FileAccess.get_file_as_string(path)
	assert_str(written).starts_with("KTBT transcript: Golmok Pocha, night 3\nFriday, rain.\n" + "=".repeat(70))
	assert_str(written).contains("The tent's own: 할머니 칼국수 Halmeoni Kalguksu.")  # the opening, tags stripped
	assert_str(written).contains("Kim Ji-ho: A [big[ soju, please.")  # (an escaped "[" is a "[" again)
	assert_str(written).contains("Finished at 3:12am.\n\nSTATS\n\nHIGHLIGHTS")
	assert_int(written.find("The tent's own")).is_less(written.find("Kim Ji-ho"))


func test_last_nights_ending_isnt_tomorrows_opening() -> void:
	var story := StoryKeeper.new()
	story.record("Last night's diary.\n")
	story.forget_before()
	var path := story.start("golmok-pocha", 4, ["Header"])
	story.finish(false, "11:40pm", "")
	var written := FileAccess.get_file_as_string(path)
	assert_str(written).not_contains("Last night's diary").contains("Cut short at 11:40pm.")


func test_previously_on_is_written_from_the_last_diary_and_the_regulars() -> void:
	var bar := {"name": "Golmok Pocha", "nights": 6, "cat": {"name": "Nabi"},
		"diary": [{"text": "A quiet night.", "facts": {"people": [{"name": "Kim Ji-ho", "hangul": "김지호"}], "weather": "rain"}}]}
	var owner_data := {"name": "Park Mi-sook", "hangul": "박미숙", "archetype": "a gruff ajumma"}
	var regulars := [{"id": "lee-min-jun-1", "name": "Lee Min-jun", "hangul": "이민준"}]
	var dice := RandomNumberGenerator.new()
	var facts := StoryKeeper.recap_facts(bar, owner_data, regulars, dice)
	assert_int(int(facts["episode"])).is_equal(7)
	assert_str(str(facts["last_entry"])).is_equal("A quiet night.")
	assert_array(facts["names"]).contains(["Park Mi-sook", "Lee Min-jun", "Kim Ji-ho"])
	assert_str(str(facts["hangul"]["Kim Ji-ho"])).is_equal("김지호")
	assert_str(str(facts["cat"])).is_equal("Nabi")
	assert_str(str(facts["teaser_example"])).is_not_empty()
	# A bar from before diaries: each regular's latest memory instead.
	Bonds.remember(Bonds.between(bar, Bonds.OWNER, "lee-min-jun-1"), 5, {Bonds.OWNER: "Always orders the same.", "lee-min-jun-1": "Kind."})
	bar.erase("diary")
	assert_array(StoryKeeper.recap_facts(bar, owner_data, regulars, dice)["memories"]).is_equal(["Lee Min-jun, a regular: Always orders the same."])
