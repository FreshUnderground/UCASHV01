import '../services/shop_service.dart';

/// Utilitaire pour corriger les shops existants en créant les clôtures
/// initiales manquantes pour servir de solde antérieur.
/// 
/// Cette correction est nécessaire pour avoir un solde antérieur
/// permettant aux agents de commencer les transactions.
class FixInitialDeposits {
  
  /// Exécute la correction pour tous les shops existants
  static Future<void> execute() async {
    print('🔧 Correction des clôtures initiales manquantes...');
    
    try {
      final shopService = ShopService.instance;
      
      // Charger tous les shops
      await shopService.loadShops();
      
      // Créer les clôtures initiales manquantes
      await shopService.createMissingInitialClosures();
      
      print('✅ Correction terminée avec succès !');
      print('📊 Les shops ont maintenant un solde antérieur (clôture de la veille).');
      
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
      
      // Vérifier s'il y a des shops sans clôture initiale
      for (final shop in shopService.shops) {
        if (shop.id != null) {
          // Si des shops existent, on suppose qu'ils ont besoin d'une clôture initiale
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
