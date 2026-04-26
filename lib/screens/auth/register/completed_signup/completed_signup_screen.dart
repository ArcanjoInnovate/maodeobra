import 'dart:io';

import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';


class CompletedSignup extends StatefulWidget {
  final String email;
  final String password;
  final int age;

  const CompletedSignup({
    super.key,
    required this.email,
    required this.password,
    required this.age,
  });

  @override
  State<CompletedSignup> createState() => _CompletedSignupState();
}

class _CompletedSignupState extends State<CompletedSignup>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _loading = true;
  bool _success = false;
  String _statusMessage = 'Preparando seu cadastro...';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _createUser();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
  Future<void> _createUser() async {
    try {
      // Fase 1: Criando conta
      setState(() => _statusMessage = 'Criando sua conta...');
      await Future.delayed(const Duration(milliseconds: 800));

      final cred = await _auth.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final uid = cred.user!.uid;

      // Fase 2: Salvando dados
      setState(() => _statusMessage = 'Salvando seus dados...');
      await Future.delayed(const Duration(milliseconds: 600));

      // Prepara os dados do usuário
      final userData = {
        'Name': 'Não definido',
        'email': widget.email,
        'finished_basic': false,
        'finished_professional': false,
        'finished_contact': false,
        'email_contact': widget.email,
        'isActive': false,
        'isPremium': false,
        'premiumExpiresAt': null,
        'telefone': 'Não definido',
        'telephoneVerified': false,
        'createdAt': DateTime.now().toIso8601String(),
        'avatar':
            'https://firebasestorage.googleapis.com/v0/b/obra-7ebd9.firebasestorage.app/o/Trabalhador%20da%20constru%C3%A7%C3%A3o%20em%20ilustra%C3%A7%C3%A3o%20vetorial.png?alt=media&token=a55ac8f3-6a40-4c86-b72f-29f6fa46a0c8',
        'age': widget.age,
        'state': 'Não definido',
        'city': 'Não definido',
        'activeMode': 'worker',
        'legalType': 'Não definido',
        // ── Campos adicionados ──────────────────────────────────────
        'terms': true,
        // ────────────────────────────────────────────────────────────
        'data_worker': {
          'profession': 'Não definida',
          'summary': 'Não definido',
          'skills': ['Nenhuma habilidade definida'],
          'company': '',
        },
        'data_contractor': {
          'profession': 'Não definida',
          'summary': 'Não definido',
          'company': '',
        },
        'ban': {
          'description': '',
          'motive': '',
          'data': '',
        },
        'warning': {
          'motive': '',
          'description': '',
          'data': '',
          'type': '',
        },
        'suspension': {
          'motive': '',
          'description': '',
          'init': '',
          'end': '',
          'data': '',
        },
      };

      await _db.child('Users').child(uid).set(userData);
      await _saveFCMToken(uid); 
      // Fase 3: Finalizando
      setState(() => _statusMessage = 'Finalizando cadastro...');
      await Future.delayed(const Duration(milliseconds: 600));

      // Sucesso!
      setState(() {
        _success = true;
        _statusMessage = 'Cadastro concluído!';
        _loading = false;
      });

      _animationController.forward();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              local_id: uid,
              userName: 'Não definido',
              userEmail: widget.email,
              userPhone: 'Não definido',
              userCity: 'Não definido',
              legalType: 'Não definido',
              contact_email: widget.email,
              userState: 'Não definido',
              age: widget.age,
              userAvatar:
                  'https://res.cloudinary.com/dsmgwupky/image/upload/v1731970845/image_3_uiwlog.png',
              finished_basic: false,
              finished_professional: false,
              finished_contact: false,
              isActive: false,
              activeMode: 'worker',
              dataWorker: {
                'profession': 'Não definida',
                'summary': 'Não definido',
                'skills': ['Nenhuma habilidade definida'],
                'legalType': 'Não definido',
                'company': '',
              },
              dataContractor: {
                'profession': 'Não definida',
                'summary': 'Não definido',
                'legalType': 'Não definido',
                'company': '',
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _success = false;
        _statusMessage = 'Erro ao criar conta';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erro: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone animado
                  if (_success)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: screenWidth * 0.3,
                          height: screenWidth * 0.3,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: screenWidth * 0.18,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: screenWidth * 0.3,
                      height: screenWidth * 0.3,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _loading
                            ? CircularProgressIndicator(
                                color: Colors.blue[700],
                                strokeWidth: 3,
                              )
                            : Icon(
                                Icons.error_outline,
                                size: screenWidth * 0.18,
                                color: Colors.red,
                              ),
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.04),

                  // Título
                  Text(
                    _success ? 'Bem-vindo!' : 'Configurando conta',
                    style: TextStyle(
                      fontSize: screenHeight * 0.032,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: screenHeight * 0.015),

                  // Mensagem de status
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: screenHeight * 0.02,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_success) ...[
                    SizedBox(height: screenHeight * 0.025),
                    Text(
                      'Olá, caro usuário!',
                      style: TextStyle(
                        fontSize: screenHeight * 0.022,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Text(
                      'Sua conta foi criada com sucesso.\nRedirecionando para o app...',
                      style: TextStyle(
                        fontSize: screenHeight * 0.017,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_loading) ...[
                    SizedBox(height: screenHeight * 0.03),

                    // Indicadores de progresso
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                        vertical: screenHeight * 0.025,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildProgressItem(
                            icon: Icons.person_add,
                            label: 'Criando conta',
                            isActive: _statusMessage.contains('Criando'),
                            isDone: !_statusMessage.contains('Criando') &&
                                !_statusMessage.contains('Preparando'),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          _buildProgressItem(
                            icon: Icons.save,
                            label: 'Salvando dados',
                            isActive: _statusMessage.contains('Salvando'),
                            isDone: _statusMessage.contains('Finalizando'),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          _buildProgressItem(
                            icon: Icons.check_circle_outline,
                            label: 'Finalizando',
                            isActive: _statusMessage.contains('Finalizando'),
                            isDone: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDone,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green[50]
                : isActive
                    ? Colors.blue[50]
                    : Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? Colors.green
                  : isActive
                      ? Colors.blue
                      : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: isDone
              ? const Icon(Icons.check, color: Colors.green, size: 20)
              : isActive
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: Colors.grey[400], size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: screenHeight * 0.018,
              color: isDone || isActive ? Colors.grey[800] : Colors.grey[500],
              fontWeight:
                  isDone || isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}