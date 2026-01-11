# Flutter Learning Notes

## Hive Database Integration

### Key Concepts
- **Hive**: A lightweight, fast NoSQL database for Flutter/Dart applications
- **Type Adapters**: Generated code that handles serialization/deserialization of custom objects
- **Boxes**: Hive's equivalent of tables in traditional databases

### Implementation Patterns

#### 1. Model Definition with Hive Annotations
```dart
@HiveType(typeId: 0) // Unique ID for each model
class MyModel extends HiveObject {
  @HiveField(0) // Field index
  String name;

  @HiveField(1)
  DateTime createdAt;

  MyModel({required this.name, required this.createdAt});
}
```

#### 2. Adapter Generation
Use `build_runner` to generate adapters:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

#### 3. Registration and Initialization
```dart
void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(MyModelAdapter());
  await Hive.openBox<MyModel>('myBox');
  runApp(MyApp());
}
```

### Advanced Flutter Patterns

#### 1. Enhanced Widget Architecture
- **Separation of Concerns**: Separate basic widgets from enhanced versions
- **Backwards Compatibility**: Keep old widgets while introducing new ones
- **Progressive Enhancement**: Allow apps to gradually adopt new features

#### 2. Future Builder with Null Safety
```dart
FutureBuilder<MyModel?>(
  future: _getModelById(id),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return MyWidget(model: snapshot.data!);
    }
    return CircularProgressIndicator();
  },
)
```

#### 3. Popup Menu Navigation
```dart
PopupMenuButton<String>(
  onSelected: (String value) {
    switch (value) {
      case 'settings':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
        break;
    }
  },
  itemBuilder: (BuildContext context) => [
    PopupMenuItem(
      value: 'settings',
      child: ListTile(
        leading: Icon(Icons.settings),
        title: Text('Settings'),
        dense: true,
      ),
    ),
  ],
)
```

### Best Practices Learned

1. **Type Safety**: Always use proper null safety with `?` and `!` operators
2. **Async Handling**: Use `async`/`await` properly and handle mounted state
3. **Resource Management**: Close boxes and dispose controllers properly
4. **Error Handling**: Always provide fallback values for database operations
5. **State Management**: Keep UI state separate from data state

### Configuration Management Pattern

#### 1. Settings Model Approach
- Create a dedicated model for app configuration
- Use Hive for persistence
- Provide sensible defaults
- Allow runtime changes with immediate persistence

#### 2. Conditional UI Rendering
```dart
if (config?.showFeature == true) ...[
  FeatureWidget(),
  SizedBox(height: 20),
],
```

This pattern allows for clean, conditional UI that responds to user preferences.

### Audio Enhancement Architecture

#### 1. Enhanced Models
- Rich metadata storage (bitrate, sample rate, channels)
- Waveform visualization data
- User annotations (tags, descriptions, ratings)
- Playback statistics and history

#### 2. Component Upgrade Strategy
- Keep existing simple components
- Add enhanced versions with more features
- Allow gradual migration through feature flags
- Maintain backwards compatibility

### Performance Considerations

1. **Lazy Loading**: Load data only when needed
2. **Efficient Queries**: Use `box.values.where()` for filtering
3. **Memory Management**: Don't keep large amounts of data in memory
4. **UI Responsiveness**: Use FutureBuilder for async operations

This integration demonstrates how to properly structure a Flutter app with persistent storage, configuration management, and progressive feature enhancement.

## Conditional UI Rendering Based on App State

### Session State Management Pattern

When building a pomodoro app, it's important to provide different experiences based on the current session state:

```dart
// Helper method to determine feature availability
bool get _shouldShowRecordingFeatures {
  // Only show during break or when stopped (not during active work session)
  return !isRunning || onBreak || canSubmitLog;
}

// Usage in UI
if (_shouldShowRecordingFeatures) ...[
  _buildRecordingSection(),
  SizedBox(height: 20),
],
```

### DraggableScrollableSheet for Overflow Prevention

Instead of using `Column` which can overflow on small screens, use `DraggableScrollableSheet`:

```dart
body: DraggableScrollableSheet(
  initialChildSize: 1.0,
  minChildSize: 0.5,
  maxChildSize: 1.0,
  builder: (context, scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Your widgets here
        ],
      ),
    );
  },
),
```

### Benefits of This Approach

1. **Responsive Design**: Content automatically adjusts to different screen sizes
2. **Slideable Interface**: Users can drag to access content that might be off-screen
3. **State-Based UI**: Features appear/disappear based on app logic
4. **Better UX**: Prevents accidental interactions during focus periods

### Modular Widget Building

Breaking down complex UI into smaller methods improves maintainability:

```dart
Widget _buildTimerSection() { /* ... */ }
Widget _buildControlButtons() { /* ... */ }
Widget _buildRecordingSection() { /* ... */ }
```

This pattern makes the code easier to:
- Debug and test individual components
- Modify specific sections without affecting others
- Reuse components in different contexts
- Maintain consistent styling

### Focus Mode Implementation

Providing visual feedback when features are disabled enhances user understanding:

```dart
if (!_shouldShowRecordingFeatures && isRunning && !onBreak) ...[
  Container(
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue[200]!),
    ),
    child: Row(
      children: [
        Icon(Icons.work, color: Colors.blue),
        Text('Focus mode: Recording features disabled'),
      ],
    ),
  ),
],
```

This integration demonstrates how to properly structure a Flutter app with persistent storage, configuration management, progressive feature enhancement, and contextual UI behavior.

## Flutter Testing Performance: Why Tests Take So Long

### Common Causes of Slow Flutter Tests

#### 1. **Widget Test Setup Overhead**
Flutter widget tests create a full widget tree and rendering pipeline for each test:

