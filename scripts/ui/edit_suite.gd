extends Control
## The edit suite: the PD steps in to cut last night's episode before "Previously on…" airs
## (from the loading screen, mid-recap, or early in the night: see visit.gd _step_in). Full
## screen, with the writers' cut already picked, so the PD only changes what they want:
## the episode's title (three the AI drafted, or their own) and the cliffhanger (two or three
## the night can answer, or their own, which plays but nudges nobody in). Nothing's running
## while it's open, so there's no timer. "Cut it" (Enter) airs it; Esc leaves it to the writers.
## Each scene has the faces of who it's about beside it (a moment's in its mood), from the faces
## last night's diary entry kept (none for nights from before they were).

const Story = preload("res://scripts/rules/story.gd")
const Text = preload("res://scripts/rules/text.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Keepsakes = preload("res://scripts/rules/keepsakes.gd")
const Polaroid = preload("res://scripts/ui/polaroid.gd")

## The cut: {"title", "title_by", "cliffhanger" (if the PD chose one), "cliffhanger_by",
## "own_teaser"}; {} leaves it all to the writers.
signal finished(cut: Dictionary)

const RED := Color("ff4f6d")  # the camera's red: the PD's
const WIDTH := 1100.0

var _titles: Array = []  # {"hangul", "english"}: the writers' pick first
var _options: Array = []  # cliffhangers the night can answer: {"kind", "who", "teaser"}
var _title_picks: Array = []  # CheckBoxes: the titles, then "your own"
var _cliff_picks: Array = []  # CheckBoxes: the writers', the options, then "your own"
var _scenes: Array = []  # what "Previously on…" could be made of (Story.scene_options), in the order it happened
var _scene_ticks: Array = []  # CheckBoxes, one a scene
var _ticked: Array = []  # ...the ticked ones, oldest tick first (a fourth drops the oldest)
var _first_ticks: Array = []  # ...as it opened (the pins): unchanged, nothing's rewritten
var own_title: LineEdit
var own_teaser: LineEdit
var problem: Label
var _done := false
const FACE_SIZE := Vector2(48, 60)  # a portrait's 64 x 80, small, beside a scene
const FACES_MOST := 2  # faces beside one scene
var scenes_with_faces := 0  # for the stats and the log


func _init() -> void:
	name = "EditSuite"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the suite's open: nothing behind it gets clicked
	z_index = 40


## Opens it on last night's episode: which it was ("season 1, episode 4": ShowSeasons.words), the drafted titles (the writers' first), the
## writers' teaser, the cliffhangers the night can answer, the scenes it could be made of, and
## the faces its diary entry kept (name -> {"key", "look"}).
func open(episode: String, titles: Array, writers_teaser: String, options: Array, scenes: Array = [], faces: Dictionary = {}) -> void:
	_titles = titles.duplicate(true)
	_options = options.duplicate(true)
	_scenes = scenes.duplicate(true)
	var dim := ColorRect.new()
	dim.color = Color(Ktv.BACKGROUND, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var scroll := ScrollContainer.new()  # (a busy night has a long list of scenes)
	scroll.name = "EditScroll"
	scroll.position = Vector2((1920.0 - WIDTH) / 2.0 - 20, 50)
	scroll.size = Vector2(WIDTH + 40, 1000)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	var heading := Ktv.label("편집실 · THE EDIT SUITE · %s" % episode.to_upper(), 40, Ktv.CREAM, 8)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.tooltip_text = Text.tip(Glossary.hangul_tip("편집실"))
	box.add_child(heading)
	box.add_child(_note("You've stepped in as the PD. The writers' cut is picked: change what you like. Nothing's running while you're in here."))
	box.add_child(_heading("THE TITLE"))
	for k in _titles.size():
		var title: Dictionary = _titles[k]
		var pick := _pick(Story.title_text(title) + ("    (the writers' pick)" if k == 0 else ""), _title_picks)
		if str(title.get("hangul", "")) != "":
			pick.tooltip_text = Text.tip(Glossary.hangul_tip(str(title["hangul"])))
		box.add_child(pick)
	own_title = _own("Your own title", Story.TITLE_MOST, _title_picks, box)
	if not _scenes.is_empty():
		box.add_child(_heading("PREVIOUSLY ON…  (up to %d)" % Story.MAX_SCENES))
		box.add_child(_note("Tick the scenes it's made of: they play in the order they happened. Your pins are ticked; a fourth tick drops the oldest. Nothing ticked: the writers choose."))
		for k in _scenes.size():
			var scene: Dictionary = _scenes[k]
			var tick := CheckBox.new()
			tick.name = "Scene%d" % k
			tick.focus_mode = Control.FOCUS_NONE
			tick.add_theme_font_size_override("font_size", 19)
			tick.add_theme_color_override("checkbox_unchecked_color", Ktv.MUTED)
			tick.add_theme_color_override("checkbox_checked_color", RED)
			tick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var when := NightRules.clock_text(int(scene["at"])) if int(scene["at"]) >= 0 else "all night"
			tick.text = "%s · %s%s" % [when, {"pin": "📌 ", "moment": "💥 "}.get(str(scene["kind"]), ""), Text.shorten(str(scene["text"]), 150)]
			if str(scene["kind"]) == "pin" and _ticked.size() < Story.MAX_SCENES:
				tick.button_pressed = true
				_ticked.append(k)
			tick.toggled.connect(_on_scene_ticked.bind(k))
			_scene_ticks.append(tick)
			var row := HBoxContainer.new()  # (the faces, then the scene)
			row.name = "SceneRow%d" % k
			row.custom_minimum_size = Vector2(WIDTH, 0)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 6)
			var shown := _add_faces(row, scene, faces)
			if shown > 0:
				scenes_with_faces += 1
			row.add_child(tick)
			box.add_child(row)
		_first_ticks = _ticked.duplicate()
	box.add_child(_heading("THE CLIFFHANGER"))
	box.add_child(_pick("«%s»    (the writers')" % writers_teaser, _cliff_picks))
	for option in _options:
		box.add_child(_pick("«%s»" % option["teaser"], _cliff_picks))
	own_teaser = _own("Your own teaser", Story.TEASER_MOST, _cliff_picks, box)
	box.add_child(_note("The game's cliffhangers bring their people in, now and then, as TV does. Your own plays as the teaser, but can't bring anyone in: the game can't tell what it asks."))
	problem = Ktv.label("", 20, RED)
	problem.name = "EditProblem"
	box.add_child(problem)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	var cut_it := _button("CutIt", "✂  Cut it  (Enter)", cut)
	cut_it.add_theme_color_override("font_color", RED)
	buttons.add_child(cut_it)
	buttons.add_child(_button("WritersHaveIt", "Leave it to the writers  (Esc)", leave_it))
	(_title_picks[0] as CheckBox).button_pressed = true
	(_cliff_picks[0] as CheckBox).button_pressed = true


## The faces of who a scene's about (up to FACES_MOST), small, before it: a moment's in its
## mood, anyone else calm; their name on hover. How many it got.
func _add_faces(row: HBoxContainer, scene: Dictionary, faces: Dictionary) -> int:
	var shown := 0
	var mood := str(scene.get("mood", "calm")) if str(scene.get("kind", "")) == "moment" else "calm"
	for person in scene.get("who", []):
		if shown >= FACES_MOST:
			break
		var face := Keepsakes.face(faces, str(person), mood)
		var picture := Polaroid.picture_of(face) if not face.is_empty() else null
		if picture == null:
			continue
		var rect := TextureRect.new()
		rect.name = "SceneFace"
		rect.texture = picture
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = FACE_SIZE
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_PASS
		rect.tooltip_text = Text.tip(str(face["name"]))
		rect.set_meta("who", str(face["name"]))
		row.add_child(rect)
		shown += 1
	if not faces.is_empty() and shown < FACES_MOST:  # (the scenes still line up, faces or not)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2((FACES_MOST - shown) * (FACE_SIZE.x + 6) - 6, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	return shown


func _heading(text: String) -> Label:
	var label := Ktv.label(text, 24, Ktv.ORANGE)
	return label


func _note(text: String) -> Label:
	var label := Ktv.label(text, 19, Ktv.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	return label


## A choice in a group (only one ticked at a time).
func _pick(text: String, group: Array) -> CheckBox:
	var pick := CheckBox.new()
	pick.text = text
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", 21)
	pick.add_theme_color_override("checkbox_unchecked_color", Ktv.MUTED)  # (the empty circle, visible on the dark)
	pick.add_theme_color_override("checkbox_checked_color", RED)
	if group.is_empty():
		pick.button_group = ButtonGroup.new()
	else:
		pick.button_group = (group[0] as CheckBox).button_group
	pick.name = "Pick%d" % group.size()
	group.append(pick)
	return pick


## "Your own": a choice with a box to write in (typing ticks it).
func _own(label: String, most: int, group: Array, box: VBoxContainer) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var pick := _pick(label + ":", group)
	row.add_child(pick)
	var typed := LineEdit.new()
	typed.name = label.replace(" ", "")
	typed.max_length = most
	typed.custom_minimum_size = Vector2(WIDTH - 260, 0)
	typed.text_changed.connect(func(_text): pick.button_pressed = true)
	typed.text_submitted.connect(func(_text): cut())
	row.add_child(typed)
	box.add_child(row)
	return typed


func _button(button_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button


## A scene ticked or unticked: three at most, a fourth dropping the oldest tick.
func _on_scene_ticked(on: bool, k: int) -> void:
	_ticked.erase(k)
	if on:
		_ticked.append(k)
		if _ticked.size() > Story.MAX_SCENES:
			var oldest: int = _ticked.pop_front()
			(_scene_ticks[oldest] as CheckBox).set_pressed_no_signal(false)


## Ticks (or unticks) scene k, as a click would.
func tick_scene(k: int, on: bool = true) -> void:
	(_scene_ticks[k] as CheckBox).button_pressed = on


## The scenes ticked now, in the order they happened.
func ticked_scenes() -> Array:
	var order := _ticked.duplicate()
	order.sort()
	return order.map(func(k): return _scenes[k])


## Ticks title k (the last: your own) or cliffhanger k (0: the writers'; the last: your own).
func pick_title(k: int) -> void:
	(_title_picks[k] as CheckBox).button_pressed = true


func pick_cliffhanger(k: int) -> void:
	(_cliff_picks[k] as CheckBox).button_pressed = true


func _picked(group: Array) -> int:
	for k in group.size():
		if (group[k] as CheckBox).button_pressed:
			return k
	return 0


## "Cut it": checks what was written, then sends the cut out.
func cut() -> void:
	if _done:
		return
	var chosen := {"title_by": "writers", "cliffhanger_by": "writers", "own_teaser": false}
	var t := _picked(_title_picks)
	if t == _titles.size():  # (your own)
		var checked := Story.check_typed(own_title.text, Story.TITLE_MOST, false)
		if str(checked["problem"]) != "":
			problem.text = "The title: " + str(checked["problem"])
			return
		chosen["title"] = {"hangul": "", "english": str(checked["text"])}
		chosen["title_by"] = "pd"
	else:
		chosen["title"] = _titles[t]
		chosen["title_by"] = "writers" if t == 0 else "pd"
	var now := _ticked.duplicate()
	now.sort()
	var first := _first_ticks.duplicate()
	first.sort()
	if not now.is_empty() and now != first:  # (changed, and not to nothing: the PD's scenes, so it's rewritten)
		chosen["scenes"] = ticked_scenes()
		chosen["scenes_by"] = "pd"
	var c := _picked(_cliff_picks)
	if c == _options.size() + 1:  # (your own)
		var checked := Story.check_typed(own_teaser.text, Story.TEASER_MOST, true)
		if str(checked["problem"]) != "":
			problem.text = "The teaser: " + str(checked["problem"])
			return
		chosen["cliffhanger"] = {"kind": "other", "who": [], "teaser": str(checked["text"])}
		chosen["cliffhanger_by"] = "pd"
		chosen["own_teaser"] = true
	elif c > 0:
		chosen["cliffhanger"] = _options[c - 1]
		chosen["cliffhanger_by"] = "pd"
	_finish(chosen)


## Esc: the writers' cut, as if the PD had never stepped in.
func leave_it() -> void:
	if not _done:
		_finish({})


func _finish(chosen: Dictionary) -> void:
	_done = true
	finished.emit(chosen)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		cut()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		leave_it()
		get_viewport().set_input_as_handled()
