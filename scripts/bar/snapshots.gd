extends RefCounted
## Real snapshots of the stage, for the customers' posts (rules/socials.gd): when something worth
## a post happens, a small crop of the tent as it is (the dish as it's set down, someone at their
## stool, the cat mid-theft), with nothing of the show's on it: no bubbles, captions, name tags,
## REC or panels. How: a camera (a SubViewport) sharing the window's 2D world, so it draws the
## same scene, but with a cull mask leaving out the KEEP_OUT layer, which everything that's
## never in a shot is put on (keep_out says what, walked to its last child: on the window,
## nothing changes). Rendered once, read back after the frame's drawn, and kept in memory
## (shots) until 3am picks the posts and the visit saves theirs beside the bar's save. No
## screen (headless, as the tests run): no snapshot, and the post's picture is drawn instead.

const DebugLog = preload("res://scripts/debug_log.gd")

const SIZE := Vector2i(300, 200)  # a crop, in the stage's own pixels (each art pixel 3 of these)
const MOST := 16  # snapshots a night: past this, none (the last ones are rarely picked)
const KEEP_OUT := 1 << 19  # the visibility layer for what's never in a shot
const IN_SHOT := 0xFFFFF & ~KEEP_OUT  # the camera's cull mask: every layer but that

var host: Control  # the tent's scene: its viewport, and where the camera goes
var stage: Control  # the tent: crops stay inside it
var keep_out: Callable = func(): return []  # -> the CanvasItems never in a shot (and everything under them)
var shots := {}  # key (Socials.snap_key) -> Image
## asked, taken, failed (nobody to aim at, or nothing read back), over (past MOST), no_screen
var counts := {"asked": 0, "taken": 0, "failed": 0, "over": 0, "no_screen": 0}
var _waiting := {}


## Whether there's a screen to take pictures of (no: headless).
static func can_render() -> bool:
	return DisplayServer.get_name() != "headless"


## The crop round a point (global), as big as SIZE, kept inside within (the stage), on whole pixels.
static func region(centre: Vector2, within: Rect2, size: Vector2 = Vector2(SIZE)) -> Rect2:
	var at := centre - size / 2.0
	at.x = clampf(at.x, within.position.x, maxf(within.position.x, within.end.x - size.x))
	at.y = clampf(at.y, within.position.y, maxf(within.position.y, within.end.y - size.y))
	return Rect2(at.round(), size)


## A snapshot for key, of whatever aim points at (-> a global point, or null if they've gone),
## after delay seconds. Once a key; never past MOST a night.
func take(key: String, aim: Callable, delay: float = 0.0) -> void:
	if key == "" or shots.has(key) or _waiting.has(key):
		return
	if shots.size() + _waiting.size() >= MOST:
		counts["over"] += 1
		DebugLog.say("Socials", "no snapshot of %s: %d tonight already" % [key, MOST])
		return
	counts["asked"] += 1
	if not can_render():
		counts["no_screen"] += 1
		DebugLog.say("Socials", "no snapshot of %s: no screen to take it from (its post's picture will be drawn)" % key)
		return
	_waiting[key] = true
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout
	if not is_instance_valid(host) or not host.is_inside_tree():
		_waiting.erase(key)
		return
	var centre: Variant = aim.call()
	if not centre is Vector2:
		_failed(key, "nobody to aim at")
		return
	var rect := region(centre, stage.get_global_rect())
	for item in keep_out.call():
		_keep_out_of_shots(item)
	var camera := SubViewport.new()
	camera.name = "SnapshotCamera"
	camera.size = SIZE
	camera.disable_3d = true
	camera.world_2d = host.get_viewport().world_2d  # (the same scene as the window)
	camera.canvas_cull_mask = IN_SHOT
	camera.canvas_transform = Transform2D(0.0, -rect.position)
	camera.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(camera)
	await RenderingServer.frame_post_draw
	var image: Image = camera.get_texture().get_image() if is_instance_valid(camera) else null
	if is_instance_valid(camera):
		camera.queue_free()
	if image == null or image.is_empty():
		_failed(key, "nothing read back")
		return
	_waiting.erase(key)
	shots[key] = image
	counts["taken"] += 1
	DebugLog.say("Socials", "snapshot of %s: %dx%d at %d,%d" % [key, SIZE.x, SIZE.y, int(rect.position.x), int(rect.position.y)])


## Something and everything under it, never in a shot (it still shows on the window).
static func _keep_out_of_shots(item: Variant) -> void:
	if not item is Node or not is_instance_valid(item):
		return
	if item is CanvasItem:
		(item as CanvasItem).visibility_layer = KEEP_OUT
	for child in (item as Node).get_children():
		_keep_out_of_shots(child)


func _failed(key: String, why: String) -> void:
	_waiting.erase(key)
	counts["failed"] += 1
	DebugLog.say("Socials", "no snapshot of %s: %s" % [key, why])