```dart
// This creates a complete Flutter environment every time
testWidgets('My widget test', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp()); // Heavy initialization
  // Test logic here
});
```

**Why it's slow:**
- Creates a new `TestWidgetsFlutterBinding`
- Initializes the entire Flutter framework
- Sets up rendering, gesture detection, and accessibility
- Loads fonts and assets

#### 2. **Async Operations and `pumpAndSettle()`**
```dart
// This can be extremely slow
await tester.pumpAndSettle(); // Waits for ALL animations to complete

// Better approach - be specific
await tester.pump(Duration(milliseconds: 100)); // Pump once with duration
await tester.pumpAndSettle(Duration(seconds: 5)); // Set a timeout
```

**Why it's slow:**
- `pumpAndSettle()` waits for ALL animations to finish
- Some animations might run indefinitely
- Network requests or timers can cause infinite waiting

#### 3. **Integration Tests with Real Devices**
```dart
// Integration tests start the entire app
void main() {
  group('App Integration Tests', () {
    testWidgets('Full app flow', (tester) async {
      await tester.pumpWidget(MyApp()); // Starts entire app
      // Test real user flows
    });
  });
}
```

**Why it's slow:**
- Starts the complete application
- Initializes all services (databases, network, etc.)
- Real device/simulator performance limitations
- Platform channel communications

#### 4. **Dart VM Warmup and Compilation**
- **JIT Compilation**: Dart compiles code on-demand during tests
- **Cold Start**: First test run is always slower
- **Package Loading**: Loading all dependencies takes time

### Performance Optimization Strategies

#### 1. **Use Unit Tests for Business Logic**
```dart
// Fast unit test - no Flutter framework
test('Business logic test', () {
  final calculator = Calculator();
  expect(calculator.add(2, 3), equals(5));
});

// Instead of slow widget test for the same logic
testWidgets('Calculator widget test', (tester) async {
  // This is overkill for simple logic testing
});
```

#### 2. **Minimize Widget Tree Size**
```dart
// Slow - tests entire app
await tester.pumpWidget(MaterialApp(home: MyApp()));

// Fast - test only the widget you need
await tester.pumpWidget(
  MaterialApp(
    home: Material(
      child: MySpecificWidget(),
    ),
  ),
);
```

#### 3. **Mock Heavy Dependencies**
```dart
// Mock expensive services
class MockApiService extends Mock implements ApiService {}
class MockDatabaseService extends Mock implements DatabaseService {}

testWidgets('Widget with mocked dependencies', (tester) async {
  await tester.pumpWidget(
    MyWidget(
      apiService: MockApiService(),
      databaseService: MockDatabaseService(),
    ),
  );
});
```

#### 4. **Use `setUpAll()` and `tearDownAll()`**
```dart
group('Multiple related tests', () {
  late MyExpensiveService service;

  setUpAll(() async {
    // Initialize once for all tests in this group
    service = await MyExpensiveService.initialize();
  });

  tearDownAll(() async {
    await service.dispose();
  });

  test('Test 1', () { /* uses service */ });
  test('Test 2', () { /* uses service */ });
});
```

#### 5. **Optimize Pump Strategies**
```dart
// Slow - waits for everything
await tester.pumpAndSettle();

// Fast - specific pumping
await tester.pump(); // Single frame
await tester.pump(Duration(milliseconds: 16)); // One frame at 60fps
await tester.pumpAndSettle(Duration(seconds: 2)); // With timeout
```

#### 6. **Golden Tests for Visual Regression**
```dart
// Faster than interaction tests for visual validation
testWidgets('Golden test', (tester) async {
  await tester.pumpWidget(MyWidget());
  await expectLater(
    find.byType(MyWidget),
    matchesGoldenFile('my_widget.png'),
  );
});
```

### Test Structure Best Practices

#### 1. **Test Pyramid Strategy**
```
Integration Tests (Few, Slow)
       ↑
Widget Tests (Some, Medium)
       ↑  
Unit Tests (Many, Fast)
```

#### 2. **Group Related Tests**
```dart
void main() {
  group('User Authentication', () {
    // All auth-related tests together
    // Share setup/teardown
  });

  group('Data Persistence', () {
    // All database tests together
  });
}
```

#### 3. **Use Test Tags for Selective Running**
```dart
@Tags(['unit'])
test('Fast unit test', () { /* ... */ });

@Tags(['integration'])
testWidgets('Slow integration test', (tester) async { /* ... */ });
```

Run specific tests:
```bash
flutter test --tags unit        # Run only unit tests
flutter test --exclude-tags integration  # Skip slow tests
```

### Common Performance Pitfalls

#### 1. **Testing Implementation Details**
```dart
// Bad - tests internal state
expect(widget.controller.isListening, isTrue);

// Good - tests user-visible behavior
expect(find.text('Expected Result'), findsOneWidget);
```

#### 2. **Over-testing UI Interactions**
```dart
// Slow - testing every possible tap
await tester.tap(find.byKey(Key('button1')));
await tester.pump();
await tester.tap(find.byKey(Key('button2')));
await tester.pump();
// ... testing every single interaction

// Better - test critical paths only
```

#### 3. **Not Using `skip` for Broken Tests**
```dart
testWidgets('Temporarily broken test', (tester) async {
  // Don't let broken tests slow down the suite
}, skip: 'Investigating performance issue');
```

### Measuring Test Performance

#### 1. **Profile Test Execution**
```bash
flutter test --reporter=json > test_results.json
# Analyze timing data from JSON output
```

#### 2. **Use Test Timing**
```dart
test('Timed test', () async {
  final stopwatch = Stopwatch()..start();
  
  // Your test logic here
  
  stopwatch.stop();
  print('Test took: ${stopwatch.elapsedMilliseconds}ms');
});
```

### Real-World Example: Optimizing Audio Tests

