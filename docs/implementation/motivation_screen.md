# Motivation Screen

Status: **implemented** (hub live under Analytics → Motivation).  
Former rework plan kept as “Next ideas” at the bottom.


**Habit** here means records in the Hive `habits` box (`HabitTrackerModel`) — recurring goals you can mark complete (daily/weekly, tied to pomodoro, workout, or custom).

On Overview:
- **Habits `0/0`** — completed vs total **active** habits
- **Habit Completion `0/1`** — same idea for the goals bar; if there are no habits, the target falls back to `1`, so you get `0/1`

There’s no main Habit screen wired up yet, so those stats are mostly empty unless something else writes into that box.

## Entry

| Path | Screen |
|------|--------|
| Main nav → Stats/Analytics → **Motivation** tab | `MotivationHubScreen` |
| Workout nav → Motivation tab (legacy) | `MotivationalCardsScreen` — freeform text cards, **not** the hub economy |

Shell tabs on Analytics: Overview | Focus | Workouts | Motivation (`analytics_screen.dart`).  
The period picker above Analytics is unused by the Motivation hub.

There are **no separate Quotes / Collection / Rewards sub-tabs**. Those are **type filters** on one card grid.

## Hub UX (`lib/screens/motivation_hub_screen.dart`)

Top → bottom:

1. **Points summary** (Analytics header, left of period dropdown, Motivation tab only)
   - Available: `UserProgressModel.availablePoints`
   - Last week: `(+earned / -spent)` from transactions
   - Source: `MotivationPointsService.summary()`

2. **Filters**
   - Type: `all` | `quote` | `collection` | `reward`
   - Scope: `all` | `acquired` (acquired = collected or purchased)

3. **Card grid** (responsive 3–5 columns)
   - Type + category, sprite or icon, title
   - Footer: cost / `owned` / `owned xN` (insufficient funds tinted)

4. **Create** → Quick Create dialog (Collection / Quote / Reward)

### Card tap

Detail modal: art, cost, acquire/buy.  
Quote cards: random / next / list / edit quotes stored in `metadata['quotes']`.

### Acquire / buy

Confirm if already owned → `userProgress.spendPoints(cost)` →  
`MotivationItemModel.recordAcquisition()` **or** `RewardModel.purchase()`.

### Card projection

| Source | Shown as |
|--------|----------|
| All `MotivationItemModel` | quote / collection cards |
| `RewardModel` except collectible-seeded | reward cards |

Collectible rewards (`metadata.isCollectible`, `source=default_boardgame_csv`, or tag `collectible`) are **hidden** in the hub so boardgames appear only as **collection** items.

Sprite art: `SpriteImage(sheet: 'motivation_64', index: imageIndex - 1)` when `imageIndex > 0`.

## Data models

| Model | Box | Role |
|-------|-----|------|
| `MotivationItemModel` | `motivationItems` | Deck: `quote` / `collection` (acquisition count + history) |
| `MotivationPointsTransactionModel` | `motivationPointsTransactions` | Ledger: `earned` \| `spent`, amount, source, createdAt |
| `RewardModel` | `rewards` | Purchasable rewards; hub projects non-collectibles |
| `MotivationalCardModel` | `motivationalCards` | **Legacy** workout cards only (not hub) |
| `UserProgressModel` | `userProgress` | `availablePoints`, lifetime earn/spend counters |

Opened at startup in `main.dart` (and hub also opens them defensively).

## Services

| Service | Role |
|---------|------|
| `MotivationSeedService` | Idempotent seed from CSVs → `MotivationItemModel` |
| `RewardSeedService` | Seeds collectible `RewardModel`s from same CSV (hub filters them out) |
| `MotivationPointsService` | `recordEarned` / `recordSpent` / `summary()` |
| `MotivationalCardService` | Legacy card CRUD — not used by hub |
| `WorkoutMotivationService` | Random quote from **acquired** hub quote items during workouts |

## Seeding

Sources:

- `assets/icon/motivation_64.csv` — name, number (sprite index), description, category  
- `assets/quotes.csv` — `person,quote1;quote2;…`  
- Sprite sheet: `assets/icon/motivation_64.png` (`motivation_64`)

Rules:

- `philosopher` → `quote`
- `boardgame` / `plant` / other → `collection`
- Quote lists matched to person name (exact, then contains)
- Stable IDs: `motivation_catalog_<number>`
- Low-cost starters: first few catalog rows use starter cost (20 prod / 5 test env)

## Points economy

**Balance:** `UserProgressModel.availablePoints`.

**Earn** (also writes ledger):

- Pomodoro complete → `pomodoro_session`
- Level-up bonus → `level_up_bonus`

**Spend:**

- Hub acquire / reward purchase → `spendPoints` + `recordSpent(..., source: 'points_spend')`

**Create catalog items** (Quick Create) does **not** spend points; it adds Hive records.

## Quick Create

Dialog from hub **Create**:

| Type | Creates |
|------|---------|
| Collection | `MotivationItemModel(type: collection)` |
| Quote | `MotivationItemModel(type: quote)` + person/topic + optional quote text |
| Reward | `RewardModel` via existing custom-reward helper |

## Related / legacy surfaces

| Surface | Status |
|---------|--------|
| `MotivationalCardsScreen` (+ add/edit/detail) | Live on workout nav; separate freeform cards |
| `RewardsManagementScreen` / `RewardsScreen` | Exist; full reward CRUD; **not** on main nav (management screen can embed hub) |
| Dual CSV seed into both items + collectible rewards | Intentional split; hub prefers collection items |

## Next ideas (not built)

- Rarity tiers / unlock effects  
- Topic quote packs / streak rewards  
- Transaction timeline + spend chart  
- Unify collectible rewards so hub doesn’t need a filter exclusion  
- Retire or merge legacy `MotivationalCardModel` path into the hub  
- Scope label `deck` (plan) vs current `all` — cosmetic only  
- Card tiles: description snippet + explicit “Need Y” footer
