class TransactionModel {
  final int? id;
  final String type; // 'ENVOI', 'RECEPTION', 'DEPOT', 'RETRAIT'
  final double montant;
  final String deviseSource;
  final String deviseDestination;
  final double montantConverti;
  final double tauxChange;
  final double commission;
  final double montantTotal;
  final int expediteurId; // ID du client expéditeur
  final int? destinataireId; // ID du client destinataire (optionnel pour certains types)
  final String? nomDestinataire; // Nom du destinataire si pas dans le système
  final String? telephoneDestinataire; // Téléphone du destinataire
  final String? adresseDestinataire; // Adresse du destinataire
  final int agentId; // ID de l'agent qui traite la transaction
  final int shopId; // ID du shop où la transaction est effectuée
  final String statut; // 'EN_ATTENTE', 'CONFIRMEE', 'ANNULEE', 'TERMINEE'
  final String? reference; // Référence unique de la transaction
  final String? notes; // Notes additionnelles
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  TransactionModel({
    this.id,
    required this.type,
    required this.montant,
    required this.deviseSource,
    required this.deviseDestination,
    required this.montantConverti,
    required this.tauxChange,
    required this.commission,
    required this.montantTotal,
    required this.expediteurId,
    this.destinataireId,
    this.nomDestinataire,
    this.telephoneDestinataire,
    this.adresseDestinataire,
    required this.agentId,
    required this.shopId,
    this.statut = 'EN_ATTENTE',
    this.reference,
    this.notes,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      type: json['type'],
      montant: (json['montant'] as num).toDouble(),
      deviseSource: json['devise_source'],
      deviseDestination: json['devise_destination'],
      montantConverti: (json['montant_converti'] as num).toDouble(),
      tauxChange: (json['taux_change'] as num).toDouble(),
      commission: (json['commission'] as num).toDouble(),
      montantTotal: (json['montant_total'] as num).toDouble(),
      expediteurId: json['expediteur_id'],
      destinataireId: json['destinataire_id'],
      nomDestinataire: json['nom_destinataire'],
      telephoneDestinataire: json['telephone_destinataire'],
      adresseDestinataire: json['adresse_destinataire'],
      agentId: json['agent_id'],
      shopId: json['shop_id'],
      statut: json['statut'] ?? 'EN_ATTENTE',
      reference: json['reference'],
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'montant': montant,
      'devise_source': deviseSource,
      'devise_destination': deviseDestination,
      'montant_converti': montantConverti,
      'taux_change': tauxChange,
      'commission': commission,
      'montant_total': montantTotal,
      'expediteur_id': expediteurId,
      'destinataire_id': destinataireId,
      'nom_destinataire': nomDestinataire,
      'telephone_destinataire': telephoneDestinataire,
      'adresse_destinataire': adresseDestinataire,
      'agent_id': agentId,
      'shop_id': shopId,
      'statut': statut,
      'reference': reference,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
    };
  }

  TransactionModel copyWith({
    int? id,
    String? type,
    double? montant,
    String? deviseSource,
    String? deviseDestination,
    double? montantConverti,
    double? tauxChange,
    double? commission,
    double? montantTotal,
    int? expediteurId,
    int? destinataireId,
    String? nomDestinataire,
    String? telephoneDestinataire,
    String? adresseDestinataire,
    int? agentId,
    int? shopId,
    String? statut,
    String? reference,
    String? notes,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      montant: montant ?? this.montant,
      deviseSource: deviseSource ?? this.deviseSource,
      deviseDestination: deviseDestination ?? this.deviseDestination,
      montantConverti: montantConverti ?? this.montantConverti,
      tauxChange: tauxChange ?? this.tauxChange,
      commission: commission ?? this.commission,
      montantTotal: montantTotal ?? this.montantTotal,
      expediteurId: expediteurId ?? this.expediteurId,
      destinataireId: destinataireId ?? this.destinataireId,
      nomDestinataire: nomDestinataire ?? this.nomDestinataire,
      telephoneDestinataire: telephoneDestinataire ?? this.telephoneDestinataire,
      adresseDestinataire: adresseDestinataire ?? this.adresseDestinataire,
      agentId: agentId ?? this.agentId,
      shopId: shopId ?? this.shopId,
      statut: statut ?? this.statut,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  // Méthodes utilitaires
  String get typeDisplay {
    switch (type) {
      case 'ENVOI':
        return 'Envoi d\'argent';
      case 'RECEPTION':
        return 'Réception d\'argent';
      case 'DEPOT':
        return 'Dépôt';
      case 'RETRAIT':
        return 'Retrait';
      default:
        return type;
    }
  }

  String get statutDisplay {
    switch (statut) {
      case 'EN_ATTENTE':
        return 'En attente';
      case 'CONFIRMEE':
        return 'Confirmée';
      case 'ANNULEE':
        return 'Annulée';
      case 'TERMINEE':
        return 'Terminée';
      default:
        return statut;
    }
  }

  // Générer une référence unique
  static String generateReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
    return 'UC${timestamp}';
  }
}
