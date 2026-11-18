extends Control
## A dish or drink on the table, drawn from its shapes (see rules/dish_art.gd): rectangles and
## ellipses, in one go, in pixels (each PIXEL on screen, as the street's grid), so they sit
## with the tent's pixel art.

var shapes: Array = []

const PIXEL := 3.0


func _draw() -> void:
	for shape in shapes:
		var at: Vector2 = shape["pos"]
		var piece: Vector2 = shape["size"]
		var from := (at / PIXEL).floor()
		var to := ((at + piece) / PIXEL).ceil().max(from + Vector2.ONE)
		if shape["kind"] == "ellipse":  # each pixel whose middle is inside it
			var centre := at + piece / 2
			for y in range(int(from.y), int(to.y)):
				for x in range(int(from.x), int(to.x)):
					var d := (Vector2(x + 0.5, y + 0.5) * PIXEL - centre) / (piece / 2).max(Vector2(0.75, 0.75) * PIXEL)
					if d.length_squared() <= 1.0:
						draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2.ONE * PIXEL), shape["colour"])
		else:
			draw_rect(Rect2(from * PIXEL, (to - from) * PIXEL), shape["colour"])
