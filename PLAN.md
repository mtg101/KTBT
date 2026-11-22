# KTBT: Plan

What's left to build for [KTBT](CONCEPT.md). Only what's left goes here: when something's built, it moves to [DEVLOG.md](DEVLOG.md) (and how it works, to CONCEPT.md), and a part-built item keeps only what's still to do. AI quirks are in [LLM-TUNING.md](LLM-TUNING.md).

## Next stages

- not sure yet...
  - are events being picked up in talks?
  - should we go for AI created portraits in the game next as a big thing?
  - yeah lots of incrementals but feels like we should leave those for now...
    - not point more cards until events get properly reacted to!

## Future ideas and improvements

### Richer play

- **Owner & Regulars have generated portraits:**
  - regulars get their own AI-generated portraits
    - initial regulars while the bar is being created
    - new regulars at end of night
  - owner also gets generated portrait at bar creation
  - game launched ComfyUI in the background and generates and saves alongside bar save
- **Finishing basics of Seasons and the platform ladder:** 
  - **The niece or nephew, higher up:** they film the phone stream (in the prompts as who's behind the camera); when the show moves up they go with it, a junior PD at the channel, then the show's PD on TV, and the prompts should say so (on the channel and TV, it's "the channel's camera" and "the show's camera crew" for now).
  - **The channels' history, told:** the side panel's The show lists every channel the show's been on; the diary, "Previously on…" and the title screen could tell it too ("three seasons on 달빛TV"), and a renewal said by name at a season's start ("Moonlight TV's renewed the show for season 3").
  - **Small touches of flavour:** the channel on the loading screen and "Previously on…"'s card.
  - **The season on TV:** the new season's premiere opening with "Previously on…" over the whole last season (the AI's, from the season page's rows), and the seasons in the diary book (each season's page between its episodes).
- **Finishing basic of Customers coming in together:**
  - **Threes and fours:** three nurses off a night shift, a team after a hoesik; waiting for three stools or squeezing in; a three-way bill fight.
  - **Greeted and ordering together, sometimes:** the owner greets a pair with one welcome ("two of you tonight?"), and one orders for both ("two somaek and the pajeon to share", one line, both served), the game deciding when; the sharing moments (pouring for each other, ssam) made for them.
  - **The story:** who came in with whom in the diary and "Previously on…".
  - **Speaking for the right person:** in a three- or four-way chat, small models are likelier to write someone else's line, or a whole exchange: the checks that strip "Name:" and cut off second lines should know every name in the chat.
- **More PD cards:** 
  - more tropey cards
    - chaebols in disguise, people transported from the Joseon period, extreme weather events, etc
  - more write-in card types
    - big news events, 'did you hear?', themed prompts (kpop, kdrama, food, etc), other ideas...? (better ideas!")
    - and 2 per night for write-ins
- **Narrative:**
  - **Drama incidents and story arcs:** K-drama beats: a confession at the counter, a drunk sent home in a taxi, a breakup at the next table, the owner's secret slowly coming out, redevelopers threatening to tear the tent down. A light **drama director** picks a beat for the night (a game fact) and the AI writes it. Over many nights, **long-term relationships**: a regular moving away, a romance at the counter, an old friend falling out with the owner.
  - **Cliffhangers the night can answer, more often:** the first recaps ended on questions no night can answer ("other"). Watch HIGHLIGHTS and THE STORY; if it persists, steer the recap prompt to the kinds on the list.
  - **Cliffhangers about what's said (a stage of its own):** "will she finally confess?", "will he quit?", "is the secret out?": the AI judges after a conversation whether it was answered (like the TV reaction check), with a check and tests for each kind.
  - **Drinking too much (with a content setting first):** past three or four bottles, someone dozes face-down on the counter (the owner drapes something over them), someone heartbroken makes the 2am call to an ex (술김에?! on TV), and one of a pair piggybacks the other home. Drunkenness played for drama, so alongside 
  - **Calendar, holidays and events:** Korean occasions from the date (`rules/seasons.gd`: Seollal, Chuseok, Christmas, 11/11...) as game facts shaping who turns up, what they order and what they talk about; and any occasion a line mentions checked against tonight's date (19 Nov: Chuseok came up in November).
  - **Types of people:** 
    - **Where people are from:** a home town as a game fact (Seoul, Busan, Daegu, Jeju, a village in Jeolla…) shaping how they talk: Busan's blunt, warm Gyeongsang satoori as flavour in fluent English (the odd "mwo-kko?", a gruffer rhythm), not broken English. Ties into the things that stick.
    - **Non-Korean visitors:** tourists and expats, naturally using Western name order (see LLM-TUNING.md).
  - **Weather that changes:** one weather at 6pm today; it could change during the night (rain setting in after midnight), the sound and visuals fading across.
  - **More of being on a show:** now and then a fly-on-the-wall trope beyond noticing the camera: someone hiding their face, someone playing up to it, a regular asking if they'll be in this week's episode, an "off the record" confession that isn't. Not every night: it's still mostly a tent bar.
  - **My fave tropes:** I'm creating a tropey Korean game... I know some tropes I want to hear!
    - repeating words: chijeu chijeu, gogi gogi gogi, etc
    - ye jeon-ha / ma-ma (sarcasm in a tent bar :)
    - myers briggs (and other astrology ;) 
    - probably all similar updates so wait until I've got a list not just a few items before asking for it
- **More social media:** after the posts stage: posts popping up live during the show; the triple+ replay for big events; and for thinking about, how a video post of the night would be made.
- **More of the show's setup:** the setup screen (a new bar's, while it's being made) choosing more than the rung: the niece or nephew, the season's length, the content setting, perhaps the owner's kind or the bar's look.
  - good for both sandbox mode and makes testing specific features easier
- **Tuning the seasons/ladder:** going down the ladder nearly never happens. We want it cozy, but we already have it so you can't 'die' in the game. So we should have shows having bad runs and being able to drop down. Can use simulated runs but real testing mean leaving the GPU spinning for hours...
  - also meh - your tent gets popular, that's fine, don't get much dopamine from tuning and I'm just here to learn to vibe...

### Presentation

- **Background animation:** the occasional street cat, more vessels and bits as dishes are added. (Cars on the overpass were tried: lights above the tent looked wrong.)
- **Varying the music:** more public-domain tunes Korean TV uses, arranged in code: folk songs (Doraji taryeong, Milyang and Jindo Arirang, Ganggang-sullae, Saeya saeya) and the classical pieces variety shows love (Flight of the Bumblebee for a rush, a Chopin nocturne at 2am, Vivaldi, the Can-can), chosen by the game from the scene, never over a reaction's sting.
- **More sound reactions:** korean TV is famous for it alongside the TV pops
  - I just need to be in the mood to do sound...
- **Voices:** characters speak their lines, a setting choosing **off**, **babble**, **system voices** or **AI voices**; the game picks each voice from facts it owns (gender, age, mood).
  - **Babble (first):** Animal Crossing-style syllables per word, pitched and paced per character (deeper and slower for an old ajusshi, quicker when nervous), from a few CC0 sounds. No AI, runs anywhere.
  - **System voices:** Godot's built-in text-to-speech with Windows' voices: robotic, but no setup; a quick test of whether speech adds anything, and a fallback.
  - **AI voices:** a local text-to-speech service beside Ollama, on the CPU so it doesn't fight the LLM: **Kokoro** (82M, Apache-2.0, good quality) or **Piper** (fast, GPL-3.0 engine, voices with their own licences). Check first how they say Korean names and words.
- **Opening style:** is it always the same rotating splat?


### Technical

- **`stop_art` should clear the art queue's list:** stopping ComfyUI throws its queue away, but `art\raw\pending.json` still lists those pictures, so `queue_art_batch` refuses ("still being made: collect_art them first (or stop_art and start again)", and stop_art doesn't help) until the file's moved aside by hand. `StopArt` in `tools/autoplay_mcp.ps1` should empty it (`SavePending @()`) when it stops ComfyUI, and say so; the same if ComfyUI isn't answering at all. Mind START-HERE's helper gotchas: it can't be tested here.
- **Optimise: only when noticed:** you'd think 10 local LLM calls with big prompts would take ages... but I'm not noticing delays yet - optimize when we need to!
  - **Watching AI quality over time:** autoplay writes the batch review we do by hand (rejections by kind, give-ups, facts and threads that went wrong, lines misusing what they were told) and compares it with the last batch; a small model reading transcripts could flag what the checks can't see (19 Nov: "that husband… he's a good kid").
  - **Prompt length:** every feature adds context (who you know, facts, threads, notes), and with an 8B model length costs speed and obedience. Measure prompt size and reply time per call in the stats, set a budget, and try a newer or Korean-fluent local model then: a better model may fix more than any single check.
  - **Speed and waiting:** each visit is 10+ AI calls:
    - **Warm the model up at the title screen:** Ollama unloads the model after 30 idle minutes (`keep_alive`), and the first reply then takes up to a minute (the loading screen looks stuck): a tiny request as the title opens.
    - **A second voice:** the owner's AI voice is busy about 98% of the night (first drinks took 11–19 minutes; chats got 8–21% of lines) because one request runs at a time. Customer chats on a second voice, alongside (`OLLAMA_NUM_PARALLEL`), each slower on one GPU:
      1. **Measure first:** a button in the pipeline test (`scenes/pipeline_test.tscn`) timing one request, then two at once, on the desktop and the laptop. Go on only if two take much less than twice as long.
      2. **Then build it:** a second AI object for chats that never wait for the owner, bubbles and transcript coping with two at once, and each voice's share in the stats.
- **Older saves kept up to date:** upgrade by the save's `version` rather than by what's missing (`scripts/save/save_upgrades.gd`), filling in whatever a new feature needs (a bar from before the cat still has none).

### Pretending to release it

- **A first night for someone new:** a guided first episode, the producer explaining one control per beat (the desk, cards, pins, spins, the edit suite).
- **Packaging, first-run setup and releasing:** a big part of the point is learning to ship a Godot game.
  - **Exporting:** export templates, a Windows preset, an icon, the name and version in the build, and a check that it runs on a clean machine (saves and logs in the user folder).
  - **Can we include the local AI models as part of the install?**  or we have to explain it in docs with fallback modes
- **A store page, as if for real:**
  - **The overview:** a one-line pitch ("Coffee Talk with soju: a Korean tent bar where every customer is invented by an AI, and every night is an episode"), short and long descriptions, features as bullets (AI customers with memories, regulars who come back, Korean TV captions, the owner's diary, Hangul names, offline mode), tags.
  - **Screenshots:** five or six moments at full resolution: a full house in the rain, a TV caption mid-pop, a reaction ("충격!"), the 3am diary, the "Previously on…" card, the title screen; perhaps a screenshot mode with the panels hidden.
  - **A promo video:** a 30–60 second K-drama-teaser cut: the tarp going up, customers ducking in, captions popping, a big moment, the diary, the title card; Arirang (or another of our arrangements) under it, and the game's stings.
  - **The rest:** a cover and a banner (from the title and loading art), a GIF or two, system requirements (an NVIDIA GPU with about 10GB, or offline mode), what the AI does and doesn't do (it runs on your machine; nothing's sent anywhere), credits, licences, a press kit.
  - **Being open about the AI:** the page says plainly that a local AI model writes the characters and the game was built with AI help.
