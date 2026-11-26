extends Node
## Faces of their own (PLAN.md, Next stages): Godot driving the image model, FLUX.2 Klein 4B in
## ComfyUI on this PC, as the helper does for the art (tools/autoplay_mcp.ps1): starting ComfyUI
## from its folder (the faces settings, ai/ai_settings.gd, or tools/comfyui_path.txt), filling
## tools/art/klein_api.json's prompt, seed and size, queueing it (/prompt), waiting for it
## (/history) and fetching the picture (/view), which rules/portrait_split.gd splits into a
## portrait (on a worker thread: about 2.5 seconds a picture). Only in the gaps when the GPU's
## free (visit.gd lets Ollama go first, Ai.let_go): open(), make() as many as wanted, close().
## redraw() makes a face's TV moods from its calm picture, as the library's reaction faces were
## (tools/art/portraits.py): the picture sent up (/upload/image), tools/art/klein_edit_api.json
## queued with its Load Image set to it, each picture split into a close-up (react_split) and the
## best seed of each mood picked against the calm one's (react_score, best()).
## A ComfyUI that was already running is used and left running; one started here is stopped.
## Anything going wrong is said in last_error and the notes, and the caller keeps the library's
## face. Tests hand it pictures (Hooks.fake_comfy) instead of ComfyUI.

