/// Modèle pour le suivi des crédits inter-shop (consolidation)
///
/// Ce modèle permet de tracker les dettes internes entre:
/// - Shop Principal (Durba): Gère tous les flots
/// - Shop Normal (C, D, E, F): Initie les transferts
/// - Shop Service (Kampala): Sert les transferts
///
/// LOGIQUE:
/// Transfert: Shop C → Kampala (service)
/// DETTES CRÉÉES:
/// 1. EXTERNE: Durba doit à Kampala (montant brut)
/// 2. INTERNE: Shop C doit à Durba (montant brut)
class CreditIntershopTrackingModel {
  final int? id;

  // Shop Principal (gère les flots - ex: Durba)
  final int shopPrincipalId;
  final String shopPrincipalDesignation;

  // Shop Normal (initie le transfert - ex: C, D, E, F)
  final int shopNormalId;
  final String shopNormalDesignation;

  // Shop Service (sert le transfert - ex: Kampala)
  final int shopServiceId;
  final String shopServiceDesignation;

  // Montants
  final double montantBrut; // Montant total (net + commission)
  final double montantNet; // Montant servi au bénéficiaire
  final double commission; // Commission encaissée
  final String devise;

  // Lien avec l'opération d'origine
  final int? operationId;
  final String? operationReference;

  // Dates
  final DateTime dateOperation;
  final DateTime dateConsolidation;

  // Tracking
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  CreditIntershopTrackingModel({
    this.id,
    required this.shopPrincipalId,
    required this.shopPrincipalDesignation,
    required this.shopNormalId,
    required this.shopNormalDesignation,
    required this.shopServiceId,
    required this.shopServiceDesignation,
    required this.montantBrut,
    required this.montantNet,
    required this.commission,
    this.devise = 'USD',
    this.operationId,
    this.operationReference,
    required this.dateOperation,
    required this.dateConsolidation,
    required this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  /// Créer depuis JSON (depuis base de données ou API)
  factory CreditIntershopTrackingModel.fromJson(Map<String, dynamic> json) {
    return CreditIntershopTrackingModel(
      id: json['id'] as int?,
      shopPrincipalId: json['shop_principal_id'] as int,
      shopPrincipalDesignation:
          json['shop_principal_designation'] as String? ?? '',
      shopNormalId: json['shop_normal_id'] as int,
      shopNormalDesignation: json['shop_normal_designation'] as String? ?? '',
      shopServiceId: json['shop_service_id'] as int,
      shopServiceDesignation: json['shop_service_designation'] as String? ?? '',
      montantBrut: (json['montant_brut'] as num?)?.toDouble() ?? 0.0,
      montantNet: (json['montant_net'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      devise: json['devise'] as String? ?? 'USD',
      operationId: json['operation_id'] as int?,
      operationReference: json['operation_reference'] as String?,
      dateOperation: DateTime.parse(json['date_operation'] as String),
      dateConsolidation: DateTime.parse(json['date_consolidation'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  /// Convertir en JSON (pour base de données ou API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_principal_id': shopPrincipalId,
      'shop_principal_designation': shopPrincipalDesignation,
      'shop_normal_id': shopNormalId,
      'shop_normal_designation': shopNormalDesignation,
      'shop_service_id': shopServiceId,
      'shop_service_designation': shopServiceDesignation,
      'montant_brut': montantBrut,
      'montant_net': montantNet,
      'commission': commission,
      'devise': devise,
      'operation_id': operationId,
      'operation_reference': operationReference,
      'date_operation': dateOperation.toIso8601String(),
      'date_consolidation': dateConsolidation.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Copier avec modifications
  CreditIntershopTrackingModel copyWith({
    int? id,
    int? shopPrincipalId,
    String? shopPrincipalDesignation,
    int? shopNormalId,
    String? shopNormalDesignation,
    int? shopServiceId,
    String? shopServiceDesignation,
    double? montantBrut,
    double? montantNet,
    double? commission,
    String? devise,
    int? operationId,
    String? operationReference,
    DateTime? dateOperation,
    DateTime? dateConsolidation,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return CreditIntershopTrackingModel(
      id: id ?? this.id,
      shopPrincipalId: shopPrincipalId ?? this.shopPrincipalId,
      shopPrincipalDesignation:
          shopPrincipalDesignation ?? this.shopPrincipalDesignation,
      shopNormalId: shopNormalId ?? this.shopNormalId,
      shopNormalDesignation:
          shopNormalDesignation ?? this.shopNormalDesignation,
      shopServiceId: shopServiceId ?? this.shopServiceId,
      shopServiceDesignation:
          shopServiceDesignation ?? this.shopServiceDesignation,
      montantBrut: montantBrut ?? this.montantBrut,
      montantNet: montantNet ?? this.montantNet,
      commission: commission ?? this.commission,
      devise: devise ?? this.devise,
      operationId: operationId ?? this.operationId,
      operationReference: operationReference ?? this.operationReference,
      dateOperation: dateOperation ?? this.dateOperation,
      dateConsolidation: dateConsolidation ?? this.dateConsolidation,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() {
    return 'CreditIntershopTracking(id: $id, normal: $shopNormalDesignation → principal: $shopPrincipalDesignation → service: $shopServiceDesignation, montant: $montantBrut $devise)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreditIntershopTrackingModel &&
        other.id == id &&
        other.shopPrincipalId == shopPrincipalId &&
        other.shopNormalId == shopNormalId &&
        other.shopServiceId == shopServiceId &&
        other.operationId == operationId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      shopPrincipalId,
      shopNormalId,
      shopServiceId,
      operationId,
    );
  }
}
