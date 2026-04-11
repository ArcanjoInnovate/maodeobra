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

class UserLookupService {
  final FirebaseService _firebase = FirebaseService();
  
  // Cache para evitar múltiplas consultas
  final Map<String, UserData> _cache = {};

  // Singleton
  static final UserLookupService _instance = UserLookupService._internal();
  factory UserLookupService() => _instance;
  UserLookupService._internal();

  /// Busca dados do usuário (com cache)
  Future<UserData> getUserData(String userId) async {
    // Verifica cache
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final snapshot = await _firebase.database
          .ref('Users/$userId')
          .get();

      if (!snapshot.exists) {
        return UserData(
          name: 'Usuário',
          avatar: '',
          profession: 'Não definida',
        );
      }

      final userData = UserData.fromMap(
        snapshot.value as Map<dynamic, dynamic>
      );

      // Salva no cache
      _cache[userId] = userData;

      return userData;
    } catch (e) {
      print('Erro ao buscar usuário $userId: $e');
      return UserData(
        name: 'Usuário',
        avatar: '',
        profession: 'Não definida',
      );
    }
  }

  /// Stream de dados do usuário (tempo real)
  Stream<UserData> getUserDataStream(String userId) {
    return _firebase.database
        .ref('Users/$userId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) {
        return UserData(
          name: 'Usuário',
          avatar: '',
          profession: 'Não definida',
        );
      }

      final userData = UserData.fromMap(
        event.snapshot.value as Map<dynamic, dynamic>
      );

      // Atualiza cache
      _cache[userId] = userData;

      return userData;
    });
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