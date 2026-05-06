import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserRelationShipService {
  final _db = FirebaseDatabase.instance.ref();

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  Future<void> _ensureFreshToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      print('⚠️ _ensureFreshToken: $e');
    }
  }

  Future<bool> isUserBlocked(String myUserId, String targetUserId) async {
    try {
      final snap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();
      return snap.exists && _isTruthy(snap.value);
    } catch (e) {
      print('❌ isUserBlocked: $e');
      return false;
    }
  }

  Future<Set<String>> fetchAllBlockedUsers(String myUserId) async {
    try {
      final results = await Future.wait([
        fetchUsersIBlocked(myUserId),
        fetchUsersWhoBlockedMe(myUserId),
      ]);
      return {...results[0], ...results[1]};
    } catch (e) {
      print('❌ fetchAllBlockedUsers: $e');
      return {};
    }
  }

  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 blockUser: $myUserId -> $targetUserId');

      final alreadySnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Já bloqueado no Firebase');
        return false;
      }

      await _ensureFreshToken();

      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .set(true);

      final confirmSnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (!confirmSnap.exists || !_isTruthy(confirmSnap.value)) {
        print('❌ Escrita não confirmada — token expirado ou rule negou');
        return false;
      }

      try {
        await _db
            .child('blocked_by/$targetUserId/$myUserId')
            .set(true);
      } catch (e) {
        print('⚠️ blocked_by falhou (não crítico): $e');
      }

      print('✅ Bloqueio gravado e confirmado');
      return true;
    } catch (e, st) {
      print('❌ blockUser erro: $e\n$st');
      return false;
    }
  }

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 unblockUser: $myUserId -> $targetUserId');

      await _ensureFreshToken();

      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .remove();

      try {
        await _db
            .child('blocked_by/$targetUserId/$myUserId')
            .remove();
      } catch (e) {
        print('⚠️ blocked_by remove falhou (não crítico): $e');
      }

      print('✅ Desbloqueado com sucesso');
      return true;
    } catch (e, st) {
      print('❌ unblockUser erro: $e\n$st');
      return false;
    }
  }

  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();
      if (!snap.exists || snap.value == null) return {};

      final value = snap.value;
      if (value is! Map) return {};

      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      print('❌ fetchUsersIBlocked: $e');
      return {};
    }
  }

  Future<Set<String>> fetchUsersWhoBlockedMe(String myUserId) async {
    try {
      final snap = await _db.child('blocked_by/$myUserId').get();
      if (!snap.exists || snap.value == null) return {};

      final value = snap.value;
      if (value is! Map) return {};

      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      print('❌ fetchUsersWhoBlockedMe: $e');
      return {};
    }
  }

  Future<({bool iBlockedThem, bool theyBlockedMe})> checkRelationship(
    String myUserId,
    String otherUserId,
  ) async {
    try {
      final results = await Future.wait([
        _db.child('Users/$myUserId/blocked_users/$otherUserId').get(),
        _db.child('blocked_by/$myUserId/$otherUserId').get(),
      ]);

      final iBlockedThem = results[0].exists && _isTruthy(results[0].value);
      final theyBlockedMe = results[1].exists && _isTruthy(results[1].value);

      print('checkRelationship: iBlockedThem=$iBlockedThem theyBlockedMe=$theyBlockedMe');
      return (iBlockedThem: iBlockedThem, theyBlockedMe: theyBlockedMe);
    } catch (e) {
      print('❌ checkRelationship: $e');
      return (iBlockedThem: false, theyBlockedMe: false);
    }
  }

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}