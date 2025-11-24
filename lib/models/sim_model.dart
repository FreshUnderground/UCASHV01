/// Modèle pour la gestion des cartes SIM
class SimModel {
  final int? id;
  final String numero;
  final String operateur; // Airtel, Vodacom, Orange, Africell
  final int shopId;
  final String? shopDesignation;
  final double soldeInitial;
  final double soldeActuel;
  final SimStatus statut;
  final String? motifSuspension;
  final DateTime dateCreation;
  final DateTime? dateSuspension;
  final String? creePar;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  SimModel({
    this.id,
    required this.numero,
    required this.operateur,
    required this.shopId,
    this.shopDesignation,
    this.soldeInitial = 0.0,
    this.soldeActuel = 0.0,
    this.statut = SimStatus.active,
    this.motifSuspension,
    required this.dateCreation,
    this.dateSuspension,
    this.creePar,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  SimModel copyWith({
    int? id,
    String? numero,
    String? operateur,
    int? shopId,
    String? shopDesignation,
    double? soldeInitial,
    double? soldeActuel,
    SimStatus? statut,
    String? motifSuspension,
    DateTime? dateCreation,
    DateTime? dateSuspension,
    String? creePar,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return SimModel(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      operateur: operateur ?? this.operateur,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      soldeInitial: soldeInitial ?? this.soldeInitial,
      soldeActuel: soldeActuel ?? this.soldeActuel,
      statut: statut ?? this.statut,
      motifSuspension: motifSuspension ?? this.motifSuspension,
      dateCreation: dateCreation ?? this.dateCreation,
      dateSuspension: dateSuspension ?? this.dateSuspension,
      creePar: creePar ?? this.creePar,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'operateur': operateur,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'solde_initial': soldeInitial,
      'solde_actuel': soldeActuel,
      'statut': statut.name,
      'motif_suspension': motifSuspension,
      'date_creation': dateCreation.toIso8601String(),
      'date_suspension': dateSuspension?.toIso8601String(),
      'cree_par': creePar,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory SimModel.fromJson(Map<String, dynamic> json) {
    return SimModel(
      id: json['id'] as int?,
      numero: (json['numero'] as String?) ?? '',
      operateur: (json['operateur'] as String?) ?? '',
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      soldeInitial: (json['solde_initial'] as num?)?.toDouble() ?? 0.0,
      soldeActuel: (json['solde_actuel'] as num?)?.toDouble() ?? 0.0,
      statut: SimStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => SimStatus.active,
      ),
      motifSuspension: json['motif_suspension'] as String?,
      dateCreation: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : DateTime.now(),
      dateSuspension: json['date_suspension'] != null
          ? DateTime.parse(json['date_suspension'] as String)
          : null,
      creePar: json['cree_par'] as String?,
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
      case SimStatus.active:
        return 'Active';
      case SimStatus.suspendue:
        return 'Suspendue';
      case SimStatus.perdue:
        return 'Perdue';
      case SimStatus.desactivee:
        return 'Désactivée';
    }
  }
}

enum SimStatus {
  active,
  suspendue,
  perdue,
  desactivee,
}
