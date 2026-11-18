extends GdUnitTestSuite
## Tests for scripts/rules/menu.gd: the menu and prices are game facts, so they must be right.

const Menu = preload("res://scripts/rules/menu.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Text = preload("res://scripts/rules/text.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Specials = preload("res://scripts/rules/specials.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")


func test_resolve_accepts_exact_id() -> void:
	assert_str(Menu.resolve("soju")).is_equal("soju")


func test_resolve_ignores_hyphens_spaces_and_case() -> void:
	# The AI writes Korean names every which way (night 30: "Dak-bokkeumtang" orders turned away).
	assert_str(Menu.resolve("Gyeranmari")).is_equal(Menu.resolve("Gyeran-mari"))
	assert_str(Menu.resolve("gyeran mari")).is_equal(Menu.resolve("Gyeran-mari"))
	assert_str(Menu.resolve("Gyeran-ma-ri")).is_equal(Menu.resolve("Gyeran-mari"))
	assert_str(Menu.resolve("Gyeran-mari")).is_not_empty()
	assert_str(Menu.compact(" Dak-bokkeum tang ")).is_equal("dakbokkeumtang")
	assert_str(Menu.resolve("sundae pie")).is_empty()  # (not on the menu: still nothing)
	# A letter typed once too often (17 Nov: "ttteokbokki", turned away twice).
	assert_str(Menu.resolve("ttteokbokki")).is_equal(Menu.resolve("tteokbokki"))
	assert_str(Menu.compact("Ttteokbokkki")).is_equal("tteokbokki")


func test_resolve_accepts_display_name_with_hyphen() -> void:
	assert_str(Menu.resolve("Gyeran-mari")).is_equal("gyeran_mari")


func test_resolve_ignores_case_and_surrounding_spaces() -> void:
	assert_str(Menu.resolve("  TTEOKBOKKI ")).is_equal("tteokbokki")


func test_resolve_returns_empty_for_unknown_item() -> void:
	assert_str(Menu.resolve("pizza")).is_empty()


func test_find_returns_the_item() -> void:
	assert_str(str(Menu.find("odeng")["name"])).is_equal("Odeng")


func test_find_returns_empty_for_unknown_id() -> void:
	assert_bool(Menu.find("pizza").is_empty()).is_true()


func test_format_won_adds_symbol_and_commas() -> void:
	assert_str(Menu.format_won(12000)).is_equal("₩12,000")
	assert_str(Menu.format_won(5000)).is_equal("₩5,000")
	assert_str(Menu.format_won(1234567)).is_equal("₩1,234,567")


func test_format_won_small_amounts_have_no_comma() -> void:
	assert_str(Menu.format_won(999)).is_equal("₩999")
	assert_str(Menu.format_won(0)).is_equal("₩0")


func test_every_item_is_complete() -> void:
	for item in Menu.ITEMS:
		var id := str(item.get("id", ""))
		assert_str(id).override_failure_message("an item has no id").is_not_empty()
		assert_str(str(item.get("name", ""))).override_failure_message("%s has no name" % id).is_not_empty()
		assert_str(str(item.get("desc", ""))).override_failure_message("%s has no description" % id).is_not_empty()
		assert_int(int(item.get("price", 0))).override_failure_message("%s has no price" % id).is_greater(0)
		assert_bool(item.get("kind", "") in ["drink", "food"]).override_failure_message("%s isn't a drink or food" % id).is_true()
		assert_bool(Color.html_is_valid(str(item.get("color", "")))).override_failure_message("%s has a bad colour" % id).is_true()


func test_ids_are_unique() -> void:
	var seen := {}
	for item in Menu.ITEMS:
		assert_bool(seen.has(item["id"])).override_failure_message("duplicate id %s" % item["id"]).is_false()
		seen[item["id"]] = true


func test_every_name_resolves_to_its_own_id() -> void:
	for item in Menu.ITEMS:
		assert_str(Menu.resolve(str(item["name"]))).is_equal(str(item["id"]))


func test_prompt_list_can_be_shuffled_and_marks_the_specials() -> void:
	var order: Array = ["sundae", "soju", "odeng"]
	var text := Menu.prompt_list(order, ["sundae"])
	var lines := text.split("\n")
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).starts_with("- sundae:")
	assert_str(lines[0]).ends_with("(TONIGHT'S SPECIAL)")
	assert_str(lines[1]).starts_with("- soju:")
	assert_str(lines[1]).not_contains("SPECIAL")
	var shuffled := Menu.shuffled_ids()
	assert_int(shuffled.size()).is_equal(Menu.ITEMS.size())
	for item in Menu.ITEMS:
		assert_bool(shuffled.has(item["id"])).is_true()  # every item, just in a new order
	assert_str(Menu.prompt_list(shuffled)).not_contains("SPECIAL")  # (none given: none marked)


