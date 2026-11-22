extends Node
## The running game: which bar is open, and keeping it saved. Loaded at startup as the
## "Game" autoload (Project Settings → Globals), so every scene can reach it.
##
## Saving is automatic: the visit scene saves after creating a bar and after every visit,
## and this saves again when the window closes or you go back to the title screen, so
## there's never a "your progress will be lost" prompt. A visit that's still going when
## you quit simply ends; the bar carries on with the next customer.

const SaveStore = preload("res://scripts/save/save_store.gd")
const DebugLog = preload("res://scripts/debug_log.gd")
const Autoplay = preload("res://scripts/autoplay.gd")
const Ai = preload("res://scripts/ai/ai.gd")

const TITLE_SCENE := "res://scenes/title.tscn"
const VISIT_SCENE := "res://scenes/visit.tscn"

## The open bar (see save_store.gd for what's in it). Empty means "a new bar, not invented yet":
## the visit scene invents its owner and name, then sets this and saves.
var bar := {}

## Test hooks. Tests can't let the game switch scenes (it would replace the test runner),
## so with change_scenes off, the scene the game asked for is just recorded.
var change_scenes := true
var requested_scene := ""

## The music, which carries on from scene to scene (see music.gd).
var music: Music = null

## A batch of nights playing themselves (`-- --autoplay=10`: see autoplay.gd), or null.
var autoplay: Autoplay = null

## The title screen's warm-up of the AI's model (warm_up_ai), for the next night's stats (the
## bar takes it when its loading screen's done, and clears it): {"ok", "seconds", "why"}, with
## "going": true while it's still loading. {} if there's been none since.
var warmed := {}
var _warming: Ai = null


func _ready() -> void:
	DebugLog.from_args(OS.get_cmdline_user_args())  # (-- --log-all: every note on the console too)
	autoplay = Autoplay.from_args(OS.get_cmdline_user_args())
	if autoplay != null:
		OS.add_logger(autoplay.errors)  # (the batch counts the errors, for its summary)
		AudioServer.set_bus_mute(0, true)  # (nobody's listening)
		DebugLog.say("Autoplay", "%d nights." % autoplay.nights)
		autoplay.write_running()  # (so the phone helper can see it's going)


## The crew run it (the menu: autoplay started in the game) for so many nights, on the open bar.
## Not on the phone helper's list (no running file: its Stop ends the game's process, and this
## is someone's game, not a test batch). Null if a batch is going already.
func start_autoplay(how_many: int) -> Autoplay:
	if autoplay != null or bar.is_empty():
		return null
	autoplay = Autoplay.in_game(how_many, str(bar.get("id", "")))
	OS.add_logger(autoplay.errors)
	DebugLog.say("Autoplay", "%d nights, the crew running it (from the menu)." % autoplay.nights)
	return autoplay


## The batch is over and the bar's the player's again (started in the game, or stopped by hand).
func end_autoplay() -> void:
	if autoplay == null:
		return
	OS.remove_logger(autoplay.errors)
	if autoplay.from_command_line:
		Autoplay.clear_running()
		AudioServer.set_bus_mute(0, false)  # (someone's here now)
	autoplay = null


## Warms the AI's model up as the title screen opens, so the bar's first reply doesn't wait up to
## a minute for Ollama to load it (it unloads after 30 idle minutes). Here rather than on the
## title, so it carries on when the title gives way to the bar. Not if the AI's offline, or a
## warm-up's going already. Noted, and counted in the next night's stats ("Opening:").
func warm_up_ai() -> void:
	if _warming != null:
		return
	_warming = Ai.new()
	_warming.name = "WarmUp"
	add_child(_warming)
	var started := Time.get_ticks_msec()
	warmed = {"going": true, "ok": false, "seconds": 0.0, "why": ""}
	var done: Dictionary = await _warming.warm_up()
	var why_offline := _warming.offline_reason
	_warming.queue_free()
	_warming = null
	if done.is_empty():
		warmed = {}
		DebugLog.say("AI", "not warming the model up at the title: offline (%s)" % (why_offline if why_offline != "" else "no Ollama"))
		return
	warmed = done
	if bool(done["ok"]):
		DebugLog.say("AI", "warmed the model up at the title: loaded in %.1fs" % float(done["seconds"]))
	else:
		DebugLog.say("AI", "warming the model up at the title failed after %.1fs: %s" % [(Time.get_ticks_msec() - started) / 1000.0, done["why"]])


## Starts the music if it isn't going yet (the title screen and the bar both ask).
func start_music() -> Music:
	if music == null:
		music = Music.new()
		music.name = "Music"
		add_child(music)
	return music


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


## Save and quit the game (autoplay, at the end of its batch). Tests only record it.
func quit() -> void:
	save()
	if autoplay != null:
		Autoplay.clear_running()
	requested_scene = "quit"
	if change_scenes:
		get_tree().quit()


func _go(scene_path: String) -> void:
	requested_scene = scene_path
	if change_scenes:
		get_tree().change_scene_to_file(scene_path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		if autoplay != null:
			Autoplay.clear_running()  # (the batch closed by hand: not running any more)
