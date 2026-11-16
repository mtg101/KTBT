extends RefCounted
## How a dish or drink looks on the table, from a short description on its menu item ("art"):
## what it comes in (the vessel), what's in it (a fill, bits of food), and a garnish. Turned
## into simple shapes, so a new dish (a bar's own, later) gets a picture from its description
## alone. Each dish's bits are scattered the same way every time (from its id).
## art: {"vessel", "fill" (a colour), "bits", "bits_colour", "garnish", "foam"}. Shapes are
## {"kind": "rect" or "ellipse", "pos", "size", "colour"}, drawn in order, in a box of size().
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

## Each vessel: its box (pixels), and where the food sits in it.
const VESSELS := {
	"bottle": {"size": Vector2(14, 34)},
	"glass": {"size": Vector2(14, 34)},
	"kettle": {"size": Vector2(26, 34)},  # makgeolli's yellow aluminium kettle, with a bowl to drink from
	"plate": {"size": Vector2(30, 34), "food": Rect2(3, 17, 24, 10)},
	"pan": {"size": Vector2(34, 34), "food": Rect2(4, 20, 22, 9)},
	"pot": {"size": Vector2(32, 34), "food": Rect2(5, 12, 22, 5)},  # the yellow ramyeon pot, eaten from
	"steel_bowl": {"size": Vector2(30, 34), "food": Rect2(6, 13, 18, 10)},
	"cup": {"size": Vector2(30, 34), "food": Rect2(9, 2, 12, 17)},  # a paper cup, skewers sticking out
	"bowl": {"size": Vector2(30, 34), "food": Rect2(3, 17, 24, 11)},
	"stone_pot": {"size": Vector2(30, 34), "food": Rect2(5, 15, 20, 5)},  # a ttukbaegi: a stew, bubbling
}
const BITS := ["cylinders", "slices", "pancake", "chunks", "noodles", "rolls", "mound", "skewers", "shells", "tofu", "strips"]
const GARNISHES := ["spring_onion", "lettuce", "seaweed", "sesame"]

const PLATE := Color("eae6dc")
const PAN := Color("2b2b31")
const POT := Color("d9b24c")
const STEEL := Color("b9bdc9")
const STONE := Color("4a3428")
const PAPER := Color("efe6d6")
const KETTLE := Color("c9a64a")
const FOAM := Color("fbf5e6")
const GREEN := Color("5fbf5a")


## The box a dish is drawn in.
static func size(art: Dictionary) -> Vector2:
	return VESSELS.get(str(art.get("vessel", "bowl")), VESSELS["bowl"])["size"]


