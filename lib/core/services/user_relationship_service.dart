import 'package:firebase_database/firebase_database.dart';

class UserRelationShipService {
  final _db = FirebaseDatabase.instance.ref();

  // ── Bloquear ──────────────────────────────────────────────

  /// Todos os IDs bloqueados (eu bloqueei + me bloquearam)
  Future<Set<String>> fetchAllBlockedUsers(String myUserId) async {
    try {
      final results = await Future.wait([
        fetchUsersIBlocked(myUserId),
        fetchUsersWhoBlockedMe(myUserId),
      ]);
      return {...results[0], ...results[1]};
    } catch (e) {
      print('❌ Erro fetchAllBlockedUsers: $e');
      return {};
    }
  }

  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 Tentando bloquear: $myUserId -> $targetUserId');

      // ✅ CORREÇÃO: Verifica nos dois caminhos possíveis
      final results = await Future.wait([
        _db.child('Users/$myUserId/blocked_users/$targetUserId').get(),
        _db.child('Users/$myUserId/blocked_users').child(targetUserId).get(),
      ]);

      final already1 = results[0].exists && results[0].value == true;
      final already2 = results[1].exists && results[1].value == true;

      if (already1 || already2) {
        print('⚠️ Usuário já bloqueado anteriormente');
        return false;
      }

      // ✅ CORREÇÃO: Usa transação para garantir atomicidade em iOS
      final updates = <String, dynamic>{
        'Users/$myUserId/blocked_users/$targetUserId': true,
        'blocked_by/$targetUserId/$myUserId': true,
      };

      print('📝 Enviando updates: $updates');

      // ✅ CORREÇÃO: Aguarda a confirmação da escrita
      await _db.update(updates);

      // ✅ VALIDAÇÃO: Verifica se realmente foi gravado
      await Future.delayed(const Duration(milliseconds: 500));
      final verification = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (!verification.exists || verification.value != true) {
        print('❌ FALHA: Bloqueio não foi persistido no Firebase');
        return false;
      }

      print('✅ Usuário bloqueado com sucesso');
      return true;
    } catch (e, stackTrace) {
      print('❌ Erro ao bloquear usuário: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ── Desbloquear ───────────────────────────────────────────

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 Tentando desbloquear: $myUserId -> $targetUserId');

      await _db.update({
        'Users/$myUserId/blocked_users/$targetUserId': null,
        'blocked_by/$targetUserId/$myUserId': null,
      });

      print('✅ Usuário desbloqueado com sucesso');
      return true;
    } catch (e, stackTrace) {
      print('❌ Erro ao desbloquear usuário: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ── Queries pontuais ──────────────────────────────────────

  /// IDs que eu bloqueei
  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();
      
      if (!snap.exists || snap.value == null) {
        print('ℹ️ fetchUsersIBlocked: Nenhum bloqueio encontrado');
        return {};
      }

      final value = snap.value;
      
      // ✅ CORREÇÃO: Tratamento robusto para diferentes tipos de dados
      if (value is Map) {
        final blocked = value.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString())
            .toSet();
        print('ℹ️ fetchUsersIBlocked: ${blocked.length} usuários bloqueados');
        return blocked;
      }

      print('⚠️ fetchUsersIBlocked: Formato de dados inesperado: ${value.runtimeType}');
      return {};
    } catch (e, stackTrace) {
      print('❌ Erro fetchUsersIBlocked: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  /// IDs que me bloquearam
  Future<Set<String>> fetchUsersWhoBlockedMe(String myUserId) async {
    try {
      final snap = await _db.child('blocked_by/$myUserId').get();
      
      if (!snap.exists || snap.value == null) {
        print('ℹ️ fetchUsersWhoBlockedMe: Nenhum bloqueio recebido');
        return {};
      }

      final value = snap.value;

      // ✅ CORREÇÃO: Tratamento robusto para diferentes tipos de dados
      if (value is Map) {
        final blockedBy = value.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString())
            .toSet();
        print('ℹ️ fetchUsersWhoBlockedMe: Bloqueado por ${blockedBy.length} usuários');
        return blockedBy;
      }

      print('⚠️ fetchUsersWhoBlockedMe: Formato de dados inesperado: ${value.runtimeType}');
      return {};
    } catch (e, stackTrace) {
      print('❌ Erro fetchUsersWhoBlockedMe: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  /// Checar relação específica com outro usuário
  Future<({bool iBlockedThem, bool theyBlockedMe})> checkRelationship(
    String myUserId,
    String otherUserId,
  ) async {
    try {
      final results = await Future.wait([
        _db.child('Users/$myUserId/blocked_users/$otherUserId').get(),
        _db.child('blocked_by/$myUserId/$otherUserId').get(),
      ]);

      final iBlockedThem = results[0].exists && results[0].value == true;
      final theyBlockedMe = results[1].exists && results[1].value == true;

      print('ℹ️ checkRelationship: iBlockedThem=$iBlockedThem, theyBlockedMe=$theyBlockedMe');

      return (
        iBlockedThem: iBlockedThem,
        theyBlockedMe: theyBlockedMe,
      );
    } catch (e, stackTrace) {
      print('❌ Erro checkRelationship: $e');
      print('Stack trace: $stackTrace');
      return (iBlockedThem: false, theyBlockedMe: false);
    }
  }

  // ── Streams para o provider ───────────────────────────────

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}