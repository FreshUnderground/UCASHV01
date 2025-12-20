-- Migration pour créer la table multi_month_payments
-- Date: 2024-12-20
-- Description: Table pour gérer les paiements multi-mois

CREATE TABLE IF NOT EXISTS `multi_month_payments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reference` varchar(50) NOT NULL UNIQUE COMMENT 'Référence unique du paiement multi-mois',
  `service_type` varchar(100) NOT NULL COMMENT 'Type de service (abonnement, loyer, etc.)',
  `service_description` text COMMENT 'Description détaillée du service',
  `montant_mensuel` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant mensuel unitaire',
  `nombre_mois` int(11) NOT NULL DEFAULT 1 COMMENT 'Nombre de mois payés',
  `montant_total` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant total calculé',
  `devise` varchar(10) NOT NULL DEFAULT 'USD' COMMENT 'Devise du paiement',
  
  -- Bonus et heures supplémentaires
  `bonus` decimal(15,2) DEFAULT 0.00 COMMENT 'Bonus à ajouter',
  `heures_supplementaires` decimal(10,2) DEFAULT 0.00 COMMENT 'Heures supplémentaires',
  `taux_horaire_supp` decimal(10,2) DEFAULT 0.00 COMMENT 'Taux horaire pour les heures supplémentaires',
  `montant_heures_supp` decimal(15,2) DEFAULT 0.00 COMMENT 'Montant calculé des heures supplémentaires',
  `montant_final_avec_ajustements` decimal(15,2) DEFAULT 0.00 COMMENT 'Montant final avec bonus et heures supp',
  
  -- Période couverte
  `date_debut` date NOT NULL COMMENT 'Premier mois couvert',
  `date_fin` date NOT NULL COMMENT 'Dernier mois couvert',
  
  -- Informations client/bénéficiaire
  `client_id` int(11) DEFAULT NULL COMMENT 'ID du client',
  `client_nom` varchar(255) DEFAULT NULL COMMENT 'Nom du client',
  `client_telephone` varchar(20) DEFAULT NULL COMMENT 'Téléphone du client',
  `numero_compte` varchar(100) DEFAULT NULL COMMENT 'Numéro de compte/contrat du service',
  
  -- Informations shops et agent
  `shop_id` int(11) NOT NULL COMMENT 'ID du shop',
  `shop_designation` varchar(255) DEFAULT NULL COMMENT 'Désignation du shop',
  `agent_id` int(11) NOT NULL COMMENT 'ID de l\'agent',
  `agent_username` varchar(100) DEFAULT NULL COMMENT 'Username de l\'agent',
  
  -- Détails de l'opération
  `destinataire` varchar(255) DEFAULT NULL COMMENT 'Nom du fournisseur de service',
  `telephone_destinataire` varchar(20) DEFAULT NULL COMMENT 'Téléphone du destinataire',
  `notes` text DEFAULT NULL COMMENT 'Notes additionnelles',
  `statut` enum('enAttente','validee','annulee') NOT NULL DEFAULT 'enAttente' COMMENT 'Statut du paiement',
  
  -- Dates et tracking
  `date_creation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date de création',
  `date_validation` datetime DEFAULT NULL COMMENT 'Date de validation',
  `last_modified_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification',
  `last_modified_by` varchar(100) DEFAULT NULL COMMENT 'Modifié par',
  `is_synced` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Synchronisé avec le serveur',
  `synced_at` datetime DEFAULT NULL COMMENT 'Date de synchronisation',
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_reference` (`reference`),
  KEY `idx_shop_id` (`shop_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_client_id` (`client_id`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_creation` (`date_creation`),
  KEY `idx_date_validation` (`date_validation`),
  KEY `idx_sync` (`is_synced`, `synced_at`),
  KEY `idx_last_modified` (`last_modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table des paiements multi-mois';

-- Index composites pour optimiser les requêtes
CREATE INDEX `idx_shop_statut_date` ON `multi_month_payments` (`shop_id`, `statut`, `date_creation`);
CREATE INDEX `idx_agent_date` ON `multi_month_payments` (`agent_id`, `date_creation`);
CREATE INDEX `idx_client_service` ON `multi_month_payments` (`client_id`, `service_type`);
CREATE INDEX `idx_sync_modified` ON `multi_month_payments` (`is_synced`, `last_modified_at`);

-- Contraintes de clés étrangères (optionnelles, selon votre structure)
-- ALTER TABLE `multi_month_payments` ADD CONSTRAINT `fk_multi_month_payments_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
-- ALTER TABLE `multi_month_payments` ADD CONSTRAINT `fk_multi_month_payments_agent` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
-- ALTER TABLE `multi_month_payments` ADD CONSTRAINT `fk_multi_month_payments_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
