# KTBT: Plan

How we're building [KTBT](CONCEPT.md): small stages, each ending with something you can run and watch. Ideas we're not committed to yet are parked in **Later ideas**, and AI quirks we've noticed are in **Tuning notes**.

Every list item follows the same pattern: a **bold label**, a colon, then the details.

## Build stages

Each stage ends with something you can run and watch. ✅ marks a finished stage.

1. ✅ **Pipeline test:** press a button, and Ollama invents a customer whose profile appears on screen. *Done 12 Nov 2026.*
2. ✅ **One visit:** a customer arrives, orders from the menu, is served automatically, chats with the owner, pays and leaves. Grey-box art. *Done 12 Nov 2026. The AI-invented owner was pulled forward from stage 3 so customers have someone to talk to, but it isn't saved yet.*
3. **Bars and saves:** title screen (New / Load), AI-invented bar name, owner kept per bar, autosave as it goes, close any time and resume on load.
4. **A full night:** a clock from opening to closing, with customers arriving at times that suit the hour.
5. **Several at once:** multiple seats and overlapping customers.
6. **Regulars:** returning customers who remember past visits.
7. **Art, sound and polish:** real assets, rain ambience, UI styling.
8. **The game:** the player joins the conversations, probably as the owner.

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
- **Repeated greeting (fixed 12 Nov 2026):** customers used to say their opening line, then repeat it at greater length when ordering. Fixed by telling the order prompt they've already greeted the owner and asking for one short line. If it creeps back, the firmer fix is to have the owner reply to the greeting ("What'll it be?") before the customer orders.
