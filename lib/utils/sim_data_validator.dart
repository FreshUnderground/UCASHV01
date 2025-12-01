import 'package:flutter/foundation.dart';
import '../services/local_db.dart';
import '../models/sim_model.dart';

/// Utilitaire pour valider et nettoyer les données SIM
class SimDataValidator {
  /// Vérifier et afficher les SIMs avec des données invalides
  static Future<void> checkInvalidSims() async {
    try {
      debugPrint('🔍 Vérification des SIMs invalides...');
      
      // Récupérer toutes les SIMs via LocalDB
      final sims = await LocalDB.instance.getAllSims();
      
      debugPrint('📊 Total SIMs: ${sims.length}');
      
      int invalidCount = 0;
      final List<Map<String, dynamic>> invalidSims = [];
      
      for (var sim in sims) {
        final issues = <String>[];
        
        // Vérifier numero
        if (sim.numero.isEmpty) {
          issues.add('numero manquant');
        }
        
        // Vérifier operateur
        if (sim.operateur.isEmpty) {
          issues.add('operateur manquant');
        }
        
        // Vérifier shop_id
        if (sim.shopId == 0) {
          issues.add('shop_id invalide (${sim.shopId})');
        }
        
        // Vérifier id
        if (sim.id == null) {
          issues.add('id manquant');
        }
        
        if (issues.isNotEmpty) {
          invalidCount++;
          invalidSims.add({
            'sim': sim,
            'issues': issues,
          });
          
          debugPrint('⚠️  SIM invalide #$invalidCount:');
          debugPrint('   ID: ${sim.id}');
          debugPrint('   Numéro: ${sim.numero}');
          debugPrint('   Opérateur: ${sim.operateur}');
          debugPrint('   Shop ID: ${sim.shopId}');
          debugPrint('   Problèmes: ${issues.join(', ')}');
          debugPrint('');
        }
      }
      
      if (invalidCount == 0) {
        debugPrint('✅ Toutes les SIMs sont valides!');
      } else {
        debugPrint('❌ $invalidCount SIM(s) invalide(s) trouvée(s)');
        debugPrint('');
        debugPrint('💡 Pour corriger:');
        debugPrint('   1. Ouvrez la gestion des SIMs');
        debugPrint('   2. Modifiez chaque SIM invalide pour ajouter les données manquantes');
        debugPrint('   3. Ou supprimez les SIMs invalides');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification: $e');
    }
  }
  
  /// Supprimer les SIMs invalides (ATTENTION: opération destructive!)
  static Future<int> deleteInvalidSims() async {
    try {
      debugPrint('🗑️  Suppression des SIMs invalides...');
      
      // Récupérer toutes les SIMs via LocalDB
      final sims = await LocalDB.instance.getAllSims();
      
      int deleted = 0;
      
      for (var sim in sims) {
        // Vérifier si la SIM est invalide
        bool isInvalid = false;
        
        // Vérifier numero
        if (sim.numero.isEmpty) {
          isInvalid = true;
        }
        
        // Vérifier operateur
        if (sim.operateur.isEmpty) {
          isInvalid = true;
        }
        
        // Vérifier shop_id
        if (sim.shopId == 0) {
          isInvalid = true;
        }
        
        // Vérifier id
        if (sim.id == null) {
          isInvalid = true;
        }
        
        if (isInvalid && sim.id != null) {
          await LocalDB.instance.deleteSim(sim.id!);
          deleted++;
          debugPrint('🗑️  SIM supprimée: ID=${sim.id}, Numéro=${sim.numero}');
        }
      }
      
      if (deleted > 0) {
        debugPrint('✅ $deleted SIM(s) invalides supprimée(s)');
      } else {
        debugPrint('✅ Aucune SIM invalide trouvée');
      }
      
      return deleted;
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression: $e');
      return 0;
    }
  }
  
  /// Valider une SIM avant de la sauvegarder
  static bool validateSim(SimModel sim) {
    final issues = <String>[];
    
    // Vérifier numero
    if (sim.numero.isEmpty) {
      issues.add('numero manquant');
    }
    
    // Vérifier operateur
    if (sim.operateur.isEmpty) {
      issues.add('operateur manquant');
    }
    
    // Vérifier shop_id
    if (sim.shopId == 0) {
      issues.add('shop_id invalide (${sim.shopId})');
    }
    
    // Vérifier id (peut être null pour les nouvelles SIMs)
    // Pas besoin de vérifier l'id ici car il peut être null
    
    if (issues.isNotEmpty) {
      debugPrint('❌ SIM invalide: ${issues.join(', ')}');
      return false;
    }
    
    return true;
  }
}