extends RefCounted
## The show's people and places: the owner's niece or nephew who films it, and the channels it's
## booked on. The game decides the facts (niece or nephew; which rung; when a new channel's
## needed), the AI the names, checked here: the niece or nephew's name (in Hangul too) and their
## stream's handle; a channel's name in Hangul and English, with what it means. Never a real
## broadcaster, platform or app, and never one of the bar's earlier channels. Offline (or when
## the AI can't), the game's own names. Kept with the show: "pd" (who films it), "channel" (now)
## and "channels" (every one it's been on: the rung, the name, the seasons).
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")
const Names = preload("res://scripts/rules/names.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")

const MAX_HANDLE := 20
const MAX_ENGLISH := 24
const MAX_MEANING := 60
const MAX_HANGUL := 8

## Real broadcasters, platforms and apps a channel's name may never be or contain (whole words,
## any case). The checks are the game's, so the AI's names stay made up.
const REAL := ["KBS", "MBC", "SBS", "EBS", "tvN", "JTBC", "Mnet", "TV Chosun", "Chosun", "Channel A", "MBN", "ENA", "YTN", "OCN", "Arirang TV",
	"Netflix", "YouTube", "TikTok", "Instagram", "Insta", "Naver", "Kakao", "Afreeca", "AfreecaTV", "SOOP", "Twitch", "Coupang", "Wavve", "Tving",
	"Disney", "Hulu", "HBO", "BBC", "CNN", "Facebook", "Twitter", "Weverse", "VLive", "Chzzk", "Shorts", "Reels",
	"케이비에스", "엠비씨", "에스비에스", "유튜브", "틱톡", "인스타", "네이버", "카카오", "아프리카", "넷플릭스", "티빙", "웨이브", "쿠팡"]

## The game's own, when the AI can't: a niece's or nephew's name, by who they are.
const RELATIVES := {
	"niece": [{"name": "Kim Ji-woo", "hangul": "김지우"}, {"name": "Park Seo-yeon", "hangul": "박서연"}, {"name": "Lee Ha-eun", "hangul": "이하은"}, {"name": "Choi Yu-na", "hangul": "최유나"}],
	"nephew": [{"name": "Kim Do-yoon", "hangul": "김도윤"}, {"name": "Park Ji-ho", "hangul": "박지호"}, {"name": "Lee Jun-seo", "hangul": "이준서"}, {"name": "Choi Min-jae", "hangul": "최민재"}],
}
## ...and channels, by rung.
const FALLBACK_CHANNELS := {
	"video": [{"hangul": "포차로그", "english": "Pocha Log", "meaning": "a pocha's video diary"},
		{"hangul": "밤포차", "english": "Night Pocha", "meaning": "a tent bar at night"},
		{"hangul": "포장마차TV", "english": "Tent Bar TV", "meaning": "tent bar TV"}],
	"network": [{"hangul": "달빛TV", "english": "Moonlight TV", "meaning": "moonlight"},
		{"hangul": "한빛방송", "english": "Hanbit Broadcasting", "meaning": "a great light"},
		{"hangul": "새벽TV", "english": "Dawn TV", "meaning": "the small hours before dawn"},
		{"hangul": "별빛방송", "english": "Starlight Broadcasting", "meaning": "starlight"}],
}


## Niece or nephew: the game's choice, from a roll.
static func relation(roll: float) -> String:
	return "niece" if roll < 0.5 else "nephew"


static func gender_of(relation_word: String) -> String:
	return "woman" if relation_word == "niece" else "man"


## Whether text names a real broadcaster, platform or app (a whole word, any case; Hangul anywhere).
static func names_real(text: String) -> String:
	var lower := " %s " % text.to_lower()
	for real in REAL:
		var word := str(real).to_lower()
		var is_latin := word.unicode_at(0) < 0x1100
		if is_latin:
			var at := lower.find(word)
			while at >= 0:
				var before := lower.substr(at - 1, 1) if at > 0 else " "
				var after := lower.substr(at + word.length(), 1)
				if not before.is_valid_identifier() and not (after.is_valid_identifier() or after.is_valid_int()):
					return str(real)
				at = lower.find(word, at + 1)
		elif text.contains(word):
			return str(real)
	return ""