const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")
const PortraitRules = preload("res://scripts/rules/portraits.gd")
const DebugLog = preload("res://scripts/debug_log.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

const URL := "http://127.0.0.1:8188"
const WORKFLOW := "res://tools/art/klein_api.json"
const EDIT_WORKFLOW := "res://tools/art/klein_edit_api.json"  # (the moods: a picture redrawn)
const MOOD_SEEDS_APART := 10  # a mood's seeds from the last mood's, as portraits.py's jobs
const PATH_FILE := "res://tools/comfyui_path.txt"  # (this PC's own, as the helper's: not in git)
const START_SECONDS := 90  # ComfyUI takes 10 to 30 seconds to start
const PICTURE_SECONDS := 180  # one picture at most (the first loads the model: about 5 seconds each after)
const POLL_SECONDS := 0.25  # how often a picture's asked after (it was a second: half a second lost a picture)
const WIDTH := PortraitSplit.W * PortraitSplit.SAMPLE  # 768 x 960, as the library's
const HEIGHT := PortraitSplit.H * PortraitSplit.SAMPLE

var last_error := ""
## After each picture asked for, made or not (make() and redraw()): for the PD's backstage note.
signal picture_done
## What it did, for the night's stats: "started" and "stopped" (ComfyUI, by us), "already" (it was
## running), "made", "failed" (pictures), "seconds" (open to close).
var counts := {}
var _pid := -1
var _started := false
var _opened_at := 0
var _workflow := {}
var _edit := {}
## The edit workflow redraw() reads (tests point it somewhere else).
var edit_workflow := EDIT_WORKFLOW
## With Hooks.fake_comfy: each workflow that would have been queued, in turn, for the tests.
var sent: Array = []
## With Hooks.fake_comfy: what happened, in turn ("ask <seed>", "split"), for the tests: each
## picture's asked for before the last one's split.
var order: Array = []


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
## boxes) and where it's saved; its whole numbers as whole numbers (JSON gives floats). reference:
## the picture an edit workflow redraws (its Load Image's, as ComfyUI named it when it was sent
## up). {} if it has no prompt box, or a reference and no Load Image.
static func workflow_for(base: Dictionary, prompt: String, pic_seed: int, width: int, height: int, prefix: String, reference: String = "") -> Dictionary:
	var workflow: Dictionary = _whole(base.duplicate(true))
	var prompted := false
	var loaded := reference == ""
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
		if type == "LoadImage" and reference != "" and inputs.has("image"):
			inputs["image"] = reference
			loaded = true
	return workflow if prompted and loaded else {}


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
	var since := Time.get_ticks_msec()  # (by the clock: counting the waits missed each check's own time, up to 3s: night 1's "14 seconds" was 34)
	while Time.get_ticks_msec() - since < START_SECONDS * 1000:
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return _fail("closed while ComfyUI was starting")
		if await _answers():
			counts["start_ms"] = Time.get_ticks_msec() - since
			DebugLog.say("Faces", "ComfyUI answering after %.1f seconds" % (int(counts["start_ms"]) / 1000.0))
			return ""
	close()
	return _fail("ComfyUI didn't answer within %d seconds (see logs/comfyui_errors.log)" % START_SECONDS)


## Stops ComfyUI if it was started here (the GPU back for Ollama); one already running is left
## running, its models unloaded. Use with await (the unloading's a request).
func close() -> void:
	if not counts.has("seconds") and _opened_at > 0:
		counts["seconds"] = roundi((Time.get_ticks_msec() - _opened_at) / 1000.0)
		DebugLog.say("Faces", "ComfyUI's time: " + time_text(counts))
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


## Where a gap's time went, for the notes: "31 pictures, 300.2s on the GPU (the first 30.1s: the
## model loading) · splits 55.8s, alongside the next picture · ComfyUI started in 12.0s · 340s in all".
static func time_text(faces: Dictionary) -> String:
	var parts := PackedStringArray()
	var pictures := "%d pictures" % (int(faces.get("made", 0)) + int(faces.get("failed", 0)))
	if faces.has("gpu_ms"):
		pictures += ", %.1fs on the GPU" % (int(faces["gpu_ms"]) / 1000.0)
		if faces.has("first_ms"):
			pictures += " (the first %.1fs: the model loading)" % (int(faces["first_ms"]) / 1000.0)
	parts.append(pictures)
	if int(faces.get("split_ms", 0)) > 0:
		parts.append("splits %.1fs, alongside the next picture" % (int(faces["split_ms"]) / 1000.0))
	if faces.has("start_ms"):
		parts.append("ComfyUI started in %.1fs" % (int(faces["start_ms"]) / 1000.0))
	parts.append("%ds in all" % int(faces.get("seconds", 0)))
	return " · ".join(parts)


func _exit_tree() -> void:
	close()  # (the game closing mid-casting never leaves ComfyUI running)


## count pictures of prompt (seeds from first_seed up), each split into a portrait:
## [{"seed", "picture" (the model's), "split" (rules/portrait_split.gd), "score"}], the ones that
## came out (a picture that fails is counted and noted, and the rest carry on). After open().
## split_name: what the split scores them as (PortraitRules.split_name: balding, glasses), else person.
## Each picture's split while ComfyUI makes the next (it's asked for first), so the GPU's never
## left waiting on the CPU.
func make(prompt: String, person: String, count: int, first_seed: int, split_name: String = "") -> Array:
	var made: Array = []
	var prefix := "ktbt/faces/%s" % person
	var ticket := {}
	if count > 0:
		ticket = await _ask(_workflow, prompt, first_seed, 0, prefix)
	for k in count:
		var pic_seed := first_seed + k
		var picture: Image = await _collect(ticket)
		if not is_inside_tree():
			return made
		var why := last_error
		var took := _took(ticket)
		if k + 1 < count:
			ticket = await _ask(_workflow, prompt, pic_seed + 1, k + 1, prefix)  # (the next one made while this one's split)
			if not is_inside_tree():
				return made
		if picture == null:
			counts["failed"] = int(counts.get("failed", 0)) + 1
			DebugLog.say("Faces", "%s, seed %d: no picture (%s)" % [person, pic_seed, why])
			picture_done.emit()
			continue
		var split := await _split(picture, split_name if split_name != "" else person)
		if not is_inside_tree():
			return made
		counts["made"] = int(counts.get("made", 0)) + 1
		picture_done.emit()
		var shares: Dictionary = split.get("shares", {})
		DebugLog.say("Faces", "%s, seed %d: made in %.1fs, split in %.1fs%s, score %.3f (hair %d%%, skin %d%%, cloth %d%%, lines %d%%)" % [person, pic_seed, took,
			int(split.get("ms", 0)) / 1000.0, " (the test's picture's split, kept)" if split.get("kept", false) else " (%d at once)" % int(split.get("pieces", 1)), float(split.get("score", 99.0)), roundi(float(shares.get("hair", 0)) * 100), roundi(float(shares.get("skin", 0)) * 100),
			roundi(float(shares.get("cloth", 0)) * 100), roundi(float(shares.get("lines", 0)) * 100)])
		made.append({"seed": pic_seed, "picture": picture, "split": split, "score": float(split.get("score", 99.0))})
	return made



## A face of someone's own in TV moods (moods: captions.gd REACTIONS's), redrawn from its calm
## picture (the model's, kept with the bar: the face's "picture"), as the library's reaction faces
## were (tools/art/portraits.py): the picture sent up to ComfyUI (/upload/image, so one that was
## already running has it too), then for each mood seeds pictures (seeds from first_seed, each mood
## MOOD_SEEDS_APART on) by the edit workflow, its prompt PortraitRules.react_prompt (glasses said
## outright), each split into its close-up on a worker thread (react_split) and scored against the
## calm one's (react_score); each mood's best seed (PortraitSplit.best). After open(). As make(),
## each picture's split while ComfyUI makes the next, from one mood to the next.
## {mood: {"seed", "picture", "split", "score", "scores": {seed: score}}}, a mood none of whose
## pictures came out {"failed": why}; {} if nothing could be tried (no edit workflow, no calm
## picture, the upload refused: why in last_error and the notes), so the calm face is kept.
## person: who (for the notes and the pictures' names: "owner", a regular's tag).
func redraw(calm: Image, person: String, glasses: bool, moods: Array, seeds: int, first_seed: int) -> Dictionary:
	var out := {}
	if calm == null or calm.is_empty():
		_fail_redraw(person, "no calm picture to redraw")
		return out
	if _edit.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(edit_workflow)) if FileAccess.file_exists(edit_workflow) else null
		if not parsed is Dictionary:
			_fail_redraw(person, "no edit workflow at %s (ComfyUI's Workflow > Export (API))" % edit_workflow)
			return out
		_edit = parsed
	var reference := await _upload(calm, "ktbt_%s_calm.png" % person)
	if not is_inside_tree():
		return out
	if reference == "":
		_fail_redraw(person, last_error)
		return out
	# Every picture to make, in turn: [mood, seed, prompt]. A mood with no face is said at once.
	var jobs: Array = []
	for m in moods.size():
		var mood := str(moods[m])
		var prompt := PortraitRules.react_prompt(mood, glasses)
		out[mood] = {}  # (keeps the moods in the order asked)
		if prompt == "":
			out[mood] = {"failed": "there's no face for the mood %s" % mood}
			DebugLog.say("Faces", "%s, %s: %s" % [person, mood, out[mood]["failed"]])
			continue
		for n in seeds:
			jobs.append([mood, first_seed + MOOD_SEEDS_APART * m + n, prompt])
	var tried := {}
	var why := {}
	var ticket := {}
	if not jobs.is_empty():
		ticket = await _ask(_edit, jobs[0][2], jobs[0][1], 0, "ktbt/faces/%s_%s" % [person, jobs[0][0]], reference)
		if not is_inside_tree():
			return _only_done(out)
	var calm_split := await _split(calm, person, true)  # (while the first picture's made)
	if not is_inside_tree():
		return _only_done(out)
	for k in jobs.size():
		var mood: String = jobs[k][0]
		var pic_seed: int = jobs[k][1]
		var picture: Image = await _collect(ticket)
		if not is_inside_tree():
			return _only_done(out)
		var failed_why := last_error
		var took := _took(ticket)
		if k + 1 < jobs.size():
			var next: Array = jobs[k + 1]
			ticket = await _ask(_edit, next[2], next[1], k + 1, "ktbt/faces/%s_%s" % [person, next[0]], reference)  # (the next one made while this one's split)
			if not is_inside_tree():
				return _only_done(out)
		if picture == null:
			counts["failed"] = int(counts.get("failed", 0)) + 1
			why[mood] = failed_why
			DebugLog.say("Faces", "%s, %s, seed %d: no picture (%s)" % [person, mood, pic_seed, failed_why])
			picture_done.emit()
		else:
			var split := await _split(picture, person, true)
			if not is_inside_tree():
				return _only_done(out)
			counts["made"] = int(counts.get("made", 0)) + 1
			picture_done.emit()
			var score := PortraitSplit.react_score(split["part"], calm_split["part"], mood)
			var shown := PortraitSplit.colours(split["part"])
			DebugLog.say("Faces", "%s, %s, seed %d: made in %.1fs, split in %.1fs%s, score %.3f (whites %d, tears %d, blush %d)" % [person, mood, pic_seed, took,
				int(split.get("ms", 0)) / 1000.0, " (the test's picture's split, kept)" if split.get("kept", false) else " (%d at once)" % int(split.get("pieces", 1)), score,
				int(shown["white"]), int(shown["tear"]), int(shown["blush"])])
			if not tried.has(mood):
				tried[mood] = []
			tried[mood].append({"seed": pic_seed, "picture": picture, "split": split, "score": score})
		if k + 1 == jobs.size() or str(jobs[k + 1][0]) != mood:
			out[mood] = _pick(person, mood, tried.get(mood, []), str(why.get(mood, "")))
	return out


