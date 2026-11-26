extends GdUnitTestSuite
## Tests for scripts/ai/portrait_maker.gd: the workflow filled in as the helper fills it, ComfyUI's
## folder read from the settings or tools/comfyui_path.txt, pictures made and split, and a face
## redrawn in its TV moods with each mood's best seed picked (here from the test's own pictures,
## Hooks.fake_comfy, the library's reaction faces in tests/support/reactions: the suite never
## needs ComfyUI).

const PortraitMaker = preload("res://scripts/ai/portrait_maker.gd")
const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const Hooks = preload("res://scripts/test_hooks.gd")
const PortraitRules = preload("res://scripts/rules/portraits.gd")
const DebugLog = preload("res://scripts/debug_log.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")

const FIXTURE := "res://tests/support/portraits/portrait_w_20s_long_8000.png"


func after_test() -> void:
	Hooks.fake_comfy = []
	Hooks.fake_upload_refused = false
	AiSettings.override = {}
	DebugLog.everything_to_console = false
	DebugLog.printed = []


func _workflow() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PortraitMaker.WORKFLOW))


func test_the_workflow_is_filled_in_as_the_helper_fills_it() -> void:
	var base := _workflow()
	var filled := PortraitMaker.workflow_for(base, "a portrait", 81230, 768, 960, "ktbt/faces/owner")
	var by_type := {}
	for id in filled:
		by_type[str(filled[id]["class_type"]) + "|" + str(filled[id].get("_meta", {}).get("title", ""))] = filled[id]["inputs"]
	assert_str(str(by_type["CLIPTextEncode|CLIP Text Encode (Positive Prompt)"]["text"])).is_equal("a portrait")
	assert_int(by_type["RandomNoise|RandomNoise"]["noise_seed"]).is_equal(81230)
	assert_int(by_type["PrimitiveInt|Width"]["value"]).is_equal(768)
	assert_int(by_type["PrimitiveInt|Height"]["value"]).is_equal(960)
	assert_str(str(by_type["SaveImage|Save Image"]["filename_prefix"])).is_equal("ktbt/faces/owner")
	assert_bool(by_type["EmptyFlux2LatentImage|Empty Flux 2 Latent"]["batch_size"] is int).override_failure_message("JSON's floats left as floats").is_true()
	assert_bool(by_type["EmptyFlux2LatentImage|Empty Flux 2 Latent"]["width"] is Array).override_failure_message("a link overwritten").is_true()
	assert_str(str(_workflow()["77:92"]["inputs"]["text"])).is_not_equal("a portrait")  # (the exported one isn't changed)
	assert_dict(PortraitMaker.workflow_for({"1": {"class_type": "SaveImage", "inputs": {}}}, "x", 1, 8, 8, "p")).is_empty()  # (no prompt box)


func test_comfyuis_folder_comes_from_the_settings_and_must_have_its_python() -> void:
	assert_str(PortraitMaker.clean_path("  \"C:\\AI\\ComfyUI_windows_portable\\\"  \nsecond line")).is_equal("C:\\AI\\ComfyUI_windows_portable")
	assert_str(PortraitMaker.clean_path("")).is_empty()
	var folder := ProjectSettings.globalize_path("user://test_comfy")
	DirAccess.make_dir_recursive_absolute(folder.path_join("python_embeded"))
	AiSettings.override = {"comfyui": folder}
	assert_str(PortraitMaker.comfy_folder()).is_empty()  # (no Python in it)
	FileAccess.open(folder.path_join("python_embeded/python.exe"), FileAccess.WRITE).close()
	assert_str(PortraitMaker.comfy_folder()).is_equal(folder)
	DirAccess.remove_absolute(folder.path_join("python_embeded/python.exe"))
	DirAccess.remove_absolute(folder.path_join("python_embeded"))
	DirAccess.remove_absolute(folder)


func test_pictures_are_made_and_split_and_counted() -> void:
	Hooks.fake_comfy = [Image.load_from_file(ProjectSettings.globalize_path(FIXTURE)), "not a picture"]
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	var made: Array = await maker.make("a portrait", "owner", 3, 500)
	maker.close()
	assert_int(made.size()).is_equal(2)  # (the second "picture" failed, and the rest carried on)
	assert_array(made.map(func(m): return m["seed"])).is_equal([500, 502])
	var split: Dictionary = made[0]["split"]
	assert_object(split["layer"]).is_not_null()
	assert_int((split["layer"] as Image).get_width()).is_equal(PortraitSplit.W)
	assert_float(made[0]["score"]).is_equal(float(split["score"]))
	assert_int(maker.counts["made"]).is_equal(2)
	assert_int(maker.counts["failed"]).is_equal(1)
	assert_bool(maker.counts.has("started")).is_false()  # (nothing started, so nothing to stop)
	assert_bool(maker.counts.has("seconds")).is_true()


