/// Model pour les opérations dans la corbeille (supprimées)
class OperationCorbeilleModel {
  final int? id;
  final int? originalOperationId;
  
  // Copie complète de l'opération supprimée
  final String codeOps;
  final String type;
  final int? shopSourceId;
  final String? shopSourceDesignation;
  final int? shopDestinationId;
  final String? shopDestinationDesignation;
  final int agentId;
  final String? agentUsername;
  final int? clientId;
  final String? clientNom;
  
  // Montants
  final double montantBrut;
  final double commission;
  final double montantNet;
  final String devise;
  
  // Détails
  final String modePaiement;
  final String? destinataire;
  final String? telephoneDestinataire;
  final String? reference;
  final String? simNumero;
  final String statut;
  final String? notes;
  final String? observation;
  
  // Dates de l'opération originale
  final DateTime dateOp;
  final DateTime? dateValidation;
  final DateTime? createdAtOriginal;
  final DateTime? lastModifiedAtOriginal;
  final String? lastModifiedByOriginal;
  
  // Informations de suppression
  final int? deletedByAdminId;
  final String? deletedByAdminName;
  final int? validatedByAgentId;
  final String? validatedByAgentName;
  final int? deletionRequestId;
  final String? deletionReason;
  final DateTime deletedAt;
  
  // Restauration
  final bool isRestored;
  final DateTime? restoredAt;
  final String? restoredBy;
  final int? restoredOperationId;
  
  // Synchronisation
  final bool isSynced;
  final DateTime? syncedAt;

  OperationCorbeilleModel({
    this.id,
    this.originalOperationId,
    required this.codeOps,
    required this.type,
    this.shopSourceId,
    this.shopSourceDesignation,
    this.shopDestinationId,
    this.shopDestinationDesignation,
    required this.agentId,
    this.agentUsername,
    this.clientId,
    this.clientNom,
    required this.montantBrut,
    this.commission = 0.0,
    required this.montantNet,
    this.devise = 'USD',
    this.modePaiement = 'cash',
    this.destinataire,
    this.telephoneDestinataire,
    this.reference,
    this.simNumero,
    this.statut = 'terminee',
    this.notes,
    this.observation,
    required this.dateOp,
    this.dateValidation,
    this.createdAtOriginal,
    this.lastModifiedAtOriginal,
    this.lastModifiedByOriginal,
    this.deletedByAdminId,
    this.deletedByAdminName,
    this.validatedByAgentId,
    this.validatedByAgentName,
    this.deletionRequestId,
    this.deletionReason,
    required this.deletedAt,
    this.isRestored = false,
    this.restoredAt,
    this.restoredBy,
    this.restoredOperationId,
    this.isSynced = false,
    this.syncedAt,
  });

