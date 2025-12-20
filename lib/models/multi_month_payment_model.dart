/// Modèle pour les paiements multi-mois
/// Permet de payer plusieurs mois d'un service/abonnement en une seule opération
class MultiMonthPaymentModel {
  final int? id;
  final String reference; // Référence unique du paiement multi-mois
  final String serviceType; // Type de service (abonnement, loyer, etc.)
  final String serviceDescription; // Description du service
  final double montantMensuel; // Montant mensuel unitaire
  final int nombreMois; // Nombre de mois payés
  final double montantTotal; // Montant total calculé automatiquement
  final String devise;
  
  // Bonus et heures supplémentaires
  final double bonus; // Bonus à ajouter
  final double heuresSupplementaires; // Heures supplémentaires
  final double tauxHoraireSupp; // Taux horaire pour les heures supplémentaires
  final double montantHeuresSupp; // Montant calculé des heures supplémentaires
  final double montantFinalAvecAjustements; // Montant final avec bonus et heures supp
  
  // Période couverte
  final DateTime dateDebut; // Premier mois couvert
  final DateTime dateFin; // Dernier mois couvert
  
  // Informations client/bénéficiaire
  final int? clientId;
  final String? clientNom;
  final String? clientTelephone;
  final String? numeroCompte; // Numéro de compte/contrat du service
  
  // Informations shops et agent
  final int shopId;
  final String? shopDesignation;
  final int agentId;
  final String? agentUsername;
  
  // Détails de l'opération
  final String? destinataire; // Nom du fournisseur de service
  final String? telephoneDestinataire;
  final String? notes;
  final MultiMonthPaymentStatus statut;
  
  // Dates et tracking
  final DateTime dateCreation;
  final DateTime? dateValidation;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;
  
  // Liste des mois individuels couverts par ce paiement
  final List<MonthlyPeriod> moisCouverts;

  MultiMonthPaymentModel({
    this.id,
    required this.reference,
    required this.serviceType,
    required this.serviceDescription,
    required this.montantMensuel,
    required this.nombreMois,
    required this.montantTotal,
    this.devise = 'USD',
    this.bonus = 0.0,
    this.heuresSupplementaires = 0.0,
    this.tauxHoraireSupp = 0.0,
    required this.dateDebut,
    required this.dateFin,
    this.clientId,
    this.clientNom,
    this.clientTelephone,
    this.numeroCompte,
    required this.shopId,
    this.shopDesignation,
    required this.agentId,
    this.agentUsername,
    this.destinataire,
    this.telephoneDestinataire,
    this.notes,
    this.statut = MultiMonthPaymentStatus.enAttente,
    required this.dateCreation,
    this.dateValidation,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
    required this.moisCouverts,
  }) : montantHeuresSupp = heuresSupplementaires * tauxHoraireSupp,
       montantFinalAvecAjustements = montantTotal + bonus + (heuresSupplementaires * tauxHoraireSupp);

