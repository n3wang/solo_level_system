class AppEnvironment {
  AppEnvironment._();

  /// Local vs deployed API. Flip this — no `--dart-define` needed.
  static const bool isDev = true;

  static const String prodApiBaseUrl = 'https://apinet.l.l0l.in';
  static const String devApiBaseUrl = 'http://127.0.0.1:5292';

  /// Web client id for Google ID tokens. Empty is fine until Google login is configured.
  static const String googleServerClientId = '';

  /// Local-only Identity user seeded by the API in Development.
  static const String devAccountEmail = 'developer@solo.local';
  static const String devAccountPassword = 'Developer123!';

  static const Duration apiTimeout = Duration(seconds: 8);

  static String get apiBaseUrl => isDev ? devApiBaseUrl : prodApiBaseUrl;

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );
  static const bool _explicitTestMode = bool.fromEnvironment(
    'APP_TEST_MODE',
    defaultValue: false,
  );

  /// Compile-time default used until [setDevelopmentDataEnabled] loads settings.
  /// Prefer the Settings → Development data toggle at runtime.
  static const bool defaultDevelopmentData = true;

  static bool? _developmentDataEnabled;

  static String get name => _rawEnv.toLowerCase();

  /// True when development / test seed data and demo behaviors are active.
  static bool get isTest {
    if (_developmentDataEnabled != null) return _developmentDataEnabled!;
    return defaultDevelopmentData ||
        _explicitTestMode ||
        name == 'test' ||
        name == 'testing';
  }

  /// Alias kept for older call sites (e.g. analytics heatmap samples).
  static bool get is_test => isTest;

  static bool get is_dev => isDev;

  /// Apply the persisted Settings toggle (call after loading user settings).
  static void setDevelopmentDataEnabled(bool enabled) {
    _developmentDataEnabled = enabled;
  }

  /// When false (prod), unacquired hub cards hide art/description until bought
  /// (Pokemon TCG style). Test / demo modes keep full preview for QA.
  static bool get revealUnacquiredCardDetails => isTest;

  // Test mode overrides for faster/demo validation flows.
  static int get seededMotivationStarterCost => isTest ? 5 : 20;
  static int get quickCreateDefaultCost => isTest ? 5 : 20;
}
