class_name Bubble
extends Control
## A speech bubble over whoever's speaking, with its tail pointing down at them, a header
## saying who they're talking to, and a curved line from the bubble to the listener. It
## follows them (someone still walking to their stool, the owner moving round), and shows a
## long line a page at a time (see Talk.bubble_pages); the transcript keeps the full record.

const NARROW := 330.0
const WIDE := 440.0  # for a long line, so it stays a few lines tall
const ABOVE_HEAD := 36.0  # the bubble sits this far above the top of the speaker's head (over their name)
const PAPER := Color("f7f1e3")
const INK := Color("2a2533")

var speaker: Control  # whoever's speaking (stage coordinates)
var listener: Control  # whoever they're talking to (or null)
var colour := Color.WHITE  # the speaker's colour: the bubble's border and the line
var stage_width := 1872.0
var width := NARROW

var _panel: PanelContainer
var _header: Label
var _body: Label
var _tail: Polygon2D
var _line: Line2D
var _listener_tag: Label


func setup(header_text: String, header_colour: Color, wide: bool = false) -> void:
	width = WIDE if wide else NARROW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = Line2D.new()
	_line.width = 3.0
	_line.default_color = Color(colour, 0.85)
	_line.antialiased = true
	add_child(_line)
	_tail = Polygon2D.new()
	_tail.color = PAPER
	add_child(_tail)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = colour
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_offset = Vector2(2, 3)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(width, 0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_header = Label.new()
	_header.name = "Header"
	_header.text = header_text
	_header.add_theme_font_size_override("font_size", 13)
	_header.add_theme_color_override("font_color", header_colour.darkened(0.35))
	column.add_child(_header)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(width - 24, 0)
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", INK)
	column.add_child(_body)
	# The listener's name tag lights up while they're being spoken to.
	if listener != null:
		_listener_tag = listener.get_node_or_null("Tag") as Label
		if _listener_tag != null:
			_listener_tag.add_theme_color_override("font_color", Color("ffe9a8"))
	_place()


## One page of the line.
func show_page(text: String) -> void:
	_body.text = text


## A newer line's been said: this one fades back and loses its line to the listener.
func dim() -> void:
	modulate = Color(1, 1, 1, 0.45)
	_line.visible = false
	_let_go_of_listener()


func _process(_delta: float) -> void:
	if not is_instance_valid(speaker) or speaker.is_queued_for_deletion():
		queue_free()
		return
	_place()


func _exit_tree() -> void:
	_let_go_of_listener()


func _let_go_of_listener() -> void:
	if _listener_tag != null and is_instance_valid(_listener_tag):
		_listener_tag.remove_theme_color_override("font_color")
	_listener_tag = null


## Over the speaker's head (kept on the stage), the tail down to them, and the line curving
## from the bubble's edge nearest the listener down to the listener's head.
func _place() -> void:
	var head := speaker.position + Vector2(40, 0)
	var bottom := head.y - ABOVE_HEAD
	var height := _panel.size.y
	var x := clampf(head.x - width / 2, 6.0, stage_width - width - 6.0)
	_panel.position = Vector2(x, maxf(4.0, bottom - height))
	var base_x := clampf(head.x, x + 18.0, x + width - 18.0)
	var panel_bottom := _panel.position.y + height
	_tail.polygon = PackedVector2Array([Vector2(base_x - 10, panel_bottom - 3), Vector2(base_x + 10, panel_bottom - 3),
		Vector2(head.x, head.y - 8)])
	if listener == null or not is_instance_valid(listener) or not _line.visible:
		_line.clear_points()
		return
	var target := listener.position + Vector2(40, -6)
	var start := Vector2(clampf(target.x, x + 24.0, x + width - 24.0), panel_bottom - 2)
	var control := Vector2((start.x + target.x) / 2, minf(start.y, target.y) - 30.0)
	var points := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		points.append(start.lerp(control, t).lerp(control.lerp(target, t), t))
	_line.points = points
