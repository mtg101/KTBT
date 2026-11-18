extends Control
## The menu board: one in each tent, in the bar's own style (a wooden board on the wall, a
## chalk A-frame out front, a paper sheet taped to the pole, or a lightbox), with 메뉴 on it.
## Click it (hover says so) and the whole menu opens over the tent: tonight's specials, the
## food, then the drinks, each in Hangul and English with what it is and its price; the house
## favourite marked 인기, anything sold out 품절. Rebuilt whenever the menu or the night
## changes (see show_menu).

const Text = preload("res://scripts/rules/text.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Art = preload("res://scripts/ui/art.gd")

## The styles, where each stands in the tent (stage coordinates, on the street's grid: a pixel
## to 3) and its size.
const STYLES := {
	"wall": {"at": Vector2(297, 126), "size": Vector2(111, 72)},
	"floor": {"at": Vector2(15, 285), "size": Vector2(75, 87)},
	"paper": {"at": Vector2(30, 198), "size": Vector2(60, 78)},
	"lightbox": {"at": Vector2(1539, 129), "size": Vector2(120, 45)},
}
const STYLE_ORDER := ["wall", "floor", "paper", "lightbox"]

const INK := Color("2a2622")
const PRICE_INK := Color("c8362a")
const CHALK := Color("eef0e6")

signal opened  # the menu was clicked open (for the stats)

var style := "wall"
var shown_ids: Array = []  # the menu's ids, in the order it's written (for tests)
var panel: PopupPanel  # the whole menu, when it's open
var _text: RichTextLabel


## A bar's board style, the same every night (from its id).
static func style_for(bar_id: String) -> String:
	return STYLE_ORDER[posmod(hash(bar_id + "board"), STYLE_ORDER.size())]


## Puts the menu up: items (menu items, in the order to write them: see Menu.board_order),
## tonight's specials and anything sold out (ids), the house favourite (an id, or ""), and
## whose board it is (the bar's id, for its style, and its name, for the menu's title).
func show_menu(items: Array, specials: Array = [], sold_out: Array = [], favourite: String = "", bar_id: String = "", bar_name: String = "") -> void:
	style = style_for(bar_id)
	position = STYLES[style]["at"]
	size = STYLES[style]["size"]
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = Text.tip("메뉴 menyu: the menu. Click to read it.")
	for child in get_children():
		if child != panel:
			child.queue_free()
	_draw_board()
	shown_ids = items.map(func(item): return str(item["id"]))
	_build_panel()
	_text.text = Glossary.explain_hangul(menu_text(items, specials, sold_out, favourite, bar_name))


## The whole menu, as BBCode: a title, then tonight's specials, the food and the drinks, each
## line the Hangul, the English name and what it is, and the price.
static func menu_text(items: Array, specials: Array, sold_out: Array, favourite: String, bar_name: String) -> String:
	var own := func(item: Dictionary) -> bool: return bool(item.get("signature", false))
	var sections := [["대표 메뉴", "THE HOUSE'S OWN", items.filter(func(item): return own.call(item))],
		["오늘의 특선", "TONIGHT'S SPECIALS", items.filter(func(item): return specials.has(item["id"]) and not own.call(item))],
		["안주", "FOOD", items.filter(func(item): return item["kind"] == "food" and not specials.has(item["id"]) and not own.call(item))],
		["주류", "DRINKS", items.filter(func(item): return item["kind"] == "drink" and not specials.has(item["id"]))]]
	var t := "[center][font_size=26][b]메뉴 MENU[/b][/font_size]\n[color=#8a8578]%s[/color][/center]\n" % bar_name
	for section in sections:
		if section[2].is_empty():
			continue
		t += "\n[color=#c8362a][b]%s  %s[/b][/color]\n[table=3]" % [section[0], section[1]]
		for item in section[2]:
			var id := str(item["id"])
			var marks := ""
			if id == favourite:
				marks += "  [color=#d8452f][b]인기[/b][/color]"
			if sold_out.has(id):
				marks += "  [color=#c8362a][b]품절[/b][/color]"
			var about := str(item.get("desc", ""))
			if str(item.get("meaning", "")) != "":
				about = "\"%s\": %s" % [item["meaning"], about]
			var name_bit := "[b]%s[/b]%s\n[color=#8a8578][font_size=13]%s[/font_size][/color]" % [item["name"], marks, about]
			if sold_out.has(id):
				name_bit = "[s]%s[/s]" % name_bit
			t += "[cell][font_size=20]%s[/font_size]   [/cell][cell]%s   [/cell][cell][color=#c8362a]%s[/color][/cell]" % [item.get("hangul", ""), name_bit, Menu.format_won(int(item["price"]))]
		t += "[/table]\n"
	return t


## Opens the whole menu over the tent (clicking the board does this).
func open() -> void:
	if panel != null:
		panel.popup_centered(Vector2i(620, 560))
		opened.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open()
		accept_event()


func _build_panel() -> void:
	if panel != null:
		return
	panel = PopupPanel.new()
	panel.name = "MenuPanel"
	var paper := StyleBoxFlat.new()
	paper.bg_color = Ktv.PAPER
	paper.set_corner_radius_all(6)
	paper.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", paper)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_text = RichTextLabel.new()
	_text.name = "MenuText"
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(580, 470)
	_text.add_theme_color_override("default_color", INK)
	_text.add_theme_font_size_override("normal_font_size", 16)
	_text.add_theme_font_size_override("bold_font_size", 16)
	column.add_child(_text)
	var close := Button.new()
	close.name = "CloseMenu"
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): panel.hide())
	column.add_child(close)


