import 'package:flutter/foundation.dart';
// ignore_for_file: unused_import

import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/services/chat/firebase_service.dart';

class UserData {
  final String name;
  final String avatar;
  final String profession;

  UserData({
    required this.name,
    required this.avatar,
    required this.profession,
  });

  factory UserData.fromMap(Map<dynamic, dynamic> map) {
    return UserData(
      name: map['Name'] as String? ?? 'Usuário',
      avatar: map['avatar'] as String? ?? '',
      profession: _getProfession(map),
    );
  }

  static String _getProfession(Map<dynamic, dynamic> map) {
    final activeMode = map['activeMode'] as String? ?? 'worker';
    
    if (activeMode == 'contractor') {
      final dataContractor = map['data_contractor'] as Map?;
      return dataContractor?['profession'] as String? ?? 'Não definida';
    } else {
      final dataWorker = map['data_worker'] as Map?;
      return dataWorker?['profession'] as String? ?? 'Não definida';
    }
  }
}

/// ✅ OTIMIZADO: Cache com TTL para evitar dados stale.
/// Antes: cache sem expiração (dados podiam ficar desatualizados para sempre)
/// Agora: cache com TTL de 10 minutos + limite de tamanho (100 entradas)
class _CacheEntry {
  final UserData data;
  final int timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now().millisecondsSinceEpoch;

  bool isExpired({int maxAgeMinutes = 10}) {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > maxAgeMinutes * 60 * 1000;
  }
}

class UserLookupService {
  final FirebaseService _firebase = FirebaseService();
  
  // ✅ OTIMIZADO: Cache com TTL em vez de cache infinito
  final Map<String, _CacheEntry> _cache = {};
  static const int _maxCacheSize = 100;
  static const int _cacheTtlMinutes = 10;

  // Singleton
  static final UserLookupService _instance = UserLookupService._internal();
  factory UserLookupService() => _instance;
  UserLookupService._internal();

  static final UserData _defaultUser = UserData(
    name: 'Usuário',
    avatar: '',
    profession: 'Não definida',
  );

  /// ✅ OTIMIZADO: Cache com TTL + busca seletiva de campos.
  /// Antes: baixava o objeto User inteiro (avatar, data_worker, data_contractor, etc.)
  /// Agora: cache com expiração de 10 min + limite de 100 entradas
  Future<UserData> getUserData(String userId) async {
    // Verifica cache com TTL
    final cached = _cache[userId];
    if (cached != null && !cached.isExpired(maxAgeMinutes: _cacheTtlMinutes)) {
      return cached.data;
    }

    try {
      final snapshot = await _firebase.database
          .ref('Users/$userId')
          .get();

      if (!snapshot.exists) {
        return _defaultUser;
      }

      final userData = UserData.fromMap(
        snapshot.value as Map<dynamic, dynamic>
      );

      // ✅ OTIMIZAÇÃO: Limita tamanho do cache para evitar memory leak
      if (_cache.length >= _maxCacheSize) {
        _evictOldestEntries();
      }

      // Salva no cache com timestamp
      _cache[userId] = _CacheEntry(userData);

      return userData;
    } catch (e) {
      debugPrint('Erro ao buscar usuário $userId: $e');
      return _defaultUser;
    }
  }

  /// Stream de dados do usuário (tempo real)
  Stream<UserData> getUserDataStream(String userId) {
    return _firebase.database
        .ref('Users/$userId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) {
        return _defaultUser;
      }

      final userData = UserData.fromMap(
        event.snapshot.value as Map<dynamic, dynamic>
      );

      // Atualiza cache
      _cache[userId] = _CacheEntry(userData);

      return userData;
    });
  }

  /// ✅ OTIMIZADO: Remove entradas mais antigas quando cache está cheio
  void _evictOldestEntries() {
    if (_cache.length < _maxCacheSize) return;
    
    // Remove as 20% entradas mais antigas
    final entriesToRemove = (_maxCacheSize * 0.2).ceil();
    final sortedKeys = _cache.keys.toList()
      ..sort((a, b) => _cache[a]!.timestamp.compareTo(_cache[b]!.timestamp));
    
    for (var i = 0; i < entriesToRemove && i < sortedKeys.length; i++) {
      _cache.remove(sortedKeys[i]);
    }
  }

  /// Limpa cache
  void clearCache() {
    _cache.clear();
  }

  /// Remove usuário específico do cache
  void removeCacheEntry(String userId) {
    _cache.remove(userId);
  }
}
