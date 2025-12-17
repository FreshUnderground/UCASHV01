/// Modèle pour la gestion des crédits virtuels entre shops/partenaires
/// Workflow: Shop accorde crédit → Virtuel diminue (sortie) → Paiement ultérieur → Cash augmente
class CreditVirtuelModel {
  final int? id;
  final String reference; // Référence unique du crédit
  final double montantCredit; // Montant du crédit accordé
  final String devise;
  
  // Informations bénéficiaire
  final String beneficiaireNom; // Nom du shop/partenaire bénéficiaire
  final String? beneficiaireTelephone;
  final String? beneficiaireAdresse;
  final String typeBeneficiaire; // 'shop', 'partenaire', 'autre'
  
  // Informations SIM et shop émetteur
  final String simNumero; // SIM utilisée pour la sortie virtuelle
  final int shopId; // Shop qui accorde le crédit
  final String? shopDesignation;
  
  // Informations agent
  final int agentId; // Agent qui accorde le crédit
  final String? agentUsername;
  
  // Statut du crédit
  final CreditVirtuelStatus statut;
  
  // Dates et tracking
  final DateTime dateSortie; // Date de sortie du crédit (virtuel diminue)
  final DateTime? datePaiement; // Date de paiement (cash augmente)
  final DateTime? dateEcheance; // Date limite de paiement
  final String? notes;
  
  // Informations de paiement
  final double? montantPaye; // Montant déjà payé (peut être partiel)
  final String? modePaiement; // 'cash', 'mobile_money', 'virement'
  final String? referencePaiement; // Référence du paiement
  
  // Synchronization
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  CreditVirtuelModel({
    this.id,
    required String reference,
    required this.montantCredit,
    this.devise = 'USD',
    required this.beneficiaireNom,
    this.beneficiaireTelephone,
    this.beneficiaireAdresse,
    this.typeBeneficiaire = 'shop',
    required this.simNumero,
    required this.shopId,
    this.shopDesignation,
    required this.agentId,
    this.agentUsername,
    this.statut = CreditVirtuelStatus.accorde,
    required this.dateSortie,
    this.datePaiement,
    this.dateEcheance,
    this.notes,
    this.montantPaye = 0.0,
    this.modePaiement,
    this.referencePaiement,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  }) : reference = reference.trim().toUpperCase();

  // Montant restant à payer
  double get montantRestant => montantCredit - (montantPaye ?? 0.0);
  
  // Crédit entièrement payé
  bool get estPaye => montantRestant <= 0.0;
  
  // Crédit en retard
  bool get estEnRetard {
    if (dateEcheance == null || estPaye) return false;
    return DateTime.now().isAfter(dateEcheance!);
  }

