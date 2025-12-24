class AvancePersonnelModel {
  final int? id;
  final String reference;
  final String personnelMatricule; // Matricule du personnel
  final String? personnelNom; // Pour affichage
  final double montant;
  final String devise;
  final DateTime dateAvance;
  final int moisAvance; // Mois pour lequel l'avance est donnée
  final int anneeAvance; // Année pour laquelle l'avance est donnée
  
  // Remboursement
  final double montantRembourse;
  final double montantRestant;
  final String statut; // 'En_Cours', 'Rembourse', 'Annule'
  final String modeRemboursement; // 'Mensuel', 'Unique', 'Progressif'
  final int nombreMoisRemboursement;
  
  final String? motif;
  final String? notes;
  final String? accordePar;
  
  // Métadonnées
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool isSynced;
  final DateTime? syncedAt;

  AvancePersonnelModel({
    this.id,
    required this.reference,
    required this.personnelMatricule,
    this.personnelNom,
    required this.montant,
    this.devise = 'USD',
    required this.dateAvance,
    int? moisAvance,
    int? anneeAvance,
    this.montantRembourse = 0.0,
    double? montantRestant,
    this.statut = 'En_Cours',
    this.modeRemboursement = 'Mensuel',
    this.nombreMoisRemboursement = 1,
    this.motif,
    this.notes,
    this.accordePar,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  }) : montantRestant = montantRestant ?? (montant - montantRembourse),
       moisAvance = moisAvance ?? dateAvance.month,
       anneeAvance = anneeAvance ?? dateAvance.year;

  // Pourcentage remboursé
  double get pourcentageRembourse => montant > 0 ? (montantRembourse / montant * 100) : 0;

  // Montant mensuel à déduire (pour mode Mensuel)
  double get montantMensuel => nombreMoisRemboursement > 0 ? montant / nombreMoisRemboursement : montant;

  factory AvancePersonnelModel.fromJson(Map<String, dynamic> json) {
    return AvancePersonnelModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      personnelMatricule: json['personnel_matricule'] ?? '',
      personnelNom: json['personnel_nom'],
      montant: json['montant'] != null 
          ? double.tryParse(json['montant'].toString()) ?? 0.0 
          : 0.0,
      devise: json['devise'] ?? 'USD',
      dateAvance: json['date_avance'] != null 
          ? DateTime.parse(json['date_avance']) 
          : DateTime.now(),
      moisAvance: json['mois_avance'],
      anneeAvance: json['annee_avance'],
      montantRembourse: json['montant_rembourse'] != null 
          ? double.tryParse(json['montant_rembourse'].toString()) ?? 0.0 
          : 0.0,
      montantRestant: json['montant_restant'] != null 
          ? double.tryParse(json['montant_restant'].toString()) ?? null 
          : null,
      statut: json['statut'] ?? 'En_Cours',
      modeRemboursement: json['mode_remboursement'] ?? 'Mensuel',
      nombreMoisRemboursement: json['nombre_mois_remboursement'] ?? 1,
      motif: json['motif'],
      notes: json['notes'],
      accordePar: json['accorde_par'],
      lastModifiedAt: json['last_modified_at'] != null 
          ? DateTime.parse(json['last_modified_at']) 
          : null,
      lastModifiedBy: json['last_modified_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'personnel_matricule': personnelMatricule,
      'personnel_nom': personnelNom,
      'montant': montant,
      'devise': devise,
      'date_avance': dateAvance.toString().split(' ')[0],
      'mois_avance': moisAvance,
      'annee_avance': anneeAvance,
      'montant_rembourse': montantRembourse,
      'montant_restant': montantRestant,
      'statut': statut,
      'mode_remboursement': modeRemboursement,
      'nombre_mois_remboursement': nombreMoisRemboursement,
      'motif': motif,
      'notes': notes,
      'accorde_par': accordePar,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  AvancePersonnelModel copyWith({
    int? id,
    String? reference,
    String? personnelMatricule,
    String? personnelNom,
    double? montant,
    String? devise,
    DateTime? dateAvance,
    int? moisAvance,
    int? anneeAvance,
    double? montantRembourse,
    double? montantRestant,
    String? statut,
    String? modeRemboursement,
    int? nombreMoisRemboursement,
    String? motif,
    String? notes,
    String? accordePar,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return AvancePersonnelModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      personnelMatricule: personnelMatricule ?? this.personnelMatricule,
      personnelNom: personnelNom ?? this.personnelNom,
      montant: montant ?? this.montant,
      devise: devise ?? this.devise,
      dateAvance: dateAvance ?? this.dateAvance,
      moisAvance: moisAvance ?? this.moisAvance,
      anneeAvance: anneeAvance ?? this.anneeAvance,
      montantRembourse: montantRembourse ?? this.montantRembourse,
      montantRestant: montantRestant ?? this.montantRestant,
      statut: statut ?? this.statut,
      modeRemboursement: modeRemboursement ?? this.modeRemboursement,
      nombreMoisRemboursement: nombreMoisRemboursement ?? this.nombreMoisRemboursement,
      motif: motif ?? this.motif,
      notes: notes ?? this.notes,
      accordePar: accordePar ?? this.accordePar,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Générer une référence unique
  static String generateReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'AVA-${now.year}${now.month.toString().padLeft(2, '0')}-$timestamp';
  }
}
