import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/models/user_model.dart';

class WarningController {
  final String localId;
  final UserRepository _repo = UserRepository();

  WarningController({required this.localId});

  /// Remove a advertência do Firebase e retorna o [UserModel] atualizado.
  /// Retorna null se algo falhar.
  Future<UserModel?> acknowledgeWarning() async {
    final cleared = await _repo.clearWarning(localId);
    if (!cleared) return null;
    return _repo.fetchUser(localId);
  }
}
