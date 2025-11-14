-- Migration: Ajouter les champs destinataire, telephone_destinataire et client_nom à operations
-- Date: 2025-11-10
-- Description: Ajouter les informations du bénéficiaire pour les transferts et le nom du client

-- Ajouter destinataire après notes
ALTER TABLE operations 
ADD COLUMN destinataire VARCHAR(100) DEFAULT NULL AFTER notes;

-- Ajouter telephone_destinataire après destinataire
ALTER TABLE operations 
ADD COLUMN telephone_destinataire VARCHAR(20) DEFAULT NULL AFTER destinataire;

-- Ajouter client_nom après client_id (si pas déjà fait)
ALTER TABLE operations 
ADD COLUMN client_nom VARCHAR(255) DEFAULT NULL AFTER client_id;

-- Ajouter un index pour rechercher par nom de destinataire
ALTER TABLE operations 
ADD INDEX idx_destinataire (destinataire);

-- Ajouter un index pour rechercher par nom de client
ALTER TABLE operations 
ADD INDEX idx_client_nom (client_nom);

-- Remplir les noms de clients existants depuis la table clients
UPDATE operations o
INNER JOIN clients c ON o.client_id = c.id
SET o.client_nom = c.nom
WHERE o.client_id IS NOT NULL AND o.client_nom IS NULL;

-- Vérifier le résultat
SELECT COUNT(*) as total_operations,
       COUNT(destinataire) as operations_avec_destinataire,
       COUNT(client_nom) as operations_avec_client_nom
FROM operations;

-- Afficher quelques exemples
SELECT id, type, client_nom, destinataire, telephone_destinataire, montant_brut, created_at 
FROM operations 
LIMIT 5;
