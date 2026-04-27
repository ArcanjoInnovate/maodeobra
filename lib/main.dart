// ignore_for_file: unused_import

import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/screens/auth/login/login_screen.dart';
import 'package:dartobra_new/screens/auth/register/onboarding_first/onboarding_first_screen.dart';
import 'package:dartobra_new/screens/auth/splash/splash_screen.dart';
import 'package:dartobra_new/screens/screens_init/maintenance_screen/maintenance_screen.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

// ============================================================
// ✅ BACKGROUND HANDLER GLOBAL
// ============================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔥 Background message: ${message.data}");
  NotificationService().handleBackgroundMessage(message);
}

Future<String?> _getCurrentUserId() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('✅ UserID: ${currentUser.uid}');
      return currentUser.uid;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId != null) {
      print('⚠️ SharedPref UserID: $userId');
      return userId;
    }

    final authBox = await Hive.openBox('auth');
    final hiveUserId = authBox.get('currentUserId');
    print('⚠️ Hive UserID: $hiveUserId');
    return hiveUserId;
  } catch (e) {
    print('❌ Erro userId: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
  ExpirationService().debugTestDate();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ============================================================
  // ✅ CHAVE GLOBAL DE NAVEGAÇÃO — permite navegar de qualquer
  //    lugar do app sem precisar de um BuildContext de widget
  // ============================================================
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ============================================================
  // ✅ LISTENER DE MANUTENÇÃO EM TEMPO REAL
  //    Guarda a subscription para cancelar no dispose()
  // ============================================================
  late final DatabaseReference _adminRef;
  late final Stream<DatabaseEvent> _adminStream;

  bool _isInMaintenance = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _listenToMaintenance(); // 🔑 inicia o listener global
  }

  @override
  void dispose() {
    // O StreamBuilder cuida do cancelamento, mas se você trocar para
    // StreamSubscription manual, cancele aqui.
    super.dispose();
  }

  // ============================================================
  // 🔑 LISTENER EM TEMPO REAL DE MANUTENÇÃO
  //    Roda independente da tela atual. Se o admin ligar o modo
  //    manutenção, o usuário é redirecionado IMEDIATAMENTE, não
  //    importa em qual rota ele estiver.
  // ============================================================
  void _listenToMaintenance() {
    _adminRef = FirebaseDatabase.instance.ref('Administrative');

    _adminRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      final isUpdating = data?['isUpdating'] == true;
      final testers = (data?['testers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final isTester = userId != null && testers.contains(userId);

      final shouldShowMaintenance = isUpdating && !isTester;

      print(
          '🔧 [Realtime] Maintenance: $isUpdating | Tester: $isTester | User: $userId');

      // Só age se o estado mudou para evitar navegação redundante
      if (shouldShowMaintenance == _isInMaintenance) return;

      setState(() => _isInMaintenance = shouldShowMaintenance);

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (shouldShowMaintenance) {
        // 🔴 Manutenção LIGADA → leva o usuário para a tela de manutenção
        //    pushAndRemoveUntil garante que ele não consiga voltar
        print('🚧 Manutenção ativada — redirecionando...');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
          (route) => false, // remove todas as rotas anteriores
        );
      } else {
        // 🟢 Manutenção DESLIGADA → volta para o Splash (que decide o fluxo)
        print('✅ Manutenção desativada — voltando ao fluxo normal...');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()),
          (route) => false,
        );
      }
    }, onError: (error) {
      print('❌ Erro no listener de manutenção: $error');
    });
  }

  // 🚀 DEBUG FCM TOKEN + ALERT VISUAL
  Future<void> _initializeNotifications() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    print('🔔 Init notificações: $userId');

    final service = NotificationService();
    await service.initialize(userId);

    FirebaseMessaging.onMessage.listen((message) {
      service.handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      service.handleNotificationTap(message.data);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      service.handleNotificationTap(initial.data);
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();

      print('🔍 === FCM DEBUG iOS ===');
      print('UserID: $userId');
      print('Token: ${token?.substring(0, 30)}...');
      print('Permissions: ${settings.authorizationStatus}');
      print('========================');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDebugAlert(
              token, settings.authorizationStatus.toString(), userId);
        }
      });
    } catch (e) {
      print('❌ Token error: $e');
    }

    print('✅ Notificações configuradas!');
  }

  // 🎨 ALERT BONITO COM TOKEN
  void _showDebugAlert(String? token, String permissions, String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('FCM iOS DEBUG', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ TOKEN GERADO!',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Token (copie):',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    token ?? 'ERRO: TOKEN NULL',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Permissions: $permissions',
                    style: const TextStyle(fontSize: 13, color: Colors.cyan)),
                Text('UserID: $userId',
                    style: const TextStyle(fontSize: 13, color: Colors.cyan)),
                const SizedBox(height: 8),
                const Text('Envie este token pro dev!',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedController(), lazy: true),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mão de Obra',
        // ✅ navigatorKey conecta o listener ao Navigator do app
        navigatorKey: navigatorKey,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        routes: {
          '/LoginScreen': (context) => const LoginScreen(),
          '/onboarding_first': (context) => const OnboardingFirst(),
        },
        // ✅ home inicial simples — o listener cuida dos redirecionamentos
        home: const SplashPage(),
      ),
    );
  }
}