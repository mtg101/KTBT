extends Control
## The title screen: start a new bar, or open one you've played before.

const SaveStore = preload("res://scripts/save_store.gd")
const Menu = preload("res://scripts/menu.gd")

const ACCENT := Color("e8833a")
const MUTED := Color("a9a6c2")
const PANEL := Color("22203a")

var _list: VBoxContainer


func _ready() -> void:
	_build_ui()
	_fill_list()


func _on_new_bar_pressed() -> void:
	Game.new_bar()


func _on_bar_pressed(id: String) -> void:
	if not Game.open_bar(id):
		_fill_list()  # It's gone or broken since the list was made; refresh it.


func _fill_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var bars := SaveStore.list_bars()
	if bars.is_empty():
		var none := Label.new()
		none.name = "NoBars"
		none.text = "No bars yet. Start a new one, and its owner and name will be invented for you."
		none.add_theme_color_override("font_color", MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(none)
		return
	for i in bars.size():
		_list.add_child(_bar_button(bars[i], i))


## One saved bar: its name and meaning, owner, visits, takings and when it was last played.
func _bar_button(bar: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Bar%d" % index
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	var owner_data: Dictionary = bar.get("owner", {})
	var visits := int(bar.get("visits", 0))
	button.text = "%s  (%s)\n%s (%s)  ·  %d %s  ·  %s  ·  last played %s" % [
		bar.get("name", "?"), bar.get("name_meaning", ""),
		owner_data.get("name", "?"), owner_data.get("title", ""),
		visits, "visit" if visits == 1 else "visits",
		Menu.format_won(int(bar.get("takings", 0))),
		_when(int(bar.get("last_played", 0)))]
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_on_bar_pressed.bind(str(bar["id"])))
	return button


## A unix time as "13 Nov 2026, 23:40" in local time.
static func _when(unix: int) -> String:
	if unix <= 0:
		return "never"
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [d["day"], months[d["month"] - 1], d["year"], d["hour"], d["minute"]]


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14132a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(1000, 0)
	col.add_theme_constant_override("separation", 18)
	centre.add_child(col)

	var title := Label.new()
	title.text = "KTBT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", ACCENT)
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Korean Tent Bar Tropes"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", MUTED)
	col.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)

	var new_button := Button.new()
	new_button.name = "NewBarButton"
	new_button.text = "New bar"
	new_button.custom_minimum_size = Vector2(0, 64)
	new_button.add_theme_font_size_override("font_size", 24)
	new_button.pressed.connect(_on_new_bar_pressed)
	col.add_child(new_button)

	var heading := Label.new()
	heading.text = "Your bars"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", ACCENT)
	col.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "BarList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
