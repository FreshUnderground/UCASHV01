import 'dart:convert';

// Modèle pour l'historique des paiements d'un salaire et des avances
class PaiementSalaireModel {
  final DateTime datePaiement;
  final double montant;
  final String? modePaiement;
  final String? agentPaiement;
  final String? notes;
  final String type; // 'salaire', 'avance', 'remboursement_avance'
  final String? referenceAvance; // Référence de l'avance si applicable
  final bool isDeduction; // true si c'est une déduction (remboursement avance)

  PaiementSalaireModel({
    required this.datePaiement,
    required this.montant,
    this.modePaiement,
    this.agentPaiement,
    this.notes,
    this.type = 'salaire',
    this.referenceAvance,
    this.isDeduction = false,
  });

  Map<String, dynamic> toJson() => {
    'datePaiement': datePaiement.toIso8601String(),
    'montant': montant,
    'modePaiement': modePaiement,
    'agentPaiement': agentPaiement,
    'notes': notes,
    'type': type,
    'referenceAvance': referenceAvance,
    'isDeduction': isDeduction,
  };

  factory PaiementSalaireModel.fromJson(Map<String, dynamic> json) {
    return PaiementSalaireModel(
      datePaiement: DateTime.parse(json['datePaiement']),
      montant: (json['montant'] as num).toDouble(),
      modePaiement: json['modePaiement'],
      agentPaiement: json['agentPaiement'],
      notes: json['notes'],
      type: json['type'] ?? 'salaire',
      referenceAvance: json['referenceAvance'],
      isDeduction: json['isDeduction'] ?? false,
    );
  }

  /// Créer un paiement d'avance
  factory PaiementSalaireModel.avance({
    required DateTime dateAvance,
    required double montant,
    required String referenceAvance,
    String? modePaiement,
    String? agentPaiement,
    String? notes,
  }) {
    return PaiementSalaireModel(
      datePaiement: dateAvance,
      montant: montant,
      modePaiement: modePaiement ?? 'Especes',
      agentPaiement: agentPaiement,
      notes: notes,
      type: 'avance',
      referenceAvance: referenceAvance,
      isDeduction: false,
    );
  }

  /// Créer un remboursement d'avance (déduction)
  factory PaiementSalaireModel.remboursementAvance({
    required DateTime dateRemboursement,
    required double montant,
    required String referenceAvance,
    String? notes,
  }) {
    return PaiementSalaireModel(
      datePaiement: dateRemboursement,
      montant: montant,
      modePaiement: 'Deduction',
      agentPaiement: 'Système',
      notes: notes ?? 'Remboursement avance automatique',
      type: 'remboursement_avance',
      referenceAvance: referenceAvance,
      isDeduction: true,
    );
  }

  /// Obtenir l'icône selon le type
  String get typeIcon {
    switch (type) {
      case 'avance':
        return '💰';
      case 'remboursement_avance':
        return '↩️';
      case 'salaire':
      default:
        return '💵';
    }
  }

  /// Obtenir la description du type
  String get typeDescription {
    switch (type) {
      case 'avance':
        return 'Avance sur salaire';
      case 'remboursement_avance':
        return 'Remboursement avance';
      case 'salaire':
      default:
        return 'Paiement salaire';
    }
  }
}

class SalaireModel {
  final int? id;
  final String reference;
  final int personnelId;
  final String? personnelNom;
  final int mois;
  final int annee;
  final String periode;
  
  final double salaireBase;
  final double primeTransport;
  final double primeLogement;
  final double primeFonction;
  final double autresPrimes;
  final double heuresSupplementaires;
  final double bonus;
  
  // Avantages en nature (RDC)
  final double avantageNatureLogement;
  final double avantageNatureVoiture;
  final double autresAvantagesNature;
  
  // Suppléments RDC
  final double supplementWeekend; // Travail week-end
  final double supplementJoursFeries; // Travail jours fériés
  final double allocationsFamiliales; // Selon nombre d'enfants
  
