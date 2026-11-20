extends GdUnitTestSuite
## Tests for scripts/ui/transcript_view.gd: the transcript on screen, with its toolbar (search,
## All/Talk/Events, text size, Compact) and catching up to the latest line.

const TranscriptView = preload("res://scripts/ui/transcript_view.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")

const TEST_SETTINGS := "user://test_transcript_settings.cfg"

var _used: Array = []


func before_test() -> void:
	Ambience.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	_used = []


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Ambience.settings_path = "user://settings.cfg"


func _view() -> TranscriptView:
	var view: TranscriptView = auto_free(TranscriptView.new())
	view.size = Vector2(600, 300)
	add_child(view)
	view.build()
	view.used.connect(func(what, detail): _used.append("%s %s" % [what, detail]))
	return view


## A night's worth: what happens, then lines said (a pin each), with their times.
func _fill(view: TranscriptView) -> void:
	view.add({"text": "Kim Ji-ho comes in out of the rain.\n\n", "pin": -1, "at": 19 * 60})
	view.add({"text": "[b]Kim Ji-ho:[/b] One soju, please.\n\n", "pin": 0, "at": 19 * 60 + 5})
	view.add({"text": "[i](The PD plays A phone rings.)[/i]\n\n", "pin": -1, "at": 23 * 60 + 40})
	view.add({"text": "[b]Owner:[/b] Ji-ho, it's for you!\n\n", "pin": 1, "at": 23 * 60 + 42})


func test_all_talk_or_events() -> void:
	var view := _view()
	_fill(view)
	assert_str(view.transcript.get_parsed_text()).contains("comes in out of the rain").contains("One soju, please")
	view.set_filter("talk")  # (only lines said: the ones with a 📌)
	await view.redraw()
	assert_str(view.transcript.get_parsed_text()).contains("One soju, please").contains("it's for you").not_contains("rain").not_contains("A phone rings")
	view.add({"text": "Someone walks past.\n\n", "pin": -1, "at": 23 * 60 + 50})  # (not talk: not shown)
	assert_str(view.transcript.get_parsed_text()).not_contains("walks past")
	view.set_filter("events")
	await view.redraw()
	assert_str(view.transcript.get_parsed_text()).contains("rain").contains("walks past").not_contains("One soju")
	view.set_filter("all")
	await view.redraw()
	assert_str(view.transcript.get_parsed_text()).contains("walks past").contains("One soju")
	assert_bool(view.filter_buttons["all"].button_pressed).is_true()
	assert_array(_used).contains(["filter talk", "filter events", "filter all"])


func test_search_finds_lines_and_names_and_goes_through_them() -> void:
	var view := _view()
	_fill(view)
	view.search.text = "ji-ho"
	view._on_search_changed("ji-ho")
	assert_array(view.matches).is_equal([0, 1, 3])  # (case aside; names too)
	assert_str(view.count_label.text).is_equal("– of 3")
	assert_str(view._display(view.chunks[1], 1)).contains("[bgcolor=")  # (marked)
	assert_str(view._display(view.chunks[2], 2)).not_contains("[bgcolor=")
	await view.next_match(1)
	assert_str(view.count_label.text).is_equal("1 of 3")
	await view.next_match(-1)  # (round from the start to the end)
	assert_str(view.count_label.text).is_equal("3 of 3")
	assert_array(_used).contains(["jump 1 of 3", "jump 3 of 3"])
	view.set_filter("talk")  # (only lines it shows)
	assert_array(view.matches).is_equal([1, 3])
	view._on_search_changed("nobody")
	assert_str(view.count_label.text).is_equal("none")
	view._on_search_changed("")
	assert_str(view.count_label.text).is_empty()
	assert_str(view._display(view.chunks[1], 1)).not_contains("[bgcolor=")
	# Marked only in the words, never inside a tag (a hover's words, a link).
	var marked := view.highlighted("[hint=Ji-ho's hover]Ji-ho[/hint] [url=pin:3]📌[/url]", "ji-ho", TranscriptView.MATCH)
	assert_str(marked).starts_with("[hint=Ji-ho's hover][bgcolor=").contains("]Ji-ho[/bgcolor][/hint]").contains("[url=pin:3]📌[/url]")


func test_a_search_counts_once_its_settled() -> void:
	var view := _view()
	_fill(view)
	view._settle.wait_time = 0.05
	view._on_search_changed("soju")
	await await_millis(200)
	assert_array(_used).contains(["search «soju» · 1 line"])


func test_compact_and_text_size_are_remembered() -> void:
	var view := _view()
	_fill(view)
	assert_int(view.font_size).is_equal(15)
	assert_int(view.transcript.get_theme_font_size("normal_font_size")).is_equal(15)
	view.set_compact(true)
	await view.redraw()
	var text := view.transcript.get_parsed_text()
	assert_str(text).contains(NightRules.clock_text(23 * 60 + 42) + "  Owner: Ji-ho").not_contains("\n\n")  # (closer together, each with its time)
	view.step_size(1)
	assert_int(view.transcript.get_theme_font_size("normal_font_size")).is_equal(17)
	for k in 10:
		view.step_size(1)
	assert_int(view.font_size).is_equal(TranscriptView.SIZES.back())  # (no bigger than the biggest)
	assert_array(_used).contains(["compact on", "size 17"])
	var again := _view()  # (next time: as it was left)
	assert_int(again.font_size).is_equal(TranscriptView.SIZES.back())
	assert_bool(again.compact).is_true()
	assert_bool(again.compact_button.button_pressed).is_true()


func test_scrolled_up_new_lines_wait_with_a_button_back_to_the_latest() -> void:
	var view := _view()
	for k in 60:
		view.add({"text": "Line %d.\n\n" % k, "pin": k, "at": 20 * 60})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(view.new_button.visible).is_false()  # (following the latest: nothing waiting)
	view.transcript.get_v_scroll_bar().value = 0.0  # (scrolled up to read something)
	view.add({"text": "Something new.\n\n", "pin": -1, "at": 20 * 60})
	view.add({"text": "And again.\n\n", "pin": -1, "at": 20 * 60})
	assert_int(view.unseen).is_equal(2)
	assert_bool(view.new_button.visible).is_true()
	assert_str(view.new_button.text).is_equal("↓ 2 new lines")
	view.catch_up()
	assert_int(view.unseen).is_equal(0)
	assert_bool(view.new_button.visible).is_false()
	assert_array(_used).contains(["catch_up 2"])