func test_a_test_pictures_split_is_kept_and_the_same_as_a_fresh_one() -> void:
	Hooks.kept_splits = {}
	Hooks.fake_comfy = [Image.load_from_file(ProjectSettings.globalize_path(FIXTURE))]
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	var made: Array = await maker.make("a portrait", "owner", 2, 700)
	var fresh: Dictionary = made[0]["split"]
	var kept: Dictionary = made[1]["split"]
	assert_bool(fresh.get("kept", false)).override_failure_message("the first one wasn't split").is_false()
	assert_bool(kept.get("kept", false)).override_failure_message("the second one was split again").is_true()
	for part in ["part", "step", "score", "shares", "resized"]:
		assert_that(kept[part]).override_failure_message("kept %s isn't the fresh one's" % part).is_equal(fresh[part])
	assert_bool((kept["layer"] as Image).get_data() == (fresh["layer"] as Image).get_data()).override_failure_message("kept layer isn't the fresh one's").is_true()
	# What's handed back is a copy: drawing on it leaves the kept one alone.
	(kept["layer"] as Image).fill(Color.RED)
	var again: Array = await maker.make("a portrait", "owner", 1, 702)
	assert_bool((again[0]["split"]["layer"] as Image).get_data() == (fresh["layer"] as Image).get_data()).override_failure_message("the kept layer was changed").is_true()
	# Scored as someone else (glasses and balding asked for, and not there): the same split, its own score.
	var other: Array = await maker.make("a portrait", "m_50s_balding_glasses", 1, 703)
	maker.close()
	var theirs: Dictionary = other[0]["split"]
	assert_bool(theirs.get("kept", false)).is_true()
	assert_float(float(theirs["score"])).is_equal(PortraitSplit.score(fresh["part"], "m_50s_balding_glasses"))
	assert_float(float(theirs["score"])).is_greater(float(fresh["score"]))
	assert_int(Hooks.kept_splits.size()).is_equal(1)
	Hooks.kept_splits = {}


# --- Their moods (redraw) ---------------------------------------------------------------------

const REACTIONS := "res://tests/support/reactions/"
const CALM := REACTIONS + "portrait_m_40s_side_part_8902.png"
const NEAR_SCORE := 0.005  # (test_reaction_split's: Godot's Lanczos isn't PIL's)


func _picture(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _mood_pictures(mood: String, first: int) -> Array:
	return [_picture(REACTIONS + "react_m_40s_side_part_%s_%d.png" % [mood, first]), _picture(REACTIONS + "react_m_40s_side_part_%s_%d.png" % [mood, first + 1])]


func _inputs(workflow: Dictionary, type: String) -> Dictionary:
	for id in workflow:
		if str(workflow[id]["class_type"]) == type:
			return workflow[id]["inputs"]
	return {}


func test_the_edit_workflow_is_given_the_picture_it_redraws() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PortraitMaker.EDIT_WORKFLOW))
	var filled := PortraitMaker.workflow_for(base, "Same person, sad", 41410, 768, 960, "ktbt/faces/owner_sad", "ktbt/ktbt_owner_calm.png")
	assert_str(str(_inputs(filled, "LoadImage")["image"])).is_equal("ktbt/ktbt_owner_calm.png")
	assert_str(str(_inputs(filled, "CLIPTextEncode")["text"])).is_equal("Same person, sad")
	assert_int(_inputs(filled, "RandomNoise")["noise_seed"]).is_equal(41410)
	assert_str(str(_inputs(filled, "SaveImage")["filename_prefix"])).is_equal("ktbt/faces/owner_sad")
	assert_bool(_inputs(filled, "EmptyFlux2LatentImage")["width"] is Array).override_failure_message("the size is the picture's (a link), not overwritten").is_true()
	assert_str(str(_inputs(base, "LoadImage")["image"])).is_not_equal("ktbt/ktbt_owner_calm.png")  # (the exported one isn't changed)
	assert_dict(PortraitMaker.workflow_for(_workflow(), "x", 1, 8, 8, "p", "ktbt/a.png")).is_empty()  # (a reference, and no Load Image to give it to)
	# Redrawn at the face's own size (768 x 960), not the exported 1 megapixel (~1.36 times the pixels).
	assert_float(float(_inputs(base, "ImageScaleToTotalPixels")["megapixels"])).is_equal(1.0)
	assert_float(float(_inputs(filled, "ImageScaleToTotalPixels")["megapixels"])).is_equal_approx(768 * 960 / 1000000.0, 0.000001)


