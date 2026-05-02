// lib/screens/notifications/notification_history_screen.dart

import 'package:dartobra_new/services/notifications/notification_history.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationHistoryScreen extends StatefulWidget {
  final String userId;

  const NotificationHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Histórico de Notificações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              isScrollable: true,
              tabs: const [
                Tab(text: 'Todas'),
                Tab(text: 'Não vistas'),
                Tab(text: 'Vistas'),
                Tab(text: 'Aprovadas'),
                Tab(text: 'Recusadas'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NotificationListTab(userId: widget.userId, status: null),
          _NotificationListTab(userId: widget.userId, status: NotificationStatus.unviewed),
          _NotificationListTab(userId: widget.userId, status: NotificationStatus.viewed),
          _NotificationListTab(userId: widget.userId, status: NotificationStatus.approved),
          _NotificationListTab(userId: widget.userId, status: NotificationStatus.rejected),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET SEPARADO COM AutomaticKeepAliveClientMixin
// Mantém o estado vivo quando troca de tab
// ═══════════════════════════════════════════════════════════════════

class _NotificationListTab extends StatefulWidget {
  final String userId;
  final NotificationStatus? status;

  const _NotificationListTab({
    required this.userId,
    this.status,
  });

  @override
  State<_NotificationListTab> createState() => _NotificationListTabState();
}

class _NotificationListTabState extends State<_NotificationListTab>
    with AutomaticKeepAliveClientMixin {
  final NotificationHistoryService _service = NotificationHistoryService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Obrigatório para o keepAlive funcionar

    return StreamBuilder<List<NotificationHistoryItem>>(
      stream: _service.getUserNotificationsStream(
        userId: widget.userId,
        filterByStatus: widget.status,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 2.5,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(widget.status);
        }

        final notifications = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return _buildNotificationCard(notifications[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(NotificationStatus? status) {
    String message;
    IconData icon;

    switch (status) {
      case NotificationStatus.unviewed:
        message = 'Nenhuma notificação não vista';
        icon = Icons.visibility_off_outlined;
        break;
      case NotificationStatus.viewed:
        message = 'Nenhuma notificação vista';
        icon = Icons.visibility_outlined;
        break;
      case NotificationStatus.approved:
        message = 'Nenhuma solicitação aprovada';
        icon = Icons.check_circle_outline;
        break;
      case NotificationStatus.rejected:
        message = 'Nenhuma solicitação recusada';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'Nenhuma notificação ainda';
        icon = Icons.notifications_none;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 40, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'As notificações aparecerão aqui',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationHistoryItem notification) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (notification.status) {
      case NotificationStatus.unviewed:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        statusIcon = Icons.fiber_new_rounded;
        break;
      case NotificationStatus.viewed:
        statusColor = const Color(0xFFEA580C);
        statusBg = const Color(0xFFFFF7ED);
        statusIcon = Icons.visibility_rounded;
        break;
      case NotificationStatus.approved:
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFF0FDF4);
        statusIcon = Icons.check_circle_rounded;
        break;
      case NotificationStatus.rejected:
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEF2F2);
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.status == NotificationStatus.unviewed
              ? statusColor.withOpacity(0.3)
              : const Color(0xFFE2E8F0),
          width: notification.status == NotificationStatus.unviewed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: notification.requesterAvatar.isNotEmpty
                      ? NetworkImage(notification.requesterAvatar)
                      : null,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: notification.requesterAvatar.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF2563EB))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.requesterName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.typeLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        notification.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    notification.type == NotificationType.vacancyRequest
                        ? Icons.work_outline
                        : Icons.person_outline,
                    size: 16,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notification.targetTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  timeago.format(notification.createdAt, locale: 'pt_BR'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (notification.respondedAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.reply_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Respondido ${timeago.format(notification.respondedAt!, locale: 'pt_BR')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}