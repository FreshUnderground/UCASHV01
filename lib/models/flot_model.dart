/// Modèle pour gérer les FLOTS (approvisionnement de liquidité entre shops)
class FlotModel {
  final int? id;
  final int shopSourceId; // Shop qui envoie la liquidité
  final String shopSourceDesignation;
  final int shopDestinationId; // Shop qui reçoit la liquidité
  final String shopDestinationDesignation;
  final double montant;
  final String devise; // USD, FC, etc.
  final ModePaiement modePaiement;
  final StatutFlot statut;
  final int agentEnvoyeurId; // Agent qui confie le flot
  final String? agentEnvoyeurUsername;
  final int? agentRecepteurId; // Agent qui reçoit le flot
  final String? agentRecepteurUsername;
  final DateTime dateEnvoi;
  final DateTime? dateReception;
  final String? notes;
  final String? reference;
  
  // Métadonnées de synchronisation
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;
  
  /// Obtient la désignation du shop source (avec fallback sur ID)
  String getShopSourceDesignation([List<dynamic>? shops]) {
    if (shopSourceDesignation.isNotEmpty) {
      return shopSourceDesignation;
    }
    
    // Essayer de résoudre depuis la liste des shops si fournie
    if (shops != null) {
      try {
        final shop = shops.firstWhere(
          (s) => s.id == shopSourceId,
          orElse: () => null,
        );
        if (shop != null && shop.designation != null && shop.designation.isNotEmpty) {
          return shop.designation;
        }
      } catch (e) {
        // Ignorer l'erreur
      }
    }
    
    return 'Shop #$shopSourceId';
  }
  
  /// Obtient la désignation du shop destination (avec fallback sur ID)
  String getShopDestinationDesignation([List<dynamic>? shops]) {
    if (shopDestinationDesignation.isNotEmpty) {
      return shopDestinationDesignation;
    }
    
    // Essayer de résoudre depuis la liste des shops si fournie
    if (shops != null) {
      try {
        final shop = shops.firstWhere(
          (s) => s.id == shopDestinationId,
          orElse: () => null,
        );
        if (shop != null && shop.designation != null && shop.designation.isNotEmpty) {
          return shop.designation;
        }
      } catch (e) {
        // Ignorer l'erreur
      }
    }
    
    return 'Shop #$shopDestinationId';
  }

