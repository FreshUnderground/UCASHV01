# 🚀 GUIDE RAPIDE - Synchronisation Automatique des Suppressions

## ✅ Fonctionnalité Activée

La synchronisation automatique des suppressions est **DÉJÀ ACTIVE** et fonctionne automatiquement.

## 🔄 Comment Ça Fonctionne (Automatique)

### Pour les Agents

Quand un admin **supprime** un agent:
1. ✅ Suppression sur le serveur MySQL
2. ⏱️ Attendre 2 minutes (sync automatique) OU rafraîchir manuellement
3. 🗑️ L'agent disparaît automatiquement de tous les terminaux

### Pour les Shops

Quand un admin **supprime** un shop:
1. ✅ Suppression sur le serveur MySQL
2. ⏱️ Attendre 2 minutes (sync automatique) OU rafraîchir manuellement
3. 🗑️ Le shop disparaît automatiquement de tous les terminaux

## 📋 Scénarios d'Utilisation

### Scénario 1: Suppression Normale (Automatique)

```
09:00 - Admin supprime Agent "John" (ID: 5)
09:02 - Sync automatique sur Terminal Agent 1
        → Agent "John" supprimé automatiquement
09:04 - Sync automatique sur Terminal Agent 2
        → Agent "John" supprimé automatiquement
```

**Action requise:** ❌ AUCUNE - Tout est automatique!

---

### Scénario 2: Rafraîchissement Manuel (Immédiat)

```
09:00 - Admin supprime Shop "Bureau Nord" (ID: 10)
09:01 - Agent clique sur "Rafraîchir" ou recharge la liste
        → Shop "Bureau Nord" supprimé immédiatement
```

**Action requise:** 🔄 Cliquer sur rafraîchir (optionnel)

---

### Scénario 3: Multiples Suppressions

```
10:00 - Admin supprime 5 agents d'un coup
10:02 - Sync automatique
        → Les 5 agents disparaissent automatiquement
```

**Résultat:** Tous les agents supprimés disparaissent en une seule fois

---

## 🧪 Comment Tester

### Test 1: Suppression Simple

1. **Terminal Admin:**
   ```sql
   DELETE FROM agents WHERE id = 999;
   ```

2. **Terminal Agent (attendre 2 min OU rafraîchir):**
   - L'agent ID 999 disparaît automatiquement

3. **Logs à vérifier:**
   ```
   🔍 Vérification des agents supprimés sur le serveur...
   🗑️ 1 agent(s) supprimé(s) détecté(s) sur le serveur
   ✅ Agent ID 999 supprimé localement
   ```

---

### Test 2: API Directement (cURL)

```bash
# Tester l'endpoint agents
curl -X POST "https://safdal.investee-group.com/server/api/sync/agents/check_deleted.php" \
  -H "Content-Type: application/json" \
  -d "{\"agent_ids\": [1, 2, 3, 999]}"

# Réponse attendue
{
  "success": true,
  "deleted_agents": [999],
  "existing_count": 3,
  "deleted_count": 1,
  "message": "1 agent(s) supprimé(s) trouvé(s)"
}
```

---

### Test 3: Via Script Batch

```bash
# Lancer le script de test automatique
test_deletion_sync.bat
```

---

## 📊 Indicateurs de Succès

### ✅ Logs Normaux (Pas de suppression)

```
🔍 Vérification des agents supprimés sur le serveur...
✅ Aucun agent supprimé trouvé sur le serveur
```

### ✅ Logs avec Suppression Détectée

```
🔍 Vérification des agents supprimés sur le serveur...
🗑️ 2 agent(s) supprimé(s) détecté(s) sur le serveur
   ✅ Agent ID 3 supprimé localement
   ✅ Agent ID 5 supprimé localement
✅ Nettoyage local terminé: 2 agent(s) supprimé(s)
```

### ⚠️ Logs d'Erreur (Non Bloquant)

```
⚠️ Erreur lors de la vérification des agents supprimés: Timeout
```
*Note: L'app continue à fonctionner normalement*

---

## 🔧 Configuration

### Modifier le Délai de Sync (Optionnel)

Par défaut: **2 minutes**

Pour changer:
```dart
// lib/services/sync_service.dart (ligne 67)
static Duration get _autoSyncInterval => const Duration(minutes: 2);

// Exemple: Changer à 1 minute
static Duration get _autoSyncInterval => const Duration(minutes: 1);
```

### Modifier le Timeout API (Optionnel)

Par défaut: **15 secondes**

Pour changer:
```dart
// Dans agent_service.dart et shop_service.dart
.timeout(
  const Duration(seconds: 15),  // ← Changer ici
  onTimeout: () { ... },
);
```

---

## 🐛 Dépannage

### Problème: Les suppressions ne se synchronisent pas

**Solutions:**

1. **Vérifier la connexion Internet**
   ```
   Logs: "❌ Aucune connexion Internet disponible"
   ```

2. **Vérifier les endpoints API**
   ```bash
   # Test manuel
   curl https://safdal.investee-group.com/server/api/sync/agents/check_deleted.php
   ```

3. **Vérifier les logs**
   ```
   Chercher: "⚠️ Erreur lors de la vérification"
   ```

4. **Forcer une synchronisation manuelle**
   ```dart
   // Dans l'app
   await AgentService.instance.loadAgents(forceRefresh: true);
   await ShopService.instance.loadShops(forceRefresh: true);
   ```

---

### Problème: Erreur 500 sur l'API

**Cause possible:** Base de données non accessible

**Solution:**
1. Vérifier que MySQL est démarré
2. Vérifier `server/config/database.php`
3. Regarder les logs PHP dans `error_log`

---

### Problème: Timeout (15s dépassé)

**Cause:** Serveur lent ou beaucoup de données

**Solution:**
```dart
// Augmenter le timeout
.timeout(
  const Duration(seconds: 30),  // 15s → 30s
  onTimeout: () { ... },
);
```

---

## 📚 Documentation Complète

- **Anglais:** `AUTOMATIC_DELETION_SYNC.md`
- **Français:** `SYNCHRONISATION_SUPPRESSION_AUTOMATIQUE.md`
- **Tests:** `test/test_deletion_sync.dart`

---

## 💡 Points Importants

1. **Automatique par défaut** ✅
   - Pas besoin de configuration
   - Fonctionne immédiatement

2. **Non bloquant** ✅
   - Si l'API échoue, l'app continue
   - Les erreurs sont loggées mais ignorées

3. **Tolérant aux erreurs** ✅
   - Timeout après 15s
   - Continue même en cas d'échec

4. **Minimal en bande passante** ✅
   - ~80 bytes par vérification
   - Vérification groupée (pas individuelle)

5. **Transparent pour l'utilisateur** ✅
   - Aucun message affiché
   - UI se met à jour automatiquement

---

## ✅ Checklist de Vérification

- [x] Endpoints API créés (`check_deleted.php`)
- [x] Méthodes de vérification ajoutées (Services)
- [x] Intégration dans le cycle de sync
- [x] Gestion des erreurs
- [x] Tests unitaires créés
- [x] Documentation complète
- [x] Aucune erreur de compilation

**🎉 Fonctionnalité 100% opérationnelle!**

---

## 🆘 Support

En cas de problème:
1. Consulter les logs de l'app
2. Tester les endpoints manuellement (cURL)
3. Vérifier la base de données MySQL
4. Consulter la documentation complète

**Tout fonctionne automatiquement - Aucune action requise!** 🚀
