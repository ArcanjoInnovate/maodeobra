import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/models/user_model.dart';

class SuspensionController {
  final String localId;
  final UserRepository _repo = UserRepository();

  SuspensionController({required this.localId});

  /// Remove a suspensão do Firebase e retorna o [UserModel] atualizado.
  /// Retorna null se algo falhar.
  Future<UserModel?> clearSuspension() async {
    final cleared = await _repo.clearSuspension(localId);
    if (!cleared) return null;
    return _repo.fetchUser(localId);
  }
}
