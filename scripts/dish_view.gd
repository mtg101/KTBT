extends Control
## A dish or drink on the table, drawn from its shapes (see rules/dish_art.gd): rectangles and
## ellipses, in one go.

var shapes: Array = []

const ELLIPSE_POINTS := 14


func _draw() -> void:
	for shape in shapes:
		var at: Vector2 = shape["pos"]
		var piece: Vector2 = shape["size"]
		if shape["kind"] == "ellipse":
			var points := PackedVector2Array()
			for k in ELLIPSE_POINTS:
				var turn := TAU * k / ELLIPSE_POINTS
				points.append(at + piece / 2 + Vector2(cos(turn) * piece.x / 2, sin(turn) * piece.y / 2))
			draw_colored_polygon(points, shape["colour"])
		else:
			draw_rect(Rect2(at, piece), shape["colour"])
