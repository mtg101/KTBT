# KTBT: Architecture

How the code is laid out, so you can find things and know where new things go. (Being tidied up step by step: see **A proper refactor** in [PLAN.md](PLAN.md). This page describes it as it is now.)

## The layers

The game's one big rule is **the game owns the facts, the AI owns the flavour**: the game decides what's true (who's here, what they ordered, the bill, the clock), asks the AI to write the words, and checks every reply against the facts before it's used. The code is layered the same way, from the bottom up:

1. **Rules** (`scripts/rules/`, plus `menu.gd` and `regulars.gd`): pure functions and the tables they use. No scene, no AI, no saving; any dice roll is passed in. They decide things (when people arrive, who may call whom what, how pull fades) and check the AI's replies (`validate_*`). Fast to test: `tests/test_rules.gd`, `tests/test_menu.gd`, `tests/test_regulars.gd`.
2. **Prompts and the AI** (`prompts.gd`, `ai.gd`, `ollama_client.gd`, `canned_ai.gd`, `ai_settings.gd`): what the AI is asked, sending it to Ollama (or offline mode's canned replies), and retrying a reply the rules reject.
3. **Saves and logs** (`save_store.gd`, `night_stats.gd`, `game.gd`): each bar's save file, the night's stats, and the `Game` autoload that holds the open bar.
4. **The bar** (`visit.gd`, with `scenes/visit.tscn`): runs a night, using everything above. Still one big script; splitting it is step 4 of the refactor.
   - **The night's events** (`night_events.gd`): everything noteworthy is announced once (someone walks on, sits down, pays, a dish is served, a chat starts, the cat moves, a big moment...), as plain data. Listening: the stats count them (`NightStats.record_event`), the TV captions pick theirs (`Captions.for_event`), and tonight's list of them becomes the diary's facts (`Story.diary_facts`) and goes in the night's log. Something new that wants to know what happened is another listener, not more lines through the bar.
5. **On screen** (the look in `ktv_style.gd`: the K-TV palette, outlined labels, pills and title-card text, which everything on screen builds from; then `bubble.gd`, `caption.gd`, `caption_reel.gd`, `diary_page.gd`, `diary_book.gd`, `recap_screen.gd`, `loading_screen.gd`, `title.gd`) and **sound** (`ambience.gd`, `music.gd`): pieces the bar and title screen show. All drawn and made in code for now.

Higher layers use lower ones, never the other way round: the rules don't know about scenes, and nothing below the bar knows about it.

## The rules, by area

Each file starts with what it's for. They preload each other as needed (never in a circle):

| File | What's in it |
|---|---|
| `rules/text.gd` | Tidying the AI's text, splitting words, checking a reply has its fields, picking by weight, sorting rejected replies into kinds |
| `rules/people.gd` | Owners and customers (checked), ages and genders, pronouns, stays and moods for company, founding regulars, the owner's fixed life |
| `rules/names.gd` | Names: Korean order and the usual casing, given names, and Hangul (checked against the romanised name) |
| `rules/looks.gd` | How people look (age range, hair, clothes, colours), how strangers are known by their looks, and the street: rain gear, who walks together, phones |
| `rules/bar_look.gd` | Each bar's name and look, from the options the game offers, and the fallbacks |
| `rules/night_rules.gd` | The clock, arrivals, how fast time runs, the days, passers-by, the sky's light and the weather |
| `rules/orders.gd` | Orders and later orders (checked; a side the line asks for is added), which food a line mentions, what's served straight away and what's cooked, tonight's specials, the bill |
| `rules/talk.gd` | The checks every line of dialogue passes, what conversations turn to, speech bubble pages, made-up Korean, and the situations a line is given now and then (food moments, table customs, sharing, how someone orders, cravings, how the owner opens) |
| `rules/address.gd` | Who calls whom what (oppa, imo, sajangnim...), and their colours on screen |
| `rules/glossary.gd` | Korean words explained on hover (the menu, pocha words, terms of address), any Hangul too (names as they're known), and counting which are said |
| `rules/hangul.gd` | What the game's own Hangul means (captions, reactions, stamps, days, titles, signs), romanised, for its hovers |
| `rules/cat_rules.gd` | The cat: coats, personalities, where it goes, how it's talked about (and the moments for talking to it), its name |
| `rules/memories.gd` | What's remembered after a visit, and the things that stick |
| `rules/captions.gd` | Korean TV captions (the game's own, from what happens) and TV reactions (from what's said) |
| `rules/story.gd` | The owner's diary at 3am, "Previously on...", and the owner's reason for closing early |
| `rules/seasons.gd` | The calendar (each bar's nights through the year), Korea's seasons and the monsoon, and tonight's weather following on from last night's |
| `rules/skyline.gd` | The city behind the tent: each bar's skyline (APT blocks, office towers, churches) and its windows going dark through the night |
| `rules/catalogue.gd` | Every dish and drink a pocha might serve, by layer (always, the classics, the bar's own), and a bar's menu: the house rules the AI's choice is checked against, and the game's own menu when it can't choose |
| `rules/signatures.gd` | A bar's signature dishes: the AI's (named in romanised Korean and Hangul, with what the name means, from the owner's story) checked, the game's price and cooking time set, and the game's own when the AI can't |
| `rules/specials.gd` | Tonight's specials and what's sold out, from the bar's own menu: by the weather and the season, never a staple or last night's again, now and then the owner's own dish |
| `rules/menu_changes.gd` | Menus that change slowly: when a dish hardly anyone orders comes off (never a classic, a staple, the owner's own or a regular's usual), and the seasonal dishes offered in its place |
| `rules/dish_art.gd` | How a dish or drink looks on the table, from its menu item's description (vessel, fill, bits, garnish) |
| `bar/tent_view.gd` | The tent's look: the tarp, the sign, the bar's touches, the sky and light by the hour, the bulbs and tonight's weather (the first part split out of `visit.gd`) |
| `bar/people_view.gd` | Drawing people: a person dressed in their look, facing us or seated from behind, a phone, an umbrella (with the snow or rain on it) or a bag over their head, running for it (part 2 split out of `visit.gd`) |
| `bar/street.gd` | The street in front of the tent: strollers, passers-by who look in and walk on, and rain gear for anyone out in the weather (part 3 split out of `visit.gd`) |
| `bar/night.gd` | Tonight: what the tent's parts share, in one place (so far its weather and its stats; it grows as parts move out) |
| `bar/layout.gd` | Where things are on the tent's stage, shared by the scene and its parts |
| `bar/draw.gd` | Small drawing helpers the tent's parts share (plain shapes, clearing a layer, how long an animation takes, sped up in tests) |

## Tests

See [TESTS.md](TESTS.md). Every test hook is in `scripts/test_hooks.gd` (the game reads them as `Hooks.<name>`, and only tests set them); scene tests share `tests/support/bar_test.gd`, and `tests/support/fake_ollama.gd` stands in for Ollama to test `ai.gd`.

## Where new things go

- **A new rule or check:** the rules file for its area (or a new one, if it's a new area), with a test in `tests/test_rules.gd`.
- **A new kind of AI request:** its prompt in `prompts.gd`, its check in the rules, its canned reply in `canned_ai.gd` (so offline mode and the tests have one), and a test that the canned reply passes the check.
- **A new switch for tests:** `scripts/test_hooks.gd`, with its test value in `for_tests()` and its default in `restore()`.

## Definition of done

A change isn't finished until it has all of these:

- **Tests:** new behaviour has tests (rules in `tests/test_rules.gd` or their own file, scenes in the click-through tests), anything a test depends on is pinned with a hook rather than left to the seed, and the whole suite passes.
- **Stats:** whatever the change adds that happens during a night (an event, a hint, a choice the AI or the game makes, something the player clicks) is counted in `night_stats.gd`: on the debug panel, in the section it belongs to (HIGHLIGHTS for anything rare, then TONIGHT, PEOPLE, TALK, POCHA LIFE, FOOD AND THE MENU, REGULARS, THE STORY, TV CAPTIONS, AI), and in the night's log under the matching group, so real nights show whether it's working.
- **Logged:** whatever it does during a night shows up in the night's transcript (what was said and done, with the time) and its log (`logs/stats/` when playing from the editor, beside `logs/transcripts/`), so a real night can be checked from the files alone, without watching it.
- **Docs:** the DEVLOG (what and why), TESTS.md (the new tests and the count), PLAN.md (what's done, and anything it leaves for later), ARCHITECTURE.md and README.md for new files, CONCEPT.md if the game itself changes, LLM-TUNING.md if it's about how the AI behaves.
- **On screen:** any Korean shown explains itself on hover (Hangul meanings in `rules/hangul.gd`, romanised words in the glossary), and every hover goes through `Text.tip`.
- **Safe to share:** no real people, brands or shows by name, and no private details (names, paths, accounts, session links) in code, docs or commit messages.

