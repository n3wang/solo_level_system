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
- Exit uses the top-right button and returns the selected room back to Pomodoro.

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
  - room volume

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
