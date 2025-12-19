class FichePaieModel {
  final int? id;
  final int salaireId;
  final int personnelId;
  final String reference;
  final String periode; // MM/YYYY
  final DateTime dateGeneration;
  final String? generePar;
  
  // Contenu de la fiche
  final String? contenuJson; // Données complètes en JSON
  final String? pdfPath; // Chemin vers le PDF généré
  
  final String statut; // 'Brouillon', 'Valide', 'Envoye'
  
  // Métadonnées
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool isSynced;
  final DateTime? syncedAt;

  FichePaieModel({
    this.id,
    required this.salaireId,
    required this.personnelId,
    required this.reference,
    required this.periode,
    required this.dateGeneration,
    this.generePar,
    this.contenuJson,
    this.pdfPath,
    this.statut = 'Valide',
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  });

  factory FichePaieModel.fromJson(Map<String, dynamic> json) {
    return FichePaieModel(
      id: json['id'],
      salaireId: json['salaire_id'] ?? 0,
      personnelId: json['personnel_id'] ?? 0,
      reference: json['reference'] ?? '',
      periode: json['periode'] ?? '',
      dateGeneration: json['date_generation'] != null 
          ? DateTime.parse(json['date_generation']) 
          : DateTime.now(),
      generePar: json['genere_par'],
      contenuJson: json['contenu_json'],
      pdfPath: json['pdf_path'],
      statut: json['statut'] ?? 'Valide',
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
      'salaire_id': salaireId,
      'personnel_id': personnelId,
      'reference': reference,
      'periode': periode,
      'date_generation': dateGeneration.toIso8601String(),
      'genere_par': generePar,
      'contenu_json': contenuJson,
      'pdf_path': pdfPath,
      'statut': statut,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  FichePaieModel copyWith({
    int? id,
    int? salaireId,
    int? personnelId,
    String? reference,
    String? periode,
    DateTime? dateGeneration,
    String? generePar,
    String? contenuJson,
    String? pdfPath,
    String? statut,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return FichePaieModel(
      id: id ?? this.id,
      salaireId: salaireId ?? this.salaireId,
      personnelId: personnelId ?? this.personnelId,
      reference: reference ?? this.reference,
      periode: periode ?? this.periode,
      dateGeneration: dateGeneration ?? this.dateGeneration,
      generePar: generePar ?? this.generePar,
      contenuJson: contenuJson ?? this.contenuJson,
      pdfPath: pdfPath ?? this.pdfPath,
      statut: statut ?? this.statut,
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
    return 'FDP-${now.year}${now.month.toString().padLeft(2, '0')}-$timestamp';
  }
}
