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
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  // 🚀 DEBUG FCM TOKEN + ALERT VISUAL
  Future<void> _initializeNotifications() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    print('🔔 Init notificações: $userId');

    final service = NotificationService();
    await service.initialize(userId);

    // ✅ Handlers normais
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

    // 🚀 DEBUG CRÍTICO - TOKEN + PERMISSIONS
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      
      print('🔍 === FCM DEBUG iOS ===');
      print('UserID: $userId');
      print('Token: ${token?.substring(0, 30)}...');
      print('Permissions: ${settings.authorizationStatus}');
      print('========================');
      
      // ✅ ALERT VISUAL NO IPHONE - VOCÊ VAI VER!
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDebugAlert(token, settings.authorizationStatus.toString(), userId);
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
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Token (copie):', style: TextStyle(fontWeight: FontWeight.w500)),
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
                      color: Colors.white
                    ),
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
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashPage(),
          '/LoginScreen': (context) => const LoginScreen(),
          '/onboarding_first': (context) => const OnboardingFirst(),
        },
        home: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('Administrative').onValue,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SplashPage();

            final data =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
            final isUpdating = data?['isUpdating'] == true;
            final testers = (data?['testers'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final userId = FirebaseAuth.instance.currentUser?.uid;
            final isTester = userId != null && testers.contains(userId);

            print(
                '🔧 Maintenance: $isUpdating | Tester: $isTester | User: $userId');

            return isTester || !isUpdating
                ? const SplashPage()
                : const MaintenanceScreen();
          },
        ),
      ),
    );
  }
}