func test_comfyui_started_early_is_waited_for_and_not_started_twice() -> void:
	# Started as the owner's invented (visit.gd _start_comfy_early), so its start-up overlaps the AI
	# making the bar; open() at the faces step only waits for what's left of it.
	Hooks.fake_comfy = [Image.load_from_file(ProjectSettings.globalize_path(FIXTURE))]
	DebugLog.everything_to_console = true
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	maker.launch()
	maker.launch()  # (once)
	assert_str(await maker.open()).is_empty()
	assert_bool(bool(maker.counts.get("early", false))).is_true()
	assert_bool(maker.counts.has("waited_ms")).is_true()
	assert_bool(bool(maker.counts.get("fake", false))).is_true()
	assert_int(DebugLog.printed.filter(func(line): return "starting ComfyUI early" in str(line)).size()).is_equal(1)
	assert_int(DebugLog.printed.filter(func(line): return "ComfyUI was started early" in str(line)).size()).is_equal(1)
	assert_int((await maker.make("a portrait", "owner", 1, 500)).size()).is_equal(1)
	assert_int(int(maker.counts["made"])).is_equal(1)  # (the counts launch() began carry on)
	maker.close()
	assert_str(PortraitMaker.time_text({"made": 1, "failed": 0, "early": true, "waited_ms": 4200, "seconds": 9})).is_equal("1 pictures · started early, 4.2s waited for it · 9s in all")
	# Not launched: open() starts it there and then, as before.
	var plain = auto_free(PortraitMaker.new())
	add_child(plain)
	assert_str(await plain.open()).is_empty()
	assert_bool(plain.counts.has("early")).is_false()
	plain.close()


func test_a_face_is_redrawn_in_its_moods_and_each_moods_best_seed_picked() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REACTIONS + "expected.json"))
	Hooks.fake_comfy = _mood_pictures("shock", 41400) + _mood_pictures("sad", 41410) + _mood_pictures("sweet", 41420)
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	DebugLog.everything_to_console = true
	DebugLog.printed = []
	var moods: Dictionary = await maker.redraw(_picture(CALM), "owner", false, ["shock", "sad", "sweet"], 2, 41400)
	maker.close()
	# Noted: the upload, each picture (who, mood, seed, made in, split in, score) and each mood's pick.
	var noted := "\n".join(DebugLog.printed)
	assert_str(noted).contains("Faces: the calm picture sent up as ktbt/ktbt_owner_calm.png")
	assert_str(noted).contains("Faces: owner, sad, seed 41410: made in ").contains("split in ").contains("score ")
	assert_str(noted).contains("Faces: owner, sweet: seed 41421 picked")
	assert_array(moods.keys()).contains_exactly(["shock", "sad", "sweet"])
	for mood in moods:
		var pick: Dictionary = moods[mood]
		assert_int(int(pick["seed"])).override_failure_message("%s's pick isn't the Python's" % mood).is_equal(int(expected["picks"][mood]))
		assert_int(pick["scores"].size()).is_equal(2)
		for pic_seed in pick["scores"]:
			var want := float(expected["pictures"]["react_m_40s_side_part_%s_%d.png" % [mood, pic_seed]]["score"])
			assert_float(float(pick["scores"][pic_seed])).override_failure_message("%s %d scored %.3f, the Python's %.3f" % [mood, pic_seed, pick["scores"][pic_seed], want]).is_equal_approx(want, NEAR_SCORE)
		assert_int((pick["split"]["layer"] as Image).get_width()).is_equal(PortraitSplit.W)
		assert_object(pick["picture"]).is_not_null()
	# What would have been queued: the edit workflow, the calm picture as its reference, each mood's words and seeds.
	assert_int(maker.sent.size()).is_equal(6)
	var seeds: Array = []
	for k in maker.sent.size():
		var workflow: Dictionary = maker.sent[k]
		var mood: String = ["shock", "sad", "sweet"][int(k / 2.0)]
		assert_str(str(_inputs(workflow, "LoadImage")["image"])).is_equal("ktbt/ktbt_owner_calm.png")
		assert_str(str(_inputs(workflow, "CLIPTextEncode")["text"])).is_equal(PortraitRules.react_prompt(mood, false))
		seeds.append(int(_inputs(workflow, "RandomNoise")["noise_seed"]))
	assert_array(seeds).is_equal([41400, 41401, 41410, 41411, 41420, 41421])
	assert_int(maker.counts["made"]).is_equal(6)
	assert_int(maker.counts["uploads"]).is_equal(1)


