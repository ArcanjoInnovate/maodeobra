import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:dartobra_new/core/services/user_relationship_service.dart';

class BlockProvider extends ChangeNotifier {
  final _service = UserRelationShipService();

  Set<String> _blockedSet = {};
  bool _isLoading = false;
  bool _initialized = false; // ✅ flag real — evita reinit desnecessário
  String? _myUserId;
  String? _lastError;

  StreamSubscription<DatabaseEvent>? _iBlockedSub;
  StreamSubscription<DatabaseEvent>? _blockedMeSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized; // ✅ exposto para as telas
  Set<String> get blockedSet => Set.unmodifiable(_blockedSet);
  String? get lastError => _lastError;

  bool isBlocked(String userId) => _blockedSet.contains(userId);

  List<T> filterBlocked<T>(List<T> items, String Function(T) getOwnerId) =>
      items.where((item) => !isBlocked(getOwnerId(item))).toList();

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    // ✅ Se já inicializado com o mesmo usuário, não faz nada
    // Isso resolve o bug de bloquear o mesmo usuário duas vezes:
    // as telas chamavam init() de novo, limpando o _blockedSet interno
    if (_initialized && _myUserId == userId) {
      print('✅ BlockProvider já inicializado para $userId — ignorando');
      return;
    }

    print('🔄 BlockProvider.init: $userId');
    _myUserId = userId;
    _initialized = false;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _reload();
      _startListeners();
      _initialized = true;
      print('✅ BlockProvider pronto: ${_blockedSet.length} bloqueados');
    } catch (e, st) {
      print('❌ BlockProvider.init erro: $e\n$st');
      _lastError = 'Erro na inicialização: $e';
      // ✅ Mesmo com erro, marca como inicializado para não ficar em loop
      _initialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _cancelListeners();
    _blockedSet = {};
    _myUserId = null;
    _lastError = null;
    _initialized = false;
    notifyListeners();
  }

  Future<void> reload() async {
    if (_myUserId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _reload();
    } catch (e) {
      print('❌ reload erro: $e');
      _lastError = 'Erro ao recarregar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── blockUser ─────────────────────────────────────────────────────────────

  Future<bool> blockUser(String targetUserId) async {
    _lastError = null;

    // Garante que está inicializado
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

    // ✅ Verifica direto no Firebase — não confia só no set local
    // No iOS o set pode estar desatualizado se a conexão foi lenta
    print('🔍 Verificando $targetUserId no Firebase...');
    try {
      final rel = await _service.checkRelationship(_myUserId!, targetUserId);
      if (rel.iBlockedThem) {
        print('⚠️ Já bloqueado (Firebase confirmou)');
        _lastError = 'Usuário já bloqueado';
        // Sincroniza o set local que estava desatualizado
        if (!_blockedSet.contains(targetUserId)) {
          _blockedSet = {..._blockedSet, targetUserId};
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      print('⚠️ Erro ao verificar relação: $e — prosseguindo mesmo assim');
    }

    try {
      print('🚫 Bloqueando $targetUserId...');
      final success = await _service.blockUser(_myUserId!, targetUserId);

      if (!success) {
        _lastError = 'Falha ao bloquear no Firebase';
        notifyListeners();
        return false;
      }

      // Atualiza local imediatamente para UI responder rápido
      _blockedSet = {..._blockedSet, targetUserId};
      notifyListeners();

      // Recarrega do Firebase para garantir consistência
      await Future.delayed(const Duration(milliseconds: 300));
      await _reload();
      notifyListeners();

      print('✅ Bloqueado: $targetUserId');
      return true;
    } catch (e, st) {
      print('❌ Exceção ao bloquear: $e\n$st');
      _lastError = 'Exceção: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    if (_myUserId == null) return false;
    try {
      final success = await _service.unblockUser(_myUserId!, targetUserId);
      if (success) {
        _blockedSet = _blockedSet.difference({targetUserId});
        await Future.delayed(const Duration(milliseconds: 300));
        await _reload();
        notifyListeners();
      }
      return success;
    } catch (e, st) {
      print('❌ Exceção ao desbloquear: $e\n$st');
      return false;
    }
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  Future<void> _reload() async {
    if (_myUserId == null) return;
    final results = await Future.wait([
      _service.fetchUsersIBlocked(_myUserId!),
      _service.fetchUsersWhoBlockedMe(_myUserId!),
    ]);
    _blockedSet = {...results[0], ...results[1]};
    print('📊 _blockedSet: ${_blockedSet.length} usuários');
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