// lib/core/utils/date_utils.dart

import 'package:intl/intl.dart';

class ChatDateUtils {
  /// Formata timestamp para exibição no chat
  /// Exemplos:
  /// - Hoje: "14:30"
  /// - Ontem: "Ontem 14:30"
  /// - Esta semana: "Seg 14:30"
  /// - Mais antigo: "15/01/2026 14:30"
  static String formatMessageTime(int timestamp) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    final timeFormat = DateFormat('HH:mm');
    final time = timeFormat.format(messageDate);

    // Hoje
    if (messageDay == today) {
      return time;
    }

    // Ontem
    if (messageDay == yesterday) {
      return 'Ontem $time';
    }

    // Esta semana (últimos 2 dias)
    final weekAgo = today.subtract(Duration(days: 7));
    if (messageDay.isAfter(weekAgo)) {
      final weekDayFormat = DateFormat('EEE', 'pt_BR');
      final weekDay = weekDayFormat.format(messageDate);
      return '$weekDay $time';
    }

    // Mais antigo
    final dateFormat = DateFormat('dd/MM/yyyy');
    final date = dateFormat.format(messageDate);
    return '$date $time';
  }

  /// Formata para lista de chats (mais compacto)
  /// Exemplos:
  /// - Hoje: "14:30"
  /// - Ontem: "Ontem"
  /// - Esta semana: "Seg"
  /// - Mais antigo: "15/01"
  static String formatChatListTime(int timestamp) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    final timeFormat = DateFormat('HH:mm');

    // Hoje
    if (messageDay == today) {
      return timeFormat.format(messageDate);
    }

    // Ontem
    if (messageDay == yesterday) {
      return 'Ontem';
    }

    // Esta semana
    final weekAgo = today.subtract(Duration(days: 7));
    if (messageDay.isAfter(weekAgo)) {
      final weekDayFormat = DateFormat('EEE', 'pt_BR');
      return weekDayFormat.format(messageDate);
    }

    // Mais antigo
    final dateFormat = DateFormat('dd/MM');
    return dateFormat.format(messageDate);
  }

  /// Formata last_seen para exibir status
  /// Exemplos:
  /// - "Online"
  /// - "Visto há 5 min"
  /// - "Visto há 2 h"
  /// - "Visto ontem"
  static String formatLastSeen(int lastSeen, bool isOnline) {
    if (isOnline) {
      return 'Online';
    }

    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
    final now = DateTime.now();
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes < 1) {
      return 'Visto agora';
    }

    if (difference.inMinutes < 60) {
      return 'Visto há ${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return 'Visto há ${difference.inHours} h';
    }

    if (difference.inDays == 1) {
      return 'Visto ontem';
    }

    if (difference.inDays < 7) {
      return 'Visto há ${difference.inDays} dias';
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    return 'Visto em ${dateFormat.format(lastSeenDate)}';
  }

  /// Formata duração (útil para typing indicator)
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inHours}h';
  }

  /// Verifica se é hoje
  static bool isToday(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Verifica se é ontem
  static bool isYesterday(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Agrupa mensagens por data (para separadores)
  static String getDateSeparator(int timestamp) {
    if (isToday(timestamp)) {
      return 'Hoje';
    }
    if (isYesterday(timestamp)) {
      return 'Ontem';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 7) {
      final weekDayFormat = DateFormat('EEEE', 'pt_BR');
      return weekDayFormat.format(date);
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    return dateFormat.format(date);
  }
}
