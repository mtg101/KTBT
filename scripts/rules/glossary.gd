extends RefCounted
## Korean words, explained on hover: not everyone has watched as much K-TV as the people who
## made this. Covers tonight's menu, everyday words people say at a pocha, and the terms of
## address (which are also coloured by warmth, see Address.WARMTH_COLOURS).

const Address = preload("res://scripts/rules/address.gd")
const Menu = preload("res://scripts/menu.gd")
const Text = preload("res://scripts/rules/text.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")

## Words that aren't on the menu or terms of address. "spellings" are lower case; the first
## one, capitalised, is how the hover names it.
const WORDS := {
	"banchan": {"spellings": ["banchan"], "hangul": "반찬", "means": "the little side dishes that come free with an order, and get topped up."},
	"kimchi": {"spellings": ["kimchi"], "hangul": "김치", "means": "spicy fermented cabbage: on every table, with everything."},
	"danmuji": {"spellings": ["danmuji"], "hangul": "단무지", "means": "bright yellow pickled radish."},
	"ssam": {"spellings": ["ssam"], "hangul": "쌈", "means": "a bite wrapped in a lettuce leaf, often made for someone else."},
	"anju": {"spellings": ["anju"], "hangul": "안주", "means": "food you eat with drinks. Nobody drinks without it."},
	"pocha": {"spellings": ["pojangmacha", "pocha"], "hangul": "포장마차", "means": "a tent bar: a street stall under a plastic tarp, open late."},
	"gochujang": {"spellings": ["gochujang"], "hangul": "고추장", "means": "red chilli paste."},
	"jjan": {"spellings": ["jjan", "zzan"], "hangul": "짠", "means": "cheers! (casual; the sound of glasses clinking)."},
	"geonbae": {"spellings": ["geonbae", "gunbae", "kunbae"], "hangul": "건배", "means": "cheers! (a little more formal)."},
	"one-shot": {"spellings": ["one-shot"], "hangul": "원샷", "means": "down it in one."},
	"aigoo": {"spellings": ["aigoo", "aigo", "aigoo-ya", "aygo"], "hangul": "아이고", "means": "oh dear, oh my, ugh: sighed at anything from a sore back to a lovely surprise."},
	"omo": {"spellings": ["omo", "omona", "eomeo", "eomeona"], "hangul": "어머", "means": "oh my! (surprised)."},
	"daebak": {"spellings": ["daebak"], "hangul": "대박", "means": "amazing! Huge!"},
	"jinjja": {"spellings": ["jinjja", "jinja", "jincha"], "hangul": "진짜", "means": "really? / seriously."},
	"hwaiting": {"spellings": ["hwaiting", "paiting"], "hangul": "화이팅", "means": "go for it! You can do it! (from the English \"fighting\")."},
	"mashisseoyo": {"spellings": ["mashisseoyo", "masisseoyo", "mashita", "mashisseo"], "hangul": "맛있어요", "means": "it's delicious."},
	"jal meokgesseumnida": {"spellings": ["jal meokgesseumnida", "jal meokgetseumnida"], "hangul": "잘 먹겠습니다", "means": "\"I'll eat well\": said before eating, as thanks to whoever cooked or is paying."},
	"noraebang": {"spellings": ["noraebang", "norebang"], "hangul": "노래방", "means": "a karaoke room: a private booth for singing with friends, often where a night out ends up."},
	"hoesik": {"spellings": ["hoesik"], "hangul": "회식", "means": "a work night out: dinner and drinks with colleagues, often not optional."},
	"maknae": {"spellings": ["maknae"], "hangul": "막내", "means": "the youngest in a family or group (who pours the drinks)."},
	"nunchi": {"spellings": ["nunchi"], "hangul": "눈치", "means": "reading the room: knowing what people feel without being told."},
	"annyeong": {"spellings": ["annyeong", "annyeonghaseyo", "annyeonghasimnikka"], "hangul": "안녕(하세요)", "means": "hello (annyeong to a friend; annyeonghaseyo politely)."},
	"gamsahamnida": {"spellings": ["gamsahamnida", "kamsahamnida", "gamsahaeyo"], "hangul": "감사합니다", "means": "thank you (polite)."},
	"gomawo": {"spellings": ["gomawo", "gomawoyo", "gomapseumnida"], "hangul": "고마워", "means": "thanks (gomawo to a friend; gomawoyo a little politer)."},
	"mianhae": {"spellings": ["mianhae", "mianhaeyo", "mianhamnida", "joesonghamnida"], "hangul": "미안해", "means": "sorry (mianhae to a friend; joesonghamnida very politely)."},
	"gwaenchana": {"spellings": ["gwaenchana", "gwaenchanayo", "gwenchana", "kwenchana"], "hangul": "괜찮아", "means": "it's okay / are you okay?"},
	"saranghae": {"spellings": ["saranghae", "saranghaeyo"], "hangul": "사랑해", "means": "I love you."},
	"eoseo oseyo": {"spellings": ["eoseo oseyo", "eoseo-oseyo", "eoseooseyo"], "hangul": "어서오세요", "means": "welcome! (called out as someone comes in)."},
	"tto osyeonneyo": {"spellings": ["tto osyeonneyo"], "hangul": "또 오셨네요", "means": "you came again! (polite, to a familiar face)."},
	"wasseo": {"spellings": ["wasseo", "wasseoyo"], "hangul": "왔어", "means": "you're here? (casual: to an old friend)."},
	"jal meogeosseumnida": {"spellings": ["jal meogeosseumnida", "jal meogeotseumnida", "jal meogeosseoyo"], "hangul": "잘 먹었습니다", "means": "\"I ate well\": thanks for the food, said as you leave."},
	"annyeonghi gaseyo": {"spellings": ["annyeonghi gaseyo", "annyeonghi-gaseyo"], "hangul": "안녕히 가세요", "means": "go in peace: goodbye, to someone leaving."},
	"josimhi ga": {"spellings": ["josimhi ga", "josimhi gaseyo", "josimhi"], "hangul": "조심히 가", "means": "get home safe (josimhi gaseyo, politely)."},
	"mwo": {"spellings": ["mwo", "mwoya", "mwo-ya", "mweo", "mwoh"], "hangul": "뭐", "means": "what?! The K-drama double-take (mwoya: what is this?!)."},
	"mworago": {"spellings": ["mworago", "mwolago", "mwo-rago"], "hangul": "뭐라고", "means": "what did you say?! (can't believe their ears)."},
	"heol": {"spellings": ["heol"], "hangul": "헐", "means": "whoa, what?! (stunned, or appalled)."},
	"jebal": {"spellings": ["jebal"], "hangul": "제발", "means": "please! (begging)."},
	"eotteoke": {"spellings": ["eotteoke", "eotteokhae", "otteoke"], "hangul": "어떡해", "means": "what do I do?! (panicking)."},
	"jeogiyo": {"spellings": ["jeogiyo", "yeogiyo"], "hangul": "저기요", "means": "excuse me! (calling someone over)."},
	"eomma": {"spellings": ["eomma", "umma"], "hangul": "엄마", "means": "mum."},
	"appa": {"spellings": ["appa"], "hangul": "아빠", "means": "dad."},
	"sunbae": {"spellings": ["sunbae", "seonbae", "sunbaenim"], "hangul": "선배", "means": "someone senior at work or school, said with respect."},
}

