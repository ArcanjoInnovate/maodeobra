// lib/models/chat/participant_model.dart

class ParticipantData {
  final String status;
  final int lastSeen;

  bool get isOnline => status == 'online';

  ParticipantData({
    required this.status,
    required this.lastSeen,
  });

  /// Factory que suporta DOIS formatos diferentes do Firebase
  /// 
  /// Formato 1 (ANTIGO - atualmente no banco):
  /// {
  ///   "contractor": "offline",
  ///   "contractor_last_seen": 1234567890,
  ///   "employee": "online",
  ///   "employee_last_seen": 1234567890
  /// }
  /// 
  /// Formato 2 (NOVO - estrutura ideal):
  /// {
  ///   "contractor": {
  ///     "status": "offline",
  ///     "last_seen": 1234567890
  ///   },
  ///   "employee": {
  ///     "status": "online",
  ///     "last_seen": 1234567890
  ///   }
  /// }
  factory ParticipantData.fromMap(Map<dynamic, dynamic> map, String role) {
    // ✅ FORMATO NOVO (aninhado)
    if (map.containsKey(role) && map[role] is Map) {
      final participantData = map[role] as Map<dynamic, dynamic>;
      
      return ParticipantData(
        status: participantData['status'] as String? ?? 'offline',
        lastSeen: participantData['last_seen'] as int? ?? 
                  DateTime.now().millisecondsSinceEpoch,
      );
    }
    
    // ✅ FORMATO ANTIGO (flat)
    // Procura por: "contractor": "offline" e "contractor_last_seen": 123
    final statusKey = role; // "contractor" ou "employee"
    final lastSeenKey = '${role}_last_seen'; // "contractor_last_seen"
    
    if (map.containsKey(statusKey)) {
      final statusValue = map[statusKey];
      final lastSeenValue = map[lastSeenKey];
      
      // Se status for String direto, é o formato antigo
      if (statusValue is String) {
        return ParticipantData(
          status: statusValue,
          lastSeen: lastSeenValue is int 
              ? lastSeenValue 
              : DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    
    // Fallback
    print('⚠️ Formato de participante não reconhecido para $role');
    print('   Dados recebidos: $map');
    
    return ParticipantData(
      status: 'offline',
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Converte para Map (formato NOVO)
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'last_seen': lastSeen,
    };
  }

  /// Cria uma cópia com campos atualizados
  ParticipantData copyWith({
    String? status,
    int? lastSeen,
  }) {
    return ParticipantData(
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() {
    return 'ParticipantData(status: $status, lastSeen: $lastSeen, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantData &&
        other.status == status &&
        other.lastSeen == lastSeen;
  }

  @override
  int get hashCode => status.hashCode ^ lastSeen.hashCode;
}

/// Classe helper para trabalhar com participants
class ParticipantsHelper {
  
  /// Converte formato antigo para novo
  static Map<String, dynamic> convertOldToNewFormat(Map<dynamic, dynamic> oldFormat) {
    return {
      'contractor': {
        'status': oldFormat['contractor'] ?? 'offline',
        'last_seen': oldFormat['contractor_last_seen'] ?? DateTime.now().millisecondsSinceEpoch,
      },
      'employee': {
        'status': oldFormat['employee'] ?? 'offline',
        'last_seen': oldFormat['employee_last_seen'] ?? DateTime.now().millisecondsSinceEpoch,
      },
    };
  }
  
  /// Verifica qual formato está sendo usado
  static bool isOldFormat(Map<dynamic, dynamic> map) {
    // Se contractor for String, é formato antigo
    return map['contractor'] is String || map['employee'] is String;
  }
  
  /// Detecta e retorna o formato
  static String detectFormat(Map<dynamic, dynamic> map) {
    if (isOldFormat(map)) {
      return 'old_flat';
    } else if (map['contractor'] is Map) {
      return 'new_nested';
    } else {
      return 'unknown';
    }
  }
}