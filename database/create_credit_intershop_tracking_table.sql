-- ===============================================
-- Table de Suivi des Crédits Inter-Shop (Consolidation)
-- ===============================================
-- 
-- OBJECTIF:
-- Suivre les dettes internes entre shops normaux et le shop principal
-- pour permettre la consolidation des dettes au niveau du shop principal.
--
-- LOGIQUE MÉTIER:
-- - Shop Principal (Durba): Gère tous les flots de cash
-- - Shop Service (Kampala): Service par défaut des transferts
-- - Shops Normaux (C, D, E, F): Initient des transferts
--
-- FLUX:
-- Client au Shop C → Transfert → Servi au Shop Kampala
-- 
-- DETTES CRÉÉES:
-- 1. EXTERNE: Durba doit à Kampala (montant brut)
-- 2. INTERNE: Shop C doit à Durba (montant brut)
--
-- RÉSULTAT:
-- - Kampala ne voit que la dette consolidée de Durba
-- - Durba gère les dettes internes des shops normaux
-- ===============================================

CREATE TABLE IF NOT EXISTS credit_intershop_tracking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Shop Principal (toujours Durba dans votre cas)
    shop_principal_id INT NOT NULL COMMENT 'Shop principal qui gère les flots (ex: Durba)',
    shop_principal_designation VARCHAR(255) DEFAULT NULL,
    
    -- Shop Normal qui a initié le transfert (C, D, E, ou F)
    shop_normal_id INT NOT NULL COMMENT 'Shop normal qui doit au shop principal',
    shop_normal_designation VARCHAR(255) DEFAULT NULL,
    
    -- Shop Service qui a servi le transfert (toujours Kampala dans votre cas)
    shop_service_id INT NOT NULL COMMENT 'Shop de service qui a servi le transfert (ex: Kampala)',
    shop_service_designation VARCHAR(255) DEFAULT NULL,
    
    -- Montants du transfert
    montant_brut DECIMAL(15,2) NOT NULL COMMENT 'Montant total (net + commission)',
    montant_net DECIMAL(15,2) NOT NULL COMMENT 'Montant servi au bénéficiaire',
    commission DECIMAL(15,2) NOT NULL COMMENT 'Commission encaissée',
    devise VARCHAR(3) DEFAULT 'USD',
    
    -- Lien vers l'opération d'origine
    operation_id INT DEFAULT NULL COMMENT 'ID de l\'opération de transfert',
    operation_reference VARCHAR(50) DEFAULT NULL COMMENT 'Référence du transfert',
    
    -- Dates
    date_operation DATETIME NOT NULL COMMENT 'Date du transfert',
    date_consolidation DATETIME NOT NULL COMMENT 'Date de consolidation (fin de journée)',
    
    -- Tracking et synchronisation
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME DEFAULT NULL,
    last_modified_by VARCHAR(100) DEFAULT NULL,
    is_synced TINYINT(1) DEFAULT 0 COMMENT '0=Non synchronisé, 1=Synchronisé',
    synced_at DATETIME DEFAULT NULL,
    
    -- Index pour optimisation (Foreign keys removed to avoid constraint errors)
    INDEX idx_principal_normal (shop_principal_id, shop_normal_id),
    INDEX idx_principal_service (shop_principal_id, shop_service_id),
    INDEX idx_normal_service (shop_normal_id, shop_service_id),
    INDEX idx_date_operation (date_operation),
    INDEX idx_date_consolidation (date_consolidation),
    INDEX idx_sync (is_synced, synced_at),
    INDEX idx_operation (operation_id)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Suivi des crédits inter-shop pour consolidation au niveau du shop principal';

