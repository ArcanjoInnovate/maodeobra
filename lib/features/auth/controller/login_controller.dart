import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/models/user_model.dart';

import 'package:dartobra_new/screens/admin/ban/ban_screen.dart';
import 'package:dartobra_new/screens/admin/suspension/suspension_screen.dart';
import 'package:dartobra_new/screens/admin/warning/warning_screen.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class LoginController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _repo = UserRepository();

  void Function(String message)? onStatusChanged;

  // ── Salvar codigo fcm ──────────────────────────────────────────────────────
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
        await FirebaseDatabase.instance.ref('Users/$userId/fcmToken').set(token);
      } else {
        onStatusChanged?.call('❌ FCM token NULL');
      }
    } catch (e) {
      onStatusChanged?.call('❌ Erro: $e');
    }
  }
  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Iniciando login para: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _saveFCMToken(user.uid);
        debugPrint('✅ Login OK + FCM token salvo: ${user.uid}');
      }
      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 FirebaseAuthException - Código: ${e.code}');

      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return {
          'success': false,
          'errorType': 'credentials',
          'message':
              'Email ou senha incorretos. Verifique suas credenciais e tente novamente.',
        };
      } else if (e.code == 'invalid-email') {
        return {
          'success': false,
          'errorType': 'credentials',
          'message': 'Formato de email inválido.',
        };
      } else if (e.code == 'user-disabled') {
        return {
          'success': false,
          'errorType': 'other',
          'message':
              'Esta conta foi desabilitada. Entre em contato com o suporte.',
        };
      } else if (e.code == 'too-many-requests') {
        return {
          'success': false,
          'errorType': 'other',
          'message':
              'Muitas tentativas de login. Aguarde alguns minutos antes de tentar novamente.',
        };
      } else if (e.code == 'network-request-failed') {
        return {
          'success': false,
          'errorType': 'network',
          'message':
              'Erro de conexão. Verifique sua internet e tente novamente.',
        };
      }

      return {
        'success': false,
        'errorType': 'other',
        'message': 'Erro ao fazer login. Tente novamente em instantes.',
      };
    } catch (e) {
      debugPrint('❌ Erro inesperado: $e');
      return {
        'success': false,
        'errorType': 'other',
        'message': 'Erro inesperado. Tente novamente.',
      };
    }
  }

  Future<void> signOut() async => _auth.signOut();

  // ── Busca dados e navega ───────────────────────────────────────────────────

  /// Busca o [UserModel] do Firebase e chama [navigateToNextScreen].
  Future<void> loadUserAndNavigate(
    BuildContext context,
    String localId,
  ) async {
    final user = await _repo.fetchUser(localId);

    if (user == null) {
      debugPrint('⚠️ Dados do usuário não encontrados para $localId');
      return;
    }

    if (!context.mounted) return;
   
    await navigateToNextScreen(context, user);
  }

  /// Decide para qual tela navegar com base no estado do [UserModel].
  Future<void> navigateToNextScreen(
    BuildContext context,
    UserModel user,
  ) async {
    // 1 – Banido
    if (user.isBanned) {
      debugPrint('🚫 Usuário banido');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BanScreen(
            occurrenceDate: user.ban?['data']?.toString() ?? '',
            reason: user.ban?['motive']?.toString() ?? '',
            description: user.ban?['description']?.toString() ?? '',
          ),
        ),
      );
      return;
    }

    // 2 – Suspenso
    if (user.isSuspended) {
      debugPrint('⏸️ Usuário suspenso');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuspensionScreen(
            localId: user.localId,
            user: user,
          ),
        ),
      );
      return;
    }

    // 3 – Advertência
    if (user.hasWarning) {
      debugPrint('⚠️ Usuário com advertência');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WarningScreen(
            localId: user.localId,
            user: user,
          ),
        ),
      );
      return;
    }

    // 4 – Home (fluxo normal)
    debugPrint('🏠 Navegando para HomeScreen');

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          key: homeScreenKey,
          local_id: user.localId,
          userName: user.userName,
          userEmail: user.email,
          contact_email: user.contactEmail,
          legalType: user.legalType,
          userPhone: user.phone,
          userCity: user.city,
          
          userState: user.state,
          age: user.age,
          userAvatar: user.avatar,
          finished_basic: user.finishedBasic,
          finished_contact: user.finishedContact,
          finished_professional: user.finishedProfessional,
          isActive: user.isActive,
          activeMode: user.activeMode,
          dataWorker: user.dataWorker,
          dataContractor: user.dataContractor,
        ),
      ),
    );
  }

  void nextScreen(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/onboarding_first');
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}
