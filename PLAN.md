# KTBT: Plan

What we're going to build next for [KTBT](CONCEPT.md). Stages are listed in the order we'll build them, and the first one is up next. Each stage ends with something you can run and watch.

When a stage is finished, it moves out of this file and into [DEVLOG.md](DEVLOG.md). AI quirks and how we handle them are in [LLM-TUNING.md](LLM-TUNING.md).

Every list item follows the same pattern: a **bold label**, a colon, then the details.

## Stages

- **Tests:** automated testing with GdUnit4, so the game's rules can't silently break as it grows. See [TESTS.md](TESTS.md) for the approach.
  - **Make the visit scene testable:** give key UI nodes fixed names (`NextButton`, `Transcript`, `TakingsLabel`, `Customer`…); allow a fixed random seed and near-zero pauses. (The rules are in `scripts/rules.gd` with their own tests, and the fake AI exists: offline mode's canned AI, with scripted replies.)
  - **Click-through visit tests:** run the visit scene with the fake AI, click **Next customer**, and check the whole visit plays out, including when the AI keeps failing or Ollama isn't running.
  - **Fast mode defaults back off:** Fast mode is on by default while we're testing a lot; turn the default off again once testing settles (or move it into the settings screen).
- **Bars and saves:** title screen (New / Load), AI-invented bar name, owner kept per bar, autosave as it goes, close any time and resume on load. Comes with save/load round-trip tests.
- **A full night:** a clock from opening to closing, with customers arriving at times that suit the hour.
- **Several at once:** multiple seats and overlapping customers.
- **Regulars and relationships:** returning customers who remember past visits. Every conversation gets *relationship context* from the game: whether this is a first visit or a return, what the owner and customer actually know about each other (names, past conversations, "the usual"), and how often they've met. The AI only uses what the game says they know.
- **Art, sound and polish:** real assets, ambient sound and background animation (see **Ambience** in the later ideas for the full wish list), UI styling. Add visual (screenshot) tests once the art settles.
- **The game:** the player joins the conversations, probably as the owner.

## Later ideas (not committed)

Grouped by type. Within each group, roughly in order of importance.

### Essentials (needed before anyone else plays it)

- **Content boundaries (a setting):** the AI writes about late-night drinking and K-drama heartbreak, so it will sometimes drift somewhere dark or crude. A **content setting** chooses how far it may go, e.g. **Cosy** (gentle, no swearing), **Drama** (the default: PG-13 heartbreak, mild language) and **Mature** (stronger language and heavier themes, handled with care). The setting goes into the style guide for every prompt, and the game also checks lines against it and rejects ones that cross it, the same way it rejects wrong titles. Some limits apply at every setting: nothing sexual beyond a kiss implied off-screen, no hateful slurs, no real-world politics, and themes like self-harm are never described or encouraged: if they come up, the owner responds with care. Most important once players can type to customers.
- **Speed and waiting:** each visit is 10+ AI calls, so prepare ahead instead of waiting: generate the next line while the current one is being read, and invent the next customer while the current one is still drinking. Probably the biggest single improvement to how the game feels.
- **Settings and accessibility:** one options screen for text size and speed, volumes (sound, music, voices), content setting, AI backend and model, voice mode and full-screen. Plus accessibility options that cost little in a text-heavy game: bigger text, high contrast, and pausing between lines until the player clicks.
- **Packaging and first-run setup:** export a playable Windows build, and on first run check for Ollama and the model, offer offline mode if they're missing, and point to setup help. Without this, nobody but the developer can run it. Later: a release on itch.io.

### Richer play

- **Calendar, holidays and events:** seasons and Korean occasions (Seollal, Chuseok, Christmas, Pepero Day on 11/11, payday Fridays) and one-off events (a big football match on the overpass screens, a typhoon closing the tent early). Game facts that shape who turns up, what they order and what they talk about.
- **Drama incidents and story arcs:** K-drama beats across nights: a confession at the counter, a drunk customer the owner sends home in a taxi, a breakup at the next table, the owner's secret slowly coming out, and the classic: redevelopers threatening to tear the tent down. A light **drama director** in the game picks a beat for the night (a game fact), and the AI writes it.
- **Journal and trope book:** a diary of past nights to reread, and, fitting the name *Korean Tent Bar Tropes*, a **trope book** that fills in as tropes appear ("Chaebol heir in disguise ✓", "Rain-soaked confession ✓"). The game tags tropes as it plans each visit, so collecting them is reliable rather than guessed from the text.
- **Variety controls:** the game tracks recent names, jobs and archetypes and tells the AI to avoid them, so a small model doesn't send three Ji-hoons in a row. If repetition shows up in practice, log it in [LLM-TUNING.md](LLM-TUNING.md).
- **Customer-to-customer chat:** customers at nearby seats talking to each other across tables.
- **Long-term relationships:** the owner and regulars getting closer over many nights.
- **Economy:** money, menu upgrades, reputation.
- **Player controls:** speed up time, set the menu, choose the weather or day.

### Presentation

- **Bar-specific menus:** each bar gets its own menu instead of the current fixed list. The menu stays a game fact (it drives orders, checks, the bill and the art), so the AI chooses and flavours it within limits the game sets. Chosen approach, a hybrid:
  - **Catalogue staples:** the game holds a catalogue of real pojangmacha food and drink (say 60–100 items, each with a description, category and price range). When a bar is created, the AI picks 8–12 that suit the owner and the bar, e.g. fancier dishes for an ex-chef, seafood for a fisherman's widow. Each catalogue item needs one picture, or shares one.
  - **Signature dishes:** the AI also invents one or two signature dishes tied to the owner's story ("Mother's kimchi jjigae, the recipe her son loved"). The game sets each one's category and price range; the AI only names and describes it, and it uses that category's generic art. Gives customers something to talk about, and the owner's secret somewhere to surface.
  - **Alternatives considered:** catalogue only (the most reliable, but no new dishes), or fully AI-generated menus (the most variety, but small models produce odd or non-Korean dishes, prices need policing, and every item would need generic category art).
- **Weather and season specials:** hot odeng on a snowy night, cold noodles in summer. The game decides which items are specials, so the AI only has to mention them.
- **Menus saved and evolving per bar:** each bar keeps its menu in its save (ties into the Bars and saves stage), and it can change slowly over time: new specials, dropped dishes, a signature dish that regulars come back for.
- **Character art:** the game decides what someone looks like, from facts it owns (age, gender, job, mood); the art system draws it, and the AI never draws anyone directly. To make that work, the AI's profiles gain a few **appearance tags** (hair, build, clothing style…) chosen from lists the game allows, so every character is drawable and looks the same on every visit, which matters for regulars. Chosen approach, in two steps:
  - **Silhouettes with props (first):** the grey boxes become stylised silhouettes with different heights, builds and hairstyle outlines, plus one or two props that say who someone is (briefcase and loosened tie, nurse's scrubs, school backpack, taxi driver's cap), with colour carrying mood. Cheap, consistent, and suits a moody night-time tent.
  - **Modular portraits (main approach):** characters assembled from layered parts (face shape, skin tone, hair, eyes, clothes, accessories) like a character creator, with the game mapping each profile to parts (a 58-year-old ajusshi gets greying hair and a cardigan; a 24-year-old office worker gets a blazer). The parts library could come from a free pack (e.g. the CC-BY-SA/GPL "Liberated Pixel Cup" sets, licence-compatible with GPL but heavy on credits, or CC0 packs; most are pixel-art or cartoony rather than K-drama), from a paid or commissioned pack (check the licence suits a GPL project), or from curated AI art (below).
  - **Pre-generated AI art library (a way to fill the parts):** on the desktop, a local image model generates a few hundred portraits or parts in one fixed style, tagged by age, gender, job and so on. A human curates them, and the game ships the keepers and picks the best match. Nothing runs during play, so there's no GPU contention with the LLM and it works on the laptop. Needs effort to keep the style consistent, and a check of the image model's licence.
  - **Live AI portraits (theoretically possible):** a local image model draws each new customer from their profile as they arrive, so everyone is unique. Not planned for now: it competes with the LLM for GPU memory (they'd have to take turns), takes several seconds per image, drifts off-style, can't run on the laptop, and sometimes produces something unusable. Worth revisiting if local image models get faster and more consistent, or if we ever have GPU memory to spare.
- **Ambience (sound and animation):** the tent should feel alive even when nobody's talking. Driven by facts the game owns (weather, time of night, what's cooking, how busy it is), so it always matches what's happening, and it needs no AI.
  - **Ambient sound:** layered loops that fade in and out: rain drumming on the tarp (heavier in a downpour), the hush of snow, traffic rumbling over the overpass that thins out in the small hours, a distant subway, sizzling and bubbling while the owner cooks, glasses clinking, low chatter when it's busy. Optional quiet background music (lo-fi or a soft K-drama-style theme) with its own volume setting. CC0 sources: Freesound (filter by licence) and Kenney's audio packs; log everything in `CREDITS.md`.
  - **Background animation:** the bulb swinging gently, steam rising from pots and bowls, rain or snow falling past the tent's opening, drips off the tarp edge, headlights sweeping across the overpass, a flickering sign, silhouettes of passers-by with umbrellas, and the occasional street cat. Godot handles these cheaply with particles, tweens and simple animations, so they run fine on the laptop.
  - **Weather as a visible fact:** today the weather only appears in the text; ambience makes it something you see and hear, and changes in weather during the night (from the A full night stage) should fade the sound and visuals across smoothly.
- **Voices:** characters "speak" their lines, with a setting to choose **off**, **babble**, **system voices** or **AI voices**. The game picks each character's voice from facts it owns (gender, age, mood), never the AI.
  - **Babble:** Animal Crossing-style babble: a short syllable sound per letter or word, pitched and paced per character (deeper and slower for an old ajusshi, quicker when nervous). No AI, works on any machine, and suits the cosy tone. Built in Godot from a few CC0 syllable sounds, pitch-shifted. The first one to build.
  - **System voices:** Godot's built-in text-to-speech, which reads lines aloud with the voices installed in Windows. No setup and no extra software, and it works on the laptop. The voices sound robotic and the choice depends on what Windows has installed, so it's mainly a quick way to test whether spoken lines add anything, and a fallback when no AI voice service is running.
  - **AI voices:** a local text-to-speech model reads the lines aloud, running as a separate local service like Ollama, with Godot playing the audio. Candidates: **Kokoro** (small 82M model, Apache-2.0 licence, good quality, runs on CPU) and **Piper** (fast on CPU, GPL-3.0 engine, many downloadable voices, each with its own licence to check). Run it on the CPU so it doesn't fight the LLM for GPU memory. Things to check first: how they pronounce Korean names and words, and whether any voices suit the setting.
- **Speech bubbles:** pop-up bubbles above whoever's speaking, alongside the transcript, which stays as the full record.
- **Korean terms with English hover text:** let the dialogue use common Korean words naturally (foods, honorifics and titles like *imo*, *ajusshi*, *sunbae*, phrases like *geonbae!*), with a hover-over English explanation. Likely approach: the game keeps a glossary and marks known terms in the text as hoverable, rather than trusting the AI to explain them.
- **AI-generated food art (much later):** a local image model on the 3080 could draw dishes, including signature ones. It would compete with the LLM for GPU memory and struggles to keep a consistent style, so it's a much-later idea rather than the plan.
- **3D graphics option:** a 3D version of the tent (e.g. low-poly CC0 models from Quaternius or Kenney) as an alternative to the 2D view. Keep the simulation logic separate from the visuals so either view can sit on top of it. Mind GPU memory: the local LLM shares the graphics card.

### Lower priority

- **Other languages:** a Korean-language mode (and maybe others), since the LLM can write them. Voices, the Korean-terms glossary and the gendered-term checks would all need work.
- **Player customisation:** the style guide, archetypes and menu catalogue as editable files, so players can make their own version of the bar.
- **Designing the game stage:** decide what the player actually does when they join the conversation (pick from dialogue choices, or type freely to the AI customers) and what changes as a result (mood, tips, whether they come back, story beats). Worth designing before that stage starts.
- **Non-Korean visitors:** tourists and expats, who would naturally use Western name order (see the name-order note in [LLM-TUNING.md](LLM-TUNING.md)).
