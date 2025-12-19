# Migration: Ajout des désignations de shops dans la table FLOTs

## Objectif
Ajouter les colonnes `shop_source_designation` et `shop_destination_designation` à la table `flots` pour stocker directement les noms des shops et éviter les jointures SQL lors de l'affichage.

## Comment exécuter la migration

### Option 1: Via le navigateur (Recommandé)
1. Ouvrez votre navigateur
2. Naviguez vers: `https://mahanaim.investee-group.com/server/database/migrate_flots_designations.php`
3. Suivez les instructions à l'écran

### Option 2: Via MySQL Client
```bash
mysql -u root -p ucash_db < server/database/migrations/add_shop_designations_to_flots.sql
```

### Option 3: Via phpMyAdmin
1. Connectez-vous à phpMyAdmin
2. Sélectionnez la base de données `ucash_db`
3. Allez dans l'onglet "SQL"
4. Copiez-collez le contenu de `server/database/migrations/add_shop_designations_to_flots.sql`
5. Cliquez sur "Exécuter"

## Changements appliqués

### Nouvelles colonnes
- `shop_source_designation` VARCHAR(255) - Nom du shop source
- `shop_destination_designation` VARCHAR(255) - Nom du shop destination

### Index créés
- `idx_shop_source_designation` - Pour recherches rapides
- `idx_shop_destination_designation` - Pour recherches rapides

### Mise à jour des données
Les FLOTs existants sont automatiquement mis à jour avec les désignations des shops correspondants.

## Vérification
Après la migration, vous pouvez vérifier que tout fonctionne:

```sql
SELECT 
    id, 
    shop_source_designation, 
    shop_destination_designation, 
    montant, 
    statut 
FROM flots 
LIMIT 10;
```

## Impact
- ✅ Les synchronisations de FLOTs incluent maintenant les noms des shops
- ✅ Pas besoin de jointures pour afficher les noms de shops
- ✅ Meilleures performances d'affichage
- ✅ Compatibilité avec l'application Flutter maintenue
