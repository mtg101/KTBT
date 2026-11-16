extends GdUnitTestSuite
## Tests for scripts/menu.gd: the menu and prices are game facts, so they must be right.

const Menu = preload("res://scripts/menu.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Prompts = preload("res://scripts/prompts.gd")


func test_resolve_accepts_exact_id() -> void:
	assert_str(Menu.resolve("soju")).is_equal("soju")


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
	assert_array(Orders.pick_specials("rain", 0.0, 0.0)).is_empty()  # (no pajeon or makgeolli here)
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
