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
//    Usa APENAS o handler do notification_service.dart.
//    NÃO declare outro handler aqui — duplicaria as notificações.
// ============================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  // ✅ Usa APENAS o handler definido em notification_service.dart
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ✅ CORRIGIDO: alert:false evita que o iOS exiba o banner automaticamente
  //    em foreground via aps.alert, o que causava notificação duplicada.
  //    O NotificationService exibe via flutter_local_notifications no onMessage.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
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

// ✅ ADICIONADO: WidgetsBindingObserver para detectar quando o app volta
//    ao foreground e zerar o badge do ícone automaticamente.
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // ============================================================
  // ✅ CHAVE GLOBAL DE NAVEGAÇÃO — permite navegar de qualquer
  //    lugar do app sem precisar de um BuildContext de widget
  // ============================================================
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ============================================================
  // ✅ LISTENER DE MANUTENÇÃO EM TEMPO REAL
  // ============================================================
  late final DatabaseReference _adminRef;

  bool _isInMaintenance = false;

  // ✅ Guard para garantir que initialize() seja chamado apenas uma vez
  bool _notificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    // ✅ Registra o observer para receber eventos de ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
    _listenToMaintenance();
  }

  @override
  void dispose() {
    // ✅ Remove o observer ao destruir o widget para evitar memory leak
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // ✅ CICLO DE VIDA DO APP
  //    Zera o badge do ícone toda vez que o usuário abre/retorna
  //    ao app — independente de ter tocado nas notificações.
  // ============================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📱 App retornou ao foreground — zerando badge');
      NotificationService().clearBadge();
    }
  }

  // ============================================================
  // 🔑 LISTENER EM TEMPO REAL DE MANUTENÇÃO
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

      if (shouldShowMaintenance == _isInMaintenance) return;

      setState(() => _isInMaintenance = shouldShowMaintenance);

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (shouldShowMaintenance) {
        print('🚧 Manutenção ativada — redirecionando...');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
          (route) => false,
        );
      } else {
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

  // ============================================================
  // 🔔 INICIALIZAÇÃO DAS NOTIFICAÇÕES
  //    ✅ Guard _notificationsInitialized evita chamadas duplas.
  //    O NotificationService também tem seu próprio guard interno,
  //    mas esta camada extra garante que nem chegamos lá duas vezes.
  // ============================================================
  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;

    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('⚠️ userId nulo — handlers de notificação não configurados ainda');
      return;
    }

    final service = NotificationService();
    await service.initialize(userId);
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
        navigatorKey: navigatorKey,
        
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        routes: {
          '/LoginScreen': (context) => const LoginScreen(),
          '/onboarding_first': (context) => const OnboardingFirst(),
        },
        home: const SplashPage(),
      ),
    );
  }
}