// lib/models/user_settings_model.dart
import 'package:hive/hive.dart';
import 'package:solo_level_system/models/card_acquisition_settings.dart';
part 'user_settings_model.g.dart';

@HiveType(typeId: 1)
class UserSettingsModel extends HiveObject {
  // Theme & Appearance
  @HiveField(0)
  String theme; // 'light', 'dark', 'system'

  @HiveField(1)
  String primaryColor; // 'red', 'blue', 'green', etc.

  @HiveField(21)
  String colorPalette; // 'default', 'original', 'warm', 'cool', 'earth', 'pastel', 'vibrant'

  // Session Settings
  @HiveField(2)
  int defaultWorkMinutes;

  @HiveField(3)
  int defaultBreakMinutes;

  @HiveField(4)
  bool autoStartBreaks;

  @HiveField(5)
  bool autoStartWork;

  // Notification Settings
  @HiveField(6)
  bool enableNotifications;

  @HiveField(7)
  bool enableSounds;

  @HiveField(8)
  String notificationSound; // path to custom sound or built-in name

  // Audio Settings
  @HiveField(9)
  String audioQuality; // 'low', 'medium', 'high'

  @HiveField(10)
  String audioFormat; // 'm4a', 'mp3', 'wav'

  @HiveField(11)
  String defaultAudioPath; // custom folder path

  @HiveField(12)
  bool enableNoiseReduction;

  // Background Music Settings
  @HiveField(19)
  bool playAudioDuringWork; // Controls music during work sessions

  @HiveField(20)
  bool playAudioDuringBreaks; // Controls music during break sessions

  // Language & Localization
  @HiveField(13)
  String language; // 'en', 'es', 'fr', etc.

  @HiveField(14)
  String dateFormat; // 'MM/dd/yyyy', 'dd/MM/yyyy', etc.

  @HiveField(15)
  String timeFormat; // '12h', '24h'

  // Privacy & Data
  @HiveField(16)
  bool enableAnalytics;

  @HiveField(17)
  bool autoBackup;

  @HiveField(18)
  String backupPath;

  /// When true, seed/show development sample data (test rewards, sample
  /// projects, demo history). When false, hide those records in the UI
  /// without deleting them from Hive.
  @HiveField(22)
  bool developmentDataEnabled;

  /// When true, focus sessions auto-open the journal after work completes.
  /// Long-press the journal button on the pomodoro screen to toggle.
  @HiveField(23)
  bool autoOpenJournalAfterFocus;

  /// `session_completion` | `rogue` | `disabled`
  @HiveField(24)
  String cardAcquisitionMode;

  /// Cards granted per focus session in session-completion mode (1–5).
  @HiveField(25)
  int sessionCompletionCardCount;

  /// `after_break` | `after_focus`
  @HiveField(26)
  String cardAcquireTiming;

  /// Rogue challenge strings (persisted even when rogue mode is off).
  @HiveField(27)
  List<String> rogueChallengeList;

  /// When true, the pomodoro screen background is red during work and green
  /// during breaks instead of the normal white/black scaffold color.
  @HiveField(28)
  bool colorBackgroundBySessionMode;

  /// macOS global shortcuts, JSON-encoded via `HotKey.toJson()`/`fromJson()`
  /// (see hotkey_manager). Empty string means "use the built-in default".
  @HiveField(29)
  String hotkeyStartPause;

  @HiveField(30)
  String hotkeyStop;

  @HiveField(31)
  String hotkeyTogglePopover;

  /// Master switch for the public solo-leveling profile page. Off by
  /// default: the public page 404s even if a handle was claimed.
  @HiveField(32)
  bool publicProfileEnabled;

  /// Shares focus/workout sessions and journal entries that aren't tied to
  /// a project. Per-project sharing is controlled by
  /// [ProjectModel.shareProgress] instead.
  @HiveField(33)
  bool shareNonProjectSessions;

  /// Gates journal entry text/quotes on the public profile independently of
  /// session sharing, so streaks/session counts can be shown without
  /// exposing journal writing.
  @HiveField(34)
  bool shareJournalText;

  /// Cached copy of the handle claimed via `/api/profile/handle`. Source of
  /// truth is the server; this is only for display convenience offline.
  @HiveField(35)
  String publicHandle;

  /// When true, a running focus/break session prevents the system from
  /// sleeping due to inactivity (via `wakelock_plus`) until the session
  /// ends, is paused, or is stopped. On by default to preserve the app's
  /// existing (previously unconditional) keep-awake behavior.
  @HiveField(36)
  bool keepAwakeDuringSession;

  UserSettingsModel({
    this.theme = 'system',
    this.primaryColor = 'green',
    this.colorPalette = 'pastel',
    this.defaultWorkMinutes = 25,
    this.defaultBreakMinutes = 5,
    this.autoStartBreaks = false,
    this.autoStartWork = false,
    this.enableNotifications = true,
    this.enableSounds = true,
    this.notificationSound = 'default',
    this.audioQuality = 'medium',
    this.audioFormat = 'm4a',
    this.defaultAudioPath = '',
    this.enableNoiseReduction = false,
    this.playAudioDuringWork = true,
    this.playAudioDuringBreaks = false,
    this.language = 'en',
    this.dateFormat = 'MM/dd/yyyy',
    this.timeFormat = '12h',
    this.enableAnalytics = false,
    this.autoBackup = true,
    this.backupPath = '',
    this.developmentDataEnabled = true,
    this.autoOpenJournalAfterFocus = true,
    this.cardAcquisitionMode = 'session_completion',
    this.sessionCompletionCardCount = 1,
    this.cardAcquireTiming = 'after_break',
    List<String>? rogueChallengeList,
    this.colorBackgroundBySessionMode = false,
    this.hotkeyStartPause = '',
    this.hotkeyStop = '',
    this.hotkeyTogglePopover = '',
    this.publicProfileEnabled = false,
    this.shareNonProjectSessions = false,
    this.shareJournalText = false,
    this.publicHandle = '',
    this.keepAwakeDuringSession = true,
  }) : rogueChallengeList =
            rogueChallengeList ?? List<String>.from(RogueChallengeDefaults.base);

  CardAcquisitionMode get acquisitionMode =>
      CardAcquisitionMode.fromWire(cardAcquisitionMode);

  set acquisitionMode(CardAcquisitionMode mode) =>
      cardAcquisitionMode = mode.wire;

  CardAcquireTiming get acquireTiming =>
      CardAcquireTiming.fromWire(cardAcquireTiming);

  set acquireTiming(CardAcquireTiming timing) =>
      cardAcquireTiming = timing.wire;

  int get clampedSessionCardCount =>
      sessionCompletionCardCount.clamp(1, 5).toInt();

  // Convenience methods
  bool get isDarkTheme => theme == 'dark';
  bool get isLightTheme => theme == 'light';
  bool get isSystemTheme => theme == 'system';

  // Audio quality as bitrate
  int get audioBitrate {
    switch (audioQuality) {
      case 'low':
        return 64;
      case 'medium':
        return 128;
      case 'high':
        return 256;
      default:
        return 128;
    }
  }
}
