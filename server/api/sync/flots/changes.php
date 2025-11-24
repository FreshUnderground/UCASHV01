<?php
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

require_once '../../../config/database.php';
require_once '../../../classes/Database.php';

// Fonction de conversion enum SQL vers index Flutter
function _convertModePaiementToIndex($mode) {
    // MySQL ENUM: 'cash', 'airtelMoney', 'mPesa', 'orangeMoney'
    // Flutter enum: cash=0, airtelMoney=1, mPesa=2, orangeMoney=3
    $modes = ['cash' => 0, 'airtelMoney' => 1, 'mPesa' => 2, 'orangeMoney' => 3];
    return $modes[$mode] ?? 0;
}

function _convertStatutFlotToIndex($statut) {
    // MySQL ENUM: 'enRoute', 'servi', 'annule'
    // Flutter enum: enRoute=0, servi=1, annule=2
    $statuts = ['enRoute' => 0, 'servi' => 1, 'annule' => 2];
    return $statuts[$statut] ?? 0;
}

try {
    $db = Database::getInstance();
    $pdo = $db->getConnection();
    
    // Paramètres de la requête
    $since = $_GET['since'] ?? null;
    $shopId = $_GET['shop_id'] ?? null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 1000;
    
    // Construction de la requête SQL
    $sql = "SELECT * FROM flots WHERE 1=1";
    $params = [];
    
    // Filtrer par shop et date selon le contexte
    if ($shopId && $shopId !== 'null' && $shopId !== '') {
        $shopIdInt = (int)$shopId;
        
        if ($since) {
            // Convertir le timestamp en format MySQL
            $sinceDate = date('Y-m-d H:i:s', strtotime($since));
            
            // Logique de synchronisation incrémentale :
            // 1. Flots REÇUS (enRoute) : envoyés par d'autres VERS vous → shop_destination_id = vous → filtrer par date_envoi
            // 2. Flots SERVIS : envoyés PAR vous et reçus par d'autres → shop_source_id = vous → filtrer par date_reception
            $sql .= " AND (";
            $sql .= "(shop_destination_id = :shop_id AND date_envoi >= :since_envoi)";
            $sql .= " OR ";
            $sql .= "(shop_source_id = :shop_id2 AND date_reception IS NOT NULL AND date_reception >= :since_reception)";
            $sql .= ")";
            
            $params[':shop_id'] = $shopIdInt;
            $params[':shop_id2'] = $shopIdInt;
            $params[':since_envoi'] = $sinceDate;
            $params[':since_reception'] = $sinceDate;
        } else {
            // Sans filtre de date, récupérer tous les flots liés au shop
            $sql .= " AND (shop_source_id = :shop_id OR shop_destination_id = :shop_id)";
            $params[':shop_id'] = $shopIdInt;
        }
    } else if ($since) {
        // Si pas de shop_id mais filtre de date (cas admin)
        $sinceDate = date('Y-m-d H:i:s', strtotime($since));
        $sql .= " AND (date_envoi >= :since OR (date_reception IS NOT NULL AND date_reception >= :since2))";
        $params[':since'] = $sinceDate;
        $params[':since2'] = $sinceDate;
    }
    
    // Ordre et limite
    $sql .= " ORDER BY date_envoi DESC, id DESC LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $flots = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les enums pour Flutter
    foreach ($flots as &$flot) {
        // Convertir mode_paiement
        if (isset($flot['mode_paiement'])) {
            $flot['mode_paiement'] = _convertModePaiementToIndex($flot['mode_paiement']);
        }
        
        // Convertir statut
        if (isset($flot['statut'])) {
            $flot['statut'] = _convertStatutFlotToIndex($flot['statut']);
        }
        
        // Convertir les dates au format ISO 8601 pour Flutter
        if (isset($flot['date_envoi'])) {
            $flot['date_envoi'] = date('c', strtotime($flot['date_envoi']));
        }
        
        if (isset($flot['date_reception']) && !empty($flot['date_reception'])) {
            $flot['date_reception'] = date('c', strtotime($flot['date_reception']));
        } else {
            $flot['date_reception'] = null;
        }
        
        if (isset($flot['created_at'])) {
            $flot['created_at'] = date('c', strtotime($flot['created_at']));
        }
        
        if (isset($flot['last_modified_at'])) {
            $flot['last_modified_at'] = date('c', strtotime($flot['last_modified_at']));
        }
        
        if (isset($flot['synced_at']) && !empty($flot['synced_at'])) {
            $flot['synced_at'] = date('c', strtotime($flot['synced_at']));
        } else {
            $flot['synced_at'] = null;
        }
        
        // Convertir les valeurs numériques
        $flot['id'] = (int)$flot['id'];
        $flot['shop_source_id'] = (int)$flot['shop_source_id'];
        $flot['shop_destination_id'] = (int)$flot['shop_destination_id'];
        $flot['montant'] = (float)$flot['montant'];
        $flot['agent_envoyeur_id'] = (int)$flot['agent_envoyeur_id'];
        
        if (isset($flot['agent_recepteur_id']) && !empty($flot['agent_recepteur_id'])) {
            $flot['agent_recepteur_id'] = (int)$flot['agent_recepteur_id'];
        } else {
            $flot['agent_recepteur_id'] = null;
        }
        
        // Ajouter le flag is_synced
        $flot['is_synced'] = true;
    }
    
    $response = [
        'success' => true,
        'entities' => $flots,  // Utiliser 'entities' au lieu de 'flots' pour correspondre au code Dart
        'count' => count($flots),
        'timestamp' => date('c'),
        'filters' => [
            'since' => $since,
            'shop_id' => $shopId,
            'limit' => $limit
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
