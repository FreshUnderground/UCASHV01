/// Utilitaires pour la gestion des devises dans le système VIRTUEL
class CurrencyUtils {
  // Devises supportées pour les transactions virtuelles
  static const List<String> supportedCurrencies = ['USD', 'CDF'];
  
  // Devise par défaut
  static const String defaultCurrency = 'USD';
  
  // Symboles des devises
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'CDF': 'FC',
  };
  
  // Noms complets des devises
  static const Map<String, String> currencyNames = {
    'USD': 'Dollar Américain',
    'CDF': 'Franc Congolais',
  };
  
  /// Obtenir le symbole d'une devise
  static String getSymbol(String currency) {
    return currencySymbols[currency] ?? currency;
  }
  
  /// Obtenir le nom complet d'une devise
  static String getName(String currency) {
    return currencyNames[currency] ?? currency;
  }
  
  /// Formater un montant avec la devise
  static String formatAmount(double amount, String currency) {
    final symbol = getSymbol(currency);
    if (currency == 'CDF') {
      // Pour le CDF, pas de décimales
      return '${amount.toStringAsFixed(0)} $symbol';
    } else {
      // Pour USD, 2 décimales
      return '$symbol${amount.toStringAsFixed(2)}';
    }
  }
  
  /// Vérifier si une devise est supportée
  static bool isSupported(String currency) {
    return supportedCurrencies.contains(currency);
  }
  
  /// Obtenir la liste des devises avec leurs noms
  static List<Map<String, String>> getCurrencyOptions() {
    return supportedCurrencies.map((currency) => {
      'code': currency,
      'name': getName(currency),
      'symbol': getSymbol(currency),
    }).toList();
  }
}
