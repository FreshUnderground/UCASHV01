/// Modèle pour les comptes spéciaux (FRAIS et DÉPENSE)
class CompteSpecialModel {
  final int? id;
  final TypeCompteSpecial type; // FRAIS ou DEPENSE
  final TypeTransactionCompte typeTransaction; // DEPOT, RETRAIT, COMMISSION_AUTO
  final double montant;
  final String description;
  final int? shopId;
  final DateTime dateTransaction;
  final int? operationId; // Lien vers l'opération si applicable
  final int? agentId;
  final String? agentUsername;
  
  // Métadonnées de synchronisation
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;

  CompteSpecialModel({
    this.id,
    required this.type,
    required this.typeTransaction,
    required this.montant,
    required this.description,
    this.shopId,
    required this.dateTransaction,
    this.operationId,
    this.agentId,
    this.agentUsername,
    this.createdAt,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
  });

  factory CompteSpecialModel.fromJson(Map<String, dynamic> json) {
    return CompteSpecialModel(
      id: _parseIntSafe(json['id']),
      type: _parseTypeCompteSpecial(json['type']),
      typeTransaction: _parseTypeTransaction(json['type_transaction']),
      montant: _parseDoubleSafe(json['montant']),
      description: json['description']?.toString() ?? '',
      shopId: _parseIntSafe(json['shop_id']),
      dateTransaction: _parseDateTimeSafe(json['date_transaction']),
      operationId: _parseIntSafe(json['operation_id']),
      agentId: _parseIntSafe(json['agent_id']),
      agentUsername: json['agent_username']?.toString(),
      createdAt: _parseDateTimeSafe(json['created_at']),
      lastModifiedAt: _parseDateTimeSafe(json['last_modified_at']),
      lastModifiedBy: json['last_modified_by']?.toString(),
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: _parseDateTimeSafe(json['synced_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'type_transaction': typeTransaction.name,
      'montant': montant,
      'description': description,
      'shop_id': shopId,
      'date_transaction': dateTransaction.toIso8601String(),
      'operation_id': operationId,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'created_at': createdAt?.toIso8601String(),
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  CompteSpecialModel copyWith({
    int? id,
    TypeCompteSpecial? type,
    TypeTransactionCompte? typeTransaction,
    double? montant,
    String? description,
    int? shopId,
    DateTime? dateTransaction,
    int? operationId,
    int? agentId,
    String? agentUsername,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return CompteSpecialModel(
      id: id ?? this.id,
      type: type ?? this.type,
      typeTransaction: typeTransaction ?? this.typeTransaction,
      montant: montant ?? this.montant,
      description: description ?? this.description,
      shopId: shopId ?? this.shopId,
      dateTransaction: dateTransaction ?? this.dateTransaction,
      operationId: operationId ?? this.operationId,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Helpers pour parsing
  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double _parseDoubleSafe(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTimeSafe(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static TypeCompteSpecial _parseTypeCompteSpecial(dynamic value) {
    if (value == null) return TypeCompteSpecial.FRAIS;
    final str = value.toString().toUpperCase();
    if (str == 'DEPENSE') return TypeCompteSpecial.DEPENSE;
    return TypeCompteSpecial.FRAIS;
  }
  
  static TypeTransactionCompte _parseTypeTransaction(dynamic value) {
    if (value == null) return TypeTransactionCompte.COMMISSION_AUTO;
    final str = value.toString().toUpperCase();
    if (str == 'DEPOT') return TypeTransactionCompte.DEPOT;
    if (str == 'DEPOT_FRAIS') return TypeTransactionCompte.DEPOT_FRAIS;
    if (str == 'RETRAIT') return TypeTransactionCompte.RETRAIT;
    if (str == 'SORTIE') return TypeTransactionCompte.SORTIE;
    return TypeTransactionCompte.COMMISSION_AUTO;
  }
}

/// Type de compte spécial
enum TypeCompteSpecial {
  FRAIS,    // Frais payés par les clients (commissions automatiques)
  DEPENSE,  // Compte pour dépenses (alimenté par boss, utilisé pour sorties)
}

/// Type de transaction dans un compte spécial
enum TypeTransactionCompte {
  DEPOT,            // Dépôt par le boss (DEPENSE uniquement)
  DEPOT_FRAIS,      // Dépôt dans compte FRAIS
  RETRAIT,          // Retrait par le boss (FRAIS uniquement)
  SORTIE,           // Sortie/Dépense (DEPENSE uniquement)
  COMMISSION_AUTO,  // Commission automatique (FRAIS uniquement)
}

extension TypeCompteSpecialExtension on TypeCompteSpecial {
  String get label {
    switch (this) {
      case TypeCompteSpecial.FRAIS:
        return 'Compte FRAIS';
      case TypeCompteSpecial.DEPENSE:
        return 'Compte DÉPENSE';
    }
  }

  String get description {
    switch (this) {
      case TypeCompteSpecial.FRAIS:
        return 'Commissions automatiques des clients → Boss peut retirer';
      case TypeCompteSpecial.DEPENSE:
        return 'Boss alimente → Utilisé pour sorties/dépenses';
    }
  }
}

extension TypeTransactionCompteExtension on TypeTransactionCompte {
  String get label {
    switch (this) {
      case TypeTransactionCompte.DEPOT:
        return 'Dépôt Boss';
      case TypeTransactionCompte.DEPOT_FRAIS:
        return 'Dépôt FRAIS';
      case TypeTransactionCompte.RETRAIT:
        return 'Retrait Boss';
      case TypeTransactionCompte.SORTIE:
        return 'Sortie/Dépense';
      case TypeTransactionCompte.COMMISSION_AUTO:
        return 'Commission Client';
    }
  }
  
  String get icon {
    switch (this) {
      case TypeTransactionCompte.DEPOT:
        return '➕';
      case TypeTransactionCompte.DEPOT_FRAIS:
        return '➡️';
      case TypeTransactionCompte.RETRAIT:
        return '➖';
      case TypeTransactionCompte.SORTIE:
        return '💸';
      case TypeTransactionCompte.COMMISSION_AUTO:
        return '💰';
    }
  }
}
