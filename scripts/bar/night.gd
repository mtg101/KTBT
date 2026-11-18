extends RefCounted
## Tonight at the tent: what the tent's parts share, in one place. The scene keeps it, and
## hands it to each part; a part reads it and changes it, rather than keeping its own copy.
## Grew a field at a time, as the parts that needed them moved out of visit.gd (see
## DEVLOG.md, 16 November 2026).

const NightStats = preload("res://scripts/bar/night_stats.gd")

var weather_kind := ""  # tonight's weather, as NightRules.weather_kind says it ("rain", "snow"...)
var stats := NightStats.new()  # tonight's debug stats (a new one each night)
var owner_stunned := ""  # a Talk.stunned_moment for the owner's next line (used once)
var owner_cat_moment := ""  # the cat's up to something the owner has to deal with (used once)
var owner_plant_moment := ""  # a PD's card has just happened to the whole tent: for the owner's next line (used once)
var owner_plant_card := ""  # ... which card (for the stats)
