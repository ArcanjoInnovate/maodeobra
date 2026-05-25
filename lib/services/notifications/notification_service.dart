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
  debugPrint('📩 [BG] Mensagem recebida: ${message.data}');
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
 
  // Payload salvo quando _onLocalNotificationTap dispara antes dos callbacks
  // estarem registrados (cold start com app terminado).
  // Consumido por processInitialMessage() no main.dart.
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
    await _requestPermissions();
    await _initLocalNotifications();
    await _registerToken(userId);
    _setupForegroundListener();
    _setupBackgroundTapListener();
    debugPrint('✅ NotificationService inicializado para: $userId');
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  ATUALIZAR CALLBACKS
  //
  //  FIX: NÃO processa _pendingPayload automaticamente aqui.
  //  Processar aqui causaria navegação antes da HomeScreen existir na árvore.
  //  O payload pendente é consumido via consumePendingPayload() chamado por
  //  processInitialMessage() no main.dart, após endOfFrame garantir que a
  //  HomeScreen já está montada.
  // ══════════════════════════════════════════════════════════════════════════
 
  void updateCallbacks({
    OnChatTapCallback? onChatTap,
    OnRequestTapCallback? onRequestTap,
  }) {
    _onChatTap = onChatTap;
    _onRequestTap = onRequestTap;
    debugPrint('🔔 Callbacks atualizados (pendingPayload=${_pendingPayload != null})');
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  consumePendingPayload
  //
  //  Retorna o payload salvo pelo _onLocalNotificationTap quando os callbacks
  //  ainda eram null, e limpa o campo (consume uma única vez).
  //  Retorna null se não houver payload pendente.
  //
  //  Chamado por processInitialMessage() em main.dart.
  // ══════════════════════════════════════════════════════════════════════════
 
  Map<String, dynamic>? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    if (payload != null) {
      debugPrint('📦 consumePendingPayload: $payload');
    }
    return payload;
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
    debugPrint('🔑 Permissão: ${settings.authorizationStatus}');
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
        debugPrint('✅ FCM token registrado: ${token.substring(0, 30)}...');
      }
 
      _messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseDatabase.instance
            .ref('Users/$userId/fcmToken')
            .set(newToken);
        debugPrint('🔄 FCM token atualizado');
      });
    } catch (e) {
      debugPrint('❌ Erro ao registrar token: $e');
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  FOREGROUND LISTENER
  // ══════════════════════════════════════════════════════════════════════════
 
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 [FG] Mensagem recebida: ${message.data}');
 
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
  // ══════════════════════════════════════════════════════════════════════════
 
  void _setupBackgroundTapListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [BG TAP] Notificação tocada: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  INITIAL MESSAGE (app estava terminado) — mantido para referência
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          '🚀 [TERMINATED] App abriu por notificação: ${initialMessage.data}');
 
      if (_onChatTap != null || _onRequestTap != null) {
        _handleNotificationTap(initialMessage.data);
      } else {
        _pendingPayload = initialMessage.data;
      }
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL NOTIFICATION TAP
  //
  //  FIX: Este callback dispara durante _initLocalNotifications() quando o
  //  app foi aberto pelo tap em uma notificação local com o app terminado.
  //  Nesse momento _onChatTap e _onRequestTap ainda são null.
  //  _handleNotificationTap detecta isso e salva em _pendingPayload em vez
  //  de descartar o payload silenciosamente (era o bug original).
  // ══════════════════════════════════════════════════════════════════════════
 
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 [LOCAL TAP] payload: ${response.payload}');
 
    if (response.payload == null || response.payload!.isEmpty) return;
 
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNotificationTap(data);
    } catch (e) {
      debugPrint('❌ Erro ao parsear payload local: $e');
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  _handleNotificationTap
  //
  //  FIX: Quando os callbacks ainda não foram registrados (cold start),
  //  salva o payload em _pendingPayload em vez de descartá-lo.
  //  Será consumido por processInitialMessage() no main.dart após a
  //  HomeScreen montar e os callbacks estarem prontos.
  // ══════════════════════════════════════════════════════════════════════════
 
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
 
    debugPrint('🎯 Roteando notificação | type=$type');
 
    if (_onChatTap == null && _onRequestTap == null) {
      debugPrint('⏳ Callbacks não registrados — salvando payload como pendente');
      _pendingPayload = data;
      return;
    }
 
    switch (type) {
      case 'chat':
      case 'chat_accepted':
        final chatId = data['chatId']?.toString() ?? '';
        final senderId = data['senderId']?.toString() ?? '';
 
        if (chatId.isNotEmpty && _onChatTap != null) {
          debugPrint('→ onChatTap($chatId, $senderId)');
          _onChatTap!(chatId, senderId);
        } else {
          debugPrint('⚠️ chatId vazio ou callback não registrado');
        }
        break;
 
      case 'request':
        final requestType = data['requestType']?.toString() ?? 'professional';
        final profileId = data['profileId']?.toString() ?? '';
        final vacancyId = data['vacancyId']?.toString() ?? '';
 
        if (_onRequestTap != null) {
          debugPrint('→ onRequestTap($requestType, $profileId, $vacancyId)');
          _onRequestTap!(requestType, profileId, vacancyId);
        }
        break;
 
      case 'vacancy_request':
        final vacancyId = data['vacancyId']?.toString() ?? '';
 
        if (vacancyId.isNotEmpty && _onRequestTap != null) {
          debugPrint('→ onRequestTap(vacancy_request, , $vacancyId)');
          _onRequestTap!('vacancy_request', '', vacancyId);
        } else {
          debugPrint('⚠️ vacancyId vazio ou callback não registrado');
        }
        break;
 
      case 'expiration_warning':
        debugPrint('ℹ️ Notificação de expiração, sem navegação especial');
        break;
 
      default:
        debugPrint('⚠️ Tipo de notificação desconhecido: $type');
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
      debugPrint('❌ Erro ao mostrar notificação local: $e');
    }
  }
 
  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITÁRIOS
  // ══════════════════════════════════════════════════════════════════════════
 
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
 
  // ══════════════════════════════════════════════════════════════════════════
  //  BADGE
  // ══════════════════════════════════════════════════════════════════════════
 
  Future<void> clearBadge() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
 
      await _localNotifications.cancelAll();
      debugPrint('🧹 Badge limpo');
    } catch (e) {
      debugPrint('❌ Erro ao limpar badge: $e');
    }
  }
}