## The shapes for a dish: its vessel, the food in it and the garnish, back to front. colour:
## the item's own colour (a bottle's, a glass's, or the food if there's no bits_colour). id:
## where its bits fall (the same every time).
static func shapes(art: Dictionary, colour: Color, id: String) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(id)
	var out: Array = []
	var vessel := str(art.get("vessel", "bowl"))
	if not VESSELS.has(vessel):
		vessel = "bowl"
	var fill := Color(str(art["fill"])) if art.has("fill") else Color(0, 0, 0, 0)
	var bits_colour := Color(str(art["bits_colour"])) if art.has("bits_colour") else colour
	var food: Rect2 = VESSELS[vessel].get("food", Rect2())
	match vessel:
		"bottle":
			out.append(_rect(Vector2(4, 0), Vector2(6, 9), colour.darkened(0.25)))  # the neck
			out.append(_rect(Vector2(0, 9), Vector2(14, 25), colour))
			out.append(_rect(Vector2(1, 19), Vector2(12, 7), Color("e9f2e4")))  # the label
			out.append(_rect(Vector2(2, 11), Vector2(2, 20), Color(1, 1, 1, 0.25)))  # a shine
		"glass":
			out.append(_rect(Vector2(1, 10), Vector2(12, 24), Color(colour, 0.9)))
			if bool(art.get("foam", false)):
				out.append(_rect(Vector2(1, 6), Vector2(12, 5), FOAM))
			out.append(_rect(Vector2(2, 12), Vector2(1, 20), Color(1, 1, 1, 0.3)))
		"kettle":
			out.append(_rect(Vector2(0, 17), Vector2(3, 9), KETTLE.darkened(0.3)))  # the handle
			out.append(_rect(Vector2(2, 13), Vector2(18, 15), KETTLE))
			out.append(_rect(Vector2(6, 10), Vector2(10, 3), KETTLE.darkened(0.15)))  # the lid
			out.append(_rect(Vector2(10, 8), Vector2(2, 2), KETTLE.darkened(0.3)))
			out.append(_rect(Vector2(19, 15), Vector2(6, 3), KETTLE))  # the spout
			out.append(_rect(Vector2(5, 16), Vector2(3, 4), KETTLE.darkened(0.12)))  # a dent
			out.append(_ellipse(Vector2(9, 27), Vector2(16, 7), colour.darkened(0.08)))  # a bowl of it
			out.append(_ellipse(Vector2(11, 27), Vector2(12, 3), colour))
		"plate", "bowl":
			out.append(_ellipse(Vector2(0, 25), Vector2(30, 9), PLATE if vessel == "plate" else Color("d9d6e8")))
			if art.has("fill"):
				out.append(_ellipse(food.position + Vector2(0, 2), food.size - Vector2(0, 2), fill))
		"pan":
			out.append(_rect(Vector2(28, 25), Vector2(6, 3), PAN.lightened(0.15)))  # the handle
			out.append(_ellipse(Vector2(0, 21), Vector2(30, 12), PAN))
			if art.has("fill"):
				out.append(_ellipse(food.position, food.size, fill))
		"pot":
			if art.has("fill"):
				out.append(_rect(food.position, food.size, fill))  # the broth, at the rim
		"steel_bowl":
			pass  # (the food first: it heaps up over the rim)
		"stone_pot":
			out.append(_ellipse(Vector2(1, 28), Vector2(28, 6), Color("2b2b31")))  # its wooden stand, dark
			if art.has("fill"):
				out.append(_rect(food.position, food.size, fill))  # the stew, at the rim
		"cup":
			pass
	out.append_array(_bits(str(art.get("bits", "")), food, bits_colour, dice))
	match vessel:
		"pot":
			out.append(_rect(Vector2(3, 17), Vector2(26, 15), POT))
			out.append(_rect(Vector2(1, 16), Vector2(30, 3), POT.lightened(0.15)))  # the rim
			out.append(_rect(Vector2(0, 19), Vector2(3, 3), POT.darkened(0.3)))  # handles
			out.append(_rect(Vector2(29, 19), Vector2(3, 3), POT.darkened(0.3)))
			out.append(_rect(Vector2(8, 22), Vector2(4, 4), POT.darkened(0.12)))  # dented, as they all are
		"stone_pot":
			out.append(_rect(Vector2(4, 18), Vector2(22, 12), STONE))
			out.append(_rect(Vector2(3, 17), Vector2(24, 3), STONE.lightened(0.15)))  # the rim
			out.append(_rect(Vector2(1, 19), Vector2(3, 3), STONE.darkened(0.2)))  # its little handles
			out.append(_rect(Vector2(26, 19), Vector2(3, 3), STONE.darkened(0.2)))
		"steel_bowl":
			out.append(_rect(Vector2(4, 21), Vector2(22, 11), STEEL))
			out.append(_rect(Vector2(3, 20), Vector2(24, 2), STEEL.lightened(0.2)))
			out.append(_rect(Vector2(7, 23), Vector2(2, 7), Color(1, 1, 1, 0.35)))
		"cup":
			out.append(_rect(Vector2(8, 18), Vector2(14, 16), PAPER))
			out.append(_rect(Vector2(8, 18), Vector2(14, 2), Color("c9a26b")))  # the broth
	out.append_array(_garnish(str(art.get("garnish", "")), food, dice))
	return out


