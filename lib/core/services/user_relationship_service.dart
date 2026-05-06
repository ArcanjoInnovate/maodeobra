// lib/core/services/user_relationship_service.dart

import 'dart:async';
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

  Future<String?> _ensureValidAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return null;
      return user.uid;
    } catch (e) {
      print('❌ _ensureValidAuth erro: $e');
      return null;
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
      return snap.exists && _isTruthy(snap.value);
    } catch (e) {
      print('❌ isUserBlocked erro: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOQUEAR — SOLUÇÃO DEFINITIVA PARA iOS
  //
  // A MUDANÇA CRÍTICA: Usa onValue (listener) em vez de .get() para confirmar.
  // O iOS cacheia .get() agressivamente, mas listeners SEMPRE vêm do servidor.
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> blockUser(String myUserId, String targetUserId) async {
    try {
      print('\n═══════════════════════════════════════════════');
      print('🔄 INICIANDO BLOQUEIO');
      print('   De: $myUserId → Para: $targetUserId');
      print('═══════════════════════════════════════════════');

      // PASSO 1: Autenticação
      final authUserId = await _ensureValidAuth();
      if (authUserId == null) {
        print('❌ FALHA: Auth inválido');
        return false;
      }
      if (authUserId != myUserId) {
        print('❌ FALHA: UID não confere');
        return false;
      }

      // PASSO 2: Verifica se já está bloqueado (usa .get() aqui porque não é crítico)
      final alreadySnap = await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .get();
      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        print('⚠️ Já bloqueado — abortando');
        return false;
      }

      final ref = _db.child('Users/$myUserId/blocked_users/$targetUserId');

      // PASSO 3: Setup listener ANTES de escrever
      // Isso garante que vamos receber o update do servidor
      final Completer<bool> completer = Completer<bool>();
      late StreamSubscription<DatabaseEvent> subscription;

      subscription = ref.onValue.listen(
        (event) {
          if (completer.isCompleted) return;

          final snap = event.snapshot;
          if (snap.exists && _isTruthy(snap.value)) {
            print('✅ Listener confirmou escrita do servidor!');
            completer.complete(true);
            subscription.cancel();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            print('❌ Erro no listener: $error');
            completer.complete(false);
            subscription.cancel();
          }
        },
      );

      // PASSO 4: Escreve no Firebase
      print('📝 Executando set()...');
      try {
        await ref.set(true).timeout(const Duration(seconds: 10));
        print('✅ set() concluído');
      } on TimeoutException {
        print('⏱️ Timeout no set()');
        subscription.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return false;
      } catch (e) {
        print('❌ Erro no set(): $e');
        subscription.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }

      // PASSO 5: Aguarda confirmação do listener com timeout
      print('⏳ Aguardando confirmação do listener...');
      final confirmed = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏱️ Timeout aguardando listener');
          subscription.cancel();
          return false;
        },
      );

      if (!confirmed) {
        print('❌ FALHA: Escrita não confirmada pelo servidor');
        return false;
      }

      // PASSO 6: blocked_by em paralelo (não crítico)
      unawaited(
        _db.child('blocked_by/$targetUserId/$myUserId').set(true).catchError(
          (e) {
            print('⚠️ blocked_by falhou (não crítico): $e');
          },
        ),
      );

      print('═══════════════════════════════════════════════');
      print('✅ BLOQUEIO CONCLUÍDO COM SUCESSO');
      print('═══════════════════════════════════════════════\n');
      return true;

    } catch (e, st) {
      print('❌ EXCEÇÃO em blockUser: $e\n$st');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESBLOQUEAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> unblockUser(String myUserId, String targetUserId) async {
    try {
      final authUserId = await _ensureValidAuth();
      if (authUserId == null || authUserId != myUserId) return false;

      await _db
          .child('Users/$myUserId/blocked_users/$targetUserId')
          .remove();

      unawaited(_db
          .child('blocked_by/$targetUserId/$myUserId')
          .remove()
          .catchError((_) {}));

      print('✅ Desbloqueado: $targetUserId');
      return true;
    } catch (e) {
      print('❌ unblockUser erro: $e');
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
      return (
        iBlockedThem: results[0].exists && _isTruthy(results[0].value),
        theyBlockedMe: results[1].exists && _isTruthy(results[1].value),
      );
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