## A mood's best seed of those tried, with every seed's score, or {"failed": why} if none came out.
func _pick(person: String, mood: String, tried: Array, why: String) -> Dictionary:
	var at := PortraitSplit.best(tried)
	if at < 0:
		DebugLog.say("Faces", "%s, %s: no picture came out (%s)" % [person, mood, why])
		return {"failed": why}
	var pick: Dictionary = tried[at]
	var scores := {}
	for each in tried:
		scores[int(each["seed"])] = snappedf(float(each["score"]), 0.001)
	pick["scores"] = scores
	DebugLog.say("Faces", "%s, %s: seed %d picked, score %.3f (of %s)" % [person, mood, int(pick["seed"]), float(pick["score"]), str(scores)])
	return pick


## redraw()'s answer when it's stopped early: only the moods it finished.
static func _only_done(out: Dictionary) -> Dictionary:
	var done := {}
	for mood in out:
		if not (out[mood] as Dictionary).is_empty():
			done[mood] = out[mood]
	return done


## Sends a picture up to ComfyUI's input folder (/upload/image, a form), for an edit workflow's
## Load Image: its name as ComfyUI has it ("ktbt/<file>"), or "" (why in last_error).
func _upload(picture: Image, file: String) -> String:
	counts["uploads"] = int(counts.get("uploads", 0)) + 1
	if not Hooks.fake_comfy.is_empty():
		await get_tree().process_frame
		if Hooks.fake_upload_refused:
			last_error = "ComfyUI refused the calm picture (the test's)"
			return ""
		DebugLog.say("Faces", "the calm picture sent up as ktbt/%s (the test's: nothing sent)" % file)
		return "ktbt/" + file
	var boundary := "ktbt%d" % Time.get_ticks_usec()
	var body := ("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n" % [boundary, file]).to_utf8_buffer()
	body.append_array(picture.save_png_to_buffer())
	body.append_array(("\r\n--%s\r\nContent-Disposition: form-data; name=\"subfolder\"\r\n\r\nktbt\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n" % [boundary, boundary, boundary]).to_utf8_buffer())
	var reply := await _request(URL + "/upload/image", HTTPClient.METHOD_POST, body, 30.0, "multipart/form-data; boundary=" + boundary)
	var answer = JSON.parse_string((reply[2] as PackedByteArray).get_string_from_utf8()) if reply[0] else null
	if not answer is Dictionary or str(answer.get("name", "")) == "":
		last_error = "ComfyUI refused the calm picture (HTTP %d)" % int(reply[1])
		return ""
	var named := str(answer["name"])
	var folder := str(answer.get("subfolder", ""))
	var reference := folder + "/" + named if folder != "" else named
	DebugLog.say("Faces", "the calm picture sent up to ComfyUI as %s (%d KB)" % [reference, roundi(body.size() / 1024.0)])
	return reference