func test_prompt_list_mentions_every_id_and_price() -> void:
	var text := Menu.prompt_list()
	for item in Menu.ITEMS:
		assert_str(text).contains(str(item["id"]))
		assert_str(text).contains(Menu.format_won(item["price"]))



func test_every_food_is_a_main_or_a_side() -> void:
	for item in Menu.ITEMS:
		if item["kind"] == "food":
			assert_bool(item.get("portion", "") in ["main", "side"]).override_failure_message("%s needs a portion" % item["id"]).is_true()


func test_menu_has_mains_sides_and_drinks() -> void:
	var counts := {"drink": 0, "main": 0, "side": 0}
	for item in Menu.ITEMS:
		var key := "drink" if item["kind"] == "drink" else str(item.get("portion", ""))
		counts[key] = counts.get(key, 0) + 1
	assert_int(counts["drink"]).is_greater(0)
	assert_int(counts["main"]).is_greater(0)
	assert_int(counts["side"]).is_greater(0)


func test_prompt_list_marks_mains_and_sides() -> void:
	assert_str(Menu.prompt_list()).contains("food, main")
	assert_str(Menu.prompt_list()).contains("food, side")



func test_aliases_resolve_to_menu_ids() -> void:
	assert_str(Menu.resolve("rice")).is_equal("gonggibap")
	assert_str(Menu.resolve("Fried rice")).is_equal("bokkeumbap")


func test_drinks_and_ready_food_need_no_cooking() -> void:
	for id in ["soju", "makgeolli", "beer", "somaek", "odeng", "gonggibap"]:
		assert_int(Menu.cook_minutes(id)).override_failure_message("%s shouldn't need cooking" % id).is_equal(0)


func test_cooked_dishes_take_some_minutes() -> void:
	for id in ["tteokbokki", "dakgalbi", "pajeon", "ramyeon", "gyeran_mari", "bokkeumbap"]:
		assert_int(Menu.cook_minutes(id)).override_failure_message("%s should need cooking" % id).is_between(1, 20)


func test_each_bar_can_have_its_own_menu() -> void:
	# The classic menu, until a bar has its own.
	assert_array(Menu.items()).is_equal(Menu.ITEMS)
	assert_array(Menu.for_bar({})).is_empty()
	var version_was := Menu.version
	# (A dish of the bar's own, not in the catalogue: a signature dish, as saved.)
	var noodles := {"id": "halmeoni_guksu", "hangul": "할머니국수", "name": "Halmeoni-guksu", "desc": "grandma's noodles", "price": 9000.0, "kind": "food",
		"portion": "main", "color": "efe6c8", "cook": 6.0, "aliases": ["grandma's noodles"]}
	var bar := {"menu": [Menu.find("soju"), noodles]}
	Menu.use(Menu.for_bar(bar))
	assert_int(Menu.version).is_greater(version_was)
	assert_int(Menu.items().size()).is_equal(2)
	assert_str(Menu.resolve("Halmeoni-guksu")).is_equal("halmeoni_guksu")
	assert_str(Menu.resolve("grandma's noodles")).is_equal("halmeoni_guksu")
	assert_dict(Menu.find("tteokbokki")).is_empty()  # (not this bar's)
	assert_int(typeof(Menu.find("halmeoni_guksu")["price"])).is_equal(TYPE_INT)  # (back from a save as a decimal)
	assert_int(Menu.cook_minutes("halmeoni_guksu")).is_equal(6)
	assert_str(Menu.prompt_list()).contains("halmeoni_guksu").not_contains("tteokbokki")
	# Everything that reads the menu keeps up: the glossary, and tonight's specials. (Every
	# catalogue dish explains itself at any bar; one of the bar's own, only while it's open.)
	assert_bool(Glossary.lookup().has("halmeoni-guksu")).is_true()
	assert_bool(Glossary.lookup().has("tteokbokki")).is_true()
	var dice := RandomNumberGenerator.new()
	assert_array(Specials.tonight(Menu.items(), "rain", "winter", [], dice)["specials"]).is_equal(["halmeoni_guksu"])  # (no pancake or makgeolli here: its own dish)
	# And back to the classic menu.
	Menu.use([])
	assert_array(Menu.items()).is_equal(Menu.ITEMS)
	assert_bool(Glossary.lookup().has("halmeoni-guksu")).is_false()


