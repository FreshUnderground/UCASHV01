<?php
/**
 * API spécialisée pour la synchronisation des validations d'opérations
 * Optimisée pour détecter rapidement les changements de statut entre agents
 */

$startTime = microtime(true);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/ApiOptimizer.php';

try {
    // Paramètres de base
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    
    // Paramètres spécifiques aux validations
    $lastValidationCheck = $_GET['last_validation_check'] ?? null;
    $myOperationsOnly = $_GET['my_operations_only'] ?? 'false'; // Seulement mes opérations initiées
    $validationWindow = (int)($_GET['validation_window'] ?? 24); // Fenêtre en heures
    
    $pagination = ApiOptimizer::validatePagination(
        $_GET['limit'] ?? 50, // Limite plus petite pour les validations
        $_GET['offset'] ?? null
    );
    
    error_log("🔍 VALIDATION SYNC - User: $userId, Window: {$validationWindow}h");
    
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants'
        ]);
        exit();
    }
    
    // Champs optimisés pour les validations
    $fields = [
        'o.id', 'o.type', 'o.montant_brut', 'o.montant_net', 'o.commission', 'o.devise',
        'o.code_ops', 'o.client_nom', 'o.destinataire', 'o.reference',
        'o.statut', 'o.created_at', 'o.last_modified_at',
        'o.agent_id', 'o.shop_source_id', 'o.shop_destination_id',
        'o.is_administrative'
    ];
    
    $fieldList = implode(', ', $fields);
    $sql = "SELECT $fieldList FROM operations o WHERE 1=1";
    $params = [];
    
    // FILTRAGE SPÉCIALISÉ POUR LES VALIDATIONS
    
    // 1. Opérations modifiées récemment (validations/annulations)
    $sql .= " AND o.last_modified_at > o.created_at";
    
    // 2. Fenêtre temporelle pour les validations
    $sql .= " AND o.last_modified_at > DATE_SUB(NOW(), INTERVAL :validation_window HOUR)";
    $params[':validation_window'] = $validationWindow;
    
    // 3. Filtrage par timestamp de dernière vérification
    if ($lastValidationCheck && !empty($lastValidationCheck)) {
        $sql .= " AND o.last_modified_at > :last_check";
        $params[':last_check'] = $lastValidationCheck;
    }
    
    // 4. Seulement mes opérations initiées (optionnel)
    if ($myOperationsOnly === 'true') {
        $sql .= " AND o.agent_id = :my_agent_id";
        $params[':my_agent_id'] = $userId;
    }
    
    // 5. Focus sur les changements de statut critiques
    $sql .= " AND o.statut IN ('servi', 'annule', 'en_attente', 'refuse')";
    
    // Filtrage par rôle et shop (sécurité)
    if ($userRole !== 'admin' && $shopId) {
        $sql .= " AND (o.shop_source_id = :shopId OR (o.shop_destination_id = :shopId2 AND o.type IN ('transfert_national', 'transfert_international_entrant')))";
        $params[':shopId'] = $shopId;
        $params[':shopId2'] = $shopId;
    } else if ($userRole !== 'admin' && !$shopId) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Accès refusé: Agent sans shop_id'
        ]);
        exit();
    }
    
    // Compter le total
    $countSql = str_replace($fieldList, 'COUNT(*)', $sql);
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalRecords = $countStmt->fetchColumn();
    
    // Ordre prioritaire : les plus récemment modifiées en premier
    $sql .= " ORDER BY o.last_modified_at DESC LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $pagination['limit'], PDO::PARAM_INT);
    $stmt->bindValue(':offset', $pagination['offset'], PDO::PARAM_INT);
    
    $stmt->execute();
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Analyser les types de validations
    $validationStats = [
        'nouvellement_servies' => 0,
        'nouvellement_annulees' => 0,
        'nouvellement_refusees' => 0,
        'mes_operations_validees' => 0,
        'operations_autres_agents' => 0,
        'validations_recentes' => 0
    ];
    
    $formattedOperations = [];
    $now = new DateTime();
    
    foreach ($operations as $op) {
        $formatted = [
            'id' => (int)$op['id'],
            'type' => $op['type'],
            'montant_brut' => (float)$op['montant_brut'],
            'montant_net' => (float)$op['montant_net'],
            'commission' => (float)$op['commission'],
            'devise' => $op['devise'],
            'code_ops' => $op['code_ops'],
            'client_nom' => $op['client_nom'],
            'destinataire' => $op['destinataire'],
            'reference' => $op['reference'],
            'statut' => $op['statut'],
            'created_at' => $op['created_at'],
            'last_modified_at' => $op['last_modified_at'],
            'agent_id' => $op['agent_id'] ? (int)$op['agent_id'] : null,
            'shop_source_id' => $op['shop_source_id'] ? (int)$op['shop_source_id'] : null,
            'shop_destination_id' => $op['shop_destination_id'] ? (int)$op['shop_destination_id'] : null,
            'is_administrative' => (bool)$op['is_administrative']
        ];
        
        // Déterminer le type de validation
        $isMyOperation = ($op['agent_id'] == $userId);
        $modifiedAt = new DateTime($op['last_modified_at']);
        $timeSinceModification = $now->diff($modifiedAt);
        
        // Ajouter des métadonnées de validation
        $formatted['validation_info'] = [
            'is_my_operation' => $isMyOperation,
            'hours_since_validation' => $timeSinceModification->h + ($timeSinceModification->days * 24),
            'validation_type' => $isMyOperation ? 'my_operation_validated' : 'other_agent_validation'
        ];
        
        // Statistiques
        switch ($op['statut']) {
            case 'servi':
                $validationStats['nouvellement_servies']++;
                break;
            case 'annule':
                $validationStats['nouvellement_annulees']++;
                break;
            case 'refuse':
                $validationStats['nouvellement_refusees']++;
                break;
        }
        
        if ($isMyOperation) {
            $validationStats['mes_operations_validees']++;
        } else {
            $validationStats['operations_autres_agents']++;
        }
        
        if ($timeSinceModification->h < 2) {
            $validationStats['validations_recentes']++;
        }
        
        $formattedOperations[] = $formatted;
    }
    
    // Réponse spécialisée pour les validations
    $response = [
        'success' => true,
        'validations' => $formattedOperations,
        'count' => count($formattedOperations),
        'total_validations' => $totalRecords,
        'validation_stats' => $validationStats,
        'sync_info' => [
            'validation_window_hours' => $validationWindow,
            'last_check' => $lastValidationCheck,
            'my_operations_only' => $myOperationsOnly === 'true',
            'next_check_timestamp' => date('c')
        ],
        'pagination' => [
            'limit' => $pagination['limit'],
            'offset' => $pagination['offset'],
            'has_more' => ($pagination['offset'] + $pagination['limit']) < $totalRecords
        ],
        'timestamp' => date('c')
    ];
    
    // Recommandations basées sur les validations
    $recommendations = [];
    
    if ($validationStats['mes_operations_validees'] > 0) {
        $recommendations[] = "✅ {$validationStats['mes_operations_validees']} de vos opérations ont été validées";
    }
    
    if ($validationStats['validations_recentes'] > 5) {
        $recommendations[] = "⚡ Beaucoup de validations récentes - vérifier les notifications";
    }
    
    if ($validationStats['nouvellement_annulees'] > 0) {
        $recommendations[] = "⚠️ {$validationStats['nouvellement_annulees']} opérations annulées - vérifier les raisons";
    }
    
    $response['recommendations'] = $recommendations;
    
    // Métriques de performance
    $executionTime = microtime(true) - $startTime;
    ApiOptimizer::logMetrics('operations/validation_sync', $executionTime, strlen(json_encode($response)), count($formattedOperations));
    
    if (DEBUG_MODE === 'true') {
        $response['debug'] = [
            'execution_time_ms' => round($executionTime * 1000, 2),
            'sql_query' => $sql,
            'params' => $params
        ];
    }
    
    echo ApiOptimizer::compressResponse($response);
    
} catch (Exception $e) {
    error_log("Erreur Validation Sync: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur lors de la synchronisation des validations',
        'error' => DEBUG_MODE === 'true' ? $e->getMessage() : 'Erreur interne'
    ]);
}
?>
