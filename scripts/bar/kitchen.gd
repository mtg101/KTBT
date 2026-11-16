extends RefCounted
## The stove: one cook, so cooked dishes queue (the first one's on, the rest wait), and when
## one's done it waits by the stove to be carried over; the stove's row of dishes shows what's
## cooking, waiting and ready. And how a dish (or the free banchan) looks on the table.
## The tent's scene decides who orders what and carries it over; this keeps the queue.
## (Part 5 of splitting visit.gd: see PLAN.md, "A proper refactor".)

const Menu = preload("res://scripts/rules/menu.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const DishView = preload("res://scripts/ui/dish_view.gd")
const Text = preload("res://scripts/rules/text.gd")
const Draw = preload("res://scripts/bar/draw.gd")

const BANCHAN := "kimchi and pickled radish"  # free with every first order, never on the bill

var queue: Array = []  # {"guest", "id", "left", "ordered"}: the first is on the stove, the rest wait
var ready: Array = []  # {"guest", "id", "ordered"}: cooked, waiting to be carried over
var stove_row: HBoxContainer  # the dishes by the stove, as you see them


## Puts dishes on to cook, for a guest, ordered at this time (game minutes).
func put_on(guest: Variant, ids: Array, clock: float) -> void:
	for id in ids:
		queue.append({"guest": guest, "id": id, "left": float(Menu.cook_minutes(id)), "ordered": clock})
	update_stove()


## The next dish that's ready, taken off the side to carry over.
func take_ready() -> Dictionary:
	var dish: Dictionary = ready.pop_front()
	update_stove()
	return dish


## One cook: the first dish in the queue cooks; when it's done it waits to be carried over
## and the next one goes on.
func cook(minutes: float) -> bool:
	if queue.is_empty():
		return false
	var changed := false
	queue[0]["left"] -= minutes
	while not queue.is_empty() and float(queue[0]["left"]) <= 0.0:
		var spare := -float(queue[0]["left"])
		var done: Dictionary = queue.pop_front()
		ready.append({"guest": done["guest"], "id": done["id"], "ordered": done["ordered"]})
		if not queue.is_empty():
			queue[0]["left"] -= spare
		changed = true
	if changed:
		update_stove()
	return changed


func update_stove() -> void:
	for child in stove_row.get_children():
		stove_row.remove_child(child)
		child.queue_free()
	for dish in ready:
		var shape := dish_shape(str(dish["id"]))
		shape.tooltip_text += " for %s (ready)" % dish["guest"].customer["name"]
		stove_row.add_child(shape)
	for i in queue.size():
		var dish: Dictionary = queue[i]
		var shape := dish_shape(str(dish["id"]))
		shape.tooltip_text += " for %s (%s)" % [dish["guest"].customer["name"], "cooking" if i == 0 else "waiting"]
		if i > 0:
			shape.modulate = Color(1, 1, 1, 0.5)
		stove_row.add_child(shape)


## A guest's dishes that are on the stove, queued, or ready to carry over.
func food_coming(guest: Variant) -> Array:
	var ids: Array = []
	for dish in queue + ready:
		if dish["guest"] == guest:
			ids.append(dish["id"])
	return ids


## A menu item on the table, drawn from its "art" (what it comes in and what's in it: see
## rules/dish_art.gd), with its name on hover. (Without art: a bottle for a drink, a bowl for
## food, in its colour.)
func dish_shape(id: String) -> Control:
	var item := Menu.find(id)
	var colour := Color(str(item["color"]))
	var art: Dictionary = item.get("art", {"vessel": "bottle"} if item["kind"] == "drink" else {"vessel": "bowl", "fill": str(item["color"])})
	var shape := DishView.new()
	shape.tooltip_text = str(item["name"])
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	shape.custom_minimum_size = DishArt.size(art)
	shape.shapes = DishArt.shapes(art, colour, id)
	return shape


## The free banchan: three little dishes.
func banchan_shape() -> Control:
	var shape := Control.new()
	shape.tooltip_text = Text.tip("Banchan: %s (free)" % BANCHAN)
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	shape.custom_minimum_size = Vector2(26, 34)
	for i in 3:
		Draw.rect(shape, Vector2(i * 9, 25), Vector2(8, 9), Color("c8452f") if i != 1 else Color("efe9cf"))
	return shape
