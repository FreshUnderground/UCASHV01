class ShopModel {
  final int? id;
  final String designation;
  final String localisation;

  // Shop principal (siège/central) ou secondaire
  final bool isPrincipal;

  // Shop de transfert/service (sert les transferts par défaut)
  final bool isTransferShop;

  // Devises supportées par le shop (2 devises max)
  final String devisePrincipale; // USD par défaut
  final String? deviseSecondaire; // CDF, UGX, ou null

  // Capitaux en devise principale (USD)
  final double capitalInitial;
  final double capitalActuel;
  final double capitalCash;
  final double capitalAirtelMoney;
  final double capitalMPesa;
  final double capitalOrangeMoney;

  // Capitaux en devise secondaire (CDF ou UGX)
  final double? capitalInitialDevise2;
  final double? capitalActuelDevise2;
  final double? capitalCashDevise2;
  final double? capitalAirtelMoneyDevise2;
  final double? capitalMPesaDevise2;
  final double? capitalOrangeMoneyDevise2;

  final double creances;
  final double dettes;

  // Champs de synchronisation
  final String? uuid;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool? isSynced;
  final DateTime? syncedAt;

  ShopModel({
    this.id,
    required this.designation,
    required this.localisation,
    this.isPrincipal = false,
    this.isTransferShop = false,
    this.devisePrincipale = 'USD',
    this.deviseSecondaire, // CDF, UGX, ou null
    // Capitaux devise principale
    this.capitalInitial = 0.0,
    this.capitalActuel = 0.0,
    this.capitalCash = 0.0,
    this.capitalAirtelMoney = 0.0,
    this.capitalMPesa = 0.0,
    this.capitalOrangeMoney = 0.0,
    // Capitaux devise secondaire
    this.capitalInitialDevise2,
    this.capitalActuelDevise2,
    this.capitalCashDevise2,
    this.capitalAirtelMoneyDevise2,
    this.capitalMPesaDevise2,
    this.capitalOrangeMoneyDevise2,
    this.creances = 0.0,
    this.dettes = 0.0,
    // Champs de synchronisation
    this.uuid,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced,
    this.syncedAt,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: _parseIntSafe(json['id']),
      designation: json['designation']?.toString() ?? '',
      localisation: json['localisation']?.toString() ?? '',
      isPrincipal: _parseBoolSafe(json['is_principal']) ?? false,
      isTransferShop: _parseBoolSafe(json['is_transfer_shop']) ?? false,
      devisePrincipale: json['devise_principale']?.toString() ?? 'USD',
      deviseSecondaire: json['devise_secondaire']?.toString(),
      // Capitaux devise principale
      capitalInitial: _parseDoubleSafe(json['capital_initial']),
      capitalActuel: _parseDoubleSafe(json['capital_actuel']),
      capitalCash: _parseDoubleSafe(json['capital_cash']),
      capitalAirtelMoney: _parseDoubleSafe(json['capital_airtel_money']),
      capitalMPesa: _parseDoubleSafe(json['capital_mpesa']),
      capitalOrangeMoney: _parseDoubleSafe(json['capital_orange_money']),
      // Capitaux devise secondaire
      capitalInitialDevise2:
          _parseDoubleNullable(json['capital_initial_devise2']),
      capitalActuelDevise2:
          _parseDoubleNullable(json['capital_actuel_devise2']),
      capitalCashDevise2: _parseDoubleNullable(json['capital_cash_devise2']),
      capitalAirtelMoneyDevise2:
          _parseDoubleNullable(json['capital_airtel_money_devise2']),
      capitalMPesaDevise2: _parseDoubleNullable(json['capital_mpesa_devise2']),
      capitalOrangeMoneyDevise2:
          _parseDoubleNullable(json['capital_orange_money_devise2']),
      creances: _parseDoubleSafe(json['creances']),
      dettes: _parseDoubleSafe(json['dettes']),
      // Champs de synchronisation
      uuid: json['uuid']?.toString(),
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.tryParse(json['last_modified_at'].toString())
          : null,
      lastModifiedBy: json['last_modified_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isSynced: _parseBoolSafe(json['is_synced']),
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
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

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _parseBoolSafe(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      if (value.toLowerCase() == 'true' || value == '1') return true;
      if (value.toLowerCase() == 'false' || value == '0') return false;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'designation': designation,
      'localisation': localisation,
      'is_principal': isPrincipal ? 1 : 0,
      'is_transfer_shop': isTransferShop ? 1 : 0,
      'devise_principale': devisePrincipale,
      'devise_secondaire': deviseSecondaire,
      // Capitaux devise principale
      'capital_initial': capitalInitial,
      'capital_actuel': capitalActuel,
      'capital_cash': capitalCash,
      'capital_airtel_money': capitalAirtelMoney,
      'capital_mpesa': capitalMPesa,
      'capital_orange_money': capitalOrangeMoney,
      // Capitaux devise secondaire
      'capital_initial_devise2': capitalInitialDevise2,
      'capital_actuel_devise2': capitalActuelDevise2,
      'capital_cash_devise2': capitalCashDevise2,
      'capital_airtel_money_devise2': capitalAirtelMoneyDevise2,
      'capital_mpesa_devise2': capitalMPesaDevise2,
      'capital_orange_money_devise2': capitalOrangeMoneyDevise2,
      'creances': creances,
      'dettes': dettes,
      // Champs de synchronisation
      'uuid': uuid,
      'last_modified_at':
          lastModifiedAt?.toString().split('.')[0].replaceFirst('T', ' '),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toString().split('.')[0].replaceFirst('T', ' '),
      'is_synced': isSynced ?? false,
      'synced_at': syncedAt?.toString(),
    };
  }

  ShopModel copyWith({
    int? id,
    String? designation,
    String? localisation,
    bool? isPrincipal,
    bool? isTransferShop,
    String? devisePrincipale,
    String? deviseSecondaire,
    // Capitaux devise principale
    double? capitalInitial,
    double? capitalActuel,
    double? capitalCash,
    double? capitalAirtelMoney,
    double? capitalMPesa,
    double? capitalOrangeMoney,
    // Capitaux devise secondaire
    double? capitalInitialDevise2,
    double? capitalActuelDevise2,
    double? capitalCashDevise2,
    double? capitalAirtelMoneyDevise2,
    double? capitalMPesaDevise2,
    double? capitalOrangeMoneyDevise2,
    double? creances,
    double? dettes,
    String? uuid,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      designation: designation ?? this.designation,
      localisation: localisation ?? this.localisation,
      isPrincipal: isPrincipal ?? this.isPrincipal,
      isTransferShop: isTransferShop ?? this.isTransferShop,
      devisePrincipale: devisePrincipale ?? this.devisePrincipale,
      deviseSecondaire: deviseSecondaire ?? this.deviseSecondaire,
      // Capitaux devise principale
      capitalInitial: capitalInitial ?? this.capitalInitial,
      capitalActuel: capitalActuel ?? this.capitalActuel,
      capitalCash: capitalCash ?? this.capitalCash,
      capitalAirtelMoney: capitalAirtelMoney ?? this.capitalAirtelMoney,
      capitalMPesa: capitalMPesa ?? this.capitalMPesa,
      capitalOrangeMoney: capitalOrangeMoney ?? this.capitalOrangeMoney,
      // Capitaux devise secondaire
      capitalInitialDevise2:
          capitalInitialDevise2 ?? this.capitalInitialDevise2,
      capitalActuelDevise2: capitalActuelDevise2 ?? this.capitalActuelDevise2,
      capitalCashDevise2: capitalCashDevise2 ?? this.capitalCashDevise2,
      capitalAirtelMoneyDevise2:
          capitalAirtelMoneyDevise2 ?? this.capitalAirtelMoneyDevise2,
      capitalMPesaDevise2: capitalMPesaDevise2 ?? this.capitalMPesaDevise2,
      capitalOrangeMoneyDevise2:
          capitalOrangeMoneyDevise2 ?? this.capitalOrangeMoneyDevise2,
      creances: creances ?? this.creances,
      dettes: dettes ?? this.dettes,
      // Champs de synchronisation
      uuid: uuid ?? this.uuid,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Vérifie si le shop utilise une devise secondaire
  bool get hasDeviseSecondaire =>
      deviseSecondaire != null && deviseSecondaire!.isNotEmpty;

  /// Obtient le capital total dans la devise spécifiée
  double getCapitalActuel(String devise) {
    if (devise == devisePrincipale) {
      return capitalActuel;
    } else if (devise == deviseSecondaire) {
      return capitalActuelDevise2 ?? 0.0;
    }
    return 0.0;
  }

  /// Obtient le capital cash dans la devise spécifiée
  double getCapitalCash(String devise) {
    if (devise == devisePrincipale) {
      return capitalCash;
    } else if (devise == deviseSecondaire) {
      return capitalCashDevise2 ?? 0.0;
    }
    return 0.0;
  }

  /// Obtient le capital mobile money dans la devise spécifiée
  double getCapitalMobileMoney(String devise, String type) {
    if (devise == devisePrincipale) {
      switch (type.toLowerCase()) {
        case 'airtel':
        case 'airtelmoney':
          return capitalAirtelMoney;
        case 'mpesa':
        case 'm-pesa':
          return capitalMPesa;
        case 'orange':
        case 'orangemoney':
          return capitalOrangeMoney;
        default:
          return 0.0;
      }
    } else if (devise == deviseSecondaire) {
      switch (type.toLowerCase()) {
        case 'airtel':
        case 'airtelmoney':
          return capitalAirtelMoneyDevise2 ?? 0.0;
        case 'mpesa':
        case 'm-pesa':
          return capitalMPesaDevise2 ?? 0.0;
        case 'orange':
        case 'orangemoney':
          return capitalOrangeMoneyDevise2 ?? 0.0;
        default:
          return 0.0;
      }
    }
    return 0.0;
  }

  /// Liste des devises supportees par ce shop
  List<String> get devisesSupportees {
    final devises = [devisePrincipale];
    if (hasDeviseSecondaire) {
      devises.add(deviseSecondaire!);
    }
    return devises;
  }

  /// Résout la désignation d'un shop depuis son ID
  /// Utilise la désignation fournie si disponible, sinon cherche dans la liste des shops
  /// Retourne "Shop #ID" en dernier recours
  static String resolveDesignation({
    required int? shopId,
    String? designation,
    List<ShopModel>? shops,
  }) {
    // Si la désignation est fournie et non vide, l'utiliser
    if (designation != null && designation.isNotEmpty) {
      return designation;
    }

    // Si pas d'ID, impossible de résoudre
    if (shopId == null) {
      return 'Shop inconnu';
    }

    // Essayer de résoudre depuis la liste des shops
    if (shops != null && shops.isNotEmpty) {
      try {
        final shop = shops.firstWhere(
          (s) => s.id == shopId,
          orElse: () => ShopModel(designation: '', localisation: ''),
        );
        if (shop.designation.isNotEmpty) {
          return shop.designation;
        }
      } catch (e) {
        // Ignorer l'erreur et utiliser le fallback
      }
    }

    // Fallback: afficher l'ID
    return 'Shop #$shopId';
  }

  /// Trouver le shop principal dans une liste de shops
  /// Retourne null si aucun shop principal n'est trouvé
  static ShopModel? findMainShop(List<ShopModel> shops) {
    try {
      return shops.firstWhere((shop) => shop.isPrincipal);
    } catch (e) {
      return null;
    }
  }

  /// Trouver le shop de service par défaut dans une liste de shops
  /// Utilise UNIQUEMENT le champ is_transfer_shop (pas de fallback sur nom)
  /// Retourne null si aucun shop de service n'est trouvé
  static ShopModel? findServiceShop(List<ShopModel> shops) {
    try {
      // Chercher par champ is_transfer_shop
      return shops.firstWhere(
        (shop) => shop.isTransferShop,
      );
    } catch (e) {
      return null; // Aucun shop de transfert configuré
    }
  }

  /// Vérifier si ce shop est le shop principal
  bool get isMainShop => isPrincipal;

  /// Vérifier si ce shop est le shop de service (transfer shop)
  /// Utilise UNIQUEMENT le champ is_transfer_shop
  bool get isServiceShop => isTransferShop;

  /// Vérifier si ce shop est un shop normal (ni principal ni service)
  bool get isNormalShop => !isPrincipal && !isTransferShop;
}
