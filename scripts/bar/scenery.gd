extends RefCounted
## The tent's fixtures, drawn: the drinks fridge, the odeng pot simmering on the stove, the
## karaoke neon across the street (flickering now and then), and steam off a hot dish just set
## down. The tent's scene places them as it builds the stage.
## (Part 11 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Text = preload("res://scripts/rules/text.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Draw = preload("res://scripts/bar/draw.gd")

## Dishes that steam when they're set down (and any stew, pancake, grill or fried dish).
const HOT_DISHES := ["tteokbokki", "odeng", "sundae", "dakgalbi", "pajeon", "ramyeon", "gonggibap", "bokkeumbap"]

var dice: RandomNumberGenerator  # the scenery's (it never shifts the game's own rolls)
var neon: Label  # the karaoke sign on the pillar
var stage_width := 0.0


func _init(scenery_dice: RandomNumberGenerator, width: float) -> void:
	dice = scenery_dice
	stage_width = width


## The drinks fridge at the back, by the stove (the owner's station), behind the owner: a
## glass door lit from inside, with shelves of soju, beer and makgeolli (only what's on the
## menu). Its shelves sit high, so the odeng pot in front doesn't hide them.
func build_fridge(stage: Control) -> void:
	var fridge := Control.new()
	fridge.name = "Fridge"
	fridge.position = Vector2(186, 116)  # just right of the odeng pot
	fridge.size = Vector2(92, 134)
	fridge.mouse_filter = Control.MOUSE_FILTER_STOP
	fridge.tooltip_text = Text.tip("The drinks fridge: soju, beer and makgeolli, ice cold.")
	stage.add_child(fridge)
	Draw.rect(fridge, Vector2.ZERO, Vector2(92, 134), Color("d8dce4"))  # the cabinet
	Draw.rect(fridge, Vector2.ZERO, Vector2(92, 14), Color("c8443a"))  # the header strip
	Draw.rect(fridge, Vector2(6, 18), Vector2(80, 112), Color("23344a"))  # inside
	Draw.rect(fridge, Vector2(6, 18), Vector2(80, 112), Color(0.9, 0.96, 1.0, 0.18))  # its light
	var shelves := [
		["soju", Vector2(7, 20), 6],  # green bottles
		["beer", Vector2(10, 16), 5],  # gold cans
		["makgeolli", Vector2(9, 20), 5],  # white bottles
	]
	for row in shelves.size():
		var drink: String = shelves[row][0]
		var shape: Vector2 = shelves[row][1]
		var count: int = shelves[row][2]
		var floor_y := 18.0 + (row + 1) * 26.0
		var colour := Color(str(Catalogue.find(drink)["color"]))  # (the catalogue's: not every bar's menu has makgeolli)
		var gap := (80.0 - count * shape.x) / (count + 1)
		for k in count:
			var x := 6.0 + gap + k * (shape.x + gap)
			Draw.rect(fridge, Vector2(x, floor_y - shape.y), shape, colour)
			if drink != "beer":  # a neck and a cap on the bottles
				Draw.rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 6), Vector2(4, 6), colour)
				Draw.rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 8), Vector2(4, 2), Color("2e7a44") if drink == "makgeolli" else Color("d8dce4"))
		Draw.rect(fridge, Vector2(6, floor_y), Vector2(80, 2), Color("9aa6b4"))  # the shelf
	var sheen := Polygon2D.new()  # light catching the glass
	sheen.polygon = PackedVector2Array([Vector2(14, 18), Vector2(34, 18), Vector2(16, 130), Vector2(6, 130), Vector2(6, 60)])
	sheen.color = Color(1, 1, 1, 0.1)
	fridge.add_child(sheen)
	Draw.rect(fridge, Vector2(80, 40), Vector2(3, 40), Color("8a8c96"))  # the handle


## The odeng pot, simmering on the stove all night: fish cake skewers poking out of the
## broth, and steam curling up off it.
func build_odeng_pot(stage: Control) -> void:
	var pot := Control.new()
	pot.name = "OdengPot"
	pot.position = Vector2(108, 212)
	pot.mouse_filter = Control.MOUSE_FILTER_STOP
	pot.size = Vector2(60, 32)
	pot.tooltip_text = Text.tip("Odeng: %s" % Catalogue.find("odeng")["desc"])  # (every tent's pot, on the menu or not)
	stage.add_child(pot)
	for k in 4:  # skewers, at a slant
		var skewer := Draw.rect(pot, Vector2(10 + k * 12, -14 + (k % 2) * 4), Vector2(2, 22), Color("d8c49a"))
		skewer.rotation = -0.2 + k * 0.12
		Draw.rect(pot, Vector2(7 + k * 12, -2 + (k % 2) * 4), Vector2(9, 8), Color("c9a26b"))  # a folded fish cake
	Draw.rect(pot, Vector2(0, 6), Vector2(60, 26), Color("8a8c96"))  # the pot (a square metal one)
	Draw.rect(pot, Vector2(-3, 4), Vector2(66, 4), Color("b0b2bc"))  # its rim
	Draw.rect(pot, Vector2(2, 8), Vector2(56, 3), Color("c9a26b", 0.8))  # the broth
	for k in 3:  # steam, rising and fading, one puff after another
		var puff := Draw.rect(pot, Vector2(20 + k * 10, 0), Vector2(10, 10), Color(1, 1, 1, 0.0))
		var rise := puff.create_tween().set_loops()
		rise.tween_interval(k * 0.9)
		rise.tween_property(puff, "position", Vector2(14 + k * 12, -46), 2.7).from(Vector2(20 + k * 10, 0))
		rise.parallel().tween_property(puff, "color:a", 0.0, 2.7).from(0.3)


## A neon sign on the pillar across from the tent: 노래방, karaoke (a kind of place, not a
## name: see CONCEPT.md, "Real people, brands and shows"), flickering now and then.
func build_neon(stage: Control) -> void:
	neon = Ktv.label("노\n래\n방", 22, Color("ff5fa2"), 6, Color("ff5fa2", 0.35))
	neon.name = "Neon"
	neon.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	neon.tooltip_text = Text.tip("노래방 noraebang: a karaoke room across the street, where the night carries on after the pocha.")
	neon.position = Vector2(stage_width - 36, 122)
	neon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(neon)
	dice.randomize()
	_flicker_neon()


## Now and then the neon stutters, the way old signs do, then comes back.
func _flicker_neon() -> void:
	if not is_instance_valid(neon):
		return
	var stutter := neon.create_tween()
	stutter.tween_interval(dice.randf_range(4.0, 14.0))
	for k in dice.randi_range(2, 4):
		stutter.tween_property(neon, "modulate:a", dice.randf_range(0.15, 0.5), 0.05)
		stutter.tween_property(neon, "modulate:a", 1.0, dice.randf_range(0.04, 0.12))
	stutter.tween_callback(_flicker_neon)


## A little steam off a hot dish just set down, for a while.
func steam(shape: Control) -> void:
	for k in 2:
		var puff := Draw.rect(shape, Vector2(9 + k * 7, 12), Vector2(7, 7), Color(1, 1, 1, 0.0))
		puff.name = "Steam"
		var rise := puff.create_tween().set_loops(4)  # (it cools down)
		rise.tween_interval(k * 0.8 + dice.randf_range(0.0, 0.4))
		rise.tween_property(puff, "position", Vector2(6 + k * 9, -18), 2.2).from(Vector2(9 + k * 7, 12))
		rise.parallel().tween_property(puff, "color:a", 0.0, 2.2).from(0.28)
