

# Data Models Documentation

## Enhanced Model Architecture

The solo level system now features a comprehensive set of models for user settings, audio management, and Pomodoro session tracking.

## Model Relationships

```mermaid
classDiagram
    class PomodoroModel {
        +DateTime startTime
        +String? audioPath
        +String? imagePath
        +int? dayPomodoroNumber
        +String? duration
        +String? project_id
        +String? project_name
    }
    
    class UserSettingsModel {
        +String theme
        +String primaryColor
        +int defaultWorkMinutes
        +int defaultBreakMinutes
        +bool autoStartBreaks
        +bool autoStartWork
        +bool enableNotifications
        +bool enableSounds
        +String notificationSound
        +String audioQuality
        +String audioFormat
        +String defaultAudioPath
        +bool enableNoiseReduction
        +String language
        +String dateFormat
        +String timeFormat
        +bool enableAnalytics
        +bool autoBackup
        +String backupPath
    }
    
    class AudioSettingsModel {
        +String codec
        +int bitRate
        +int sampleRate
        +int channels
        +double playbackSpeed
        +double volume
        +bool enableEqualizer
        +List~double~ equalizerBands
        +bool enableNoiseReduction
        +double noiseReductionLevel
        +bool enableAutoGain
        +double gainLevel
        +bool enableCompression
        +double compressionRatio
        +bool showWaveform
        +String waveformColor
        +bool showSpectrogram
        +int fftSize
        +String exportFormat
        +int exportQuality
        +bool includeMetadata
    }
    
    class EnhancedAudioModel {
        +String filePath
        +String fileName
        +DateTime createdAt
        +DateTime? modifiedAt
        +int durationMs
        +int fileSizeBytes
        +String format
        +int bitRate
        +int sampleRate
        +int channels
        +String? title
        +String? description
        +List~String~ tags
        +String? category
        +int rating
        +String? transcription
        +List~double~? waveformData
        +int? waveformSamples
        +List~String~ processingHistory
        +String? originalFilePath
        +int playCount
        +DateTime? lastPlayedAt
        +int? lastPlayPosition
        +bool isShared
        +List~String~ sharedWith
        +bool isFavorite
        +bool isArchived
        +double? averageVolume
        +double? peakVolume
        +bool? hasSilence
        +List~double~? frequencySpectrum
    }
    
    class HiveObject {
        <<interface>>
    }
    
    class HomeScreen {
        +saveSession()
        +takePhoto()
        +startBreak()
        +stopTimer()
    }
    
    class SettingsScreen {
        +_loadSettings()
        +_saveUserSettings()
        +_saveAudioSettings()
    }
    
    class AudioManagementScreen {
        +_filterAndSortAudios()
        +_deleteAudio()
        +_exportAudio()
    }
    
    class EnhancedAudioPlayer {
        +_togglePlayback()
        +_changeSpeed()
        +_changeVolume()
    }
    
    class EnhancedAudioRecorder {
        +_startRecording()
        +_stopRecording()
        +_saveRecording()
    }
    
    PomodoroModel --|> HiveObject : extends
    UserSettingsModel --|> HiveObject : extends
    AudioSettingsModel --|> HiveObject : extends
    EnhancedAudioModel --|> HiveObject : extends
    
    HomeScreen ..> PomodoroModel : creates/saves
    HomeScreen ..> UserSettingsModel : reads
    
    SettingsScreen ..> UserSettingsModel : manages
    SettingsScreen ..> AudioSettingsModel : manages
    
    AudioManagementScreen ..> EnhancedAudioModel : manages
    AudioManagementScreen ..> EnhancedAudioRecorder : uses
    AudioManagementScreen ..> EnhancedAudioPlayer : uses
    
    EnhancedAudioPlayer ..> EnhancedAudioModel : plays
    EnhancedAudioPlayer ..> AudioSettingsModel : reads
    
    EnhancedAudioRecorder ..> EnhancedAudioModel : creates
    EnhancedAudioRecorder ..> AudioSettingsModel : reads
    
    PomodoroModel --> EnhancedAudioModel : audioPath reference
    
    note for PomodoroModel "TypeId: 0\nCore session tracking"
    note for UserSettingsModel "TypeId: 1\nUser preferences & app config"
    note for AudioSettingsModel "TypeId: 2\nAudio processing & playback settings"
    note for EnhancedAudioModel "TypeId: 3\nDetailed audio file metadata"
```

