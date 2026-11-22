extends GdUnitTestSuite
## Tests for scripts/rules/keepsakes.gd (the end card's moment, the diary's polaroids, a kept
## face) and the polaroids on the page (scripts/ui/polaroid.gd, scripts/ui/diary_page.gd) and in
## "Previously on…" (scripts/ui/recap_screen.gd).

const Keepsakes = preload("res://scripts/rules/keepsakes.gd")
const DiaryPage = preload("res://scripts/ui/diary_page.gd")
const Polaroid = preload("res://scripts/ui/polaroid.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const RecapScreen = preload("res://scripts/ui/recap_screen.gd")

const STUDENT := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true, "skin": 2}
const FACE := {"key": "w_20s_long_glasses", "look": STUDENT}


func _moment(who: String, at: int, size: int, mood := "funny") -> Dictionary:
	return {"kind": "big_moment", "at": at, "who": who, "mood": mood, "size": size, "caption": "WHAT", "hangul": "ㅋㅋㅋ"}


func _sat(who: String, at: int, regular := "") -> Dictionary:
	return {"kind": "sat_down", "at": at, "name": who, "regular": regular}


func _left(who: String, at: int) -> Dictionary:
	return {"kind": "left", "at": at, "name": who}


func test_the_biggest_moment_is_the_highest_size_and_ties_go_to_the_latest() -> void:
	assert_dict(Keepsakes.biggest_moment([])).is_empty()
	assert_dict(Keepsakes.biggest_moment([_sat("Kim Ji-ho", 1100)])).is_empty()  # (no moment tonight: no card)
	var events := [_moment("Kim Ji-ho", 1100, 4), _moment("Park Min-seo", 1200, 5, "sad"), _moment("Lee Do-yun", 1300, 4)]
	assert_str(str(Keepsakes.biggest_moment(events)["who"])).is_equal("Park Min-seo")
	events.append(_moment("Lee Do-yun", 1400, 5, "shock"))
	assert_str(str(Keepsakes.biggest_moment(events)["mood"])).is_equal("shock")  # (a tie: the latest)
	assert_str(str(Keepsakes.biggest_moment([_moment("Kim Ji-ho", 1100, 4), _moment("Lee Do-yun", 1300, 4)])["who"])).is_equal("Lee Do-yun")
	assert_str(str(Keepsakes.biggest_moment([{"kind": "big_moment", "at": 1100, "who": "Kim Ji-ho", "mood": "sad"}])["who"])).is_equal("Kim Ji-ho")  # (from before sizes were kept)


func test_a_given_name_finds_their_face_and_stays_run_to_closing() -> void:
	var faces := {"Kim Ji-ho": FACE, "Park Min-seo": FACE}
	assert_str(Keepsakes.whose("Ji-ho", faces)).is_equal("Kim Ji-ho")
	assert_str(Keepsakes.whose("Park Min-seo", faces)).is_equal("Park Min-seo")
	assert_str(Keepsakes.whose("Do-yun", faces)).is_equal("")
	var stays := Keepsakes.stays([_sat("Kim Ji-ho", 1100), _sat("Park Min-seo", 1150), _left("Kim Ji-ho", 1190)], 1620)
	assert_dict(stays).is_equal({"Kim Ji-ho": 90, "Park Min-seo": 470})


