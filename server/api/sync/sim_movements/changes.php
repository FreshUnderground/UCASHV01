<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Récupérer le paramètre 'since' (timestamp de dernière sync)
    $since = $_GET['since'] ?? '2020-01-01T00:00:00.000';
    
    error_log("📝 [SIM Movements Changes] Requête depuis: $since");
    
    // Récupérer tous les mouvements modifiés depuis le timestamp
    $stmt = $conn->prepare("
        SELECT 
            id,
            sim_id,
            sim_numero,
            ancien_shop_id,
            ancien_shop_designation,
            nouveau_shop_id,
            nouveau_shop_designation,
            admin_responsable,
            motif,
            date_movement,
            last_modified_at,
            last_modified_by,
            is_synced,
            synced_at
        FROM sim_movements
        WHERE last_modified_at >= ?
        ORDER BY date_movement DESC
    ");
    
    $stmt->execute([$since]);
    $movements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("📝 [SIM Movements Changes] " . count($movements) . " mouvements trouvés");
    
    echo json_encode([
        'success' => true,
        'entities' => $movements,
        'count' => count($movements),
        'since' => $since,
        'timestamp' => date('c')
    ]);
    
} catch (PDOException $e) {
    error_log("❌ [SIM Movements Changes] Erreur de base de données: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur de base de données: ' . $e->getMessage(),
        'entities' => [],
        'timestamp' => date('c')
    ]);
} catch (Exception $e) {
    error_log("❌ [SIM Movements Changes] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'entities' => [],
        'timestamp' => date('c')
    ]);
}