extends Control
## The owner's diary as a book: a page at a time (see diary_page.gd), opening at the latest
## night, with Older and Newer to flip through (or the arrow keys), and Close (or Esc). Over a
## dimmed screen: from the bar's Diary button during a night, or a bar's Diary button on the
## title screen. Shows whatever entries it's given (SaveStore.record_diary's), so "Previously
## on…" can open it at the night it's recapping too.

const DiaryPage = preload("res://scripts/ui/diary_page.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

signal closed

var _entries: Array = []
var _whose := ""
var _at := 0
var _page: Control
var _older: Button
var _newer: Button
var _where: Label


func _init() -> void:
	name = "DiaryBook"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the book's open: nothing behind it gets clicked
	z_index = 30
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	_page = DiaryPage.new()
	_page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_page)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_older = _button("DiaryOlder", "◀ Older", _flip.bind(-1))
	buttons.add_child(_older)
	_where = Label.new()
	_where.name = "DiaryWhere"
	_where.custom_minimum_size = Vector2(200, 0)
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_where.add_theme_font_size_override("font_size", 20)
	_where.add_theme_color_override("font_color", Ktv.LIGHT)
	buttons.add_child(_where)
	_newer = _button("DiaryNewer", "Newer ▶", _flip.bind(1))
	buttons.add_child(_newer)
	buttons.add_child(_button("DiaryClose", "Close", close))


## Opens the book at an entry (the latest, unless told which night).
func open(entries: Array, whose: String, night: int = -1) -> void:
	_entries = entries.duplicate()
	_entries.sort_custom(func(a, b): return int(a.get("night", 0)) < int(b.get("night", 0)))
	_whose = whose
	_at = _entries.size() - 1
	for k in _entries.size():
		if int(_entries[k].get("night", 0)) == night:
			_at = k
	_show_page()


func close() -> void:
	closed.emit()
	queue_free()


func showing_night() -> int:
	return int(_entries[_at].get("night", 0)) if not _entries.is_empty() else 0


func _flip(by: int) -> void:
	_at = clampi(_at + by, 0, maxi(0, _entries.size() - 1))
	_show_page()


func _show_page() -> void:
	if _entries.is_empty():
		_page.show_entry({"text": "Nothing written yet: the first entry comes at 3am.", "stamp": "soju", "episode": 0}, _whose)
	else:
		_page.show_entry(_entries[_at], _whose)
	_older.disabled = _at <= 0
	_newer.disabled = _at >= _entries.size() - 1
	_where.text = "%d of %d" % [_at + 1, _entries.size()] if not _entries.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT:
			_flip(-1)
		KEY_RIGHT:
			_flip(1)
		KEY_ESCAPE:
			close()
		_:
			return
	get_viewport().set_input_as_handled()


func _button(button_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(150, 48)
	button.pressed.connect(action)
	return button