  /// Helper method to parse double from dynamic value (handles String, int, double)
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory OperationCorbeilleModel.fromJson(Map<String, dynamic> json) {
    return OperationCorbeilleModel(
      id: json['id'],
      originalOperationId: json['original_operation_id'],
      codeOps: json['code_ops'] ?? '',
      type: json['type'] ?? '',
      shopSourceId: json['shop_source_id'],
      shopSourceDesignation: json['shop_source_designation'],
      shopDestinationId: json['shop_destination_id'],
      shopDestinationDesignation: json['shop_destination_designation'],
      agentId: json['agent_id'] ?? 0,
      agentUsername: json['agent_username'],
      clientId: json['client_id'],
      clientNom: json['client_nom'],
      montantBrut: _parseDouble(json['montant_brut']),
      commission: _parseDouble(json['commission']),
      montantNet: _parseDouble(json['montant_net']),
      devise: json['devise'] ?? 'USD',
      modePaiement: json['mode_paiement'] ?? 'cash',
      destinataire: json['destinataire'],
      telephoneDestinataire: json['telephone_destinataire'],
      reference: json['reference'],
      simNumero: json['sim_numero'],
      statut: json['statut'] ?? 'terminee',
      notes: json['notes'],
      observation: json['observation'],
      dateOp: json['date_op'] != null 
          ? DateTime.parse(json['date_op']) 
          : DateTime.now(),
      dateValidation: json['date_validation'] != null 
          ? DateTime.parse(json['date_validation']) 
          : null,
      createdAtOriginal: json['created_at_original'] != null 
          ? DateTime.parse(json['created_at_original']) 
          : null,
      lastModifiedAtOriginal: json['last_modified_at_original'] != null 
          ? DateTime.parse(json['last_modified_at_original']) 
          : null,
      lastModifiedByOriginal: json['last_modified_by_original'],
      deletedByAdminId: json['deleted_by_admin_id'],
      deletedByAdminName: json['deleted_by_admin_name'],
      validatedByAgentId: json['validated_by_agent_id'],
      validatedByAgentName: json['validated_by_agent_name'],
      deletionRequestId: json['deletion_request_id'],
      deletionReason: json['deletion_reason'],
      deletedAt: json['deleted_at'] != null 
          ? DateTime.parse(json['deleted_at']) 
          : DateTime.now(),
      isRestored: json['is_restored'] == 1 || json['is_restored'] == true,
      restoredAt: json['restored_at'] != null 
          ? DateTime.parse(json['restored_at']) 
          : null,
      restoredBy: json['restored_by'],
      restoredOperationId: json['restored_operation_id'],
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_operation_id': originalOperationId,
      'code_ops': codeOps,
      'type': type,
      'shop_source_id': shopSourceId,
      'shop_source_designation': shopSourceDesignation,
      'shop_destination_id': shopDestinationId,
      'shop_destination_designation': shopDestinationDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'client_id': clientId,
      'client_nom': clientNom,
      'montant_brut': montantBrut,
      'commission': commission,
      'montant_net': montantNet,
      'devise': devise,
      'mode_paiement': modePaiement,
      'destinataire': destinataire,
      'telephone_destinataire': telephoneDestinataire,
      'reference': reference,
      'sim_numero': simNumero,
      'statut': statut,
      'notes': notes,
      'observation': observation,
      'date_op': dateOp.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'created_at_original': createdAtOriginal?.toIso8601String(),
      'last_modified_at_original': lastModifiedAtOriginal?.toIso8601String(),
      'last_modified_by_original': lastModifiedByOriginal,
      'deleted_by_admin_id': deletedByAdminId,
      'deleted_by_admin_name': deletedByAdminName,
      'validated_by_agent_id': validatedByAgentId,
      'validated_by_agent_name': validatedByAgentName,
      'deletion_request_id': deletionRequestId,
      'deletion_reason': deletionReason,
      'deleted_at': deletedAt.toIso8601String(),
      'is_restored': isRestored ? 1 : 0,
      'restored_at': restoredAt?.toIso8601String(),
      'restored_by': restoredBy,
      'restored_operation_id': restoredOperationId,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  OperationCorbeilleModel copyWith({
    int? id,
    int? originalOperationId,
    String? codeOps,
    String? type,
    int? shopSourceId,
    String? shopSourceDesignation,
    int? shopDestinationId,
    String? shopDestinationDesignation,
    int? agentId,
    String? agentUsername,
    int? clientId,
    String? clientNom,
    double? montantBrut,
    double? commission,
    double? montantNet,
    String? devise,
    String? modePaiement,
    String? destinataire,
    String? telephoneDestinataire,
    String? reference,
    String? simNumero,
    String? statut,
    String? notes,
    String? observation,
    DateTime? dateOp,
    DateTime? dateValidation,
    DateTime? createdAtOriginal,
    DateTime? lastModifiedAtOriginal,
    String? lastModifiedByOriginal,
    int? deletedByAdminId,
    String? deletedByAdminName,
    int? validatedByAgentId,
    String? validatedByAgentName,
    int? deletionRequestId,
    String? deletionReason,
    DateTime? deletedAt,
    bool? isRestored,
    DateTime? restoredAt,
    String? restoredBy,
    int? restoredOperationId,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return OperationCorbeilleModel(
      id: id ?? this.id,
      originalOperationId: originalOperationId ?? this.originalOperationId,
      codeOps: codeOps ?? this.codeOps,
      type: type ?? this.type,
      shopSourceId: shopSourceId ?? this.shopSourceId,
      shopSourceDesignation: shopSourceDesignation ?? this.shopSourceDesignation,
      shopDestinationId: shopDestinationId ?? this.shopDestinationId,
      shopDestinationDesignation: shopDestinationDesignation ?? this.shopDestinationDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      clientId: clientId ?? this.clientId,
      clientNom: clientNom ?? this.clientNom,
      montantBrut: montantBrut ?? this.montantBrut,
      commission: commission ?? this.commission,
      montantNet: montantNet ?? this.montantNet,
      devise: devise ?? this.devise,
      modePaiement: modePaiement ?? this.modePaiement,
      destinataire: destinataire ?? this.destinataire,
      telephoneDestinataire: telephoneDestinataire ?? this.telephoneDestinataire,
      reference: reference ?? this.reference,
      simNumero: simNumero ?? this.simNumero,
      statut: statut ?? this.statut,
      notes: notes ?? this.notes,
      observation: observation ?? this.observation,
      dateOp: dateOp ?? this.dateOp,
      dateValidation: dateValidation ?? this.dateValidation,
      createdAtOriginal: createdAtOriginal ?? this.createdAtOriginal,
      lastModifiedAtOriginal: lastModifiedAtOriginal ?? this.lastModifiedAtOriginal,
      lastModifiedByOriginal: lastModifiedByOriginal ?? this.lastModifiedByOriginal,
      deletedByAdminId: deletedByAdminId ?? this.deletedByAdminId,
      deletedByAdminName: deletedByAdminName ?? this.deletedByAdminName,
      validatedByAgentId: validatedByAgentId ?? this.validatedByAgentId,
      validatedByAgentName: validatedByAgentName ?? this.validatedByAgentName,
      deletionRequestId: deletionRequestId ?? this.deletionRequestId,
      deletionReason: deletionReason ?? this.deletionReason,
      deletedAt: deletedAt ?? this.deletedAt,
      isRestored: isRestored ?? this.isRestored,
      restoredAt: restoredAt ?? this.restoredAt,
      restoredBy: restoredBy ?? this.restoredBy,
      restoredOperationId: restoredOperationId ?? this.restoredOperationId,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
