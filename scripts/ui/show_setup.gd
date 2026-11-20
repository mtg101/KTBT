extends Control
## Setting up the show: while a new bar's being made, the PD can step in (from the loading
## screen, or Enter) and set the show up before its first episode. Full screen, the game's
## defaults picked, so the PD only changes what they want. For now, where the show starts on
## the ladder (rules/ladder.gd: a new bar's starts on the phone stream; starting higher skips
## the climb, mostly for trying the rungs out); more of the show's setup goes here later.
## Nothing's running while it's open, and the bar waits for it. "Start the show" (Enter) or Esc
## closes it with what's picked.

const Ladder = preload("res://scripts/rules/ladder.gd")
const Text = preload("res://scripts/rules/text.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

## What's chosen: {"rung"}.
signal finished(choices: Dictionary)

const RED := Color("ff4f6d")  # the camera's red: the PD's
const WIDTH := 1100.0
const HEADING_HANGUL := "방송 준비"

var _rung_picks: Array = []  # CheckBoxes, one a rung, lowest first
var _done := false


func _init() -> void:
	name = "ShowSetup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # it's open: nothing behind it gets clicked
	z_index = 40


## Opens it with what's chosen so far (the game's defaults to start with).
func open(start_with: Dictionary = {}) -> void:
	var dim := ColorRect.new()
	dim.color = Color(Ktv.BACKGROUND, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2((1920.0 - WIDTH) / 2.0, 70)
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var heading := Ktv.label("%s · SETTING UP THE SHOW" % HEADING_HANGUL, 40, Ktv.CREAM, 8)
	heading.name = "SetupHeading"
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.tooltip_text = Text.tip(Glossary.hangul_tip(HEADING_HANGUL))
	box.add_child(heading)
	box.add_child(_note("You're the PD, setting up the show before its first episode. The game's picks are ticked: change what you like. Nothing's running while you're in here."))
	box.add_child(_heading("WHERE THE SHOW STARTS"))
	box.add_child(_note("A new show starts as a phone stream and climbs the ladder season by season. Starting higher skips the climb."))
	var chosen := str(start_with.get("rung", Ladder.FIRST))
	for rung in Ladder.RUNGS:
		var pick := CheckBox.new()
		pick.name = "Rung_%s" % rung["id"]
		var title := str(rung["short"])
		pick.text = "%s   %s %s" % [title.left(1).to_upper() + title.substr(1), rung["word"], rung["english"]]  # ("Network TV", not capitalize()'s "Network Tv")
		pick.focus_mode = Control.FOCUS_NONE
		pick.add_theme_font_size_override("font_size", 22)
		pick.add_theme_color_override("checkbox_unchecked_color", Ktv.MUTED)  # (the empty circle, visible on the dark)
		pick.add_theme_color_override("checkbox_checked_color", RED)
		pick.button_group = ButtonGroup.new() if _rung_picks.is_empty() else (_rung_picks[0] as CheckBox).button_group
		Ktv.light_radios(pick)  # (Godot's own empty ones vanish on the dark)
		pick.tooltip_text = Text.tip("%s: %s\n%s" % [rung["word"], Glossary.hangul_tip(str(rung["word"])), rung["about"]])
		pick.button_pressed = str(rung["id"]) == chosen
		_rung_picks.append(pick)
		box.add_child(pick)
		var about := _note(Ladder.describe(str(rung["id"])))
		about.name = "About_%s" % rung["id"]
		about.add_theme_font_size_override("font_size", 17)
		about.custom_minimum_size = Vector2(WIDTH - 40, 0)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 40)
		indent.add_child(about)
		box.add_child(indent)
	var start := Button.new()
	start.name = "SetupDone"
	start.text = "Start the show (Enter)"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(320, 52)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(done)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(start)
	box.add_child(row)


## Picks a rung (as clicking it does).
func pick_rung(id: String) -> void:
	for pick in _rung_picks:
		if str((pick as CheckBox).name) == "Rung_%s" % id:
			(pick as CheckBox).button_pressed = true


## What's picked now: {"rung"}.
func choices() -> Dictionary:
	for k in _rung_picks.size():
		if (_rung_picks[k] as CheckBox).button_pressed:
			return {"rung": str(Ladder.RUNGS[k]["id"])}
	return {"rung": Ladder.FIRST}


## "Start the show": closes it with what's picked.
func done() -> void:
	if _done:
		return
	_done = true
	finished.emit(choices())
	queue_free()


func _heading(text: String) -> Label:
	return Ktv.label(text, 24, Ktv.ORANGE)


func _note(text: String) -> Label:
	var label := Ktv.label(text, 19, Ktv.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	return label


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_ESCAPE:
		done()
		get_viewport().set_input_as_handled()
