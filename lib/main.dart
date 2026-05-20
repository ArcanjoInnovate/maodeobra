// ignore_for_file: unused_import

import 'dart:io';

import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/controllers/search_controller.dart' as app_search;
import 'package:dartobra_new/core/providers/block_provider.dart';
import 'package:dartobra_new/screens/auth/login/login_screen.dart';
import 'package:dartobra_new/screens/auth/register/onboarding_first/onboarding_first_screen.dart';
import 'package:dartobra_new/screens/auth/splash/splash_screen.dart';
import 'package:dartobra_new/screens/home/home_screen.dart';
import 'package:dartobra_new/screens/screens_init/maintenance_screen/maintenance_screen.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/notifications/notification_navigation_service.dart';
import 'package:dartobra_new/services/notifications/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<_MyAppState> appStateKey = GlobalKey<_MyAppState>();

Future<String?> _getCurrentUserId() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) return currentUser.uid;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId != null) return userId;

    final authBox = await Hive.openBox('auth');
    return authBox.get('currentUserId');
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
    alert: false,
    badge: false,
    sound: false,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
  ExpirationService().debugTestDate();

  runApp(MyApp(key: appStateKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final DatabaseReference _adminRef;
  bool _isInMaintenance = false;
  bool _notificationsInitialized = false;
  String? _currentUserId;
  String? _currentUserRole;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  RemoteMessage? _initialMessage;
  bool _initialMessageProcessed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clearBadge();
    _listenToMaintenance();
    _initializeNotifications();
  }

  Future<void> clearBadge() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      print('❌ Erro ao limpar badge: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().clearBadge();
    }
  }

  void _listenToMaintenance() {
    _adminRef = FirebaseDatabase.instance.ref('Administrative');

    _adminRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final isUpdating = data?['isUpdating'] == true;
      final testers =
          (data?['testers'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final isTester = userId != null && testers.contains(userId);
      final shouldShowMaintenance = isUpdating && !isTester;

      if (shouldShowMaintenance == _isInMaintenance) return;

      setState(() => _isInMaintenance = shouldShowMaintenance);

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (shouldShowMaintenance) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
          (route) => false,
        );
      } else {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()),
          (route) => false,
        );
      }
    }, onError: (error) {
      print('❌ Erro listener manutenção: $error');
    });
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    _initialMessage ??= await FirebaseMessaging.instance.getInitialMessage();
  }

  Future<void> reinitializeNotifications(String userId) async {
    print('🔄 Reinicializando notificações: $userId');

    _currentUserId = userId;

    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      _currentUserRole = await _getUserRole(userId);

      final service = NotificationService();
      await service.initialize(userId);

      service.updateCallbacks(
        onChatTap: (chatId, senderId) async {
          await _safeNavigateChat(chatId, _currentUserId!, _currentUserRole!);
        },
        onRequestTap: (requestType, profileId, vacancyId) async {
          await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
              requestType, profileId, vacancyId);
        },
      );

      print('✅ Notificações inicializadas: $userId | $_currentUserRole');
    }
  }

  Future<void> processInitialMessage() async {
    if (_initialMessageProcessed) return;

    if (_currentUserId == null) {
      _currentUserId = await _getCurrentUserId();
      if (_currentUserId == null) return;
    }
    if (_currentUserRole == null) {
      _currentUserRole = await _getUserRole(_currentUserId!);
    }

    if (_initialMessage != null) {
      _initialMessageProcessed = true;
      await _dispatchPayload(_initialMessage!.data);
      return;
    }

    final pending = NotificationService().consumePendingPayload();
    if (pending != null) {
      _initialMessageProcessed = true;
      await _dispatchPayload(pending);
    }
  }

  Future<void> _dispatchPayload(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? '';

    bool homeReady = false;
    for (int i = 0; i < 30; i++) {
      final state = homeScreenKey.currentState;
      if (state != null && state.mounted) {
        homeReady = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!homeReady) return;
    await Future.delayed(const Duration(milliseconds: 300));

    switch (type) {
      case 'chat':
      case 'chat_accepted':
        final chatId = data['chatId']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          await _safeNavigateChat(chatId, _currentUserId!, _currentUserRole!);
        }
        break;
      case 'request':
        await _safeNavigateRequest(
          _currentUserId!,
          _currentUserRole!,
          data['requestType']?.toString() ?? 'professional',
          data['profileId']?.toString() ?? '',
          data['vacancyId']?.toString() ?? '',
        );
        break;
      case 'vacancy_request':
        final vacancyId = data['vacancyId']?.toString() ?? '';
        if (vacancyId.isNotEmpty) {
          await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
              'vacancy_request', '', vacancyId);
        }
        break;
    }
  }

  Future<void> _safeNavigateChat(
      String chatId, String userId, String userRole) async {
    for (int i = 0; i < 10; i++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await NotificationNavigationService().navigateToChat(
          context: context,
          chatId: chatId,
          userId: userId,
          userRole: userRole,
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _safeNavigateRequest(
    String userId,
    String userRole,
    String requestType,
    String? profileId,
    String? vacancyId,
  ) async {
    for (int i = 0; i < 10; i++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await NotificationNavigationService().navigateToRequest(
          context: context,
          userId: userId,
          userRole: userRole,
          requestType: requestType,
          profileId: profileId,
          vacancyId: vacancyId,
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<String> _getUserRole(String userId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('Users/$userId/activeMode').get();
      return snapshot.value?.toString() ?? 'employee';
    } catch (e) {
      return 'employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ⚠️ ORDEM IMPORTA: BlockProvider primeiro,
        // depois os controllers que dependem dele.
        ChangeNotifierProvider(create: (_) => BlockProvider()),
        ChangeNotifierProvider(create: (_) => FeedController(), lazy: true),
        ChangeNotifierProvider(
            create: (_) => app_search.SearchController(), lazy: true),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mão de Obra',
        navigatorKey: navigatorKey,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        routes: {
          '/LoginScreen': (context) => const LoginScreen(),
          '/onboarding_first': (context) => const OnboardingFirst(),
        },
        home: _isInMaintenance ? const MaintenanceScreen() : const SplashPage(),
      ),
    );
  }
}