## Database Schema

```mermaid
erDiagram
    POMODORO_MODEL {
        int hive_field_0_start_time "DateTime startTime"
        string hive_field_1_audio_path "String? audioPath"
        string hive_field_2_image_path "String? imagePath"
        int hive_field_3_day_pomodoro_number "int? dayPomodoroNumber"
        string hive_field_4_duration "String? duration"
        string hive_field_5_project_id "String? project_id"
        string hive_field_6_project_name "String? project_name"
    }
    
    USER_SETTINGS_MODEL {
        string hive_field_0_theme "String theme"
        string hive_field_1_primary_color "String primaryColor"
        int hive_field_2_default_work_minutes "int defaultWorkMinutes"
        int hive_field_3_default_break_minutes "int defaultBreakMinutes"
        bool hive_field_4_auto_start_breaks "bool autoStartBreaks"
        bool hive_field_5_auto_start_work "bool autoStartWork"
        bool hive_field_6_enable_notifications "bool enableNotifications"
        bool hive_field_7_enable_sounds "bool enableSounds"
        string hive_field_8_notification_sound "String notificationSound"
        string hive_field_9_audio_quality "String audioQuality"
        string hive_field_10_audio_format "String audioFormat"
        string hive_field_11_default_audio_path "String defaultAudioPath"
        bool hive_field_12_enable_noise_reduction "bool enableNoiseReduction"
        string hive_field_13_language "String language"
        string hive_field_14_date_format "String dateFormat"
        string hive_field_15_time_format "String timeFormat"
        bool hive_field_16_enable_analytics "bool enableAnalytics"
        bool hive_field_17_auto_backup "bool autoBackup"
        string hive_field_18_backup_path "String backupPath"
    }
    
    AUDIO_SETTINGS_MODEL {
        string hive_field_0_codec "String codec"
        int hive_field_1_bit_rate "int bitRate"
        int hive_field_2_sample_rate "int sampleRate"
        int hive_field_3_channels "int channels"
        double hive_field_4_playback_speed "double playbackSpeed"
        double hive_field_5_volume "double volume"
        bool hive_field_6_enable_equalizer "bool enableEqualizer"
        list hive_field_7_equalizer_bands "List<double> equalizerBands"
        bool hive_field_8_enable_noise_reduction "bool enableNoiseReduction"
        double hive_field_9_noise_reduction_level "double noiseReductionLevel"
        bool hive_field_10_enable_auto_gain "bool enableAutoGain"
        double hive_field_11_gain_level "double gainLevel"
        bool hive_field_12_enable_compression "bool enableCompression"
        double hive_field_13_compression_ratio "double compressionRatio"
        bool hive_field_14_show_waveform "bool showWaveform"
        string hive_field_15_waveform_color "String waveformColor"
        bool hive_field_16_show_spectrogram "bool showSpectrogram"
        int hive_field_17_fft_size "int fftSize"
        string hive_field_18_export_format "String exportFormat"
        int hive_field_19_export_quality "int exportQuality"
        bool hive_field_20_include_metadata "bool includeMetadata"
    }
    
    ENHANCED_AUDIO_MODEL {
        string hive_field_0_file_path "String filePath"
        string hive_field_1_file_name "String fileName"
        datetime hive_field_2_created_at "DateTime createdAt"
        datetime hive_field_3_modified_at "DateTime? modifiedAt"
        int hive_field_4_duration_ms "int durationMs"
        int hive_field_5_file_size_bytes "int fileSizeBytes"
        string hive_field_6_format "String format"
        int hive_field_7_bit_rate "int bitRate"
        int hive_field_8_sample_rate "int sampleRate"
        int hive_field_9_channels "int channels"
        string hive_field_10_title "String? title"
        string hive_field_11_description "String? description"
        list hive_field_12_tags "List<String> tags"
        string hive_field_13_category "String? category"
        int hive_field_14_rating "int rating"
        string hive_field_15_transcription "String? transcription"
        list hive_field_16_waveform_data "List<double>? waveformData"
        int hive_field_17_waveform_samples "int? waveformSamples"
        list hive_field_18_processing_history "List<String> processingHistory"
        string hive_field_19_original_file_path "String? originalFilePath"
        int hive_field_20_play_count "int playCount"
        datetime hive_field_21_last_played_at "DateTime? lastPlayedAt"
        int hive_field_22_last_play_position "int? lastPlayPosition"
        bool hive_field_23_is_shared "bool isShared"
        list hive_field_24_shared_with "List<String> sharedWith"
        bool hive_field_25_is_favorite "bool isFavorite"
        bool hive_field_26_is_archived "bool isArchived"
        double hive_field_27_average_volume "double? averageVolume"
        double hive_field_28_peak_volume "double? peakVolume"
        bool hive_field_29_has_silence "bool? hasSilence"
        list hive_field_30_frequency_spectrum "List<double>? frequencySpectrum"
    }
    
    POMODORO_MODEL ||--o{ ENHANCED_AUDIO_MODEL : "references via audioPath"
```

