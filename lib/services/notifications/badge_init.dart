// SCRIPT PARA VERIFICAR E INICIALIZAR BADGES
// Execute este código UMA VEZ no seu app (pode ser no initState do HomeScreen)

import 'package:firebase_database/firebase_database.dart';

class BadgeInitializer {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Verifica e inicializa badge se não existir
  static Future<void> ensureBadgeExists(String userId) async {
    try {
      final snapshot = await _database.child('badges/$userId').get();
      
      if (!snapshot.exists) {
        print('⚠️ Badge não existe para $userId, criando...');
        
        await _database.child('badges/$userId').set({
          'unread_chats': 0,
          'unread_requests': 0,
          'updated_at': ServerValue.timestamp,
        });
        
        print('✅ Badge criado para $userId');
      } else {
        print('✅ Badge já existe para $userId');
        print('📊 Dados: ${snapshot.value}');
      }
    } catch (e) {
      print('❌ Erro ao verificar badge: $e');
    }
  }

  /// Recalcula badges do zero (use apenas se estiver com problemas)
  static Future<void> recalculateBadges(String userId, String userRole) async {
    try {
      print('🔄 Recalculando badges para $userId ($userRole)...');
      
      int unreadChats = 0;
      int unreadRequests = 0;

      // Conta chats não lidos
      final role = userRole == 'worker' ? 'employee' : 'contractor';
      final chatsSnapshot = await _database
          .child('Chats')
          .orderByChild(role)
          .equalTo(userId)
          .get();

      if (chatsSnapshot.exists) {
        final chats = chatsSnapshot.value as Map<dynamic, dynamic>;
        
        for (var chatEntry in chats.entries) {
          final chatData = chatEntry.value as Map<dynamic, dynamic>;
          final unreadCount = chatData['unreadCount'] as Map<dynamic, dynamic>?;
          
          if (unreadCount != null) {
            final count = (unreadCount[role] as int?) ?? 0;
            if (count > 0) {
              unreadChats++;
            }
          }
        }
      }

      // Conta requests não lidos
      if (userRole == 'worker') {
        // Conta worker requests
        final profileSnapshot = await _database
            .child('professionals')
            .orderByChild('local_id')
            .equalTo(userId)
            .get();

        if (profileSnapshot.exists) {
          final profiles = profileSnapshot.value as Map<dynamic, dynamic>;
          final profileData = profiles.values.first as Map<dynamic, dynamic>;
          final views = profileData['views'] as Map<dynamic, dynamic>?;
          final requestViews = views?['request_views'] as Map<dynamic, dynamic>?;

          if (requestViews != null) {
            for (var req in requestViews.values) {
              final reqData = req as Map<dynamic, dynamic>;
              if (reqData['viewed_by_owner'] == false) {
                unreadRequests++;
              }
            }
          }
        }
      } else {
        // Conta vacancy requests
        final vacanciesSnapshot = await _database
            .child('vacancy')
            .orderByChild('local_id')
            .equalTo(userId)
            .get();

        if (vacanciesSnapshot.exists) {
          final vacancies = vacanciesSnapshot.value as Map<dynamic, dynamic>;
          
          for (var vacancy in vacancies.values) {
            final vacancyData = vacancy as Map<dynamic, dynamic>;
            final views = vacancyData['views'] as Map<dynamic, dynamic>?;
            final requestViews = views?['request_views'] as Map<dynamic, dynamic>?;

            if (requestViews != null) {
              for (var req in requestViews.values) {
                final reqData = req as Map<dynamic, dynamic>;
                if (reqData['viewed_by_owner'] == false) {
                  unreadRequests++;
                }
              }
            }
          }
        }
      }

      // Limita a 9
      unreadChats = unreadChats.clamp(0, 9);
      unreadRequests = unreadRequests.clamp(0, 9);

      // Atualiza no Firebase
      await _database.child('badges/$userId').set({
        'unread_chats': unreadChats,
        'unread_requests': unreadRequests,
        'updated_at': ServerValue.timestamp,
      });

      print('✅ Badges recalculados:');
      print('   📬 Chats: $unreadChats');
      print('   📋 Requests: $unreadRequests');
      
    } catch (e) {
      print('❌ Erro ao recalcular badges: $e');
    }
  }

  /// Debug: mostra estrutura completa de badges
  static Future<void> debugBadges(String userId) async {
    try {
      final snapshot = await _database.child('badges/$userId').get();
      
      print('═══════════════════════════════════════');
      print('🔍 DEBUG BADGES - $userId');
      print('═══════════════════════════════════════');
      
      if (snapshot.exists) {
        print('✅ Badge existe');
        print('📊 Dados: ${snapshot.value}');
      } else {
        print('❌ Badge NÃO existe');
      }
      
      print('═══════════════════════════════════════');
    } catch (e) {
      print('❌ Erro ao debugar: $e');
    }
  }
}

// ============================================================
// COMO USAR
// ============================================================

// 1. No HomeScreen, initState:
/*
@override
void initState() {
  super.initState();
  
  // Garante que badge existe
  BadgeInitializer.ensureBadgeExists(widget.local_id);
  
  // OU se estiver com problemas, recalcula do zero:
  // BadgeInitializer.recalculateBadges(widget.local_id, _activeMode);
}
*/

// 2. Para debugar:
/*
// Adicione um botão temporário no AppBar:
IconButton(
  icon: Icon(Icons.bug_report),
  onPressed: () async {
    await BadgeInitializer.debugBadges(widget.local_id);
    await BadgeInitializer.recalculateBadges(widget.local_id, _activeMode);
  },
)
*/