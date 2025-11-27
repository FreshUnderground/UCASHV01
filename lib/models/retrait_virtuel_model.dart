/// Modèle pour les retraits virtuels (diminution du solde SIM)
class RetraitVirtuelModel {
  final int? id;
  final String simNumero;
  final String? simOperateur;
  final int shopSourceId; // Shop qui fait le retrait
  final String? shopSourceDesignation;
  final int shopDebiteurId; // Shop qui doit l'argent
  final String? shopDebiteurDesignation;
  final double montant;
  final String devise;
  final double soldeAvant; // Solde de la SIM avant le retrait
  final double soldeApres;  // Solde de la SIM après le retrait
  final int agentId;
  final String? agentUsername;
  final String? notes;
  final RetraitVirtuelStatus statut;
  final DateTime dateRetrait;
  final DateTime? dateRemboursement; // Quand le flot de remboursement est reçu
  final int? flotRemboursementId; // ID du flot qui a remboursé
  
  // Synchronization
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  RetraitVirtuelModel({
    this.id,
    required this.simNumero,
    this.simOperateur,
    required this.shopSourceId,
    this.shopSourceDesignation,
    required this.shopDebiteurId,
    this.shopDebiteurDesignation,
    required this.montant,
    this.devise = 'USD',
    required this.soldeAvant,
    required this.soldeApres,
    required this.agentId,
    this.agentUsername,
    this.notes,
    this.statut = RetraitVirtuelStatus.enAttente,
    required this.dateRetrait,
    this.dateRemboursement,
    this.flotRemboursementId,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  RetraitVirtuelModel copyWith({
    int? id,
    String? simNumero,
    String? simOperateur,
    int? shopSourceId,
    String? shopSourceDesignation,
    int? shopDebiteurId,
    String? shopDebiteurDesignation,
    double? montant,
    String? devise,
    double? soldeAvant,
    double? soldeApres,
    int? agentId,
    String? agentUsername,
    String? notes,
    RetraitVirtuelStatus? statut,
    DateTime? dateRetrait,
    DateTime? dateRemboursement,
    int? flotRemboursementId,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return RetraitVirtuelModel(
      id: id ?? this.id,
      simNumero: simNumero ?? this.simNumero,
      simOperateur: simOperateur ?? this.simOperateur,
      shopSourceId: shopSourceId ?? this.shopSourceId,
      shopSourceDesignation: shopSourceDesignation ?? this.shopSourceDesignation,
      shopDebiteurId: shopDebiteurId ?? this.shopDebiteurId,
      shopDebiteurDesignation: shopDebiteurDesignation ?? this.shopDebiteurDesignation,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      soldeAvant: soldeAvant ?? this.soldeAvant,
      soldeApres: soldeApres ?? this.soldeApres,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      notes: notes ?? this.notes,
      statut: statut ?? this.statut,
      dateRetrait: dateRetrait ?? this.dateRetrait,
      dateRemboursement: dateRemboursement ?? this.dateRemboursement,
      flotRemboursementId: flotRemboursementId ?? this.flotRemboursementId,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sim_numero': simNumero,
      'sim_operateur': simOperateur,
      'shop_source_id': shopSourceId,
      'shop_source_designation': shopSourceDesignation,
      'shop_debiteur_id': shopDebiteurId,
      'shop_debiteur_designation': shopDebiteurDesignation,
      'montant': montant,
      'devise': devise,
      'solde_avant': soldeAvant,
      'solde_apres': soldeApres,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'notes': notes,
      'statut': statut.name,
      'date_retrait': dateRetrait.toIso8601String(),
      'date_remboursement': dateRemboursement?.toIso8601String(),
      'flot_remboursement_id': flotRemboursementId,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory RetraitVirtuelModel.fromJson(Map<String, dynamic> json) {
    return RetraitVirtuelModel(
      id: json['id'] as int?,
      simNumero: (json['sim_numero'] as String?) ?? '',
      simOperateur: json['sim_operateur'] as String?,
      shopSourceId: (json['shop_source_id'] as int?) ?? 0,
      shopSourceDesignation: json['shop_source_designation'] as String?,
      shopDebiteurId: (json['shop_debiteur_id'] as int?) ?? 0,
      shopDebiteurDesignation: json['shop_debiteur_designation'] as String?,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
      soldeAvant: (json['solde_avant'] as num?)?.toDouble() ?? 0.0,
      soldeApres: (json['solde_apres'] as num?)?.toDouble() ?? 0.0,
      agentId: (json['agent_id'] as int?) ?? 0,
      agentUsername: json['agent_username'] as String?,
      notes: json['notes'] as String?,
      statut: RetraitVirtuelStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => RetraitVirtuelStatus.enAttente,
      ),
      dateRetrait: json['date_retrait'] != null
          ? DateTime.parse(json['date_retrait'] as String)
          : DateTime.now(),
      dateRemboursement: json['date_remboursement'] != null
          ? DateTime.parse(json['date_remboursement'] as String)
          : null,
      flotRemboursementId: json['flot_remboursement_id'] as int?,
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

  String get statutLabel {
    switch (statut) {
      case RetraitVirtuelStatus.enAttente:
        return 'En Attente de Remboursement';
      case RetraitVirtuelStatus.rembourse:
        return 'Remboursé';
      case RetraitVirtuelStatus.annule:
        return 'Annulé';
    }
  }

  @override
  String toString() {
    return 'RetraitVirtuel(id: $id, SIM: $simNumero, montant: $montant $devise, '
        'shopDebiteur: $shopDebiteurDesignation, statut: ${statut.name})';
  }
}

enum RetraitVirtuelStatus {
  enAttente,  // En attente de remboursement
  rembourse,  // Remboursé par flot
  annule,     // Annulé
}
