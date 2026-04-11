import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/models/user_model.dart';

class UserRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Busca o usuário uma vez e retorna [UserModel] ou null em caso de erro.
  Future<UserModel?> fetchUser(String localId) async {
    try {
      final snapshot = await _db.child('Users/$localId').get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return UserModel.fromMap(
        localId,
        snapshot.value as Map<dynamic, dynamic>,
      );
    } catch (e) {
      print('❌ UserRepository.fetchUser erro: $e');
      return null;
    }
  }

  /// Stream contínuo do usuário. Ideal para HomeScreen.
  Stream<UserModel?> streamUser(String localId) {
    return _db.child('Users/$localId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return UserModel.fromMap(
        localId,
        event.snapshot.value as Map<dynamic, dynamic>,
      );
    });
  }

  /// Limpa o nó [warning] do usuário.
  Future<bool> clearWarning(String localId) async {
    try {
      await _db.child('Users/$localId').update({
        'warning': {
          'archive_id': '',
          'article': '',
          'data': '',
          'description': '',
          'motive': '',
          'type': '',
        },
      });
      print('✅ Advertência removida: $localId');
      return true;
    } catch (e) {
      print('❌ clearWarning erro: $e');
      return false;
    }
  }

  /// Limpa o nó [suspension] do usuário.
  Future<bool> clearSuspension(String localId) async {
    try {
      await _db.child('Users/$localId').update({
        'suspension': {
          'archive_id': '',
          'article': '',
          'data': '',
          'description': '',
          'duration_days': '',
          'end': '',
          'init': '',
          'motive': '',
        },
      });
      print('✅ Suspensão removida: $localId');
      return true;
    } catch (e) {
      print('❌ clearSuspension erro: $e');
      return false;
    }
  }
}
