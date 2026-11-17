extends RefCounted
## The night as a story, kept: tonight's transcript file (written as the night goes, so it's
## there even if the game closes mid-night: a header saying which bar and night and with what
## AI, how the bar opened, everything said and done, and at the end how it ended and the
## night's stats), and what "Previously on…" is written from. In the project's
## logs/transcripts/ folder when running from the editor (handy for reading and sharing;
## .gitignore keeps them out of commits). The tent's scene writes the diary and plays the
## recap; this keeps the record.
## (Part 7 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Story = preload("res://scripts/rules/story.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

var file: FileAccess  # tonight's transcript, while it's being written
## What's shown before tonight's transcript starts (the bar opening: its menu, its own dishes,
## the recap), for the top of it.
var before := ""
var _tags := RegEx.create_from_string("\\[[^\\]]*\\]")  # BBCode tags, stripped for the file


## Whether tonight's transcript is being written.
func is_writing() -> bool:
	return file != null and file.is_open()


## Something shown on screen (BBCode), into the transcript as plain text: tonight's, or, before
## it starts, kept for the top of it.
func record(bbcode: String) -> void:
	var plain := _tags.sub(bbcode.replace("[lb]", "\u0001"), "", true).replace("\u0001", "[")  # ([lb]: how a "[" in the AI's text is escaped)
	if file != null:
		file.store_string(plain)
		file.flush()
	else:
		before += plain


## Starts tonight's transcript: its header (header_lines: the bar and night, the weather, the
## AI), then how the bar opened. Returns its path, or "" if it couldn't be written.
func start(bar_id: String, night: int, header_lines: Array) -> String:
	file = null
	var folder := Hooks.transcript_folder
	if folder == "":
		folder = "res://logs/transcripts/" if OS.has_feature("editor") else "user://logs/transcripts/"
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").left(15)
	var path := folder.path_join("%s_%s_night%d.txt" % [stamp, bar_id, night])
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("\n".join(PackedStringArray(header_lines + ["=".repeat(70)])) + "\n")
	file.store_string(before.strip_edges() + "\n\n" if before.strip_edges() != "" else "")
	before = ""
	file.flush()
	return path


## The end of the night (or the bar closed early): how it ended, and the night's stats.
func finish(finished: bool, clock_text: String, stats_text: String) -> void:
	if file == null:
		return
	file.store_string("\n%s\n%s at %s.\n\nSTATS\n\n%s\n" % ["=".repeat(70), "Finished" if finished else "Cut short", clock_text, stats_text])
	file.close()
	file = null
	before = ""


## Last night's ending, the diary: not part of the next night's opening.
func forget_before() -> void:
	before = ""


## "Previously on…": what the recap's written from: the last diary entry and its facts, the
## regulars (and each one's latest memory, for a bar from before diaries), and who may be named.
## dice: for which teaser example the AI is shown (the scenery's: the game's rolls don't shift).
static func recap_facts(bar: Dictionary, owner_data: Dictionary, regulars: Array, dice: RandomNumberGenerator) -> Dictionary:
	var diary: Array = bar.get("diary", [])
	var last: Dictionary = diary[-1] if not diary.is_empty() else {}
	var names: Array = [str(owner_data.get("name", ""))]
	for regular in regulars:
		names.append(str(regular["name"]))
	var latest_memories: Array = []
	if last.is_empty():
		for regular in regulars:
			var kept: Array = regular.get("memories", [])
			if not kept.is_empty():
				latest_memories.append("%s, a regular: %s" % [regular["name"], kept[-1].get("owner", "")])
	var last_facts: Dictionary = last.get("facts", {})
	var hangul := {str(owner_data.get("name", "")): str(owner_data.get("hangul", ""))}  # for the recap's name tags
	for regular in regulars:
		hangul[str(regular["name"])] = str(regular.get("hangul", ""))
	for person in last_facts.get("people", []):
		names.append(str(person["name"]))
		if not hangul.has(str(person["name"])) or str(hangul[str(person["name"])]) == "":
			hangul[str(person["name"])] = str(person.get("hangul", ""))
	return {
		"episode": int(bar.get("nights", 0)) + 1, "bar": str(bar.get("name", "")), "owner": str(owner_data.get("name", "")),
		"archetype": str(owner_data.get("archetype", "")), "owner_data": owner_data.duplicate(true), "cat": str(bar.get("cat", {}).get("name", "")),
		"regulars": regulars.map(func(r): return str(r["name"])), "names": names,
		"last": last_facts, "last_entry": str(last.get("text", "")), "memories": latest_memories, "hangul": hangul,
		"teaser_example": Story.RECAP_TEASER_EXAMPLES[dice.randi() % Story.RECAP_TEASER_EXAMPLES.size()],
	}
