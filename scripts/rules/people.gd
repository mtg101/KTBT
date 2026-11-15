extends RefCounted
## Who people are: owners and customers as the AI invents them (checked), their ages and
## genders, how long customers stay and their mood for company, founding regulars, and the
## owner's fixed life.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Looks = preload("res://scripts/rules/looks.gd")
const Names = preload("res://scripts/rules/names.gd")
const Text = preload("res://scripts/rules/text.gd")


const MIN_DRINKING_AGE := 19  # Korea's legal drinking age: enforced by the game, not the AI.


const MAX_CUSTOMER_AGE := 90


const MIN_OWNER_AGE := 40  # Owners are called Ajumma or Ajusshi, which suits 40 and over.


const MAX_OWNER_AGE := 85


const OWNER_FIELDS := ["name", "age", "archetype", "appearance", "personality", "speech_style", "secret"]


## The owner's life: facts the game keeps so they never change from line to line or night to
## night (without them, an owner's wife "passed away" one minute and "left" the next). The AI
## writes them with the owner; if it leaves one out, or the bar is older than them, the game
## picks one from these (fitting the owner's gender).
const OWNER_LIFE := ["family", "before"]


const MAX_OWNER_LIFE := 160


const OWNER_FAMILIES := {
	"woman": ["widowed young; a grown daughter in Daejeon who wants her to retire", "married to a night-shift taxi driver; two sons, one in the army",
		"divorced long ago; raised her son alone, and he works in an office in Gangnam now", "never married; looks after her old mother in the flat upstairs",
		"married thirty years; her husband does the market run every morning and naps all afternoon"],
	"man": ["widowed; a son in Busan who rarely calls", "married to a hairdresser who thinks the tent is a terrible idea; one daughter at university",
		"divorced; sees his two grandchildren on Sundays", "never married; there was someone once, a long time ago",
		"married, with three grown children who all left Seoul"],
}


const OWNER_BEFORES := ["a factory line in Ulsan", "a fish stall at Jagalchi market in Busan", "a bank clerk until the crisis in '97",
	"a cook in the army, then in a hotel kitchen", "long-distance trucking", "a dry-cleaning shop that closed", "a primary school dinner hall",
	"a noodle stand at a bus terminal"]


## The owner's life facts, filled in where missing (from the tables, by roll), tidied and
## kept short. Returns true if it changed anything.
static func fill_owner_life(owner: Dictionary, roll: float) -> bool:
	var changed := false
	var gender := str(owner.get("gender", "woman"))
	for key in OWNER_LIFE:
		var value := Text.unquote(Text.tidy_text(owner.get(key, "")))
		if value.length() > MAX_OWNER_LIFE:
			value = ""
		if value == "":
			var choices: Array = OWNER_FAMILIES.get(gender, OWNER_FAMILIES["woman"]) if key == "family" else OWNER_BEFORES
			value = str(choices[clampi(floori(roll * choices.size()), 0, choices.size() - 1)])
		if str(owner.get(key, "")) != value:
			owner[key] = value
			changed = true
	return changed


const CUSTOMER_FIELDS := ["name", "age", "job", "mood", "reason", "speech_style", "appearance"]


const CUSTOMER_DETAIL_FIELDS := ["age", "job", "mood", "reason", "speech_style", "appearance"]


## Korean terms of address that only fit one gender. The game picks the owner's gender
## (and so their title: see Prompts.OWNER_ADDRESS), then rejects an owner whose archetype
## uses a word for the other gender.
const GENDERED_TERMS := {
	"woman": ["ajumma", "ajumeoni", "ajummoni", "imo", "halmeoni", "halmoni", "eomeoni", "eomma", "nuna", "noona", "eonni", "unni"],
	"man": ["ajusshi", "ajeossi", "ajussi", "ajeoshi", "ajeosshi", "samchon", "harabeoji", "abeoji", "appa", "hyung", "hyeong", "oppa"],
}


## age_range: the one the game decided (see AGE_RANGES); "" for any owner's age.
static func validate_owner(data: Variant, gender: String, age_range: String = "") -> String:
	var problem := Text.check_fields(data, OWNER_FIELDS)
	if problem != "":
		return problem
	data["name"] = Names.name_case(Names.family_name_first(Text.tidy_text(data["name"])))
	data["hangul"] = Names.fit_hangul(str(data["name"]), data.get("hangul", ""))  # shown only if it fits
	problem = check_age(data, MIN_OWNER_AGE, MAX_OWNER_AGE)
	if problem != "":
		return problem
	fit_age(data, age_range)
	# The owner is a {gender}: their archetype mustn't use a word for the other gender.
	var other := "man" if gender == "woman" else "woman"
	var said := Text.words(str(data["archetype"]))
	for term in GENDERED_TERMS[other]:
		if term in said:
			return "the owner is a %s, but their archetype uses \"%s\", which is for a %s" % [gender, term, other]
	return ""


## The game decides every customer's gender (left to choose, the AI picked a woman about
## three times in four): about one in a hundred is non-binary, and the rest are split evenly
## between women and men. The AI only names them.
const NON_BINARY_CHANCE := 0.01


## A new customer's gender, from a random roll between 0 and 1.
static func game_gender(roll: float) -> String:
	if roll < NON_BINARY_CHANCE:
		return "non-binary"
	return "woman" if roll < NON_BINARY_CHANCE + (1.0 - NON_BINARY_CHANCE) / 2.0 else "man"


