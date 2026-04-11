// lib/services/badge/badge_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BadgeHelper {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // ========================================
  // MARCAR CHAT COMO LIDO (CORRIGIDO)
  // ========================================
  
  /// ✅ OTIMIZADO: Usa query server-side para mensagens não lidas em vez de baixar todas.
  /// Usa batch update único. Removido queries redundantes (chatSnapshot, unreadSnapshot).
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

      // ✅ OTIMIZAÇÃO: Query server-side para mensagens não lidas em vez de baixar todas
      final messagesSnapshot = await _database
          .child('ChatMessages/$chatId')
          .orderByChild(readField)
          .equalTo(false)
          .get();

      final updates = <String, dynamic>{
        // Sempre zera o unreadCount
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

      // ✅ OTIMIZAÇÃO: Uma única escrita batch
      await _database.update(updates);

      // Recalcula badge
      await recalculateChatBadge(userId);

    } catch (e, stack) {
      debugPrint('❌ Erro ao marcar chat como lido: $e');
      debugPrint('Stack: $stack');
    }
  }

  // ========================================
  // DECREMENTAR BADGE DE CHAT (PRIVADO - OTIMIZADO)
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
  // RECALCULAR BADGE DE CHATS (PARA SINCRONIZAÇÃO)
  // ========================================
  
  /// ✅ OTIMIZADO: Usa Future.wait para queries paralelas + transaction em vez de set().
  /// Antes: 3 queries sequenciais + set() (sobrescrevia unread_requests)
  /// Agora: 2 queries paralelas + transaction (preserva outros campos)
  static Future<void> recalculateChatBadge(String userId) async {
    try {
      debugPrint('🔄 Recalculando chat badge: $userId');

      // ✅ OTIMIZAÇÃO: Queries paralelas em vez de sequenciais
      final results = await Future.wait([
        _database.child('Chats').orderByChild('employee').equalTo(userId).get(),
        _database.child('Chats').orderByChild('contractor').equalTo(userId).get(),
      ]);

      final chatsAsEmployeeSnapshot = results[0];
      final chatsAsContractorSnapshot = results[1];

      int totalUnreadChats = 0;

      // Conta chats não lidos como EMPLOYEE
      totalUnreadChats += _countUnreadFromSnapshot(chatsAsEmployeeSnapshot, 'employee');

      // Conta chats não lidos como CONTRACTOR
      totalUnreadChats += _countUnreadFromSnapshot(chatsAsContractorSnapshot, 'contractor');

      // Limita a 9
      final clampedTotal = totalUnreadChats.clamp(0, 9);

      // ✅ OTIMIZAÇÃO: Usa transaction em vez de set() para preservar outros campos
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

  /// Helper para contar chats não lidos de um snapshot
  static int _countUnreadFromSnapshot(DataSnapshot snapshot, String role) {
    if (!snapshot.exists) return 0;
    
    final chats = snapshot.value as Map<dynamic, dynamic>;
    int count = 0;
    
    for (var chatEntry in chats.entries) {
      final chatData = chatEntry.value as Map<dynamic, dynamic>;
      final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
      
      if (unreadCountData != null) {
        final unread = (unreadCountData[role] as int?) ?? 0;
        if (unread > 0) {
          count++;
        }
      }
    }
    
    return count;
  }


  static Future<int> getUnreadMessagesCountByRole(String userId, String role) async {
  try {
    final field = role == 'employee' ? 'employee' : 'contractor';
    
    // 1. Busca todos os chats do usuário neste role
    final chatsSnapshot = await _database
        .child('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .get();

    if (!chatsSnapshot.exists) {
      return 0;
    }

    final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
    int totalUnreadMessages = 0;

    // 2. Para cada chat, conta mensagens não lidas
    for (var chatEntry in chats.entries) {
      final chatId = chatEntry.key.toString();
      final chatData = chatEntry.value as Map<dynamic, dynamic>;
      
      // Pega unreadCount deste chat
      final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
      if (unreadCountData != null) {
        final myUnread = (unreadCountData[role] as int?) ?? 0;
        
        // Se tem mensagens não lidas, conta TODAS as mensagens não lidas deste chat
        if (myUnread > 0) {
          final messagesCount = await _countUnreadMessagesInChat(chatId, userId, role);
          totalUnreadMessages += messagesCount;
          debugPrint('  Chat $chatId: $messagesCount mensagens não lidas');
        }
      }
    }

    debugPrint('✅ Total de mensagens não lidas ($role): $totalUnreadMessages');
    return totalUnreadMessages;
  } catch (e) {
    debugPrint('❌ Erro ao contar mensagens: $e');
    return 0;
  }
}

/// Conta mensagens não lidas em um chat específico
static Future<int> _countUnreadMessagesInChat(
  String chatId,
  String userId,
  String role,
) async {
  try {
    final readField = role == 'employee' 
        ? 'read_by_employee' 
        : 'read_by_contractor';

    final messagesSnapshot = await _database
        .child('ChatMessages/$chatId')
        .get();

    if (!messagesSnapshot.exists) {
      return 0;
    }

    final messages = messagesSnapshot.value as Map<dynamic, dynamic>;
    int unreadCount = 0;

    for (var messageEntry in messages.entries) {
      if (messageEntry.key == '_placeholder') continue;
      
      final message = messageEntry.value as Map<dynamic, dynamic>;
      
      // Verifica se é mensagem do outro usuário (não minha)
      final senderId = message['sender_id']?.toString() ?? '';
      if (senderId == userId) continue; // Ignora minhas próprias mensagens
      
      // Verifica se não foi lida
      final isRead = message[readField] == true;
      if (!isRead) {
        unreadCount++;
      }
    }

    return unreadCount;
  } catch (e) {
    debugPrint('❌ Erro ao contar mensagens do chat $chatId: $e');
    return 0;
  }
}

// ========================================
// STREAM DE MENSAGENS NÃO LIDAS POR ROLE
// ========================================

/// Stream do total de mensagens não lidas
static Stream<int> getUnreadMessagesCountByRoleStream(String userId, String role) {
  final field = role == 'employee' ? 'employee' : 'contractor';
  
  return _database
      .child('Chats')
      .orderByChild(field)
      .equalTo(userId)
      .onValue
      .asyncMap((event) async {
    if (!event.snapshot.exists) {
      return 0;
    }

    final chats = event.snapshot.value as Map<dynamic, dynamic>;
    int totalUnreadMessages = 0;

    for (var chatEntry in chats.entries) {
      final chatId = chatEntry.key.toString();
      final chatData = chatEntry.value as Map<dynamic, dynamic>;
      
      final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
      if (unreadCountData != null) {
        final myUnread = (unreadCountData[role] as int?) ?? 0;
        
        if (myUnread > 0) {
          final messagesCount = await _countUnreadMessagesInChat(chatId, userId, role);
          totalUnreadMessages += messagesCount;
        }
      }
    }

    return totalUnreadMessages;
  });
}

  // ========================================
  // CONTAR CHATS NÃO LIDOS POR ROLE
  // ========================================
  /// ✅ OTIMIZADO: Corrigido bug onde int era passado por valor.
  /// Agora usa retorno de _countAllUnreadMessages para somar corretamente.
  static Future<void> recalculateMessageBadge(String userId) async {
    try {
      debugPrint('🔄 Recalculando badge de mensagens: $userId');
      
      // ✅ FIX: Soma os retornos em vez de passar int por valor
      final unreadAsEmployee = await _countAllUnreadMessages(userId, 'employee');
      final unreadAsContractor = await _countAllUnreadMessages(userId, 'contractor');
      final totalUnreadMessages = unreadAsEmployee + unreadAsContractor;

      // Salvar em badges/$userId/unread_messages
      final badgeRef = _database.child('badges/$userId');
      await badgeRef.runTransaction((current) {
        final data = current == null 
            ? {'unread_messages': totalUnreadMessages}
            : Map<String, dynamic>.from(current as Map);
        
        data['unread_messages'] = totalUnreadMessages.clamp(0, 99);
        data['updated_at'] = ServerValue.timestamp;
        
        return Transaction.success(data);
      });

      debugPrint('✅ Total mensagens não lidas: ${totalUnreadMessages.clamp(0, 99)}');
      
    } catch (e) {
      debugPrint('❌ Erro recalculateMessageBadge: $e');
    }
  }

  /// ✅ OTIMIZADO: Retorna int em vez de receber por parâmetro (fix do bug).
  /// Usa unreadCount do chat para evitar queries desnecessárias em chats já lidos.
  static Future<int> _countAllUnreadMessages(
    String userId, 
    String userRole,
  ) async {
    final field = userRole == 'employee' ? 'employee' : 'contractor';
    final readField = userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';
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
      
      // ✅ OTIMIZAÇÃO: Verifica unreadCount primeiro para pular chats já lidos
      final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
      if (unreadCountData != null) {
        final myUnread = (unreadCountData[userRole] as int?) ?? 0;
        if (myUnread == 0) continue; // Pula chats sem mensagens não lidas
      }
      
      // Conta mensagens não lidas DESTE chat
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
  // 3️⃣ Contar mensagens de UM chat específico
  // ========================================
  
  static Future<int> getUnreadMessageCountInChat(String chatId, String userRole) async {
    try {
      final readField = userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';
      
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
  // 4️⃣ STREAMS para UI
  // ========================================
  
  /// Stream TOTAL mensagens não lidas
  static Stream<int> getMessageBadgeStream(String userId) {
    return _database
        .child('badges/$userId/unread_messages')
        .onValue
        .map((event) => (event.snapshot.value as int?)?.clamp(0, 99) ?? 0);
  }

  /// Stream mensagens não lidas de UM chat
  static Stream<int> getUnreadMessageCountStream(String chatId, String userRole) {
    final readField = userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';
    
    return _database
        .child('ChatMessages/$chatId')
        .orderByChild(readField)
        .equalTo(false)
        .onValue
        .map((event) => event.snapshot.exists ? (event.snapshot.value as Map).length : 0);
  }

  static Future<int> getUnreadCountByRole(String userId, String role) async {
    try {
      final field = role == 'employee' ? 'employee' : 'contractor';
      
      final chatsSnapshot = await _database
          .child('Chats')
          .orderByChild(field)
          .equalTo(userId)
          .get();

      if (!chatsSnapshot.exists) {
        return 0;
      }

      final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      for (var chatEntry in chats.entries) {
        final chatData = chatEntry.value as Map<dynamic, dynamic>;
        final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
        
        if (unreadCountData != null) {
          final myUnread = (unreadCountData[role] as int?) ?? 0;
          if (myUnread > 0) {
            unreadCount++;
          }
        }
      }

      return unreadCount;
    } catch (e) {
      debugPrint('❌ Erro ao contar por role: $e');
      return 0;
    }
  }

  // ========================================
  // STREAM DE CHATS NÃO LIDOS POR ROLE
  // ========================================
  
  static Stream<int> getUnreadCountByRoleStream(String userId, String role) {
    final field = role == 'employee' ? 'employee' : 'contractor';
    
    return _database
        .child('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      if (!event.snapshot.exists) {
        return 0;
      }

      final chats = event.snapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      for (var chatEntry in chats.entries) {
        final chatData = chatEntry.value as Map<dynamic, dynamic>;
        final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
        
        if (unreadCountData != null) {
          final myUnread = (unreadCountData[role] as int?) ?? 0;
          if (myUnread > 0) {
            unreadCount++;
          }
        }
      }

      return unreadCount;
    });
  }

  // ========================================
  // STREAM DE BADGES
  // ========================================
  
  static Stream<BadgeData> getBadgeStream(String userId) {
    return _database
        .child('badges/$userId')
        .onValue
        .map((event) {
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
  // STREAMS SIMPLIFICADOS (APENAS TRUE/FALSE)
  // ========================================
  
  /// Retorna TRUE se tiver QUALQUER chat não lido
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

  /// Retorna TRUE se tiver QUALQUER request não lida
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
