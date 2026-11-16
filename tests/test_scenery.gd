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
	var dish := Control.new()
	stage.add_child(dish)
	scenery.steam(dish)
	assert_int(dish.get_child_count()).is_equal(2)  # (two puffs)


func test_the_stats_panel_shows_a_section_at_a_time() -> void:
	var text: RichTextLabel = auto_free(RichTextLabel.new())
	text.bbcode_enabled = true
	var tabs: HFlowContainer = auto_free(HFlowContainer.new())
	var panel := StatsPanel.new(text, tabs, Color.WHITE, Color.GRAY)
	var stats := NightStats.new()
	stats.events = [{"kind": "cheered_on", "at": 21 * 60 + 58}]
	panel.refresh(stats, 0, 0, 3)
	assert_str(text.get_parsed_text()).contains("Night 3").contains("HIGHLIGHTS").contains("hwaiting chorus").not_contains("PEOPLE")
	var all := tabs.get_node("StatsTab_ALL") as Button
	all.pressed.emit()  # (as clicking it does)
	assert_str(panel.tab).is_equal("ALL")
	assert_str(text.get_parsed_text()).contains("PEOPLE").contains("HIGHLIGHTS")
	assert_bool(all.button_pressed).is_true()
