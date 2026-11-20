extends Node
## "Let the crew run it": autoplay in the game (see autoplay.gd). The top bar's badge while the
## crew are running it (which night of how many; a click to stop), the menu's row to start it
## (for how many nights) or stop it, and the question Stop asks: finish tonight and hand the bar
## back, or hand it over there and then. visit.gd does what's asked (start_asked, stop_chosen)
## and says how things are (show_state); this only draws and asks.

const Text = preload("res://scripts/rules/text.gd")
const Autoplay = preload("res://scripts/autoplay.gd")

signal start_asked(nights: int)
signal stop_chosen(how: String)  # "after_tonight" or "now"

const STOP_AFTER := "after_tonight"
const STOP_NOW := "now"
const ABOUT := "The crew run the show for you: the owner as ever, and the PD's desk (cards, the camera, pins, the edit), stepping in to cut the episode, and opening the next night, for as many nights as you say. Watch as long as you like: the transcript, the side panel and the hovers all work; what would change the run (closing the bar, the desk, opening the next night, reading pauses) waits until you stop them."

var badge: Button  # the top bar's, while they're running it
var row: HBoxContainer  # the menu's
var label: Label
var nights_box: SpinBox
var start_button: Button
var stop_button: Button
var dialog: AcceptDialog
var _last := false  # stopping after tonight


## The badge (into the top bar, after its first item) and the menu's row (into the menu's column,
## after its first row).
func build(top_bar: Control, menu_column: Control, badge_style: StyleBox) -> void:
	badge = Button.new()
	badge.name = "CrewBadge"
	badge.flat = false
	badge.focus_mode = Control.FOCUS_NONE
	badge.add_theme_color_override("font_color", Color.BLACK)
	badge.add_theme_color_override("font_hover_color", Color.BLACK)
	for state in ["normal", "hover", "pressed"]:
		badge.add_theme_stylebox_override(state, badge_style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.visible = false
	badge.pressed.connect(ask_stop)
	top_bar.add_child(badge)
	top_bar.move_child(badge, mini(1, top_bar.get_child_count() - 1))

	row = HBoxContainer.new()
	row.name = "CrewRow"
	row.add_theme_constant_override("separation", 12)
	menu_column.add_child(row)
	menu_column.move_child(row, mini(1, menu_column.get_child_count() - 1))
	label = Label.new()
	label.name = "CrewLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = Text.tip(ABOUT)
	row.add_child(label)
	nights_box = SpinBox.new()
	nights_box.name = "CrewNights"
	nights_box.min_value = 1
	nights_box.max_value = Autoplay.MOST_NIGHTS
	nights_box.value = Autoplay.MENU_NIGHTS
	nights_box.suffix = "nights"
	nights_box.custom_minimum_size = Vector2(140, 0)
	nights_box.tooltip_text = Text.tip("How many nights the crew run it for (tonight, if it's open, is the first).")
	row.add_child(nights_box)
	start_button = Button.new()
	start_button.name = "CrewStart"
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(100, 40)
	start_button.pressed.connect(func(): start_asked.emit(int(nights_box.value)))
	row.add_child(start_button)
	stop_button = Button.new()
	stop_button.name = "CrewStop"
	stop_button.text = "Stop…"
	stop_button.custom_minimum_size = Vector2(100, 40)
	stop_button.tooltip_text = Text.tip("Stop the crew: after tonight, or now, taking over tonight yourself.")
	stop_button.pressed.connect(ask_stop)
	row.add_child(stop_button)

	dialog = AcceptDialog.new()
	dialog.name = "CrewStopDialog"
	dialog.title = "Stop the crew?"
	dialog.dialog_text = "The crew are running it. Stop them after tonight (the night's played out and written up, then the bar's yours), or now (tonight's yours from here)?"
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(560, 0)
	dialog.ok_button_text = "Keep going"
	dialog.add_button("Stop after tonight", false, STOP_AFTER)
	dialog.add_button("Stop now: I'll take over", false, STOP_NOW)
	dialog.custom_action.connect(choose)
	add_child(dialog)


## How things are: running (and which night: "night 3 of 10"; last: it stops after tonight);
## otherwise whether it can be started now, and if not, why.
func show_state(running: bool, progress: String, last: bool, can_start: bool, why_not: String = "") -> void:
	_last = last
	badge.visible = running
	badge.text = "▶ %s · %s" % ["CREW RUNNING" if not last else "CREW'S LAST NIGHT", progress.to_upper()]
	badge.tooltip_text = Text.tip(ABOUT + "\n\n" + ("They stop after tonight." if last else "Click to stop them."))
	label.text = ("▶ The crew are running it: %s%s" % [progress, " (stopping after tonight)" if last else ""]) if running else "▶ Let the crew run it"
	nights_box.visible = not running
	start_button.visible = not running
	start_button.disabled = not can_start
	start_button.tooltip_text = Text.tip("The crew take over for %d nights." % int(nights_box.value) if can_start else why_not)
	stop_button.visible = running


## Stop asks first (the badge, the menu's Stop…, or closing the bar while they're running it).
func ask_stop() -> void:
	if badge.visible and dialog != null:
		dialog.popup_centered()


## A choice in the stop question (STOP_AFTER or STOP_NOW; anything else: keep going).
func choose(how: StringName) -> void:
	if dialog != null:
		dialog.hide()
	if str(how) in [STOP_AFTER, STOP_NOW]:
		stop_chosen.emit(str(how))
