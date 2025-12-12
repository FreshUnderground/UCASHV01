import '../models/billetage_model.dart';

enum OperationType {
  transfertNational,
  transfertInternationalSortant,
  transfertInternationalEntrant,
  depot,
  retrait,
  virement,
  retraitMobileMoney, // Retrait Mobile Money (Cash-Out)
  flotShopToShop, // FLOT: Transfert de liquidité entre shops (commission = 0)
}

enum OperationStatus {
  enAttente,
  validee,
  terminee,
  annulee,
}

enum ModePaiement {
  cash,
  airtelMoney,
  mPesa,
  orangeMoney,
}

class OperationModel {
  final int? id;
  final OperationType type;
  final double montantBrut;
  final double commission;
  final double montantNet;
  final String devise;
  
  // Informations client
  final int? clientId;
  final String? clientNom;
  
  // Informations shops
  final int? shopSourceId;
  final String? shopSourceDesignation;
  final int? shopDestinationId;
  final String? shopDestinationDesignation;
  
  // Informations agent
  final int agentId;
  final String? agentUsername;
  
  // Code d'opération unique (OBLIGATOIRE)
  final String codeOps;
  
  // Détails opération
  final String? destinataire;
  final String? telephoneDestinataire;
  final String? reference;
  final String? simNumero; // Numéro de SIM pour les retraits
  final ModePaiement modePaiement;
  final OperationStatus statut;
  final String? notes;
  final String? observation; // New field for agent observations
  final String? billetage; // JSON string representation of BilletageModel
  
  // Getter to access billetage as a BilletageModel object
  BilletageModel? get billetageModel {
    if (billetage == null || billetage!.isEmpty) {
      return null;
    }
    try {
      return BilletageModel.fromJson(billetage!);
    } catch (e) {
      // Return null if parsing fails
      return null;
    }
  }

  // Dates et tracking
  final DateTime dateOp;
  final DateTime? dateValidation; // Date de validation du transfert
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;
  
  // Flot administratif (n'impacte PAS le cash disponible, crée seulement des dettes)
  final bool isAdministrative;

  OperationModel({
    this.id,
    required this.type,
    required this.montantBrut,
    required this.commission,
    required this.montantNet,
    this.devise = 'USD',
    
    // Client
    this.clientId,
    this.clientNom,
    
    // Shops
    this.shopSourceId,
    this.shopSourceDesignation,
    this.shopDestinationId,
    this.shopDestinationDesignation,
    
    // Agent
    required this.agentId,
    this.agentUsername,
    
    // Code d'opération (OBLIGATOIRE)
    required this.codeOps,
    
    // Détails
    this.destinataire,
    this.telephoneDestinataire,
    this.reference,
    this.simNumero,
    required this.modePaiement,
    this.statut = OperationStatus.terminee,
    this.notes,
    this.observation,
    this.billetage,
    
    // Dates
    required this.dateOp,
    this.dateValidation,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
    
    // Flot administratif
    this.isAdministrative = false,
  });

