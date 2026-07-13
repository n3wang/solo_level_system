# Motivation Screen — Cards Unlock System

Status: **design revision** (hub exists; broaden “motivation items” into abstract **Cards** that unlock options across the app).  
No new implementation yet — this doc is the target model.

**Habit** here means records in the Hive `habits` box (`HabitTrackerModel`) — recurring goals you can mark complete (daily/weekly, tied to pomodoro, workout, or custom).

On Overview:
- **Habits `0/0`** — completed vs total **active** habits
- **Habit Completion `0/1`** — same idea for the goals bar; if there are no habits, the target falls back to `1`, so you get `0/1`

There’s no main Habit screen wired up yet, so those stats are mostly empty unless something else writes into that box.


## Card sources

Where each card type's content comes from today, and where to add more. All paths are repo-relative under `assets/` and bundled via `pubspec.yaml`. Services read them with `rootBundle.loadString(...)` — never hardcode content in Dart (see CLAUDE.md: `default_workouts.yaml` is the source of truth for exercise audio).

### Content sources (data)

| Source file | Feeds card type | Read by | Format / notes |
|-------------|-----------------|---------|----------------|
| `assets/icon/motivation_64.csv` | `quote` (philosopher rows), `collection` (boardgame + plant rows) | `MotivationSeedService` | `name,number,description,category`; `category ∈ {philosopher, boardgame, plant}` → 33 / 22 / 40 rows. `number` = sprite index into `motivation_64`. |
| `assets/quotes.csv` | `quote` (quote text packs) | `MotivationSeedService` | `philosopher,quotes`; quotes are `;`-separated, joined onto the matching philosopher card's `metadata.quotes`. |
| `assets/icon/motivation_64.csv` (boardgame rows) | `reward` (hidden collectible dupes) | `RewardSeedService` (`_sourceTag = default_boardgame_csv`) | Same CSV, re-projected as demo rewards; **hidden** in the hub so boardgames show only as `collection`. Fold away once one Card catalog is canonical. |
| `assets/workouts/default_workouts.yaml` | `program`, `set` (+ exercises, audio refs) | `ProgramsService` / `DefaultWorkoutsService` | Exercises, sets, routines, `audio_file` per exercise. Program/set **cards** not seeded yet — `unlockTargetId` will point at program/set ids from here. |
| `assets/lofi/lofi_mapping.json` (+ `assets/lofi/*.mp3`) | `music` | `LofiService` | `tracks[]`: `id, filename, title, author, albumImage`. Music **cards** not seeded yet — one card per track (or small pack). |
| `assets/lofi/room_music_whitelist.yaml` (+ `assets/album/*`) | `room` | room/atmosphere loader | Rooms: `id, name, description, iconAssetPath, trackRegex, visuals[], phrases[]`. Room **cards** not seeded yet — `unlockTargetId` = room `id`. |

### Art / audio sources (referenced by cards, not cards themselves)

| Source | Used for |
|--------|----------|
| `assets/icon/motivation_64.png` | Sprite sheet `motivation_64`; card art via `imageIndex` (= CSV `number`; drawn at sprite slot `imageIndex − 1`). |
| `assets/album/*.png` / `*.gif` | Room / album backgrounds (room card art, atmosphere visuals). |
| `assets/icon/workout_icons_128px.png` + `.csv` + `workout_icons_sliced/*` | Exercise / set / program card icons. |
| `assets/audio/workouts/*.mp3` | Per-exercise cue audio (referenced from YAML `audio_file`). |
| `assets/audio/{s01,s02,s03}*.mp3`, `break_time.mp3`, `workout_complete.mp3` | Sound effects (session/loot feedback) — **not** cards. |

### Adding a future source

Adding content = drop the asset + extend the matching source file; a seed service turns it into cards. No new Dart per item.

| To add a… | Do this |
|-----------|---------|
| Quote pack | Add a `philosopher,quotes` row to `quotes.csv` (and a `motivation_64.csv` row if it needs its own sprite). |
| Collection item | Add a `boardgame`/`plant` row to `motivation_64.csv` with a sprite `number`. |
| Program / set | Add it to `default_workouts.yaml`; seed a `program`/`set` card whose `unlockTargetId` = its id. |
| Music track/pack | Add `.mp3`(s) to `assets/lofi/` + an entry in `lofi_mapping.json`; seed a `music` card per track/pack. |
| Room | Add a room block to `room_music_whitelist.yaml` + visuals to `assets/album/`; seed a `room` card with `unlockTargetId` = room id. |
| Reward | User-authored at runtime (Quick Create / Rewards screen) — no asset. |
| Guide / Option | Author a **markdown file** — see below. |

