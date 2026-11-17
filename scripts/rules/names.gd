extends RefCounted
## Names: checked, turned to Korean order and the usual casing, and shown in Hangul too
## (checked against the romanised name, and dropped rather than shown wrong).
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


const MAX_NAME_LENGTH := 30


## A new customer's name and gender, the first of two steps (it's quick, so a retry costs
## little): {"name": family name first, in English letters, "gender": "woman" or "man"}.
## taken: the names of everyone already at the counter. Two people there can't share a name
## (it would confuse the transcript, and the AI). gender: one the game has already decided
## (then only the name is needed).
static func validate_customer_name(data: Variant, taken: Array = [], gender: String = "") -> String:
	if gender != "" and typeof(data) == TYPE_DICTIONARY:
		data["gender"] = gender
	var problem := Text.check_fields(data, ["name", "gender"])
	if problem != "":
		return problem
	var customer_name := Text.tidy_text(data["name"])
	if gender == "":
		# The AI's choice: woman or man (non-binary customers are the game's decision).
		gender = Text.tidy_text(data["gender"]).to_lower()
		if gender not in ["woman", "man"]:
			return "\"gender\" must be \"woman\" or \"man\""
	if customer_name.split(" ", false).size() < 2:
		return "the name needs a family name and a given name, family name first"
	customer_name = name_case(family_name_first(customer_name))
	if customer_name.length() > MAX_NAME_LENGTH:
		return "the name was far too long"
	for c in customer_name:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c in [" ", "-", "'"]):
			return "the name must be in English letters"
	for other in taken:
		if customer_name.to_lower() == str(other).to_lower():
			return "someone called %s is already at the counter: pick a different name" % customer_name
	data["name"] = customer_name
	data["gender"] = gender
	data["hangul"] = fit_hangul(customer_name, data.get("hangul", ""))  # shown only if it fits
	return ""


## Western order ("Min-jae Lee") turned round to Korean order ("Lee Min-jae"), when the
## first part isn't a family name and the last is. Small models do this now and then.
## Korean names as they're usually romanised: "Kim Jae-Ho" -> "Kim Jae-ho", "KIM JI-HO" -> "Kim Ji-ho".
static func name_case(full: String) -> String:
	var parts := PackedStringArray()
	for part in full.split(" ", false):
		var pieces := part.split("-", false)
		var tidy := PackedStringArray()
		for k in pieces.size():
			tidy.append(pieces[k].to_lower().capitalize() if k == 0 else pieces[k].to_lower())
		parts.append("-".join(tidy))
	return " ".join(parts)


static func family_name_first(full: String) -> String:
	var parts := full.split(" ", false)
	if parts.size() == 2 and not SURNAMES.has(parts[0].to_lower()) and SURNAMES.has(parts[1].to_lower()):
		return "%s %s" % [parts[1], parts[0]]
	return full


## Common family names: romanised (any common spelling) -> Hangul.
const SURNAMES := {
	"kim": ["김"], "gim": ["김"], "lee": ["이"], "yi": ["이"], "rhee": ["이"], "park": ["박"], "bak": ["박"], "pak": ["박"],
	"choi": ["최"], "choe": ["최"], "jung": ["정"], "jeong": ["정"], "chung": ["정"], "kang": ["강"], "gang": ["강"],
	"cho": ["조"], "jo": ["조"], "yoon": ["윤"], "yun": ["윤"], "jang": ["장"], "chang": ["장"], "lim": ["임", "림"],
	"im": ["임"], "rim": ["림", "임"], "han": ["한"], "oh": ["오"], "o": ["오"], "seo": ["서"], "suh": ["서"],
	"shin": ["신"], "sin": ["신"], "kwon": ["권"], "gwon": ["권"], "hwang": ["황"], "ahn": ["안"], "an": ["안"],
	"song": ["송"], "yoo": ["유", "류"], "yu": ["유", "류"], "ryu": ["류", "유"], "hong": ["홍"], "jeon": ["전"],
	"jun": ["전"], "ko": ["고"], "go": ["고"], "moon": ["문"], "mun": ["문"], "yang": ["양"], "son": ["손"],
	"bae": ["배"], "baek": ["백"], "paik": ["백"], "heo": ["허"], "hur": ["허"], "nam": ["남"], "noh": ["노"],
	"no": ["노"], "roh": ["노"], "ha": ["하"], "kwak": ["곽"], "sung": ["성"], "seong": ["성"], "cha": ["차"],
	"joo": ["주"], "ju": ["주"], "woo": ["우"], "min": ["민"], "na": ["나"], "jin": ["진"], "ji": ["지"],
	"eom": ["엄"], "um": ["엄"], "chae": ["채"], "won": ["원"], "cheon": ["천"], "chun": ["천"], "bang": ["방"],
	"gong": ["공"], "kong": ["공"], "hyun": ["현"], "hyeon": ["현"], "byun": ["변"], "byeon": ["변"], "yeom": ["염"],
	"do": ["도"], "seok": ["석"], "sun": ["선"], "ma": ["마"], "gil": ["길"], "pyo": ["표"], "wang": ["왕"],
	"koo": ["구"], "goo": ["구"], "gu": ["구"], "ku": ["구"], "maeng": ["맹"], "tak": ["탁"], "yeo": ["여"],
	"ok": ["옥"], "jegal": ["제갈"], "namgung": ["남궁"], "hwangbo": ["황보"], "seonwoo": ["선우"],
}


