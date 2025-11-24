<?php
// Script pour créer la table sim_solde_movements
require_once __DIR__ . '/../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    $sql = "
    CREATE TABLE IF NOT EXISTS sim_solde_movements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        sim_id INT NOT NULL,
        sim_numero VARCHAR(20) NOT NULL,
        ancien_solde DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        nouveau_solde DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        difference DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        motif TEXT,
        agent_responsable VARCHAR(100),
        date_movement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME NULL,
        INDEX idx_sim_id (sim_id),
        INDEX idx_sim_numero (sim_numero),
        INDEX idx_date (date_movement),
        INDEX idx_agent (agent_responsable)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ";
    
    $conn->exec($sql);
    echo "✅ Table 'sim_solde_movements' créée avec succès\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}