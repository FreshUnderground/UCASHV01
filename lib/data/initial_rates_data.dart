import 'package:flutter/foundation.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';

class InitialRatesData {
  // Taux de change reels bases sur le marche congolais (octobre 2024)
  static List<TauxModel> getInitialTaux() {
    return [
      // Taux USD vers CDF
      TauxModel(
        id: 1,
        deviseSource: 'USD',
        deviseCible: 'CDF',
        taux: 2850.0, // 1 USD = 2850 CDF (taux reel approximatif)
        type: 'MOYEN',
      ),
      // Taux USD vers UGX
      TauxModel(
        id: 2,
        deviseSource: 'USD',
        deviseCible: 'UGX',
        taux: 3700.0, // 1 USD = 3700 UGX
        type: 'MOYEN',
      ),
    ];
  }

  // Commissions réelles basées sur les pratiques du marché
  static List<CommissionModel> getInitialCommissions() {
    return [
      // Commission pour transferts sortants (depuis RDC vers l'étranger)
      CommissionModel(
        id: 1,
        type: 'SORTANT',
        taux: 3.5, // 3.5% de commission pour les envois
        description: 'Commission pour transferts sortants depuis la RDC vers l\'étranger',
      ),
      
      // Commission pour transferts entrants (gratuit selon la demande)
      CommissionModel(
        id: 2,
        type: 'ENTRANT',
        taux: 0.0, // Gratuit pour les réceptions
        description: 'Transferts entrants vers la RDC (service gratuit)',
      ),
    ];
  }

  // Methode pour initialiser les donnees dans le systeme
  static Future<void> initializeRealData() async {
    try {
      // Cette methode sera appelee au demarrage de l'application
      // pour s'assurer que des donnees reelles sont disponibles
      debugPrint('🔄 Initialisation des donnees reelles...');
      
      final taux = getInitialTaux();
      final commissions = getInitialCommissions();
      
      debugPrint('✅ ${taux.length} taux de change initialises');
      debugPrint('✅ ${commissions.length} commissions initialisees');
      
      // Les donnees seront sauvegardees via TauxChangeService
      debugPrint('📊 Donnees reelles prete a etre utilisees');
      
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des donnees: $e');
    }
  }

  // Informations sur les taux (pour documentation)
  static Map<String, String> getTauxInfo() {
    return {
      'source': 'Marché des changes congolais',
      'date': 'Octobre 2024',
      'base': 'Franc Congolais (CDF)',
      'note': 'Taux indicatifs basés sur les pratiques du marché',
      'national': 'Taux pour transferts internes en RDC',
      'entrant': 'Taux pour réceptions depuis l\'étranger (plus avantageux)',
      'sortant': 'Taux pour envois vers l\'étranger (frais inclus)',
    };
  }

  // Informations sur les commissions
  static Map<String, String> getCommissionInfo() {
    return {
      'sortant': '3.5% - Commission standard pour envois internationaux',
      'entrant': '0% - Service gratuit pour attirer les réceptions',
      'politique': 'Encourager les entrées de devises en RDC',
      'competitivite': 'Taux compétitifs par rapport aux autres services',
    };
  }
}
