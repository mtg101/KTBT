extends RefCounted
## Tonight at the tent: what the tent's parts share, in one place. The scene keeps it, and
## hands it to each part; a part reads it and changes it, rather than keeping its own copy.
## Grows a field at a time, as the parts that need them move out of visit.gd (see PLAN.md,
## "A proper refactor").

const NightStats = preload("res://scripts/night_stats.gd")

var weather_kind := ""  # tonight's weather, as NightRules.weather_kind says it ("rain", "snow"...)
var stats := NightStats.new()  # tonight's debug stats (a new one each night)