func _fail_redraw(person: String, why: String) -> void:
	last_error = why
	counts["redraws_failed"] = int(counts.get("redraws_failed", 0)) + 1
	DebugLog.say("Faces", "%s's moods not made: %s (the calm face kept)" % [person, why])

## Asks ComfyUI for a picture (queued, not waited for): a ticket for _collect, {"id", "asked"}
## (or with Hooks.fake_comfy {"fake": k, "asked"}), or {"error": why}.
func _ask(base: Dictionary, prompt: String, pic_seed: int, k: int, prefix: String, reference: String = "") -> Dictionary:
	var asked := Time.get_ticks_msec()
	if not Hooks.fake_comfy.is_empty():
		if not base.is_empty():
			sent.append(workflow_for(base, prompt, pic_seed, WIDTH, HEIGHT, prefix, reference))
		order.append("ask %d" % pic_seed)
		return {"fake": k, "asked": asked}
	var workflow := workflow_for(base, prompt, pic_seed, WIDTH, HEIGHT, prefix, reference)
	if workflow.is_empty():
		return {"error": "the workflow has no prompt box" + (" or Load Image" if reference != "" else "")}
	var queued := await _request(URL + "/prompt", HTTPClient.METHOD_POST, JSON.stringify({"prompt": workflow, "client_id": "ktbt-game"}), 15.0)
	var answer = JSON.parse_string((queued[2] as PackedByteArray).get_string_from_utf8()) if queued[0] else null
	if not answer is Dictionary or str(answer.get("prompt_id", "")) == "":
		return {"error": "ComfyUI didn't take the picture (HTTP %d)" % int(queued[1])}
	return {"id": str(answer["prompt_id"]), "asked": asked}


