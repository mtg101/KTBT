extends Node
## Faces of their own (PLAN.md, Next stages): Godot driving the image model, FLUX.2 Klein 4B in
## ComfyUI on this PC, as the helper does for the art (tools/autoplay_mcp.ps1): starting ComfyUI
## from its folder (the faces settings, ai/ai_settings.gd, or tools/comfyui_path.txt), filling
## tools/art/klein_api.json's prompt, seed and size, queueing it (/prompt), waiting for it
## (/history) and fetching the picture (/view), which rules/portrait_split.gd splits into a
## portrait (on a worker thread: about 2.5 seconds a picture). Only in the gaps when the GPU's
## free (visit.gd lets Ollama go first, Ai.let_go): open(), make() as many as wanted, close().
## A ComfyUI that was already running is used and left running; one started here is stopped.
## Anything going wrong is said in last_error and the notes, and the caller keeps the library's
## face. Tests hand it pictures (Hooks.fake_comfy) instead of ComfyUI.

const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")
const DebugLog = preload("res://scripts/debug_log.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

const URL := "http://127.0.0.1:8188"
const WORKFLOW := "res://tools/art/klein_api.json"
const PATH_FILE := "res://tools/comfyui_path.txt"  # (this PC's own, as the helper's: not in git)
const START_SECONDS := 90  # ComfyUI takes 10 to 30 seconds to start
const PICTURE_SECONDS := 180  # one picture at most (the first loads the model: about 5 seconds each after)
const WIDTH := PortraitSplit.W * PortraitSplit.SAMPLE  # 768 x 960, as the library's
const HEIGHT := PortraitSplit.H * PortraitSplit.SAMPLE

var last_error := ""
## What it did, for the night's stats: "started" and "stopped" (ComfyUI, by us), "already" (it was
## running), "made", "failed" (pictures), "seconds" (open to close).
var counts := {}
var _pid := -1
var _started := false
var _opened_at := 0
var _workflow := {}


## The ComfyUI folder to start: the setting, else tools/comfyui_path.txt's line; "" if neither
## names a folder with ComfyUI's own Python in it.
static func comfy_folder() -> String:
	var chosen := str(AiSettings.load_settings().get("comfyui", ""))
	if chosen.strip_edges() == "" and FileAccess.file_exists(PATH_FILE):
		chosen = FileAccess.get_file_as_string(PATH_FILE)
	chosen = clean_path(chosen)
	if chosen == "" or not FileAccess.file_exists(chosen.path_join("python_embeded/python.exe")):
		return ""
	return chosen


## A folder as written in a file or a setting: its first line, without quotes or a trailing slash.
static func clean_path(text: String) -> String:
	var line := text.strip_edges().split("\n", false)
	if line.is_empty():
		return ""
	return line[0].strip_edges().trim_prefix("\"").trim_suffix("\"").rstrip("\\/")


## The workflow to queue for one picture: a copy of the exported one with the prompt in its
## (first, not negative) text box, the seed, the size (the Klein template's Width and Height
## boxes) and where it's saved; its whole numbers as whole numbers (JSON gives floats). {} if it
## has no prompt box.
static func workflow_for(base: Dictionary, prompt: String, pic_seed: int, width: int, height: int, prefix: String) -> Dictionary:
	var workflow: Dictionary = _whole(base.duplicate(true))
	var prompted := false
	for id in workflow:
		var node = workflow[id]
		if not node is Dictionary or not (node as Dictionary).get("inputs") is Dictionary:
			continue
		var inputs: Dictionary = node["inputs"]
		var type := str(node.get("class_type", ""))
		var meta = node.get("_meta", {})
		var title := str(meta.get("title", "")) if meta is Dictionary else ""
		if type.begins_with("CLIPTextEncode") and inputs.has("text") and not "Negative" in title and not prompted:
			inputs["text"] = prompt
			prompted = true
		for field in ["seed", "noise_seed"]:
			if inputs.has(field) and not inputs[field] is Array:
				inputs[field] = pic_seed
		if inputs.has("width") and inputs.has("height") and not inputs["width"] is Array:
			inputs["width"] = width
			inputs["height"] = height
		if type == "PrimitiveInt" and title == "Width":
			inputs["value"] = width
		if type == "PrimitiveInt" and title == "Height":
			inputs["value"] = height
		if type == "SaveImage":
			inputs["filename_prefix"] = prefix
	return workflow if prompted else {}


static func _whole(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value:
			value[key] = _whole(value[key])
	elif value is Array:
		for k in (value as Array).size():
			value[k] = _whole(value[k])
	elif value is float and is_equal_approx(value, roundf(value)) and absf(value) < 9.0e15:
		return int(value)
	return value


## Gets ComfyUI answering: already running (used, and left running), or started from its folder
## and waited for. "" when it's answering, otherwise why not (in last_error too).
func open() -> String:
	_opened_at = Time.get_ticks_msec()
	counts = {"made": 0, "failed": 0}
	if not Hooks.fake_comfy.is_empty():
		counts["fake"] = true
		return ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORKFLOW)) if FileAccess.file_exists(WORKFLOW) else null
	if not parsed is Dictionary:
		return _fail("no workflow at %s (ComfyUI's Workflow > Export (API))" % WORKFLOW)
	_workflow = parsed
	if await _answers():
		counts["already"] = true
		DebugLog.say("Faces", "ComfyUI's already running: using it (and leaving it running)")
		return ""
	if OS.get_name() != "Windows":
		return _fail("ComfyUI isn't running, and it's only started on Windows")
	var folder := comfy_folder()
	if folder == "":
		return _fail("can't find ComfyUI: its folder goes in ai_settings.cfg's comfyui, or on one line in tools/comfyui_path.txt")
	var logs := ProjectSettings.globalize_path("res://logs/" if OS.has_feature("editor") else "user://logs/")
	DirAccess.make_dir_recursive_absolute(logs)
	var starter := ProjectSettings.globalize_path("user://start_comfyui.bat")  # (a batch file: cmd's quoting, and its output into the logs)
	var file := FileAccess.open(starter, FileAccess.WRITE)
	if file == null:
		return _fail("couldn't write %s" % starter)
	file.store_string("@echo off\r\ncd /d \"%s\"\r\n\"%s\" -s ComfyUI\\main.py --windows-standalone-build --disable-auto-launch > \"%s\" 2> \"%s\"\r\n" % [
		folder, folder.path_join("python_embeded/python.exe").replace("/", "\\"), (logs + "comfyui.log").replace("/", "\\"), (logs + "comfyui_errors.log").replace("/", "\\")])
	file.close()
	_pid = OS.create_process("cmd.exe", ["/c", starter.replace("/", "\\")])
	if _pid <= 0:
		return _fail("couldn't start ComfyUI from %s" % folder)
	_started = true
	counts["started"] = true
	DebugLog.say("Faces", "started ComfyUI (from its folder, process %d)" % _pid)
	for wait in range(2, START_SECONDS + 1, 2):
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree():
			return _fail("closed while ComfyUI was starting")
		if await _answers():
			DebugLog.say("Faces", "ComfyUI answering after %d seconds" % wait)
			return ""
	close()
	return _fail("ComfyUI didn't answer within %d seconds (see logs/comfyui_errors.log)" % START_SECONDS)


