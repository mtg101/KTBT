extends RefCounted
## Every dish and drink a pocha in the game might serve: the classic menu's (menu.gd), and the
## rest of real pojangmacha food. A bar's own menu is chosen from here when it opens (with one
## or two signature dishes of its own, later), so its owner shows in what's on it.
## Each dish is a menu item (see menu.gd), plus:
## - "category": drinks, stew, pancake, noodles, seafood, grill, fried, side or rice;
## - "price_range": [lowest, highest] in won (what a bar may charge; "price" is the usual);
## - "tags": what kind of dish it is (spicy, seafood, comfort, fancy, cheap, hearty, light,
##   classic), for choosing a menu that suits an owner and for specials;
## - "season" (optional): "summer" or "winter", when it's at its best;
## - "word" (optional): the one word that names it in talk ("golbaengi"), so a line can't serve
##   it at a bar that doesn't have it.
## (Part of the game's rules: tables only, and a few ways to read them. See ARCHITECTURE.md.)

const Menu = preload("res://scripts/rules/menu.gd")
const Text = preload("res://scripts/rules/text.gd")

## Every bar's menu has these (it's a pocha), ...
const ALWAYS := ["soju", "beer", "gonggibap"]

## ... somaek wherever there's soju and beer (mixed at the table, never chosen or on the board) ...
const MIXED := ["somaek"]

## ... at least CLASSICS_AT_LEAST of the pocha classics (each group is one classic: either will
## do), and makgeolli most of the time ...
const CLASSICS := [["tteokbokki"], ["odeng", "eomuk_tang"], ["sundae"], ["pajeon", "kimchi_jeon", "haemul_pajeon"], ["gyeran_mari"], ["ramyeon", "udon"]]
const CLASSICS_AT_LEAST := 4
const MAKGEOLLI_CHANCE := 0.7

## ... and OWN_PICKS more of its own, to suit the owner, at least one of them a hearty main.
const OWN_PICKS := Vector2i(3, 5)
const HEARTY := ["stew", "grill", "seafood"]  # (categories)

## In all, a menu has this many items, with room for SIGNATURES signature dishes of its own.
const MENU_SIZE := Vector2i(12, 16)
const SIGNATURES := 2


## Which layer a dish is in: "always", "classic" (one of the classics, or makgeolli), "own"
## (chosen from the catalogue to suit the owner) or "signature" (the owner's own invention:
## see rules/signatures.gd).
static func layer(id: String) -> String:
	if id.begins_with("own_"):
		return "signature"
	if ALWAYS.has(id) or MIXED.has(id):
		return "always"
	if id == "makgeolli":
		return "classic"
	for group in CLASSICS:
		if group.has(id):
			return "classic"
	return "own"


## The classic menu's dishes, with what the catalogue adds to them.
const CLASSIC := {
	"soju": {"category": "drinks", "price_range": [5000, 6000], "tags": ["classic", "cheap"]},
	"makgeolli": {"category": "drinks", "price_range": [5000, 7000], "tags": ["classic", "comfort"]},
	"beer": {"category": "drinks", "price_range": [5000, 6000], "tags": ["classic", "cheap"]},
	"somaek": {"category": "drinks", "price_range": [9000, 11000], "tags": ["classic"]},
	"tteokbokki": {"category": "side", "price_range": [10000, 14000], "tags": ["classic", "spicy", "comfort", "cheap"]},
	"odeng": {"category": "side", "price_range": [7000, 9000], "tags": ["classic", "comfort", "cheap"], "season": "winter"},
	"sundae": {"category": "side", "price_range": [11000, 15000], "tags": ["classic", "hearty"]},
	"dakgalbi": {"category": "grill", "price_range": [16000, 22000], "tags": ["spicy", "hearty"]},
	"pajeon": {"category": "pancake", "price_range": [13000, 17000], "tags": ["classic", "comfort"]},
	"ramyeon": {"category": "noodles", "price_range": [4000, 6000], "tags": ["classic", "cheap", "comfort"]},
	"gyeran_mari": {"category": "side", "price_range": [8000, 11000], "tags": ["comfort", "light"]},
	"gonggibap": {"category": "rice", "price_range": [1000, 2000], "tags": ["cheap"]},
	"bokkeumbap": {"category": "rice", "price_range": [3000, 4000], "tags": ["comfort"]},
}

