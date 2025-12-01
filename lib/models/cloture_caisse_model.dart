/// Modèle pour la clôture de caisse quotidienne
/// Ce modèle enregistre le solde de fin de journée qui sera utilisé
/// comme solde d'ouverture (solde antérieur) pour le jour suivant
class ClotureCaisseModel {
  final int? id;
  final int shopId;
  final DateTime dateCloture; // Date de la clôture (fin de journée)
  
  // NOUVEAU: Solde FRAIS antérieur (enregistré lors de la clôture)
  final double soldeFraisAnterieur;
  
  // Montants SAISIS par l'agent (comptage physique)
  final double soldeSaisiCash;
  final double soldeSaisiAirtelMoney;
  final double soldeSaisiMPesa;
  final double soldeSaisiOrangeMoney;
  final double soldeSaisiTotal;
  
  // Montants CALCULÉS par le système (solde antérieur + opérations du jour)
  final double soldeCalculeCash;
  final double soldeCalculeAirtelMoney;
  final double soldeCalculeMPesa;
  final double soldeCalculeOrangeMoney;
  final double soldeCalculeTotal;
  
  // Écarts (différences entre saisi et calculé)
  final double ecartCash;
  final double ecartAirtelMoney;
  final double ecartMPesa;
  final double ecartOrangeMoney;
  final double ecartTotal;
  
  final String cloturePar; // Username de l'agent qui a clôturé
  final DateTime dateEnregistrement; // Date/heure d'enregistrement de la clôture
  final String? notes; // Notes optionnelles

  ClotureCaisseModel({
    this.id,
    required this.shopId,
    required this.dateCloture,
    this.soldeFraisAnterieur = 0.0,
    required this.soldeSaisiCash,
    required this.soldeSaisiAirtelMoney,
    required this.soldeSaisiMPesa,
    required this.soldeSaisiOrangeMoney,
    required this.soldeSaisiTotal,
    required this.soldeCalculeCash,
    required this.soldeCalculeAirtelMoney,
    required this.soldeCalculeMPesa,
    required this.soldeCalculeOrangeMoney,
    required this.soldeCalculeTotal,
    required this.ecartCash,
    required this.ecartAirtelMoney,
    required this.ecartMPesa,
    required this.ecartOrangeMoney,
    required this.ecartTotal,
    required this.cloturePar,
    required this.dateEnregistrement,
    this.notes,
  });

