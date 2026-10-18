/// API keys, passed in at build time so they don't live in the code.
///
/// Run with: flutter run --dart-define-from-file=secrets.json
/// (see secrets.example.json). Without it, USDA's shared DEMO_KEY is used,
/// which works but only allows about 30 searches an hour.
class ApiKeys {
  ApiKeys._();

  static const String usda =
      String.fromEnvironment('USDA_API_KEY', defaultValue: 'DEMO_KEY');

  static bool get usingDemoUsdaKey => usda == 'DEMO_KEY';
}
