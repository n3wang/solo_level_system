# True Solo Leveling mode (gamified / AFK RPG)

The uniqueness of this game, you could say that comes from the combiantion of gaming and cards combined with productivity.

## Vision

After the user has engaged with the app for a while (enough sessions / days / focus time—TBD thresholds), the app **invites** them to try **True Solo Leveling mode**: a super-gamified layer on top of real productivity. Core fantasy: **study and workouts = training**; **characters = party**; **long focus blocks = journeys / campaigns** with **light, mostly cinematic** gameplay (no heavy real-time twitch mechanics at first).

- Combines modern world + fantasy
- You travel to these portals
- And only U level up. How? collecting cards. 
- Start with just you. Might meet assistants that accompany u some are only belonging to that world.

---

### First Visuals Storyline


- An apparison of an invite letter to join the beta True-Leveling mode.
- "I wish the"


---

## Lore wise:

- The idea would be to that you are invited as a hero to defeat and travel around the world. I need help sort to focus.
- Then you go into the place. and fight and actually improve the word by doing something interesting.
- I mean there has to be some emotion and seeying places you explored in afk with all these. 


### Combat mechanics

- Enable programming feature. Cause why not.  Without programming does the following in random order
  - Choose which from the available to hit
- There are positions. where the some can only hit 
  - Select allies randomnly for buffs
  - Select enemies randombnly 
  - Randomnly fill in the positions
  - Select random dice for the players (the idea is that a couple dices are thrown, one per character +1 and then the higher are selected in order of character speed (assigned to them. ))


### Game mechanics

- To play the expenditions, you need to have enough resources andstudies one on the expedition
  - Food: every so often you get food because a characters so during the breaks
  - Research: Done while doing so
- These are accumlated throught during camapigns and when starting work session. and break sessions
- After accumulating so you can go on expeditions. Eventually can choose to differnet experditions place to go. (switch enabled once there is more than 1, and appears like new indicating new map. Eventually something nice would be that you go exploring the map as you visit different terrains. )
- Character tiers: Choose the repetition of characters to improve the tier of the character. Can choose other characters to create relationshisp
- Relationships with the characters in the world. Have very small auogenerated thumbnails to meet characters and increase relationshps with random people. Thats how u do as you complete "quests" or your followers explore with you
- Start alone: start alone and only able to do research on your own. on the game 
- Game characters might abandon you or decrease relationship with you depending on how u distribute the share and what they feel was their share based on comparison with you and relationship they have w u and jealousy. . 


## Data Modeling for world.

### Companions


stats:
- relationship: relationship w player
- time: study time w character on pomodoros
- tier: estimated networth (based on distribution of shares shared with this character)
- total experience: increased mainly throguh expditions
- 


- constitution: health points value and core strength
  -   Increased by completing the gym
  -   Increased by going tand completing long break queue things.
  -   Make the excercises also have that character ding that workout. or at least a cute repeating workout animation of her that might switch around randomnly and when pausing have her complaining or saying u weak or what. 
- dexterity: directly related to the damage output multiplier of the character 
- wisdom: tied to magic skills where can increase things like healing, buff debuffs and interactions


- skills: accumulation of skills. Can be obtained through

preprogrammed items
- prases List<phrase, ?emotion>: predeterminate additional phrases that one might say depending and refining the character can add a animation or emotion action. 


"I like your world music"

"whats that picture about?"

















## Unlock & onboarding

- **Gate**: e.g. N completed Pomodoros, or M calendar days active, or “first week completed”—configurable Remote Config / constants later.
- **Prompt**: one-time modal: short pitch + “Maybe later” + “Turn on”.
- **Progressive disclosure**: turning on enables **logic + UI shells** immediately; **big art/music packs** download in the background (see Architecture).
- **Opt-out**: user can disable the mode anytime; prompts do not nag on every launch (cooldown).

---

## Training & daily tasks (stats from real behaviour)

| Real activity              | RPG mapping (example)                          |
|---------------------------|-------------------------------------------------|
| Pomodoro completed        | Technique / “attack” training, XP, loot rolls   |
| Workout session completed | Constitution / stamina, party fatigue recovery  |
| Streak / consistency      | Passive bonuses or relationship trust         |

Implementation note: derive stats from **existing** Hive/events (sessions completed); avoid duplicate timers.

---

## Relationships & characters

