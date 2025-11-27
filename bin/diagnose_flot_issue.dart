import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/models/flot_model.dart';

/// Script de diagnostic pour vérifier les FLOTs stockés localement
void main() async {
  print('🔍 ===== DIAGNOSTIC DES FLOTS =====\n');
  
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  
  // 1. Afficher toutes les clés FLOT
  final flotKeys = keys.where((k) => k.startsWith('flot_')).toList();
  print('📋 Clés FLOT trouvées: ${flotKeys.length}');
  print('   → ${flotKeys.join(", ")}\n');
  
  if (flotKeys.isEmpty) {
    print('❌ PROBLÈME: Aucun FLOT trouvé dans SharedPreferences!');
    print('   Cela signifie que le FLOT n\'a pas été sauvegardé localement.\n');
    return;
  }
  
  // 2. Charger et afficher les détails de chaque FLOT
  print('📦 Détails des FLOTs:\n');
  for (var key in flotKeys) {
    try {
      final flotData = prefs.getString(key);
      if (flotData != null) {
        final json = jsonDecode(flotData);
        final flot = FlotModel.fromJson(json);
        
        print('  • FLOT #${flot.id}');
        print('    Reference: ${flot.reference}');
        print('    Montant: ${flot.montant} ${flot.devise}');
        print('    Source: Shop ${flot.shopSourceId} (${flot.shopSourceDesignation})');
        print('    Destination: Shop ${flot.shopDestinationId} (${flot.shopDestinationDesignation})');
        print('    Statut: ${flot.statutLabel}');
        print('    Date Envoi: ${flot.dateEnvoi}');
        print('    Date Réception: ${flot.dateReception ?? "Non reçu"}');
        print('    Agent Envoyeur: ${flot.agentEnvoyeurUsername} (ID: ${flot.agentEnvoyeurId})');
        print('    Agent Récepteur: ${flot.agentRecepteurUsername ?? "N/A"} (ID: ${flot.agentRecepteurId ?? "N/A"})');
        print('    Synchronisé: ${flot.isSynced ? "✅ Oui" : "❌ Non"}');
        print('    Synced At: ${flot.syncedAt ?? "Jamais"}\n');
      }
    } catch (e) {
      print('    ⚠️ Erreur lors du chargement de $key: $e\n');
    }
  }
  
  // 3. Afficher les FLOTs en attente de synchronisation
  print('\n🔄 ===== SYNCHRONISATION =====\n');
  final pendingFlotsData = prefs.getString('pending_flots');
  if (pendingFlotsData != null && pendingFlotsData.isNotEmpty) {
    try {
      final List<dynamic> pending = jsonDecode(pendingFlotsData);
      print('📪 FLOTs en attente de sync: ${pending.length}');
      for (var i = 0; i < pending.length; i++) {
        final flotJson = pending[i] as Map<String, dynamic>;
        print('   ${i + 1}. Reference: ${flotJson['reference']}, Montant: ${flotJson['montant']}');
      }
    } catch (e) {
      print('⚠️ Erreur lors de la lecture des FLOTs en attente: $e');
    }
  } else {
    print('✅ Aucun FLOT en attente de synchronisation');
  }
  
  print('\n✅ Diagnostic terminé\n');
  
  // 4. Recommandations
  print('💡 ===== RECOMMANDATIONS =====\n');
  print('1. Vérifiez que le shop ID utilisé correspond à celui du FLOT');
  print('2. Si le FLOT n\'est pas synchronisé, vérifiez la connexion internet');
  print('3. Essayez de rafraîchir la page FLOT avec le bouton "Actualiser"');
  print('4. Vérifiez les logs de synchronisation dans la console\n');
}
