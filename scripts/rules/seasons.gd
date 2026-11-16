extends RefCounted
## The calendar and the weather: each bar's nights run through the year, one a day, through
## Korea's seasons (with the summer monsoon, 장마 jangma, as a season of its own), and each
## night's weather follows on from the night before: wet spells come in runs, and the first
## snow of each winter is a moment of its own.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]  # (a year with no leap day)
const YEAR_DAYS := 365

## Each season: its name, in Hangul too, and the days of the year it starts on (0 is 1 January).
## The monsoon's late June to late July; the rest are the usual three months each.
const SEASONS := {
	"winter": {"hangul": "겨울", "name": "winter"},
	"spring": {"hangul": "봄", "name": "spring"},
	"summer": {"hangul": "여름", "name": "summer"},
	"monsoon": {"hangul": "장마", "name": "the monsoon"},
	"autumn": {"hangul": "가을", "name": "autumn"},
}
const SEASON_STARTS := [[0, "winter"], [59, "spring"], [151, "summer"], [171, "monsoon"], [206, "summer"], [243, "autumn"], [334, "winter"]]

## Tonight's weather, by season: what it's like (as the prompts and the transcript say it; the
## game reads the kind from the words, see NightRules.weather_kind) and how likely. "from" and
## "to": only between these days of the year (cherry blossom in early April).
const WEATHER := {
	"winter": [
		{"text": "clear, bitterly cold air", "weight": 3.0},
		{"text": "snow falling steadily on the tarp", "weight": 2.0},
		{"text": "a raw, cold wind off the river", "weight": 2.0},
		{"text": "freezing fog", "weight": 1.0},
	],
	"spring": [
		{"text": "a warm spring breeze", "weight": 3.0},
		{"text": "cherry blossom petals on the breeze", "weight": 2.0, "from": 88, "to": 108},
		{"text": "light drizzle", "weight": 2.0},
		{"text": "a mild, clear evening", "weight": 2.0},
		{"text": "yellow dust hazing the streetlights", "weight": 1.0},
	],
	"monsoon": [
		{"text": "monsoon downpour: heavy rain hammering the tarp", "weight": 4.0},
		{"text": "heavy rain drumming on the tarp", "weight": 2.0},
		{"text": "light drizzle", "weight": 2.0},
		{"text": "a muggy summer heat", "weight": 1.0},
	],
	"summer": [
		{"text": "a muggy summer heat", "weight": 4.0},
		{"text": "a sticky, muggy night with thunder far off", "weight": 1.0},
		{"text": "heavy rain drumming on the tarp", "weight": 1.0},
		{"text": "a warm, clear night", "weight": 1.5},
		{"text": "a typhoon's edge: heavy rain and wind", "weight": 0.5, "from": 213},
	],
	"autumn": [
		{"text": "crisp, clear autumn air", "weight": 3.0},
		{"text": "a cool breeze", "weight": 2.0},
		{"text": "thick fog", "weight": 1.0},
		{"text": "light drizzle", "weight": 1.0},
		{"text": "clear, bitterly cold air", "weight": 1.0, "from": 305},
	],
}

## How often a night's weather is the same as the night before's (if it can be, this season).
const SAME_AGAIN_CHANCE := 0.45

## The first snow of each winter: a moment of its own (첫눈 cheonnun: in K-dramas, whoever you
## see the first snow with is the one).
const FIRST_SNOW := "the first snow of winter"


## Today's day of the year (0 to 364), from the computer's clock (29 February counts as the
## 28th).
static func today() -> int:
	var now := Time.get_date_dict_from_system()
	var doy := int(now["day"]) - 1
	for m in int(now["month"]) - 1:
		doy += int(MONTH_DAYS[m])
	return mini(doy, YEAR_DAYS - 1)


## The day of the year (0 to 364) of a bar's night: night 1 is on its first_date, and each
## night is the next day.
static func day_of_year(first_date: int, night: int) -> int:
	return posmod(first_date + night - 1, YEAR_DAYS)


## A day of the year as {"day", "month" (1 to 12), "text" ("14 November"), "season"}.
static func date(doy: int) -> Dictionary:
	var left := posmod(doy, YEAR_DAYS)
	var month := 0
	while left >= MONTH_DAYS[month]:
		left -= MONTH_DAYS[month]
		month += 1
	return {"day": left + 1, "month": month + 1, "text": "%d %s" % [left + 1, MONTHS[month]], "season": season(doy)}


## The season for a day of the year (see SEASON_STARTS).
static func season(doy: int) -> String:
	var found := "winter"
	for start in SEASON_STARTS:
		if posmod(doy, YEAR_DAYS) >= int(start[0]):
			found = str(start[1])
	return found


## Which winter a day belongs to (December with the January after it), for the first snow:
## counted from the bar's first night.
static func winter_number(first_date: int, night: int) -> int:
	return floori((first_date + night - 1 + 31) / float(YEAR_DAYS))  # (from 1 December, a new winter)


## The weather options for a day of the year: its season's, within their dates.
static func options(doy: int) -> Array:
	var day := posmod(doy, YEAR_DAYS)
	return WEATHER[season(doy)].filter(func(option): return day >= int(option.get("from", 0)) and day <= int(option.get("to", YEAR_DAYS)))


## Tonight's weather: the same as last night's now and then (if it can be, this season), or
## one of the season's by weight. roll: one roll (0 to 1) decides both. snowed: whether it's
## snowed yet this winter (if not, the first snow is the first snow).
static func next_weather(doy: int, last: String, roll: float, snowed: bool = true) -> String:
	var choices := options(doy)
	var texts: Array = choices.map(func(option): return str(option["text"]))
	var again := last.replace(FIRST_SNOW, "snow falling steadily on the tarp")
	var picked := ""
	if texts.has(again) and roll < SAME_AGAIN_CHANCE:
		picked = again
	else:
		var rest := (roll - SAME_AGAIN_CHANCE) / (1.0 - SAME_AGAIN_CHANCE) if texts.has(again) else roll
		var total := 0.0
		for option in choices:
			total += float(option["weight"])
		var at := clampf(rest, 0.0, 0.9999) * total
		for option in choices:
			at -= float(option["weight"])
			picked = str(option["text"])
			if at < 0.0:
				break
	if not snowed and picked.contains("snow"):
		return FIRST_SNOW
	return picked


## The season as the prompts say it: "late autumn", "early spring", "the monsoon".
static func season_words(doy: int) -> String:
	var name := season(doy)
	if name == "monsoon":
		return "the monsoon, 장마"
	var day := posmod(doy, YEAR_DAYS)
	var start := 0
	var length := 0
	for k in SEASON_STARTS.size():
		if str(SEASON_STARTS[k][1]) == name and day >= int(SEASON_STARTS[k][0]):
			start = int(SEASON_STARTS[k][0])
			length = (int(SEASON_STARTS[k + 1][0]) if k + 1 < SEASON_STARTS.size() else YEAR_DAYS) - start
	if name == "winter":  # (winter runs over the new year: from 1 December)
		var from_december := posmod(day - 334, YEAR_DAYS)
		return "early winter" if from_december < 30 else ("late winter" if from_december >= 60 else "midwinter")
	var through := float(day - start) / maxf(1.0, float(length))
	return ("early " if through < 0.33 else ("late " if through >= 0.67 else "")) + name
