extends RefCounted
## Saving and loading bars. Each bar is one human-readable JSON file in user://saves/
## (on Windows: %APPDATA%\Godot\app_userdata\KTBT\saves\), named after its id.
##
## Writes are safe: the new version is written to "<id>.json.tmp" first and only then
## swapped in, so a crash mid-save can't corrupt a bar. If a crash leaves only the .tmp
## file, loading uses it.
##
## A bar: {version, id, name, name_meaning, owner, takings, visits, history, created,
## last_played}. history holds a short summary of each visit (newest last), kept to
## HISTORY_LIMIT entries; later stages (regulars) will build on it.

const VERSION := 1
const HISTORY_LIMIT := 100
const NIGHT_LOG_LIMIT := 100
const REQUIRED := ["id", "name", "owner"]

## Where saves live. Tests point this somewhere else so they never touch real bars.
static var folder := "user://saves/"


## A brand new bar, not yet saved.
static func new_bar(bar_name: String, meaning: String, owner_data: Dictionary) -> Dictionary:
	var now := _now()
	return {
		"version": VERSION,
		"id": make_id(bar_name, now),
		"name": bar_name,
		"name_meaning": meaning,
		"owner": owner_data.duplicate(true),
		"takings": 0,
		"visits": 0,
		"nights": 0,
		"first_day": 4,  # 0 = Monday; the visit scene picks a random one for a new bar
		"history": [],
		"night_log": [],
		"created": now,
		"last_played": now,
	}


## "Mi-sook-ne Pocha" made at 1794600000 -> "mi-sook-ne-pocha-1794600000"
static func make_id(bar_name: String, when: int) -> String:
	var slug := ""
	for c in bar_name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			slug += c
		elif not slug.ends_with("-") and slug != "":
			slug += "-"
	slug = slug.trim_suffix("-")
	if slug == "":
		slug = "bar"
	return "%s-%d" % [slug, when]


## Saves the bar (and stamps last_played). Returns OK or the error.
static func save_bar(bar: Dictionary) -> Error:
	var made := DirAccess.make_dir_recursive_absolute(folder)
	if made != OK and not DirAccess.dir_exists_absolute(folder):
		return made
	bar["last_played"] = _now()
	var path := _path(str(bar["id"]))
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(bar, "\t"))
	file.close()
	# Swap the new version in. (Remove first: renaming over a file isn't reliable everywhere.)
	if FileAccess.file_exists(path):
		var removed := DirAccess.remove_absolute(path)
		if removed != OK:
			return removed
	return DirAccess.rename_absolute(temp, path)


## The saved bar with this id, or {} if it's missing or unreadable.
static func load_bar(id: String) -> Dictionary:
	var path := _path(id)
	var bar := _read(path)
	if bar.is_empty():
		bar = _read(path + ".tmp")  # a save that crashed just before being swapped in
	return bar


## Every saved bar, most recently played first. Unreadable files are skipped.
static func list_bars() -> Array:
	var bars: Array = []
	var seen := {}
	var dir := DirAccess.open(folder)
	if dir == null:
		return bars
	for file_name in dir.get_files():
		var id := ""
		if file_name.ends_with(".json"):
			id = file_name.trim_suffix(".json")
		elif file_name.ends_with(".json.tmp"):
			id = file_name.trim_suffix(".json.tmp")
		if id == "" or seen.has(id):
			continue
		var bar := load_bar(id)
		if not bar.is_empty():
			seen[id] = true
			bars.append(bar)
	bars.sort_custom(func(a, b): return int(a.get("last_played", 0)) > int(b.get("last_played", 0)))
	return bars


## Adds a finished visit to the bar: takings, visit count and a short history entry.
static func record_visit(bar: Dictionary, summary: Dictionary) -> void:
	bar["visits"] = int(bar.get("visits", 0)) + 1
	bar["takings"] = int(bar.get("takings", 0)) + int(summary.get("bill", 0))
	var history: Array = bar.get("history", [])
	history.append(summary.duplicate(true))
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	bar["history"] = history


## Adds a finished night to the bar: the night count and a short summary in night_log.
static func record_night(bar: Dictionary, summary: Dictionary) -> void:
	bar["nights"] = int(bar.get("nights", 0)) + 1
	var log: Array = bar.get("night_log", [])
	log.append(summary.duplicate(true))
	while log.size() > NIGHT_LOG_LIMIT:
		log.pop_front()
	bar["night_log"] = log


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	for key in REQUIRED:
		if not data.has(key):
			return {}
	# JSON has no integers, so whole numbers come back as floats: put them back.
	for key in ["version", "takings", "visits", "nights", "first_day", "created", "last_played"]:
		if data.has(key):
			data[key] = int(data[key])
	if data["owner"] is Dictionary and data["owner"].has("age"):
		data["owner"]["age"] = int(data["owner"]["age"])
	return data


static func _path(id: String) -> String:
	return folder.path_join(id + ".json")


static func _now() -> int:
	return int(Time.get_unix_time_from_system())
