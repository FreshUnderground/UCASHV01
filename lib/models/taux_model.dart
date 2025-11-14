/// Modele de taux de change entre devises
class TauxModel {
  final int? id;
  final String deviseSource;  // Devise de depart (ex: USD)
  final String deviseCible;   // Devise d'arrivee (ex: CDF)
  final double taux;          // Taux de conversion (1 USD = X CDF)
  final String type;          // 'ACHAT', 'VENTE', 'MOYEN'
  final DateTime? dateEffet;  // Date d'application du taux
  final bool estActif;        // Taux actuellement actif

  TauxModel({
    this.id,
    required this.deviseSource,
    required this.deviseCible,
    required this.taux,
    this.type = 'MOYEN',
    this.dateEffet,
    this.estActif = true,
  });

  factory TauxModel.fromJson(Map<String, dynamic> json) {
    return TauxModel(
      id: _parseIntSafe(json['id']),
      deviseSource: json['devise_source']?.toString() ?? 'USD',
      deviseCible: json['devise_cible']?.toString() ?? '',
      taux: _parseDoubleSafe(json['taux']),
      type: json['type']?.toString() ?? 'MOYEN',
      dateEffet: json['date_effet'] != null 
          ? DateTime.tryParse(json['date_effet'].toString()) 
          : null,
      estActif: _parseBoolSafe(json['est_actif']) ?? true,
    );
  }

  // Méthodes utilitaires pour conversion sécurisée
  static double _parseDoubleSafe(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool _parseBoolSafe(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      if (value.toLowerCase() == 'true' || value == '1') return true;
      if (value.toLowerCase() == 'false' || value == '0') return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'devise_source': deviseSource,
      'devise_cible': deviseCible,
      'taux': taux,
      'type': type,
      'date_effet': dateEffet?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'est_actif': estActif,
    };
  }

  TauxModel copyWith({
    int? id,
    String? deviseSource,
    String? deviseCible,
    double? taux,
    String? type,
    DateTime? dateEffet,
    bool? estActif,
  }) {
    return TauxModel(
      id: id ?? this.id,
      deviseSource: deviseSource ?? this.deviseSource,
      deviseCible: deviseCible ?? this.deviseCible,
      taux: taux ?? this.taux,
      type: type ?? this.type,
      dateEffet: dateEffet ?? this.dateEffet,
      estActif: estActif ?? this.estActif,
    );
  }
  
  /// Convertit un montant de la devise source vers la devise cible
  double convertir(double montant) {
    return montant * taux;
  }
  
  /// Convertit un montant de la devise cible vers la devise source (inverse)
  double convertirInverse(double montant) {
    return montant / taux;
  }
  
  /// Retourne le taux inverse (pour conversion dans l'autre sens)
  TauxModel get inverse {
    return TauxModel(
      id: id,
      deviseSource: deviseCible,
      deviseCible: deviseSource,
      taux: 1 / taux,
      type: type,
      dateEffet: dateEffet,
      estActif: estActif,
    );
  }
  
  /// Cle unique pour identifier un taux (ex: "USD_CDF")
  String get cle => '${deviseSource}_$deviseCible';
  
  @override
  String toString() {
    return '1 $deviseSource = $taux $deviseCible ($type)';
  }
}
