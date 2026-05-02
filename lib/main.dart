// ignore_for_file: unused_import

import 'dart:io';

import 'package:dartobra_new/controllers/feed_controller.dart';
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
  bool _blockProviderInitialized = false;
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
    _initializeNotifications();
    _listenToMaintenance();
  }

  Future<void> clearBadge() async {
    try {
      await _localNotifications.cancelAll();
      print('🧹 Badge limpo');
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
      print('📱 App retornou ao foreground — zerando badge');
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

      print('🔧 Maintenance: $isUpdating | Tester: $isTester | User: $userId');

      if (shouldShowMaintenance == _isInMaintenance) return;

      setState(() => _isInMaintenance = shouldShowMaintenance);

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (shouldShowMaintenance) {
        print('🚧 Manutenção ativada');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
          (route) => false,
        );
      } else {
        print('✅ Manutenção desativada');
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
    if (_initialMessage != null) {
      print(
          '🚀 [TERMINATED] Notificação inicial capturada: ${_initialMessage!.data}');
    }

    _currentUserId = await _getCurrentUserId();
    if (_currentUserId == null) {
      print('⚠️ userId nulo — notificações serão inicializadas pelo SplashPage');
      return;
    }

    if (!_blockProviderInitialized && _currentUserId != null) {
      final blockProvider = Provider.of<BlockProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await blockProvider.init(_currentUserId!);
      _blockProviderInitialized = true;
      print('✅ BlockProvider inicializado com userId: $_currentUserId');
    }

    _notificationsInitialized = true; 

    _currentUserRole = await _getUserRole(_currentUserId!);

    final service = NotificationService();
    await service.initialize(_currentUserId!);

    service.updateCallbacks(
      onChatTap: (chatId, senderId) async {
        print('🔔 onChatTap: $chatId');
        await _safeNavigateChat(chatId, _currentUserId!, _currentUserRole!);
      },
      onRequestTap: (requestType, profileId, vacancyId) async {
        print('🔔 onRequestTap: $requestType | $profileId | $vacancyId');
        await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
            requestType, profileId, vacancyId);
      },
    );

    print('✅ Callbacks configurados: $_currentUserId | $_currentUserRole');
  }

  Future<void> reinitializeNotifications(String userId) async {
    if (_notificationsInitialized) return;

    print('🔄 Reinicializando notificações com userId: $userId');
    _currentUserId = userId;
    _notificationsInitialized = true;
    if (!_blockProviderInitialized) {
      final blockProvider = Provider.of<BlockProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await blockProvider.init(userId);
      _blockProviderInitialized = true;
      print('✅ BlockProvider RE-inicializado com userId: $userId');
    }

    _currentUserRole = await _getUserRole(userId);

    final service = NotificationService();
    await service.initialize(userId);

    service.updateCallbacks(
      onChatTap: (chatId, senderId) async {
        print('🔔 onChatTap: $chatId');
        await _safeNavigateChat(chatId, _currentUserId!, _currentUserRole!);
      },
      onRequestTap: (requestType, profileId, vacancyId) async {
        print('🔔 onRequestTap: $requestType | $profileId | $vacancyId');
        await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
            requestType, profileId, vacancyId);
      },
    );

    print('✅ Notificações re-inicializadas: $userId | $_currentUserRole');
  }

  Future<void> processInitialMessage() async {
    if (_initialMessageProcessed) return;

    if (_currentUserId == null) {
      _currentUserId = await _getCurrentUserId();
      if (_currentUserId == null) {
        print('⚠️ processInitialMessage: userId nulo, abortando');
        return;
      }
    }
    if (_currentUserRole == null) {
      _currentUserRole = await _getUserRole(_currentUserId!);
    }

    if (_initialMessage != null) {
      _initialMessageProcessed = true;
      print('🎯 Processando notificação FCM inicial...');
      await _dispatchPayload(_initialMessage!.data);
      return;
    }

    final pending = NotificationService().consumePendingPayload();
    if (pending != null) {
      _initialMessageProcessed = true;
      print('🎯 Processando payload local pendente: $pending');
      await _dispatchPayload(pending);
      return;
    }

    print('ℹ️ processInitialMessage: nenhum payload pendente');
  }

  Future<void> _dispatchPayload(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? '';

    print('⏳ Aguardando HomeScreen montar...');
    bool homeReady = false;
    for (int i = 0; i < 30; i++) {
      final state = homeScreenKey.currentState;
      if (state != null && state.mounted) {
        homeReady = true;
        print('✅ HomeScreen montada na tentativa ${i + 1}');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!homeReady) {
      print('⚠️ HomeScreen não montou em 9 segundos, abortando navegação');
      return;
    }

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
        final requestType = data['requestType']?.toString() ?? 'professional';
        final profileId = data['profileId']?.toString() ?? '';
        final vacancyId = data['vacancyId']?.toString() ?? '';
        await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
            requestType, profileId, vacancyId);
        break;

      case 'vacancy_request':
        final vacancyId = data['vacancyId']?.toString() ?? '';
        if (vacancyId.isNotEmpty) {
          await _safeNavigateRequest(_currentUserId!, _currentUserRole!,
              'vacancy_request', '', vacancyId);
        }
        break;

      default:
        print('⚠️ Tipo desconhecido: $type');
    }
  }

  Future<void> _safeNavigateChat(
      String chatId, String userId, String userRole) async {
    for (int i = 0; i < 10; i++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        print('📱 [tentativa ${i + 1}] Navegando para chat: $chatId');
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
    print('⚠️ FALHOU navegar chat - sem context após 10 tentativas');
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
        print('📱 [tentativa ${i + 1}] Navegando para request: $requestType');
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
    print('⚠️ FALHOU navegar request - sem context após 10 tentativas');
  }

  Future<String> _getUserRole(String userId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('Users/$userId/activeMode').get();
      return snapshot.value?.toString() ?? 'employee';
    } catch (e) {
      print('❌ Erro userRole: $e');
      return 'employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedController(), lazy: true),
      ChangeNotifierProvider(create: (_) => BlockProvider()),
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