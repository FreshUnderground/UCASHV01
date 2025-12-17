<?php
/**
 * API: Download Virtual Transactions Corbeille
 * Method: GET
 * Returns all virtual transactions in corbeille for synchronization
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    $since = $_GET['since'] ?? null;
    $isRestored = $_GET['is_restored'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    
    error_log("[VT_CORBEILLE] Download request - since: " . ($since ?? 'null') . ", isRestored: " . ($isRestored ?? 'null') . ", userId: " . $userId);
    
    // Build SQL query
    $sql = "SELECT * FROM virtual_transactions_corbeille WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    if ($isRestored !== null) {
        $sql .= " AND is_restored = ?";
        $params[] = $isRestored === '1' ? 1 : 0;
    }
    
    $sql .= " ORDER BY deletion_date DESC";
    
    error_log("[VT_CORBEILLE] SQL query: " . $sql);
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[VT_CORBEILLE] Found " . count($items) . " corbeille items");
    
    // Convert data for Flutter with proper types
    $data = [];
    foreach ($items as $item) {
        $data[] = [
            'id' => (int)$item['id'],
            'reference' => $item['reference'],
            'virtual_transaction_id' => $item['virtual_transaction_id'] ? (int)$item['virtual_transaction_id'] : null,
            
            // Original transaction data
            'montant_virtuel' => (float)$item['montant_virtuel'],
            'frais' => (float)$item['frais'],
            'montant_cash' => (float)$item['montant_cash'],
            'devise' => $item['devise'],
            'sim_numero' => $item['sim_numero'],
            'shop_id' => (int)$item['shop_id'],
            'shop_designation' => $item['shop_designation'],
            'agent_id' => (int)$item['agent_id'],
            'agent_username' => $item['agent_username'],
            'client_nom' => $item['client_nom'],
            'client_telephone' => $item['client_telephone'],
            'statut' => $item['statut'],
            'date_enregistrement' => $item['date_enregistrement'],
            'date_validation' => $item['date_validation'],
            'notes' => $item['notes'],
            'is_administrative' => (bool)$item['is_administrative'],
            
            // Deletion information
            'deleted_by_agent_id' => (int)$item['deleted_by_agent_id'],
            'deleted_by_agent_name' => $item['deleted_by_agent_name'],
            'deletion_date' => $item['deletion_date'],
            'deletion_reason' => $item['deletion_reason'],
            
            // Restoration information
            'is_restored' => (bool)$item['is_restored'],
            'restored_by' => $item['restored_by'],
            'restoration_date' => $item['restoration_date'],
            'restoration_reason' => $item['restoration_reason'],
            
            // Synchronization
            'is_synced' => (bool)$item['is_synced'],
            'synced_at' => $item['synced_at'],
            'last_modified_at' => $item['last_modified_at'],
            'last_modified_by' => $item['last_modified_by']
        ];
    }
    
    $response = [
        'success' => true,
        'data' => $data,
        'count' => count($data),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("[VT_CORBEILLE] Download error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
