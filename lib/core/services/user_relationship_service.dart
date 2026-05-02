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
      print('Erro fetchAllBlockedUsers: $e');
      return {};
    }
  }
  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      final already = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (already.exists) {
        print('Usuário já bloqueado');
        return false;
      }

      // Atômico: minha lista + índice inverso
      await _db.update({
        'Users/$myUserId/blocked_users/$targetUserId': true,
        'blocked_by/$targetUserId/$myUserId': true,
      });

      return true;
    } catch (e) {
      print('Erro ao bloquear usuário: $e');
      return false;
    }
  }

  // ── Desbloquear ───────────────────────────────────────────

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      await _db.update({
        'Users/$myUserId/blocked_users/$targetUserId': null,
        'blocked_by/$targetUserId/$myUserId': null,
      });
      return true;
    } catch (e) {
      print('Erro ao desbloquear usuário: $e');
      return false;
    }
  }

  // ── Queries pontuais ──────────────────────────────────────

  /// IDs que eu bloqueei
  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();
      if (!snap.exists || snap.value == null) return {};
      return (snap.value as Map).keys.map((k) => k.toString()).toSet();
    } catch (e) {
      print('Erro fetchUsersIBlocked: $e');
      return {};
    }
  }

  /// IDs que me bloquearam
  Future<Set<String>> fetchUsersWhoBlockedMe(String myUserId) async {
    try {
      final snap = await _db.child('blocked_by/$myUserId').get();
      if (!snap.exists || snap.value == null) return {};
      return (snap.value as Map).keys.map((k) => k.toString()).toSet();
    } catch (e) {
      print('Erro fetchUsersWhoBlockedMe: $e');
      return {};
    }
  }

  /// Checar relação específica com outro usuário
  Future<({bool iBlockedThem, bool theyBlockedMe})> checkRelationship(
    String myUserId,
    String otherUserId,
  ) async {
    final results = await Future.wait([
      _db.child('Users/$myUserId/blocked_users/$otherUserId').get(),
      _db.child('blocked_by/$myUserId/$otherUserId').get(),
    ]);
    return (
      iBlockedThem: results[0].exists,
      theyBlockedMe: results[1].exists,
    );
  }

  // ── Streams para o provider ───────────────────────────────

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}