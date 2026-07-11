# Motivation Screen Rework Plan

## Goal

Rework the Motivation experience into a card-based hub that combines:

- `quote` cards
- `collection` cards
- `reward` cards

The screen mirrors the sketch structure and provides clear points economy visibility:

- current available points
- last-week gained and spent points
- total gained and total spent points

## UX Structure (Sketch-Aligned)

### Top Tabs (existing analytics shell)

- Overview
- Focus
- Workout
- Motivation

### Motivation Header

- Points summary badge:
  - `available points`
  - `(+gained_lw / -spent_lw)`
  - secondary text with cumulative `total gained / total spent`

### Filter Row

- Type filter:
  - `all`
  - `quote`
  - `collection`
  - `reward`
- Scope filter:
  - `deck` (all visible cards)
  - `acquired` (collected or purchased cards)

### Card Grid

Each card shows:

- type label
- icon or visual index
- title
- short description or quote snippet
- status footer (`acquired`, `X pts`, or `Need Y`)

### Quick Create Access

- `+ Create` action from Motivation tab
- Switch type directly in form:
  - Collection
  - Quote
  - Reward

## Data Design

## 1) Motivation Catalog / Deck Items

Model: `MotivationItemModel`

Purpose:

- store quote and collection cards
- track acquisition state for non-reward deck items
- support seeded system cards and user-created cards

Core fields:

- `id`
- `type` (`quote|collection|reward`)
- `title`
- `description`
- `category`
- `pointsCost`
- `isAcquired`
- `acquiredAt`
- `quotePerson`
- `quoteText`
- `imageIndex`
- `isSystem`
- `metadata`

## 2) Points Transactions

Model: `MotivationPointsTransactionModel`

Purpose:

- support reliable points analytics queries
- compute last week deltas and lifetime totals from immutable records

Core fields:

- `id`
- `kind` (`earned|spent`)
- `amount`
- `source` (e.g. `pomodoro_session`, `points_spend`, `level_up_bonus`)
- `createdAt`
- `metadata`

## 3) Reward Model Interop

Existing `RewardModel` remains for user-generated and purchased rewards.

Motivation UI includes rewards by projecting reward records into motivation card view models.

## Seed Strategy

Sources:

- `assets/icon/motivation_64.csv`
- `assets/quotes.csv`

Rules:

- `philosopher` rows become `quote` cards
- `boardgame` and `plant` rows become `collection` cards
- quote text comes from `quotes.csv` by person/topic matching
- title, description, and image index come from `motivation_64.csv`
- low-cost starter cards include 20-point unlocks for onboarding

Seeding is idempotent by stable IDs (`motivation_catalog_<number>`).

## Query Requirements

The Motivation header requires:

- `available`: from `UserProgressModel.availablePoints`
- `lastWeekEarned`: sum of `earned` transactions in last 7 days
- `lastWeekSpent`: sum of `spent` transactions in last 7 days
- `totalEarned`: sum of all `earned`
- `totalSpent`: sum of all `spent`

Service: `MotivationPointsService.summary()`

## Quick Create Flow

Dialog: `Quick Create Motivation`

Type switch:

- Collection: creates `MotivationItemModel(type=collection)`
- Quote: creates `MotivationItemModel(type=quote)` with person/topic and optional quote text
- Reward: creates `RewardModel` via existing reward creation flow

## Integration Notes

- Keep reward purchase behavior unchanged
- Use transaction logging for all spend and earn pathways
- New boxes are opened at app startup:
  - `motivationItems`
  - `motivationPointsTransactions`

## Next Iteration Ideas

- Add sprite sheet preview using `imageIndex` from `motivation_64.png`
- Add rarity tiers and drop-style unlock effects
- Add topic-based quote packs and streak-based quote rewards
- Add transaction timeline and category spend chart