static func _bits(kind: String, food: Rect2, colour: Color, dice: RandomNumberGenerator) -> Array:
	var out: Array = []
	match kind:
		"cylinders":  # rice cakes
			for _k in 7:
				out.append(_rect(_spot(food, Vector2(6, 3), dice), Vector2(6, 3), colour))
		"slices":  # sundae: dark rounds, flecked
			for _k in 6:
				var at := _spot(food, Vector2(5, 5), dice)
				out.append(_ellipse(at, Vector2(5, 5), colour))
				out.append(_rect(at + Vector2(2, 2), Vector2(1, 1), colour.lightened(0.45)))
		"pancake":
			out.append(_ellipse(food.position - Vector2(1, 1), food.size + Vector2(2, 2), colour))
			for _k in 3:
				out.append(_ellipse(_spot(food, Vector2(4, 3), dice), Vector2(4, 3), colour.darkened(0.25)))  # browned
		"chunks":
			for _k in 7:
				out.append(_rect(_spot(food, Vector2(4, 3), dice), Vector2(4, 3), colour))
		"noodles":
			var x := food.position.x
			while x < food.end.x - 2:
				out.append(_rect(Vector2(x, food.position.y + (1 if int(x) % 4 == 1 else 0)), Vector2(2, 2), colour))
				x += 2
		"rolls":  # gyeran-mari: three slices, each with its roll inside
			for k in 3:
				var at := Vector2(food.position.x + 1 + k * 8, food.position.y)
				out.append(_rect(at, Vector2(7, 8), colour))
				out.append(_rect(at + Vector2(2, 3), Vector2(3, 1), colour.darkened(0.25)))
				out.append(_rect(at + Vector2(3, 5), Vector2(2, 1), Color(GREEN, 0.8)))
		"mound":
			out.append(_ellipse(food.position, food.size, colour))
			out.append(_ellipse(food.position + Vector2(food.size.x * 0.25, 1), Vector2(food.size.x * 0.4, 3), colour.lightened(0.25)))
		"shells":  # clams: pale ovals, each with its dark edge
			for _k in 5:
				var at := _spot(food, Vector2(6, 4), dice)
				out.append(_ellipse(at, Vector2(6, 4), colour.darkened(0.3)))
				out.append(_ellipse(at + Vector2(1, 0), Vector2(4, 3), colour))
		"tofu":  # white squares, with stir-fried kimchi heaped beside them
			for k in 3:
				out.append(_rect(Vector2(food.position.x + 1 + k * 6, food.position.y + 3), Vector2(5, 5), Color("f4f0e4")))
			out.append(_ellipse(Vector2(food.end.x - 7, food.position.y + 1), Vector2(7, 6), colour))
		"strips":  # squid or whelks, in curls
			for _k in 6:
				out.append(_rect(_spot(food, Vector2(5, 2), dice), Vector2(5, 2), colour))
		"skewers":  # odeng: folded fish cake up each stick
			for k in 3:
				var stick := food.position.x + 1 + k * 5
				out.append(_rect(Vector2(stick, food.position.y), Vector2(1, food.size.y), Color("d8c39a")))
				for fold in 3:
					out.append(_rect(Vector2(stick - 2 + (fold % 2) * 2, food.position.y + 3 + fold * 4), Vector2(4, 3), colour))
	return out


static func _garnish(kind: String, food: Rect2, dice: RandomNumberGenerator) -> Array:
	var out: Array = []
	match kind:
		"spring_onion":
			for _k in 4:
				out.append(_rect(_spot(food, Vector2(3, 1), dice), Vector2(3, 1), GREEN))
		"lettuce":  # to wrap it in: ssam
			out.append(_ellipse(Vector2(food.position.x - 4, food.position.y - 3), Vector2(10, 7), Color("7cc46a")))
		"seaweed":
			for _k in 4:
				out.append(_rect(_spot(food, Vector2(2, 2), dice), Vector2(2, 2), Color("1f2a1f")))
		"sesame":
			for _k in 5:
				out.append(_rect(_spot(food, Vector2(1, 1), dice), Vector2(1, 1), Color("f5efe0")))
	return out


## Somewhere in the food's area for a piece this size.
static func _spot(food: Rect2, piece: Vector2, dice: RandomNumberGenerator) -> Vector2:
	return Vector2(dice.randf_range(food.position.x, maxf(food.position.x, food.end.x - piece.x)),
		dice.randf_range(food.position.y, maxf(food.position.y, food.end.y - piece.y))).floor()


static func _rect(pos: Vector2, piece: Vector2, colour: Color) -> Dictionary:
	return {"kind": "rect", "pos": pos, "size": piece, "colour": colour}


static func _ellipse(pos: Vector2, piece: Vector2, colour: Color) -> Dictionary:
	return {"kind": "ellipse", "pos": pos, "size": piece, "colour": colour}
