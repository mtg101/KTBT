extends RefCounted
## Bars saved by older versions of the game, brought up to date in one place (step 6 of the
## refactor: see DEVLOG.md). Two kinds:
## - upgrade: what the game fills in itself, as the bar opens (an owner from before looks gets
##   a look for their age; one from before owners had a fixed life gets one; a cat from before
##   nicknames gets one, its old name kept as "former_name"; regulars from before bonds have
##   their memories, names and friends moved into bonds, and their facts marked known by the
##   owner): saved straight away.
## - ai_needs: what it needs the AI for, once, while the bar opens (names in Hangul, founding
##   regulars for a bar from before regulars, signature dishes for a menu from before them).
## Each upgrade happens once: what it fills in is saved, so the next time there's nothing to do.

const Looks = preload("res://scripts/rules/looks.gd")
const People = preload("res://scripts/rules/people.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Bonds = preload("res://scripts/rules/bonds.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")


## What the game fills in itself, without the AI. Returns what it filled in ([]: nothing):
## "owner_look", "owner_life", "cat_nickname", "bonds", "takings" (dropped), "show" (a bar from before
## seasons: its first season starts with its next night, on network TV, where its show always was),
## "rung" (a bar from before the ladder, or on a rung there was for a day: on network TV). (The game's dice, in the order they always were:
## the look first; the cat's nickname needs none.)
static func upgrade(bar: Dictionary) -> Array:
	var changed: Array = []
	var owner_data: Dictionary = bar.get("owner", {})
	if not owner_data.has("look"):  # a bar from before looks: one for their age, without asking the AI
		owner_data["look"] = Looks.pick_look(str(owner_data.get("gender", "woman")), Looks.age_range_of(int(owner_data.get("age", 55))), "", true)
		changed.append("owner_look")
	if People.fill_owner_life(owner_data, randf()):  # a bar from before owners had a fixed life
		changed.append("owner_life")
	var cat: Dictionary = bar.get("cat", {})
	if not cat.is_empty() and not CatRules.is_nickname(str(cat.get("name", ""))):  # a cat from before nicknames (no dice)
		cat["former_name"] = str(cat.get("name", ""))
		cat["name"] = CatRules.nickname_for_old_cat(cat)
		cat["hangul"] = str(CatRules.CAT_NICKNAMES[cat["name"]]["hangul"])
		changed.append("cat_nickname")
	if Bonds.upgrade(bar):  # regulars from before bonds (no dice)
		changed.append("bonds")
	if bar.has("takings"):  # a bar from when takings were kept (they aren't: the ratings are the score, 19 Nov)
		bar.erase("takings")
		for night in bar.get("night_log", []):
			night.erase("takings")
		changed.append("takings")
	if not bar.has("show"):  # a bar from before the show had seasons (19 Nov): season 1 starts next night
		bar["show"] = ShowSeasons.fresh(Ladder.OLDER)
		changed.append("show")
	elif not bar["show"].has("rung") or Ladder.RETIRED.has(str(bar["show"]["rung"])):  # a bar from before the ladder (20 Nov), or on a rung retired the same day: network TV
		bar["show"]["rung"] = Ladder.OLDER
		changed.append("rung")
	return changed


## What a bar still needs the AI for, once, as it opens: "hangul" (the owner's or the cat's name
## in Hangul, from before names had it, or whose first try didn't fit), "founding_regulars" (a
## bar from before regulars: its two), "signatures" (a menu from before signature dishes).
## menus, founding: whether those are on (test hooks).
static func ai_needs(bar: Dictionary, menus: bool = true, founding: bool = true) -> Array:
	var needs: Array = []
	var cat: Dictionary = bar.get("cat", {})
	if str(bar.get("owner", {}).get("hangul", "")) == "" or (not cat.is_empty() and str(cat.get("hangul", "")) == ""):
		needs.append("hangul")
	if founding and not bar.has("regulars"):
		needs.append("founding_regulars")
	if menus and not bar.get("menu", []).is_empty() and not bar.has("signatures_by"):
		needs.append("signatures")
	return needs
