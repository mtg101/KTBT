extends RefCounted
## A shape drawn in pixels of the grid's size (3 on screen), for things the game shapes as it
## goes (an umbrella's canopy, snow settling on it): each pixel whose middle is inside the shape,
## on its colour's light ramp (lit at the top, in shadow lower down), a dark line round its edge.
## As a Sprite2D, so it can be turned and faded like the shape it stands in for.

const PeopleArt = preload("res://scripts/ui/people_art.gd")

const GRID := 3.0


## points: the shape (its holder's coordinates); scale: the holder's (so its pixels stay the
## grid's size however big the holder's drawn); outline: a dark line round its edge.
static func sprite(points: PackedVector2Array, colour: Color, scale: float = 1.0, outline: bool = true) -> Sprite2D:
	var cell := GRID / maxf(scale, 0.01)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	lo = (lo / cell).floor() * cell
	var cells := Vector2i(((hi - lo) / cell).ceil()) + Vector2i.ONE
	var inside := []
	for y in cells.y:
		var row := []
		for x in cells.x:
			row.append(Geometry2D.is_point_in_polygon(lo + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell, points))
		inside.append(row)
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var ramp: Array = PeopleArt.ramp(Color(colour, 1.0))
	for y in cells.y:
		for x in cells.x:
			if not inside[y][x]:
				continue
			var edge: bool = outline and (x == 0 or y == 0 or x == cells.x - 1 or y == cells.y - 1
				or not inside[y][x - 1] or not inside[y][x + 1] or not inside[y - 1][x] or not inside[y + 1][x])
			var step := 1 if edge else clampi(5 - int(3.0 * y / maxf(cells.y - 1, 1)), 2, 5)
			var shade: Color = ramp[step]
			shade.a = colour.a
			image.set_pixel(x, y, shade)
	var shape := Sprite2D.new()
	shape.texture = ImageTexture.create_from_image(image)
	shape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shape.centered = false
	shape.position = lo
	shape.scale = Vector2.ONE * cell
	return shape
