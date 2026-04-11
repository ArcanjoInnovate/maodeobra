// lib/services/badge/badge_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BadgeHelper {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // ========================================
  // MARCAR CHAT COMO LIDO (CORRIGIDO)
  // ========================================
  
  static Future<void> markChatAsRead(
    String chatId,
    String userId,
    String userRole,
  ) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📖 MARCANDO CHAT COMO LIDO');
      debugPrint('═══════════════════════════════════════');
      debugPrint('ChatId: $chatId');
      debugPrint('UserId: $userId');
      debugPrint('UserRole: $userRole');

      final chatRef = _database.child('Chats/$chatId');
      
      // 1. Verifica se estrutura existe
      final chatSnapshot = await chatRef.get();
      if (!chatSnapshot.exists) {
        debugPrint('⚠️ Chat não existe');
        return;
      }

      // 2. Verifica unreadCount ANTES de modificar
      final unreadSnapshot = await chatRef.child('unreadCount/$userRole').get();
      
      if (!unreadSnapshot.exists) {
        debugPrint('⚠️ unreadCount não existe, criando estrutura...');
        await chatRef.child('unreadCount').set({
          'employee': 0,
          'contractor': 0,
        });
      }

      final currentUnreadCount = (unreadSnapshot.value as int?) ?? 0;
      final wasUnread = currentUnreadCount == 1;
      
      debugPrint('📊 unreadCount ANTES: $currentUnreadCount');
      debugPrint('❓ Era não lido? $wasUnread');

      // 3. SEMPRE seta para 0 (marca como lido)
      await chatRef.child('unreadCount/$userRole').set(0);
      debugPrint('✅ unreadCount setado para 0');

      // 4. Marca mensagens individuais como lidas
      final readField = userRole == 'employee' 
          ? 'read_by_employee' 
          : 'read_by_contractor';

      final messagesRef = _database.child('ChatMessages/$chatId');
      final messagesSnapshot = await messagesRef.get();

      if (messagesSnapshot.exists) {
        final messages = messagesSnapshot.value as Map<dynamic, dynamic>;
        final updates = <String, dynamic>{};
        
        int markedCount = 0;
        for (var messageId in messages.keys) {
          if (messageId == '_placeholder') continue;
          
          final message = messages[messageId];
          if (message is Map && message[readField] != true) {
            updates['ChatMessages/$chatId/$messageId/$readField'] = true;
            markedCount++;
          }
        }
        
        if (updates.isNotEmpty) {
          await _database.ref.update(updates);
          debugPrint('✅ $markedCount mensagens marcadas como lidas');
        }
      }

      // 5. RECALCULA badge SEMPRE (não decrementa diretamente)
      // Isso garante sincronização correta
      debugPrint('🔄 Recalculando badge completo...');
      await recalculateChatBadge(userId);

      debugPrint('═══════════════════════════════════════\n');
    } catch (e, stack) {
      debugPrint('❌ ERRO ao marcar chat: $e');
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
  
  static Future<void> recalculateChatBadge(String userId) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔄 RECALCULANDO CHAT BADGE (AMBOS OS ROLES)');
      debugPrint('═══════════════════════════════════════');
      debugPrint('UserId: $userId');
      debugPrint('Timestamp: ${DateTime.now()}');

      // 1. Verifica se badge existe ANTES
      final badgeSnapshot = await _database.child('badges/$userId').get();
      if (badgeSnapshot.exists) {
        final badgeData = badgeSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('📊 Badge ANTES: ${badgeData['unread_chats'] ?? 'null'}');
      } else {
        debugPrint('⚠️ Badge NÃO EXISTE, será criado');
      }

      // Busca todos os chats onde o usuário é EMPLOYEE
      final chatsAsEmployeeSnapshot = await _database
          .child('Chats')
          .orderByChild('employee')
          .equalTo(userId)
          .get();

      // Busca todos os chats onde o usuário é CONTRACTOR
      final chatsAsContractorSnapshot = await _database
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(userId)
          .get();

      int totalUnreadChats = 0;
      List<String> unreadChatIds = [];

      // Conta chats não lidos como EMPLOYEE
      if (chatsAsEmployeeSnapshot.exists) {
        final chats = chatsAsEmployeeSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('📊 Chats como EMPLOYEE: ${chats.length}');
        
        for (var chatEntry in chats.entries) {
          final chatId = chatEntry.key.toString();
          final chatData = chatEntry.value as Map<dynamic, dynamic>;
          final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
          
          if (unreadCountData != null) {
            final unread = (unreadCountData['employee'] as int?) ?? 0;
            debugPrint('  Chat $chatId: unreadCount.employee = $unread');
            if (unread == 1) {
              totalUnreadChats++;
              unreadChatIds.add(chatId);
              debugPrint('    ✉️ NÃO LIDO!');
            }
          } else {
            debugPrint('  Chat $chatId: SEM unreadCount');
          }
        }
      } else {
        debugPrint('📊 Nenhum chat como EMPLOYEE');
      }

      // Conta chats não lidos como CONTRACTOR
      if (chatsAsContractorSnapshot.exists) {
        final chats = chatsAsContractorSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('📊 Chats como CONTRACTOR: ${chats.length}');
        
        for (var chatEntry in chats.entries) {
          final chatId = chatEntry.key.toString();
          final chatData = chatEntry.value as Map<dynamic, dynamic>;
          final unreadCountData = chatData['unreadCount'] as Map<dynamic, dynamic>?;
          
          if (unreadCountData != null) {
            final unread = (unreadCountData['contractor'] as int?) ?? 0;
            debugPrint('  Chat $chatId: unreadCount.contractor = $unread');
            if (unread == 1) {
              totalUnreadChats++;
              unreadChatIds.add(chatId);
              debugPrint('    ✉️ NÃO LIDO!');
            }
          } else {
            debugPrint('  Chat $chatId: SEM unreadCount');
          }
        }
      } else {
        debugPrint('📊 Nenhum chat como CONTRACTOR');
      }

      // Limita a 9
      final clampedTotal = totalUnreadChats.clamp(0, 9);
      
      debugPrint('');
      debugPrint('📊 RESUMO DO RECÁLCULO:');
      debugPrint('  Total bruto: $totalUnreadChats');
      debugPrint('  Total limitado (max 9): $clampedTotal');
      debugPrint('  Chats não lidos: ${unreadChatIds.join(', ')}');

      // Atualiza badge (ou cria se não existir)
      await _database.child('badges/$userId').set({
        'unread_chats': clampedTotal,
        'unread_requests': badgeSnapshot.exists 
            ? ((badgeSnapshot.value as Map)['unread_requests'] ?? 0)
            : 0,
        'updated_at': ServerValue.timestamp,
      });

      debugPrint('✅ Badge DEPOIS: $clampedTotal');
      debugPrint('✅ Badge salvo em badges/$userId');
      debugPrint('═══════════════════════════════════════\n');
    } catch (e, stack) {
      debugPrint('❌ Erro ao recalcular: $e');
      debugPrint('Stack: $stack');
    }
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
  static Future<void> recalculateMessageBadge(String userId) async {
    try {
      debugPrint('🔥 RECALCULANDO BADGE POR MENSAGENS: $userId');
      
      int totalUnreadMessages = 0;

      // Chats como EMPLOYEE
      await _countAllUnreadMessages(userId, 'employee', totalUnreadMessages);
      
      // Chats como CONTRACTOR  
      await _countAllUnreadMessages(userId, 'contractor', totalUnreadMessages);

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

      debugPrint('✅ TOTAL MENSAGENS NÃO LIDAS: ${totalUnreadMessages.clamp(0, 99)}');
      
    } catch (e) {
      debugPrint('❌ Erro recalculateMessageBadge: $e');
    }
  }

  /// Conta mensagens não lidas de TODOS os chats de um role
  static Future<void> _countAllUnreadMessages(
    String userId, 
    String userRole, 
    int totalUnreadMessages // Referência para somar
  ) async {
    final field = userRole == 'employee' ? 'employee' : 'contractor';
    final readField = userRole == 'employee' ? 'read_by_employee' : 'read_by_contractor';
    
    final chatsSnapshot = await _database
        .child('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .get();

    if (!chatsSnapshot.exists) return;

    final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
    for (var chatEntry in chats.entries) {
      final chatId = chatEntry.key.toString();
      
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
          if (myUnread == 1) {
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
          if (myUnread == 1) {
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