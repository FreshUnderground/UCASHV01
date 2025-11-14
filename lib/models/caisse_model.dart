class CaisseModel {
  final int? id;
  final int shopId;
  final String type; // 'CASH', 'AIRTEL', 'MPESA', 'ORANGE'
  final double solde;

  CaisseModel({
    this.id,
    required this.shopId,
    required this.type,
    this.solde = 0.0,
  });

  factory CaisseModel.fromJson(Map<String, dynamic> json) {
    return CaisseModel(
      id: json['id'],
      shopId: json['shop_id'],
      type: json['type'],
      solde: json['solde']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'type': type,
      'solde': solde,
    };
  }

  CaisseModel copyWith({
    int? id,
    int? shopId,
    String? type,
    double? solde,
  }) {
    return CaisseModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      type: type ?? this.type,
      solde: solde ?? this.solde,
    );
  }
}
