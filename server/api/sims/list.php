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
    
    // Récupérer les paramètres de filtrage
    $shopId = $_GET['shop_id'] ?? null;
    $operateur = $_GET['operateur'] ?? null;
    $statut = $_GET['statut'] ?? null;
    $limit = $_GET['limit'] ?? 100;
    $offset = $_GET['offset'] ?? 0;
    
    error_log("📱 [SIMs List] Requête avec filtres");
    
    // Construire la requête avec filtres
    $sql = "
        SELECT 
            s.id,
            s.numero,
            s.operateur,
            s.shop_id,
            s.shop_designation,
            s.solde_initial,
            s.solde_actuel,
            s.statut,
            s.date_creation,
            s.last_modified_at,
            sh.designation as shop_nom,
            sh.localisation as shop_localisation
        FROM sims s
        LEFT JOIN shops sh ON s.shop_id = sh.id
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtres
    if ($shopId) {
        $sql .= " AND s.shop_id = ?";
        $params[] = $shopId;
    }
    
    if ($operateur) {
        $sql .= " AND s.operateur = ?";
        $params[] = $operateur;
    }
    
    if ($statut) {
        $sql .= " AND s.statut = ?";
        $params[] = $statut;
    }
    
    $sql .= " ORDER BY s.date_creation DESC LIMIT ? OFFSET ?";
    $params[] = (int)$limit;
    $params[] = (int)$offset;
    
    $stmt = $conn->prepare($sql);
    
    // Binder les paramètres
    foreach ($params as $index => $value) {
        $stmt->bindValue($index + 1, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
    }
    
    $stmt->execute();
    $sims = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Compter le total pour pagination
    $countSql = "
        SELECT COUNT(*) as total
        FROM sims s
        WHERE 1=1
    ";
    
    $countParams = [];
    
    if ($shopId) {
        $countSql .= " AND s.shop_id = ?";
        $countParams[] = $shopId;
    }
    
    if ($operateur) {
        $countSql .= " AND s.operateur = ?";
        $countParams[] = $operateur;
    }
    
    if ($statut) {
        $countSql .= " AND s.statut = ?";
        $countParams[] = $statut;
    }
    
    $countStmt = $conn->prepare($countSql);
    foreach ($countParams as $index => $value) {
        $countStmt->bindValue($index + 1, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
    }
    $countStmt->execute();
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Calculer les totaux par opérateur
    $totalsStmt = $conn->prepare("
        SELECT 
            operateur,
            COUNT(*) as count,
            SUM(solde_actuel) as total_solde
        FROM sims
        WHERE statut = 'active'
        GROUP BY operateur
    ");
    $totalsStmt->execute();
    $totals = $totalsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'sims' => $sims,
        'total' => (int)$totalCount,
        'limit' => (int)$limit,
        'offset' => (int)$offset,
        'totals_by_operator' => $totals
    ]);
    
} catch (Exception $e) {
    error_log("❌ [SIMs List] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}