## Waits for a picture _ask asked for and fetches it: the picture, or null (why in last_error).
## ComfyUI's own time making it (its history's start and finish) goes in the ticket ("ms") and
## the counts ("gpu_ms", and "first_ms" for the first since open(): the model loading).
func _collect(ticket: Dictionary) -> Image:
	if ticket.has("error"):
		last_error = str(ticket["error"])
		return null
	if ticket.has("fake"):
		await get_tree().process_frame
		var fake = Hooks.fake_comfy[int(ticket["fake"]) % Hooks.fake_comfy.size()]
		if fake is Image:
			return (fake as Image).duplicate() as Image
		last_error = "the test's picture wasn't one"
		return null
	var id := str(ticket.get("id", ""))
	var deadline := int(ticket.get("asked", Time.get_ticks_msec())) + PICTURE_SECONDS * 1000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(POLL_SECONDS).timeout
		if not is_inside_tree():
			return null
		var history := await _request(URL + "/history/" + id, HTTPClient.METHOD_GET, "", 5.0)
		var entries = JSON.parse_string((history[2] as PackedByteArray).get_string_from_utf8()) if history[0] else null
		if not entries is Dictionary or not entries.has(id):
			continue
		var ms := comfy_ms(entries[id])
		if ms >= 0:
			ticket["ms"] = ms
			counts["gpu_ms"] = int(counts.get("gpu_ms", 0)) + ms
			if not counts.has("first_ms"):
				counts["first_ms"] = ms
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


