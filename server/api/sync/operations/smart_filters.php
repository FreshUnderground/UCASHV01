<?php
/**
 * API avec filtres intelligents pour éviter le retéléchargement
 * Système de filtrage avancé par statut, date et modifications
 */

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
    $since = $_GET['since'] ?? null;
    
    // NOUVEAUX FILTRES INTELLIGENTS
    $filterStrategy = $_GET['filter_strategy'] ?? 'smart'; // smart, status_based, time_based, hybrid
    $excludeStatuses = $_GET['exclude_statuses'] ?? null; // Statuts à exclure (ex: "servi,annule")
    $includeOnlyStatuses = $_GET['include_only_statuses'] ?? null; // Seulement ces statuts
    $modifiedSince = $_GET['modified_since'] ?? null; // Seulement les modifiées depuis X
    $createdSince = $_GET['created_since'] ?? null; // Seulement les créées depuis X
    $priorityMode = $_GET['priority_mode'] ?? 'balanced'; // critical, balanced, all
    
    $pagination = ApiOptimizer::validatePagination(
        $_GET['limit'] ?? null,
        $_GET['offset'] ?? null
    );
    
    error_log("🎯 SMART FILTERS - Strategy: $filterStrategy, Priority: $priorityMode");
    
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants'
        ]);
        exit();
    }
    
    // Champs optimisés
    $fields = [
        'o.id', 'o.type', 'o.montant_brut', 'o.montant_net', 'o.commission', 'o.devise',
        'o.code_ops', 'o.client_id', 'o.client_nom', 'o.agent_id',
        'o.shop_source_id', 'o.shop_destination_id', 'o.destinataire',
        'o.telephone_destinataire', 'o.reference', 'o.mode_paiement', 'o.statut',
        'o.created_at', 'o.last_modified_at', 'o.is_administrative'
    ];
    
    $fieldList = implode(', ', $fields);
    $sql = "SELECT $fieldList FROM operations o WHERE 1=1";
    $params = [];
    
    // STRATÉGIES DE FILTRAGE INTELLIGENTES
    
    if ($filterStrategy === 'smart') {
        // STRATÉGIE INTELLIGENTE : Priorise les opérations critiques
        
        switch ($priorityMode) {
            case 'critical':
                // SEULEMENT les opérations critiques (en attente + modifications récentes)
                $sql .= " AND (
                    o.statut = 'en_attente' 
                    OR (o.last_modified_at > DATE_SUB(NOW(), INTERVAL 2 HOUR) AND o.last_modified_at > o.created_at)
                )";
                break;
                
            case 'balanced':
                // ÉQUILIBRÉ : En attente + servis/annulés récents + modifications
                $sql .= " AND (
                    o.statut = 'en_attente'
                    OR (o.statut IN ('servi', 'annule') AND o.last_modified_at > DATE_SUB(NOW(), INTERVAL 24 HOUR))
                    OR (o.last_modified_at > DATE_SUB(NOW(), INTERVAL 6 HOUR) AND o.last_modified_at > o.created_at)
                )";
                break;
                
            case 'all':
                // TOUS avec filtre temporel
                if ($since) {
                    $sql .= " AND o.last_modified_at > :since";
                    $params[':since'] = $since;
                }
                break;
        }
        
    } else if ($filterStrategy === 'status_based') {
        // FILTRAGE PAR STATUT
        
        if ($includeOnlyStatuses) {
            $statuses = explode(',', $includeOnlyStatuses);
            $placeholders = str_repeat('?,', count($statuses) - 1) . '?';
            $sql .= " AND o.statut IN ($placeholders)";
            $params = array_merge($params, $statuses);
        }
        
        if ($excludeStatuses) {
            $excludedStatuses = explode(',', $excludeStatuses);
            $placeholders = str_repeat('?,', count($excludedStatuses) - 1) . '?';
            $sql .= " AND o.statut NOT IN ($placeholders)";
            $params = array_merge($params, $excludedStatuses);
        }
        
    } else if ($filterStrategy === 'time_based') {
        // FILTRAGE TEMPOREL AVANCÉ
        
        if ($modifiedSince) {
            $sql .= " AND o.last_modified_at > :modified_since";
            $params[':modified_since'] = $modifiedSince;
        }
        
        if ($createdSince) {
            $sql .= " AND o.created_at > :created_since";
            $params[':created_since'] = $createdSince;
        }
        
        // Filtre pour les opérations modifiées (pas seulement créées)
        if ($_GET['only_modified'] === 'true') {
            $sql .= " AND o.last_modified_at > o.created_at";
        }
        
    } else if ($filterStrategy === 'hybrid') {
        // STRATÉGIE HYBRIDE : Combine plusieurs approches
        
        $conditions = [];
        
        // 1. Toujours inclure les en attente
        $conditions[] = "o.statut = 'en_attente'";
        
        // 2. Opérations récemment modifiées
        if ($modifiedSince) {
            $conditions[] = "o.last_modified_at > :modified_since";
            $params[':modified_since'] = $modifiedSince;
        } else {
            $conditions[] = "(o.last_modified_at > DATE_SUB(NOW(), INTERVAL 4 HOUR) AND o.last_modified_at > o.created_at)";
        }
        
        // 3. Opérations servis/annulés récents
        $conditions[] = "(o.statut IN ('servi', 'annule') AND o.last_modified_at > DATE_SUB(NOW(), INTERVAL 12 HOUR))";
        
        // 4. Nouvelles opérations
        if ($createdSince) {
            $conditions[] = "o.created_at > :created_since";
            $params[':created_since'] = $createdSince;
        }
        
        $sql .= " AND (" . implode(' OR ', $conditions) . ")";
    }
    
    // Filtrage par rôle (sécurité)
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
    
    // Ajouter ordre et pagination
    $sql .= " ORDER BY 
        CASE 
            WHEN o.statut = 'en_attente' THEN 1
            WHEN o.last_modified_at > o.created_at THEN 2
            ELSE 3
        END,
        o.last_modified_at DESC 
        LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $pagination['limit'], PDO::PARAM_INT);
    $stmt->bindValue(':offset', $pagination['offset'], PDO::PARAM_INT);
    
    $stmt->execute();
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater et analyser les résultats
    $formattedOperations = [];
    $stats = [
        'en_attente' => 0,
        'servi' => 0,
        'annule' => 0,
        'modified_operations' => 0,
        'new_operations' => 0
    ];
    
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
        
        // Statistiques
        $stats[$op['statut']] = ($stats[$op['statut']] ?? 0) + 1;
        
        if ($op['last_modified_at'] > $op['created_at']) {
            $stats['modified_operations']++;
        } else {
            $stats['new_operations']++;
        }
        
        $formattedOperations[] = $formatted;
    }
    
    // Réponse avec métadonnées de filtrage
    $response = [
        'success' => true,
        'entities' => $formattedOperations,
        'count' => count($formattedOperations),
        'total_records' => $totalRecords,
        'filter_info' => [
            'strategy' => $filterStrategy,
            'priority_mode' => $priorityMode,
            'applied_filters' => [
                'exclude_statuses' => $excludeStatuses,
                'include_only_statuses' => $includeOnlyStatuses,
                'modified_since' => $modifiedSince,
                'created_since' => $createdSince
            ]
        ],
        'statistics' => $stats,
        'pagination' => [
            'limit' => $pagination['limit'],
            'offset' => $pagination['offset'],
            'has_more' => ($pagination['offset'] + $pagination['limit']) < $totalRecords
        ],
        'timestamp' => date('c')
    ];
    
    // Recommandations pour la prochaine synchronisation
    $recommendations = [];
    
    if ($stats['en_attente'] > 50) {
        $recommendations[] = "Beaucoup d'opérations en attente - considérer filter_strategy=critical";
    }
    
    if ($stats['modified_operations'] > $stats['new_operations'] * 2) {
        $recommendations[] = "Beaucoup de modifications - utiliser modified_since pour optimiser";
    }
    
    if ($totalRecords > 1000) {
        $recommendations[] = "Volume élevé - réduire la fenêtre temporelle ou utiliser pagination";
    }
    
    $response['recommendations'] = $recommendations;
    
    echo ApiOptimizer::compressResponse($response);
    
} catch (Exception $e) {
    error_log("Erreur Smart Filters: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur lors du filtrage intelligent',
        'error' => DEBUG_MODE === 'true' ? $e->getMessage() : 'Erreur interne'
    ]);
}
?>
