-- Migration: Ajouter client_nom à la table operations
-- Date: 2025-11-10
-- Description: Ajouter la colonne client_nom pour la résolution des clients par nom au lieu de ID timestamp

-- Ajouter la colonne client_nom après client_id
ALTER TABLE operations 
ADD COLUMN client_nom VARCHAR(255) DEFAULT NULL AFTER client_id;

-- Ajouter un index pour améliorer les performances de recherche
ALTER TABLE operations 
ADD INDEX idx_client_nom (client_nom);

-- Mettre à jour les valeurs existantes avec les noms des clients
UPDATE operations o
INNER JOIN clients c ON o.client_id = c.id
SET o.client_nom = c.nom
WHERE o.client_id IS NOT NULL;

-- Vérifier le résultat
SELECT COUNT(*) as total_operations, 
       COUNT(client_nom) as operations_avec_nom,
       COUNT(client_id) as operations_avec_client_id
FROM operations;

-- Afficher quelques exemples
SELECT id, client_id, client_nom, type, montant_brut, created_at 
FROM operations 
WHERE client_id IS NOT NULL 
LIMIT 5;
