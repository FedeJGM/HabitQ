import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads the HabitQ JWT written by [AuthService] after login. The key must
/// stay in sync with `features/auth/auth_service.dart`'s `_tokenKey`.
class TokenStorage {
  const TokenStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const key = 'habitq_jwt';

  Future<String?> read() => _secureStorage.read(key: key);
}
