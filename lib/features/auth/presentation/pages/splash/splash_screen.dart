import 'dart:io';
import 'dart:math' as math;
import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/controllers/search_controller.dart' as app_search;
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/features/auth/controller/login_controller.dart';
import 'package:dartobra_new/main.dart' as MyApp;
import 'package:dartobra_new/services/notifications/notification_navigation_service.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

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
        debugPrint('📱 iOS ${iosInfo.systemVersion}');

        final NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('🔔 iOS Notificações: ${settings.authorizationStatus}');

        await [Permission.camera, Permission.photos].request();
      } else if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        debugPrint('🤖 Android SDK ${androidInfo.version.sdkInt}');

        if (androidInfo.version.sdkInt >= 33) {
          // ✅ Android 13+: Photo Picker não precisa de READ_MEDIA_IMAGES.
          // Apenas notificação e câmera são solicitadas.
          await Permission.notification.request();
        } else {
          // Android ≤12: storage cobre acesso à galeria via seletor legado
          await Permission.storage.request();
        }
        await Permission.camera.request();
      }
    } catch (e) {
      debugPrint('⚠️ Erro permissões: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

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

      // ── PASSO CRÍTICO ──────────────────────────────────────────────────────
      // Inicializa o BlockProvider e conecta os controllers ANTES de navegar
      // para a HomeScreen. Isso garante que quando o FeedController e o
      // SearchController carregarem seus dados, os bloqueados já estão
      // disponíveis via blockedSet — sem depender de chamada própria ao Firebase.
      //
      // No iOS isso é especialmente importante porque o SDK não tem cache
      // local persistente, e chamadas paralelas ao Firebase podem retornar
      // vazias se feitas antes da conexão estar estável.
      await _initBlockProviderAndConnectControllers(currentUser.uid);

      await _refreshNotificationCallbacks(currentUser.uid, user.activeMode);

      if (!mounted) return;
      await _loginCtrl.navigateToNextScreen(context, user);

      await WidgetsBinding.instance.endOfFrame;

      final appState = MyApp.appStateKey.currentState;
      if (appState != null) {
        await appState.reinitializeNotifications(currentUser.uid);
        await appState.processInitialMessage();
      }
    } catch (e) {
      debugPrint('❌ Erro splash: $e');
      _goToLogin();
    }
  }

  /// Inicializa o BlockProvider com await real e conecta FeedController
  /// e SearchController via callbacks — tudo antes de exibir o feed.
  Future<void> _initBlockProviderAndConnectControllers(String userId) async {
    if (!mounted) return;

    try {
      final blockProvider = context.read<BlockProvider>();

      // Aguarda com timeout para não travar a splash em caso de falha de rede.
      // 8 segundos é suficiente para qualquer conexão móvel razoável no iOS.
      await blockProvider.init(userId).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⚠️ BlockProvider.init timeout — feed carregará sem bloqueados'
              ' e sincronizará via stream quando a rede responder');
        },
      );

      debugPrint(
          '✅ BlockProvider pronto: ${blockProvider.blockedSet.length} bloqueados');

      if (!mounted) return;

      try {
        context.read<FeedController>().registerWithBlockProvider(blockProvider);
        debugPrint('✅ FeedController registrado no BlockProvider');
      } catch (e) {
        debugPrint('⚠️ FeedController não disponível ainda: $e');
      }

      try {
        context
            .read<app_search.SearchController>()
            .registerWithBlockProvider(blockProvider);
        debugPrint('✅ SearchController registrado no BlockProvider');
      } catch (e) {
        debugPrint('⚠️ SearchController não disponível ainda: $e');
      }
    } catch (e) {
      debugPrint('❌ _initBlockProviderAndConnectControllers: $e');
    }
  }

  Future<void> _refreshNotificationCallbacks(
      String userId, String userRole) async {
    final service = NotificationService();

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
  }

  void _goToLogin() {
    if (mounted) Navigator.pushReplacementNamed(context, '/LoginScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: Stack(
          children: [
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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