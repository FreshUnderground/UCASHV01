import 'dart:math';

class CreditPersonnelModel {
  final int? id;
  final String reference;
  final String personnelMatricule;
  final String? personnelNom; // Pour affichage
  final double montantCredit;
  final String devise;
  final double tauxInteret; // Taux d'intérêt annuel (%)
  final DateTime dateOctroi;
  final DateTime dateEcheance;
  
  // Remboursement
  final double montantRembourse;
  final double interetsPayes;
  final double montantRestant;
  final String statut; // 'En_Cours', 'Rembourse', 'En_Retard', 'Annule'
  final int dureeMois; // Durée du crédit en mois
  final double mensualite; // Montant mensuel à rembourser
  final String modeRemboursement; // 'Mensuel', 'Unique', 'Progressif'
  final int? moisRemboursement; // Mois de remboursement unique
  final int? anneeRemboursement; // Année de remboursement unique
  
  final String? motif;
  final String? garanties;
  final String? notes;
  final String? accordePar;
  
  // Métadonnées
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool isSynced;
  final DateTime? syncedAt;

  CreditPersonnelModel({
    this.id,
    required this.reference,
    required this.personnelMatricule,
    this.personnelNom,
    required this.montantCredit,
    this.devise = 'USD',
    this.tauxInteret = 0.0,
    required this.dateOctroi,
    required this.dateEcheance,
    this.montantRembourse = 0.0,
    this.interetsPayes = 0.0,
    double? montantRestant,
    this.statut = 'En_Cours',
    required this.dureeMois,
    double? mensualite,
    this.modeRemboursement = 'Mensuel',
    this.moisRemboursement,
    this.anneeRemboursement,
    this.motif,
    this.garanties,
    this.notes,
    this.accordePar,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  })  : montantRestant = montantRestant ?? (montantCredit - montantRembourse),
        mensualite = mensualite ?? _calculateMensualite(montantCredit, tauxInteret, dureeMois);

  // Calcul de la mensualité avec intérêt
  static double _calculateMensualite(double montant, double tauxAnnuel, int dureeMois) {
    if (dureeMois <= 0) return montant;
    if (tauxAnnuel == 0) return montant / dureeMois;
    
    // Formule de calcul d'amortissement
    final tauxMensuel = tauxAnnuel / 12 / 100;
    final mensualite = montant * 
        (tauxMensuel * pow(1 + tauxMensuel, dureeMois).toDouble()) / 
        (pow(1 + tauxMensuel, dureeMois).toDouble() - 1);
    
    return mensualite;
  }

  // Montant mensuel calculé
  double get montantMensuel => mensualite;

  // Montant total à rembourser (capital + intérêts)
  double get montantTotalARembourser => mensualite * dureeMois;

  // Intérêts totaux
  double get interetsTotaux => montantTotalARembourser - montantCredit;

  // Pourcentage remboursé
  double get pourcentageRembourse => montantCredit > 0 ? (montantRembourse / montantCredit * 100) : 0;

  // Vérifier si le crédit est en retard
  bool get estEnRetard => dateEcheance.isBefore(DateTime.now()) && montantRestant > 0;

  factory CreditPersonnelModel.fromJson(Map<String, dynamic> json) {
    return CreditPersonnelModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      personnelMatricule: json['personnel_matricule'] ?? '',
      personnelNom: json['personnel_nom'],
      montantCredit: json['montant_credit'] != null 
          ? double.tryParse(json['montant_credit'].toString()) ?? 0.0 
          : 0.0,
      devise: json['devise'] ?? 'USD',
      tauxInteret: json['taux_interet'] != null 
          ? double.tryParse(json['taux_interet'].toString()) ?? 0.0 
          : 0.0,
      dateOctroi: json['date_octroi'] != null 
          ? DateTime.parse(json['date_octroi']) 
          : DateTime.now(),
      dateEcheance: json['date_echeance'] != null 
          ? DateTime.parse(json['date_echeance']) 
          : DateTime.now(),
      montantRembourse: json['montant_rembourse'] != null 
          ? double.tryParse(json['montant_rembourse'].toString()) ?? 0.0 
          : 0.0,
      interetsPayes: json['interets_payes'] != null 
          ? double.tryParse(json['interets_payes'].toString()) ?? 0.0 
          : 0.0,
      montantRestant: json['montant_restant'] != null 
          ? double.tryParse(json['montant_restant'].toString()) ?? null 
          : null,
      statut: json['statut'] ?? 'En_Cours',
      dureeMois: json['duree_mois'] ?? 1,
      mensualite: json['mensualite'] != null 
          ? double.tryParse(json['mensualite'].toString()) ?? null 
          : null,
      modeRemboursement: json['mode_remboursement'] ?? 'Mensuel',
      moisRemboursement: json['mois_remboursement'],
      anneeRemboursement: json['annee_remboursement'],
      motif: json['motif'],
      garanties: json['garanties'],
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
      'montant_credit': montantCredit,
      'devise': devise,
      'taux_interet': tauxInteret,
      'date_octroi': dateOctroi.toString().split(' ')[0],
      'date_echeance': dateEcheance.toString().split(' ')[0],
      'montant_rembourse': montantRembourse,
      'interets_payes': interetsPayes,
      'montant_restant': montantRestant,
      'statut': statut,
      'duree_mois': dureeMois,
      'mensualite': mensualite,
      'mode_remboursement': modeRemboursement,
      'mois_remboursement': moisRemboursement,
      'annee_remboursement': anneeRemboursement,
      'motif': motif,
      'garanties': garanties,
      'notes': notes,
      'accorde_par': accordePar,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  CreditPersonnelModel copyWith({
    int? id,
    String? reference,
    String? personnelMatricule,
    String? personnelNom,
    double? montantCredit,
    String? devise,
    double? tauxInteret,
    DateTime? dateOctroi,
    DateTime? dateEcheance,
    double? montantRembourse,
    double? interetsPayes,
    double? montantRestant,
    String? statut,
    int? dureeMois,
    double? mensualite,
    String? modeRemboursement,
    int? moisRemboursement,
    int? anneeRemboursement,
    String? motif,
    String? garanties,
    String? notes,
    String? accordePar,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return CreditPersonnelModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      personnelMatricule: personnelMatricule ?? this.personnelMatricule,
      personnelNom: personnelNom ?? this.personnelNom,
      montantCredit: montantCredit ?? this.montantCredit,
      devise: devise ?? this.devise,
      tauxInteret: tauxInteret ?? this.tauxInteret,
      dateOctroi: dateOctroi ?? this.dateOctroi,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      montantRembourse: montantRembourse ?? this.montantRembourse,
      interetsPayes: interetsPayes ?? this.interetsPayes,
      montantRestant: montantRestant ?? this.montantRestant,
      statut: statut ?? this.statut,
      dureeMois: dureeMois ?? this.dureeMois,
      mensualite: mensualite ?? this.mensualite,
      modeRemboursement: modeRemboursement ?? this.modeRemboursement,
      moisRemboursement: moisRemboursement ?? this.moisRemboursement,
      anneeRemboursement: anneeRemboursement ?? this.anneeRemboursement,
      motif: motif ?? this.motif,
      garanties: garanties ?? this.garanties,
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
    return 'CRE-${now.year}${now.month.toString().padLeft(2, '0')}-$timestamp';
  }
}
