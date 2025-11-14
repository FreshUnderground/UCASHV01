class CommissionModel {
  final int? id;
  final String type; // 'SORTANT' ou 'ENTRANT'
  final double taux;
  final String description;

  CommissionModel({
    this.id,
    required this.type,
    required this.taux,
    required this.description,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: _parseIntSafe(json['id']),
      type: json['type']?.toString() ?? 'SORTANT',
      taux: _parseDoubleSafe(json['taux']),
      description: json['description']?.toString() ?? '',
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'taux': taux,
      'description': description,
    };
  }

  CommissionModel copyWith({
    int? id,
    String? type,
    double? taux,
    String? description,
  }) {
    return CommissionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      taux: taux ?? this.taux,
      description: description ?? this.description,
    );
  }
}
