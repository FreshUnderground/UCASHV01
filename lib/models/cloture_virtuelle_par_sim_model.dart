/// Modèle pour la clôture virtuelle détaillée par SIM
/// Chaque SIM a sa propre clôture avec solde, cash disponible et frais
class ClotureVirtuelleParSimModel {
  final int? id;
  final int shopId;
  final String simNumero;
  final String operateur;
  final DateTime dateCloture;
  
  // === SOLDES ===
  final double soldeAnterieur; // Solde au début de la journée (total converti)
  final double soldeActuel; // Solde à la clôture (total converti)
  final double soldeAnterieurUSD; // Solde antérieur USD
  final double soldeAnterieurCDF; // Solde antérieur CDF
  final double soldeActuelUSD; // Solde actuel USD
  final double soldeActuelCDF; // Solde actuel CDF
  
  // === CASH DISPONIBLE ===
  final double cashDisponible; // Cash physique disponible pour cette SIM
  
  // === FRAIS ===
  final double fraisAnterieur; // Frais accumulés avant aujourd'hui
  final double fraisDuJour; // Frais générés aujourd'hui
  final double fraisTotal; // Total des frais (antérieur + du jour)
  
  // === TRANSACTIONS DU JOUR ===
  final int nombreCaptures;
  final double montantCaptures;
  final double montantCapturesUSD;
  final double montantCapturesCDF;
  final int nombreServies;
  final double montantServies;
  final double montantServiesUSD;
  final double montantServiesCDF;
  final double cashServi;
  final int nombreEnAttente;
  final double montantEnAttente;
  final double montantEnAttenteUSD;
  final double montantEnAttenteCDF;
  
  // === RETRAITS (FLOTS VIRTUELS) ===
  final int nombreRetraits;
  final double montantRetraits;
  
  // === DÉPÔTS CLIENTS ===
  final int nombreDepots;
  final double montantDepots;
  
  // === MÉTADONNÉES ===
  final String cloturePar;
  final int agentId;
  final DateTime dateEnregistrement;
  final String? notes;
  
  // === SYNCHRONISATION ===
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  ClotureVirtuelleParSimModel({
    this.id,
    required this.shopId,
    required this.simNumero,
    required this.operateur,
    required this.dateCloture,
    required this.soldeAnterieur,
    required this.soldeActuel,
    required this.soldeAnterieurUSD,
    required this.soldeAnterieurCDF,
    required this.soldeActuelUSD,
    required this.soldeActuelCDF,
    required this.cashDisponible,
    required this.fraisAnterieur,
    required this.fraisDuJour,
    required this.fraisTotal,
    required this.nombreCaptures,
    required this.montantCaptures,
    required this.montantCapturesUSD,
    required this.montantCapturesCDF,
    required this.nombreServies,
    required this.montantServies,
    required this.montantServiesUSD,
    required this.montantServiesCDF,
    required this.cashServi,
    required this.nombreEnAttente,
    required this.montantEnAttente,
    required this.montantEnAttenteUSD,
    required this.montantEnAttenteCDF,
    required this.nombreRetraits,
    required this.montantRetraits,
    required this.nombreDepots,
    required this.montantDepots,
    required this.cloturePar,
    required this.agentId,
    required this.dateEnregistrement,
    this.notes,
    this.isSynced = false,
    this.syncedAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'sim_numero': simNumero,
      'operateur': operateur,
      'date_cloture': dateCloture.toIso8601String().split('T')[0], // Date only
      'solde_anterieur': soldeAnterieur,
      'solde_actuel': soldeActuel,
      'solde_anterieur_usd': soldeAnterieurUSD,
      'solde_anterieur_cdf': soldeAnterieurCDF,
      'solde_actuel_usd': soldeActuelUSD,
      'solde_actuel_cdf': soldeActuelCDF,
      'cash_disponible': cashDisponible,
      'frais_anterieur': fraisAnterieur,
      'frais_du_jour': fraisDuJour,
      'frais_total': fraisTotal,
      'nombre_captures': nombreCaptures,
      'montant_captures': montantCaptures,
      'montant_captures_usd': montantCapturesUSD,
      'montant_captures_cdf': montantCapturesCDF,
      'nombre_servies': nombreServies,
      'montant_servies': montantServies,
      'montant_servies_usd': montantServiesUSD,
      'montant_servies_cdf': montantServiesCDF,
      'cash_servi': cashServi,
      'nombre_en_attente': nombreEnAttente,
      'montant_en_attente': montantEnAttente,
      'montant_en_attente_usd': montantEnAttenteUSD,
      'montant_en_attente_cdf': montantEnAttenteCDF,
      'nombre_retraits': nombreRetraits,
      'montant_retraits': montantRetraits,
      'nombre_depots': nombreDepots,
      'montant_depots': montantDepots,
      'cloture_par': cloturePar,
      'agent_id': agentId,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      'notes': notes,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
    };
  }

