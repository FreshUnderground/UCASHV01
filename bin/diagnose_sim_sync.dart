import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Script de diagnostic pour la synchronisation des SIMs
/// Vérifie les SIMs côté serveur et côté local
void main() async {
  print('\n🔍 ======== DIAGNOSTIC SYNCHRONISATION SIMS ========\n');
  
  const serverUrl = 'https://mahanaim.investee-group.com/server/api/sync/sims/changes.php';
  
  try {
    // 1. Vérifier les SIMs sur le serveur
    print('📡 Vérification des SIMs sur le serveur...');
    print('   URL: $serverUrl');
    
    final response = await http.get(
      Uri.parse('$serverUrl?since=2020-01-01T00:00:00.000'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));
    
    print('   Status code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final entities = data['entities'] as List;
      
      print('\n✅ Réponse serveur OK');
      print('   Total SIMs sur serveur: ${entities.length}');
      
      // Filtrer les SIMs Airtel
      final airtelSims = entities.where((sim) => 
        (sim['operateur'] as String).toLowerCase().contains('airtel')
      ).toList();
      
      print('\n📱 SIMs Airtel trouvées: ${airtelSims.length}');
      if (airtelSims.isNotEmpty) {
        for (var i = 0; i < airtelSims.length; i++) {
          final sim = airtelSims[i];
          print('\n   ${i + 1}. Airtel SIM:');
          print('      ID: ${sim['id']}');
          print('      Numéro: ${sim['numero']}');
          print('      Opérateur: ${sim['operateur']}');
          print('      Shop ID: ${sim['shop_id']}');
          print('      Shop: ${sim['shop_designation'] ?? 'N/A'}');
          print('      Statut: ${sim['statut']}');
          print('      Solde: ${sim['solde_actuel']} USD');
          print('      Dernière modif: ${sim['last_modified_at']}');
          print('      Synced: ${sim['is_synced']} (${sim['synced_at']})');
        }
      }
      
      // Afficher toutes les SIMs par opérateur
      final simsByOperateur = <String, int>{};
      for (var sim in entities) {
        final op = sim['operateur'] as String;
        simsByOperateur[op] = (simsByOperateur[op] ?? 0) + 1;
      }
      
      print('\n📊 Répartition par opérateur:');
      simsByOperateur.forEach((op, count) {
        print('   $op: $count SIM(s)');
      });
      
      print('\n💡 DIAGNOSTIC:');
      if (airtelSims.length > 1) {
        print('   ⚠️  ${airtelSims.length} SIMs Airtel trouvées sur le serveur');
        print('   ℹ️  Vérifiez que TOUTES sont téléchargées en local');
        print('');
        print('🔧 SOLUTIONS:');
        print('   1. Forcer une synchronisation complète');
        print('   2. Vérifier les logs de sync dans l\'app Flutter');
        print('   3. Vérifier si les SIMs ont des shop_id valides');
        print('   4. Exécuter: flutter run bin/verify_sync.dart');
      } else {
        print('   ✅ Une seule SIM Airtel sur le serveur (normal)');
      }
      
    } else {
      print('❌ Erreur HTTP: ${response.statusCode}');
      print('   Body: ${response.body}');
    }
    
  } catch (e, stackTrace) {
    print('❌ Erreur lors de la vérification:');
    print('   $e');
    print('\n   Stack trace:');
    print('   $stackTrace');
  }
  
  print('\n🔍 ======== FIN DU DIAGNOSTIC ========\n');
  print('📝 Prochaines étapes:');
  print('   1. Notez le nombre de SIMs Airtel trouvées');
  print('   2. Comparez avec le nombre en local dans l\'app');
  print('   3. Lancez une synchronisation depuis l\'app');
  print('   4. Vérifiez les logs de l\'app Flutter');
  print('');
}
