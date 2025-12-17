/// Modèle pour les transactions virtuelles supprimées (corbeille)
/// Équivalent à OperationCorbeilleModel mais pour les transactions virtuelles
class VirtualTransactionCorbeilleModel {
  final int? id;
  final String reference; // Référence originale de la transaction virtuelle
  final int? virtualTransactionId; // ID original de la transaction virtuelle
  
  // Données originales de la transaction (préservées pour restauration)
  final double montantVirtuel;
  final double frais;
  final double montantCash;
  final String devise;
  final String simNumero;
  final int shopId;
  final String? shopDesignation;
  final int agentId;
  final String? agentUsername;
  final String? clientNom;
  final String? clientTelephone;
  final String statut;
  final DateTime dateEnregistrement;
  final DateTime? dateValidation;
  final String? notes;
  final bool isAdministrative;
  
  // Informations de suppression
  final int deletedByAgentId;
  final String deletedByAgentName;
  final DateTime deletionDate;
  final String? deletionReason;
  
  // Informations de restauration
  final bool isRestored;
  final String? restoredBy;
  final DateTime? restorationDate;
  final String? restorationReason;
  
  // Synchronisation
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  VirtualTransactionCorbeilleModel({
    this.id,
    required this.reference,
    this.virtualTransactionId,
    required this.montantVirtuel,
    this.frais = 0.0,
    required this.montantCash,
    this.devise = 'USD',
    required this.simNumero,
    required this.shopId,
    this.shopDesignation,
    required this.agentId,
    this.agentUsername,
    this.clientNom,
    this.clientTelephone,
    required this.statut,
    required this.dateEnregistrement,
    this.dateValidation,
    this.notes,
    this.isAdministrative = false,
    required this.deletedByAgentId,
    required this.deletedByAgentName,
    required this.deletionDate,
    this.deletionReason,
    this.isRestored = false,
    this.restoredBy,
    this.restorationDate,
    this.restorationReason,
    this.isSynced = false,
    this.syncedAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  VirtualTransactionCorbeilleModel copyWith({
    int? id,
    String? reference,
    int? virtualTransactionId,
    double? montantVirtuel,
    double? frais,
    double? montantCash,
    String? devise,
    String? simNumero,
    int? shopId,
    String? shopDesignation,
    int? agentId,
    String? agentUsername,
    String? clientNom,
    String? clientTelephone,
    String? statut,
    DateTime? dateEnregistrement,
    DateTime? dateValidation,
    String? notes,
    bool? isAdministrative,
    int? deletedByAgentId,
    String? deletedByAgentName,
    DateTime? deletionDate,
    String? deletionReason,
    bool? isRestored,
    String? restoredBy,
    DateTime? restorationDate,
    String? restorationReason,
    bool? isSynced,
    DateTime? syncedAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return VirtualTransactionCorbeilleModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      virtualTransactionId: virtualTransactionId ?? this.virtualTransactionId,
      montantVirtuel: montantVirtuel ?? this.montantVirtuel,
      frais: frais ?? this.frais,
      montantCash: montantCash ?? this.montantCash,
      devise: devise ?? this.devise,
      simNumero: simNumero ?? this.simNumero,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      clientNom: clientNom ?? this.clientNom,
      clientTelephone: clientTelephone ?? this.clientTelephone,
      statut: statut ?? this.statut,
      dateEnregistrement: dateEnregistrement ?? this.dateEnregistrement,
      dateValidation: dateValidation ?? this.dateValidation,
      notes: notes ?? this.notes,
      isAdministrative: isAdministrative ?? this.isAdministrative,
      deletedByAgentId: deletedByAgentId ?? this.deletedByAgentId,
      deletedByAgentName: deletedByAgentName ?? this.deletedByAgentName,
      deletionDate: deletionDate ?? this.deletionDate,
      deletionReason: deletionReason ?? this.deletionReason,
      isRestored: isRestored ?? this.isRestored,
      restoredBy: restoredBy ?? this.restoredBy,
      restorationDate: restorationDate ?? this.restorationDate,
      restorationReason: restorationReason ?? this.restorationReason,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'virtual_transaction_id': virtualTransactionId,
      'montant_virtuel': montantVirtuel,
      'frais': frais,
      'montant_cash': montantCash,
      'devise': devise,
      'sim_numero': simNumero,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'client_nom': clientNom,
      'client_telephone': clientTelephone,
      'statut': statut,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'notes': notes,
      'is_administrative': isAdministrative,
      'deleted_by_agent_id': deletedByAgentId,
      'deleted_by_agent_name': deletedByAgentName,
      'deletion_date': deletionDate.toIso8601String(),
      'deletion_reason': deletionReason,
      'is_restored': isRestored,
      'restored_by': restoredBy,
      'restoration_date': restorationDate?.toIso8601String(),
      'restoration_reason': restorationReason,
      'is_synced': isSynced,
      'synced_at': syncedAt?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
    };
  }

  factory VirtualTransactionCorbeilleModel.fromJson(Map<String, dynamic> json) {
    return VirtualTransactionCorbeilleModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      virtualTransactionId: json['virtual_transaction_id'],
      montantVirtuel: (json['montant_virtuel'] ?? 0).toDouble(),
      frais: (json['frais'] ?? 0).toDouble(),
      montantCash: (json['montant_cash'] ?? 0).toDouble(),
      devise: json['devise'] ?? 'USD',
      simNumero: json['sim_numero'] ?? '',
      shopId: json['shop_id'] ?? 0,
      shopDesignation: json['shop_designation'],
      agentId: json['agent_id'] ?? 0,
      agentUsername: json['agent_username'],
      clientNom: json['client_nom'],
      clientTelephone: json['client_telephone'],
      statut: json['statut'] ?? '',
      dateEnregistrement: DateTime.parse(json['date_enregistrement'] ?? DateTime.now().toIso8601String()),
      dateValidation: json['date_validation'] != null 
          ? DateTime.parse(json['date_validation']) 
          : null,
      notes: json['notes'],
      isAdministrative: json['is_administrative'] ?? false,
      deletedByAgentId: json['deleted_by_agent_id'] ?? 0,
      deletedByAgentName: json['deleted_by_agent_name'] ?? '',
      deletionDate: DateTime.parse(json['deletion_date'] ?? DateTime.now().toIso8601String()),
      deletionReason: json['deletion_reason'],
      isRestored: json['is_restored'] ?? false,
      restoredBy: json['restored_by'],
      restorationDate: json['restoration_date'] != null 
          ? DateTime.parse(json['restoration_date']) 
          : null,
      restorationReason: json['restoration_reason'],
      isSynced: json['is_synced'] ?? false,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
      lastModifiedAt: json['last_modified_at'] != null 
          ? DateTime.parse(json['last_modified_at']) 
          : null,
      lastModifiedBy: json['last_modified_by'],
    );
  }

  /// Obtenir le libellé du statut original de la transaction
  String get statutLabel {
    switch (statut.toLowerCase()) {
      case 'enattente':
        return 'En attente';
      case 'validee':
        return 'Validée';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }

  /// Obtenir une description courte de la transaction
  String get description {
    return 'Réf: $reference - ${montantVirtuel.toStringAsFixed(2)} $devise';
  }

  @override
  String toString() {
    return 'VirtualTransactionCorbeilleModel(id: $id, reference: $reference, montant: $montantVirtuel $devise, deletedBy: $deletedByAgentName, isRestored: $isRestored)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VirtualTransactionCorbeilleModel &&
        other.reference == reference &&
        other.deletionDate == deletionDate;
  }

  @override
  int get hashCode => reference.hashCode ^ deletionDate.hashCode;
}
