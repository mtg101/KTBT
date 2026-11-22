class_name Caption
extends Control
## A Korean variety-show caption (자막): big outlined Hangul over a coloured English tag, an
## icon, a slight tilt, popping in with an overshoot, held a moment, then fading. Placed by
## whoever it's about (see visit.gd _caption); the words come from Captions.CAPTIONS. With a
## face (ui/face_sticker.gd), it's slapped on beside the words, thumped in just after them.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const FaceSticker = preload("res://scripts/ui/face_sticker.gd")
const INK := Ktv.INK
const HANGUL_SIZE := 50
const ENGLISH_SIZE := 24
const ICON_SIZE := 44

var time_scale := 1.0  # tests run it in a blink
var at := Vector2.ZERO  # where it goes: the middle of its bottom edge (stage coordinates)
var stage_width := 1872.0
var _box: VBoxContainer
var _row: HBoxContainer
var _placed := false
var sticker: FaceSticker  # its face, if it has one


## face: its face (set up, not yet in the tree), or null; face_first: on the left of the words.
func setup(words: Dictionary, icon: String, colour: Color, face: FaceSticker = null, face_first := true) -> void:
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
	Ktv.soft_shadow(hangul, Vector2(2, 3))
	_box.add_child(hangul)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Ktv.pill(colour.darkened(0.15), 10, 3, 10, false)
	style.content_margin_top = 0
	style.content_margin_bottom = 2
	tag.add_theme_stylebox_override("panel", style)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(tag)
	var english := _label(str(words.get("english", "")), ENGLISH_SIZE, Color.WHITE, 6)
	english.name = "English"
	tag.add_child(english)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if face != null:
		sticker = face
		row.add_child(face)
		if face_first:
			row.move_child(face, 0)
		face.time_scale = time_scale
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
	if sticker != null:
		sticker.slam(0.14)


func _label(text: String, font_size: int, colour: Color, outline: int) -> Label:
	var made := Ktv.label(text, font_size, colour, outline)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return made
