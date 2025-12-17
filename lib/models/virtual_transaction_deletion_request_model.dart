/// Statuts possibles pour une demande de suppression de transaction virtuelle
enum VirtualTransactionDeletionRequestStatus {
  enAttente,
  adminValidee,
  agentValidee,
  refusee,
  annulee;

  String get name {
    switch (this) {
      case VirtualTransactionDeletionRequestStatus.enAttente:
        return 'en_attente';
      case VirtualTransactionDeletionRequestStatus.adminValidee:
        return 'admin_validee';
      case VirtualTransactionDeletionRequestStatus.agentValidee:
        return 'agent_validee';
      case VirtualTransactionDeletionRequestStatus.refusee:
        return 'refusee';
      case VirtualTransactionDeletionRequestStatus.annulee:
        return 'annulee';
    }
  }

  static VirtualTransactionDeletionRequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente':
        return VirtualTransactionDeletionRequestStatus.enAttente;
      case 'admin_validee':
        return VirtualTransactionDeletionRequestStatus.adminValidee;
      case 'agent_validee':
        return VirtualTransactionDeletionRequestStatus.agentValidee;
      case 'refusee':
        return VirtualTransactionDeletionRequestStatus.refusee;
      case 'annulee':
        return VirtualTransactionDeletionRequestStatus.annulee;
      default:
        return VirtualTransactionDeletionRequestStatus.enAttente;
    }
  }
}

/// Modèle pour les demandes de suppression de transactions virtuelles
/// Suit le même workflow que les demandes de suppression d'opérations
class VirtualTransactionDeletionRequestModel {
  final int? id;
  final String reference; // Référence de la transaction virtuelle
  final int? virtualTransactionId;
  final String transactionType;
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
  
  // Validation admin
  final int? validatedByAdminId;
  final String? validatedByAdminName;
  final DateTime? validationAdminDate;
  
  // Validation agent
  final int? validatedByAgentId;
  final String? validatedByAgentName;
  final DateTime? validationDate;
  
  // Statut et suivi
  final VirtualTransactionDeletionRequestStatus statut;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime createdAt;
  
  // Synchronisation
  final bool isSynced;
  final DateTime? syncedAt;

  VirtualTransactionDeletionRequestModel({
    this.id,
    required this.reference,
    this.virtualTransactionId,
    required this.transactionType,
    required this.montant,
    this.devise = 'USD',
    this.destinataire,
    this.expediteur,
    this.clientNom,
    required this.requestedByAdminId,
    required this.requestedByAdminName,
    required this.requestDate,
    this.reason,
    this.validatedByAdminId,
    this.validatedByAdminName,
    this.validationAdminDate,
    this.validatedByAgentId,
    this.validatedByAgentName,
    this.validationDate,
    this.statut = VirtualTransactionDeletionRequestStatus.enAttente,
    this.lastModifiedAt,
    this.lastModifiedBy,
    required this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  });

  VirtualTransactionDeletionRequestModel copyWith({
    int? id,
    String? reference,
    int? virtualTransactionId,
    String? transactionType,
    double? montant,
    String? devise,
    String? destinataire,
    String? expediteur,
    String? clientNom,
    int? requestedByAdminId,
    String? requestedByAdminName,
    DateTime? requestDate,
    String? reason,
    int? validatedByAdminId,
    String? validatedByAdminName,
    DateTime? validationAdminDate,
    int? validatedByAgentId,
    String? validatedByAgentName,
    DateTime? validationDate,
    VirtualTransactionDeletionRequestStatus? statut,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return VirtualTransactionDeletionRequestModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      virtualTransactionId: virtualTransactionId ?? this.virtualTransactionId,
      transactionType: transactionType ?? this.transactionType,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      destinataire: destinataire ?? this.destinataire,
      expediteur: expediteur ?? this.expediteur,
      clientNom: clientNom ?? this.clientNom,
      requestedByAdminId: requestedByAdminId ?? this.requestedByAdminId,
      requestedByAdminName: requestedByAdminName ?? this.requestedByAdminName,
      requestDate: requestDate ?? this.requestDate,
      reason: reason ?? this.reason,
      validatedByAdminId: validatedByAdminId ?? this.validatedByAdminId,
      validatedByAdminName: validatedByAdminName ?? this.validatedByAdminName,
      validationAdminDate: validationAdminDate ?? this.validationAdminDate,
      validatedByAgentId: validatedByAgentId ?? this.validatedByAgentId,
      validatedByAgentName: validatedByAgentName ?? this.validatedByAgentName,
      validationDate: validationDate ?? this.validationDate,
      statut: statut ?? this.statut,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'virtual_transaction_id': virtualTransactionId,
      'transaction_type': transactionType,
      'montant': montant,
      'devise': devise,
      'destinataire': destinataire,
      'expediteur': expediteur,
      'client_nom': clientNom,
      'requested_by_admin_id': requestedByAdminId,
      'requested_by_admin_name': requestedByAdminName,
      'request_date': requestDate.toIso8601String(),
      'reason': reason,
      'validated_by_admin_id': validatedByAdminId,
      'validated_by_admin_name': validatedByAdminName,
      'validation_admin_date': validationAdminDate?.toIso8601String(),
      'validated_by_agent_id': validatedByAgentId,
      'validated_by_agent_name': validatedByAgentName,
      'validation_date': validationDate?.toIso8601String(),
      'statut': statut.name,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory VirtualTransactionDeletionRequestModel.fromJson(Map<String, dynamic> json) {
    return VirtualTransactionDeletionRequestModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      virtualTransactionId: json['virtual_transaction_id'],
      transactionType: json['transaction_type'] ?? '',
      montant: (json['montant'] ?? 0).toDouble(),
      devise: json['devise'] ?? 'USD',
      destinataire: json['destinataire'],
      expediteur: json['expediteur'],
      clientNom: json['client_nom'],
      requestedByAdminId: json['requested_by_admin_id'] ?? 0,
      requestedByAdminName: json['requested_by_admin_name'] ?? '',
      requestDate: DateTime.parse(json['request_date'] ?? DateTime.now().toIso8601String()),
      reason: json['reason'],
      validatedByAdminId: json['validated_by_admin_id'],
      validatedByAdminName: json['validated_by_admin_name'],
      validationAdminDate: json['validation_admin_date'] != null 
          ? DateTime.parse(json['validation_admin_date']) 
          : null,
      validatedByAgentId: json['validated_by_agent_id'],
      validatedByAgentName: json['validated_by_agent_name'],
      validationDate: json['validation_date'] != null 
          ? DateTime.parse(json['validation_date']) 
          : null,
      statut: VirtualTransactionDeletionRequestStatus.fromString(json['statut'] ?? 'en_attente'),
      lastModifiedAt: json['last_modified_at'] != null 
          ? DateTime.parse(json['last_modified_at']) 
          : null,
      lastModifiedBy: json['last_modified_by'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isSynced: json['is_synced'] ?? false,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  @override
  String toString() {
    return 'VirtualTransactionDeletionRequestModel(id: $id, reference: $reference, statut: ${statut.name}, requestedBy: $requestedByAdminName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VirtualTransactionDeletionRequestModel &&
        other.reference == reference &&
        other.statut == statut;
  }

  @override
  int get hashCode => reference.hashCode ^ statut.hashCode;
}
