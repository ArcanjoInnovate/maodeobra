class UserModel {
  final String localId;
  final String userName;
  final String email;
  final String contactEmail;
  final String legalType;
  final String phone;
  final String city;
  final String state;
  final int age;
  final String avatar;
  final bool finishedBasic;
  final bool finishedContact;
  final bool finishedProfessional;
  final bool isActive;
  final String activeMode;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;
  final Map<String, dynamic> suspension;
  final Map<String, dynamic> warning;
  final Map<String, dynamic>? ban;
  final List<String> blockedUsers;

  const UserModel({
    required this.localId,
    required this.userName,
    required this.email,
    required this.contactEmail,
    required this.legalType,
    required this.phone,
    required this.city,
    required this.state,
    required this.age,
    required this.avatar,
    required this.finishedBasic,
    required this.finishedContact,
    required this.finishedProfessional,
    required this.isActive,
    required this.activeMode,
    required this.dataWorker,
    required this.dataContractor,
    required this.suspension,
    required this.warning,
    required this.blockedUsers,
    this.ban,
  });

  /// Constrói um [UserModel] a partir do Map retornado pelo Firebase Realtime Database.
  /// [localId] deve ser passado separadamente pois é a chave do nó, não um campo interno.
  factory UserModel.fromMap(String localId, Map<dynamic, dynamic> map) {
    int parsedAge = 0;
    final rawAge = map['age'];
    if (rawAge is int) {
      parsedAge = rawAge;
    } else if (rawAge != null) {
      parsedAge = int.tryParse(rawAge.toString()) ?? 0;
    }

    return UserModel(
      localId: localId,
      blockedUsers: map['blocked_users'] != null
          ? List<String>.from(map['blocked_users'] as List)
          : [],
      userName: map['Name'] ?? map['userName'] ?? '',
      email: map['email'] ?? '',
      contactEmail: map['email_contact'] ?? map['contact_email'] ?? '',
      legalType: map['legalType'] ?? 'PF',
      phone: map['telefone'] ?? map['userPhone'] ?? '',
      city: map['city'] ?? map['userCity'] ?? '',
      state: map['state'] ?? map['userState'] ?? '',
      age: parsedAge,
      avatar: map['avatar'] ?? map['userAvatar'] ?? '',
      finishedBasic: map['finished_basic'] ?? false,
      finishedContact: map['finished_contact'] ?? false,
      finishedProfessional: map['finished_professional'] ?? false,
      isActive: map['isActive'] ?? false,
      activeMode: (map['activeMode'] ?? 'worker').toString().isEmpty
          ? 'worker'
          : map['activeMode'],
      dataWorker: map['data_worker'] != null
          ? Map<String, dynamic>.from(map['data_worker'] as Map)
          : {},
      dataContractor: map['data_contractor'] != null
          ? Map<String, dynamic>.from(map['data_contractor'] as Map)
          : {},
      suspension: map['suspension'] != null
          ? Map<String, dynamic>.from(map['suspension'] as Map)
          : {},
      warning: map['warning'] != null
          ? Map<String, dynamic>.from(map['warning'] as Map)
          : {},
      ban: map['ban'] != null
          ? Map<String, dynamic>.from(map['ban'] as Map)
          : null,
    );
  }

  /// Retorna true se o usuário possui uma suspensão ativa (campos não-vazios).
  bool get isSuspended {
    final end = suspension['end']?.toString() ?? '';
    final motive = suspension['motive']?.toString() ?? '';
    return end.isNotEmpty && motive.isNotEmpty;
  }

  /// Retorna true se o usuário possui uma advertência ativa.
  bool get hasWarning {
    final motive = warning['motive']?.toString() ?? '';
    return motive.isNotEmpty;
  }

  /// Retorna true se o usuário está banido.
  bool get isBanned {
    final motive = ban?['motive']?.toString() ?? '';
    return motive.isNotEmpty;
  }

  /// Calcula os dias restantes de suspensão com base no campo [end] (formato dd/MM/yyyy).
  /// Retorna 0 ou negativo se a suspensão expirou ou o campo estiver vazio.
  int get suspensionDaysRemaining {
    final endStr = suspension['end']?.toString() ?? '';
    if (endStr.isEmpty) return 0;

    try {
      final parts = endStr.split('/');
      if (parts.length != 3) return 0;
      final endDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
        23,
        59,
        59,
      );
      final diff = endDate.difference(DateTime.now()).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  @override
  String toString() => 'UserModel(localId: $localId, userName: $userName)';
}
