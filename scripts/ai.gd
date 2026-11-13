extends Node
## Asks the AI for a JSON reply, checks it, and retries with feedback if it's wrong.
##
## The game owns the facts: nothing the AI says is used until a validator approves it.
## A validator is a Callable that takes the parsed reply and returns "" if it's usable,
## or a short description of the problem (which is fed back to the AI on the retry).
## Validators may tidy the data in place (trim text, fix types).
##
## Two backends, chosen by scripts/ai_settings.gd: the local LLM via Ollama, or the canned
## AI (offline mode). In "auto" mode it uses Ollama, and switches to canned for the rest of
## the session if Ollama fails, emitting offline_started so the game can say so.

signal offline_started(reason: String)

const OllamaClient = preload("res://scripts/ollama_client.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")

@export var max_attempts := 3
## In "auto" mode, how long to wait for Ollama to answer "are you there?" before going offline.
const SERVER_CHECK_SECONDS := 3.0

## Test hook: behave as if Ollama can't be reached, instantly. Leave alone otherwise.
static var simulate_unreachable := false

## Why the last ask_json() call failed, in plain words.
var last_error := ""
## True when replies come from the canned AI rather than the LLM.
var offline := false
## Why we're offline: chosen in the settings, or why Ollama failed.
var offline_reason := ""
var settings := {}

var _client: OllamaClient
var _canned := CannedAi.new()
var _auto_fallback := false
var _checking_server := false

signal _server_checked


func _ready() -> void:
	settings = AiSettings.load_settings()
	_client = OllamaClient.new()
	_client.base_url = str(settings["server"])
	_client.model = str(settings["model"])
	add_child(_client)
	_auto_fallback = settings["backend"] == "auto"
	if settings["backend"] == "canned":
		offline = true
		offline_reason = "chosen in the AI settings"
	elif _auto_fallback:
		_check_server()


## Use with await. request says what's being asked, for the canned AI: {"purpose": ...,
## plus context}; the LLM ignores it and reads the messages instead. Returns the approved
## Dictionary, or {} if it couldn't get a usable reply (see last_error).
func ask_json(messages: Array, validator: Callable, options: Dictionary = {}, request: Dictionary = {}) -> Dictionary:
	if _checking_server:
		await _server_checked
	if offline:
		return await _ask_canned(validator, request)
	last_error = ""
	var convo := messages.duplicate()
	for attempt in max_attempts:
		var reply: Array
		if simulate_unreachable:
			await get_tree().process_frame
			reply = [false, "Can't reach Ollama (simulated for a test)."]
		else:
			_client.chat(convo, true, options)
			reply = await _client.finished
		if not reply[0]:
			# Ollama didn't answer at all: retrying straight away won't help.
			if _auto_fallback:
				_go_offline(str(reply[1]))
				return await _ask_canned(validator, request)
			last_error = str(reply[1])
			return {}
		var content := str(reply[1])
		var data = JSON.parse_string(content)
		var problem: String = validator.call(data)
		if problem == "":
			return data
		last_error = "the AI's reply was rejected %d times (last time because %s)" % [attempt + 1, problem]
		convo = messages.duplicate()
		convo.append({"role": "assistant", "content": content})
		convo.append({"role": "user", "content": "That reply can't be used because %s. Try again, replying with only the JSON object." % problem})
	return {}


func _ask_canned(validator: Callable, request: Dictionary) -> Dictionary:
	last_error = ""
	for attempt in max_attempts:
		# A frame's pause, so the game behaves the same as with a real (slower) AI.
		await get_tree().process_frame
		var data = _canned.reply(request)
		var problem: String = validator.call(data)
		if problem == "":
			return data
		last_error = "the canned reply was rejected %d times (last time because %s)" % [attempt + 1, problem]
	return {}


## Auto mode: ask Ollama "are you there?" with a short time limit, and go offline straight
## away if it doesn't answer, rather than waiting for a full request to time out (which can
## take minutes when nothing's listening). Requests wait for this check to finish.
func _check_server() -> void:
	_checking_server = true
	# Wait a frame so the game has connected to offline_started before we might emit it.
	await get_tree().process_frame
	var reachable := false
	if not simulate_unreachable:
		var http := HTTPRequest.new()
		http.timeout = SERVER_CHECK_SECONDS
		add_child(http)
		if http.request(str(settings["server"]) + "/api/tags") == OK:
			var result: Array = await http.request_completed
			reachable = result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200
		http.queue_free()
	_checking_server = false
	if not reachable:
		_go_offline("couldn't reach Ollama at %s" % settings["server"])
	_server_checked.emit()


func _go_offline(reason: String) -> void:
	offline = true
	offline_reason = reason
	offline_started.emit(reason)
