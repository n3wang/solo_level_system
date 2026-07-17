class AppEnvironment {
  AppEnvironment._();

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );
  static const bool _explicitTestMode = bool.fromEnvironment(
    'APP_TEST_MODE',
    defaultValue: false,
  );

  /// Common demo/test gate. When true: Overview heatmap gets sample minutes
  /// for the previous 25 days, cheaper unlocks, etc.
  static const bool is_test = true;

  static String get name => _rawEnv.toLowerCase();

  static bool get isTest =>
      is_test || _explicitTestMode || name == 'test' || name == 'testing';

  /// When false (prod), unacquired hub cards hide art/description until bought
  /// (Pokemon TCG style). Test / demo modes keep full preview for QA.
  static bool get revealUnacquiredCardDetails => isTest;

  // Test mode overrides for faster/demo validation flows.
  static int get seededMotivationStarterCost => isTest ? 5 : 20;
  static int get quickCreateDefaultCost => isTest ? 5 : 20;
}