## The rest of a customer, the second step, once the game has their name and gender.
## age_range: the one the game decided (see AGE_RANGES); "" for any adult age.
static func validate_customer_details(data: Variant, age_range: String = "") -> String:
	var problem := Text.check_fields(data, CUSTOMER_DETAIL_FIELDS)
	if problem != "":
		return problem
	problem = check_age(data, MIN_DRINKING_AGE, MAX_CUSTOMER_AGE)
	if problem == "":
		fit_age(data, age_range)
	return problem


## A whole customer at once (name included). taken: names already at the counter.
static func validate_customer(data: Variant, taken: Array = []) -> String:
	var problem := Text.check_fields(data, CUSTOMER_FIELDS)
	if problem != "":
		return problem
	var customer_name := Text.tidy_text(data["name"])
	for other in taken:
		if customer_name.to_lower() == str(other).to_lower():
			return "someone called %s is already at the counter: pick a different name" % customer_name
	return check_age(data, MIN_DRINKING_AGE, MAX_CUSTOMER_AGE)


## The game decides each customer's mood for company when they sit down:
## "chatty" (happy to talk to anyone at the counter), "quiet" (keeps to themselves, so isn't
## drawn into other customers' chats) or "owner" (here to talk to the owner: they stay
## longer and get the owner's attention sooner).
const HERE_TO_TALK_CHANCE := 0.2


const KEEPS_TO_THEMSELVES_CHANCE := 0.25


const COMPANY_TEXT := {
	"chatty": "happy to chat with anyone at the counter",
	"quiet": "keeps to themselves, and would rather not talk to other customers",
	"owner": "here to talk to the owner: they have something on their mind",
}


## The mood for company, from a random roll between 0 and 1.
static func company(roll: float) -> String:
	if roll < HERE_TO_TALK_CHANCE:
		return "owner"
	if roll < HERE_TO_TALK_CHANCE + KEEPS_TO_THEMSELVES_CHANCE:
		return "quiet"
	return "chatty"


## How many game minutes a customer stays, from a random roll between 0 and 1: 30 to 60
## for most, 60 to 90 for someone here to talk. When it's up, they say goodbye and pay,
## whether or not they got much of the owner's time.
static func stay_minutes(company_mood: String, roll: float) -> int:
	var shortest := 60 if company_mood == "owner" else 30
	return shortest + roundi(30.0 * clampf(roll, 0.0, 1.0))


## When it's busy (someone else waiting to be greeted, or this many already at the counter),
## the owner greets a newcomer quickly: takes the order and serves it, and comes back for a
## proper word later. On a quiet night they have a first chat straight away.
const BUSY_COUNTER := 3


## waiting: how many others are still waiting to be greeted; seated: how many are already
## at the counter.
static func quick_greeting(waiting: int, seated: int) -> bool:
	return waiting > 0 or seated >= BUSY_COUNTER


## Whether someone can be drawn into a chat with another customer.
static func joins_chats(company_mood: String) -> bool:
	return company_mood != "quiet"


## Checks "age" is a whole number in range. Accepts "34" or 34.0 and stores 34.
## An age outside the range the game decided is moved to the nearest age inside it, rather
## than rejected: the range is the game's fact, and asking again for a number costs a whole call.
static func fit_age(data: Dictionary, age_range: String) -> void:
	if Looks.AGE_RANGES.has(age_range):
		data["age"] = clampi(int(data["age"]), int(Looks.AGE_RANGES[age_range][0]), int(Looks.AGE_RANGES[age_range][1]))


static func check_age(data: Dictionary, lowest: int, highest: int) -> String:
	var age = data["age"]
	if typeof(age) == TYPE_STRING and age.is_valid_int():
		age = age.to_int()
	if typeof(age) != TYPE_INT and typeof(age) != TYPE_FLOAT:
		return "the age wasn't a number"
	if int(age) < lowest or int(age) > highest:
		return "an age of %d doesn't fit here (it must be %d to %d)" % [int(age), lowest, highest]
	data["age"] = int(age)
	return ""


const FOUNDING_FIELDS := ["name", "age", "job", "speech_style", "appearance", "history", "owner_knows", "knows_of_owner"]


const MAX_REGULAR_TEXT := 300


## One of a new bar's founding regulars (the game decided their gender and age range).
## taken: names they mustn't share (the owner, the other founding regular).
static func validate_founding_regular(data: Variant, taken: Array, gender: String, age_range: String) -> String:
	var problem := Text.check_fields(data, FOUNDING_FIELDS)
	if problem != "":
		return problem
	problem = Names.validate_customer_name(data, taken, gender)
	if problem != "":
		return problem
	problem = check_age(data, MIN_DRINKING_AGE, MAX_CUSTOMER_AGE)
	if problem != "":
		return problem
	fit_age(data, age_range)
	for key in ["history", "owner_knows", "knows_of_owner", "appearance"]:
		if Text.tidy_text(data[key]).length() > MAX_REGULAR_TEXT:
			return "\"%s\" is too long: one sentence" % key
	return ""


## What brings a regular in tonight.
static func validate_regular_tonight(data: Variant) -> String:
	return Text.check_fields(data, ["mood", "reason"])
