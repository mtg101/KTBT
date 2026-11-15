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
static func hint(tip: String, inner: String) -> String:
	var safe := tip.replace("[", "(").replace("]", ")").replace("\n", " ").replace("'", "’").replace("\"", "”")
	return "[hint=%s]%s[/hint]" % [safe, inner]
