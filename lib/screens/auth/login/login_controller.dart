import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/models/user_model.dart';

import 'package:dartobra_new/screens/admin/ban/ban_screen.dart';
import 'package:dartobra_new/screens/admin/suspension/suspension_screen.dart';
import 'package:dartobra_new/screens/admin/warning/warning_screen.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _repo = UserRepository();

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Iniciando login para: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Login bem-sucedido! UID: ${credential.user?.uid}');
      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException - Código: ${e.code}');

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
      print('❌ Erro inesperado: $e');
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
      print('⚠️ Dados do usuário não encontrados para $localId');
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
      print('🚫 Usuário banido');
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
      print('⏸️ Usuário suspenso');
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
      print('⚠️ Usuário com advertência');
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
    print('🏠 Navegando para HomeScreen');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await NotificationService().initialize(firebaseUser.uid);
    }

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
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