## The rest: real pocha food and drink, beyond the classic menu.
const MORE := [
	# Drinks
	{"id": "bokbunja", "hangul": "복분자", "name": "Bokbunja", "desc": "sweet black raspberry wine", "price": 13000, "price_range": [12000, 15000], "kind": "drink", "category": "drinks", "color": "5a1f3a", "tags": ["fancy"], "aliases": ["raspberry wine", "black raspberry wine"], "word": "bokbunja", "art": {"vessel": "bottle"}},
	{"id": "maesilju", "hangul": "매실주", "name": "Maesilju", "desc": "plum wine, sweet and sharp", "price": 11000, "price_range": [10000, 13000], "kind": "drink", "category": "drinks", "color": "c9a23a", "tags": ["light"], "aliases": ["plum wine"], "word": "maesilju", "art": {"vessel": "bottle"}},
	{"id": "saida", "hangul": "사이다", "name": "Saida", "desc": "lemon-lime soda, for anyone not drinking", "price": 2000, "price_range": [2000, 3000], "kind": "drink", "category": "drinks", "color": "cfe8d8", "tags": ["cheap", "light"], "aliases": ["soda", "lemonade", "cider"], "art": {"vessel": "glass", "foam": true}},
	# Stews and soups: a pot on the burner, for the table to share
	{"id": "eomuk_tang", "hangul": "어묵탕", "name": "Eomuk-tang", "desc": "fish cake soup in a big pot, refilled with broth", "price": 15000, "price_range": [13000, 18000], "kind": "food", "portion": "main", "category": "stew", "color": "c9a26b", "cook": 8, "tags": ["comfort", "hearty"], "season": "winter", "aliases": ["fish cake soup", "eomuk soup"], "art": {"vessel": "pan", "fill": "d9b98a", "bits": "skewers", "bits_colour": "c9a26b"}},
	{"id": "kimchi_jjigae", "hangul": "김치찌개", "name": "Kimchi-jjigae", "desc": "kimchi stew with pork and tofu", "price": 12000, "price_range": [10000, 14000], "kind": "food", "portion": "main", "category": "stew", "color": "c8452f", "cook": 10, "tags": ["spicy", "comfort", "classic"], "season": "winter", "aliases": ["kimchi stew"], "art": {"vessel": "stone_pot", "fill": "c8452f", "bits": "chunks", "bits_colour": "f4f0e4"}},
	{"id": "budae_jjigae", "hangul": "부대찌개", "name": "Budae-jjigae", "desc": "army stew: sausage, ham, beans, noodles and kimchi in one pot", "price": 18000, "price_range": [16000, 22000], "kind": "food", "portion": "main", "category": "stew", "color": "d0582f", "cook": 10, "tags": ["spicy", "hearty"], "aliases": ["army stew"], "word": "budae", "art": {"vessel": "pan", "fill": "d0582f", "bits": "chunks", "bits_colour": "e8b07a", "garnish": "spring_onion"}},
	{"id": "haemul_tang", "hangul": "해물탕", "name": "Haemul-tang", "desc": "spicy seafood stew: crab, clams, squid and prawns", "price": 32000, "price_range": [28000, 40000], "kind": "food", "portion": "main", "category": "stew", "color": "c8452f", "cook": 14, "tags": ["seafood", "spicy", "fancy", "hearty"], "aliases": ["seafood stew"], "word": "haemultang", "art": {"vessel": "pan", "fill": "c8452f", "bits": "shells", "bits_colour": "e8d8c0"}},
	{"id": "dak_bokkeumtang", "hangul": "닭볶음탕", "name": "Dak-bokkeumtang", "desc": "braised spicy chicken with potatoes", "price": 22000, "price_range": [20000, 26000], "kind": "food", "portion": "main", "category": "stew", "color": "c4572e", "cook": 14, "tags": ["spicy", "hearty", "comfort"], "aliases": ["braised chicken", "spicy braised chicken"], "word": "dakbokkeumtang", "art": {"vessel": "pan", "fill": "c4572e", "bits": "chunks", "bits_colour": "e8c07a"}},
	{"id": "altang", "hangul": "알탕", "name": "Altang", "desc": "spicy pollock roe stew", "price": 16000, "price_range": [14000, 18000], "kind": "food", "portion": "main", "category": "stew", "color": "d0582f", "cook": 10, "tags": ["seafood", "spicy"], "aliases": ["roe stew", "fish roe stew"], "word": "altang", "art": {"vessel": "stone_pot", "fill": "d0582f", "bits": "chunks", "bits_colour": "f2b8a0", "garnish": "spring_onion"}},
	{"id": "dongtae_jjigae", "hangul": "동태찌개", "name": "Dongtae-jjigae", "desc": "frozen pollock stew, hot and clean", "price": 15000, "price_range": [13000, 17000], "kind": "food", "portion": "main", "category": "stew", "color": "c8452f", "cook": 12, "tags": ["seafood", "spicy", "comfort"], "season": "winter", "aliases": ["pollock stew"], "word": "dongtae", "art": {"vessel": "stone_pot", "fill": "c8452f", "bits": "chunks", "bits_colour": "f4f0e4", "garnish": "spring_onion"}},
	# Pancakes
	{"id": "kimchi_jeon", "hangul": "김치전", "name": "Kimchi-jeon", "desc": "kimchi pancake, crisp at the edges", "price": 12000, "price_range": [10000, 14000], "kind": "food", "portion": "main", "category": "pancake", "color": "d0602f", "cook": 8, "tags": ["spicy", "comfort", "cheap"], "aliases": ["kimchi pancake"], "art": {"vessel": "plate", "bits": "pancake"}},
	{"id": "haemul_pajeon", "hangul": "해물파전", "name": "Haemul-pajeon", "desc": "seafood and spring onion pancake", "price": 18000, "price_range": [16000, 22000], "kind": "food", "portion": "main", "category": "pancake", "color": "d9b44a", "cook": 10, "tags": ["seafood", "comfort"], "aliases": ["seafood pancake"], "art": {"vessel": "plate", "bits": "pancake", "garnish": "spring_onion"}},
	{"id": "bindaetteok", "hangul": "빈대떡", "name": "Bindaetteok", "desc": "mung bean pancake, thick and crunchy", "price": 13000, "price_range": [11000, 15000], "kind": "food", "portion": "main", "category": "pancake", "color": "c99a4a", "cook": 9, "tags": ["comfort", "classic"], "aliases": ["mung bean pancake"], "word": "bindaetteok", "art": {"vessel": "plate", "bits": "pancake", "garnish": "spring_onion"}},
	{"id": "gamja_jeon", "hangul": "감자전", "name": "Gamja-jeon", "desc": "grated potato pancake", "price": 11000, "price_range": [9000, 13000], "kind": "food", "portion": "main", "category": "pancake", "color": "e2c879", "cook": 9, "tags": ["comfort", "light"], "aliases": ["potato pancake"], "art": {"vessel": "plate", "bits": "pancake"}},
	# Noodles
	{"id": "janchi_guksu", "hangul": "잔치국수", "name": "Janchi-guksu", "desc": "banquet noodles: thin wheat noodles in a clear anchovy broth", "price": 7000, "price_range": [6000, 8000], "kind": "food", "portion": "main", "category": "noodles", "color": "efe6c8", "cook": 6, "tags": ["light", "cheap", "comfort"], "aliases": ["banquet noodles", "noodle soup"], "word": "guksu", "art": {"vessel": "steel_bowl", "bits": "noodles", "bits_colour": "f4efdc"}},
	{"id": "bibim_guksu", "hangul": "비빔국수", "name": "Bibim-guksu", "desc": "cold noodles in sweet and spicy sauce", "price": 8000, "price_range": [7000, 9000], "kind": "food", "portion": "main", "category": "noodles", "color": "d0582f", "cook": 5, "tags": ["spicy", "light"], "season": "summer", "aliases": ["spicy cold noodles"], "art": {"vessel": "steel_bowl", "bits": "noodles", "bits_colour": "d0582f"}},
	{"id": "naengmyeon", "hangul": "물냉면", "name": "Mul-naengmyeon", "desc": "icy buckwheat noodles in cold broth", "price": 10000, "price_range": [9000, 12000], "kind": "food", "portion": "main", "category": "noodles", "color": "c9b89a", "cook": 5, "tags": ["light"], "season": "summer", "aliases": ["cold noodles", "naengmyeon"], "art": {"vessel": "steel_bowl", "bits": "noodles", "bits_colour": "8a7a6a"}},
	{"id": "kalguksu", "hangul": "칼국수", "name": "Kalguksu", "desc": "knife-cut noodles in a clam broth", "price": 9000, "price_range": [8000, 11000], "kind": "food", "portion": "main", "category": "noodles", "color": "efe6c8", "cook": 8, "tags": ["comfort", "seafood"], "season": "winter", "aliases": ["knife-cut noodles", "knife noodles"], "word": "kalguksu", "art": {"vessel": "pot", "fill": "efe6c8", "bits": "noodles", "bits_colour": "f4efdc"}},
	{"id": "udon", "hangul": "우동", "name": "Udon", "desc": "thick noodles in hot broth, the tent bar way", "price": 7000, "price_range": [6000, 8000], "kind": "food", "portion": "main", "category": "noodles", "color": "e8d8a8", "cook": 5, "tags": ["comfort", "cheap"], "season": "winter", "aliases": ["udon noodles"], "art": {"vessel": "steel_bowl", "bits": "noodles", "bits_colour": "f4efdc", "garnish": "spring_onion"}},
	# Seafood
	{"id": "golbaengi_muchim", "hangul": "골뱅이무침", "name": "Golbaengi-muchim", "desc": "whelks in a spicy dressing, with thin noodles", "price": 20000, "price_range": [18000, 24000], "kind": "food", "portion": "main", "category": "seafood", "color": "d0582f", "cook": 6, "tags": ["seafood", "spicy", "classic"], "aliases": ["spicy whelks", "whelks"], "word": "golbaengi", "art": {"vessel": "plate", "fill": "d0582f", "bits": "strips", "bits_colour": "8a5a3a", "garnish": "spring_onion"}},
	{"id": "jogae_gui", "hangul": "조개구이", "name": "Jogae-gui", "desc": "clams grilled in their shells", "price": 25000, "price_range": [22000, 30000], "kind": "food", "portion": "main", "category": "seafood", "color": "e8d8c0", "cook": 10, "tags": ["seafood", "fancy"], "aliases": ["grilled clams", "clams"], "word": "jogaegui", "art": {"vessel": "pan", "bits": "shells", "bits_colour": "e8d8c0"}},
	{"id": "ojingeo_bokkeum", "hangul": "오징어볶음", "name": "Ojingeo-bokkeum", "desc": "squid stir-fried in red pepper sauce", "price": 16000, "price_range": [14000, 18000], "kind": "food", "portion": "main", "category": "seafood", "color": "c8452f", "cook": 8, "tags": ["seafood", "spicy"], "aliases": ["spicy squid", "stir-fried squid"], "word": "ojingeo", "art": {"vessel": "plate", "fill": "c8452f", "bits": "strips", "bits_colour": "f4e8d8", "garnish": "sesame"}},
	{"id": "nakji_bokkeum", "hangul": "낙지볶음", "name": "Nakji-bokkeum", "desc": "small octopus, fiery and stir-fried", "price": 22000, "price_range": [20000, 26000], "kind": "food", "portion": "main", "category": "seafood", "color": "b83a2a", "cook": 8, "tags": ["seafood", "spicy", "fancy"], "aliases": ["spicy octopus", "octopus"], "word": "nakji", "art": {"vessel": "plate", "fill": "b83a2a", "bits": "strips", "bits_colour": "e8b0a0", "garnish": "sesame"}},
	{"id": "gul", "hangul": "생굴", "name": "Saenggul", "desc": "fresh raw oysters, with gochujang to dip", "price": 18000, "price_range": [16000, 22000], "kind": "food", "portion": "side", "category": "seafood", "color": "d8d0c0", "cook": 3, "tags": ["seafood", "fancy", "light"], "season": "winter", "aliases": ["oysters", "raw oysters"], "word": "saenggul", "art": {"vessel": "plate", "bits": "shells", "bits_colour": "d8d0c0"}},
	{"id": "mareun_ojingeo", "hangul": "마른오징어", "name": "Mareun-ojingeo", "desc": "dried squid, grilled, with mayonnaise to dip", "price": 9000, "price_range": [8000, 11000], "kind": "food", "portion": "side", "category": "seafood", "color": "d8b87a", "cook": 3, "tags": ["seafood", "cheap", "classic"], "aliases": ["dried squid", "grilled squid"], "art": {"vessel": "plate", "bits": "strips", "bits_colour": "d8b87a"}},
	# The grill and the fryer
	{"id": "dak_ttongjip", "hangul": "닭똥집", "name": "Dak-ttongjip", "desc": "chicken gizzards, stir-fried with garlic", "price": 13000, "price_range": [11000, 15000], "kind": "food", "portion": "main", "category": "grill", "color": "8a4a2a", "cook": 8, "tags": ["hearty", "classic", "cheap"], "aliases": ["gizzards", "chicken gizzards"], "word": "ttongjip", "art": {"vessel": "pan", "bits": "chunks", "bits_colour": "8a4a2a", "garnish": "spring_onion"}},
	{"id": "dak_kkochi", "hangul": "닭꼬치", "name": "Dak-kkochi", "desc": "chicken skewers, glazed sweet or spicy", "price": 9000, "price_range": [8000, 11000], "kind": "food", "portion": "side", "category": "grill", "color": "b8602a", "cook": 6, "tags": ["cheap", "comfort"], "aliases": ["chicken skewers"], "word": "kkochi", "art": {"vessel": "plate", "bits": "skewers", "bits_colour": "b8602a"}},
	{"id": "sotteok", "hangul": "소떡소떡", "name": "Sotteok-sotteok", "desc": "sausage and rice cakes on a stick, in sweet chilli sauce", "price": 6000, "price_range": [5000, 7000], "kind": "food", "portion": "side", "category": "grill", "color": "c8452f", "cook": 5, "tags": ["cheap", "spicy"], "aliases": ["sausage and rice cake skewers"], "word": "sotteok", "art": {"vessel": "plate", "bits": "skewers", "bits_colour": "c8603a"}},
	{"id": "gopchang", "hangul": "곱창", "name": "Gopchang", "desc": "grilled beef intestines, chewy and rich", "price": 24000, "price_range": [20000, 28000], "kind": "food", "portion": "main", "category": "grill", "color": "c9925a", "cook": 12, "tags": ["hearty", "fancy"], "aliases": ["grilled intestines"], "art": {"vessel": "pan", "bits": "chunks", "bits_colour": "e8c08a", "garnish": "spring_onion"}},
	{"id": "kkeopdegi", "hangul": "껍데기", "name": "Kkeopdegi", "desc": "grilled pork skin, crisp and sticky", "price": 12000, "price_range": [10000, 14000], "kind": "food", "portion": "main", "category": "grill", "color": "c97a4a", "cook": 8, "tags": ["cheap", "hearty"], "aliases": ["pork skin", "grilled pork skin"], "word": "kkeopdegi", "art": {"vessel": "pan", "bits": "strips", "bits_colour": "c97a4a"}},
	{"id": "dak_gangjeong", "hangul": "닭강정", "name": "Dak-gangjeong", "desc": "crisp fried chicken bites in a sticky sweet glaze", "price": 16000, "price_range": [14000, 19000], "kind": "food", "portion": "main", "category": "fried", "color": "b8602a", "cook": 10, "tags": ["comfort", "hearty"], "aliases": ["sweet fried chicken", "fried chicken"], "word": "gangjeong", "art": {"vessel": "plate", "bits": "chunks", "bits_colour": "b8602a", "garnish": "sesame"}},
	{"id": "twigim", "hangul": "모둠튀김", "name": "Modum-twigim", "desc": "a plate of fried things: squid, sweet potato, seaweed rolls", "price": 10000, "price_range": [8000, 12000], "kind": "food", "portion": "side", "category": "fried", "color": "d9a84a", "cook": 6, "tags": ["cheap", "comfort", "classic"], "aliases": ["tempura", "fried snacks", "twigim"], "word": "twigim", "art": {"vessel": "plate", "bits": "chunks", "bits_colour": "d9a84a"}},
	# Sides
	{"id": "dubu_kimchi", "hangul": "두부김치", "name": "Dubu-kimchi", "desc": "warm tofu with stir-fried kimchi and pork", "price": 13000, "price_range": [11000, 15000], "kind": "food", "portion": "side", "category": "side", "color": "c8452f", "cook": 6, "tags": ["classic", "comfort"], "aliases": ["tofu kimchi", "tofu with kimchi"], "word": "dubu", "art": {"vessel": "plate", "bits": "tofu", "bits_colour": "c8452f"}},
	{"id": "gyeran_jjim", "hangul": "계란찜", "name": "Gyeran-jjim", "desc": "steamed egg, puffed up in its pot", "price": 6000, "price_range": [5000, 7000], "kind": "food", "portion": "side", "category": "side", "color": "f2d36b", "cook": 6, "tags": ["light", "comfort", "cheap"], "aliases": ["steamed egg", "egg custard"], "word": "jjim", "art": {"vessel": "stone_pot", "fill": "f2d36b", "bits": "mound", "bits_colour": "f2d36b", "garnish": "spring_onion"}},
	{"id": "corn_cheese", "hangul": "콘치즈", "name": "Corn cheese", "desc": "sweetcorn baked under melted cheese, in a sizzling pan", "price": 9000, "price_range": [8000, 10000], "kind": "food", "portion": "side", "category": "side", "color": "f2d36b", "cook": 6, "tags": ["comfort", "cheap"], "aliases": ["cheesy corn"], "art": {"vessel": "pan", "bits": "mound", "bits_colour": "f2c84a"}},
	{"id": "eomuk_bokkeum", "hangul": "어묵볶음", "name": "Eomuk-bokkeum", "desc": "stir-fried fish cake strips, sweet and salty", "price": 6000, "price_range": [5000, 7000], "kind": "food", "portion": "side", "category": "side", "color": "c9a26b", "cook": 4, "tags": ["cheap", "light"], "aliases": ["stir-fried fish cake"], "art": {"vessel": "plate", "bits": "strips", "bits_colour": "c9a26b", "garnish": "sesame"}},
	{"id": "gyeran_hurai", "hangul": "계란후라이", "name": "Gyeran-hurai", "desc": "a fried egg, runny in the middle", "price": 2000, "price_range": [1000, 2000], "kind": "food", "portion": "side", "category": "side", "color": "f4f0e4", "cook": 2, "tags": ["cheap", "comfort"], "aliases": ["fried egg"], "art": {"vessel": "plate", "bits": "mound", "bits_colour": "f2c84a"}},
	# Rice
	{"id": "jumeokbap", "hangul": "주먹밥", "name": "Jumeokbap", "desc": "rice balls with seaweed, squeezed by hand", "price": 4000, "price_range": [3000, 5000], "kind": "food", "portion": "side", "category": "rice", "color": "f4f1e8", "cook": 3, "tags": ["cheap", "comfort"], "aliases": ["rice balls", "rice ball"], "word": "jumeokbap", "art": {"vessel": "plate", "bits": "mound", "bits_colour": "f4f1e8", "garnish": "seaweed"}},
	{"id": "kimchi_bokkeumbap", "hangul": "김치볶음밥", "name": "Kimchi-bokkeumbap", "desc": "kimchi fried rice with a fried egg on top", "price": 9000, "price_range": [8000, 10000], "kind": "food", "portion": "main", "category": "rice", "color": "d0602f", "cook": 6, "tags": ["comfort", "cheap", "spicy"], "aliases": ["kimchi fried rice"], "art": {"vessel": "pan", "bits": "mound", "bits_colour": "d0602f", "garnish": "seaweed"}},
]


