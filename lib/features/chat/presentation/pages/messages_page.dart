import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  final _chatService = TripChatService();
  List<ChatEntryData> _entries = [];
  bool _loading = true;
  bool _openingChat = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.03, end: 0.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = AuthState.userId ?? '';
    final driverProfileId = AuthState.driverProfileId;
    final providerProfileId = AuthState.providerProfileId;

    List<ChatEntryData> entries;
    if (AuthState.isDriver && driverProfileId != null) {
      entries = await _chatService.getChatsForDriver(driverProfileId, userId);
    } else if (providerProfileId != null) {
      entries = await _chatService.getChatsForServiceProvider(
        providerProfileId,
        userId,
      );
    } else {
      entries = [];
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _openChat(ChatEntryData entry) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);

    try {
      final userId = AuthState.userId ?? '';
      String? roomId;

      if (entry.roomId != null) {
        roomId = entry.roomId!;
      } else {
        roomId = await _chatService.getOrCreateChatRoom(
          tripId: entry.isTrip ? entry.referenceId : null,
          serviceRequestId: entry.isTrip ? null : entry.referenceId,
          clientId: entry.clientId,
          providerId: userId,
        );
      }

      if (!mounted) return;

      if (roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o chat. Tente novamente.'),
          ),
        );
        return;
      }

      context.push(
        '/chat/$roomId',
        extra: ChatPageArgs(
          roomId: roomId,
          title: entry.title,
          subtitle: entry.subtitle,
          clientName: entry.clientName,
          clientAvatarUrl: entry.clientAvatarUrl,
          clientId: entry.clientId,
          tripId: entry.isTrip ? entry.referenceId : null,
          serviceRequestId: entry.isTrip ? null : entry.referenceId,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mensagens',
          style: TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_entries.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma mensagem',
                    style: TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final entry = _entries[i];
                  if (entry.unreadCount > 0) {
                    return AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => _ConversationTile(
                        entry: entry,
                        onTap: () => _openChat(entry),
                        pulseAlpha: _pulseAnimation.value,
                      ),
                    );
                  }
                  return _ConversationTile(
                    entry: entry,
                    onTap: () => _openChat(entry),
                  );
                },
              ),
            ),
          if (_openingChat)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatEntryData entry;
  final VoidCallback onTap;
  final double? pulseAlpha;

  const _ConversationTile({
    required this.entry,
    required this.onTap,
    this.pulseAlpha,
  });

  @override
  Widget build(BuildContext context) {
    final unread = entry.unreadCount;
    final hasUnread = unread > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasUnread && pulseAlpha != null
              ? Color.lerp(Colors.white, AppColors.secondary, pulseAlpha!)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              backgroundImage:
                  entry.clientAvatarUrl != null &&
                      entry.clientAvatarUrl!.isNotEmpty
                  ? NetworkImage(entry.clientAvatarUrl!)
                  : null,
              child:
                  entry.clientAvatarUrl == null ||
                      entry.clientAvatarUrl!.isEmpty
                  ? Text(
                      entry.clientName.isNotEmpty ? entry.clientName[0] : '?',
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 18,
                        color: AppColors.secondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.clientName,
                    style: const TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (entry.subtitle.isNotEmpty)
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (entry.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.lastMessage!,
                      style: TextStyle(
                        fontFamily: 'QuasimodoSemiBold',
                        fontSize: 13,
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (hasUnread)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
