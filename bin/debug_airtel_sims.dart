import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Script de diagnostic pour identifier pourquoi deux Airtel SIMs en ligne
/// mais une seule en local
void main() async {
  print('\n🔍 ======== DIAGNOSTIC AIRTEL SIMS ========\n');

  const serverUrl =
      'https://safdal.investee-group.com/server/api/sync/sims/changes.php';

  try {
    // 1. Récupérer TOUTES les SIMs du serveur
    print('📡 Récupération des SIMs depuis le serveur...');
    print('   URL: $serverUrl');

    final response = await http.get(
      Uri.parse('$serverUrl?since=2020-01-01T00:00:00.000'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      print('❌ Erreur HTTP: ${response.statusCode}');
      print('   Body: ${response.body}');
      exit(1);
    }

    final data = jsonDecode(response.body);
    final entities = data['entities'] as List;

    print('✅ Réponse serveur OK');
    print('   Total SIMs: ${entities.length}\n');

    // 2. Filtrer et afficher les SIMs Airtel
    final airtelSims = entities
        .where((sim) =>
            (sim['operateur'] as String).toLowerCase().contains('airtel'))
        .toList();

    print('📱 SIMS AIRTEL TROUVÉES: ${airtelSims.length}\n');
    print('=' * 80);

    for (var i = 0; i < airtelSims.length; i++) {
      final sim = airtelSims[i];
      print('\n${i + 1}. AIRTEL SIM #${sim['id']}');
      print('   ├─ Numéro: ${sim['numero']}');
      print('   ├─ Opérateur: ${sim['operateur']}');
      print('   ├─ Shop ID: ${sim['shop_id']}');
      print('   ├─ Shop: ${sim['shop_designation'] ?? 'N/A'}');
      print('   ├─ Statut: ${sim['statut']}');
      print('   ├─ Solde initial: ${sim['solde_initial']} USD');
      print('   ├─ Solde actuel: ${sim['solde_actuel']} USD');
      print('   ├─ Date création: ${sim['date_creation']}');
      print('   ├─ Créé par: ${sim['cree_par']}');
      print('   ├─ Dernière modif: ${sim['last_modified_at']}');
      print('   ├─ Modifié par: ${sim['last_modified_by'] ?? 'N/A'}');
      print('   ├─ Is synced: ${sim['is_synced']}');
      print('   └─ Synced at: ${sim['synced_at'] ?? 'N/A'}');
      print('   ' + '-' * 76);
    }

    print('\n' + '=' * 80);

    // 3. Analyser les différences
    if (airtelSims.length >= 2) {
      print('\n🔬 ANALYSE COMPARATIVE DES DEUX SIMS:\n');

      final sim1 = airtelSims[0];
      final sim2 = airtelSims[1];

      print(
          '┌─ DIFFÉRENCES IDENTIFIÉES ─────────────────────────────────────┐');

      // Comparer les champs critiques
      final comparisons = {
        'ID': [sim1['id'], sim2['id']],
        'Numéro': [sim1['numero'], sim2['numero']],
        'Opérateur': [sim1['operateur'], sim2['operateur']],
        'Shop ID': [sim1['shop_id'], sim2['shop_id']],
        'Shop': [sim1['shop_designation'], sim2['shop_designation']],
        'Statut': [sim1['statut'], sim2['statut']],
        'Solde actuel': [sim1['solde_actuel'], sim2['solde_actuel']],
        'Date création': [sim1['date_creation'], sim2['date_creation']],
        'Dernière modif': [sim1['last_modified_at'], sim2['last_modified_at']],
      };

      for (var entry in comparisons.entries) {
        final field = entry.key;
        final values = entry.value;
        final isDifferent = values[0] != values[1];
        final icon = isDifferent ? '⚠️' : '✅';

        print('│ $icon $field:');
        print('│    SIM 1: ${values[0]}');
        print('│    SIM 2: ${values[1]}');
        print('│');
      }

      print(
          '└────────────────────────────────────────────────────────────────┘');

      // Diagnostic
      print('\n💡 DIAGNOSTIC POSSIBLE:');

      if (sim1['id'] == sim2['id']) {
        print('   ❌ PROBLÈME: Les deux SIMs ont le MÊME ID (${sim1['id']})!');
        print('      → C\'est un doublon dans la base de données serveur');
        print('      → Solution: Supprimer l\'une des deux sur le serveur');
      } else if (sim1['numero'] == sim2['numero']) {
        print(
            '   ⚠️ AVERTISSEMENT: Même numéro (${sim1['numero']}) mais IDs différents');
        print('      → Possible doublon avec IDs différents');
        print('      → Vérifier quelle SIM est la bonne');
      } else if (sim1['shop_id'] != sim2['shop_id']) {
        print('   ℹ️ Les deux SIMs sont dans des shops différents:');
        print(
            '      → SIM 1: Shop ${sim1['shop_id']} (${sim1['shop_designation']})');
        print(
            '      → SIM 2: Shop ${sim2['shop_id']} (${sim2['shop_designation']})');
        print(
            '      → Vérifier si le filtre de shop en local empêche de voir la 2e');
      } else {
        print('   ℹ️ Les deux SIMs semblent légitimes et distinctes');
        print('      → Problème probablement dans la synchronisation locale');
        print('      → Vérifier les logs de sync dans l\'app Flutter');
      }
    }

    print('\n📝 PROCHAINES ÉTAPES:\n');
    print('   1. Comparer avec les SIMs en local dans l\'app');
    print('   2. Lancer une synchronisation manuelle depuis l\'app');
    print('   3. Vérifier les logs Flutter (rechercher "SIM ID" ou "Airtel")');
    print('   4. Si doublon d\'ID, nettoyer la base serveur');
    print('');
  } catch (e, stackTrace) {
    print('❌ Erreur lors du diagnostic:');
    print('   $e');
    print('\n   Stack trace:');
    print('   $stackTrace');
    exit(1);
  }

  print('\n🔍 ======== FIN DU DIAGNOSTIC ========\n');
}
