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
	return {"texture": ImageTexture.create_from_image(picture), "name": face_name, "mood": "shock", "how": how}


func test_a_caption_with_faces_has_them_slapped_on_and_a_zoom_clears_the_talk() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	captions.show_caption("cheers", {"seated": 2}, null, Vector2(300, 200), [_face("Kim Ji-ho", "mood")])
	var first := captions.shown
	assert_object(first.sticker).is_not_null()
	assert_bool(first.get_parent() == captions.layer).is_true()  # (over the stage, by them)
	assert_int(first.sticker.get_index()).is_equal(first.sticker.get_parent().get_child_count() - 1)  # (they're on the left: the face on its right, nearer the middle)
	captions.show_caption("cheers", {"seated": 2})  # (a caption without faces)
	assert_object(captions.shown.sticker).is_null()
	# A zoom: over the whole window, dimmed behind, the bubbles faded for the beat.
	var window: Control = auto_free(Control.new())
	add_child(window)
	captions.zoom_layer = window
	captions.bubble_layer = auto_free(Control.new())
	add_child(captions.bubble_layer)
	Hooks.pause_scale_override = 1.0  # (real time, to catch the bubbles mid-fade)
	captions.pop({"hangul": "충격!", "english": "SHE QUIT?!"}, "😱", "ff4f6d", "dun", false, null, Vector2(-1, -1), 3.6, [_face("Kim Ji-ho", "stood_in")], true)
	assert_bool(captions.shown_zoom.get_parent() == window and captions.shown.get_parent() == captions.shown_zoom).is_true()
	assert_object(captions.shown_zoom.get_node_or_null("Dim")).is_not_null()
	assert_float(captions.shown.at.x).is_equal(960.0)  # (the middle of the window)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(captions.bubble_layer.modulate.a).is_less(1.0)  # (fading: at the tests' speed it's soon back)
	captions.show_caption("cheers", {"seated": 2})  # (the next caption: the zoom's gone with it)
	assert_object(captions.shown_zoom).is_null()
	assert_dict(captions.night.stats.stings).is_equal({"beside": 1, "zoom": 1, "mood": 1, "stood_in": 1})


func test_the_end_card_is_a_zoom_with_its_title() -> void:
	var captions := _captions()
	var window: Control = auto_free(Control.new())
	add_child(window)
	captions.zoom_layer = window
	captions.end_card({"hangul": "충격!", "english": "SHE QUIT?!"}, "😱", "ff4f6d", "dun", [_face("Kim Ji-ho", "mood")], 4.5)
	assert_str(str(captions.shown_zoom.name)).is_equal("EndCard")
	assert_bool(captions.shown.get_parent() == captions.shown_zoom).is_true()
	assert_object(captions.shown.sticker).is_not_null()
	var title := captions.shown_zoom.get_node("EndCardTitle")
	assert_str((title.get_node("Hangul") as Label).text).is_equal("오늘의 명장면")
	assert_str((title.get_node("English") as Label).text).is_equal("TONIGHT'S BEST MOMENT")
	assert_str(str(_lines[-1])).contains("SHE QUIT?!")
	assert_int(int(captions.night.stats.stings.get("zoom", 0))).is_equal(1)


func test_whoever_s_face_is_on_it_gets_the_clipart_on_stage() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	var one: Control = auto_free(Control.new())
	var two: Control = auto_free(Control.new())
	captions.layer.add_child(one)
	captions.layer.add_child(two)
	var faces := [_face("Kim Ji-ho", "mood"), _face("Park Min-seo", "mood")]
	faces[0]["node"] = one
	faces[1]["node"] = two
	captions.show_caption("another_round", {"name": "Kim Ji-ho", "friend": "Park Min-seo", "drinks": 3}, null, Vector2(300, 200), faces)
	assert_object(one.get_node_or_null("Clipart")).is_not_null()  # both of them: the stars
	assert_object(two.get_node_or_null("Clipart")).is_not_null()
	assert_str(one.get_node("Clipart").clip).is_equal("stars")
	assert_dict(captions.night.stats.clipart).is_equal({"stars": 1})
	# The next caption takes the last one's off; a plain face (a new face) gets none.
	var calm := _face("Kim Ji-ho", "calm")
	calm["mood"] = "calm"
	calm["node"] = one
	captions.show_caption("new_face", {"name": "Kim Ji-ho"}, null, Vector2(300, 200), [calm])
	assert_object(one.get_node_or_null("Clipart")).is_null()
	assert_array(captions.stuck).is_empty()
	# A reaction's: its mood's; after a zoom, it waits for the zoom to go.
	var window: Control = auto_free(Control.new())
	add_child(window)
	captions.zoom_layer = window
	var shocked := _face("Kim Ji-ho", "mood")
	shocked["node"] = one
	captions.pop({"hangul": "충격!", "english": "SHE QUIT?!"}, "😱", "ff4f6d", "dun", false, one, Vector2(-1, -1), 3.6, [shocked], true)
	var sticker: Control = one.get_node("Clipart")
	assert_bool(["lightning", "bang", "mind_blown"].has(sticker.clip)).is_true()
	assert_float(sticker.modulate.a).is_equal(0.0)  # (not yet: the zoom's up)


func test_the_clipart_goes_on_the_face_even_with_nobody_on_stage() -> void:
	Hooks.caption_pacing = false
	var captions := _captions()
	captions.show_caption("cheers", {"seated": 2}, null, Vector2(300, 200), [_face("Kim Ji-ho", "mood")])  # (no node: they've gone)
	assert_array(captions.stuck).is_empty()  # none on stage...
	assert_str(captions.shown.sticker.clip).is_not_empty()  # ...but on their face on the pop
	assert_int(captions.night.stats.clipart.values().reduce(func(a, b): return a + b, 0)).is_equal(1)  # (counted once a caption)
