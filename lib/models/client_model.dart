class ClientModel {
  final int? id;
  final String nom;
  final String telephone;
  final String? adresse;
  final String? username;
  final String? password;
  final String? numeroCompte; // Champ legacy - utilisé pour compatibilité DB
  final int? shopId;  // Changé de int à int? pour permettre null
  final double solde; // Solde du compte client (devise principale USD)
  final double? soldeDevise2; // Solde en devise secondaire (CDF/UGX)
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool? isSynced;
  final DateTime? syncedAt;

  // Getter pour formater l'ID comme numéro de compte
  String get numeroCompteFormate {
    if (id == null) return 'N/A';
    return 'CL${id.toString().padLeft(6, '0')}';
  }

  ClientModel({
    this.id,
    required this.nom,
    required this.telephone,
    this.adresse,
    this.username,
    this.password,
    this.numeroCompte, // Nouveau champ
    this.shopId,  // Changé de required int à int?
    this.solde = 0.0,
    this.soldeDevise2,
    this.isActive = true,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    // Support des deux formats: camelCase (serveur) et snake_case (local)
    final shopIdValue = json['shopId'] ?? json['shop_id'];
    
    // Handle ID parsing more robustly
    int? parseId(dynamic idValue) {
      if (idValue == null) return null;
      if (idValue is int) return idValue;
      if (idValue is String) return int.tryParse(idValue);
      return null;
    }
    
    return ClientModel(
      id: parseId(json['id']),
      nom: json['nom'] ?? '',
      telephone: json['telephone']?.toString() ?? '',
      adresse: json['adresse'],
      username: json['username'],
      password: json['password'],
      numeroCompte: json['numero_compte'], // Nouveau champ
      shopId: parseId(shopIdValue),  // Permettre null
      solde: json['solde']?.toDouble() ?? 0.0,
      soldeDevise2: json['solde_devise2']?.toDouble(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : 
                (json['created_at'] != null ? DateTime.parse(json['created_at']) : null),
      lastModifiedAt: json['lastModifiedAt'] != null ? DateTime.parse(json['lastModifiedAt']) : 
                      (json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null),
      lastModifiedBy: json['lastModifiedBy']?.toString() ?? json['last_modified_by']?.toString(),
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt']) : 
               (json['synced_at'] != null ? DateTime.parse(json['synced_at']) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'telephone': telephone.toString(),
      'adresse': adresse,
      'username': username,
      'password': password,
      'numero_compte': numeroCompte, // Nouveau champ
      'shop_id': shopId,  // Permettre null
      'solde': solde,
      'solde_devise2': soldeDevise2,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'last_modified_at': lastModifiedAt?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced == true ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  ClientModel copyWith({
    int? id,
    String? nom,
    String? telephone,
    String? adresse,
    String? username,
    String? password,
    String? numeroCompte, // Nouveau champ
    int? shopId,
    double? solde,
    double? soldeDevise2,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      username: username ?? this.username,
      password: password ?? this.password,
      numeroCompte: numeroCompte ?? this.numeroCompte, // Nouveau champ
      shopId: shopId ?? this.shopId,
      solde: solde ?? this.solde,
      soldeDevise2: soldeDevise2 ?? this.soldeDevise2,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}