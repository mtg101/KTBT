extends RefCounted
## Text helpers the rules share: tidying the AI's text, splitting words, checking a reply has
## its fields, and sorting rejected replies into kinds for the stats.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

static func pick_weighted(weights: Dictionary, roll: float, skip: String) -> String:
	var total := 0.0
	for key in weights:
		if key != skip:
			total += float(weights[key])
	var target := clampf(roll, 0.0, 0.9999) * total
	var choice := ""
	for key in weights:
		if key == skip or float(weights[key]) <= 0.0:
			continue
		choice = key
		target -= float(weights[key])
		if target < 0.0:
			return key
	return choice


## What kind of problem a validator found, for the stats: the AI's rejected replies,
## grouped so the most common mistakes stand out.
static func problem_kind(problem: String) -> String:
	var p := problem.to_lower()
	if p.contains("never how they look"):
		return "teasing that crossed the line"
	if p.begins_with("the signature dish"):
		return "signature dishes"
	if p.contains("sold out tonight"):
		return "sold out"
	if p.contains("the caption"):
		return "TV reactions"
	if p.contains("made-up korean"):
		return "made-up Korean"
	if p.contains("the line calls"):
		return "address rules"
	if p.contains("already at the counter") or p.contains("already called"):
		return "same name"
	if p.contains("the cat"):
		return "the cat"
	if p.contains("hangul") or p.contains("\"tarp\"") or p.contains("\"sign\"") or p.contains("\"shape\"") or p.contains("touches"):
		return "the bar's look"
	if p.contains("in brackets"):
		return "brackets (translations, asides)"
	if p.contains("only just met"):
		return "oppa, hyung, nuna or eonni"
	if p.contains("isn't on the table") or p.contains("isn't in \"items\"") or p.contains("asks for more"):
		return "food that wasn't ordered"
	if p.contains("isn't on the menu"):
		return "not on the menu"
	if p.contains("real brand"):
		return "real brands"
	if p.contains("too dark a turn of phrase"):
		return "dark turns of phrase"
	if p.contains("gives something away"):
		return "giving things away"
	if p.contains("doesn't ask for it"):
		return "line doesn't match the order"
	if p.contains("sounds like a first order"):
		return "later order sounded like a first one"
	if p.contains("json") or p.contains("didn't include") or p.contains("left out") or p.contains("was empty") or p.contains("wasn't a list"):
		return "missing or broken JSON"
	if p.contains("gender"):
		return "name format"
	if p.contains("age"):
		return "age"
	if p.contains("archetype"):
		return "owner's gendered words"
	if p.contains("name"):
		return "name format"
	if p.contains("drink") or p.contains("food") or p.contains("main") or p.contains("order") or p.contains("bokkeumbap"):
		return "order rules"
	if p.contains("too long"):
		return "too long"
	return "other"


## Checks every field is present and that text fields aren't empty. Tidies text in place.
static func check_fields(data: Variant, fields: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	for field in fields:
		if not data.has(field):
			return "it left out \"%s\"" % field
		if field == "age":
			continue
		var text := tidy_text(data[field])
		if text == "":
			return "\"%s\" was empty" % field
		data[field] = text
	return ""


## Text fields sometimes come back as lists: join them up.
static func tidy_text(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for part in value:
			parts.append(str(part).strip_edges())
		return ", ".join(parts)
	return str(value).strip_edges()


## "\"Hello\"" -> "Hello" (straight, curly or single quotes)
static func unquote(text: String) -> String:
	for pair in [["\"", "\""], ["“", "”"], ["'", "'"]]:
		if text.length() >= 2 and text.begins_with(pair[0]) and text.ends_with(pair[1]):
			return text.substr(1, text.length() - 2).strip_edges()
	return text


## "Gruff-but-soft Ajumma!" -> ["gruff", "but", "soft", "ajumma"]
static func words(text: String) -> PackedStringArray:
	var letters := ""
	for c in text.to_lower():
		letters += c if (c >= "a" and c <= "z") else " "
	return letters.split(" ", false)


## "a messy bob" -> "A messy bob."
static func as_sentence(text: String) -> String:
	var result := sentence_case(text.strip_edges())
	if result != "" and not (result.ends_with(".") or result.ends_with("!") or result.ends_with("?")):
		result += "."
	return result


## "light drizzle" -> "Light drizzle"
static func sentence_case(text: String) -> String:
	if text == "":
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


## The numbers written in digits in text, without their commas ("₩412,000" -> "412000").
static func numbers_in(text: String) -> Array:
	var found: Array = []
	var digits := ""
	for c in text + " ":
		if c >= "0" and c <= "9":
			digits += c
		elif c == "," and digits != "":
			continue
		else:
			if digits != "":
				found.append(digits)
			digits = ""
	return found


## A BBCode hover tip around some (already BBCode) text. The tip is made safe to sit inside
## the tag: no square brackets, no newlines, and curly quotes in place of straight ones
## (a straight ' in "ma'am" made Godot read the rest as a quoted value, and the whole tag
## showed as raw text).
static func hint(tip_words: String, inner: String) -> String:
	var safe := tip_words.replace("[", "(").replace("]", ")").replace("\n", " ").replace("'", "’").replace("\"", "”")
	return "[hint=%s]%s[/hint]" % [tip(safe), inner]


## The widest a hover (tooltip) gets, in characters a line: Godot's tooltips don't wrap, so a
## long one runs right across the screen.
const TIP_WIDTH := 48


## Hover text, wrapped to TIP_WIDTH (each line of it, keeping any line breaks it has). Every
## tooltip in the game goes through this.
static func tip(text: String, width: int = TIP_WIDTH) -> String:
	var lines := PackedStringArray()
	for each in text.split("\n"):
		lines.append(_wrap_line(each, width))
	return "\n".join(lines)


## Text broken onto lines of at most this many characters, at spaces (a word longer than that
## gets a line of its own). For tooltips, which don't wrap by themselves.
static func wrap(text: String, width: int) -> String:
	return _wrap_line(text, width)


## (wrap's work, under a name of its own: called from inside this script, wrap() is taken
## for Godot's maths wrap(value, min, max).)
static func _wrap_line(text: String, width: int) -> String:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		if line != "" and line.length() + 1 + word.length() > width:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return "\n".join(lines)


## Text cut to at most this many characters, at a word, with "…" if anything went.
static func shorten(text: String, most: int) -> String:
	var clean := text.strip_edges()
	if clean.length() <= most:
		return clean
	var cut := clean.left(most - 1)
	if cut.rfind(" ") > most / 2.0:  # (at a space only past halfway, or too much would go)
		cut = cut.left(cut.rfind(" "))
	return cut.rstrip(" ,.;:·") + "…"
