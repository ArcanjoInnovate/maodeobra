import 'package:flutter/foundation.dart';
// lib/services/chat_migration_service.dart

import 'package:dartobra_new/services/chat/firebase_service.dart';

/// Serviço para migrar chats da estrutura antiga para nova
/// 
/// ESTRUTURA ANTIGA:
/// Chats/{chatId}/messages/{messageId}
/// 
/// ESTRUTURA NOVA:
/// ChatMessages/{chatId}/{messageId}
class ChatMigrationService {
  final FirebaseService _firebase = FirebaseService();

  /// Migra um chat específico
  Future<void> migrateChat(String chatId) async {
    try {
      debugPrint('🔄 Iniciando migração do chat: $chatId');

      // 1. Busca mensagens antigas
      final oldMessagesRef = _firebase.database
          .ref('Chats/$chatId/messages');
      
      final snapshot = await oldMessagesRef.get();

      if (!snapshot.exists) {
        debugPrint('✅ Chat $chatId não tem mensagens antigas para migrar');
        return;
      }

      final oldMessages = snapshot.value as Map<dynamic, dynamic>;
      
      // Ignora se for apenas o placeholder "init"
      if (oldMessages.length == 1 && oldMessages.containsKey('init')) {
        debugPrint('✅ Chat $chatId só tem placeholder, nada a migrar');
        return;
      }

      // 2. Copia para nova estrutura
      final newMessagesRef = _firebase.database
          .ref('ChatMessages/$chatId');

      final Map<String, dynamic> messagesToMigrate = {};

      oldMessages.forEach((messageId, messageData) {
        if (messageId == 'init') return; // Pula placeholder
        
        if (messageData is Map) {
          messagesToMigrate[messageId.toString()] = messageData;
        }
      });

      if (messagesToMigrate.isEmpty) {
        debugPrint('✅ Chat $chatId não tem mensagens válidas para migrar');
        return;
      }

      // 3. Salva na nova estrutura
      await newMessagesRef.set(messagesToMigrate);

      debugPrint('✅ Migradas ${messagesToMigrate.length} mensagens do chat $chatId');

      // 4. OPCIONAL: Remove mensagens antigas (comente se quiser manter backup)
      // await oldMessagesRef.remove();
      // print('🗑️ Mensagens antigas removidas de Chats/$chatId/messages');

    } catch (e) {
      debugPrint('❌ Erro ao migrar chat $chatId: $e');
      rethrow;
    }
  }

  /// Migra todos os chats de um usuário
  Future<void> migrateUserChats(String userId, String userRole) async {
    try {
      debugPrint('🔄 Iniciando migração dos chats do usuário: $userId ($userRole)');

      // Busca todos os chats do usuário
      final field = userRole == 'contractor' ? 'contractor' : 'employee';
      
      final chatsSnapshot = await _firebase.database
          .ref('Chats')
          .orderByChild(field)
          .equalTo(userId)
          .get();

      if (!chatsSnapshot.exists) {
        debugPrint('✅ Usuário não tem chats para migrar');
        return;
      }

      final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
      int migratedCount = 0;

      for (var chatId in chats.keys) {
        try {
          await migrateChat(chatId.toString());
          migratedCount++;
        } catch (e) {
          debugPrint('⚠️ Erro ao migrar chat $chatId: $e');
          // Continua com os próximos chats mesmo se um falhar
        }
      }

      debugPrint('✅ Migração concluída: $migratedCount de ${chats.length} chats');

    } catch (e) {
      debugPrint('❌ Erro ao migrar chats do usuário: $e');
      rethrow;
    }
  }

  /// Verifica se um chat precisa ser migrado
  Future<bool> needsMigration(String chatId) async {
    try {
      // Verifica se tem mensagens na estrutura antiga
      final oldMessagesSnapshot = await _firebase.database
          .ref('Chats/$chatId/messages')
          .get();

      if (!oldMessagesSnapshot.exists) {
        return false;
      }

      final oldMessages = oldMessagesSnapshot.value as Map<dynamic, dynamic>;
      
      // Ignora se for só o placeholder
      if (oldMessages.length == 1 && oldMessages.containsKey('init')) {
        return false;
      }

      // Verifica se já existe na estrutura nova
      final newMessagesSnapshot = await _firebase.database
          .ref('ChatMessages/$chatId')
          .get();

      // Precisa migrar se tem mensagens antigas E não tem na nova estrutura
      return !newMessagesSnapshot.exists;

    } catch (e) {
      debugPrint('Erro ao verificar migração: $e');
      return false;
    }
  }

  /// Migra automaticamente ao abrir chat (se necessário)
  Future<void> migrateIfNeeded(String chatId) async {
    try {
      final needsMig = await needsMigration(chatId);
      
      if (needsMig) {
        debugPrint('🔄 Chat $chatId precisa ser migrado, iniciando...');
        await migrateChat(chatId);
      }
    } catch (e) {
      debugPrint('⚠️ Erro na migração automática: $e');
      // Não lança erro para não bloquear o chat
    }
  }

  /// Limpa estrutura antiga após confirmar migração
  Future<void> cleanupOldStructure(String chatId) async {
    try {
      debugPrint('🗑️ Limpando estrutura antiga do chat: $chatId');

      // Verifica se migração foi bem-sucedida
      final newMessagesSnapshot = await _firebase.database
          .ref('ChatMessages/$chatId')
          .get();

      if (!newMessagesSnapshot.exists) {
        throw Exception('Migração não confirmada, não é seguro limpar');
      }

      // Remove mensagens antigas
      await _firebase.database
          .ref('Chats/$chatId/messages')
          .remove();

      // Remove historical_messages se existir
      await _firebase.database
          .ref('Chats/$chatId/historical_messages')
          .remove();

      debugPrint('✅ Estrutura antiga removida com sucesso');

    } catch (e) {
      debugPrint('❌ Erro ao limpar estrutura antiga: $e');
      rethrow;
    }
  }

  /// Estatísticas de migração
  Future<Map<String, int>> getMigrationStats() async {
    try {
      final chatsSnapshot = await _firebase.database
          .ref('Chats')
          .get();

      if (!chatsSnapshot.exists) {
        return {
          'total': 0,
          'migrated': 0,
          'pending': 0,
        };
      }

      final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
      int total = chats.length;
      int migrated = 0;
      int pending = 0;

      for (var chatId in chats.keys) {
        final needs = await needsMigration(chatId.toString());
        if (needs) {
          pending++;
        } else {
          migrated++;
        }
      }

      return {
        'total': total,
        'migrated': migrated,
        'pending': pending,
      };

    } catch (e) {
      debugPrint('Erro ao obter estatísticas: $e');
      return {'total': 0, 'migrated': 0, 'pending': 0};
    }
  }
}