func test_the_polaroids_are_the_big_moment_then_a_regular_or_whoever_stayed_longest() -> void:
	var faces := {"Kim Ji-ho": FACE, "Park Min-seo": FACE, "Lee Do-yun": FACE, "Choi Mi-rae": FACE, "Han Su-bin": FACE}
	var events := [_sat("Kim Ji-ho", 1100), _sat("Park Min-seo", 1110), _sat("Lee Do-yun", 1120, "regular"), _sat("Choi Mi-rae", 1130),
		_moment("Ji-ho", 1150, 5, "shock"), _moment("Lee Do-yun", 1160, 4, "sweet"),
		_left("Lee Do-yun", 1200), _left("Kim Ji-ho", 1400)]
	# The moment's first, in its mood; then the regular (in their own moment's), though others stayed longer.
	assert_array(Keepsakes.polaroids(events, faces, 1620)).is_equal([{"name": "Kim Ji-ho", "mood": "shock"}, {"name": "Lee Do-yun", "mood": "sweet"}])
	# No regular: whoever stayed longest, calm (no moment of theirs); a tie by name.
	events[2] = _sat("Lee Do-yun", 1120)
	assert_array(Keepsakes.polaroids(events, faces, 1620)).is_equal([{"name": "Kim Ji-ho", "mood": "shock"}, {"name": "Park Min-seo", "mood": "calm"}])
	# No moment tonight: just the one. Nobody with a face: none.
	assert_array(Keepsakes.polaroids([_sat("Kim Ji-ho", 1100), _sat("Park Min-seo", 1300)], faces, 1620)).is_equal([{"name": "Kim Ji-ho", "mood": "calm"}])
	assert_array(Keepsakes.polaroids(events, {}, 1620)).is_empty()
	# The owner's moment: theirs first; never the owner second.
	var owners := faces.duplicate()
	owners["Oh Mi-sook"] = FACE
	assert_array(Keepsakes.polaroids([_sat("Kim Ji-ho", 1100), _moment("Oh Mi-sook", 1200, 5, "warm")], owners, 1620, "Oh Mi-sook")) \
		.is_equal([{"name": "Oh Mi-sook", "mood": "warm"}, {"name": "Kim Ji-ho", "mood": "calm"}])


