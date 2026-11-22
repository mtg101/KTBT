extends Control
## The title screen: start a new bar, or open one you've played before.

const Text = preload("res://scripts/rules/text.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const DiaryBook = preload("res://scripts/ui/diary_book.gd")

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const ACCENT := Ktv.ORANGE
const MUTED := Ktv.MUTED
const PANEL := Ktv.PANEL

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
	if Game.autoplay != null and not Game.autoplay.begun:  # (a batch of nights: straight in, once the screen's up)
		Game.autoplay.begun = true
		_start_autoplay.call_deferred()


## Autoplay: its bar (or a new one of its own, if it named none or that one won't load).
func _start_autoplay() -> void:
	if Game.autoplay.bar_id == "" or not Game.open_bar(Game.autoplay.bar_id):
		Game.new_bar()


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


func _on_diary_pressed(bar: Dictionary) -> void:
	var book := DiaryBook.new()
	add_child(book)
	book.open(bar.get("diary", []), "%s's diary" % bar.get("owner", {}).get("name", ""), -1, str(bar.get("id", "")))


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
		var entries: Array = bars[i].get("diary", [])
		if not entries.is_empty():
			var diary := Button.new()
			diary.name = "Diary%d" % i
			diary.text = "📖 Diary"
			diary.tooltip_text = Text.tip("Read the owner's diary.")
			diary.custom_minimum_size = Vector2(130, 64)
			diary.pressed.connect(_on_diary_pressed.bind(bars[i]))
			row.add_child(diary)
		var delete := Button.new()
		delete.name = "Delete%d" % i
		delete.text = "Sure?" if _confirming == id else "Delete"
		delete.tooltip_text = Text.tip("Click again to delete this bar for good." if _confirming == id else "Delete this bar (you'll be asked to click again).")
		delete.custom_minimum_size = Vector2(110, 64)
		if _confirming == id:
			delete.add_theme_color_override("font_color", ACCENT)
		delete.pressed.connect(_on_delete_pressed.bind(id))
		row.add_child(delete)
		_list.add_child(row)


## One saved bar: its name and meaning, owner, nights, visits, regulars, when it was last played
## and where the show's got to in its season.
func _bar_button(bar: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Bar%d" % index
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	var owner_data: Dictionary = bar.get("owner", {})
	var visits := int(bar.get("visits", 0))
	var nights := int(bar.get("nights", 0))
	var regulars := Array(bar.get("regulars", [])).size()
	button.text = "%s  (%s)\n%s (%s)  ·  %d %s, %d %s, %d %s  ·  last played %s" % [
		bar.get("name", "?"), bar.get("name_meaning", ""),
		owner_data.get("name", "?"), owner_data.get("title", ""),
		nights, "night" if nights == 1 else "nights",
		visits, "visit" if visits == 1 else "visits",
		regulars, "regular" if regulars == 1 else "regulars",
		_when(int(bar.get("last_played", 0)))]
	if bar.has("show"):  # where the show's got to: "season 2, 3 of 8 aired"
		var aired: Dictionary = bar["show"]
		var channel: Dictionary = aired.get("channel", {})
		var on := str(Ladder.rung(ShowSeasons.rung_of(aired))["name"])
		if str(channel.get("rung", "")) == ShowSeasons.rung_of(aired):
			on += " (%s)" % channel.get("english", "")  # (the channel it's booked on)
		button.text += "  ·  season %d on %s, %d of %d aired" % [int(aired.get("season", 1)), on, int(aired.get("aired", 0)), ShowSeasons.EPISODES]
	if bool(bar.get("autoplay", false)):
		button.text += "  ·  played by autoplay"  # (a test bar: see autoplay.gd)
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
	card_style.border_color = Ktv.PINK
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
	title.add_theme_color_override("font_color", Ktv.CREAM)
	Ktv.title_card(title, 24, Ktv.PINK.darkened(0.15), Vector2(6, 8))
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Korean Tent Bar Tropes"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Ktv.YELLOW)
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Ktv.INK)
	col.add_child(subtitle)

	var music_row := HBoxContainer.new()  # the music's volume (it plays from here on)
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(music_row)
	var music_toggle := CheckBox.new()
	music_toggle.name = "MusicToggle"
	music_toggle.text = "Music"
	music_toggle.button_pressed = Game.music.enabled
	music_toggle.tooltip_text = Text.tip("Arirang, now and then.")
	music_toggle.add_theme_color_override("font_color", MUTED)
	music_toggle.toggled.connect(Game.music.set_enabled)
	Ktv.light_ticks(music_toggle)
	music_row.add_child(music_toggle)
	var music := HSlider.new()
	music.name = "MusicVolume"
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = Game.music.volume
	music.custom_minimum_size = Vector2(160, 0)
	music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music.tooltip_text = Text.tip("Arirang, now and then (all the way down for none).")
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
