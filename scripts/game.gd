extends Node
## The running game: which bar is open, and keeping it saved. Loaded at startup as the
## "Game" autoload (Project Settings → Globals), so every scene can reach it.
##
## Saving is automatic: the visit scene saves after creating a bar and after every visit,
## and this saves again when the window closes or you go back to the title screen, so
## there's never a "your progress will be lost" prompt. A visit that's still going when
## you quit simply ends; the bar carries on with the next customer.

const SaveStore = preload("res://scripts/save_store.gd")

const TITLE_SCENE := "res://scenes/title.tscn"
const VISIT_SCENE := "res://scenes/visit.tscn"

## The open bar (see save_store.gd for what's in it). Empty means "a new bar, not invented yet":
## the visit scene invents its owner and name, then sets this and saves.
var bar := {}

## Test hooks. Tests can't let the game switch scenes (it would replace the test runner),
## so with change_scenes off, the scene the game asked for is just recorded.
var change_scenes := true
var requested_scene := ""


## Start a brand new bar.
func new_bar() -> void:
	bar = {}
	_go(VISIT_SCENE)


## Open a saved bar. Returns false if it couldn't be loaded.
func open_bar(id: String) -> bool:
	var loaded := SaveStore.load_bar(id)
	if loaded.is_empty():
		return false
	bar = loaded
	_go(VISIT_SCENE)
	return true


## Save the open bar, if there is one.
func save() -> void:
	if not bar.is_empty():
		var result := SaveStore.save_bar(bar)
		if result != OK:
			push_error("Couldn't save the bar (error %d)." % result)


## Save, close the bar and go back to the title screen.
func back_to_title() -> void:
	save()
	bar = {}
	_go(TITLE_SCENE)


func _go(scene_path: String) -> void:
	requested_scene = scene_path
	if change_scenes:
		get_tree().change_scene_to_file(scene_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
