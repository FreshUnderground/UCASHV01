enum DeletionRequestStatus {
  enAttente,
  validee,
  refusee,
  annulee,
}

/// Model pour les demandes de suppression d'opérations
class DeletionRequestModel {
  final int? id;
  final String codeOps; // Code unique de l'opération à supprimer
  final int? operationId; // ID local (peut changer)
  
  // Détails de l'opération à supprimer
  final String operationType;
  final double montant;
  final String devise;
  final String? destinataire;
  final String? expediteur;
  final String? clientNom;
  
  // Informations de la demande
  final int requestedByAdminId;
  final String requestedByAdminName;
  final DateTime requestDate;
  final String? reason;
  
  // Validation par l'agent
  final int? validatedByAgentId;
  final String? validatedByAgentName;
  final DateTime? validationDate;
  
  // Statut
  final DeletionRequestStatus statut;
  
  // Métadonnées
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  
  // Synchronisation
  final bool isSynced;
  final DateTime? syncedAt;

  DeletionRequestModel({
    this.id,
    required this.codeOps,
    this.operationId,
    required this.operationType,
    required this.montant,
    this.devise = 'USD',
    this.destinataire,
    this.expediteur,
    this.clientNom,
    required this.requestedByAdminId,
    required this.requestedByAdminName,
    required this.requestDate,
    this.reason,
    this.validatedByAgentId,
    this.validatedByAgentName,
    this.validationDate,
    this.statut = DeletionRequestStatus.enAttente,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  factory DeletionRequestModel.fromJson(Map<String, dynamic> json) {
    return DeletionRequestModel(
      id: json['id'],
      codeOps: json['code_ops'],
      operationId: json['operation_id'],
      operationType: json['operation_type'] ?? '',
      montant: (json['montant'] ?? 0).toDouble(),
      devise: json['devise'] ?? 'USD',
      destinataire: json['destinataire'],
      expediteur: json['expediteur'],
      clientNom: json['client_nom'],
      requestedByAdminId: json['requested_by_admin_id'] ?? 0,
      requestedByAdminName: json['requested_by_admin_name'] ?? '',
      requestDate: json['request_date'] != null 
          ? DateTime.parse(json['request_date']) 
          : DateTime.now(),
      reason: json['reason'],
      validatedByAgentId: json['validated_by_agent_id'],
      validatedByAgentName: json['validated_by_agent_name'],
      validationDate: json['validation_date'] != null 
          ? DateTime.parse(json['validation_date']) 
          : null,
      statut: _parseStatus(json['statut']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      lastModifiedAt: json['last_modified_at'] != null 
          ? DateTime.parse(json['last_modified_at']) 
          : null,
      lastModifiedBy: json['last_modified_by'],
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code_ops': codeOps,
      'operation_id': operationId,
      'operation_type': operationType,
      'montant': montant,
      'devise': devise,
      'destinataire': destinataire,
      'expediteur': expediteur,
      'client_nom': clientNom,
      'requested_by_admin_id': requestedByAdminId,
      'requested_by_admin_name': requestedByAdminName,
      'request_date': requestDate.toIso8601String(),
      'reason': reason,
      'validated_by_agent_id': validatedByAgentId,
      'validated_by_agent_name': validatedByAgentName,
      'validation_date': validationDate?.toIso8601String(),
      'statut': statut.index,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'last_modified_at': (lastModifiedAt ?? DateTime.now()).toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  static DeletionRequestStatus _parseStatus(dynamic value) {
    if (value == null) return DeletionRequestStatus.enAttente;
    
    if (value is int) {
      if (value >= 0 && value < DeletionRequestStatus.values.length) {
        return DeletionRequestStatus.values[value];
      }
      return DeletionRequestStatus.enAttente;
    }
    
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'enattente':
        case 'en_attente':
          return DeletionRequestStatus.enAttente;
        case 'validee':
          return DeletionRequestStatus.validee;
        case 'refusee':
          return DeletionRequestStatus.refusee;
        case 'annulee':
          return DeletionRequestStatus.annulee;
        default:
          return DeletionRequestStatus.enAttente;
      }
    }
    
    return DeletionRequestStatus.enAttente;
  }

  String get statutLabel {
    switch (statut) {
      case DeletionRequestStatus.enAttente:
        return 'En Attente';
      case DeletionRequestStatus.validee:
        return 'Validée';
      case DeletionRequestStatus.refusee:
        return 'Refusée';
      case DeletionRequestStatus.annulee:
        return 'Annulée';
    }
  }

  DeletionRequestModel copyWith({
    int? id,
    String? codeOps,
    int? operationId,
    String? operationType,
    double? montant,
    String? devise,
    String? destinataire,
    String? expediteur,
    String? clientNom,
    int? requestedByAdminId,
    String? requestedByAdminName,
    DateTime? requestDate,
    String? reason,
    int? validatedByAgentId,
    String? validatedByAgentName,
    DateTime? validationDate,
    DeletionRequestStatus? statut,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return DeletionRequestModel(
      id: id ?? this.id,
      codeOps: codeOps ?? this.codeOps,
      operationId: operationId ?? this.operationId,
      operationType: operationType ?? this.operationType,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      destinataire: destinataire ?? this.destinataire,
      expediteur: expediteur ?? this.expediteur,
      clientNom: clientNom ?? this.clientNom,
      requestedByAdminId: requestedByAdminId ?? this.requestedByAdminId,
      requestedByAdminName: requestedByAdminName ?? this.requestedByAdminName,
      requestDate: requestDate ?? this.requestDate,
      reason: reason ?? this.reason,
      validatedByAgentId: validatedByAgentId ?? this.validatedByAgentId,
      validatedByAgentName: validatedByAgentName ?? this.validatedByAgentName,
      validationDate: validationDate ?? this.validationDate,
      statut: statut ?? this.statut,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
