-- Migration pour corriger la table flots
-- À exécuter dans phpMyAdmin ou MySQL CLI

-- 1. Modifier la colonne id pour supporter les grands nombres (timestamp-based IDs)
ALTER TABLE flots MODIFY COLUMN id BIGINT(20) NOT NULL AUTO_INCREMENT;

-- 2. Ajouter les colonnes manquantes si elles n'existent pas
ALTER TABLE flots 
  ADD COLUMN IF NOT EXISTS shop_source_designation VARCHAR(255) DEFAULT NULL AFTER shop_source_id;

ALTER TABLE flots 
  ADD COLUMN IF NOT EXISTS shop_destination_designation VARCHAR(255) DEFAULT NULL AFTER shop_destination_id;

ALTER TABLE flots 
  ADD COLUMN IF NOT EXISTS agent_envoyeur_username VARCHAR(100) DEFAULT NULL AFTER agent_envoyeur_id;

ALTER TABLE flots 
  ADD COLUMN IF NOT EXISTS agent_recepteur_username VARCHAR(100) DEFAULT NULL AFTER agent_recepteur_id;

-- 3. Supprimer les FLOTs avec ID max si présents (INT overflow)
DELETE FROM flots WHERE id = 2147483647;
DELETE FROM flots WHERE id >= 2147483640;

-- 4. Vérifier la structure finale
DESCRIBE flots;

-- 5. Afficher les FLOTs restants
SELECT id, shop_source_id, shop_destination_id, montant, statut, is_synced, synced_at 
FROM flots 
ORDER BY id DESC 
LIMIT 10;
