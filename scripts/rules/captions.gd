extends RefCounted
## Korean TV captions: the game's own, from what happens, and the reactions the AI picks from
## what's said.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Address = preload("res://scripts/rules/address.gd")
const Names = preload("res://scripts/rules/names.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")


## Korean variety-show captions (자막, jamak): when something noteworthy happens, one pops up
## by whoever it's about, with a sound sting. The game decides when (from what it already
## knows), and owns every word, so they're always right. Each kind has its words, as [Hangul,
## English], several to pick from at random, so they don't repeat too often (and the English
## mixes and matches pieces: "<SOLO|LONE> <DINER|WOLF>" picks one of each); the English
## carries the romanised Korean for the words worth learning, like "JJAN!". Blanks are filled
## from the game's facts (see caption_words), and a wording is only picked when the game has
## everything it needs, so every kind has at least one with no blanks but {they}. Then an icon,
## a colour, its sound sting, and whether it's an emergency (the flashing red border and
## siren, like the red light in Please Take Care of My Refrigerator).
const CAPTIONS := {
	# Emergencies
	"full_house": {"words": [["만석!", "FULL HOUSE<!|!!|?!>"], ["자리 없음!", "NO SEATS LEFT<!|…|?!>"], ["만석!", "EVERY STOOL <TAKEN|FULL|GONE>!"],
		["만석!", "<SORRY|NOT TONIGHT|NEXT TIME>, PAL"]],
		"icon": "🚨", "colour": "ff3b3b", "sound": "siren", "emergency": true},
	"stove": {"words": [["주문 폭주!", "ORDERS PILING UP<!|!!>"], ["비상!", "BISANG! <EMERGENCY|RED ALERT|ALL HANDS>!"], ["주문 폭주!", "{dishes} DISHES <WAITING|QUEUING|IN THE QUEUE>!"],
		["불났다!", "THE STOVE'S ON FIRE <(NOT REALLY)|(FIGURATIVELY)|(SORT OF)>"], ["주문 폭주!", "{owner} <PANICS|SWEATS|DOESN'T PANIC (MUCH)>"]],
		"icon": "🚨", "colour": "ff3b3b", "sound": "siren", "emergency": true},
	# The night
	"rush": {"words": [["퇴근 러시!", "THE AFTER-WORK <RUSH|STAMPEDE|FLOOD>!"], ["퇴근 러시!", "{seated} AT THE COUNTER <ALREADY|AND COUNTING>!"],
		["바쁘다 바빠!", "BAPPEUDA BAPPA! <SO BUSY|BUSY BUSY|NO REST>!"], ["퇴근 러시!", "OFFICE <ESCAPEES|REFUGEES|SURVIVORS> INCOMING"]],
		"icon": "🏃", "colour": "ffb400", "sound": "whoosh", "emergency": false},
	"dawn": {"words": [["새벽 감성 ON", "SAEBYEOK GAMSEONG: 2AM <FEELS|MOOD|HONESTY>"], ["새벽 2시", "2AM: <TIME FOR HONESTY|CONFESSION O'CLOCK|THE DEEP TALK HOUR>"],
		["새벽 감성 ON", "{seated} <STILL HERE|HANGING ON|NOT GOING HOME> AT 2AM"]],
		"icon": "🌌", "colour": "b48cff", "sound": "sparkle", "emergency": false},
	"quiet": {"words": [["고요…", "ALL <QUIET|STILL|HUSHED>…"], ["고요…", "JUST {owner} AND THE {weather} <NOW|LEFT|TONIGHT>"], ["아무도 없다…", "<NOBODY|NOT A SOUL|EMPTY STOOLS> LEFT…"],
		["고요…", "{owner} <WIPES THE COUNTER|SITS DOWN AT LAST|STARES INTO THE STEAM>"]],
		"icon": "🌙", "colour": "a8b0ff", "sound": "whoosh", "emergency": false},
	"last_orders": {"words": [["마감!", "LAST ORDERS<!|, PEOPLE!|, DRINK UP!>"], ["영업 끝!", "<THAT'S A WRAP|LIGHTS OUT SOON|TIME'S UP>!"], ["마감!", "{owner} <STACKS THE STOOLS|CALLS TIME|HAS HAD ENOUGH>"]],
		"icon": "🔔", "colour": "ffb400", "sound": "ding", "emergency": false},
	# People coming in
	"new_face": {"words": [["손님 등장!", "A NEW <FACE|CHALLENGER|CUSTOMER>!"], ["누구세요?", "NUGUSEYO? <WHO'S THIS|WHO ARE YOU|AND YOU ARE>?"],
		["손님 등장!", "A WILD {job} APPEARS!"], ["직업 공개", "TONIGHT'S <GUEST|CHALLENGER|MYSTERY GUEST>: {job}"], ["손님 등장!", "{job}, <OFF THE CLOCK|CLOCKED OUT|AFTER HOURS>"]],
		"chance": 0.6, "icon": "👀", "colour": "7fe0c0", "sound": "pop", "emergency": false},
	"late_guest": {"words": [["야밤 손님!", "A LATE-NIGHT <GUEST|STRAY|WANDERER>!"], ["이 시간에?!", "AT THIS <HOUR|TIME>?!"], ["야밤 손님!", "{job}, <AFTER MIDNIGHT|STILL UP|NOT SLEEPING>?!"]],
		"chance": 0.5, "icon": "🌙", "colour": "a8b0ff", "sound": "pop", "emergency": false},
	"solo": {"words": [["혼술!", "HONSUL: <DRINKING SOLO|PARTY OF ONE|ME, MYSELF, SOJU>"], ["혼술 시작", "<SOLO|LONE|PARTY-OF-ONE> <DINER|DRINKER|WOLF|SOUL>"],
		["혼술 시작", "A TABLE FOR ONE<!|…|, PLEASE>"], ["비 오는 날 혼술…", "HONSUL IN THE {weather}<…|!>"]],
		"icon": "🍶", "colour": "7fd8ff", "sound": "pop", "emergency": false},
	"regular_back": {"words": [["돌아왔다!", "{they} BACK<!|!!|, AGAIN!> ★"], ["단골 출석!", "<PRESENT AND CORRECT|CHECKED IN|ATTENDANCE: YES>! ★"],
		["단골 출석!", "VISIT NUMBER {visit} ★"], ["돌아왔다!", "{name} IS <BACK|HOME|HERE AGAIN>! ★"], ["단골 출석!", "THE USUAL <STOOL|FACE|SUSPECT>! ★"]],
		"icon": "👋", "colour": "4fd2ff", "sound": "ding", "emergency": false},
	"founding": {"words": [["단골 등장!", "THE <OLD|ORIGINAL|LEGENDARY> REGULAR! ★★"], ["터줏대감", "TEOJUTDAEGAM: <PART OF THE FURNITURE|THE TENT'S OLD GUARD|BASICALLY STAFF> ★★"],
		["단골 등장!", "{name}, {years} ★★"]],
		"icon": "👑", "colour": "ffd23f", "sound": "ding", "emergency": false},
	"jjin_chin": {"words": [["찐친 등장!", "JJIN-CHIN: <REAL FRIENDS|TRUE FRIENDS|BESTIES>! ∞"], ["찐친 등장!", "{name} & {friend} ∞"], ["또 만났네", "TOGETHER AGAIN<!|…|?!> ∞"],
		["찐친 등장!", "THE <DUO|PAIR|TAG TEAM> IS BACK ∞"]],
		"icon": "🤝", "colour": "ff8fc0", "sound": "sparkle", "emergency": false},
	# At the counter
	"cheers": {"words": [["짠!", "JJAN! <CHEERS|BOTTOMS UP|HERE WE GO>!"], ["건배!", "GEONBAE! <CHEERS|TO TONIGHT|TO SURVIVING MONDAY>!"], ["원샷!", "ONE SHOT<!|!!|, NO SIPPING!>"],
		["짠!", "{drink} <TIME|O'CLOCK|FIRST>!"]],
		"chance": 0.7, "icon": "🍶", "colour": "7fd8ff", "sound": "pop", "emergency": false},
	"another_round": {"words": [["한 잔 더!", "<ONE MORE|ANOTHER|AND ANOTHER><!|?!|…>"], ["한 잔 더!", "ROUND {drinks}<!|?!|, FIGHT!>"], ["달린다!", "DALLINDA! <ON A ROLL|FULL SPEED|NO BRAKES>!"],
		["간 건강 주의", "<LIVER|HANGOVER|TOMORROW> WARNING"]],
		"chance": 0.7, "icon": "🍻", "colour": "7fd8ff", "sound": "pop", "emergency": false},
	"order_up": {"words": [["나왔습니다~", "ORDER UP<!|~|, HOT!>"], ["먹방 시작!", "MUKBANG <TIME|MODE: ON|BEGINS>!"], ["폭풍 흡입!", "<INHALING IT|NO CHEWING|GONE IN SECONDS>!"],
		["꿀맛!", "GGULMAT! <HONEY-TASTY|SO GOOD|CHEF'S KISS>!"], ["폭풍 흡입!", "{dish}, <INHALED|DEMOLISHED|VANISHED|ANNIHILATED>!"],
		["비주얼 실화?!", "THAT {dish}, <FOR REAL|IS THAT LEGAL|LOOK AT IT>?!"], ["나왔습니다~", "ONE {dish}, <HOT|STEAMING|STRAIGHT FROM THE FIRE>!"]],
		"chance": 0.7, "icon": "🍲", "colour": "ff9a4f", "sound": "ding", "emergency": false},
	"eating": {"words": [["맛있겠다~", "MASITGETDA~ <IT MUST BE GOOD|LOOKS AMAZING|I'M HUNGRY NOW>!"], ["잘 먹네!", "JAL MEONGNE! <YOU EAT WELL|WHAT AN APPETITE|EATING LIKE A CHAMP>!"],
		["먹을 줄 아네", "<KNOWS HOW TO EAT|A PRO EATER|EATS LIKE THEY MEAN IT>!"], ["잘 먹네!", "{name} <EATS WELL|CLEARS THE PLATE|ISN'T SHARING>!"]],
		"icon": "😋", "colour": "ff9a4f", "sound": "ding", "emergency": false},
	"multitask": {"words": [["사장님 멀티태스킹!", "THE OWNER <MULTITASKS|HAS SIX HANDS|DOES IT ALL>!"], ["초스피드!", "<SUPER|LIGHTNING|INHUMAN> SPEED!"],
		["사장님 멀티태스킹!", "{seated} CUSTOMERS, ONE {owner}"]],
		"icon": "⚡", "colour": "ffd23f", "sound": "whoosh", "emergency": false},
	"chat_start": {"words": [["대화 시작?!", "STRANGERS <TALKING|CHATTING|BONDING>?!"], ["급 친해짐", "<SUDDENLY|INSTANTLY|ALREADY> FRIENDS"], ["대화 시작?!", "{name} × {friend}<?!|…?>"]],
		"icon": "💬", "colour": "c79bff", "sound": "whoosh", "emergency": false},
	"joins": {"words": [["합류!", "{they} <JOINING IN|IN TOO|NOT MISSING THIS>!"], ["합류!", "{name} <JOINS IN|WANTS IN|PULLS UP A STOOL>!"], ["나도 나도!", "NADO NADO! <ME TOO|COUNT ME IN>!"]],
		"icon": "🙋", "colour": "c79bff", "sound": "pop", "emergency": false},
	"owner_joins": {"words": [["사장님 참전!", "THE OWNER JOINS THE <FIGHT|BATTLE|PARTY>!"], ["사장님 등판!", "{owner} <STEPS UP|ENTERS THE CHAT|HAS OPINIONS>"]],
		"icon": "🔥", "colour": "ff7a4f", "sound": "whoosh", "emergency": false},
	"friendlier": {"words": [["{term_hangul}!", "\"{term}\" <NOW|FROM NOW ON|UNLOCKED>!"], ["호칭 승급!", "PROMOTED TO \"{term}\"<!|!!>"], ["호칭 승급!", "<CLOSER|FRIENDLIER|NO MORE FORMALITIES> NOW!"]],
		"icon": "💕", "colour": "ff8fc0", "sound": "sparkle", "emergency": false},
	# Paying and going
	"bill": {"words": [["계산!", "<PAID UP|SETTLED|ALL SQUARE>!"], ["계산!", "{amount}"], ["잘 먹었습니다!", "JAL MEOGEOTSEUMNIDA! <THANKS FOR THE FOOD|THAT WAS GOOD>!"]],
		"chance": 0.5, "icon": "💸", "colour": "8cf05a", "sound": "pop", "emergency": false},
	"big_spender": {"words": [["통 큰 손님!", "BIG <SPENDER|WALLET|NIGHT>!"], ["통 큰 손님!", "BIG SPENDER! {amount}"], ["플렉스!", "FLEX! {amount}"], ["플렉스!", "{amount}?! <PAYDAY|RICH|SPLASHING OUT>!"]],
		"icon": "💰", "colour": "ffd23f", "sound": "ding", "emergency": false},
	"new_regular": {"words": [["단골 탄생?!", "A NEW REGULAR<?!|!!> ★"], ["단골 탄생?!", "{name}, A REGULAR <NOW|IN THE MAKING>?! ★"], ["또 올 것 같은 예감", "{they} <COMING BACK|HOOKED|ONE OF US>… ★"]],
		"icon": "✨", "colour": "8cf05a", "sound": "sparkle", "emergency": false},
	# The cat
	"cat_lap": {"words": [["냥!", "{cat} <MAKES A FRIEND|CLAIMS A LAP|SETTLES IN>"], ["심쿵!", "SIMKUNG! <HEART-THUMP|TOO CUTE|CAN'T MOVE NOW>!"], ["냥!", "{cat} <CHOOSES|PICKS|ADOPTS> {name}"],
		["집사 간택!", "<CHOSEN BY THE CAT|THE CAT HAS SPOKEN|A NEW BUTLER>!"]],
		"icon": "🐾", "colour": "ffc46b", "sound": "nyang", "emergency": false},
	"cat_out": {"words": [["가출?!", "{cat} RUNS <OFF|AWAY>?!"], ["가출?!", "THE CAT'S <OFF|GONE|OUT>!"], ["순찰 중", "{cat} ON <PATROL|THE PROWL|NIGHT SHIFT>"]],
		"icon": "🐈", "colour": "ffc46b", "sound": "nyang", "emergency": false},
	"cat_back": {"words": [["냥이 출근!", "{cat} CLOCKS <IN|BACK IN>"], ["귀가!", "THE CAT'S <BACK|HOME|RETURNED>!"]],
		"icon": "🐈", "colour": "ffc46b", "sound": "nyang", "emergency": false},
}


