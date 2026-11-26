extends RefCounted
## The night: the clock, who arrives when, how fast time runs, the days of the week, passers-
## by, the sky's light and the weather.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

## The tent opens at 6pm and closes at 3am. Times are minutes since midnight at the start of
## the night, so 3am is 27 * 60. Nobody new arrives after LAST_ARRIVAL.
const OPEN_MINUTES := 18 * 60


const CLOSE_MINUTES := 27 * 60


## Closing up early (visit.gd _close_early): whoever's at the counter has at most this many game
## minutes left to finish what they've got (no more orders, no new chats), then they settle up
## and go, goodbyes and all. Not thrown out, but not lingering for another hour either (26 Nov:
## the last customer took ages, and the player wondered what was going on).
const CLOSING_UP_MINUTES := 15.0


const LAST_ARRIVAL_MINUTES := 26 * 60 + 30  # 2:30am


const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


## Roughly how many customers arrive in each hour (keyed by the hour it starts; 24 is midnight):
## a steady trickle after work, a rush from 9 to 1am (peaking from 10 to 11, when the tent
## usually fills up), then the stragglers. About twenty a night: enough that strangers are
## often sitting side by side, while leaving time to talk (a real tent might get thirty; a
## setting could change it).
const ARRIVALS_PER_HOUR := {18: 1.4, 19: 1.6, 20: 1.8, 21: 3.4, 22: 4.8, 23: 3.4, 24: 2.2, 25: 1.2, 26: 0.8}


## 1080 -> "6:00pm", 1445 -> "12:05am"
static func clock_text(minutes: int) -> String:
	var m := minutes % (24 * 60)
	var hour := floori(m / 60.0)
	var hour_12 := hour % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d%s" % [hour_12, m % 60, "am" if hour < 12 else "pm"]


## How many customers usually arrive per hour at this time of night.
static func arrivals_per_hour(minutes: int) -> float:
	return ARRIVALS_PER_HOUR.get(clampi(floori(minutes / 60.0), 18, 26), 1.0)


## Game minutes until the next customer, from a random roll between 0 and 1: on average
## 60 / arrivals_per_hour, anywhere from half to one and a half times that, and at least 5.
## busier: how much busier the show's ratings make tonight (Ratings.busier, 0.9 to 1.1).
static func next_arrival_gap(minutes: int, roll: float, busier: float = 1.0) -> int:
	var average := 60.0 / (arrivals_per_hour(minutes) * maxf(busier, 0.1))
	return maxi(5, roundi(average * (0.5 + roll)))


## How fast game time runs, by how many people are in (at the counter or waiting to be
## greeted): an empty tent's quiet stretches fly by, one customer goes a bit quicker, and
## from two (when customers can chat) it's normal speed, so there's time to talk.
const TIME_SPEEDS := [6.0, 2.0, 1.0]


static func time_speed(people: int) -> float:
	return TIME_SPEEDS[clampi(people, 0, TIME_SPEEDS.size() - 1)]


## A customer who's been waiting this many game minutes for a free stool gives up.
const GIVE_UP_MINUTES := 30


## Which day night number `night` falls on, for a bar whose first night was first_day (0 = Monday).
static func night_day(first_day: int, night: int) -> String:
	return DAYS[posmod(first_day + night - 1, DAYS.size())]


## The night's most memorable line, for the summary: the longest thing a customer said.
## Lines are {"speaker", "text"}. Returns {} if nobody said anything.
static func memorable_line(lines: Array) -> Dictionary:
	var best := {}
	for line in lines:
		if best.is_empty() or str(line["text"]).length() > str(best["text"]).length():
			best = line
	return best


## Stools at the counter.
const SEATS := 5


## Most people walk past without stopping: a few for every customer, busiest in the evening,
## few in the small hours. Game minutes until the next passer-by, from a roll between 0 and 1.
static func stroll_gap(minutes: int, roll: float) -> float:
	var per_hour := 3.0 * arrivals_per_hour(minutes) + 1.0
	return maxf(1.0, 60.0 / per_hour * (0.4 + 1.2 * clampf(roll, 0.0, 1.0)))


## The sky, the tent's glow and the bulbs through the night (minutes since midnight at the
## start of the night): dusk at 6pm, dark by 9, deepest in the small hours, the glow warmest
## mid-evening and a little tired by the end.
const NIGHT_LIGHT := [
	[18 * 60, "3c3a72", 0.06, "e0c48a"],
	[19 * 60 + 30, "24234e", 0.12, "f5d58a"],
	[21 * 60, "100f24", 0.2, "ffd27f"],
	[24 * 60, "0a0918", 0.22, "ffcf75"],
	[26 * 60, "07060f", 0.17, "f0bb66"],
	[27 * 60, "0b0a16", 0.15, "e8b060"],
]


## {"sky": Color, "glow": alpha of the tent's warm glow, "bulb": Color} at this time.
static func night_light(minutes: float) -> Dictionary:
	var points := NIGHT_LIGHT
	if minutes <= points[0][0]:
		return {"sky": Color(points[0][1]), "glow": points[0][2], "bulb": Color(points[0][3])}
	for i in range(1, points.size()):
		if minutes <= points[i][0]:
			var a: Array = points[i - 1]
			var b: Array = points[i]
			var t: float = (minutes - float(a[0])) / float(b[0] - a[0])
			return {"sky": Color(a[1]).lerp(Color(b[1]), t), "glow": lerpf(a[2], b[2], t), "bulb": Color(a[3]).lerp(Color(b[3]), t)}
	var last: Array = points.back()
	return {"sky": Color(last[1]), "glow": last[2], "bulb": Color(last[3])}


## What the night's weather looks like: "drizzle", "rain", "snow", "fog", "cold", "muggy",
## "breeze" (from the weather text), or "" if it's none of those.
static func weather_kind(weather: String) -> String:
	var w := weather.to_lower()
	if w.contains("heavy rain") or w.contains("downpour") or w.contains("typhoon"):
		return "rain"
	if w.contains("drizzle") or w.contains("rain"):
		return "drizzle"
	if w.contains("snow"):
		return "snow"
	if w.contains("fog") or w.contains("dust") or w.contains("haze"):
		return "fog"  # (yellow dust, 황사, blown in from the west in spring: a haze like fog)
	if w.contains("cold"):
		return "cold"
	if w.contains("muggy") or w.contains("heat"):
		return "muggy"
	if w.contains("breeze") or w.contains("wind"):
		return "breeze"
	return ""