## Menu words that are also spelt other ways (the menu's own name is always included).
const MENU_SPELLINGS := {
	"tteokbokki": ["ddeokbokki", "topokki"],
	"odeng": ["eomuk"],
	"ramyeon": ["ramyun", "ramen"],
	"makgeolli": ["makkoli", "makkeolli"],
	"somaek": ["so-maek", "somaeck", "somac"],
	"pajeon": ["pajun"],
	"dakgalbi": ["dak-galbi", "dak galbi"],
	"gyeran_mari": ["gyeran mari", "gyeranmari"],
	"gonggibap": ["gongi-bap", "gonggi bap"],
	"bokkeumbap": ["bokkeum-bap", "bokkeum bap"],
}

## Menu items that aren't Korean words, so need no explaining.
const MENU_PLAIN := ["beer"]

## The colour of an explained word (terms of address use their warmth colours instead).
const WORD_COLOUR := "e8d9a8"

static var _lookup := {}
static var _pattern: RegEx = null
static var _known_hangul := {}  # Hangul -> its whole hover tip (see hangul_tip)
static var _remembered := {}  # names in Hangul, as they're known (see remember)
static var _hangul_pattern: RegEx = null
static var _menu_version := -1  # the menu these tables were built from (see Menu.version)


## Builds the tables again if the menu's changed since (another bar opened).
static func _keep_up_with_menu() -> void:
	if _menu_version == Menu.version:
		return
	_menu_version = Menu.version
	_lookup = {}
	_pattern = null
	_known_hangul = {}
