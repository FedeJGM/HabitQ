import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/chat/chat_service.dart';
import 'package:mobile/features/chat/conversation_history_screen.dart';

class _FakeChatService implements ChatService {
  _FakeChatService({this.conversations, this.fetchError, this.deleteError});

  List<ConversationSummary>? conversations;
  ApiException? fetchError;
  ApiException? deleteError;
  final List<String> deletedIds = [];

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    if (fetchError != null) throw fetchError!;
    return conversations ?? [];
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    if (deleteError != null) throw deleteError!;
    deletedIds.add(conversationId);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) {
    throw UnimplementedError();
  }

  @override
  Future<ChatTurn> sendMessage(String message, {String? conversationId}) {
    throw UnimplementedError();
  }
}

void main() {
  Widget buildApp(ChatService chatService) {
    return MaterialApp(
      routes: {
        AppRoutes.chat: (context) => Scaffold(
              body: Text('Chat:${ModalRoute.of(context)!.settings.arguments}'),
            ),
      },
      home: ConversationHistoryScreen(chatService: chatService),
    );
  }

  testWidgets('shows an empty state when there are no conversations', (tester) async {
    final fakeService = _FakeChatService(conversations: []);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tenés conversaciones.'), findsOneWidget);
  });

  testWidgets('lists the fetched conversations', (tester) async {
    final fakeService = _FakeChatService(conversations: [
      ConversationSummary(
        id: 'c1',
        title: null,
        createdAt: DateTime(2026, 9, 1, 10, 0),
        updatedAt: DateTime(2026, 9, 2, 14, 32),
      ),
    ]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 sep'), findsOneWidget);
  });

  testWidgets('shows an error message when fetching fails', (tester) async {
    final fakeService = _FakeChatService(fetchError: ApiException('boom'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('tapping a conversation navigates to ChatScreen with its id', (tester) async {
    final fakeService = _FakeChatService(conversations: [
      ConversationSummary(
        id: 'c1',
        title: null,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 2, 14, 32),
      ),
    ]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('2 sep'));
    await tester.pumpAndSettle();

    expect(find.text('Chat:c1'), findsOneWidget);
  });

  testWidgets('deleting a conversation removes it from the list', (tester) async {
    final fakeService = _FakeChatService(conversations: [
      ConversationSummary(
        id: 'c1',
        title: null,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 2, 14, 32),
      ),
    ]);
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(fakeService.deletedIds, ['c1']);
    expect(find.text('Todavía no tenés conversaciones.'), findsOneWidget);
  });

  testWidgets('shows an error and keeps the item when deleting fails', (tester) async {
    final fakeService = _FakeChatService(
      conversations: [
        ConversationSummary(
          id: 'c1',
          title: null,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 2, 14, 32),
        ),
      ],
      deleteError: ApiException('No se pudo borrar.'),
    );
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo borrar.'), findsOneWidget);
    expect(find.textContaining('2 sep'), findsOneWidget);
  });
}
