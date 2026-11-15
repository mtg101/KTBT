extends RefCounted
## Offline mode: a stand-in for the LLM that answers instantly from pre-written characters
## and lines, for machines without a suitable GPU. It's also the fake AI the tests use.
##
## Replies are built to pass the game's rules (scripts/rules.gd), using what the game says
## it's asking for (the "request": purpose plus context), and still go through the same
## checks as real AI replies.
##
## Tests can queue exact replies with CannedAi.scripted (raw JSON text or Dictionaries,
## including deliberately bad ones); while the queue has anything in it, it's used first.

const Menu = preload("res://scripts/menu.gd")
const Rules = preload("res://scripts/rules.gd")

static var scripted: Array = []

## Every pre-written name in Hangul (shown next to the romanised one).
const HANGUL := {
	"Park Mi-sook": "박미숙", "Choi Young-ja": "최영자", "Han Jeong-hee": "한정희", "Kim Sung-ho": "김성호",
	"Lee Dong-wook": "이동욱", "Yoon Jae-seok": "윤재석", "Kim Ji-ho": "김지호", "Park Seo-jun": "박서준",
	"Lee Min-ji": "이민지", "Jung Woo-jin": "정우진", "Bae Joon-young": "배준영", "Choi Hye-rin": "최혜린",
	"Han Seol": "한설", "Kang Da-eun": "강다은", "Oh Sang-chul": "오상철", "Seo Yeon-woo": "서연우",
	"Yoo Ha-neul": "유하늘", "Yoon Na-rae": "윤나래",
}

const OWNERS := {
	"woman": [
		{"name": "Park Mi-sook", "age": 61, "archetype": "gruff-but-soft ajumma", "appearance": "Apron, rubber gloves and reading glasses on a chain.", "personality": "blunt, caring, nosy", "speech_style": "short and scolding", "secret": "She once sang backing vocals for a famous trot singer."},
		{"name": "Choi Young-ja", "age": 68, "archetype": "the tent's unofficial grandmother", "appearance": "A padded vest and a knitted hat pulled low.", "personality": "patient, sharp-eyed, stubborn", "speech_style": "slow, with a proverb for everything", "secret": "She ran this tent with a husband nobody ever met."},
		{"name": "Han Jeong-hee", "age": 47, "archetype": "former chef who walked out of a hotel kitchen", "appearance": "Sleeves rolled up, hair tied back with a pencil through it.", "personality": "proud, funny, restless", "speech_style": "quick and teasing", "secret": "She still gets job offers from the hotel she left, and burns them."},
	],
	"man": [
		{"name": "Kim Sung-ho", "age": 58, "archetype": "quiet ajusshi with a mysterious past", "appearance": "A grey cardigan and a scar across one knuckle.", "personality": "calm, watchful, kind", "speech_style": "few words, each one chosen", "secret": "He was once a bodyguard for a chaebol family."},
		{"name": "Lee Dong-wook", "age": 52, "archetype": "ex-gangster who traded fists for frying pans", "appearance": "A crisp white towel over one shoulder and a tattoo peeking from a sleeve.", "personality": "gruff, loyal, sentimental", "speech_style": "growls, then softens", "secret": "He sends money every month to a family he once wronged."},
		{"name": "Yoon Jae-seok", "age": 64, "archetype": "retired taxi driver who knows every street in Seoul", "appearance": "A flat cap and a radio playing old ballads beside him.", "personality": "chatty, wise, a little sad", "speech_style": "rambling stories with a point at the end", "secret": "He drove the same woman home every Friday for ten years and never asked her name."},
	],
}