## The niece or nephew, as the AI invents them: {"name", "hangul", "handle"}. Checked: a Korean
## name, family name first (in Hangul, shown only if it fits); a handle of lowercase letters,
## digits, dots and underscores (an "@" in front is dropped), naming nothing real. Tidies data in place.
static func validate_relative(data: Variant) -> String:
	var problem := Text.check_fields(data, ["name", "handle"])
	if problem != "":
		return problem
	var full := Text.tidy_text(data["name"])
	if full.split(" ", false).size() < 2:
		return "the name needs a family name and a given name, family name first"
	full = Names.name_case(Names.family_name_first(full))
	for c in full:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c in [" ", "-", "'"]):
			return "the name must be in English letters"
	var handle := Text.tidy_text(data["handle"]).to_lower().trim_prefix("@")
	if handle.length() < 4 or handle.length() > MAX_HANDLE:
		return "the handle must be 4 to %d characters" % MAX_HANDLE
	if not (handle.unicode_at(0) >= 97 and handle.unicode_at(0) <= 122):
		return "the handle must start with a letter"
	for c in handle:
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in ["_", "."]):
			return "the handle can only have lowercase letters, numbers, dots and underscores (not \"%s\")" % c
	var real := names_real(handle.replace("_", " ").replace(".", " "))
	if real != "":
		return "the handle names a real platform (%s): make one up" % real
	data["name"] = full
	data["hangul"] = Names.fit_hangul(full, data.get("hangul", ""))
	data["handle"] = handle
	return ""


## A channel's name, as the AI invents it: {"hangul", "english", "meaning"}. Checked: Hangul (with
## "TV" or "+" allowed, as Korean channels write them), English letters for the English name, a
## short meaning in English; naming nothing real, and none of the bar's earlier channels (taken:
## their names, any case). Tidies data in place.
static func validate_channel(data: Variant, earlier: Array = []) -> String:
	var problem := Text.check_fields(data, ["hangul", "english", "meaning"])
	if problem != "":
		return problem
	var hangul := Text.tidy_text(data["hangul"]).replace(" ", "")
	var english := Text.unquote(Text.tidy_text(data["english"]))
	var meaning := Text.unquote(Text.tidy_text(data["meaning"]))
	if hangul.length() < 2 or hangul.length() > MAX_HANGUL:
		return "the Hangul name must be 2 to %d characters" % MAX_HANGUL
	var syllables := 0
	for c in hangul.replace("TV", "").replace("+", ""):
		if c.unicode_at(0) >= 0xAC00 and c.unicode_at(0) <= 0xD7A3:
			syllables += 1
		elif not (c >= "0" and c <= "9"):
			return "the Hangul name must be Hangul (and \"TV\", \"+\" or a number if you like), not \"%s\"" % c
	if syllables < 2:
		return "the Hangul name needs at least two Hangul syllables"
	if english.length() < 3 or english.length() > MAX_ENGLISH:
		return "the English name must be 3 to %d characters" % MAX_ENGLISH
	for c in english:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in [" ", "-", "'", "+", "&"]):
			return "the English name must be in English letters (not \"%s\")" % c
	if meaning.length() < 2 or meaning.length() > MAX_MEANING:
		return "the meaning must be a few words of English (at most %d characters)" % MAX_MEANING
	for text in [hangul, english]:
		var real := names_real(text)
		if real != "":
			return "%s is a real channel or platform: make one up" % real
	for name_before in earlier:
		if str(name_before).to_lower() in [hangul.to_lower(), english.to_lower()]:
			return "the show's been on %s before: a new name" % name_before
	data["hangul"] = hangul
	data["english"] = english
	data["meaning"] = meaning
	return ""