### Guides & options as markdown (proposed)

`guide` and `option` cards are **text-first** (a title + a description/how-to body), so author them as markdown files instead of CSV rows. Opening the card renders the markdown; for guides the same body feeds the on-screen **?** modal.

Layout (bundled — list the folders in `pubspec.yaml` with trailing slash):

```
assets/cards/
  guides/
    motivation-hub.md
    active-workout.md
    focus-pomodoro.md
  options/
    project-slots.md
    room-slots.md
```

Each file = one card. YAML frontmatter carries the card fields; the markdown body is the description (guides: the how-to; options: what the setting does, shown when the card is opened).

Guide example — `assets/cards/guides/motivation-hub.md`:

```markdown
---
type: guide
screenKey: motivation_hub
title: Motivation Hub Guide
rarity: common
imageIndex: 5      # optional sprite in motivation_64
starter: true      # ships already unlocked
---
Every tile is a Card. Spend points (earned from focus and workout sessions)
to acquire cards. Acquiring a card unlocks what it represents.

## Tips
- Filter by type or "acquired" to find cards fast.
- Session loot drops cards weighted by rarity.
```

Option example — `assets/cards/options/project-slots.md`:

```markdown
---
type: option
settingKey: project_slots
title: Project Slot
rarity: uncommon
capacityPerCopy: 1
starterCopies: 3   # seeded owned xN → base capacity
cost: 50
---
Each copy raises your maximum number of projects by one. Buy again to add more.
```

Seeding: a `CardMarkdownSeedService` enumerates `assets/cards/guides/` and `.../options/` from `AssetManifest.json`, parses frontmatter → card fields and body → `metadata.howTo` (guide) or `description` (option), then upserts by a stable id derived from the filename (`guide_motivation_hub`, `option_project_slots`). Re-running updates body/fields without dropping `acquisitionCount`. `## Tips` under a guide body becomes `metadata.tips`.

Rendering: the card detail modal and `HelpButton` render the markdown body (upgrade `help_button.dart` from plain `Text` to a markdown widget, e.g. `flutter_markdown`).

This replaces the current hardcoded starter guide/option seeding in `motivation_seed_service.dart` (`_ensureStarterUnlockCards`) — those two option cards and the hub guide move to markdown files, and new guides/options are added by dropping a `.md` file.

## Core idea: Cards, not “motivation items”

Everything in the Motivation hub is a **Card**. A card is a collectible entry you can browse, filter, and acquire with points. Acquiring a card **unlocks the thing it represents** in the rest of the app.

**Progression = collectible cards (+ points to buy them).**  
There is **no level** and **no experience (XP)** track. Features, capacity, content, and help are all gated by owning the right cards — not by reaching a level or XP threshold. Any existing level / XP UI or earn paths are **legacy to remove** in favor of this card catalog.

| Card type | Unlocks |
|-----------|---------|
| `quote` | Quote packs usable during workouts / motivation surfaces |
| `collection` | Collectible art / themed sets (boardgames, plants, etc.) |
| `reward` | Redeemable rewards (points sink) |
| `room` | Background / room scene for focus / workout atmosphere |
| `music` | Music track (or small pack) in the audio picker |
| `program` | Workout program availability |
| `set` | Exercise set (group of exercises) availability |
| `guide` | Screen / feature “how to use” help (see below) |
| `option` | A setting / capacity limit (stackable — see below) |

Unlocking a card is the gate: until acquired, the corresponding option stays locked (or hidden) on its screen. Until acquired, the card still shows in the hub (catalog) so the player can discover and buy it.



### Option cards (stackable settings)

`option` cards do **not** unlock a single asset. They unlock or raise a **setting / capacity**, and **copies stack**.

`acquisitionCount` = how much capacity that option grants (or adds), depending on the card.

Examples:

| Option card | Effect per copy | Starter copies |
|-------------|-----------------|----------------|
| **Project slots** | +1 max project | **×3** → max 3 projects |
| **Room slots** | +1 max room (saved / usable room slots) | **×3** → max 3 rooms |

Players buy the same card again to accumulate more capacity (e.g. from 3 → 4 projects). Hub footer shows `owned xN`. Soft-cap or rising cost can come later; design assumes rebuy is always allowed for these cards.

Distinguish from `room` / `program` content cards:

- `room` / `program` / `music` = **which** assets exist in the picker
- `option` (room slots / project slots) = **how many** you may keep or use at once

### Filter surface

Type filters on one card grid (no separate sub-tabs):

`all` | `quote` | `collection` | `reward` | `room` | `music` | `program` | `set` | `guide` | `option`

Scope: `all` | `acquired`.

## Starter unlocks (first-run defaults)

