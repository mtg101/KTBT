extends GdUnitTestSuite
## Tests for scripts/bar/scenery.gd and scripts/bar/stats_panel.gd: the tent's fixtures, and
## the stats panel's tabs, on their own.

const Scenery = preload("res://scripts/bar/scenery.gd")
const StatsPanel = preload("res://scripts/bar/stats_panel.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")


func test_the_tents_fixtures() -> void:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: the steam and the neon's flicker are tweens)
	var scenery := Scenery.new(RandomNumberGenerator.new(), 1872.0)
	scenery.build_fridge(stage)
	scenery.build_odeng_pot(stage)
	scenery.build_neon(stage)
	assert_object(stage.get_node_or_null("Fridge")).is_not_null()
	assert_str((stage.get_node("OdengPot") as Control).tooltip_text).contains("Odeng")
	assert_str(scenery.neon.tooltip_text).contains("noraebang")  # (Korean on screen explains itself)
	# Its three syllables fit on its board (117 to 216), in the pixel font.
	assert_float(scenery.neon.position.y).is_greater_equal(117.0)
	assert_float(scenery.neon.position.y + scenery.neon.get_combined_minimum_size().y).is_less_equal(216.0)
	var board_left: float = scenery.stage_width - Scenery.NEON_BOARD_IN
	assert_float(scenery.neon.position.x - board_left).is_equal(9.0)  # (inside the tube, a pixel clear: the board 39 wide)
	var dish := Control.new()
	stage.add_child(dish)
	scenery.steam(dish)
	assert_int(dish.get_child_count()).is_equal(2)  # (two puffs)
	var cloud: TextureRect = dish.get_child(0)
	assert_vector(cloud.size).is_equal(Vector2(2, 2) * Scenery.PUFF_PIXEL)  # a little cloud in pixels
	scenery._rise(0.5, cloud, Vector2(9, 12), Vector2(6, -18), 0.28)
	assert_float(fposmod(cloud.get_global_transform().origin.x, 3.0)).is_equal_approx(0.0, 0.01)  # on the grid's lines
	assert_float(cloud.modulate.a).is_equal_approx(0.14, 0.001)  # fading in steps
	var board := Scenery.closed_board()
	assert_vector(Vector2(board.get_size())).is_equal(Vector2(28, 27))  # (the CLOSED board, in pixel art)


func test_the_side_panel_has_four_tabs_and_the_stats_a_section_at_a_time() -> void:
	var text: RichTextLabel = auto_free(RichTextLabel.new())
	text.bbcode_enabled = true
	var tabs: HFlowContainer = auto_free(HFlowContainer.new())
	var panel := StatsPanel.new(text, tabs, Color.WHITE, Color.GRAY)
	var diary_opened := [0]
	panel.on_diary = func(): diary_opened[0] += 1
	var stats := NightStats.new()
	stats.events = [{"kind": "cheered_on", "at": 21 * 60 + 58}]
	panel.refresh(stats, 0, 0, 3, "[b]THE OWNER[/b]\nPark Mi-sook, 58", "[b]BEHIND THE CAMERA[/b]\nKim Ji-woo, the owner's niece")
	assert_array(tabs.get_children().filter(func(c): return c is Button and not c is OptionButton).map(func(b): return (b as Button).text)).is_equal(["Here now", "📺 The show", "📖 Diary", "Stats"])
	# It opens on who's here now (the tent's own text), not the stats.
	assert_str(text.get_parsed_text()).contains("HERE NOW").contains("Night 3").contains("Park Mi-sook").not_contains("HIGHLIGHTS")
	(tabs.get_node("PanelTab_THE_SHOW") as Button).pressed.emit()  # (as clicking it does)
	assert_str(text.get_parsed_text()).contains("THE SHOW").contains("Kim Ji-woo, the owner's niece")
	(tabs.get_node("PanelTab_DIARY") as Button).pressed.emit()  # the diary pops up; the tab stays where it was
	assert_int(diary_opened[0]).is_equal(1)
	assert_str(panel.tab).is_equal(StatsPanel.SHOW)
	# The stats: every section, from a dropdown, Highlights first and All at the end.
	var sections := tabs.get_node("StatsSection") as OptionButton
	assert_bool(sections.visible).is_false()
	(tabs.get_node("PanelTab_STATS") as Button).pressed.emit()
	assert_bool(sections.visible).is_true()
	assert_str(sections.get_item_text(0)).starts_with("Highlights")  # (with how many tonight)
	assert_str(sections.get_item_text(sections.item_count - 1)).is_equal("All")
	assert_str(text.get_parsed_text()).contains("STATS (debug)").contains("HIGHLIGHTS").contains("hwaiting chorus").not_contains("PEOPLE")
	sections.select(sections.item_count - 1)
	sections.item_selected.emit(sections.item_count - 1)  # (as picking it does)
	assert_str(panel.section).is_equal("ALL")
	assert_str(text.get_parsed_text()).contains("PEOPLE").contains("HIGHLIGHTS")
	panel.show_section("PEOPLE")
	assert_str(text.get_parsed_text()).contains("PEOPLE").not_contains("hwaiting chorus")
	assert_str(sections.get_item_text(sections.selected)).is_equal("People")