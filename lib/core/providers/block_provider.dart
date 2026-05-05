import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:dartobra_new/core/services/user_relationship_service.dart';

class BlockProvider extends ChangeNotifier {
  final _service = UserRelationShipService();

  Set<String> _blockedSet = {};
  bool _isLoading = false;
  String? _myUserId;
  String? _lastError;
  int _initAttempts = 0;
  static const int _maxInitAttempts = 3;

  StreamSubscription<DatabaseEvent>? _iBlockedSub;
  StreamSubscription<DatabaseEvent>? _blockedMeSub;

  // ── Getters ───────────────────────────────

  bool get isLoading => _isLoading;
  Set<String> get blockedSet => Set.unmodifiable(_blockedSet);
  String? get lastError => _lastError;

  /// true se há qualquer bloqueio (eu bloqueei ou fui bloqueado)
  bool isBlocked(String userId) => _blockedSet.contains(userId);

  /// Filtra qualquer lista removendo usuários bloqueados
  List<T> filterBlocked<T>(List<T> items, String Function(T) getOwnerId) =>
      items.where((item) => !isBlocked(getOwnerId(item))).toList();

  // ── Init / Logout ─────────────────────────

  Future<void> init(String userId) async {
    print('🔄 BlockProvider.init chamado com userId: $userId');
    
    if (_myUserId == userId && _blockedSet.isNotEmpty) {
      print('✅ BlockProvider já inicializado com este userId: $_myUserId');
      return;
    }

    _myUserId = userId;
    _initAttempts++;

    if (_initAttempts > _maxInitAttempts) {
      print('❌ Máximo de tentativas de inicialização atingido: $_maxInitAttempts');
      _lastError = 'Falha ao inicializar após $_maxInitAttempts tentativas';
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      print('📥 Carregando lista de bloqueios...');
      await _reload();
      
      print('👂 Iniciando listeners em tempo real...');
      _startListeners();

      _initAttempts = 0; // Reset counter on success
      print('✅ BlockProvider inicializado com sucesso: ${_blockedSet.length} bloqueios');
    } catch (e, stackTrace) {
      print('❌ Erro ao inicializar BlockProvider: $e');
      print('Stack trace: $stackTrace');
      _lastError = 'Erro na inicialização: $e';
      
      // Retry automático se ainda tiver tentativas
      if (_initAttempts < _maxInitAttempts) {
        print('🔄 Tentando novamente em 2 segundos... (tentativa $_initAttempts/$_maxInitAttempts)');
        await Future.delayed(const Duration(seconds: 2));
        return init(userId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    print('👋 BlockProvider logout');
    _cancelListeners();
    _blockedSet = {};
    _myUserId = null;
    _lastError = null;
    _initAttempts = 0;
    notifyListeners();
  }

  // recarrega bloqueios do zero (usado após mudanças manuais, tipo bloqueio/desbloqueio)
  Future<void> reload() async {
    if (_myUserId == null) {
      print('⚠️ reload: userId nulo');
      return;
    }
    
    print('🔄 Recarregando bloqueios...');
    _isLoading = true;
    notifyListeners();
    
    try {
      await _reload();
      print('✅ Bloqueios recarregados: ${_blockedSet.length} usuários');
    } catch (e, stackTrace) {
      print('❌ Erro ao recarregar bloqueios: $e');
      print('Stack trace: $stackTrace');
      _lastError = 'Erro ao recarregar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Ações (delegam ao service, atualizam local imediatamente) ──

  Future<bool> blockUser(String targetUserId) async {
    print('🚫 Tentando bloquear usuário: $targetUserId');
    _lastError = null;

    // ✅ VALIDAÇÃO: Garante que o provider está inicializado
    if (_myUserId == null) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ Usuário não autenticado');
        _lastError = 'Usuário não autenticado';
        notifyListeners();
        return false;
      }
      
      print('⚠️ BlockProvider não inicializado, inicializando agora...');
      await init(currentUser.uid);
    }

    if (_myUserId == null) {
      print('❌ Falha ao inicializar BlockProvider');
      _lastError = 'Falha ao inicializar provider';
      notifyListeners();
      return false;
    }

    // ✅ VALIDAÇÃO: Verifica se já está bloqueado localmente
    if (_blockedSet.contains(targetUserId)) {
      print('⚠️ Usuário já está na lista de bloqueados localmente');
      _lastError = 'Usuário já bloqueado';
      notifyListeners();
      return false;
    }

    try {
      print('📡 Enviando requisição de bloqueio ao Firebase...');
      final success = await _service.blockUser(_myUserId!, targetUserId);
      
      if (!success) {
        print('❌ Service retornou falha ao bloquear');
        _lastError = 'Falha ao bloquear no Firebase';
        notifyListeners();
        return false;
      }

      // ✅ Atualiza localmente SOMENTE se o service retornou sucesso
      print('✅ Bloqueio bem-sucedido, atualizando localmente...');
      _blockedSet = {..._blockedSet, targetUserId};
      
      // ✅ Aguarda um momento e recarrega para garantir sincronização
      await Future.delayed(const Duration(milliseconds: 500));
      await _reload();
      
      notifyListeners();
      print('✅ Usuário bloqueado com sucesso: $targetUserId');
      return true;
    } catch (e, stackTrace) {
      print('❌ Exceção ao bloquear usuário: $e');
      print('Stack trace: $stackTrace');
      _lastError = 'Exceção: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    print('✅ Tentando desbloquear usuário: $targetUserId');
    
    if (_myUserId == null) {
      print('❌ userId nulo ao desbloquear');
      return false;
    }

    try {
      final success = await _service.unblockUser(_myUserId!, targetUserId);
      
      if (success) {
        print('✅ Desbloqueio bem-sucedido, atualizando localmente...');
        _blockedSet = _blockedSet.difference({targetUserId});
        
        // ✅ Aguarda um momento e recarrega para garantir sincronização
        await Future.delayed(const Duration(milliseconds: 500));
        await _reload();
        
        notifyListeners();
        print('✅ Usuário desbloqueado com sucesso: $targetUserId');
      } else {
        print('❌ Falha ao desbloquear no service');
      }
      
      return success;
    } catch (e, stackTrace) {
      print('❌ Exceção ao desbloquear usuário: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ── Internos ──────────────────────────────

  Future<void> _reload() async {
    if (_myUserId == null) {
      print('⚠️ _reload: userId nulo');
      return;
    }

    try {
      print('📥 Buscando bloqueios do Firebase...');
      final results = await Future.wait([
        _service.fetchUsersIBlocked(_myUserId!),
        _service.fetchUsersWhoBlockedMe(_myUserId!),
      ]);
      
      final iBlocked = results[0];
      final blockedMe = results[1];
      
      _blockedSet = {...iBlocked, ...blockedMe};
      
      print('📊 Bloqueios carregados:');
      print('   - Eu bloqueei: ${iBlocked.length}');
      print('   - Me bloquearam: ${blockedMe.length}');
      print('   - Total: ${_blockedSet.length}');
    } catch (e, stackTrace) {
      print('❌ Erro ao recarregar bloqueios: $e');
      print('Stack trace: $stackTrace');
      throw e; // Re-throw para ser capturado pelo caller
    }
  }

  void _startListeners() {
    print('👂 Iniciando listeners de bloqueio...');
    _cancelListeners();
    
    if (_myUserId == null) {
      print('⚠️ _startListeners: userId nulo');
      return;
    }

    _iBlockedSub = _service.watchIBlocked(_myUserId!).listen(
      (event) async {
        print('🔔 Listener iBlocked disparado');
        try {
          await _reload();
          notifyListeners();
        } catch (e) {
          print('❌ Erro no listener iBlocked: $e');
        }
      },
      onError: (error) {
        print('❌ Erro no stream iBlocked: $error');
      },
    );

    _blockedMeSub = _service.watchBlockedMe(_myUserId!).listen(
      (event) async {
        print('🔔 Listener blockedMe disparado');
        try {
          await _reload();
          notifyListeners();
        } catch (e) {
          print('❌ Erro no listener blockedMe: $e');
        }
      },
      onError: (error) {
        print('❌ Erro no stream blockedMe: $error');
      },
    );

    print('✅ Listeners iniciados com sucesso');
  }

  void _cancelListeners() {
    print('🛑 Cancelando listeners...');
    _iBlockedSub?.cancel();
    _blockedMeSub?.cancel();
    _iBlockedSub = null;
    _blockedMeSub = null;
  }

  @override
  void dispose() {
    print('🗑️ BlockProvider dispose');
    _cancelListeners();
    super.dispose();
  }
}