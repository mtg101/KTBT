extends Control
## A dish or drink on the table in pixel art, painted from its shapes (rules/dish_art.gd: what
## it comes in, the food in it, the garnish), so a bar's own dishes get a picture from their
## description alone. Each shape fills the grid's pixels whose middles are inside it (each
## PIXEL on screen, as the tent's art), on its colour's light ramp: lit from above (its top
## row a step up, its bottom row a step down), a darker edge round the whole dish so it reads
## on the counter, and a shine (a see-through white) brightening what's under it. Painted once
## for each look (CACHE), kept on the grid's lines wherever its row puts it, and lit by the
## hour with the tent (pixel_light.gd).

const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")

const PIXEL := 3.0
const BASE := 4  # a ramp's step in plain light (people_art.gd LEVELS)

static var _cache := {}  # the shapes (as text) -> ImageTexture

var shapes: Array = []:
	set(value):
		shapes = value
		picture = null
		queue_redraw()
var picture: ImageTexture  # (painted when first drawn: for the tests)


func _init() -> void:
	PixelLight.light(self, "tent")
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()  # (moved along its row: back onto the grid's lines)


func _draw() -> void:
	if picture == null:
		picture = paint(shapes)
	if picture == null:
		return
	var at := get_global_transform().origin
	var off := Vector2(snappedf(at.x, PIXEL), snappedf(at.y, PIXEL)) - at  # (the stage sits on the grid's lines)
	draw_texture_rect(picture, Rect2(off, Vector2(picture.get_size()) * PIXEL), false)


## The dish's picture: its shapes painted into the grid's pixels, on their ramps. Null for none.
static func paint(dish_shapes: Array) -> ImageTexture:
	if dish_shapes.is_empty():
		return null
	var key := str(dish_shapes)
	if _cache.has(key):
		return _cache[key]
	var cells := Vector2i.ZERO
	for shape in dish_shapes:
		var end: Vector2 = (shape["pos"] + shape["size"]) / PIXEL
		cells = cells.max(Vector2i(ceili(end.x), ceili(end.y)))
	var base := {}  # Vector2i -> the colour it's made of (for the edge)
	var step := {}  # Vector2i -> its step on that colour's ramp
	var image := Image.create(maxi(cells.x, 1), maxi(cells.y, 1), false, Image.FORMAT_RGBA8)
	for shape in dish_shapes:
		var colour: Color = shape["colour"]
		var spots := _cells(shape)
		if spots.is_empty():
			continue
		var top := spots[0].y
		var bottom := spots[0].y
		for spot in spots:
			top = mini(top, spot.y)
			bottom = maxi(bottom, spot.y)
		for spot in spots:
			if spot.x < 0 or spot.y < 0 or spot.x >= image.get_width() or spot.y >= image.get_height():
				continue
			if colour.a < 0.6:  # a shine or a see-through glaze: brightens (or tints) what's under it
				var under := image.get_pixelv(spot)
				image.set_pixelv(spot, under.lerp(Color(colour, 1.0), colour.a) if under.a > 0.0 else colour)
				continue
			var lit := BASE
			if bottom - top >= 1:  # (lit from above: the top a step up, the bottom a step down)
				lit = BASE + 1 if spot.y == top else (BASE - 1 if spot.y == bottom else BASE)
			base[spot] = Color(colour, 1.0)
			step[spot] = lit
			var painted: Color = PeopleArt.ramp(Color(colour, 1.0))[lit]
			painted.a = colour.a
			image.set_pixelv(spot, painted)
	# A darker edge round the whole dish (where it meets the counter or the air).
	for spot: Vector2i in base:
		for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = spot + side
			if next.x < 0 or next.y < 0 or next.x >= image.get_width() or next.y >= image.get_height() or image.get_pixelv(next).a == 0.0:
				var edge: Color = PeopleArt.ramp(base[spot])[maxi(0, mini(int(step[spot]), BASE - 1) - 1)]
				edge.a = image.get_pixelv(spot).a
				image.set_pixelv(spot, edge)
				break
	var made := ImageTexture.create_from_image(image)
	_cache[key] = made
	return made


## The grid's pixels a shape fills: every pixel whose middle is inside it (an ellipse's), or that
## it covers (a rectangle's, at least one).
static func _cells(shape: Dictionary) -> Array[Vector2i]:
	var at: Vector2 = shape["pos"]
	var piece: Vector2 = shape["size"]
	var from := (at / PIXEL).floor()
	var to := ((at + piece) / PIXEL).ceil().max(from + Vector2.ONE)
	var out: Array[Vector2i] = []
	for y in range(int(from.y), int(to.y)):
		for x in range(int(from.x), int(to.x)):
			if shape["kind"] == "ellipse":
				var centre := at + piece / 2
				var d := (Vector2(x + 0.5, y + 0.5) * PIXEL - centre) / (piece / 2).max(Vector2(0.75, 0.75) * PIXEL)
				if d.length_squared() > 1.0:
					continue
			out.append(Vector2i(x, y))
	return out
