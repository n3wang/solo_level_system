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