<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../config/database.php';

try {
    $shopId = $_GET['shop_id'] ?? null;
    $adminId = $_GET['admin_id'] ?? null;
    $startDate = $_GET['start_date'] ?? null;
    $endDate = $_GET['end_date'] ?? null;
    $limit = $_GET['limit'] ?? 50;
    
    // Construire la requête
    $sql = "
        SELECT 
            al.id,
            al.table_name,
            al.record_id as shop_id,
            al.action as adjustment_type,
            al.old_values,
            al.new_values,
            al.changed_fields,
            al.user_id as admin_id,
            al.username as admin_username,
            al.reason,
            al.created_at,
            s.designation as shop_name,
            s.localisation as shop_location
        FROM audit_log al
        LEFT JOIN shops s ON al.record_id = s.id
        WHERE al.table_name = 'shops'
          AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
    ";
    
    $params = [];
    
    if ($shopId) {
        $sql .= " AND al.record_id = ?";
        $params[] = $shopId;
    }
    
    if ($adminId) {
        $sql .= " AND al.user_id = ?";
        $params[] = $adminId;
    }
    
    if ($startDate) {
        $sql .= " AND al.created_at >= ?";
        $params[] = $startDate;
    }
    
    if ($endDate) {
        $sql .= " AND al.created_at <= ?";
        $params[] = $endDate . ' 23:59:59';
    }
    
    $sql .= " ORDER BY al.created_at DESC LIMIT ?";
    $params[] = (int)$limit;
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $adjustments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats
    $formattedAdjustments = [];
    foreach ($adjustments as $adj) {
        $oldValues = json_decode($adj['old_values'], true);
        $newValues = json_decode($adj['new_values'], true);
        $changedFields = json_decode($adj['changed_fields'], true);
        
        $capitalBefore = $oldValues['capital_actuel'] ?? 0;
        $capitalAfter = $newValues['capital_actuel'] ?? 0;
        $difference = $capitalAfter - $capitalBefore;
        
        $formattedAdjustments[] = [
            'id' => $adj['id'],
            'shop_id' => $adj['shop_id'],
            'shop_name' => $adj['shop_name'],
            'shop_location' => $adj['shop_location'],
            'adjustment_type' => $adj['adjustment_type'],
            'amount' => abs($difference),
            'mode_paiement' => $changedFields['mode_paiement'] ?? 'cash',
            'capital_before' => $capitalBefore,
            'capital_after' => $capitalAfter,
            'difference' => $difference,
            'reason' => $adj['reason'],
            'description' => $changedFields['description'] ?? null,
            'admin_id' => $adj['admin_id'],
            'admin_username' => $adj['admin_username'],
            'created_at' => $adj['created_at'],
            'details' => [
                'cash_before' => $oldValues['capital_cash'] ?? 0,
                'cash_after' => $newValues['capital_cash'] ?? 0,
                'airtel_before' => $oldValues['capital_airtel_money'] ?? 0,
                'airtel_after' => $newValues['capital_airtel_money'] ?? 0,
                'mpesa_before' => $oldValues['capital_mpesa'] ?? 0,
                'mpesa_after' => $newValues['capital_mpesa'] ?? 0,
                'orange_before' => $oldValues['capital_orange_money'] ?? 0,
                'orange_after' => $newValues['capital_orange_money'] ?? 0,
            ]
        ];
    }
    
    // Calculer les statistiques
    $totalIncreases = 0;
    $totalDecreases = 0;
    $countIncreases = 0;
    $countDecreases = 0;
    
    foreach ($formattedAdjustments as $adj) {
        if ($adj['adjustment_type'] === 'CAPITAL_INCREASE') {
            $totalIncreases += $adj['amount'];
            $countIncreases++;
        } else {
            $totalDecreases += $adj['amount'];
            $countDecreases++;
        }
    }
    
    $response = [
        'success' => true,
        'adjustments' => $formattedAdjustments,
        'summary' => [
            'total_adjustments' => count($formattedAdjustments),
            'total_increases' => $totalIncreases,
            'count_increases' => $countIncreases,
            'total_decreases' => $totalDecreases,
            'count_decreases' => $countDecreases,
            'net_change' => $totalIncreases - $totalDecreases,
        ],
        'filters' => [
            'shop_id' => $shopId,
            'admin_id' => $adminId,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'limit' => (int)$limit,
        ]
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur: ' . $e->getMessage()
    ]);
}
