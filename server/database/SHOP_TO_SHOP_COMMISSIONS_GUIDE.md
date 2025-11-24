# Guide des Commissions Shop-to-Shop

## Description
Ce guide explique comment fonctionne le nouveau système de commissions basé sur les routes entre shops. Chaque commission est désormais définie par une paire (shop source, shop destination) plutôt que par un seul shop.

## Structure de la Base de Données

### Nouvelles Colonnes dans la Table `commissions`
- `source_shop_id`: ID du shop source (obligatoire)
- `destination_shop_id`: ID du shop destination (optionnel)

### Index Ajoutés
- `idx_source_shop`: Pour rechercher rapidement par shop source
- `idx_destination_shop`: Pour rechercher rapidement par shop destination
- `idx_source_dest_commission`: Pour rechercher par paire (source, destination, type)
- `idx_source_commission`: Pour rechercher par (source, type)

## Hiérarchie des Commissions

Le système utilise une hiérarchie de priorité pour déterminer quelle commission appliquer :

1. **Commission spécifique route**: (source_shop_id, destination_shop_id) - Priorité la plus élevée
2. **Commission source uniquement**: (source_shop_id, destination_shop_id=NULL) - Priorité moyenne
3. **Commission globale**: (source_shop_id=NULL, destination_shop_id=NULL) - Priorité la plus basse

## Exemples d'Utilisation

### Création d'une Commission Spécifique Route
```sql
INSERT INTO commissions (
    source_shop_id, 
    destination_shop_id, 
    type, 
    taux, 
    description
) VALUES (
    1,  -- Shop BUTEMBO (source)
    2,  -- Shop KAMPALA (destination)
    'SORTANT',
    1.0,  -- 1%
    'Commission transfert BUTEMBO vers KAMPALA'
);
```

### Création d'une Commission Source Uniquement
```sql
INSERT INTO commissions (
    source_shop_id, 
    destination_shop_id, 
    type, 
    taux, 
    description
) VALUES (
    1,   -- Shop BUTEMBO (source)
    NULL, -- Toutes destinations
    'SORTANT',
    1.5,  -- 1.5%
    'Commission sortante par défaut pour BUTEMBO'
);
```

## API de Synchronisation

### Format des Données
Les APIs de synchronisation ont été mises à jour pour inclure :
- `sourceShopId`: ID du shop source
- `destinationShopId`: ID du shop destination

### Exemple de Données JSON
```json
{
  "entities": [
    {
      "id": 1,
      "sourceShopId": 1,
      "destinationShopId": 2,
      "type": "SORTANT",
      "taux": 1.0,
      "description": "Commission transfert BUTEMBO vers KAMPALA",
      "isActive": true,
      "createdAt": "2023-01-01T00:00:00Z",
      "lastModifiedAt": "2023-01-01T00:00:00Z"
    }
  ]
}
```

## Migration

Pour migrer votre base de données existante :

1. Exécutez le script de migration :
   ```bash
   php server/database/run_update_commissions_shop_to_shop.php
   ```

2. Le script mettra automatiquement à jour :
   - La structure de la table `commissions`
   - Les index et contraintes
   - Les enregistrements existants (shop_id → source_shop_id)

## Utilisation dans l'Application Mobile

Dans l'application Flutter, le système sélectionne automatiquement :
- **Shop source**: Basé sur le shop de l'utilisateur connecté
- **Shop destination**: Sélectionné par l'utilisateur lors du transfert

La commission est alors déterminée en recherchant dans l'ordre :
1. Commission spécifique (source, destination)
2. Commission par source uniquement
3. Commission globale par défaut

## Exemple de Cas d'Utilisation

Pour un utilisateur du shop BUTEMBO (ID=1) effectuant un transfert vers KAMPALA (ID=2) :
1. Le système recherche une commission avec source=1 et destination=2
2. Si non trouvée, il cherche une commission avec source=1 et destination=NULL
3. Si toujours non trouvée, il utilise la commission globale

Cela permet de configurer des commissions comme :
- (BUTEMBO - KAMPALA) : 1%
- (BUTEMBO - KINDU) : 1.5%
- Commission par défaut pour BUTEMBO : 2%

## Administration

L'administrateur peut créer des commissions via l'interface en sélectionnant :
1. Le shop source
2. Le shop destination (optionnel)
3. Le type de commission (SORTANT/ENTRANT)
4. Le taux
5. Une description

Cette approche permet une gestion fine des commissions selon les routes commerciales.