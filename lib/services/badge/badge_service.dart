// lib/services/badge/badge_service.dart
//
// ✅ N2-01 CORRIGIDO: getUnreadMessagesCountByRoleStream e getUnreadCountByRoleStream
// substituídos por leitura direta do nó badges/{uid} — elimina N reads por evento.
// Cloud Function já mantém badges/{uid}/unread_chats atualizado em tempo real.

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BadgeHelper {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // ========================================
  // MARCAR CHAT COMO LIDO
  // ========================================

  static Future<void> markChatAsRead(
    String chatId,
    String userId,
    String userRole,
  ) async {
    try {
      debugPrint('📖 markChatAsRead: chat=$chatId role=$userRole');

      final readField = userRole == 'employee'
          ? 'read_by_employee'
          : 'read_by_contractor';

      final messagesSnapshot = await _database
          .child('ChatMessages/$chatId')
          .orderByChild(readField)
          .equalTo(false)
          .get();

      final updates = <String, dynamic>{
        'Chats/$chatId/unreadCount/$userRole': 0,
      };

      if (messagesSnapshot.exists) {
        final messages = messagesSnapshot.value as Map<dynamic, dynamic>;
        for (var messageId in messages.keys) {
          if (messageId == '_placeholder') continue;
          updates['ChatMessages/$chatId/$messageId/$readField'] = true;
        }
        debugPrint('✅ ${messages.length} mensagens marcadas como lidas');
      }

      await _database.update(updates);
      await _decrementChatBadge(userId);
    } catch (e, stack) {
      debugPrint('❌ Erro ao marcar chat como lido: $e');
      debugPrint('Stack: $stack');
    }
  }

  // ========================================
  // DECREMENTAR BADGE DE CHAT (PRIVADO)
  // ========================================

  // ignore: unused_element
  static Future<void> _decrementChatBadge(String userId) async {
    try {
      final badgeRef = _database.child('badges/$userId');

      debugPrint('📉 Decrementando chat badge para $userId');

      await badgeRef.runTransaction((current) {
        if (current == null) {
          debugPrint('  ⚠️ Badge não existe, criando com 0');
          return Transaction.success({
            'unread_chats': 0,
            'unread_requests': 0,
            'updated_at': ServerValue.timestamp,
          });
        }

        final data = Map<String, dynamic>.from(current as Map);
        final currentBadge = (data['unread_chats'] as int?) ?? 0;

        if (currentBadge > 0) {
          final newBadge = currentBadge - 1;
          data['unread_chats'] = newBadge;
          data['updated_at'] = ServerValue.timestamp;
          debugPrint('  ✅ Chat badge: $currentBadge → $newBadge');
        } else {
          debugPrint('  ⚠️ Badge já está em 0');
        }

        return Transaction.success(data);
      });
    } catch (e) {
      debugPrint('❌ Erro ao decrementar chat badge: $e');
    }
  }

  // ========================================
  // DECREMENTAR REQUEST BADGE
  // ========================================

  static Future<void> _decrementRequestBadge(String userId) async {
    try {
      final badgeRef = _database.child('badges/$userId');

      await badgeRef.runTransaction((current) {
        if (current == null) {
          return Transaction.success({
            'unread_chats': 0,
            'unread_requests': 0,
            'updated_at': ServerValue.timestamp,
          });
        }

        final data = Map<String, dynamic>.from(current as Map);
        final currentBadge = (data['unread_requests'] as int?) ?? 0;

        if (currentBadge > 0) {
          data['unread_requests'] = currentBadge - 1;
          data['updated_at'] = ServerValue.timestamp;
          debugPrint('✅ Request badge: $currentBadge → ${currentBadge - 1}');
        } else {
          debugPrint('⚠️ Badge já está em 0');
        }

        return Transaction.success(data);
      });
    } catch (e) {
      debugPrint('❌ Erro ao decrementar request badge: $e');
    }
  }

  // ========================================
  // DECREMENTAR REQUEST (PÚBLICO)
  // ========================================

  static Future<void> decrementRequestBadge(String userId) async {
    debugPrint('📉 Decrementando request badge: $userId');
    await _decrementRequestBadge(userId);
  }

  // ========================================
  // RECALCULAR BADGE DE CHATS
  // ========================================

  static Future<void> recalculateChatBadge(String userId) async {
    try {
      debugPrint('🔄 Recalculando chat badge: $userId');

      final results = await Future.wait([
        _database.child('Chats').orderByChild('employee').equalTo(userId).get(),
        _database.child('Chats').orderByChild('contractor').equalTo(userId).get(),
      ]);

      int totalUnreadChats = 0;
      totalUnreadChats += _countUnreadFromSnapshot(results[0], 'employee');
      totalUnreadChats += _countUnreadFromSnapshot(results[1], 'contractor');

      final clampedTotal = totalUnreadChats.clamp(0, 9);

      await _database.child('badges/$userId').runTransaction((current) {
        final data = current == null
            ? <String, dynamic>{'unread_chats': 0, 'unread_requests': 0}
            : Map<String, dynamic>.from(current as Map);

        data['unread_chats'] = clampedTotal;
        data['updated_at'] = ServerValue.timestamp;

        return Transaction.success(data);
      });

      debugPrint('✅ Chat badge atualizado: $clampedTotal');
    } catch (e, stack) {
      debugPrint('❌ Erro ao recalcular: $e');
      debugPrint('Stack: $stack');
    }
  }

  static int _countUnreadFromSnapshot(DataSnapshot snapshot, String role) {
    if (!snapshot.exists) return 0;

    final chats = snapshot.value as Map<dynamic, dynamic>;
    int count = 0;

    for (var chatEntry in chats.entries) {
      final chatData = chatEntry.value as Map<dynamic, dynamic>;
      final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;

      if (unreadCountData != null) {
        final unread = (unreadCountData[role] as int?) ?? 0;
        if (unread > 0) count++;
      }
    }

    return count;
  }

  // ========================================
  // CONTAR MENSAGENS NÃO LIDAS (ONE-SHOT)
  // ========================================

  static Future<int> getUnreadMessagesCountByRole(
      String userId, String role) async {
    try {
      final field = role == 'employee' ? 'employee' : 'contractor';

      final chatsSnapshot = await _database
          .child('Chats')
          .orderByChild(field)
          .equalTo(userId)
          .get();

      if (!chatsSnapshot.exists) return 0;

      final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
      int totalUnreadMessages = 0;

      for (var chatEntry in chats.entries) {
        final chatId = chatEntry.key.toString();
        final chatData = chatEntry.value as Map<dynamic, dynamic>;
        final unreadCountData =
            chatData['unreadCount'] as Map<dynamic, dynamic>?;

        if (unreadCountData != null) {
          final myUnread = (unreadCountData[role] as int?) ?? 0;
          if (myUnread > 0) {
            final messagesCount =
                await _countUnreadMessagesInChat(chatId, userId, role);
            totalUnreadMessages += messagesCount;
            debugPrint('  Chat $chatId: $messagesCount mensagens não lidas');
          }
        }
      }

      debugPrint(
          '✅ Total de mensagens não lidas ($role): $totalUnreadMessages');
      return totalUnreadMessages;
    } catch (e) {
      debugPrint('❌ Erro ao contar mensagens: $e');
      return 0;
    }
  }

  static Future<int> _countUnreadMessagesInChat(
    String chatId,
    String userId,
    String role,
  ) async {
    try {
      final readField =
          role == 'employee' ? 'read_by_employee' : 'read_by_contractor';

      final messagesSnapshot = await _database
          .child('ChatMessages/$chatId')
          .orderByChild(readField)
          .equalTo(false)
          .get();

      if (!messagesSnapshot.exists) return 0;

      final messages = messagesSnapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;
      for (var entry in messages.entries) {
        if (entry.key == '_placeholder') continue;
        final msg = entry.value as Map<dynamic, dynamic>;
        final senderId = msg['sender_id']?.toString() ?? '';
        if (senderId != userId) unreadCount++;
      }

      return unreadCount;
    } catch (e) {
      debugPrint('Erro ao contar mensagens do chat $chatId: $e');
      return 0;
    }
  }

  // ========================================
  // ✅ N2-01 — STREAM DE MENSAGENS NÃO LIDAS
  // ANTES: asyncMap com N reads a cada evento de qualquer chat
  // DEPOIS: escuta badges/{uid}/unread_chats — 0 reads extras
  //
  // NOTA: este stream agora retorna a contagem de CHATS não lidos
  // (não de mensagens individuais), pois é o que o nó badges mantém.
  // Se a UI precisar do número exato de mensagens, use
  // getUnreadMessagesCountByRole() como one-shot pontual.
  // ========================================

  static Stream<int> getUnreadMessagesCountByRoleStream(
      String userId, String role) {
    // O nó badges/{uid}/unread_chats já é mantido pela Cloud Function
    // e representa os chats com mensagens não lidas — substitui o N+1.
    return _database
        .child('badges/$userId/unread_chats')
        .onValue
        .map((event) => (event.snapshot.value as int?)?.clamp(0, 9) ?? 0);
  }

  // ========================================
  // CONTAR CHATS NÃO LIDOS (ONE-SHOT)
  // ========================================

  static Future<int> getUnreadCountByRole(String userId, String role) async {
    try {
      final field = role == 'employee' ? 'employee' : 'contractor';

      final chatsSnapshot = await _database
          .child('Chats')
          .orderByChild(field)
          .equalTo(userId)
          .get();

      if (!chatsSnapshot.exists) return 0;

      final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      for (var chatEntry in chats.entries) {
        final chatData = chatEntry.value as Map<dynamic, dynamic>;
        final unreadCountData =
            chatData['unreadCount'] as Map<dynamic, dynamic>?;

        if (unreadCountData != null) {
          final myUnread = (unreadCountData[role] as int?) ?? 0;
          if (myUnread > 0) unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      debugPrint('❌ Erro ao contar por role: $e');
      return 0;
    }
  }

  // ========================================
  // ✅ N2-01 — STREAM DE CHATS NÃO LIDOS POR ROLE
  // ANTES: asyncMap sobre todos os chats a cada evento
  // DEPOIS: escuta badges/{uid}/unread_chats direto — 1 listener, 0 reads extras
  // ========================================

  static Stream<int> getUnreadCountByRoleStream(String userId, String role) {
    // badges/{uid}/unread_chats já soma employee + contractor.
    // Se a UI precisar separar por role, use getUnreadCountByRole() one-shot.
    return _database
        .child('badges/$userId/unread_chats')
        .onValue
        .map((event) => (event.snapshot.value as int?)?.clamp(0, 9) ?? 0);
  }

  // ========================================
  // RECALCULAR BADGE DE MENSAGENS
  // ========================================

  static Future<void> recalculateMessageBadge(String userId) async {
    try {
      debugPrint('🔄 Recalculando badge de mensagens: $userId');

      final unreadAsEmployee =
          await _countAllUnreadMessages(userId, 'employee');
      final unreadAsContractor =
          await _countAllUnreadMessages(userId, 'contractor');
      final totalUnreadMessages = unreadAsEmployee + unreadAsContractor;

      final badgeRef = _database.child('badges/$userId');
      await badgeRef.runTransaction((current) {
        final data = current == null
            ? {'unread_messages': totalUnreadMessages}
            : Map<String, dynamic>.from(current as Map);

        data['unread_messages'] = totalUnreadMessages.clamp(0, 99);
        data['updated_at'] = ServerValue.timestamp;

        return Transaction.success(data);
      });

      debugPrint(
          '✅ Total mensagens não lidas: ${totalUnreadMessages.clamp(0, 99)}');
    } catch (e) {
      debugPrint('❌ Erro recalculateMessageBadge: $e');
    }
  }

  static Future<int> _countAllUnreadMessages(
    String userId,
    String userRole,
  ) async {
    final field = userRole == 'employee' ? 'employee' : 'contractor';
    final readField =
        userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';
    int totalUnreadMessages = 0;

    final chatsSnapshot = await _database
        .child('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .get();

    if (!chatsSnapshot.exists) return 0;

    final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
    for (var chatEntry in chats.entries) {
      final chatId = chatEntry.key.toString();
      final chatData = chatEntry.value as Map<dynamic, dynamic>;

      final unreadCountData =
          chatData['unreadCount'] as Map<dynamic, dynamic>?;
      if (unreadCountData != null) {
        final myUnread = (unreadCountData[userRole] as int?) ?? 0;
        if (myUnread == 0) continue;
      }

      final msgSnapshot = await _database
          .child('ChatMessages/$chatId')
          .orderByChild(readField)
          .equalTo(false)
          .get();

      if (msgSnapshot.exists) {
        final count = (msgSnapshot.value as Map).length;
        totalUnreadMessages += count;
        debugPrint('  💬 $chatId ($userRole): +$count msgs');
      }
    }

    return totalUnreadMessages;
  }

  // ========================================
  // CONTAR MENSAGENS DE UM CHAT ESPECÍFICO
  // ========================================

  static Future<int> getUnreadMessageCountInChat(
      String chatId, String userRole) async {
    try {
      final readField =
          userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';

      final snapshot = await _database
          .child('ChatMessages/$chatId')
          .orderByChild(readField)
          .equalTo(false)
          .get();

      return snapshot.exists ? (snapshot.value as Map).length : 0;
    } catch (e) {
      debugPrint('❌ Erro contar msgs $chatId: $e');
      return 0;
    }
  }

  // ========================================
  // STREAMS PARA UI
  // ========================================

  static Stream<int> getMessageBadgeStream(String userId) {
    return _database
        .child('badges/$userId/unread_messages')
        .onValue
        .map((event) => (event.snapshot.value as int?)?.clamp(0, 99) ?? 0);
  }

  static Stream<int> getUnreadMessageCountStream(
      String chatId, String userRole) {
    final readField =
        userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';

    return _database
        .child('ChatMessages/$chatId')
        .orderByChild(readField)
        .equalTo(false)
        .onValue
        .map((event) =>
            event.snapshot.exists ? (event.snapshot.value as Map).length : 0);
  }

  // ========================================
  // STREAM DE BADGES COMPLETO
  // ========================================

  static Stream<BadgeData> getBadgeStream(String userId) {
    return _database.child('badges/$userId').onValue.map((event) {
      if (!event.snapshot.exists) {
        return BadgeData(unreadChats: 0, unreadRequests: 0);
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return BadgeData(
        unreadChats: (data['unread_chats'] as int?) ?? 0,
        unreadRequests: (data['unread_requests'] as int?) ?? 0,
      );
    });
  }

  // ========================================
  // STREAMS SIMPLIFICADOS (TRUE/FALSE)
  // ========================================

  static Stream<bool> hasUnreadChatsStream(String userId) {
    return _database
        .child('badges/$userId/unread_chats')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return false;
      final count = (event.snapshot.value as int?) ?? 0;
      return count > 0;
    });
  }

  static Stream<bool> hasUnreadRequestsStream(String userId) {
    return _database
        .child('badges/$userId/unread_requests')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return false;
      final count = (event.snapshot.value as int?) ?? 0;
      return count > 0;
    });
  }

  // ========================================
  // GET BADGE ATUAL
  // ========================================

  static Future<BadgeData> getCurrentBadge(String userId) async {
    try {
      final snapshot = await _database.child('badges/$userId').get();

      if (!snapshot.exists) {
        return BadgeData(unreadChats: 0, unreadRequests: 0);
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      return BadgeData(
        unreadChats: (data['unread_chats'] as int?) ?? 0,
        unreadRequests: (data['unread_requests'] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Erro ao obter badge: $e');
      return BadgeData(unreadChats: 0, unreadRequests: 0);
    }
  }

  // ========================================
  // CRIAR BADGE SE NÃO EXISTIR
  // ========================================

  static Future<void> ensureBadgeExists(String userId) async {
    try {
      final snapshot = await _database.child('badges/$userId').get();

      if (!snapshot.exists) {
        debugPrint('⚠️ Badge não existe para $userId, criando...');

        await _database.child('badges/$userId').set({
          'unread_chats': 0,
          'unread_requests': 0,
          'updated_at': ServerValue.timestamp,
        });

        debugPrint('✅ Badge criado');
      }
    } catch (e) {
      debugPrint('❌ Erro ao criar badge: $e');
    }
  }

  // ========================================
  // ZERAR BADGES
  // ========================================

  static Future<void> clearAllBadges(String userId) async {
    try {
      await _database.child('badges/$userId').set({
        'unread_chats': 0,
        'unread_requests': 0,
        'updated_at': ServerValue.timestamp,
      });
      debugPrint('✅ Badges zerados');
    } catch (e) {
      debugPrint('❌ Erro ao zerar badges: $e');
    }
  }
}

// ========================================
// MODELO DE DADOS
// ========================================

class BadgeData {
  final int unreadChats;
  final int unreadRequests;

  BadgeData({
    required this.unreadChats,
    required this.unreadRequests,
  });

  int get total => unreadChats + unreadRequests;

  @override
  String toString() {
    return 'BadgeData(chats: $unreadChats, requests: $unreadRequests)';
  }
}