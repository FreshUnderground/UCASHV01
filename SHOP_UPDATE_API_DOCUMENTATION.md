# 🔄 API de Mise à Jour des Shops avec Notification aux Agents

## 📋 Vue d'Ensemble

Cette fonctionnalité permet de mettre à jour un shop existant via une API dédiée qui:
1. ✅ Met à jour les informations du shop sur le serveur
2. ✅ Identifie tous les agents associés à ce shop
3. ✅ Marque la modification avec un timestamp pour forcer la resynchronisation
4. ✅ Retourne la liste des agents affectés

## 🎯 Cas d'Usage

### Scénario Typique:
1. Un **administrateur** modifie le nom ou la localisation d'un shop
2. Le shop est mis à jour sur le serveur
3. Tous les **agents** de ce shop verront la modification lors de leur prochaine synchronisation
4. Les données du shop sont **automatiquement mises à jour** sur leur poste

---

## 🛠️ Fichiers Créés/Modifiés

### 📁 Serveur (PHP)

#### 1. **`server/api/sync/shops/update.php`** (NOUVEAU)
Endpoint dédié pour la mise à jour de shops.

**URL:** `POST /api/sync/shops/update.php`

**Payload:**
```json
{
  "shop_id": 123,
  "designation": "Nouveau Nom Shop",
  "localisation": "Nouvelle Localisation",
  "capital_initial": 10000.0,
  "devise_principale": "USD",
  "devise_secondaire": "CDF",
  "capital_actuel": 10000.0,
  "capital_cash": 5000.0,
  "capital_airtel_money": 0.0,
  "capital_mpesa": 0.0,
  "capital_orange_money": 0.0,
  "user_id": "admin",
  "timestamp": "2025-12-11T10:00:00Z"
}
```

**Réponse (Succès):**
```json
{
  "success": true,
  "message": "Shop mis à jour avec succès",
  "shop": {
    "id": 123,
    "designation": "Nouveau Nom Shop",
    "old_designation": "Ancien Nom",
    "localisation": "Nouvelle Localisation"
  },
  "affected_agents": {
    "count": 3,
    "agents": [
      {
        "id": 45,
        "username": "agent001",
        "nom": "Jean Dupont"
      },
      {
        "id": 46,
        "username": "agent002",
        "nom": "Marie Martin"
      }
    ]
  },
  "notification": {
    "type": "SHOP_UPDATED",
    "message": "Les agents du shop devront resynchroniser leurs données"
  },
  "timestamp": "2025-12-11T10:00:01Z"
}
```

**Réponse (Erreur):**
```json
{
  "success": false,
  "message": "Shop avec ID 999 introuvable",
  "timestamp": "2025-12-11T10:00:01Z"
}
```

#### 2. **`server/api/sync/shops/test_update.php`** (NOUVEAU)
Script de test automatisé pour valider l'endpoint.

**Usage:**
```bash
# Via navigateur:
http://localhost/UCASHV01/server/api/sync/shops/test_update.php

# Via CLI:
php server/api/sync/shops/test_update.php
```

**Sortie:**
```
=== TEST MISE À JOUR SHOP ===

📊 Étape 1: Recherche d'un shop existant...
✅ Shop trouvé:
   - ID: 1
   - Designation: Shop Principal
   - Localisation: Butembo Centre
   - Capital actuel: 10000 USD

📤 Étape 2: Envoi de la requête de mise à jour...
   Nouveau nom: Shop Principal (MODIFIÉ)
   Nouvelle localisation: Butembo - Test Zone
   Nouveau capital: 15000 USD

🚀 Étape 3: Exécution de la requête...
📊 Code HTTP: 200

📄 Étape 4: Réponse du serveur:
----------------------------------------
{
    "success": true,
    "message": "Shop mis à jour avec succès",
    ...
}
----------------------------------------

✅ Mise à jour réussie!

👥 Agents affectés: 2
   - Jean Dupont (agent001)
   - Marie Martin (agent002)

🔍 Étape 5: Vérification dans la base de données...
📊 Shop après mise à jour:
   - ID: 1
   - Designation: Shop Principal (MODIFIÉ)
   - Localisation: Butembo - Test Zone
   - Capital: 15000 USD
   - Dernière modification: 2025-12-11 10:00:01

✅ Designation mise à jour correctement
✅ Localisation mise à jour correctement
✅ Capital mis à jour correctement

=== FIN DU TEST ===
```

