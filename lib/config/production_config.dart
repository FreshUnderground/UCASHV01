/// Configuration de production pour UCASH
/// Version: 1.0.0 Production Ready
class ProductionConfig {
  // Version de l'application
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String environment = 'PRODUCTION';
  
  // Configuration API de production
  static const String apiBaseUrl = 'https://api.ucash.cd'; // URL de production
  static const String apiVersion = 'v1';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Configuration MySQL de production
  static const String mysqlHost = 'mysql.ucash.cd';
  static const String mysqlDatabase = 'ucash_production';
  static const int mysqlPort = 3306;
  
  // Configuration de sécurité
  static const bool enableDebugLogs = false; // Désactivé en production
  static const bool enableCrashReporting = true;
  static const bool enableAnalytics = true;
  
  // Configuration de synchronisation
  static const Duration syncInterval = Duration(minutes: 10); // Plus conservateur
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 5);
  
  // Configuration de cache
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100; // MB
  
  // Configuration de performance
  static const int maxConcurrentOperations = 5;
  static const Duration operationTimeout = Duration(seconds: 15);
  
  // Limites métier
  static const double maxTransactionAmount = 50000.0; // USD
  static const double minTransactionAmount = 1.0; // USD
  static const int maxDailyTransactions = 100;
  
  // Configuration de backup
  static const Duration backupInterval = Duration(hours: 6);
  static const int maxBackupFiles = 7; // 7 jours
  
  // Informations légales
  static const String companyName = 'UCASH SARL';
  static const String companyAddress = 'Kinshasa, République Démocratique du Congo';
  static const String supportEmail = 'support@ucash.cd';
  static const String supportPhone = '+243 XXX XXX XXX';
  
  // Configuration des devises supportées
  static const List<String> supportedCurrencies = ['USD', 'CDF', 'EUR'];
  
  // Configuration des modes de paiement
  static const List<String> paymentMethods = [
    'Cash',
    'Airtel Money',
    'M-Pesa',
    'Orange Money'
  ];
  
  // Configuration des villes supportées
  static const List<String> supportedCities = [
    'Kinshasa',
    'Lubumbashi', 
    'Goma',
    'Mbuji-Mayi',
    'Kisangani',
    'Kananga',
    'Likasi',
    'Kolwezi',
    'Tshikapa',
    'Beni',
    'Butembo',
    'Matadi',
    'Bukavu',
    'Uvira',
    'Bunia'
  ];
  
  // Configuration des rôles utilisateur
  static const List<String> userRoles = ['ADMIN', 'AGENT', 'CLIENT'];
  
  // Configuration des types d'opérations
  static const List<String> operationTypes = [
    'depot',
    'retrait', 
    'transfertNational',
    'transfertInternationalSortant',
    'transfertInternationalEntrant'
  ];
  
  // Configuration des statuts d'opération
  static const List<String> operationStatuses = [
    'enAttente',
    'validee',
    'annulee',
    'terminee'
  ];
  
  /// Obtenir l'URL complète de l'API
  static String getApiUrl(String endpoint) {
    return '$apiBaseUrl/$apiVersion/$endpoint';
  }
  
  /// Vérifier si l'environnement est en production
  static bool get isProduction => environment == 'PRODUCTION';
  
  /// Obtenir la configuration de timeout selon le type d'opération
  static Duration getTimeoutForOperation(String operationType) {
    switch (operationType) {
      case 'sync':
        return const Duration(minutes: 2);
      case 'transfer':
        return const Duration(seconds: 30);
      case 'query':
        return const Duration(seconds: 10);
      default:
        return operationTimeout;
    }
  }
}