func test_the_catalogue_is_complete() -> void:
	var everything := Catalogue.all()
	assert_int(everything.size()).is_greater_equal(40)
	var ids := {}
	var names := {}
	for item in everything:
		var id := str(item["id"])
		assert_bool(ids.has(id)).override_failure_message("%s twice" % id).is_false()
		ids[id] = true
		for field in ["hangul", "name", "desc", "kind", "category", "price_range", "tags", "art", "color"]:
			assert_bool(item.has(field)).override_failure_message("%s has no %s" % [id, field]).is_true()
		assert_array(["drinks", "stew", "pancake", "noodles", "seafood", "grill", "fried", "side", "rice"]).contains([item["category"]])
		var range_won: Array = item["price_range"]
		assert_int(int(item["price"])).override_failure_message("%s's price" % id).is_between(int(range_won[0]), int(range_won[1]))
		for tag in item["tags"]:
			assert_array(["spicy", "seafood", "comfort", "fancy", "cheap", "hearty", "light", "classic"]).contains([tag])
		assert_array(["", "summer", "winter"]).contains([str(item.get("season", ""))])
		if item["kind"] == "food":
			assert_array(["main", "side"]).contains([item.get("portion", "")])
		assert_bool(DishArt.VESSELS.has(str(item["art"].get("vessel", "")))).override_failure_message("%s's vessel" % id).is_true()
		var box := DishArt.size(item["art"])
		for shape in DishArt.shapes(item["art"], Color(str(item["color"])), id):
			var end: Vector2 = shape["pos"] + shape["size"]
			assert_bool(shape["pos"].x >= 0 and shape["pos"].y >= 0 and end.x <= box.x + 0.01 and end.y <= box.y + 0.01).override_failure_message("%s: a shape outside its box" % id).is_true()
		# Every name, and every other name, means one dish only.
		for called in [str(item["name"]).to_lower()] + Array(item.get("aliases", [])):
			assert_bool(names.has(called) and names[called] != id).override_failure_message("\"%s\" is two dishes" % called).is_false()
			names[called] = id
	# The layers: the dishes every bar has, and the classics, are all in it.
	for id in Catalogue.ALWAYS:
		assert_dict(Catalogue.find(id)).is_not_empty()
	for group in Catalogue.CLASSICS:
		for id in group:
			assert_dict(Catalogue.find(id)).override_failure_message(str(id)).is_not_empty()
	assert_str(Catalogue.layer("soju")).is_equal("always")
	assert_str(Catalogue.layer("kimchi_jeon")).is_equal("classic")
	assert_str(Catalogue.layer("makgeolli")).is_equal("classic")
	assert_str(Catalogue.layer("golbaengi_muchim")).is_equal("own")


func test_another_bars_dish_is_never_served_here() -> void:
	# On the classic menu: golbaengi is another bar's.
	assert_str(Talk.off_menu_here("Imo, I'll have the golbaengi tonight.")).is_equal("golbaengi")
	assert_str(Talk.off_menu_here("My uncle makes the best golbaengi in Busan.")).is_empty()  # (talking about it is fine)
	assert_array(Talk.romanised_korean("Have you ever had budae jjigae, though?")).is_empty()  # (it's real)
	assert_bool(Glossary.lookup().has("budae")).is_true()  # (and explains itself)
	# At a bar that serves it, it's served.
	Menu.use([Menu.find("soju"), Catalogue.find("golbaengi_muchim"), Catalogue.find("kimchi_jjigae")])
	assert_str(Talk.off_menu_here("Imo, I'll have the golbaengi tonight.")).is_empty()
	assert_str(Talk.off_menu_here("The kimchi jjigae here is the best.")).is_empty()  # (jjigae's ours tonight)
	Menu.use([])


