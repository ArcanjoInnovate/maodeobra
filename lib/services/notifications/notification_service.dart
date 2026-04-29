import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as local_notifications;

// ══════════════════════════════════════════════════════════════════════════════
//  BACKGROUND HANDLER (top-level, obrigatório pelo Firebase)
// ══════════════════════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 [BG] Mensagem recebida: ${message.data}');
  // Não mostra notificação local aqui - o sistema já mostra via APNs/FCM
  // Apenas loga para debugging
}

// ══════════════════════════════════════════════════════════════════════════════
//  CALLBACKS
// ══════════════════════════════════════════════════════════════════════════════

typedef OnChatTapCallback = Future<void> Function(
    String chatId, String senderId);
typedef OnRequestTapCallback = Future<void> Function(
    String requestType, String? profileId, String? vacancyId);

// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentUserId;
  OnChatTapCallback? _onChatTap;
  OnRequestTapCallback? _onRequestTap;

  // Guarda o payload pendente (quando o app abre por notification tap)
  Map<String, dynamic>? _pendingPayload;

  // ── Canal Android para notificações locais ──────────────────────────────
  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_channel',
    'Mensagens de Chat',
    description: 'Notificações de novas mensagens',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _requestChannel =
      AndroidNotificationChannel(
    'request_channel',
    'Solicitações',
    description: 'Notificações de solicitações de chat e candidaturas',
    importance: Importance.high,
    playSound: true,
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  INICIALIZAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    // 1. Permissões
    await _requestPermissions();

    // 2. Inicializar local notifications
    await _initLocalNotifications();

    // 3. Registrar/atualizar FCM token
    await _registerToken(userId);

    // 4. Listeners
    _setupForegroundListener();
    _setupBackgroundTapListener();
    await _checkInitialMessage();

    print('✅ NotificationService inicializado para: $userId');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ATUALIZAR CALLBACKS (chamado no main.dart)
  // ══════════════════════════════════════════════════════════════════════════

  void updateCallbacks({
    OnChatTapCallback? onChatTap,
    OnRequestTapCallback? onRequestTap,
  }) {
    _onChatTap = onChatTap;
    _onRequestTap = onRequestTap;

    // Se houver payload pendente (app abriu via notificação), processa agora
    if (_pendingPayload != null) {
      print('🔔 Processando payload pendente...');
      _handleNotificationTap(_pendingPayload!);
      _pendingPayload = null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERMISSÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('🔑 Permissão: ${settings.authorizationStatus}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL NOTIFICATIONS SETUP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Criar canais Android
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<local_notifications.AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_chatChannel);
        await androidPlugin.createNotificationChannel(_requestChannel);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FCM TOKEN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _registerToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseDatabase.instance
            .ref('Users/$userId/fcmToken')
            .set(token);
        print('✅ FCM token registrado: ${token.substring(0, 30)}...');
      }

      // Listener para refresh de token
      _messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseDatabase.instance
            .ref('Users/$userId/fcmToken')
            .set(newToken);
        print('🔄 FCM token atualizado');
      });
    } catch (e) {
      print('❌ Erro ao registrar token: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FOREGROUND LISTENER
  //
  //  Quando o app está aberto e recebe uma notificação, mostra
  //  uma local notification para o usuário poder tocar.
  // ══════════════════════════════════════════════════════════════════════════

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 [FG] Mensagem recebida: ${message.data}');

      final data = message.data;
      final type = data['type'] ?? '';

      final title = data['notificationTitle'] ?? 'Nova notificação';
      final body = data['notificationBody'] ?? '';
      final tag = data['notificationTag'] ?? data['chatId'] ?? type;

      _showLocalNotification(
        title: title,
        body: body,
        payload: jsonEncode(data),
        tag: tag,
        channelId: type == 'chat' ? _chatChannel.id : _requestChannel.id,
        channelName: type == 'chat' ? _chatChannel.name : _requestChannel.name,
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BACKGROUND TAP LISTENER
  //
  //  Quando o usuário toca em uma notificação com o app em background.
  // ══════════════════════════════════════════════════════════════════════════

  void _setupBackgroundTapListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 [BG TAP] Notificação tocada: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INITIAL MESSAGE (app estava terminado)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print(
          '🚀 [TERMINATED] App abriu por notificação: ${initialMessage.data}');

      // Se os callbacks já estão configurados, processa imediatamente
      if (_onChatTap != null || _onRequestTap != null) {
        _handleNotificationTap(initialMessage.data);
      } else {
        // Guarda para processar quando os callbacks forem registrados
        _pendingPayload = initialMessage.data;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL NOTIFICATION TAP
  //
  //  Quando o usuário toca na notificação local (foreground).
  // ══════════════════════════════════════════════════════════════════════════

  void _onLocalNotificationTap(NotificationResponse response) {
    print('🔔 [LOCAL TAP] payload: ${response.payload}');

    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNotificationTap(data);
    } catch (e) {
      print('❌ Erro ao parsear payload local: $e');
    }
  }

  Future<void> dismissChatNotifications(String chatId) async {
    try {
      debugPrint('🧹 Fechando notificações do chat: $chatId');

      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<local_notifications.AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          await androidPlugin.cancel(chatId.hashCode, tag: chatId);
        }
      }

      await _localNotifications.cancel(chatId.hashCode);

      debugPrint('✅ Notificações do chat $chatId removidas');
    } catch (e) {
      debugPrint('❌ Erro ao fechar notificações: $e');
    }
  }

  Future<void> removeToken(String userId) async {
    try {
      await FirebaseDatabase.instance.ref('Users/$userId/fcmToken').remove();
      debugPrint('🗑️ Token FCM removido');
    } catch (e) {
      debugPrint('❌ Erro ao remover token: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';

    print('🎯 Roteando notificação | type=$type');

    switch (type) {
      case 'chat':
      case 'chat_accepted':
        final chatId = data['chatId']?.toString() ?? '';
        final senderId = data['senderId']?.toString() ?? '';

        if (chatId.isNotEmpty && _onChatTap != null) {
          print('→ onChatTap($chatId, $senderId)');
          _onChatTap!(chatId, senderId);
        } else {
          print('⚠️ chatId vazio ou callback não registrado');
        }
        break;

      case 'request':
        // Solicitação de chat em perfil profissional (worker recebe)
        final requestType = data['requestType']?.toString() ?? 'professional';
        final profileId = data['profileId']?.toString() ?? '';
        final vacancyId = data['vacancyId']?.toString() ?? '';

        if (_onRequestTap != null) {
          print('→ onRequestTap($requestType, $profileId, $vacancyId)');
          _onRequestTap!(requestType, profileId, vacancyId);
        }
        break;

      case 'vacancy_request':
        // Candidatura em vaga (contractor recebe)
        final vacancyId = data['vacancyId']?.toString() ?? '';

        if (vacancyId.isNotEmpty && _onRequestTap != null) {
          print('→ onRequestTap(vacancy_request, , $vacancyId)');
          _onRequestTap!('vacancy_request', '', vacancyId);
        } else {
          print('⚠️ vacancyId vazio ou callback não registrado');
        }
        break;

      case 'expiration_warning':
        // Notificação de expiração — não navega, apenas abre o app
        print('ℹ️ Notificação de expiração, sem navegação especial');
        break;

      default:
        print('⚠️ Tipo de notificação desconhecido: $type');
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MOSTRAR LOCAL NOTIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    String? tag,
    required String channelId,
    required String channelName,
  }) async {
    try {
      await _localNotifications.show(
        tag?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            tag: tag,
            groupKey: channelId,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      print('❌ Erro ao mostrar notificação local: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BADGE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> clearBadge() async {
    try {
      // Limpa badge do iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // Limpa notificações locais
      await _localNotifications.cancelAll();

      print('🧹 Badge limpo');
    } catch (e) {
      print('❌ Erro ao limpar badge: $e');
    }
  }
}