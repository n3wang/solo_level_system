# Rooms Logic Implementation Plan

## Goal
Decouple **Rooms** from **Projects**.

Rooms should represent ambience only:
- Room-specific track pool
- Room-specific visuals
- Room-specific phrases
- Timer uses only selected room ambience
- Pomodoro visuals rotate based on selected room

Projects remain for productivity/logging metadata, not ambience selection.

## Product Rules
- Remove room/project chips from `HomeScreen` top area.
- Keep project selection separate (if still needed for logs), but not for ambience control.
- Add dedicated room selection state on Home.
- Timer playback chooses tracks only from selected room.
- Timer visual cycles only from selected room visuals.
- Phrase rotation shows only selected room phrases.
- Random room mode picks a room first, then uses that room's ambience set.

## Data Model Refactor
Create explicit room entities:

- `RoomModel`
  - `id`, `name`, `description`, `createdAt`, `isActive`
- `RoomAmbienceModel` (or expanded existing room model)
  - `roomId`
  - `selectedTracks: List<String>`
  - `selectedVisuals: List<RoomVisualConfig>`
  - `phrases: List<String>`
  - `volume: double`

Important:
- Stop keying ambience by `projectId`.
- Key ambience strictly by `roomId`.
- Keep projects untouched for session logging.

## State and Services
Add dedicated room state in Home:
- `RoomModel? selectedRoom`
- `List<String> roomTracks`
- `List<RoomVisualConfig> roomVisuals`
- `List<String> roomPhrases`

Create `RoomAmbienceService` responsibilities:
- Load selected room ambience
- Provide next track from room pool
- Provide next visual from room visual list
- Provide next phrase from phrase list
- Handle fallback behavior if room ambience is empty

## Home Screen Behavior
- Remove room-as-project chip UI from Home.
- Keep timer UX unchanged except ambience source.
- Add rotation logic:
  - phrase rotation (existing cadence can be reused)
  - visual rotation (for example every 20-40 seconds)
  - track continuity (next track from room pool when needed)
- If selected room has no ambience assets:
  - phrase hidden
  - visual fallback placeholder
  - track fallback behavior (global random or silent, based on product decision)

## Room Management Screen Changes
- Manage **rooms**, not projects.
- Create/edit/delete room metadata independent from projects.
- Track/visual/phrase assignment stored under `roomId`.
- Keep existing reusable track preview chip and multi-select add flow.

## Migration Plan
1. Introduce new storage boxes/tables (`rooms`, `roomAmbience`).
2. Seed sample rooms into new room storage.
3. Migrate old `roomManagement` entries keyed by project IDs where possible:
   - Map known sample IDs directly
   - Move unknown entries to an "Imported Room" flow (optional)
4. Keep backward compatibility for one release, then remove legacy path.

## Test Plan
- Unit:
  - room ambience load by `roomId`
  - phrase/visual/track rotation logic
  - fallback behavior
- Widget:
  - Home no longer shows room-as-project chips
  - phrase/visual updates while timer runs
- Integration:
  - selecting room changes track pool/visual cycle/phrases immediately
  - built-in and uploaded tracks both work in room-only ambience flow

## Milestones
1. Model and storage split (rooms vs projects)
2. Home decoupling (bind ambience to selected room)
3. Playback and visual/phrase rotation integration
4. Migration and seed update
5. Docs, cleanup, and legacy removal

## Phase 2+ Feature Roadmap

### Popularity and Insights
- Track room popularity metrics:
  - `visitCount`
  - `sessionsCompleted`
  - `totalFocusMinutes`
  - return usage (`d1`, `d7` style retention)
- Add UX surfaces:
  - Trending rooms
  - Most effective room for current user
  - Personal room history chart

### Social Layer (Staged)
- Stage 1: Room presence only (anonymous online count, optional lightweight avatar)
- Stage 2: Lightweight interaction (emoji/status/reaction)
- Stage 3: Full room chat (with moderation/reporting/rate limits)

### Room Agent (Relationship System)
- Daily relationship points if user completes at least one study session in that room
- Agent progression based on consistency and room streaks
- Unlocks:
  - cosmetic room elements
  - unique motivational lines
  - optional non-competitive ambient bonuses

## Offline-First Network Strategy
- App remains fully functional offline by default:
  - room ambience setup
  - room selection
  - phrase/visual/track cycles
  - local popularity and agent progression updates
- Network becomes enhancement only:
  - sync events to backend when available
  - fetch cloud popularity/presence/chat snapshots
- Use outbox pattern:
  - write local first
  - enqueue API action
  - sync in background when online
- Conflict resolution:
  - prefer last-write-wins for mutable room metadata
  - additive merge for counters (minutes, sessions, visits)

## API Repository Plan (Single API Endpoint Later)
- Introduce `RoomApiRepository` abstraction now with mock implementation
- All room API calls route through this repository:
  - ambience sync
  - popularity reads/writes
  - presence
  - chat
  - room-agent progression
- Current phase:
  - mock responses
  - local cache + outbox queue
  - zero hard dependency on connectivity
- Future phase:
  - swap mock transport with real API client
  - keep same repository contract so UI/domain code stays unchanged

