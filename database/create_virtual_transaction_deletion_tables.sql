-- Create virtual transaction deletion requests table
-- Same structure as deletion_requests but for virtual transactions
CREATE TABLE IF NOT EXISTS virtual_transaction_deletion_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(255) NOT NULL, -- Virtual transaction reference instead of code_ops
    virtual_transaction_id INT, -- ID of the virtual transaction
    transaction_type VARCHAR(100) NOT NULL, -- Type of virtual transaction
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    destinataire VARCHAR(255),
    expediteur VARCHAR(255),
    client_nom VARCHAR(255),
    
    -- Request information
    requested_by_admin_id INT NOT NULL,
    requested_by_admin_name VARCHAR(255) NOT NULL,
    request_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    
    -- Admin validation
    validated_by_admin_id INT NULL,
    validated_by_admin_name VARCHAR(255) NULL,
    validation_admin_date DATETIME NULL,
    
    -- Agent validation
    validated_by_agent_id INT NULL,
    validated_by_agent_name VARCHAR(255) NULL,
    validation_date DATETIME NULL,
    
    -- Status and tracking
    statut ENUM('en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee') NOT NULL DEFAULT 'en_attente',
    last_modified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(255),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Synchronization
    is_synced BOOLEAN NOT NULL DEFAULT FALSE,
    synced_at DATETIME NULL,
    
    INDEX idx_reference (reference),
    INDEX idx_virtual_transaction_id (virtual_transaction_id),
    INDEX idx_statut (statut),
    INDEX idx_requested_by_admin (requested_by_admin_id),
    INDEX idx_validated_by_admin (validated_by_admin_id),
    INDEX idx_validated_by_agent (validated_by_agent_id),
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_is_synced (is_synced)
);

-- Create virtual transactions corbeille (trash) table
-- Same structure as operations_corbeille but for virtual transactions
CREATE TABLE IF NOT EXISTS virtual_transactions_corbeille (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(255) NOT NULL, -- Original virtual transaction reference
    virtual_transaction_id INT, -- Original virtual transaction ID
    
    -- Original transaction data (preserved for restoration)
    montant_virtuel DECIMAL(15,2) NOT NULL,
    frais DECIMAL(15,2) NOT NULL DEFAULT 0,
    montant_cash DECIMAL(15,2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    sim_numero VARCHAR(50) NOT NULL,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(255),
    agent_id INT NOT NULL,
    agent_username VARCHAR(255),
    client_nom VARCHAR(255),
    client_telephone VARCHAR(50),
    statut VARCHAR(50) NOT NULL,
    date_enregistrement DATETIME NOT NULL,
    date_validation DATETIME,
    notes TEXT,
    is_administrative BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Deletion information
    deleted_by_agent_id INT NOT NULL,
    deleted_by_agent_name VARCHAR(255) NOT NULL,
    deletion_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deletion_reason TEXT,
    
    -- Restoration information
    is_restored BOOLEAN NOT NULL DEFAULT FALSE,
    restored_by VARCHAR(255) NULL,
    restoration_date DATETIME NULL,
    restoration_reason TEXT,
    
    -- Synchronization
    is_synced BOOLEAN NOT NULL DEFAULT FALSE,
    synced_at DATETIME NULL,
    last_modified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(255),
    
    INDEX idx_reference (reference),
    INDEX idx_virtual_transaction_id (virtual_transaction_id),
    INDEX idx_shop_id (shop_id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_deleted_by_agent (deleted_by_agent_id),
    INDEX idx_is_restored (is_restored),
    INDEX idx_is_synced (is_synced),
    INDEX idx_deletion_date (deletion_date),
    INDEX idx_last_modified (last_modified_at)
);
