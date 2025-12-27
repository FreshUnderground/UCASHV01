<?php
/**
 * Classe d'optimisation pour les API UCASH
 * Gère la compression, pagination, et limitation des données
 */

class ApiOptimizer {
    
    /**
     * Compresse la réponse JSON si activé
     */
    public static function compressResponse($data) {
        if (ENABLE_COMPRESSION === 'true' && function_exists('gzencode')) {
            $json = json_encode($data);
            
            // Vérifier si le client accepte la compression
            $acceptEncoding = $_SERVER['HTTP_ACCEPT_ENCODING'] ?? '';
            
            if (strpos($acceptEncoding, 'gzip') !== false) {
                header('Content-Encoding: gzip');
                return gzencode($json, COMPRESSION_LEVEL);
            }
        }
        
        return json_encode($data);
    }
    
    /**
     * Valide et limite les paramètres de pagination
     */
    public static function validatePagination($limit = null, $offset = null) {
        // Limite par défaut
        $limit = $limit ?? API_DEFAULT_LIMIT;
        
        // Validation de la limite
        $limit = max(1, min((int)$limit, API_MAX_RESULTS));
        
        // Validation de l'offset
        $offset = max(0, (int)($offset ?? 0));
        
        return [
            'limit' => $limit,
            'offset' => $offset
        ];
    }
    
    /**
     * Optimise la requête SQL pour réduire les données
     */
    public static function optimizeQuery($baseQuery, $fields = null) {
        if ($fields && is_array($fields)) {
            // Remplacer SELECT * par les champs spécifiques
            $fieldList = implode(', ', $fields);
            $baseQuery = preg_replace('/SELECT\s+\*/', "SELECT $fieldList", $baseQuery);
        }
        
        return $baseQuery;
    }
    
    /**
     * Applique le filtrage intelligent par statut et date
     */
    public static function applySmartFiltering($query, $params, $tableName) {
        $filterMode = $_GET['filter_mode'] ?? null;
        
        if ($filterMode === 'smart') {
            $pendingAll = $_GET['pending_all'] ?? 'false';
            $servedDays = (int)($_GET['served_days'] ?? 2);
            $cancelledDays = (int)($_GET['cancelled_days'] ?? 1);
            
            // Construire le filtre intelligent
            $smartFilter = " AND (";
            
            // EN ATTENTE: Toutes (critiques)
            if ($pendingAll === 'true') {
                if ($tableName === 'operations') {
                    $smartFilter .= "o.statut = 'en_attente'";
                } else {
                    $smartFilter .= "vt.statut = 'en_attente'";
                }
            }
            
            // SERVIS: X derniers jours
            if ($servedDays > 0) {
                $smartFilter .= " OR (";
                if ($tableName === 'operations') {
                    $smartFilter .= "o.statut = 'servi' AND o.last_modified_at >= DATE_SUB(NOW(), INTERVAL $servedDays DAY)";
                } else {
                    $smartFilter .= "vt.statut = 'validee' AND vt.date_validation >= DATE_SUB(NOW(), INTERVAL $servedDays DAY)";
                }
                $smartFilter .= ")";
            }
            
            // ANNULÉS: X derniers jours
            if ($cancelledDays > 0) {
                $smartFilter .= " OR (";
                if ($tableName === 'operations') {
                    $smartFilter .= "o.statut = 'annule' AND o.last_modified_at >= DATE_SUB(NOW(), INTERVAL $cancelledDays DAY)";
                } else {
                    $smartFilter .= "vt.statut = 'annulee' AND vt.last_modified_at >= DATE_SUB(NOW(), INTERVAL $cancelledDays DAY)";
                }
                $smartFilter .= ")";
            }
            
            $smartFilter .= ")";
            
            return $query . $smartFilter;
        }
        
        return $query;
    }
    
    /**
     * Formate la réponse avec métadonnées de pagination
     */
    public static function formatResponse($data, $total = null, $limit = null, $offset = null) {
        $response = [
            'success' => true,
            'entities' => $data,
            'count' => count($data),
            'timestamp' => date('c')
        ];
        
        // Ajouter métadonnées de pagination si disponibles
        if ($total !== null) {
            $response['pagination'] = [
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset,
                'has_more' => ($offset + $limit) < $total
            ];
        }
        
        return $response;
    }
    
    /**
     * Réduit les données redondantes (normalisation)
     */
    public static function normalizeData($data) {
        if (empty($data)) return $data;
        
        // Extraire les entités référencées fréquemment
        $shops = [];
        $agents = [];
        $clients = [];
        
        foreach ($data as &$item) {
            // Normaliser les shops
            if (isset($item['shop_source_designation'])) {
                $shopId = $item['shop_source_id'];
                if (!isset($shops[$shopId])) {
                    $shops[$shopId] = $item['shop_source_designation'];
                }
                unset($item['shop_source_designation']);
            }
            
            if (isset($item['shop_destination_designation'])) {
                $shopId = $item['shop_destination_id'];
                if (!isset($shops[$shopId])) {
                    $shops[$shopId] = $item['shop_destination_designation'];
                }
                unset($item['shop_destination_designation']);
            }
            
            // Normaliser les agents
            if (isset($item['agent_username'])) {
                $agentId = $item['agent_id'];
                if (!isset($agents[$agentId])) {
                    $agents[$agentId] = $item['agent_username'];
                }
                unset($item['agent_username']);
            }
        }
        
        return [
            'entities' => $data,
            'references' => [
                'shops' => $shops,
                'agents' => $agents,
                'clients' => $clients
            ]
        ];
    }
    
    /**
     * Log des métriques de performance
     */
    public static function logMetrics($endpoint, $executionTime, $dataSize, $recordCount) {
        if (DEBUG_MODE === 'true') {
            error_log(json_encode([
                'timestamp' => date('c'),
                'endpoint' => $endpoint,
                'execution_time_ms' => round($executionTime * 1000, 2),
                'data_size_kb' => round($dataSize / 1024, 2),
                'record_count' => $recordCount,
                'memory_usage_mb' => round(memory_get_usage(true) / 1024 / 1024, 2)
            ]));
        }
    }
}
