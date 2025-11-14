import 'dart:io';
import 'package:ucashv01/services/sync_service.dart';
import 'package:ucashv01/services/local_db.dart';
import 'package:ucashv01/services/shop_service.dart';
import 'package:ucashv01/models/shop_model.dart';

void main() async {
  print('🧪 Test de la fonctionnalité de synchronisation');
  
  try {
    // Initialize services
    final syncService = SyncService();
    await syncService.initialize();
    
    final shopService = ShopService.instance;
    await shopService.loadShops();
    
    print('✅ Services initialisés avec succès');
    
    // Test connectivity
    print('🔍 Test de la connectivité...');
    final isConnected = await syncService.testConnection();
    print('🌐 Connectivité: ${isConnected ? "✅ Connecté" : "❌ Déconnecté"}');
    
    // Test sync
    print('🔄 Test de synchronisation...');
    final result = await syncService.syncAll(userId: 'test_user');
    print('📊 Résultat de synchronisation: ${result.success ? "✅ Réussi" : "❌ Échoué"}');
    print('📝 Message: ${result.message}');
    
    // Test get last sync timestamp
    final timestamp = await syncService.getLastSyncTimestamp('shops');
    print('🕒 Dernière synchronisation shops: ${timestamp ?? "Jamais"}');
    
    print('🏁 Tests terminés');
  } catch (e) {
    print('❌ Erreur lors des tests: $e');
  }
}