func test_a_polaroid_is_their_face_in_whole_pixels_with_their_name_under_it() -> void:
	var picture := PeopleArt.portrait(STUDENT, "w_20s_long_glasses")
	assert_object(picture).is_not_null()
	var polaroid: Polaroid = auto_free(Polaroid.new())
	polaroid.setup(picture, "Kim Ji-ho", "Ji-ho", 0.07)
	add_child(polaroid)
	var face := polaroid.get_node("Picture") as TextureRect
	assert_vector(face.size).is_equal(Vector2(64, 80) * Polaroid.SCALE)
	assert_int(face.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_str((polaroid.get_node("Name") as Label).text).is_equal("Ji-ho")
	assert_float(polaroid.rotation).is_equal_approx(0.07, 0.0001)
	assert_int(polaroid.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_diary_page_shows_the_entry_s_polaroids_and_older_entries_have_none() -> void:
	var page: DiaryPage = auto_free(DiaryPage.new())
	add_child(page)
	var plain_width := (page.get_node("Entry") as Control).size.x
	var entry := {"text": "A quiet night.", "stamp": "soju", "season": 1, "season_episode": 2, "day": "Friday", "weather": "rain",
		"photos": [{"name": "Kim Ji-ho", "mood": "shock", "key": "w_20s_long_glasses", "look": STUDENT},
			{"name": "Park Min-seo", "mood": "calm", "key": "w_20s_long_glasses", "look": STUDENT},
			{"name": "Nobody", "mood": "calm", "key": "", "look": {}}]}  # (no picture: left out)
	page.show_entry(entry, "Mi-sook's diary")
	assert_array(page.photo_names()).is_equal(["Kim Ji-ho", "Park Min-seo"])
	assert_float((page.get_node("Entry") as Control).size.x).is_equal(plain_width - DiaryPage.PHOTO_ROOM)  # (the writing makes room)
	assert_vector((page.get_node("Stamp") as Control).position).is_equal(DiaryPage.STAMP_BESIDE)
	var first := page.get_node("Photos").get_child(0)
	var shocked := PeopleArt.portrait(STUDENT, "w_20s_long_glasses", "shock")
	assert_object((first.get_node("Picture") as TextureRect).texture).is_equal(shocked if shocked != null else PeopleArt.portrait(STUDENT, "w_20s_long_glasses"))
	# An older entry (from before keepsakes): the page as ever.
	page.show_entry({"text": "Older.", "stamp": "soju", "season": 1, "season_episode": 1}, "Mi-sook's diary")
	assert_array(page.photo_names()).is_empty()
	assert_float((page.get_node("Entry") as Control).size.x).is_equal(plain_width)
	assert_vector((page.get_node("Stamp") as Control).position).is_equal(DiaryPage.STAMP_AT)


func test_a_kept_face_by_a_full_or_given_name_in_their_moment_s_mood() -> void:
	var faces := {"Kim Ji-ho": FACE, "Park Min-seo": FACE}
	assert_dict(Keepsakes.face(faces, "Ji-ho", "shock")).is_equal({"name": "Kim Ji-ho", "key": FACE["key"], "look": STUDENT, "mood": "shock"})
	assert_dict(Keepsakes.face(faces, "Lee Do-yun")).is_empty()  # (nobody kept)
	assert_dict(Keepsakes.face({}, "Kim Ji-ho")).is_empty()  # (an entry from before faces were kept)
	assert_dict(Keepsakes.face({"Kim Ji-ho": {"key": "", "look": STUDENT}}, "Kim Ji-ho")).is_empty()  # (kept with no face)
	var moments := [{"who": "Ji-ho", "mood": "shock"}, {"who": "Lee Do-yun", "mood": "sad"}]
	assert_str(Keepsakes.last_mood(moments, "Kim Ji-ho", faces)).is_equal("shock")
	assert_str(Keepsakes.last_mood(moments, "Park Min-seo", faces)).is_equal("calm")  # (no moment of hers)
	assert_str(Keepsakes.last_mood(moments, "Lee Do-yun", faces)).is_equal("calm")  # (no face kept: not hers to show)
	# The picture: in the mood, or calm if that face isn't drawn.
	assert_object(Polaroid.picture_of(Keepsakes.face(faces, "Ji-ho", "shock"))).is_not_null()
	assert_object(Polaroid.picture_of(Keepsakes.face(faces, "Ji-ho", "no_such_mood"))).is_same(PeopleArt.portrait(STUDENT, str(FACE["key"])))
	assert_object(Polaroid.picture_of({})).is_null()


func test_previously_on_shows_who_each_beat_s_about_and_last_night_s_polaroids_on_the_card() -> void:
	var screen := RecapScreen.new()
	screen.time_scale = 0.02
	add_child(screen)
	var faces := {"Kim Ji-ho": FACE, "Park Min-seo": FACE}
	var photos := [{"name": "Kim Ji-ho", "mood": "shock", "key": FACE["key"], "look": STUDENT}, {"name": "Park Min-seo", "mood": "calm", "key": FACE["key"], "look": STUDENT}]
	screen.play(["Ji-ho quits.", "Do-yun stays away.", "Min-seo laughs."], "Will he come back?", 5, "Golmok Pocha", false,
		{"people": {"Kim Ji-ho": "김지호", "Lee Do-yun": "이도윤", "Park Min-seo": "박민서"}, "moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!"}],
		"faces": faces, "photos": photos, "place": {"season": 1, "episode": 5}})
	await screen.finished
	assert_array(screen.beat_faces).is_equal(["Kim Ji-ho", "Park Min-seo"])  # (Do-yun's beat: no face kept, so none)
	assert_array(screen.card_faces).is_equal(["Kim Ji-ho", "Park Min-seo"])
	assert_object(screen.find_child("RecapCardPhoto1", true, false)).is_not_null()


func test_previously_on_from_before_faces_were_kept_has_none() -> void:
	var screen := RecapScreen.new()
	screen.time_scale = 0.02
	add_child(screen)
	screen.play(["Ji-ho quits."], "Will he come back?", 5, "Golmok Pocha", false, {"people": {"Kim Ji-ho": "김지호"}, "place": {"season": 1, "episode": 5}})
	await screen.finished
	assert_array(screen.beat_faces).is_empty()
	assert_array(screen.card_faces).is_empty()
	assert_object(screen.find_child("RecapFace", true, false)).is_null()
