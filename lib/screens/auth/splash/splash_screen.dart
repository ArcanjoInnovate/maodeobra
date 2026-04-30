import 'dart:io';
import 'dart:math' as math;
import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/main.dart' as MyApp;
import 'package:dartobra_new/screens/auth/login/login_controller.dart';
import 'package:dartobra_new/services/notifications/notification_navigation_service.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final Animation<double> _logoAnimation;
  late final Animation<double> _pulseAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _repo = UserRepository();
  final LoginController _loginCtrl = LoginController();

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _requestPermissions();
    _initApp();

  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        debugPrint('📱 iOS ${iosInfo.systemVersion} - Iniciando permissões...');

        // ✅ 1. NOTIFICAÇÕES (Firebase - iOS obrigatório)
        final NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('🔔 iOS Notificações: ${settings.authorizationStatus}');

        // ✅ 2. CÂMERA + FOTOS juntas
        final statuses = await [
          Permission.camera,
          Permission.photos,
        ].request();

        statuses.forEach((permission, status) {
          debugPrint('🔐 iOS $permission → $status');
        });
      } else if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        debugPrint(
            '🤖 Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})');

        // ✅ 1. NOTIFICAÇÕES (Android 13+)
        if (androidInfo.version.sdkInt >= 33) {
          final notifStatus = await Permission.notification.request();
          debugPrint('🔔 Android Notificações: $notifStatus');
        }

        // ✅ 2. CÂMERA
        final cameraStatus = await Permission.camera.request();
        debugPrint('📸 Android Câmera: $cameraStatus');

        // ✅ 3. FOTOS (Android 13+) ou STORAGE (Android < 13)
        if (androidInfo.version.sdkInt >= 33) {
          final photosStatus = await Permission.photos.request();
          debugPrint('🖼️ Android Fotos: $photosStatus');
        } else {
          final storageStatus = await Permission.storage.request();
          debugPrint('💾 Android Storage: $storageStatus');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao solicitar permissões: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  // ── Animações ──────────────────────────────────────────────────────────────

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _logoController.forward();
  }

  // ── Inicialização ──────────────────────────────────────────────────────────

  Future<void> _initApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        _goToLogin();
        return;
      }

      final user = await _repo.fetchUser(currentUser.uid);

      if (user == null) {
        await _auth.signOut();
        _goToLogin();
        return;
      }

      // ✅ ADICIONE AQUI — usuário confirmado, configura notificações
      await _refreshNotificationCallbacks(currentUser.uid, user.activeMode);

      if (!mounted) return;
      await _loginCtrl.navigateToNextScreen(context, user);
    } catch (e) {
      print('❌ Erro: $e');
      _goToLogin();
    }
  }

// ✅ ADICIONE ESTE MÉTODO no _SplashPageState
  Future<void> _refreshNotificationCallbacks(
      String userId, String userRole) async {
    final service = NotificationService();

    // ❌ REMOVA ESSA LINHA
    // await service.initialize(userId);

    // ✅ Só atualiza os callbacks, sem reinicializar
    service.updateCallbacks(
      onChatTap: (chatId, senderId) async {
        final context = MyApp.navigatorKey.currentContext;
        if (context == null) return;

        await NotificationNavigationService().navigateToChat(
          context: context,
          chatId: chatId,
          userId: userId,
          userRole: userRole,
        );
      },
      onRequestTap: (requestType, profileId, vacancyId) async {
        final context = MyApp.navigatorKey.currentContext;
        if (context == null) return;

        await NotificationNavigationService().navigateToRequest(
          context: context,
          userId: userId,
          userRole: userRole,
          requestType: requestType ?? '',
          profileId: profileId,
          vacancyId: vacancyId,
        );
      },
    );

    print('✅ Callbacks atualizados | user: $userId | role: $userRole');
  }

  void _goToLogin() {
    if (mounted) Navigator.pushReplacementNamed(context, '/LoginScreen');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Blue 900
              Color(0xFF3B82F6), // Blue 500
              Color(0xFF60A5FA), // Blue 400
            ],
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos de fundo
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Conteúdo principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo com animação
                  ScaleTransition(
                    scale: _logoAnimation,
                    child: FadeTransition(
                      opacity: _logoAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo_no_bg.png',
                          width: 150,
                          height: 200,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Nome do app
                  FadeTransition(
                    opacity: _logoAnimation,
                    child: Column(
                      children: [
                        Text(
                          'MãoDeObra',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conectando profissionais',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading indicator animado
                  AnimatedBuilder(
                    animation: _rotateController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateController.value * 2 * math.pi,
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Versão do app no rodapé
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _logoAnimation,
                child: Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
