extends RefCounted
## The tent's cat: who it is (saved with the bar), where it is now (and who with), drawing it
## and moving it there (prowling under the stools, winding round ankles, out in the street),
## and what the AI's told about it, and checked against. The tent's scene decides when it
## moves, and what happens because of it (moments, thefts); this keeps track and draws.
## (Part 4 of splitting visit.gd: see PLAN.md, "A proper refactor".)

const CatRules = preload("res://scripts/rules/cat_rules.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Layout = preload("res://scripts/bar/layout.gd")

const MOVE_MINUTES := Vector2(25, 60)  # how long the cat stays put

var info := {}  # who it is: name, coat, personality (and its Hangul): {} for a bar without one
var spot := "stove"
var with_guest: Variant = null  # the customer it's on, at the feet of, or begging from (the tent's Guest)
var next_move := 0.0  # game minutes until it moves on
var node: Control
var tween: Tween
var dice: RandomNumberGenerator  # the scenery's (it never shifts the game's own rolls)
var stage_width := 0.0


func _init(scenery_dice: RandomNumberGenerator, width: float) -> void:
	dice = scenery_dice
	stage_width = width


## The cat's name, for counting lines that talk to it (Talk.hint_taken).
func tells() -> Array:
	return [] if info.is_empty() else [str(info["name"]).to_lower()]


func with_name() -> String:
	return str(with_guest.customer["name"]) if with_guest != null else ""


## Where the cat is, for the AI's prompts.
func prompt() -> String:
	if info.is_empty():
		return ""
	return Prompts.describe_cat(info, CatRules.cat_text(str(info["name"]), spot, with_name()))


## Where the cat is, for checking the AI's lines.
func fact() -> Dictionary:
	if info.is_empty():
		return {}
	return {"name": info["name"], "spot": spot, "with": with_name()}


## Moves the cat's shape to its spot (it's hidden while it's out in the street).
func place() -> void:
	if info.is_empty():
		return
	var target := Vector2(150, 222)  # the stove end of the counter
	match spot:
		"counter": target = Vector2(stage_width - 160, 222)
		"stools": target = Vector2(randf_range(Layout.SEAT_X[0] - 120, Layout.SEAT_X[NightRules.SEATS - 1] + 60), 348)
		"street": target = Vector2(stage_width + 80, 348)
		"lap": target = Vector2(Layout.SEAT_X[with_guest.seat] - 20, 282)
		"feet": target = Vector2(Layout.SEAT_X[with_guest.seat] + 18, 348)
		"food": target = Vector2(Layout.SEAT_X[with_guest.seat] + 48, 318)
	node.visible = true
	face_towards(target.x)
	if tween != null and tween.is_valid():
		tween.kill()
	tween = node.create_tween()
	tween.tween_property(node, "position", target, Draw.scaled(1.0)).set_trans(Tween.TRANS_SINE)
	if spot == "street":
		tween.tween_callback(func(): node.visible = spot != "street")
	elif spot in ["stools", "feet"]:
		tween.tween_callback(_prowl)  # it doesn't just sit there


## Faces the cat the way it's going (it's drawn facing right; flipped, it faces left).
func face_towards(to_x: float) -> void:
	if absf(to_x - node.position.x) > 1.0:
		node.scale.x = 1.0 if to_x > node.position.x else -1.0
		(node.get_node("Tag") as Label).scale.x = node.scale.x  # turned back, so the name still reads


## Prowling under the stools: a pause to sniff about, then padding off somewhere else along
## the floor, again and again until it goes somewhere new. Winding round someone's ankles,
## the same but back and forth around their feet. (Scenery dice: see dice.)
func _prowl() -> void:
	if not is_instance_valid(node) or not (spot in ["stools", "feet"]):
		return
	var to: Vector2
	if spot == "feet" and with_guest != null:
		var feet_x: float = Layout.SEAT_X[with_guest.seat] + 18
		to = Vector2(feet_x + dice.randf_range(-34.0, 34.0), 348)
	else:
		to = Vector2(dice.randf_range(Layout.SEAT_X[0] - 120, Layout.SEAT_X[NightRules.SEATS - 1] + 60), 348)
	var pause := dice.randf_range(0.6, 2.4) if spot == "stools" else dice.randf_range(0.2, 0.7)
	var pace := 110.0 if spot == "stools" else 60.0  # pixels a second: ambling, or slow and close
	tween = node.create_tween()
	tween.tween_interval(Draw.scaled(pause))
	tween.tween_callback(face_towards.bind(to.x))
	tween.tween_property(node, "position", to, Draw.scaled(maxf(0.3, node.position.distance_to(to) / pace))).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_prowl)


## A grey-box cat: body, head, ears and tail, in its coat colour (calico and tabby get patches).
func build(stage: Control) -> void:
	node = Control.new()
	node.name = "Cat"
	node.position = Vector2(150, 222)
	node.size = Vector2(46, 28)
	node.z_index = 1  # in front of customers, so it shows on a lap
	node.pivot_offset = node.size / 2  # so flipping it to face left keeps it in place
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.visible = false
	stage.add_child(node)
	for part in [["Tail", Vector2(-10, 10), Vector2(12, 4)], ["Body", Vector2(0, 10), Vector2(32, 16)], ["Head", Vector2(28, 2), Vector2(15, 14)],
			["EarLeft", Vector2(29, -2), Vector2(4, 5)], ["EarRight", Vector2(38, -2), Vector2(4, 5)], ["Patch", Vector2(8, 12), Vector2(10, 7)]]:
		Draw.rect(node, part[1], part[2], Color.WHITE).name = part[0]
	var tag := Label.new()  # its name, above it (centred on the cat, so it stays put when it turns)
	tag.name = "Tag"
	tag.position = Vector2(-77, -24)
	tag.size = Vector2(200, 18)
	tag.pivot_offset = tag.size / 2
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_child(tag)


func paint(label: String) -> void:
	(node.get_node("Tag") as Label).text = label
	var coat := Color(str(CatRules.CAT_COATS.get(info["coat"], "9c7a52")))
	for part in ["Tail", "Body", "Head", "EarLeft", "EarRight"]:
		(node.get_node(part) as ColorRect).color = coat
	var patch := node.get_node("Patch") as ColorRect
	patch.visible = info["coat"] in ["calico", "tabby"]
	patch.color = Color("d9883a") if info["coat"] == "calico" else coat.darkened(0.35)
