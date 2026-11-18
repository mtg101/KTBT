extends Control
## A person in pixel art, one way round (people_art.gd's picture): kept on the grid's lines as
## they move (each pixel 3 on screen, as the tent's and the street's, so they never shimmer
## between them), breathing (now and then their head and shoulders rise a pixel and settle,
## their legs or the seat staying put, so nobody's frozen), and walking whenever they're moving
## (facing us: four frames, a step every so far they go, whatever moves them: the street, coming
## in, leaving, the owner going along the counter).

const GRID := 3.0
const BREATH_SECONDS := Vector2(2.6, 4.2)  # a breath every so often (each person their own)
const BREATH_IN := 0.9  # ...held up this long

const PeopleArt = preload("res://scripts/ui/people_art.gd")
const STEP := 16.0  # on the stage: a frame of the walk every this far they go
const STILL_AFTER := 0.12  # seconds without moving: standing again

var split := 20  # the rows above this rise (head and shoulders); the rest stay
var walk_frame := -1  # the walk's frame showing, or -1 standing (for the tests)
var _walker: TextureRect  # walking, facing us: the frames (none from behind: seated)
var _frames: Array = []
var _last_at := Vector2.INF
var _walked := 0.0
var _still_for := 0.0
var breathing := 0.0  # 0 or 1: up a pixel (for the tests)
var _upper: TextureRect
var _lower: TextureRect
var _next_breath := 0.0
var _clock := 0.0


## picture: the person (people_art.gd), split: the first row that stays put; walks: whether
## they walk this way round (facing us).
func _init(picture: Texture2D, rows_up: int, walks: bool = false) -> void:
	split = rows_up
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = picture.get_size() * GRID
	_lower = _part(picture, Rect2(0, split - 1, picture.get_width(), picture.get_height() - split + 1))  # (a row more: no gap when the top rises)
	_upper = _part(picture, Rect2(0, 0, picture.get_width(), split))
	_next_breath = randf_range(0.0, BREATH_SECONDS.y)
	if walks:
		_frames = PeopleArt.walk_frames(picture)
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
	add_child(part)
	return part


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= _next_breath:
		breathing = 1.0 if breathing == 0.0 else 0.0
		_next_breath = _clock + (BREATH_IN if breathing == 1.0 else randf_range(BREATH_SECONDS.x, BREATH_SECONDS.y))
	_upper.position.y = -GRID * breathing
	_walk(delta)
	snap()


## A step's frame for however far they've gone; standing again once they stop.
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
	else:
		_still_for += delta
	var walking := _still_for < STILL_AFTER and _walked > 0.0
	walk_frame = int(_walked / STEP) % _frames.size() if walking else -1
	_walker.visible = walking
	_upper.visible = not walking
	_lower.visible = not walking
	if walking:
		_walker.texture = _frames[walk_frame]


## Onto the grid's lines: wherever the person is (moving or not), their pixels land on the grid.
func snap() -> void:
	var holder := get_parent().get_parent() as Control  # (the person: Person/Look/this)
	if holder == null:
		return
	var at := holder.position
	position = Vector2(snappedf(at.x, GRID), snappedf(at.y, GRID)) - at
