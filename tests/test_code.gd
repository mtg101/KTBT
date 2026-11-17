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


## A test file built on the shared base (tests/support/bar_test.gd) quietly replaces any
## helper it defines again with the same name, and every test that used the base's breaks.
func test_no_test_redefines_a_shared_helper() -> void:
	var defined := RegEx.create_from_string("(?m)^func\\s+(\\w+)\\s*\\(")
	var shared: Array = defined.search_all(FileAccess.get_file_as_string("res://tests/support/bar_test.gd")).map(func(m): return m.get_string(1)) \
		.filter(func(helper): return not ["before", "after", "before_test", "after_test", "_setup"].has(helper))  # (hooks meant to be overridden: gdUnit's, and the base's own _setup)
	assert_array(shared).is_not_empty()
	for path in _scripts("res://tests"):
		var text := FileAccess.get_file_as_string(path)
		if not text.begins_with("extends \"res://tests/support/bar_test.gd\""):
			continue
		for found in defined.search_all(text):
			var helper := found.get_string(1)
			assert_bool(shared.has(helper)).override_failure_message("%s: \"%s\" is already a shared helper in tests/support/bar_test.gd (pick another name)" % [path, helper]).is_false()


func test_indents_are_tabs() -> void:
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			assert_bool(lines[i].begins_with(" ")).override_failure_message("%s:%d: indented with spaces (tabs only)" % [path, i + 1]).is_false()


## PLAN.md is only what's left (see its opening): nothing in it says it's done. When part of
## an item's built, that part moves to the DEVLOG (and how it works, to CONCEPT.md).
const DONE_IN_A_PLAN := ["\\(done\\b", "\\bdone \\(", "\\bpartly done\\b", "\\bbuilt \\d", "\\(fixed\\b", "\\bfixed \\d", "\\bsince \\d+ (nov|dec|jan)",
	"\\b(is|are) in \\(\\d", "\\bdone, the\\b", "\\bnow built\\b"]


func test_the_plan_only_says_whats_left() -> void:
	var plan := FileAccess.get_file_as_string("res://PLAN.md")
	assert_str(plan).is_not_empty()
	for pattern in DONE_IN_A_PLAN:
		var found := RegEx.create_from_string("(?i)" + pattern).search(plan)
		if found != null:
			var line := plan.substr(0, found.get_start()).count("\n") + 1
			fail("PLAN.md line %d says something's done (\"%s\"): move that to the DEVLOG, and keep only what's left" % [line, found.get_string()])


## The test count is the same everywhere it's written, and the newest day in the DEVLOG says it
## (so a change with tests always gets a DEVLOG entry).
func test_the_docs_have_the_test_count() -> void:
	var count := 0
	for path in _scripts("res://tests"):
		count += RegEx.create_from_string("(?m)^func test_").search_all(FileAccess.get_file_as_string(path)).size()
	assert_str(FileAccess.get_file_as_string("res://TESTS.md")).override_failure_message("TESTS.md doesn't say \"All %d tests pass\"" % count).contains("All %d tests pass" % count)
	assert_str(FileAccess.get_file_as_string("res://README.md")).override_failure_message("README.md doesn't say \"%d automated tests\"" % count).contains("%d automated tests" % count)
	var devlog := FileAccess.get_file_as_string("res://DEVLOG.md")
	var newest := devlog.find("\n## ")
	var day := devlog.substr(newest, devlog.find("\n## ", newest + 4) - newest)
	assert_str(day).override_failure_message("the newest day in DEVLOG.md doesn't mention \"%d tests\": add an entry for what changed" % count).contains("%d tests" % count)


## Each row of TESTS.md's table says how many tests its suite has, and it's right.
func test_the_tests_table_has_each_suites_count() -> void:
	var row := RegEx.create_from_string("(?m)^\\|[^|]*\\|\\s*`tests/(test_\\w+)\\.gd`\\s*\\|\\s*(?:—\\s*\\|\\s*)?✅ (\\d+)")  # (a click-through suite's count is in the last column)
	var rows := row.search_all(FileAccess.get_file_as_string("res://TESTS.md"))
	assert_int(rows.size()).is_greater(20)
	for found in rows:
		var suite := "res://tests/%s.gd" % found.get_string(1)
		var count := RegEx.create_from_string("(?m)^func test_").search_all(FileAccess.get_file_as_string(suite)).size()
		assert_int(int(found.get_string(2))).override_failure_message("TESTS.md says %s has %s tests, but it has %d" % [found.get_string(1), found.get_string(2), count]).is_equal(count)

## No scene test compares the tent's guests themselves (is_equal, contains...): gdUnit compares
## them field by field, down through their nodes, and on Windows that ran out of stack and
## crashed the whole run with no error (17 Nov). Compare their names (bar_test.gd's _names).
func test_no_scene_test_compares_guests_deeply() -> void:
	var deep := RegEx.create_from_string("assert_(array|object)\\((?!_names\\().*(_guests|\\.people)\\b.*\\.(is_equal|is_not_equal|contains)")
	for path in _scripts("res://tests"):
		var text := FileAccess.get_file_as_string(path)
		if not text.begins_with("extends \"res://tests/support/bar_test.gd\""):
			continue  # (stand-in guests are small: only the scene's are deep)
		var lines := text.split("\n")
		for k in lines.size():
			if deep.search(lines[k]) != null and not lines[k].contains("_names("):
				fail("%s:%d compares guests themselves: compare _names(...) instead" % [path, k + 1])


## Every script is in ARCHITECTURE.md's map of the files, and every test file in TESTS.md.
func test_the_docs_list_every_file() -> void:
	var architecture := FileAccess.get_file_as_string("res://ARCHITECTURE.md") + FileAccess.get_file_as_string("res://README.md")
	for path in _scripts("res://scripts"):
		assert_str(architecture).override_failure_message("%s isn't in ARCHITECTURE.md's map of the files" % path).contains(str(path).get_file())
	var tests := FileAccess.get_file_as_string("res://TESTS.md")
	for path in _scripts("res://tests"):
		if not str(path).contains("/support/"):
			assert_str(tests).override_failure_message("%s isn't in TESTS.md" % path).contains(str(path).get_file())


## Every script under a folder, its subfolders too.
func _scripts(folder: String) -> Array:
	var found: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found
