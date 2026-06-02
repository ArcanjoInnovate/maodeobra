import 'package:flutter/foundation.dart';
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
      debugPrint('❌ _ensureValidAuth erro: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VERIFICAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isUserBlocked(String myUserId, String targetUserId) async {
    try {
      final snap =
          await _db.child('Users/$myUserId/blocked_users/$targetUserId').get();
      return snap.exists && _isTruthy(snap.value);
    } catch (e) {
      debugPrint('❌ isUserBlocked erro: $e');
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
      debugPrint('\n═══════════════════════════════════════════════');
      debugPrint('🔄 INICIANDO BLOQUEIO');
      debugPrint('   De: $myUserId → Para: $targetUserId');
      debugPrint('═══════════════════════════════════════════════');

      // PASSO 1: Autenticação
      final authUserId = await _ensureValidAuth();
      if (authUserId == null) {
        debugPrint('❌ FALHA: Auth inválido');
        return false;
      }
      if (authUserId != myUserId) {
        debugPrint('❌ FALHA: UID não confere');
        return false;
      }

      // PASSO 2: Verifica se já está bloqueado (usa .get() aqui porque não é crítico)
      final alreadySnap =
          await _db.child('Users/$myUserId/blocked_users/$targetUserId').get();
      if (alreadySnap.exists && _isTruthy(alreadySnap.value)) {
        debugPrint('⚠️ Já bloqueado — abortando');
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
            debugPrint('✅ Listener confirmou escrita do servidor!');
            completer.complete(true);
            subscription.cancel();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            debugPrint('❌ Erro no listener: $error');
            completer.complete(false);
            subscription.cancel();
          }
        },
      );

      // PASSO 4: Escreve no Firebase
      debugPrint('📝 Executando set()...');
      try {
        await ref.set(true).timeout(const Duration(seconds: 10));
        debugPrint('✅ set() concluído');
      } on TimeoutException {
        debugPrint('⏱️ Timeout no set()');
        subscription.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return false;
      } catch (e) {
        debugPrint('❌ Erro no set(): $e');
        subscription.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }

      // PASSO 5: Aguarda confirmação do listener com timeout
      // ✅ subscription SEMPRE cancelado ao sair deste bloco
      bool confirmed = false;
      try {
        confirmed = await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('⏱️ Timeout aguardando listener');
            return false;
          },
        );
      } finally {
        subscription.cancel();
      }

      if (!confirmed) {
        debugPrint('❌ FALHA: Escrita não confirmada pelo servidor');
        return false;
      }

      // PASSO 6: blocked_by em paralelo (não crítico)
      unawaited(
        _db.child('blocked_by/$targetUserId/$myUserId').set(true).catchError(
          (e) {
            debugPrint('⚠️ blocked_by falhou (não crítico): $e');
          },
        ),
      );

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('✅ BLOQUEIO CONCLUÍDO COM SUCESSO');
      debugPrint('═══════════════════════════════════════════════\n');
      return true;
    } catch (e, st) {
      debugPrint('❌ EXCEÇÃO em blockUser: $e\n$st');
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

      await _db.child('Users/$myUserId/blocked_users/$targetUserId').remove();

      unawaited(_db
          .child('blocked_by/$targetUserId/$myUserId')
          .remove()
          .catchError((_) {}));

      debugPrint('✅ Desbloqueado: $targetUserId');
      return true;
    } catch (e) {
      debugPrint('❌ unblockUser erro: $e');
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
      debugPrint('❌ fetchAllBlockedUsers: $e');
      return {};
    }
  }

  Future<Set<String>> fetchUsersIBlocked(String myUserId) async {
    try {
      final ref = _db.child('Users/$myUserId/blocked_users');
      // Força sincronização com servidor antes de ler
      ref.keepSynced(true);
      final snap = await ref.get();
      ref.keepSynced(false);
      if (!snap.exists || snap.value == null) return {};
      final value = snap.value;
      if (value is! Map) return {};
      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      debugPrint('❌ fetchUsersIBlocked: $e');
      return {};
    }
  }

  Future<Set<String>> fetchUsersWhoBlockedMe(String myUserId) async {
    try {
      final ref = _db.child('blocked_by/$myUserId');
      ref.keepSynced(true);
      final snap = await ref.get();
      ref.keepSynced(false);
      if (!snap.exists || snap.value == null) return {};
      final value = snap.value;
      if (value is! Map) return {};
      return value.entries
          .where((e) => _isTruthy(e.value))
          .map((e) => e.key.toString())
          .toSet();
    } catch (e) {
      debugPrint('❌ fetchUsersWhoBlockedMe: $e');
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
      debugPrint('❌ checkRelationship: $e');
      return (iBlockedThem: false, theyBlockedMe: false);
    }
  }

  Stream<DatabaseEvent> watchIBlocked(String myUserId) =>
      _db.child('Users/$myUserId/blocked_users').onValue;

  Stream<DatabaseEvent> watchBlockedMe(String myUserId) =>
      _db.child('blocked_by/$myUserId').onValue;
}