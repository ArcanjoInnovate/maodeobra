// lib/services/chat/chat_service.dart

// ignore_for_file: unused_field, unnecessary_cast

import 'dart:async';
import 'package:dartobra_new/services/badge/badge_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/message_model.dart';
import '../../models/chat/participant_model.dart';
import '../../core/constants/firebase_paths.dart';
import 'firebase_service.dart';

class ChatServiceFinal {
  final FirebaseService _firebase = FirebaseService();

  static const int INITIAL_MESSAGES_LIMIT = 15;

  final Map<String, List<Message>> _messagesCache = {};
  final Map<String, int> _lastLoadedTimestamp = {};
  final Map<String, StreamSubscription> _activeListeners = {};

  String? _activeChat;
  String? _userRole;

  static final ChatServiceFinal _instance = ChatServiceFinal._internal();
  factory ChatServiceFinal() => _instance;
  ChatServiceFinal._internal();

  // ========================================
  // 1️⃣ INICIALIZAÇÃO
  // ========================================

  Future<Chat> initializeChat(
    String chatId,
    String contractorId,
    String employeeId,
    String userRole,
  ) async {
    try {
      final chatSnapshot = await _firebase.getSnapshot(
        FirebasePaths.chatPath(chatId),
      );

      Chat chat;

      if (chatSnapshot == null) {
        final initialData = Chat.createInitialStructure(contractorId, employeeId);
        await _firebase.chatRef(chatId).set(initialData);
        await _firebase.ensureChatMessagesStructure(chatId);
        chat = Chat.fromMap(chatId, initialData);
      } else {
        chat = Chat.fromMap(chatId, chatSnapshot.value as Map<dynamic, dynamic>);
        await _firebase.ensureChatMessagesStructure(chatId);
      }

      return chat;
    } catch (e) {
      throw Exception('Erro ao inicializar chat: $e');
    }
  }

  // ========================================
  // 2️⃣ STATUS ONLINE/OFFLINE
  // ========================================

  Future<void> setUserOnline(String chatId, String userRole) async {
    try {
      _activeChat = chatId;
      _userRole = userRole;

      final statusPath = 'Chats/$chatId/participants/$userRole';
      final lastSeenPath = 'Chats/$chatId/participants/${userRole}_last_seen';
      final now = ServerValue.timestamp;

      await _firebase.updateMultiplePaths({
        statusPath: 'online',
        lastSeenPath: now,
      });

      _firebase.setOnDisconnect(statusPath, 'offline');
      _firebase.setOnDisconnect(lastSeenPath, now);
    } catch (e) {
      print('❌ Erro ao marcar online: $e');
    }
  }

  Future<void> setUserOffline(String chatId, String userRole) async {
    try {
      final statusPath = 'Chats/$chatId/participants/$userRole';
      final lastSeenPath = 'Chats/$chatId/participants/${userRole}_last_seen';

      await _firebase.updateMultiplePaths({
        statusPath: 'offline',
        lastSeenPath: ServerValue.timestamp,
      });

      await _firebase.cancelOnDisconnect(statusPath);
      await _firebase.cancelOnDisconnect(lastSeenPath);

      _activeChat = null;
      _userRole = null;
    } catch (e) {
      print('❌ Erro ao marcar offline: $e');
    }
  }

  // ========================================
  // 3️⃣ ENVIAR MENSAGEM
  // ========================================