## Bar names for offline mode: either named after the owner ("Mi-sook-ne Pocha") or one of these.
const BAR_NAMES := [
	{"name": "Haengbok Pocha", "meaning": "Happiness Tent"},
	{"name": "Byeolbit Pocha", "meaning": "Starlight Tent"},
	{"name": "Dalbit Pojangmacha", "meaning": "Moonlight Tent"},
	{"name": "Bitsori Pocha", "meaning": "Sound of the Rain Tent"},
	{"name": "Golmok Pocha", "meaning": "Back Alley Tent"},
	{"name": "Uri-jip Pocha", "meaning": "Our House Tent"},
	{"name": "Sarang Pocha", "meaning": "Love Tent"},
	{"name": "Saebyeok Pocha", "meaning": "Before-Dawn Tent"},
]
## The canned bar names in Hangul, for the sign (others get "포장마차").
const BAR_HANGUL := {
	"Haengbok Pocha": "행복 포차", "Byeolbit Pocha": "별빛 포차", "Dalbit Pojangmacha": "달빛 포장마차",
	"Bitsori Pocha": "빗소리 포차", "Golmok Pocha": "골목 포차", "Uri-jip Pocha": "우리집 포차",
	"Sarang Pocha": "사랑 포차", "Saebyeok Pocha": "새벽 포차",
}

const CUSTOMERS := [
	{"name": "Kim Ji-ho", "gender": "woman", "age": 34, "job": "office worker", "mood": "worn out", "reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired", "appearance": "A crumpled blazer and a lanyard she forgot to take off."},
	{"name": "Park Seo-jun", "gender": "man", "age": 27, "job": "junior salaryman", "mood": "relieved", "reason": "He escaped the company dinner before the third round.", "speech_style": "polite, nervous laughter", "appearance": "A loosened tie and a suit a size too big."},
	{"name": "Lee Min-ji", "gender": "woman", "age": 29, "job": "night-shift nurse", "mood": "exhausted but wired", "reason": "Her shift ended and she can't face going home to sleep yet.", "speech_style": "brisk, darkly funny", "appearance": "Scrubs under a long padded coat."},
	{"name": "Jung Woo-jin", "gender": "man", "age": 23, "job": "university student", "mood": "triumphant", "reason": "He just finished his last exam of the year.", "speech_style": "loud, excitable", "appearance": "A backpack covered in keyrings and a grin he can't hide."},
	{"name": "Choi Hye-rin", "gender": "woman", "age": 31, "job": "web designer", "mood": "heartbroken", "reason": "Her boyfriend of five years ended it by text this afternoon.", "speech_style": "quiet, trailing off", "appearance": "Smudged eyeliner and a phone she keeps checking."},
	{"name": "Oh Sang-chul", "gender": "man", "age": 55, "job": "taxi driver", "mood": "content", "reason": "He's on his break between fares.", "speech_style": "easygoing, full of road stories", "appearance": "A cap pushed back and a thermos under his arm."},
	{"name": "Seo Yeon-woo", "gender": "man", "age": 38, "job": "chaebol heir in disguise", "mood": "curious, a little lost", "reason": "He wanted one night where nobody knows who he is.", "speech_style": "too formal, then trying to sound casual", "appearance": "A cheap hoodie over very expensive shoes."},
	{"name": "Kang Da-eun", "gender": "woman", "age": 26, "job": "convenience store clerk", "mood": "nervous", "reason": "She's working up the courage to tell someone how she feels.", "speech_style": "hesitant, rehearsing lines under her breath", "appearance": "A neatly ironed shirt and a letter sticking out of her bag."},
	{"name": "Bae Joon-young", "gender": "man", "age": 44, "job": "delivery rider", "mood": "soaked and grumpy", "reason": "His last delivery of the night was cancelled at the door.", "speech_style": "short complaints, then a laugh", "appearance": "A dripping rain cape and a helmet under one arm."},
	{"name": "Yoon Na-rae", "gender": "woman", "age": 36, "job": "single mother and accountant", "mood": "guilty but determined", "reason": "Her mother is babysitting, and this is her first night out in a year.", "speech_style": "warm, apologetic", "appearance": "A tidy coat and a hair clip shaped like a cartoon rabbit."},
	{"name": "Han Seol", "gender": "non-binary", "age": 28, "job": "tattoo artist", "mood": "quietly pleased", "reason": "They just finished a twelve-hour piece and want to sit somewhere warm.", "speech_style": "soft, dry humour", "appearance": "Ink-stained fingers and a long black coat."},
	{"name": "Yoo Ha-neul", "gender": "non-binary", "age": 33, "job": "radio producer", "mood": "restless", "reason": "Their late-night show was cancelled this afternoon.", "speech_style": "fast, thoughtful", "appearance": "Big headphones round their neck and a scarf wound three times."},
]