## Stops ComfyUI if it was started here (the GPU back for Ollama); one already running is left
## running, its models unloaded. Use with await (the unloading's a request).
func close() -> void:
	if not counts.has("seconds") and _opened_at > 0:
		counts["seconds"] = roundi((Time.get_ticks_msec() - _opened_at) / 1000.0)
	if not _started:
		if bool(counts.get("already", false)) and not bool(counts.get("freed", false)) and is_inside_tree():
			await _free_gpu()  # (one already running is left running, but without the model on the GPU)
		return
	_started = false
	OS.execute("taskkill", ["/PID", str(_pid), "/T", "/F"])  # (the batch file and ComfyUI's Python under it)
	counts["stopped"] = true
	DebugLog.say("Faces", "stopped ComfyUI: the GPU's Ollama's again")


## Asks a ComfyUI that was already running to unload its models (/free), so Ollama gets the
## GPU back without stopping it. Use with await.
func _free_gpu() -> void:
	counts["freed"] = true
	var reply := await _request(URL + "/free", HTTPClient.METHOD_POST, JSON.stringify({"unload_models": true, "free_memory": true}), 5.0)
	counts["unloaded"] = bool(reply[0])
	DebugLog.say("Faces", "ComfyUI (left running) unloaded its models: the GPU's Ollama's again" if reply[0] else "ComfyUI (left running) didn't unload its models (HTTP %d)" % int(reply[1]))


func _exit_tree() -> void:
	close()  # (the game closing mid-casting never leaves ComfyUI running)


