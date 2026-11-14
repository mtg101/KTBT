# KTBT: Testing

How we test KTBT: what's checked automatically, what still needs a human, and the conventions tests follow. Setting up the test framework is covered in [TOOLCHAIN.md](TOOLCHAIN.md#7-testing-gdunit4), and the plan for building the tests is the Tests stage in [PLAN.md](PLAN.md).

## The approach

KTBT's core rule is **the game owns the facts; the AI owns the flavour**. The game decides the time, menu, prices, bills, titles and who knows whom, and it checks everything the AI produces before using it. Those rules are what keep a game full of AI-generated characters coherent, so they're what the tests protect.

- **Automated tests** check the game's rules and flow. They use a **fake AI** with canned replies, so they're fast, run without a GPU or Ollama, and give the same result every time.
- **Playtesting** checks the parts tests can't judge: whether characters feel right, whether dialogue reads well, whether it's fun to watch. For an AI-driven game, a human reading the output is still the main quality check.
- **AI quality runs** sit in between: batches of real AI generations, counted rather than pass/fail.

**Framework:** [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (v6.2.0 from the Godot Asset Store; version notes in [TOOLCHAIN.md](TOOLCHAIN.md#pick-the-right-version)). Chosen over GUT for its click-through scene testing, built-in mocks, and VS Code and GitHub integration.

## Test layers

- **Rule tests (unit):** pure functions with no AI and no scene. Examples: `Menu.resolve("Gyeran-mari")` gives `gyeran_mari`; `format_won(12000)` gives `₩12,000`; the bill adds up; an 18-year-old customer is rejected; an order with pizza is rejected; an Ajusshi described as an ajumma is rejected; a line saying "soju" when beer was ordered is rejected; "Name:" prefixes are stripped from dialogue. *From the Tests stage.*
- **Click-through tests (functional and UI):** load a real scene with the fake AI plugged in, click buttons with simulated mouse input (so a disabled or covered button makes the test fail), wait for signals, then check the result. Example: a customer turns up, and the test checks the order line and conversation reach the transcript, the takings rise by exactly the bill, the customer leaves and the counter clears. Also covers failures: the AI keeps giving bad replies (the soju fallback), or Ollama isn't running. *From the Tests stage.*
- **Save/load tests:** save a bar, load it back, and check nothing was lost or changed. *Done (`test_save_store.gd`, `test_bars.gd`); saves made mid-conversation will need tests when resuming mid-visit is built.*
- **Visual tests:** screenshot a scene and compare it with an approved image, to catch broken layouts and clipped text. These need a real display rather than headless mode. *From the Art, sound and polish stage, once the art settles.*
- **AI quality runs (not pass/fail):** generate a batch of real customers or visits with the actual model and count problems: rejection and retry rates, backwards names, wrong titles, mismatched orders. Useful for tuning prompts and for comparing models (Llama, Gemma, Qwen). *Whenever we tune prompts or try a new model.*

## How the click-through tests work

- **Real scene, real clicks:** each test loads a real scene (`scenes/visit.tscn` or `scenes/title.tscn`) with GdUnit4's scene runner and clicks buttons by moving the simulated mouse over them and pressing, so a disabled or covered button fails the test.
- **Offline AI:** tests set `AiSettings.override = {"backend": "canned"}`, so no Ollama is needed. `CannedAi.scripted` queues exact replies (including bad ones) that are used before the normal canned ones.
- **Test hooks** (static variables, reset after every test): `Visit.pause_scale_override` (0.01 makes a visit take a blink), `Visit.random_seed` (same customers and orders every run), `Visit.run_clock` (false holds the night's clock still, so no customers arrive on their own; stays and the stove keep going), `Visit.stay_minutes_override` (e.g. 600 keeps customers seated until the test ends their stay), `Visit.company_override` (everyone chatty, quiet or here to talk), `Visit.chat_chance_override` (1.0 makes customers chat whenever they can, 0.0 never), `Visit.gender_override` (e.g. every customer non-binary), `Visit.cat_wanders` (false keeps the cat still; tests move it with `_move_cat`), `Ai.simulate_unreachable` (behave as if Ollama can't be reached, instantly) and `Ai.canned_think_seconds` (offline mode "thinks" before each reply, to test what happens while the AI is busy).
- **Customers arrive through `_arrive()`:** there's no Next customer button any more, so tests call the scene's `_arrive()`, the same method the game uses when someone turns up (several at once for a crowd, as if they turned up together), so arrivals are counted exactly as in play.
- **Separate stats folders:** like saves, tests point `NightStats.folder` at their own folder, so test nights don't fill the real stats logs.
- **Waiting:** tests wait a frame at a time until the scene isn't busy, with a time limit, rather than sleeping for fixed times.
- **Let layouts settle before clicking:** containers (like the title screen's) position their children over the first frames after a scene loads, so the click helper waits a few frames before aiming. A button also fires on mouse *release*, so after clicking, tests wait for the effect rather than checking straight away.
- **No real scene changes:** switching scenes would replace GdUnit's own test runner, so tests set `Game.change_scenes = false` and check `Game.requested_scene` instead.
- **Separate save folders:** tests point `SaveStore.folder` at their own `user://test_saves…/` folder and empty it before and after each test, so real bars are never touched.

## Conventions

- **Location:** tests live in `tests/`, mirroring `scripts/` (e.g. `tests/test_menu.gd` tests `scripts/menu.gd`).
- **Naming:** test files start with `test_`; test functions describe the behaviour, e.g. `test_order_mentioning_unordered_item_is_rejected()`.
- **Rules live in `scripts/rules.gd`:** game rules and validators stay out of scene scripts, so tests can call them without loading a scene.
- **Fake AI:** scenes take the AI through one object (`ai.gd`), and tests swap in a fake that returns scripted replies, including deliberately bad ones. The game's **canned AI** (offline mode, for machines without a suitable GPU) is built on the same fake, so tests and offline play share one implementation.
- **Fixed randomness:** tests set a fixed random seed, so the moment, entry side and visit length are the same every run and failures can be reproduced.
- **No waiting around:** tests set pauses to near zero, so a whole visit runs in a second or two. The night's clock is scaled the same way, so a whole night (6pm to 3am) runs in a few seconds.
- **Named nodes:** UI nodes that tests interact with have fixed names (`NextButton`, `Transcript`, `TakingsLabel`, `Customer`…), so tests don't break when the layout changes.
- **No real AI in the test suite:** the suite must pass with Ollama switched off. Real-model checks belong in AI quality runs.

## Bugs become tests

When we fix a problem, we add a test that would have caught it, so it can't creep back. These tests have `regression` in their name and point to the matching entry in [LLM-TUNING.md](LLM-TUNING.md). Fixed issues covered so far:

- **Owner titles:** the owner prompt no longer asks the AI for a title, and an archetype using a term for the other gender is rejected (whole words only). `test_rules.gd`, `test_prompts.gd`.
- **Double opening and mismatched orders:** a visit's customer prompt has no opening line, and an order line mentioning an item that wasn't ordered is rejected (except soju and beer with somaek). `test_rules.gd`, `test_prompts.gd`.
- **Strangers acting like regulars:** order and conversation prompts include the first-visit note. `test_prompts.gd`.
- **Not listening to each other (partly fixed):** serving appears in the transcript as a stage direction, and the "what just happened" recap comes after the conversation in every dialogue prompt. `test_prompts.gd`.
- **Talking about food that isn't on the table:** the style guide names no menu items, and a conversation line mentioning food that isn't on the table is rejected. `test_rules.gd`, `test_prompts.gd`.
- **Unrealistic orders:** orders need a drink and a food; two mains or two drinks are rejected unless the customer is hungry or having a rough night; the prompt asks for one drink. `test_rules.gd`, `test_prompts.gd`, `test_menu.gd`.
- **Everyone orders exactly once / later orders too early / sounding like a first order:** later-order limits, fried rice only after a main, the "more" wording check, the odds, and the turn spacing (never the first reply or last line, two later orders spaced apart). `test_rules.gd`, `test_prompts.gd`.
- **The cat as it really is:** stroking it, or talk of it on a lap, is rejected unless it's on the lap of someone in the conversation. `test_rules.gd`, `test_prompts.gd`, `test_visit.gd`.
- **Same names, slow arrivals:** a customer's name and gender come first, in their own quick step; a name that's at the counter (or the owner's) is rejected; the prompt lists names to avoid. `test_rules.gd`, `test_prompts.gd`, `test_canned_ai.gd`, `test_visit.gd`.
- **Later orders that ask for more than they get:** "another tteokbokki" without tteokbokki in the order is rejected, "this/the tteokbokki" is fine, aliases like "rice" are caught in order lines (and "fried rice" isn't also read as "rice"), and conversation can still mention rice. `test_rules.gd`.

## Coverage so far

All 279 tests pass (14 November 2026, GdUnit4 v6.2.0 on Godot 4.7.2).

| Area | Test file | Rule tests | Click-through tests |
|---|---|---|---|
| Menu and prices (`menu.gd`) | `tests/test_menu.gd` | ✅ 18: lookup by id, name or alias, won formatting, every item complete, mains and sides, unique ids, cooking times | — |
| Rules and validators (`rules.gd`): customers, owners, orders, later orders, dialogue lines, bills, order odds and timing, the night's clock | `tests/test_rules.gd` | ✅ 120 (including bar names and the fallback name; the night's clock, arrivals, days of the week and memorable lines; five stools, what's served straight away and the "still cooking" table text; stays and moods for company; quick greetings; strangers' honorifics; customer names and gender in two steps, no same names, non-binary at 1%; how fast time runs; kinds of rejected reply; the cat's spots and personalities, the stroking and lap checks, and cat names) | — |
| Prompts include the right facts (`prompts.gd`) | `tests/test_prompts.gd` | ✅ 32 (including customer chats, strangers talking politely, moods for company, the name step and they/them, and the cat) | — |
| Visits, several at once, and customers talking (`visit.tscn`) | `tests/test_visit.gd` | — | ✅ 32: the owner arrives; offline badge; a full visit (transcript, exact takings, customer leaves, counter clears); several customers seated at once with takings that add up; seven at once fill exactly five stools, no stool shared; someone who waits too long walks past; cooked food waits at the stove and is carried over; the AI hears what's still cooking; the owner moves between customers; takings over four visits (covers later orders); a bad owner reply retried; Try again after the owner fails; soju-and-odeng fallback; Ollama unreachable in `auto` (goes offline); `ollama` backend never falls back; customers say goodbye and leave when their time's up; customers chat to each other; quiet customers keep to themselves; no two at the counter share a name; quick greetings when busy; food carried over while the AI thinks; the stats panel shown and hidden, and counting a visit and customer chats; gender symbols on screen; a non-binary customer; time speeding up when empty and slowing when busy; a new bar gets a cat; the AI names it; a cat on a lap is in that customer's conversation and jumps down when they leave; the cat wanders by itself |
| Offline mode (`canned_ai.gd`) and AI settings (`ai_settings.gd`) | `tests/test_canned_ai.gd` | ✅ 19: canned bar names and cat names pass the rules; every canned owner, customer, order, later order and line passes the game's rules; no canned line mentions menu food; replies are copies; scripted replies; settings override and fallback; canned names avoid ones at the counter; canned chat lines pass the rules; details for any name; non-binary only when the game says | Covered by `test_visit.gd`, which runs on the canned AI |
| Save files (`save_store.gd`) | `tests/test_save_store.gd` | ✅ 19: round trips, whole numbers restored, no leftover `.tmp`, overwriting, crash recovery from `.tmp`, newest-first listing, broken files skipped, visits recorded, history limit, nights recorded and their log limit, deleting a bar | — |
| Title screen, new and saved bars, autosave (`title.tscn`, `game.gd`) | `tests/test_bars.gd` | — | ✅ 14: empty list; saved bars newest first; nights and visits shown; deleting a bar takes two clicks; New bar; opening a saved bar; a new bar named and saved straight away; fallback name; each visit saved; a saved bar reopens with owner and takings; reopening asks the AI nothing; Close the bar saves and returns to the title; it waits for the owner to finish mid-visit; closing the window saves |
| A full night (`visit.tscn`) | `tests/test_night.gd` | — | ✅ 10: Night 1 opens at 6pm; the clock runs by itself; customers arrive without clicking; someone turning up mid-night is served; the night ends at 3am with a summary; the night is saved; the night's stats log is written; Open for another night starts Night 2 on the next day; Close the bar saves and goes to the title; a saved bar carries on from its next night |
| Debug stats (`night_stats.gd`) | `tests/test_night_stats.gd` | ✅ 6: AI calls counted and rejections grouped; averages with nothing yet; the panel's sections; the log saved as JSON; the actual rejection reasons kept; how full the tent was | Covered by `test_visit.gd` and `test_night.gd` |

*Updated as tests are added.*
