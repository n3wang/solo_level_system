# Room Management Screen

This document describes the first implementation of the Pomodoro Room Management screen.

## Access Point

- The screen is accessible from the main Pomodoro page (`HomeScreen`).
- A bottom-left icon button is shown when no Pomodoro is actively running:
  - not started yet
  - paused
  - finished / waiting submission
- Tapping the icon opens `RoomManagementScreen`.

## Room Selection Rules

- A room maps to a project.
- Users can:
  - tap room cards to select a room and open a room info modal
  - swipe room cards horizontally to change room
- A `Random` room option exists.
  - If selected, no specific project is bound.
  - This matches the rule where random available audio can play when no room is specified.
- Room selection does not change Pomodoro work/break durations.
- Bottom room indicators are textless rectangular chips, one per room (including Random).
  - selected chip is colored
  - no checkmark/tick icon
- A `Clear` button appears only when a specific room is selected.
- Exit uses the top-right button and returns the selected room back to Pomodoro.

## Room Info Editing

- Room info modal includes a top-right pencil (`edit`) action.
- Editable fields:
  - title
  - description
  - phrases (list of strings, one per line)
- Saving updates room title/description and stores phrase list in room configuration.

## Phrase Runtime Behavior

- If the selected room has phrases, Pomodoro can show them while running.
- Phrases rotate periodically (about every 24 seconds).
- If no phrases are configured, no phrase banner is shown.

## Tracks

- Tap a track item to preview/listen.
- Add tracks via:
  - existing audios not yet selected
    - built-in lofi assets
    - user library audio files from `audioFiles` box
  - upload from phone files using file picker
- Accepted upload formats:
  - `mp3`, `wav`, `m4a`, `aac`, `ogg`, `flac`
- Uploaded tracks are copied into app documents storage under `room_audio`.

## Visuals

- Add visuals from:
  - local album (gallery picker)
  - file picker (image/GIF upload)
- Accepted visual formats:
  - `jpg`, `jpeg`, `png`, `webp`, `gif`
- Tap a visual to open popup preview.
- GIF visuals include selectable speed tags:
  - `x0.2`, `x0.5`, `x1`, `x1.5`, `x2`
- Speed value is persisted per GIF visual in room config metadata.
- Visual assets are copied into app documents storage under `room_visuals`.

## Persistence

- Room-specific setup is persisted in Hive box: `roomManagement`.
- Storage key is:
  - project id for room-bound config
  - `__random__` for random room config
- Stored values:
  - selected tracks
  - selected visuals (with GIF flags and speeds)
  - room volume (3 fixed levels: base x1, x2, x3)

## Seeded Sample Rooms

Two sample rooms are auto-seeded when Pomodoro home initializes, if they do not already exist:

- `Space Station Study`
  - project id: `sample-room-space-station-study`
  - room icon/visual: `assets/album/al16-spaceship.png`
  - seeded tracks: built-in lofi ids `1..8`
- `Abandoned Mansion Study`
  - project id: `sample-room-abandoned-mansion-study`
  - room icon/visual: `assets/album/an02_model1_working_2.gif`
  - seeded tracks: built-in lofi ids `30..38`

Seeding is non-destructive:

- it only creates missing sample projects
- it only writes room track presets if no room config exists yet
- existing user-edited room configs remain untouched

## Files Added / Updated

- Added:
  - `lib/models/room_management_model.dart`
  - `lib/screens/room_management_screen.dart`
  - `lib/utils/room_management_seed_service.dart`
  - `docs/room_management_screen.md`
- Updated:
  - `lib/screens/home_screen.dart`
  - `pubspec.yaml` (added `file_picker`)


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


