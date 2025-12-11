# 📊 État des APIs et Synchronisation - Opérations Shop

## 🎯 Question

**Les opérations de suppression, ajustement de capital et modification de shop ont-elles des APIs backend et peuvent-elles être remarquées par les agents lors des mises à jour?**

---

## ✅ Résumé Rapide

| Opération | API Backend | Sync Agents | Notification | Audit Trail |
|-----------|------------|-------------|--------------|-------------|
| **Modification Shop** | ✅ OUI (partiel) | ✅ OUI | ❌ NON | ⚠️ Basique |
| **Ajustement Capital** | ✅ OUI | ❌ NON | ❌ NON | ✅ OUI |
| **Suppression Shop** | ❌ NON | ❌ NON | ❌ NON | ❌ NON |

---

## 📝 Analyse Détaillée

### 1️⃣ **MODIFICATION DE SHOP**

#### ✅ API Backend Existante

**Fichier:** `lib/services/shop_service.dart` (ligne 183-266)

```dart
Future<Map<String, dynamic>?> updateShopViaAPI(ShopModel shop, {String userId = 'admin'})
```

**Endpoint:** `server/api/shops/update.php` ❌ **N'EXISTE PAS ENCORE!**

**Comment ça fonctionne actuellement:**

1. **Mise à jour locale:**
   ```dart
   await LocalDB.instance.updateShop(updatedShop);
   ```

2. **Marquage pour sync:**
   ```dart
   final updatedShop = shop.copyWith(
     isSynced: false,  // ← Marque pour upload
     lastModifiedAt: DateTime.now(),
   );
   ```

3. **Sync automatique:**
   ```dart
   _syncInBackground();  // Upload via SyncManager
   ```

#### 🔄 Synchronisation avec les Agents

**Méthode:** Via `SyncManager.php` (ligne 109-156)

```php
private function updateShop($data) {
    $sql = "UPDATE shops SET 
        designation = ?, localisation = ?,
        capital_actuel = ?, capital_cash = ?, ...
        last_modified_at = ?, last_modified_by = ?
        WHERE id = ?";
}
```

**Comment les agents le voient:**

1. ✅ **Download Sync:** Lors du prochain sync, les agents téléchargent les shops mis à jour
2. ✅ **Automatique:** Pas besoin d'action manuelle
3. ✅ **Timestamp:** Le champ `last_modified_at` permet de détecter les changements

**Exemple de flux:**

```
Admin modifie "Shop Central"
    ↓
Sauvegarde locale avec is_synced=false
    ↓
Sync auto upload vers serveur
    ↓
SyncManager.updateShop() met à jour la BD
    ↓
Agent fait un sync download
    ↓
Agent voit "Shop Central" mis à jour
```

#### ⚠️ **PROBLÈME:** Pas d'API dédiée `update.php`

Le code attend un endpoint `server/api/shops/update.php` qui n'existe PAS encore!

**Solution à implémenter:** Créer `server/api/shops/update.php`

---

### 2️⃣ **AJUSTEMENT DE CAPITAL**

#### ✅ API Backend Complète

**Fichier:** `server/api/audit/log_capital_adjustment.php` (226 lignes)

**Endpoint:** `POST /api/audit/log_capital_adjustment.php`

**Fonctionnalités:**

1. ✅ **Validation:** Vérifie le shop, le montant, le mode de paiement
2. ✅ **Calcul:** Ajuste les capitaux selon le type (INCREASE/DECREASE)
3. ✅ **Mise à jour BD:** UPDATE shops avec nouveaux capitaux
4. ✅ **Audit Trail:** Enregistrement complet dans `audit_log`
5. ✅ **Métadonnées:** Raison obligatoire, description optionnelle

**Exemple d'enregistrement:**

```sql
INSERT INTO audit_log (
    table_name = 'shops',
    record_id = 123,
    action = 'CAPITAL_INCREASE',
    old_values = '{"capital_actuel": 10000, "capital_cash": 10000}',
    new_values = '{"capital_actuel": 15000, "capital_cash": 15000}',
    changed_fields = '{"amount": 5000, "mode_paiement": "CASH"}',
    user_id = 1,
    username = 'admin',
    reason = 'Injection de capital supplémentaire'
)
```

