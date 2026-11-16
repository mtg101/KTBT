extends GdUnitTestSuite
## Tests for scripts/bar/captions_on_screen.gd: TV captions on screen, on their own.

const CaptionsOnScreen = preload("res://scripts/bar/captions_on_screen.gd")
const Night = preload("res://scripts/bar/night.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

var _lines: Array = []
var _stings: Array = []


func before_test() -> void:
	_lines = []
	_stings = []
	Hooks.pause_scale_override = 0.01


func after_test() -> void:
	Hooks.caption_pacing = true
	Hooks.pause_scale_override = -1.0


func _captions() -> CaptionsOnScreen:
	var layer: Control = auto_free(Control.new())
	add_child(layer)
	var captions := CaptionsOnScreen.new(Night.new(), 1872.0, func(line): _lines.append(line), func(sound): _stings.append(sound))
	captions.layer = layer
	captions.red_frame = Panel.new()
	layer.add_child(captions.red_frame)
	return captions


func test_a_caption_pops_up_with_its_sting_and_goes_in_the_transcript() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	captions.show_caption("cheers", {"seated": 2})
	assert_object(captions.shown).is_not_null()
	assert_int(captions.night.stats.captions.get("cheers", 0)).is_equal(1)
	assert_str(str(_lines[0])).contains("[lb]TV]")  # (escaped, as it's BBCode)
	assert_int(_stings.size()).is_equal(1)
	var first := captions.shown
	captions.show_caption("cheers", {"seated": 2})
	assert_bool(captions.shown != first).is_true()  # a new one replaces it
	assert_int(captions.red_flashes).is_equal(0)


func test_an_emergency_flashes_the_red_light() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	captions.show_caption("full_house", {"seated": 5})
	assert_int(captions.red_flashes).is_equal(1)
	assert_bool(captions.red_frame.visible).is_true()


func test_captions_are_paced_and_wait_for_a_reaction() -> void:
	Hooks.caption_pacing = true
	var captions := _captions()
	captions.reaction_shown()  # a reaction's up
	assert_bool(captions.reaction_ready()).is_false()
	captions.show_caption("cheers", {"seated": 2})
	assert_object(captions.shown).is_null()  # routine: it waits
	captions.show_caption("full_house", {"seated": 5})  # an emergency doesn't wait
	assert_int(captions.red_flashes).is_equal(1)