- On session **start**, roll or pick **visitors / party members** in the current “room” (ties into existing room theming).
- **Relationship meter**: increases when training **together** (same focus block, shared workout day, dialogue choices—later).
- **Train together**: cosmetics + small combat modifiers (AFK resolves), not mandatory micro-management.

---

## +18-adjacent content (conversation / flirt)

- Conversations can accumulate across breaks/sessions if desired narrative depth.
- **Feature flag**: `adultInteractionsEnabled` (dev build vs store policy); default off in production until legal/product decision.
- When off: substitute neutral dialogue packs; hide UI entry points entirely.

---

## Dungeons & AFK campaigning

### Session shape (concept)

- Optional **dungeon explore** metaphor during a long focus block (e.g. ~50 minutes): party **travels / rests / towns** most of the time (low CPU: slides, looping GIFs/WebP, or short Lottie-scale motion).
- **Final ~5 minutes** (or configurable): spike toward **boss / climax** encounter—dice or simple RNG narrative so it stays **readable and quick**.

### Dice / combat abstraction

- Combat is **narrative + numbers**: rolls modified by Technique, Constitution, relationships, gear (gacha-lite later).
- **Death / wipe**: thematic recovery (inn, bar—party flees); run continues or soft-fails without punishing real productivity metrics.

---

## Architecture (fast to build, scalable delivery)

### 1. Separate “gamification runtime” from “content packs”

- **Core app**: feature flags, save slots, timers tied to Pomodoro/workout lifecycle, orchestration (“what phase is this session in?”).
- **Mode pack**: images, spine-like data *if ever*, audio stubs, localized strings, campaign JSON. Treat as **versioned content** (e.g. `solo_level_assets_v3`).

This keeps installs small and iterations fast.

### 2. Lightweight on-screen gameplay

Prefer, in order of cost/complexity:

1. **Static character art + vignette text + progress bar** (MVP ship).
2. **WebP/GIF loops** already used in rooms—reuse pipelines.
3. **Sprite-sheet or Rive/Lottie** for key moments only if needed.
4. **Avoid** embedding a second game engine in v1.

Target **60 FPS is not required**; target **smooth enough + low memory** over polish.

### 3. Background download strategy

- **Flutter**: isolate download (e.g. `dio` + file sink), checksum manifest, pause/resume-aware if possible on mobile.
- **Manifest**: YAML/JSON in bundle or CDN listing files, hashes, incremental pack IDs (`base`, `dungeon_act1`).
- **States**: `missing` → `downloading %` → `verifying` → `ready`; UI shows readiness in Settings / mode hub.
- **First run**: playable with **placeholder art** (`CharacterSlot` grey silhouette) until pack ready.
- **Storage**: application support directory; clear cache action; obey platform storage guidance.

### 4. Persistence

- Small **campaign state**: JSON in Hive alongside existing boxes, or dedicated `gamification_campaign` box.
- **Split**: “account progress” vs “episode state” vs “pure cosmetic inventory”.

### 5. Gacha later, slots now

- v1: **fixed roster + random visitors** only.
- Later: pity counters, banners, IAP—hook only **interfaces** first (`RewardsPort`) so storefront rules stay swappable.

### 6. Campaign modes



- Campaign = **timeline of phases** keyed to wall-clock or Pomodoro progress within a session.
- Phase driver is a tiny **finite state machine** in Dart (`TravelState`, `TownState`, `CombatState`) fed by Tick from existing timer—not a separate game loop.

---

## Milestones

1. **M0**: Prompt + flag + stub “Training hall” UI (placeholder art).
2. **M1**: Link Pomodoro complete → Technique XP; workout → Constitution; persistence.
3. **M2**: Session arc (travel placeholders → boss RNG text) tied to timer phases.
4. **M3**: Background pack download + manifest; swap placeholders for real sprites.
5. **M4**: Relationship meters + rotating visitors; richer copy.
6. **M5+**: Gacha, adult dialogue gated content, fuller dungeon variety.

---

## Open questions

- Threshold to show invite (sessions vs streak vs level).
- Offline-only vs CDN for asset packs (and update signing).
- App size budget per pack (Mb) per store guideline.
- Whether “dungeon-only last 5 min” always maps to Pomodoro timing or adapts per focus length.


---

_Legacy brainstorming (preserved snippets)_

Maybe even have a dungeon to explore that can only be done in the last ~5 minutes; if skipped, characters still get stronger from normal training.
