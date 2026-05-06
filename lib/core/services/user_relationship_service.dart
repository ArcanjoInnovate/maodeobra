import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserRelationShipService {
  final _db = FirebaseDatabase.instance.ref();

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  /// ✅ NOVO: Verifica se o usuário está autenticado e se o token está válido
  Future<String?> _ensureValidAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Usuário não autenticado');
        return null;
      }

      // Força refresh do token
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        print('❌ Token inválido ou vazio');
        return null;
      }

      print('✅ Auth válido para: ${user.uid}');
      return user.uid;
    } catch (e) {
      print('❌ Erro ao verificar auth: $e');
      return null;
    }
  }

  /// ✅ NOVO: Testa conectividade com Firebase
  Future<bool> _testConnection() async {
    try {
      final testRef = _db.child('.info/connected');
      final snap = await testRef.get();
      final connected = snap.value == true;
      print(connected ? '✅ Firebase conectado' : '❌ Firebase desconectado');
      return connected;
    } catch (e) {
      print('❌ Erro ao testar conexão: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFICAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isUserBlocked(String myUserId, String targetUserId) async {
    try {
      final snap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();
      final blocked = snap.exists && _isTruthy(snap.value);
      print('isUserBlocked: $targetUserId = $blocked');
      return blocked;
    } catch (e) {
      print('❌ isUserBlocked erro: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOQUEAR - VERSÃO SIMPLIFICADA FOCADA APENAS EM blocked_users
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('\n═══════════════════════════════════════════════');
      print('🔄 INICIANDO BLOQUEIO');
      print('   De: $myUserId');
      print('   Para: $targetUserId');
      print('═══════════════════════════════════════════════');

      // ✅ PASSO 1: Verificar autenticação
      final authUserId = await _ensureValidAuth();
      if (authUserId == null) {
        print('❌ FALHA: Autenticação inválida');
        return false;
      }

      if (authUserId != myUserId) {
        print('❌ FALHA: UserId não corresponde ao auth ($authUserId != $myUserId)');
        return false;
      }

      // ✅ PASSO 2: Testar conexão
      final connected = await _testConnection();
      if (!connected) {
        print('❌ FALHA: Sem conexão com Firebase');
        return false;
      }

      // ✅ PASSO 3: Verificar se já está bloqueado
      print('\n📋 Verificando se já bloqueado...');
      final alreadySnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Já bloqueado no Firebase');
        return false;
      }
      print('✅ Não está bloqueado, prosseguindo...');

      // ✅ PASSO 4: Escrever no Firebase (APENAS blocked_users)
      print('\n📝 Escrevendo em Firebase...');
      print('   Path: Users/$myUserId/blocked_users/$targetUserId');
      
      final ref = _db.child('Users/$myUserId/blocked_users/$targetUserId');
      
      // Aguarda um pouco para garantir que o token está propagado
      await Future.delayed(const Duration(milliseconds: 300));
      
      await ref.set(true);
      print('✅ set() concluído');

      // ✅ PASSO 5: Verificar se a escrita foi bem-sucedida
      print('\n🔍 Verificando se escrita foi confirmada...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final confirmSnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();

      if (!confirmSnap.exists) {
        print('❌ FALHA: Nó não existe após escrita');
        print('   Possível causa: Firebase Security Rules bloquearam');
        return false;
      }

      if (!_isTruthy(confirmSnap.value)) {
        print('❌ FALHA: Valor não é truthy (value=${confirmSnap.value})');
        return false;
      }

      print('✅ Escrita confirmada!');
      print('   Value: ${confirmSnap.value}');

      // ✅ OPCIONAL: Tentar escrever em blocked_by (não crítico)
      print('\n📝 Tentando escrever em blocked_by (não crítico)...');
      try {
        await _db
            .child('blocked_by/$targetUserId/$myUserId')
            .set(true);
        print('✅ blocked_by escrito');
      } catch (e) {
        print('⚠️ blocked_by falhou (ignorando): $e');
      }

      print('\n═══════════════════════════════════════════════');
      print('✅ BLOQUEIO CONCLUÍDO COM SUCESSO');
      print('═══════════════════════════════════════════════\n');
      
      return true;

    } catch (e, st) {
      print('\n═══════════════════════════════════════════════');
      print('❌ EXCEÇÃO EM blockUser');
      print('   Erro: $e');
      print('   Stack: $st');
      print('═══════════════════════════════════════════════\n');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESBLOQUEAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      print('🔄 unblockUser: $myUserId -> $targetUserId');

      final authUserId = await _ensureValidAuth();
      if (authUserId == null || authUserId != myUserId) {
        print('❌ Auth inválido para desbloquear');
        return false;
      }

      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .remove();

      try {
        await _db
            .child('blocked_by/$targetUserId/$myUserId')
            .remove();
      } catch (e) {
        print('⚠️ blocked_by remove falhou: $e');
      }

      print('✅ Desbloqueado com sucesso');
      return true;
    } catch (e, st) {
      print('❌ unblockUser erro: $e\n$st');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH
  // ══════════════════════════════════════════════════════════════════════════

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