```dart
// Before: Slow test
testWidgets('Audio player test', (tester) async {
  await tester.pumpWidget(MyApp()); // Starts entire app
  await tester.pumpAndSettle(); // Waits for everything
  
  await tester.tap(find.byIcon(Icons.play_arrow));
  await tester.pumpAndSettle(); // Waits for all animations
  
  expect(find.text('Playing'), findsOneWidget);
});

// After: Fast test
testWidgets('Audio player test', (tester) async {
  final mockAudioService = MockAudioService();
  
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: AudioPlayer(audioService: mockAudioService),
      ),
    ),
  );
  
  await tester.tap(find.byIcon(Icons.play_arrow));
  await tester.pump(); // Single pump
  
  expect(find.text('Playing'), findsOneWidget);
  verify(mockAudioService.play()).called(1);
});
```

### Summary: Making Tests Faster

1. **Use the right test type**: Unit tests for logic, widget tests for UI behavior
2. **Mock dependencies**: Don't initialize real services in tests
3. **Minimize widget trees**: Test only what you need
4. **Be specific with pumping**: Avoid `pumpAndSettle()` when possible
5. **Use test tags**: Run fast tests frequently, slow tests less often
6. **Profile and measure**: Identify actual bottlenecks
7. **Test behavior, not implementation**: Focus on user-visible outcomes

**Remember**: Fast tests get run more often, leading to better code quality and faster development cycles!

## Audio Asset Management with JSON Mapping

### Dynamic Audio Asset Organization Pattern

When managing a large number of audio files in Flutter, hardcoding file paths becomes unmaintainable. This pattern demonstrates a scalable approach:

#### 1. **Automated File Organization**
```dart
// Dart script that renames files systematically
final newName = 'lofi_${counter.toString().padLeft(3, '0')}.mp3';
await file.renameSync(newPath);
```

**Benefits:**
- Consistent naming scheme
- Easier to reference programmatically
- Better organization for large asset collections

#### 2. **JSON Metadata Mapping**
```json
{
  "version": "1.0",
  "generated": "2025-09-25T10:41:59.556245",
  "total_tracks": 41,
  "tracks": [
    {
      "id": 1,
      "filename": "lofi_001.mp3",
      "originalName": "10-lady-of-the-80x27s-128379",
      "title": "Lady Of The 80's",
      "author": "Unknown Artist",
      "site": "Freesound/Pixabay",
      "duration": "6:37",
      "fileSize": 5743
    }
  ]
}
```

**Advantages:**
- Rich metadata without filename clutter
- Easy to search and filter
- Version tracking for asset updates
- Internationalization-ready

#### 3. **Service Layer Abstraction**
```dart
class LofiService {
  static Future<List<LofiTrack>> getAllTracks() async {
    final mapping = await getLofiMapping();
    return mapping.tracks;
  }

  static Future<LofiTrack?> getTrackById(int id) async {
    final mapping = await getLofiMapping();
    try {
      return mapping.tracks.firstWhere((track) => track.id == id);
    } catch (e) {
      return null;
    }
  }
}
```

#### 4. **Background Music Service Pattern**
```dart
class BackgroundMusicService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<LofiTrack> _playlist = [];

  Future<void> playRandomTrack() async {
    if (_playlist.isEmpty) {
      await _refreshPlaylist();
    }
    _playlist.shuffle();
    _currentTrack = _playlist.first;
    await _playCurrentTrack();
  }
}
```

### Asset Management Best Practices

#### 1. **Pubspec.yaml Optimization**
Instead of listing every file:
```yaml
# Bad - Hard to maintain
assets:
  - assets/lofi/track1.mp3
  - assets/lofi/track2.mp3
  # ... 40 more files

# Good - Directory-based inclusion
assets:
  - assets/lofi/
```

#### 2. **Automated Asset Organization**
Create scripts that:
- Rename files with consistent patterns
- Extract metadata from filenames
- Generate JSON mappings automatically
- Update mappings when new files are added

#### 3. **Runtime Asset Discovery**
```dart
// Load available tracks dynamically
final tracks = await LofiService.getAllTracks();
final randomTrack = await LofiService.getRandomTrack();
final durationFiltered = await LofiService.getTracksByDurationRange(
  minDuration: Duration(minutes: 3),
  maxDuration: Duration(minutes: 8),
);
```

### Integration with Existing Code

#### 1. **Gradual Migration Pattern**
When refactoring existing hardcoded asset lists:

```dart
// Before: Hardcoded playlist
List<String> lofiPlaylist = [
  'lofi/old-track-1.mp3',
  'lofi/old-track-2.mp3',
  // ... many hardcoded entries
];

// After: Dynamic service-based approach
void _playLofi() async {
  try {
    await _backgroundMusicService.playRandomTrack();
    final currentTrack = _backgroundMusicService.currentTrack;
    // Use rich metadata instead of filename parsing
  } catch (e) {
    // Graceful error handling
  }
}
```

#### 2. **Backward Compatibility**
Keep old audio player as fallback while introducing new service:

```dart
final _bgPlayer = ap.AudioPlayer(); // Legacy player
final _backgroundMusicService = BackgroundMusicService(); // New service

// Use new service but keep old one for compatibility
```

### Maintenance and Updates

#### 1. **Simple Update Scripts**
```batch
@echo off
echo Updating lofi audio mapping...
dart scripts/lofi_organizer.dart
echo Done! Run 'flutter clean' if you added new files.
```

#### 2. **Version Control**
- JSON mapping files should be version controlled
- Audio files themselves might be `.gitignore`d due to size
- Scripts and utilities should be committed

#### 3. **Metadata Enhancement**
Future improvements can add:
- BPM detection for tempo matching
- Mood categorization
- User rating systems
- Playlist generation based on session duration
- Audio analysis for volume normalization

