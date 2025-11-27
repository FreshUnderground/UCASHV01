class UserModel {
  final int? id;
  final String username;
  final String password;
  final String role;
  final int? shopId;
  final String? nom;
  final String? adresse;
  final String? telephone;
  final double? solde;
  final String? devise;
  final int? createdBy;
  final DateTime? createdAt;

  UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.shopId,
    this.nom,
    this.adresse,
    this.telephone,
    this.solde,
    this.devise,
    this.createdBy,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? 'AGENT',
      shopId: json['shop_id'],
      nom: json['nom'],
      adresse: json['adresse'],
      telephone: json['telephone'],
      solde: json['solde']?.toDouble(),
      devise: json['devise'],
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'shop_id': shopId,
      'nom': nom,
      'adresse': adresse,
      'telephone': telephone,
      'solde': solde,
      'devise': devise,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    int? shopId,
    String? nom,
    String? adresse,
    String? telephone,
    double? solde,
    String? devise,
    int? createdBy,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      nom: nom ?? this.nom,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      solde: solde ?? this.solde,
      devise: devise ?? this.devise,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Vérifie si l'utilisateur est administrateur
  bool get isAdmin => role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'ADMINISTRATEUR';

  /// Vérifie si l'utilisateur est agent
  bool get isAgent => role.toUpperCase() == 'AGENT';
}
