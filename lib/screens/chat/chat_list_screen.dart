// lib/screens/chat_list_screen.dart

// ignore_for_file: unused_field

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';
import 'package:dartobra_new/models/chat/chat_model.dart';
import 'package:dartobra_new/services/chat/chat_service.dart';
import 'package:dartobra_new/services/chat/firebase_service.dart';
import 'package:dartobra_new/services/chat/user_lookup_service.dart';
import 'package:dartobra_new/widgets/common/online_status_indicator.dart';
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const ChatListScreen({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final ChatServiceFinal _chatService = ChatServiceFinal();
  final FirebaseService _firebase = FirebaseService();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mensagens',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Badge indicator TOTAL
          StreamBuilder<BadgeData>(
            stream: BadgeHelper.getBadgeStream(widget.userId),
            builder: (context, snapshot) {
              final badgeData = snapshot.data;
              if (badgeData == null || badgeData.unreadChats == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${badgeData.unreadChats}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Connection status
          StreamBuilder<bool>(
            stream: _firebase.connectionState,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            // Tab CONTRACTOR com badge
            StreamBuilder<int>(
              stream: BadgeHelper.getUnreadCountByRoleStream(
                widget.userId,
                'contractor',
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.work_outline, size: 20),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Contratante',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // Tab EMPLOYEE com badge
            StreamBuilder<int>(
              stream: BadgeHelper.getUnreadCountByRoleStream(
                widget.userId,
                'employee',
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Funcionário',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chats como CONTRATANTE
          _ChatListTab(
            key: const ValueKey('contractor'),
            userId: widget.userId,
            roleFilter: 'contractor',
            onOpenChat: _openChat,
          ),

          // Tab 2: Chats como FUNCIONÁRIO
          _ChatListTab(
            key: const ValueKey('employee'),
            userId: widget.userId,
            roleFilter: 'employee',
            onOpenChat: _openChat,
          ),
        ],
      ),
    );
  }

  void _openChat(Chat chat, String roleFilter) async {
    if (chat.blockDialog) {
      _showBlockedDialog(context);
      return;
    }

    final isContractor = roleFilter == 'contractor';
    final otherUserId = isContractor ? chat.employeeId : chat.contractorId;

    try {
      final userLookup = UserLookupService();
      final otherUserData = await userLookup.getUserData(otherUserId);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ChatControllerFinal(),
            child: ChatRoomScreen(
              chatId: chat.chatId,
              contractorId: chat.contractorId,
              employeeId: chat.employeeId,
              userRole: roleFilter,
              userId: widget.userId,
              otherUserName: otherUserData.name,
              otherUserAvatar: otherUserData.avatar.isNotEmpty
                  ? otherUserData.avatar
                  : null,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Erro ao abrir chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao abrir conversa. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 34,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Conversa bloqueada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Esta conversa foi bloqueada devido a denúncias envolvendo uma das partes.\n\n'
                'Para solicitar a reversão do bloqueio, entre em contato com o nosso suporte.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Entendi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab de lista de chats (normal + seção "Bloqueados")
// ─────────────────────────────────────────────────────────────────────────────
class _ChatListTab extends StatefulWidget {
  final String userId;
  final String roleFilter;
  final Function(Chat, String) onOpenChat;

  const _ChatListTab({
    Key? key,
    required this.userId,
    required this.roleFilter,
    required this.onOpenChat,
  }) : super(key: key);

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab> {
  bool _blockedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final chatService = ChatServiceFinal();

    return StreamBuilder<List<Chat>>(
      stream: chatService.getChatListStream(widget.userId, widget.roleFilter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(context, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Carregando conversas...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final allChats = snapshot.data ?? [];
        final normalChats = allChats.where((c) => !c.blockDialog).toList();
        final blockedChats = allChats.where((c) => c.blockDialog).toList();

        if (allChats.isEmpty) {
          return _buildEmptyState(context, widget.roleFilter);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ── Chats normais ──────────────────────────────────────────
              if (normalChats.isEmpty && blockedChats.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma conversa ativa',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              ...normalChats.asMap().entries.map((entry) {
                final index = entry.key;
                final chat = entry.value;
                return Column(
                  children: [
                    _ChatListTile(
                      key: ValueKey(chat.chatId),
                      chat: chat,
                      currentUserId: widget.userId,
                      userRole: widget.roleFilter,
                      isBlocked: false,
                      onTap: () => widget.onOpenChat(chat, widget.roleFilter),
                    ),
                    if (index < normalChats.length - 1)
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  ],
                );
              }),

              // ── Seção "Bloqueados" ──────────────────────────────────────
              if (blockedChats.isNotEmpty) ...[
                const SizedBox(height: 8),
                _BlockedSectionHeader(
                  count: blockedChats.length,
                  expanded: _blockedExpanded,
                  onToggle: () =>
                      setState(() => _blockedExpanded = !_blockedExpanded),
                ),
                if (_blockedExpanded) ...[
                  ...blockedChats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final chat = entry.value;
                    return Column(
                      children: [
                        _ChatListTile(
                          key: ValueKey('blocked_${chat.chatId}'),
                          chat: chat,
                          currentUserId: widget.userId,
                          userRole: widget.roleFilter,
                          isBlocked: true,
                          onTap: () =>
                              widget.onOpenChat(chat, widget.roleFilter),
                        ),
                        if (index < blockedChats.length - 1)
                          const Divider(
                              height: 1, indent: 72, endIndent: 16),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String role) {
    final isContractor = role == 'contractor';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isContractor ? Icons.work_outline : Icons.person_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conversa ainda',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isContractor
                  ? 'Suas conversas como contratante aparecerão aqui'
                  : 'Suas conversas como funcionário aparecerão aqui',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar conversas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header da seção "Bloqueados"
// ─────────────────────────────────────────────────────────────────────────────
class _BlockedSectionHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  const _BlockedSectionHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(
                  color: expanded
                      ? Colors.grey.shade200
                      : Colors.transparent),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Bloqueados',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile individual de chat
// ─────────────────────────────────────────────────────────────────────────────
class _ChatListTile extends StatelessWidget {
  final Chat chat;
  final String currentUserId;
  final String userRole;
  final bool isBlocked;
  final VoidCallback onTap;

  const _ChatListTile({
    Key? key,
    required this.chat,
    required this.currentUserId,
    required this.userRole,
    required this.isBlocked,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isContractor = userRole == 'contractor';
    final otherUserId = isContractor ? chat.employeeId : chat.contractorId;
    final otherRole = isContractor ? 'employee' : 'contractor';

    final otherParticipant = chat.participants[otherRole];

    if (otherParticipant == null) {
      print(
          '⚠️ Participante não encontrado para role: $otherRole no chat: ${chat.chatId}');
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: StreamBuilder<UserData>(
        stream: UserLookupService().getUserDataStream(otherUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildErrorTile(context);
          }

          final userData = userSnapshot.data ??
              UserData(name: 'Usuário', avatar: '', profession: '');

          if (isBlocked) {
            return _buildBlockedTile(context, userData);
          }

          // ── Stream do MEU unreadCount (para badge e negrito)
          return StreamBuilder<int>(
            stream:  BadgeHelper.getUnreadMessageCountStream(chat.chatId, userRole),
            initialData: 0,
            builder: (context, myUnreadSnapshot) {
              final myUnreadCount = myUnreadSnapshot.data ?? 0;

              // ── Stream do unreadCount do DESTINATÁRIO (para ícone de leitura)
              return StreamBuilder<int>(
                stream: ChatServiceFinal()
                    .getUnreadCountStream(chat.chatId, otherRole),
                initialData: 0,
                builder: (context, otherUnreadSnapshot) {
                  final otherUnreadCount = otherUnreadSnapshot.data ?? 0;

                  // Eu enviei a última mensagem?
                  final iLastSender =
                      chat.metadata.lastSender == userRole;

                  // Destinatário leu = eu enviei + unread do outro é 0
                  final recipientRead =
                      iLastSender && otherUnreadCount == 0;

                  return Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            OnlineStatusBadge(
                              isOnline: otherParticipant.isOnline,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[300],
                                backgroundImage:
                                    userData.avatar.isNotEmpty
                                        ? NetworkImage(userData.avatar)
                                        : null,
                                child: userData.avatar.isEmpty
                                    ? const Icon(Icons.person,
                                        color: Colors.white, size: 28)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userData.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: myUnreadCount > 0
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(
                                            chat.metadata.lastTimestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // ✅ CORRIGIDO: ícone só aparece se EU
                                      // enviei a última mensagem
                                      if (iLastSender)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 4),
                                          child: Icon(
                                            recipientRead
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 16,
                                            color: recipientRead
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                        ),

                                      Expanded(
                                        child: Text(
                                          chat.metadata.lastMessage
                                                  .isEmpty
                                              ? 'Nenhuma mensagem ainda'
                                              : chat.metadata.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: myUnreadCount > 0
                                                ? Colors.black87
                                                : Colors.grey[600],
                                            fontWeight: myUnreadCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (myUnreadCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .primaryColor,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12),
                                          ),
                                          child: Text(
                                            myUnreadCount > 99
                                                ? '99+'
                                                : '$myUnreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBlockedTile(BuildContext context, UserData userData) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: 0.55,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: userData.avatar.isNotEmpty
                          ? NetworkImage(userData.avatar)
                          : null,
                      child: userData.avatar.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 9, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userData.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(chat.metadata.lastTimestamp),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Conversa bloqueada',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorTile(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.error_outline, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Erro ao carregar conversa',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    try {
      return ChatDateUtils.formatChatListTime(timestamp);
    } catch (e) {
      return '';
    }
  }
}