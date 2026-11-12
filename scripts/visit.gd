extends Control
## Stage 2: one visit.
##
## When the scene starts, the AI invents the tent's owner. Press "Next customer" and
## one customer arrives, orders from the menu, is served, chats with the owner,
## pays and leaves. Grey boxes for now; real art comes in a later stage.
##
## The game owns the facts (time, menu, prices, the bill, how a visit runs);
## the AI owns the flavour (who the people are and what they say).

const Ai = preload("res://scripts/ai.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")

const MIN_DRINKING_AGE := 19  # Korea's legal drinking age: enforced by the game, not the AI.
const MAX_ORDER_ITEMS := 4
const OWNER_FIELDS := ["name", "title", "age", "archetype", "appearance", "personality", "speech_style", "secret"]
## Korean terms of address that only fit one gender. The game picks the owner's gender,
## then rejects an owner whose title or archetype uses a word for the other one.
const GENDERED_TERMS := {
	"woman": ["ajumma", "ajumeoni", "ajummoni", "imo", "halmeoni", "halmoni", "eomeoni", "eomma", "nuna", "noona", "eonni", "unni"],
	"man": ["ajusshi", "ajeossi", "ajussi", "ajeoshi", "ajeosshi", "samchon", "harabeoji", "abeoji", "appa", "hyung", "hyeong", "oppa"],
}
const CUSTOMER_FIELDS := ["name", "age", "job", "mood", "reason", "speech_style", "appearance"]

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

const ACCENT := Color("e8833a")
const MUTED := Color("a9a6c2")
const OWNER_COLOR := Color("8f8aa8")
const OWNER_TEXT := Color("ffd27f")
const CUSTOMER_COLORS := [Color("6fa8c7"), Color("8fc79a"), Color("c78fb5"), Color("c7b06f"), Color("9a8fc7"), Color("c7836f")]

# Where things stand in the scene (pixels, inside the stage area).
const CUSTOMER_SEAT_X := 785.0
const CUSTOMER_Y := 190.0
const OFFSCREEN_X := 1320.0

var _ai: Ai
var _owner := {}
var _customer := {}
var _order: Array = []
var _moment := {}
var _transcript: Array = []
var _takings := 0
var _busy := false
var _customer_color := Color.WHITE

# UI
var _button: Button
var _fast_toggle: CheckBox
var _moment_label: Label
var _takings_label: Label
var _log: RichTextLabel
var _typing_label: Label
var _info: RichTextLabel

# Scene pieces
var _owner_node: Control
var _owner_tag: Label
var _customer_node: Control
var _customer_body: ColorRect
var _customer_head: ColorRect
var _customer_tag: Label
var _items_row: HBoxContainer


func _ready() -> void:
	_ai = Ai.new()
	add_child(_ai)
	_build_ui()
	_invent_owner()


func _on_button_pressed() -> void:
	if _busy:
		return
	if _owner.is_empty():
		_invent_owner()
	else:
		_run_visit()


# --- The owner -------------------------------------------------------------

func _invent_owner() -> void:
	_busy = true
	_button.disabled = true
	_narrate("Somewhere under a Seoul overpass, someone is unrolling an orange tarp...")
	_typing_label.text = "The AI is inventing the tent's owner..."
	var gender: String = ["woman", "man"].pick_random()
	var result: Dictionary = await _ai.ask_json(Prompts.owner_messages(gender), _validate_owner.bind(gender), {"temperature": 0.9})
	_typing_label.text = ""
	if result.is_empty():
		_narrate("Couldn't invent the owner: %s" % _ai.last_error)
		_button.text = "Try again"
		_button.disabled = false
		_busy = false
		return
	_owner = result
	_owner["gender"] = gender
	_owner_tag.text = _owner_display()
	_owner_node.visible = true
	_narrate(_as_sentence(str(_owner["appearance"])))
	_narrate("%s opens up for the night." % _owner_display())
	_update_info()
	_button.text = "Next customer"
	_button.disabled = false
	_busy = false


# --- One visit, start to finish ---------------------------------------------

