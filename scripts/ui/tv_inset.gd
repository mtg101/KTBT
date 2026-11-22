extends Control
## The TV box (PLAN.md, "Using portraits"): Korean TV's picture-in-picture, cutting to camera
## beside a caption: the face of whoever it's about (or two side by side), each their library
## portrait in the caption's mood (people_art.gd portrait()), whole pixels scaled up and never
## smoothed, framed in the caption's colour with their name under it. Most often an inset in
## the stage's corner away from them; for the night's first big moment, the zoom: the whole
## window dimmed, the face big in the middle and the caption under it. Pops in with the
## caption, holds as long, fades and frees itself. Never takes a click.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const INSET_SCALE := 3  # the portrait's 64 x 80 at 192 x 240: twice the size of the people on stage
const ZOOM_SCALE := 6  # 384 x 480, the window's middle
const NAME_SIZE := 22
const ZOOM_NAME_SIZE := 32
const BORDER := 6
const MARGIN := 16.0  # from the stage's edge
const DIM := Color(0.04, 0.03, 0.1, 0.72)  # the zoom's window, behind the face

var time_scale := 1.0  # tests run it in a blink
var zoomed := false
var faces_shown := 0
var box: PanelContainer  # the frame and its faces (the caption goes under it, in a zoom)


## faces: [{"texture", "name"}], one or two; colour: the caption's.
func setup(faces: Array, colour: Color, zoom: bool) -> void:
	zoomed = zoom
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if zoom:
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = DIM
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	box = PanelContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Ktv.INK
	style.border_color = colour
	style.set_border_width_all(BORDER)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(BORDER + 4)
	style.shadow_color = Ktv.SHADOW
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var scale_by := ZOOM_SCALE if zoom else INSET_SCALE
	for face in faces:
		var texture: Texture2D = face["texture"]
		var column := VBoxContainer.new()
		column.name = "Face"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)
		row.add_child(column)
		var picture := TextureRect.new()
		picture.name = "Picture"
		picture.texture = texture
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.custom_minimum_size = Vector2(texture.get_size() * scale_by)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
		var label := Ktv.label(str(face.get("name", "")), ZOOM_NAME_SIZE if zoom else NAME_SIZE, colour.lightened(0.55), 6, Ktv.INK)
		label.name = "Name"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		faces_shown += 1


## The inset: in the stage's top corner away from whoever it's about (their x on the stage).
func place_inset(stage_width: float, their_x: float) -> void:
	size = box.get_combined_minimum_size()
	box.size = size
	var x := MARGIN if their_x >= stage_width / 2 else stage_width - size.x - MARGIN
	position = Vector2(x, MARGIN)
	pivot_offset = size / 2


## The zoom: over the whole window, the face in the middle near the top (room under it for the
## caption: zoom_caption_spot()).
func place_zoom(screen: Vector2) -> void:
	position = Vector2.ZERO
	size = screen
	box.size = box.get_combined_minimum_size()
	box.position = Vector2((screen.x - box.size.x) / 2, screen.y * 0.1)
	box.pivot_offset = box.size / 2
	pivot_offset = screen / 2


## Where a zoom's caption goes (the middle of its bottom edge): just under the face.
func zoom_caption_spot() -> Vector2:
	return Vector2(size.x / 2, box.position.y + box.size.y + 150)


## Cuts in, holds, fades away (then frees itself).
func pop(hold_seconds: float) -> void:
	var grows: Control = box if zoomed else self
	grows.scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12 * time_scale)
	tween.parallel().tween_property(grows, "scale", Vector2.ONE, 0.25 * time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.0, hold_seconds - 0.55) * time_scale)
	tween.tween_property(self, "modulate:a", 0.0, 0.4 * time_scale)
	tween.tween_callback(queue_free)
