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
}
