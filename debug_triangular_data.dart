import 'package:flutter/foundation.dart';
import 'lib/services/local_db.dart';
import 'lib/models/triangular_debt_settlement_model.dart';

/// Script de debug pour analyser les données triangulaires en LocalDB
void main() async {
  await debugTriangularData();
}

Future<void> debugTriangularData() async {
  debugPrint('🔍 === DEBUG TRIANGULAR DATA ===');
  
  try {
    // 1. Vérifier toutes les clés dans SharedPreferences
    final prefs = await LocalDB.instance.database;
    final allKeys = prefs.getKeys();
    
    final triangularKeys = allKeys.where((k) => k.startsWith('triangular_settlement_')).toList();
    debugPrint('📊 Total clés triangular_settlement_: ${triangularKeys.length}');
    
    if (triangularKeys.isNotEmpty) {
      debugPrint('🔑 Clés trouvées:');
      for (var key in triangularKeys) {
        debugPrint('   - $key');
      }
    }
    
    // 2. Récupérer via getAllTriangularDebtSettlements
    final allSettlements = await LocalDB.instance.getAllTriangularDebtSettlements();
    debugPrint('📋 getAllTriangularDebtSettlements() retourne: ${allSettlements.length} éléments');
    
    // 3. Analyser chaque règlement
    for (var settlement in allSettlements) {
      debugPrint('🔺 Règlement: ${settlement.reference}');
      debugPrint('   - ID: ${settlement.id}');
      debugPrint('   - isSynced: ${settlement.isSynced}');
      debugPrint('   - isDeleted: ${settlement.isDeleted}');
      debugPrint('   - Montant: ${settlement.montant} ${settlement.devise}');
      debugPrint('   - Date: ${settlement.dateReglement}');
      
      // Vérifier le JSON
      try {
        final json = settlement.toJson();
        debugPrint('   - JSON is_synced: ${json['is_synced']}');
        debugPrint('   - JSON is_deleted: ${json['is_deleted']}');
      } catch (e) {
        debugPrint('   - ❌ Erreur JSON: $e');
      }
    }
    
    // 4. Compter les non-synchronisés
    final unsyncedCount = allSettlements.where((s) => !s.isSynced).length;
    debugPrint('📤 Règlements non synchronisés: $unsyncedCount');
    
    // 5. Compter les non-supprimés
    final activeCount = allSettlements.where((s) => !s.isDeleted).length;
    debugPrint('✅ Règlements actifs (non supprimés): $activeCount');
    
    // 6. Simuler la logique de sync
    debugPrint('🔄 === SIMULATION LOGIQUE SYNC ===');
    final unsyncedData = <Map<String, dynamic>>[];
    
    for (var settlement in allSettlements) {
      try {
        final json = settlement.toJson();
        // Vérifier si non synchronisé (même logique que sync_service.dart)
        if (json['is_synced'] != true) {
          debugPrint('🔺 Règlement non synchronisé détecté: ${settlement.reference}');
          unsyncedData.add(json);
        } else {
          debugPrint('✅ Règlement déjà synchronisé: ${settlement.reference}');
        }
      } catch (e) {
        debugPrint('❌ Erreur conversion JSON pour ${settlement.id}: $e');
      }
    }
    
    debugPrint('📊 RÉSULTAT SIMULATION: ${unsyncedData.length} règlements à synchroniser');
    
  } catch (e) {
    debugPrint('❌ Erreur debug: $e');
  }
  
  debugPrint('🔍 === FIN DEBUG ===');
}
