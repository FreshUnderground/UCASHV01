/// Devises supportees par le systeme UCASH
enum Devise {
  USD, // Dollar americain (devise principale)
  CDF, // Franc congolais
  UGX, // Shilling ougandais
}

extension DeviseExtension on Devise {
  String get code {
    switch (this) {
      case Devise.USD:
        return 'USD';
      case Devise.CDF:
        return 'CDF';
      case Devise.UGX:
        return 'UGX';
    }
  }
  
  String get nom {
    switch (this) {
      case Devise.USD:
        return 'Dollar Americain';
      case Devise.CDF:
        return 'Franc Congolais';
      case Devise.UGX:
        return 'Shilling Ougandais';
    }
  }
  
  String get symbole {
    switch (this) {
      case Devise.USD:
        return '\$';
      case Devise.CDF:
        return 'FC';
      case Devise.UGX:
        return 'USh';
    }
  }
  
  /// Parse une chaine en devise
  static Devise? fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return Devise.USD;
      case 'CDF':
        return Devise.CDF;
      case 'UGX':
        return Devise.UGX;
      default:
        return null;
    }
  }
}

/// Configuration de devises pour un shop
/// Un shop peut utiliser 1 ou 2 devises maximum
class ShopDeviseConfig {
  final Devise devisePrincipale;
  final Devise? deviseSecondaire;
  
  ShopDeviseConfig({
    this.devisePrincipale = Devise.USD,
    this.deviseSecondaire,
  });
  
  /// Verifie si le shop supporte une devise
  bool supporte(Devise devise) {
    return devise == devisePrincipale || devise == deviseSecondaire;
  }
  
  /// Verifie si le shop supporte une devise par code
  bool supporteCode(String code) {
    final devise = DeviseExtension.fromCode(code);
    if (devise == null) return false;
    return supporte(devise);
  }
  
  /// Liste des devises supportees
  List<Devise> get devises {
    final list = [devisePrincipale];
    if (deviseSecondaire != null) {
      list.add(deviseSecondaire!);
    }
    return list;
  }
  
  /// Liste des codes de devises
  List<String> get codes => devises.map((d) => d.code).toList();
  
  /// Configurations predefinies
  static ShopDeviseConfig usdOnly() => ShopDeviseConfig(
    devisePrincipale: Devise.USD,
  );
  
  static ShopDeviseConfig usdCdf() => ShopDeviseConfig(
    devisePrincipale: Devise.USD,
    deviseSecondaire: Devise.CDF,
  );
  
  static ShopDeviseConfig usdUgx() => ShopDeviseConfig(
    devisePrincipale: Devise.USD,
    deviseSecondaire: Devise.UGX,
  );
  
  factory ShopDeviseConfig.fromCodes(String? principale, String? secondaire) {
    final dev1 = principale != null 
        ? DeviseExtension.fromCode(principale) ?? Devise.USD 
        : Devise.USD;
    final dev2 = secondaire != null 
        ? DeviseExtension.fromCode(secondaire) 
        : null;
    
    return ShopDeviseConfig(
      devisePrincipale: dev1,
      deviseSecondaire: dev2,
    );
  }
}
