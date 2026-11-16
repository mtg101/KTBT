extends RefCounted
## Small drawing helpers for the tent's placeholder art: plain shapes and layers.
## (Shared by the tent's parts: see scripts/bar/.)


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
