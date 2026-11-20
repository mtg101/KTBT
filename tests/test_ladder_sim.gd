extends GdUnitTestSuite
## Tests for scripts/rules/ladder_sim.gd: the ladder simulated, many shows through many seasons
## in a moment, checking it's paced as meant: a rung can be climbed in one great season, more
## likely two; a PD who does little stays near the bottom; and the reports, printed (run this
## suite to see them when tuning the ladder).

const LadderSim = preload("res://scripts/rules/ladder_sim.gd")

const SHOWS := 200
const SEASONS := 8


func _run(pd: String, seed_value: int = 20) -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var model: Array = LadderSim.PDS[pd]
	var result := LadderSim.run(dice, float(model[0]), float(model[1]), SEASONS, SHOWS)
	print(LadderSim.report(result, "%s PD (nights about %.1f, spread %.1f)" % [pd, float(model[0]), float(model[1])]))
	return result


func test_the_ladder_is_paced_a_rung_in_one_great_season_more_likely_two() -> void:
	var autopilot := _run("autopilot")
	# A PD like the autopilot: a channel after a season, mostly; TV a season or two later.
	assert_int(LadderSim.median_climb(autopilot, "video")).is_between(1, 2)
	assert_int(LadderSim.median_climb(autopilot, "network")).is_between(1, 2)
	assert_float(LadderSim.share_by(autopilot, "network", SEASONS)).is_greater(0.8)  # (most get to TV in the end)
	# A great PD: a rung a season.
	var great := _run("great")
	assert_int(LadderSim.median_climb(great, "video")).is_equal(1)
	assert_int(LadderSim.median_climb(great, "network")).is_equal(1)
	_run("steady")  # (in between: for the report)
	# A PD who lets the night run: the stream, mostly.
	var quiet := _run("quiet")
	assert_float(LadderSim.share_by(quiet, "network", SEASONS)).is_less(0.2)
	# The same dice, the same shows.
	assert_dict(_run("autopilot")["final"]).is_equal(autopilot["final"])
