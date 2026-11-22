extends Control
## Recasting a regular's face (faces of their own: visit.gd _open_recast), at 3am while the GPU's
## free between nights: the regulars along the top with their faces as they are now; the PD clicks
## one, three new casting photos are taken (visit.gd shows them here as they come, show_state),
## and clicking a photo makes it their face (framed, and on their button). Leaving without
## clicking one keeps the face they have. Full screen over the summary page; "Done" (Enter or
## Esc) closes it, once no photos are being taken.

const Text = preload("res://scripts/rules/text.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")

## The PD picks whose face to recast (a regular's id).
signal chosen(id: String)
## The PD picks this round's photo k for their face.
signal face_picked(k: int)
## Done: closed.
signal finished

const RED := Color("ff4f6d")  # the camera's red: the PD's
const WIDTH := 1100.0
const PHOTO_SCALE := 2  # the photos: the portrait's pixels two to one, never smoothed
const FACE_SIZE := Vector2(64, 80)

var _regulars_row: HBoxContainer
var _note: Label
var _photos_row: HBoxContainer
var _done_button: Button
var _shooting := false
var _done := false
var _chosen := ""


func _init() -> void:
	name = "RecastScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # it's open: nothing behind it gets clicked
	z_index = 40


## Opens it with the bar's regulars: [{"id", "name", "texture" (their face now), "own" (their own, not the library's)}].
func open(regulars: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(Ktv.BACKGROUND, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2((1920.0 - WIDTH) / 2.0, 70)
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(Ktv.label("RECASTING A FACE", 40, Ktv.CREAM, 8))
	box.add_child(_wrapped("You're the PD. Click a regular to have three new casting photos taken (about half a minute), then click the one you want for their face on the show. Leave without clicking one and they keep the face they have.", Ktv.MUTED))
	_regulars_row = HBoxContainer.new()
	_regulars_row.name = "RecastRegulars"
	_regulars_row.add_theme_constant_override("separation", 16)
	_regulars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_regulars_row)
	for k in regulars.size():
		var regular: Dictionary = regulars[k]
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := _photo_button("RecastRegular_%d" % k, regular.get("texture", null))
		face.set_meta("id", str(regular["id"]))
		face.tooltip_text = Text.tip("Recast %s's face (%s now)" % [regular["name"], "their own" if bool(regular.get("own", false)) else "one from the show's library"])
		face.pressed.connect(_choose.bind(str(regular["id"])))
		column.add_child(_frame("RecastRegularFrame_%d" % k, face, false))
		var label := Ktv.label(str(regular["name"]), 18, Ktv.LIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(FACE_SIZE.x * PHOTO_SCALE + 12, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
		_regulars_row.add_child(column)
	_note = _wrapped("Pick a regular.", Ktv.MUTED)
	_note.name = "RecastNote"
	box.add_child(_note)
	_photos_row = HBoxContainer.new()
	_photos_row.name = "RecastPhotos"
	_photos_row.add_theme_constant_override("separation", 16)
	_photos_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_photos_row)
	_done_button = Button.new()
	_done_button.name = "RecastDone"
	_done_button.text = "Done (Enter)"
	_done_button.focus_mode = Control.FOCUS_NONE
	_done_button.custom_minimum_size = Vector2(240, 52)
	_done_button.add_theme_font_size_override("font_size", 22)
	_done_button.pressed.connect(done)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_done_button)
	box.add_child(row)


## The photos, as they are: {"status": "shooting", "ready" or "none" (no photos: "why"), "who",
## "faces": [{"texture", "score"}], "pick": the one now their face (-1: none of these yet)}.
func show_state(state: Dictionary) -> void:
	var who := str(state.get("who", "them"))
	var status := str(state.get("status", ""))
	_shooting = status == "shooting"
	_done_button.disabled = _shooting
	var pick := int(state.get("pick", -1))
	match status:
		"shooting":
			_note.text = "The casting photographer's taking %s's photos..." % who
		"ready":
			_note.text = ("%s's new face is framed. Click another to use it instead." % who) if pick >= 0 else ("Click the one you want for %s's face (lower scores split more cleanly), or leave them as they are." % who)
		"none":
			_note.text = "No photos of %s (%s): they keep the face they have." % [who, state.get("why", "?")]
	for child in _photos_row.get_children():
		_photos_row.remove_child(child)
		child.queue_free()
	var faces: Array = state.get("faces", [])
	for k in faces.size():
		var photo := _photo_button("RecastPhoto_%d" % k, faces[k]["texture"])
		photo.tooltip_text = Text.tip(("%s's face on the show (the split's score %.3f: lower is cleaner)" if k == pick else "Use this one for %s's face (the split's score %.3f: lower is cleaner)") % [who, float(faces[k].get("score", 0.0))])
		photo.pressed.connect(func(): face_picked.emit(k))
		_photos_row.add_child(_frame("RecastFrame_%d" % k, photo, k == pick))


## A regular's face on their button, after the PD's picked a new one.
func update_regular(id: String, texture: Texture2D) -> void:
	for column in _regulars_row.get_children():
		for frame in column.get_children():
			if frame is PanelContainer:
				var face := frame.get_child(0) as TextureButton
				if face != null and str(face.get_meta("id", "")) == id:
					face.texture_normal = texture


## Whose face is being recast ("" before one's picked).
func chosen_id() -> String:
	return _chosen


## Closes it (not while photos are being taken).
func done() -> void:
	if _done or _shooting:
		return
	_done = true
	finished.emit()
	queue_free()


func _choose(id: String) -> void:
	if _shooting:
		return
	_chosen = id
	for column in _regulars_row.get_children():
		for frame in column.get_children():
			if frame is PanelContainer:
				var face := frame.get_child(0) as TextureButton
				_style(frame as PanelContainer, face != null and str(face.get_meta("id", "")) == id)
	chosen.emit(id)


func _photo_button(id: String, texture: Texture2D) -> TextureButton:
	var photo := TextureButton.new()
	photo.name = id
	photo.texture_normal = texture
	photo.ignore_texture_size = true
	photo.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo.custom_minimum_size = FACE_SIZE * PHOTO_SCALE
	photo.focus_mode = Control.FOCUS_NONE
	return photo


func _frame(id: String, inside: Control, picked: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = id
	_style(frame, picked)
	frame.add_child(inside)
	return frame


func _style(frame: PanelContainer, picked: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Ktv.PANEL
	style.border_color = RED if picked else Ktv.MUTED
	style.set_border_width_all(5 if picked else 1)
	style.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", style)


func _wrapped(text: String, colour: Color) -> Label:
	var label := Ktv.label(text, 19, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	return label


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_ESCAPE:
		done()
		get_viewport().set_input_as_handled()