## Every dish and drink, as full menu items (the classic menu's with the catalogue's extras).
static func all() -> Array:
	var found: Array = []
	for item in Menu.ITEMS:
		var full: Dictionary = item.duplicate(true)
		full.merge(CLASSIC.get(item["id"], {}))
		found.append(full)
	for item in MORE:
		found.append(item.duplicate(true))
	return found


## The catalogue's dish with this id, or {}.
static func find(id: String) -> Dictionary:
	for item in all():
		if item["id"] == id:
			return item
	return {}


## The words naming a dish that's in the catalogue but not on tonight's menu: a line can talk
## about them, but not as if they're served here (see Talk.off_menu_here).
static func off_menu_words() -> Array:
	var words: Array = []
	for item in all():
		if Menu.find(str(item["id"])).is_empty() and str(item.get("word", "")) != "":
			words.append(str(item["word"]))
	return words


# --- A bar's menu ------------------------------------------------------------------------

const MAX_WHY := 220  # characters: the line on why it's this bar's menu


## Checks the AI's menu for a new bar: {"dishes": [catalogue ids: the classics it keeps and its
## own], "prices": {id: won, optional}, "why": "a line on why"}. The always dishes are added
## by the game (any listed are fine). On success, data["menu"] is the menu in full (see
## menu_from) and data["why"] is tidied.
static func validate_menu(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("dishes", null)) != TYPE_ARRAY:
		return "\"dishes\" wasn't a list of catalogue ids"
	var chosen: Array = []
	for entry in data["dishes"]:
		var id := str(entry).strip_edges()
		if find(id).is_empty():
			return "\"%s\" isn't in the catalogue: use the ids as listed" % id
		if chosen.has(id) or ALWAYS.has(id) or MIXED.has(id):
			continue
		chosen.append(id)
	var classics := 0
	for group in CLASSICS:
		if group.any(func(id): return chosen.has(id)):
			classics += 1
	if classics < CLASSICS_AT_LEAST:
		return "it keeps %d of the pocha classics, and every tent has at least %d of them (tteokbokki, a fish cake, sundae, a pancake, gyeran-mari, a late-night noodle)" % [classics, CLASSICS_AT_LEAST]
	var own: Array = chosen.filter(func(id): return layer(id) == "own")
	if own.size() < OWN_PICKS.x or own.size() > OWN_PICKS.y:
		return "it has %d dishes of its own, beyond the classics, and a tent has %d to %d" % [own.size(), OWN_PICKS.x, OWN_PICKS.y]
	var total := ALWAYS.size() + chosen.size()
	if total > MENU_SIZE.y - SIGNATURES:
		return "that's %d dishes and drinks, and a tent's menu has at most %d (before its signature dishes): fewer" % [total, MENU_SIZE.y - SIGNATURES]
	if not chosen.any(func(id): return HEARTY.has(str(find(id)["category"]))):
		return "there's no hearty main (a stew, something from the grill, or seafood)"
	var prices: Dictionary = data.get("prices", {}) if typeof(data.get("prices", {})) == TYPE_DICTIONARY else {}
	for id in prices:
		var range_won: Array = find(str(id)).get("price_range", [])
		if range_won.is_empty():
			continue
		var price := int(prices[id])
		if price < int(range_won[0]) or price > int(range_won[1]):
			return "%s at ₩%d: it's between ₩%d and ₩%d at a pocha" % [find(str(id))["name"], price, int(range_won[0]), int(range_won[1])]
	var why := Text.tidy_text(data.get("why", ""))
	if why == "":
		return "\"why\" was empty: a line on why this is their menu"
	if why.length() > MAX_WHY:
		return "\"why\" is too long: one line"
	data["why"] = why
	data["menu"] = menu_from(chosen, prices)
	return ""


