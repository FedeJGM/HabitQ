import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/chat/chat_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error, this.response});

  ApiException? error;
  Map<String, dynamic>? response;
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    postedBodies.add(body);
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> get(String path) {
    throw UnimplementedError();
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

void main() {
  group('ChatService.sendMessage', () {
    test('posts only the message when no conversationId is given', () async {
      final fakeClient = _FakeApiClient(response: {
        'conversation_id': 'c1',
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'content': 'Dormí entre 7 y 9 horas.',
          'created_at': '2026-09-01T00:00:00Z',
        },
        'sources': [],
      });
      final service = ChatService(apiClient: fakeClient);

      await service.sendMessage('¿Cuánto debo dormir?');

      expect(fakeClient.postedBodies.single, {'message': '¿Cuánto debo dormir?'});
    });

    test('includes conversationId in the body when given', () async {
      final fakeClient = _FakeApiClient(response: {
        'conversation_id': 'c1',
        'message': {
          'id': 'm2',
          'role': 'assistant',
          'content': 'Y para adolescentes, 8 a 10 horas.',
          'created_at': '2026-09-01T00:00:05Z',
        },
        'sources': [],
      });
      final service = ChatService(apiClient: fakeClient);

      await service.sendMessage('¿Y para adolescentes?', conversationId: 'c1');

      expect(fakeClient.postedBodies.single, {
        'message': '¿Y para adolescentes?',
        'conversation_id': 'c1',
      });
    });

    test('parses the conversation id, message, and sources from the response', () async {
      final fakeClient = _FakeApiClient(response: {
        'conversation_id': 'c1',
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'content': 'Dormí entre 7 y 9 horas.',
          'created_at': '2026-09-01T00:00:00Z',
        },
        'sources': [
          {
            'document_id': 'd1',
            'title': 'Healthy Sleep',
            'organization': 'CDC',
            'source_url': null,
          },
        ],
      });
      final service = ChatService(apiClient: fakeClient);

      final turn = await service.sendMessage('¿Cuánto debo dormir?');

      expect(turn.conversationId, 'c1');
      expect(turn.message.id, 'm1');
      expect(turn.message.role, 'assistant');
      expect(turn.message.content, 'Dormí entre 7 y 9 horas.');
      expect(turn.sources, hasLength(1));
      expect(turn.sources.single.title, 'Healthy Sleep');
      expect(turn.sources.single.organization, 'CDC');
      expect(turn.sources.single.sourceUrl, isNull);
    });

    test('propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('No se pudo conectar con el servidor.'));
      final service = ChatService(apiClient: fakeClient);

      await expectLater(
        service.sendMessage('¿Cuánto debo dormir?'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
