<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once '../../config/database.php';

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données invalides');
    }
    
    // Valider les données requises
    $shopId = $data['shop_id'] ?? null;
    $adjustmentType = $data['adjustment_type'] ?? null; // 'INCREASE' ou 'DECREASE'
    $amount = $data['amount'] ?? null;
    $reason = $data['reason'] ?? null;
    $adminId = $data['admin_id'] ?? null;
    $adminUsername = $data['admin_username'] ?? 'admin';
    
    if (!$shopId || !$adjustmentType || !$amount || !$reason || !$adminId) {
        throw new Exception('Données manquantes: shop_id, adjustment_type, amount, reason, admin_id sont requis');
    }
    
    // Récupérer les valeurs du shop AVANT modification
    $stmt = $pdo->prepare("
        SELECT 
            capital_initial,
            capital_actuel,
            capital_cash,
            capital_airtel_money,
            capital_mpesa,
            capital_orange_money,
            designation
        FROM shops 
        WHERE id = ?
    ");
    $stmt->execute([$shopId]);
    $shopBefore = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$shopBefore) {
        throw new Exception("Shop ID $shopId introuvable");
    }
    
    // Calculer les nouveaux capitaux
    $capitalChange = ($adjustmentType === 'INCREASE') ? $amount : -$amount;
    
    $newCapitalActuel = $shopBefore['capital_actuel'] + $capitalChange;
    
    // Répartir le changement selon le mode de paiement spécifié
    $modePaiement = $data['mode_paiement'] ?? 'cash'; // cash, airtel_money, mpesa, orange_money
    
    $newCapitalCash = $shopBefore['capital_cash'];
    $newCapitalAirtel = $shopBefore['capital_airtel_money'];
    $newCapitalMPesa = $shopBefore['capital_mpesa'];
    $newCapitalOrange = $shopBefore['capital_orange_money'];
    
    switch ($modePaiement) {
        case 'airtel_money':
            $newCapitalAirtel += $capitalChange;
            break;
        case 'mpesa':
            $newCapitalMPesa += $capitalChange;
            break;
        case 'orange_money':
            $newCapitalOrange += $capitalChange;
            break;
        case 'cash':
        default:
            $newCapitalCash += $capitalChange;
            break;
    }
    
    // Mettre à jour le shop
    $updateStmt = $pdo->prepare("
        UPDATE shops 
        SET 
            capital_actuel = ?,
            capital_cash = ?,
            capital_airtel_money = ?,
            capital_mpesa = ?,
            capital_orange_money = ?,
            last_modified_at = NOW(),
            last_modified_by = ?
        WHERE id = ?
    ");
    
    $updateStmt->execute([
        $newCapitalActuel,
        $newCapitalCash,
        $newCapitalAirtel,
        $newCapitalMPesa,
        $newCapitalOrange,
        $adminUsername,
        $shopId
    ]);
    
    // Récupérer les nouvelles valeurs
    $stmt->execute([$shopId]);
    $shopAfter = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // ✅ ENREGISTRER DANS AUDIT LOG
    $auditStmt = $pdo->prepare("
        INSERT INTO audit_log (
            table_name,
            record_id,
            action,
            old_values,
            new_values,
            changed_fields,
            user_id,
            user_role,
            username,
            shop_id,
            reason,
            created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ");
    
    $oldValues = json_encode([
        'capital_initial' => $shopBefore['capital_initial'],
        'capital_actuel' => $shopBefore['capital_actuel'],
        'capital_cash' => $shopBefore['capital_cash'],
        'capital_airtel_money' => $shopBefore['capital_airtel_money'],
        'capital_mpesa' => $shopBefore['capital_mpesa'],
        'capital_orange_money' => $shopBefore['capital_orange_money'],
    ]);
    
    $newValues = json_encode([
        'capital_initial' => $shopAfter['capital_initial'],
        'capital_actuel' => $shopAfter['capital_actuel'],
        'capital_cash' => $shopAfter['capital_cash'],
        'capital_airtel_money' => $shopAfter['capital_airtel_money'],
        'capital_mpesa' => $shopAfter['capital_mpesa'],
        'capital_orange_money' => $shopAfter['capital_orange_money'],
    ]);
    
    $changedFields = json_encode([
        'adjustment_type' => $adjustmentType,
        'amount' => $amount,
        'mode_paiement' => $modePaiement,
        'description' => $data['description'] ?? null,
    ]);
    
    $auditStmt->execute([
        'shops',
        $shopId,
        $adjustmentType === 'INCREASE' ? 'CAPITAL_INCREASE' : 'CAPITAL_DECREASE',
        $oldValues,
        $newValues,
        $changedFields,
        $adminId,
        'ADMIN',
        $adminUsername,
        $shopId,
        $reason
    ]);
    
    $auditId = $pdo->lastInsertId();
    
    // Réponse de succès
    $response = [
        'success' => true,
        'message' => 'Ajustement de capital enregistré avec succès',
        'adjustment' => [
            'audit_id' => $auditId,
            'shop_id' => $shopId,
            'shop_name' => $shopBefore['designation'],
            'adjustment_type' => $adjustmentType,
            'amount' => $amount,
            'mode_paiement' => $modePaiement,
            'capital_before' => $shopBefore['capital_actuel'],
            'capital_after' => $shopAfter['capital_actuel'],
            'difference' => $capitalChange,
            'admin' => $adminUsername,
            'timestamp' => date('Y-m-d H:i:s'),
        ],
        'details' => [
            'cash' => [
                'before' => $shopBefore['capital_cash'],
                'after' => $shopAfter['capital_cash'],
                'change' => $shopAfter['capital_cash'] - $shopBefore['capital_cash']
            ],
            'airtel_money' => [
                'before' => $shopBefore['capital_airtel_money'],
                'after' => $shopAfter['capital_airtel_money'],
                'change' => $shopAfter['capital_airtel_money'] - $shopBefore['capital_airtel_money']
            ],
            'mpesa' => [
                'before' => $shopBefore['capital_mpesa'],
                'after' => $shopAfter['capital_mpesa'],
                'change' => $shopAfter['capital_mpesa'] - $shopBefore['capital_mpesa']
            ],
            'orange_money' => [
                'before' => $shopBefore['capital_orange_money'],
                'after' => $shopAfter['capital_orange_money'],
                'change' => $shopAfter['capital_orange_money'] - $shopBefore['capital_orange_money']
            ]
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
