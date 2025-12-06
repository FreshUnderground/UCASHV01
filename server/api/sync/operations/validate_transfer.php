<?php
/**
 * API Endpoint: Validate Transfer
 * 
 * Permet au shop DESTINATION de valider un transfert directement dans MySQL.
 * Cette validation est IMMÉDIATE et visible par tous les shops.
 * 
 * ⚠️ IMPORTANT: Identification des opérations entre bases différentes!
 * - reference peut être NULL
 * - Les IDs diffèrent entre SharedPreferences local et MySQL
 * - Solution: Utiliser une combinaison unique (shop_source + date + montant + destinataire)
 * 
 * METHOD: POST
 * BODY: {
 *   "reference": "TRF-xxx",           // Optionnel (peut être null)
 *   "operation_id": 123,               // Optionnel (ID MySQL si connu)
 *   "code_ops": "UCASH-20251118-1-103045", // Optionnel (code d'opération unique)
 *   "shop_source_id": 1,               // REQUIS pour identification
 *   "shop_destination_id": 5,          // REQUIS (sécurité)
 *   "date_operation": "2025-11-10 20:39:29",  // REQUIS pour identification
 *   "montant_net": 492.50,             // REQUIS pour identification
 *   "destinataire": "SEMEYI",          // REQUIS pour identification
 *   "mode_paiement": "cash",
 *   "validated_by": "agent_username"
 * }
 * 
 * RESPONSE: {
 *   "success": true,
 *   "message": "Transfert validé avec succès",
 *   "operation": {...},
 *   "timestamp": "2024-11-10T10:30:00Z"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Gérer les requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Méthode non autorisée. Utilisez POST.'
    ]);
    exit;
}

require_once __DIR__ . '/../../../classes/Database.php';

try {
    // Récupérer les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données JSON invalides');
    }
    
    // Valider les paramètres requis
    // Strategy: Utiliser une combinaison unique pour identifier l'opération
    $hasReference = isset($data['reference']) && !empty($data['reference']);
    $hasId = isset($data['operation_id']);
    $hasCodeOps = isset($data['code_ops']) && !empty($data['code_ops']);
    $hasComposite = isset($data['shop_source_id']) && isset($data['date_operation']) && 
                    isset($data['montant_net']) && isset($data['destinataire']);
    
    if (!$hasReference && !$hasId && !$hasCodeOps && !$hasComposite) {
        throw new Exception(
            'Identification insuffisante. Fournissez soit:\n' .
            '1. reference (si disponible)\n' .
            '2. code_ops (code d\'opération unique)\n' .
            '3. operation_id (si connu)\n' .
            '4. Combinaison: shop_source_id + date_operation + montant_net + destinataire'
        );
    }
    
    if (!isset($data['mode_paiement']) || !isset($data['shop_destination_id']) || !isset($data['validated_by'])) {
        throw new Exception('Paramètres manquants: mode_paiement, shop_destination_id, validated_by requis');
    }
    
    // Extraire les paramètres
    $reference = isset($data['reference']) ? $data['reference'] : null;
    $operationId = isset($data['operation_id']) ? (int)$data['operation_id'] : null;
    $codeOps = isset($data['code_ops']) ? $data['code_ops'] : null;
    $shopSourceId = isset($data['shop_source_id']) ? (int)$data['shop_source_id'] : null;
    $dateOperation = isset($data['date_operation']) ? $data['date_operation'] : null;
    $montantNet = isset($data['montant_net']) ? (float)$data['montant_net'] : null;
    $destinataire = isset($data['destinataire']) ? $data['destinataire'] : null;
    $modePaiement = $data['mode_paiement'];
    $shopDestinationId = (int)$data['shop_destination_id'];
    $validatedBy = $data['validated_by'];
    
    // Valider le mode de paiement
    $modesValides = ['cash', 'airtelMoney', 'mPesa', 'orangeMoney'];
    if (!in_array($modePaiement, $modesValides)) {
        throw new Exception('Mode de paiement invalide. Valeurs acceptées: ' . implode(', ', $modesValides));
    }
    
    // Connexion à la base de données
    $db = Database::getInstance()->getConnection();
    $db->beginTransaction();
    
    // 1. Récupérer l'opération avec stratégie multi-niveaux
    // IMPORTANT: Les IDs diffèrent entre SharedPreferences et MySQL!
    // Strategy 1: Par reference (si disponible et non-null)
    // Strategy 2: Par code_ops (si disponible)
    // Strategy 3: Par ID (si fourni)
    // Strategy 4: Par combinaison unique (shop_source + date + montant + destinataire)
    
    $operation = null;
    $stmt = null;
    
    if ($hasReference && $reference) {
        // Strategy 1: Recherche par reference
        $stmt = $db->prepare("
            SELECT * FROM operations 
            WHERE reference = :reference
            FOR UPDATE
        ");
        $stmt->execute([':reference' => $reference]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($operation) {
            error_log("✅ Opération trouvée par reference: $reference");
            $operationId = $operation['id'];
        }
    }
    
    if (!$operation && $hasCodeOps && $codeOps) {
        // Strategy 2: Recherche par code_ops
        $stmt = $db->prepare("
            SELECT * FROM operations 
            WHERE code_ops = :code_ops
            FOR UPDATE
        ");
        $stmt->execute([':code_ops' => $codeOps]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($operation) {
            error_log("✅ Opération trouvée par code_ops: $codeOps");
            $operationId = $operation['id'];
        }
    }
    
    if (!$operation && $hasId) {
        // Strategy 3: Recherche par ID (moins fiable)
        $stmt = $db->prepare("
            SELECT * FROM operations 
            WHERE id = :id
            FOR UPDATE
        ");
        $stmt->execute([':id' => $operationId]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($operation) {
            error_log("⚠️ Opération trouvée par ID: $operationId (moins fiable)");
        }
    }
    
    if (!$operation && $hasComposite) {
        // Strategy 4: Recherche par combinaison unique (le plus fiable!)
        $stmt = $db->prepare("
            SELECT * FROM operations 
            WHERE shop_source_id = :shop_source_id
            AND DATE_FORMAT(date_operation, '%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:date_operation, '%Y-%m-%d %H:%i:%s')
            AND ABS(montant_net - :montant_net) < 0.01
            AND destinataire = :destinataire
            AND type IN ('transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant')
            ORDER BY created_at DESC
            LIMIT 1
            FOR UPDATE
        ");
        $stmt->execute([
            ':shop_source_id' => $shopSourceId,
            ':date_operation' => $dateOperation,
            ':montant_net' => $montantNet,
            ':destinataire' => $destinataire
        ]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($operation) {
            error_log("✅ Opération trouvée par combinaison unique (shop:$shopSourceId, date:$dateOperation, montant:$montantNet, dest:$destinataire)");
            $operationId = $operation['id'];
        }
    }
    
    if (!$operation) {
        $identifiers = [];
        if ($reference) $identifiers[] = "reference='$reference'";
        if ($codeOps) $identifiers[] = "code_ops='$codeOps'";
        if ($operationId) $identifiers[] = "id=$operationId";
        if ($hasComposite) $identifiers[] = "composite(shop:$shopSourceId,date:$dateOperation,montant:$montantNet)";
        throw new Exception("Opération non trouvée avec: " . implode(' ou ', $identifiers));
    }
    
    // 2. Vérifications de sécurité
    
    // Vérifier que c'est un transfert
    $typesTransfert = ['transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant'];
    if (!in_array($operation['type'], $typesTransfert)) {
        throw new Exception("L'opération ID $operationId n'est pas un transfert");
    }
    
    // Vérifier que le statut est EN_ATTENTE
    if ($operation['statut'] !== 'enAttente') {
        throw new Exception("Le transfert n'est pas en attente (Statut actuel: {$operation['statut']})");
    }
    
    // ❗ SÉCURITÉ CRITIQUE: Vérifier que le shop est bien la DESTINATION
    if ($operation['shop_destination_id'] != $shopDestinationId) {
        throw new Exception("Erreur de sécurité: Ce transfert n'est pas destiné au shop ID $shopDestinationId");
    }
    
    // 3. Mettre à jour le transfert
    $updateStmt = $db->prepare("
        UPDATE operations 
        SET 
            statut = 'validee',
            mode_paiement = :mode_paiement,
            date_validation = NOW(),
            last_modified_at = NOW(),
            last_modified_by = :validated_by,
            is_synced = 0,
            synced_at = NULL
        WHERE code_ops = :code_ops OR id = :id
    ");
    
    $updateStmt->execute([
        ':mode_paiement' => $modePaiement,
        ':validated_by' => $validatedBy,
        ':code_ops' => $codeOps ?? '',
        ':id' => $operationId
    ]);
    
    // 4. Récupérer l'opération mise à jour pour la réponse
    $finalStmt = $db->prepare("SELECT * FROM operations WHERE code_ops = :code_ops OR id = :id");
    $finalStmt->execute([
        ':code_ops' => $codeOps ?? '',
        ':id' => $operationId
    ]);
    $updatedOperation = $finalStmt->fetch(PDO::FETCH_ASSOC);
    
    // 5. Mettre à jour les métadonnées de synchronisation
    $metaStmt = $db->prepare("
        UPDATE sync_metadata 
        SET last_sync_date = NOW(), 
            sync_count = sync_count + 1,
            last_sync_user = :user_id
        WHERE table_name = 'operations'
    ");
    $metaStmt->execute([':user_id' => $validatedBy]);
    
    // Commit de la transaction
    $db->commit();
    
    // Log de succès
    $identifierUsed = 'unknown';
    if ($hasReference && $reference) $identifierUsed = "reference='$reference'";
    elseif ($hasCodeOps && $codeOps) $identifierUsed = "code_ops='$codeOps'";
    elseif ($hasId) $identifierUsed = "ID=$operationId";
    elseif ($hasComposite) $identifierUsed = "composite(shop:$shopSourceId,date:$dateOperation,montant:$montantNet)";
    
    error_log("✅ Transfert identifié via $identifierUsed validé par shop $shopDestinationId (agent: $validatedBy)");
    error_log("   Type: {$operation['type']}, Montant: {$operation['montant_net']} {$operation['devise']}");
    error_log("   Destinataire: {$operation['destinataire']}");
    
    // Réponse de succès
    echo json_encode([
        'success' => true,
        'message' => 'Transfert validé avec succès',
        'operation' => [
            'id' => $updatedOperation['id'],
            'reference' => $updatedOperation['reference'],  // IMPORTANT: Retourner la reference
            'type' => $updatedOperation['type'],
            'statut' => $updatedOperation['statut'],
            'mode_paiement' => $updatedOperation['mode_paiement'],
            'montant_brut' => (float)$updatedOperation['montant_brut'],
            'montant_net' => (float)$updatedOperation['montant_net'],
            'commission' => (float)$updatedOperation['commission'],
            'destinataire' => $updatedOperation['destinataire'],
            'shop_source_id' => (int)$updatedOperation['shop_source_id'],
            'shop_destination_id' => (int)$updatedOperation['shop_destination_id'],
            'last_modified_at' => $updatedOperation['last_modified_at'],
            'last_modified_by' => $updatedOperation['last_modified_by'],
        ],
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    
    error_log("❌ Erreur validation transfert: " . $e->getMessage());
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