  factory OperationModel.fromJson(Map<String, dynamic> json) {
    return OperationModel(
      id: json['id'],
      type: _parseOperationType(json['type']),
      montantBrut: (json['montant_brut'] ?? 0).toDouble(),
      commission: (json['commission'] ?? 0).toDouble(),
      montantNet: (json['montant_net'] ?? 0).toDouble(),
      devise: json['devise'] ?? 'USD',
      
      // Client
      clientId: json['client_id'],
      clientNom: json['client_nom'],
      
      // Shops
      shopSourceId: json['shop_source_id'],
      shopSourceDesignation: json['shop_source_designation'],
      shopDestinationId: json['shop_destination_id'],
      shopDestinationDesignation: json['shop_destination_designation'],
      
      // Agent
      agentId: json['agent_id'] ?? 0, // Fallback to 0 if null
      agentUsername: json['agent_username'],
      codeOps: json['code_ops'] ?? _generateCodeOps(json['id']),
      
      // Détails
      destinataire: json['destinataire'],
      telephoneDestinataire: json['telephone_destinataire'],
      reference: json['reference'],
      simNumero: json['sim_numero'],
      modePaiement: _parseModePaiement(json['mode_paiement']),
      statut: _parseOperationStatus(json['statut']),
      notes: json['notes'],
      observation: json['observation'],
      billetage: json['billetage'],
      
      // Dates
      dateOp: json['date_op'] != null ? DateTime.parse(json['date_op']) : (json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now()),
      dateValidation: json['date_validation'] != null ? DateTime.parse(json['date_validation']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by'],
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at']) : null,
      
      // Flot administratif
      isAdministrative: json['is_administrative'] == 1 || json['is_administrative'] == true,
    );
  }
  
  /// Parse OperationType depuis String (MySQL) ou int (local)
  static OperationType _parseOperationType(dynamic value) {
    if (value == null) return OperationType.depot;
    
    // Si c'est déjà un index
    if (value is int) {
      if (value >= 0 && value < OperationType.values.length) {
        return OperationType.values[value];
      }
      return OperationType.depot;
    }
    
    // Si c'est une string (depuis MySQL)
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'transfertnational':
          return OperationType.transfertNational;
        case 'transfertinternationalsortant':
          return OperationType.transfertInternationalSortant;
        case 'transfertinternationalentrant':
          return OperationType.transfertInternationalEntrant;
        case 'depot':
          return OperationType.depot;
        case 'retrait':
          return OperationType.retrait;
        case 'virement':
          return OperationType.virement;
        case 'retrait_mobile_money':
        case 'retraitmobilemoney':
          return OperationType.retraitMobileMoney;
        case 'flotshoptoshop':
        case 'flot_shop_to_shop':
          return OperationType.flotShopToShop;
        default:
          return OperationType.depot;
      }
    }
    
