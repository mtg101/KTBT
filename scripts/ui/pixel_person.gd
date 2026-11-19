extends Control
## A person in pixel art, one way round (people_art.gd's picture): kept on the grid's lines as
## they move (each pixel 3 on screen, as the tent's and the street's, so they never shimmer
## between them), breathing (now and then their head and shoulders rise a pixel and settle,
## their legs or the seat staying put, so nobody's frozen), and bobbing gently whenever they're
## moving (facing us: up a pixel and down again every so far they go, whatever moves them: the
## street, coming in, leaving, the owner going along the counter).

const GRID := 3.0
const BREATH_SECONDS := Vector2(2.6, 4.2)  # a breath every so often (each person their own)
const BREATH_IN := 0.9  # ...held up this long

const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const STEP := 20.0  # on the stage: a frame of the stride (or up or down a pixel, gliding) every this far they go
const STILL_AFTER := 0.12  # seconds without moving: standing again

## Poses for a big moment's mood (people_view.gd pose): a laugh shakes their shoulders, a sad
## one slumps them, a shock jolts them up, a warm or sweet one's a nod, an awkward one a fidget.
const POSES := {"funny": 1.4, "roast": 1.4, "sad": 8.0, "shock": 0.35, "warm": 0.8, "sweet": 0.8, "awkward": 1.0}

var split := 20  # the rows above this rise (head and shoulders); the rest stay
var pose_mood := ""  # the pose they're in now ("" for none: for the tests)
var _pose_left := 0.0
var walk_frame := -1  # the bob's frame showing (0 down, 1 up), or -1 standing still (for the tests)
var _walker: TextureRect  # walking: the frames (from the side, or facing us gliding; none from behind: seated)
var _strides := false  # walking from the side (else gliding facing us)
var facing_left := false  # walking leftwards (the side view mirrored: for the tests)
var _frames: Array = []
var _last_at := Vector2.INF
var _walked := 0.0
var _still_for := 0.0
var breathing := 0.0  # 0 or 1: up a pixel (for the tests)
## Leaning (radians, + to the right, as people_view.gd lean says): pixel people are never turned
## (turned pixels shimmer), so their head and shoulders lean over a pixel or two instead, or
## the whole of them, walking.
var lean := 0.0
const LEAN_PIXELS := 30.0  # pixels of the grid to a radian of leaning (0.07, a tipsy sway: 2)
var _upper: TextureRect
var _own: Texture2D  # their picture, as they usually are (a gesture shows another for a moment)
var _steps: Array = []  # a gesture: [picture, seconds], one after another, then their own again
var _step_left := 0.0
var gesture := ""  # (for the tests: the picture showing now, "" for their own)
var _lower: TextureRect
var _next_breath := 0.0
var _clock := 0.0


## picture: the person (people_art.gd), split: the first row that stays put; walks: whether
## they walk this way round (facing us).
## stride: the side view's frames to walk in (people_art.gd side_frames; [] glides with a bob).
func _init(picture: Texture2D, rows_up: int, walks: bool = false, stride: Array = []) -> void:
	split = rows_up
	_own = picture
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelLight.light(self, "people")  # (lit by the hour, wherever they are: pixel_light.gd; their parts share it)
	size = picture.get_size() * GRID
	_lower = _part(picture, Rect2(0, split - 1, picture.get_width(), picture.get_height() - split + 1))  # (a row more: no gap when the top rises)
	_upper = _part(picture, Rect2(0, 0, picture.get_width(), split))
	_next_breath = randf_range(0.0, BREATH_SECONDS.y)
	if walks:
		_frames = stride if not stride.is_empty() else PeopleArt.walk_frames(picture)
		_strides = not stride.is_empty()
		_walker = _part(picture, Rect2(Vector2.ZERO, picture.get_size()))
		_walker.visible = false


