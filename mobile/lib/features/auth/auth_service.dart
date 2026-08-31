import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../../core/networking/api_client.dart';
import 'user.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
}

/// Holds Google Sign-In + HabitQ backend auth. Exposes plain [ChangeNotifier]
/// state (no external state-management package) for the Login screen.
class AuthService extends ChangeNotifier {
  AuthService({ApiClient? apiClient, FlutterSecureStorage? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _googleSignIn = GoogleSignIn(
          serverClientId: AppConfig.googleClientId.isEmpty
              ? null
              : AppConfig.googleClientId,
          scopes: const ['email'],
        );

  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final GoogleSignIn _googleSignIn;

  static const _tokenKey = 'habitq_jwt';

  bool isLoading = false;

  /// Signs in with Google, exchanges the ID token with the backend, and
  /// stores the returned HabitQ JWT. Returns the authenticated user.
  Future<HabitQUser> signInWithGoogle() async {
    isLoading = true;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw AuthFailure('Inicio de sesión cancelado.');
      }

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw AuthFailure('No se pudo obtener el token de Google.');
      }

      final response = await _apiClient.post('/auth/google', {'id_token': idToken});

      final accessToken = response['access_token'] as String;
      await _secureStorage.write(key: _tokenKey, value: accessToken);

      return HabitQUser.fromJson(response['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw AuthFailure(e.message);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
