extends RefCounted
## Autoplay: a batch of nights that play themselves, with the real AI, while nobody's watching,
## so a test run can be ten nights rather than one (tools/autoplay.bat). Started from the
## command line: `-- --autoplay=10` (how many nights), and `--autoplay-bar=<id>` to carry on a
## bar rather than start a new one (to test regulars over many nights). Each night is logged as
## usual (its stats and transcript); after each, the batch's own summary file is written again
## (nights played, how long each took, the AI's rejections and give-ups, any errors), so a batch
## that's stopped early still has one. It stops after its nights, or at the end of a night when
## Ollama stopped answering (and says why). Nothing waits for a click: the step-in prompts and
## the edit time out by themselves, as always. The PD's parts aren't played yet (see PLAN.md).

const NightStats = preload("res://scripts/bar/night_stats.gd")

## How long the summary page stays up before the next night opens (to see it, if you look in).
const PAUSE_SECONDS := 8.0
## The file saying a batch is running (see write_running).
const RUNNING_FILE := "running.json"
## Errors kept word for word in the summary (the rest are only counted).
const ERRORS_KEPT := 10

## Where the summaries go (tests set their own): beside the night logs, in autoplay/.
static var folder := ""

var nights := 0  # how many to play
var bar_id := ""  # the bar to carry on ("": a new one, autoplay's own)
var begun := false  # the title screen's opened the bar
var played: Array = []  # each night: {"night", "minutes", "customers", "offline", "rejected", "gave_up", "errors", "ratings" (-1: none), "season" ("": none)}
var stop_reason := ""  # why it stopped early ("" if it didn't)
var pause_seconds := PAUSE_SECONDS
var errors := Errors.new()
var _started := ""
var _last_msec := 0
var _errors_before := 0


## Counts the errors Godot reports while the batch runs (and keeps the first few).
class Errors:
	extends Logger
	var count := 0
	var kept: Array = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var where := "%s:%d, %s" % [file.get_file(), line, function]
		for trace in script_backtraces:  # (the script's line, not the engine's, when there is one)
			if trace.get_frame_count() > 0:
				where = "%s:%d, %s" % [trace.get_frame_file(0).get_file(), trace.get_frame_line(0), trace.get_frame_function(0)]
				break
		note("%s (%s)" % [rationale if rationale != "" else code, where])

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func note(text: String) -> void:
		_lock.lock()
		count += 1
		if kept.size() < ERRORS_KEPT:
			kept.append(text)
		_lock.unlock()


func _init(how_many: int = 0, carry_on: String = "") -> void:
	nights = how_many
	bar_id = carry_on
	_started = Time.get_datetime_string_from_system(false, true)
	_last_msec = Time.get_ticks_msec()


## The batch the command line asks for, or null for an ordinary game.
static func from_args(args: PackedStringArray) -> Variant:
	var how_many := 0
	var carry_on := ""
	for arg in args:
		if arg.begins_with("--autoplay="):
			how_many = maxi(int(arg.trim_prefix("--autoplay=")), 0)
		elif arg.begins_with("--autoplay-bar="):
			carry_on = arg.trim_prefix("--autoplay-bar=")
	if how_many <= 0:
		return null
	return new(how_many, carry_on)


## A night's done (logged and written up): note it. ratings: its TV ratings (Ratings.score), or -1;
## season: where it was in the show's seasons ("S1 · EP 8/8 · FINALE", and the verdict after a finale), or "".
func night_done(night: int, customers: int, offline: bool, rejected: int, gave_up: int, ratings: float = -1.0, season: String = "") -> void:
	var now := Time.get_ticks_msec()
	played.append({"night": night, "minutes": snappedf((now - _last_msec) / 60000.0, 0.1), "customers": customers, "offline": offline,
		"rejected": rejected, "gave_up": gave_up, "errors": errors.count - _errors_before, "ratings": ratings, "season": season})
	_last_msec = now
	_errors_before = errors.count


## Stop at the end of this night (the first reason given is kept).
func stop(reason: String) -> void:
	if stop_reason == "":
		stop_reason = reason


func finished() -> bool:
	return played.size() >= nights or stop_reason != ""


## Which night of the batch this is, for the night's log ("night 3 of 10").
func progress_text() -> String:
	return "night %d of %d" % [mini(played.size() + 1, nights), nights]


func summary_text(bar_name: String) -> String:
	var lines := ["KTBT autoplay: %s" % bar_name, "Started %s. %d of %d nights played%s." % [_started, played.size(), nights,
		"" if not finished() else (", stopped early: " + stop_reason if stop_reason != "" else ", all done")], ""]
	var minutes := 0.0
	for night in played:
		minutes += float(night["minutes"])
		lines.append("Night %d: %.1f min, %d customers, %sAI rejected %d, gave up %d%s%s" % [night["night"], night["minutes"], night["customers"],
			("ratings %.1f%%, " % float(night["ratings"])) if float(night.get("ratings", -1.0)) >= 0.0 else "", night["rejected"], night["gave_up"], ", OFFLINE" if night["offline"] else "", ", %d errors" % night["errors"] if int(night["errors"]) > 0 else ""])
		if str(night.get("season", "")) != "":
			lines[-1] += " (%s)" % night["season"]
	lines.append("")
	lines.append("Altogether %.0f min. Errors: %d%s" % [minutes, errors.count, ":" if not errors.kept.is_empty() else "."])
	for kept in errors.kept:
		lines.append("  " + str(kept))
	return "\n".join(PackedStringArray(lines)) + "\n"


static func summary_folder() -> String:
	if folder != "":
		return folder
	return NightStats.logs_folder().trim_suffix("/").get_base_dir().path_join("autoplay")


## Writes (or writes again) the batch's summary file; its path.
func save_summary(bar_name: String, bar: String) -> String:
	var where := summary_folder()
	DirAccess.make_dir_recursive_absolute(where)
	var path := where.path_join("%s_%s.txt" % [_started.replace(":", "").replace(" ", "_").left(15), bar])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(summary_text(bar_name))
	file.close()
	return path


## The file that says a batch is running, beside the summaries: the game's own process id, so
## the phone helper (tools/autoplay_mcp.ps1) can tell it's still going, and stop it, without
## searching Windows for it.
static func running_path() -> String:
	return summary_folder().path_join(RUNNING_FILE)


## Says the batch is running (at the start, and again after each night, with how far it's got).
func write_running(bar_name: String = "") -> void:
	DirAccess.make_dir_recursive_absolute(summary_folder())
	var file := FileAccess.open(running_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "nights": nights, "played": played.size(), "started": _started, "bar": bar_name}))
	file.close()


## The batch has ended (all done, stopped early, or the window closed).
static func clear_running() -> void:
	if FileAccess.file_exists(running_path()):
		DirAccess.remove_absolute(running_path())