### Performance Considerations

#### 1. **Lazy Loading**
```dart
static LofiMapping? _cachedMapping;

static Future<LofiMapping> getLofiMapping() async {
  if (_cachedMapping != null) {
    return _cachedMapping!;
  }
  // Load and cache on first use
}
```

#### 2. **Efficient Asset Access**
- Cache JSON mapping in memory
- Use asset bundle for fast file access
- Consider compression for metadata files

#### 3. **Memory Management**
- Don't load all audio files at once
- Stream audio content when needed
- Dispose audio players properly

This pattern scales well from small apps to large applications with hundreds of audio assets, providing a maintainable and extensible solution for dynamic asset management.

## Event-Driven Sound Effects System

### Contextual Audio Feedback Implementation

In productivity apps like pomodoro timers, providing audio feedback for different events enhances the user experience and helps maintain focus flow.

#### 1. **Sound Event Mapping Pattern**
```dart
enum SoundEvent {
  audioRecordSubmitted, // s01 - when audio record is submitted
  breakTimeStarts,      // s01 - when break time starts
  workTimeCompleted,    // s03 - when work time is completed
  breakTimeEnds,        // s02 - when break time ends
}

static const Map<SoundEvent, String> _soundFiles = {
  SoundEvent.audioRecordSubmitted: 'audio/s01-video-game-bonus-323603.mp3',
  SoundEvent.breakTimeStarts: 'audio/s01-video-game-bonus-323603.mp3',
  SoundEvent.workTimeCompleted: 'audio/s03-positive-notification-new-level-152480.mp3',
  SoundEvent.breakTimeEnds: 'audio/s02-level-up-4-243762.mp3',
};
```

**Benefits:**
- Type-safe event definitions
- Centralized sound file management
- Easy to modify sound mappings
- Multiple events can share the same sound file

#### 2. **Singleton Service Pattern for Audio**
```dart
class SoundEffectsService {
  static final SoundEffectsService _instance = SoundEffectsService._internal();
  factory SoundEffectsService() => _instance;
  SoundEffectsService._internal();

  final AudioPlayer _soundPlayer = AudioPlayer();
  bool _soundEffectsEnabled = true;
  double _soundVolume = 0.8;
}
```

**Advantages:**
- Single audio player instance to avoid conflicts
- Global volume and enable/disable controls
- Memory efficient - only one service instance
- Easy to integrate across multiple screens

#### 3. **Strategic Event Integration**
```dart
// Work session completed
if (!onBreak) {
  _soundEffectsService.playWorkTimeCompleted(); // s03 - achievement sound
  setState(() {
    isRunning = false;
    canSubmitLog = true;
  });
}

// Break time starts (user submits log)
void submitLog() {
  saveSession();
  _soundEffectsService.playBreakTimeStarts(); // s01 - positive feedback
  setState(() {
    onBreak = true;
  });
}

// Audio recording completed
onRecordingComplete: (audioModel) {
  _soundEffectsService.playAudioRecordSubmitted(); // s01 - confirmation
  setState(() {
    canSubmitLog = true;
  });
}
```

### Sound Design Psychology

#### 1. **Audio Cue Associations**
- **s01 (Bonus)**: Positive actions - recording completion, break start
- **s02 (Level Up)**: Transitions - break end, ready for work
- **s03 (Achievement)**: Accomplishments - work session completion

#### 2. **Volume and Control**
```dart
void setSoundVolume(double volume) {
  _soundVolume = volume.clamp(0.0, 1.0);
}

void setSoundEffectsEnabled(bool enabled) {
  _soundEffectsEnabled = enabled;
}

Future<void> playSound(SoundEvent event) async {
  if (!_soundEffectsEnabled) return;
  // Play sound with proper volume and error handling
}
```

### Testing Challenges with Audio Services

#### 1. **Platform Channel Dependencies**
Audio plugins like `audioplayers` require platform channels that aren't available in unit tests:

```dart
// This will fail in unit tests
test('Should play sound', () {
  final service = SoundEffectsService();
  service.playWorkTimeCompleted(); // MissingPluginException
});
```

#### 2. **Testing Strategies**
- **Unit Tests**: Test business logic (volume control, enable/disable)
- **Integration Tests**: Test actual audio playback on real devices
- **Mock Services**: Create mock implementations for UI tests

```dart
// Better approach - test the logic, not the platform integration
test('Should respect enabled/disabled state', () {
  final service = SoundEffectsService();
  service.setSoundEffectsEnabled(false);
  expect(service.soundEffectsEnabled, isFalse);
});
```

#### 3. **Error Handling**
```dart
Future<void> playSound(SoundEvent event) async {
  if (!_soundEffectsEnabled) return;

  try {
    final soundFile = _soundFiles[event];
    if (soundFile == null) return;

    await _soundPlayer.setVolume(_soundVolume);
    await _soundPlayer.play(AssetSource(soundFile));
  } catch (e) {
    print('Failed to play sound: $e');
    // Fail silently - don't break app functionality
  }
}
```

### Integration Best Practices

#### 1. **Asset Organization**
```yaml
# pubspec.yaml
assets:
  - assets/audio/    # Sound effects directory
  - assets/lofi/     # Background music directory
```

#### 2. **Service Lifecycle Management**
```dart
@override
void dispose() {
  timer?.cancel();
  _backgroundMusicService.dispose();
  _soundEffectsService.dispose(); // Clean up audio resources
  super.dispose();
}
```

#### 3. **Non-Blocking Implementation**
```dart
// Don't await sound effects - they should be fire-and-forget
_soundEffectsService.playWorkTimeCompleted(); // No await
setState(() {
  // Continue with UI updates immediately
});
```

### Future Enhancements

#### 1. **User Customization**
- Allow users to upload custom sound files
- Sound theme selection (game sounds, nature sounds, etc.)
- Per-event volume controls