## The board itself, in its style, with 메뉴 on it and a few lines of writing.
func _draw_board() -> void:
	var box: Vector2 = size
	rotation_degrees = 0.0
	if Art.place(self, "menu/" + style, Vector2.ZERO, "topleft", 3) != null:  # (in pixel art: art/menus, its writing and all)
		_title(Vector2(0, 2 if style == "lightbox" else 6), box.x, PRICE_INK if style in ["paper", "lightbox"] else (CHALK if style == "floor" else INK))
		return
	Art.drawn("menu/" + style)
	match style:
		"wall":
			_rect(Vector2(0, 0), box, Color("6a4628"))  # the board
			_rect(Vector2(6, 6), box - Vector2(12, 12), Color("f3ead6"))  # the menu pinned to it
			_rect(Vector2(box.x / 2 - 3, 2), Vector2(6, 6), Color("c8362a"))  # a pin
			_title(Vector2(0, 8), box.x, INK)
			_scribbles(Vector2(14, 32), box.x - 28, 4, Color(0.2, 0.2, 0.2, 0.45))
		"floor":
			_rect(Vector2(8, box.y - 20), Vector2(5, 20), Color("4a3524"))  # the A-frame's legs
			_rect(Vector2(box.x - 13, box.y - 20), Vector2(5, 20), Color("4a3524"))
			_rect(Vector2(0, 0), Vector2(box.x, box.y - 16), Color("4a3524"))
			_rect(Vector2(4, 4), Vector2(box.x - 8, box.y - 24), Color("2f4a3a"))  # chalkboard
			_title(Vector2(0, 6), box.x, CHALK)
			_scribbles(Vector2(10, 30), box.x - 20, 4, Color(CHALK, 0.6))
		"paper":
			_rect(Vector2(0, 0), box, Color("f6efdc"))
			_rect(Vector2(box.x / 2 - 9, -3), Vector2(18, 7), Color(1, 1, 1, 0.5))  # tape
			_title(Vector2(0, 6), box.x, PRICE_INK)
			_scribbles(Vector2(8, 30), box.x - 16, 5, Color(0.2, 0.2, 0.2, 0.45))
			rotation_degrees = -3.0
		"lightbox":
			_rect(Vector2(-6, -6), box + Vector2(12, 12), Color(1.0, 0.95, 0.8, 0.18))  # its glow
			_rect(Vector2(0, 0), box, Color("fff8e6"))
			_rect(Vector2(0, 0), Vector2(box.x, 4), Color("c8362a"))
			_title(Vector2(0, 8), box.x, PRICE_INK)
			_scribbles(Vector2(12, 34), box.x - 24, 1, Color(0.2, 0.2, 0.2, 0.4))
	if style != "paper":
		rotation_degrees = 0.0


func _title(at: Vector2, width: float, colour: Color) -> void:
	var title := Ktv.label("메뉴", 18, colour)
	title.position = at
	title.size = Vector2(width, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)


## Lines of writing too small to read (the menu's to be clicked on).
func _scribbles(at: Vector2, width: float, lines: int, colour: Color) -> void:
	for k in lines:
		var long := width * (0.55 + 0.4 * float((k * 37) % 10) / 10.0)
		_rect(at + Vector2(0, k * 9), Vector2(long, 2), colour)
		_rect(at + Vector2(width - 12, k * 9), Vector2(12, 2), Color(PRICE_INK, colour.a))  # its price


func _rect(at: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = at
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r
