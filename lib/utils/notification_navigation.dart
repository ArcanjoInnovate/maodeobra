// lib/utils/notification_navigation_helper.dart

import 'package:flutter/material.dart';

class NotificationNavigationHelper {
  static void handleNotification(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
    Function(int) setTabIndex,
  ) {
    switch (type) {
      case 'chat':
      case 'chat_accepted':
        // Navega para chats (índice 2)
        debugPrint('📱 Navegando para Chats');
        setTabIndex(2);
        break;

      case 'chat_request':
      case 'request':
        // Navega para vagas (índice 3)
        debugPrint('📱 Navegando para Vagas');
        setTabIndex(3);
        break;

      case 'expiration_warning':
        // Navega para vagas também (é onde está o perfil profissional)
        debugPrint('📱 Navegando para Vagas (expiração)');
        setTabIndex(3);
        break;

      default:
        debugPrint('⚠️ Tipo de notificação desconhecido: $type');
    }
  }
}