## Hangul syllables start with one of these 19 consonants (ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ);
## which ones each romanised start can be.
const ROMAN_STARTS := [
	["kk", [1]], ["tt", [4]], ["pp", [8]], ["ss", [10]], ["jj", [13]], ["ch", [14, 12]], ["sh", [9]],
	["g", [0, 1]], ["k", [0, 15, 1]], ["n", [2]], ["d", [3, 4]], ["t", [16, 3]], ["r", [5, 2, 11]], ["l", [5, 2, 11]],
	["m", [6]], ["b", [7, 8]], ["p", [17, 7]], ["s", [9, 10]], ["j", [12, 13]], ["c", [14]], ["h", [18]], ["f", [17]],
]


## The fallback cat names in Hangul.
const CAT_HANGUL := {"Nabi": "나비", "Nyang-i": "냥이", "Mandu": "만두", "Kong-i": "콩이", "Gamja": "감자", "Bori": "보리", "Chijeu": "치즈",
	"Hotteok": "호떡", "Kkami": "까미", "Kkamjang-i": "깜장이", "Dubu": "두부", "Seolgi": "설기", "Godeungeo": "고등어", "Hodu": "호두",
	"Samsaek-i": "삼색이", "Jaetbit": "잿빛"}  # (the cats' nicknames: see CatRules.CAT_NICKNAMES)


## A name in Hangul, if it fits the romanised name: Hangul letters only, a sensible length, the
## family name matching, and each syllable starting with the right consonant (when the
## syllables can be lined up, as in "Kim Ji-ho" and 김지호). Returns it tidied, or "" if not.
static func fit_hangul(roman: String, hangul: Variant) -> String:
	var written := Text.tidy_text(str(hangul if hangul != null else "")).replace(" ", "")
	if written.length() < 1 or written.length() > 5:
		return ""
	for c in written:
		if c.unicode_at(0) < 0xAC00 or c.unicode_at(0) > 0xD7A3:
			return ""
	var parts := roman.to_lower().split(" ", false)
	if parts.size() >= 2:  # a person: family name first
		if written.length() < 2:
			return ""
		var family: Array = SURNAMES.get(parts[0], [])
		if not family.is_empty() and not family.any(func(h): return written.begins_with(h)):
			return ""
	var syllables := PackedStringArray()
	for part in parts:
		for piece in part.split("-", false):
			syllables.append(piece)
	if syllables.size() == written.length():
		for i in syllables.size():
			if not _starts_alike(syllables[i], written[i]):
				return ""
	elif not syllables.is_empty() and not _starts_alike(syllables[0], written[0]):
		return ""
	return written


## Whether a romanised syllable and a Hangul syllable start with the same sound.
static func _starts_alike(roman: String, syllable: String) -> bool:
	var initial := floori((syllable.unicode_at(0) - 0xAC00) / 588.0)
	var start := roman.to_lower()
	if start == "" or start[0] in ["a", "e", "i", "o", "u", "y", "w"]:
		return initial == 11  # ㅇ: a syllable starting with a vowel
	for entry in ROMAN_STARTS:
		if start.begins_with(entry[0]):
			return initial in entry[1]
	return true  # a letter we don't know: don't hold it against them


## The given name in a full name ("Kim Ji-ho" -> "Ji-ho"); a one-word name stays as it is.
static func given_name(full: String) -> String:
	var parts := full.strip_edges().split(" ", false, 1)
	return parts[1] if parts.size() > 1 else full.strip_edges()
