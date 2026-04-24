import 'dart:io';
import 'dart:math' as math;
import 'package:dartobra_new/core/repositories/user_repository.dart';
import 'package:dartobra_new/screens/auth/login/login_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // ✅ iOS - Notificações (sempre pede)
    if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      debugPrint('📱 iOS ${iosInfo.systemVersion} - Pedindo notificações...');
      
      // Pede notificações no iOS
      final notificationStatus = await Permission.notification.request();
      debugPrint('🔔 iOS Notification: $notificationStatus');
      
      // Outras permissões iOS
      final statuses = await [
        Permission.camera,
        Permission.photos,
      ].request();
      
      statuses.forEach((permission, status) {
        debugPrint('🔐 iOS $permission → $status');
      });
      
      return; // iOS pronto!
    }

    // ✅ Android
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final permissions = <Permission>[
      Permission.camera,
      Permission.notification,  // ✅ Sempre pede no Android 13+
      if (sdkInt >= 33) Permission.photos,
      if (sdkInt < 33) Permission.storage,
    ];

    final statuses = await permissions.request();
    statuses.forEach((permission, status) {
      debugPrint('🔐 Android $permission → $status');
    });

    // Verifica se precisa abrir configurações
    final deniedPermissions = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();

    if (deniedPermissions.isNotEmpty) {
      await _showPermissionsDialog(deniedPermissions);
    }
  } catch (e) {
    debugPrint('⚠️ Erro ao solicitar permissões: $e');
  }
}
  Future<void> _showPermissionsDialog(List<Permission> deniedPermissions) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Permissões necessárias'),
      content: const Text(
        'Câmera e acesso a fotos são essenciais para o funcionamento do app. '
        'Por favor, habilite nas configurações.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Agora não', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await openAppSettings(); // leva para as configurações do app
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Abrir Configurações',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
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
        print('❌ Nenhum usuário logado');
        _goToLogin();
        return;
      }

      print('✅ Usuário logado: ${currentUser.uid}');

      final user = await _repo.fetchUser(currentUser.uid);

      if (user == null) {
        print('⚠️ Dados do usuário não encontrados — fazendo logout');
        await _auth.signOut();
        _goToLogin();
        return;
      }

      if (!mounted) return;
      await _loginCtrl.navigateToNextScreen(context, user);
    } catch (e) {
      print('❌ Erro ao inicializar app: $e');
      _goToLogin();
    }
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