const OWNER_FIRST_LINES := [
	"There you go. Eat while it's hot, and don't let it go cold on me.",
	"Here. Long day, hm? Sit, eat, the rest can wait.",
	"That should warm you up. You look like you need it.",
]
const OWNER_LINES := [
	"Don't drink on an empty stomach. Eat something first.",
	"Hm. Whoever upset you isn't worth losing sleep over.",
	"I've seen a lot of people sit on that stool. The sad ones always come back smiling, eventually.",
	"You talk, I'll listen. That's what the tent is for.",
	"Rain like this washes the whole city clean. People too, sometimes.",
	"Slow down. The night's long and nobody's chasing you here.",
	"When I was your age, I worried about the same things. Look at me now: still worrying, but with a good apron.",
	"Aigoo. Life's like this tent: a bit leaky, but it keeps standing.",
	"You'll be fine. You have that look, the stubborn kind.",
	"Tell me more. I'm not going anywhere.",
]
const CUSTOMER_LINES := [
	"Honestly? Today was a lot. More than a lot.",
	"I keep telling myself it'll get better. I'm starting to doubt myself.",
	"You're easy to talk to, %s. Easier than anyone at work.",
	"Is it strange to feel more at home here than in my own flat?",
	"Sorry, I didn't mean to dump all that on you.",
	"Maybe you're right. Maybe I've been carrying this too long.",
	"My mother used to say the same thing, you know.",
	"Ha. When you put it like that, it doesn't sound so bad.",
	"I needed a place where nobody expects anything from me.",
	"Can I just sit a while? It's nice listening to the rain.",
]
const CUSTOMER_LAST_LINES := [
	"Thank you, %s. I think I can face tomorrow now.",
	"I should go before the last train. Thank you for tonight, %s.",
	"Here, keep the change. I'll come back when things are better.",
	"That's me done. Thanks for listening, %s.",
]


## Offline mode's TV reactions: one caption per mood.
const REACTION_CAPTIONS := {"shock": "WAIT, WHAT?!", "sad": "THAT ONE HURT", "sweet": "IS THIS A MOMENT?",
	"warm": "SO WHOLESOME", "funny": "TOO FUNNY", "awkward": "SO AWKWARD"}