---

### 📱 Client Flutter

#### 1. **`lib/services/shop_service.dart`** (MODIFIÉ)

**Nouvelle Méthode Ajoutée:**

```dart
/// Met à jour un shop directement via l'API serveur (nouveau endpoint dédié)
/// Utilisé par les admins pour modifier un shop et notifier tous les agents
Future<Map<String, dynamic>?> updateShopViaAPI(
  ShopModel shop, 
  {String userId = 'admin'}
) async {
  // ...implementation
}
```

**Usage dans l'Interface:**

```dart
// Depuis un widget admin (ex: EditShopDialog)
final shopService = ShopService.instance;

// Option 1: Mise à jour locale + sync en arrière-plan (mode normal)
await shopService.updateShop(updatedShop);

// Option 2: Mise à jour immédiate via API + notification agents (mode admin)
final result = await shopService.updateShopViaAPI(
  updatedShop, 
  userId: 'admin_username'
);

if (result != null && result['success'] == true) {
  // Afficher le nombre d'agents affectés
  final agentsCount = result['affected_agents']['count'];
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Shop modifié avec succès! $agentsCount agents seront notifiés.'
      ),
      backgroundColor: Colors.green,
    ),
  );
} else {
  // Erreur
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Erreur lors de la mise à jour du shop'),
      backgroundColor: Colors.red,
    ),
  );
}
```

**Imports Ajoutés:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
```

---

## 🔄 Flux de Synchronisation

### 📤 Depuis l'Admin (Modification du Shop)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ADMIN modifie le shop via EditShopDialog                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. ShopService.updateShopViaAPI() appelé                   │
│    - POST vers /api/sync/shops/update.php                  │
│    - Payload: toutes les données du shop                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. SERVEUR traite la requête                               │
│    - Vérifie que le shop existe                            │
│    - Met à jour la table shops                             │
│    - Marque is_synced = 1, synced_at = NOW()              │
│    - Met à jour last_modified_at = NOW()                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. SERVEUR identifie les agents affectés                   │
│    SELECT * FROM agents WHERE shop_id = X AND is_active=1  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. SERVEUR renvoie la réponse                              │
│    - success: true                                          │
│    - shop: {...}                                            │
│    - affected_agents: [...]                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. ADMIN reçoit confirmation                                │
│    - Shop mis à jour localement (is_synced = true)         │
│    - Affichage: "X agents seront notifiés"                 │
└─────────────────────────────────────────────────────────────┘
```

### 📥 Côté Agent (Réception de la Modification)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. AGENT se connecte ou lance une sync manuelle            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. SyncService.downloadTableData('shops')                  │
│    - GET /api/sync/shops/changes.php?since=XXX             │
│    - Le shop modifié a last_modified_at > since            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. SERVEUR retourne le shop modifié                        │
│    - Incluant les nouvelles données                        │
│    - is_synced = true, synced_at récent                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. AGENT sauvegarde localement                             │
│    - LocalDB.updateShop(shopModifié)                       │
│    - ShopService met à jour le cache                       │
│    - notifyListeners() → UI se rafraîchit                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Interface de l'AGENT affiche les nouvelles données      │
│    - Nouveau nom du shop                                    │
│    - Nouvelle localisation                                  │
│    - Capitaux mis à jour                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧪 Tests

### Test 1: Modification Basique via API

```dart
// Test unitaire Flutter
void main() {
  test('Update shop via API should succeed', () async {
    final shopService = ShopService.instance;
    
    // Créer un shop de test
    final testShop = ShopModel(
      id: 123,
      designation: 'Test Shop',
      localisation: 'Test Location',
      capitalInitial: 10000.0,
      capitalActuel: 10000.0,
      capitalCash: 10000.0,
      capitalAirtelMoney: 0.0,
      capitalMPesa: 0.0,
      capitalOrangeMoney: 0.0,
    );
    
    // Modifier le shop
    final modifiedShop = testShop.copyWith(
      designation: 'Test Shop MODIFIÉ',
      localisation: 'New Location',
    );
    
    // Appeler l'API
    final result = await shopService.updateShopViaAPI(modifiedShop);
    
    // Vérifications
    expect(result, isNotNull);
    expect(result['success'], true);
    expect(result['shop']['designation'], 'Test Shop MODIFIÉ');
  });
}
```