func test_a_bars_menu_keeps_the_house_rules() -> void:
	var good := {"dishes": ["tteokbokki", "odeng", "sundae", "pajeon", "makgeolli", "golbaengi_muchim", "dak_ttongjip", "dubu_kimchi"],
		"prices": {"golbaengi_muchim": 22000}, "why": "  She grew up on her mother's whelk stall.  "}
	assert_str(Catalogue.validate_menu(good)).is_empty()
	var ids: Array = good["menu"].map(func(item): return str(item["id"]))
	assert_array(ids.slice(0, 4)).is_equal(["soju", "beer", "gonggibap", "somaek"])  # (the game adds them, first: somaek's mixed at the table)
	assert_int(ids.size()).is_equal(12)
	assert_int(int(good["menu"][ids.find("golbaengi_muchim")]["price"])).is_equal(22000)  # (its price)
	assert_int(int(good["menu"][ids.find("tteokbokki")]["price"])).is_equal(int(Catalogue.find("tteokbokki")["price"]))  # (the usual)
	assert_str(str(good["why"])).is_equal("She grew up on her mother's whelk stall.")
	# Broken rules go back with the reason.
	var few_classics := {"dishes": ["tteokbokki", "sundae", "golbaengi_muchim", "dak_ttongjip", "dubu_kimchi"], "why": "x"}
	assert_str(Catalogue.validate_menu(few_classics)).contains("classics")
	var no_own := {"dishes": ["tteokbokki", "odeng", "sundae", "pajeon"], "why": "x"}
	assert_str(Catalogue.validate_menu(no_own)).contains("of its own")
	var not_hearty := {"dishes": ["tteokbokki", "odeng", "sundae", "pajeon", "dubu_kimchi", "corn_cheese", "jumeokbap"], "why": "x"}
	assert_str(Catalogue.validate_menu(not_hearty)).contains("hearty")
	var dear := good.duplicate(true)
	dear["prices"] = {"tteokbokki": 50000}
	assert_str(Catalogue.validate_menu(dear)).contains("between")
	var unknown := good.duplicate(true)
	unknown["dishes"] = good["dishes"] + ["unicorn_stew"]
	assert_str(Catalogue.validate_menu(unknown)).contains("isn't in the catalogue")
	var why_not := good.duplicate(true)
	why_not["why"] = ""
	assert_str(Catalogue.validate_menu(why_not)).contains("why")
	var everything := {"dishes": Catalogue.all().map(func(item): return str(item["id"])), "why": "x"}
	assert_str(Catalogue.validate_menu(everything)).is_not_empty()  # (far too many)
	# The game's own menus keep the same rules.
	for k in 20:
		var dice := RandomNumberGenerator.new()
		dice.seed = k
		var fallback := Catalogue.fallback_menu(dice)
		var chosen: Array = fallback.map(func(item): return str(item["id"]))
		assert_str(Catalogue.validate_menu({"dishes": chosen, "why": "x"})).override_failure_message(str(chosen)).is_empty()
	# The AI's asked within them, with the whole catalogue but the dishes every pocha has.
	var asked := str(Prompts.menu_messages({"name": "Park Mi-sook", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "x", "appearance": "x", "personality": "x", "speech_style": "x", "secret": "x"}, "Byeolbit Pocha", "Starlight Tent")[1]["content"])
	assert_str(asked).contains("golbaengi_muchim").contains("A CLASSIC").contains("at least 4").not_contains("- soju:")


func test_the_fallback_order_is_always_on_the_menu() -> void:
	assert_array(Orders.fallback_order()).is_equal(["soju", "odeng"])
	Menu.use([Menu.find("soju"), Catalogue.find("gyeran_mari"), Catalogue.find("kimchi_jjigae")])
	assert_array(Orders.fallback_order()).is_equal(["soju", "gyeran_mari"])
	Menu.use([])


func test_the_board_shows_the_menu_the_way_a_pocha_writes_it() -> void:
	var ids: Array = Menu.board_order(["pajeon"]).map(func(item): return str(item["id"]))
	assert_str(str(ids[0])).is_equal("pajeon")  # tonight's special first
	assert_array(ids).not_contains(["bokkeumbap"])  # (you ask for it: made in the leftover sauce)
	assert_array(ids).not_contains(["somaek"])  # (you mix it at the table: never on the menu)
	assert_int(ids.find("tteokbokki")).is_less(ids.find("odeng"))  # mains, then sides
	assert_int(ids.find("odeng")).is_less(ids.find("soju"))  # then the drinks
	assert_int(ids.size()).is_equal(Menu.ITEMS.size() - 2)
	# The house favourite: the food ordered most lately, if it's been ordered a few times.
	var history := [{"order": ["soju", "tteokbokki"]}, {"order": ["beer", "tteokbokki", "odeng"]}, {"order": ["soju", "tteokbokki"]}, {"order": ["soju", "soju"]}]
	assert_str(Menu.favourite(history)).is_equal("tteokbokki")
	assert_str(Menu.favourite(history.slice(0, 2))).is_empty()  # (not enough yet)
	assert_str(Menu.favourite([{"order": ["soju"]}, {"order": ["soju"]}, {"order": ["soju"]}])).is_empty()  # (food only)


