import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Criar conta com email e senha
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Criar usuário
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Atualizar nome do usuário
      await credential.user?.updateDisplayName(name);
      
      // Enviar email de verificação (opcional)
      await credential.user?.sendEmailVerification();

      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Tratar erros específicos
      if (e.code == 'weak-password') {
        throw 'A senha é muito fraca';
      } else if (e.code == 'email-already-in-use') {
        throw 'Este email já está em uso';
      } else if (e.code == 'invalid-email') {
        throw 'Email inválido';
      }
      throw 'Erro ao criar conta: ${e.message}';
    } catch (e) {
      throw 'Erro inesperado: $e';
    }
  }
}