-- ===============================================
-- NOTE IMPORTANTE:
-- Les clés étrangères ont été retirées pour éviter les erreurs de contraintes.
-- Si vous souhaitez les ajouter manuellement après création, utilisez:
--
-- ALTER TABLE credit_intershop_tracking 
--   ADD CONSTRAINT fk_credit_shop_principal 
--   FOREIGN KEY (shop_principal_id) REFERENCES shops(id) ON DELETE CASCADE;
--
-- ALTER TABLE credit_intershop_tracking 
--   ADD CONSTRAINT fk_credit_shop_normal 
--   FOREIGN KEY (shop_normal_id) REFERENCES shops(id) ON DELETE CASCADE;
--
-- ALTER TABLE credit_intershop_tracking 
--   ADD CONSTRAINT fk_credit_shop_service 
--   FOREIGN KEY (shop_service_id) REFERENCES shops(id) ON DELETE CASCADE;
-- ===============================================

-- ===============================================
-- EXEMPLES D'UTILISATION
-- ===============================================

-- Exemple 1: Transfert de Shop C → Kampala (service)
-- Client au Shop C paie 100 USD + 3 USD frais
-- Kampala sert 100 USD au bénéficiaire
--
-- INSERT INTO credit_intershop_tracking (
--     shop_principal_id, shop_principal_designation,
--     shop_normal_id, shop_normal_designation,
--     shop_service_id, shop_service_designation,
--     montant_brut, montant_net, commission, devise,
--     operation_id, operation_reference,
--     date_operation, date_consolidation
-- ) VALUES (
--     1, 'DURBA',           -- Shop principal
--     3, 'SHOP C',          -- Shop normal (initiateur)
--     2, 'KAMPALA',         -- Shop service
--     103.00, 100.00, 3.00, 'USD',
--     12345, 'TRF-20260117-001',
--     NOW(), NOW()
-- );
--
-- RÉSULTAT:
-- - Kampala voit: Durba doit 103 USD
-- - Durba voit: Shop C doit 103 USD
-- - Shop C voit: Doit 103 USD à Durba

-- ===============================================
-- REQUÊTES UTILES
-- ===============================================

-- 1. Voir tous les crédits consolidés pour Durba (shop principal)
-- SELECT * FROM credit_intershop_tracking 
-- WHERE shop_principal_id = 1 
-- ORDER BY date_operation DESC;

-- 2. Total dû par chaque shop normal à Durba
-- SELECT 
--     shop_normal_designation,
--     SUM(montant_brut) as total_du,
--     COUNT(*) as nombre_transferts
-- FROM credit_intershop_tracking
-- WHERE shop_principal_id = 1
-- GROUP BY shop_normal_id, shop_normal_designation
-- ORDER BY total_du DESC;

-- 3. Total que Durba doit à Kampala (consolidé)
-- SELECT 
--     shop_service_designation,
--     SUM(montant_brut) as total_consolide,
--     COUNT(*) as nombre_transferts
-- FROM credit_intershop_tracking
-- WHERE shop_principal_id = 1
-- GROUP BY shop_service_id, shop_service_designation;

-- 4. Détail des crédits d'une période
-- SELECT 
--     date_operation,
--     shop_normal_designation,
--     shop_service_designation,
--     montant_brut,
--     commission,
--     operation_reference
-- FROM credit_intershop_tracking
-- WHERE shop_principal_id = 1
--   AND date_operation BETWEEN '2026-01-01' AND '2026-01-31'
-- ORDER BY date_operation DESC;

-- ===============================================
-- MAINTENANCE
-- ===============================================

-- Vérifier l'intégrité des données
-- SELECT COUNT(*) FROM credit_intershop_tracking WHERE shop_principal_id NOT IN (SELECT id FROM shops);
-- SELECT COUNT(*) FROM credit_intershop_tracking WHERE shop_normal_id NOT IN (SELECT id FROM shops);
-- SELECT COUNT(*) FROM credit_intershop_tracking WHERE shop_service_id NOT IN (SELECT id FROM shops);

-- Nettoyer les enregistrements non synchronisés de plus de 30 jours (optionnel)
-- DELETE FROM credit_intershop_tracking 
-- WHERE is_synced = 0 
--   AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- ===============================================
