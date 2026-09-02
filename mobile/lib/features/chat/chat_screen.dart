import 'package:flutter/material.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'chat_service.dart';

class _DisplayMessage {
  const _DisplayMessage({required this.role, required this.content, this.sources = const []});

  final String role;
  final String content;
  final List<ChatSource> sources;
}

/// Chat with HabitQ. Each screen instance is its own session: it starts
/// empty (no history loaded — that's the separate "historial" feature) and
/// carries the conversationId returned by the first reply forward to
/// subsequent messages, so the backend keeps them in the same conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.chatService});

  final ChatService? chatService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_DisplayMessage> _messages = [];
  String? _conversationId;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSend => !_isSending && _controller.text.trim().isNotEmpty;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_DisplayMessage(role: 'user', content: text));
      _isSending = true;
      _errorMessage = null;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final turn = await _chatService.sendMessage(text, conversationId: _conversationId);
      if (!mounted) return;
      setState(() {
        _conversationId = turn.conversationId;
        _messages.add(
          _DisplayMessage(
            role: turn.message.role,
            content: turn.message.content,
            sources: turn.sources,
          ),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    _scrollToBottom();
  }

  Widget _buildBubble(_DisplayMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.background,
          border: isUser ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final source in message.sources)
                Text(
                  source.organization != null
                      ? '${source.title} — ${source.organization}'
                      : source.title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat con HabitQ')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Preguntame lo que quieras sobre hábitos saludables.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return _buildBubble(_messages[index]);
                      },
                    ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribí tu pregunta...',
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _canSend ? _handleSend : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