## Component Architecture

```mermaid
graph TB
    A[HomeScreen] --> B[PomodoroModel]
    A --> C[UserSettingsModel]
    A --> D[EnhancedAudioRecorder]
    
    E[SettingsScreen] --> C
    E --> F[AudioSettingsModel]
    
    G[AudioManagementScreen] --> H[EnhancedAudioModel]
    G --> I[EnhancedAudioPlayer]
    G --> D
    
    I --> H
    I --> F
    D --> H
    D --> F
    
    J[HistoryScreen] --> B
    J --> I
    
    B --> K[(Hive Database)]
    C --> K
    F --> K
    H --> K
    
    L[PomodoroModelAdapter] --> K
    M[UserSettingsAdapter] --> K
    N[AudioSettingsAdapter] --> K
    O[EnhancedAudioAdapter] --> K
    
    D --> P[Audio Files]
    I --> P
    
    B -.-> P : audioPath reference
    H -.-> P : filePath
    
    subgraph "Data Layer"
        B
        C
        F
        H
        K
        L
        M
        N
        O
    end
    
    subgraph "UI Layer"
        A
        E
        G
        J
        I
        D
    end
    
    subgraph "File System"
        P
    end
```

## Model Details

### PomodoroModel (TypeId: 0)
Core model for tracking Pomodoro sessions. Links to audio recordings and images captured during sessions.

**Key Features:**
- Session timing and metadata
- Project organization
- Media attachment references

### UserSettingsModel (TypeId: 1) 
Comprehensive user preferences covering all aspects of the application.

**Categories:**
- **Theme & Appearance**: Dark/light mode, colors
- **Session Defaults**: Work/break durations, automation
- **Notifications**: Alerts, sounds, preferences
- **Audio Preferences**: Quality, format, storage
- **Localization**: Language, date/time formats
- **Privacy**: Analytics, backup settings

### AudioSettingsModel (TypeId: 2)
Detailed audio processing and playback configuration.

**Categories:**
- **Recording**: Codec, bitrate, sample rate, channels
- **Playback**: Speed, volume, equalizer
- **Processing**: Noise reduction, auto-gain, compression
- **Visualization**: Waveform, spectrogram settings
- **Export**: Format, quality, metadata inclusion

