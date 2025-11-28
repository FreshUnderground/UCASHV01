# Clear and Reload Data Feature - MISE À JOUR IMPORTANTE

## ATTENTION: Modification de l'approche

**Le paramètre `clearBeforeLoad` a été SUPPRIMÉ de l'utilisation dans SyncService.**

### Pourquoi?

L'approche initiale causait un problème critique:
1. Les données étaient supprimées localement avec `clearBeforeLoad: true`
2. Mais si le rechargement depuis le serveur échouait, **l'utilisateur ne pouvait plus se connecter**
3. Les données étaient perdues sans garantie de rechargement

### Solution actuelle

Le SyncService gère maintenant la synchronisation de manière **incrémentale et sécurisée**:

1. **Téléchargement depuis le serveur** (`_downloadTableData`)
2. **Insertion/mise à jour dans LocalDB** (`_processRemoteChanges`)
3. **Rechargement en mémoire** avec `forceRefresh: true` (PAS `clearBeforeLoad`)

```dart
// Dans _downloadTableData (ligne 778-789)
switch (tableName) {
  case 'shops':
    await ShopService.instance.loadShops(forceRefresh: true);  // ✅ Sécurisé
    break;
  case 'agents':
    await AgentService.instance.loadAgents(forceRefresh: true);  // ✅ Sécurisé
    break;
  // ...
}
```

### Différence entre `forceRefresh` et `clearBeforeLoad`

| Paramètre | Action | Risque | Utilisation |
|------------|--------|--------|-------------|
| `forceRefresh: true` | Vide le cache en mémoire, recharge depuis LocalDB | ✅ Aucun | Normal |
| `clearBeforeLoad: true` | **Supprime les données de LocalDB**, puis recharge | ❌ Élevé si sync échoue | **NON UTILISÉ** |

## Architecture

### 1. Méthodes de suppression dans LocalDB

Ajout de 5 nouvelles méthodes dans [`lib/services/local_db.dart`](lib/services/local_db.dart):

```dart
/// Supprimer tous les shops en local
Future<void> clearAllShops() async

/// Supprimer tous les agents en local (protège l'admin)
Future<void> clearAllAgents() async

/// Supprimer tous les clients en local
Future<void> clearAllClients() async

/// Supprimer toutes les commissions en local
Future<void> clearAllCommissions() async

/// Supprimer tous les taux en local
Future<void> clearAllTaux() async
```

**Important**: La méthode `clearAllAgents()` protège automatiquement le compte admin pour éviter de bloquer l'accès à l'application.

### 2. Paramètre clearBeforeLoad dans les services

Chaque service de chargement de données a maintenant un paramètre optionnel `clearBeforeLoad`:

#### ShopService
```dart
Future<void> loadShops({
  bool forceRefresh = false, 
  bool clearBeforeLoad = false
}) async
```

#### AgentService
```dart
Future<void> loadAgents({
  bool forceRefresh = false, 
  bool clearBeforeLoad = false
}) async
```

#### ClientService
```dart
Future<void> loadClients({
  int? shopId, 
  bool clearBeforeLoad = false
}) async
```

#### RatesService
```dart
Future<void> loadRatesAndCommissions({
  bool clearBeforeLoad = false
}) async
```

### 3. Intégration avec le SyncService

Le [`SyncService`](lib/services/sync_service.dart) utilise automatiquement `clearBeforeLoad: true` dans deux endroits clés:

#### a) Dans `_downloadTableData()` (ligne 778-809)
Lorsque des données sont téléchargées depuis le serveur:
```dart
switch (tableName) {
  case 'shops':
    await ShopService.instance.loadShops(clearBeforeLoad: true);
    break;
  case 'agents':
    await AgentService.instance.loadAgents(clearBeforeLoad: true);
    break;
  case 'clients':
    await ClientService().loadClients(clearBeforeLoad: true);
    break;
  case 'taux':
  case 'commissions':
    await RatesService.instance.loadRatesAndCommissions(clearBeforeLoad: true);
    break;
}
```

#### b) Dans `_processRemoteChanges()` (ligne 891-927)
Après le traitement des changements distants:
```dart
// CRITIQUE: Recharger les services en mémoire après traitement
switch (tableName) {
  case 'shops':
    await ShopService.instance.loadShops(clearBeforeLoad: true);
    break;
  // ... autres cas
}
```

### 4. Intégration avec AuthService

Le [`AuthService`](lib/services/auth_service.dart) utilise également `clearBeforeLoad: true` lors du rafraîchissement des données utilisateur après une connexion (méthode `refreshUserData()`):

