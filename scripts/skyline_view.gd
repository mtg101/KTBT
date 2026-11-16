extends Control
## The city behind the tent (see rules/skyline.gd for what's in it), drawn in one go: every
## building and window is a rectangle, redrawn only when the game's minute changes. Hover a
## building for what it is (Korean on screen explains itself). The towers' red lights blink by
## themselves.

const Skyline = preload("res://scripts/rules/skyline.gd")
const Text = preload("res://scripts/rules/text.gd")

const APT := Color("17162e")
const TOWER := Color("1a2340")
const CHURCH := Color("1c1a2c")
const CROSS := Color("ff3346")
const TOWER_GLASS := Color("cfe0ff")
const CROWN := Color(0.5, 0.58, 0.84, 0.45)
const NUMBER_SIZE := 11
const CROSS_HEIGHT := 20.0

var ground := 252.0  # where the buildings stand (behind the counter)
var buildings: Array = []
var seed_for := ""  # whose skyline this is (a bar's id)
var _minute := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "The city behind the overpass."  # (each building has its own: see _get_tooltip)


## A new skyline (from Skyline.plan), for this bar.
func show_city(plan: Array, bar_id: String) -> void:
	buildings = plan
	seed_for = bar_id
	for child in get_children():
		child.queue_free()
	for building in buildings:
		if building["kind"] == "tower":
			var light := ColorRect.new()  # the red aviation light, blinking
			light.name = "TowerLight"
			light.color = CROSS
			light.size = Vector2(4, 4)
			light.position = Vector2(float(building["x"]) + float(building["width"]) / 2 - 2, ground - float(building["height"]) - 4)
			light.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(light)
			var blink := light.create_tween().set_loops()
			blink.tween_property(light, "modulate:a", 0.15, 0.9)
			blink.tween_property(light, "modulate:a", 1.0, 0.25)
	_minute = -1
	queue_redraw()


## The time (game minutes): windows go dark as the night goes on. Redrawn once a minute.
func set_minutes(minutes: float) -> void:
	if int(minutes) == _minute:
		return
	_minute = int(minutes)
	queue_redraw()


## How many windows are lit right now (for tests).
func lit_count() -> int:
	var count := 0
	for building in buildings:
		for window in building["windows"]:
			if Skyline.lit(window, float(maxi(_minute, 0))):
				count += 1
	return count


func _draw() -> void:
	var font := get_theme_default_font()  # (the game's, with Hangul)
	var minutes := float(maxi(_minute, 18 * 60))
	for building in buildings:
		var x := float(building["x"])
		var width := float(building["width"])
		var height := float(building["height"])
		var top := ground - height
		match str(building["kind"]):
			"apt":
				draw_rect(Rect2(x, top, width, height), APT)
				draw_rect(Rect2(x, top, width, 3), APT.lightened(0.12))  # the roof's edge
				draw_string(font, Vector2(x, top + 17), Skyline.block_label(int(building["number"])), HORIZONTAL_ALIGNMENT_CENTER, width, NUMBER_SIZE, Skyline.NUMBER_COLOUR)
			"tower":
				draw_rect(Rect2(x, top, width, height), TOWER)
				var stripe := x + 6.0
				while stripe < x + width - 2:
					draw_rect(Rect2(stripe, top + 8, 1, height - 8), Color(TOWER_GLASS, 0.08))  # glass panels
					stripe += 9.0
				draw_rect(Rect2(x, top, width, 6), CROWN)  # a lit crown, with no name on it
			"church":
				draw_rect(Rect2(x, top, width, height), CHURCH)
				var middle := x + width / 2
				draw_rect(Rect2(middle - 7, top - CROSS_HEIGHT - 2, 14, CROSS_HEIGHT + 2), Color(CROSS, 0.12))  # its glow
				draw_rect(Rect2(middle - 1.5, top - CROSS_HEIGHT, 3, CROSS_HEIGHT), CROSS)
				draw_rect(Rect2(middle - 6, top - CROSS_HEIGHT + 5, 12, 3), CROSS)
		for window in building["windows"]:
			if not Skyline.lit(window, minutes):
				continue
			var colour: Color = TOWER_GLASS if building["kind"] == "tower" else (Skyline.TV if window["tv"] else Skyline.WARM)
			draw_rect(Rect2(Vector2(x + float(window["x"]), ground - float(window["y"]) - Skyline.WINDOW.y), Skyline.WINDOW), Color(colour, 0.7))


## What's under the mouse: an APT block (its number explained), an office tower or a church.
func _get_tooltip(at_position: Vector2) -> String:
	for building in buildings:
		var x := float(building["x"])
		var top := ground - float(building["height"]) - (CROSS_HEIGHT if building["kind"] == "church" else 0.0)
		if at_position.x < x or at_position.x > x + float(building["width"]) or at_position.y < top or at_position.y > ground:
			continue
		match str(building["kind"]):
			"apt":
				var label := Skyline.block_label(int(building["number"]))
				return Text.tip("%s: block %d. Every APT (아파트, apateu: an apartment complex) numbers its blocks, painted big on the side. Most of Seoul lives in one." % [label, int(building["number"])])
			"tower":
				return Text.tip("A glass office tower, a big company's headquarters: still lit, because someone's working late (야근, yageun: overtime).")
			"church":
				return Text.tip("A church's red neon cross: there are so many on Seoul's skyline at night they're a sight of their own.")
	return ""
