import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/chat/chat_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error, this.response, this.listResponse});

  ApiException? error;
  Map<String, dynamic>? response;
  List<dynamic>? listResponse;
  final List<Map<String, dynamic>> postedBodies = [];
  final List<String> getListPaths = [];
  final List<String> deletedPaths = [];

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
  Future<List<dynamic>> getList(String path) async {
    getListPaths.add(path);
    if (error != null) throw error!;
    return listResponse!;
  }

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
    if (error != null) throw error!;
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

    test('parses authors, year, DOI and pages of a source', () async {
      final fakeClient = _FakeApiClient(response: {
        'conversation_id': 'c1',
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'content': 'ok',
          'created_at': '2026-09-01T00:00:00Z',
        },
        'sources': [
          {
            'document_id': 'd1',
            'title': 'Sleep and health',
            'organization': 'Sleep Journal',
            'source_url': 'https://europepmc.org/articles/PMC1',
            'authors': 'Doe J, Roe R.',
            'year': 2024,
            'doi': '10.1/abc',
            'pages': [1, 3],
          },
        ],
      });
      final service = ChatService(apiClient: fakeClient);

      final source = (await service.sendMessage('q')).sources.single;

      expect(source.authors, 'Doe J, Roe R.');
      expect(source.year, 2024);
      expect(source.doi, '10.1/abc');
      expect(source.pages, [1, 3]);
    });

    test('tolerates sources from an older backend without the new fields', () async {
      final fakeClient = _FakeApiClient(response: {
        'conversation_id': 'c1',
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'content': 'ok',
          'created_at': '2026-09-01T00:00:00Z',
        },
        'sources': [
          {'document_id': 'd1', 'title': 'Healthy Sleep', 'organization': 'CDC', 'source_url': null},
        ],
      });
      final service = ChatService(apiClient: fakeClient);

      final source = (await service.sendMessage('q')).sources.single;

      expect(source.authors, isNull);
      expect(source.year, isNull);
      expect(source.doi, isNull);
      expect(source.pages, isEmpty);
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

  group('ChatService.fetchConversations', () {
    test('GETs /chat/conversations and parses each summary', () async {
      final fakeClient = _FakeApiClient(listResponse: [
        {
          'id': 'c1',
          'title': null,
          'created_at': '2026-09-01T10:00:00Z',
          'updated_at': '2026-09-01T10:05:00Z',
        },
      ]);
      final service = ChatService(apiClient: fakeClient);

      final conversations = await service.fetchConversations();

      expect(fakeClient.getListPaths, ['/chat/conversations']);
      expect(conversations, hasLength(1));
      expect(conversations.single.id, 'c1');
      expect(conversations.single.title, isNull);
      expect(conversations.single.updatedAt, DateTime.parse('2026-09-01T10:05:00Z'));
    });

    test('propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = ChatService(apiClient: fakeClient);

      await expectLater(service.fetchConversations(), throwsA(isA<ApiException>()));
    });
  });

  group('ChatService.fetchMessages', () {
    test('GETs the conversation messages path and parses them', () async {
      final fakeClient = _FakeApiClient(listResponse: [
        {
          'id': 'm1',
          'role': 'user',
          'content': '¿Cuánto debo dormir?',
          'created_at': '2026-09-01T10:00:00Z',
        },
        {
          'id': 'm2',
          'role': 'assistant',
          'content': 'Entre 7 y 9 horas.',
          'created_at': '2026-09-01T10:00:05Z',
        },
      ]);
      final service = ChatService(apiClient: fakeClient);

      final messages = await service.fetchMessages('c1');

      expect(fakeClient.getListPaths, ['/chat/conversations/c1/messages']);
      expect(messages, hasLength(2));
      expect(messages[0].role, 'user');
      expect(messages[1].role, 'assistant');
      expect(messages[1].content, 'Entre 7 y 9 horas.');
    });

    test('propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = ChatService(apiClient: fakeClient);

      await expectLater(service.fetchMessages('c1'), throwsA(isA<ApiException>()));
    });
  });

  group('ChatService.deleteConversation', () {
    test('DELETEs the conversation path', () async {
      final fakeClient = _FakeApiClient();
      final service = ChatService(apiClient: fakeClient);

      await service.deleteConversation('c1');

      expect(fakeClient.deletedPaths, ['/chat/conversations/c1']);
    });

    test('propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = ChatService(apiClient: fakeClient);

      await expectLater(service.deleteConversation('c1'), throwsA(isA<ApiException>()));
    });
  });
}
