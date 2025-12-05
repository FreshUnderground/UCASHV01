import 'operation_model.dart';

enum TypeMouvement {
  entree,
  sortie,
}

class JournalCaisseModel {
  final int? id;
  final int shopId;
  final int agentId;
  final String libelle;
  final double montant;
  final TypeMouvement type;
  final ModePaiement mode;
  final DateTime dateAction;
  final int? operationId; // Lien avec l'opération si applicable
  final String? notes;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  JournalCaisseModel({
    this.id,
    required this.shopId,
    required this.agentId,
    required this.libelle,
    required this.montant,
    required this.type,
    required this.mode,
    required this.dateAction,
    this.operationId,
    this.notes,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  factory JournalCaisseModel.fromJson(Map<String, dynamic> json) {
    return JournalCaisseModel(
      id: json['id'],
      shopId: json['shop_id'],
      agentId: json['agent_id'],
      libelle: json['libelle'],
      montant: json['montant'].toDouble(),
      type: _parseTypeMouvement(json['type']),
      mode: _parseModePaiement(json['mode']),
      dateAction: DateTime.parse(json['date_action']),
      operationId: json['operation_id'],
      notes: json['notes'],
      lastModifiedAt: json['last_modified_at'] != null ? DateTime.parse(json['last_modified_at']) : null,
      lastModifiedBy: json['last_modified_by'],
    );
  }
  
  /// Parse TypeMouvement depuis String (MySQL) ou int (local)
  static TypeMouvement _parseTypeMouvement(dynamic value) {
    if (value == null) return TypeMouvement.entree;
    
    // Si c'est déjà un index
    if (value is int) {
      if (value >= 0 && value < TypeMouvement.values.length) {
        return TypeMouvement.values[value];
      }
      return TypeMouvement.entree;
    }
    
    // Si c'est une string (depuis MySQL)
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'entree':
          return TypeMouvement.entree;
        case 'sortie':
          return TypeMouvement.sortie;
        default:
          return TypeMouvement.entree;
      }
    }
    
    return TypeMouvement.entree;
  }
  
  /// Parse ModePaiement depuis String (MySQL) ou int (local)
  static ModePaiement _parseModePaiement(dynamic value) {
    if (value == null) return ModePaiement.cash;
    
    // Si c'est déjà un index
    if (value is int) {
      if (value >= 0 && value < ModePaiement.values.length) {
        return ModePaiement.values[value];
      }
      return ModePaiement.cash;
    }
    
    // Si c'est une string (depuis MySQL)
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'cash':
          return ModePaiement.cash;
        case 'airtelmoney':
          return ModePaiement.airtelMoney;
        case 'mpesa':
          return ModePaiement.mPesa;
        case 'orangemoney':
          return ModePaiement.orangeMoney;
        default:
          return ModePaiement.cash;
      }
    }
    
    return ModePaiement.cash;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'agent_id': agentId,
      'libelle': libelle,
      'montant': montant,
      'type': type.index,
      'mode': mode.index,
      'date_action': dateAction.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'operation_id': operationId,
      'notes': notes,
      'last_modified_at': lastModifiedAt?.toString().split('.')[0].replaceFirst('T', ' '), // Format: YYYY-MM-DD HH:MM:SS
      'last_modified_by': lastModifiedBy,
    };
  }

  String get typeLabel {
    switch (type) {
      case TypeMouvement.entree:
        return 'Entrée';
      case TypeMouvement.sortie:
        return 'Sortie';
    }
  }

  String get modeLabel {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }

  JournalCaisseModel copyWith({
    int? id,
    int? shopId,
    int? agentId,
    String? libelle,
    double? montant,
    TypeMouvement? type,
    ModePaiement? mode,
    DateTime? dateAction,
    int? operationId,
    String? notes,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return JournalCaisseModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      agentId: agentId ?? this.agentId,
      libelle: libelle ?? this.libelle,
      montant: montant ?? this.montant,
      type: type ?? this.type,
      mode: mode ?? this.mode,
      dateAction: dateAction ?? this.dateAction,
      operationId: operationId ?? this.operationId,
      notes: notes ?? this.notes,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }
}