## A kind with a "chance" (the ones that come up all night: a new face, a bill) is shown only
## that often, so they don't crowd out the rest ("AT THIS TIME?!" four times after midnight).
const CAPTION_STINGS := ["siren", "whoosh", "ding", "sparkle", "nyang", "pop"]


const CAPTION_GAP := 3.0  # real seconds at least between captions (emergencies don't wait)...


const CAPTION_SAME_GAP := 12.0  # ...and between two of the same kind, so none repeats on and on


const CAPTION_SECONDS := 2.6  # how long one stays up


const RUSH_SEATED := 4  # the rush: the first time this many are at the counter


const STOVE_BACKED := 3  # orders piling up: this many dishes waiting at the stove


const QUIET_AFTER := 23 * 60  # gone quiet: the last customer leaving after 11pm


const LATE_GUEST_AFTER := 24 * 60  # a late-night guest: in after midnight


const DAWN_AT := 26 * 60  # 2am feelings


const BIG_SPENDER := 40000  # a bill this big (won) gets a big spender caption


## Whether a caption can show now (real seconds, scaled for tests): not too soon after the last
## one, nor after the last of its kind. last_any and last_same are -1 for never.
static func caption_allowed(kind: String, now: float, last_any: float, last_same: float, gap: float = CAPTION_GAP, same_gap: float = CAPTION_SAME_GAP) -> bool:
	if not CAPTIONS.has(kind):
		return false
	if last_same >= 0.0 and now - last_same < same_gap:
		return false
	if bool(CAPTIONS[kind]["emergency"]):
		return true
	return last_any < 0.0 or now - last_any >= gap


