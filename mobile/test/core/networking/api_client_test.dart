import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/networking/api_client.dart';

void main() {
  group('ApiClient', () {
    test('post does not attach Authorization header when no token stored', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      final result = await apiClient.post('/auth/google', {'id_token': 'abc'});

      expect(capturedRequest!.headers.containsKey('Authorization'), isFalse);
      expect(capturedRequest!.url.path, '/auth/google');
      expect(jsonDecode(capturedRequest!.body), {'id_token': 'abc'});
      expect(result, {'ok': true});
    });

    test('post succeeds when the response arrives within a custom timeout', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      final result = await apiClient.post(
        '/chat',
        {'message': 'hi'},
        timeout: const Duration(seconds: 1),
      );

      expect(result, {'ok': true});
    });

    test('post throws ApiException when the response exceeds a custom timeout', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      await expectLater(
        apiClient.post('/chat', {'message': 'hi'}, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<ApiException>()),
      );
    });

    test('get attaches Authorization header when a token is stored', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'age_range': '25-34'}), 200);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => 'fake-jwt');

      final result = await apiClient.get('/profile');

      expect(capturedRequest!.headers['Authorization'], 'Bearer fake-jwt');
      expect(capturedRequest!.method, 'GET');
      expect(result, {'age_range': '25-34'});
    });

    test('put sends the body and the Authorization header', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'age_range': '25-34'}), 200);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => 'fake-jwt');

      await apiClient.put('/profile', {'age_range': '25-34', 'main_goal': 'sleep_better'});

      expect(capturedRequest!.method, 'PUT');
      expect(capturedRequest!.headers['Authorization'], 'Bearer fake-jwt');
      expect(jsonDecode(capturedRequest!.body), {
        'age_range': '25-34',
        'main_goal': 'sleep_better',
      });
    });

    test('throws ApiException with the backend detail on error status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Profile not found'}), 404);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => 'fake-jwt');

      await expectLater(
        apiClient.get('/profile'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Profile not found'),
        ),
      );
    });

    test('throws ApiException when the connection fails', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network down');
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      await expectLater(apiClient.get('/profile'), throwsA(isA<ApiException>()));
    });

    test('a failed connection is reported as ApiConnectionException with the usual message', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network down');
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      await expectLater(
        apiClient.get('/profile'),
        throwsA(
          isA<ApiConnectionException>().having(
            (e) => e.message,
            'message',
            'No se pudo conectar con el servidor. Verifica tu conexión.',
          ),
        ),
      );
    });

    test('a backend error is not a connection error', () async {
      final mockClient = MockClient((request) async => http.Response(jsonEncode({'detail': 'No'}), 500));
      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      await expectLater(
        apiClient.get('/profile'),
        throwsA(isA<ApiException>().having((e) => e is ApiConnectionException, 'is connection', false)),
      );
    });

    test('getList attaches the Authorization header and returns a JSON array', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {'domain': 'sleep', 'key': 'hours', 'value': '7_8'},
          ]),
          200,
        );
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => 'fake-jwt');

      final result = await apiClient.getList('/habits');

      expect(capturedRequest!.headers['Authorization'], 'Bearer fake-jwt');
      expect(capturedRequest!.method, 'GET');
      expect(result, [
        {'domain': 'sleep', 'key': 'hours', 'value': '7_8'},
      ]);
    });

    test('getList throws ApiException with the backend detail on error status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Not authenticated'}), 401);
      });

      final apiClient = ApiClient(client: mockClient, tokenProvider: () async => null);

      await expectLater(
        apiClient.getList('/habits'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Not authenticated'),
        ),
      );
    });
  });
}
