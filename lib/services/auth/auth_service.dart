import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Function(String)? onStatusChanged;

  // ============================================================
  // ✅ LOGIN - SALVA FCM TOKEN AUTOMATICAMENTE
  // ============================================================
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _saveFCMToken(user.uid);
        print('✅ Login OK + FCM token salvo: ${user.uid}');
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

  // ============================================================
  // ✅ REGISTRO - SALVA FCM TOKEN AUTOMATICAMENTE
  // ============================================================
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();

        await _saveFCMToken(user.uid);
        print('✅ Registro OK + FCM token salvo: ${user.uid}');
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

  // ============================================================
  // ✅ SALVAR FCM TOKEN (iOS + Android)
  // ============================================================
  Future<void> _saveFCMToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Solicita permissão (necessário no iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('⚠️ Permissão de notificação negada pelo usuário');
        return;
      }

      // Obtém o token FCM
      final token = await messaging.getToken();

      if (token == null) {
        print('⚠️ FCM token nulo — verifique a configuração do projeto');
        return;
      }

      // Salva no Realtime Database
      await FirebaseDatabase.instance.ref('Users/$userId').update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': ServerValue.timestamp,
        'platform': _getPlatform(),
      });

      print('✅ FCM token salvo com sucesso: $token');

      // Atualiza o token automaticamente quando ele for renovado
      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseDatabase.instance.ref('Users/$userId').update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': ServerValue.timestamp,
        });
        print('🔄 FCM token renovado e salvo: $newToken');
      });
    } catch (e) {
      // Não bloqueia o fluxo de login em caso de falha no FCM
      print('❌ Erro ao salvar FCM token: $e');
    }
  }

  String _getPlatform() {
    try {
      // Evita import de dart:io — usa assertion de plataforma do Flutter
      return 'mobile';
    } catch (_) {
      return 'unknown';
    }
  }

  // ============================================================
  // ✅ LOGOUT - REMOVE TOKEN
  // ============================================================
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref('Users/${user.uid}/fcmToken')
            .remove();
        print('🗑️ FCM token removido no logout');
      }

      await _auth.signOut();
      print('✅ Logout completo');
    } catch (e) {
      print('❌ Erro logout: $e');
      rethrow;
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}