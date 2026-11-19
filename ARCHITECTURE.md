# KTBT: Architecture

How the code is laid out, so you can find things and know where new things go. (The refactor that tidied it up, finished 16 Nov 2026, is in [DEVLOG.md](DEVLOG.md).)

## The layers

The game's one big rule is **the game owns the facts, the AI owns the flavour**: the game decides what's true (who's here, what they ordered, the bill, the clock), asks the AI to write the words, and checks every reply against the facts before it's used. The code is layered the same way, from the bottom up:

1. **Rules** (`scripts/rules/`): pure functions and the tables they use, one file per area, including the menu (`menu.gd`) and regulars (`regulars.gd`). No scene, no AI, no saving; any dice roll is passed in. They decide things (when people arrive, who may call whom what, how pull fades) and check the AI's replies (`validate_*`). Fast to test: `tests/test_rules.gd`, `tests/test_menu.gd`, `tests/test_regulars.gd`.
2. **Prompts and the AI** (`scripts/ai/`: `prompts.gd`, `ai.gd`, `ollama_client.gd`, `canned_ai.gd`, `ai_settings.gd`): what the AI is asked, sending it to Ollama (or offline mode's canned replies), and retrying a reply the rules reject.
3. **Saves** (`scripts/save/`: `save_store.gd`, `save_upgrades.gd`, and `scripts/game.gd`): each bar's save file, older bars brought up to date in one place, and the `Game` autoload that holds the open bar.
4. **The bar** (`scripts/visit.gd`, with `scenes/visit.tscn`, and its parts in `scripts/bar/`): runs a night. `visit.gd` keeps the night's clock and loop, arrivals, what the owner does next, asking the AI for each line, and putting the parts together; each part has one job and tests of its own (the table below).
   - **Tonight** (`bar/night.gd`): what the parts share, in one place (the weather, the stats, the owner's moments waiting for their next line). The scene hands it to each part; `visit.gd`'s own names for these pass through to it.
   - **The night's events** (`bar/night_events.gd`): everything noteworthy is announced once (someone walks on, sits down, pays, a dish is served, a chat starts, the cat moves, a big moment...), as plain data. Listening: the stats count them (`bar/night_stats.gd`: `NightStats.record_event`), the TV captions pick theirs (`Captions.for_event`), and tonight's list of them becomes the diary's facts (`Story.diary_facts`) and goes in the night's log. Something new that wants to know what happened is another listener, not more lines through the bar.
   - **Waiting:** the bar's waits (on the AI, a pause, the reader) belong to it (`_frame_done`, `_pause`, `_timer`), and anything that waited checks `_closed()` before carrying on.
5. **On screen** (`scripts/ui/`: the look in `ktv_style.gd`, the K-TV palette, outlined labels, pills and title-card text, which everything on screen builds from; then bubbles, captions, the diary, the recap, the loading screen, the menu board, dishes and the skyline; and `scripts/title.gd`) and **sound** (`scripts/sound/`: `ambience.gd`, `music.gd`): pieces the bar and title screen show. All drawn and made in code for now.
6. **Autoplay** (`scripts/autoplay.gd`, started by a VS Code task, `tools/autoplay.bat`, or from the phone through `tools/autoplay_mcp.ps1`): a batch of nights that play themselves with the real AI, for testing while nobody's watching. `game.gd` reads it from the command line (`-- --autoplay=10`, `--autoplay-bar=<id>`), the title screen opens its bar, and `visit.gd`'s `_autoplay_next`, once a night's logged, opens the saved bar again for the next (so each night has its "Previously on…", as coming back the next day does), then quits after the last. Batches run with `--audio-driver Dummy`: no sound, and none of Windows' audio errors. Its summary file counts each night, the AI's rejections and give-ups, and any errors Godot reports (it's a `Logger`). While a batch runs, `logs/autoplay/running.json` holds its process id and how far it's got (written at the start and after each night, removed at the end), which is how the phone helper tells it's running, and stops it.

Higher layers use lower ones, never the other way round: the rules don't know about scenes, and nothing below the bar knows about it.

## The files, by job

Each file starts with what it's for (paths from `scripts/`). They preload each other as needed (never in a circle):

| File | What's in it |
|---|---|
| `rules/text.gd` | Tidying the AI's text, splitting words, finding whole phrases (what every "doesn't say X" check uses), checking a reply has its fields, picking by weight, sorting rejected replies into kinds |
| `rules/people.gd` | Owners and customers (checked), ages and genders, pronouns, stays and moods for company, founding regulars, the owner's fixed life |
| `rules/names.gd` | Names: Korean order and the usual casing, given names, and Hangul (checked against the romanised name) |
| `rules/looks.gd` | How people look (age range, hair, clothes, colours), how strangers are known by their looks, and the street: rain gear, who walks together, phones |
| `rules/bar_look.gd` | Each bar's name and look, from the options the game offers, and the fallbacks |
| `rules/night_rules.gd` | The clock, arrivals, how fast time runs, the days, passers-by, the sky's light and the weather |
| `rules/orders.gd` | Orders and later orders (checked; a side the line asks for is added), which food a line mentions, what's served straight away and what's cooked, tonight's specials, the bill |
| `rules/talk.gd` | The checks every line of dialogue passes (teasing that crosses the line among them), what conversations turn to (and the night's shape: lighter before midnight), speech bubble pages, made-up Korean, and the situations a line is given now and then (food moments, table customs, sharing, how someone orders, cravings, how the owner opens) |
| `rules/address.gd` | Who calls whom what (oppa, imo, sajangnim...), and their colours on screen |
| `rules/glossary.gd` | Korean words explained on hover (the menu, pocha words, terms of address), any Hangul too (names as they're known), and counting which are said |
| `rules/hangul.gd` | What the game's own Hangul means (captions, reactions, stamps, days, titles, signs), romanised, for its hovers |
| `rules/cat_rules.gd` | The cat: coats, personalities, where it goes, how it's talked about (and the moments for talking to it), and its nickname (a stray's, from the list Koreans give street cats, to suit its coat) |
| `rules/memories.gd` | What's remembered after a visit, and the things that stick |
| `rules/captions.gd` | Korean TV captions (the game's own, from what happens) and TV reactions (from what's said) |
| `rules/story.gd` | The owner's diary at 3am, "Previously on...", an episode's titles and the PD's cut (the scenes and cliffhangers they can choose, checking what they write, the cut applied to the recap), and the owner's reason for closing early |
| `rules/ratings.gd` | The show's TV ratings (시청률) at 3am: the score from tonight's events (big moments, moods as aired, the cliffhanger, regulars, the PD's cards, happenings, luck), its bands and banners, its hover, and how the last few nights' ratings nudge how often customers arrive |
| `rules/seasons.gd` | The calendar (each bar's nights through the year), Korea's seasons and the monsoon, and tonight's weather following on from last night's |
| `rules/skyline.gd` | The city behind the tent: each bar's skyline (mostly APT blocks; towers, churches, shop buildings with a sign on every floor, a district office, a block going up, and gaps), the mountains behind with their hillside houses and rooftop rooms, its windows going dark through the night and its shops' signs as they shut |
| `rules/catalogue.gd` | Every dish and drink a pocha might serve, by layer (always, the classics, the bar's own), and a bar's menu: the house rules the AI's choice is checked against, and the game's own menu when it can't choose |
| `rules/signatures.gd` | A bar's signature dishes: the AI's (named in romanised Korean and Hangul, with what the name means, from the owner's story) checked, the game's price and cooking time set, and the game's own when the AI can't |
| `rules/specials.gd` | Tonight's specials and what's sold out, from the bar's own menu: by the weather and the season, never a staple or last night's again, now and then the owner's own dish |
| `rules/plants.gd` | The PD's pack of plant cards: what each one is (as data: a situation, who it's for, any fact it makes true, and for a write-in, what the PD types; so more can be added), the show's made-up sponsors, checking what the PD writes, dealing tonight's hand (what can happen tonight, not last night's), when one can be played, and what it gives whoever it happens to |
| `rules/menu_changes.gd` | Menus that change slowly: when a dish hardly anyone orders comes off (never a classic, a staple, the owner's own or a regular's usual), and the seasonal dishes offered in its place |
| `rules/dish_art.gd` | How a dish or drink looks on the table, from its menu item's description (vessel, fill, bits, garnish) |
| `rules/menu.gd` | Tonight's menu (the open bar's, or the classic one), prices, resolving what the AI wrote to a menu id, the board's order, what's sold out |
| `rules/regulars.gd` | Regulars: who comes back, how often, how they fade (and a simulation to tune it) |
| `bar/night_events.gd` | The night's events, announced once each, for the stats, captions and diary |
| `bar/night_stats.gd` | Tonight's debug stats: counted as the night goes, the panel's sections and the night's log |
| `save/save_store.gd` | Each bar's save file: read, written and deleted safely; the history, night log and diary (latest 200) |
| `ai/` | The AI: `prompts.gd` (every prompt), `ai.gd` (asking, checking, retrying), `ollama_client.gd`, `canned_ai.gd` (offline mode), `ai_settings.gd` |
| `ui/` | On screen: `ktv_style.gd` (the look), `art.gd` (images from `art/manifest.json`, where there are any, drawn in pixels; anything without one drawn in code), `bubble.gd`, `caption.gd`, `caption_reel.gd`, `diary_page.gd`, `diary_book.gd`, `recap_screen.gd`, `loading_screen.gd`, `menu_board.gd`, `dish_view.gd`, `skyline_view.gd`, `edit_suite.gd` (the PD cutting last night's episode: its title, scenes and cliffhanger) |
| `sound/` | `ambience.gd` (the tent's sounds) and `music.gd` (Arirang), made in code |
| `bar/street_art.gd` | The street behind the tent in pixel art: the night sky and each bar's own street (a piece for each slot, picked by the bar's id from those there's art for) from `art/` on a grid of its own (624×154, each pixel 3 on screen), behind the stage and reaching above it; without street art, just the sky |
| `bar/tent_view.gd` | The tent's look: the tarp, the sign, the bar's touches, the sky and light by the hour, the bulbs and tonight's weather (the first part split out of `visit.gd`) |
| `ui/pixel_shape.gd` | A shape the game makes as it goes (an umbrella's canopy, snow on it) drawn in pixels of the grid's size, on its colour's ramp with a dark edge, as a Sprite2D to turn and fade |
| `ui/pixel_font.gd` | The words on the stage in the pixel Korean font (Galmuri, `fonts/galmuri`): each piece of text (the sign, the neon, the CLOSED board, name tags, speech bubbles) at a whole multiple of its size's own pixel height, never smoothed, the ordinary font behind it for a symbol it hasn't got; without the font files, the ordinary font |
| `ui/pixel_light.gd` | The light by the hour on the pixels: a shader on every piece of pixel art (the street's, the tent's, the people's and the cat's: one material for each kind) moving each pixel whole steps along its colour's light ramp (darker bluer, lighter warmer), dithered on the grid; the light where it is, in steps, is the night's own (by the hour and the weather) plus each bulb's that's on (`tent_view.gd` sets them each frame; the street hardly feels them); what glows by itself keeps its light |
| `ui/pixel_cat.gd` | The cat in pixel art (`art/cats`, drawn by `tools/art/cat.py`): asleep or sitting up when it's still (as `cat.gd` says, by where it is), walking whenever it moves (a frame of its stride every so far), mirrored to face left, on the grid's lines, lit by the hour with the cat |
| `ui/pixel_person.gd` | A person in pixel art, one way round: kept on the grid's lines as they move, breathing (their head and shoulders rise a pixel now and then, the rest staying put), walking from the side whenever they're moving, mirrored going left (`people_art.gd` `side_frames`; gliding facing us with a bob without them), and posing for a big moment's mood (a laugh, a slump, a jolt, a nod, a fidget) |
| `ui/people_art.gd` | People in pixel art: a person's picture, facing us or from behind, stacked from the layers in `art/people` (drawn by `tools/art/people.py`) and painted onto their own skin, hair and clothes colours' ramps (and the fixed ones: a white shirt, the apron...); null without the layers, and `people_view.gd` draws the shapes |
| `bar/people_view.gd` | Drawing people: a person dressed in their look, facing us or seated from behind, a phone, an umbrella (with the snow or rain on it) or a bag over their head, running for it (part 2 split out of `visit.gd`) |
| `bar/street.gd` | The street in front of the tent: strollers, passers-by who look in and walk on, and rain gear for anyone out in the weather (part 3 split out of `visit.gd`) |
| `bar/cat.gd` | The tent's cat: who it is, where it is and who with, drawing it (in pixel art: `ui/pixel_cat.gd`) and moving it there (prowling, winding round ankles), and what the AI's told and checked against (part 4 split out of `visit.gd`) |
| `bar/kitchen.gd` | The stove: the queue of dishes cooking and waiting, those ready to carry over, the stove's row, and how a dish or the free banchan looks on the table (part 5 split out of `visit.gd`) |
| `bar/captions_on_screen.gd` | TV captions on screen: pacing them, popping one up (with its sting and a line in the transcript), the reaction's timing, and the red light (part 6 split out of `visit.gd`) |
| `bar/story_keeper.gd` | The night as a story, kept: tonight's transcript file (the opening, the night, how it ended and the stats) and what "Previously on…" is written from (part 7 split out of `visit.gd`) |
| `bar/regulars_tonight.gd` | The bar's regulars tonight: who's coming in, their facts for the prompts, how they're announced, drifting away at the night's end, what the owner remembers (part 8 split out of `visit.gd`; the rules are in `regulars.gd`) |
| `bar/counter_chats.gd` | Customers chatting at the counter: the chats going on, who can chat or join in, choosing the next spell (part 9 split out of `visit.gd`) |
| `bar/friendliness.gd` | Who calls whom: how the owner and customers address each other, two regulars' record of each other, and the "can I call you eonni?" moment (part 10, first half, split out of `visit.gd`) |
| `bar/conversation.gd` | What each line is given: the situations and moments for the owner's conversations and the customers' chats, how strangers know each other, who spoke last (part 10, second half, split out of `visit.gd`) |
| `bar/scenery.gd` | The tent's fixtures: the drinks fridge, the odeng pot, the karaoke neon across the street, steam off a hot dish (part 11 split out of `visit.gd`) |
| `bar/stats_panel.gd` | The side panel's contents: who's here now (the first tab, written by the tent), then a tab per section of the debug stats, one at a time (part 11) |
| `bar/camera.gd` | The PD's camera: who the show's following (the player clicks a customer or the cat), and the airtime that gets them (for the cat, whoever it's with): the owner sees to them sooner, the counter's chats lean their way, they notice the camera once, and a followed cat wanders sooner |
| `bar/pd_desk.gd` | The PD's desk: the lines pinned for the episode (three a night), tonight's hand of plant cards (dealt from their own dice, aimed at whoever the camera's on), the box a write-in is typed in, the edit (a big moment's spins for five seconds), and the camera's "● REC" corner and viewfinder. The tent decides what a played card does to the night (`visit.gd`'s `_card_happens`) and airs the spin picked (part 12 split out of `visit.gd`) |
| `bar/autopilot.gd` | The autopilot PD, in an autoplay batch only: decides, from its own dice, when to play each of tonight's cards (spread over 7pm to 1am, a write-in with words from a small list, checked like a player's), when to move the camera, which lines to pin, which spin to air, and whether and how to step in and cut the episode. `visit.gd` does what it decides through the player's own calls, and marks it in the transcript ("(Autopilot PD …)") and the stats (`pd.autopilot`). |
| `save/save_upgrades.gd` | Bars saved by older versions, brought up to date in one place: what the game fills in itself, and what still needs the AI, once (refactor step 6) |
| `bar/night.gd` | Tonight: what the tent's parts share, in one place (its weather, its stats, and the owner's moments waiting for their next line; it grows as parts move out) |
| `bar/layout.gd` | Where things are on the tent's stage, shared by the scene and its parts |
| `pipeline_test.gd` | A quick check that Godot, Ollama and the model are talking (its own scene; not part of the game) |
| `bar/draw.gd` | Small drawing helpers the tent's parts share (plain shapes, clearing a layer, how long an animation takes, sped up in tests) |

## Tests

See [TESTS.md](TESTS.md). Every test hook is in `scripts/test_hooks.gd` (the game reads them as `Hooks.<name>`, and only tests set them); scene tests share `tests/support/bar_test.gd`, and `tests/support/fake_ollama.gd` stands in for Ollama to test `ai.gd`.

## Where new things go

- **A new part of the bar:** a file in `scripts/bar/` with one job, given the `Night` (and whatever else it needs) by `visit.gd`, with a test file of its own that runs without a night.
- **A new rule or check:** the rules file for its area (or a new one, if it's a new area), with a test in `tests/test_rules.gd`.
- **A new kind of AI request:** its prompt in `prompts.gd`, its check in the rules, its canned reply in `canned_ai.gd` (so offline mode and the tests have one), and a test that the canned reply passes the check.
- **A new switch for tests:** `scripts/test_hooks.gd`, with its test value in `for_tests()` and its default in `restore()`.

## Definition of done

A change isn't finished until it has all of these:

- **Tests:** new behaviour has tests (rules in `tests/test_rules.gd` or their own file, scenes in the click-through tests), anything a test depends on is pinned with a hook rather than left to the seed, and the whole suite passes.
- **Stats:** whatever the change adds that happens during a night (an event, a hint, a choice the AI or the game makes, something the player clicks) is counted in `night_stats.gd`: on the debug panel, in the section it belongs to (HIGHLIGHTS for anything rare, then TONIGHT, PEOPLE, TALK, POCHA LIFE, FOOD AND THE MENU, REGULARS, THE STORY, TV CAPTIONS, AI), and in the night's log under the matching group, so real nights show whether it's working.
- **Logged:** whatever it does during a night shows up in the night's transcript (what was said and done, with the time) and its log (`logs/stats/` when playing from the editor, beside `logs/transcripts/`), so a real night can be checked from the files alone, without watching it.
- **Docs (checked by `test_code.gd`), every time:** the DEVLOG (what was done and why, with the new test count); PLAN.md (only ever what's left: anything built, even part of an item, comes out of it, and anything the change leaves for later goes in); TESTS.md (the new tests and the count); ARCHITECTURE.md and README.md for new files; CONCEPT.md for how the game works, if that changes; LLM-TUNING.md if it's about how the AI behaves.
- **On screen:** any Korean shown explains itself on hover (Hangul meanings in `rules/hangul.gd`, romanised words in the glossary), and every hover goes through `Text.tip`.
- **Safe to share:** no real people, brands or shows by name, and no private details (names, paths, accounts, session links) in code, docs or commit messages.

