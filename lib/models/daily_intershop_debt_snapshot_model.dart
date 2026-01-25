/// Model for daily inter-shop debt snapshots
/// Stores daily debt balances to avoid recalculating from the beginning
class DailyIntershopDebtSnapshotModel {
  final int? id;
  final int shopId;
  final int otherShopId;
  final DateTime date;
  final double detteAnterieure; // Debt at start of day
  final double creancesDuJour; // Credits added today
  final double dettesDuJour; // Debts added today
  final double
      soldeCumule; // Cumulative balance (detteAnterieure + creances - dettes)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;
  final int syncVersion;

  DailyIntershopDebtSnapshotModel({
    this.id,
    required this.shopId,
    required this.otherShopId,
    required this.date,
    this.detteAnterieure = 0.0,
    this.creancesDuJour = 0.0,
    this.dettesDuJour = 0.0,
    this.soldeCumule = 0.0,
    this.createdAt,
    this.updatedAt,
    this.synced = false,
    this.syncVersion = 1,
  });

  /// Create from database map
  factory DailyIntershopDebtSnapshotModel.fromMap(Map<String, dynamic> map) {
    return DailyIntershopDebtSnapshotModel(
      id: map['id'] as int?,
      shopId: map['shop_id'] as int,
      otherShopId: map['other_shop_id'] as int,
      date: DateTime.parse(map['date'] as String),
      detteAnterieure: (map['dette_anterieure'] as num?)?.toDouble() ?? 0.0,
      creancesDuJour: (map['creances_du_jour'] as num?)?.toDouble() ?? 0.0,
      dettesDuJour: (map['dettes_du_jour'] as num?)?.toDouble() ?? 0.0,
      soldeCumule: (map['solde_cumule'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      synced: (map['synced'] as int?) == 1,
      syncVersion: map['sync_version'] as int? ?? 1,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      'other_shop_id': otherShopId,
      'date': date.toIso8601String().split('T')[0], // Store as DATE only
      'dette_anterieure': detteAnterieure,
      'creances_du_jour': creancesDuJour,
      'dettes_du_jour': dettesDuJour,
      'solde_cumule': soldeCumule,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
      'sync_version': syncVersion,
    };
  }

  /// Create a copy with modified fields
  DailyIntershopDebtSnapshotModel copyWith({
    int? id,
    int? shopId,
    int? otherShopId,
    DateTime? date,
    double? detteAnterieure,
    double? creancesDuJour,
    double? dettesDuJour,
    double? soldeCumule,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    int? syncVersion,
  }) {
    return DailyIntershopDebtSnapshotModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      otherShopId: otherShopId ?? this.otherShopId,
      date: date ?? this.date,
      detteAnterieure: detteAnterieure ?? this.detteAnterieure,
      creancesDuJour: creancesDuJour ?? this.creancesDuJour,
      dettesDuJour: dettesDuJour ?? this.dettesDuJour,
      soldeCumule: soldeCumule ?? this.soldeCumule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  String toString() {
    return 'DailyIntershopDebtSnapshot(id: $id, shopId: $shopId, otherShopId: $otherShopId, '
        'date: ${date.toIso8601String().split('T')[0]}, '
        'detteAnterieure: $detteAnterieure, creances: $creancesDuJour, '
        'dettes: $dettesDuJour, soldeCumule: $soldeCumule)';
  }
}
