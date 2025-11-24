-- Migration: Ajouter shop_source_designation et shop_destination_designation à la table flots
-- Date: 2025-11-20
-- Description: Ajouter les colonnes manquantes pour la désignation des shops

USE ucash_db;

-- Ajouter shop_source_designation après shop_source_id
ALTER TABLE flots 
ADD COLUMN shop_source_designation VARCHAR(100) NOT NULL DEFAULT '' AFTER shop_source_id;

-- Ajouter shop_destination_designation après shop_destination_id
ALTER TABLE flots 
ADD COLUMN shop_destination_designation VARCHAR(100) NOT NULL DEFAULT '' AFTER shop_destination_id;

-- Mettre à jour les valeurs existantes en récupérant les désignations depuis la table shops
UPDATE flots f
INNER JOIN shops s ON f.shop_source_id = s.id
SET f.shop_source_designation = s.designation
WHERE f.shop_source_designation = '';

UPDATE flots f
INNER JOIN shops s ON f.shop_destination_id = s.id
SET f.shop_destination_designation = s.designation
WHERE f.shop_destination_designation = '';

-- Vérifier le résultat
SELECT 
    COUNT(*) as total_flots,
    COUNT(CASE WHEN shop_source_designation != '' THEN 1 END) as avec_source_designation,
    COUNT(CASE WHEN shop_destination_designation != '' THEN 1 END) as avec_destination_designation
FROM flots;

-- Afficher quelques exemples
SELECT id, shop_source_id, shop_source_designation, shop_destination_id, shop_destination_designation, montant, devise
FROM flots 
LIMIT 5;
