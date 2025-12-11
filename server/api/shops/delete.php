<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

try {
    // Récupérer les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données invalides ou manquantes');
    }
    
    // Validation des champs requis
    $shopId = $data['shop_id'] ?? null;
    $adminId = $data['admin_id'] ?? null;
    $adminUsername = $data['admin_username'] ?? 'admin';
    $reason = $data['reason'] ?? null;
    $deleteType = $data['delete_type'] ?? 'soft'; // 'soft' ou 'hard'
    
    if (!$shopId) {
        throw new Exception('ID du shop requis');
    }
    
    if (!$adminId) {
        throw new Exception('ID de l\'admin requis');
    }
    
    if (!$reason || strlen(trim($reason)) < 10) {
        throw new Exception('Une raison détaillée est requise (minimum 10 caractères)');
    }
    
    // Connexion à la base de données
    require_once __DIR__ . '/../../config/database.php';
    
    if (!isset($pdo)) {
        throw new Exception('Connexion à la base de données impossible');
    }
    
    $pdo->beginTransaction();
    
    // Vérifier que le shop existe
    $shopStmt = $pdo->prepare("SELECT * FROM shops WHERE id = ?");
    $shopStmt->execute([$shopId]);
    $shop = $shopStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$shop) {
        throw new Exception('Shop non trouvé');
    }
    
    // Vérifier les agents assignés à ce shop
    $agentsStmt = $pdo->prepare("
        SELECT id, username, nom 
        FROM agents 
        WHERE shop_id = ? AND is_active = 1
    ");
    $agentsStmt->execute([$shopId]);
    $affectedAgents = $agentsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Vérifier les opérations du shop
    $operationsStmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM operations 
        WHERE shop_id = ?
    ");
    $operationsStmt->execute([$shopId]);
    $operationsCount = $operationsStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Vérifier les caisses du shop
    $caissesStmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM caisses 
        WHERE shop_id = ?
    ");
    $caissesStmt->execute([$shopId]);
    $caissesCount = $caissesStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Si des agents sont assignés, les désassigner ou bloquer la suppression
    if (count($affectedAgents) > 0) {
        $forceDelete = $data['force_delete'] ?? false;
        
        if (!$forceDelete) {
            throw new Exception(
                'Ce shop a ' . count($affectedAgents) . ' agent(s) assigné(s). ' .
                'Veuillez les réassigner ou utiliser force_delete=true'
            );
        }
        
        // Désassigner les agents (les mettre sur shop_id = NULL ou 1)
        $unassignStmt = $pdo->prepare("
            UPDATE agents 
            SET shop_id = NULL, 
                last_modified_at = NOW(),
                last_modified_by = ?
            WHERE shop_id = ?
        ");
        $unassignStmt->execute([$adminUsername, $shopId]);
    }
    
    // Enregistrer l'état avant suppression pour l'audit
    $oldValues = json_encode([
        'id' => $shop['id'],
        'designation' => $shop['designation'],
        'localisation' => $shop['localisation'],
        'capital_actuel' => $shop['capital_actuel'],
        'capital_cash' => $shop['capital_cash'],
        'capital_airtel_money' => $shop['capital_airtel_money'],
        'capital_mpesa' => $shop['capital_mpesa'],
        'capital_orange_money' => $shop['capital_orange_money'],
        'created_at' => $shop['created_at'],
    ]);
    
    $metadata = json_encode([
        'delete_type' => $deleteType,
        'agents_count' => count($affectedAgents),
        'operations_count' => $operationsCount,
        'caisses_count' => $caissesCount,
        'affected_agents' => array_column($affectedAgents, 'username'),
    ]);
    
    // Effectuer la suppression
    if ($deleteType === 'soft') {
        // Soft delete: marquer comme inactif
        $deleteStmt = $pdo->prepare("
            UPDATE shops 
            SET is_active = 0,
                last_modified_at = NOW(),
                last_modified_by = ?
            WHERE id = ?
        ");
        $deleteStmt->execute([$adminUsername, $shopId]);
        $actionType = 'SHOP_SOFT_DELETE';
    } else {
        // Hard delete: supprimer réellement (DANGER!)
        // D'abord supprimer les dépendances
        $pdo->prepare("DELETE FROM caisses WHERE shop_id = ?")->execute([$shopId]);
        $pdo->prepare("DELETE FROM cloture_caisse WHERE shop_id = ?")->execute([$shopId]);
        
        // Puis supprimer le shop
        $deleteStmt = $pdo->prepare("DELETE FROM shops WHERE id = ?");
        $deleteStmt->execute([$shopId]);
        $actionType = 'SHOP_HARD_DELETE';
    }
    
    // Enregistrer dans l'audit log
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
    
    $auditStmt->execute([
        'shops',
        $shopId,
        $actionType,
        $oldValues,
        null, // Pas de nouvelles valeurs pour une suppression
        $metadata,
        $adminId,
        'ADMIN',
        $adminUsername,
        $shopId,
        $reason
    ]);
    
    $auditId = $pdo->lastInsertId();
    
    $pdo->commit();
    
    // Réponse de succès
    $response = [
        'success' => true,
        'message' => $deleteType === 'soft' 
            ? 'Shop désactivé avec succès' 
            : 'Shop supprimé définitivement',
        'deletion' => [
            'audit_id' => $auditId,
            'shop_id' => $shopId,
            'shop_name' => $shop['designation'],
            'delete_type' => $deleteType,
            'admin' => $adminUsername,
            'timestamp' => date('Y-m-d H:i:s'),
        ],
        'affected_agents' => [
            'count' => count($affectedAgents),
            'agents' => $affectedAgents,
            'action' => count($affectedAgents) > 0 ? 'unassigned' : 'none'
        ],
        'statistics' => [
            'operations_affected' => $operationsCount,
            'caisses_deleted' => $deleteType === 'hard' ? $caissesCount : 0,
        ]
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