#### ❌ **PROBLÈME:** Pas de notification aux agents

**État actuel:**

- ✅ Le capital est modifié dans la BD
- ✅ L'audit trail est enregistré
- ❌ **Mais les agents NE SONT PAS notifiés automatiquement**

**Impact:**

```
Admin ajuste capital Shop A: 10,000 → 15,000 USD
    ↓
BD mise à jour ✅
    ↓
Audit enregistré ✅
    ↓
Agent du Shop A fait un sync ⚠️
    ↓
QUESTION: L'agent verra-t-il le nouveau capital?
```

**Réponse:** **OUI, mais seulement lors du prochain sync download!**

Les agents téléchargent TOUTES les données shops lors du sync, donc ils verront le changement. Mais il n'y a **pas de notification push**.

---

### 3️⃣ **SUPPRESSION DE SHOP**

#### ❌ Pas d'API Backend

**Fichier:** `lib/services/shop_service.dart` (ligne 268-287)

```dart
Future<bool> deleteShop(int shopId) async {
  await LocalDB.instance.deleteShop(shopId);  // Suppression LOCALE uniquement
  _shops.removeWhere((s) => s.id == shopId);
  return true;
}
```

**Problèmes:**

1. ❌ **Suppression locale uniquement** - Pas de sync avec le serveur
2. ❌ **Pas d'API backend** - Le serveur ne sait pas que le shop est supprimé
3. ❌ **Pas d'audit trail** - Aucun enregistrement de qui a supprimé quoi
4. ❌ **Incohérence** - Le shop existe toujours sur le serveur et chez les autres agents
5. ❌ **Danger** - Lors du prochain sync download, le shop réapparaîtra!

**Impact:**

```
Admin supprime "Shop Nord"
    ↓
Suppression locale ✅
    ↓
Disparaît de l'interface admin ✅
    ↓
MAIS:
- Shop existe toujours sur le serveur ❌
- Les agents le voient encore ❌
- Lors du prochain sync, il revient chez l'admin ❌
```

**🚨 URGENT:** Cette fonctionnalité est **cassée** et dangereuse!

---

## 🔧 Solutions à Implémenter

### 🎯 PRIORITÉ 1: API de Suppression de Shop

**Créer:** `server/api/shops/delete.php`

```php
<?php
header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);
$shopId = $data['shop_id'];
$adminId = $data['admin_id'];
$reason = $data['reason']; // Raison obligatoire

// 1. Vérifier que le shop existe
// 2. Vérifier qu'il n'y a pas d'agents assignés
// 3. Soft delete: is_active = 0
// 4. Enregistrer dans audit_log
// 5. Retourner les agents affectés
```

**Flux:**

```
Admin supprime shop
    ↓
API delete.php
    ↓
Soft delete (is_active=0) ou hard delete
    ↓
Audit trail enregistré
    ↓
Retourne liste des agents à notifier
    ↓
Agents font sync download
    ↓
Shop disparaît chez les agents
```

---

### 🎯 PRIORITÉ 2: API de Modification de Shop

**Créer:** `server/api/shops/update.php`

```php
<?php
header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

// 1. Valider les données
// 2. Mettre à jour le shop
// 3. Enregistrer dans audit_log
// 4. Trouver les agents du shop
// 5. Retourner les agents affectés

$response = [
    'success' => true,
    'affected_agents' => [
        'count' => 3,
        'agent_ids' => [1, 2, 3]
    ]
];
```

---

### 🎯 PRIORITÉ 3: Notification Push pour Ajustement Capital

**Améliorer:** `log_capital_adjustment.php`

Ajouter à la fin de la réponse:

```php
// Trouver les agents du shop
$agentsStmt = $pdo->prepare("
    SELECT id, username, nom 
    FROM agents 
    WHERE shop_id = ? AND is_active = 1
");
$agentsStmt->execute([$shopId]);
$affectedAgents = $agentsStmt->fetchAll(PDO::FETCH_ASSOC);

$response['affected_agents'] = [
    'count' => count($affectedAgents),
    'agents' => $affectedAgents
];
```

---

## 📊 Comparaison: État Actuel vs Idéal

### **État Actuel**

