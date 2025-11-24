import 'dart:convert';

class SimMovementModel {
  final int? id;
  final int simId;
  final String simNumero;
  final int? ancienShopId;
  final String? ancienShopDesignation;
  final int nouveauShopId;
  final String nouveauShopDesignation;
  final String adminResponsable;
  final String? motif;
  final DateTime dateMovement;
  final DateTime lastModifiedAt;
  final String lastModifiedBy;

  SimMovementModel({
    this.id,
    required this.simId,
    required this.simNumero,
    this.ancienShopId,
    this.ancienShopDesignation,
    required this.nouveauShopId,
    required this.nouveauShopDesignation,
    required this.adminResponsable,
    this.motif,
    required this.dateMovement,
    required this.lastModifiedAt,
    required this.lastModifiedBy,
  });

  /// Description lisible du mouvement
  String get movementDescription {
    if (ancienShopId == null) {
      return 'Affectation initiale de la SIM $simNumero au shop $nouveauShopDesignation';
    }
    return 'Transfert de la SIM $simNumero du shop $ancienShopDesignation vers $nouveauShopDesignation';
  }

  /// Créer une copie avec des valeurs modifiées
  SimMovementModel copyWith({
    int? id,
    int? simId,
    String? simNumero,
    int? ancienShopId,
    String? ancienShopDesignation,
    int? nouveauShopId,
    String? nouveauShopDesignation,
    String? adminResponsable,
    String? motif,
    DateTime? dateMovement,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return SimMovementModel(
      id: id ?? this.id,
      simId: simId ?? this.simId,
      simNumero: simNumero ?? this.simNumero,
      ancienShopId: ancienShopId ?? this.ancienShopId,
      ancienShopDesignation: ancienShopDesignation ?? this.ancienShopDesignation,
      nouveauShopId: nouveauShopId ?? this.nouveauShopId,
      nouveauShopDesignation: nouveauShopDesignation ?? this.nouveauShopDesignation,
      adminResponsable: adminResponsable ?? this.adminResponsable,
      motif: motif ?? this.motif,
      dateMovement: dateMovement ?? this.dateMovement,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sim_id': simId,
      'sim_numero': simNumero,
      'ancien_shop_id': ancienShopId,
      'ancien_shop_designation': ancienShopDesignation,
      'nouveau_shop_id': nouveauShopId,
      'nouveau_shop_designation': nouveauShopDesignation,
      'admin_responsable': adminResponsable,
      'motif': motif,
      'date_movement': dateMovement.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'last_modified_by': lastModifiedBy,
    };
  }

  /// Créer à partir de JSON
  factory SimMovementModel.fromJson(Map<String, dynamic> json) {
    return SimMovementModel(
      id: json['id'] as int?,
      simId: json['sim_id'] as int,
      simNumero: json['sim_numero'] as String,
      ancienShopId: json['ancien_shop_id'] as int?,
      ancienShopDesignation: json['ancien_shop_designation'] as String?,
      nouveauShopId: json['nouveau_shop_id'] as int,
      nouveauShopDesignation: json['nouveau_shop_designation'] as String,
      adminResponsable: json['admin_responsable'] as String,
      motif: json['motif'] as String?,
      dateMovement: DateTime.parse(json['date_movement'] as String),
      lastModifiedAt: DateTime.parse(json['last_modified_at'] as String),
      lastModifiedBy: json['last_modified_by'] as String,
    );
  }

  /// Créer à partir d'une chaîne JSON
  factory SimMovementModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    return SimMovementModel.fromJson(json);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimMovementModel &&
        other.id == id &&
        other.simId == simId &&
        other.simNumero == simNumero &&
        other.ancienShopId == ancienShopId &&
        other.ancienShopDesignation == ancienShopDesignation &&
        other.nouveauShopId == nouveauShopId &&
        other.nouveauShopDesignation == nouveauShopDesignation &&
        other.adminResponsable == adminResponsable &&
        other.motif == motif &&
        other.dateMovement == dateMovement &&
        other.lastModifiedAt == lastModifiedAt &&
        other.lastModifiedBy == lastModifiedBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      simId,
      simNumero,
      ancienShopId,
      ancienShopDesignation,
      nouveauShopId,
      nouveauShopDesignation,
      adminResponsable,
      motif,
      dateMovement,
      lastModifiedAt,
      lastModifiedBy,
    );
  }

  @override
  String toString() {
    return 'SimMovementModel(id: $id, simId: $simId, simNumero: $simNumero, '
        'ancienShopId: $ancienShopId, ancienShopDesignation: $ancienShopDesignation, '
        'nouveauShopId: $nouveauShopId, nouveauShopDesignation: $nouveauShopDesignation, '
        'adminResponsable: $adminResponsable, motif: $motif, '
        'dateMovement: $dateMovement, lastModifiedAt: $lastModifiedAt, '
        'lastModifiedBy: $lastModifiedBy)';
  }
}