// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Handler GLOBAL para notificações em background.
/// IMPORTANTE: Deve estar fora da classe, no top-level.
///
/// Como o backend envia mensagens DATA-ONLY (sem bloco "notification"),
/// o Android não exibe nada automaticamente. Este handler recebe os dados
/// e exibe via flutter_local_notifications com tag = chatId,
/// permitindo cancelar todas as notificações de um chat de uma só vez.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Mensagem em background: ${message.data}');

  final data = message.data;
  final type = data['type'];

  // ✅ Trata mensagens de chat (data-only) e outros tipos com notification block
  if (type == 'chat') {
    final chatId = data['notificationTag'] ?? data['chatId'];
    final title = data['notificationTitle'] ?? data['senderName'] ?? 'Nova mensagem';
    final body = data['notificationBody'] ?? '';
    final senderAvatar = data['senderAvatar'] ?? '';

    if (chatId == null) return;

    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await localNotifications.initialize(initSettings);

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Mensagens de Chat',
      channelDescription: 'Notificações de novas mensagens de chat',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      color: const Color(0xFF6B21A8),
      largeIcon: senderAvatar.isNotEmpty
          ? FilePathAndroidBitmap(senderAvatar)
          : null,
      tag: chatId,
      playSound: true,
      enableVibration: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: chatId,
    );

    await localNotifications.show(
      chatId.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload:
          'type:chat|chatId:$chatId|senderId:${data['senderId'] ?? ''}|notificationTag:$chatId',
    );
  }
  // Outros tipos (chat_request, expiration_warning, etc.) têm bloco
  // "notification" no payload, então o sistema exibe automaticamente.
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Callback para navegação de chat (configurado externamente)
  Function(String chatId, String senderId)? onNotificationTap;

  /// Callback para navegação de solicitações (configurado externamente)
  Function(String requestType, String? profileId, String? vacancyId)?
      onRequestNotificationTap;

  // ============================================================
  // INICIALIZAÇÃO PRINCIPAL
  // ============================================================

  Future<void> initialize(String userId) async {
    try {
      debugPrint('🔔 Inicializando serviço de notificações...');

      final settings = await _requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permissão de notificação concedida');

        await _getAndSaveToken(userId);
        await _setupLocalNotifications();
        _setupMessageHandlers();
        _setupTokenRefreshListener(userId);

        debugPrint('✅ Serviço de notificações inicializado com sucesso');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ Permissão de notificação negada pelo usuário');
      } else {
        debugPrint(
            '⚠️ Permissão de notificação: ${settings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao inicializar notificações: $e');
    }
  }

  // ============================================================
  // PERMISSÕES
  // ============================================================

  void updateCallbacks({
    Function(String chatId, String senderId)? onChatTap,
    Function(String requestType, String? profileId, String? vacancyId)? onRequestTap,
  }) {
    if (onChatTap != null) onNotificationTap = onChatTap;
    if (onRequestTap != null) onRequestNotificationTap = onRequestTap;
    debugPrint('🔄 Callbacks de notificação atualizados');
  }
  Future<NotificationSettings> _requestPermission() async {
    return await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
  }

  Future<bool> hasPermission() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // ============================================================
  // TOKEN FCM
  // ============================================================

  Future<void> _getAndSaveToken(String userId) async {
    final token = await _fcm.getToken(); // ✅ Pega token iOS também
    
    if (token != null) {
      await FirebaseDatabase.instance
          .ref('Users/$userId/fcmToken')  // ✅ Salva iOS também!
          .set(token);
    }
  }

  void _setupTokenRefreshListener(String userId) {
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 Token FCM atualizado');
      FirebaseDatabase.instance.ref('Users/$userId/fcmToken').set(newToken);
    });
  }

  /// Remove token do Firebase (chamar no logout)
  Future<void> removeToken(String userId) async {
    try {
      await FirebaseDatabase.instance.ref('Users/$userId/fcmToken').remove();
      debugPrint('🗑️ Token FCM removido');
    } catch (e) {
      debugPrint('❌ Erro ao remover token: $e');
    }
  }

  // ============================================================
  // NOTIFICAÇÕES LOCAIS
  // ============================================================

  Future<void> _setupLocalNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages',
      'Mensagens de Chat',
      description: 'Notificações de novas mensagens de chat',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    debugPrint('✅ Notificações locais configuradas');
  }

  // ============================================================
  // HANDLERS DE MENSAGENS
  // ============================================================

  void _setupMessageHandlers() {
    // App em FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Mensagem recebida (foreground): ${message.data}');
      _showLocalNotification(message);
    });

    // App em BACKGROUND — usuário clica na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notificação clicada (background)');
      final chatId = message.data['chatId'] ?? message.data['notificationTag'];
      if (chatId != null) {
        dismissChatNotifications(chatId);
      }
      _handleNotificationClick(message.data);
    });

    // App estava FECHADO — usuário clica na notificação
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      debugPrint('🔔 App aberto por notificação');
      final chatId = message.data['chatId'] ?? message.data['notificationTag'];
      if (chatId != null) {
        await dismissChatNotifications(chatId);
      }
      _handleNotificationClick(message.data);
    }
  }

  // ============================================================
  // EXIBIR NOTIFICAÇÃO LOCAL (FOREGROUND)
  // ✅ Lê do campo data primeiro (mensagens data-only de chat)
  // ✅ Cai no notification block como fallback (outros tipos)
  // ============================================================

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;

      // ✅ Lê do data primeiro — mensagens de chat são data-only
      final title = data['notificationTitle'] ??
          data['senderName'] ??
          message.notification?.title ??
          'Nova mensagem';
      final body = data['notificationBody'] ??
          message.notification?.body ??
          '';

      final chatId = data['notificationTag'] ?? data['chatId'];
      final senderAvatar = data['senderAvatar'] ?? '';

      final notificationId =
          chatId != null ? chatId.hashCode : message.hashCode;

      final BigPictureStyleInformation? bigPictureStyle =
          senderAvatar.isNotEmpty
              ? BigPictureStyleInformation(
                  FilePathAndroidBitmap(senderAvatar),
                  largeIcon: FilePathAndroidBitmap(senderAvatar),
                  contentTitle: title,
                  summaryText: body,
                  hideExpandedLargeIcon: false,
                )
              : null;

      final MessagingStyleInformation? messagingStyle =
          bigPictureStyle == null
              ? MessagingStyleInformation(
                  Person(name: title, important: true),
                  groupConversation: false,
                  messages: [
                    Message(body, DateTime.now(), Person(name: title)),
                  ],
                )
              : null;

      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Mensagens de Chat',
        channelDescription: 'Notificações de novas mensagens de chat',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF6B21A8),
        largeIcon: senderAvatar.isNotEmpty
            ? FilePathAndroidBitmap(senderAvatar)
            : null,
        styleInformation: bigPictureStyle ?? messagingStyle,
        tag: chatId,
        playSound: true,
        enableVibration: true,
      );

      final iosDetailsWithThread = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: chatId ?? '',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetailsWithThread,
      );

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: _encodePayload(data),
      );
    } catch (e) {
      debugPrint('❌ Erro ao mostrar notificação local: $e');
    }
  }

  // ============================================================
  // FECHAR NOTIFICAÇÕES DE UM CHAT ESPECÍFICO
  // ============================================================

  Future<void> dismissChatNotifications(String chatId) async {
    try {
      debugPrint('🧹 Fechando notificações do chat: $chatId');

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.cancel(chatId.hashCode, tag: chatId);
      }

      await _localNotifications.cancel(chatId.hashCode);

      debugPrint('✅ Notificações do chat $chatId removidas');
    } catch (e) {
      debugPrint('❌ Erro ao fechar notificações: $e');
    }
  }

  /// Fecha TODAS as notificações do app (usar no logout ou clearAll)
  Future<void> dismissAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('🧹 Todas as notificações removidas');
  }

  // ============================================================
  // NAVEGAÇÃO AO CLICAR
  // ============================================================

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Notificação local clicada');
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);

      final chatId = data['chatId'] ?? data['notificationTag'];
      if (chatId != null) {
        dismissChatNotifications(chatId);
      }

      _handleNotificationClick(data);
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint('📱 Tipo de notificação: $type | Data: $data');

    if (type == 'chat') {
      final chatId = data['chatId'];
      final senderId = data['senderId'];

      if (chatId != null && onNotificationTap != null) {
        debugPrint('✅ Abrindo chat: $chatId');
        onNotificationTap!(chatId, senderId ?? '');
      } else {
        debugPrint('⚠️ Callback de navegação não configurado');
      }
    } else if (type == 'request' || type == 'chat_request') {
      final requestType = data['requestType'];
      final profileId = data['profileId'];
      final vacancyId = data['vacancyId'];

      debugPrint(
          '📩 Solicitação | tipo: $requestType | profile: $profileId | vacancy: $vacancyId');

      if (onRequestNotificationTap != null) {
        debugPrint('✅ Abrindo tela de solicitações');
        onRequestNotificationTap!(requestType, profileId, vacancyId);
      } else {
        debugPrint('⚠️ Callback de requests não configurado');
      }
    }
  }

  // ============================================================
  // HELPERS DE PAYLOAD
  // ============================================================

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final Map<String, dynamic> data = {};
    for (final part in payload.split('|')) {
      final idx = part.indexOf(':');
      if (idx != -1) {
        data[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }
    return data;
  }

  // ============================================================
  // BADGE (iOS)
  // ============================================================

  Future<void> setBadgeCount(int count) async {
    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔢 Badge count atualizado: $count');
    } catch (e) {
      debugPrint('⚠️ Erro ao atualizar badge: $e');
    }
  }

  Future<void> clearBadge() async => setBadgeCount(0);

  // ============================================================
  // LIMPEZA
  // ============================================================

  void dispose() {
    debugPrint('🧹 NotificationService disposed');
  }
}