Ship a small set of cards already acquired so the app is usable without spending points first.

| Area | Default unlocked |
|------|------------------|
| **Sets (exercises)** | Almost all — at least every set that is referenced by seeded programs / YAML sets |
| **Programs** | **7 Minutes Workout** program card unlocked |
| **Music** | A few core, nice tracks unlocked |
| **Rooms / album art** | 2–3 room / album background images unlocked |
| **Option: project slots** | **3 copies** owned → max **3** projects |
| **Option: room slots** | **3 copies** owned → max **3** rooms |
| **Guides** | Core instructional cards for the main flows (decorative in hub; functional help on screens) |

Everything else starts locked and appears in the hub as purchasable cards.

## Guide cards → screen help

`guide` cards are **instructional / decorative** in the Motivation hub (art + short blurb about a feature).

Once a guide card is **unlocked**, its corresponding screen gains a **?** control. Tapping **?** opens a modal that explains how to use that screen (content sourced from the unlocked guide card: title, body, optional tips).

| Concept | Behavior |
|---------|----------|
| Locked guide | Visible in hub catalog; no **?** on the target screen (or **?** disabled / “unlock in Motivation”) |
| Unlocked guide | **?** appears on the target screen → modal with how-to content |
| Hub tile | Decorative presentation of the same guide (sprite, title, short description) |

Target screens for guides (examples): Motivation hub itself, Active Workout, Programs, Focus / Pomodoro, Analytics, Settings-related atmospheres (rooms / music) as needed.

## Entry (current)

| Path | Screen |
|------|--------|
| Main nav → Stats/Analytics → **Motivation** tab | `MotivationHubScreen` |
| Workout nav → Motivation tab (legacy) | `MotivationalCardsScreen` — freeform text cards, **not** the hub economy |

Shell tabs on Analytics: Overview | Focus | Workouts | Motivation (`analytics_screen.dart`).  
The period picker above Analytics is unused by the Motivation hub.

## Hub UX (target shape)

Top → bottom:

1. **Points summary** (Analytics header, left of period dropdown, Motivation tab only)
   - Available: `UserProgressModel.availablePoints`
   - Last week: `(+earned / -spent)` from transactions
   - Source: `MotivationPointsService.summary()`

2. **Filters** — types above + `all` / `acquired`

3. **Card grid** (responsive 3–5 columns)
   - Type + category, sprite or icon, title
   - Footer: cost / `owned` / `owned xN` (insufficient funds tinted)
   - Locked vs acquired visual state

4. **Create** → Quick Create (extend for new card types where user-authored cards make sense)

### Card tap

Detail modal: art, cost, description, acquire/buy.  
Quote cards: random / next / list / edit quotes stored in metadata.  
Program / set / room / music / guide cards: show what unlocking enables (and for guides, preview of the how-to body).  
Option cards: show current capacity from copies (`owned xN` → “max N projects/rooms”) and cost of +1.

### Acquire / buy

Confirm if already owned → spend points → mark card acquired → **propagate unlock** so the option appears on the matching screen.  
For `option` cards, rebuy is expected: each purchase increments `acquisitionCount` and raises the limit.

### Unlock propagation (new)

| Card type | Effect when acquired |
|-----------|----------------------|
| `quote` | Quote pack usable by `WorkoutMotivationService` / hub |
| `collection` | Collection entry owned (display / progress) |
| `reward` | Same as today (`RewardModel.purchase` path) |
| `room` | Room/background selectable in atmosphere / session UI |
| `music` | Track selectable in music picker |
| `program` | Program selectable / startable in workout programs |
| `set` | Exercises in that set available for custom / program building |
| `guide` | Enable **?** + how-to modal on the mapped screen |
| `option` | Raise setting capacity: `max = acquisitionCount` (or base + count); enforce in create/save flows |

## Data model direction

Keep a single hub concept of **Card** (evolve `MotivationItemModel` or rename conceptually to Card). Broaden `type` beyond `quote | collection | reward`.

Suggested fields / metadata:

| Field / metadata | Role |
|------------------|------|
| `type` | `quote` \| `collection` \| `reward` \| `room` \| `music` \| `program` \| `set` \| `guide` \| `option` |
| `unlockTargetId` | ID of program, set, track, room asset, screen key, or setting key (`project_slots`, `room_slots`, …) |
| `acquisitionCount` | Stack depth; for `option`, drives max capacity |
| `metadata.quotes` | Quote lists (existing) |
| `metadata.howTo` / body | Guide modal content |
| `metadata.screenKey` | Which screen gets the **?** (for `guide`) |
| `metadata.settingKey` | Which limit this option raises (`max_projects`, `max_rooms`, …) |
| `metadata.capacityPerCopy` | Usually `1`; allows +N per purchase later if needed |
| `isStarter` / seeded `isAcquired` | First-run unlocked cards (option starters seed with `acquisitionCount: 3`) |
| `rarity` | Drop / display tier (e.g. `common` \| `uncommon` \| `rare` \| `epic`) |
| `imageIndex` / asset paths | Sprite or album / room art |

