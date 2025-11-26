import 'dart:convert';

/// Modèle pour la réconciliation bancaire
/// Compare le capital système vs capital réel (compté physiquement)
class ReconciliationModel {
  final int? id;
  final int shopId;
  final DateTime dateReconciliation;
  final ReconciliationPeriode periode;

  // Capital système (selon BD)
  final double capitalSystemeCash;
  final double capitalSystemeAirtel;
  final double capitalSystemeMpesa;
  final double capitalSystemeOrange;
  final double capitalSystemeTotal;

  // Capital réel (compté)
  final double capitalReelCash;
  final double capitalReelAirtel;
  final double capitalReelMpesa;
  final double capitalReelOrange;
  final double capitalReelTotal;

  // Écarts (auto-calculés côté serveur, mais on peut les stocker)
  final double? ecartCash;
  final double? ecartAirtel;
  final double? ecartMpesa;
  final double? ecartOrange;
  final double? ecartTotal;
  final double? ecartPourcentage;

  // Statut
  final ReconciliationStatut statut;
  final String? notes;
  final String? justification;

  // Devise secondaire (optionnel)
  final String? deviseSecondaire;
  final double? capitalSystemeDevise2;
  final double? capitalReelDevise2;
  final double? ecartDevise2;

  // Actions correctives
  final bool actionCorrectiveRequise;
  final String? actionCorrectivePrise;

  // Métadonnées
  final int? createdBy;
  final int? verifiedBy;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? lastModifiedAt;

  // Sync
  final bool isSynced;
  final DateTime? syncedAt;
  final String? lastModifiedBy;