## The game's own niece or nephew (offline, or when the AI can't): from the list, by a roll,
## with a handle made from their given name.
static func fallback_relative(relation_word: String, roll: float) -> Dictionary:
	var choices: Array = RELATIVES.get(relation_word, RELATIVES["niece"])
	var picked: Dictionary = choices[clampi(floori(roll * choices.size()), 0, choices.size() - 1)].duplicate()
	picked["handle"] = "%s_pocha_live" % Names.given_name(str(picked["name"])).to_lower().replace("-", "")
	return picked


## The game's own channel for a rung (offline, or when the AI can't): the first not taken.
static func fallback_channel(rung: String, earlier: Array) -> Dictionary:
	for each in FALLBACK_CHANNELS.get(rung, FALLBACK_CHANNELS["network"]):
		if not earlier.any(func(t): return str(t).to_lower() in [str(each["hangul"]).to_lower(), str(each["english"]).to_lower()]):
			return each.duplicate()
	var first: Dictionary = FALLBACK_CHANNELS.get(rung, FALLBACK_CHANNELS["network"])[0].duplicate()
	first["english"] = "%s 2" % first["english"]  # (every one taken: a second of the first)
	first["hangul"] = "%s2" % first["hangul"]
	return first


## The phone stream's channel: the niece or nephew's own handle.
static func stream_channel(relative: Dictionary) -> Dictionary:
	return {"hangul": "", "english": "@" + str(relative.get("handle", "")), "meaning": "%s's own stream" % Names.given_name(str(relative.get("name", "")))}


## Every name the show's channels have had (for the check: never the same again).
static func taken_names(show: Dictionary) -> Array:
	var names: Array = []
	for each in show.get("channels", []):
		for key in ["hangul", "english"]:
			if str(each.get(key, "")) != "":
				names.append(str(each[key]))
	return names


## Books the show on a channel for its rung, from this season: show["channel"], and the history.
static func book(show: Dictionary, rung: String, channel: Dictionary, season: int) -> void:
	var booked := channel.duplicate()
	booked["rung"] = rung
	booked["from_season"] = season
	show["channel"] = booked
	var history: Array = show.get("channels", [])
	history.append(booked.duplicate())
	show["channels"] = history


## Whether the show needs a channel booked (none yet, or it's moved to a rung its channel isn't on).
static func needs_booking(show: Dictionary) -> bool:
	return str(show.get("channel", {}).get("rung", "")) != str(show.get("rung", Ladder.OLDER))


## "Moonlight TV" (the English, for reading at a glance), or the stream's "@jiwoo_pocha_live".
static func display_name(channel: Dictionary) -> String:
	return str(channel.get("english", ""))


## The channel as words: "달빛TV (Moonlight TV)", "@jiwoo_pocha_live".
static func full_name(channel: Dictionary) -> String:
	var hangul := str(channel.get("hangul", ""))
	return ("%s (%s)" % [hangul, channel.get("english", "")]) if hangul != "" else str(channel.get("english", ""))


## Its hover: "달빛TV Dalbit TV: Moonlight TV, moonlight. Network TV."
static func hover(channel: Dictionary) -> String:
	var rung := str(channel.get("rung", ""))
	var where := str(Ladder.rung(rung)["short"]) if rung != "" else ""
	return "%s: %s%s." % [full_name(channel), channel.get("meaning", ""), (". " + where.left(1).to_upper() + where.substr(1)) if where != "" else ""]


## Who's behind the camera, for the prompts: on the phone stream, the niece or nephew on their
## phone; on the channel, its camera; on TV, the show's crew.
static func camera_crew(show: Dictionary) -> String:
	var rung := str(show.get("rung", Ladder.OLDER))
	var relative: Dictionary = show.get("pd", {})
	if rung == "phone" and not relative.is_empty():
		return "%s, the owner's %s, filming on %s phone," % [Names.given_name(str(relative["name"])), relative.get("relation", "niece"), "her" if str(relative.get("relation", "niece")) == "niece" else "his"]
	if rung == "video":
		return "The channel's camera"
	return "The show's camera crew"