## A caption's words, filled in: {"hangul", "english"}. fill, all optional: gender (for
## "SHE'S BACK!"), name and friend (full names; captions use the given name), term, cat, owner
## (a name: the given name), amount, dish, drink, job, weather, visit, drinks, dishes, seated,
## years. roll (0 to 1) picks among the wordings the game has everything for.
static func caption_words(kind: String, fill: Dictionary = {}, roll: float = 0.0) -> Dictionary:
	var data: Dictionary = CAPTIONS.get(kind, {})
	if data.is_empty():
		return {}
	var values := {"they": str({"woman": "SHE'S", "man": "HE'S"}.get(str(fill.get("gender", "")), "THEY'RE"))}
	for key in fill:
		var value := str(fill[key]).strip_edges()
		if value == "" or key == "gender":
			continue
		match str(key):
			"name", "friend", "owner":
				value = Names.given_name(value).to_upper()
			"term":
				values["term_hangul"] = str(Address.TERMS.get(value, {}).get("hangul", value))
				value = value.to_upper()
			"amount":
				pass
			_:
				value = value.to_upper()
		values[key] = value
	var usable: Array = []
	for wording in data["words"]:
		if _blanks_filled(str(wording[0]) + str(wording[1]), values):
			usable.append(wording)
	if usable.is_empty():
		return {}
	var chosen: Array = usable[clampi(floori(roll * usable.size()), 0, usable.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + str(roll))  # the same roll, the same pieces
	return {"hangul": str(chosen[0]).format(values), "english": pick_pieces(str(chosen[1]), rng).format(values)}


## Mix and match: each "<A|B|C>" in text becomes one of A, B or C.
static func pick_pieces(text: String, rng: RandomNumberGenerator) -> String:
	var out := ""
	var at := 0
	while true:
		var start := text.find("<", at)
		var end := text.find(">", start + 1) if start != -1 else -1
		if start == -1 or end == -1:
			break
		var options := text.substr(start + 1, end - start - 1).split("|")
		out += text.substr(at, start - at) + options[rng.randi_range(0, options.size() - 1)]
		at = end + 1
	return out + text.substr(at)


static func _blanks_filled(text: String, values: Dictionary) -> bool:
	var at := text.find("{")
	while at != -1:
		var end := text.find("}", at)
		if end == -1 or not values.has(text.substr(at + 1, end - at - 1)):
			return false
		at = text.find("{", end)
	return true


## How a caption reads in the transcript: "[TV] 만석! FULL HOUSE!"
static func caption_text(kind: String, fill: Dictionary = {}, roll: float = 0.0) -> String:
	var said := caption_words(kind, fill, roll)
	if said.is_empty():
		return ""
	return "[TV] %s %s" % [said["hangul"], said["english"]]


## The AI spots a big moment in a conversation and writes its caption (in English); the game
## owns the rest: the Hangul (Llama 8B's Korean isn't reliable enough to show), the icon,
## colour and sound, from the mood. "means" goes in the prompt.
const REACTIONS := {
	"shock": {"hangul": ["충격!", "동공지진", "헐!"], "icon": "😱", "colour": "ff4f6d", "sound": "dun",
		"means": "a shock: big news, a confession, a surprise"},
	"sad": {"hangul": ["눈물주의", "짠하다…", "울컥"], "icon": "😢", "colour": "6fa8ff", "sound": "sad",
		"means": "something sad: a loss, a hard time, loneliness"},
	"sweet": {"hangul": ["설렘?", "심쿵!", "핑크빛?"], "icon": "💗", "colour": "ff8fc0", "sound": "sparkle",
		"means": "sparks between two people: flirting, a blush"},
	"warm": {"hangul": ["훈훈", "감동", "따뜻해"], "icon": "🥹", "colour": "ffc46b", "sound": "ding",
		"means": "kindness: someone looked after, a thank-you that means a lot"},
	"funny": {"hangul": ["빵 터짐", "ㅋㅋㅋ", "웃음 폭발"], "icon": "🤣", "colour": "ffd23f", "sound": "boing",
		"means": "a really funny line, or a joke that lands"},
	"awkward": {"hangul": ["어색…", "정적…", "할 말 없음"], "icon": "😅", "colour": "a8b0ff", "sound": "pop",
		"means": "an awkward moment: a silence, a gaffe, the wrong thing said"},
}


const REACTION_STINGS := ["dun", "sad", "sparkle", "ding", "boing", "pop"]


const REACTION_WORDS := 6  # a caption is short: "SHE QUIT HER JOB?!"


const REACTION_CHARS := 40


const REACTION_GAP := 20.0  # real seconds at least between reactions


const REACTION_SECONDS := 3.6  # a reaction stays up a little longer than a routine caption


const REACT_EVERY := 4  # lines of a conversation with the owner between asks


const REACTION_LINES := 6  # how many of the latest lines the AI sees


## How big a moment has to be (the AI says, 1 to 5) to get a caption. Asked just "was it a big
## moment?", Llama 3.1 8B said yes nearly every time; rating it first, it can say "a 2" and
## mean no. (At 4, it hardly ever said yes: 7 captions in six nights. 3 lets the personal
## moments in too.)
const REACTION_MIN_SIZE := 3
## How long a reaction check put off while the owner was needed can wait (game minutes):
## any later and the moment's gone.
const REACTION_STALE_MINUTES := 20.0


## Checks the AI's answer to "was that a big moment?": {"mood": "none"}, or a mood from
## REACTIONS, "who" (one of names, the people talking: a given name will do) and a short
## "caption". Tidies it: who becomes the full name, the caption capitals.
static func validate_reaction(data: Variant, names: Array, items: Array = []) -> String:
	if typeof(data) != TYPE_DICTIONARY or not data.has("mood"):
		return "it didn't include \"mood\""
	var mood := str(data["mood"]).strip_edges().to_lower()
	if mood in ["", "none", "no", "nothing", "null"]:
		data["mood"] = "none"
		return ""
	var size := int(data.get("size", 0)) if typeof(data.get("size", 0)) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING] else 0
	if size < REACTION_MIN_SIZE:
		data["mood"] = "none"  # (not big enough: no caption)
		data["size"] = size
		return ""
	if not REACTIONS.has(mood):
		return "the caption's \"mood\" was \"%s\", which isn't one of %s or \"none\"" % [mood, ", ".join(PackedStringArray(REACTIONS.keys()))]
	var said_who := str(data.get("who", "")).strip_edges().to_lower()
	var who := ""
	for person in names:
		var full := str(person)
		if said_who == full.to_lower() or said_who == Names.given_name(full).to_lower() or said_who == full.get_slice(" ", 0).to_lower() + " " + Names.given_name(full).to_lower():
			who = full
	if who == "":
		return "the caption's \"who\" was \"%s\", which isn't one of the people talking (%s)" % [data.get("who", ""), ", ".join(PackedStringArray(names))]
	var caption := Text.unquote(Text.tidy_text(data.get("caption", ""))).strip_edges()
	if caption == "":
		return "the caption was empty"
	if caption.contains("(") or caption.contains("[") or caption.contains("\n"):
		return "the caption has brackets or more than one line"
	if caption.split(" ", false).size() > REACTION_WORDS or caption.length() > REACTION_CHARS:
		return "the caption was longer than five words"
	if Talk.real_brand(caption) != "":
		return "the caption names a real brand (%s)" % Talk.real_brand(caption)
	var mention := Orders.unordered_mention(caption, items) if not items.is_empty() else ""
	if mention != "":
		return "the caption mentions %s, which nobody ordered" % mention
	if not Talk.romanised_korean(caption, names).is_empty():
		return "the caption has made-up Korean words in it"
	data["mood"] = mood
	data["who"] = who
	data["caption"] = caption.to_upper()
	return ""


