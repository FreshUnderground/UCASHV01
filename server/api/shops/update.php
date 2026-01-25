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
    $userId = $data['user_id'] ?? 'admin';
    $timestamp = $data['timestamp'] ?? date('Y-m-d H:i:s');
    
    if (!$shopId) {
        throw new Exception('ID du shop requis');
    }
    
    // Connexion à la base de données
    if (!isset($pdo)) {
        throw new Exception('Connexion à la base de données impossible');
    }
    
    $pdo->beginTransaction();
    
    // Récupérer l'état actuel du shop
    $oldStmt = $pdo->prepare("SELECT * FROM shops WHERE id = ?");
    $oldStmt->execute([$shopId]);
    $shopBefore = $oldStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$shopBefore) {
        throw new Exception('Shop non trouvé');
    }
    
    // Préparer les champs à mettre à jour
    $fieldsToUpdate = [];
    $params = [];
    $changedFields = [];
    
    // Liste des champs modifiables
    $allowedFields = [
        'designation',
        'localisation',
        'is_principal',
        'capital_initial',
        'devise_principale',
        'devise_secondaire',
        'capital_actuel',
        'capital_cash',
        'capital_airtel_money',
        'capital_mpesa',
        'capital_orange_money',
        'capital_actuel_devise2',
        'capital_cash_devise2',
        'capital_airtel_money_devise2',
        'capital_mpesa_devise2',
        'capital_orange_money_devise2',
        'creances',
        'dettes',
    ];
    
    // Construire la requête UPDATE dynamiquement
    foreach ($allowedFields as $field) {
        if (array_key_exists($field, $data)) {
            $fieldsToUpdate[] = "$field = ?";
            $params[] = $data[$field];
            
            // Enregistrer les changements pour l'audit
            if ($data[$field] != $shopBefore[$field]) {
                $changedFields[$field] = [
                    'old' => $shopBefore[$field],
                    'new' => $data[$field]
                ];
            }
        }
    }
    
    // Ajouter les champs de tracking
    $fieldsToUpdate[] = "last_modified_at = ?";
    $fieldsToUpdate[] = "last_modified_by = ?";
    $fieldsToUpdate[] = "is_synced = 1";
    $fieldsToUpdate[] = "synced_at = NOW()";
    
    $params[] = $timestamp;
    $params[] = $userId;
    $params[] = $shopId; // Pour la clause WHERE
    
    // Exécuter la mise à jour
    $updateSql = "UPDATE shops SET " . implode(", ", $fieldsToUpdate) . " WHERE id = ?";
    $updateStmt = $pdo->prepare($updateSql);
    $updateStmt->execute($params);
    
    // Récupérer l'état après mise à jour
    $oldStmt->execute([$shopId]);
    $shopAfter = $oldStmt->fetch(PDO::FETCH_ASSOC);
    
    // Enregistrer dans l'audit log si il y a eu des changements
    if (!empty($changedFields)) {
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
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        
        $auditStmt->execute([
            'shops',
            $shopId,
            'SHOP_UPDATE',
            json_encode($shopBefore),
            json_encode($shopAfter),
            json_encode($changedFields),
            $userId,
            'ADMIN',
            $userId,
            $shopId
        ]);
        
        $auditId = $pdo->lastInsertId();
    } else {
        $auditId = null;
    }
    
    // Trouver les agents affectés par ce shop
    $agentsStmt = $pdo->prepare("
        SELECT id, username, nom, shop_id 
        FROM agents 
        WHERE shop_id = ? AND is_active = 1
    ");
    $agentsStmt->execute([$shopId]);
    $affectedAgents = $agentsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    $pdo->commit();
    
    // Réponse de succès
    $response = [
        'success' => true,
        'message' => 'Shop mis à jour avec succès',
        'shop' => [
            'id' => $shopId,
            'designation' => $shopAfter['designation'],
            'localisation' => $shopAfter['localisation'],
            'capital_actuel' => $shopAfter['capital_actuel'],
            'updated_at' => $shopAfter['last_modified_at'],
            'updated_by' => $shopAfter['last_modified_by'],
        ],
        'changes' => [
            'count' => count($changedFields),
            'fields' => array_keys($changedFields),
            'details' => $changedFields,
        ],
        'audit' => [
            'id' => $auditId,
            'recorded' => !empty($changedFields),
        ],
        'affected_agents' => [
            'count' => count($affectedAgents),
            'agents' => array_map(function($agent) {
                return [
                    'id' => $agent['id'],
                    'username' => $agent['username'],
                    'nom' => $agent['nom']
                ];
            }, $affectedAgents)
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