static var _tag_pattern: RegEx = null


## Every explained spelling (lower case): {"tip": hover text, "colour": hex, "word": the word
## it's a spelling of (for counting: "ramen" and "ramyeon" are both "Ramyeon")}.
static func lookup() -> Dictionary:
	_keep_up_with_menu()
	if not _lookup.is_empty():
		return _lookup
	var found := {}
	for id in Address.TERMS:
		var term: Dictionary = Address.TERMS[id]
		var tip := "%s %s: %s" % [term["hangul"], str(id).capitalize(), term["means"]]
		for spelling in term["spellings"]:
			found[spelling] = {"tip": tip, "colour": Address.WARMTH_COLOURS[term["warmth"]], "word": str(id).capitalize()}
	for item in Menu.items():
		if MENU_PLAIN.has(item["id"]):
			continue
		var tip := "%s %s: %s" % [item.get("hangul", ""), item["name"], item.get("desc", "")]
		var spellings: Array = [str(item["name"]).to_lower()]
		spellings.append_array(MENU_SPELLINGS.get(item["id"], []))
		for spelling in spellings:
			if not found.has(spelling):
				found[spelling] = {"tip": tip, "colour": WORD_COLOUR, "word": str(item["name"])}
	# Every other pocha dish too (another bar's, talked about), after tonight's menu.
	for item in Catalogue.all():
		if MENU_PLAIN.has(item["id"]):
			continue
		var tip := "%s %s: %s" % [item.get("hangul", ""), item["name"], item.get("desc", "")]
		for spelling in [str(item["name"]).to_lower(), str(item.get("word", ""))]:
			if spelling != "" and not found.has(spelling):
				found[spelling] = {"tip": tip, "colour": WORD_COLOUR, "word": str(item["name"])}
	for id in WORDS:
		var word: Dictionary = WORDS[id]
		if word["spellings"].is_empty():
			continue
		var tip := "%s %s: %s" % [word["hangul"], str(word["spellings"][0]).capitalize(), word["means"]]
		for spelling in word["spellings"]:
			if not found.has(spelling):
				found[spelling] = {"tip": tip, "colour": WORD_COLOUR, "word": str(word["spellings"][0]).capitalize()}
	_lookup = found
	return _lookup


## A line (already escaped for BBCode, with no tags of its own yet) with every Korean word
## the game knows given a hover hint and a colour. One pass, longest spellings first, so a
## word inside one hint's tip is never hinted again. names: people's names, left alone
## ("Jeong", "Sundae"... a person beats a word). ink: one colour for every explained word
## instead of the usual ones (which are made for the dark transcript, not the diary's paper).
static func explain(bbcode: String, names: Array = [], ink: String = "") -> String:
	var words := lookup()
	var skip := _name_parts(names)
	var out := ""
	var at := 0
	for found in _word_pattern().search_all(bbcode):
		out += bbcode.substr(at, found.get_start() - at)
		var word := found.get_string(1)
		var known: Dictionary = words.get(word.to_lower(), {})
		if known.is_empty() or skip.has(word.to_lower()):
			out += word
		else:
			out += Text.hint(str(known["tip"]), "[color=#%s]%s[/color]" % [known["colour"] if ink == "" else ink, word])
		at = found.get_end()
	return out + bbcode.substr(at)


## Any Hangul in a line of BBCode given a hover hint saying what it is (so you can tell a
## translation from something else): the game's own (Hangul.MEANINGS), the menu, pocha words
## and terms of address, and names as they're known (see remember). Steps round tags, and
## leaves anything already inside a hint alone. A run it doesn't know is still marked as
## Korean.
static func explain_hangul(bbcode: String) -> String:
	if _tag_pattern == null:
		_tag_pattern = RegEx.create_from_string("\\[[^\\]]*\\]")
	var out := ""
	var at := 0
	var inside := 0  # hints we're in
	for tag in _tag_pattern.search_all(bbcode):
		var text := bbcode.substr(at, tag.get_start() - at)
		out += text if inside > 0 else _hint_hangul(text)
		var said := tag.get_string()
		if said.begins_with("[hint"):
			inside += 1
		elif said == "[/hint]":
			inside = maxi(0, inside - 1)
		out += said
		at = tag.get_end()
	var rest := bbcode.substr(at)
	return out + (rest if inside > 0 else _hint_hangul(rest))