#### 2. **Context Awareness**
- Different sounds for different times of day
- Intensity-based sounds (louder for longer work sessions)
- Silent mode during specific hours

#### 3. **Analytics Integration**
- Track which sounds are most effective for focus
- A/B test different sound combinations
- User preference learning

This event-driven sound effects system enhances user experience by providing immediate, contextual audio feedback while maintaining clean architecture and proper error handling.

## Flutter Local Notifications with Android Integration

### Background Timer Notifications Implementation

When building productivity apps like pomodoro timers, users need to see timer progress and controls even when the app is in the background. This requires proper notification setup with Android permissions.

#### 1. **Notification Service Architecture**
```dart
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _updateTimer;
  int _remainingSeconds = 0;
}
```

**Key Design Decisions:**
- Singleton pattern ensures single notification instance
- Internal timer for countdown updates
- State tracking for pause/resume functionality

#### 2. **Android Manifest Permissions**
```xml
<!-- Required for notification functionality -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

**Permission Rationale:**
- `POST_NOTIFICATIONS`: Required for Android 13+ notification display
- `WAKE_LOCK`: Keep timer running when screen is off
- `VIBRATE`: Optional vibration for timer completion
- `FOREGROUND_SERVICE`: For persistent timer notifications

#### 3. **Ongoing Notification Configuration**
```dart
final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
  'pomodoro_timer',
  'Pomodoro Timer',
  channelDescription: 'Notification for pomodoro timer controls',
  importance: Importance.low,         // Avoid interrupting user
  priority: Priority.low,             // Less intrusive
  ongoing: true,                      // Cannot be swiped away
  autoCancel: false,                  // Persist until manually cleared
  showWhen: false,                    // Don't show timestamp
  category: AndroidNotificationCategory.stopwatch,
  actions: _buildNotificationActions(isRunning),
);
```

**Configuration Benefits:**
- Low importance/priority prevents interruption
- Ongoing status keeps notification persistent
- Stopwatch category optimizes for timer use case
- Action buttons provide direct control

#### 4. **Real-time Timer Updates**
```dart
void _startUpdateTimer() {
  _hasActiveTimer = true;
  _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      _updateNotificationTime();
    } else {
      _stopUpdateTimer();
    }
  });
}

void _updateNotificationTime() {
  final String timeText = formatTime(_remainingSeconds);
  final String status = _isBreak ? 'Break' : 'Focus';
  final String title = '$status Time - $timeText';

  _notifications.show(1, title, 'Tap to open app', notificationDetails);
}
```

**Update Strategy:**
- Separate timer for notification updates
- Efficient string formatting for countdown display
- Memory management with proper timer disposal

#### 5. **App Lifecycle Integration**
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  if (state == AppLifecycleState.resumed) {
    _loadProjects();
  } else if (state == AppLifecycleState.paused ||
             state == AppLifecycleState.inactive) {
    if (isRunning) {
      _notificationService.showTimerNotification(
        remainingSeconds: remainingSeconds,
        isRunning: isRunning,
        isBreak: onBreak,
        onPlay: startTimer,
        onPause: stopTimer,
        onStop: resetTimer,
      );
    }
  }
}
```

**Lifecycle Management:**
- Show notification when app goes to background
- Hide notification when app returns to foreground
- Maintain timer state consistency

#### 6. **Notification Action Callbacks**
```dart
void _onNotificationTap(NotificationResponse notificationResponse) {
  final String? payload = notificationResponse.payload;

  switch (payload) {
    case 'play':
      _onPlay?.call();
      break;
    case 'pause':
      _onPause?.call();
      break;
    case 'stop':
      _onStop?.call();
      break;
  }
}

List<AndroidNotificationAction> _buildNotificationActions(bool isRunning) {
  return [
    if (isRunning)
      const AndroidNotificationAction('pause', 'Pause', cancelNotification: false)
    else
      const AndroidNotificationAction('play', 'Play', cancelNotification: false),
    const AndroidNotificationAction('stop', 'Stop', cancelNotification: false),
  ];
}
```

**Action System:**
- Dynamic action buttons based on current state
- Callback system links notifications to app logic
- Non-canceling actions maintain notification persistence

### Testing and Debugging Notifications

#### 1. **Test Button Implementation**
```dart
Future<void> _testNotification() async {
  try {
    await _notificationService.initialize();
    await _notificationService.showTimerNotification(
      remainingSeconds: 1500, // 25:00
      isRunning: true,
      isBreak: false,
      onPlay: () => _showTestResult('Play button pressed!'),
      onPause: () => _showTestResult('Pause button pressed!'),
      onStop: () => _showTestResult('Stop button pressed!'),
    );
  } catch (e) {
    _showError('Failed to send notification: $e');
  }
}
```

**Testing Benefits:**
- Manual notification testing without timer dependency
- Immediate feedback on notification functionality
- Easy debugging of permission issues

#### 2. **Common Debugging Issues**
- **Permissions**: Android 13+ requires runtime permission requests
- **Initialization**: Service must be initialized before use
- **Channel Registration**: Notification channels must be created first
- **Action IDs**: Unique action identifiers prevent conflicts

#### 3. **Error Handling Patterns**
```dart
Future<void> showTimerNotification({...}) async {
  if (!_isInitialized) await initialize();

  try {
    await _notifications.show(1, title, body, notificationDetails);
  } catch (e) {
    print('Notification error: $e');
    // Fail gracefully - don't crash the app
  }
}
```

**Resilience Strategies:**
- Graceful degradation when notifications fail
- Silent error handling to maintain app stability
- Automatic initialization attempts

### Integration Best Practices

