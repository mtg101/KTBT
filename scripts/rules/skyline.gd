extends RefCounted
## The city behind the tent: a skyline of its own for each bar (from the bar's id, so it's the
## same every night), drawn from rectangles. Rows of APT blocks (아파트, with the block's number
## painted big on the side, as every complex in Korea has), a glass office tower or two with
## a red light on top (nameless: no real company), and now and then a church's red neon cross.
## Windows go dark through the night: busy at nine, a few night owls at two.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const WINDOW := Vector2(5, 4)  # a window, in pixels
const WINDOW_GAP := Vector2(5, 6)  # from one window to the next
const MARGIN := 7.0  # from a building's edge to its first window

## How much of the city's lit, by the hour (the hour it starts; 24 is midnight, 27 is 3am).
const LIT_BY_HOUR := {18: 0.45, 19: 0.6, 20: 0.7, 21: 0.75, 22: 0.68, 23: 0.55, 24: 0.4, 25: 0.25, 26: 0.13, 27: 0.07}
const TV_CHANCE := 0.18  # a window lit by a TV: blue-white, not warm
const WARM := Color("f2c46b")
const TV := Color("a9c4ff")
const NUMBER_COLOUR := Color("8a8fb8")


## The skyline for a stage this wide, from this seed (the bar's id, hashed): a list of
## buildings, left to right, each {"kind" ("apt", "tower" or "church"), "x", "width",
## "height", "number" (an APT block's: 101, 102... ), "windows": [{"x", "y", "dark_at"
## (the share of the city that's lit when it goes dark, 0 to 1), "tv"}]}. Positions are from
## the building's bottom-left; heights go up.
static func plan(width: float, seed_value: int) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var buildings: Array = []
	var x := dice.randf_range(-30.0, 10.0)
	var number := 100 + dice.randi_range(1, 8)
	var towers := 0
	while x < width:
		var roll := dice.randf()
		var building := {}
		if roll < 0.12 and towers < 2 and x > 200.0 and x < width - 200.0:
			towers += 1
			building = {"kind": "tower", "width": dice.randf_range(70.0, 100.0), "height": dice.randf_range(165.0, 215.0)}
		elif roll < 0.2:
			building = {"kind": "church", "width": dice.randf_range(50.0, 70.0), "height": dice.randf_range(55.0, 80.0)}
		else:
			number += 1
			building = {"kind": "apt", "width": dice.randf_range(95.0, 150.0), "height": dice.randf_range(95.0, 150.0), "number": number}
		building["x"] = x
		building["windows"] = _windows(building, dice)
		buildings.append(building)
		x += float(building["width"]) + dice.randf_range(4.0, 26.0)
	return buildings


static func _windows(building: Dictionary, dice: RandomNumberGenerator) -> Array:
	var windows: Array = []
	var top := float(building["height"]) - (26.0 if building["kind"] == "apt" else 12.0)  # (room for the block's number)
	var across := floori((float(building["width"]) - MARGIN * 2 + WINDOW_GAP.x) / (WINDOW.x + WINDOW_GAP.x))
	var y := MARGIN
	while y + WINDOW.y < top:
		for k in across:
			windows.append({"x": MARGIN + k * (WINDOW.x + WINDOW_GAP.x), "y": y, "dark_at": dice.randf(), "tv": dice.randf() < TV_CHANCE})
		y += WINDOW.y + WINDOW_GAP.y
	return windows


## How much of the city's lit at this time (game minutes), between the hours.
static func lit_share(minutes: float) -> float:
	var hour := clampi(floori(minutes / 60.0), 18, 27)
	var next := mini(hour + 1, 27)
	var through := clampf((minutes - hour * 60.0) / 60.0, 0.0, 1.0)
	return lerpf(float(LIT_BY_HOUR[hour]), float(LIT_BY_HOUR[next]), through)


## Whether a window's lit at this time: until the city's share falls to its dark_at.
static func lit(window: Dictionary, minutes: float) -> bool:
	return float(window["dark_at"]) < lit_share(minutes)


## An APT block's number, as painted on its side: "103동" (dong: a block of a complex).
static func block_label(number: int) -> String:
	return "%d동" % number
