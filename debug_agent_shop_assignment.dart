import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Script de débogage pour vérifier les assignations shop des agents
/// Exécuter avec: dart run debug_agent_shop_assignment.dart
void main() async {
  print('🔍 Vérification des assignations shop des agents...\n');

  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();

  // Compter les agents et shops
  final agentKeys = keys.where((k) => k.startsWith('agent_')).toList();
  final shopKeys = keys.where((k) => k.startsWith('shop_')).toList();

  print('📊 Statistiques:');
  print('   Agents trouvés: ${agentKeys.length}');
  print('   Shops trouvés: ${shopKeys.length}');
  print('\n');

  // Lister les shops disponibles
  print('🏪 Liste des shops:');
  final shops = <int, String>{};
  for (var key in shopKeys) {
    try {
      final shopData = prefs.getString(key);
      if (shopData != null) {
        final shopJson = jsonDecode(shopData);
        final id = shopJson['id'];
        final designation = shopJson['designation'] ?? 'Sans nom';
        shops[id] = designation;
        print('   ✓ Shop ID: $id - $designation');
      }
    } catch (e) {
      print('   ✗ Erreur parsing $key: $e');
    }
  }
  print('\n');

  // Vérifier chaque agent
  print('👥 Vérification des agents:');
  var agentsAvecShop = 0;
  var agentsSansShop = 0;
  var agentsShopInvalide = 0;

  for (var key in agentKeys) {
    try {
      final agentData = prefs.getString(key);
      if (agentData != null) {
        final agentJson = jsonDecode(agentData);
        final username = agentJson['username'] ?? 'inconnu';
        final agentId = agentJson['id'];
        final shopId = agentJson['shop_id'] ?? agentJson['shopId'];
        final role = agentJson['role'] ?? 'AGENT';
        final isActive =
            agentJson['is_active'] == 1 || agentJson['isActive'] == true;

        print('\n   Agent: $username (ID: $agentId)');
        print('      Role: $role');
        print('      Actif: $isActive');
        print('      Shop ID: ${shopId ?? "NON ASSIGNÉ"}');

        if (shopId != null) {
          if (shops.containsKey(shopId)) {
            print('      Shop: ${shops[shopId]} ✅');
            agentsAvecShop++;
          } else {
            print('      Shop: INTROUVABLE (ID $shopId n\'existe pas) ❌');
            agentsShopInvalide++;
          }
        } else {
          print('      Shop: PAS D\'ASSIGNATION ⚠️');
          agentsSansShop++;
        }

        // Afficher le JSON brut pour debug
        print('      JSON: ${agentJson.toString().substring(0, 100)}...');
      }
    } catch (e) {
      print('   ✗ Erreur parsing $key: $e');
    }
  }

  print('\n');
  print('📈 Résumé:');
  print('   Agents avec shop valide: $agentsAvecShop ✅');
  print('   Agents sans assignation: $agentsSansShop ⚠️');
  print('   Agents avec shop invalide: $agentsShopInvalide ❌');

  if (agentsSansShop > 0 || agentsShopInvalide > 0) {
    print('\n⚠️ PROBLÈMES DÉTECTÉS:');
    if (agentsSansShop > 0) {
      print('   → $agentsSansShop agent(s) n\'ont pas de shop assigné');
      print('   → Solution: Assigner un shop via l\'interface admin');
    }
    if (agentsShopInvalide > 0) {
      print(
          '   → $agentsShopInvalide agent(s) ont un shop_id qui n\'existe pas');
      print(
          '   → Solution: Synchroniser les shops ou corriger les assignations');
    }
  } else {
    print('\n✅ Tous les agents ont un shop valide!');
  }
}