  factory ClotureVirtuelleParSimModel.fromMap(Map<String, dynamic> map) {
    return ClotureVirtuelleParSimModel(
      id: map['id'] as int?,
      shopId: map['shop_id'] as int,
      simNumero: map['sim_numero'] as String,
      operateur: map['operateur'] as String,
      dateCloture: DateTime.parse(map['date_cloture'] as String),
      soldeAnterieur: (map['solde_anterieur'] as num).toDouble(),
      soldeActuel: (map['solde_actuel'] as num).toDouble(),
      soldeAnterieurUSD: (map['solde_anterieur_usd'] as num?)?.toDouble() ?? 0.0,
      soldeAnterieurCDF: (map['solde_anterieur_cdf'] as num?)?.toDouble() ?? 0.0,
      soldeActuelUSD: (map['solde_actuel_usd'] as num?)?.toDouble() ?? 0.0,
      soldeActuelCDF: (map['solde_actuel_cdf'] as num?)?.toDouble() ?? 0.0,
      cashDisponible: (map['cash_disponible'] as num).toDouble(),
      fraisAnterieur: (map['frais_anterieur'] as num).toDouble(),
      fraisDuJour: (map['frais_du_jour'] as num).toDouble(),
      fraisTotal: (map['frais_total'] as num).toDouble(),
      nombreCaptures: map['nombre_captures'] as int,
      montantCaptures: (map['montant_captures'] as num).toDouble(),
      montantCapturesUSD: (map['montant_captures_usd'] as num?)?.toDouble() ?? 0.0,
      montantCapturesCDF: (map['montant_captures_cdf'] as num?)?.toDouble() ?? 0.0,
      nombreServies: map['nombre_servies'] as int,
      montantServies: (map['montant_servies'] as num).toDouble(),
      montantServiesUSD: (map['montant_servies_usd'] as num?)?.toDouble() ?? 0.0,
      montantServiesCDF: (map['montant_servies_cdf'] as num?)?.toDouble() ?? 0.0,
      cashServi: (map['cash_servi'] as num).toDouble(),
      nombreEnAttente: map['nombre_en_attente'] as int,
      montantEnAttente: (map['montant_en_attente'] as num).toDouble(),
      montantEnAttenteUSD: (map['montant_en_attente_usd'] as num?)?.toDouble() ?? 0.0,
      montantEnAttenteCDF: (map['montant_en_attente_cdf'] as num?)?.toDouble() ?? 0.0,
      nombreRetraits: map['nombre_retraits'] as int,
      montantRetraits: (map['montant_retraits'] as num).toDouble(),
      nombreDepots: map['nombre_depots'] as int,
      montantDepots: (map['montant_depots'] as num).toDouble(),
      cloturePar: map['cloture_par'] as String,
      agentId: map['agent_id'] as int,
      dateEnregistrement: DateTime.parse(map['date_enregistrement'] as String),
      notes: map['notes'] as String?,
      isSynced: (map['is_synced'] as int?) == 1,
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
      lastModifiedAt: map['last_modified_at'] != null ? DateTime.parse(map['last_modified_at'] as String) : null,
      lastModifiedBy: map['last_modified_by'] as String?,
    );
  }

