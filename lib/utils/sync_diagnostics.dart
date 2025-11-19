import 'package:flutter/foundation.dart';
import '../services/local_db.dart';
import '../services/shop_service.dart';
import '../services/operation_service.dart';
import '../models/operation_model.dart';

/// Utilitaire de diagnostic pour les problèmes de synchronisation
/// des opérations de capital initial
class SyncDiagnostics {
  
  /// Vérifie l'état des opérations de capital initial
  static Future<void> checkInitialCapitalOperations() async {
    debugPrint('🔍 === DIAGNOSTIC DES OPÉRATIONS DE CAPITAL INITIAL ===');
    
    try {
      // Charger toutes les opérations
      final allOperations = await LocalDB.instance.getAllOperations();
      final initialCapitalOps = allOperations.where(
        (op) => op.destinataire == 'CAPITAL INITIAL'
      ).toList();
      
      debugPrint('📊 Total opérations: ${allOperations.length}');
      debugPrint('💰 Opérations de capital initial: ${initialCapitalOps.length}');
      
      if (initialCapitalOps.isEmpty) {
        debugPrint('⚠️ Aucune opération de capital initial trouvée');
        return;
      }
      
      // Afficher les détails de chaque opération
      for (var op in initialCapitalOps) {
        debugPrint('   - OP #${op.id}:');
        debugPrint('     • Montant: ${op.montantNet} USD');
        debugPrint('     • Shop ID: ${op.shopSourceId}');
        debugPrint('     • Statut: ${op.statut.name}');
        debugPrint('     • Synced: ${op.isSynced}');
        debugPrint('     • Date: ${op.dateOp}');
        debugPrint('     • Last modified: ${op.lastModifiedAt}');
      }
      
      // Vérifier les shops associés
      await ShopService.instance.loadShops();
      final shops = ShopService.instance.shops;
      debugPrint('🏪 Shops chargés: ${shops.length}');
      
      // Vérifier si les shops ont des opérations de capital initial
      for (var shop in shops) {
        final shopOps = initialCapitalOps.where(
          (op) => op.shopSourceId == shop.id
        ).toList();
        
        debugPrint('   - Shop "${shop.designation}" (ID: ${shop.id}):');
        debugPrint('     • Capital initial: ${shop.capitalInitial} USD');
        debugPrint('     • Capital cash: ${shop.capitalCash} USD');
        debugPrint('     • Opérations de capital: ${shopOps.length}');
        
        if (shopOps.isNotEmpty) {
          for (var op in shopOps) {
            debugPrint('       • OP #${op.id}: ${op.montantNet} USD (synced: ${op.isSynced})');
          }
        } else {
          debugPrint('       • ⚠️ Aucune opération de capital trouvée pour ce shop');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors du diagnostic: $e');
    }
    
    debugPrint('🔍 === FIN DU DIAGNOSTIC ===');
  }
  
  /// Force la synchronisation des opérations de capital initial non synchronisées
  static Future<void> forceSyncInitialCapitalOperations() async {
    debugPrint('🔄 === FORCE SYNC DES OPÉRATIONS DE CAPITAL INITIAL ===');
    
    try {
      // Recharger les services
      await ShopService.instance.loadShops();
      await OperationService().loadOperations();
      
      final operations = OperationService().operations;
      final unsyncedInitialCapitalOps = operations.where(
        (op) => op.destinataire == 'CAPITAL INITIAL' && op.isSynced != true
      ).toList();
      
      debugPrint('📊 Opérations de capital initial non synchronisées: ${unsyncedInitialCapitalOps.length}');
      
      if (unsyncedInitialCapitalOps.isEmpty) {
        debugPrint('✅ Toutes les opérations de capital initial sont synchronisées');
        return;
      }
      
      // Marquer ces opérations comme non synchronisées pour forcer l'upload
      for (var op in unsyncedInitialCapitalOps) {
        final updatedOp = op.copyWith(isSynced: false);
        await LocalDB.instance.updateOperation(updatedOp);
        debugPrint('🔄 OP #${op.id}: Marquée pour synchronisation');
      }
      
      debugPrint('✅ ${unsyncedInitialCapitalOps.length} opérations marquées pour synchronisation');
      debugPrint('💡 Lancez une synchronisation manuelle pour les uploader');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du force sync: $e');
    }
    
    debugPrint('🔄 === FIN DU FORCE SYNC ===');
  }
}