/// Modèle pour les échanges de crédit virtuel entre SIMs
class VirtualExchangeModel {
  final int? id;
  final String simSource; // SIM qui donne le crédit
  final String simDestination; // SIM qui reçoit le crédit
  final String? simSourceOperateur;
  final String? simDestinationOperateur;
  final double montant;
  final String devise; // USD ou CDF
  final double soldeSourceAvant; // Solde SIM source avant échange
  final double soldeSourceApres; // Solde SIM source après échange
  final double soldeDestinationAvant; // Solde SIM destination avant échange
  final double soldeDestinationApres; // Solde SIM destination après échange
  final int shopId; // Shop qui effectue l'échange
  final String? shopDesignation;
  final int agentId; // Agent qui effectue l'échange
  final String? agentUsername;
  final String? notes;
  final VirtualExchangeStatus statut;
  final DateTime dateEchange;
  final DateTime? dateValidation; // Quand l'échange est validé
  final String? reference; // Référence unique de l'échange
  
  // Synchronization
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  VirtualExchangeModel({
    this.id,
    required this.simSource,
    required this.simDestination,
    this.simSourceOperateur,
    this.simDestinationOperateur,
    required this.montant,
    this.devise = 'USD',
    required this.soldeSourceAvant,
    required this.soldeSourceApres,
    required this.soldeDestinationAvant,
    required this.soldeDestinationApres,
    required this.shopId,
    this.shopDesignation,
    required this.agentId,
    this.agentUsername,
    this.notes,
    this.statut = VirtualExchangeStatus.enAttente,
    required this.dateEchange,
    this.dateValidation,
    this.reference,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  VirtualExchangeModel copyWith({
    int? id,
    String? simSource,
    String? simDestination,
    String? simSourceOperateur,
    String? simDestinationOperateur,
    double? montant,
    String? devise,
    double? soldeSourceAvant,
    double? soldeSourceApres,
    double? soldeDestinationAvant,
    double? soldeDestinationApres,
    int? shopId,
    String? shopDesignation,
    int? agentId,
    String? agentUsername,
    String? notes,
    VirtualExchangeStatus? statut,
    DateTime? dateEchange,
    DateTime? dateValidation,
    String? reference,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return VirtualExchangeModel(
      id: id ?? this.id,
      simSource: simSource ?? this.simSource,
      simDestination: simDestination ?? this.simDestination,
      simSourceOperateur: simSourceOperateur ?? this.simSourceOperateur,
      simDestinationOperateur: simDestinationOperateur ?? this.simDestinationOperateur,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      soldeSourceAvant: soldeSourceAvant ?? this.soldeSourceAvant,
      soldeSourceApres: soldeSourceApres ?? this.soldeSourceApres,
      soldeDestinationAvant: soldeDestinationAvant ?? this.soldeDestinationAvant,
      soldeDestinationApres: soldeDestinationApres ?? this.soldeDestinationApres,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      notes: notes ?? this.notes,
      statut: statut ?? this.statut,
      dateEchange: dateEchange ?? this.dateEchange,
      dateValidation: dateValidation ?? this.dateValidation,
      reference: reference ?? this.reference,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sim_source': simSource,
      'sim_destination': simDestination,
      'sim_source_operateur': simSourceOperateur,
      'sim_destination_operateur': simDestinationOperateur,
      'montant': montant,
      'devise': devise,
      'solde_source_avant': soldeSourceAvant,
      'solde_source_apres': soldeSourceApres,
      'solde_destination_avant': soldeDestinationAvant,
      'solde_destination_apres': soldeDestinationApres,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'notes': notes,
      'statut': statut.name,
      'date_echange': dateEchange.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'reference': reference,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory VirtualExchangeModel.fromJson(Map<String, dynamic> json) {
    return VirtualExchangeModel(
      id: json['id'] as int?,
      simSource: (json['sim_source'] as String?) ?? '',
      simDestination: (json['sim_destination'] as String?) ?? '',
      simSourceOperateur: json['sim_source_operateur'] as String?,
      simDestinationOperateur: json['sim_destination_operateur'] as String?,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
      soldeSourceAvant: (json['solde_source_avant'] as num?)?.toDouble() ?? 0.0,
      soldeSourceApres: (json['solde_source_apres'] as num?)?.toDouble() ?? 0.0,
      soldeDestinationAvant: (json['solde_destination_avant'] as num?)?.toDouble() ?? 0.0,
      soldeDestinationApres: (json['solde_destination_apres'] as num?)?.toDouble() ?? 0.0,
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      agentId: (json['agent_id'] as int?) ?? 0,
      agentUsername: json['agent_username'] as String?,
      notes: json['notes'] as String?,
      statut: VirtualExchangeStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => VirtualExchangeStatus.enAttente,
      ),
      dateEchange: json['date_echange'] != null
          ? DateTime.parse(json['date_echange'] as String)
          : DateTime.now(),
      dateValidation: json['date_validation'] != null
          ? DateTime.parse(json['date_validation'] as String)
          : null,
      reference: json['reference'] as String?,
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
      case VirtualExchangeStatus.enAttente:
        return 'En Attente';
      case VirtualExchangeStatus.valide:
        return 'Validé';
      case VirtualExchangeStatus.annule:
        return 'Annulé';
    }
  }

  /// Génère une référence unique pour l'échange
  static String generateReference() {
    final now = DateTime.now();
    final timestamp = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'VEX$timestamp${now.millisecond.toString().padLeft(3, '0').substring(0, 2)}';
  }

  @override
  String toString() {
    return 'VirtualExchange(id: $id, ${simSource} → ${simDestination}, montant: $montant $devise, statut: ${statut.name})';
  }
}

enum VirtualExchangeStatus {
  enAttente,  // En attente de validation
  valide,     // Échange validé et effectué
  annule,     // Échange annulé
}
