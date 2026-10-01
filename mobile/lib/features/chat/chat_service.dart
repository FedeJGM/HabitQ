import '../../core/networking/api_client.dart';

class ChatSource {
  const ChatSource({
    required this.documentId,
    required this.title,
    this.organization,
    this.sourceUrl,
  });

  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
        documentId: json['document_id'] as String,
        title: json['title'] as String,
        organization: json['organization'] as String?,
        sourceUrl: json['source_url'] as String?,
      );

  final String documentId;
  final String title;
  final String? organization;
  final String? sourceUrl;
}

class ChatMessage {
  const ChatMessage({required this.id, required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
      );

  final String id;
  final String role;
  final String content;
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

  final ApiClient _apiClient;

  Future<ChatTurn> sendMessage(String message, {String? conversationId}) async {
    final response = await _apiClient.post('/chat', {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });
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
