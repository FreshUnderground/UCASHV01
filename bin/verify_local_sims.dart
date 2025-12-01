import 'package:ucashv01/services/local_db.dart';

/// Script pour vérifier les SIMs enregistrées localement
void main() async {
  print('\n🔍 ======== VÉRIFICATION SIMS LOCALES ========\n');
  
  try {
    // Charger toutes les SIMs sans filtre de shop
    final allSims = await LocalDB.instance.getAllSims();
    
    print('📱 Total SIMs en local: ${allSims.length}\n');
    print('=' * 80);
    
    if (allSims.isEmpty) {
      print('\n❌ AUCUNE SIM TROUVÉE EN LOCAL!');
      print('   → Lancez une synchronisation depuis l\'app');
      print('   → Vérifiez que le serveur est accessible');
    } else {
      // Afficher toutes les SIMs
      for (var i = 0; i < allSims.length; i++) {
        final sim = allSims[i];
        print('\n${i + 1}. SIM #${sim.id}');
        print('   ├─ Numéro: ${sim.numero}');
        print('   ├─ Opérateur: ${sim.operateur}');
        print('   ├─ Shop ID: ${sim.shopId}');
        print('   ├─ Shop: ${sim.shopDesignation ?? 'N/A'}');
        print('   ├─ Statut: ${sim.statut.name}');
        print('   ├─ Solde initial: ${sim.soldeInitial} USD');
        print('   ├─ Solde actuel: ${sim.soldeActuel} USD');
        print('   ├─ Date création: ${sim.dateCreation}');
        print('   ├─ Créé par: ${sim.creePar ?? 'N/A'}');
        print('   ├─ Dernière modif: ${sim.lastModifiedAt ?? 'N/A'}');
        print('   ├─ Is synced: ${sim.isSynced}');
        print('   └─ Synced at: ${sim.syncedAt ?? 'N/A'}');
        print('   ' + '-' * 76);
      }
      
      // Statistiques par opérateur
      final simsByOperateur = <String, int>{};
      for (var sim in allSims) {
        simsByOperateur[sim.operateur] = (simsByOperateur[sim.operateur] ?? 0) + 1;
      }
      
      print('\n' + '=' * 80);
      print('\n📊 STATISTIQUES PAR OPÉRATEUR:\n');
      simsByOperateur.forEach((op, count) {
        print('   $op: $count SIM(s)');
      });
      
      // Statistiques par shop
      final simsByShop = <int, List<String>>{};
      for (var sim in allSims) {
        simsByShop.putIfAbsent(sim.shopId, () => []);
        simsByShop[sim.shopId]!.add('${sim.numero} (${sim.operateur})');
      }
      
      print('\n📊 STATISTIQUES PAR SHOP:\n');
      simsByShop.forEach((shopId, simNumeros) {
        final shopDesignation = allSims.firstWhere((s) => s.shopId == shopId).shopDesignation ?? 'N/A';
        print('   Shop $shopId ($shopDesignation): ${simNumeros.length} SIM(s)');
        for (var numero in simNumeros) {
          print('      - $numero');
        }
      });
      
      // Filtrer les Airtel
      final airtelSims = allSims.where((s) => s.operateur.toLowerCase().contains('airtel')).toList();
      print('\n📱 SIMS AIRTEL EN LOCAL: ${airtelSims.length}\n');
      
      if (airtelSims.isEmpty) {
        print('   ❌ Aucune SIM Airtel trouvée en local');
        print('   → Mais il y en a 3 sur le serveur!');
        print('   → Lancez une synchronisation manuelle');
      } else {
        print('   ℹ️ SIMs Airtel:');
        for (var sim in airtelSims) {
          print('      - ${sim.numero} (Shop: ${sim.shopDesignation}, Solde: ${sim.soldeActuel} USD)');
        }
      }
    }
    
    print('\n💡 NOTE IMPORTANTE:');
    print('   → L\'app FILTRE les SIMs par shop lors de l\'affichage');
    print('   → Un agent ne voit QUE les SIMs de SON shop');
    print('   → Un admin peut voir TOUTES les SIMs via "Gestion SIMs"');
    print('   → C\'est normal de ne pas voir toutes les SIMs dans l\'interface utilisateur');
    
  } catch (e, stackTrace) {
    print('❌ Erreur lors de la vérification:');
    print('   $e');
    print('\n   Stack trace:');
    print('   $stackTrace');
  }
  
  print('\n🔍 ======== FIN VÉRIFICATION ========\n');
}