## A reply for what the game is asking: request["purpose"] is "owner", "customer", "order",
## "extra_order" or "line", plus whatever context that needs.
func reply(request: Dictionary) -> Variant:
	if not scripted.is_empty():
		var next = scripted.pop_front()
		if typeof(next) == TYPE_STRING:
			return JSON.parse_string(next)
		# A copy, so the game can tidy it without touching the test's original.
		return next.duplicate(true) if typeof(next) == TYPE_DICTIONARY else next
	var title := str(request.get("title", "Ajumma"))
	match str(request.get("purpose", "")):
		"owner":
			var owner: Dictionary = OWNERS[str(request.get("gender", "woman"))].pick_random().duplicate()
			owner["hangul"] = HANGUL.get(owner["name"], "")
			return _fit_look(owner, request, 40)
		"hangul":
			var person_name := str(request.get("name", ""))
			return {"hangul": HANGUL.get(person_name, Rules.CAT_HANGUL.get(person_name, ""))}
		"founding_regular":
			var taken: Array = request.get("taken", [])
			var picked := _customer(taken, str(request.get("gender", "")))
			var regular := picked.duplicate()
			regular["hangul"] = HANGUL.get(picked["name"], "")
			regular["history"] = "Started coming the winter the owner first put up the tarp, and never stopped."
			regular["owner_knows"] = "Works too hard, eats too little, and always says it's the last bottle."
			regular["knows_of_owner"] = "The owner never takes a day off, even when it snows."
			return _fit_look(regular, request, Rules.MIN_DRINKING_AGE)
		"regular_tonight":
			var mood_from: Dictionary = CUSTOMERS.pick_random()
			return {"mood": mood_from["mood"], "reason": mood_from["reason"]}
		"recap":
			return Rules.stitched_recap(request.get("facts", {}))
		"diary":
			return {"entry": Rules.stitched_diary(request.get("facts", {}))}
		"reaction":
			# Mostly nothing; now and then a big moment, about one of the people talking.
			var names: Array = request.get("names", [])
			if names.is_empty() or randf() < 0.75:
				return {"size": randi_range(1, 3), "mood": "none"}
			var mood: String = REACTION_CAPTIONS.keys().pick_random()
			return {"size": 4, "mood": mood, "who": names.pick_random(), "caption": REACTION_CAPTIONS[mood]}
		"memory":
			var night: String = {"loved": "loved it", "enjoyed": "enjoyed it", "fine": "it was fine", "didnt": "didn't enjoy it"}.get(str(request.get("verdict", "fine")), "it was fine")
			return {"owner_remembers": "Quiet at first, then talked about work.", "they_remember": "The owner fussed over them, and the food was good.",
				"job": "", "family": "", "home": "", "other": "", "night": night, "towards_owner": "the same"}
		"customer_name":
			var picked := _customer(request.get("taken", []), str(request.get("gender", "")))
			return {"name": picked["name"], "hangul": HANGUL.get(picked["name"], ""), "gender": picked["gender"]}
		"customer":
			return _fit_look(_customer_details(str(request.get("name", "")), str(request.get("gender", ""))), request, Rules.MIN_DRINKING_AGE)
		"chat_line":
			if bool(request.get("owner_speaks", false)):
				return {"line": OWNER_LINES.pick_random()}
			return {"line": CHAT_OPENERS.pick_random() if bool(request.get("first", false)) else CHAT_LINES.pick_random()}
		"bar_name":
			return _bar_name(str(request.get("owner_name", "")))
		"bar_look":
			return {
				"hangul": BAR_HANGUL.get(str(request.get("bar_name", "")), Rules.DEFAULT_HANGUL),
				"tarp": request.get("tarps", Rules.BAR_TARPS.keys()).pick_random(),
				"shape": request.get("shapes", Rules.TENT_SHAPES.keys()).pick_random(),
				"sign": Rules.SIGN_STYLES.keys().pick_random(),
				"touches": [Rules.BAR_TOUCHES.keys().pick_random()],
			}
		"cat_name":
			var cat_name := Rules.fallback_cat_name(randf(), request.get("taken", []))
			return {"name": cat_name, "hangul": Rules.CAT_HANGUL.get(cat_name, "")}
		"order":
			return _order(title, int(request.get("max_mains", 1)), int(request.get("max_drinks", 1)))
		"extra_order":
			return _extra_order(title, request.get("table", []))
		"line":
			return {"line": _line(title, bool(request.get("owner_speaks", true)), bool(request.get("first", false)), bool(request.get("last", false)))}
	return {}


## The details for a customer the game has already named: the canned one with that name,
## or (for a name from a scripted reply) one of the same gender, renamed.
## A pre-written person made to fit the look the game decided (its age range, and how they
## look), as the AI would.
func _fit_look(person: Dictionary, request: Dictionary, youngest: int) -> Dictionary:
	var look: Dictionary = request.get("look", {})
	if look.is_empty():
		return person
	var band: Array = Rules.AGE_RANGES[look["age_range"]]
	person["age"] = randi_range(maxi(youngest, int(band[0])), int(band[1]))
	person["appearance"] = Rules.as_sentence("Someone %s" % Rules.look_text(look))
	return person


func _customer_details(customer_name: String, gender: String) -> Dictionary:
	for c in CUSTOMERS:
		if c["name"] == customer_name:
			return c.duplicate()
	var same := CUSTOMERS.filter(func(c): return gender == "" or c["gender"] == gender)
	var details: Dictionary = (same if not same.is_empty() else CUSTOMERS).pick_random().duplicate()
	if customer_name != "":
		details["name"] = customer_name
	return details


## A customer whose name nobody at the counter already has. gender: one the game has
## decided (non-binary); otherwise a woman or a man, as the AI would choose.
func _customer(taken: Array, gender: String = "") -> Dictionary:
	var kind := CUSTOMERS.filter(func(c): return c["gender"] == gender if gender != "" else c["gender"] != "non-binary")
	var choices := kind.filter(func(c): return not taken.has(c["name"]))
	if choices.is_empty():
		choices = kind if not kind.is_empty() else CUSTOMERS
	return choices.pick_random().duplicate()


