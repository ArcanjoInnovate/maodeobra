// lib/models/chat/chat_model.dart

import 'participant_model.dart';

class Chat {
  final String chatId;
  final String contractorId;
  final String employeeId;
  final bool blockDialog;
  final ChatMetadata metadata;
  final Map<String, ParticipantData> participants;
  final Map<String, int> unreadCount;

  Chat({
    required this.chatId,
    required this.contractorId,
    required this.employeeId,
    required this.blockDialog,
    required this.metadata,
    required this.participants,
    required this.unreadCount,
  });

  /// Factory que suporta AMBOS os formatos de participants
  factory Chat.fromMap(String chatId, Map<dynamic, dynamic> map) {
    try {
      // Parse metadata
      final metadataMap = map['metadata'] as Map<dynamic, dynamic>?;
      final metadata = metadataMap != null
          ? ChatMetadata.fromMap(metadataMap)
          : ChatMetadata.empty();

      // Parse participants (SUPORTA DOIS FORMATOS)
      final participantsMap = map['participants'] as Map<dynamic, dynamic>?;
      final participants = <String, ParticipantData>{};

      if (participantsMap != null) {
        final format = ParticipantsHelper.detectFormat(participantsMap);
        print('📋 Chat $chatId: formato participants = $format');

        if (format == 'old_flat') {
          participants['contractor'] = ParticipantData.fromMap(
            participantsMap,
            'contractor',
          );
          participants['employee'] = ParticipantData.fromMap(
            participantsMap,
            'employee',
          );
        } else if (format == 'new_nested') {
          if (participantsMap['contractor'] is Map) {
            participants['contractor'] = ParticipantData.fromMap(
              participantsMap,
              'contractor',
            );
          }
          if (participantsMap['employee'] is Map) {
            participants['employee'] = ParticipantData.fromMap(
              participantsMap,
              'employee',
            );
          }
        } else {
          print('⚠️ Formato de participants desconhecido no chat $chatId');
        }
      }

      // Parse unreadCount — Firebase retorna num, nunca fazer cast direto para int
      final unreadCountMap = map['unreadCount'] as Map<dynamic, dynamic>?;
      final unreadCount = <String, int>{
        'contractor': unreadCountMap?['contractor'] == null
            ? 0
            : (unreadCountMap!['contractor'] as num).toInt(),
        'employee': unreadCountMap?['employee'] == null
            ? 0
            : (unreadCountMap!['employee'] as num).toInt(),
      };

      return Chat(
        chatId: chatId,
        contractorId: map['contractor'] as String? ?? '',
        employeeId: map['employee'] as String? ?? '',
        blockDialog: map['block_dialog'] as bool? ?? false,
        metadata: metadata,
        participants: participants,
        unreadCount: unreadCount,
      );
    } catch (e) {
      print('❌ Erro ao parsear chat $chatId: $e');
      print('   Dados: $map');
      rethrow;
    }
  }

  /// Converte para Map (usa formato NOVO)
  Map<String, dynamic> toMap() {
    return {
      'contractor': contractorId,
      'employee': employeeId,
      'block_dialog': blockDialog,
      'metadata': metadata.toMap(),
      'participants': {
        'contractor': participants['contractor']?.toMap() ??
            {'status': 'offline', 'last_seen': 0},
        'employee': participants['employee']?.toMap() ??
            {'status': 'offline', 'last_seen': 0},
      },
      'unreadCount': unreadCount,
    };
  }

  /// Cria estrutura inicial do chat (formato NOVO)
  static Map<String, dynamic> createInitialStructure(
    String contractorId,
    String employeeId,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;

    return {
      'contractor': contractorId,
      'employee': employeeId,
      'block_dialog': false,
      'metadata': {
        'created_at': now,
        'last_message': '',
        'last_sender': '',
        'last_timestamp': 0,
      },
      'participants': {
        'contractor': {
          'status': 'offline',
          'last_seen': now,
        },
        'employee': {
          'status': 'offline',
          'last_seen': now,
        },
      },
      'unreadCount': {
        'contractor': 0,
        'employee': 0,
      },
    };
  }

  Chat copyWith({
    String? chatId,
    String? contractorId,
    String? employeeId,
    bool? blockDialog,
    ChatMetadata? metadata,
    Map<String, ParticipantData>? participants,
    Map<String, int>? unreadCount,
  }) {
    return Chat(
      chatId: chatId ?? this.chatId,
      contractorId: contractorId ?? this.contractorId,
      employeeId: employeeId ?? this.employeeId,
      blockDialog: blockDialog ?? this.blockDialog,
      metadata: metadata ?? this.metadata,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatMetadata {
  final String lastMessage;
  final String lastSender;
  final int lastTimestamp;
  final int? createdAt;

  ChatMetadata({
    required this.lastMessage,
    required this.lastSender,
    required this.lastTimestamp,
    this.createdAt,
  });

  factory ChatMetadata.fromMap(Map<dynamic, dynamic> map) {
    return ChatMetadata(
      lastMessage: map['last_message'] as String? ?? '',
      lastSender: map['last_sender'] as String? ?? '',
      // Firebase retorna num, nunca fazer cast direto para int
      lastTimestamp: map['last_timestamp'] == null
          ? 0
          : (map['last_timestamp'] as num).toInt(),
      createdAt: map['created_at'] == null
          ? null
          : (map['created_at'] as num).toInt(),
    );
  }

  factory ChatMetadata.empty() {
    return ChatMetadata(
      lastMessage: '',
      lastSender: '',
      lastTimestamp: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'last_message': lastMessage,
      'last_sender': lastSender,
      'last_timestamp': lastTimestamp,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  ChatMetadata copyWith({
    String? lastMessage,
    String? lastSender,
    int? lastTimestamp,
    int? createdAt,
  }) {
    return ChatMetadata(
      lastMessage: lastMessage ?? this.lastMessage,
      lastSender: lastSender ?? this.lastSender,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}