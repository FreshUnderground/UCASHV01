-- ========================================
-- TABLE: deleted_operations_log (Journal des opérations supprimées)
-- ========================================
CREATE TABLE IF NOT EXISTS deleted_operations_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code_ops VARCHAR(50) NOT NULL,
    operation_type ENUM(
        'transfertNational',
        'transfertInternationalSortant',
        'transfertInternationalEntrant',
        'depot',
        'retrait',
        'virement',
        'retraitMobileMoney'
    ) NOT NULL,
    shop_source_id INT NULL,
    shop_destination_id INT NULL,
    date_suppression DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    raison_suppression TEXT NULL,
    deleted_by VARCHAR(50) NULL,
    
    INDEX idx_code_ops (code_ops),
    INDEX idx_date_suppression (date_suppression),
    INDEX idx_shop_source_id (shop_source_id),
    INDEX idx_shop_destination_id (shop_destination_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Trigger to automatically log deleted operations
DELIMITER $$

CREATE TRIGGER log_deleted_operations 
BEFORE DELETE ON operations
FOR EACH ROW
BEGIN
    INSERT INTO deleted_operations_log (
        code_ops,
        operation_type,
        shop_source_id,
        shop_destination_id,
        raison_suppression,
        deleted_by
    ) VALUES (
        OLD.code_ops,
        OLD.type,
        OLD.shop_source_id,
        OLD.shop_destination_id,
        'Supprimé via API delete.php',
        OLD.last_modified_by
    );
END$$

DELIMITER ;