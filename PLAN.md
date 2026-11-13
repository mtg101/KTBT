# KTBT: Plan

How we're building [KTBT](CONCEPT.md): small stages, each ending with something you can run and watch. Ideas we're not committed to yet are parked in **Later ideas**, and AI quirks we've noticed are in **Tuning notes**.

Every list item follows the same pattern: a **bold label**, a colon, then the details.

## Build stages

Each stage ends with something you can run and watch. ✅ marks a finished stage. Stage 2.5 was slotted in after stage 2, so the later numbers stay as they were.

- ✅ **1. Pipeline test:** press a button, and Ollama invents a customer whose profile appears on screen. *Done 12 Nov 2026.*
- ✅ **2. One visit:** a customer arrives, orders from the menu, is served automatically, chats with the owner, pays and leaves. Grey-box art. *Done 12 Nov 2026. The AI-invented owner was pulled forward from stage 3 so customers have someone to talk to, but it isn't saved yet.*
- **2.5. Tests:** automated testing with GdUnit4, so the game's rules can't silently break as it grows. See [TESTS.md](TESTS.md) for the approach.
  - **Docs first:** `TESTS.md`, plus a GdUnit4 section and checklist item in `TOOLCHAIN.md`.
  - **Install GdUnit4:** the release that supports our Godot version (see `TOOLCHAIN.md`).
  - **Make the code testable:** move the validators and other game rules out of `visit.gd` into `scripts/rules.gd`; give key UI nodes fixed names (`NextButton`, `Transcript`, `TakingsLabel`, `Customer`…); let a fake AI be plugged in; allow a fixed random seed and near-zero pauses.
  - **Rule tests:** menu lookup and prices, the bill, ages, owner titles and gendered terms, order/line matching, dialogue tidying. Includes a test for each fixed tuning issue so it can't creep back.
  - **Click-through visit tests:** run the visit scene with the fake AI, click **Next customer**, and check the whole visit plays out, including when the AI keeps failing or Ollama isn't running.
- **3. Bars and saves:** title screen (New / Load), AI-invented bar name, owner kept per bar, autosave as it goes, close any time and resume on load. Comes with save/load round-trip tests.
- **4. A full night:** a clock from opening to closing, with customers arriving at times that suit the hour.
- **5. Several at once:** multiple seats and overlapping customers.
- **6. Regulars and relationships:** returning customers who remember past visits. Every conversation gets *relationship context* from the game: whether this is a first visit or a return, what the owner and customer actually know about each other (names, past conversations, "the usual"), and how often they've met. The AI only uses what the game says they know.
- **7. Art, sound and polish:** real assets, rain ambience, UI styling. Add visual (screenshot) tests once the art settles.
- **8. The game:** the player joins the conversations, probably as the owner.

## Later ideas (not committed)

- **Customer-to-customer chat:** customers at nearby seats talking to each other across tables.
- **Player controls:** speed up time, set the menu, choose the weather or day.
- **Economy:** money, menu upgrades, reputation.
- **Long-term relationships:** the owner and regulars getting closer over many nights.
- **Speech bubbles:** pop-up bubbles above whoever's speaking, alongside the transcript, which stays as the full record.
- **Korean terms with English hover text:** let the dialogue use common Korean words naturally (foods, honorifics and titles like *imo*, *ajusshi*, *sunbae*, phrases like *geonbae!*), with a hover-over English explanation. Likely approach: the game keeps a glossary and marks known terms in the text as hoverable, rather than trusting the AI to explain them.
- **3D graphics option:** a 3D version of the tent (e.g. low-poly CC0 models from Quaternius or Kenney) as an alternative to the 2D view. Keep the simulation logic separate from the visuals so either view can sit on top of it. Mind GPU memory: the local LLM shares the graphics card.
- **Non-Korean visitors:** tourists and expats, who would naturally use Western name order (see the name-order note below).

## Tuning notes

- **Name order (open):** the AI sometimes writes names Western-style (e.g. "Ji-hoon Kim" instead of "Kim Ji-hoon"), despite being asked for family name first. Minor. Fix later with a prompt example, or by having the AI give family and given names as separate fields that the game joins in the right order.
- **Double opening and mismatched orders (fixed 12 Nov 2026):** customers said an opening line, then ordered again, and what they said didn't match what was served (e.g. "one soju, please", then "one of everything", then served tteokbokki, beer and gyeran-mari). Cause: the opening line was written when the customer was invented, before the AI had seen the menu. A prompt tweak didn't fix it. Fixed by restructuring: in a visit, the customer's first words come from the order step, as one line (greeting plus order), and the game rejects a line that mentions any menu item not in the order.
- **Owner titles (fixed 12 Nov 2026):** the AI gave owners titles that didn't fit: a man's title on a woman ("Kim Sun-young (Ajeossi)", a "gruff-but-soft ajumma"), then relationship terms like *oppa* and *hyungnim*, which only work when a particular kind of person is speaking. Fixed in two steps. The game picks the owner's gender and sets their title itself: a woman is always **Ajumma** and a man always **Ajusshi** (`OWNER_ADDRESS` in `scripts/prompts.gd`). Customers may use that or a safe alternative (Imo, Sajangnim, Eomeoni / Samchon, Sajangnim), but never oppa, hyung, nuna or eonni. The game also rejects an owner whose archetype uses a term for the other gender (`GENDERED_TERMS` in `scripts/visit.gd`). Owners are now 40 or older, to suit the titles.
- **Strangers acting like regulars (interim fix 12 Nov 2026, full fix in stage 6):** first-time customers talk as if they're known: the owner uses a name they were never told, or a customer sits down and asks for "the usual" or calls themselves a regular. Cause: the prompts never say who knows whom. The real fix belongs in stage 6, where the game tracks relationships and passes them into every conversation. Interim fix: `describe_relationship()` in `scripts/prompts.gd` tells the order and conversation prompts that it's a first visit, the owner doesn't know their name unless they say it, and nobody asks for "the usual". Stage 6 replaces that function's text with what the game has actually tracked.