  FlotModel({
    this.id,
    required this.shopSourceId,
    required this.shopSourceDesignation,
    required this.shopDestinationId,
    required this.shopDestinationDesignation,
    required this.montant,
    this.devise = 'USD',
    required this.modePaiement,
    this.statut = StatutFlot.enRoute,
    required this.agentEnvoyeurId,
    this.agentEnvoyeurUsername,
    this.agentRecepteurId,
    this.agentRecepteurUsername,
    required this.dateEnvoi,
    this.dateReception,
    this.notes,
    this.reference,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  factory FlotModel.fromJson(Map<String, dynamic> json) {
    return FlotModel(
      id: json['id'] as int?,
      shopSourceId: json['shop_source_id'] as int,
      shopSourceDesignation: json['shop_source_designation'] as String? ?? '',
      shopDestinationId: json['shop_destination_id'] as int,
      shopDestinationDesignation: json['shop_destination_designation'] as String? ?? '',
      montant: (json['montant'] as num).toDouble(),
      devise: json['devise'] as String? ?? 'USD',
      modePaiement: _parseModePaiement(json['mode_paiement']),
      statut: _parseStatutFlot(json['statut']),
      agentEnvoyeurId: json['agent_envoyeur_id'] as int,
      agentEnvoyeurUsername: json['agent_envoyeur_username'] as String?,
      agentRecepteurId: json['agent_recepteur_id'] as int?,
      agentRecepteurUsername: json['agent_recepteur_username'] as String?,
      dateEnvoi: DateTime.parse(json['date_envoi'] as String),
      dateReception: json['date_reception'] != null 
          ? DateTime.parse(json['date_reception'] as String)
          : null,
      notes: json['notes'] as String?,
      reference: json['reference'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: (json['is_synced'] == 1 || json['is_synced'] == true),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_source_id': shopSourceId,
      'shop_source_designation': shopSourceDesignation,
      'shop_destination_id': shopDestinationId,
      'shop_destination_designation': shopDestinationDesignation,
      'montant': montant,
      'devise': devise,
      'mode_paiement': modePaiement.index,
      'statut': statut.index,
      'agent_envoyeur_id': agentEnvoyeurId,
      'agent_envoyeur_username': agentEnvoyeurUsername,
      'agent_recepteur_id': agentRecepteurId,
      'agent_recepteur_username': agentRecepteurUsername,
      'date_envoi': dateEnvoi.toIso8601String(),
      'date_reception': dateReception?.toIso8601String(),
      'notes': notes,
      'reference': reference,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'last_modified_at': (lastModifiedAt ?? DateTime.now()).toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  static ModePaiement _parseModePaiement(dynamic value) {
    if (value == null) return ModePaiement.cash;
    
    if (value is int) {
      if (value >= 0 && value < ModePaiement.values.length) {
        return ModePaiement.values[value];
      }
      return ModePaiement.cash;
    }
    
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'cash':
          return ModePaiement.cash;
        case 'airtelmoney':
          return ModePaiement.airtelMoney;
        case 'mpesa':
          return ModePaiement.mPesa;
        case 'orangemoney':
          return ModePaiement.orangeMoney;
        default:
          return ModePaiement.cash;
      }
    }
    
    return ModePaiement.cash;
  }

  static StatutFlot _parseStatutFlot(dynamic value) {
    if (value == null) return StatutFlot.enRoute;
    
    if (value is int) {
      if (value >= 0 && value < StatutFlot.values.length) {
        return StatutFlot.values[value];
      }
      return StatutFlot.enRoute;
    }
    
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'enroute':
        case 'en_route':
          return StatutFlot.enRoute;
        case 'servi':
          return StatutFlot.servi;
        case 'annule':
          return StatutFlot.annule;
        default:
          return StatutFlot.enRoute;
      }
    }
    
    return StatutFlot.enRoute;
  }

  FlotModel copyWith({
    int? id,
    int? shopSourceId,
    String? shopSourceDesignation,
    int? shopDestinationId,
    String? shopDestinationDesignation,
    double? montant,
    String? devise,
    ModePaiement? modePaiement,
    StatutFlot? statut,
    int? agentEnvoyeurId,
    String? agentEnvoyeurUsername,
    int? agentRecepteurId,
    String? agentRecepteurUsername,
    DateTime? dateEnvoi,
    DateTime? dateReception,
    String? notes,
    String? reference,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return FlotModel(
      id: id ?? this.id,
      shopSourceId: shopSourceId ?? this.shopSourceId,
      shopSourceDesignation: shopSourceDesignation ?? this.shopSourceDesignation,
      shopDestinationId: shopDestinationId ?? this.shopDestinationId,
      shopDestinationDesignation: shopDestinationDesignation ?? this.shopDestinationDesignation,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      modePaiement: modePaiement ?? this.modePaiement,
      statut: statut ?? this.statut,
      agentEnvoyeurId: agentEnvoyeurId ?? this.agentEnvoyeurId,
      agentEnvoyeurUsername: agentEnvoyeurUsername ?? this.agentEnvoyeurUsername,
      agentRecepteurId: agentRecepteurId ?? this.agentRecepteurId,
      agentRecepteurUsername: agentRecepteurUsername ?? this.agentRecepteurUsername,
      dateEnvoi: dateEnvoi ?? this.dateEnvoi,
      dateReception: dateReception ?? this.dateReception,
      notes: notes ?? this.notes,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  String get statutLabel {
    switch (statut) {
      case StatutFlot.enRoute:
        return 'En Route';
      case StatutFlot.servi:
        return 'Servi';
      case StatutFlot.annule:
        return 'Annulé';
    }
  }
}

/// Statut d'un flot
enum StatutFlot {
  enRoute,  // Le flot est en cours (liquidité confiée mais pas encore reçue)
  servi,    // Le flot a été reçu par le shop destination
  annule,   // Le flot a été annulé
}

/// Mode de paiement (réutilisation de l'enum existant)
enum ModePaiement {
  cash,
  airtelMoney,
  mPesa,
  orangeMoney,
}
