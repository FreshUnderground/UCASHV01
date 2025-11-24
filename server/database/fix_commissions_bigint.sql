-- ============================================================================
-- FIX: Convertir TOUS les IDs en BIGINT pour supporter les timestamps
-- Problème: Les IDs générés par l'app (timestamps) dépassent INT max (2147483647)
-- Solution: Utiliser BIGINT qui supporte jusqu'à 9223372036854775807
-- ============================================================================

-- Désactiver temporairement les contraintes de clés étrangères
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- ÉTAPE 1: Modifier TOUTES les colonnes ID en BIGINT
-- ============================================================================

-- TABLE: shops
ALTER TABLE shops MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT;
SELECT '✅ shops.id → BIGINT' AS status;

-- TABLE: agents
ALTER TABLE agents 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL;
SELECT '✅ agents (id, shop_id) → BIGINT' AS status;

-- TABLE: clients
ALTER TABLE clients 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL;
SELECT '✅ clients (id, shop_id) → BIGINT' AS status;

-- TABLE: operations
ALTER TABLE operations 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_source_id BIGINT NULL,
  MODIFY COLUMN shop_destination_id BIGINT NULL,
  MODIFY COLUMN agent_id BIGINT NULL,
  MODIFY COLUMN client_id BIGINT NULL;
SELECT '✅ operations (id, shop_source_id, shop_destination_id, agent_id, client_id) → BIGINT' AS status;

-- TABLE: taux
ALTER TABLE taux MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT;
SELECT '✅ taux.id → BIGINT' AS status;

-- TABLE: commissions
ALTER TABLE commissions 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL,
  MODIFY COLUMN shop_source_id BIGINT NULL,
  MODIFY COLUMN shop_destination_id BIGINT NULL;
SELECT '✅ commissions (id, shop_id, shop_source_id, shop_destination_id) → BIGINT' AS status;

-- TABLE: journal_caisse
ALTER TABLE journal_caisse 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL,
  MODIFY COLUMN agent_id BIGINT NULL,
  MODIFY COLUMN operation_id BIGINT NULL;
SELECT '✅ journal_caisse (id, shop_id, agent_id, operation_id) → BIGINT' AS status;

-- TABLE: flots (si elle existe)
ALTER TABLE flots 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_source_id BIGINT NULL,
  MODIFY COLUMN shop_destination_id BIGINT NULL,
  MODIFY COLUMN agent_id BIGINT NULL;
SELECT '✅ flots (id, shop_source_id, shop_destination_id, agent_id) → BIGINT' AS status;

-- TABLE: cloture_caisse (si elle existe)
ALTER TABLE cloture_caisse 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL;
SELECT '✅ cloture_caisse (id, shop_id) → BIGINT' AS status;

-- TABLE: comptes_speciaux (si elle existe)
ALTER TABLE comptes_speciaux 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT,
  MODIFY COLUMN shop_id BIGINT NULL,
  MODIFY COLUMN operation_id BIGINT NULL,
  MODIFY COLUMN agent_id BIGINT NULL;
SELECT '✅ comptes_speciaux (id, shop_id, operation_id, agent_id) → BIGINT' AS status;

-- TABLE: document_headers (si elle existe)
ALTER TABLE document_headers 
  MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT;
SELECT '✅ document_headers.id → BIGINT' AS status;

-- Réactiver les contraintes de clés étrangères
SET FOREIGN_KEY_CHECKS = 1;

SELECT '🎉 CONVERSION TERMINÉE - Tous les IDs sont maintenant en BIGINT!' AS final_status;
SELECT 'Vous pouvez maintenant créer des entités avec des IDs > 2147483647' AS info;