## How long a picture took to make, in seconds: ComfyUI's own time if it said, else from asking
## to fetching (which, now the next's asked for before a split, can include our split's wait).
static func _took(ticket: Dictionary) -> float:
	if ticket.has("ms"):
		return int(ticket["ms"]) / 1000.0
	return (Time.get_ticks_msec() - int(ticket.get("asked", Time.get_ticks_msec()))) / 1000.0


## ComfyUI's own time making a picture, in ms, from its /history entry's status messages
## (execution_start to execution_success, each with a timestamp in ms): -1 if it doesn't say.
static func comfy_ms(entry: Dictionary) -> int:
	var status = entry.get("status", {})
	if not status is Dictionary:
		return -1
	var start := -1.0
	var finish := -1.0
	for message in status.get("messages", []):
		if not message is Array or message.size() < 2 or not message[1] is Dictionary:
			continue
		var stamp := float(message[1].get("timestamp", -1))
		if str(message[0]) == "execution_start":
			start = stamp
		elif str(message[0]) == "execution_success":
			finish = stamp
	if start < 0 or finish < start:
		return -1
	return roundi(finish - start)


## The split on a worker thread, the game carrying on meanwhile. The test's pictures
## (Hooks.fake_comfy) are the same few over and over, so each one's split is kept the first time
## (Hooks.kept_splits, by the picture's pixels) and a copy handed back after, scored afresh for who
## it's for (the score's the only part that depends on them, and quick), marked "kept": about 2.5
## seconds a face saved, the split itself checked against the Python's by test_portrait_split.
## react: a mood's picture, split into its close-up (react_split: no score of its own, react_score
## is against the calm one's), checked by test_reaction_split.
func _split(picture: Image, person: String, react: bool = false) -> Dictionary:
	var key := ""
	if not Hooks.fake_comfy.is_empty():
		order.append("split")
		key = "%s%dx%d|%d" % ["react|" if react else "", picture.get_width(), picture.get_height(), hash(picture.get_data())]
		if Hooks.kept_splits.has(key):
			await get_tree().process_frame
			var kept := copy_split(Hooks.kept_splits[key])
			if not react:
				kept["score"] = PortraitSplit.score(kept["part"], person)
			kept["kept"] = true
			kept["ms"] = 0
			return kept
	var out := {}
	var task := WorkerThreadPool.add_task(func(): out.merge(PortraitSplit.react_split(picture) if react else PortraitSplit.split(picture, person)))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	counts["split_ms"] = int(counts.get("split_ms", 0)) + int(out.get("ms", 0))  # (for the stats: how long the splits took, not the kept ones)
	if key != "":
		Hooks.kept_splits[key] = copy_split(out)
	return out


## A split nothing else shares: its layer and its parts copied, so changing one leaves the other.
static func copy_split(split: Dictionary) -> Dictionary:
	var copy := {}
	for k in split:
		var value = split[k]
		copy[k] = value.duplicate() if value is Image or typeof(value) >= TYPE_DICTIONARY else value
	return copy


func _answers() -> bool:
	var reply := await _request(URL + "/system_stats", HTTPClient.METHOD_GET, "", 3.0)
	return reply[0]


## [ok (HTTP 200), the HTTP code, the body]. body: text (JSON), or bytes sent as they are with
## content_type (the upload's form).
func _request(url: String, method: HTTPClient.Method, body: Variant, seconds: float, content_type: String = "application/json") -> Array:
	var http := HTTPRequest.new()
	http.timeout = seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: " + content_type]) if method == HTTPClient.METHOD_POST else PackedStringArray()
	var asked: Error = http.request_raw(url, headers, method, body) if body is PackedByteArray else http.request(url, headers, method, str(body))
	if asked != OK:
		http.queue_free()
		return [false, 0, PackedByteArray()]
	var result: Array = await http.request_completed
	http.queue_free()
	return [result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, result[1], result[3]]


func _fail(why: String) -> String:
	last_error = why
	DebugLog.say("Faces", "no ComfyUI: %s" % why)
	return why
