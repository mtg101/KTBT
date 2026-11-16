extends GdUnitTestSuite
## Checks on the code itself, before anything else (the refactor's pre-check): the slips that
## otherwise only show when Godot loads a file and refuses it (warnings are errors here).

## Godot's own functions: a local of the same name shadows it.
const GODOT_FUNCTIONS := ["wrap", "sign", "min", "max", "clamp", "range", "len", "str", "abs", "round", "floor", "ceil", "lerp",
	"hash", "load", "print", "snapped", "exp", "log", "sin", "cos", "tan", "sqrt", "pow", "fmod", "seed", "weakref", "typeof",
	"char", "ord", "convert", "posmod", "floori", "ceili", "roundi", "absi", "signi", "maxi", "mini", "clampi", "maxf", "minf",
	"clampf", "lerpf", "smoothstep", "move_toward", "is_instance_valid"]
## A Node's own members (and signals): a local of the same name in a Node's script shadows it.
const NODE_MEMBERS := ["name", "owner", "position", "size", "scale", "rotation", "visible", "modulate", "z_index", "ready"]
## gdUnit's own functions: a local of the same name in a test stops the test file loading.
const GDUNIT_FUNCTIONS := ["before", "after", "any", "any_int", "any_float", "any_string", "any_object", "any_array",
	"any_dictionary", "mock", "spy", "fail", "skip", "auto_free"]


func test_no_local_shadows_a_name_godot_or_gdunit_already_has() -> void:
	var declared := RegEx.create_from_string("^\\t+(?:var|const)\\s+([a-z_]\\w*)|^\\t+for\\s+([a-z_]\\w*)\\s+in\\b")
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var base := "RefCounted"
		for line in lines:
			if line.begins_with("extends "):
				base = line.get_slice(" ", 1)
				break
		var node_script := not ["RefCounted", "Object", "Resource"].has(base)
		var in_inner_class := false
		for i in lines.size():
			if lines[i].begins_with("class "):
				in_inner_class = true  # (its own base: RefCounted)
			var found := declared.search(lines[i])
			if found == null:
				continue
			var local := found.get_string(1) if found.get_string(1) != "" else found.get_string(2)
			var clashes: bool = GODOT_FUNCTIONS.has(local) or (path.begins_with("res://tests") and GDUNIT_FUNCTIONS.has(local)) \
				or (node_script and not in_inner_class and NODE_MEMBERS.has(local))
			assert_bool(clashes).override_failure_message("%s:%d: \"%s\" shadows a name Godot or gdUnit already has" % [path, i + 1, local]).is_false()


func test_indents_are_tabs() -> void:
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			assert_bool(lines[i].begins_with(" ")).override_failure_message("%s:%d: indented with spaces (tabs only)" % [path, i + 1]).is_false()


## Every script under a folder, its subfolders too.
func _scripts(folder: String) -> Array:
	var found: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found