# --- Signature dishes ---------------------------------------------------------------------

const Signatures = preload("res://scripts/rules/signatures.gd")
const MenuBoard = preload("res://scripts/ui/menu_board.gd")

const A_SIGNATURE := {"name": "Halmeoni Kalguksu", "hangul": "할머니 칼국수", "meaning": "grandma's knife-cut noodles",
	"desc": "hand-cut noodles in anchovy broth, her grandmother's recipe", "category": "noodles", "vessel": "bowl", "bits": "noodles",
	"garnish": "seaweed", "colour": "#E9DCC0"}


func _signature(changes: Dictionary) -> Dictionary:
	var dish := A_SIGNATURE.duplicate()
	dish.merge(changes, true)
	return {"dishes": [dish]}


func test_a_signature_dish_is_the_ais_words_and_the_games_facts() -> void:
	var data := {"dishes": [A_SIGNATURE]}
	assert_str(Signatures.validate_signatures(data, Menu.ITEMS)).is_empty()
	var item: Dictionary = data["items"][0]
	assert_str(str(item["id"])).is_equal("own_halmeoni_kalguksu")
	assert_str(Catalogue.layer(str(item["id"]))).is_equal("signature")
	assert_bool(Signatures.is_signature(item)).is_true()
	# The game's price (the usual for its kind, and a little more: it's the house's own) and cooking time.
	assert_int(int(item["price"])).is_equal(Signatures.price_for("noodles"))
	assert_int(int(item["price"])).is_greater(Signatures.price_for("noodles") - Signatures.PREMIUM - 1)
	assert_int(int(item["cook"])).is_greater_equal(4)
	assert_str(str(item["portion"])).is_equal("main")
	assert_str(str(item["color"])).is_equal("e9dcc0")
	assert_str(str(item["art"]["vessel"])).is_equal("bowl")
	assert_str(str(item["art"]["fill"])).is_equal("e9dcc0")
	assert_array(item["aliases"]).contains(["grandma's knife-cut noodles"])  # (ordered by what it means, too)
	assert_bool(DishArt.shapes(item["art"], Color(str(item["color"])), str(item["id"])).is_empty()).is_false()  # drawn
	# Two is fine; three is too many, none too few.
	var two := {"dishes": [A_SIGNATURE, _signature({"name": "Eomma Son-mat Jjigae", "hangul": "엄마 손맛 찌개", "category": "stew", "vessel": "stone_pot"})["dishes"][0]]}
	assert_str(Signatures.validate_signatures(two)).is_empty()
	assert_str(Signatures.validate_signatures({"dishes": two["dishes"] + [A_SIGNATURE]})).is_not_empty()
	assert_str(Signatures.validate_signatures({"dishes": []})).is_not_empty()
	assert_str(Signatures.validate_signatures({"dishes": [A_SIGNATURE, A_SIGNATURE]})).contains("already")  # (two of the same)


func test_a_signature_dish_is_checked() -> void:
	for wrong in [
			{"hangul": "할머니 냉면"},  # (the Hangul isn't the name)
			{"hangul": "halmeoni"},
			{"name": "할머니 칼국수"},  # (the name in English letters)
			{"name": "Tteokbokki", "hangul": "떡볶이"},  # (already a dish)
			{"meaning": "할머니 칼국수"},  # (in English)
			{"meaning": ""},
			{"desc": "noodles"},  # (too short to say what it is)
			{"category": "dessert"},
			{"vessel": "bottle"},  # (food comes in a dish)
			{"bits": "sprinkles"},
			{"garnish": "glitter"},
			{"colour": "reddish"}]:
		assert_str(Signatures.validate_signatures(_signature(wrong), Menu.ITEMS)).override_failure_message("passed: %s" % wrong).is_not_empty()
	var brand: String = Talk.REAL_BRANDS[0]
	assert_str(Signatures.validate_signatures(_signature({"desc": "noodles the way %s makes them, but better" % brand}))).contains("brand")
	assert_str(Signatures.validate_signatures(_signature({"bits": "", "garnish": ""}))).is_empty()  # (bits and garnish are optional)
	# The game's own all pass, and one is always found.
	for dish in Signatures.FALLBACKS:
		assert_str(Signatures.validate_signatures({"dishes": [dish]}, Menu.ITEMS)).override_failure_message(str(dish["name"])).is_empty()
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	assert_int(Signatures.fallback(dice, Menu.ITEMS).size()).is_equal(1)


