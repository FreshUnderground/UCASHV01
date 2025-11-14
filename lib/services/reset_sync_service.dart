import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResetSyncService {
  /// Réinitialiser tous les timestamps de synchronisation
  static Future<void> resetAllSyncTimestamps() async {
    debugPrint('🔄 Réinitialisation des timestamps de synchronisation...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Liste des entités à réinitialiser
      final entities = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
      
      int resetCount = 0;
      for (String entity in entities) {
        final key = 'sync_last_${entity}';
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          resetCount++;
          debugPrint('✅ Reset timestamp pour: $entity');
        }
      }
      
      debugPrint('🎉 $resetCount timestamps réinitialisés !');
      debugPrint('📤 La prochaine sync uploadera TOUTES les données locales');
      
    } catch (e) {
      debugPrint('❌ Erreur reset timestamps: $e');
    }
  }
  
  /// Vérifier les timestamps actuels
  static Future<void> checkSyncTimestamps() async {
    debugPrint('🔍 === TIMESTAMPS DE SYNCHRONISATION ===');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final entities = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
      
      for (String entity in entities) {
        final key = 'sync_last_$entity';
        final timestamp = prefs.getString(key);
        
        if (timestamp != null) {
          debugPrint('📅 $entity: $timestamp');
        } else {
          debugPrint('🆕 $entity: Jamais synchronisé (null)');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Erreur check timestamps: $e');
    }
    
    debugPrint('🔍 === FIN TIMESTAMPS ===');
  }
  
  /// Forcer une synchronisation complète (reset + sync)
  static Future<void> forceFreshSync() async {
    debugPrint('🚀 === SYNCHRONISATION COMPLÈTE FORCÉE ===');
    
    await checkSyncTimestamps();
    await resetAllSyncTimestamps();
    
    debugPrint('✅ Prêt pour synchronisation complète !');
    debugPrint('💡 Cliquez maintenant sur "Sync MySQL" pour uploader toutes les données');
  }
}
