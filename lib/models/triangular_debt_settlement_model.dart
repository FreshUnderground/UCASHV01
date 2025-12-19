/// Modèle pour gérer les règlements triangulaires de dettes inter-shops
/// 
/// **Scénario**: Shop A doit à Shop C, mais Shop B reçoit le paiement pour le compte de Shop C
/// 
/// **Impacts**:
/// - Dette de Shop A envers Shop C: diminue
/// - Dette de Shop B envers Shop C: augmente
/// 
/// **Exemple concret**:
/// - Shop MOKU doit 5000 USD à Shop NGANGAZU
/// - Agent de MOKU paie 5000 USD à Shop BUKAVU pour le compte de NGANGAZU
/// - Résultat:
///   * MOKU doit maintenant 0 USD à NGANGAZU (dette diminuée de 5000)
///   * BUKAVU doit maintenant 5000 USD à NGANGAZU (dette augmentée de 5000)

class TriangularDebtSettlementModel {
  final int? id;
  final String reference;
  
  // Shops impliqués dans le règlement triangulaire
  final int shopDebtorId; // Shop A (qui doit l'argent initialement)
  final String shopDebtorDesignation;
  final int shopIntermediaryId; // Shop B (qui reçoit le paiement)
  final String shopIntermediaryDesignation;
  final int shopCreditorId; // Shop C (à qui l'argent est dû)
  final String shopCreditorDesignation;
  
  // Informations du règlement
  final double montant;
  final String devise;
  final DateTime dateReglement;
  final String? modePaiement; // Comment le paiement a été effectué
  final String? notes;
  
  // Agent qui a effectué l'opération
  final int agentId;
  final String? agentUsername;
  
  // Métadonnées
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  TriangularDebtSettlementModel({
    this.id,
    required this.reference,
    required this.shopDebtorId,
    required this.shopDebtorDesignation,
    required this.shopIntermediaryId,
    required this.shopIntermediaryDesignation,
    required this.shopCreditorId,
    required this.shopCreditorDesignation,
    required this.montant,
    this.devise = 'USD',
    required this.dateReglement,
    this.modePaiement,
    this.notes,
    required this.agentId,
    this.agentUsername,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  /// Factory pour créer depuis JSON (base de données locale)
  factory TriangularDebtSettlementModel.fromJson(Map<String, dynamic> json) {
    return TriangularDebtSettlementModel(
      id: json['id'] as int?,
      reference: json['reference'] as String,
      shopDebtorId: json['shop_debtor_id'] as int,
      shopDebtorDesignation: json['shop_debtor_designation'] as String? ?? '',
      shopIntermediaryId: json['shop_intermediary_id'] as int,
      shopIntermediaryDesignation: json['shop_intermediary_designation'] as String? ?? '',
      shopCreditorId: json['shop_creditor_id'] as int,
      shopCreditorDesignation: json['shop_creditor_designation'] as String? ?? '',
      montant: (json['montant'] as num).toDouble(),
      devise: json['devise'] as String? ?? 'USD',
      dateReglement: DateTime.parse(json['date_reglement'] as String),
      modePaiement: json['mode_paiement'] as String?,
      notes: json['notes'] as String?,
      agentId: json['agent_id'] as int,
      agentUsername: json['agent_username'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: (json['is_synced'] as int?) == 1,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  /// Convertir en JSON pour la base de données locale
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'shop_debtor_id': shopDebtorId,
      'shop_debtor_designation': shopDebtorDesignation,
      'shop_intermediary_id': shopIntermediaryId,
      'shop_intermediary_designation': shopIntermediaryDesignation,
      'shop_creditor_id': shopCreditorId,
      'shop_creditor_designation': shopCreditorDesignation,
      'montant': montant,
      'devise': devise,
      'date_reglement': dateReglement.toIso8601String(),
      'mode_paiement': modePaiement,
      'notes': notes,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'created_at': createdAt?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Copie avec modifications
  TriangularDebtSettlementModel copyWith({
    int? id,
    String? reference,
    int? shopDebtorId,
    String? shopDebtorDesignation,
    int? shopIntermediaryId,
    String? shopIntermediaryDesignation,
    int? shopCreditorId,
    String? shopCreditorDesignation,
    double? montant,
    String? devise,
    DateTime? dateReglement,
    String? modePaiement,
    String? notes,
    int? agentId,
    String? agentUsername,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return TriangularDebtSettlementModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      shopDebtorId: shopDebtorId ?? this.shopDebtorId,
      shopDebtorDesignation: shopDebtorDesignation ?? this.shopDebtorDesignation,
      shopIntermediaryId: shopIntermediaryId ?? this.shopIntermediaryId,
      shopIntermediaryDesignation: shopIntermediaryDesignation ?? this.shopIntermediaryDesignation,
      shopCreditorId: shopCreditorId ?? this.shopCreditorId,
      shopCreditorDesignation: shopCreditorDesignation ?? this.shopCreditorDesignation,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      dateReglement: dateReglement ?? this.dateReglement,
      modePaiement: modePaiement ?? this.modePaiement,
      notes: notes ?? this.notes,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Générer une référence unique pour le règlement triangulaire
  static String generateReference() {
    final now = DateTime.now();
    return 'TRI${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';
  }

  @override
  String toString() {
    return 'TriangularDebtSettlement(id: $id, ref: $reference, '
        'debtor: $shopDebtorDesignation, intermediary: $shopIntermediaryDesignation, '
        'creditor: $shopCreditorDesignation, montant: $montant $devise)';
  }
}
