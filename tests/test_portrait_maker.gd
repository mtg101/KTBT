extends GdUnitTestSuite
## Tests for scripts/ai/portrait_maker.gd: the workflow filled in as the helper fills it, ComfyUI's
## folder read from the settings or tools/comfyui_path.txt, and pictures made and split (here from
## the test's own pictures, Hooks.fake_comfy: the suite never needs ComfyUI).

const PortraitMaker = preload("res://scripts/ai/portrait_maker.gd")
const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

const FIXTURE := "res://tests/support/portraits/portrait_w_20s_long_8000.png"


func after_test() -> void:
	Hooks.fake_comfy = []
	AiSettings.override = {}


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
