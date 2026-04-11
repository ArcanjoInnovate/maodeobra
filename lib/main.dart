// ignore_for_file: unused_import

import 'package:dartobra_new/screens/auth/login/login_screen.dart';
import 'package:dartobra_new/screens/auth/register/onboarding_first/onboarding_first_screen.dart';
import 'package:dartobra_new/screens/auth/splash/splash_screen.dart';
import 'package:dartobra_new/screens/screens_init/maintenance_screen/maintenance_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/services/expiration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Mensagem em background: ${message.notification?.title}');
}

// ignore: unused_element
Future<String?> _getCurrentUserId() async {
  try {
    // ✅ PRIORIDADE 1: Firebase Auth (fonte da verdade)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('✅ UserID do Firebase Auth: ${currentUser.uid}');
      return currentUser.uid;
    }
    
    // Fallback: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId != null) {
      print('⚠️ UserID do SharedPreferences: $userId');
      return userId;
    }
    
    // Fallback: Hive
    final authBox = await Hive.openBox('auth');
    final hiveUserId = authBox.get('currentUserId');
    print('⚠️ UserID do Hive: $hiveUserId');
    return hiveUserId;
  } catch (e) {
    print('❌ Erro ao pegar userId: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 🧪 TESTE DE EXPIRAÇÃO (descomente para testar)
  // ExpirationService.testDate = DateTime.now().add(Duration(days: 1, hours: 22, minutes: 58));
  ExpirationService().debugTestDate();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FeedController(),
          lazy: true,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mão de Obra',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashPage(),
          '/LoginScreen': (context) => const LoginScreen(),
          '/onboarding_first': (context) => const OnboardingFirst(),
        },
        // ✅ SISTEMA DE MANUTENÇÃO COM TESTERS LIBERADOS DO FIREBASE
        builder: (context, child) {
          // ✅ ESCUTA MUDANÇAS DE AUTENTICAÇÃO EM TEMPO REAL
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final currentUser = authSnapshot.data;
              final currentUserId = currentUser?.uid;
              
              print('👤 Auth State: ${currentUser != null ? "LOGADO" : "DESLOGADO"}');
              print('👤 Current User ID: $currentUserId');
              
              return StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('Administrative')
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    // Enquanto carrega, mostra o child normalmente
                    return child ?? const SizedBox();
                  }

                  final data = snapshot.data?.snapshot.value;
                  Map<dynamic, dynamic>? adminData;
                  if (data is Map) {
                    adminData = data;
                  }
                  
                  // Verifica se está em manutenção
                  final raw = adminData?['isUpdating'];
                  print('🔥 Administrative/isUpdating = $raw');

                  final isUpdating = raw == true || 
                                    raw == 1 || 
                                    raw.toString() == 'true';

                  // ✅ BUSCA LISTA DE TESTERS DO FIREBASE
                  List<String> testerIds = [];
                  try {
                    final testersRaw = adminData?['testers'];
                    if (testersRaw is List) {
                      testerIds = testersRaw
                          .where((id) => id != null && id.toString().isNotEmpty)
                          .map((id) => id.toString())
                          .toList();
                    }
                  } catch (e) {
                    print('❌ Erro ao processar testers: $e');
                  }

                  print('🧪 Testers: $testerIds');
                  
                  final isTester = currentUserId != null && testerIds.contains(currentUserId);
                  print('✅ Is Tester: $isTester');
                  
                  // 🔓 LIBERA ACESSO SE:
                  // 1. É tester (está na lista do Firebase) OU
                  // 2. NÃO está em manutenção
                  if (isTester || !isUpdating) {
                    print('✅ ACESSO LIBERADO (isTester=$isTester, isUpdating=$isUpdating)');
                    return child ?? const SizedBox();
                  }

                  print('🔒 MANUTENÇÃO ATIVA');
                  return const MaintenanceScreen();
                },
              );
            },
          );
        },
      ),
    );
  }
}