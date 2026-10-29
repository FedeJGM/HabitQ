import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/core/widgets/error_notice.dart';
import 'package:mobile/core/widgets/skeleton.dart';
import 'package:mobile/features/chat/chat_service.dart';
import 'package:mobile/features/chat/conversation_history_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

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

  testWidgets('the empty state is the shared EmptyState block', (tester) async {
    await tester.pumpWidget(buildApp(_FakeChatService(conversations: [])));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('shows skeletons, not a spinner, while loading', (tester) async {
    await tester.pumpWidget(buildApp(_FakeChatService(conversations: [])));

    expect(find.byType(SkeletonCard), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed load offers Reintentar and recovers', (tester) async {
    final fakeService = _FakeChatService(fetchError: ApiException('boom'));
    await tester.pumpWidget(buildApp(fakeService));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorNotice), findsOneWidget);

    fakeService
      ..fetchError = null
      ..conversations = [
        ConversationSummary(
          id: 'c1',
          title: null,
          createdAt: DateTime(2026, 9, 1, 10, 0),
          updatedAt: DateTime(2026, 9, 2, 14, 32),
        ),
      ];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorNotice), findsNothing);
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

    await tester.tap(find.byIcon(Symbols.delete_rounded));
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

    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo borrar.'), findsOneWidget);
    expect(find.textContaining('2 sep'), findsOneWidget);
  });
}
