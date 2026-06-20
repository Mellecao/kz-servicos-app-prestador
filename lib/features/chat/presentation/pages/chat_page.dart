import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ChatPage extends StatefulWidget {
  final ChatPageArgs args;

  const ChatPage({super.key, required this.args});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatService = TripChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessageData> _messages = [];
  bool _sending = false;
  StreamSubscription<List<ChatMessageData>>? _subscription;
  RealtimeChannel? _tripChannel;

  static const _presets = [
    'Estou a caminho',
    'Cheguei ao local',
    'Aguardando passageiro',
    'Trânsito intenso',
    'Preciso de ajuda',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _subscribeToTripCancellation();
    _markRead();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tripChannel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToTripCancellation() {
    final tripId = widget.args.tripId;
    if (tripId == null) return;
    _tripChannel = Supabase.instance.client
        .channel('chat-trip-cancel-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tripId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete ||
                payload.newRecord['status'] == 'cancelled') {
              _handleRemoteCancellation();
            }
          },
        )
        .subscribe();
  }

  void _handleRemoteCancellation() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta corrida foi cancelada pela KZ.')),
    );
    context.go('/home');
  }

  void _subscribeToMessages() {
    _subscription = _chatService.subscribeToMessages(widget.args.roomId).listen(
      (messages) {
        if (mounted) {
          final currentUserId = AuthState.userId ?? '';
          final hasNewUnread = messages.any(
            (m) => m.senderId != currentUserId && !m.isRead,
          );
          setState(() => _messages = messages);
          _scrollToBottom();
          if (hasNewUnread) _markRead();
        }
      },
    );
  }

  Future<void> _markRead() async {
    final userId = AuthState.userId;
    if (userId != null) {
      await _chatService.markMessagesRead(widget.args.roomId, userId);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;
    final userId = AuthState.userId ?? '';
    final trimmed = text.trim();
    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(widget.args.roomId, userId, trimmed);
      if (mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final tripId = widget.args.tripId;
    if (tripId != null && tripId.isNotEmpty) {
      context.go('/active-trip?tripId=${Uri.encodeComponent(tripId)}');
      return;
    }
    context.go('/messages');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthState.userId ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
              backgroundImage:
                  widget.args.clientAvatarUrl != null &&
                      widget.args.clientAvatarUrl!.isNotEmpty
                  ? NetworkImage(widget.args.clientAvatarUrl!)
                  : null,
              child:
                  widget.args.clientAvatarUrl == null ||
                      widget.args.clientAvatarUrl!.isEmpty
                  ? Text(
                      widget.args.clientName.isNotEmpty
                          ? widget.args.clientName[0]
                          : '?',
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.args.clientName,
                    style: const TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.args.title.isNotEmpty ||
                      widget.args.subtitle.isNotEmpty)
                    Text(
                      widget.args.title.isNotEmpty
                          ? widget.args.title
                          : widget.args.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.args.title.isNotEmpty || widget.args.subtitle.isNotEmpty)
            _TripDetailsHeader(args: widget.args),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return _MessageBubble(
                  message: msg,
                  isFromMe: msg.senderId == currentUserId,
                  clientName: widget.args.clientName,
                  clientAvatarUrl: widget.args.clientAvatarUrl,
                );
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _presets.length,
              separatorBuilder: (context2, index2) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _sendMessage(_presets[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _presets[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetailsHeader extends StatelessWidget {
  final ChatPageArgs args;

  const _TripDetailsHeader({required this.args});

  @override
  Widget build(BuildContext context) {
    final details = args.subtitle.isNotEmpty ? args.subtitle : args.title;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.highlight.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  args.title.isNotEmpty ? args.title : 'Corrida',
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageData message;
  final bool isFromMe;
  final String clientName;
  final String? clientAvatarUrl;

  const _MessageBubble({
    required this.message,
    required this.isFromMe,
    required this.clientName,
    this.clientAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondary,
              backgroundImage:
                  clientAvatarUrl != null && clientAvatarUrl!.isNotEmpty
                  ? NetworkImage(clientAvatarUrl!)
                  : null,
              child: clientAvatarUrl == null || clientAvatarUrl!.isEmpty
                  ? Text(
                      clientName.isNotEmpty ? clientName[0] : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isFromMe ? AppColors.secondary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                bottomRight: Radius.circular(isFromMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isFromMe ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isFromMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