func test_a_signature_dish_explains_itself() -> void:
	var data := {"dishes": [A_SIGNATURE]}
	Signatures.validate_signatures(data)
	var item: Dictionary = data["items"][0]
	Menu.use(Menu.ITEMS + [item])
	assert_str(Menu.resolve("Halmeoni Kalguksu")).is_equal(str(item["id"]))
	assert_str(Menu.resolve("grandma's knife-cut noodles")).is_equal(str(item["id"]))
	assert_str(Menu.prompt_list([str(item["id"])])).contains("\"grandma's knife-cut noodles\"").contains("THE OWNER'S OWN DISH")
	assert_str(Glossary.hangul_tip("할머니 칼국수")).contains("Halmeoni Kalguksu").contains("grandma's knife-cut noodles")
	assert_str(Talk.off_menu_here("Have you tried the kalguksu here?")).is_empty()  # (it's served here)
	assert_array(Talk.romanised_korean("Halmeoni Kalguksu, please, and soju.")).is_empty()  # (real: it's on the menu)
	var board := MenuBoard.menu_text(Menu.board_order(), [], [], "", "Test Pocha")
	assert_str(board).contains("대표 메뉴").contains("Halmeoni Kalguksu").contains("grandma's knife-cut noodles")
	assert_int(board.find("대표 메뉴")).is_less(board.find("안주"))  # (the house's own first)
	assert_str(Prompts.signature_messages({"name": "Kim Mi-sook", "age": 58, "title": "Imo", "archetype": "a widow", "appearance": "Small.",
		"personality": "warm", "speech_style": "short", "secret": "none"}, "Test Pocha", "a test", ["Soju"])[1]["content"]).contains("stone_pot").contains("noodles")
	Menu.use([])


# --- Menus that change slowly ---------------------------------------------------------------

const MenuChanges = preload("res://scripts/rules/menu_changes.gd")


func test_a_dish_nobody_orders_makes_way_for_something_new() -> void:
	# Every few weeks of nights, now and then.
	assert_bool(MenuChanges.due(MenuChanges.EVERY - 1, 0.0)).is_false()
	assert_bool(MenuChanges.due(MenuChanges.EVERY, 0.0)).is_true()
	assert_bool(MenuChanges.due(MenuChanges.EVERY * 3, 0.99)).is_false()
	var menu: Array = Catalogue.menu_from(["tteokbokki", "odeng", "sundae", "pajeon", "kimchi_jjigae", "naengmyeon", "golbaengi_muchim"])
	var own := {"id": "own_halmeoni_kalguksu", "name": "Halmeoni Kalguksu", "kind": "food", "portion": "main", "price": 10000, "signature": true}
	menu.append(own)
	# What goes: the bar's own pick ordered least (never a classic, a staple or the owner's own),
	# if hardly anyone's ordered it, and not anyone's usual.
	var history: Array = []
	for k in 10:
		history.append({"order": ["soju", "kimchi_jjigae"]})
	history.append({"order": ["beer", "golbaengi_muchim"]})
	assert_str(MenuChanges.going(menu, history, [])).is_equal("naengmyeon")  # (never ordered)
	assert_str(MenuChanges.going(menu, history, ["naengmyeon"])).is_equal("golbaengi_muchim")  # (a regular's usual stays)
	assert_str(MenuChanges.going(menu, history, ["naengmyeon", "golbaengi_muchim"])).is_empty()  # (kimchi-jjigae sells: it stays)
	# What could come on: off the menu, the same kind, best this season first; hearty if it has to be.
	var dice := RandomNumberGenerator.new()
	dice.seed = 5
	var summer := MenuChanges.offered(menu, "naengmyeon", "summer", dice)
	assert_int(summer.size()).is_equal(MenuChanges.OFFERED)
	for id in summer:
		assert_str(str(Catalogue.find(str(id))["kind"])).is_equal("food")
		assert_array(menu.map(func(item): return item["id"])).not_contains([id])
		assert_str(Catalogue.layer(str(id))).is_equal("own")
	var only_hearty: Array = Catalogue.menu_from(["tteokbokki", "odeng", "sundae", "pajeon", "kimchi_jjigae"])
	for id in MenuChanges.offered(only_hearty, "kimchi_jjigae", "winter", dice):
		assert_array(Catalogue.HEARTY).contains([Catalogue.find(str(id))["category"]])  # (the house rules: a hearty main)
	# The AI chooses one of them, with a line on why.
	assert_str(MenuChanges.validate_change({"dish": summer[0], "why": "It's too hot for stew."}, summer)).is_empty()
	assert_str(MenuChanges.validate_change({"dish": "pizza", "why": "Why not."}, summer)).is_not_empty()
	assert_str(MenuChanges.validate_change({"dish": summer[0], "why": ""}, summer)).is_not_empty()
	# Swapped in its place, at its usual price.
	var swapped := MenuChanges.swapped(menu, "naengmyeon", str(summer[0]))
	assert_int(swapped.size()).is_equal(menu.size())
	assert_str(str(swapped[menu.map(func(item): return item["id"]).find("naengmyeon")]["id"])).is_equal(str(summer[0]))
	assert_int(int(swapped[menu.map(func(item): return item["id"]).find("naengmyeon")]["price"])).is_equal(int(Catalogue.find(str(summer[0]))["price"]))


