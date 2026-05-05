import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:dartobra_new/core/services/user_relationship_service.dart';

class BlockProvider extends ChangeNotifier {
  final _service = UserRelationShipService();

  Set<String> _blockedSet = {};
  bool _isLoading = false;
  String? _myUserId;

  StreamSubscription<DatabaseEvent>? _iBlockedSub;
  StreamSubscription<DatabaseEvent>? _blockedMeSub;

// ── Getters ───────────────────────────────

  bool get isLoading => _isLoading;
  Set<String> get blockedSet => Set.unmodifiable(_blockedSet);

  /// true se há qualquer bloqueio (eu bloqueei ou fui bloqueado)
  bool isBlocked(String userId) => _blockedSet.contains(userId);

  /// Filtra qualquer lista removendo usuários bloqueados
  List<T> filterBlocked<T>(List<T> items, String Function(T) getOwnerId) =>
      items.where((item) => !isBlocked(getOwnerId(item))).toList();

  // ── Init / Logout ─────────────────────────

  Future<void> init(String userId) async {
    if (_myUserId == userId && _blockedSet.isNotEmpty) {
      print('⚠️ [BlockProvider] Já inicializado para $userId');
      return;
    }
    
    _myUserId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      await _reload();
      _startListeners();
    } catch (e, stack) {
      print('❌ [BlockProvider] Erro no init: $e\n$stack');
      // ✅ Fallback: tentar novamente após 2s
      await Future.delayed(const Duration(seconds: 2));
      try {
        await _reload();
        _startListeners();
      } catch (e2) {
        print('❌ [BlockProvider] Fallback falhou: $e2');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void logout() {
    _cancelListeners();
    _blockedSet = {};
    _myUserId = null;
    notifyListeners();
  }

  // recarrega bloqueios do zero (usado após mudanças manuais, tipo bloqueio/desbloqueio)
  Future<void> reload() async {
    if (_myUserId == null) return;
    _isLoading = true;
    notifyListeners();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }
  // ── Ações (delegam ao service, atualizam local imediatamente) ──

  Future<bool> blockUser(String targetUserId) async {
    if (_myUserId == null) return false;

    final success = await _service.blockUser(_myUserId!, targetUserId);
    if (success) {
      _blockedSet = {..._blockedSet, targetUserId};
      notifyListeners();
    }
    return success;
  }

  Future<bool> unblockUser(String targetUserId) async {
    if (_myUserId == null) return false;

    final success = await _service.unblockUser(_myUserId!, targetUserId);
    if (success) {
      _blockedSet = _blockedSet.difference({targetUserId});
      notifyListeners();
    }
    return success;
  }

  // ── Internos ──────────────────────────────

  Future<void> _reload() async {
    if (_myUserId == null) return;
    final results = await Future.wait([
      _service.fetchUsersIBlocked(_myUserId!),
      _service.fetchUsersWhoBlockedMe(_myUserId!),
    ]);
    _blockedSet = {...results[0], ...results[1]};
  }

  void _startListeners() {
    _cancelListeners();
    if (_myUserId == null) return;

    _iBlockedSub = _service.watchIBlocked(_myUserId!).listen((_) async {
      await _reload();
      notifyListeners();
    });

    _blockedMeSub = _service.watchBlockedMe(_myUserId!).listen((_) async {
      await _reload();
      notifyListeners();
    });
  }

  void _cancelListeners() {
    _iBlockedSub?.cancel();
    _blockedMeSub?.cancel();
    _iBlockedSub = null;
    _blockedMeSub = null;
  }

  @override
  void dispose() {
    _cancelListeners();
    super.dispose();
  }
}