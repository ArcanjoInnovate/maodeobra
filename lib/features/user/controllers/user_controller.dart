import 'package:flutter/foundation.dart';
import 'package:dartobra_new/features/user/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserController {
  final UserService _userService = UserService();
  
  // Cache local
  List<String> _blockedUsers = [];
  bool _isLoaded = false;
  
  /// Carrega bloqueados UMA VEZ (chame no login/splash)
  Future<void> loadBlockedUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    _blockedUsers = await _userService.fetchBlockedUsers(currentUserId);
    _isLoaded = true;
    debugPrint('${_blockedUsers.length} usuários bloqueados carregados');
  }
  
  /// Retorna lista de bloqueados (0 leituras)
  List<String> getBlockedUsers() {
    return _blockedUsers;
  }
  
  /// Atualiza cache após bloquear
  void addBlockedUser(String userId) {
    if (!_blockedUsers.contains(userId)) {
      _blockedUsers.add(userId);
    }
  }
  
  /// Atualiza cache após desbloquear
  void removeBlockedUser(String userId) {
    _blockedUsers.remove(userId);
  }
  
  /// Limpa cache (logout)
  void clearCache() {
    _blockedUsers.clear();
    _isLoaded = false;
  }
}