func _run_visit() -> void:
	_busy = true
	_button.disabled = true
	_transcript.clear()
	_order.clear()
	_customer = {}
	_moment = {
		"day": DAYS.pick_random(),
		"time": TIMES.pick_random(),
		"weather": WEATHER.pick_random(),
	}
	_moment_label.text = "%s, %s, %s" % [_moment["day"], _moment["time"], _moment["weather"]]
	_update_info()
	_log.append_text("\n[center][color=#%s]· · ·[/color][/center]\n\n" % MUTED.to_html(false))
	_narrate("%s, %s. %s." % [_moment["day"], _moment["time"], _sentence_case(_moment["weather"])])

	# 1. Who walks in?
	_typing_label.text = "Someone is coming down the street..."
	var customer: Dictionary = await _ai.ask_json(
		Prompts.customer_messages(_moment["day"], _moment["time"], _moment["weather"], false),
		_validate_customer, {"temperature": 0.9})
	_typing_label.text = ""
	if customer.is_empty():
		_narrate("Nobody came in after all. (%s)" % _ai.last_error)
		_finish_visit()
		return
	_customer = customer
	_customer_color = CUSTOMER_COLORS.pick_random()
	_update_info()
	_narrate(_as_sentence(str(_customer["appearance"])))
	await _walk_in()

	# 2. They sit down, say hello and order in one line, so what they say matches
	# what they get. The menu and the bill belong to the game.
	_typing_label.text = "%s is looking at the menu..." % _customer["name"]
	var order: Dictionary = await _ai.ask_json(
		Prompts.order_messages(_owner, _customer, _moment, Menu.prompt_list(), _transcript),
		_validate_order, {"temperature": 0.7})
	_typing_label.text = ""
	if order.is_empty():
		_order = ["soju"]
		_narrate("(The AI couldn't come up with a valid order, so the game served soju: %s.)" % _ai.last_error)
	else:
		_order = order["items"]
		await _say(false, str(order["line"]))
	_update_info()

	# 3. Served automatically.
	await _serve(_order)

	# 4. The conversation: owner and customer take turns; the customer has the last word.
	var exchanges := randi_range(3, 5)
	var total_lines := exchanges * 2
	for i in total_lines:
		var owner_speaks := i % 2 == 0
		var direction := ""
		if i == 0:
			direction = "They've just set down the order: %s." % _item_names(_order)
		elif i == total_lines - 2:
			direction = "The customer is nearly ready to leave."
		elif i == total_lines - 1:
			direction = "This is the customer's last line: they're paying up and heading back out into the night."
		var speaker := str(_owner["name"]) if owner_speaks else str(_customer["name"])
		var alias := str(_owner["title"]) if owner_speaks else ""
		_typing_label.text = "%s is thinking..." % (_owner_display() if owner_speaks else speaker)
		var reply: Dictionary = await _ai.ask_json(
			Prompts.dialogue_messages(_owner, _customer, _moment, _item_names(_order), _transcript, owner_speaks, direction),
			_validate_line.bind(speaker, alias), {"temperature": 0.85})
		_typing_label.text = ""
		if reply.is_empty():
			_narrate("(The conversation fizzled out: %s.)" % _ai.last_error)
			break
		await _say(owner_speaks, str(reply["line"]))

	# 5. Pay and leave. The game works out the bill.
	var bill := _bill(_order)
	_takings += bill
	_takings_label.text = "Takings: %s" % Menu.format_won(_takings)
	_narrate("%s pays %s and heads back out into the night." % [_customer["name"], Menu.format_won(bill)])
	await _walk_out()
	_clear_items()
	_finish_visit()


func _finish_visit() -> void:
	_typing_label.text = ""
	_button.disabled = false
	_busy = false


# --- Things happening in the scene -----------------------------------------

