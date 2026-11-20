extends GdUnitTestSuite
## Tests for scripts/save/save_upgrades.gd (older bars brought up to date in one place) and the
## diary's cap in scripts/save/save_store.gd.

const SaveUpgrades = preload("res://scripts/save/save_upgrades.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")

const OLD_OWNER := {"name": "Kim Sung-ho", "age": 58, "gender": "man", "title": "Ajusshi"}


func test_an_old_bar_gets_what_the_game_can_fill_in_once() -> void:
	var bar := {"id": "old-pocha", "name": "Old Pocha", "owner": OLD_OWNER.duplicate()}
	var changed := SaveUpgrades.upgrade(bar)
	assert_array(changed).contains(["owner_look", "owner_life", "show"])
	assert_dict(bar["show"]).is_equal(ShowSeasons.fresh("network"))  # (a bar from before seasons: season 1 starts next night, on network TV, where its show always was)
	var before_ladder := {"id": "ladder-pocha", "owner": bar["owner"], "cat": bar.get("cat", {}), "show": {"season": 2, "aired": 3}}  # (a bar from before the ladder: on cable)
	assert_array(SaveUpgrades.upgrade(before_ladder)).is_equal(["rung"])
	assert_str(str(before_ladder["show"]["rung"])).is_equal("network")
	var retired := {"id": "cable-pocha", "owner": bar["owner"], "cat": bar.get("cat", {}), "show": {"season": 1, "aired": 2, "rung": "cable"}}  # (a rung there was for a day)
	assert_array(SaveUpgrades.upgrade(retired)).is_equal(["rung"])
	assert_str(str(retired["show"]["rung"])).is_equal("network")
	assert_str(str(SaveStore.new_bar("New Pocha", "", OLD_OWNER)["show"]["rung"])).is_equal("phone")  # (a new bar starts on the phone stream)
	assert_bool(bar["owner"].has("look")).is_true()
	assert_str(str(bar["owner"].get("family", ""))).is_not_empty()
	assert_array(SaveUpgrades.upgrade(bar)).is_empty()  # (once: next time, nothing to do)
	# A cat from before nicknames gets one (the old name kept), once.
	var with_cat := {"id": "cat-pocha", "owner": bar["owner"], "cat": {"name": "Ji-eun", "coat": "black", "personality": "lazy", "hangul": "지은"}}
	assert_array(SaveUpgrades.upgrade(with_cat)).is_equal(["cat_nickname", "show"])
	assert_bool(CatRules.nicknames_for("black").has(str(with_cat["cat"]["name"]))).is_true()
	assert_str(str(with_cat["cat"]["former_name"])).is_equal("Ji-eun")
	assert_str(str(with_cat["cat"]["hangul"])).is_equal(str(CatRules.CAT_NICKNAMES[with_cat["cat"]["name"]]["hangul"]))
	assert_array(SaveUpgrades.upgrade(with_cat)).is_empty()
	# A bar from when takings were kept: they go (the ratings are the score, 19 Nov), once.
	var with_takings := {"id": "rich-pocha", "owner": bar["owner"], "takings": 412000, "night_log": [{"night": 1, "customers": 9, "takings": 98000}]}
	assert_array(SaveUpgrades.upgrade(with_takings)).is_equal(["takings", "show"])
	assert_bool(with_takings.has("takings")).is_false()
	assert_dict(with_takings["night_log"][0]).is_equal({"night": 1, "customers": 9})
	assert_array(SaveUpgrades.upgrade(with_takings)).is_empty()


func test_what_an_old_bar_still_needs_the_ai_for() -> void:
	var bar := {"owner": OLD_OWNER.duplicate(), "cat": {"name": "Nabi", "hangul": "나비"}, "menu": [{"id": "soju"}]}
	assert_array(SaveUpgrades.ai_needs(bar)).contains_exactly(["hangul", "founding_regulars", "signatures"])
	bar["owner"]["hangul"] = "김성호"
	bar["regulars"] = []
	bar["signatures_by"] = "game"
	assert_array(SaveUpgrades.ai_needs(bar)).is_empty()
	bar.erase("regulars")
	assert_array(SaveUpgrades.ai_needs(bar, true, false)).is_empty()  # (founding regulars off, in a test)
	assert_array(SaveUpgrades.ai_needs({"owner": {"hangul": "김성호"}, "regulars": []})).is_empty()  # (the classic menu: no signatures to make)


func test_a_bar_keeps_its_latest_diary_entries() -> void:
	var bar := {}
	for night in SaveStore.DIARY_LIMIT + 5:
		SaveStore.record_diary(bar, {"night": night + 1, "text": "Night %d." % (night + 1)})
	assert_int(bar["diary"].size()).is_equal(SaveStore.DIARY_LIMIT)
	assert_int(int(bar["diary"][0]["night"])).is_equal(6)  # (the oldest went)
	SaveStore.record_diary(bar, {"night": SaveStore.DIARY_LIMIT + 5, "text": "Written again."})  # (the same night: replaced)
	assert_int(bar["diary"].size()).is_equal(SaveStore.DIARY_LIMIT)
	assert_str(str(bar["diary"][-1]["text"])).is_equal("Written again.")
