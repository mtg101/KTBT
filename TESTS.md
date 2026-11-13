# KTBT: Testing

How we test KTBT: what's checked automatically, what still needs a human, and the conventions tests follow. Setting up the test framework is covered in [TOOLCHAIN.md](TOOLCHAIN.md#7-testing-gdunit4), and the plan for building the tests is the Tests stage in [PLAN.md](PLAN.md).

## The approach

KTBT's core rule is **the game owns the facts; the AI owns the flavour**. The game decides the time, menu, prices, bills, titles and who knows whom, and it checks everything the AI produces before using it. Those rules are what keep a game full of AI-generated characters coherent, so they're what the tests protect.

- **Automated tests** check the game's rules and flow. They use a **fake AI** with canned replies, so they're fast, run without a GPU or Ollama, and give the same result every time.
- **Playtesting** checks the parts tests can't judge: whether characters feel right, whether dialogue reads well, whether it's fun to watch. For an AI-driven game, a human reading the output is still the main quality check.
- **AI quality runs** sit in between: batches of real AI generations, counted rather than pass/fail.

**Framework:** [GdUnit4](https://github.com/MikeSchulze/gdUnit4). Chosen over GUT for its click-through scene testing, built-in mocks, and VS Code and GitHub integration.

## Test layers

- **Rule tests (unit):** pure functions with no AI and no scene. Examples: `Menu.resolve("Gyeran-mari")` gives `gyeran_mari`; `format_won(12000)` gives `₩12,000`; the bill adds up; an 18-year-old customer is rejected; an order with pizza is rejected; an Ajusshi described as an ajumma is rejected; a line saying "soju" when beer was ordered is rejected; "Name:" prefixes are stripped from dialogue. *From the Tests stage.*
- **Click-through tests (functional and UI):** load a real scene with the fake AI plugged in, click buttons with simulated mouse input (so a disabled or covered button makes the test fail), wait for signals, then check the result. Example: click **Next customer** and check the order line and conversation reach the transcript, the takings rise by exactly the bill, the customer leaves and the counter clears. Also covers failures: the AI keeps giving bad replies (the soju fallback), or Ollama isn't running. *From the Tests stage.*
- **Save/load tests:** save a bar, load it back, and check nothing was lost or changed, including a save made mid-conversation. *From the Bars and saves stage.*
- **Visual tests:** screenshot a scene and compare it with an approved image, to catch broken layouts and clipped text. These need a real display rather than headless mode. *From the Art, sound and polish stage, once the art settles.*
- **AI quality runs (not pass/fail):** generate a batch of real customers or visits with the actual model and count problems: rejection and retry rates, backwards names, wrong titles, mismatched orders. Useful for tuning prompts and for comparing models (Llama, Gemma, Qwen). *Whenever we tune prompts or try a new model.*

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

When we fix a problem, we add a test that would have caught it, so it can't creep back. Fixes from [TUNING.md](TUNING.md) waiting for tests:

- **Owner titles:** an owner's title always matches their gender (Ajumma or Ajusshi), and an archetype using a term for the other gender is rejected.
- **Double opening and mismatched orders:** in a visit, the customer's first line comes from the order step, and a line mentioning an item that wasn't ordered is rejected (except soju and beer with somaek).
- **Strangers acting like regulars:** order and conversation prompts include the first-visit relationship note.

## Coverage so far

| Area | Rule tests | Click-through tests |
|---|---|---|
| Menu and prices (`menu.gd`) | Not yet | — |
| Validators: owner, customer, order, dialogue | Not yet | — |
| Prompts include the right facts (`prompts.gd`) | Not yet | — |
| One visit (`visit.tscn`) | — | Not yet |
| Saving and loading | — | — (Bars and saves stage) |

*Updated as tests are added.*
