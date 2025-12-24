import 'package:flutter/material.dart';
import 'lib/services/triangular_debt_settlement_service.dart';

/// Script de test pour la suppression des règlements triangulaires
/// Usage: dart run test_triangular_deletion.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔺 === TEST SUPPRESSION RÈGLEMENT TRIANGULAIRE ===');
  
  // Test avec la référence de l'exemple
  const testReference = 'TRI20251221-83194';
  const testUserId = 'admin';
  const testReason = 'Test de suppression depuis script';
  
  try {
    print('📋 Paramètres de test:');
    print('   Référence: $testReference');
    print('   Utilisateur: $testUserId');
    print('   Raison: $testReason');
    print('');
    
    // Exécuter la suppression
    print('🚀 Lancement de la suppression...');
    final success = await TriangularDebtSettlementService.instance
        .deleteTriangularSettlement(
      reference: testReference,
      userId: testUserId,
      deleteReason: testReason,
    );
    
    if (success) {
      print('');
      print('✅ === SUPPRESSION RÉUSSIE ===');
      print('   Le règlement $testReference a été supprimé');
      print('   - Suppression locale: ✅');
      print('   - Suppression serveur: ✅');
      print('   - Synchronisation: ✅');
    } else {
      print('');
      print('❌ === SUPPRESSION ÉCHOUÉE ===');
      print('   Vérifiez les logs pour plus de détails');
    }
    
    print('');
    print('📊 Vérification des règlements actifs...');
    final activeSettlements = await TriangularDebtSettlementService.instance
        .getActiveTriangularSettlements();
    
    print('   Règlements actifs: ${activeSettlements.length}');
    for (final settlement in activeSettlements) {
      print('   - ${settlement.reference}: ${settlement.montant} ${settlement.devise}');
    }
    
    print('');
    print('📊 Vérification de tous les règlements (incluant supprimés)...');
    final allSettlements = await TriangularDebtSettlementService.instance
        .getAllTriangularSettlements(includeDeleted: true);
    
    print('   Total règlements: ${allSettlements.length}');
    final deletedCount = allSettlements.where((s) => s.isDeleted).length;
    print('   Règlements supprimés: $deletedCount');
    
  } catch (e, stackTrace) {
    print('');
    print('💥 === ERREUR DURANT LE TEST ===');
    print('   Erreur: $e');
    print('   Stack trace: $stackTrace');
  }
  
  print('');
  print('🏁 Test terminé');
}