  Future<String> sendMessage(
    String chatId,
    String text,
    String senderRole,
  ) async {
    try {
      if (text.trim().isEmpty) throw Exception('Mensagem vazia');

      final now = DateTime.now().millisecondsSinceEpoch;
      final messagesRef = _firebase.chatMessagesRef(chatId).push();
      final messageId = messagesRef.key!;

      final message = Message(
        id: messageId,
        text: text.trim(),
        sender: senderRole,
        timestamp: now,
        // Quem envia já leu a própria mensagem
        readByContractor: senderRole == 'contractor',
        readByEmployee: senderRole == 'employee',
      );

      await messagesRef.set(message.toMap());

      final recipientRole = senderRole == 'contractor' ? 'employee' : 'contractor';
      await _incrementUnreadCount(chatId, recipientRole);

      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: text.trim(),
        lastSender: senderRole,
        lastTimestamp: now,
      );

      print('✅ Mensagem enviada: $messageId');
      return messageId;
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

Future<void> _incrementUnreadCount(String chatId, String userRole) async {
  try {
    final countRef = _firebase.database.ref('Chats/$chatId/unreadCount/$userRole');
    
    // Lê o valor ANTES da transação
    final before = await countRef.get();
    print('🔢 ANTES da transação: ${before.value} (tipo: ${before.value.runtimeType})');
    
    final result = await countRef.runTransaction((current) {
      print('🔄 current dentro da transação: $current (tipo: ${current.runtimeType})');
      if (current == null) return Transaction.success(1);
      final currentCount = (current as num).toInt();
      print('✅ novo valor será: ${currentCount + 1}');
      return Transaction.success(currentCount + 1);
    });
    
    print('💾 resultado commitado: ${result.committed} | valor: ${result.snapshot.value}');
    
  } catch (e, stack) {
    print('❌ Erro ao incrementar unreadCount: $e');
    print('Stack: $stack');
  }
}

  // ========================================
  // 4️⃣ STREAM DE MENSAGENS
  // ========================================

  Stream<List<Message>> getMessagesStream(String chatId) {
    final controller = StreamController<List<Message>>.broadcast();

    _loadInitialMessages(chatId, INITIAL_MESSAGES_LIMIT).then((initialMessages) {
      _messagesCache[chatId] = initialMessages;
      controller.add(initialMessages);

      if (initialMessages.isNotEmpty) {
        _lastLoadedTimestamp[chatId] = initialMessages.last.timestamp;
      }

      _setupIncrementalListener(chatId, controller);
    });

    return controller.stream;
  }

  Future<List<Message>> _loadInitialMessages(String chatId, int limit) async {
    try {
      final snapshot = await _firebase
          .chatMessagesRef(chatId)
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) return [];

      final data = snapshot.value;
      if (data is! Map) return [];

      final messages = <Message>[];

      (data as Map<dynamic, dynamic>).forEach((key, value) {
        if (key == '_placeholder') return;
        if (value is Map) {
          try {
            final msg = Message.fromMap(key, value);
            print('📩 Mensagem $key | read_by_contractor=${msg.readByContractor} | read_by_employee=${msg.readByEmployee}');
            messages.add(msg);
          } catch (e) {
            print('⚠️ Erro ao parsear mensagem $key: $e');
          }
        }
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      print('❌ Erro ao carregar mensagens iniciais: $e');
      return [];
    }
  }

  void _setupIncrementalListener(
    String chatId,
    StreamController<List<Message>> controller,
  ) {
    final lastTimestamp = _lastLoadedTimestamp[chatId] ?? 0;

    final listener = _firebase
        .chatMessagesRef(chatId)
        .orderByChild('timestamp')
        .startAfter(lastTimestamp)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.key == '_placeholder') return;

      final data = event.snapshot.value;
      if (data is! Map) return;

      try {
        final newMessage = Message.fromMap(event.snapshot.key!, data);
        final currentMessages = _messagesCache[chatId] ?? [];
        final isDuplicate = currentMessages.any((m) => m.id == newMessage.id);

        if (!isDuplicate) {
          currentMessages.add(newMessage);
          _messagesCache[chatId] = currentMessages;
          _lastLoadedTimestamp[chatId] = newMessage.timestamp;
          controller.add(currentMessages);
        }
      } catch (e) {
        print('❌ Erro ao processar nova mensagem: $e');
      }
    });

