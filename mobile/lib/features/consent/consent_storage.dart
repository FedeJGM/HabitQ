import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local-only record of the initial consent (plan section 2). Scoped to
/// this device, not the account: a fresh install re-asks even for a user
/// whose onboarding is already done server-side.
class ConsentStorage {
  const ConsentStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _key = 'habitq_consent_accepted';

  Future<bool> hasAccepted() async {
    final value = await _secureStorage.read(key: _key);
    return value == 'true';
  }

  Future<void> accept() => _secureStorage.write(key: _key, value: 'true');
}