## count pictures of prompt (seeds from first_seed up), each split into a portrait:
## [{"seed", "picture" (the model's), "split" (rules/portrait_split.gd), "score"}], the ones that
## came out (a picture that fails is counted and noted, and the rest carry on). After open().
func make(prompt: String, person: String, count: int, first_seed: int) -> Array:
	var made: Array = []
	for k in count:
		var pic_seed := first_seed + k
		var asked := Time.get_ticks_msec()
		var picture: Image = await _picture(prompt, person, pic_seed, k)
		if not is_inside_tree():
			return made
		if picture == null:
			counts["failed"] = int(counts.get("failed", 0)) + 1
			DebugLog.say("Faces", "%s, seed %d: no picture (%s)" % [person, pic_seed, last_error])
			continue
		var took := (Time.get_ticks_msec() - asked) / 1000.0
		var split := await _split(picture, person)
		if not is_inside_tree():
			return made
		counts["made"] = int(counts.get("made", 0)) + 1
		var shares: Dictionary = split.get("shares", {})
		DebugLog.say("Faces", "%s, seed %d: made in %.1fs, split in %.1fs, score %.3f (hair %d%%, skin %d%%, cloth %d%%, lines %d%%)" % [person, pic_seed, took,
			int(split.get("ms", 0)) / 1000.0, float(split.get("score", 99.0)), roundi(float(shares.get("hair", 0)) * 100), roundi(float(shares.get("skin", 0)) * 100),
			roundi(float(shares.get("cloth", 0)) * 100), roundi(float(shares.get("lines", 0)) * 100)])
		made.append({"seed": pic_seed, "picture": picture, "split": split, "score": float(split.get("score", 99.0))})
	return made


func _picture(prompt: String, person: String, pic_seed: int, k: int) -> Image:
	if not Hooks.fake_comfy.is_empty():
		await get_tree().process_frame
		var fake = Hooks.fake_comfy[k % Hooks.fake_comfy.size()]
		if fake is Image:
			return (fake as Image).duplicate() as Image
		last_error = "the test's picture wasn't one"
		return null
	var workflow := workflow_for(_workflow, prompt, pic_seed, WIDTH, HEIGHT, "ktbt/faces/%s" % person)
	if workflow.is_empty():
		last_error = "the workflow has no prompt box"
		return null
	var queued := await _request(URL + "/prompt", HTTPClient.METHOD_POST, JSON.stringify({"prompt": workflow, "client_id": "ktbt-game"}), 15.0)
	var answer = JSON.parse_string((queued[2] as PackedByteArray).get_string_from_utf8()) if queued[0] else null
	if not answer is Dictionary or str(answer.get("prompt_id", "")) == "":
		last_error = "ComfyUI didn't take the picture (HTTP %d)" % int(queued[1])
		return null
	var id := str(answer["prompt_id"])
	for _second in PICTURE_SECONDS:
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return null
		var history := await _request(URL + "/history/" + id, HTTPClient.METHOD_GET, "", 5.0)
		var entries = JSON.parse_string((history[2] as PackedByteArray).get_string_from_utf8()) if history[0] else null
		if not entries is Dictionary or not entries.has(id):
			continue
		for node in entries[id].get("outputs", {}).values():
			for image in node.get("images", []):
				var query := "filename=%s&subfolder=%s&type=%s" % [str(image.get("filename", "")).uri_encode(), str(image.get("subfolder", "")).uri_encode(), str(image.get("type", "output"))]
				var fetched := await _request(URL + "/view?" + query, HTTPClient.METHOD_GET, "", 30.0)
				var picture := Image.new()
				if fetched[0] and picture.load_png_from_buffer(fetched[2]) == OK:
					return picture
				last_error = "couldn't fetch the picture from ComfyUI"
				return null
		last_error = "ComfyUI finished without a picture"
		return null
	last_error = "no picture after %d seconds" % PICTURE_SECONDS
	return null


## The split on a worker thread, the game carrying on meanwhile.
func _split(picture: Image, person: String) -> Dictionary:
	var out := {}
	var task := WorkerThreadPool.add_task(func(): out.merge(PortraitSplit.split(picture, person)))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return out


func _answers() -> bool:
	var reply := await _request(URL + "/system_stats", HTTPClient.METHOD_GET, "", 3.0)
	return reply[0]


## [ok (HTTP 200), the HTTP code, the body].
func _request(url: String, method: HTTPClient.Method, body: String, seconds: float) -> Array:
	var http := HTTPRequest.new()
	http.timeout = seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"]) if method == HTTPClient.METHOD_POST else PackedStringArray()
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return [false, 0, PackedByteArray()]
	var result: Array = await http.request_completed
	http.queue_free()
	return [result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, result[1], result[3]]


func _fail(why: String) -> String:
	last_error = why
	DebugLog.say("Faces", "no ComfyUI: %s" % why)
	return why
