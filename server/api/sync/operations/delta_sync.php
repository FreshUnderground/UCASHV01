<?php
/**
 * API de synchronisation delta intelligente pour les opérations
 * Évite le retéléchargement des opérations déjà synchronisées
 * Capture uniquement les modifications (statut, validation, etc.)
 */

$startTime = microtime(true);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/ApiOptimizer.php';

try {
    // Paramètres de synchronisation delta
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    
    // Nouveaux paramètres pour la synchronisation delta
    $knownIds = $_GET['known_ids'] ?? null; // IDs déjà synchronisés (format: "1,2,3,4")
    $syncMode = $_GET['sync_mode'] ?? 'delta'; // 'delta', 'full', 'updates_only'
    $statusFilter = $_GET['status_filter'] ?? null; // Filtrer par statut spécifique
    $lastSyncHash = $_GET['last_sync_hash'] ?? null; // Hash de la dernière sync pour validation
    
    $pagination = ApiOptimizer::validatePagination(
        $_GET['limit'] ?? null,
        $_GET['offset'] ?? null
    );
    
    error_log("🔄 DELTA SYNC - Mode: $syncMode, Known IDs: " . ($knownIds ? 'Oui' : 'Non'));
    
    // Validation des paramètres requis
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants: user_id et user_role'
        ]);
        exit();
    }
    
    // Convertir les IDs connus en tableau
    $knownIdsArray = [];
    if ($knownIds && !empty($knownIds)) {
        $knownIdsArray = array_map('intval', explode(',', $knownIds));
    }
    
    // Champs optimisés pour la synchronisation delta
    $baseFields = [
        'o.id', 'o.type', 'o.montant_brut', 'o.montant_net', 'o.commission', 'o.devise',
        'o.code_ops', 'o.client_id', 'o.client_nom', 'o.agent_id',
        'o.shop_source_id', 'o.shop_destination_id', 'o.destinataire',
        'o.telephone_destinataire', 'o.reference', 'o.mode_paiement', 'o.statut',
        'o.created_at', 'o.last_modified_at', 'o.is_administrative'
    ];
    
    $fieldList = implode(', ', $baseFields);
    $params = [];
    
    // LOGIQUE DELTA SYNC INTELLIGENTE
    if ($syncMode === 'delta' && !empty($knownIdsArray)) {
        
        // 1. NOUVELLES OPÉRATIONS (pas dans known_ids)
        $newOperationsSql = "SELECT $fieldList FROM operations o WHERE 1=1";
        
        if ($since && !empty($since)) {
            $newOperationsSql .= " AND o.created_at > :since_new";
            $params[':since_new'] = $since;
        }
        
        // Exclure les IDs déjà connus
        $placeholders = str_repeat('?,', count($knownIdsArray) - 1) . '?';
        $newOperationsSql .= " AND o.id NOT IN ($placeholders)";
        
        // 2. OPÉRATIONS MODIFIÉES (dans known_ids mais modifiées)
        $updatedOperationsSql = "SELECT $fieldList FROM operations o WHERE 1=1";
        
        if ($since && !empty($since)) {
            $updatedOperationsSql .= " AND o.last_modified_at > :since_updated";
            $params[':since_updated'] = $since;
        }
        
        // Inclure seulement les IDs connus qui ont été modifiés
        $updatedOperationsSql .= " AND o.id IN ($placeholders)";
        $updatedOperationsSql .= " AND o.last_modified_at > o.created_at"; // Modifiées après création
        
        // Combiner les deux requêtes avec UNION
        $sql = "($newOperationsSql) UNION ($updatedOperationsSql)";
        
        // Paramètres pour les deux parties de l'UNION
        $allParams = array_merge($params, $knownIdsArray, $knownIdsArray);
        
    } else if ($syncMode === 'updates_only' && !empty($knownIdsArray)) {
        
        // SEULEMENT LES MISES À JOUR des opérations connues
        $sql = "SELECT $fieldList FROM operations o WHERE 1=1";
        
        if ($since && !empty($since)) {
            $sql .= " AND o.last_modified_at > :since";
            $params[':since'] = $since;
        }
        
        $placeholders = str_repeat('?,', count($knownIdsArray) - 1) . '?';
        $sql .= " AND o.id IN ($placeholders)";
        $sql .= " AND o.last_modified_at > o.created_at"; // Seulement les modifiées
        
        $allParams = array_merge($params, $knownIdsArray);
        
    } else {
        
        // MODE FULL (synchronisation complète)
        $sql = "SELECT $fieldList FROM operations o WHERE 1=1";
        
        if ($since && !empty($since)) {
            $sql .= " AND o.last_modified_at > :since";
            $params[':since'] = $since;
        }
        
        $allParams = $params;
    }
    
    // Filtrage par statut spécifique
    if ($statusFilter && !empty($statusFilter)) {
        $statuses = explode(',', $statusFilter);
        $statusPlaceholders = str_repeat('?,', count($statuses) - 1) . '?';
        $sql .= " AND o.statut IN ($statusPlaceholders)";
        $allParams = array_merge($allParams, $statuses);
    }
    
    // Logique de filtrage par rôle
    if ($userRole !== 'admin' && $shopId) {
        $sql .= " AND (o.shop_source_id = ? OR (o.shop_destination_id = ? AND o.type IN ('transfert_national', 'transfert_international_entrant')))";
        $allParams[] = $shopId;
        $allParams[] = $shopId;
    } else if ($userRole !== 'admin' && !$shopId) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Accès refusé: Agent sans shop_id affecté'
        ]);
        exit();
    }
    
    // Ajouter l'ordre et la pagination
    $sql .= " ORDER BY o.last_modified_at DESC LIMIT ? OFFSET ?";
    $allParams[] = $pagination['limit'];
    $allParams[] = $pagination['offset'];
    
    // Exécuter la requête
    $stmt = $pdo->prepare($sql);
    $stmt->execute($allParams);
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats
    $formattedOperations = [];
    $newOperations = [];
    $updatedOperations = [];
    
    foreach ($operations as $op) {
        $formatted = [
            'id' => (int)$op['id'],
            'type' => $op['type'],
            'montant_brut' => (float)$op['montant_brut'],
            'montant_net' => (float)$op['montant_net'],
            'commission' => (float)$op['commission'],
            'devise' => $op['devise'],
            'code_ops' => $op['code_ops'],
            'client_id' => $op['client_id'] ? (int)$op['client_id'] : null,
            'client_nom' => $op['client_nom'],
            'agent_id' => $op['agent_id'] ? (int)$op['agent_id'] : null,
            'shop_source_id' => $op['shop_source_id'] ? (int)$op['shop_source_id'] : null,
            'shop_destination_id' => $op['shop_destination_id'] ? (int)$op['shop_destination_id'] : null,
            'destinataire' => $op['destinataire'],
            'telephone_destinataire' => $op['telephone_destinataire'],
            'reference' => $op['reference'],
            'mode_paiement' => $op['mode_paiement'],
            'statut' => $op['statut'],
            'created_at' => $op['created_at'],
            'last_modified_at' => $op['last_modified_at'],
            'is_administrative' => (bool)$op['is_administrative'],
            'sync_action' => 'unknown' // Sera déterminé ci-dessous
        ];
        
        // Déterminer le type d'action de synchronisation
        if (in_array($formatted['id'], $knownIdsArray)) {
            $formatted['sync_action'] = 'update';
            $updatedOperations[] = $formatted;
        } else {
            $formatted['sync_action'] = 'new';
            $newOperations[] = $formatted;
        }
        
        $formattedOperations[] = $formatted;
    }
    
    // Calculer un hash de synchronisation pour validation
    $operationIds = array_column($formattedOperations, 'id');
    sort($operationIds);
    $syncHash = md5(implode(',', $operationIds) . $since);
    
    // Statistiques de synchronisation
    $syncStats = [
        'total_operations' => count($formattedOperations),
        'new_operations' => count($newOperations),
        'updated_operations' => count($updatedOperations),
        'sync_mode' => $syncMode,
        'known_ids_count' => count($knownIdsArray),
        'sync_hash' => $syncHash,
        'timestamp' => date('c')
    ];
    
    // Réponse optimisée
    $response = [
        'success' => true,
        'entities' => $formattedOperations,
        'new_operations' => $newOperations,
        'updated_operations' => $updatedOperations,
        'sync_stats' => $syncStats,
        'pagination' => [
            'limit' => $pagination['limit'],
            'offset' => $pagination['offset'],
            'has_more' => count($formattedOperations) === $pagination['limit']
        ]
    ];
    
    // Métriques de performance
    $executionTime = microtime(true) - $startTime;
    ApiOptimizer::logMetrics('operations/delta_sync', $executionTime, strlen(json_encode($response)), count($formattedOperations));
    
    if (DEBUG_MODE === 'true') {
        $response['debug'] = [
            'execution_time_ms' => round($executionTime * 1000, 2),
            'sql_query' => $sql,
            'params_count' => count($allParams)
        ];
    }
    
    echo ApiOptimizer::compressResponse($response);
    
} catch (Exception $e) {
    error_log("Erreur Delta Sync: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur lors de la synchronisation delta',
        'error' => DEBUG_MODE === 'true' ? $e->getMessage() : 'Erreur interne'
    ]);
}
?>
