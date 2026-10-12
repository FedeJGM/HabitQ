import '../../core/networking/api_client.dart';

class ChatSource {
  const ChatSource({
    required this.documentId,
    required this.title,
    this.organization,
    this.sourceUrl,
    this.authors,
    this.year,
    this.doi,
    this.pages = const [],
  });

  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
        documentId: json['document_id'] as String,
        title: json['title'] as String,
        organization: json['organization'] as String?,
        sourceUrl: json['source_url'] as String?,
        authors: json['authors'] as String?,
        year: json['year'] as int?,
        doi: json['doi'] as String?,
        pages: ((json['pages'] as List?) ?? const []).cast<int>(),
      );

  final String documentId;
  final String title;
  final String? organization;
  final String? sourceUrl;
  final String? authors;
  final int? year;
  final String? doi;
  final List<int> pages;

  /// Where the reader can open the paper: the DOI link when there is a DOI,
  /// otherwise the source URL. Null when neither is usable. Only http(s) URLs
  /// with a host qualify: the values come from third-party metadata and must
  /// never become a `javascript:` or `file:` link.
  Uri? get link {
    final doiValue = doi;
    if (doiValue != null && doiValue.isNotEmpty) {
      return Uri.https('doi.org', '/$doiValue');
    }

    final url = sourceUrl == null ? null : Uri.tryParse(sourceUrl!);
    if (url == null || url.host.isEmpty) return null;
    return url.scheme == 'https' || url.scheme == 'http' ? url : null;
  }

  /// One-line reference without the link: "Authors (Year). Title. Journal. Págs. 1, 3."
  /// Missing pieces are skipped.
  String get citation {
    String trimmed(String text) => text.replaceAll(RegExp(r'\.+\s*$'), '');

    final cleanAuthors = authors == null ? null : trimmed(authors!);
    final head = [
      if (cleanAuthors != null && cleanAuthors.isNotEmpty) cleanAuthors,
      if (year != null) '($year)',
    ].join(' ');
    final sentences = [
      if (head.isNotEmpty) head,
      trimmed(title),
      if (organization != null) trimmed(organization!),
    ];

    final pagesText = switch (pages.length) {
      0 => null,
      1 => 'Pág. ${pages.single}',
      _ => 'Págs. ${pages.join(', ')}',
    };

    return '${sentences.join('. ')}.${pagesText == null ? '' : ' $pagesText.'}';
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        sources: ((json['sources'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ChatSource.fromJson)
            .toList(),
      );

  final String id;
  final String role;
  final String content;
  final List<ChatSource> sources;
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: json['id'] as String,
        title: json['title'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String id;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ChatTurn {
  const ChatTurn({required this.conversationId, required this.message, required this.sources});

  factory ChatTurn.fromJson(Map<String, dynamic> json) => ChatTurn(
        conversationId: json['conversation_id'] as String,
        message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
        sources: (json['sources'] as List)
            .cast<Map<String, dynamic>>()
            .map(ChatSource.fromJson)
            .toList(),
      );

  final String conversationId;
  final ChatMessage message;
  final List<ChatSource> sources;
}

/// Wraps POST /chat. Each call is one turn; the caller is responsible for
/// carrying `conversationId` forward across turns in the same session (see
/// [ChatScreen]) so the backend keeps them in the same conversation.
class ChatService {
  ChatService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// POST /chat runs embedding, DB search and the LLM, so it can take well over
  /// the default 15s (e.g. the first question after a backend restart).
  static const chatRequestTimeout = Duration(seconds: 60);

  final ApiClient _apiClient;

  Future<ChatTurn> sendMessage(String message, {String? conversationId}) async {
    final response = await _apiClient.post(
      '/chat',
      {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      },
      timeout: chatRequestTimeout,
    );
    return ChatTurn.fromJson(response);
  }

  Future<List<ConversationSummary>> fetchConversations() async {
    final results = await _apiClient.getList('/chat/conversations');
    return results.cast<Map<String, dynamic>>().map(ConversationSummary.fromJson).toList();
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final results = await _apiClient.getList('/chat/conversations/$conversationId/messages');
    return results.cast<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  Future<void> deleteConversation(String conversationId) {
    return _apiClient.delete('/chat/conversations/$conversationId');
  }
}