  ReconciliationModel({
    this.id,
    required this.shopId,
    required this.dateReconciliation,
    this.periode = ReconciliationPeriode.DAILY,
    required this.capitalSystemeCash,
    required this.capitalSystemeAirtel,
    required this.capitalSystemeMpesa,
    required this.capitalSystemeOrange,
    required this.capitalSystemeTotal,
    required this.capitalReelCash,
    required this.capitalReelAirtel,
    required this.capitalReelMpesa,
    required this.capitalReelOrange,
    required this.capitalReelTotal,
    this.ecartCash,
    this.ecartAirtel,
    this.ecartMpesa,
    this.ecartOrange,
    this.ecartTotal,
    this.ecartPourcentage,
    this.statut = ReconciliationStatut.EN_COURS,
    this.notes,
    this.justification,
    this.deviseSecondaire,
    this.capitalSystemeDevise2,
    this.capitalReelDevise2,
    this.ecartDevise2,
    this.actionCorrectiveRequise = false,
    this.actionCorrectivePrise,
    this.createdBy,
    this.verifiedBy,
    DateTime? createdAt,
    this.verifiedAt,
    this.lastModifiedAt,
    this.isSynced = false,
    this.syncedAt,
    this.lastModifiedBy,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'date_reconciliation': dateReconciliation.toIso8601String().split('T')[0],
        'periode': periode.name,
        'capital_systeme_cash': capitalSystemeCash,
        'capital_systeme_airtel': capitalSystemeAirtel,
        'capital_systeme_mpesa': capitalSystemeMpesa,
        'capital_systeme_orange': capitalSystemeOrange,
        'capital_systeme_total': capitalSystemeTotal,
        'capital_reel_cash': capitalReelCash,
        'capital_reel_airtel': capitalReelAirtel,
        'capital_reel_mpesa': capitalReelMpesa,
        'capital_reel_orange': capitalReelOrange,
        'capital_reel_total': capitalReelTotal,
        'ecart_cash': ecartCash,
        'ecart_airtel': ecartAirtel,
        'ecart_mpesa': ecartMpesa,
        'ecart_orange': ecartOrange,
        'ecart_total': ecartTotal,
        'ecart_pourcentage': ecartPourcentage,
        'statut': statut.name,
        'notes': notes,
        'justification': justification,
        'devise_secondaire': deviseSecondaire,
        'capital_systeme_devise2': capitalSystemeDevise2,
        'capital_reel_devise2': capitalReelDevise2,
        'ecart_devise2': ecartDevise2,
        'action_corrective_requise': actionCorrectiveRequise ? 1 : 0,
        'action_corrective_prise': actionCorrectivePrise,
        'created_by': createdBy,
        'verified_by': verifiedBy,
        'created_at': createdAt.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
        'last_modified_at': lastModifiedAt?.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
        'synced_at': syncedAt?.toIso8601String(),
        'last_modified_by': lastModifiedBy,
      };

  factory ReconciliationModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationModel(
      id: json['id'] as int?,
      shopId: json['shop_id'] as int,
      dateReconciliation: json['date_reconciliation'] is String
          ? DateTime.parse(json['date_reconciliation'] as String)
          : (json['date_reconciliation'] as DateTime),
      periode: ReconciliationPeriode.values.firstWhere(
        (e) => e.name == json['periode'],
        orElse: () => ReconciliationPeriode.DAILY,
      ),
      capitalSystemeCash: (json['capital_systeme_cash'] as num).toDouble(),
      capitalSystemeAirtel: (json['capital_systeme_airtel'] as num).toDouble(),
      capitalSystemeMpesa: (json['capital_systeme_mpesa'] as num).toDouble(),
      capitalSystemeOrange: (json['capital_systeme_orange'] as num).toDouble(),
      capitalSystemeTotal: (json['capital_systeme_total'] as num).toDouble(),
      capitalReelCash: (json['capital_reel_cash'] as num).toDouble(),
      capitalReelAirtel: (json['capital_reel_airtel'] as num).toDouble(),
      capitalReelMpesa: (json['capital_reel_mpesa'] as num).toDouble(),
      capitalReelOrange: (json['capital_reel_orange'] as num).toDouble(),
      capitalReelTotal: (json['capital_reel_total'] as num).toDouble(),
      ecartCash: json['ecart_cash'] != null ? (json['ecart_cash'] as num).toDouble() : null,
      ecartAirtel: json['ecart_airtel'] != null ? (json['ecart_airtel'] as num).toDouble() : null,
      ecartMpesa: json['ecart_mpesa'] != null ? (json['ecart_mpesa'] as num).toDouble() : null,
      ecartOrange: json['ecart_orange'] != null ? (json['ecart_orange'] as num).toDouble() : null,
      ecartTotal: json['ecart_total'] != null ? (json['ecart_total'] as num).toDouble() : null,
      ecartPourcentage: json['ecart_pourcentage'] != null ? (json['ecart_pourcentage'] as num).toDouble() : null,
      statut: ReconciliationStatut.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => ReconciliationStatut.EN_COURS,
      ),
      notes: json['notes'] as String?,
      justification: json['justification'] as String?,
      deviseSecondaire: json['devise_secondaire'] as String?,
      capitalSystemeDevise2: json['capital_systeme_devise2'] != null ? (json['capital_systeme_devise2'] as num).toDouble() : null,
      capitalReelDevise2: json['capital_reel_devise2'] != null ? (json['capital_reel_devise2'] as num).toDouble() : null,
      ecartDevise2: json['ecart_devise2'] != null ? (json['ecart_devise2'] as num).toDouble() : null,
      actionCorrectiveRequise: json['action_corrective_requise'] == 1 || json['action_corrective_requise'] == true,
      actionCorrectivePrise: json['action_corrective_prise'] as String?,
      createdBy: json['created_by'] as int?,
      verifiedBy: json['verified_by'] as int?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : (json['created_at'] as DateTime? ?? DateTime.now()),
      verifiedAt: json['verified_at'] is String ? DateTime.parse(json['verified_at'] as String) : null,
      lastModifiedAt: json['last_modified_at'] is String ? DateTime.parse(json['last_modified_at'] as String) : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] is String ? DateTime.parse(json['synced_at'] as String) : null,
      lastModifiedBy: json['last_modified_by'] as String?,
    );
  }

  ReconciliationModel copyWith({
    int? id,
    int? shopId,
    DateTime? dateReconciliation,
    ReconciliationPeriode? periode,
    double? capitalSystemeCash,
    double? capitalSystemeAirtel,
    double? capitalSystemeMpesa,
    double? capitalSystemeOrange,
    double? capitalSystemeTotal,
    double? capitalReelCash,
    double? capitalReelAirtel,
    double? capitalReelMpesa,
    double? capitalReelOrange,
    double? capitalReelTotal,
    double? ecartCash,
    double? ecartAirtel,
    double? ecartMpesa,
    double? ecartOrange,
    double? ecartTotal,
    double? ecartPourcentage,
    ReconciliationStatut? statut,
    String? notes,
    String? justification,
    String? deviseSecondaire,
    double? capitalSystemeDevise2,
    double? capitalReelDevise2,
    double? ecartDevise2,
    bool? actionCorrectiveRequise,
    String? actionCorrectivePrise,
    int? createdBy,
    int? verifiedBy,
    DateTime? createdAt,
    DateTime? verifiedAt,
    DateTime? lastModifiedAt,
    bool? isSynced,
    DateTime? syncedAt,
    String? lastModifiedBy,
  }) =>
      ReconciliationModel(
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        dateReconciliation: dateReconciliation ?? this.dateReconciliation,
        periode: periode ?? this.periode,
        capitalSystemeCash: capitalSystemeCash ?? this.capitalSystemeCash,
        capitalSystemeAirtel: capitalSystemeAirtel ?? this.capitalSystemeAirtel,
        capitalSystemeMpesa: capitalSystemeMpesa ?? this.capitalSystemeMpesa,
        capitalSystemeOrange: capitalSystemeOrange ?? this.capitalSystemeOrange,
        capitalSystemeTotal: capitalSystemeTotal ?? this.capitalSystemeTotal,
        capitalReelCash: capitalReelCash ?? this.capitalReelCash,
        capitalReelAirtel: capitalReelAirtel ?? this.capitalReelAirtel,
        capitalReelMpesa: capitalReelMpesa ?? this.capitalReelMpesa,
        capitalReelOrange: capitalReelOrange ?? this.capitalReelOrange,
        capitalReelTotal: capitalReelTotal ?? this.capitalReelTotal,
        ecartCash: ecartCash ?? this.ecartCash,
        ecartAirtel: ecartAirtel ?? this.ecartAirtel,
        ecartMpesa: ecartMpesa ?? this.ecartMpesa,
        ecartOrange: ecartOrange ?? this.ecartOrange,
        ecartTotal: ecartTotal ?? this.ecartTotal,
        ecartPourcentage: ecartPourcentage ?? this.ecartPourcentage,
        statut: statut ?? this.statut,
        notes: notes ?? this.notes,
        justification: justification ?? this.justification,
        deviseSecondaire: deviseSecondaire ?? this.deviseSecondaire,
        capitalSystemeDevise2: capitalSystemeDevise2 ?? this.capitalSystemeDevise2,
        capitalReelDevise2: capitalReelDevise2 ?? this.capitalReelDevise2,
        ecartDevise2: ecartDevise2 ?? this.ecartDevise2,
        actionCorrectiveRequise: actionCorrectiveRequise ?? this.actionCorrectiveRequise,
        actionCorrectivePrise: actionCorrectivePrise ?? this.actionCorrectivePrise,
        createdBy: createdBy ?? this.createdBy,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        createdAt: createdAt ?? this.createdAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
        isSynced: isSynced ?? this.isSynced,
        syncedAt: syncedAt ?? this.syncedAt,
        lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      );

  /// Calcule les écarts (utilisé côté client si nécessaire)
  Map<String, double> get ecarts => {
        'cash': capitalReelCash - capitalSystemeCash,
        'airtel': capitalReelAirtel - capitalSystemeAirtel,
        'mpesa': capitalReelMpesa - capitalSystemeMpesa,
        'orange': capitalReelOrange - capitalSystemeOrange,
        'total': capitalReelTotal - capitalSystemeTotal,
      };

  /// Calcule le pourcentage d'écart
  double get calculateEcartPourcentage {
    if (capitalSystemeTotal == 0) return 0;
    return ((capitalReelTotal - capitalSystemeTotal) / capitalSystemeTotal * 100);
  }

  /// Détermine le niveau d'alerte basé sur l'écart
  ReconciliationAlertLevel get alertLevel {
    final ecartPct = ecartPourcentage?.abs() ?? calculateEcartPourcentage.abs();
    if (ecartPct > 5) return ReconciliationAlertLevel.CRITIQUE;
    if (ecartPct > 2) return ReconciliationAlertLevel.ATTENTION;
    if (ecartPct > 0) return ReconciliationAlertLevel.MINEUR;
    return ReconciliationAlertLevel.OK;
  }
}

enum ReconciliationPeriode {
  DAILY,
  WEEKLY,
  MONTHLY,
}

enum ReconciliationStatut {
  EN_COURS,
  VALIDE,
  ECART_ACCEPTABLE,
  ECART_ALERTE,
  INVESTIGATION,
}

enum ReconciliationAlertLevel {
  OK,
  MINEUR,
  ATTENTION,
  CRITIQUE,
}
