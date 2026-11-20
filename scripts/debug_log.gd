extends RefCounted
## What the game notes as it goes ("always log all the things": each fact as it happens, so a
## night can be checked from its log), kept quiet. Into each night's debug file, beside its
## transcript (logs/debug/, as logs/transcripts/), with the time it happened; on the console only
## what's worth watching a night by: the hourly light (it's ticking along), autoplay and the crew,
## the season, and where the night's files are (errors show there anyway). The owner's every
## step isn't noted at all any more (20 Nov). `-- --log-all` puts everything on the console too.

## Shown on the console as well as in the file.
const CONSOLE := ["Light", "Autoplay", "Season", "Night transcript", "Night stats saved", "Debug log"]
## Kept until tonight's file's open (a bar's first notes come before its first night).
const MOST_WAITING := 200

static var folder := ""  # where the files go ("": logs/debug/ in the project, from the editor; user:// otherwise). Tests set their own.
static var everything_to_console := false  # (-- --log-all)
static var printed: Array = []  # the console's last few lines (for the tests)
static var _file: FileAccess
static var _waiting: Array = []


## A note: what kind it is ("Regulars", "Light"...) and what happened.
static func say(kind: String, text: String) -> void:
	var line := "%s: %s" % [kind, text]
	if everything_to_console or kind in CONSOLE:
		print(line)
		printed.append(line)
		if printed.size() > 20:
			printed.pop_front()
	var stamped := "%s  %s" % [Time.get_time_string_from_system(), line]
	if _file != null:
		_file.store_line(stamped)
		_file.flush()
	elif _waiting.size() < MOST_WAITING:
		_waiting.append(stamped)


## Tonight's file (visit.gd, as tonight's transcript starts): anything noted before it first.
## Its path, or "" if it couldn't be written.
static func start_night(bar_id: String, night: int) -> String:
	_file = null
	var where := folder
	if where == "":
		where = "res://logs/debug/" if OS.has_feature("editor") else "user://logs/debug/"
	DirAccess.make_dir_recursive_absolute(where)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").left(15)
	var path := where.path_join("%s_%s_night%d.txt" % [stamp, bar_id, night])
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return ""
	for line in _waiting:
		_file.store_line(line)
	_waiting = []
	_file.flush()
	return path


## Whether the command line asks for everything on the console (`-- --log-all`).
static func from_args(args: PackedStringArray) -> void:
	everything_to_console = args.has("--log-all")
