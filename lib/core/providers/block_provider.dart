import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:dartobra_new/core/services/user_relationship_service.dart';

class BlockProvider extends ChangeNotifier {
  final _service = UserRelationShipService();

  Set<String> _blockedSet = {};
  bool _isLoading = false;
  bool _initialized = false;
  bool _initSucceeded = false;
  String? _myUserId;
  String? _lastError;

  StreamSubscription<DatabaseEvent>? _iBlockedSub;
  StreamSubscription<DatabaseEvent>? _blockedMeSub;

  // ── Callbacks de notificação ──────────────────────────────
  // Controllers (FeedController, SearchController) registram aqui
  // para serem notificados imediatamente ao bloquear/desbloquear.

  final List<void Function(String userId)> _onBlockCallbacks = [];
  final List<void Function(String userId)> _onUnblockCallbacks = [];

  void registerOnBlock(void Function(String userId) callback) {
    if (!_onBlockCallbacks.contains(callback)) {
      _onBlockCallbacks.add(callback);
    }
  }

  void registerOnUnblock(void Function(String userId) callback) {
    if (!_onUnblockCallbacks.contains(callback)) {
      _onUnblockCallbacks.add(callback);
    }
  }

  void unregisterOnBlock(void Function(String userId) callback) {
    _onBlockCallbacks.remove(callback);
  }

  void unregisterOnUnblock(void Function(String userId) callback) {
    _onUnblockCallbacks.remove(callback);
  }

  void _notifyBlock(String userId) {
    for (final cb in List.of(_onBlockCallbacks)) {
      cb(userId);
    }
  }

  void _notifyUnblock(String userId) {
    for (final cb in List.of(_onUnblockCallbacks)) {
      cb(userId);
    }
  }

  // ── Getters ───────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  bool get initSucceeded => _initSucceeded;
  Set<String> get blockedSet => Set.unmodifiable(_blockedSet);
  String? get lastError => _lastError;

  bool isBlocked(String userId) => _blockedSet.contains(userId);

  List<T> filterBlocked<T>(List<T> items, String Function(T) getOwnerId) =>
      items.where((item) => !isBlocked(getOwnerId(item))).toList();

  // ── Init ──────────────────────────────────────────────────

  Future<void> init(String userId) async {
    if (_initialized && _initSucceeded && _myUserId == userId) {
      print('✅ BlockProvider já inicializado com sucesso para $userId');
      return;
    }

    if (_isLoading && _myUserId == userId) {
      print('⏳ BlockProvider já carregando para $userId');
      return;
    }

    print('🔄 BlockProvider.init: $userId');
    _myUserId = userId;
    _initialized = false;
    _initSucceeded = false;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _reload();
      _startListeners();
      _initialized = true;
      _initSucceeded = true;
      print('✅ BlockProvider pronto: ${_blockedSet.length} bloqueados');
    } catch (e, st) {
      print('❌ BlockProvider.init erro: $e\n$st');
      _lastError = 'Erro na inicialização: $e';
      _initialized = true;
      _initSucceeded = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _cancelListeners();
    _onBlockCallbacks.clear();
    _onUnblockCallbacks.clear();
    _blockedSet = {};
    _myUserId = null;
    _lastError = null;
    _initialized = false;
    _initSucceeded = false;
    notifyListeners();
  }

  Future<void> reload() async {
    if (_myUserId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _reload();
      _initSucceeded = true;
    } catch (e) {
      print('❌ reload erro: $e');
      _lastError = 'Erro ao recarregar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── blockUser ─────────────────────────────────────────────

  Future<bool> blockUser(String targetUserId) async {
    _lastError = null;

    if (!_initialized || _myUserId == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _lastError = 'Usuário não autenticado';
        notifyListeners();
        return false;
      }
      await init(uid);
    }

    if (_myUserId == null) {
      _lastError = 'Falha ao inicializar provider';
      notifyListeners();
      return false;
    }

    print('🔍 Verificando se $targetUserId já está bloqueado...');
    final jaExiste = await _service.isUserBlocked(_myUserId!, targetUserId);
    if (jaExiste) {
      print('⚠️ Já bloqueado');
      _lastError = 'Usuário já bloqueado';
      if (!_blockedSet.contains(targetUserId)) {
        _blockedSet = {..._blockedSet, targetUserId};
        notifyListeners();
      }
      return false;
    }

    try {
      final success = await _service.blockUser(_myUserId!, targetUserId);

      if (!success) {
        _lastError =
            'Falha ao bloquear. Verifique sua conexão e tente novamente.';
        notifyListeners();
        return false;
      }

      // Atualiza local imediatamente
      _blockedSet = {..._blockedSet, targetUserId};
      notifyListeners();

      // Notifica todos os controllers registrados
      _notifyBlock(targetUserId);

      // Sincroniza do servidor em background
      Future.delayed(const Duration(milliseconds: 500), () async {
        await _reload();
        notifyListeners();
      });

      print('✅ Bloqueado com sucesso: $targetUserId');
      return true;
    } catch (e, st) {
      print('❌ Exceção ao bloquear: $e\n$st');
      _lastError = 'Exceção: $e';
      notifyListeners();
      return false;
    }
  }

  // ── unblockUser ───────────────────────────────────────────

  Future<bool> unblockUser(String targetUserId) async {
    if (_myUserId == null) return false;
    try {
      final success = await _service.unblockUser(_myUserId!, targetUserId);
      if (success) {
        _blockedSet = _blockedSet.difference({targetUserId});

        // Notifica todos os controllers registrados
        _notifyUnblock(targetUserId);

        await Future.delayed(const Duration(milliseconds: 400));
        await _reload();
        notifyListeners();
      }
      return success;
    } catch (e, st) {
      print('❌ unblockUser: $e\n$st');
      return false;
    }
  }

  // ── Internos ──────────────────────────────────────────────

  Future<void> _reload() async {
    if (_myUserId == null) return;
    final results = await Future.wait([
      _service.fetchUsersIBlocked(_myUserId!),
      _service.fetchUsersWhoBlockedMe(_myUserId!),
    ]);
    _blockedSet = {...results[0], ...results[1]};
    print('📊 _blockedSet atualizado: ${_blockedSet.length} usuários');
  }

  void _startListeners() {
    _cancelListeners();
    if (_myUserId == null) return;

    _iBlockedSub = _service.watchIBlocked(_myUserId!).listen(
      (_) async {
        await _reload();
        notifyListeners();
      },
      onError: (e) => print('❌ Stream iBlocked: $e'),
    );

    _blockedMeSub = _service.watchBlockedMe(_myUserId!).listen(
      (_) async {
        await _reload();
        notifyListeners();
      },
      onError: (e) => print('❌ Stream blockedMe: $e'),
    );
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