#### 1. **Service Initialization Order**
```dart
void _safeInitialize() async {
  try {
    await _loadConfig();
    await _loadUserSettings();
    await _backgroundMusicService.initialize();
    await _notificationService.initialize(); // After other services
    // Continue with app setup
  } catch (e) {
    // Handle initialization errors
  }
}
```

#### 2. **Resource Cleanup**
```dart
@override
void dispose() {
  timer?.cancel();
  _backgroundMusicService.dispose();
  _soundEffectsService.dispose();
  _notificationService.dispose(); // Clean up notification timers
  super.dispose();
}
```

#### 3. **State Synchronization**
- Ensure notification state matches app timer state
- Handle edge cases like app termination during timer
- Provide user feedback for notification permissions

### Performance Considerations

#### 1. **Efficient Updates**
- Only update notification text when time changes
- Batch multiple state changes
- Use lightweight string formatting

#### 2. **Memory Management**
- Cancel timers when not needed
- Dispose of notification plugin properly
- Avoid memory leaks in callback functions

#### 3. **Battery Optimization**
- Use low-priority notifications
- Minimize update frequency when appropriate
- Respect system doze mode and app standby

This notification implementation provides seamless background timer functionality while maintaining good Android citizenship and user experience standards.

## Image Overlay UI Pattern with Stack Widgets

### Full-Screen Image Cards with Text Overlays

When creating motivational cards or visual content that combines images with text, Flutter's `Stack` widget provides powerful layering capabilities.

#### 1. **Stack Widget Fundamentals**
```dart
Stack(
  fit: StackFit.expand,  // Children fill the entire stack
  children: [
    // Layer 1: Background image
    Image.file(File(imagePath), fit: BoxFit.cover),

    // Layer 2: Dark overlay for text readability
    Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
    ),

    // Layer 3: Text content
    Center(
      child: Text('Motivational text here',
        style: TextStyle(
          color: Colors.white,
          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
        ),
      ),
    ),
  ],
)
```

**Key Concepts:**
- **StackFit.expand**: Makes all children fill the available space
- **BoxFit.cover**: Image fills width while maintaining aspect ratio
- **Gradient Overlay**: Improves text readability over images
- **Text Shadows**: Ensures text visibility regardless of background

#### 2. **Dynamic Image Handling**
```dart
if (card.imagePath != null && File(card.imagePath!).existsSync())
  Image.file(File(card.imagePath!), fit: BoxFit.cover)
else
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).primaryColor.withOpacity(0.7),
          Theme.of(context).primaryColor,
        ],
      ),
    ),
  )
```

**Benefits:**
- Graceful fallback when no image is provided
- File existence check prevents runtime errors
- Themed gradient maintains visual consistency
- Null safety with proper null checking

#### 3. **Hive Storage for Images**
```dart
@HiveType(typeId: 23)
class MotivationalCardModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  String? imagePath;  // Store file path, not the image itself

  @HiveField(3)
  DateTime createdAt;
}
```

**Storage Strategy:**
- Store file paths, not binary data
- Use `path_provider` to get app directory
- Copy picked images to persistent location
- Clean up image files when deleting cards

#### 4. **Image Picker Integration**
```dart
Future<String?> pickImageFromGallery() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile == null) return null;

  // Save to app directory with unique filename
  final dir = await getApplicationDocumentsDirectory();
  final fileName = 'card_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final newPath = '${dir.path}/$fileName';
  final newFile = await File(pickedFile.path).copy(newPath);

  return newFile.path;
}
```

**Implementation Details:**
- Unique filenames prevent collisions
- Files stored in app documents directory
- Original file copied to permanent location
- Returns path for database storage

#### 5. **Grid View for Card Display**
```dart
GridView.builder(
  padding: const EdgeInsets.all(16),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 0.75,  // Portrait cards
  ),
  itemCount: cards.length,
  itemBuilder: (context, index) => _buildCardTile(cards[index]),
)
```

**Layout Benefits:**
- Responsive grid adapts to screen size
- Fixed aspect ratio maintains card proportions
- Proper spacing for touch targets
- Efficient item building with builder pattern

#### 6. **Full-Screen Detail View**
```dart
Scaffold(
  backgroundColor: Colors.black,
  extendBodyBehindAppBar: true,  // AppBar transparent over content
  appBar: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  body: GestureDetector(
    onTap: () => Navigator.pop(context),  // Tap to close
    child: Stack(/* content */),
  ),
)
```

**UX Features:**
- Immersive full-screen experience
- Transparent app bar with back button
- Tap-anywhere to close
- Black background for focus

### Service Layer Pattern for Feature Modules

#### 1. **Dedicated Service Class**
```dart
class MotivationalCardService {
  static const String _boxName = 'motivationalCards';

  List<MotivationalCardModel> getAllCards() {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    return box.values.toList();
  }

  Future<MotivationalCardModel> createCard({
    required String text,
    String? imagePath,
  }) async {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    final card = MotivationalCardModel(/* ... */);
    await box.add(card);
    return card;
  }

  Future<void> deleteCard(String id) async {
    final box = Hive.box<MotivationalCardModel>(_boxName);
    // Delete from database and clean up image file
  }
}
```

**Service Benefits:**
- Centralized business logic
- Consistent error handling
- Easy to test independently
- Reusable across multiple screens

#### 2. **ValueListenableBuilder for Reactive UI**
```dart
ValueListenableBuilder(
  valueListenable: Hive.box<MotivationalCardModel>('motivationalCards').listenable(),
  builder: (context, Box<MotivationalCardModel> box, _) {
    final cards = box.values.toList();

    if (cards.isEmpty) {
      return EmptyState();
    }

    return GridView.builder(/* ... */);
  },
)
```

**Reactivity Benefits:**
- Automatic UI updates when data changes
- No manual setState() calls needed
- Efficient re-rendering
- Clean separation of concerns

### Navigation Integration Patterns