  CreditVirtuelModel copyWith({
    int? id,
    String? reference,
    double? montantCredit,
    String? devise,
    String? beneficiaireNom,
    String? beneficiaireTelephone,
    String? beneficiaireAdresse,
    String? typeBeneficiaire,
    String? simNumero,
    int? shopId,
    String? shopDesignation,
    int? agentId,
    String? agentUsername,
    CreditVirtuelStatus? statut,
    DateTime? dateSortie,
    DateTime? datePaiement,
    bool clearDatePaiement = false,
    DateTime? dateEcheance,
    bool clearDateEcheance = false,
    String? notes,
    double? montantPaye,
    String? modePaiement,
    String? referencePaiement,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return CreditVirtuelModel(
      id: id ?? this.id,
      reference: reference != null ? reference.trim().toUpperCase() : this.reference,
      montantCredit: montantCredit ?? this.montantCredit,
      devise: devise ?? this.devise,
      beneficiaireNom: beneficiaireNom ?? this.beneficiaireNom,
      beneficiaireTelephone: beneficiaireTelephone ?? this.beneficiaireTelephone,
      beneficiaireAdresse: beneficiaireAdresse ?? this.beneficiaireAdresse,
      typeBeneficiaire: typeBeneficiaire ?? this.typeBeneficiaire,
      simNumero: simNumero ?? this.simNumero,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      statut: statut ?? this.statut,
      dateSortie: dateSortie ?? this.dateSortie,
      datePaiement: clearDatePaiement ? null : (datePaiement ?? this.datePaiement),
      dateEcheance: clearDateEcheance ? null : (dateEcheance ?? this.dateEcheance),
      notes: notes ?? this.notes,
      montantPaye: montantPaye ?? this.montantPaye,
      modePaiement: modePaiement ?? this.modePaiement,
      referencePaiement: referencePaiement ?? this.referencePaiement,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'montant_credit': montantCredit,
      'devise': devise,
      'beneficiaire_nom': beneficiaireNom,
      'beneficiaire_telephone': beneficiaireTelephone,
      'beneficiaire_adresse': beneficiaireAdresse,
      'type_beneficiaire': typeBeneficiaire,
      'sim_numero': simNumero,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'statut': statut.name,
      'date_sortie': dateSortie.toIso8601String(),
      'date_paiement': datePaiement?.toIso8601String(),
      'date_echeance': dateEcheance?.toIso8601String(),
      'notes': notes,
      'montant_paye': montantPaye,
      'mode_paiement': modePaiement,
      'reference_paiement': referencePaiement,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory CreditVirtuelModel.fromJson(Map<String, dynamic> json) {
    // Gérer is_synced qui peut être bool (serveur) ou int (local)
    bool isSynced = false;
    if (json['is_synced'] != null) {
      if (json['is_synced'] is bool) {
        isSynced = json['is_synced'] as bool;
      } else if (json['is_synced'] is int) {
        isSynced = (json['is_synced'] as int) == 1;
      }
    }
    
    return CreditVirtuelModel(
      id: json['id'] as int?,
      reference: ((json['reference'] as String?) ?? '').trim().toUpperCase(),
      montantCredit: (json['montant_credit'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
      beneficiaireNom: (json['beneficiaire_nom'] as String?) ?? '',
      beneficiaireTelephone: json['beneficiaire_telephone'] as String?,
      beneficiaireAdresse: json['beneficiaire_adresse'] as String?,
      typeBeneficiaire: (json['type_beneficiaire'] as String?) ?? 'shop',
      simNumero: (json['sim_numero'] as String?) ?? '',
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      agentId: (json['agent_id'] as int?) ?? 0,
      agentUsername: json['agent_username'] as String?,
      statut: CreditVirtuelStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => CreditVirtuelStatus.accorde,
      ),
      dateSortie: json['date_sortie'] != null
          ? DateTime.parse(json['date_sortie'] as String)
          : DateTime.now(),
      datePaiement: json['date_paiement'] != null
          ? DateTime.parse(json['date_paiement'] as String)
          : null,
      dateEcheance: json['date_echeance'] != null
          ? DateTime.parse(json['date_echeance'] as String)
          : null,
      notes: json['notes'] as String?,
      montantPaye: (json['montant_paye'] as num?)?.toDouble() ?? 0.0,
      modePaiement: json['mode_paiement'] as String?,
      referencePaiement: json['reference_paiement'] as String?,
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: isSynced,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  String get statutLabel {
    switch (statut) {
      case CreditVirtuelStatus.accorde:
        return 'Accordé';
      case CreditVirtuelStatus.partiellementPaye:
        return 'Partiellement Payé';
      case CreditVirtuelStatus.paye:
        return 'Payé';
      case CreditVirtuelStatus.annule:
        return 'Annulé';
      case CreditVirtuelStatus.enRetard:
        return 'En Retard';
    }
  }

  String get typeBeneficiaireLabel {
    switch (typeBeneficiaire) {
      case 'shop':
        return 'Shop';
      case 'partenaire':
        return 'Partenaire';
      case 'autre':
        return 'Autre';
      default:
        return typeBeneficiaire;
    }
  }

  @override
  String toString() {
    return 'CreditVirtuel(id: $id, ref: $reference, montant: $montantCredit $devise, '
        'beneficiaire: $beneficiaireNom, statut: ${statut.name}, restant: $montantRestant)';
  }
}

enum CreditVirtuelStatus {
  accorde,           // Crédit accordé, virtuel diminué
  partiellementPaye, // Paiement partiel reçu
  paye,              // Entièrement payé
  annule,            // Crédit annulé
  enRetard,          // Échéance dépassée
}
