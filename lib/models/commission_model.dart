class CommissionModel {
  final int? id;
  final String type; // 'SORTANT' ou 'ENTRANT'
  final double taux;
  final String description;
  final int? shopId; // Pour les commissions spécifiques à un shop (null = général)
  final int? shopSourceId; // Pour les commissions shop-to-shop (shop source)
  final int? shopDestinationId; // Pour les commissions shop-to-shop (shop destination)
  
  // Métadonnées de synchronisation
  final bool isSynced;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? syncedAt;

  CommissionModel({
    this.id,
    required this.type,
    required this.taux,
    required this.description,
    this.shopId,
    this.shopSourceId,
    this.shopDestinationId,
    this.isSynced = false,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.syncedAt,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: _parseIntSafe(json['id']),
      type: json['type']?.toString() ?? 'SORTANT',
      taux: _parseDoubleSafe(json['taux']),
      description: json['description']?.toString() ?? '',
      shopId: _parseIntSafe(json['shop_id']),
      shopSourceId: _parseIntSafe(json['shop_source_id']),
      shopDestinationId: _parseIntSafe(json['shop_destination_id']),
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.tryParse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by']?.toString(),
      syncedAt: json['synced_at'] != null ? DateTime.tryParse(json['synced_at']) : null,
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
      'shop_id': shopId,
      'shop_source_id': shopSourceId,
      'shop_destination_id': shopDestinationId,
      'is_synced': isSynced ? 1 : 0,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  CommissionModel copyWith({
    int? id,
    String? type,
    double? taux,
    String? description,
    int? shopId,
    int? shopSourceId,
    int? shopDestinationId,
    bool? isSynced,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? syncedAt,
  }) {
    return CommissionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      taux: taux ?? this.taux,
      description: description ?? this.description,
      shopId: shopId ?? this.shopId,
      shopSourceId: shopSourceId ?? this.shopSourceId,
      shopDestinationId: shopDestinationId ?? this.shopDestinationId,
      isSynced: isSynced ?? this.isSynced,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
