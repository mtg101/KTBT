extends Node
## Talks to a local Ollama server over HTTP.
##
## Usage: add it as a child, then call chat(messages). Either connect to
## chat_completed / chat_failed, or `await finished` to get [ok, text].
## Only one request at a time.

signal chat_completed(content: String)
signal chat_failed(error: String)
## Emitted after every request, success or not: ok is true on success, and text
## is either the AI's reply or the error message.
signal finished(ok: bool, text: String)

## 127.0.0.1 rather than "localhost": on Windows, localhost can resolve to the
## IPv6 address first, and Ollama only listens on IPv4 by default.
@export var base_url: String = "http://127.0.0.1:11434"
@export var model: String = "llama3.1:8b"
## How long Ollama keeps the model loaded in GPU memory after a request.
## Long enough that the slow first-load only happens once per session.
@export var keep_alive: String = "30m"
@export var timeout_seconds: float = 120.0

var busy := false
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = timeout_seconds
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Sends a chat to Ollama. messages is an Array of {"role": ..., "content": ...}.
## json_format asks Ollama to force the reply to be valid JSON.
## options are passed straight through (e.g. {"temperature": 0.9}).
func chat(messages: Array, json_format: bool = false, options: Dictionary = {}) -> void:
	if busy:
		# Deferred so anyone awaiting `finished` right after this call still hears it.
		_done.call_deferred(false, "Still waiting for the previous reply.")
		return
	var body := {
		"model": model,
		"messages": messages,
		"stream": false,
		"keep_alive": keep_alive,
	}
	if json_format:
		body["format"] = "json"
	if not options.is_empty():
		body["options"] = options
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(base_url + "/api/chat", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_done.call_deferred(false, "Couldn't start the request (Godot error %d)." % err)
		return
	busy = true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_done(false, _describe_result(result))
		return
	var text := body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	if response_code != 200:
		var detail := text
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			detail = str(data["error"])
		_done(false, "Ollama said no (HTTP %d): %s" % [response_code, detail])
		return
	if typeof(data) != TYPE_DICTIONARY or not data.has("message"):
		_done(false, "Ollama sent back something unexpected.")
		return
	_done(true, str(data["message"].get("content", "")))


func _done(ok: bool, text: String) -> void:
	if ok:
		chat_completed.emit(text)
	else:
		chat_failed.emit(text)
	finished.emit(ok, text)


func _describe_result(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_CANT_RESOLVE:
			return "Can't reach Ollama at %s. Is it running? (Look for the llama icon in the system tray.)" % base_url
		HTTPRequest.RESULT_TIMEOUT:
			return "Ollama took longer than %d seconds to reply, so we gave up." % int(timeout_seconds)
		_:
			return "The request to Ollama failed (HTTPRequest result %d)." % result