func test_one_seed_a_mood_and_a_second_only_when_it_scores_badly() -> void:
	# The game's way (visit.gd passes MOOD_CLEAN_ENOUGH): a mood's two seeds were never more than
	# 0.03 apart, so the second's only made when the first scores worse than retry_over.
	# shock 41400 scores 0.180 (kept), sad 41410 0.422 (over 0.3: 41411 too, 0.125, picked).
	Hooks.fake_comfy = [_picture(REACTIONS + "react_m_40s_side_part_shock_41400.png"), _picture(REACTIONS + "react_m_40s_side_part_sad_41410.png"), _picture(REACTIONS + "react_m_40s_side_part_sad_41411.png")]
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	DebugLog.everything_to_console = true
	DebugLog.printed = []
	var moods: Dictionary = await maker.redraw(_picture(CALM), "owner", false, ["shock", "sad"], 2, 41400, 0.3)
	assert_array(moods.keys()).contains_exactly(["shock", "sad"])
	assert_int(int(moods["shock"]["seed"])).is_equal(41400)
	assert_int(moods["shock"]["scores"].size()).is_equal(1)
	assert_int(int(moods["sad"]["seed"])).is_equal(41411)
	assert_array(moods["sad"]["scores"].keys()).contains_exactly([41410, 41411])
	assert_array(maker.order).is_equal(["ask 41400", "split", "ask 41410", "split", "split", "ask 41411", "split"])  # (the retry asked for once it's known it's needed)
	assert_int(maker.counts["made"]).is_equal(3)
	assert_int(maker.counts["retries"]).is_equal(1)
	assert_str("\n".join(DebugLog.printed)).contains("Faces: owner, sad: scored 0.42").contains("over 0.30, so seed 41411 too")
	# A first picture that doesn't come out is tried again too; never more than seeds.
	Hooks.fake_comfy = ["not a picture", _picture(REACTIONS + "react_m_40s_side_part_sad_41411.png")]
	maker.order = []
	var again: Dictionary = await maker.redraw(_picture(CALM), "owner", false, ["sad"], 2, 500, 0.3)
	assert_int(int(again["sad"]["seed"])).is_equal(501)
	assert_int(maker.counts["retries"]).is_equal(2)
	Hooks.fake_comfy = ["not a picture"]
	var none: Dictionary = await maker.redraw(_picture(CALM), "owner", false, ["sad"], 2, 500, 0.3)
	assert_str(str(none["sad"].get("failed", ""))).is_equal("the test's picture wasn't one")  # (two tries, then the calm face)
	assert_int(maker.counts["retries"]).is_equal(3)
	maker.close()


func test_a_mood_that_fails_says_why_and_the_rest_carry_on() -> void:
	Hooks.fake_comfy = ["not a picture", "not a picture"] + _mood_pictures("sweet", 41420)
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	var moods: Dictionary = await maker.redraw(_picture(CALM), "regular_minji", true, ["sad", "bored", "sweet"], 2, 500)
	assert_str(str(moods["sad"].get("failed", ""))).is_equal("the test's picture wasn't one")
	assert_str(str(moods["bored"].get("failed", ""))).contains("no face for the mood bored")
	assert_int(int(moods["sweet"]["seed"])).is_between(520, 521)  # (sweet's seeds still its own: the third mood's)
	assert_str(str(_inputs(maker.sent[0], "CLIPTextEncode")["text"])).contains("same glasses")
	assert_int(maker.counts["failed"]).is_equal(2)
	# Nothing to try: the upload refused, no edit workflow, no calm picture. The calm face is kept.
	Hooks.fake_upload_refused = true
	assert_dict(await maker.redraw(_picture(CALM), "owner", false, ["sad"], 2, 500)).is_empty()
	assert_str(maker.last_error).contains("refused the calm picture")
	Hooks.fake_upload_refused = false
	assert_dict(await maker.redraw(null, "owner", false, ["sad"], 2, 500)).is_empty()
	assert_str(maker.last_error).contains("no calm picture")
	var fresh = auto_free(PortraitMaker.new())
	add_child(fresh)
	fresh.edit_workflow = "res://tools/art/no_such_workflow.json"
	assert_str(await fresh.open()).is_empty()
	assert_dict(await fresh.redraw(_picture(CALM), "owner", false, ["sad"], 2, 500)).is_empty()
	assert_str(fresh.last_error).contains("no edit workflow")
	maker.close()
	fresh.close()
	assert_int(maker.counts["redraws_failed"]).is_equal(2)


