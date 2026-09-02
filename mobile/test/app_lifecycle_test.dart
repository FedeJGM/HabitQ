import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/networking/token_storage.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/main.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response});

  Map<String, dynamic>? response;
  final List<String> postedPaths = [];

  @override
  Future<Map<String, dynamic>> get(String path) async => response ?? {};

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    postedPaths.add(path);
    return response ?? {};
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<List<dynamic>> getList(String path) {
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

String _makeToken(DateTime expiry) {
  String segment(Object? value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final payload = segment({'sub': 'u1', 'exp': expiry.millisecondsSinceEpoch ~/ 1000});
  return '$header.$payload.dummy-signature';
}

void main() {
  testWidgets('refreshes the token when the app resumes and it is close to expiring',
      (tester) async {
    final soon = DateTime.now().toUtc().add(const Duration(minutes: 10));
    final fakeClient = _FakeApiClient(response: {'access_token': 'new-token'});
    final tokenStorage = _FakeTokenStorage()..stored = _makeToken(soon);
    final authService = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

    await tester.pumpWidget(HabitQApp(authService: authService));
    await tester.pump();

    // Cold start already triggers one refreshTokenIfNeeded() call.
    expect(fakeClient.postedPaths, ['/auth/refresh']);

    fakeClient.postedPaths.clear();
    tokenStorage.stored = _makeToken(soon);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(fakeClient.postedPaths, ['/auth/refresh']);
  });

  testWidgets('does not call refresh on resume when the token is far from expiring',
      (tester) async {
    final farFuture = DateTime.now().toUtc().add(const Duration(hours: 12));
    final fakeClient = _FakeApiClient();
    final tokenStorage = _FakeTokenStorage()..stored = _makeToken(farFuture);
    final authService = AuthService(apiClient: fakeClient, tokenStorage: tokenStorage);

    await tester.pumpWidget(HabitQApp(authService: authService));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(fakeClient.postedPaths, isEmpty);
  });
}