## A name (or the bar's) in Hangul, as it's known: its hover says whose it is.
static func remember(hangul: String, tip: String) -> void:
	if hangul.strip_edges() != "":
		_remembered[hangul.strip_edges()] = tip


## The hover for a run of Hangul: what it says, as fully as the game knows. "" if it has
## nothing on any of it (the caller still marks it as Korean).
static func hangul_tip(run: String) -> String:
	var whole := _hangul_known(run)
	if whole != "":
		return whole
	var parts := PackedStringArray()
	var any := false
	for word in run.split(" ", false):
		var known := _hangul_known(word)
		any = any or known != ""
		parts.append(known if known != "" else word)
	return "; ".join(parts) if any else ""


static func _hangul_known(run: String) -> String:
	_keep_up_with_menu()
	var bare := _bare(run)
	if _remembered.has(bare):
		return str(_remembered[bare])
	if _known_hangul.is_empty():
		for key in Hangul.MEANINGS:
			_known_hangul[_bare(str(key))] = "%s %s" % [key, Hangul.MEANINGS[key]]
		# The menu, pocha words and terms of address, by their own Hangul ("안녕(하세요)" as
		# 안녕 and 안녕하세요 both).
		var sources: Array = []
		for item in Menu.items() + Catalogue.all():
			sources.append([str(item.get("hangul", "")), "%s %s: %s" % [item.get("hangul", ""), item["name"], item.get("desc", "")]])
		for id in WORDS:
			sources.append([str(WORDS[id]["hangul"]), "%s %s: %s" % [WORDS[id]["hangul"], str(WORDS[id]["spellings"][0]).capitalize() if not WORDS[id]["spellings"].is_empty() else id, WORDS[id]["means"]]])
		for id in Address.TERMS:
			sources.append([str(Address.TERMS[id]["hangul"]), "%s %s: %s" % [Address.TERMS[id]["hangul"], str(id).capitalize(), Address.TERMS[id]["means"]]])
		for source in sources:
			var hangul := str(source[0])
			for key in [hangul, hangul.replace("(", "").replace(")", ""), hangul.get_slice("(", 0)]:
				if key != "" and not _known_hangul.has(_bare(key)):
					_known_hangul[_bare(key)] = str(source[1])
	return str(_known_hangul.get(bare, ""))


## Hangul without the punctuation round it ("만석!" and "만석" are the same word).
static func _bare(run: String) -> String:
	return run.strip_edges().rstrip("!?~…. ").lstrip("(").rstrip(")")


static func _hint_hangul(text: String) -> String:
	if _hangul_pattern == null:
		# A run of Hangul (syllables, or ㅋㅋㅋ), with spaces or digits between its words, and
		# the punctuation after it ("새벽 2시", "주문 폭주!").
		_hangul_pattern = RegEx.create_from_string("[\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+(?:[ 0-9]*[\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+)*[!?~…]*")
	var out := ""
	var at := 0
	for found in _hangul_pattern.search_all(text):
		var run := found.get_string()
		out += text.substr(at, found.get_start() - at)
		var tip := hangul_tip(run)
		out += Text.hint(tip if tip != "" else "%s: Korean, in Hangul" % run, run)
		at = found.get_end()
	return out + text.substr(at)


## The Korean words in some plain text, one entry per time it's said (as lookup()'s "word").
## names: people's names, which don't count.
static func words_in(text: String, names: Array = []) -> Array:
	var skip := _name_parts(names)
	var words: Array = []
	for found in _word_pattern().search_all(text):
		var spelling := found.get_string(1).to_lower()
		if not skip.has(spelling):
			words.append(str(lookup()[spelling]["word"]))
	return words


## Every spelling, longest first, as one pattern (made once).
static func _word_pattern() -> RegEx:
	_keep_up_with_menu()
	if _pattern == null:
		var spellings: Array = lookup().keys()
		spellings.sort_custom(func(a, b): return str(a).length() > str(b).length())
		var escaped := PackedStringArray(spellings.map(func(s): return _regex_escape(str(s))))
		_pattern = RegEx.create_from_string("(?i)(?<![\\w-])(" + "|".join(escaped) + ")(?![\\w-])")
	return _pattern


static func _name_parts(names: Array) -> PackedStringArray:
	var parts := PackedStringArray()
	for person in names:
		parts.append_array(str(person).to_lower().split(" ", false))
	return parts


static func _regex_escape(value: String) -> String:
	var out := ""
	for c in value:
		out += ("\\" + c) if ".^$*+?()[]{}|\\".contains(c) else c
	return out
