import '../services/shop_service.dart';

/// Utilitaire pour corriger les shops existants en créant les opérations
/// de dépôt initial manquantes pour le cash initial.
/// 
/// Cette correction est nécessaire car avant cette mise à jour,
/// le cash initial n'était pas enregistré comme une entrée en caisse.
class FixInitialDeposits {
  
  /// Exécute la correction pour tous les shops existants
  static Future<void> execute() async {
    print('🔧 Correction des dépôts initiaux manquants...');
    
    try {
      final shopService = ShopService.instance;
      
      // Charger tous les shops
      await shopService.loadShops();
      
      // Créer les dépôts initiaux manquants
      await shopService.createMissingInitialDeposits();
      
      print('✅ Correction terminée avec succès !');
      print('📊 Les mouvements de caisse incluent maintenant le cash initial.');
      
    } catch (e) {
      print('❌ Erreur lors de la correction: $e');
      rethrow;
    }
  }
  
  /// Vérifie si des corrections sont nécessaires
  static Future<bool> needsCorrection() async {
    try {
      final shopService = ShopService.instance;
      await shopService.loadShops();
      
      // Vérifier s'il y a des shops avec du cash mais sans dépôt initial
      for (final shop in shopService.shops) {
        if (shop.capitalCash > 0) {
          // Cette vérification nécessiterait d'accéder à LocalDB
          // Pour simplifier, on retourne true si des shops ont du cash
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Erreur lors de la vérification: $e');
      return false;
    }
  }
}
