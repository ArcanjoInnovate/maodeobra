// lib/services/notification_history/notification_history_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

enum NotificationStatus {
  unviewed,
  viewed,
  rejected,
  approved,
}

enum NotificationType {
  vacancyRequest,
  professionalRequest,
}

class NotificationHistoryItem {
  final String id;
  final NotificationType type;
  final String targetId;
  final String targetTitle;
  final String requesterId;
  final String requesterName;
  final String requesterAvatar;
  final NotificationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? viewedAt;
  final DateTime? respondedAt;

  NotificationHistoryItem({
    required this.id,
    required this.type,
    required this.targetId,
    required this.targetTitle,
    required this.requesterId,
    required this.requesterName,
    required this.requesterAvatar,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.viewedAt,
    this.respondedAt,
  });

  factory NotificationHistoryItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationHistoryItem(
      id: id,
      type: _parseType(map['type']?.toString() ?? ''),
      targetId: map['target_id']?.toString() ?? '',
      targetTitle: map['target_title']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      requesterName: map['requester_name']?.toString() ?? 'Usuário',
      requesterAvatar: map['requester_avatar']?.toString() ?? '',
      status: _parseStatus(map['status']?.toString() ?? ''),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] ?? 0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] ?? 0),
      viewedAt: map['viewed_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['viewed_at']) 
          : null,
      respondedAt: map['responded_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['responded_at']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == NotificationType.vacancyRequest 
          ? 'vacancy_request' 
          : 'professional_request',
      'target_id': targetId,
      'target_title': targetTitle,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_avatar': requesterAvatar,
      'status': _statusToString(status),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'viewed_at': viewedAt?.millisecondsSinceEpoch,
      'responded_at': respondedAt?.millisecondsSinceEpoch,
    };
  }

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'vacancy_request':
        return NotificationType.vacancyRequest;
      case 'professional_request':
        return NotificationType.professionalRequest;
      default:
        return NotificationType.vacancyRequest;
    }
  }

  static NotificationStatus _parseStatus(String status) {
    switch (status) {
      case 'unviewed':
        return NotificationStatus.unviewed;
      case 'viewed':
        return NotificationStatus.viewed;
      case 'rejected':
        return NotificationStatus.rejected;
      case 'approved':
        return NotificationStatus.approved;
      default:
        return NotificationStatus.unviewed;
    }
  }

  static String _statusToString(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.unviewed:
        return 'unviewed';
      case NotificationStatus.viewed:
        return 'viewed';
      case NotificationStatus.rejected:
        return 'rejected';
      case NotificationStatus.approved:
        return 'approved';
    }
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  String get statusLabel {
    switch (status) {
      case NotificationStatus.unviewed:
        return 'Não vista';
      case NotificationStatus.viewed:
        return 'Vista';
      case NotificationStatus.rejected:
        return 'Recusada';
      case NotificationStatus.approved:
        return 'Aprovada';
    }
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.vacancyRequest:
        return 'Candidatura em vaga';
      case NotificationType.professionalRequest:
        return 'Solicitação de chat';
    }
  }
}