  final double avancesDeduites;
  final double creditsDeduits;
  final double impots; // IPR - Impôt Professionnel sur Rémunération
  final double cotisationCnss; // Cotisation INSS
  final double autresDeductions;
  final double retenueDisciplinaire; // Sanctions
  final double retenueAbsences; // Absences non justifiées
  
  final double salaireBrut;
  final double totalDeductions;
  final double salaireNet;
  final double netImposable; // Net imposable pour déclaration fiscale
  
  final String devise;
  final DateTime? datePaiement;
  final String modePaiement;
  final String statut;
  final double montantPaye;
  final String? notes;
  final String? agentPaiement;
  
  // Historique des paiements (stocké en JSON dans la BDD)
  final String? historiquePaiementsJson;
  
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool isSynced;
  final DateTime? syncedAt;

  SalaireModel({
    this.id,
    required this.reference,
    required this.personnelId,
    this.personnelNom,
    required this.mois,
    required this.annee,
    required this.periode,
    this.salaireBase = 0.0,
    this.primeTransport = 0.0,
    this.primeLogement = 0.0,
    this.primeFonction = 0.0,
    this.autresPrimes = 0.0,
    this.heuresSupplementaires = 0.0,
    this.bonus = 0.0,
    this.avantageNatureLogement = 0.0,
    this.avantageNatureVoiture = 0.0,
    this.autresAvantagesNature = 0.0,
    this.supplementWeekend = 0.0,
    this.supplementJoursFeries = 0.0,
    this.allocationsFamiliales = 0.0,
    this.avancesDeduites = 0.0,
    this.creditsDeduits = 0.0,
    this.impots = 0.0,
    this.cotisationCnss = 0.0,
    this.autresDeductions = 0.0,
    this.retenueDisciplinaire = 0.0,
    this.retenueAbsences = 0.0,
    double? salaireBrut,
    double? totalDeductions,
    double? salaireNet,
    double? netImposable,
    this.devise = 'USD',
    this.datePaiement,
    this.modePaiement = 'Especes',
    this.statut = 'En_Attente',
    this.montantPaye = 0.0,
    this.notes,
    this.agentPaiement,
    this.historiquePaiementsJson,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  })  : salaireBrut = salaireBrut ?? (salaireBase + primeTransport + primeLogement + primeFonction + autresPrimes + heuresSupplementaires + bonus + avantageNatureLogement + avantageNatureVoiture + autresAvantagesNature + supplementWeekend + supplementJoursFeries + allocationsFamiliales),
        totalDeductions = totalDeductions ?? (avancesDeduites + creditsDeduits + impots + cotisationCnss + autresDeductions + retenueDisciplinaire + retenueAbsences),
        salaireNet = salaireNet ?? ((salaireBrut ?? (salaireBase + primeTransport + primeLogement + primeFonction + autresPrimes + heuresSupplementaires + bonus + avantageNatureLogement + avantageNatureVoiture + autresAvantagesNature + supplementWeekend + supplementJoursFeries + allocationsFamiliales)) - (totalDeductions ?? (avancesDeduites + creditsDeduits + impots + cotisationCnss + autresDeductions + retenueDisciplinaire + retenueAbsences))),
        netImposable = netImposable ?? ((salaireBrut ?? 0) - cotisationCnss);

  double get montantRestant => salaireNet - montantPaye;
  double get pourcentagePaye => salaireNet > 0 ? (montantPaye / salaireNet * 100) : 0;
  
  // Parser l'historique des paiements depuis JSON
  List<PaiementSalaireModel> get historiquePaiements {
    if (historiquePaiementsJson == null || historiquePaiementsJson!.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = json.decode(historiquePaiementsJson!);
      return jsonList.map((json) => PaiementSalaireModel.fromJson(json)).toList()
        ..sort((a, b) => b.datePaiement.compareTo(a.datePaiement)); // Trier par date décroissante
    } catch (e) {
      return [];
    }
  }

  /// Obtenir seulement les paiements de salaire
  List<PaiementSalaireModel> get paiementsSalaire {
    return historiquePaiements.where((p) => p.type == 'salaire').toList();
  }

  /// Obtenir seulement les avances
  List<PaiementSalaireModel> get avancesRecues {
    return historiquePaiements.where((p) => p.type == 'avance').toList();
  }

