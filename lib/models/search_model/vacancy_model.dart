// lib/models/search_model/vacancy_model.dart

class VacancyModel {
  final String id;
  final String city;
  final String company;
  final String createdAt;
  final String description;
  final String emailContact;
  final List<String> images;
  final String legalType;
  final String localId;
  final String phoneContact;
  final String profession;
  final String salary;
  final String salaryType;
  final String state;
  final String status;
  final String title;
  final String type;
  final String updatedAt;
  final String expiresAt; // ✅ ADICIONADO

  VacancyModel({
    required this.id,
    required this.city,
    required this.company,
    required this.createdAt,
    required this.description,
    required this.emailContact,
    required this.images,
    required this.legalType,
    required this.localId,
    required this.phoneContact,
    required this.profession,
    required this.salary,
    required this.salaryType,
    required this.state,
    required this.status,
    required this.title,
    required this.type,
    required this.updatedAt,
    this.expiresAt = '', // ✅ ADICIONADO (opcional com default vazio)
  });

  factory VacancyModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return VacancyModel(
      id: id,
      city: json['city'] ?? '',
      company: json['company'] ?? json['company_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      description: json['description'] ?? '',
      emailContact: json['email_contact'] ?? '',
      images: json['midia']?['images'] != null
          ? List<String>.from(json['midia']['images'])
          : [],
      legalType: json['legal_type'] ?? '',
      localId: json['local_id'] ?? '',
      phoneContact: json['phone_contact'] ?? '',
      profession: json['profession'] ?? '',
      salary: json['salary'] ?? '',
      salaryType: json['salary_type'] ?? '',
      state: json['state'] ?? '',
      status: json['status'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      expiresAt: json['expires_at']?.toString() ?? '', // ✅ ADICIONADO
    );
  }

  factory VacancyModel.fromMap(Map<String, dynamic> map) {
    return VacancyModel(
      id: map['id'] ?? '',
      city: map['city'] ?? '',
      company: map['company'] ?? map['company_name'] ?? '',
      createdAt: map['created_at'] ?? map['createdAt'] ?? '',
      description: map['description'] ?? '',
      emailContact: map['email_contact'] ?? map['emailContact'] ?? '',
      images: map['midia']?['images'] != null
          ? (map['midia']['images'] is List
              ? List<String>.from(map['midia']['images'])
              : <String>[])
          : (map['images'] != null && map['images'] is List
              ? List<String>.from(map['images'])
              : []),
      legalType: map['legal_type'] ?? map['legalType'] ?? '',
      localId: map['local_id'] ?? map['localId'] ?? '',
      phoneContact: map['phone_contact'] ?? map['phoneContact'] ?? '',
      profession: map['profession'] ?? '',
      salary: map['salary'] ?? '',
      salaryType: map['salary_type'] ?? map['salaryType'] ?? '',
      state: map['state'] ?? '',
      status: map['status'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      updatedAt: map['updated_at'] ?? map['updatedAt'] ?? '',
      expiresAt: map['expires_at']?.toString() ?? map['expiresAt']?.toString() ?? '', // ✅ ADICIONADO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city': city,
      'company': company,
      'created_at': createdAt,
      'description': description,
      'email_contact': emailContact,
      'images': images,
      'legal_type': legalType,
      'local_id': localId,
      'phone_contact': phoneContact,
      'profession': profession,
      'salary': salary,
      'salary_type': salaryType,
      'state': state,
      'status': status,
      'title': title,
      'type': type,
      'updated_at': updatedAt,
      'expires_at': expiresAt, // ✅ ADICIONADO
    };
  }

  Map<String, dynamic> toMap() => toJson();

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        profession.toLowerCase().contains(q) ||
        company.toLowerCase().contains(q);
  }

  VacancyModel copyWith({
    String? id,
    String? city,
    String? company,
    String? createdAt,
    String? description,
    String? emailContact,
    List<String>? images,
    String? legalType,
    String? localId,
    String? phoneContact,
    String? profession,
    String? salary,
    String? salaryType,
    String? state,
    String? status,
    String? title,
    String? type,
    String? updatedAt,
    String? expiresAt, // ✅ ADICIONADO
  }) {
    return VacancyModel(
      id: id ?? this.id,
      city: city ?? this.city,
      company: company ?? this.company,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      emailContact: emailContact ?? this.emailContact,
      images: images ?? this.images,
      legalType: legalType ?? this.legalType,
      localId: localId ?? this.localId,
      phoneContact: phoneContact ?? this.phoneContact,
      profession: profession ?? this.profession,
      salary: salary ?? this.salary,
      salaryType: salaryType ?? this.salaryType,
      state: state ?? this.state,
      status: status ?? this.status,
      title: title ?? this.title,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt, // ✅ ADICIONADO
    );
  }

  @override
  String toString() {
    return 'VacancyModel(id: $id, title: $title, profession: $profession, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VacancyModel && other.id == id && other.localId == localId;
  }

  @override
  int get hashCode => id.hashCode ^ localId.hashCode;
}