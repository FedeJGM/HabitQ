import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../../core/networking/api_client.dart';
import '../../core/networking/token_storage.dart';
import '../../core/utils/jwt.dart';
import 'user.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
}

/// Holds Google Sign-In + HabitQ backend auth. Exposes plain [ChangeNotifier]
/// state (no external state-management package) for the Login screen.
class AuthService extends ChangeNotifier {
  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    GoogleSignIn? googleSignIn,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? const TokenStorage(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: AppConfig.googleClientId.isEmpty
                  ? null
                  : AppConfig.googleClientId,
              scopes: const ['email'],
            );

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final GoogleSignIn _googleSignIn;

  /// How close to expiry (or already expired) a stored JWT must be before
  /// [refreshTokenIfNeeded] proactively renews it. A reactive retry-on-401
  /// doesn't work for this backend: POST /auth/refresh reissues a token from
  /// one that is still valid (see D-09/D-13 in docs/decisions.md), so an
  /// already-expired token can't be recovered after the fact.
  static const _refreshBuffer = Duration(minutes: 60);

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
      await _tokenStorage.write(accessToken);

      return HabitQUser.fromJson(response['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw AuthFailure(e.message);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches the authenticated user from the backend (GET /auth/me).
  Future<HabitQUser> fetchCurrentUser() async {
    final response = await _apiClient.get('/auth/me');
    return HabitQUser.fromJson(response);
  }

  /// Best-effort POST /auth/logout, then discards the stored HabitQ JWT
  /// regardless of the backend call's outcome — logging out must not get
  /// stuck on a network error, and the JWT is stateless so the backend has
  /// no way to force it invalid anyway.
  Future<void> signOut() async {
    try {
      await _apiClient.post('/auth/logout', const {});
    } on ApiException {
      // Ignored: local sign-out proceeds either way.
    }
    // Without this the plugin keeps the cached Google account and the next
    // signIn() reuses it silently, never showing the account picker.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignored: the HabitQ session is discarded either way.
    }
    await _tokenStorage.delete();
  }

  /// Proactively renews the stored JWT when it's close to expiring (or
  /// already expired). Meant to be called when the app becomes active
  /// (cold start, or resuming from background) rather than reactively
  /// after a request fails — see the class-level note on [_refreshBuffer].
  Future<void> refreshTokenIfNeeded() async {
    final token = await _tokenStorage.read();
    if (token == null) return;

    final expiry = jwtExpiry(token);
    if (expiry == null) return;

    if (expiry.difference(DateTime.now().toUtc()) > _refreshBuffer) return;

    try {
      final response = await _apiClient.post('/auth/refresh', const {});
      final newToken = response['access_token'] as String;
      await _tokenStorage.write(newToken);
    } on ApiException {
      // The stored token is unrecoverable (refresh needs a still-valid
      // token too) — drop it instead of leaving a dead JWT in storage.
      await _tokenStorage.delete();
    }
  }
}
