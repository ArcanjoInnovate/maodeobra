import 'package:firebase_database/firebase_database.dart';

class UserRelationShipService {
  final _db = FirebaseDatabase.instance.ref();

  // ── Helper: normaliza valores booleanos do Firebase ──────────
  // iOS pode retornar int (1) em vez de bool (true)
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  // ── Bloquear ──────────────────────────────────────────────────

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

      // ✅ Verifica se já está bloqueado usando _isTruthy (corrige bug iOS)
      final alreadySnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Usuário já bloqueado anteriormente');
        return false;
      }

      // ✅ Grava o bloqueio de forma atômica
      final updates = <String, dynamic>{
        'Users/$myUserId/blocked_users/$targetUserId': true,
        'blocked_by/$targetUserId/$myUserId': true,
      };

      print('📝 Enviando updates: $updates');
      await _db.update(updates);

      // ✅ Confia no await do update() — não faz verificação pós-escrita
      // A verificação anterior causava falso-negativo no iOS porque
      // o Firebase iOS retorna 1 (int) em vez de true (bool),
      // fazendo verification.value != true ser sempre true no iOS.
      print('✅ Usuário bloqueado com sucesso');
      return true;
    } catch (e, stackTrace) {
      print('❌ Erro ao bloquear usuário: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ── Desbloquear ───────────────────────────────────────────────

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

  // ── Queries pontuais ──────────────────────────────────────────

  /// IDs que eu bloqueei
  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();

      if (!snap.exists || snap.value == null) {
        print('ℹ️ fetchUsersIBlocked: Nenhum bloqueio encontrado');
        return {};
      }

      final value = snap.value;

      // ✅ Garante que é um Map antes de iterar
      if (value is! Map) {
        print('⚠️ fetchUsersIBlocked: Formato inesperado: ${value.runtimeType}');
        return {};
      }

      // ✅ Usa _isTruthy para compatibilidade iOS (int 1 == bool true)
      final blocked = value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();

      print('ℹ️ fetchUsersIBlocked: ${blocked.length} usuários bloqueados');
      return blocked;
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

      // ✅ Garante que é um Map antes de iterar
      if (value is! Map) {
        print('⚠️ fetchUsersWhoBlockedMe: Formato inesperado: ${value.runtimeType}');
        return {};
      }

      // ✅ Usa _isTruthy para compatibilidade iOS (int 1 == bool true)
      final blockedBy = value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();

      print('ℹ️ fetchUsersWhoBlockedMe: Bloqueado por ${blockedBy.length} usuários');
      return blockedBy;
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

      // ✅ Usa _isTruthy para compatibilidade iOS
      final iBlockedThem =
          results[0].exists && _isTruthy(results[0].value);
      final theyBlockedMe =
          results[1].exists && _isTruthy(results[1].value);

      print(
          'ℹ️ checkRelationship: iBlockedThem=$iBlockedThem, theyBlockedMe=$theyBlockedMe');

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

  // ── Streams para o provider ───────────────────────────────────

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}