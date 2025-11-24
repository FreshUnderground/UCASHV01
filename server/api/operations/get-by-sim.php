<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Récupérer les paramètres
    $simNumero = $_GET['sim_numero'] ?? null;
    $startDate = $_GET['start_date'] ?? null;
    $endDate = $_GET['end_date'] ?? null;
    $limit = $_GET['limit'] ?? 50;
    $offset = $_GET['offset'] ?? 0;
    
    if (!$simNumero) {
        throw new Exception('Numéro de SIM requis');
    }
    
    error_log("📱 [Operations SIM] Requête pour SIM: $simNumero");
    
    // Construire la requête avec filtres
    $sql = "
        SELECT 
            o.id,
            o.type,
            o.montant_brut,
            o.commission,
            o.montant_net,
            o.devise,
            o.destinataire,
            o.telephone_destinataire,
            o.reference,
            o.mode_paiement,
            o.statut,
            o.code_ops,
            o.date_op,
            o.date_validation,
            o.shop_source_designation,
            o.shop_destination_designation,
            o.agent_username,
            o.observation
        FROM operations o
        WHERE o.telephone_destinataire = :sim_numero
    ";
    
    $params = [':sim_numero' => $simNumero];
    
    // Filtre par date
    if ($startDate) {
        $sql .= " AND o.date_op >= :start_date";
        $params[':start_date'] = $startDate;
    }
    
    if ($endDate) {
        $sql .= " AND o.date_op <= :end_date";
        $params[':end_date'] = $endDate;
    }
    
    $sql .= " ORDER BY o.date_op DESC LIMIT :limit OFFSET :offset";
    
    $stmt = $conn->prepare($sql);
    
    // Binder les paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', (int)$limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', (int)$offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Compter le total pour pagination
    $countSql = "
        SELECT COUNT(*) as total
        FROM operations o
        WHERE o.telephone_destinataire = :sim_numero
    ";
    
    $countParams = [':sim_numero' => $simNumero];
    
    if ($startDate) {
        $countSql .= " AND o.date_op >= :start_date";
        $countParams[':start_date'] = $startDate;
    }
    
    if ($endDate) {
        $countSql .= " AND o.date_op <= :end_date";
        $countParams[':end_date'] = $endDate;
    }
    
    $countStmt = $conn->prepare($countSql);
    foreach ($countParams as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    error_log("📱 [Operations SIM] " . count($operations) . " opérations trouvées pour SIM: $simNumero");
    
    echo json_encode([
        'success' => true,
        'operations' => $operations,
        'total' => (int)$totalCount,
        'limit' => (int)$limit,
        'offset' => (int)$offset
    ]);
    
} catch (Exception $e) {
    error_log("❌ [Operations SIM] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}