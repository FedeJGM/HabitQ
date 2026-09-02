import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/chat/chat_screen.dart';
import 'package:mobile/features/chat/chat_service.dart';

class _FakeChatService implements ChatService {
  _FakeChatService({
    this.responses = const [],
    this.error,
    this.historyMessages,
    this.historyError,
  });

  List<ChatTurn> responses;
  ApiException? error;
  List<ChatMessage>? historyMessages;
  ApiException? historyError;
  final List<String> sentMessages = [];
  final List<String?> sentConversationIds = [];
  final List<String> fetchMessagesConversationIds = [];
  int _callCount = 0;
  Completer<void>? gate;

  @override
  Future<ChatTurn> sendMessage(String message, {String? conversationId}) async {
    sentMessages.add(message);
    sentConversationIds.add(conversationId);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    final turn = responses[_callCount];
    _callCount++;
    return turn;
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    fetchMessagesConversationIds.add(conversationId);
    if (historyError != null) throw historyError!;
    return historyMessages ?? [];
  }

  @override
  Future<List<ConversationSummary>> fetchConversations() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    throw UnimplementedError();
  }
}

ChatTurn _turn({
  required String conversationId,
  required String content,
  List<ChatSource> sources = const [],
}) {
  return ChatTurn(
    conversationId: conversationId,
    message: ChatMessage(id: 'm-$content', role: 'assistant', content: content),
    sources: sources,
  );
}

/// Finds the send IconButton (find.byIcon matches the Icon glyph itself,
/// which is nested inside the actual IconButton).
Finder _sendButton() => find.ancestor(
      of: find.byIcon(Icons.send),
      matching: find.byType(IconButton),
    );

void main() {
  Widget buildApp(ChatService chatService) {
    return MaterialApp(home: ChatScreen(chatService: chatService));
  }

  testWidgets('send button is disabled when the input is empty', (tester) async {
    final fakeService = _FakeChatService();
    await tester.pumpWidget(buildApp(fakeService));

    final sendButton = tester.widget<IconButton>(_sendButton());
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('shows the user message immediately, then the assistant reply with sources',
      (tester) async {
    final fakeService = _FakeChatService(responses: [
      _turn(
        conversationId: 'c1',
        content: 'Dormí entre 7 y 9 horas.',
        sources: const [
          ChatSource(documentId: 'd1', title: 'Healthy Sleep', organization: 'CDC'),
        ],
      ),
    ]);
    fakeService.gate = Completer<void>();
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pump();

    // User message shown immediately, before the backend call resolves.
    expect(find.text('¿Cuánto debo dormir?'), findsOneWidget);
    expect(find.text('Dormí entre 7 y 9 horas.'), findsNothing);

    fakeService.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Dormí entre 7 y 9 horas.'), findsOneWidget);
    expect(find.textContaining('Healthy Sleep'), findsOneWidget);
    expect(find.textContaining('CDC'), findsOneWidget);
  });

  testWidgets('clears the input after sending', (tester) async {
    final fakeService = _FakeChatService(responses: [
      _turn(conversationId: 'c1', content: 'Entre 7 y 9 horas.'),
    ]);
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets('reuses the conversationId from the first reply on the next message',
      (tester) async {
    final fakeService = _FakeChatService(responses: [
      _turn(conversationId: 'c1', content: 'Entre 7 y 9 horas.'),
      _turn(conversationId: 'c1', content: 'Entre 8 y 10 horas.'),
    ]);
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '¿Y para adolescentes?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(fakeService.sentConversationIds, [null, 'c1']);
  });

  testWidgets('shows an error message when sending fails, without crashing the screen',
      (tester) async {
    final fakeService = _FakeChatService(error: ApiException('No se pudo conectar con el servidor.'));
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.text('¿Cuánto debo dormir?'), findsOneWidget);
  });

  testWidgets('preloads history when opened with a conversationId', (tester) async {
    final fakeService = _FakeChatService(
      historyMessages: [
        const ChatMessage(id: 'm1', role: 'user', content: '¿Cuánto debo dormir?'),
        const ChatMessage(id: 'm2', role: 'assistant', content: 'Entre 7 y 9 horas.'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chatService: fakeService, conversationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(fakeService.fetchMessagesConversationIds, ['c1']);
    expect(find.text('¿Cuánto debo dormir?'), findsOneWidget);
    expect(find.text('Entre 7 y 9 horas.'), findsOneWidget);
  });

  testWidgets('sends the next message under the preloaded conversationId', (tester) async {
    final fakeService = _FakeChatService(
      historyMessages: [
        const ChatMessage(id: 'm1', role: 'user', content: '¿Cuánto debo dormir?'),
      ],
      responses: [_turn(conversationId: 'c1', content: 'Entre 7 y 9 horas.')],
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chatService: fakeService, conversationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '¿Y para adolescentes?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(fakeService.sentConversationIds, ['c1']);
  });

  testWidgets('shows an error when loading history fails', (tester) async {
    final fakeService = _FakeChatService(
      historyError: ApiException('No se pudo cargar la conversación.'),
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chatService: fakeService, conversationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la conversación.'), findsOneWidget);
  });

  testWidgets('history icon navigates to the chat history route', (tester) async {
    final fakeService = _FakeChatService();
    await tester.pumpWidget(MaterialApp(
      routes: {
        AppRoutes.chatHistory: (_) => const Scaffold(body: Text('History')),
      },
      home: ChatScreen(chatService: fakeService),
    ));

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
  });
}
