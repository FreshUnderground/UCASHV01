import 'package:flutter/foundation.dart';

/// Configuration centralisée pour la synchronisation
/// 
/// Permet d'ajuster facilement les paramètres de sync sans modifier
/// le code source des services
class SyncConfig {
  /// ========== TIMING CONFIGURATION ==========
  
  /// Intervalle de synchronisation FAST (données critiques)
  /// Tables: operations, flots, clients, comptes_speciaux, sims, virtual_transactions
  static const Duration fastSyncInterval = Duration(minutes: 2);
  
  /// Intervalle de synchronisation SLOW (données de configuration)
  /// Tables: shops, agents, commissions, cloture_caisse, document_headers
  static const Duration slowSyncInterval = Duration(minutes: 10);
  
  /// Délai avant retry des syncs échouées
  static const Duration retryDelay = Duration(seconds: 30);
  
  /// Timeout pour les requêtes HTTP de sync
  static const Duration syncTimeout = Duration(seconds: 30);
  
  /// ========== DATA CONSISTENCY CONFIGURATION ==========
  
  /// Fenêtre de chevauchement pour éviter les données manquantes
  /// 
  /// PROBLÈME RÉSOLU:
  /// - User A sync à 12:00:00
  /// - User B crée opération à 12:00:05
  /// - User A re-sync à 12:02:00 avec since=12:00:00
  /// - SANS overlap: Opération 12:00:05 peut être manquée
  /// - AVEC overlap: On télécharge depuis 11:59:00 → Garantie aucune perte
  /// 
  /// Valeur recommandée: 60 secondes
  /// - Plus court (30s): Risque de données manquantes
  /// - Plus long (120s): Plus de données dupliquées (mais sûr)
  static const Duration overlapWindow = Duration(seconds: 60);
  
  /// Activer/désactiver le overlap window
  /// 
  /// ⚠️ ATTENTION: Désactiver = risque de données manquantes!
  /// Utile uniquement pour tests/debugging
  static const bool enableOverlapWindow = true;
  
  /// ========== PAGINATION CONFIGURATION ==========
  
  /// Nombre maximum d'entités à télécharger par requête
  /// 
  /// Valeur actuelle: 1000 (définie côté serveur)
  /// Recommandation future: 500 (meilleure performance réseau)
  static const int maxRecordsPerRequest = 1000;
  
  /// Activer la pagination (future implémentation)
  static const bool enablePagination = false;
  
  /// Taille de page pour la pagination
  static const int pageSize = 500;
  
  /// Nombre maximum de pages à télécharger par sync
  /// (Protection contre les boucles infinies)
  static const int maxPagesPerSync = 10;
  
  /// ========== RETRY CONFIGURATION ==========
  
  /// Nombre maximum de tentatives pour une sync échouée
  static const int maxRetries = 2;
  
  /// Délais progressifs pour les retries (backoff exponentiel)
  static const List<Duration> retryDelays = [
    Duration(seconds: 3),   // 1ère tentative: 3s
    Duration(seconds: 10),  // 2ème tentative: 10s
  ];
  
  /// ========== OFFLINE MODE CONFIGURATION ==========
  
  /// Nombre maximum d'opérations en queue offline
  static const int maxPendingOperations = 1000;
  
  /// Nombre maximum de flots en queue offline
  static const int maxPendingFlots = 500;
  
  /// Durée de conservation des opérations en attente
  static const Duration pendingDataRetention = Duration(days: 7);
  
  /// ========== MONITORING CONFIGURATION ==========
  
  /// Activer les logs détaillés de sync
  /// 
  /// En production: false (pour performance)
  /// En développement: true (pour debugging)
  static bool get enableDetailedLogs => kDebugMode;
  
  /// Fréquence des rapports de santé de sync
  static const Duration healthReportInterval = Duration(hours: 1);
  
  /// Seuil d'alerte pour taux de succès de sync (%)
  static const double minSuccessRate = 80.0;
  
  /// Délai maximum acceptable depuis dernière sync réussie
  static const Duration maxTimeSinceLastSync = Duration(minutes: 10);
  
  /// ========== NETWORK OPTIMIZATION ==========
  
  /// Compresser les requêtes HTTP (future implémentation)
  static const bool enableCompression = false;
  
  /// Utiliser la sync delta (seulement champs modifiés)
  static const bool enableDeltaSync = false;
  
  /// Taille maximale de batch pour uploads
  static const int maxUploadBatchSize = 100;
  
  /// ========== TABLE-SPECIFIC CONFIGURATION ==========
  
  /// Tables critiques qui doivent TOUJOURS être synchronisées
  static const List<String> criticalTables = [
    'operations',
    'flots',
    'clients',
    'comptes_speciaux',
  ];
  
  /// Tables qui peuvent tolérer un délai de sync plus long
  static const List<String> nonCriticalTables = [
    'document_headers',
    'cloture_caisse',
    'audit_log',
    'reconciliations',
  ];
  
  /// ========== HELPER METHODS ==========
  
  /// Obtenir le délai de retry pour une tentative donnée
  static Duration getRetryDelay(int attempt) {
    if (attempt >= retryDelays.length) {
      return retryDelays.last;
    }
    return retryDelays[attempt];
  }
  
  /// Vérifier si une table est critique
  static bool isCriticalTable(String tableName) {
    return criticalTables.contains(tableName);
  }
  
  /// Obtenir la configuration complète sous forme JSON
  static Map<String, dynamic> toJson() {
    return {
      'timing': {
        'fast_sync_interval': '${fastSyncInterval.inMinutes} min',
        'slow_sync_interval': '${slowSyncInterval.inMinutes} min',
        'retry_delay': '${retryDelay.inSeconds}s',
        'sync_timeout': '${syncTimeout.inSeconds}s',
      },
      'consistency': {
        'overlap_window': '${overlapWindow.inSeconds}s',
        'enable_overlap': enableOverlapWindow,
      },
      'pagination': {
        'max_records_per_request': maxRecordsPerRequest,
        'enable_pagination': enablePagination,
        'page_size': pageSize,
        'max_pages': maxPagesPerSync,
      },
      'retry': {
        'max_retries': maxRetries,
        'retry_delays': retryDelays.map((d) => '${d.inSeconds}s').toList(),
      },
      'offline': {
        'max_pending_operations': maxPendingOperations,
        'max_pending_flots': maxPendingFlots,
        'retention_days': pendingDataRetention.inDays,
      },
      'monitoring': {
        'detailed_logs': enableDetailedLogs,
        'health_report_interval': '${healthReportInterval.inHours}h',
        'min_success_rate': '$minSuccessRate%',
        'max_time_since_sync': '${maxTimeSinceLastSync.inMinutes} min',
      },
      'optimization': {
        'compression': enableCompression,
        'delta_sync': enableDeltaSync,
        'max_upload_batch': maxUploadBatchSize,
      },
    };
  }
  
  /// Logger la configuration au démarrage
  static void logConfiguration() {
    if (enableDetailedLogs) {
      debugPrint('⚙️ ========== SYNC CONFIGURATION ==========');
      final config = toJson();
      config.forEach((category, settings) {
        debugPrint('📋 $category:');
        if (settings is Map) {
          settings.forEach((key, value) {
            debugPrint('   • $key: $value');
          });
        }
      });
      debugPrint('⚙️ =======================================');
    }
  }
}
