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


func _face(face_name: String, how: String) -> Dictionary:
	var picture := Image.create(64, 80, false, Image.FORMAT_RGBA8)
	return {"texture": ImageTexture.create_from_image(picture), "name": face_name, "how": how}


func test_a_caption_with_faces_gets_its_tv_box_and_a_zoom_clears_the_talk() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	captions.show_caption("cheers", {"seated": 2}, null, Vector2(300, 200), [_face("Kim Ji-ho", "mood")])
	var box := captions.shown_box
	assert_object(box).is_not_null()
	assert_bool(box.get_parent() == captions.layer and not box.zoomed).is_true()
	assert_float(box.position.x).is_greater(936.0)  # (the caption's on the left: the box goes right)
	captions.show_caption("cheers", {"seated": 2})  # (a caption without faces: the last box goes with it)
	assert_object(captions.shown_box).is_null()
	assert_bool(not is_instance_valid(box) or box.is_queued_for_deletion()).is_true()
	# A zoom: over the whole window, the caption with it, the bubbles faded for the beat.
	var window: Control = auto_free(Control.new())
	add_child(window)
	captions.zoom_layer = window
	captions.bubble_layer = auto_free(Control.new())
	add_child(captions.bubble_layer)
	Hooks.pause_scale_override = 1.0  # (real time, to catch the bubbles mid-fade)
	captions.pop({"hangul": "충격!", "english": "SHE QUIT?!"}, "😱", "ff4f6d", "dun", false, null, Vector2(-1, -1), 3.6, [_face("Kim Ji-ho", "stood_in")], true)
	assert_bool(captions.shown_box.zoomed and captions.shown_box.get_parent() == window).is_true()
	assert_bool(captions.shown.get_parent() == captions.shown_box).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(captions.bubble_layer.modulate.a).is_less(1.0)  # (fading: at the tests' speed it's soon back)
	assert_dict(captions.night.stats.stings).is_equal({"inset": 1, "zoom": 1, "mood": 1, "stood_in": 1})
