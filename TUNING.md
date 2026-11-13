# KTBT: Tuning notes

Quirks we've noticed in the AI's output, why they happen, and how we handle them. Open issues are waiting for a fix; fixed ones stay here as a record of what works with a small local model, and each should get a test (see [TESTS.md](TESTS.md#bugs-become-tests)).

**Lesson so far:** when a small model keeps doing something odd, changing what it's asked to produce, or having the game decide and check the fact itself, works better than adding more instructions to the prompt.

## Open

- **Name order:** the AI sometimes writes names Western-style (e.g. "Ji-hoon Kim" instead of "Kim Ji-hoon"), despite being asked for family name first. Minor. Fix later with a prompt example, or by having the AI give family and given names as separate fields that the game joins in the right order. Related idea: non-Korean visitors, in [PLAN.md](PLAN.md).
- **Strangers acting like regulars (interim fix 12 Nov 2026):** first-time customers talked as if they were known: the owner used a name they were never told, or a customer sat down and asked for "the usual" or called themselves a regular. Cause: the prompts never said who knows whom. Interim fix: `describe_relationship()` in `scripts/prompts.gd` tells the order and conversation prompts that it's a first visit, the owner doesn't know their name unless they say it, and nobody asks for "the usual". The full fix is in the Regulars and relationships stage, which replaces that function's text with what the game has actually tracked.

## Fixed

- **Double opening and mismatched orders (fixed 12 Nov 2026):** customers said an opening line, then ordered again, and what they said didn't match what was served (e.g. "one soju, please", then "one of everything", then served tteokbokki, beer and gyeran-mari). Cause: the opening line was written when the customer was invented, before the AI had seen the menu. A prompt tweak didn't fix it. Fixed by restructuring: in a visit, the customer's first words come from the order step, as one line (greeting plus order), and the game rejects a line that mentions any menu item not in the order.
- **Owner titles (fixed 12 Nov 2026):** the AI gave owners titles that didn't fit: a man's title on a woman ("Kim Sun-young (Ajeossi)", a "gruff-but-soft ajumma"), then relationship terms like *oppa* and *hyungnim*, which only work when a particular kind of person is speaking. Fixed in two steps. The game picks the owner's gender and sets their title itself: a woman is always **Ajumma** and a man always **Ajusshi** (`OWNER_ADDRESS` in `scripts/prompts.gd`). Customers may use that or a safe alternative (Imo, Sajangnim, Eomeoni / Samchon, Sajangnim), but never oppa, hyung, nuna or eonni. The game also rejects an owner whose archetype uses a term for the other gender (`GENDERED_TERMS` in `scripts/visit.gd`). Owners are now 40 or older, to suit the titles.
