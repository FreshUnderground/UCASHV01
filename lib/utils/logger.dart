import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Utilitaire de logging pour UCASH
/// Remplace debugPrint avec des logs conditionnels selon l'environnement
class Logger {
  /// Log de debug (désactivé en production)
  static void debug(String message) {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('[DEBUG] $message');
    }
  }

  /// Log d'information (toujours actif)
  static void info(String message) {
    // ignore: avoid_print
    print('[INFO] $message');
  }

  /// Log d'erreur (toujours actif)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('[ERROR] $message');
    if (error != null) {
      // ignore: avoid_print
      print('[ERROR] Details: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('[ERROR] Stack trace: $stackTrace');
    }
  }

  /// Log d'avertissement (toujours actif)
  static void warning(String message) {
    // ignore: avoid_print
    print('[WARNING] $message');
  }

  /// Log de succès (toujours actif)
  static void success(String message) {
    // ignore: avoid_print
    print('[SUCCESS] $message');
  }

  /// Log de synchronisation (conditionnel)
  static void sync(String message) {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('[SYNC] $message');
    }
  }

  /// Log de performance (conditionnel)
  static void performance(String message) {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('[PERF] $message');
    }
  }
}

/// Extension pour remplacer facilement debugPrint
extension DebugPrintReplacement on String {
  void logDebug() => Logger.debug(this);
  void logInfo() => Logger.info(this);
  void logError([dynamic error, StackTrace? stackTrace]) => Logger.error(this, error, stackTrace);
  void logWarning() => Logger.warning(this);
  void logSuccess() => Logger.success(this);
  void logSync() => Logger.sync(this);
}