Rewards may remain projected from `RewardModel` or fold into Cards later; see legacy notes below.

## Current implementation snapshot (as of hub live)

Useful until the redesign lands:

| Piece | Today |
|-------|--------|
| Types in hub | `quote` \| `collection` \| `reward` only |
| Models | `MotivationItemModel`, `RewardModel`, points ledger, legacy `MotivationalCardModel` |
| Seeding | `motivation_64.csv`, `quotes.csv`, sprite `motivation_64` |
| Points | Earn: +1 / minute on session complete; spend: hub acquire — **not** level-up |
| Session loot | +1 random card / 10 min (min 1); repeats stack; rarity-weighted |
| Filters | `all` \| `quote` \| `collection` \| `reward` + scope `all` \| `acquired` |
| Legacy | `UserProgressModel` still has level / XP fields in code — **retire**; points-only + cards |

Collectible rewards from CSV are hidden in the hub so boardgames appear as **collection** cards only.

## Points & session rewards (cards only — no XP / levels)

**Balance:** points (today on `UserProgressModel.availablePoints`; keep points, drop level/XP).

**Spend:** Hub acquire / reward purchase → unlock or stack cards.

**Create catalog items** does **not** spend points; it adds records.

**Progress display:** hub / analytics show **points + card collection** (owned counts, types unlocked, rarity) — not level bars or XP.

### Session complete (focus or workout)

On completing **any** session (focus / pomodoro **or** workout):

| Grant | Rule |
|-------|------|
| **Points** | **+1 point per minute** spent in the session (card currency) |
| **Random cards** | **+1 random card per 10 minutes**, floored — but **at least 1 card** even for short sessions |

Examples:

| Duration | Points | Random cards |
|----------|--------|--------------|
| 7 min workout | +7 | **1** (minimum) |
| 25 min focus | +25 | **2** (⌊25/10⌋) |
| 50 min | +50 | **5** |

#### Random card drops

- Drawn from the catalog drop pool (weighted by **rarity**; exact weights TBD).
- Drops **can repeat**; repeats **stack** (`acquisitionCount` / `owned xN`) — same as option copy stacking.
- Stacking a content/option card re-applies unlock semantics (e.g. another room-slot copy raises capacity).
- Show a short “loot” summary after the session (points + cards gained, rarity callouts).

**Do not** award XP, level-ups, or “level_up_bonus” points.

### Rarity

Every catalog card has a **rarity** used for drop chance and hub presentation (tint / badge). Stacking does not change rarity; rarer cards are simply harder to roll on session complete. Players can still **buy** cards in the hub with points (buy path may ignore rarity weights or charge more for higher rarity — TBD).

## Related / legacy surfaces

| Surface | Status |
|---------|--------|
| `MotivationalCardsScreen` | Live on workout nav; separate freeform cards — candidate to merge into hub Cards |
| `RewardsManagementScreen` / `RewardsScreen` | Exist; not on main nav |
| Dual CSV seed (items + collectible rewards) | Prefer single Card catalog over time |

## Implementation checklist (not started)

- [ ] Widen card `type` enum + filters for room / music / program / set / guide / option
- [ ] Define unlock propagation APIs (query “is X unlocked?” + “max capacity for setting Y?”)
- [ ] Seed starters: all in-set exercises/sets, 7 Minutes program, core music, 2–3 rooms/album images, core guides
- [ ] Seed option cards: project slots ×3, room slots ×3; enforce max in create/save UI
- [ ] Allow rebuy of `option` cards to stack capacity; hub shows `owned xN`
- [ ] Wire **?** + how-to modal from unlocked `guide` cards on target screens
- [ ] Hub detail copy for unlockable option / content cards
- [ ] Optional: rename UX copy from “Motivation Item” → “Card” throughout hub
- [ ] **Remove levels & experience:** drop XP earn, level-up bonus, level/XP UI; points + cards only
- [ ] Replace any “unlock at level N / XP” gates with `option` / content / `guide` cards
- [ ] Session complete grants: **+1 point / minute** + **⌊minutes/10⌋ random cards (min 1)**; repeats stack
- [ ] Rarity on cards + weighted drop table; post-session loot UI
- [ ] Retire or merge legacy `MotivationalCardModel` into Cards
- [ ] Transaction timeline / spend chart (stretch)
