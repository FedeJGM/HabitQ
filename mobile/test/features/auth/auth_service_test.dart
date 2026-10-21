import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/networking/token_storage.dart';
import 'package:mobile/features/auth/auth_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response, this.error});

  Map<String, dynamic>? response;
  ApiException? error;
  final List<String> postedPaths = [];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    postedPaths.add(path);
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<List<dynamic>> getList(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String path) {
    throw UnimplementedError();
  }
}

class _FakeTokenStorage implements TokenStorage {
  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String token) async {
    stored = token;
  }

  @override
  Future<void> delete() async {
    stored = null;
  }
}

class _FakeGoogleSignIn implements GoogleSignIn {
  _FakeGoogleSignIn({this.signOutError});

  final Object? signOutError;
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _makeToken(DateTime expiry) {
  String segment(Object? value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final payload = segment({'sub': 'u1', 'exp': expiry.millisecondsSinceEpoch ~/ 1000});
  return '$header.$payload.dummy-signature';
}

void main() {
  group('AuthService.fetchCurrentUser', () {
    test('GETs /auth/me and parses the user', () async {
      final fakeClient = _FakeApiClient(response: {
        'id': 'u1',
        'email': 'test@example.com',
        'name': 'Alice',
        'onboarding_completed': true,
      });
      final service = AuthService(apiClient: fakeClient);

      final user = await service.fetchCurrentUser();

      expect(user.id, 'u1');
      expect(user.name, 'Alice');
      expect(user.onboardingCompleted, isTrue);
    });

    test('propagates ApiException from the backend', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = AuthService(apiClient: fakeClient);

      await expectLater(service.fetchCurrentUser(), throwsA(isA<ApiException>()));
    });
  });

  group('AuthService.signOut', () {
    test('clears the Google session so the account picker shows again', () async {
      final google = _FakeGoogleSignIn();
      final tokenStorage = _FakeTokenStorage()..stored = 'jwt';
      final service = AuthService(
        apiClient: _FakeApiClient(response: const {}),
        tokenStorage: tokenStorage,
        googleSignIn: google,
      );

      await service.signOut();

      expect(google.signOutCalls, 1);
      expect(tokenStorage.stored, isNull);
    });

    test('still discards the token when Google sign-out fails', () async {
      final google = _FakeGoogleSignIn(signOutError: Exception('play services'));
      final tokenStorage = _FakeTokenStorage()..stored = 'jwt';
      final service = AuthService(
        apiClient: _FakeApiClient(response: const {}),
        tokenStorage: tokenStorage,
        googleSignIn: google,
      );

      await service.signOut();

      expect(tokenStorage.stored, isNull);
    });
  });

  group('AuthService.refreshTokenIfNeeded', () {
    test('does nothing when there is no stored token', () async {
      final fakeClient = _FakeApiClient();
      final tokenStorage = _FakeTokenStorage();
      final service = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

      await service.refreshTokenIfNeeded();

      expect(fakeClient.postedPaths, isEmpty);
    });

    test('does nothing when the stored token is far from expiring', () async {
      final farFuture = DateTime.now().toUtc().add(const Duration(hours: 12));
      final fakeClient = _FakeApiClient();
      final tokenStorage = _FakeTokenStorage()..stored = _makeToken(farFuture);
      final service = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

      await service.refreshTokenIfNeeded();

      expect(fakeClient.postedPaths, isEmpty);
    });

    test('refreshes and stores the new token when close to expiring', () async {
      final soon = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final fakeClient = _FakeApiClient(response: {'access_token': 'new-token'});
      final tokenStorage = _FakeTokenStorage()..stored = _makeToken(soon);
      final service = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

      await service.refreshTokenIfNeeded();

      expect(fakeClient.postedPaths, ['/auth/refresh']);
      expect(tokenStorage.stored, 'new-token');
    });

    test('clears the stored token when refresh itself fails', () async {
      final expired = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final fakeClient = _FakeApiClient(error: ApiException('token expired'));
      final tokenStorage = _FakeTokenStorage()..stored = _makeToken(expired);
      final service = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

      await service.refreshTokenIfNeeded();

      expect(fakeClient.postedPaths, ['/auth/refresh']);
      expect(tokenStorage.stored, isNull);
    });
  });
}
