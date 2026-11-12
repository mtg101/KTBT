extends Control
## Stage 1: pipeline test.
## Press the button and the local LLM (via Ollama) invents a pojangmacha customer.
## The game picks the day, time and weather and checks the reply;
## the AI only invents the person.

const OllamaClient = preload("res://scripts/ollama_client.gd")
const Prompts = preload("res://scripts/prompts.gd")

const MAX_ATTEMPTS := 3
const MIN_AGE := 19  # Korea's legal drinking age: the game enforces it, not the AI.

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const TIMES := ["6:30pm", "7:45pm", "9:00pm", "10:20pm", "11:40pm", "12:50am", "1:40am", "2:30am", "3:15am", "4:05am"]
const WEATHER := [
	"light drizzle",
	"heavy rain drumming on the tarp",
	"clear, bitterly cold air",
	"the first snow of winter",
	"a muggy summer heat",
	"thick fog",
	"a warm spring breeze",
]
const FIELDS := ["name", "age", "job", "mood", "reason", "speech_style", "appearance", "opening_line"]

const ACCENT := Color("e8833a")
const MUTED := Color("a9a6c2")

var _client: OllamaClient
var _button: Button
var _context_label: Label
var _status_label: Label
var _profile: RichTextLabel
var _raw_text: RichTextLabel

var _scene := {}
var _attempt := 0
var _started_ms := 0
var _waiting := false
var _last_problem := ""


func _ready() -> void:
	_client = OllamaClient.new()
	add_child(_client)
	_client.chat_completed.connect(_on_chat_completed)
	_client.chat_failed.connect(_on_chat_failed)
	_build_ui()
	_status_label.text = "Ready. Make sure Ollama is running, then press the button."


func _process(_delta: float) -> void:
	if _waiting:
		var text := "The AI is thinking... %.1fs" % _elapsed()
		if _attempt > 1:
			text += "  (attempt %d of %d: last reply was rejected because %s)" % [_attempt, MAX_ATTEMPTS, _last_problem]
		_status_label.text = text


func _on_invent_pressed() -> void:
	_scene = {
		"day": DAYS.pick_random(),
		"time": TIMES.pick_random(),
		"weather": WEATHER.pick_random(),
	}
	_context_label.text = "%s, %s, %s" % [_scene["day"], _scene["time"], _scene["weather"]]
	_profile.text = ""
	_raw_text.text = ""
	_attempt = 0
	_request_customer()


func _request_customer() -> void:
	_attempt += 1
	_button.disabled = true
	_waiting = true
	_started_ms = Time.get_ticks_msec()
	var messages := Prompts.customer_messages(_scene["day"], _scene["time"], _scene["weather"])
	_client.chat(messages, true, {"temperature": 0.9})


func _on_chat_completed(content: String) -> void:
	_waiting = false
	var seconds := _elapsed()
	_raw_text.text = content
	var data = JSON.parse_string(content)
	var problem := _validate_customer(data)
	if problem != "":
		_last_problem = problem
		if _attempt < MAX_ATTEMPTS:
			_request_customer()
		else:
			_finish("Gave up after %d attempts. Last problem: %s." % [MAX_ATTEMPTS, problem])
		return
	_show_customer(data)
	var note := "Customer invented in %.1fs" % seconds
	if _attempt > 1:
		note += " on attempt %d (earlier replies were rejected)" % _attempt
	_finish(note + ".")


func _on_chat_failed(error: String) -> void:
	_waiting = false
	_finish("Problem: " + error)


func _finish(message: String) -> void:
	_status_label.text = message
	_button.disabled = false


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _started_ms) / 1000.0


## The game owns the facts: check the AI's reply before using it.
## Returns "" if it's fine, otherwise a short description of the problem.
func _validate_customer(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	for field in FIELDS:
		if not data.has(field):
			return "it left out '%s'" % field
		if field != "age" and str(data[field]).strip_edges() == "":
			return "'%s' was empty" % field
	var age = data["age"]
	if typeof(age) == TYPE_STRING and age.is_valid_int():
		age = age.to_int()
	if typeof(age) != TYPE_INT and typeof(age) != TYPE_FLOAT:
		return "the age wasn't a number"
	if int(age) < MIN_AGE:
		return "they were %d, too young to drink in Korea" % int(age)
	data["age"] = int(age)
	return ""


func _show_customer(data: Dictionary) -> void:
	var t := "[font_size=34][b]%s[/b][/font_size]   [color=#%s]%s, %s[/color]\n\n" % [
		_esc(data["name"]), MUTED.to_html(false), str(data["age"]), _esc(data["job"])]
	t += _row("Mood", data["mood"])
	t += _row("Why tonight", data["reason"])
	t += _row("How they talk", data["speech_style"])
	t += _row("Looks like", data["appearance"])
	t += "\n[i][color=#ffd27f]\"%s\"[/color][/i]" % _esc(data["opening_line"])
	_profile.text = t


func _row(label: String, value: Variant) -> String:
	return "[color=#%s][b]%s:[/b][/color]  %s\n" % [ACCENT.to_html(false), label, _esc(value)]


## Stop anything the AI writes from being read as BBCode formatting.
func _esc(value: Variant) -> String:
	return str(value).replace("[", "[lb]")


func _on_raw_toggled(on: bool) -> void:
	_raw_text.visible = on


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = "KTBT  ·  Stage 1: pipeline test"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", ACCENT)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)

	_button = Button.new()
	_button.text = "Invent a customer"
	_button.custom_minimum_size = Vector2(240, 48)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(_on_invent_pressed)
	row.add_child(_button)

	_context_label = Label.new()
	_context_label.text = "Tonight: press the button"
	_context_label.add_theme_font_size_override("font_size", 20)
	_context_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_context_label)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status_label)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color("26243d")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	col.add_child(panel)

	_profile = RichTextLabel.new()
	_profile.bbcode_enabled = true
	_profile.selection_enabled = true
	_profile.add_theme_font_size_override("normal_font_size", 20)
	_profile.add_theme_font_size_override("bold_font_size", 20)
	_profile.add_theme_font_size_override("italics_font_size", 22)
	panel.add_child(_profile)

	var raw_toggle := CheckBox.new()
	raw_toggle.text = "Show the AI's raw JSON reply"
	raw_toggle.toggled.connect(_on_raw_toggled)
	col.add_child(raw_toggle)

	_raw_text = RichTextLabel.new()
	_raw_text.bbcode_enabled = false
	_raw_text.selection_enabled = true
	_raw_text.custom_minimum_size = Vector2(0, 150)
	_raw_text.add_theme_color_override("default_color", MUTED)
	_raw_text.visible = false
	col.add_child(_raw_text)
