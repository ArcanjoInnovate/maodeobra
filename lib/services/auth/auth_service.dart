import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        await _saveFCMToken(user.uid); // ✅ SALVA TOKEN iOS!
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
        
        await _saveFCMToken(user.uid); // ✅ SALVA TOKEN iOS!
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
    // ✅ iOS OBRIGATÓRIO: pedir permissão antes de getToken()
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('📲 Status permissão notificação: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('⚠️ Usuário negou notificações — token não salvo');
      return;
    }

    // ✅ iOS também precisa do APNs token antes do FCM token
    // Aguarda um momento para o APNs inicializar
    if (Platform.isIOS) {
      await Future.delayed(const Duration(seconds: 1));
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      print('🍎 APNs token: ${apnsToken != null ? apnsToken.substring(0, 10) + "..." : "NULL"}');
      
      if (apnsToken == null) {
        print('⚠️ APNs token NULL — FCM não disponível ainda no iOS');
        return;
      }
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      print('📱 FCM Token: ${token.substring(0, 20)}...');

      await FirebaseDatabase.instance
          .ref('Users/$userId/fcmToken')
          .set(token);

      print('✅ FCM Token salvo para $userId');

      final service = NotificationService();
      await service.initialize(userId);
    } else {
      print('⚠️ FCM Token ainda NULL após APNs OK');
    }
  } catch (e) {
    print('❌ Erro ao salvar FCM token: $e');
  }
}

  // ============================================================
  // ✅ LOGOUT - REMOVE TOKEN
  // ============================================================
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // ✅ Remove FCM token
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