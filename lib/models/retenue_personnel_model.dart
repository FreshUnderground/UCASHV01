class RetenuePersonnelModel {
  final int? id;
  final String reference;
  final String personnelMatricule;
  final String? personnelNom;
  
  final double montantTotal;
  final double montantDeduitMensuel;
  final int nombreMois;
  final int moisDebut;
  final int anneeDebut;
  
  final String motif;
  final String type; // 'Perte', 'Dette', 'Sanction', 'Autre'
  final String statut; // 'En_Cours', 'Termine', 'Annule'
  
  final double montantDejaDeduit;
  final double montantRestant;
  
  final DateTime dateCreation;
  final String? creePar;
  final String? notes;
  
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  RetenuePersonnelModel({
    this.id,
    required this.reference,
    required this.personnelMatricule,
    this.personnelNom,
    required this.montantTotal,
    double? montantDeduitMensuel,
    int? nombreMois,
    required this.moisDebut,
    required this.anneeDebut,
    required this.motif,
    this.type = 'Autre',
    this.statut = 'En_Cours',
    this.montantDejaDeduit = 0.0,
    double? montantRestant,
    DateTime? dateCreation,
    this.creePar,
    this.notes,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  })  : nombreMois = nombreMois ?? 1,
        montantDeduitMensuel = montantDeduitMensuel ?? (montantTotal / (nombreMois ?? 1)),
        montantRestant = montantRestant ?? (montantTotal - montantDejaDeduit),
        dateCreation = dateCreation ?? DateTime.now();

  static String generateReference() {
    final now = DateTime.now();
    return 'RET${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  // Vérifier si la retenue est active pour un mois/année donné
  bool isActivePourPeriode(int mois, int annee) {
    if (statut != 'En_Cours') return false;
    
    final periodeDebut = anneeDebut * 12 + moisDebut;
    final periodeFin = periodeDebut + nombreMois - 1;
    final periodeActuelle = annee * 12 + mois;
    
    return periodeActuelle >= periodeDebut && periodeActuelle <= periodeFin;
  }

  // Calculer le montant à déduire pour une période donnée
  double getMontantPourPeriode(int mois, int annee) {
    if (!isActivePourPeriode(mois, annee)) return 0.0;
    
    // Vérifier s'il reste encore du montant à déduire
    if (montantRestant <= 0) return 0.0;
    
    // Retourner le montant mensuel, ou le restant si c'est moins
    return montantRestant < montantDeduitMensuel ? montantRestant : montantDeduitMensuel;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'personnel_matricule': personnelMatricule,
    'personnel_nom': personnelNom,
    'montantTotal': montantTotal,
    'montantDeduitMensuel': montantDeduitMensuel,
    'nombreMois': nombreMois,
    'moisDebut': moisDebut,
    'anneeDebut': anneeDebut,
    'motif': motif,
    'type': type,
    'statut': statut,
    'montantDejaDeduit': montantDejaDeduit,
    'montantRestant': montantRestant,
    'dateCreation': dateCreation.toIso8601String(),
    'creePar': creePar,
    'notes': notes,
    'lastModifiedAt': lastModifiedAt?.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'isSynced': isSynced ? 1 : 0,
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory RetenuePersonnelModel.fromJson(Map<String, dynamic> json) {
    return RetenuePersonnelModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      personnelMatricule: json['personnel_matricule'] ?? '',
      personnelNom: json['personnel_nom'],
      montantTotal: (json['montantTotal'] as num).toDouble(),
      montantDeduitMensuel: (json['montantDeduitMensuel'] as num).toDouble(),
      nombreMois: json['nombreMois'],
      moisDebut: json['moisDebut'],
      anneeDebut: json['anneeDebut'],
      motif: json['motif'],
      type: json['type'] ?? 'Autre',
      statut: json['statut'] ?? 'En_Cours',
      montantDejaDeduit: (json['montantDejaDeduit'] as num?)?.toDouble() ?? 0.0,
      montantRestant: (json['montantRestant'] as num?)?.toDouble(),
      dateCreation: json['dateCreation'] != null ? DateTime.parse(json['dateCreation']) : DateTime.now(),
      creePar: json['creePar'],
      notes: json['notes'],
      lastModifiedAt: json['lastModifiedAt'] != null ? DateTime.parse(json['lastModifiedAt']) : null,
      lastModifiedBy: json['lastModifiedBy'],
      isSynced: json['isSynced'] == 1,
      syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt']) : null,
    );
  }

  RetenuePersonnelModel copyWith({
    int? id,
    String? reference,
    String? personnelMatricule,
    String? personnelNom,
    double? montantTotal,
    double? montantDeduitMensuel,
    int? nombreMois,
    int? moisDebut,
    int? anneeDebut,
    String? motif,
    String? type,
    String? statut,
    double? montantDejaDeduit,
    double? montantRestant,
    DateTime? dateCreation,
    String? creePar,
    String? notes,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return RetenuePersonnelModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      personnelMatricule: personnelMatricule ?? this.personnelMatricule,
      personnelNom: personnelNom ?? this.personnelNom,
      montantTotal: montantTotal ?? this.montantTotal,
      montantDeduitMensuel: montantDeduitMensuel ?? this.montantDeduitMensuel,
      nombreMois: nombreMois ?? this.nombreMois,
      moisDebut: moisDebut ?? this.moisDebut,
      anneeDebut: anneeDebut ?? this.anneeDebut,
      motif: motif ?? this.motif,
      type: type ?? this.type,
      statut: statut ?? this.statut,
      montantDejaDeduit: montantDejaDeduit ?? this.montantDejaDeduit,
      montantRestant: montantRestant ?? this.montantRestant,
      dateCreation: dateCreation ?? this.dateCreation,
      creePar: creePar ?? this.creePar,
      notes: notes ?? this.notes,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
