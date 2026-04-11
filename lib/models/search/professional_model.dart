// lib/models/search/professional_model.dart

class ProfessionalModel {
  final String id;
  final String avatar;
  final String city;
  final String company;
  final String createdAt;
  final String legalType;
  final String localId;
  final String name;
  final String profession;
  final List<String> skills;
  final String state;
  final String status;
  final String summary;
  final String type;
  final String updatedAt;

  ProfessionalModel({
    required this.id,
    required this.avatar,
    required this.city,
    required this.company,
    required this.createdAt,
    required this.legalType,
    required this.localId,
    required this.name,
    required this.profession,
    required this.skills,
    required this.state,
    required this.status,
    required this.summary,
    required this.type,
    required this.updatedAt,
  });

  // ✅ MÉTODO fromJson (mantido)
  factory ProfessionalModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return ProfessionalModel(
      id: id,
      avatar: json['avatar'] ?? '',
      city: json['city'] ?? '',
      company: json['company'] ?? '',
      createdAt: json['created_at'] ?? '',
      legalType: json['legal_type'] ?? '',
      localId: json['local_id'] ?? '',
      name: json['name'] ?? '',
      profession: json['profession'] ?? '',
      skills: json['skills'] != null 
          ? List<String>.from(json['skills']) 
          : [],
      state: json['state'] ?? '',
      status: json['status'] ?? '',
      summary: json['summary'] ?? '',
      type: json['type'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  // ✅ NOVO: Método fromMap (para compatibilidade com Map<String, dynamic>)
  factory ProfessionalModel.fromMap(Map<String, dynamic> map) {
    return ProfessionalModel(
      id: map['id'] ?? '',
      avatar: map['avatar'] ?? '',
      city: map['city'] ?? '',
      company: map['company'] ?? '',
      createdAt: map['created_at'] ?? map['createdAt'] ?? '',
      legalType: map['legal_type'] ?? map['legalType'] ?? '',
      localId: map['local_id'] ?? map['localId'] ?? '',
      name: map['name'] ?? '',
      profession: map['profession'] ?? '',
      skills: map['skills'] != null 
          ? (map['skills'] is List 
              ? List<String>.from(map['skills']) 
              : <String>[])
          : [],
      state: map['state'] ?? '',
      status: map['status'] ?? '',
      summary: map['summary'] ?? '',
      type: map['type'] ?? '',
      updatedAt: map['updated_at'] ?? map['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar': avatar,
      'city': city,
      'company': company,
      'created_at': createdAt,
      'legal_type': legalType,
      'local_id': localId,
      'name': name,
      'profession': profession,
      'skills': skills,
      'state': state,
      'status': status,
      'summary': summary,
      'type': type,
      'updated_at': updatedAt,
    };
  }

  // ✅ NOVO: Método toMap (alias para toJson)
  Map<String, dynamic> toMap() => toJson();

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
           profession.toLowerCase().contains(q) ||
           company.toLowerCase().contains(q) ||
           skills.any((s) => s.toLowerCase().contains(q));
  }

  // ✅ NOVO: Método copyWith (útil para atualizações)
  ProfessionalModel copyWith({
    String? id,
    String? avatar,
    String? city,
    String? company,
    String? createdAt,
    String? legalType,
    String? localId,
    String? name,
    String? profession,
    List<String>? skills,
    String? state,
    String? status,
    String? summary,
    String? type,
    String? updatedAt,
  }) {
    return ProfessionalModel(
      id: id ?? this.id,
      avatar: avatar ?? this.avatar,
      city: city ?? this.city,
      company: company ?? this.company,
      createdAt: createdAt ?? this.createdAt,
      legalType: legalType ?? this.legalType,
      localId: localId ?? this.localId,
      name: name ?? this.name,
      profession: profession ?? this.profession,
      skills: skills ?? this.skills,
      state: state ?? this.state,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProfessionalModel(id: $id, name: $name, profession: $profession)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ProfessionalModel &&
      other.id == id &&
      other.localId == localId;
  }

  @override
  int get hashCode => id.hashCode ^ localId.hashCode;
}
