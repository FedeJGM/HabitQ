import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads and writes the HabitQ JWT. The single source of truth for the
/// storage key — `AuthService` and `ApiClient` both go through this class
/// instead of holding their own `FlutterSecureStorage` instance.
class TokenStorage {
  const TokenStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const key = 'habitq_jwt';

  Future<String?> read() => _secureStorage.read(key: key);

  Future<void> write(String token) => _secureStorage.write(key: key, value: token);

  Future<void> delete() => _secureStorage.delete(key: key);
}
