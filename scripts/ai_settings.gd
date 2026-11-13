extends RefCounted
## Which AI the game uses, set per machine in a small settings file, so the desktop (with a
## big GPU) and the laptop (without one) can share the same project.
##
## The file is user://ai_settings.cfg. On Windows that's
## %APPDATA%\Godot\app_userdata\KTBT\ai_settings.cfg. It's created with the defaults the
## first time the game runs; edit it in any text editor:
##
##   [ai]
##   backend="auto"                     ; "auto", "ollama" or "canned"
##   server="http://127.0.0.1:11434"    ; where Ollama is (another PC's address works too)
##   model="llama3.1:8b"                ; any model Ollama has pulled
##
## backend: "ollama" always uses the local LLM; "canned" never does (offline mode: instant,
## pre-written characters, for machines without a suitable GPU); "auto" uses Ollama and
## switches to canned for the rest of the session if Ollama can't be reached.

const PATH := "user://ai_settings.cfg"
const BACKENDS := ["auto", "ollama", "canned"]
const DEFAULTS := {
	"backend": "auto",
	"server": "http://127.0.0.1:11434",
	"model": "llama3.1:8b",
}

## Tests set this (e.g. {"backend": "canned"}) to override the file without touching it.
static var override := {}


## The settings to use: the defaults, then the file, then any override.
static func load_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for key in DEFAULTS:
			settings[key] = str(file.get_value("ai", key, DEFAULTS[key]))
	else:
		# First run: write the defaults so there's a file to find and edit.
		for key in DEFAULTS:
			file.set_value("ai", key, DEFAULTS[key])
		file.save(PATH)
	settings.merge(override, true)
	if not (settings["backend"] in BACKENDS):
		push_warning("Unknown AI backend \"%s\" in %s; using \"auto\"." % [settings["backend"], PATH])
		settings["backend"] = "auto"
	return settings
