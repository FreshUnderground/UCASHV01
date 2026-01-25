import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration de l'application
class AppConfig {
  // Version de l'application
  static const String appVersion = '1.0.0';
  static const String appName = 'UCASH';

  // URL personnalisée stockée par l'utilisateur
  static String? _customApiUrl;

  /// URL de l'API - Peut être personnalisée par l'utilisateur
  ///
  /// L'utilisateur peut définir son URL via les paramètres de synchronisation
  /// Si aucune URL personnalisée n'est définie, utilise l'URL par défaut selon l'environnement
  static Future<String> getApiBaseUrl() async {
    // Si URL personnalisée existe, l'utiliser
    if (_customApiUrl != null && _customApiUrl!.isNotEmpty) {
      return _customApiUrl!.trim();
    }

    // Sinon, charger depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('custom_api_url');

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _customApiUrl = savedUrl.trim();
      return _customApiUrl!;
    }

    // Sinon, utiliser l'URL par défaut selon l'environnement
    return _getDefaultApiUrl();
  }

  /// URL par défaut selon l'environnement (sans personnalisation)
  static String _getDefaultApiUrl() {
    // URL de production par défaut
    const productionUrl = 'https://safdal.investee-group.com/server/api';

    // Pour développement local uniquement (peut être personnalisé via config)
    if (kIsWeb) {
      return productionUrl;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return productionUrl;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return productionUrl;
    } else {
      // Desktop
      return productionUrl;
    }
  }

  /// Sauvegarder l'URL personnalisée
  static Future<void> setCustomApiUrl(String url) async {
    // Nettoyer l'URL: trim et supprimer le slash final si présent
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_url', cleanUrl);
    _customApiUrl = cleanUrl;
    debugPrint('✅ URL API personnalisée sauvegardée: $cleanUrl');
  }

  /// Réinitialiser à l'URL par défaut
  static Future<void> resetToDefaultApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_api_url');
    _customApiUrl = null;
    debugPrint('✅ URL API réinitialisée à la valeur par défaut');
  }

  /// URL synchrone pour compatibilité (utilise la dernière URL chargée)
  static String get apiBaseUrl {
    return _customApiUrl ?? _getDefaultApiUrl();
  }

  /// URL du serveur de synchronisation
  static Future<String> getSyncBaseUrl() async {
    final baseUrl = await getApiBaseUrl();
    return '$baseUrl/sync';
  }

  /// URL synchrone pour compatibilité
  static String get syncBaseUrl => '$apiBaseUrl/sync';

  /// Délai de timeout pour les requêtes HTTP
  static const Duration httpTimeout = Duration(seconds: 30);

  /// Délai de timeout pour la synchronisation
  static const Duration syncTimeout = Duration(seconds: 30);

  /// Intervalle de synchronisation automatique
  static const Duration autoSyncInterval = Duration(minutes: 3);

  /// Mode debug
  static bool get isDebugMode => kDebugMode;

  /// Mode production
  static bool get isProduction {
    // Sur Web, bool.fromEnvironment ne fonctionne pas
    // On utilise une approche différente
    if (kIsWeb) {
      // En développement Web, considérer comme non-production
      // En production, cette valeur peut être définie via les variables d'environnement du build
      const isProd =
          bool.fromEnvironment('FLUTTER_WEB_PRODUCTION', defaultValue: false);
      return isProd;
    } else {
      // Sur mobile/desktop, utiliser la méthode standard
      return bool.fromEnvironment('dart.vm.product');
    }
  }

  /// Plateforme
  static String get platform {
    if (kIsWeb) return 'Web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS';
    return 'Desktop';
  }

  /// Log d'information
  static void logInfo(String message) {
    debugPrint('[UCASH INFO] $message');
  }

  /// Log de configuration au démarrage
  static void logConfig() {
    debugPrint('🚀 ========== UCASH CONFIGURATION ==========');
    debugPrint('📱 Plateforme: $platform');
    debugPrint('🔧 Mode: ${isDebugMode ? "DEBUG" : "PRODUCTION"}');
    debugPrint('🌐 API URL: $apiBaseUrl');
    debugPrint('🔄 Sync URL: $syncBaseUrl');
    debugPrint('⏱️ Auto-sync: ${autoSyncInterval.inSeconds}s');
    debugPrint('🚀 ==========================================');
  }
}
