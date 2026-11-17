extends RefCounted
## Bars saved by older versions of the game, brought up to date in one place (step 6 of the
## refactor: see DEVLOG.md). Two kinds:
## - upgrade: what the game fills in itself, as the bar opens (an owner from before looks gets
##   a look for their age; one from before owners had a fixed life gets one): saved straight away.
## - ai_needs: what it needs the AI for, once, while the bar opens (names in Hangul, founding
##   regulars for a bar from before regulars, signature dishes for a menu from before them).
## Each upgrade happens once: what it fills in is saved, so the next time there's nothing to do.

const Looks = preload("res://scripts/rules/looks.gd")
const People = preload("res://scripts/rules/people.gd")


## What the game fills in itself, without the AI. Returns what it filled in ([]: nothing):
## "owner_look", "owner_life". (The game's dice, in the order they always were: the look first.)
static func upgrade(bar: Dictionary) -> Array:
	var changed: Array = []
	var owner_data: Dictionary = bar.get("owner", {})
	if not owner_data.has("look"):  # a bar from before looks: one for their age, without asking the AI
		owner_data["look"] = Looks.pick_look(str(owner_data.get("gender", "woman")), Looks.age_range_of(int(owner_data.get("age", 55))), "", true)
		changed.append("owner_look")
	if People.fill_owner_life(owner_data, randf()):  # a bar from before owners had a fixed life
		changed.append("owner_life")
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
