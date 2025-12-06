<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les paramètres de filtre
    $shop_id = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000; // Limite par défaut
    $days = isset($_GET['days']) ? intval($_GET['days']) : 4; // Nombre de jours (défaut: 4)
    $type_filter = isset($_GET['type']) ? $_GET['type'] : null; // NOUVEAU: Filtre par type (ex: flotShopToShop)
    
    // Calculer la date limite (4 derniers jours par défaut)
    $date_limit = date('Y-m-d H:i:s', strtotime("-$days days"));
    
    // Construire la requête SQL
    if ($shop_id !== null && $shop_id > 0) {
        // Mode AGENT: Filtrer par shop (source OU destination) + type optionnel + jours
        $type_condition = '';
        if ($type_filter !== null && !empty($type_filter)) {
            $type_condition = 'AND o.type = :type_filter';
            error_log("[ALL-OPERATIONS] Filtre type actif: $type_filter");
        }
        
        error_log("[ALL-OPERATIONS] Mode AGENT: shop_id=$shop_id, limit=$limit, days=$days (depuis $date_limit)");
        
        $query = "SELECT 
                    o.id, o.type, o.montant_brut, o.montant_net, o.commission, o.devise,
                    o.code_ops, o.client_id, o.client_nom,
                    o.agent_id, o.agent_username,
                    o.shop_source_id, o.shop_source_designation,
                    o.shop_destination_id, o.shop_destination_designation,
                    o.destinataire, o.telephone_destinataire, o.reference,
                    o.mode_paiement, o.statut, o.notes,
                    o.created_at, o.last_modified_at, o.last_modified_by,
                    o.is_synced, o.synced_at
                  FROM operations o
                  WHERE (o.shop_source_id = :shop_id OR o.shop_destination_id = :shop_id2)
                    AND o.created_at >= :date_limit
                    $type_condition
                  ORDER BY o.last_modified_at DESC
                  LIMIT :limit";
        
        $stmt = $pdo->prepare($query);
        $stmt->bindValue(':shop_id', $shop_id, PDO::PARAM_INT);
        $stmt->bindValue(':shop_id2', $shop_id, PDO::PARAM_INT);
        $stmt->bindValue(':date_limit', $date_limit, PDO::PARAM_STR);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        if ($type_filter !== null && !empty($type_filter)) {
            $stmt->bindValue(':type_filter', $type_filter, PDO::PARAM_STR);
        }
    } else {
        // Mode ADMIN: Récupérer TOUTES les opérations + filtre type optionnel + jours
        $type_condition = '';
        if ($type_filter !== null && !empty($type_filter)) {
            $type_condition = 'AND o.type = :type_filter';
        }
        
        error_log("[ALL-OPERATIONS] Mode ADMIN: toutes les opérations, limit=$limit, days=$days (depuis $date_limit)");;
        
        $query = "SELECT 
                    o.id, o.type, o.montant_brut, o.montant_net, o.commission, o.devise,
                    o.code_ops, o.client_id, o.client_nom,
                    o.agent_id, o.agent_username,
                    o.shop_source_id, o.shop_source_designation,
                    o.shop_destination_id, o.shop_destination_designation,
                    o.destinataire, o.telephone_destinataire, o.reference,
                    o.mode_paiement, o.statut, o.notes,
                    o.created_at, o.last_modified_at, o.last_modified_by,
                    o.is_synced, o.synced_at
                  FROM operations o
                  WHERE o.created_at >= :date_limit
                  $type_condition
                  ORDER BY o.last_modified_at DESC
                  LIMIT :limit";
        
        $stmt = $pdo->prepare($query);
        $stmt->bindValue(':date_limit', $date_limit, PDO::PARAM_STR);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        if ($type_filter !== null && !empty($type_filter)) {
            $stmt->bindValue(':type_filter', $type_filter, PDO::PARAM_STR);
        }
    }
    
    $stmt->execute();
    
    $operations = [];
    
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $operations[] = [
            'id' => (int)$row['id'],
            'type' => $row['type'],
            'code_ops' => $row['code_ops'],
            'reference' => $row['reference'],
            'date_op' => $row['created_at'], // Utiliser created_at comme date_op
            'shop_id' => $row['shop_source_id'] ? (int)$row['shop_source_id'] : null,
            'shop_source_id' => $row['shop_source_id'] ? (int)$row['shop_source_id'] : null,
            'shop_destination_id' => $row['shop_destination_id'] ? (int)$row['shop_destination_id'] : null,
            'shop_source_designation' => $row['shop_source_designation'],
            'shop_destination_designation' => $row['shop_destination_designation'],
            'client_id' => $row['client_id'] ? (int)$row['client_id'] : null,
            'client_nom' => $row['client_nom'],
            'agent_id' => $row['agent_id'] ? (int)$row['agent_id'] : null,
            'agent_username' => $row['agent_username'],
            'montant_brut' => (float)$row['montant_brut'],
            'montant_net' => (float)$row['montant_net'],
            'commission' => (float)$row['commission'],
            'devise' => $row['devise'],
            'statut' => $row['statut'],
            'mode_paiement' => $row['mode_paiement'],
            'destinataire' => $row['destinataire'],
            'telephone_destinataire' => $row['telephone_destinataire'],
            'notes' => $row['notes'],
            'created_at' => $row['created_at'],
            'last_modified_at' => $row['last_modified_at'],
            'last_modified_by' => $row['last_modified_by'],
            'is_synced' => (bool)$row['is_synced'],
            'synced_at' => $row['synced_at'],
        ];
    }
    
    $mode = ($shop_id !== null && $shop_id > 0) ? "AGENT (shop $shop_id)" : "ADMIN (tous les shops)";
    error_log("[ALL-OPERATIONS] Mode: $mode, Opérations trouvées: " . count($operations));
    
    echo json_encode([
        'success' => true,
        'operations' => $operations,
        'count' => count($operations),
        'mode' => $mode,
        'days' => $days,
        'date_limit' => $date_limit,
        'message' => count($operations) . ' opération(s) trouvée(s) (derniers ' . $days . ' jours)'
    ]);
    
} catch (PDOException $e) {
    error_log("[ALL-OPERATIONS] Erreur PDO: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