## A reaction's words for the screen: {"hangul" (picked by roll from its mood), "english"}.
static func reaction_words(mood: String, caption: String, roll: float = 0.0) -> Dictionary:
	if not REACTIONS.has(mood):
		return {}
	var choices: Array = REACTIONS[mood]["hangul"]
	return {"hangul": str(choices[clampi(floori(roll * choices.size()), 0, choices.size() - 1)]), "english": caption.to_upper()}


## Which caption a night event gets, if any (see night_events.gd): {"kind", "fill"}, or {}.
## facts: the event's own, plus, for "sat_down", "rush_open" (the after-work rush hasn't had
## its caption yet tonight).
static func for_event(event: String, facts: Dictionary) -> Dictionary:
	match event:
		"walked_on":
			if bool(facts.get("first", false)):  # several giving up at once: one caption
				return {"kind": "full_house", "fill": {}}
		"dawn":
			return {"kind": "dawn", "fill": {}}
		"last_orders":
			return {"kind": "last_orders", "fill": {}}
		"sat_down":
			var regular := str(facts.get("regular", ""))
			if regular != "":
				if str(facts.get("friend", "")) != "":
					return {"kind": "jjin_chin", "fill": {"name": facts.get("name", ""), "friend": facts["friend"]}}
				return {"kind": "founding" if regular == "founding" else "regular_back",
					"fill": {"gender": facts.get("gender", ""), "name": facts.get("name", ""), "visit": facts.get("visit", 0), "years": facts.get("years", "")}}
			if bool(facts.get("rush_open", false)) and int(facts.get("seated", 0)) >= RUSH_SEATED:
				return {"kind": "rush", "fill": {}}
			if int(facts.get("seated", 0)) == 1:
				return {"kind": "solo", "fill": {}}
			return {"kind": "late_guest" if int(facts.get("minutes", 0)) >= LATE_GUEST_AFTER else "new_face", "fill": {"job": facts.get("job", "")}}
		"greeted":
			if bool(facts.get("quick", false)):
				return {"kind": "multitask", "fill": {}}
		"drinks_poured":
			if bool(facts.get("first", false)):
				return {"kind": "cheers", "fill": {"drink": facts.get("drink", "")}}
			return {"kind": "another_round", "fill": {"drinks": facts.get("drinks", 0)}}
		"stove_backed":
			return {"kind": "stove", "fill": {"dishes": facts.get("dishes", 0)}}
		"dish_served":
			if int(facts.get("food_served", 0)) == 2:  # their second dish: they're clearly tucking in
				return {"kind": "eating", "fill": {"name": facts.get("name", "")}}
			return {"kind": "order_up", "fill": {"dish": facts.get("dish", "")}}
		"paid":
			return {"kind": "big_spender" if int(facts.get("bill", 0)) >= BIG_SPENDER else "bill", "fill": {"amount": facts.get("amount", "")}}
		"left":
			if int(facts.get("seated", 1)) == 0 and int(facts.get("waiting", 1)) == 0 and not bool(facts.get("last_orders", false)) and int(facts.get("minutes", 0)) >= QUIET_AFTER:
				return {"kind": "quiet", "fill": {}}
		"chat_started":
			return {"kind": "chat_start", "fill": {"name": facts.get("name", ""), "friend": facts.get("friend", "")}}
		"joined_chat":
			return {"kind": "joins", "fill": {"gender": facts.get("gender", ""), "name": facts.get("name", "")}}
		"owner_joined":
			return {"kind": "owner_joins", "fill": {}}
		"cat_moved":
			var spot := str(facts.get("spot", ""))
			if spot == "lap" and bool(facts.get("new_lap", false)):
				return {"kind": "cat_lap", "fill": {"cat": facts.get("cat", ""), "name": facts.get("with", "")}}
			if spot == "street" and not bool(facts.get("was_out", false)):
				return {"kind": "cat_out", "fill": {"cat": facts.get("cat", "")}}
			if bool(facts.get("was_out", false)) and spot != "street":
				return {"kind": "cat_back", "fill": {"cat": facts.get("cat", "")}}
		"became_regular":
			return {"kind": "new_regular", "fill": {"gender": facts.get("gender", ""), "name": facts.get("name", "")}}
		"friendlier":
			return {"kind": "friendlier", "fill": {"term": facts.get("term", "")}}
	return {}