    return OperationType.depot;
  }
  
  /// Parse ModePaiement depuis String (MySQL) ou int (local)
  static ModePaiement _parseModePaiement(dynamic value) {
    if (value == null) return ModePaiement.cash;
    
    // Si c'est déjà un index
    if (value is int) {
      if (value >= 0 && value < ModePaiement.values.length) {
        return ModePaiement.values[value];
      }
      return ModePaiement.cash;
    }
    
    // Si c'est une string (depuis MySQL)
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
  
  /// Génère un code d'opération unique (format court: YYMMDDHHMMSSXXX sans caractères spéciaux)
  /// Utilisé uniquement en fallback si aucun code n'est fourni
  static String _generateCodeOps(dynamic id) {
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final milliseconds = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    
    // Format: YYMMDDHHMMSSXXX (14 chiffres) garantit l'unicité via timestamp complet
    return '$year$month$day$hour$minute$second$milliseconds';
  }
  
  /// Parse OperationStatus depuis String (MySQL) ou int (local)
  static OperationStatus _parseOperationStatus(dynamic value) {
    if (value == null) return OperationStatus.terminee;
    
    // Si c'est déjà un index
    if (value is int) {
      if (value >= 0 && value < OperationStatus.values.length) {
        return OperationStatus.values[value];
      }
      return OperationStatus.terminee;
    }
    
    // Si c'est une string (depuis MySQL)
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'enattente':
          return OperationStatus.enAttente;
        case 'validee':
          return OperationStatus.validee;
        case 'terminee':
          return OperationStatus.terminee;
        case 'annulee':
          return OperationStatus.annulee;
        default:
          return OperationStatus.terminee;
      }
    }
    
    return OperationStatus.terminee;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'montant_brut': montantBrut,
      'commission': commission,
      'montant_net': montantNet,
      'devise': devise,
      
      // Client
      'client_id': clientId,
      'client_nom': clientNom,
      
      // Shops
      'shop_source_id': shopSourceId,
      'shop_source_designation': (shopSourceDesignation == null || shopSourceDesignation!.isEmpty) ? null : shopSourceDesignation,
      'shop_destination_id': shopDestinationId,
      'shop_destination_designation': (shopDestinationDesignation == null || shopDestinationDesignation!.isEmpty) ? null : shopDestinationDesignation,
      
      // Agent
      'agent_id': agentId,
      'agent_username': agentUsername,
      'code_ops': codeOps,
      
      // Détails
      'destinataire': destinataire,
      'telephone_destinataire': telephoneDestinataire,
      'reference': reference,
      'sim_numero': simNumero,
      'mode_paiement': modePaiement.index,
      'statut': statut.index,
      'notes': notes,
      'observation': observation,
      'billetage': billetage,
      
      // Dates
      'date_op': dateOp.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'created_at': (createdAt ?? dateOp).toIso8601String(),
      'last_modified_at': (lastModifiedAt ?? DateTime.now()).toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      
      // Flot administratif
      'is_administrative': isAdministrative ? 1 : 0,
    };
  }

  String get typeLabel {
    switch (type) {
      case OperationType.transfertNational:
        return 'Transfert National';
      case OperationType.transfertInternationalSortant:
        return 'Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return 'Transfert International Entrant';
      case OperationType.depot:
        return 'Dépôt';
      case OperationType.retrait:
        return 'Retrait';
      case OperationType.virement:
        return 'Virement';
      case OperationType.retraitMobileMoney:
        return 'Retrait Mobile Money';
      case OperationType.flotShopToShop:
        return 'FLOT Shop-to-Shop';
    }
  }

  String get statutLabel {
    switch (statut) {
      case OperationStatus.enAttente:
        return 'En Attente';
      case OperationStatus.validee:
        return 'Validée';
      case OperationStatus.terminee:
        return 'Terminée';
      case OperationStatus.annulee:
        return 'Annulée';
    }
  }

  String get modePaiementLabel {
    switch (modePaiement) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }
  
  /// Résout la désignation du shop source (avec fallback sur ID)
  String getShopSourceDesignation([List<dynamic>? shops]) {
    if (shopSourceDesignation != null && shopSourceDesignation!.isNotEmpty) {
      return shopSourceDesignation!;
    }
    
    if (shops != null && shopSourceId != null) {
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
    
    return shopSourceId != null ? 'Shop #$shopSourceId' : 'Shop inconnu';
  }
  
  /// Résout la désignation du shop destination (avec fallback sur ID)
  String getShopDestinationDesignation([List<dynamic>? shops]) {
    if (shopDestinationDesignation != null && shopDestinationDesignation!.isNotEmpty) {
      return shopDestinationDesignation!;
    }
    
    if (shops != null && shopDestinationId != null) {
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
    
    return shopDestinationId != null ? 'Shop #$shopDestinationId' : 'Shop inconnu';
  }

  OperationModel copyWith({
    int? id,
    OperationType? type,
    double? montantBrut,
    double? commission,
    double? montantNet,
    String? devise,
    
    // Client
    int? clientId,
    String? clientNom,
    
    // Shops
    int? shopSourceId,
    String? shopSourceDesignation,
    int? shopDestinationId,
    String? shopDestinationDesignation,
    
    // Agent
    int? agentId,
    String? agentUsername,
    String? codeOps,
    
    // Détails
    String? destinataire,
    String? telephoneDestinataire,
    String? reference,
    String? simNumero,
    ModePaiement? modePaiement,
    OperationStatus? statut,
    String? notes,
    String? observation,
    String? billetage,
    
    // Dates
    DateTime? dateOp,
    DateTime? dateValidation,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
    
    // Flot administratif
    bool? isAdministrative,
  }) {
    return OperationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      montantBrut: montantBrut ?? this.montantBrut,
      commission: commission ?? this.commission,
      montantNet: montantNet ?? this.montantNet,
      devise: devise ?? this.devise,
      
      // Client
      clientId: clientId ?? this.clientId,
      clientNom: clientNom ?? this.clientNom,
      
      // Shops
      shopSourceId: shopSourceId ?? this.shopSourceId,
      shopSourceDesignation: shopSourceDesignation ?? this.shopSourceDesignation,
      shopDestinationId: shopDestinationId ?? this.shopDestinationId,
      shopDestinationDesignation: shopDestinationDesignation ?? this.shopDestinationDesignation,
      
      // Agent
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      codeOps: codeOps ?? this.codeOps,
      
      // Détails
      destinataire: destinataire ?? this.destinataire,
      telephoneDestinataire: telephoneDestinataire ?? this.telephoneDestinataire,
      reference: reference ?? this.reference,
      simNumero: simNumero ?? this.simNumero,
      modePaiement: modePaiement ?? this.modePaiement,
      statut: statut ?? this.statut,
      notes: notes ?? this.notes,
      observation: observation ?? this.observation,
      billetage: billetage ?? this.billetage,
      
      // Dates
      dateOp: dateOp ?? this.dateOp,
      dateValidation: dateValidation ?? this.dateValidation,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      
      // Flot administratif
      isAdministrative: isAdministrative ?? this.isAdministrative,
    );
  }
}
