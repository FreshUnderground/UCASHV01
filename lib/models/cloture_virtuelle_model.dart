/// Modèle pour la clôture des transactions virtuelles quotidienne
class ClotureVirtuelleModel {
  final int? id;
  final int shopId;
  final String? shopDesignation;
  final DateTime dateCloture; // Date de la clôture (fin de journée)
  
  // === TRANSACTIONS VIRTUELLES ===
  // Captures (créations)
  final int nombreCaptures;
  final double montantTotalCaptures; // Somme montantVirtuel
  
  // Servies
  final int nombreServies;
  final double montantVirtuelServies;
  final double fraisPercus; // Total des commissions
  final double cashServi; // Total montantCash servi
  
  // En attente
  final int nombreEnAttente;
  final double montantVirtuelEnAttente;
  
  // Annulées
  final int nombreAnnulees;
  final double montantVirtuelAnnulees;
  
  // === FLOTS ===
  final int nombreRetraits;
  final double montantTotalRetraits;
  final int nombreRetraitsRembourses;
  final double montantRetraitsRembourses;
  final int nombreRetraitsEnAttente;
  final double montantRetraitsEnAttente;
  
  // === SOLDES DES SIMS ===
  // Par opérateur
  final Map<String, double> soldesParOperateur; // {"Airtel": 1500.0, "Vodacom": 2000.0}
  final Map<String, int> nombreSimsParOperateur; // {"Airtel": 3, "Vodacom": 2}
  
  // Totaux
  final double soldeTotalSims; // Somme de tous les soldes SIM
  final int nombreTotalSims;
  
  // === RÉSUMÉ FINANCIER ===
  final double soldeTotalVirtuel; // = soldeTotalSims (argent dans les SIMs)
  final double cashDuAuxClients; // = montantVirtuelEnAttente (à servir) - TOUJOURS EN USD
  final double fraisTotalJournee; // Commissions du jour - TOUJOURS EN USD
  
  // Métadonnées
  final String cloturePar; // Username de l'agent qui a clôturé
  final DateTime dateEnregistrement;
  final String? notes;
  