| Opération | Admin voit | Agents voient | Temps de propagation |
|-----------|-----------|---------------|---------------------|
| Modification | Immédiat | Au prochain sync | 1-5 minutes |
| Ajustement Capital | Immédiat | Au prochain sync | 1-5 minutes |
| Suppression | Immédiat | **Jamais** ❌ | **Infini** ❌ |

### **État Idéal (Après Implémentation)**

| Opération | Admin voit | Agents voient | Temps de propagation |
|-----------|-----------|---------------|---------------------|
| Modification | Immédiat | Au prochain sync | 1-5 minutes |
| Ajustement Capital | Immédiat | Au prochain sync + notification | < 1 minute |
| Suppression | Immédiat | Au prochain sync | 1-5 minutes |

---

## 🎓 Comment les Agents Voient les Changements

### **Mécanisme de Synchronisation**

```dart
// Dans RobustSyncService (auto-sync toutes les 2 minutes)
Future<void> _performSync() async {
  // 1. Upload des données locales
  await _uploadLocalChanges();
  
  // 2. Download des données serveur
  await _downloadServerData();  // ← Les shops mis à jour arrivent ici
}
```

**Download des Shops:**

```dart
final allShops = await LocalDB.instance.getAllShops();
// Les shops téléchargés incluent:
// - Nouveaux shops créés par l'admin
// - Shops modifiés (designation, localisation, capital)
// - Shops avec capital ajusté
// - (Shops supprimés si API implémentée)
```

### **Détection des Changements**

Les agents détectent les changements via:

1. **`last_modified_at`** - Timestamp de dernière modification
2. **`is_synced`** - Flag de synchronisation
3. **`synced_at`** - Date de dernière sync

**Exemple:**

```sql
-- L'agent télécharge tous les shops modifiés après sa dernière sync
SELECT * FROM shops 
WHERE last_modified_at > :last_sync_time
ORDER BY last_modified_at DESC
```

---

## 🚨 Problèmes Critiques Identifiés

### ❌ **CRITIQUE 1:** Suppression non synchronisée

**Impact:** Les shops supprimés réapparaissent après sync!

**Solution:** Implémenter `server/api/shops/delete.php` avec soft delete

---

### ⚠️ **CRITIQUE 2:** Pas d'API update.php

**Impact:** Le code attend un endpoint qui n'existe pas!

**Code affecté:** `lib/services/shop_service.dart` ligne 190

```dart
final url = Uri.parse('$baseUrl/shops/update.php');  // ← N'existe pas!
```

**Solution:** Créer l'endpoint ou utiliser le SyncManager existant

---

### ⚠️ **CRITIQUE 3:** Pas de notification en temps réel

**Impact:** Les agents doivent attendre 1-5 minutes pour voir les changements

**Solution:** Implémenter un système de notifications ou réduire l'intervalle de sync

---

## ✅ Recommandations

### **Court Terme (1-2 jours)**

1. ✅ **Créer `server/api/shops/delete.php`** pour la suppression sécurisée
2. ✅ **Créer `server/api/shops/update.php`** pour la modification directe
3. ✅ **Ajouter audit trail** pour les modifications et suppressions

### **Moyen Terme (1 semaine)**

4. ✅ **Implémenter soft delete** (is_active = 0) au lieu de hard delete
5. ✅ **Ajouter liste des agents affectés** dans les réponses API
6. ✅ **Créer page admin "Audit des Shops"** pour voir l'historique complet

### **Long Terme (1 mois)**

7. ✅ **Notification push** pour changements critiques
8. ✅ **Système de versioning** pour les shops
9. ✅ **Rollback capability** pour annuler des changements

---

## 📞 Conclusion

**Réponse à votre question:**

✅ **Modification Shop:** API partielle (via SyncManager), agents voient au prochain sync  
✅ **Ajustement Capital:** API complète avec audit trail, agents voient au prochain sync  
❌ **Suppression Shop:** PAS d'API, suppression locale uniquement, **DANGEREUX!**

**Les agents PEUVENT voir les modifications et ajustements**, mais:
- ⏱️ Délai de 1-5 minutes (intervalle de sync)
- ❌ Pas de notification push
- ❌ Suppression non fonctionnelle

**Action requise:** Implémenter les 3 APIs manquantes pour un système complet et sécurisé!
