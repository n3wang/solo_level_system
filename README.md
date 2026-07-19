# solo_level_system


Checkout devdocs for kanban board.

## Maintenance Hive Database

To update the modesl flutter schemas:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Running tests.

```bash
flutter test
```

### Running app in test environment

Use compile-time flags to boot the app in test mode (with test-specific values):

```bash
flutter run --dart-define=APP_ENV=test
```

or:

```bash
flutter run --dart-define=APP_TEST_MODE=true
```


```bash
flutter run --dart-define=APP_ENV=test -d chrome
```

## Workout Icon Pre-Slice (required before build/run)

Workout icons are now loaded from pre-sliced assets (not runtime sprite slicing).
Run this before `flutter run` / `flutter build` whenever the sheet changes:

```bash
dart run scripts/slice_workout_sprites.dart
```

Windows shortcut:

```bash
scripts\slice_sprites.bat
```

One-command run on Windows (slice + run):

```bash
scripts\flutter_run_with_slice.bat
```

In Cursor/VS Code, use the launch config `Flutter Run (auto-slice icons)` to
run slicing automatically before launch.

## Lofi Rooms Whitelist (YAML)

Room-specific music and visuals are whitelisted in:

`assets/data/rooms.yml`

Each room entry supports:
- `trackRegex` to match audio files by filename
- `visuals` for room GIF/PNG assets
- `phrases` for room quote rotation

Notes:
- New audio files dropped under `assets/audio/lofi/` are auto-discovered at runtime,
  even if `lofi_tracks.yml` was not updated yet.
- Empty room music is disallowed: when a room has no selected tracks, app falls
  back to an available lofi track so playback still works.