  // Synchronization
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  ClotureVirtuelleModel({
    this.id,
    required this.shopId,
    this.shopDesignation,
    required this.dateCloture,
    required this.nombreCaptures,
    required this.montantTotalCaptures,
    required this.nombreServies,
    required this.montantVirtuelServies,
    required this.fraisPercus,
    required this.cashServi,
    required this.nombreEnAttente,
    required this.montantVirtuelEnAttente,
    required this.nombreAnnulees,
    required this.montantVirtuelAnnulees,
    required this.nombreRetraits,
    required this.montantTotalRetraits,
    required this.nombreRetraitsRembourses,
    required this.montantRetraitsRembourses,
    required this.nombreRetraitsEnAttente,
    required this.montantRetraitsEnAttente,
    required this.soldesParOperateur,
    required this.nombreSimsParOperateur,
    required this.soldeTotalSims,
    required this.nombreTotalSims,
    required this.soldeTotalVirtuel,
    required this.cashDuAuxClients,
    required this.fraisTotalJournee,
    required this.cloturePar,
    required this.dateEnregistrement,
    this.notes,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  factory ClotureVirtuelleModel.fromJson(Map<String, dynamic> json) {
    return ClotureVirtuelleModel(
      id: json['id'] as int?,
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      dateCloture: json['date_cloture'] != null
          ? DateTime.parse(json['date_cloture'] as String)
          : DateTime.now(),
      nombreCaptures: (json['nombre_captures'] as int?) ?? 0,
      montantTotalCaptures: (json['montant_total_captures'] as num?)?.toDouble() ?? 0.0,
      nombreServies: (json['nombre_servies'] as int?) ?? 0,
      montantVirtuelServies: (json['montant_virtuel_servies'] as num?)?.toDouble() ?? 0.0,
      fraisPercus: (json['frais_percus'] as num?)?.toDouble() ?? 0.0,
      cashServi: (json['cash_servi'] as num?)?.toDouble() ?? 0.0,
      nombreEnAttente: (json['nombre_en_attente'] as int?) ?? 0,
      montantVirtuelEnAttente: (json['montant_virtuel_en_attente'] as num?)?.toDouble() ?? 0.0,
      nombreAnnulees: (json['nombre_annulees'] as int?) ?? 0,
      montantVirtuelAnnulees: (json['montant_virtuel_annulees'] as num?)?.toDouble() ?? 0.0,
      nombreRetraits: (json['nombre_retraits'] as int?) ?? 0,
      montantTotalRetraits: (json['montant_total_retraits'] as num?)?.toDouble() ?? 0.0,
      nombreRetraitsRembourses: (json['nombre_retraits_rembourses'] as int?) ?? 0,
      montantRetraitsRembourses: (json['montant_retraits_rembourses'] as num?)?.toDouble() ?? 0.0,
      nombreRetraitsEnAttente: (json['nombre_retraits_en_attente'] as int?) ?? 0,
      montantRetraitsEnAttente: (json['montant_retraits_en_attente'] as num?)?.toDouble() ?? 0.0,
      soldesParOperateur: json['soldes_par_operateur'] != null
          ? Map<String, double>.from(json['soldes_par_operateur'])
          : {},
      nombreSimsParOperateur: json['nombre_sims_par_operateur'] != null
          ? Map<String, int>.from(json['nombre_sims_par_operateur'])
          : {},
      soldeTotalSims: (json['solde_total_sims'] as num?)?.toDouble() ?? 0.0,
      nombreTotalSims: (json['nombre_total_sims'] as int?) ?? 0,
      soldeTotalVirtuel: (json['solde_total_virtuel'] as num?)?.toDouble() ?? 0.0,
      cashDuAuxClients: (json['cash_du_aux_clients'] as num?)?.toDouble() ?? 0.0,
      fraisTotalJournee: (json['frais_total_journee'] as num?)?.toDouble() ?? 0.0,
      cloturePar: (json['cloture_par'] as String?) ?? '',
      dateEnregistrement: json['date_enregistrement'] != null
          ? DateTime.parse(json['date_enregistrement'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'date_cloture': dateCloture.toIso8601String().split('T')[0], // Date only
      'nombre_captures': nombreCaptures,
      'montant_total_captures': montantTotalCaptures,
      'nombre_servies': nombreServies,
      'montant_virtuel_servies': montantVirtuelServies,
      'frais_percus': fraisPercus,
      'cash_servi': cashServi,
      'nombre_en_attente': nombreEnAttente,
      'montant_virtuel_en_attente': montantVirtuelEnAttente,
      'nombre_annulees': nombreAnnulees,
      'montant_virtuel_annulees': montantVirtuelAnnulees,
      'nombre_retraits': nombreRetraits,
      'montant_total_retraits': montantTotalRetraits,
      'nombre_retraits_rembourses': nombreRetraitsRembourses,
      'montant_retraits_rembourses': montantRetraitsRembourses,
      'nombre_retraits_en_attente': nombreRetraitsEnAttente,
      'montant_retraits_en_attente': montantRetraitsEnAttente,
      'soldes_par_operateur': soldesParOperateur,
      'nombre_sims_par_operateur': nombreSimsParOperateur,
      'solde_total_sims': soldeTotalSims,
      'nombre_total_sims': nombreTotalSims,
      'solde_total_virtuel': soldeTotalVirtuel,
      'cash_du_aux_clients': cashDuAuxClients,
      'frais_total_journee': fraisTotalJournee,
      'cloture_par': cloturePar,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      if (notes != null) 'notes': notes,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  ClotureVirtuelleModel copyWith({
    int? id,
    int? shopId,
    String? shopDesignation,
    DateTime? dateCloture,
    int? nombreCaptures,
    double? montantTotalCaptures,
    int? nombreServies,
    double? montantVirtuelServies,
    double? fraisPercus,
    double? cashServi,
    int? nombreEnAttente,
    double? montantVirtuelEnAttente,
    int? nombreAnnulees,
    double? montantVirtuelAnnulees,
    int? nombreRetraits,
    double? montantTotalRetraits,
    int? nombreRetraitsRembourses,
    double? montantRetraitsRembourses,
    int? nombreRetraitsEnAttente,
    double? montantRetraitsEnAttente,
    Map<String, double>? soldesParOperateur,
    Map<String, int>? nombreSimsParOperateur,
    double? soldeTotalSims,
    int? nombreTotalSims,
    double? soldeTotalVirtuel,
    double? cashDuAuxClients,
    double? fraisTotalJournee,
    String? cloturePar,
    DateTime? dateEnregistrement,
    String? notes,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return ClotureVirtuelleModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      dateCloture: dateCloture ?? this.dateCloture,
      nombreCaptures: nombreCaptures ?? this.nombreCaptures,
      montantTotalCaptures: montantTotalCaptures ?? this.montantTotalCaptures,
      nombreServies: nombreServies ?? this.nombreServies,
      montantVirtuelServies: montantVirtuelServies ?? this.montantVirtuelServies,
      fraisPercus: fraisPercus ?? this.fraisPercus,
      cashServi: cashServi ?? this.cashServi,
      nombreEnAttente: nombreEnAttente ?? this.nombreEnAttente,
      montantVirtuelEnAttente: montantVirtuelEnAttente ?? this.montantVirtuelEnAttente,
      nombreAnnulees: nombreAnnulees ?? this.nombreAnnulees,
      montantVirtuelAnnulees: montantVirtuelAnnulees ?? this.montantVirtuelAnnulees,
      nombreRetraits: nombreRetraits ?? this.nombreRetraits,
      montantTotalRetraits: montantTotalRetraits ?? this.montantTotalRetraits,
      nombreRetraitsRembourses: nombreRetraitsRembourses ?? this.nombreRetraitsRembourses,
      montantRetraitsRembourses: montantRetraitsRembourses ?? this.montantRetraitsRembourses,
      nombreRetraitsEnAttente: nombreRetraitsEnAttente ?? this.nombreRetraitsEnAttente,
      montantRetraitsEnAttente: montantRetraitsEnAttente ?? this.montantRetraitsEnAttente,
      soldesParOperateur: soldesParOperateur ?? this.soldesParOperateur,
      nombreSimsParOperateur: nombreSimsParOperateur ?? this.nombreSimsParOperateur,
      soldeTotalSims: soldeTotalSims ?? this.soldeTotalSims,
      nombreTotalSims: nombreTotalSims ?? this.nombreTotalSims,
      soldeTotalVirtuel: soldeTotalVirtuel ?? this.soldeTotalVirtuel,
      cashDuAuxClients: cashDuAuxClients ?? this.cashDuAuxClients,
      fraisTotalJournee: fraisTotalJournee ?? this.fraisTotalJournee,
      cloturePar: cloturePar ?? this.cloturePar,
      dateEnregistrement: dateEnregistrement ?? this.dateEnregistrement,
      notes: notes ?? this.notes,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() {
    return 'ClotureVirtuelle(id: $id, shop: $shopDesignation, date: ${dateCloture.toIso8601String().split('T')[0]}, '
        'captures: $nombreCaptures, servies: $nombreServies, soldeSIMs: \$${soldeTotalSims.toStringAsFixed(2)})';
  }
}