#### 1. **Tab-Based Navigation**
```dart
TabController(length: 3, vsync: this);  // Add new tab

TabBar(
  controller: _tabController,
  tabs: [
    Tab(icon: Icon(Icons.card_giftcard), text: 'Rewards'),
    Tab(icon: Icon(Icons.history), text: 'History'),
    Tab(icon: Icon(Icons.auto_awesome), text: 'Motivation'),  // New tab
  ],
)

TabBarView(
  controller: _tabController,
  children: [
    RewardsTab(),
    HistoryTab(),
    MotivationalCardsScreen(),  // New screen
  ],
)
```

**Integration Strategy:**
- Add to existing screen as new tab
- Maintains navigation context
- Logical grouping with related features
- No changes to bottom navigation bar

#### 2. **Empty State UI**
```dart
if (cards.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome, size: 64, color: Colors.grey[400]),
        SizedBox(height: 16),
        Text('No motivational cards yet'),
        SizedBox(height: 8),
        Text('Tap the + button to create your first card'),
        SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _navigateToAddCard,
          icon: Icon(Icons.add),
          label: Text('Create Card'),
        ),
      ],
    ),
  );
}
```

**UX Best Practices:**
- Clear empty state messaging
- Visual icon for context
- Call-to-action button
- Helpful guidance text

### Testing Considerations

#### 1. **Image File Testing**
- Mock file system operations
- Use test fixtures for image paths
- Test both with and without images
- Verify cleanup on deletion

#### 2. **Service Testing**
- Test CRUD operations
- Verify Hive box interactions
- Test error handling paths
- Mock image picker for unit tests

#### 3. **UI Testing**
- Test navigation flows
- Verify empty states
- Test image display
- Test overlay text rendering

This pattern demonstrates building a complete feature module with image handling, persistent storage, service layer architecture, and seamless navigation integration - all following Flutter best practices for maintainable, scalable code.

## YAML-Based Theme System Architecture

### Centralized Theme Management with Asset Configuration

When building apps with multiple visual themes, managing colors, fonts, and sizes across numerous files becomes unmaintainable. A YAML-based theme system provides a single source of truth for all visual styling.

#### 1. **YAML Theme Configuration Structure**
```yaml
default:
  name: "Default"
  colors:
    color1: "#9C27B0"  # 5 core colors
    color2: "#2196F3"
    color3: "#4CAF50"
    color4: "#FF9800"
    color5: "#F44336"
  backgrounds:
    primary: "#FFFFFF"    # 6 background variants
    secondary: "#F5F5F5"
    surface: "#FFFFFF"
    dark: "#121212"       # Dark mode equivalents
    darkSecondary: "#1E1E1E"
    darkSurface: "#2C2C2C"
  fonts:
    primary: "Roboto"     # 3 font families
    secondary: "Poppins"
    monospace: "Courier"
  fontSizes:
    small: 12.0           # 3 base font sizes
    medium: 16.0
    large: 24.0
```

**Design Rationale:**
- **5 Colors**: Provides enough variety without overwhelming
- **6 Backgrounds**: Covers light/dark mode with variations
- **3 Fonts**: Primary text, headings, and code/monospace
- **3 Sizes**: Small, medium, large with derived sizes

#### 2. **Theme Model Architecture**
```dart
class AppTheme {
  final String name;
  final ThemeColors colors;          // 5 colors
  final ThemeBackgrounds backgrounds; // 6 backgrounds
  final ThemeFonts fonts;            // 3 fonts
  final ThemeFontSizes fontSizes;    // 3 base sizes

  factory AppTheme.fromMap(Map<dynamic, dynamic> map) {
    // Parse YAML into typed models
  }
}

class ThemeFontSizes {
  final double small, medium, large;

  // Derived sizes calculated from base sizes
  double get xSmall => small * 0.9;
  double get xLarge => large * 1.2;
  double get caption => small;
  double get body => medium;
  double get heading => large;
}
```

**Type Safety Benefits:**
- Compile-time checking for theme properties
- Auto-complete in IDE
- Clear documentation through types
- Derived values calculated consistently

#### 3. **YAML Loader with Caching**
```dart
class ThemeLoader {
  static Map<String, AppTheme>? _cachedThemes;
  static const String _themesPath = 'assets/themes/themes.yaml';

  static Future<Map<String, AppTheme>> loadThemes() async {
    if (_cachedThemes != null) return _cachedThemes!;

    final yamlString = await rootBundle.loadString(_themesPath);
    final yamlMap = loadYaml(yamlString);

    final themes = <String, AppTheme>{};
    yamlMap.forEach((key, value) {
      themes[key.toString()] = AppTheme.fromMap(value);
    });

    _cachedThemes = themes;
    return themes;
  }
}
```

**Performance Optimizations:**
- Load YAML once and cache in memory
- Async loading prevents UI blocking
- Fallback to default theme if loading fails
- Clear cache method for development hot reload

#### 4. **Theme Manager Service**
```dart
class ThemeManager {
  static AppTheme? _currentTheme;
  static String _currentThemeKey = 'default';

  static Future<void> initialize({String themeKey = 'default'}) async {
    final theme = await ThemeLoader.loadTheme(themeKey);
    await setTheme(theme, themeKey);
  }

  static Future<bool> switchTheme(String themeKey) async {
    final theme = await ThemeLoader.loadTheme(themeKey);
    await setTheme(theme, themeKey);
    return true;
  }

  static Future<List<String>> getAvailableThemes() async {
    return await ThemeLoader.getThemeKeys();
  }
}
```

**Manager Responsibilities:**
- Initialize theme system at app startup
- Switch themes at runtime
- Query available themes
- Handle theme loading errors gracefully

