extends GdUnitTestSuite
## Tests for scripts/menu.gd: the menu and prices are game facts, so they must be right.

const Menu = preload("res://scripts/menu.gd")


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
