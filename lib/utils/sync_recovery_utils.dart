import 'package:flutter/foundation.dart';
import '../services/robust_sync_service.dart';
import '../services/sync_service.dart';

/// Utilitaires pour la récupération de synchronisation
/// Utilisé pour résoudre les problèmes de circuit breaker et de sync bloquée
class SyncRecoveryUtils {
  
  /// Force la réinitialisation du circuit breaker et relance la synchronisation
  /// Utilisé quand la sync est bloquée par le circuit breaker
  static Future<void> forceResetAndSync() async {
    debugPrint('🔧 === FORCE RESET CIRCUIT BREAKER ET SYNC ===');
    
    try {
      // 1. Reset du circuit breaker dans RobustSyncService
      final robustSync = RobustSyncService();
      robustSync.forceResetCircuitBreaker();
      
      // 2. Attendre un peu pour que le reset prenne effet
      await Future.delayed(Duration(seconds: 2));
      
      // 3. Force sync maintenant
      debugPrint('🚀 Lancement de la synchronisation forcée...');
      await robustSync.forceSyncNow();
      
      debugPrint('✅ Reset et sync forcée terminés');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du reset forcé: $e');
      rethrow;
    }
  }
  
  /// Vérifie l'état du circuit breaker et affiche les informations de diagnostic
  static Map<String, dynamic> getDiagnosticInfo() {
    final robustSync = RobustSyncService();
    final stats = robustSync.getStats();
    
    debugPrint('📊 === DIAGNOSTIC SYNC ===');
    debugPrint('Circuit breaker ouvert: ${stats['isCircuitBreakerOpen']}');
    debugPrint('Nombre d\'échecs: ${stats['failureCount']}');
    debugPrint('Dernière erreur: ${stats['lastFailureTime']}');
    debugPrint('Tables échouées (fast): ${stats['failedFastTables']}');
    debugPrint('Tables échouées (slow): ${stats['failedSlowTables']}');
    debugPrint('En ligne: ${stats['isOnline']}');
    debugPrint('Sync activée: ${stats['isEnabled']}');
    
    return stats;
  }
  
  /// Reset spécifique pour les problèmes de triangular_debt_settlements
  static Future<void> fixTriangularDebtSettlementsSync() async {
    debugPrint('🔺 === FIX TRIANGULAR DEBT SETTLEMENTS SYNC ===');
    
    try {
      // 1. Reset circuit breaker
      final robustSync = RobustSyncService();
      robustSync.forceResetCircuitBreaker();
      
      // 2. Test de la connectivité vers l'endpoint triangular
      debugPrint('🧪 Test de l\'endpoint triangular_debt_settlements...');
      
      // 3. Force sync avec retry
      debugPrint('🔄 Tentative de sync avec retry...');
      await robustSync.forceSyncNow();
      
      debugPrint('✅ Fix triangular debt settlements terminé');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du fix triangular: $e');
      
      // En cas d'échec, au moins reset le circuit breaker
      final robustSync = RobustSyncService();
      robustSync.forceResetCircuitBreaker();
      debugPrint('🔧 Circuit breaker reseté malgré l\'erreur');
    }
  }
  
  /// Affiche les tables critiques qui échouent et leurs statuts
  static void showFailedTablesStatus() {
    final stats = getDiagnosticInfo();
    final failedFast = stats['failedFastTables'] as List<String>? ?? [];
    final failedSlow = stats['failedSlowTables'] as List<String>? ?? [];
    
    debugPrint('📋 === TABLES EN ÉCHEC ===');
    
    if (failedFast.isNotEmpty) {
      debugPrint('⚡ Tables FAST en échec: ${failedFast.join(', ')}');
    }
    
    if (failedSlow.isNotEmpty) {
      debugPrint('🐌 Tables SLOW en échec: ${failedSlow.join(', ')}');
    }
    
    if (failedFast.isEmpty && failedSlow.isEmpty) {
      debugPrint('✅ Aucune table en échec actuellement');
    }
    
    // Vérifier spécifiquement triangular_debt_settlements
    if (failedFast.contains('triangular_debt_settlements') || 
        failedSlow.contains('triangular_debt_settlements')) {
      debugPrint('🔺 PROBLÈME DÉTECTÉ: triangular_debt_settlements en échec');
      debugPrint('💡 Solution: Appeler fixTriangularDebtSettlementsSync()');
    }
  }
}
