extends RefCounted
## Small drawing helpers for the tent's placeholder art: plain shapes and layers.
## (Shared by the tent's parts: see scripts/bar/.)

const Hooks = preload("res://scripts/test_hooks.gd")


## A plain rectangle, added to parent, that never catches the mouse.
static func rect(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Everything in a node, gone.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## How long a pause or an animation takes: as given, or sped up (or slowed) in tests.
static func scaled(seconds: float) -> float:
	if Hooks.pause_scale_override >= 0.0:
		return seconds * Hooks.pause_scale_override
	return seconds