  ClotureVirtuelleParSimModel copyWith({
    int? id,
    int? shopId,
    String? simNumero,
    String? operateur,
    DateTime? dateCloture,
    double? soldeAnterieur,
    double? soldeActuel,
    double? soldeAnterieurUSD,
    double? soldeAnterieurCDF,
    double? soldeActuelUSD,
    double? soldeActuelCDF,
    double? cashDisponible,
    double? fraisAnterieur,
    double? fraisDuJour,
    double? fraisTotal,
    int? nombreCaptures,
    double? montantCaptures,
    double? montantCapturesUSD,
    double? montantCapturesCDF,
    int? nombreServies,
    double? montantServies,
    double? montantServiesUSD,
    double? montantServiesCDF,
    double? cashServi,
    int? nombreEnAttente,
    double? montantEnAttente,
    double? montantEnAttenteUSD,
    double? montantEnAttenteCDF,
    int? nombreRetraits,
    double? montantRetraits,
    int? nombreDepots,
    double? montantDepots,
    String? cloturePar,
    int? agentId,
    DateTime? dateEnregistrement,
    String? notes,
    bool? isSynced,
    DateTime? syncedAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return ClotureVirtuelleParSimModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      simNumero: simNumero ?? this.simNumero,
      operateur: operateur ?? this.operateur,
      dateCloture: dateCloture ?? this.dateCloture,
      soldeAnterieur: soldeAnterieur ?? this.soldeAnterieur,
      soldeActuel: soldeActuel ?? this.soldeActuel,
      soldeAnterieurUSD: soldeAnterieurUSD ?? this.soldeAnterieurUSD,
      soldeAnterieurCDF: soldeAnterieurCDF ?? this.soldeAnterieurCDF,
      soldeActuelUSD: soldeActuelUSD ?? this.soldeActuelUSD,
      soldeActuelCDF: soldeActuelCDF ?? this.soldeActuelCDF,
      cashDisponible: cashDisponible ?? this.cashDisponible,
      fraisAnterieur: fraisAnterieur ?? this.fraisAnterieur,
      fraisDuJour: fraisDuJour ?? this.fraisDuJour,
      fraisTotal: fraisTotal ?? this.fraisTotal,
      nombreCaptures: nombreCaptures ?? this.nombreCaptures,
      montantCaptures: montantCaptures ?? this.montantCaptures,
      montantCapturesUSD: montantCapturesUSD ?? this.montantCapturesUSD,
      montantCapturesCDF: montantCapturesCDF ?? this.montantCapturesCDF,
      nombreServies: nombreServies ?? this.nombreServies,
      montantServies: montantServies ?? this.montantServies,
      montantServiesUSD: montantServiesUSD ?? this.montantServiesUSD,
      montantServiesCDF: montantServiesCDF ?? this.montantServiesCDF,
      cashServi: cashServi ?? this.cashServi,
      nombreEnAttente: nombreEnAttente ?? this.nombreEnAttente,
      montantEnAttente: montantEnAttente ?? this.montantEnAttente,
      montantEnAttenteUSD: montantEnAttenteUSD ?? this.montantEnAttenteUSD,
      montantEnAttenteCDF: montantEnAttenteCDF ?? this.montantEnAttenteCDF,
      nombreRetraits: nombreRetraits ?? this.nombreRetraits,
      montantRetraits: montantRetraits ?? this.montantRetraits,
      nombreDepots: nombreDepots ?? this.nombreDepots,
      montantDepots: montantDepots ?? this.montantDepots,
      cloturePar: cloturePar ?? this.cloturePar,
      agentId: agentId ?? this.agentId,
      dateEnregistrement: dateEnregistrement ?? this.dateEnregistrement,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  @override
  String toString() {
    return 'ClotureVirtuelleParSimModel(id: $id, simNumero: $simNumero, dateCloture: $dateCloture, soldeActuel: $soldeActuel, cashDisponible: $cashDisponible, fraisTotal: $fraisTotal)';
  }
}
