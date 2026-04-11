// lib/models/chat/message_model.dart

class Message {
  final String id;
  final String text;
  final String sender;
  final int timestamp;
  final bool readByContractor;
  final bool readByEmployee;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    required this.readByContractor,
    required this.readByEmployee,
  });

  /// Firebase usa snake_case: read_by_contractor / read_by_employee
  factory Message.fromMap(String id, Map<dynamic, dynamic> map) {
    return Message(
      id: id,
      text: map['text'] as String? ?? '',
      sender: map['sender'] as String? ?? '',
      timestamp: map['timestamp'] as int? ?? 0,
      // ✅ lê os campos exatos do banco (snake_case)
      readByContractor: map['read_by_contractor'] as bool? ?? false,
      readByEmployee: map['read_by_employee'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sender': sender,
      'timestamp': timestamp,
      // ✅ salva em snake_case igual ao banco
      'read_by_contractor': readByContractor,
      'read_by_employee': readByEmployee,
    };
  }

  Message copyWith({
    String? id,
    String? text,
    String? sender,
    int? timestamp,
    bool? readByContractor,
    bool? readByEmployee,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      readByContractor: readByContractor ?? this.readByContractor,
      readByEmployee: readByEmployee ?? this.readByEmployee,
    );
  }
}