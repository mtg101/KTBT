# KTBT: Architecture

How the code is laid out, so you can find things and know where new things go. (Being tidied up step by step: see **A proper refactor** in [PLAN.md](PLAN.md). This page describes it as it is now.)

## The layers

The game's one big rule is **the game owns the facts, the AI owns the flavour**: the game decides what's true (who's here, what they ordered, the bill, the clock), asks the AI to write the words, and checks every reply against the facts before it's used. The code is layered the same way, from the bottom up:

1. **Rules** (`scripts/rules/`, plus `menu.gd` and `regulars.gd`): pure functions and the tables they use. No scene, no AI, no saving; any dice roll is passed in. They decide things (when people arrive, who may call whom what, how pull fades) and check the AI's replies (`validate_*`). Fast to test: `tests/test_rules.gd`, `tests/test_menu.gd`, `tests/test_regulars.gd`.
2. **Prompts and the AI** (`prompts.gd`, `ai.gd`, `ollama_client.gd`, `canned_ai.gd`, `ai_settings.gd`): what the AI is asked, sending it to Ollama (or offline mode's canned replies), and retrying a reply the rules reject.
3. **Saves and logs** (`save_store.gd`, `night_stats.gd`, `game.gd`): each bar's save file, the night's stats, and the `Game` autoload that holds the open bar.
4. **The bar** (`visit.gd`, with `scenes/visit.tscn`): runs a night, using everything above. Still one big script; splitting it is step 4 of the refactor.
5. **On screen** (`bubble.gd`, `caption.gd`, `caption_reel.gd`, `diary_page.gd`, `diary_book.gd`, `recap_screen.gd`, `loading_screen.gd`, `title.gd`) and **sound** (`ambience.gd`, `music.gd`): pieces the bar and title screen show. All drawn and made in code for now.

Higher layers use lower ones, never the other way round: the rules don't know about scenes, and nothing below the bar knows about it.

## The rules, by area

Each file starts with what it's for. They preload each other as needed (never in a circle):

| File | What's in it |
|---|---|
| `rules/text.gd` | Tidying the AI's text, splitting words, checking a reply has its fields, picking by weight, sorting rejected replies into kinds |
| `rules/people.gd` | Owners and customers (checked), ages and genders, stays and moods for company, founding regulars, the owner's fixed life |
| `rules/names.gd` | Names: Korean order and the usual casing, given names, and Hangul (checked against the romanised name) |
| `rules/looks.gd` | How people look (age range, hair, clothes, colours), and how strangers are known by their looks |
| `rules/bar_look.gd` | Each bar's name and look, from the options the game offers, and the fallbacks |
| `rules/night_rules.gd` | The clock, arrivals, how fast time runs, the days, passers-by, the sky's light and the weather |
| `rules/orders.gd` | Orders and later orders (checked), which food a line mentions, what's served straight away and what's cooked, the bill |
| `rules/talk.gd` | The checks every line of dialogue passes, what conversations turn to, speech bubble pages, made-up Korean, food moments |
| `rules/address.gd` | Who calls whom what (oppa, imo, sajangnim...), and their colours on screen |
| `rules/cat_rules.gd` | The cat: coats, personalities, where it goes, how it's talked about, its name |
| `rules/memories.gd` | What's remembered after a visit, and the things that stick |
| `rules/captions.gd` | Korean TV captions (the game's own, from what happens) and TV reactions (from what's said) |
| `rules/story.gd` | The owner's diary at 3am, and "Previously on..." |

## Tests

See [TESTS.md](TESTS.md). Every test hook is in `scripts/test_hooks.gd` (the game reads them as `Hooks.<name>`, and only tests set them); scene tests share `tests/support/bar_test.gd`.

## Where new things go

- **A new rule or check:** the rules file for its area (or a new one, if it's a new area), with a test in `tests/test_rules.gd`.
- **A new kind of AI request:** its prompt in `prompts.gd`, its check in the rules, its canned reply in `canned_ai.gd` (so offline mode and the tests have one), and a test that the canned reply passes the check.
- **A new switch for tests:** `scripts/test_hooks.gd`, with its test value in `for_tests()` and its default in `restore()`.
