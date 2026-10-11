import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_shell.dart';
import 'chat_service.dart';

class _DisplayMessage {
  const _DisplayMessage({required this.role, required this.content, this.sources = const []});

  final String role;
  final String content;
  final List<ChatSource> sources;
}

/// Chat with HabitQ. Each screen instance is its own session: it starts
/// empty unless opened with [conversationId] (from ConversationHistoryScreen
/// — via constructor for tests, or the pushNamed route argument otherwise),
/// in which case its prior messages are preloaded. Either way, the
/// conversationId in play is carried forward to subsequent messages, so the
/// backend keeps them in the same conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.chatService, this.conversationId});

  final ChatService? chatService;
  final String? conversationId;

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
  bool _isLoadingHistory = false;
  String? _errorMessage;
  bool _initializedFromArguments = false;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArguments) return;
    _initializedFromArguments = true;

    final resolvedId =
        widget.conversationId ?? (ModalRoute.of(context)?.settings.arguments as String?);
    if (resolvedId != null) {
      _conversationId = resolvedId;
      _loadHistory(resolvedId);
    }
  }

  Future<void> _loadHistory(String conversationId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final messages = await _chatService.fetchMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(
          messages.map((m) => _DisplayMessage(role: m.role, content: m.content)),
        );
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingHistory = false;
      });
    }
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.white,
          border: isUser ? null : Border.all(color: const Color(0xFF79747E), width: 0.2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 13,
                color: isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Referencias',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              for (final source in message.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // Selectable so the user can copy the DOI/link (no
                  // url_launcher dependency in the app yet).
                  child: SelectableText(
                    source.citation,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HabitQShell(
      currentTab: HabitQTab.chat,
      onLogout: () => signOutAndGoToLogin(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    'Chat con HabitQ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.chatHistory),
                  icon: const Icon(Icons.history),
                  tooltip: 'Historial de conversaciones',
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0x33787878),
                border: Border.all(color: const Color(0xFF79747E), width: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _isLoadingHistory
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
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
                            padding: const EdgeInsets.all(12),
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
                    padding: const EdgeInsets.all(8),
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
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