class NotificationHistoryService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  static final NotificationHistoryService _instance = 
      NotificationHistoryService._internal();
  factory NotificationHistoryService() => _instance;
  NotificationHistoryService._internal();

  // ════════════════════════════════════════════════
  // 1. CRIAR NOTIFICAÇÃO (quando alguém se candidata)
  // ════════════════════════════════════════════════

  Future<String?> createNotification({
    required String ownerId,
    required NotificationType type,
    required String targetId,
    required String targetTitle,
    required String requesterId,
    required String requesterName,
    required String requesterAvatar,
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));
      
      final notificationRef = _database
          .child('notification_history/$ownerId')
          .push();
      
      final notification = NotificationHistoryItem(
        id: notificationRef.key!,
        type: type,
        targetId: targetId,
        targetTitle: targetTitle,
        requesterId: requesterId,
        requesterName: requesterName,
        requesterAvatar: requesterAvatar,
        status: NotificationStatus.unviewed,
        createdAt: now,
        updatedAt: now,
        expiresAt: expiresAt,
      );

      await notificationRef.set(notification.toMap());
      
      debugPrint('✅ Notificação criada: ${notificationRef.key}');
      return notificationRef.key;
    } catch (e) {
      debugPrint('❌ Erro ao criar notificação: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // 2. MARCAR COMO VISTA
  // ════════════════════════════════════════════════

  Future<bool> markAsViewed({
    required String ownerId,
    required String notificationId,
  }) async {
    try {
      final now = DateTime.now();
      
      await _database
          .child('notification_history/$ownerId/$notificationId')
          .update({
        'status': 'viewed',
        'viewed_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
      
      debugPrint('✅ Notificação marcada como vista: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao marcar como vista: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 3. MARCAR COMO RECUSADA
  // ════════════════════════════════════════════════

  Future<bool> markAsRejected({
    required String ownerId,
    required String notificationId,
  }) async {
    try {
      final now = DateTime.now();
      
      await _database
          .child('notification_history/$ownerId/$notificationId')
          .update({
        'status': 'rejected',
        'responded_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
      
      debugPrint('✅ Notificação marcada como recusada: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao marcar como recusada: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 4. MARCAR COMO APROVADA
  // ════════════════════════════════════════════════

  Future<bool> markAsApproved({
    required String ownerId,
    required String notificationId,
  }) async {
    try {
      final now = DateTime.now();
      
      await _database
          .child('notification_history/$ownerId/$notificationId')
          .update({
        'status': 'approved',
        'responded_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
      
      debugPrint('✅ Notificação marcada como aprovada: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao marcar como aprovada: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 5. BUSCAR NOTIFICAÇÕES DO USUÁRIO
  // ════════════════════════════════════════════════

  Future<List<NotificationHistoryItem>> getUserNotifications({
    required String userId,
    NotificationStatus? filterByStatus,
    NotificationType? filterByType,
    bool includeExpired = false,
  }) async {
    try {
      final snapshot = await _database
          .child('notification_history/$userId')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      List<NotificationHistoryItem> notifications = [];

      for (final entry in data.entries) {
        final notification = NotificationHistoryItem.fromMap(
          entry.key,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );

        // Filtrar expiradas
        if (!includeExpired && notification.isExpired) continue;

        // Filtrar por status
        if (filterByStatus != null && notification.status != filterByStatus) {
          continue;
        }

        // Filtrar por tipo
        if (filterByType != null && notification.type != filterByType) {
          continue;
        }

        notifications.add(notification);
      }

      // Ordenar por data (mais recentes primeiro)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    } catch (e) {
      debugPrint('❌ Erro ao buscar notificações: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════
  // 6. STREAM DE NOTIFICAÇÕES
  // ════════════════════════════════════════════════

  Stream<List<NotificationHistoryItem>> getUserNotificationsStream({
    required String userId,
    NotificationStatus? filterByStatus,
    NotificationType? filterByType,
    bool includeExpired = false,
  }) {
    return _database
        .child('notification_history/$userId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <NotificationHistoryItem>[];
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      List<NotificationHistoryItem> notifications = [];

      for (final entry in data.entries) {
        final notification = NotificationHistoryItem.fromMap(
          entry.key,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );

        if (!includeExpired && notification.isExpired) continue;
        if (filterByStatus != null && notification.status != filterByStatus) {
          continue;
        }
        if (filterByType != null && notification.type != filterByType) {
          continue;
        }

        notifications.add(notification);
      }

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  // ════════════════════════════════════════════════
  // 7. DELETAR NOTIFICAÇÃO
  // ════════════════════════════════════════════════

  Future<bool> deleteNotification({
    required String ownerId,
    required String notificationId,
  }) async {
    try {
      await _database
          .child('notification_history/$ownerId/$notificationId')
          .remove();
      
      debugPrint('✅ Notificação deletada: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao deletar notificação: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 8. LIMPAR NOTIFICAÇÕES EXPIRADAS
  // ════════════════════════════════════════════════

  Future<int> cleanExpiredNotifications(String userId) async {
    try {
      final snapshot = await _database
          .child('notification_history/$userId')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final now = DateTime.now();
      int deletedCount = 0;

      for (final entry in data.entries) {
        final expiresAt = entry.value['expires_at'] as int?;
        if (expiresAt != null) {
          final expirationDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
          if (now.isAfter(expirationDate)) {
            await _database
                .child('notification_history/$userId/${entry.key}')
                .remove();
            deletedCount++;
          }
        }
      }

      debugPrint('✅ $deletedCount notificações expiradas removidas');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Erro ao limpar notificações expiradas: $e');
      return 0;
    }
  }

  // ════════════════════════════════════════════════
  // 9. CONTAR NOTIFICAÇÕES POR STATUS
  // ════════════════════════════════════════════════

  Future<Map<String, int>> getNotificationCounts(String userId) async {
    try {
      final snapshot = await _database
          .child('notification_history/$userId')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return {
          'unviewed': 0,
          'viewed': 0,
          'rejected': 0,
          'approved': 0,
          'total': 0,
        };
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final now = DateTime.now();
      
      int unviewed = 0;
      int viewed = 0;
      int rejected = 0;
      int approved = 0;

      for (final entry in data.entries) {
        final expiresAt = entry.value['expires_at'] as int?;
        if (expiresAt != null) {
          final expirationDate = DateTime.fromMillisecondsSinceEpoch(expiresAt);
          if (now.isAfter(expirationDate)) continue;
        }

        final status = entry.value['status']?.toString() ?? '';
        switch (status) {
          case 'unviewed':
            unviewed++;
            break;
          case 'viewed':
            viewed++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'approved':
            approved++;
            break;
        }
      }

      return {
        'unviewed': unviewed,
        'viewed': viewed,
        'rejected': rejected,
        'approved': approved,
        'total': unviewed + viewed + rejected + approved,
      };
    } catch (e) {
      debugPrint('❌ Erro ao contar notificações: $e');
      return {
        'unviewed': 0,
        'viewed': 0,
        'rejected': 0,
        'approved': 0,
        'total': 0,
      };
    }
  }
}