  /// Obtenir seulement les remboursements d'avances
  List<PaiementSalaireModel> get remboursementsAvances {
    return historiquePaiements.where((p) => p.type == 'remboursement_avance').toList();
  }

  /// Calculer le total des avances reçues
  double get totalAvancesRecues {
    return avancesRecues.fold<double>(0.0, (sum, p) => sum + p.montant);
  }

  /// Calculer le total des remboursements d'avances
  double get totalRemboursementsAvances {
    return remboursementsAvances.fold<double>(0.0, (sum, p) => sum + p.montant);
  }

  factory SalaireModel.fromJson(Map<String, dynamic> json) {
    return SalaireModel(
      id: json['id'],
      reference: json['reference'] ?? '',
      personnelId: json['personnel_id'] ?? 0,
      personnelNom: json['personnel_nom'],
      mois: json['mois'] ?? 1,
      annee: json['annee'] ?? DateTime.now().year,
      periode: json['periode'] ?? '',
      salaireBase: json['salaire_base'] != null ? double.tryParse(json['salaire_base'].toString()) ?? 0.0 : 0.0,
      primeTransport: json['prime_transport'] != null ? double.tryParse(json['prime_transport'].toString()) ?? 0.0 : 0.0,
      primeLogement: json['prime_logement'] != null ? double.tryParse(json['prime_logement'].toString()) ?? 0.0 : 0.0,
      primeFonction: json['prime_fonction'] != null ? double.tryParse(json['prime_fonction'].toString()) ?? 0.0 : 0.0,
      autresPrimes: json['autres_primes'] != null ? double.tryParse(json['autres_primes'].toString()) ?? 0.0 : 0.0,
      heuresSupplementaires: json['heures_supplementaires'] != null ? double.tryParse(json['heures_supplementaires'].toString()) ?? 0.0 : 0.0,
      bonus: json['bonus'] != null ? double.tryParse(json['bonus'].toString()) ?? 0.0 : 0.0,
      avantageNatureLogement: json['avantage_nature_logement'] != null ? double.tryParse(json['avantage_nature_logement'].toString()) ?? 0.0 : 0.0,
      avantageNatureVoiture: json['avantage_nature_voiture'] != null ? double.tryParse(json['avantage_nature_voiture'].toString()) ?? 0.0 : 0.0,
      autresAvantagesNature: json['autres_avantages_nature'] != null ? double.tryParse(json['autres_avantages_nature'].toString()) ?? 0.0 : 0.0,
      supplementWeekend: json['supplement_weekend'] != null ? double.tryParse(json['supplement_weekend'].toString()) ?? 0.0 : 0.0,
      supplementJoursFeries: json['supplement_jours_feries'] != null ? double.tryParse(json['supplement_jours_feries'].toString()) ?? 0.0 : 0.0,
      allocationsFamiliales: json['allocations_familiales'] != null ? double.tryParse(json['allocations_familiales'].toString()) ?? 0.0 : 0.0,
      avancesDeduites: json['avances_deduites'] != null ? double.tryParse(json['avances_deduites'].toString()) ?? 0.0 : 0.0,
      creditsDeduits: json['credits_deduits'] != null ? double.tryParse(json['credits_deduits'].toString()) ?? 0.0 : 0.0,
      impots: json['impots'] != null ? double.tryParse(json['impots'].toString()) ?? 0.0 : 0.0,
      cotisationCnss: json['cotisation_cnss'] != null ? double.tryParse(json['cotisation_cnss'].toString()) ?? 0.0 : 0.0,
      autresDeductions: json['autres_deductions'] != null ? double.tryParse(json['autres_deductions'].toString()) ?? 0.0 : 0.0,
      retenueDisciplinaire: json['retenue_disciplinaire'] != null ? double.tryParse(json['retenue_disciplinaire'].toString()) ?? 0.0 : 0.0,
      retenueAbsences: json['retenue_absences'] != null ? double.tryParse(json['retenue_absences'].toString()) ?? 0.0 : 0.0,
      salaireBrut: json['salaire_brut'] != null ? double.tryParse(json['salaire_brut'].toString()) ?? 0.0 : null,
      totalDeductions: json['total_deductions'] != null ? double.tryParse(json['total_deductions'].toString()) ?? 0.0 : null,
      salaireNet: json['salaire_net'] != null ? double.tryParse(json['salaire_net'].toString()) ?? 0.0 : null,
      netImposable: json['net_imposable'] != null ? double.tryParse(json['net_imposable'].toString()) ?? 0.0 : null,
      devise: json['devise'] ?? 'USD',
      datePaiement: json['date_paiement'] != null ? DateTime.parse(json['date_paiement']) : null,
      modePaiement: json['mode_paiement'] ?? 'Especes',
      statut: json['statut'] ?? 'En_Attente',
      montantPaye: json['montant_paye'] != null ? double.tryParse(json['montant_paye'].toString()) ?? 0.0 : 0.0,
      notes: json['notes'],
      agentPaiement: json['agent_paiement'],
      historiquePaiementsJson: json['historique_paiements_json'],
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'personnel_id': personnelId,
      'personnel_nom': personnelNom,
      'mois': mois,
      'annee': annee,
      'periode': periode,
      'salaire_base': salaireBase,
      'prime_transport': primeTransport,
      'prime_logement': primeLogement,
      'prime_fonction': primeFonction,
      'autres_primes': autresPrimes,
      'heures_supplementaires': heuresSupplementaires,
      'bonus': bonus,
      'avantage_nature_logement': avantageNatureLogement,
      'avantage_nature_voiture': avantageNatureVoiture,
      'autres_avantages_nature': autresAvantagesNature,
      'supplement_weekend': supplementWeekend,
      'supplement_jours_feries': supplementJoursFeries,
      'allocations_familiales': allocationsFamiliales,
      'avances_deduites': avancesDeduites,
      'credits_deduits': creditsDeduits,
      'impots': impots,
      'cotisation_cnss': cotisationCnss,
      'autres_deductions': autresDeductions,
      'retenue_disciplinaire': retenueDisciplinaire,
      'retenue_absences': retenueAbsences,
      'salaire_brut': salaireBrut,
      'total_deductions': totalDeductions,
      'salaire_net': salaireNet,
      'net_imposable': netImposable,
      'devise': devise,
      'date_paiement': datePaiement?.toString().split(' ')[0],
      'mode_paiement': modePaiement,
      'statut': statut,
      'montant_paye': montantPaye,
      'notes': notes,
      'agent_paiement': agentPaiement,
      'historique_paiements_json': historiquePaiementsJson,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  SalaireModel copyWith({
    int? id,
    String? reference,
    int? personnelId,
    String? personnelNom,
    int? mois,
    int? annee,
    String? periode,
    double? salaireBase,
    double? primeTransport,
    double? primeLogement,
    double? primeFonction,
    double? autresPrimes,
    double? heuresSupplementaires,
    double? bonus,
    double? avantageNatureLogement,
    double? avantageNatureVoiture,
    double? autresAvantagesNature,
    double? supplementWeekend,
    double? supplementJoursFeries,
    double? allocationsFamiliales,
    double? avancesDeduites,
    double? creditsDeduits,
    double? impots,
    double? cotisationCnss,
    double? autresDeductions,
    double? retenueDisciplinaire,
    double? retenueAbsences,
    double? salaireBrut,
    double? totalDeductions,
    double? salaireNet,
    double? netImposable,
    String? devise,
    DateTime? datePaiement,
    String? modePaiement,
    String? statut,
    double? montantPaye,
    String? notes,
    String? agentPaiement,
    String? historiquePaiementsJson,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return SalaireModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      personnelId: personnelId ?? this.personnelId,
      personnelNom: personnelNom ?? this.personnelNom,
      mois: mois ?? this.mois,
      annee: annee ?? this.annee,
      periode: periode ?? this.periode,
      salaireBase: salaireBase ?? this.salaireBase,
      primeTransport: primeTransport ?? this.primeTransport,
      primeLogement: primeLogement ?? this.primeLogement,
      primeFonction: primeFonction ?? this.primeFonction,
      autresPrimes: autresPrimes ?? this.autresPrimes,
      heuresSupplementaires: heuresSupplementaires ?? this.heuresSupplementaires,
      bonus: bonus ?? this.bonus,
      avantageNatureLogement: avantageNatureLogement ?? this.avantageNatureLogement,
      avantageNatureVoiture: avantageNatureVoiture ?? this.avantageNatureVoiture,
      autresAvantagesNature: autresAvantagesNature ?? this.autresAvantagesNature,
      supplementWeekend: supplementWeekend ?? this.supplementWeekend,
      supplementJoursFeries: supplementJoursFeries ?? this.supplementJoursFeries,
      allocationsFamiliales: allocationsFamiliales ?? this.allocationsFamiliales,
      avancesDeduites: avancesDeduites ?? this.avancesDeduites,
      creditsDeduits: creditsDeduits ?? this.creditsDeduits,
      impots: impots ?? this.impots,
      cotisationCnss: cotisationCnss ?? this.cotisationCnss,
      autresDeductions: autresDeductions ?? this.autresDeductions,
      retenueDisciplinaire: retenueDisciplinaire ?? this.retenueDisciplinaire,
      retenueAbsences: retenueAbsences ?? this.retenueAbsences,
      salaireBrut: salaireBrut ?? this.salaireBrut,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      salaireNet: salaireNet ?? this.salaireNet,
      netImposable: netImposable ?? this.netImposable,
      devise: devise ?? this.devise,
      datePaiement: datePaiement ?? this.datePaiement,
      modePaiement: modePaiement ?? this.modePaiement,
      statut: statut ?? this.statut,
      montantPaye: montantPaye ?? this.montantPaye,
      notes: notes ?? this.notes,
      agentPaiement: agentPaiement ?? this.agentPaiement,
      historiquePaiementsJson: historiquePaiementsJson ?? this.historiquePaiementsJson,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  static String generateReference() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'SAL-${now.year}${now.month.toString().padLeft(2, '0')}-$timestamp';
  }

  static String generatePeriode(int mois, int annee) {
    return '${mois.toString().padLeft(2, '0')}/$annee';
  }

  /// Recalcule automatiquement le salaire avec de nouveaux bonus/avantages
  static SalaireModel recalculateWithBonusAndAdvantages({
    required SalaireModel salaire,
    double? newBonus,
    double? newAvantageNatureLogement,
    double? newAvantageNatureVoiture,
    double? newAutresAvantagesNature,
    double? newHeuresSupplementaires,
    double? newSupplementWeekend,
    double? newSupplementJoursFeries,
    double? newAllocationsFamiliales,
  }) {
    return salaire.copyWith(
      bonus: newBonus,
      avantageNatureLogement: newAvantageNatureLogement,
      avantageNatureVoiture: newAvantageNatureVoiture,
      autresAvantagesNature: newAutresAvantagesNature,
      heuresSupplementaires: newHeuresSupplementaires,
      supplementWeekend: newSupplementWeekend,
      supplementJoursFeries: newSupplementJoursFeries,
      allocationsFamiliales: newAllocationsFamiliales,
      lastModifiedAt: DateTime.now(),
      isSynced: false, // Marquer comme non synchronisé
    );
  }

  /// Calcule le total des avantages (bonus + avantages en nature + suppléments)
  double get totalAvantages => bonus + avantageNatureLogement + avantageNatureVoiture + 
      autresAvantagesNature + heuresSupplementaires + supplementWeekend + 
      supplementJoursFeries + allocationsFamiliales;

  /// Calcule le salaire de base avec primes (sans avantages variables)
  double get salaireBaseAvecPrimes => salaireBase + primeTransport + primeLogement + 
      primeFonction + autresPrimes;

  /// Recalcule tous les montants avec les valeurs actuelles
  SalaireModel recalculateAmounts() {
    final newSalaireBrut = salaireBase + primeTransport + primeLogement + primeFonction + 
        autresPrimes + heuresSupplementaires + bonus + avantageNatureLogement + 
        avantageNatureVoiture + autresAvantagesNature + supplementWeekend + 
        supplementJoursFeries + allocationsFamiliales;
    
    final newTotalDeductions = avancesDeduites + creditsDeduits + impots + cotisationCnss + 
        autresDeductions + retenueDisciplinaire + retenueAbsences;
    
    final newSalaireNet = newSalaireBrut - newTotalDeductions;
    final newNetImposable = newSalaireBrut - cotisationCnss;

    return copyWith(
      salaireBrut: newSalaireBrut,
      totalDeductions: newTotalDeductions,
      salaireNet: newSalaireNet,
      netImposable: newNetImposable,
      lastModifiedAt: DateTime.now(),
      isSynced: false,
    );
  }

  /// Vérifie si le salaire a des avantages variables
  bool get hasVariableAdvantages => bonus > 0 || avantageNatureLogement > 0 || 
      avantageNatureVoiture > 0 || autresAvantagesNature > 0 || heuresSupplementaires > 0 ||
      supplementWeekend > 0 || supplementJoursFeries > 0 || allocationsFamiliales > 0;

  /// Détail des avantages sous forme de texte
  String get advantagesDetails {
    List<String> details = [];
    if (bonus > 0) {
      details.add('Bonus: ${bonus.toStringAsFixed(2)} $devise');
    }
    if (avantageNatureLogement > 0) {
      details.add('Avantage logement: ${avantageNatureLogement.toStringAsFixed(2)} $devise');
    }
    if (avantageNatureVoiture > 0) {
      details.add('Avantage voiture: ${avantageNatureVoiture.toStringAsFixed(2)} $devise');
    }
    if (autresAvantagesNature > 0) {
      details.add('Autres avantages: ${autresAvantagesNature.toStringAsFixed(2)} $devise');
    }
    if (heuresSupplementaires > 0) {
      details.add('Heures supp: ${heuresSupplementaires.toStringAsFixed(2)} $devise');
    }
    if (supplementWeekend > 0) {
      details.add('Supplément weekend: ${supplementWeekend.toStringAsFixed(2)} $devise');
    }
    if (supplementJoursFeries > 0) {
      details.add('Supplément jours fériés: ${supplementJoursFeries.toStringAsFixed(2)} $devise');
    }
    if (allocationsFamiliales > 0) {
      details.add('Allocations familiales: ${allocationsFamiliales.toStringAsFixed(2)} $devise');
    }
    return details.join(', ');
  }

  /// Ajouter une avance à l'historique
  SalaireModel ajouterAvanceAHistorique({
    required DateTime dateAvance,
    required double montantAvance,
    required String referenceAvance,
    String? agentAvance,
    String? notesAvance,
  }) {
    final historique = List<PaiementSalaireModel>.from(historiquePaiements);
    
    // Ajouter l'avance
    historique.add(PaiementSalaireModel.avance(
      dateAvance: dateAvance,
      montant: montantAvance,
      referenceAvance: referenceAvance,
      agentPaiement: agentAvance,
      notes: notesAvance,
    ));
    
    // Convertir en JSON
    final historiqueJson = json.encode(
      historique.map((p) => p.toJson()).toList()
    );
    
    return copyWith(
      historiquePaiementsJson: historiqueJson,
      lastModifiedAt: DateTime.now(),
    );
  }

  /// Ajouter un remboursement d'avance à l'historique
  SalaireModel ajouterRemboursementAvanceAHistorique({
    required DateTime dateRemboursement,
    required double montantRembourse,
    required String referenceAvance,
    String? notes,
  }) {
    final historique = List<PaiementSalaireModel>.from(historiquePaiements);
    
    // Ajouter le remboursement
    historique.add(PaiementSalaireModel.remboursementAvance(
      dateRemboursement: dateRemboursement,
      montant: montantRembourse,
      referenceAvance: referenceAvance,
      notes: notes,
    ));
    
    // Convertir en JSON
    final historiqueJson = json.encode(
      historique.map((p) => p.toJson()).toList()
    );
    
    return copyWith(
      historiquePaiementsJson: historiqueJson,
      lastModifiedAt: DateTime.now(),
    );
  }
}
