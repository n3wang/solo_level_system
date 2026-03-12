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






