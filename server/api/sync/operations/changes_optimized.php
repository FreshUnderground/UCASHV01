<?php
/**
 * API optimisée pour la synchronisation des opérations
 * Gère la compression, pagination intelligente et filtrage par taille
 */

// Démarrer la mesure de performance
$startTime = microtime(true);

// Headers optimisés avec compression
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/ApiOptimizer.php';

try {
    // Récupérer et valider les paramètres
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    
    // Validation de pagination avec limites sécurisées
    $pagination = ApiOptimizer::validatePagination(
        $_GET['limit'] ?? null,
        $_GET['offset'] ?? null
    );
    
    // Paramètres de filtrage intelligent
    $fields = $_GET['fields'] ?? null; // Champs spécifiques à retourner
    $compress = $_GET['compress'] ?? 'true';
    
    error_log("📊 API Optimisée - limit: {$pagination['limit']}, offset: {$pagination['offset']}");
    
    // Validation des paramètres requis
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants: user_id et user_role',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Définir les champs optimisés (réduire la taille des données)
    $defaultFields = [
        'o.id', 'o.type', 'o.montant_brut', 'o.montant_net', 'o.commission', 'o.devise',
        'o.code_ops', 'o.client_id', 'o.client_nom', 'o.agent_id',
        'o.shop_source_id', 'o.shop_destination_id', 'o.destinataire',
        'o.telephone_destinataire', 'o.reference', 'o.mode_paiement', 'o.statut',
        'o.created_at', 'o.last_modified_at', 'o.is_administrative'
    ];
    
    // Champs étendus (seulement si demandés explicitement)
    $extendedFields = [
        'o.shop_source_designation', 'o.shop_destination_designation',
        'o.agent_username', 'o.notes', 'o.observation'
    ];
    
    $selectedFields = $defaultFields;
    if ($fields === 'extended') {
        $selectedFields = array_merge($defaultFields, $extendedFields);
    }
    
    // Construire la requête optimisée
    $fieldList = implode(', ', $selectedFields);
    $sql = "SELECT $fieldList FROM operations o WHERE 1=1";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND o.last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // Appliquer le filtrage intelligent par statut/date
    $sql = ApiOptimizer::applySmartFiltering($sql, $params, 'operations');
    
    // Logique de filtrage par rôle (optimisée)
    if ($userRole !== 'admin' && $shopId) {
        $sql .= " AND (o.shop_source_id = :shopId OR (o.shop_destination_id = :shopId2 AND o.type IN ('transfert_national', 'transfert_international_entrant')))";
        $params[':shopId'] = $shopId;
        $params[':shopId2'] = $shopId;
    } else if ($userRole !== 'admin' && !$shopId) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Accès refusé: Agent sans shop_id affecté',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Compter le total pour la pagination
    $countSql = str_replace($fieldList, 'COUNT(*)', $sql);
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalRecords = $countStmt->fetchColumn();
    
    // Ajouter pagination et ordre
    $sql .= " ORDER BY o.last_modified_at DESC LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $pagination['limit'], PDO::PARAM_INT);
    $stmt->bindValue(':offset', $pagination['offset'], PDO::PARAM_INT);
    
    $stmt->execute();
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats (optimisé)
    $formattedOperations = [];
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
            'is_administrative' => (bool)$op['is_administrative']
        ];
        
        // Ajouter les champs étendus si demandés
        if ($fields === 'extended') {
            if (isset($op['shop_source_designation'])) {
                $formatted['shop_source_designation'] = $op['shop_source_designation'];
            }
            if (isset($op['shop_destination_designation'])) {
                $formatted['shop_destination_designation'] = $op['shop_destination_designation'];
            }
            if (isset($op['agent_username'])) {
                $formatted['agent_username'] = $op['agent_username'];
            }
            if (isset($op['notes'])) {
                $formatted['notes'] = $op['notes'];
            }
            if (isset($op['observation'])) {
                $formatted['observation'] = $op['observation'];
            }
        }
        
        $formattedOperations[] = $formatted;
    }
    
    // Normaliser les données si demandé
    if ($compress === 'true' && count($formattedOperations) > 50) {
        $normalizedData = ApiOptimizer::normalizeData($formattedOperations);
        $responseData = ApiOptimizer::formatResponse(
            $normalizedData['entities'],
            $totalRecords,
            $pagination['limit'],
            $pagination['offset']
        );
        $responseData['references'] = $normalizedData['references'];
    } else {
        $responseData = ApiOptimizer::formatResponse(
            $formattedOperations,
            $totalRecords,
            $pagination['limit'],
            $pagination['offset']
        );
    }
    
    // Calculer les métriques de performance
    $executionTime = microtime(true) - $startTime;
    $responseJson = json_encode($responseData);
    $dataSize = strlen($responseJson);
    
    // Logger les métriques
    ApiOptimizer::logMetrics('operations/changes_optimized', $executionTime, $dataSize, count($formattedOperations));
    
    // Ajouter les métriques à la réponse si en mode debug
    if (DEBUG_MODE === 'true') {
        $responseData['debug'] = [
            'execution_time_ms' => round($executionTime * 1000, 2),
            'data_size_kb' => round($dataSize / 1024, 2),
            'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 2),
            'sql_query' => $sql
        ];
    }
    
    // Envoyer la réponse compressée
    echo ApiOptimizer::compressResponse($responseData);
    
} catch (Exception $e) {
    error_log("Erreur API operations optimisée: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur lors de la récupération des opérations',
        'error' => DEBUG_MODE === 'true' ? $e->getMessage() : 'Erreur interne',
        'timestamp' => date('c')
    ]);
}
?>
