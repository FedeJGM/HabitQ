import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_notice.dart';
import '../../core/widgets/skeleton.dart';
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
  bool _loadFailed = false;
  bool _errorIsConnection = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _errorMessage = null;
    });
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
        _errorIsConnection = e is ApiConnectionException;
        _loadFailed = true;
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
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 4))
            : Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorNotice(
                        message: _errorMessage!,
                        isConnection: _errorIsConnection,
                        onRetry: _loadFailed ? _load : null,
                      ),
                    ),
                  Expanded(
                    child: _conversations.isEmpty
                        ? const Center(
                            child: EmptyState(
                              icon: Symbols.forum_rounded,
                              title: 'Todavía no tenés conversaciones.',
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
                                    Symbols.chat_bubble_rounded,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(_formatUpdatedAt(conversation.updatedAt)),
                                  trailing: IconButton(
                                    icon: const Icon(Symbols.delete_rounded),
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
