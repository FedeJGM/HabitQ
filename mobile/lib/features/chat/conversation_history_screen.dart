import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'chat_service.dart';

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _formatUpdatedAt(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]}, $hour:$minute';
}

/// Lists past conversations (GET /chat/conversations). Tapping one reopens
/// it in ChatScreen with its messages preloaded; deleting removes it from
/// both the backend and this list without a full reload.
class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key, this.chatService});

  final ChatService? chatService;

  @override
  State<ConversationHistoryScreen> createState() => _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  late final ChatService _chatService;
  List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await _chatService.fetchConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDelete(ConversationSummary conversation) async {
    try {
      await _chatService.deleteConversation(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversations = _conversations.where((c) => c.id != conversation.id).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  void _handleOpen(ConversationSummary conversation) {
    Navigator.of(context).pushNamed(AppRoutes.chat, arguments: conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de conversaciones')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    ),
                  Expanded(
                    child: _conversations.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Todavía no tenés conversaciones.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(_formatUpdatedAt(conversation.updatedAt)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Borrar conversación',
                                    onPressed: () => _handleDelete(conversation),
                                  ),
                                  onTap: () => _handleOpen(conversation),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
