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
  });
}