  factory ClotureCaisseModel.fromJson(Map<String, dynamic> json) {
    return ClotureCaisseModel(
      id: json['id'] as int?,
      shopId: json['shop_id'] as int,
      dateCloture: DateTime.parse(json['date_cloture'] as String),
      soldeFraisAnterieur: ((json['solde_frais_anterieur'] ?? 0) as num).toDouble(),
      soldeSaisiCash: ((json['solde_saisi_cash'] ?? 0) as num).toDouble(),
      soldeSaisiAirtelMoney: ((json['solde_saisi_airtel_money'] ?? 0) as num).toDouble(),
      soldeSaisiMPesa: ((json['solde_saisi_mpesa'] ?? 0) as num).toDouble(),
      soldeSaisiOrangeMoney: ((json['solde_saisi_orange_money'] ?? 0) as num).toDouble(),
      soldeSaisiTotal: ((json['solde_saisi_total'] ?? 0) as num).toDouble(),
      soldeCalculeCash: ((json['solde_calcule_cash'] ?? 0) as num).toDouble(),
      soldeCalculeAirtelMoney: ((json['solde_calcule_airtel_money'] ?? 0) as num).toDouble(),
      soldeCalculeMPesa: ((json['solde_calcule_mpesa'] ?? 0) as num).toDouble(),
      soldeCalculeOrangeMoney: ((json['solde_calcule_orange_money'] ?? 0) as num).toDouble(),
      soldeCalculeTotal: ((json['solde_calcule_total'] ?? 0) as num).toDouble(),
      ecartCash: ((json['ecart_cash'] ?? 0) as num).toDouble(),
      ecartAirtelMoney: ((json['ecart_airtel_money'] ?? 0) as num).toDouble(),
      ecartMPesa: ((json['ecart_mpesa'] ?? 0) as num).toDouble(),
      ecartOrangeMoney: ((json['ecart_orange_money'] ?? 0) as num).toDouble(),
      ecartTotal: ((json['ecart_total'] ?? 0) as num).toDouble(),
      cloturePar: json['cloture_par'] as String,
      dateEnregistrement: DateTime.parse(json['date_enregistrement'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      'date_cloture': dateCloture.toIso8601String(),
      'solde_frais_anterieur': soldeFraisAnterieur,
      'solde_saisi_cash': soldeSaisiCash,
      'solde_saisi_airtel_money': soldeSaisiAirtelMoney,
      'solde_saisi_mpesa': soldeSaisiMPesa,
      'solde_saisi_orange_money': soldeSaisiOrangeMoney,
      'solde_saisi_total': soldeSaisiTotal,
      'solde_calcule_cash': soldeCalculeCash,
      'solde_calcule_airtel_money': soldeCalculeAirtelMoney,
      'solde_calcule_mpesa': soldeCalculeMPesa,
      'solde_calcule_orange_money': soldeCalculeOrangeMoney,
      'solde_calcule_total': soldeCalculeTotal,
      'ecart_cash': ecartCash,
      'ecart_airtel_money': ecartAirtelMoney,
      'ecart_mpesa': ecartMPesa,
      'ecart_orange_money': ecartOrangeMoney,
      'ecart_total': ecartTotal,
      'cloture_par': cloturePar,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }

  ClotureCaisseModel copyWith({
    int? id,
    int? shopId,
    DateTime? dateCloture,
    double? soldeFraisAnterieur,
    double? soldeSaisiCash,
    double? soldeSaisiAirtelMoney,
    double? soldeSaisiMPesa,
    double? soldeSaisiOrangeMoney,
    double? soldeSaisiTotal,
    double? soldeCalculeCash,
    double? soldeCalculeAirtelMoney,
    double? soldeCalculeMPesa,
    double? soldeCalculeOrangeMoney,
    double? soldeCalculeTotal,
    double? ecartCash,
    double? ecartAirtelMoney,
    double? ecartMPesa,
    double? ecartOrangeMoney,
    double? ecartTotal,
    String? cloturePar,
    DateTime? dateEnregistrement,
    String? notes,
  }) {
    return ClotureCaisseModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      dateCloture: dateCloture ?? this.dateCloture,
      soldeFraisAnterieur: soldeFraisAnterieur ?? this.soldeFraisAnterieur,
      soldeSaisiCash: soldeSaisiCash ?? this.soldeSaisiCash,
      soldeSaisiAirtelMoney: soldeSaisiAirtelMoney ?? this.soldeSaisiAirtelMoney,
      soldeSaisiMPesa: soldeSaisiMPesa ?? this.soldeSaisiMPesa,
      soldeSaisiOrangeMoney: soldeSaisiOrangeMoney ?? this.soldeSaisiOrangeMoney,
      soldeSaisiTotal: soldeSaisiTotal ?? this.soldeSaisiTotal,
      soldeCalculeCash: soldeCalculeCash ?? this.soldeCalculeCash,
      soldeCalculeAirtelMoney: soldeCalculeAirtelMoney ?? this.soldeCalculeAirtelMoney,
      soldeCalculeMPesa: soldeCalculeMPesa ?? this.soldeCalculeMPesa,
      soldeCalculeOrangeMoney: soldeCalculeOrangeMoney ?? this.soldeCalculeOrangeMoney,
      soldeCalculeTotal: soldeCalculeTotal ?? this.soldeCalculeTotal,
      ecartCash: ecartCash ?? this.ecartCash,
      ecartAirtelMoney: ecartAirtelMoney ?? this.ecartAirtelMoney,
      ecartMPesa: ecartMPesa ?? this.ecartMPesa,
      ecartOrangeMoney: ecartOrangeMoney ?? this.ecartOrangeMoney,
      ecartTotal: ecartTotal ?? this.ecartTotal,
      cloturePar: cloturePar ?? this.cloturePar,
      dateEnregistrement: dateEnregistrement ?? this.dateEnregistrement,
      notes: notes ?? this.notes,
    );
  }
}
