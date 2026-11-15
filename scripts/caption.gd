class_name Caption
extends Control
## A Korean variety-show caption (자막): big outlined Hangul over a coloured English tag, an
## icon, a slight tilt, popping in with an overshoot, held a moment, then fading. Placed by
## whoever it's about (see visit.gd _caption); the words come from Rules.CAPTIONS.

const INK := Color("1d1a26")
const HANGUL_SIZE := 50
const ENGLISH_SIZE := 24
const ICON_SIZE := 44

var time_scale := 1.0  # tests run it in a blink
var at := Vector2.ZERO  # where it goes: the middle of its bottom edge (stage coordinates)
var stage_width := 1872.0
var _box: VBoxContainer
var _row: HBoxContainer
var _placed := false


func setup(words: Dictionary, icon: String, colour: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	_row = row
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var mark := _label(icon, ICON_SIZE, Color.WHITE, 8)
	mark.name = "Icon"
	row.add_child(mark)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", -6)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_box)
	var hangul := _label(str(words.get("hangul", "")), HANGUL_SIZE, colour, 14)
	hangul.name = "Hangul"
	hangul.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hangul.add_theme_constant_override("shadow_offset_x", 3)
	hangul.add_theme_constant_override("shadow_offset_y", 4)
	_box.add_child(hangul)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = colour.darkened(0.15)
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 0
	style.content_margin_bottom = 2
	tag.add_theme_stylebox_override("panel", style)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(tag)
	var english := _label(str(words.get("english", "")), ENGLISH_SIZE, Color.WHITE, 6)
	english.name = "English"
	tag.add_child(english)
	rotation = randf_range(-0.09, 0.09)
	_place()


## Centred over the spot, kept on the stage (sizes are only known once it's laid out).
func _place() -> void:
	size = _row.get_combined_minimum_size()
	pivot_offset = size / 2
	position = Vector2(clampf(at.x - size.x / 2, 8.0, stage_width - size.x - 8.0), maxf(4.0, at.y - size.y))


func _process(_delta: float) -> void:
	if not _placed and is_inside_tree():
		_placed = true
		_place()


## Pops in, holds, and fades away (then frees itself).
func pop(hold_seconds: float) -> void:
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.08 * time_scale)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.32 * time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.5 * time_scale).set_trans(Tween.TRANS_SINE)  # a little throb
	tween.tween_property(self, "scale", Vector2.ONE, 0.5 * time_scale).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.0, hold_seconds - 1.3) * time_scale)
	tween.tween_property(self, "modulate:a", 0.0, 0.4 * time_scale)
	tween.tween_callback(queue_free)


func _label(text: String, font_size: int, colour: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline)
	return label
