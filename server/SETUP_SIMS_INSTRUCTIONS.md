# 🔧 Instructions d'installation - Tables SIMS et Virtual Transactions

## ❌ Problème Actuel

Les erreurs HTTP 500 lors de la synchronisation des SIMs et transactions virtuelles indiquent que **les tables n'existent pas dans la base de données du serveur de production**.

```
⚠️ Erreur HTTP sims: 500
⚠️ Erreur HTTP virtual_transactions: 500
```

## ✅ Solution

Vous devez exécuter le script d'initialisation sur votre serveur de production pour créer les tables nécessaires.

### Méthode 1: Via navigateur (RECOMMANDÉ)

1. **Créez un fichier temporaire** sur votre serveur:
   ```
   https://mahanaim.investee-group.com/server/run_init_sims.php
   ```

2. **Contenu du fichier `run_init_sims.php`**:
   ```php
   <?php
   // Script temporaire pour initialiser les tables SIMS
   // À SUPPRIMER après exécution!
   
   require_once __DIR__ . '/init_sims_virtual_transactions.php';
   ```

3. **Accédez au fichier dans votre navigateur**:
   ```
   https://mahanaim.investee-group.com/server/run_init_sims.php
   ```

4. **Vérifiez la sortie** - Vous devriez voir:
   ```
   ========================================
   INITIALISATION DES TABLES SIMS ET VIRTUAL_TRANSACTIONS
   ========================================
   
   📱 Vérification de la table SIMS...
   ✅ Table SIMS vérifiée/créée
      📊 Nombre de SIMs: 0
   
   💰 Vérification de la table VIRTUAL_TRANSACTIONS...
   ✅ Table VIRTUAL_TRANSACTIONS vérifiée/créée
      📊 Nombre de transactions virtuelles: 0
   
   📜 Vérification de la table SIM_MOVEMENTS...
   ✅ Table SIM_MOVEMENTS vérifiée/créée
      📊 Nombre de mouvements: 0
   
   ========================================
   ✅ INITIALISATION TERMINÉE AVEC SUCCÈS
   ========================================
   ```

5. **⚠️ IMPORTANT: Supprimez le fichier `run_init_sims.php` après exécution!**

### Méthode 2: Via SSH/Terminal (si vous avez accès SSH)

```bash
cd /path/to/your/server
php init_sims_virtual_transactions.php
```

### Méthode 3: Via phpMyAdmin

Si vous préférez créer manuellement les tables via phpMyAdmin:

1. Ouvrez phpMyAdmin sur votre serveur
2. Sélectionnez votre base de données
3. Allez dans l'onglet "SQL"
4. Copiez et exécutez les requêtes SQL du fichier `init_sims_virtual_transactions.php`

## 📋 Tables qui seront créées

### 1. **sims**
- Gestion des cartes SIM
- Colonnes: id, numero, operateur, shop_id, solde_initial, solde_actuel, statut, etc.

### 2. **virtual_transactions**
- Transactions de capture/retrait virtuels
- Colonnes: id, reference, montant_virtuel, frais, montant_cash, sim_numero, statut, etc.

### 3. **sim_movements**
- Historique des transferts de SIM entre shops
- Colonnes: id, sim_id, ancien_shop_id, nouveau_shop_id, date_movement, etc.

## 🔍 Vérification

Après l'exécution du script, testez la synchronisation dans l'application:

1. Rechargez l'application
2. Vérifiez les logs de synchronisation
3. Vous devriez voir:
   ```
   ✅ sims synchronisé
   ✅ virtual_transactions synchronisé
   ```

## 📞 Support

Si vous rencontrez des erreurs:
- Vérifiez les permissions du fichier PHP
- Vérifiez que le fichier `config/database.php` est correctement configuré
- Consultez les logs d'erreurs PHP de votre serveur
