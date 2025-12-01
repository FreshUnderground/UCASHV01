# Fix: SIMs manquantes en local (2 Airtel en ligne, 1 en local)

## 🔍 Problème

Vous voyez **2 SIMs Airtel** sur le serveur (en ligne) mais seulement **1 SIM** en local dans l'application.

C'est un problème de **synchronisation descendante** (download serveur → app).

## 🎯 Diagnostic Rapide

### Étape 1: Vérifier les SIMs sur le serveur

Exécutez le script de diagnostic:

```bash
dart run bin/diagnose_sim_sync.dart
```

Ce script va:
- ✅ Compter le nombre total de SIMs sur le serveur
- ✅ Afficher toutes les SIMs Airtel trouvées
- ✅ Montrer leurs détails (ID, numéro, shop, statut)

### Étape 2: Vérifier les SIMs en local

Dans l'application Flutter:
1. Allez dans **Configuration** → **Gestion SIMs**
2. Notez combien de SIMs Airtel vous voyez
3. Comparez avec le résultat du script

## 🔧 Solutions

### Solution 1: Forcer une synchronisation complète

#### Depuis l'application:

1. **Dans le dashboard Admin ou Agent:**
   - Cliquez sur l'icône de synchronisation (🔄)
   - OU
   - Allez dans **Configuration** → **Synchronisation**
   - Cliquez sur **"Synchroniser maintenant"**

2. **Vérifiez les logs dans la console:**
   ```
   📥 Download SIMs...
   ✅ X SIMs téléchargées depuis le serveur
   💾 X SIMs sauvegardées en local
   ```

3. **Rechargez la page/l'écran SIMs**

#### Depuis le code (pour développeur):

```dart
// Dans un fichier de test ou console
import 'package:ucashv01/services/sync_service.dart';
import 'package:ucashv01/services/sim_service.dart';

void main() async {
  // 1. Synchroniser
  final syncService = SyncService();
  await syncService.syncAll(userId: 'admin');
  
  // 2. Recharger les SIMs
  await SimService.instance.loadSims();
  
  // 3. Afficher les SIMs
  print('Total SIMs: ${SimService.instance.sims.length}');
  for (var sim in SimService.instance.sims) {
    print('${sim.numero} - ${sim.operateur} - Shop ${sim.shopId}');
  }
}
```

### Solution 2: Vérifier les shop_id

Les SIMs ne sont téléchargées que si elles ont un `shop_id` valide.

1. **Vérifiez sur le serveur:**
   ```bash
   dart run bin/diagnose_sim_sync.dart
   ```
   
   Regardez le champ `Shop ID` de chaque SIM Airtel.

2. **Si une SIM a `shop_id = 0` ou `null`:**
   - Elle ne sera PAS téléchargée en local
   - **Solution:** Corriger le `shop_id` sur le serveur

### Solution 3: Vider le cache local et re-synchroniser

#### Méthode A: Depuis l'application

1. **Sur mobile/web:**
   - Paramètres du navigateur/app → Effacer les données
   - OU
   - Se déconnecter complètement
   - Vider le cache
   - Se reconnecter

2. **Lancer une nouvelle synchronisation**

#### Méthode B: Depuis le code

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ucashv01/services/local_db.dart';

void main() async {
  // 1. Vider TOUTES les SIMs locales
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('sim_'));
  for (var key in keys) {
    await prefs.remove(key);
  }
  
  print('✅ Cache SIMs vidé');
  
  // 2. Re-synchroniser
  final syncService = SyncService();
  await syncService.downloadTableData('sims', 'manual_clear', 'admin');
  
  // 3. Recharger
  await SimService.instance.loadSims();
  print('Total SIMs après sync: ${SimService.instance.sims.length}');
}
```

### Solution 4: Vérifier la logique de filtrage

La méthode `loadSims()` peut filtrer par `shopId`:

```dart
// Dans l'app, vérifiez comment les SIMs sont chargées
await SimService.instance.loadSims(); // Toutes les SIMs
// OU
await SimService.instance.loadSims(shopId: 123); // Seulement shop 123
```

**Si vous filtrez par shopId:**
- Vérifiez que les 2 SIMs Airtel ont le MÊME `shop_id`
- Sinon, une sera invisible

## 📋 Checklist de Vérification

- [ ] Exécuter `dart run bin/diagnose_sim_sync.dart`
- [ ] Noter le nombre de SIMs Airtel sur le serveur
- [ ] Comparer avec le nombre en local
- [ ] Vérifier les `shop_id` de toutes les SIMs Airtel
- [ ] Forcer une synchronisation complète
- [ ] Recharger l'écran SIMs dans l'app
- [ ] Vérifier les logs de synchronisation
- [ ] Si nécessaire, vider le cache et re-synchroniser

## 🔬 Debug Avancé

### Activer les logs détaillés

Dans `lib/services/sync_service.dart`, vérifiez que les logs sont activés:

```dart
debugPrint('📥 [SYNC] Téléchargement SIMs...');
debugPrint('   Depuis: $since');
debugPrint('   Réponse: ${entities.length} SIMs');
```

### Vérifier la table `sims` sur le serveur

Exécutez cette requête SQL sur le serveur:

```sql
SELECT 
    id, numero, operateur, shop_id, shop_designation, 
    statut, last_modified_at, is_synced 
FROM sims 
WHERE operateur LIKE '%airtel%'
ORDER BY id;
```

Résultat attendu:
```
+----+-------------+-----------+---------+-------------------+--------+---------------------+-----------+
| id | numero      | operateur | shop_id | shop_designation  | statut | last_modified_at    | is_synced |
+----+-------------+-----------+---------+-------------------+--------+---------------------+-----------+
| 1  | 0817000001  | Airtel    | 100     | Shop Kisangani    | active | 2024-11-29 10:00:00 | 1         |
| 2  | 0817000002  | Airtel    | 100     | Shop Kisangani    | active | 2024-11-29 11:00:00 | 1         |
+----+-------------+-----------+---------+-------------------+--------+---------------------+-----------+
```

Si vous voyez 2 lignes → Problème de synchronisation
Si vous voyez 1 ligne → Problème de données serveur (possible doublon phantom)

## 🚀 Solution Rapide (TL;DR)

```bash
# 1. Diagnostic
dart run bin/diagnose_sim_sync.dart

# 2. Dans l'app Flutter, déclencher sync
#    Dashboard → Icône 🔄 Sync

# 3. Recharger l'écran SIMs
#    Configuration → Gestion SIMs
```

## 📞 Si le problème persiste

Fournissez ces informations:

1. **Résultat du script de diagnostic:**
   ```
   Total SIMs sur serveur: X
   SIMs Airtel trouvées: X
   ```

2. **Nombre de SIMs en local:**
   ```
   Total SIMs dans l'app: X
   SIMs Airtel dans l'app: X
   ```

3. **Logs de synchronisation:**
   ```
   Copier les logs console lors de la sync
   ```

4. **shop_id des SIMs Airtel:**
   ```
   SIM 1: shop_id = ?
   SIM 2: shop_id = ?
   ```

---

**Date:** 2024-11-29  
**Priorité:** ⚠️ Moyenne  
**Impact:** Données incomplètes en local
