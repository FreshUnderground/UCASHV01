class AgentModel {
  final int? id;
  final String username;
  final String password;
  final int shopId;
  final String? nom;
  final String? telephone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  AgentModel({
    this.id,
    required this.username,
    required this.password,
    required this.shopId,
    this.nom,
    this.telephone,
    this.isActive = true,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      shopId: json['shop_id'] ?? json['shopId'], // Support des deux formats
      nom: json['nom'],
      telephone: json['telephone'],
      isActive: json['is_active'] == 1 || json['isActive'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'shop_id': shopId,
      'nom': nom,
      'telephone': telephone,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'last_modified_at': lastModifiedAt?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'last_modified_by': lastModifiedBy,
    };
  }

  AgentModel copyWith({
    int? id,
    String? username,
    String? password,
    int? shopId,
    String? nom,
    String? telephone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return AgentModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      shopId: shopId ?? this.shopId,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }
}
