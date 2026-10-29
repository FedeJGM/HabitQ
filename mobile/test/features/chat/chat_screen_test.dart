import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_routes.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/core/widgets/error_notice.dart';
import 'package:mobile/features/chat/chat_screen.dart';
import 'package:mobile/features/chat/chat_service.dart';
import 'package:material_symbols_icons/symbols.dart';

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
      of: find.byIcon(Symbols.send_rounded),
      matching: find.byType(IconButton),
    );

void main() {
  Widget buildApp(ChatService chatService, {UrlOpener? urlOpener}) {
    return MaterialApp(home: ChatScreen(chatService: chatService, urlOpener: urlOpener));
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

  testWidgets('renders Markdown in the assistant reply without literal asterisks',
      (tester) async {
    final fakeService = _FakeChatService(responses: [
      _turn(
        conversationId: 'c1',
        content: '* **Actividad física y ejercicio:** caminá 30 minutos.\n'
            '* Dormí entre 7 y 9 horas.',
      ),
    ]);
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), 'Dame consejos');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Actividad física y ejercicio', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('*', findRichText: true), findsNothing);
  });

  testWidgets('scrolls to the start of a long assistant reply, not its end', (tester) async {
    final paragraphs = [for (var i = 1; i <= 40; i++) 'Parrafo $i de la respuesta.'];
    final fakeService = _FakeChatService(responses: [
      _turn(conversationId: 'c1', content: paragraphs.join('\n\n')),
    ]);
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), 'Dame una respuesta larga');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final firstTop =
        tester.getTopLeft(find.textContaining('Parrafo 1 de', findRichText: true)).dy;
    expect(firstTop, greaterThanOrEqualTo(0));
    expect(firstTop, lessThan(screenHeight));
  });

  testWidgets('shows a full reference list under the assistant reply', (tester) async {
    final fakeService = _FakeChatService(responses: [
      _turn(
        conversationId: 'c1',
        content: 'Dormí entre 7 y 9 horas.',
        sources: const [
          ChatSource(
            documentId: 'd1',
            title: 'Sleep and health',
            organization: 'Sleep Journal',
            authors: 'Doe J.',
            year: 2024,
            doi: '10.1/abc',
            pages: [3],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(buildApp(fakeService));

    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(find.text('Referencias'), findsOneWidget);
    expect(find.textContaining('Doe J (2024). Sleep and health. Sleep Journal.'), findsOneWidget);
    expect(find.textContaining('Pág. 3'), findsOneWidget);
    expect(find.text('https://doi.org/10.1/abc'), findsOneWidget);
  });

  group('reference links', () {
    ChatService serviceWithSource(ChatSource source) => _FakeChatService(responses: [
          _turn(conversationId: 'c1', content: 'Entre 7 y 9 horas.', sources: [source]),
        ]);

    Future<void> sendOneMessage(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
      await tester.pump();
      await tester.tap(_sendButton());
      await tester.pumpAndSettle();
    }

    testWidgets('tapping the link opens it in the external app', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(buildApp(
        serviceWithSource(
          const ChatSource(documentId: 'd1', title: 'Sleep', doi: '10.1/abc'),
        ),
        urlOpener: (uri) async {
          opened.add(uri);
          return true;
        },
      ));

      await sendOneMessage(tester);
      await tester.tap(find.text('https://doi.org/10.1/abc'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://doi.org/10.1/abc')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tells the user when the link cannot be opened', (tester) async {
      await tester.pumpWidget(buildApp(
        serviceWithSource(
          const ChatSource(documentId: 'd1', title: 'Sleep', doi: '10.1/abc'),
        ),
        urlOpener: (uri) async => false,
      ));

      await sendOneMessage(tester);
      await tester.tap(find.text('https://doi.org/10.1/abc'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    });

    testWidgets('tells the user when opening the link throws', (tester) async {
      await tester.pumpWidget(buildApp(
        serviceWithSource(
          const ChatSource(documentId: 'd1', title: 'Sleep', doi: '10.1/abc'),
        ),
        urlOpener: (uri) async => throw Exception('no handler'),
      ));

      await sendOneMessage(tester);
      await tester.tap(find.text('https://doi.org/10.1/abc'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    });

    testWidgets('shows no link for a source with an unsafe URL', (tester) async {
      await tester.pumpWidget(buildApp(
        serviceWithSource(
          const ChatSource(documentId: 'd1', title: 'Sleep', sourceUrl: 'javascript:alert(1)'),
        ),
      ));

      await sendOneMessage(tester);

      expect(find.textContaining('javascript'), findsNothing);
      expect(find.byKey(const ValueKey('reference-link-d1')), findsNothing);
    });
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

  testWidgets('shows the stored references of preloaded assistant messages', (tester) async {
    final fakeService = _FakeChatService(
      historyMessages: [
        const ChatMessage(id: 'm1', role: 'user', content: '¿Cuánto debo dormir?'),
        const ChatMessage(
          id: 'm2',
          role: 'assistant',
          content: 'Entre 7 y 9 horas.',
          sources: [
            ChatSource(
              documentId: 'd1',
              title: 'Sleep and health',
              organization: 'Sleep Journal',
              authors: 'Doe J.',
              year: 2024,
              doi: '10.1/abc',
              pages: [3],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chatService: fakeService, conversationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Referencias'), findsOneWidget);
    expect(find.textContaining('Doe J (2024). Sleep and health. Sleep Journal.'), findsOneWidget);
    expect(find.text('https://doi.org/10.1/abc'), findsOneWidget);
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

  testWidgets('a failed send offers Reintentar, which asks the same question again once', (tester) async {
    final fakeService = _FakeChatService(
      error: ApiConnectionException(),
      responses: [_turn(conversationId: 'c1', content: 'Aquí tienes la respuesta.')],
    );
    await tester.pumpWidget(buildApp(fakeService));
    await tester.enterText(find.byType(TextField), '¿Cuánto debo dormir?');
    await tester.pump();
    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(find.byType(ErrorNotice), findsOneWidget);
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);

    fakeService.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(fakeService.sentMessages, ['¿Cuánto debo dormir?', '¿Cuánto debo dormir?']);
    expect(find.text('¿Cuánto debo dormir?'), findsOneWidget);
    expect(find.text('Aquí tienes la respuesta.'), findsOneWidget);
    expect(find.byType(ErrorNotice), findsNothing);
  });

  testWidgets('a failed history load offers Reintentar', (tester) async {
    final fakeService = _FakeChatService(
      historyError: ApiException('No se pudo cargar la conversación.'),
      historyMessages: [const ChatMessage(id: 'm1', role: 'user', content: 'Hola de nuevo')],
    );
    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(chatService: fakeService, conversationId: 'c9')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorNotice), findsOneWidget);

    fakeService.historyError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.byType(ErrorNotice), findsNothing);
    expect(fakeService.fetchMessagesConversationIds, ['c9', 'c9']);
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

    await tester.tap(find.byIcon(Symbols.history_rounded));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
  });
}
