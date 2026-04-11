// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Handler GLOBAL para notificações em background.
/// IMPORTANTE: Deve estar fora da classe, no top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Mensagem em background: ${message.notification?.title}');
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
    try {
      final token = await _fcm.getToken();

      if (token != null) {
        await FirebaseDatabase.instance
            .ref('Users/$userId/fcmToken')
            .set(token);
        debugPrint('✅ Token FCM salvo: ${token.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ Token FCM não disponível');
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar token FCM: $e');
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
      await FirebaseDatabase.instance
          .ref('Users/$userId/fcmToken')
          .remove();
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
      debugPrint('📬 Mensagem recebida (app aberto): ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // App em BACKGROUND — usuário clica na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notificação clicada (background)');
      _handleNotificationClick(message.data);
    });

    // App estava FECHADO — usuário clica na notificação
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      debugPrint('🔔 App aberto por notificação');
      _handleNotificationClick(message.data);
    }
  }

  // ============================================================
  // EXIBIR NOTIFICAÇÃO LOCAL
  // ============================================================

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? 'Nova mensagem';
      final body = message.notification?.body ?? '';

      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Mensagens de Chat',
        channelDescription: 'Notificações de novas mensagens de chat',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        notificationDetails,
        payload: _encodePayload(message.data),
      );
    } catch (e) {
      debugPrint('❌ Erro ao mostrar notificação local: $e');
    }
  }

  // ============================================================
  // NAVEGAÇÃO AO CLICAR
  // ============================================================

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Notificação local clicada');
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
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
    } else if (type == 'request') {
      final requestType = data['requestType'];
      final profileId = data['profileId'];
      final vacancyId = data['vacancyId'];

      debugPrint('📩 Solicitação | tipo: $requestType | profile: $profileId | vacancy: $vacancyId');

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
      final kv = part.split(':');
      if (kv.length == 2) data[kv[0]] = kv[1];
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