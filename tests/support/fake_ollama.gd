extends "res://scripts/ai/ollama_client.gd"
## A stand-in for Ollama, for testing ai.gd's checking and retrying: it answers each chat()
## with the next scripted reply ([ok, text]) instead of going over HTTP, and keeps every
## conversation it was sent.

var replies: Array = []  # [ok, text], used in order
var asked: Array = []  # each chat()'s messages, as sent
var warmed := 0  # how many times warm_up() was asked (it takes the next reply too)


func _ready() -> void:
	pass  # (no HTTPRequest: nothing goes over the network)


func chat(messages: Array, _json_format: bool = false, _options: Dictionary = {}) -> void:
	asked.append(messages.duplicate(true))
	var reply: Array = replies.pop_front() if not replies.is_empty() else [false, "the fake ran out of replies"]
	_done.call_deferred(bool(reply[0]), str(reply[1]))


func warm_up() -> void:
	warmed += 1
	var reply: Array = replies.pop_front() if not replies.is_empty() else [false, "the fake ran out of replies"]
	_done.call_deferred(bool(reply[0]), "" if bool(reply[0]) else str(reply[1]))