    // ✅ Listener de CHANGES — quando read_by_ muda no Firebase,
    // atualiza a mensagem no cache e re-emite a lista
    final changeListener = _firebase
        .chatMessagesRef(chatId)
        .onChildChanged
        .listen((event) {
      if (event.snapshot.key == '_placeholder') return;

      final data = event.snapshot.value;
      if (data is! Map) return;

      try {
        final updatedMessage = Message.fromMap(event.snapshot.key!, data);
        final currentMessages = _messagesCache[chatId] ?? [];
        final index = currentMessages.indexWhere((m) => m.id == updatedMessage.id);

        if (index != -1) {
          currentMessages[index] = updatedMessage;
          _messagesCache[chatId] = currentMessages;
          controller.add(List.from(currentMessages));
          print('🔄 Mensagem atualizada: ${updatedMessage.id} | read_by_contractor=${updatedMessage.readByContractor} | read_by_employee=${updatedMessage.readByEmployee}');
        }
      } catch (e) {
        print('❌ Erro ao processar mudança de mensagem: $e');
      }
    });

    _activeListeners['messages_$chatId'] = listener;
    _activeListeners['changes_$chatId'] = changeListener;
  }

  // ========================================
  // 5️⃣ PAGINAÇÃO
  // ========================================

  Future<List<Message>> loadOlderMessages(
    String chatId, {
    required int oldestTimestamp,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firebase
          .chatMessagesRef(chatId)
          .orderByChild('timestamp')
          .endBefore(oldestTimestamp)
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) return [];

      final data = snapshot.value;
      if (data is! Map) return [];

      final messages = <Message>[];

      (data as Map<dynamic, dynamic>).forEach((key, value) {
        if (key == '_placeholder') return;
        if (value is Map) {
          try {
            messages.add(Message.fromMap(key, value));
          } catch (e) {
            print('⚠️ Erro ao parsear mensagem antiga: $e');
          }
        }
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final cachedMessages = _messagesCache[chatId] ?? [];
      _messagesCache[chatId] = [...messages, ...cachedMessages];

      return messages;
    } catch (e) {
      print('❌ Erro ao carregar mensagens antigas: $e');
      return [];
    }
  }

  // ========================================
  // 6️⃣ MARK AS READ
  //
  // Zera unreadCount E atualiza read_by_contractor
  // ou read_by_employee nas mensagens do Firebase.
  // O onChildChanged acima re-emite a lista automaticamente.
  // ========================================

  Future<void> markAsRead(String chatId, String userRole) async {
    try {
      print('═══════════════════════════════════════');
      print('📖 markAsRead | chat=$chatId | role=$userRole');

      // Campo que este usuário precisa marcar como lido
      final readField = userRole == 'contractor'
          ? 'read_by_contractor'
          : 'read_by_employee';

      // 1. Busca mensagens onde o campo ainda é false
      final snapshot = await _firebase
          .chatMessagesRef(chatId)
          .orderByChild(readField)
          .equalTo(false)
          .get();

      print('📦 Mensagens com $readField=false: ${snapshot.exists ? 'sim' : 'nenhuma'}');

      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};

        data.forEach((messageId, value) {
          if (messageId == '_placeholder') return;
          // Caminho absoluto a partir da raiz do banco
          updates['ChatMessages/$chatId/$messageId/$readField'] = true;
          print('   ✏️ Marcando: ChatMessages/$chatId/$messageId/$readField = true');
        });

        if (updates.isNotEmpty) {
          // Batch update — uma única escrita no Firebase
          await _firebase.database.ref().update(updates);
          print('✅ ${updates.length} mensagens atualizadas');
        }
      }

      // 2. Zera o unreadCount
      await _firebase.database
          .ref('Chats/$chatId/unreadCount/$userRole')
          .set(0);
      // ✅ ADICIONAR NO FINAL - após zerar unreadCount
    print('✅ unreadCount/$userRole zerado');
    
    // 🔥 CRÍTICO: Recalcular badge global
    await _recalculateBadgeForUserInChat(chatId, userRole);
      print('✅ unreadCount/$userRole zerado');
      print('═══════════════════════════════════════');
    } catch (e) {
      print('❌ Erro em markAsRead: $e');
    }
  }

  Future<void> _recalculateBadgeForUserInChat(String chatId, String userRole) async {
  try {
    // Pega contractorId e employeeId do chat
    final chatRef = _firebase.chatRef(chatId);
    final chatSnapshot = await chatRef.get();
    
    if (!chatSnapshot.exists) return;
    
    final chatData = chatSnapshot.value as Map<dynamic, dynamic>;
    final contractorId = chatData['contractor']?.toString() ?? '';
    final employeeId = chatData['employee']?.toString() ?? '';
    
    // Recalcula para AMBOS os usuários do chat
    if (contractorId.isNotEmpty) {
      await BadgeHelper.recalculateChatBadge(contractorId);
    }
    if (employeeId.isNotEmpty && employeeId != contractorId) {
      await BadgeHelper.recalculateChatBadge(employeeId);
    }
  } catch (e) {
    print('❌ Erro ao recalcular badge do chat: $e');
  }
}
  // ========================================
  // 7️⃣ STATUS DO OUTRO USUÁRIO
  // ========================================

  Stream<ParticipantData> getOtherParticipantStatus(
    String chatId,
    String myRole,
  ) {
    final otherRole = myRole == 'contractor' ? 'employee' : 'contractor';

    return _firebase.database
        .ref('Chats/$chatId/participants')
        .onValue
        .map((event) {
      try {
        if (event.snapshot.exists) {
          final data = event.snapshot.value;
          if (data is Map) {
            return ParticipantData.fromMap(data, otherRole);
          }
        }
      } catch (e) {
        print('❌ Erro ao processar status: $e');
      }
      return ParticipantData(
        status: 'offline',
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  // ========================================
  // 8️⃣ UNREAD COUNT
  // ========================================

  Stream<int> getUnreadCountStream(String chatId, String userRole) {
    return _firebase.database
        .ref('Chats/$chatId/unreadCount/$userRole')
        .onValue
        .map((event) => (event.snapshot.value as int?) ?? 0);
  }

  // ========================================
  // 9️⃣ METADATA
  // ========================================

  Future<void> _updateChatMetadata({
    required String chatId,
    required String lastMessage,
    required String lastSender,
    required int lastTimestamp,
  }) async {
    try {
      await _firebase.chatMetadataRef(chatId).update({
        'last_message': lastMessage,
        'last_sender': lastSender,
        'last_timestamp': lastTimestamp,
      });
    } catch (e) {
      print('❌ Erro ao atualizar metadata: $e');
    }
  }

  // ========================================
  // 🔟 LISTA DE CHATS
  // ========================================

  Stream<List<Chat>> getChatListStream(String userId, String userRole) {
    final field = userRole == 'contractor' ? 'contractor' : 'employee';

    return _firebase.database
        .ref('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .onValue
        .map((event) {
      try {
        if (!event.snapshot.exists) return <Chat>[];

        final data = event.snapshot.value;
        if (data is! Map) return <Chat>[];

        final chats = <Chat>[];

        (data as Map<dynamic, dynamic>).forEach((chatId, chatData) {
          if (chatData is Map) {
            try {
              chats.add(Chat.fromMap(chatId, chatData));
            } catch (e) {
              print('❌ Erro ao parsear chat $chatId: $e');
            }
          }
        });

        chats.sort((a, b) =>
            b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));

        return chats;
      } catch (e) {
        print('❌ Erro ao processar lista de chats: $e');
        return <Chat>[];
      }
    });
  }

  // ========================================
  // 🧹 CLEANUP
  // ========================================

  void disposeChat() {
    _activeListeners.forEach((_, sub) => sub.cancel());
    _activeListeners.clear();
    _activeChat = null;
    _userRole = null;
    print('🧹 Chat listeners cancelados');
  }

  void clearChatCache(String chatId) {
    _messagesCache.remove(chatId);
    _lastLoadedTimestamp.remove(chatId);
  }

  void clearAllCache() {
    _messagesCache.clear();
    _lastLoadedTimestamp.clear();
  }

  void dispose() {
    disposeChat();
    clearAllCache();
  }
}