```dart
// Rafraîchir les taux et commissions
await RatesService.instance.loadRatesAndCommissions(clearBeforeLoad: true);

// Rafraîchir les shops
await ShopService.instance.loadShops(clearBeforeLoad: true);

// Rafraîchir les agents
await AgentService.instance.loadAgents(clearBeforeLoad: true);
```

## Flux d'exécution

### Synchronisation normale

1. **Upload des données locales** → Serveur
2. **Download des données du serveur**:
   - Pour chaque table (shops, agents, clients, commissions):
     1. Supprimer toutes les données locales de cette table
     2. Télécharger les données depuis le serveur
     3. Insérer les données dans la base locale
     4. Recharger le service en mémoire

### Connexion utilisateur

1. **Login réussi**
2. **Rafraîchissement des données**:
   - Suppression locale + rechargement des taux et commissions
   - Suppression locale + rechargement des shops
   - Suppression locale + rechargement des agents
   - Rechargement de l'utilisateur actuel

## Avantages

### ✅ Fraîcheur des données
- Les données locales sont toujours synchronisées avec le serveur
- Aucune donnée obsolète ne reste en local

### ✅ Cohérence
- Les suppressions effectuées sur le serveur sont reflétées en local
- Les modifications sont toujours à jour

### ✅ Simplicité
- Pas de logique complexe de détection de suppressions
- Approche "clean slate" à chaque synchronisation

### ✅ Fiabilité
- Résout les problèmes de doublons
- Élimine les données corrompues

## Considérations de performance

### Impact minimal
- La suppression locale est rapide (quelques ms)
- Le téléchargement depuis le serveur est optimisé
- Le rechargement en mémoire est instantané

### Optimisations
- Les données sont supprimées **uniquement pendant la synchronisation**
- Utilisation de SharedPreferences pour un accès rapide
- Traitement asynchrone pour ne pas bloquer l'interface

## Utilisation

### Utilisation automatique
Le paramètre `clearBeforeLoad: true` est utilisé **automatiquement** dans les scénarios suivants:
- Synchronisation via SyncService
- Rafraîchissement des données après login (AuthService)

### Utilisation manuelle (si nécessaire)
Si vous devez forcer un rechargement depuis le serveur:

```dart
// Recharger les shops
await ShopService.instance.loadShops(clearBeforeLoad: true);

// Recharger les agents
await AgentService.instance.loadAgents(clearBeforeLoad: true);

// Recharger les clients
await ClientService().loadClients(clearBeforeLoad: true);

// Recharger les taux et commissions
await RatesService.instance.loadRatesAndCommissions(clearBeforeLoad: true);
```

## Tests

### Test manuel
1. Créer un shop/agent/client dans l'application
2. Synchroniser avec le serveur
3. Supprimer l'entité sur le serveur (via MySQL)
4. Synchroniser à nouveau depuis l'application
5. ✅ L'entité supprimée ne devrait plus apparaître localement

### Test de persistance
1. Créer plusieurs shops/agents/clients
2. Synchroniser
3. Fermer l'application
4. Rouvrir l'application
5. ✅ Les données devraient être présentes (rechargées depuis le serveur)

## Maintenance

### Logs de débogage
Les logs suivants permettent de suivre le processus:
```
🗑️ [ShopService] Suppression des shops en local avant rechargement...
🗑️ Shops supprimés en local: 5
📥 Download shops...
✅ 5 shops rechargés depuis le serveur
```

### Surveillance
Surveiller les logs pour détecter:
- Suppressions massives inattendues
- Échecs de téléchargement après suppression
- Problèmes de performance

## Fichiers modifiés

1. **lib/services/local_db.dart**
   - Ajout de 5 méthodes clear*()

2. **lib/services/shop_service.dart**
   - Ajout du paramètre `clearBeforeLoad`

3. **lib/services/agent_service.dart**
   - Ajout du paramètre `clearBeforeLoad`

4. **lib/services/client_service.dart**
   - Ajout du paramètre `clearBeforeLoad`

5. **lib/services/rates_service.dart**
   - Ajout du paramètre `clearBeforeLoad`

6. **lib/services/sync_service.dart**
   - Utilisation de `clearBeforeLoad: true` dans 2 emplacements

7. **lib/services/auth_service.dart**
   - Utilisation de `clearBeforeLoad: true` dans `refreshUserData()`

## Compatibilité

- ✅ Compatible avec la synchronisation existante
- ✅ Compatible avec le système offline/online
- ✅ Compatible avec tous les types de données (shops, agents, clients, taux, commissions)
- ✅ Préserve le compte admin

## Conclusion

Cette fonctionnalité garantit que les données locales sont toujours une copie fidèle des données du serveur, éliminant les problèmes de données obsolètes, de doublons et d'incohérences.