## Half the time named after the owner's given name ("Park Mi-sook" -> "Mi-sook-ne Pocha").
func _bar_name(owner_name: String) -> Dictionary:
	var parts := owner_name.split(" ", false)
	if parts.size() >= 2 and randf() < 0.5:
		var given := parts[parts.size() - 1]
		return {"name": "%s-ne Pocha" % given, "meaning": "%s's family's tent" % given}
	return BAR_NAMES.pick_random().duplicate()


func _order(title: String, max_mains: int, max_drinks: int) -> Dictionary:
	var drinks := _ids(func(item): return item["kind"] == "drink")
	var mains := _ids(func(item): return item.get("portion", "") == "main")
	var sides := _ids(func(item): return item.get("portion", "") == "side" and not item.get("extra_only", false))
	var items: Array = [drinks.pick_random()]
	if max_drinks > 1 and randf() < 0.5:
		items.append(items[0])
	items.append(mains.pick_random())
	if max_mains > 1 and randf() < 0.5:
		items.append(mains.pick_random())
	if items.size() < 4 and randf() < 0.4:
		items.append(sides.pick_random())
	var templates := ["%s, %s, please.", "Evening, %s. I'll have %s.", "%s! %s for me tonight."]
	return {"items": items, "line": templates.pick_random() % [title, _spoken(items)]}


func _extra_order(title: String, table: Array) -> Dictionary:
	var options: Array = []
	for id in table:
		if Menu.find(id).get("kind", "") == "drink":
			var drink_name := str(Menu.find(id)["name"])
			options.append({"items": [id], "line": "%s, one more %s, please." % [title, drink_name]})
			options.append({"items": [id], "line": "Another %s, %s. It's that kind of night." % [drink_name, title]})
			break
	options.append({"items": ["gonggibap"], "line": "Could I get a bowl of rice too, %s?" % title})
	var has_main := false
	for id in table:
		if Menu.find(id).get("portion", "") == "main":
			has_main = true
	if has_main and not table.has("bokkeumbap"):
		options.append({"items": ["bokkeumbap"], "line": "%s, could you make fried rice in this sauce too?" % title})
	return options.pick_random().duplicate(true)

## Customers chatting to each other: strangers, so polite, and no food or names.
const CHAT_OPENERS := [
	"Jeogiyo, sorry. Is it always this busy in here?",
	"Sorry, I couldn't help overhearing. Rough day?",
	"Excuse me, do you mind if I ask what time the last bus goes?",
	"Is this weather ever going to make up its mind?",
]
const CHAT_LINES := [
	"Ha! You sound like my sister. She says the same thing.",
	"Same here, honestly. Work's been eating me alive.",
	"Cheers to that. To surviving the week.",
	"I come here when my flat's too quiet. Strange, isn't it?",
	"Nobody listens like a stranger at midnight.",
	"You're right. I should stop worrying about things I can't change.",
	"Is that so? I'd never have guessed.",
	"My boss would faint if he saw me out this late.",
	"It's nice, talking to someone who doesn't know my whole story.",
	"Well, now I feel a bit better. Thank you for that.",
]


func _line(title: String, owner_speaks: bool, first: bool, last: bool) -> String:
	if owner_speaks:
		return OWNER_FIRST_LINES.pick_random() if first else OWNER_LINES.pick_random()
	var line: String = CUSTOMER_LAST_LINES.pick_random() if last else CUSTOMER_LINES.pick_random()
	return line % title if line.contains("%s") else line


## Menu ids of items that match.
func _ids(matches: Callable) -> Array:
	var ids: Array = []
	for item in Menu.ITEMS:
		if matches.call(item):
			ids.append(item["id"])
	return ids


## ["soju", "ramyeon", "ramyeon"] -> "Soju and two Ramyeon"
func _spoken(items: Array) -> String:
	var counts := {}
	var seen: Array = []
	for id in items:
		if not counts.has(id):
			counts[id] = 0
			seen.append(id)
		counts[id] += 1
	var parts := PackedStringArray()
	for id in seen:
		var item_name := str(Menu.find(id)["name"])
		parts.append(item_name if counts[id] == 1 else "two %s" % item_name)
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
