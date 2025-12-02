/// Modèle pour la clôture virtuelle détaillée par SIM
/// Chaque SIM a sa propre clôture avec solde, cash disponible et frais
class ClotureVirtuelleParSimModel {
  final int? id;
  final int shopId;
  final String simNumero;
  final String operateur;
  final DateTime dateCloture;
  
  // === SOLDES ===
  final double soldeAnterieur; // Solde au début de la journée
  final double soldeActuel; // Solde à la clôture
  
  // === CASH DISPONIBLE ===
  final double cashDisponible; // Cash physique disponible pour cette SIM
  
  // === FRAIS ===
  final double fraisAnterieur; // Frais accumulés avant aujourd'hui
  final double fraisDuJour; // Frais générés aujourd'hui
  final double fraisTotal; // Total des frais (antérieur + du jour)
  
  // === TRANSACTIONS DU JOUR ===
  final int nombreCaptures;
  final double montantCaptures;
  final int nombreServies;
  final double montantServies;
  final double cashServi;
  final int nombreEnAttente;
  final double montantEnAttente;
  
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
    required this.cashDisponible,
    required this.fraisAnterieur,
    required this.fraisDuJour,
    required this.fraisTotal,
    required this.nombreCaptures,
    required this.montantCaptures,
    required this.nombreServies,
    required this.montantServies,
    required this.cashServi,
    required this.nombreEnAttente,
    required this.montantEnAttente,
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
      'cash_disponible': cashDisponible,
      'frais_anterieur': fraisAnterieur,
      'frais_du_jour': fraisDuJour,
      'frais_total': fraisTotal,
      'nombre_captures': nombreCaptures,
      'montant_captures': montantCaptures,
      'nombre_servies': nombreServies,
      'montant_servies': montantServies,
      'cash_servi': cashServi,
      'nombre_en_attente': nombreEnAttente,
      'montant_en_attente': montantEnAttente,
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
      cashDisponible: (map['cash_disponible'] as num).toDouble(),
      fraisAnterieur: (map['frais_anterieur'] as num).toDouble(),
      fraisDuJour: (map['frais_du_jour'] as num).toDouble(),
      fraisTotal: (map['frais_total'] as num).toDouble(),
      nombreCaptures: map['nombre_captures'] as int,
      montantCaptures: (map['montant_captures'] as num).toDouble(),
      nombreServies: map['nombre_servies'] as int,
      montantServies: (map['montant_servies'] as num).toDouble(),
      cashServi: (map['cash_servi'] as num).toDouble(),
      nombreEnAttente: map['nombre_en_attente'] as int,
      montantEnAttente: (map['montant_en_attente'] as num).toDouble(),
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
    double? cashDisponible,
    double? fraisAnterieur,
    double? fraisDuJour,
    double? fraisTotal,
    int? nombreCaptures,
    double? montantCaptures,
    int? nombreServies,
    double? montantServies,
    double? cashServi,
    int? nombreEnAttente,
    double? montantEnAttente,
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
      cashDisponible: cashDisponible ?? this.cashDisponible,
      fraisAnterieur: fraisAnterieur ?? this.fraisAnterieur,
      fraisDuJour: fraisDuJour ?? this.fraisDuJour,
      fraisTotal: fraisTotal ?? this.fraisTotal,
      nombreCaptures: nombreCaptures ?? this.nombreCaptures,
      montantCaptures: montantCaptures ?? this.montantCaptures,
      nombreServies: nombreServies ?? this.nombreServies,
      montantServies: montantServies ?? this.montantServies,
      cashServi: cashServi ?? this.cashServi,
      nombreEnAttente: nombreEnAttente ?? this.nombreEnAttente,
      montantEnAttente: montantEnAttente ?? this.montantEnAttente,
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
