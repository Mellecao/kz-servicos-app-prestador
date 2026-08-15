import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/support_chat_service.dart';

class SupportChatPage extends StatefulWidget {
  final String? initialDraft;
  const SupportChatPage({super.key, this.initialDraft});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _service = SupportChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<List<SupportMessageData>>? _subscription;
  SupportConversationData? _conversation;
  List<SupportMessageData> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _currentUserId => AuthState.userId ?? '';

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.initialDraft?.trim() ?? '';
    _initialize();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _subscription?.cancel();
    _subscription = null;
    final userId = _currentUserId;
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sessão expirada. Entre novamente.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final conversation = await _service.getOrCreateConversation(userId);
      if (!mounted) return;
      setState(() => _conversation = conversation);
      _subscription = _service
          .subscribeToMessages(conversation.id)
          .listen(
            (messages) {
              if (!mounted) return;
              final hasUnread = messages.any(
                (message) => message.senderId != userId && !message.isRead,
              );
              setState(() {
                _messages = messages;
                _loading = false;
              });
              _scrollToBottom();
              if (hasUnread) {
                unawaited(_markRead(conversation.id, userId));
              }
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _loading = false;
                _error = 'Não foi possível acompanhar as mensagens.';
              });
            },
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível abrir o chat com a KZ.';
      });
    }
  }

  Future<void> _markRead(String conversationId, String userId) async {
    try {
      await _service.markMessagesRead(
        conversationId: conversationId,
        readerId: userId,
      );
    } catch (_) {
      // Realtime will retry the read state when the next message arrives.
    }
  }

  Future<void> _sendMessage() async {
    final conversation = _conversation;
    final text = _messageController.text.trim();
    if (conversation == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        conversationId: conversation.id,
        senderId: _currentUserId,
        message: text,
      );
      if (mounted) _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a mensagem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.secondary,
              child: Text(
                'KZ',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OutfitBlack',
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat com a KZ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Suporte',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _SupportChatError(message: _error!, onRetry: _initialize)
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma mensagem ainda.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _SupportMessageBubble(
                              message: message,
                              isFromProvider:
                                  message.senderId == _currentUserId,
                            );
                          },
                        ),
                ),
                _SupportComposer(
                  controller: _messageController,
                  sending: _sending,
                  onSend: _sendMessage,
                ),
              ],
            ),
    );
  }
}

class _SupportChatError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SupportChatError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportMessageBubble extends StatelessWidget {
  final SupportMessageData message;
  final bool isFromProvider;

  const _SupportMessageBubble({
    required this.message,
    required this.isFromProvider,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(
      message.createdAt.toLocal(),
    ).format(context);
    return Align(
      alignment: isFromProvider ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        decoration: BoxDecoration(
          color: isFromProvider ? AppColors.secondary : Colors.white,
          border: isFromProvider
              ? null
              : Border.all(color: const Color(0xFFE4E6EA)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isFromProvider ? 14 : 4),
            bottomRight: Radius.circular(isFromProvider ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: isFromProvider ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                color: isFromProvider
                    ? Colors.white.withValues(alpha: 0.72)
                    : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _SupportComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE4E6EA))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Escreva uma mensagem',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