func _walk_in() -> void:
	_customer_body.color = _customer_color
	_customer_head.color = _customer_color.lightened(0.25)
	_customer_tag.text = str(_customer["name"])
	_customer_node.position = Vector2(OFFSCREEN_X, CUSTOMER_Y)
	_customer_node.visible = true
	var tween := create_tween()
	tween.tween_property(_customer_node, "position:x", CUSTOMER_SEAT_X, _scaled(1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _walk_out() -> void:
	var tween := create_tween()
	tween.tween_property(_customer_node, "position:x", OFFSCREEN_X, _scaled(1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_customer_node.visible = false


func _serve(items: Array) -> void:
	_typing_label.text = "%s is cooking..." % _owner_display()
	for id in items:
		await get_tree().create_timer(_scaled(0.9)).timeout
		_add_item_visual(Menu.find(id))
	_typing_label.text = ""
	_narrate("Served: %s." % _item_names(items))


func _add_item_visual(item: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = str(item["name"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var dish := ColorRect.new()
	dish.color = Color(str(item["color"]))
	dish.custom_minimum_size = Vector2(34, 22)
	dish.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(dish)
	_items_row.add_child(box)


func _clear_items() -> void:
	for child in _items_row.get_children():
		child.queue_free()


## Shows a line of dialogue, adds it to the transcript, then pauses long enough to read it.
func _say(owner_speaks: bool, text: String) -> void:
	var who := _owner_display() if owner_speaks else str(_customer["name"])
	var colour := OWNER_TEXT if owner_speaks else _customer_color.lightened(0.35)
	_transcript.append({"speaker": str(_owner["name"]) if owner_speaks else who, "text": text})
	_log.append_text("[color=#%s][b]%s:[/b][/color] %s\n\n" % [colour.to_html(false), _esc(who), _esc(text)])
	await _pause_for(text)


func _narrate(text: String) -> void:
	_log.append_text("[i][color=#%s]%s[/color][/i]\n\n" % [MUTED.to_html(false), _esc(text)])


func _pause_for(text: String) -> void:
	var seconds := clampf(1.0 + text.length() * 0.035, 1.5, 7.0)
	await get_tree().create_timer(_scaled(seconds)).timeout


func _scaled(seconds: float) -> float:
	return seconds * (0.3 if _fast_toggle.button_pressed else 1.0)


# --- Small helpers -----------------------------------------------------------

func _owner_display() -> String:
	if _owner.is_empty():
		return "The owner"
	return "%s (%s)" % [_owner["name"], _owner["title"]]


## "Soju, Soju, Tteokbokki" -> "2x Soju, Tteokbokki"
func _item_names(items: Array) -> String:
	var counts := {}
	var order_seen: Array = []
	for id in items:
		if not counts.has(id):
			counts[id] = 0
			order_seen.append(id)
		counts[id] += 1
	var parts := PackedStringArray()
	for id in order_seen:
		var item_name := str(Menu.find(id).get("name", id))
		parts.append(item_name if counts[id] == 1 else "%dx %s" % [counts[id], item_name])
	return ", ".join(parts)


func _bill(items: Array) -> int:
	var total := 0
	for id in items:
		total += int(Menu.find(id).get("price", 0))
	return total


## "a messy bob" -> "A messy bob."
func _as_sentence(text: String) -> String:
	var result := _sentence_case(text.strip_edges())
	if result != "" and not (result.ends_with(".") or result.ends_with("!") or result.ends_with("?")):
		result += "."
	return result


func _sentence_case(text: String) -> String:
	if text == "":
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


## Stop anything the AI writes from being read as BBCode formatting.
func _esc(value: Variant) -> String:
	return str(value).replace("[", "[lb]")


func _update_info() -> void:
	var accent := ACCENT.to_html(false)
	var muted := MUTED.to_html(false)
	var t := ""
	if not _owner.is_empty():
		t += "[color=#%s][b]THE OWNER[/b][/color]\n" % accent
		t += "[b]%s[/b], %s\n" % [_esc(_owner_display()), _owner["age"]]
		t += "%s\n" % _esc(_owner["archetype"])
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(_owner["personality"])]
		t += "[i][color=#%s]Secret: %s[/color][/i]\n" % [muted, _esc(_owner["secret"])]
	if not _customer.is_empty():
		t += "\n[color=#%s][b]CUSTOMER[/b][/color]\n" % accent
		t += "[b]%s[/b], %s, %s\n" % [_esc(_customer["name"]), _customer["age"], _esc(_customer["job"])]
		t += "Mood: %s\n" % _esc(_customer["mood"])
		t += "[color=#%s]%s[/color]\n" % [muted, _esc(_customer["reason"])]
		if not _order.is_empty():
			t += "Ordered: %s (%s)\n" % [_esc(_item_names(_order)), Menu.format_won(_bill(_order))]
	_info.text = t


# --- Checking the AI's replies (the game owns the facts) ---------------------

func _validate_owner(data: Variant, gender: String) -> String:
	var problem := _check_fields(data, OWNER_FIELDS)
	if problem != "":
		return problem
	problem = _check_age(data, 30, 85)
	if problem != "":
		return problem
	# The owner is a {gender}: their title and archetype mustn't use a word for the other gender.
	var other := "man" if gender == "woman" else "woman"
	for field in ["title", "archetype"]:
		var words := _words(str(data[field]))
		for term in GENDERED_TERMS[other]:
			if term in words:
				return "the owner is a %s, but their %s uses \"%s\", which is for a %s" % [gender, field, term, other]
	return ""


## "Gruff-but-soft Ajumma!" -> ["gruff", "but", "soft", "ajumma"]
func _words(text: String) -> PackedStringArray:
	var letters := ""
	for c in text.to_lower():
		letters += c if (c >= "a" and c <= "z") else " "
	return letters.split(" ", false)


func _validate_customer(data: Variant) -> String:
	var problem := _check_fields(data, CUSTOMER_FIELDS)
	if problem != "":
		return problem
	return _check_age(data, MIN_DRINKING_AGE, 90)


func _validate_order(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	if not data.has("items") or typeof(data["items"]) != TYPE_ARRAY:
		return "\"items\" wasn't a list of menu ids"
	var raw: Array = data["items"]
	if raw.is_empty():
		return "they didn't order anything"
	if raw.size() > MAX_ORDER_ITEMS:
		return "they ordered %d items, and the most is %d" % [raw.size(), MAX_ORDER_ITEMS]
	var ids: Array = []
	for entry in raw:
		var id := Menu.resolve(str(entry))
		if id == "":
			return "\"%s\" isn't on the menu" % str(entry)
		ids.append(id)
	data["items"] = ids
	var line := _unquote(_tidy_text(data.get("line", "")))
	if line == "":
		return "\"line\" was empty"
	# What they say must match what they get: no mentioning dishes they didn't order.
	var allowed := ids.duplicate()
	if ids.has("somaek"):
		allowed.append_array(["soju", "beer"])  # somaek is soju in beer, so they may say so
	var said := _words(line)
	for item in Menu.ITEMS:
		var item_word: String = _words(str(item["name"]))[0]
		if not allowed.has(item["id"]) and item_word in said:
			return "the line mentions %s, but that isn't in \"items\"" % item["name"]
	data["line"] = line
	return ""


func _validate_line(data: Variant, speaker: String, alias: String) -> String:
	if typeof(data) != TYPE_DICTIONARY or not data.has("line"):
		return "it didn't include \"line\""
	var line := _tidy_text(data["line"])
	# Small models sometimes carry on and write the other person's reply too: keep the first part.
	var cut := line.find("\n")
	if cut > 0:
		line = line.substr(0, cut).strip_edges()
	# ...or start with "Name:". Strip that off.
	for prefix in [speaker, alias]:
		if prefix != "" and line.to_lower().begins_with(prefix.to_lower() + ":"):
			line = line.substr(prefix.length() + 1).strip_edges()
	line = _unquote(line)
	if line == "":
		return "the line was empty"
	if line.length() > 500:
		return "the line was far too long"
	data["line"] = line
	return ""


func _check_fields(data: Variant, fields: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	for field in fields:
		if not data.has(field):
			return "it left out \"%s\"" % field
		if field == "age":
			continue
		var text := _tidy_text(data[field])
		if text == "":
			return "\"%s\" was empty" % field
		data[field] = text
	return ""


func _check_age(data: Dictionary, lowest: int, highest: int) -> String:
	var age = data["age"]
	if typeof(age) == TYPE_STRING and age.is_valid_int():
		age = age.to_int()
	if typeof(age) != TYPE_INT and typeof(age) != TYPE_FLOAT:
		return "the age wasn't a number"
	if int(age) < lowest or int(age) > highest:
		return "an age of %d doesn't fit here (it must be %d to %d)" % [int(age), lowest, highest]
	data["age"] = int(age)
	return ""


## Text fields sometimes come back as lists: join them up.
func _tidy_text(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for part in value:
			parts.append(str(part).strip_edges())
		return ", ".join(parts)
	return str(value).strip_edges()


func _unquote(text: String) -> String:
	for pair in [["\"", "\""], ["“", "”"], ["'", "'"]]:
		if text.length() >= 2 and text.begins_with(pair[0]) and text.ends_with(pair[1]):
			return text.substr(1, text.length() - 2).strip_edges()
	return text


# --- Building the screen ------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14132a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top bar
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 10)
	bar.size = Vector2(1232, 44)
	bar.add_theme_constant_override("separation", 18)
	add_child(bar)

	var title := Label.new()
	title.text = "KTBT  ·  Stage 2: one visit"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(title)

	_moment_label = Label.new()
	_moment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moment_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_moment_label.clip_text = true
	bar.add_child(_moment_label)

	_takings_label = Label.new()
	_takings_label.text = "Takings: %s" % Menu.format_won(0)
	_takings_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_takings_label)

	_fast_toggle = CheckBox.new()
	_fast_toggle.text = "Fast"
	_fast_toggle.tooltip_text = "Shorter pauses between lines, for testing."
	bar.add_child(_fast_toggle)

	_button = Button.new()
	_button.text = "Next customer"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.disabled = true
	_button.pressed.connect(_on_button_pressed)
	bar.add_child(_button)

	# The tent
	var stage := Control.new()
	stage.position = Vector2(0, 60)
	stage.size = Vector2(1280, 380)
	stage.clip_contents = true
	add_child(stage)
	_build_stage(stage)

	# Bottom left: what's being said
	var log_panel := _panel(Vector2(24, 452), Vector2(820, 256))
	add_child(log_panel)
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log.add_theme_font_size_override("bold_font_size", 17)
	_log.add_theme_font_size_override("italics_font_size", 16)
	log_box.add_child(_log)
	_typing_label = Label.new()
	_typing_label.add_theme_color_override("font_color", MUTED)
	log_box.add_child(_typing_label)

	# Bottom right: who's who
	var info_panel := _panel(Vector2(860, 452), Vector2(396, 256))
	add_child(info_panel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.selection_enabled = true
	_info.add_theme_font_size_override("normal_font_size", 15)
	_info.add_theme_font_size_override("bold_font_size", 15)
	_info.add_theme_font_size_override("italics_font_size", 15)
	info_panel.add_child(_info)


func _panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var box := StyleBoxFlat.new()
	box.bg_color = Color("22203a")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Grey-box tent: overpass, glow, bulb, owner, counter, stool, customer, roof.
## Children are drawn in the order they're added, so later things sit in front.
func _build_stage(stage: Control) -> void:
	_rect(stage, Vector2(0, 0), Vector2(1280, 36), Color("0c0b1a"))  # the overpass
	_rect(stage, Vector2(80, 36), Vector2(44, 344), Color("1f1e36"))  # pillars
	_rect(stage, Vector2(1156, 36), Vector2(44, 344), Color("1f1e36"))
	_rect(stage, Vector2(140, 110), Vector2(1000, 270), Color(0.91, 0.51, 0.23, 0.16))  # warm glow inside the tent
	_rect(stage, Vector2(0, 372), Vector2(1280, 8), Color("2a2840"))  # wet street

	_rect(stage, Vector2(639, 110), Vector2(2, 36), Color("55536b"))  # bulb wire
	_rect(stage, Vector2(632, 146), Vector2(16, 16), OWNER_TEXT)  # the bulb

	_owner_node = _person(stage, Vector2(560, 150), OWNER_COLOR)
	_owner_tag = _owner_node.get_node("Tag") as Label
	_owner_node.visible = false

	_rect(stage, Vector2(300, 250), Vector2(680, 18), Color("8a5a33"))  # counter top
	_rect(stage, Vector2(320, 268), Vector2(640, 104), Color("5c3820"))  # counter front

	_items_row = HBoxContainer.new()
	_items_row.position = Vector2(400, 198)
	_items_row.size = Vector2(370, 52)
	_items_row.alignment = BoxContainer.ALIGNMENT_END
	_items_row.add_theme_constant_override("separation", 8)
	stage.add_child(_items_row)

	_rect(stage, Vector2(790, 340), Vector2(70, 12), Color("9a9ab0"))  # stool
	_rect(stage, Vector2(819, 352), Vector2(12, 20), Color("6e6e86"))

	_customer_node = _person(stage, Vector2(OFFSCREEN_X, CUSTOMER_Y), Color.WHITE)
	_customer_body = _customer_node.get_node("Body") as ColorRect
	_customer_head = _customer_node.get_node("Head") as ColorRect
	_customer_tag = _customer_node.get_node("Tag") as Label
	_customer_node.visible = false

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(120, 40), Vector2(1160, 40), Vector2(1250, 112), Vector2(30, 112)])
	roof.color = ACCENT
	stage.add_child(roof)
	_rect(stage, Vector2(30, 112), Vector2(1220, 10), Color("c8612a"))


func _rect(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A grey-box person: a head, a body and a name tag, grouped so they move together.
func _person(parent: Control, pos: Vector2, colour: Color) -> Control:
	var root := Control.new()
	root.position = pos
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var head := _rect(root, Vector2(17, 0), Vector2(46, 44), colour.lightened(0.25))
	head.name = "Head"
	var body := _rect(root, Vector2(0, 44), Vector2(80, 106), colour)
	body.name = "Body"
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-110, -30)
	tag.size = Vector2(300, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(tag)
	return root