  MultiMonthPaymentModel copyWith({
    int? id,
    String? reference,
    String? serviceType,
    String? serviceDescription,
    double? montantMensuel,
    int? nombreMois,
    double? montantTotal,
    String? devise,
    double? bonus,
    double? heuresSupplementaires,
    double? tauxHoraireSupp,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? clientId,
    String? clientNom,
    String? clientTelephone,
    String? numeroCompte,
    int? shopId,
    String? shopDesignation,
    int? agentId,
    String? agentUsername,
    String? destinataire,
    String? telephoneDestinataire,
    String? notes,
    MultiMonthPaymentStatus? statut,
    DateTime? dateCreation,
    DateTime? dateValidation,
    bool clearDateValidation = false,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
    List<MonthlyPeriod>? moisCouverts,
  }) {
    return MultiMonthPaymentModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      serviceType: serviceType ?? this.serviceType,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      montantMensuel: montantMensuel ?? this.montantMensuel,
      nombreMois: nombreMois ?? this.nombreMois,
      montantTotal: montantTotal ?? this.montantTotal,
      devise: devise ?? this.devise,
      bonus: bonus ?? this.bonus,
      heuresSupplementaires: heuresSupplementaires ?? this.heuresSupplementaires,
      tauxHoraireSupp: tauxHoraireSupp ?? this.tauxHoraireSupp,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      clientId: clientId ?? this.clientId,
      clientNom: clientNom ?? this.clientNom,
      clientTelephone: clientTelephone ?? this.clientTelephone,
      numeroCompte: numeroCompte ?? this.numeroCompte,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      destinataire: destinataire ?? this.destinataire,
      telephoneDestinataire: telephoneDestinataire ?? this.telephoneDestinataire,
      notes: notes ?? this.notes,
      statut: statut ?? this.statut,
      dateCreation: dateCreation ?? this.dateCreation,
      dateValidation: clearDateValidation ? null : (dateValidation ?? this.dateValidation),
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      moisCouverts: moisCouverts ?? this.moisCouverts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'service_type': serviceType,
      'service_description': serviceDescription,
      'montant_mensuel': montantMensuel,
      'nombre_mois': nombreMois,
      'montant_total': montantTotal,
      'devise': devise,
      'bonus': bonus,
      'heures_supplementaires': heuresSupplementaires,
      'taux_horaire_supp': tauxHoraireSupp,
      'montant_heures_supp': montantHeuresSupp,
      'montant_final_avec_ajustements': montantFinalAvecAjustements,
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': dateFin.toIso8601String(),
      'client_id': clientId,
      'client_nom': clientNom,
      'client_telephone': clientTelephone,
      'numero_compte': numeroCompte,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'destinataire': destinataire,
      'telephone_destinataire': telephoneDestinataire,
      'notes': notes,
      'statut': statut.name,
      'date_creation': dateCreation.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      'mois_couverts': moisCouverts.map((m) => m.toJson()).toList(),
    };
  }

  factory MultiMonthPaymentModel.fromJson(Map<String, dynamic> json) {
    // Gérer is_synced qui peut être bool (serveur) ou int (local)
    bool isSynced = false;
    if (json['is_synced'] != null) {
      if (json['is_synced'] is bool) {
        isSynced = json['is_synced'] as bool;
      } else if (json['is_synced'] is int) {
        isSynced = (json['is_synced'] as int) == 1;
      }
    }

    // Parser les mois couverts
    List<MonthlyPeriod> moisCouverts = [];
    if (json['mois_couverts'] != null) {
      final List<dynamic> moisList = json['mois_couverts'] as List<dynamic>;
      moisCouverts = moisList.map((m) => MonthlyPeriod.fromJson(m as Map<String, dynamic>)).toList();
    }
    
    return MultiMonthPaymentModel(
      id: json['id'] as int?,
      reference: (json['reference'] as String?) ?? '',
      serviceType: (json['service_type'] as String?) ?? '',
      serviceDescription: (json['service_description'] as String?) ?? '',
      montantMensuel: (json['montant_mensuel'] as num?)?.toDouble() ?? 0.0,
      nombreMois: (json['nombre_mois'] as int?) ?? 1,
      montantTotal: (json['montant_total'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0.0,
      heuresSupplementaires: (json['heures_supplementaires'] as num?)?.toDouble() ?? 0.0,
      tauxHoraireSupp: (json['taux_horaire_supp'] as num?)?.toDouble() ?? 0.0,
      dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'] as String)
          : DateTime.now(),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'] as String)
          : DateTime.now(),
      clientId: json['client_id'] as int?,
      clientNom: json['client_nom'] as String?,
      clientTelephone: json['client_telephone'] as String?,
      numeroCompte: json['numero_compte'] as String?,
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      agentId: (json['agent_id'] as int?) ?? 0,
      agentUsername: json['agent_username'] as String?,
      destinataire: json['destinataire'] as String?,
      telephoneDestinataire: json['telephone_destinataire'] as String?,
      notes: json['notes'] as String?,
      statut: MultiMonthPaymentStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => MultiMonthPaymentStatus.enAttente,
      ),
      dateCreation: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : DateTime.now(),
      dateValidation: json['date_validation'] != null
          ? DateTime.parse(json['date_validation'] as String)
          : null,
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: isSynced,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      moisCouverts: moisCouverts,
    );
  }

  String get statutLabel {
    switch (statut) {
      case MultiMonthPaymentStatus.enAttente:
        return 'En Attente';
      case MultiMonthPaymentStatus.validee:
        return 'Validé';
      case MultiMonthPaymentStatus.annulee:
        return 'Annulé';
    }
  }

  /// Recalcule automatiquement le montant final avec les ajustements
  static MultiMonthPaymentModel recalculateAmounts({
    required MultiMonthPaymentModel payment,
    double? newBonus,
    double? newHeuresSupplementaires,
    double? newTauxHoraireSupp,
  }) {
    final bonus = newBonus ?? payment.bonus;
    final heuresSupp = newHeuresSupplementaires ?? payment.heuresSupplementaires;
    final tauxHoraire = newTauxHoraireSupp ?? payment.tauxHoraireSupp;
    
    return payment.copyWith(
      bonus: bonus,
      heuresSupplementaires: heuresSupp,
      tauxHoraireSupp: tauxHoraire,
      lastModifiedAt: DateTime.now(),
    );
  }

  /// Calcule le montant total de base (sans ajustements)
  double get montantTotalBase => montantMensuel * nombreMois;

  /// Calcule le montant des heures supplémentaires
  double get montantHeuresSupplementairesCalcule => heuresSupplementaires * tauxHoraireSupp;

  /// Calcule le montant final avec tous les ajustements
  double get montantFinalCalcule => montantTotal + bonus + montantHeuresSupplementairesCalcule;

  /// Vérifie si le paiement a des ajustements (bonus ou heures supp)
  bool get hasAdjustments => bonus > 0 || heuresSupplementaires > 0;

  /// Détail des ajustements sous forme de texte
  String get adjustmentsDetails {
    List<String> details = [];
    if (bonus > 0) {
      details.add('Bonus: ${bonus.toStringAsFixed(2)} $devise');
    }
    if (heuresSupplementaires > 0) {
      details.add('Heures supp: ${heuresSupplementaires.toStringAsFixed(1)}h × ${tauxHoraireSupp.toStringAsFixed(2)} = ${montantHeuresSupplementairesCalcule.toStringAsFixed(2)} $devise');
    }
    return details.join(', ');
  }

  @override
  String toString() {
    return 'MultiMonthPayment(id: $id, ref: $reference, service: $serviceType, '
        'mois: $nombreMois, base: $montantTotal $devise, final: ${montantFinalCalcule.toStringAsFixed(2)} $devise, statut: ${statut.name})';
  }
}

