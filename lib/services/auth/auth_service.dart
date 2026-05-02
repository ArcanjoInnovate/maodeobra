import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Function(String)? onStatusChanged;

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _saveFCMToken(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') throw 'Usuário não encontrado';
      if (e.code == 'wrong-password') throw 'Senha incorreta';
      throw 'Erro de login: ${e.message}';
    } catch (e) {
      throw 'Erro inesperado: $e';
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();
        await _saveFCMToken(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw 'Senha muito fraca';
      if (e.code == 'email-already-in-use') throw 'Email já em uso';
      if (e.code == 'invalid-email') throw 'Email inválido';
      throw 'Erro ao criar conta: ${e.message}';
    } catch (e) {
      throw 'Erro inesperado: $e';
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref('Users/${user.uid}/fcmToken')
            .remove();
      }
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        onStatusChanged?.call('❌ Notificação negada');
        return;
      }

      onStatusChanged?.call('⏳ Buscando FCM token...');
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        onStatusChanged?.call('✅ FCM: ${token.substring(0, 15)}...');
        await FirebaseDatabase.instance
            .ref('Users/$userId/fcmToken')
            .set(token);
      } else {
        onStatusChanged?.call('❌ FCM token NULL');
      }
    } catch (e) {
      onStatusChanged?.call('❌ Erro: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}