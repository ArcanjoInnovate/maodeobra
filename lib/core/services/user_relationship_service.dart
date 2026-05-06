import 'package:firebase_database/firebase_database.dart';

class UserRelationShipService {
  final _db = FirebaseDatabase.instance.ref();

  // ═══════════════════════════════════════════════════════════
  // POR QUE EXISTE O _isTruthy?
  //
  // O SDK do Firebase iOS deserializa booleanos do JSON como
  // inteiros (1 / 0) em vez de bool (true / false).
  // Android e Web entregam bool normalmente.
  // Em Dart, 1 == true é FALSE — tipagem forte.
  // Então sem esse helper, qualquer verificação "== true"
  // falha silenciosamente no iOS.
  // ═══════════════════════════════════════════════════════════
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  // ── Verificação direta de um bloqueio específico ──────────
  // Usado pelo BlockProvider antes de tentar bloquear,
  // evitando o bug de bloquear o mesmo usuário duas vezes no iOS
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

  // ── Buscar todos os bloqueados ────────────────────────────

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

  // ── Bloquear ──────────────────────────────────────────────
  //
  // FIX iOS: NÃO usar _db.update() com paths multi-level (contendo "/").
  //
  // O SDK nativo do Firebase iOS silencia escritas via update() com
  // paths profundos — o await retorna sem exceção mas NADA é gravado
  // no banco. Android e Web funcionam pois usam a REST API por baixo.
  //
  // Solução: usar .child(...).set() individualmente em cada referência.
  // É mais verboso mas 100% confiável em todas as plataformas.
  // ─────────────────────────────────────────────────────────
  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 blockUser: $myUserId -> $targetUserId');

      // Verifica se já existe antes de gravar
      final alreadySnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Já bloqueado no Firebase');
        return false;
      }

      // ✅ FIX iOS: set() individual em cada ref em vez de update() multi-level
      // update({'path/com/barras': value}) falha silenciosamente no iOS SDK
      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .set(true);

      await _db
          .child('blocked_by/$targetUserId/$myUserId')
          .set(true);

      // ✅ Verificação pós-escrita: confirma que realmente foi gravado
      // Necessário no iOS onde a escrita pode falhar sem lançar exceção
      final confirmSnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (!confirmSnap.exists || !_isTruthy(confirmSnap.value)) {
        print('❌ Escrita não confirmada no Firebase (bug iOS silent fail)');
        return false;
      }

      print('✅ Bloqueio gravado e confirmado no Firebase');
      return true;
    } catch (e, st) {
      print('❌ blockUser erro: $e\n$st');
      return false;
    }
  }

  // ── Desbloquear ───────────────────────────────────────────
  //
  // FIX iOS: mesmo motivo do blockUser — usa remove() individual
  // em vez de update() com valor null, que também falha no iOS.
  // ─────────────────────────────────────────────────────────
  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 unblockUser: $myUserId -> $targetUserId');

      // ✅ FIX iOS: remove() individual em cada ref
      // update({'path': null}) falha silenciosamente no iOS SDK
      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .remove();

      await _db
          .child('blocked_by/$targetUserId/$myUserId')
          .remove();

      print('✅ Desbloqueado com sucesso');
      return true;
    } catch (e, st) {
      print('❌ unblockUser erro: $e\n$st');
      return false;
    }
  }

  // ── Queries ───────────────────────────────────────────────

  /// IDs que EU bloqueei
  /// Caminho: Users/MEU_ID/blocked_users = { TARGET_ID: true, ... }
  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final snap = await _db.child('Users/$myUserId/blocked_users').get();
      if (!snap.exists || snap.value == null) return {};

      final value = snap.value;
      if (value is! Map) return {};

      // Keys são os IDs bloqueados
      // _isTruthy nos values filtra entradas inválidas (iOS pode entregar 1)
      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      print('❌ fetchUsersIBlocked: $e');
      return {};
    }
  }

  /// IDs que ME bloquearam
  /// Caminho: blocked_by/MEU_ID = { QUEM_ME_BLOQUEOU: true, ... }
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

  /// Checar relação específica com outro usuário
  Future<({bool iBlockedThem, bool theyBlockedMe})> checkRelationship(
    String myUserId,
    String otherUserId,
  ) async {
    try {
      final results = await Future.wait([
        // Eu bloqueei o outro?
        // Users/MEU_ID/blocked_users/OUTRO_ID
        _db.child('Users/$myUserId/blocked_users/$otherUserId').get(),
        // O outro me bloqueou?
        // blocked_by/MEU_ID/OUTRO_ID
        _db.child('blocked_by/$myUserId/$otherUserId').get(),
      ]);

      final iBlockedThem = results[0].exists && _isTruthy(results[0].value);
      final theyBlockedMe = results[1].exists && _isTruthy(results[1].value);

      print(
          'checkRelationship: iBlockedThem=$iBlockedThem theyBlockedMe=$theyBlockedMe');
      return (iBlockedThem: iBlockedThem, theyBlockedMe: theyBlockedMe);
    } catch (e) {
      print('❌ checkRelationship: $e');
      return (iBlockedThem: false, theyBlockedMe: false);
    }
  }

  // ── Streams em tempo real para o BlockProvider ────────────

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}