/// Représente une période mensuelle couverte par le paiement
class MonthlyPeriod {
  final int annee;
  final int mois;
  final double montant;
  final String devise;

  MonthlyPeriod({
    required this.annee,
    required this.mois,
    required this.montant,
    this.devise = 'USD',
  });

  Map<String, dynamic> toJson() {
    return {
      'annee': annee,
      'mois': mois,
      'montant': montant,
      'devise': devise,
    };
  }

  factory MonthlyPeriod.fromJson(Map<String, dynamic> json) {
    return MonthlyPeriod(
      annee: (json['annee'] as int?) ?? DateTime.now().year,
      mois: (json['mois'] as int?) ?? DateTime.now().month,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
    );
  }

  String get monthName {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[mois - 1];
  }

  @override
  String toString() {
    return '$monthName $annee';
  }
}

enum MultiMonthPaymentStatus {
  enAttente, // Paiement enregistré, en attente de validation
  validee,   // Paiement validé et traité
  annulee,   // Paiement annulé
}

/// Types de services prédéfinis
enum ServiceType {
  abonnement,     // Abonnements (internet, TV, etc.)
  loyer,          // Loyer
  electricite,    // Facture d'électricité
  eau,            // Facture d'eau
  telephone,      // Facture téléphone
  assurance,      // Assurance
  scolarite,      // Frais de scolarité
  autre,          // Autre service
}

extension ServiceTypeExtension on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.abonnement:
        return 'Abonnement';
      case ServiceType.loyer:
        return 'Loyer';
      case ServiceType.electricite:
        return 'Électricité';
      case ServiceType.eau:
        return 'Eau';
      case ServiceType.telephone:
        return 'Téléphone';
      case ServiceType.assurance:
        return 'Assurance';
      case ServiceType.scolarite:
        return 'Scolarité';
      case ServiceType.autre:
        return 'Autre';
    }
  }

  String get icon {
    switch (this) {
      case ServiceType.abonnement:
        return '📺';
      case ServiceType.loyer:
        return '🏠';
      case ServiceType.electricite:
        return '⚡';
      case ServiceType.eau:
        return '💧';
      case ServiceType.telephone:
        return '📞';
      case ServiceType.assurance:
        return '🛡️';
      case ServiceType.scolarite:
        return '🎓';
      case ServiceType.autre:
        return '📋';
    }
  }
}
