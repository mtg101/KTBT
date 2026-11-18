extends TextureRect
## The cat in pixel art (tools/art/cat.py: a picture for each coat and pose): curled up asleep
## or sitting up when it's still (cat.gd says which, by where it is), and walking whenever it's
## moving (whatever moves it: prowling, padding off into the street), a frame of its stride
## every so far it goes. Drawn facing right; the cat's node is mirrored to face left. Kept on
## the grid's lines (a pixel 3 on screen, as everything else's), and lit by the hour with the
## cat (its node's material: pixel_light.gd).

const Art = preload("res://scripts/ui/art.gd")

const GRID := 3.0
const PIXELS := Vector2(24, 14)  # a picture, on the grid
const BASE := Vector2(-13, -16)  # on the cat's node (46 x 28): centred on it, its feet on the node's line
const STEP := 12.0  # stage pixels: a frame of the stride every this far it goes
const STILL_AFTER := 0.15  # seconds without moving: still again

var coat := ""
var rest := "sit"  # its pose when still: "sleep" or "sit"
var pose := ""  # the pose showing ("walk_2"...: for the tests)
var _frame := 0
var _last_at := Vector2.INF
var _walked := 0.0
var _still_for := 0.0


## Whether there's art for a coat (else cat.gd draws its shapes).
static func has_art(coat_name: String) -> bool:
	return Art.has("cat/%s_sit" % coat_name)


func _init() -> void:
	name = "Picture"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_parent_material = true  # (lit by the hour with the cat)
	size = PIXELS * GRID
	position = BASE


## Shows a pose ("sleep", "sit", "walk_0"...) in its coat.
func show_pose(which: String) -> void:
	pose = which
	texture = Art.texture("cat/%s_%s" % [coat, which])


## Still, in its resting pose (where it's settled: cat.gd).
func settle(which: String) -> void:
	rest = which
	if not pose.begins_with("walk"):
		show_pose(rest)


func _process(delta: float) -> void:
	var holder := get_parent() as Control
	if holder == null or coat == "":
		return
	var at := holder.position
	if _last_at != Vector2.INF and at.distance_to(_last_at) > 0.01:
		_walked += at.distance_to(_last_at)
		_still_for = 0.0
		if not pose.begins_with("walk"):
			_walked = 0.0
			show_pose("walk_%d" % _frame)
		elif _walked >= STEP:
			_walked = 0.0
			_frame = (_frame + 1) % 4
			show_pose("walk_%d" % _frame)
	else:
		_still_for += delta
		if _still_for >= STILL_AFTER and pose != rest:
			show_pose(rest)
	_last_at = at
	snap()


## Onto the grid's lines, wherever the cat is and whichever way it faces (mirrored about its
## node's middle, the picture's left edge on the stage is the same either way).
func snap() -> void:
	var holder := get_parent() as Control
	if holder == null:
		return
	var left := holder.position + BASE
	var off := Vector2(snappedf(left.x, GRID), snappedf(left.y, GRID)) - left
	position = BASE + Vector2(off.x * (-1.0 if holder.scale.x < 0.0 else 1.0), off.y)