func test_a_signature_dishs_hangul_may_run_its_words_together() -> void:
	# 18 Nov: "Appa Jjamppong" written 아빠짬뽕 was turned down for having one word, not two.
	assert_str(Signatures.hangul_problem("Appa Jjamppong", "아빠짬뽕")).is_empty()
	assert_str(Signatures.hangul_problem("Appa Jjamppong", "아빠 짬뽕")).is_empty()
	assert_str(Signatures.hangul_problem("Appa Jjamppong", "김치짬뽕")).contains("doesn't match")  # (it still has to start right)
	assert_str(Signatures.hangul_problem("Halmeoni Kalguksu", "할머니칼국수")).is_empty()  # (was turned down before 18 Nov, for having no space)


func test_a_dish_asked_for_as_the_menu_describes_it_is_that_dish() -> void:
	# 18 Nov: "those sausage and rice cakes on a stick" (sotteok) read as tteokbokki's "rice cakes".
	Menu.use([Menu.find("tteokbokki"), Catalogue.find("sotteok"), Menu.find("soju")])
	var said: Array = Orders.mentions("Can I get some of those sausage and rice cakes on a stick too?", true).map(func(m): return str(m["id"]))
	assert_array(said).contains(["sotteok"])
	assert_array(said).not_contains(["tteokbokki"])
	assert_array(Orders.mentions("Spicy rice cakes, please.", true).map(func(m): return str(m["id"]))).contains(["tteokbokki"])  # (still tteokbokki)
	Menu.use([])


func test_the_kimchi_on_the_table_isnt_kimchi_jjigae() -> void:
	# 18 Nov: "Eat the kimchi first" turned down 10 times as mentioning Kimchi-jjigae (the banchan's free).
	Menu.use([Menu.find("tteokbokki"), Catalogue.find("kimchi_jjigae"), Menu.find("soju")])
	assert_str(Orders.unordered_mention("Eat the kimchi first, you're too thin.", ["tteokbokki", "soju"])).is_empty()
	assert_str(Orders.unordered_mention("Is the kimchi jjigae any good tonight?", ["tteokbokki", "soju"])).is_equal("Kimchi-jjigae")  # (by name: still found)
	assert_str(Orders.unordered_mention("Kimchijjigae, please.", ["tteokbokki", "soju"])).is_equal("Kimchi-jjigae")
	Menu.use([])


func test_a_menu_id_written_another_way_is_still_found() -> void:
	# 18 Nov: "gyeran-mari" for gyeran_mari turned the new bar's menu down.
	assert_str(Catalogue.loose_id("gyeran-mari")).is_equal("gyeran_mari")
	assert_str(Catalogue.loose_id("Gyeran Mari")).is_equal("gyeran_mari")
	assert_str(Catalogue.loose_id("sunda")).is_empty()  # (not a dish: still turned down)
	assert_str(Text.problem_kind("\"sunda\" isn't in the catalogue: use the ids as listed")).is_equal("menu ids")  # (not "the cat")