### EnhancedAudioModel (TypeId: 3)
Comprehensive audio file metadata with advanced features.

**Categories:**
- **File Properties**: Path, size, format, technical specs
- **Metadata**: Title, description, tags, category, rating
- **Waveform**: Visualization data and analysis
- **Processing**: Edit history, original file tracking
- **Usage**: Play statistics, playback position
- **Organization**: Favorites, sharing, archiving
- **Analysis**: Volume levels, frequency spectrum, silence detection

## Usage Patterns

### User Settings Management
```dart
// Load user settings
final userBox = Hive.box<UserSettingsModel>('userSettings');
final settings = userBox.get('settings') ?? UserSettingsModel();

// Update theme
settings.theme = 'dark';
settings.primaryColor = 'blue';
userBox.put('settings', settings);
```

### Audio Settings Configuration
```dart
// Configure recording quality
final audioBox = Hive.box<AudioSettingsModel>('audioSettings');
final audioSettings = audioBox.get('settings') ?? AudioSettingsModel();

audioSettings.codec = 'aacLc';
audioSettings.bitRate = 256;
audioSettings.enableNoiseReduction = true;
audioBox.put('settings', audioSettings);
```

### Enhanced Audio Management
```dart
// Create enhanced audio model
final audioModel = EnhancedAudioModel(
  filePath: filePath,
  fileName: fileName,
  createdAt: DateTime.now(),
  durationMs: duration.inMilliseconds,
  fileSizeBytes: fileSize,
  format: 'm4a',
  bitRate: 128,
  sampleRate: 44100,
  channels: 1,
  category: 'voice_note',
  tags: ['work', 'meeting'],
);

// Save to database
final audioBox = Hive.box<EnhancedAudioModel>('audioFiles');
await audioBox.add(audioModel);

// Update play statistics
audioModel.incrementPlayCount();
audioModel.addTag('important');
```

### Session Creation with Enhanced Audio
```dart
// Create Pomodoro session with audio reference
final session = PomodoroModel(
  startTime: DateTime.now(),
  audioPath: enhancedAudio.filePath, // Reference to enhanced audio
  imagePath: imagePath,
  dayPomodoroNumber: sessionCount,
  project_id: 'project_001',
  project_name: 'App Development',
);

final pomodoroBox = Hive.box<PomodoroModel>('pomodoros');
await pomodoroBox.add(session);
```

## Advanced Features

### Audio Processing Pipeline
1. **Recording** → AudioSettingsModel configuration applied
2. **Processing** → Noise reduction, auto-gain if enabled
3. **Analysis** → Waveform generation, volume analysis
4. **Metadata** → Title, tags, category assignment
5. **Storage** → EnhancedAudioModel creation and database save

### Search and Filtering
- **Text Search**: Title, filename, tags, description
- **Category Filtering**: voice_note, music, meeting, ambient
- **Status Filtering**: Favorites, archived, shared
- **Sorting**: Date, name, duration, size, play count

### Data Relationships
- PomodoroModel references EnhancedAudioModel via audioPath
- UserSettingsModel provides defaults for AudioSettingsModel
- AudioSettingsModel configures EnhancedAudioRecorder behavior
- EnhancedAudioModel tracks detailed usage and processing history

## Future Enhancements

### Planned Models
1. **ProjectModel** - Detailed project management with goals and milestones
2. **CategoryModel** - Custom audio categories with icons and colors  
3. **GoalModel** - Progress tracking and achievement system
4. **SyncModel** - Cloud synchronization and backup management
5. **AnalyticsModel** - Detailed usage analytics and insights

### Planned Features
1. **AI Integration** - Transcription, summarization, sentiment analysis
2. **Collaboration** - Shared projects and audio comments
3. **Advanced Analytics** - Productivity insights and recommendations
4. **Export/Import** - Data portability and backup/restore
5. **Plugin System** - Third-party integrations and extensions


