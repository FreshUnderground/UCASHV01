<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Lire les données JSON
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data || !isset($data['operation_id'])) {
        throw new Exception('ID d\'opération requis');
    }
    
    $operationId = $data['operation_id'];
    $commission = $data['commission'] ?? null;
    $montantNet = $data['montant_net'] ?? null;
    $observation = $data['observation'] ?? null;
    $agentUsername = $data['agent_username'] ?? null;
    $dateValidation = date('Y-m-d H:i:s');
    
    error_log("📱 [Servir Opération] Traitement opération ID: $operationId");
    
    // 1. Mettre à jour l'opération comme SERVIE
    $stmt = $conn->prepare("
        UPDATE operations SET
            statut = 'terminee',
            commission = COALESCE(?, commission),
            montant_net = COALESCE(?, montant_net),
            observation = ?,
            date_validation = ?,
            last_modified_at = ?,
            last_modified_by = ?
        WHERE id = ?
    ");
    
    $stmt->execute([
        $commission,
        $montantNet,
        $observation,
        $dateValidation,
        $dateValidation,
        $agentUsername,
        $operationId
    ]);
    
    if ($stmt->rowCount() === 0) {
        throw new Exception('Opération non trouvée ou déjà traitée');
    }
    
    // 2. Récupérer les détails de l'opération pour créer la dette
    $opStmt = $conn->prepare("
        SELECT 
            shop_source_id,
            shop_source_designation,
            montant_net,
            devise,
            mode_paiement,
            code_ops
        FROM operations 
        WHERE id = ?
    ");
    $opStmt->execute([$operationId]);
    $operation = $opStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$operation) {
        throw new Exception('Détails de l\'opération non trouvés');
    }
    
    // 3. Créer la dette entre shop de la SIM et SHOP CENTRAL
    // TODO: Récupérer l'ID du shop central depuis la config
    $shopCentralId = 1; // À remplacer par la vraie valeur
    $shopCentralDesignation = 'SHOP C';
    
    $flotStmt = $conn->prepare("
        INSERT INTO flots (
            shop_source_id,
            shop_source_designation,
            shop_destination_id,
            shop_destination_designation,
            montant,
            devise,
            mode_paiement,
            agent_envoyeur_id,
            agent_envoyeur_username,
            notes,
            date_envoi,
            statut,
            is_synced,
            synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'envoye', 1, NOW())
    ");
    
    // Récupérer l'ID de l'agent
    $agentStmt = $conn->prepare("SELECT id FROM agents WHERE username = ? LIMIT 1");
    $agentStmt->execute([$agentUsername]);
    $agent = $agentStmt->fetch(PDO::FETCH_ASSOC);
    $agentId = $agent['id'] ?? null;
    
    $flotStmt->execute([
        $operation['shop_source_id'],
        $operation['shop_source_designation'],
        $shopCentralId,
        $shopCentralDesignation,
        $operation['montant_net'],
        $operation['devise'],
        $operation['mode_paiement'],
        $agentId,
        $agentUsername,
        'Dette retrait Mobile Money - Réf: ' . $operation['code_ops'],
        $dateValidation
    ]);
    
    $flotId = $conn->lastInsertId();
    error_log("📝 [Servir Opération] Dette créée (Flot ID: $flotId)");
    
    // 4. TODO: Mettre à jour le solde de la SIM
    // Pour l'instant, le solde doit être mis à jour manuellement
    
    echo json_encode([
        'success' => true,
        'message' => 'Opération servie avec succès',
        'operation_id' => $operationId,
        'flot_id' => $flotId
    ]);
    
} catch (Exception $e) {
    error_log("❌ [Servir Opération] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}