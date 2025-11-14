-- Migration: Ajouter 'virement' au type ENUM de la table operations
-- Date: 2025-11-10
-- Description: Ajouter le type 'virement' pour supporter les virements internes entre comptes

-- Modifier la colonne type pour ajouter 'virement'
ALTER TABLE operations 
MODIFY COLUMN type ENUM('depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'virement') NOT NULL;

-- Vérifier la modification
SELECT COLUMN_NAME, COLUMN_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'operations' 
AND COLUMN_NAME = 'type';
