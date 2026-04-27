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
  // DEBUG TOTAL - remove depois
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(seconds: 3));
    
    final settings = await FirebaseMessaging.instance.requestPermission();
    print('📲 Auth status: ${settings.authorizationStatus}');
    
    final apns = await FirebaseMessaging.instance.getAPNSToken();
    print('🍎 APNs: $apns');
    
    final fcm = await FirebaseMessaging.instance.getToken();
    print('📱 FCM: $fcm');
    
    // Salva tudo no banco para você ver
    await FirebaseDatabase.instance.ref('debug_fcm').set({
      'apns': apns ?? 'NULL',
      'fcm': fcm ?? 'NULL',
      'auth': settings.authorizationStatus.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  });
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref('Users/${user.uid}/fcmToken')
          .set(token);
      print('✅ FCM token salvo via onTokenRefresh: ${token.substring(0, 20)}');
    }
  });

  // Tenta pegar token imediatamente também
  FirebaseMessaging.instance.getToken().then((token) async {
    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref('Users/${user.uid}/fcmToken')
            .set(token);
      }
    }
  });
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
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

  Future<void> _initializeNotifications() async {
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('⚠️ Sem userId - handlers não configurados');
      return;
    }

    print('🔔 Init notificações: $userId');
    final service = NotificationService();
    await service.initialize(userId);

    FirebaseMessaging.onMessage.listen((message) {
      service.handleForegroundMessage(message);
      print('📱 Foreground message: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      service.handleNotificationTap(message.data);
      print('👆 Notification tap: ${message.data}');
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      service.handleNotificationTap(initial.data);
      print('🔄 Initial message: ${initial.data}');
    }

    print('✅ Notificações 100% configuradas!');
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

            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
            final isUpdating = data?['isUpdating'] == true;
            final testers = (data?['testers'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final userId = FirebaseAuth.instance.currentUser?.uid;
            final isTester = userId != null && testers.contains(userId);

            print('🔧 Maintenance: $isUpdating | Tester: $isTester | User: $userId');

            return isTester || !isUpdating ? const SplashPage() : const MaintenanceScreen();
          },
        ),
      ),
    );
  }
}