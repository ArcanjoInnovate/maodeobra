import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

// ✅ N3-05: Todo método que faz full scan de Chats/professionals/vacancy
// está restrito a kDebugMode. Em produção, as chamadas são no-ops com aviso
// no console — nunca geram reads desnecessários.

class BadgeInitializer {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Verifica e inicializa badge se não existir.
  /// Seguro para produção: lê apenas badges/{userId} (1 read).
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

        debugPrint('✅ Badge criado para $userId');
      } else {
        debugPrint('✅ Badge já existe para $userId');
        debugPrint('📊 Dados: ${snapshot.value}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar badge: $e');
    }
  }

  /// Recalcula badges do zero fazendo full scan de Chats, professionals e vacancy.
  ///
  /// ⚠️ N3-05: RESTRITO A DEBUG — faz leituras O(N) no RTDB.
  /// Em produção use a Cloud Function weeklyBadgeCleanup para recalcular.
  static Future<void> recalculateBadges(
      String userId, String userRole) async {
    if (!kDebugMode) {
      debugPrint(
        '⛔ recalculateBadges: bloqueado em produção (N3-05). '
        'Use a Cloud Function weeklyBadgeCleanup.',
      );
      return;
    }

    try {
      debugPrint('🔄 [DEBUG] Recalculando badges para $userId ($userRole)...');

      int unreadChats = 0;
      int unreadRequests = 0;

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
          final unreadCount =
              chatData['unreadCount'] as Map<dynamic, dynamic>?;

          if (unreadCount != null) {
            final count = (unreadCount[role] as int?) ?? 0;
            if (count > 0) unreadChats++;
          }
        }
      }

      if (userRole == 'worker') {
        final profileSnapshot = await _database
            .child('professionals')
            .orderByChild('local_id')
            .equalTo(userId)
            .get();

        if (profileSnapshot.exists) {
          final profiles = profileSnapshot.value as Map<dynamic, dynamic>;
          final profileData =
              profiles.values.first as Map<dynamic, dynamic>;
          final views = profileData['views'] as Map<dynamic, dynamic>?;
          final requestViews =
              views?['request_views'] as Map<dynamic, dynamic>?;

          if (requestViews != null) {
            for (var req in requestViews.values) {
              final reqData = req as Map<dynamic, dynamic>;
              if (reqData['viewed_by_owner'] == false) unreadRequests++;
            }
          }
        }
      } else {
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
            final requestViews =
                views?['request_views'] as Map<dynamic, dynamic>?;

            if (requestViews != null) {
              for (var req in requestViews.values) {
                final reqData = req as Map<dynamic, dynamic>;
                if (reqData['viewed_by_owner'] == false) unreadRequests++;
              }
            }
          }
        }
      }

      unreadChats = unreadChats.clamp(0, 9);
      unreadRequests = unreadRequests.clamp(0, 9);

      await _database.child('badges/$userId').set({
        'unread_chats': unreadChats,
        'unread_requests': unreadRequests,
        'updated_at': ServerValue.timestamp,
      });

      debugPrint('✅ [DEBUG] Badges recalculados:');
      debugPrint('   📬 Chats: $unreadChats');
      debugPrint('   📋 Requests: $unreadRequests');
    } catch (e) {
      debugPrint('❌ Erro ao recalcular badges: $e');
    }
  }

  /// Debug: mostra estrutura completa de badges.
  ///
  /// ⚠️ N3-05: RESTRITO A DEBUG.
  static Future<void> debugBadges(String userId) async {
    if (!kDebugMode) {
      debugPrint('⛔ debugBadges: bloqueado em produção (N3-05).');
      return;
    }

    try {
      final snapshot = await _database.child('badges/$userId').get();

      debugPrint('═══════════════════════════════════════');
      debugPrint('🔍 DEBUG BADGES - $userId');
      debugPrint('═══════════════════════════════════════');

      if (snapshot.exists) {
        debugPrint('✅ Badge existe');
        debugPrint('📊 Dados: ${snapshot.value}');
      } else {
        debugPrint('❌ Badge NÃO existe');
      }

      debugPrint('═══════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ Erro ao debugar: $e');
    }
  }
}

// ============================================================
// COMO USAR
// ============================================================

// 1. No HomeScreen, initState — seguro em produção:
/*
@override
void initState() {
  super.initState();
  BadgeInitializer.ensureBadgeExists(widget.local_id);
}
*/

// 2. Para recalcular ou debugar (apenas em builds de debug):
/*
IconButton(
  icon: Icon(Icons.bug_report),
  onPressed: () async {
    await BadgeInitializer.debugBadges(widget.local_id);
    await BadgeInitializer.recalculateBadges(widget.local_id, _activeMode);
  },
)
*/