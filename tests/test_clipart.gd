extends GdUnitTestSuite
## Tests for scripts/rules/clipart.gd (which clipart, where) and scripts/ui/clipart_sticker.gd
## (stuck to someone on stage).

const Clipart = preload("res://scripts/rules/clipart.gd")
const ClipartSticker = preload("res://scripts/ui/clipart_sticker.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")
const Art = preload("res://scripts/ui/art.gd")
const Layout = preload("res://scripts/bar/layout.gd")

const PLACES := ["over", "face", "beside", "chest", "behind", "feet"]
const DRIFTS := ["", "across", "up"]


func before_test() -> void:
	Art.folder = "res://art/"
	Art.reset()


func after_test() -> void:
	Art.reset()


func test_every_clipart_is_complete_and_every_mood_has_some() -> void:
	for clip in Clipart.CLIPS:
		var data: Dictionary = Clipart.CLIPS[clip]
		assert_int(int(data["frames"])).override_failure_message(clip).is_greater(0)
		assert_int(int(data["fps"])).override_failure_message(clip).is_greater(0)
		assert_bool(PLACES.has(Clipart.place(clip))).override_failure_message(clip).is_true()
		assert_bool(DRIFTS.has(Clipart.drift(clip))).override_failure_message(clip).is_true()
	for mood in Captions.REACTIONS:  # (every mood a face can have but the plain one)
		assert_bool(Clipart.BY_MOOD.has(mood)).override_failure_message(mood).is_true()
	for clips in Clipart.BY_MOOD.values() + Clipart.BY_KIND.values():
		for clip in clips:
			assert_bool(Clipart.CLIPS.has(clip)).override_failure_message(clip).is_true()
	for kind in Clipart.BY_KIND:
		assert_bool(Captions.CAPTIONS.has(kind)).override_failure_message(kind).is_true()


func test_its_hangul_is_explained_on_hover() -> void:
	for clip in Clipart.CLIPS:
		if Clipart.hangul(clip) != "":
			assert_bool(Hangul.MEANINGS.has(Clipart.hangul(clip))).override_failure_message("no meaning for %s" % Clipart.hangul(clip)).is_true()


func test_every_frame_has_its_art() -> void:
	var manifest := Art.manifest()
	for id in Clipart.ids():
		assert_bool(manifest.has("clipart/" + str(id))).override_failure_message(str(id)).is_true()
	assert_int(Clipart.ids().size()).is_equal(Art.ids("clipart").size())
	assert_array(Clipart.frame_keys("crow")).is_equal(["clipart/crow_0", "clipart/crow_1", "clipart/crow_2", "clipart/crow_3"])


func test_the_kind_comes_first_then_an_emergency_then_the_mood() -> void:
	assert_str(Clipart.pick("another_round", "funny", false)).is_equal("stars")  # the kind's own
	assert_str(Clipart.pick("hoesik_escape", "funny", false)).is_equal("soul")
	assert_str(Clipart.pick("bill_fight", "shock", false, 0.0)).is_equal("flames")
	assert_str(Clipart.pick("bill_fight", "shock", false, 0.99)).is_equal("siren")
	assert_str(Clipart.pick("stove", "shock", true)).is_equal("siren")  # an emergency: the siren
	assert_str(Clipart.pick("couple", "sweet", false, 0.0)).is_equal("hearts")  # else the mood's, by roll
	assert_str(Clipart.pick("", "awkward", false, 0.99)).is_equal("tumbleweed")
	assert_str(Clipart.pick("", "roast", false, 0.5)).is_equal("arrow")
	assert_str(Clipart.pick("new_face", "calm", false)).is_equal("")  # a plain face: none


func test_a_sticker_sits_on_its_person_follows_them_and_goes() -> void:
	var person: Control = auto_free(Control.new())
	person.size = Layout.PERSON_SIZE
	add_child(person)
	var sticker := ClipartSticker.new()
	assert_bool(sticker.setup("rain_cloud")).is_true()
	sticker.time_scale = 0.01
	sticker.stick(person, 2.6)
	assert_bool(sticker.get_parent() == person).is_true()  # (a child: wherever they go, it goes)
	assert_float(sticker.position.y + sticker.size.y).is_less(0.0)  # over their head
	assert_bool(sticker.show_behind_parent).is_false()
	assert_str(Art.used.get("clipart/rain_cloud_0", "")).is_equal("image")
	await await_millis(200)
	assert_bool(is_instance_valid(sticker)).is_false()  # (gone after its beat)


func test_flowers_go_behind_and_a_crow_flies_across_with_its_words() -> void:
	var person: Control = auto_free(Control.new())
	add_child(person)
	var flowers := ClipartSticker.new()
	flowers.setup("flowers")
	flowers.time_scale = 0.01
	flowers.stick(person, 2.6)
	assert_bool(flowers.show_behind_parent).is_true()
	var crow := ClipartSticker.new()
	crow.setup("crow")
	crow.time_scale = 0.01
	crow.stick(person, 2.6)
	var words := crow.get_node_or_null("Words") as Label
	assert_str(words.text).is_equal("까악 까악")
	assert_str(words.tooltip_text).contains("caw")
	var start := crow.position.x
	await await_millis(15)
	assert_float(crow.position.x).is_greater(start)  # (left to right)
	var haha := ClipartSticker.new()
	haha.setup("haha")
	assert_object(haha.get_node_or_null("Words")).is_null()  # (the drawing is the words: its hover's on the picture)
	assert_str((haha.get_node("Picture") as Control).tooltip_text).contains("lol")
	haha.free()


func test_a_clipart_without_its_art_isnt_built() -> void:
	Art.folder = "res://tests/no_art_here/"
	Art.reset()
	var sticker := ClipartSticker.new()
	assert_bool(sticker.setup("crow")).is_false()
	assert_int(sticker.get_child_count()).is_equal(0)
	sticker.free()


func test_it_loops_its_frames() -> void:
	var sticker: ClipartSticker = auto_free(ClipartSticker.new())
	sticker.setup("siren")
	add_child(sticker)
	sticker.time_scale = 1.0
	sticker._process(1.0 / 8.0 + 0.01)  # (8 frames a second)
	assert_int(sticker.frame).is_equal(1)
	sticker._process(3.0 / 8.0)
	assert_int(sticker.frame).is_equal(0)  # (4 frames: round again)