func test_each_picture_is_asked_for_before_the_last_ones_split() -> void:
	# So ComfyUI makes the next picture while the CPU splits this one (it sat idle half the time).
	Hooks.fake_comfy = [Image.load_from_file(ProjectSettings.globalize_path(FIXTURE))]
	var maker = auto_free(PortraitMaker.new())
	add_child(maker)
	assert_str(await maker.open()).is_empty()
	var made: Array = await maker.make("a portrait", "owner", 3, 500)
	assert_int(made.size()).is_equal(3)
	assert_array(maker.order).is_equal(["ask 500", "ask 501", "split", "ask 502", "split", "split"])
	# The moods too, from one mood to the next, the calm picture's split while the first is made.
	Hooks.fake_comfy = _mood_pictures("shock", 41400) + _mood_pictures("sad", 41410)
	maker.order = []
	var moods: Dictionary = await maker.redraw(_picture(CALM), "owner", false, ["shock", "sad"], 2, 41400)
	maker.close()
	assert_array(moods.keys()).contains_exactly(["shock", "sad"])
	assert_array(maker.order).is_equal(["ask 41400", "split", "ask 41401", "split", "ask 41410", "split", "ask 41411", "split", "split"])


func test_comfyuis_own_time_is_read_from_its_history() -> void:
	var entry := {"status": {"status_str": "success", "messages": [["execution_start", {"prompt_id": "a", "timestamp": 1000}],
		["execution_cached", {"nodes": [], "timestamp": 1001}], ["execution_success", {"prompt_id": "a", "timestamp": 10500}]]}}
	assert_int(PortraitMaker.comfy_ms(entry)).is_equal(9500)
	assert_int(PortraitMaker.comfy_ms({})).is_equal(-1)
	assert_int(PortraitMaker.comfy_ms({"status": {"messages": [["execution_start", {"timestamp": 1000}]]}})).is_equal(-1)  # (not finished)
	assert_int(PortraitMaker.comfy_ms({"status": {"messages": ["junk", [1]]}})).is_equal(-1)
	assert_float(PortraitMaker._took({"ms": 9500, "asked": 0})).is_equal(9.5)
	# Noted when it closes: where the gap's time went.
	assert_str(PortraitMaker.time_text({"made": 30, "failed": 1, "gpu_ms": 300200, "first_ms": 30100, "split_ms": 55800, "start_ms": 12000, "seconds": 340})).is_equal(
		"31 pictures, 300.2s on the GPU (the first 30.1s: the model loading) · splits 55.8s, alongside the next picture · ComfyUI started in 12.0s · 340s in all")
	assert_str(PortraitMaker.time_text({"made": 2, "failed": 0, "seconds": 3})).is_equal("2 pictures · 3s in all")


func test_a_picture_given_up_on_is_found_in_comfyuis_queue_and_the_gpu_noted() -> void:
	# 26 Nov: a picture past PICTURE_SECONDS was left queued, and each next one waited behind it.
	var queue := {"queue_running": [[7, "abc", {}]], "queue_pending": [[8, "def", {}], [9, "ghi", {}]]}
	assert_str(PortraitMaker.queue_place(queue, "abc")).is_equal("running")
	assert_str(PortraitMaker.queue_place(queue, "ghi")).is_equal("waiting")
	assert_str(PortraitMaker.queue_place(queue, "zzz")).is_empty()
	assert_str(PortraitMaker.queue_place({}, "abc")).is_empty()
	assert_str(PortraitMaker.queue_place({"queue_running": "junk", "queue_pending": [["x"]]}, "abc")).is_empty()
	# The GPU's free memory, noted as the pictures start.
	var gb := 1024 * 1024 * 1024
	assert_str(PortraitMaker.gpu_text({"devices": [{"vram_total": 12 * gb, "vram_free": 3 * gb}]})).is_equal("3.0 of 12.0 GB free on the GPU")
	assert_str(PortraitMaker.gpu_text({})).is_empty()
	assert_str(PortraitMaker.gpu_text({"devices": [{"name": "cpu"}]})).is_empty()
	# Counted in the notes and the night's stats.
	assert_str(PortraitMaker.time_text({"made": 2, "failed": 1, "cancelled": 1, "seconds": 3})).is_equal("3 pictures · 1 given up on and taken off ComfyUI · 3s in all")
	assert_str(NightStats.comfy_text({"made": 2, "failed": 1, "cancelled": 1})).contains("(1 given up on)")