### Test 2: Vérification des Agents Affectés

```php
// Test PHP
$updateData = [
    'shop_id' => 1,
    'designation' => 'Shop Test',
    'user_id' => 'test_admin',
];

$response = callAPI('/api/sync/shops/update.php', $updateData);

assert($response['success'] === true);
assert(isset($response['affected_agents']));
assert($response['affected_agents']['count'] >= 0);
```

### Test 3: Synchronisation Agent après Modification

1. Admin modifie le shop ID 1
2. Agent de ce shop se synchronise
3. Vérifier que l'agent reçoit les nouvelles données
4. Vérifier que l'interface de l'agent affiche le nouveau nom

---

## 📊 Base de Données

### Champs Importants pour la Synchronisation

```sql
-- Table shops
CREATE TABLE shops (
    id INT PRIMARY KEY,
    designation VARCHAR(255),
    localisation VARCHAR(255),
    -- ... autres champs ...
    
    -- CRITIQUES pour la synchronisation:
    last_modified_at TIMESTAMP,  -- Mis à jour à chaque modification
    last_modified_by VARCHAR(100), -- Qui a modifié
    is_synced BOOLEAN,            -- Toujours true côté serveur
    synced_at TIMESTAMP           -- Quand la sync a eu lieu
);

-- Table agents
CREATE TABLE agents (
    id INT PRIMARY KEY,
    username VARCHAR(100),
    nom VARCHAR(255),
    shop_id INT,  -- ⭐ Clé pour identifier les agents affectés
    is_active BOOLEAN,
    -- ...
    FOREIGN KEY (shop_id) REFERENCES shops(id)
);
```

### Requêtes Utilisées

```sql
-- 1. Vérifier l'existence du shop
SELECT id, designation FROM shops WHERE id = ?;

-- 2. Mettre à jour le shop
UPDATE shops SET 
    designation = ?,
    localisation = ?,
    -- ... autres champs ...
    last_modified_at = ?,
    last_modified_by = ?
WHERE id = ?;

-- 3. Identifier les agents affectés
SELECT id, username, nom 
FROM agents 
WHERE shop_id = ? AND is_active = 1;

-- 4. Download côté agent (récupère shops modifiés)
SELECT * FROM shops 
WHERE last_modified_at > ?
ORDER BY last_modified_at DESC;
```

---

## ⚙️ Configuration

### URL de l'API

L'URL de base est configurée dans `app_config.dart`:

```dart
static Future<String> getSyncBaseUrl() async {
  // Retourne: http://localhost/UCASHV01/server/api/sync
  // En production: https://votre-domaine.com/api/sync
}
```

### Timeout

Le timeout par défaut est de **15 secondes** pour les requêtes HTTP.

---

## 🚨 Gestion des Erreurs

### Erreurs Possibles

| Code | Message | Cause | Solution |
|------|---------|-------|----------|
| 405 | Méthode non autorisée | Utilisation de GET au lieu de POST | Utiliser POST |
| 500 | shop_id est requis | Payload manquant shop_id | Ajouter shop_id |
| 500 | Shop avec ID X introuvable | Shop n'existe pas | Vérifier l'ID |
| 500 | Échec mise à jour shop | Erreur SQL | Vérifier les données |

### Logs Serveur

Les logs sont enregistrés dans les error logs PHP:

```
Shop Update Request - Shop ID: 123, User: admin
Shop Updated Successfully - ID: 123, Affected Agents: 3
```

ou en cas d'erreur:

```
Shop Update Error: Shop avec ID 999 introuvable
```

---

## 📈 Prochaines Étapes

- [ ] Ajouter notification push en temps réel aux agents
- [ ] Implémenter un système de queue pour les modifications en batch
- [ ] Ajouter un historique des modifications de shops
- [ ] Créer un dashboard de monitoring des synchronisations

---

**Date de création:** 2025-12-11  
**Dernière mise à jour:** 2025-12-11  
**Version:** 1.0.0  
**Statut:** ✅ Opérationnel
