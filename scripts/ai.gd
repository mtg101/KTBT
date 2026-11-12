extends Node
## Asks the local LLM for a JSON reply, checks it, and retries with feedback if it's wrong.
##
## The game owns the facts: nothing the AI says is used until a validator approves it.
## A validator is a Callable that takes the parsed reply and returns "" if it's usable,
## or a short description of the problem (which is fed back to the AI on the retry).
## Validators may tidy the data in place (trim text, fix types).

const OllamaClient = preload("res://scripts/ollama_client.gd")

@export var max_attempts := 3

## Why the last ask_json() call failed, in plain words.
var last_error := ""
var _client: OllamaClient


func _ready() -> void:
	_client = OllamaClient.new()
	add_child(_client)


## Use with await. Returns the approved Dictionary, or {} if it couldn't get a usable
## reply (see last_error).
func ask_json(messages: Array, validator: Callable, options: Dictionary = {}) -> Dictionary:
	last_error = ""
	var convo := messages.duplicate()
	for attempt in max_attempts:
		_client.chat(convo, true, options)
		var reply: Array = await _client.finished
		if not reply[0]:
			# A connection problem: retrying straight away won't help.
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
