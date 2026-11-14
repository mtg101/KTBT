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
- **Click-through tests (functional and UI):** load a real scene with the fake AI plugged in, click buttons with simulated mouse input (so a disabled or covered button makes the test fail), wait for signals, then check the result. Example: click **Next customer** and check the order line and conversation reach the transcript, the takings rise by exactly the bill, the customer leaves and the counter clears. Also covers failures: the AI keeps giving bad replies (the soju fallback), or Ollama isn't running. *From the Tests stage.*
- **Save/load tests:** save a bar, load it back, and check nothing was lost or changed, including a save made mid-conversation. *From the Bars and saves stage.*
- **Visual tests:** screenshot a scene and compare it with an approved image, to catch broken layouts and clipped text. These need a real display rather than headless mode. *From the Art, sound and polish stage, once the art settles.*
- **AI quality runs (not pass/fail):** generate a batch of real customers or visits with the actual model and count problems: rejection and retry rates, backwards names, wrong titles, mismatched orders. Useful for tuning prompts and for comparing models (Llama, Gemma, Qwen). *Whenever we tune prompts or try a new model.*

## How the click-through tests work

- **Real scene, real clicks:** each test loads `scenes/visit.tscn` with GdUnit4's scene runner and clicks buttons by moving the simulated mouse over them and pressing, so a disabled or covered button fails the test.
- **Offline AI:** tests set `AiSettings.override = {"backend": "canned"}`, so no Ollama is needed. `CannedAi.scripted` queues exact replies (including bad ones) that are used before the normal canned ones.
- **Test hooks** (static variables, reset after every test): `Visit.pause_scale_override` (0.01 makes a visit take a blink), `Visit.random_seed` (same customers and orders every run) and `Ai.simulate_unreachable` (behave as if Ollama can't be reached, instantly).
- **Waiting:** tests wait a frame at a time until the scene isn't busy, with a time limit, rather than sleeping for fixed times.

## Conventions

- **Location:** tests live in `tests/`, mirroring `scripts/` (e.g. `tests/test_menu.gd` tests `scripts/menu.gd`).
- **Naming:** test files start with `test_`; test functions describe the behaviour, e.g. `test_order_mentioning_unordered_item_is_rejected()`.
- **Rules live in `scripts/rules.gd`:** game rules and validators stay out of scene scripts, so tests can call them without loading a scene.
- **Fake AI:** scenes take the AI through one object (`ai.gd`), and tests swap in a fake that returns scripted replies, including deliberately bad ones. The game's **canned AI** (offline mode, for machines without a suitable GPU) is built on the same fake, so tests and offline play share one implementation.
- **Fixed randomness:** tests set a fixed random seed, so the moment, entry side and visit length are the same every run and failures can be reproduced.
- **No waiting around:** tests set pauses to near zero, so a whole visit runs in a second or two.
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
- **Later orders that ask for more than they get:** "another tteokbokki" without tteokbokki in the order is rejected, "this/the tteokbokki" is fine, aliases like "rice" are caught in order lines (and "fried rice" isn't also read as "rice"), and conversation can still mention rice. `test_rules.gd`.

## Coverage so far

All 134 tests pass (13 November 2026, GdUnit4 v6.2.0 on Godot 4.7.2).

| Area | Test file | Rule tests | Click-through tests |
|---|---|---|---|
| Menu and prices (`menu.gd`) | `tests/test_menu.gd` | ✅ 16: lookup by id, name or alias, won formatting, every item complete, mains and sides, unique ids | — |
| Rules and validators (`rules.gd`): customers, owners, orders, later orders, dialogue lines, bills, order odds and timing | `tests/test_rules.gd` | ✅ 77 | — |
| Prompts include the right facts (`prompts.gd`) | `tests/test_prompts.gd` | ✅ 19 | — |
| One visit (`visit.tscn`) | `tests/test_visit.gd` | — | ✅ 10: the owner arrives; offline badge; a full visit by clicking (transcript, exact takings, customer leaves, counter clears, button re-enabled); button disabled during a visit; takings over four visits (covers later orders); a bad owner reply retried; Try again after the owner fails; soju-and-odeng fallback; Ollama unreachable in `auto` (goes offline); `ollama` backend never falls back |
| Offline mode (`canned_ai.gd`) and AI settings (`ai_settings.gd`) | `tests/test_canned_ai.gd` | ✅ 12: every canned owner, customer, order, later order and line passes the game's rules; no canned line mentions menu food; replies are copies; scripted replies; settings override and fallback | Covered by `test_visit.gd`, which runs on the canned AI |
| Saving and loading | — | — | — (Bars and saves stage) |

*Updated as tests are added.*
