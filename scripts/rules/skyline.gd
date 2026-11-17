extends RefCounted
## The city behind the tent: a skyline of its own for each bar (from the bar's id, so it's the
## same every night), drawn from rectangles. Rows of APT blocks (아파트), a glass office tower
## or two with a red light on top (nameless: no real company), now and then a church's red neon
## cross, and shop buildings (상가) with a lit sign on every floor, the way Seoul does it:
## karaoke, a PC bang, chicken and beer, a cram school, a clinic (generic signs, never a
## brand). Windows go dark through the night: busy at nine, a few night owls at two; each
## shop's sign goes off when it shuts (the karaoke and the PC bang never do).
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
const FLOOR := 20.0  # a shop building's floor, in pixels: one sign each

## The signs on a shop building's floors: generic shops (never a brand), each with its colour,
## what it means (for the hover) and when it shuts (game minutes; past 27 * 60: never, tonight).
const SIGNS := [
	{"hangul": "노래방", "means": "noraebang: karaoke rooms", "colour": "ff4fd8", "shuts": 30 * 60},
	{"hangul": "PC방", "means": "PC bang: a gaming café, open all night", "colour": "4fe3ff", "shuts": 30 * 60},
	{"hangul": "치킨", "means": "chikin: fried chicken (and beer)", "colour": "ffd23f", "shuts": 26 * 60},
	{"hangul": "호프", "means": "hopeu: a hof, a beer hall", "colour": "ffb347", "shuts": 27 * 60},
	{"hangul": "당구장", "means": "danggujang: a pool hall", "colour": "6cff8f", "shuts": 26 * 60},
	{"hangul": "학원", "means": "hagwon: a cram school, lessons until late", "colour": "ffffff", "shuts": 22 * 60},
	{"hangul": "병원", "means": "byeongwon: a clinic", "colour": "7fb2ff", "shuts": 20 * 60},
	{"hangul": "약국", "means": "yakguk: a pharmacy", "colour": "6cff8f", "shuts": 22 * 60},
	{"hangul": "고기", "means": "gogi: a Korean barbecue place", "colour": "ff5a3c", "shuts": 25 * 60},
	{"hangul": "사우나", "means": "sauna: a bathhouse, open all night", "colour": "ff8a8a", "shuts": 30 * 60},
	{"hangul": "부동산", "means": "budongsan: an estate agent", "colour": "c8c8ff", "shuts": 21 * 60},
]


## The skyline for a stage this wide, from this seed (the bar's id, hashed): a list of
## buildings, left to right, each {"kind" ("apt", "tower", "church" or "shops"), "x", "width",
## "height", "number" (an APT block's: 101, 102...; for its hover), "signs" (a shop
## building's: one of SIGNS a floor, from the bottom), "windows": [{"x", "y", "dark_at" (the
## share of the city that's lit when it goes dark, 0 to 1), "tv"}]}. Positions are from the
## building's bottom-left; heights go up.
static func plan(width: float, seed_value: int) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var buildings: Array = []
	var x := dice.randf_range(-30.0, 10.0)
	var number := 100 + dice.randi_range(1, 8)
	var towers := 0
	while buildings.is_empty() or float(buildings[-1]["x"]) + float(buildings[-1]["width"]) < width:  # (right across: no gap at the end)
		var roll := dice.randf()
		var building := {}
		if roll < 0.12 and towers < 2 and x > 200.0 and x < width - 200.0:
			towers += 1
			building = {"kind": "tower", "width": dice.randf_range(70.0, 100.0), "height": dice.randf_range(165.0, 215.0)}
		elif roll < 0.2:
			building = {"kind": "church", "width": dice.randf_range(50.0, 70.0), "height": dice.randf_range(55.0, 80.0)}
		elif roll < 0.5:
			var floors := dice.randi_range(4, 7)
			var signs: Array = []
			var choices: Array = range(SIGNS.size())
			for k in floors:
				signs.append(choices.pop_at(dice.randi_range(0, choices.size() - 1)))
			building = {"kind": "shops", "width": dice.randf_range(70.0, 110.0), "height": floors * FLOOR + 6.0, "signs": signs}
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
	if building["kind"] == "shops":
		return windows  # (their signs are their windows)
	var top := float(building["height"]) - 12.0
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


## Whether a shop's sign is still lit at this time (game minutes).
static func sign_lit(sign_index: int, minutes: float) -> bool:
	return minutes < float(SIGNS[sign_index]["shuts"])


## An APT block's number, as its address has it (for its hover): "103동" (dong: a block of a complex).
static func block_label(number: int) -> String:
	return "%d동" % number
