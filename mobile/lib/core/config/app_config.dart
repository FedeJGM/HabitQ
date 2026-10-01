/// Values injected at build/run time via `--dart-define-from-file=../.env`
/// (the root `.env`, shared with backend/). See README for setup.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Google OAuth Web Client ID. Passed as `serverClientId` to GoogleSignIn
  /// so the resulting ID token's audience matches what the backend validates.
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
}
