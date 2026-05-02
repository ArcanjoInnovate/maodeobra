import 'package:firebase_database/firebase_database.dart';

class UserService {
  final _databaseRef = FirebaseDatabase.instance.ref('Users');
  
  /// Carrega lista de bloqueados do Firebase
  Future<List<String>> fetchBlockedUsers(String myUserId) async {
    try {
      final snapshot = await _databaseRef.child('$myUserId/blocked_users').get();
      
      if (snapshot.exists && snapshot.value != null) {
        if (snapshot.value is List) {
          return List<String>.from(snapshot.value as List);
        } else if (snapshot.value is Map) {
          return (snapshot.value as Map)
              .values
              .map((e) => e.toString())
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Erro ao carregar bloqueados: $e');
      return [];
    }
  }
}