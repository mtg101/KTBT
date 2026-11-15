extends Control
## The title screen: start a new bar, or open one you've played before.

const SaveStore = preload("res://scripts/save_store.gd")
const Menu = preload("res://scripts/menu.gd")

const ACCENT := Color("e8833a")
const MUTED := Color("a9a6c2")
const PANEL := Color("22203a")

var _list: VBoxContainer
## The bar whose Delete button has been clicked once ("Sure?"), and when, so a second click
## soon after deletes it. One stray click never loses a bar.
var _confirming := ""
var _confirm_left := 0.0
const CONFIRM_SECONDS := 4.0


func _ready() -> void:
	Game.start_music()
	_build_ui()
	_fill_list()


func _on_new_bar_pressed() -> void:
	Game.new_bar()


func _on_bar_pressed(id: String) -> void:
	if not Game.open_bar(id):
		_fill_list()  # It's gone or broken since the list was made; refresh it.


func _process(delta: float) -> void:
	if _confirming != "":
		_confirm_left -= delta
		if _confirm_left <= 0.0:
			_confirming = ""
			_fill_list()


func _on_delete_pressed(id: String) -> void:
	if _confirming == id:
		SaveStore.delete_bar(id)
		_confirming = ""
	else:
		_confirming = id
		_confirm_left = CONFIRM_SECONDS
	_fill_list()


func _fill_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var open := _bar_button(bars[i], i)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(open)
		var id := str(bars[i]["id"])
		var delete := Button.new()
		delete.name = "Delete%d" % i
		delete.text = "Sure?" if _confirming == id else "Delete"
		delete.tooltip_text = "Click again to delete this bar for good." if _confirming == id else "Delete this bar (you'll be asked to click again)."
		delete.custom_minimum_size = Vector2(110, 64)
		if _confirming == id:
			delete.add_theme_color_override("font_color", ACCENT)
		delete.pressed.connect(_on_delete_pressed.bind(id))
		row.add_child(delete)
		_list.add_child(row)


## One saved bar: its name and meaning, owner, nights, visits, takings and when it was last played.
func _bar_button(bar: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Bar%d" % index
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	var owner_data: Dictionary = bar.get("owner", {})
	var visits := int(bar.get("visits", 0))
	var nights := int(bar.get("nights", 0))
	var regulars := Array(bar.get("regulars", [])).size()
	button.text = "%s  (%s)\n%s (%s)  ·  %d %s, %d %s, %d %s  ·  %s  ·  last played %s" % [
		bar.get("name", "?"), bar.get("name_meaning", ""),
		owner_data.get("name", "?"), owner_data.get("title", ""),
		nights, "night" if nights == 1 else "nights",
		visits, "visit" if visits == 1 else "visits",
		regulars, "regular" if regulars == 1 else "regulars",
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
	# The loading screen's night, tent, rays and ribbons behind it all, with Korean TV captions
	# popping up either side.
	var backdrop := LoadingScreen.new()
	backdrop.name = "Backdrop"
	backdrop.backdrop = true
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()  # a dark card, so the menu reads over the busy backdrop
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.07, 0.06, 0.15, 0.85)
	card_style.border_color = Color("ff7eb6")
	card_style.set_border_width_all(4)
	card_style.set_corner_radius_all(28)
	card_style.content_margin_left = 40
	card_style.content_margin_right = 40
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", card_style)
	centre.add_child(card)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(1000, 0)
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)

	var title := Label.new()
	title.text = "KTBT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("fff4e0"))
	title.add_theme_constant_override("outline_size", 24)
	title.add_theme_color_override("font_outline_color", Color("ff7eb6").darkened(0.15))
	title.add_theme_color_override("font_shadow_color", Color("2a1840"))
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_outline_size", 24)
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Korean Tent Bar Tropes"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color("ffd27f"))
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Color("1a1840"))
	col.add_child(subtitle)

	var music_row := HBoxContainer.new()  # the music's volume (it plays from here on)
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(music_row)
	var music_label := Label.new()
	music_label.text = "Music"
	music_label.add_theme_color_override("font_color", MUTED)
	music_row.add_child(music_label)
	var music := HSlider.new()
	music.name = "MusicVolume"
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = Game.music.volume
	music.custom_minimum_size = Vector2(160, 0)
	music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music.tooltip_text = "Arirang, now and then (all the way down for none)."
	music.value_changed.connect(Game.music.set_volume)
	music_row.add_child(music)

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
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "BarList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
