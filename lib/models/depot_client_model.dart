class DepotClientModel {
  final int? id;
  final int shopId;
  final String simNumero;
  final double montant;
  final String telephoneClient;
  final DateTime dateDepot;
  final int userId;

  DepotClientModel({
    this.id,
    required this.shopId,
    required this.simNumero,
    required this.montant,
    required this.telephoneClient,
    required this.dateDepot,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'sim_numero': simNumero,
      'montant': montant,
      'telephone_client': telephoneClient,
      'date_depot': dateDepot.toIso8601String(),
      'user_id': userId,
    };
  }

  factory DepotClientModel.fromMap(Map<String, dynamic> map) {
    return DepotClientModel(
      id: map['id'] as int?,
      shopId: map['shop_id'] as int,
      simNumero: map['sim_numero'] as String,
      montant: (map['montant'] as num).toDouble(),
      telephoneClient: map['telephone_client'] as String,
      dateDepot: DateTime.parse(map['date_depot'] as String),
      userId: map['user_id'] as int,
    );
  }
  
  DepotClientModel copyWith({
    int? id,
    int? shopId,
    String? simNumero,
    double? montant,
    String? telephoneClient,
    DateTime? dateDepot,
    int? userId,
  }) {
    return DepotClientModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      simNumero: simNumero ?? this.simNumero,
      montant: montant ?? this.montant,
      telephoneClient: telephoneClient ?? this.telephoneClient,
      dateDepot: dateDepot ?? this.dateDepot,
      userId: userId ?? this.userId,
    );
  }
}