func _part(picture: Texture2D, region: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = picture
	atlas.region = region
	var part := TextureRect.new()
	part.texture = atlas
	part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	part.stretch_mode = TextureRect.STRETCH_SCALE
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.position = region.position * GRID
	part.size = region.size * GRID
	part.use_parent_material = true
	add_child(part)
	return part


func _process(delta: float) -> void:
	_clock += delta
	if not _steps.is_empty() or _step_left > 0.0:
		_step_left -= delta
		if _step_left <= 0.0:
			_next_step()
	if _clock >= _next_breath:
		breathing = 1.0 if breathing == 0.0 else 0.0
		_next_breath = _clock + (BREATH_IN if breathing == 1.0 else randf_range(BREATH_SECONDS.x, BREATH_SECONDS.y))
	var upper_y := -GRID * breathing
	var nudge := Vector2.ZERO
	if _pose_left > 0.0:
		_pose_left -= delta
		var t: float = POSES[pose_mood] - _pose_left  # (how long they've been in it)
		match pose_mood:
			"funny", "roast":  # shoulders shaking
				upper_y = -GRID * (int(t * 10.0) % 2)
			"sad":  # slumped, head down
				upper_y = GRID * 2
			"shock":  # jolted up off their feet or seat
				nudge.y = -GRID * 2
			"warm", "sweet":  # a nod or two
				upper_y = GRID * (int(t * 5.0) % 2)
			"awkward":  # a fidget, side to side
				nudge.x = GRID * (1 if int(t * 8.0) % 2 == 0 else -1)
		if _pose_left <= 0.0:
			pose_mood = ""
	_upper.position = Vector2(lean_x(), upper_y)
	_walk(delta)
	snap()
	position += nudge


## A gesture: other pictures for a moment (people_art.gd: a glass raised, a mouthful, a hand to
## the head), each for its seconds ([picture, seconds, name]...), then their own again.
func show_steps(steps: Array) -> void:
	_steps = steps.duplicate()
	_step_left = 0.0
	_next_step()


func _next_step() -> void:
	if _steps.is_empty():
		_show(_own)
		gesture = ""
		_step_left = 0.0
		return
	var step: Array = _steps.pop_front()
	_show(step[0] if step[0] != null else _own)  # (null: their own picture, between frames)
	_step_left = float(step[1])
	gesture = str(step[2]) if step.size() > 2 else ""


func _show(picture: Texture2D) -> void:
	for part in [_upper, _lower]:
		(part.texture as AtlasTexture).atlas = picture


## How far over they're leaning, on the screen: whole pixels of the grid, three at most.
func lean_x() -> float:
	return GRID * clampi(roundi(lean * LEAN_PIXELS), -3, 3)


## A big moment's mood, in their pose for a while (POSES); one they haven't got, nothing.
func pose(mood: String) -> void:
	if not POSES.has(mood):
		return
	pose_mood = mood
	_pose_left = float(POSES[mood])
	breathing = 0.0


## The bob's frame for however far they've gone; standing again once they stop.
func _walk(delta: float) -> void:
	if _walker == null:
		return
	var holder := get_parent().get_parent() as Control if get_parent() != null else null
	if holder == null:
		return
	var at := holder.position
	var moved := 0.0 if _last_at == Vector2.INF else at.distance_to(_last_at)
	_last_at = at
	if moved > 0.01:
		_walked += moved
		_still_for = 0.0
		if absf(_dx(at)) > 0.01:
			facing_left = _dx(at) < 0.0
	else:
		_still_for += delta
	var walking := _still_for < STILL_AFTER and _walked > 0.0
	walk_frame = int(_walked / STEP) % _frames.size() if walking else -1
	_walker.visible = walking
	_upper.visible = not walking
	_lower.visible = not walking
	if walking:
		_walker.position.x = lean_x()
		_walker.texture = _frames[walk_frame]
		_walker.flip_h = _strides and facing_left
	_hold_phone(holder, walking and _strides)
	_prev_x = at.x


## A phone in their hand: held up at the chest facing us, and in front of their face from the
## side, on whichever side they're walking towards (its screen's light with it).
const PHONE_SIDE_X := 66.0  # walking right: the phone's left edge (the person's 96 wide), in the hand (people.py PHONE_HAND_SIDE)
const PHONE_SIDE_Y := 57.0
const GLOW_SIDE_X := 54.0
const PHONE_FRONT_Y := 78.0  # facing us, the phone's top, the tallest (people_view.gd add_phone)


func _hold_phone(holder: Control, side: bool) -> void:
	var phone := holder.get_node_or_null("Phone") as Control
	if phone == null:
		return
	var glow := holder.get_node_or_null("PhoneGlow") as Control
	if not phone.has_meta("front_at"):
		phone.set_meta("front_at", phone.position)
		if glow != null:
			glow.set_meta("front_at", glow.position)
	if not side:
		phone.position = phone.get_meta("front_at")
		if glow != null:
			glow.position = glow.get_meta("front_at")
		return
	var width := holder.size.x if holder.size.x > 0.0 else 96.0
	var down := float(phone.get_meta("front_at").y) - PHONE_FRONT_Y  # (a shorter person's hand is lower: as far as facing us)
	phone.position = Vector2(width - PHONE_SIDE_X - phone.size.x if facing_left else PHONE_SIDE_X, PHONE_SIDE_Y + down)
	if glow != null:
		glow.position = Vector2(width - GLOW_SIDE_X - glow.size.x if facing_left else GLOW_SIDE_X, glow.get_meta("front_at").y)


var _prev_x := INF


## Which way they went across, this frame.
func _dx(at: Vector2) -> float:
	return 0.0 if _prev_x == INF else at.x - _prev_x


## Onto the grid's lines: wherever the person is (moving or not), their pixels land on the grid.
func snap() -> void:
	var holder := get_parent().get_parent() as Control  # (the person: Person/Look/this)
	if holder == null:
		return
	var at := holder.position
	position = Vector2(snappedf(at.x, GRID), snappedf(at.y, GRID)) - at