#### 5. **Integration with Color Palette**
```dart
class AppColorPalette {
  // Static colors (backwards compatible)
  static const Color color1 = Color(0xFF9C27B0);
  static const Color color2 = Color(0xFF2196F3);

  // Dynamic theme system
  static AppTheme? _activeTheme;

  static void setActiveTheme(AppTheme theme) {
    _activeTheme = theme;
  }

  // Theme-aware getters
  static Color get themeColor1 => _activeTheme?.colors.color1 ?? color1;
  static Color get themeColor2 => _activeTheme?.colors.color2 ?? color2;

  // Theme backgrounds
  static Color get backgroundPrimary =>
      _activeTheme?.backgrounds.primary ?? white;

  // Theme fonts
  static String get fontPrimary =>
      _activeTheme?.fonts.primary ?? 'Roboto';

  // Theme sizes
  static double get fontSizeMedium =>
      _activeTheme?.fontSizes.medium ?? 16.0;
}
```

**Backwards Compatibility:**
- Static colors still work (don't change with themes)
- Theme-aware getters use active theme or fallback
- Gradual migration path from static to dynamic
- No breaking changes to existing code

#### 6. **Usage Patterns**

**Initialization:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.initialize(themeKey: 'default');
  runApp(MyApp());
}
```

**Runtime Theme Switching:**
```dart
DropdownButton<String>(
  value: currentTheme,
  items: ['default', 'warm', 'cool']
      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
      .toList(),
  onChanged: (value) async {
    if (value != null) {
      await ThemeManager.switchTheme(value);
      setState(() {});  // Rebuild with new theme
    }
  },
)
```

**Using Theme Values:**
```dart
// Colors
Container(color: AppColorPalette.themeColor1);

// Backgrounds
Scaffold(backgroundColor: AppColorPalette.backgroundPrimary);

// Fonts and sizes
Text('Hello', style: TextStyle(
  fontFamily: AppColorPalette.fontPrimary,
  fontSize: AppColorPalette.fontSizeMedium,
));
```

### Benefits of YAML-Based Themes

#### 1. **Non-Developer Friendly**
- Designers can edit themes without touching code
- Quick experimentation with color schemes
- No compilation needed to preview changes
- Easy A/B testing of different themes

#### 2. **Centralized Configuration**
- Single file contains all theme variants
- Easy to version control
- Clear documentation of available themes
- Prevents color/font inconsistencies

#### 3. **Runtime Flexibility**
- Switch themes without app restart
- Load custom themes from server
- User-created themes possible
- Theme marketplace potential

#### 4. **Maintenance Benefits**
- Update entire app's look from one file
- No need to search/replace across codebase
- Theme changes isolated from business logic
- Easy to add new themes

### Common Patterns and Best Practices

#### 1. **Theme File Organization**
```
assets/
  themes/
    themes.yaml        # All themes in one file
    custom/           # Optional user themes
      user_theme_1.yaml
```

#### 2. **Pubspec.yaml Configuration**
```yaml
dependencies:
  yaml: ^3.1.2  # YAML parsing

flutter:
  assets:
    - assets/themes/
```

#### 3. **Error Handling**
```dart
try {
  await ThemeManager.initialize(themeKey: userPreference);
} catch (e) {
  print('Theme loading failed: $e');
  // App continues with default static colors
}
```

#### 4. **Development Workflow**
```dart
// Hot reload support
if (kDebugMode) {
  FloatingActionButton(
    onPressed: () async {
      await ThemeManager.reloadThemes();
      setState(() {});
    },
    child: Icon(Icons.refresh),
  );
}
```

### Testing Strategies

#### 1. **Theme Loading Tests**
```dart
test('Should load all themes from YAML', () async {
  final themes = await ThemeLoader.loadThemes();
  expect(themes.containsKey('default'), isTrue);
  expect(themes.containsKey('warm'), isTrue);
});
```

#### 2. **Color Parsing Tests**
```dart
test('Should parse hex colors correctly', () {
  final color = ThemeColors.parseColor('#FF0000', Colors.black);
  expect(color, equals(Color(0xFFFF0000)));
});
```

#### 3. **Fallback Tests**
```dart
test('Should fallback to static colors when no theme', () {
  AppColorPalette.setActiveTheme(null);
  expect(AppColorPalette.themeColor1, equals(AppColorPalette.color1));
});
```

### Performance Considerations

#### 1. **Caching Strategy**
- Load YAML once at startup
- Cache parsed theme objects in memory
- Clear cache only when needed (development)
- Minimal memory footprint (themes are small)

#### 2. **Build Performance**
- No code generation needed
- No build_runner overhead
- Fast hot reload
- Instant theme switching

#### 3. **Runtime Performance**
- Theme getters are simple property accesses
- No expensive calculations
- Derived font sizes cached in model
- Negligible performance impact

### Migration Path from Static Colors

#### Step 1: Add Theme System (No Breaking Changes)
```dart
// Old code still works
Container(color: AppColorPalette.color1);
```

#### Step 2: Gradually Update to Theme-Aware
```dart
// Update to use theme colors
Container(color: AppColorPalette.themeColor1);
```

#### Step 3: Remove Static Colors (Optional)
```dart
// Eventually deprecate static colors
@deprecated
static const Color color1 = Color(0xFF9C27B0);
```

### Advanced Features

#### 1. **Multiple Theme Files**
- Split themes into categories
- Load themes dynamically from server
- User-created theme support
- Theme marketplace/sharing

#### 2. **Theme Interpolation**
- Smooth color transitions between themes
- Animated theme switching
- Time-based theme changes

#### 3. **Conditional Theming**
- Different themes for different user types
- Feature-flag based theming
- A/B testing with themes
- Personalized color schemes

This YAML-based theme system demonstrates how to build a flexible, maintainable, and designer-friendly styling system that scales from small apps to large applications with complex theming requirements.