## A bar's menu in full, from the dishes chosen and their prices (each its usual price if
## not given): the always dishes first, then the classics, then its own.
static func menu_from(chosen: Array, prices: Dictionary = {}) -> Array:
	var ids: Array = ALWAYS.duplicate() + MIXED
	for wanted in ["classic", "own"]:
		for id in chosen:
			if layer(str(id)) == wanted and not ids.has(id):
				ids.append(id)
	var menu: Array = []
	for id in ids:
		var item := find(str(id))
		if prices.has(id):
			item["price"] = int(prices[id])
		menu.append(item)
	return menu


## The game's own menu, by the same rules, when the AI can't choose (or it's offline): the
## classics (CLASSICS_AT_LEAST of them, or one more), makgeolli now and then, and its own
## dishes, at least one hearty. dice: its own (from the bar's id), so the game's rolls don't shift.
static func fallback_menu(dice: RandomNumberGenerator) -> Array:
	var groups: Array = CLASSICS.duplicate()
	_shuffle(groups, dice)
	var chosen: Array = []
	for group in groups.slice(0, CLASSICS_AT_LEAST + dice.randi_range(0, 1)):
		chosen.append(group[dice.randi_range(0, group.size() - 1)])
	if dice.randf() < MAKGEOLLI_CHANCE:
		chosen.append("makgeolli")
	var own: Array = all().filter(func(item): return layer(str(item["id"])) == "own" and not bool(item.get("extra_only", false))).map(func(item): return str(item["id"]))
	_shuffle(own, dice)
	var hearty: Array = own.filter(func(id): return HEARTY.has(str(find(id)["category"])))
	var picks: Array = [hearty[0]]
	var wanted := dice.randi_range(OWN_PICKS.x, OWN_PICKS.y)
	for id in own:
		if picks.size() >= wanted:
			break
		if not picks.has(id):
			picks.append(id)
	return menu_from(chosen + picks)


static func _shuffle(list: Array, dice: RandomNumberGenerator) -> void:
	for k in range(list.size() - 1, 0, -1):
		var j := dice.randi_range(0, k)
		var held: Variant = list[k]
		list[k] = list[j]
		list[j] = held


## The catalogue as a list for the AI to choose from: each dish's id, name, what it is, its
## category, tags and price range, and whether it's one of the classics.
static func prompt_list() -> String:
	var lines := PackedStringArray()
	for item in all():
		var id := str(item["id"])
		if ALWAYS.has(id) or MIXED.has(id) or bool(item.get("extra_only", false)):
			continue
		var range_won: Array = item["price_range"]
		lines.append("- %s: %s (%s). %s; %s; ₩%d to ₩%d%s%s" % [id, item["name"], item["desc"], item["category"], ", ".join(PackedStringArray(item["tags"])),
			int(range_won[0]), int(range_won[1]), (", best in " + str(item["season"])) if item.has("season") else "", " (A CLASSIC)" if layer(id) == "classic" else ""])
	return "\n".join(lines)
