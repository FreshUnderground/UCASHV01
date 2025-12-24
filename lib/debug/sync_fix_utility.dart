import 'package:flutter/foundation.dart';
import '../services/robust_sync_service.dart';
import '../utils/sync_recovery_utils.dart';

/// Utilitaire simple pour forcer le reset du circuit breaker
/// et tester la récupération de synchronisation
class SyncFixUtility {
  
  /// Force le reset du circuit breaker et relance la sync
  /// À utiliser quand le circuit breaker est OPEN et bloque toutes les syncs
  static Future<void> forceFixSyncNow() async {
    debugPrint('🚨 === FORCE FIX SYNC - RESET CIRCUIT BREAKER ===');
    
    try {
      // 1. Obtenir l'état actuel
      final diagnosticInfo = SyncRecoveryUtils.getDiagnosticInfo();
      debugPrint('📊 Circuit breaker ouvert: ${diagnosticInfo['isCircuitBreakerOpen']}');
      debugPrint('📊 Échecs: ${diagnosticInfo['failureCount']}');
      debugPrint('📊 Tables échouées (fast): ${diagnosticInfo['failedFastTables']}');
      debugPrint('📊 Tables échouées (slow): ${diagnosticInfo['failedSlowTables']}');
      
      // 2. Force reset du circuit breaker
      debugPrint('🔧 Force reset du circuit breaker...');
      final robustSync = RobustSyncService();
      robustSync.forceResetCircuitBreaker();
      
      // 3. Attendre un peu
      await Future.delayed(Duration(seconds: 3));
      
      // 4. Vérifier que le reset a fonctionné
      final newDiagnosticInfo = SyncRecoveryUtils.getDiagnosticInfo();
      debugPrint('✅ Nouveau état circuit breaker: ${newDiagnosticInfo['isCircuitBreakerOpen']}');
      
      // 5. Force sync maintenant
      debugPrint('🚀 Lancement de la synchronisation forcée...');
      await robustSync.forceSyncNow();
      
      debugPrint('✅ === FORCE FIX SYNC TERMINÉ ===');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du force fix sync: $e');
      
      // En cas d'erreur, au moins essayer de reset le circuit breaker
      try {
        final robustSync = RobustSyncService();
        robustSync.forceResetCircuitBreaker();
        debugPrint('🔧 Circuit breaker reseté malgré l\'erreur');
      } catch (resetError) {
        debugPrint('❌ Impossible de reset le circuit breaker: $resetError');
      }
    }
  }
  
  /// Affiche l'état détaillé du système de sync
  static void showSyncStatus() {
    debugPrint('📋 === ÉTAT DÉTAILLÉ DU SYSTÈME DE SYNC ===');
    
    final diagnosticInfo = SyncRecoveryUtils.getDiagnosticInfo();
    
    debugPrint('🔄 Sync activée: ${diagnosticInfo['isEnabled']}');
    debugPrint('🌐 En ligne: ${diagnosticInfo['isOnline']}');
    debugPrint('🚨 Circuit breaker ouvert: ${diagnosticInfo['isCircuitBreakerOpen']}');
    debugPrint('📊 Nombre d\'échecs: ${diagnosticInfo['failureCount']}');
    debugPrint('⏰ Dernière erreur: ${diagnosticInfo['lastFailureTime']}');
    debugPrint('⚡ Dernière sync rapide: ${diagnosticInfo['lastFastSync']}');
    debugPrint('🐌 Dernière sync lente: ${diagnosticInfo['lastSlowSync']}');
    debugPrint('✅ Succès sync rapide: ${diagnosticInfo['fastSyncSuccess']}');
    debugPrint('❌ Erreurs sync rapide: ${diagnosticInfo['fastSyncErrors']}');
    debugPrint('✅ Succès sync lente: ${diagnosticInfo['slowSyncSuccess']}');
    debugPrint('❌ Erreurs sync lente: ${diagnosticInfo['slowSyncErrors']}');
    
    final failedFast = diagnosticInfo['failedFastTables'] as List<String>? ?? [];
    final failedSlow = diagnosticInfo['failedSlowTables'] as List<String>? ?? [];
    
    if (failedFast.isNotEmpty) {
      debugPrint('⚡ Tables FAST en échec: ${failedFast.join(', ')}');
    }
    
    if (failedSlow.isNotEmpty) {
      debugPrint('🐌 Tables SLOW en échec: ${failedSlow.join(', ')}');
    }
    
    if (failedFast.isEmpty && failedSlow.isEmpty) {
      debugPrint('✅ Aucune table en échec');
    }
    
    debugPrint('📋 === FIN ÉTAT SYNC ===');
  }
  
  /// Test spécifique pour triangular_debt_settlements
  static Future<void> testTriangularSync() async {
    debugPrint('🔺 === TEST TRIANGULAR DEBT SETTLEMENTS SYNC ===');
    
    try {
      await SyncRecoveryUtils.fixTriangularDebtSettlementsSync();
      debugPrint('✅ Test triangular sync terminé');
    } catch (e) {
      debugPrint('❌ Erreur test triangular sync: $e');
    }
  }
}
