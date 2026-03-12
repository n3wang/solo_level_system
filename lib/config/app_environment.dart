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

  static String get name => _rawEnv.toLowerCase();

  static bool get isTest =>
      _explicitTestMode || name == 'test' || name == 'testing';

  // Test mode overrides for faster/demo validation flows.
  static int get seededMotivationStarterCost => isTest ? 5 : 20;
  static int get quickCreateDefaultCost => isTest ? 5 : 20;
}

