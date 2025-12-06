<?php
/**
 * Endpoint pour télécharger TOUS les comptes spéciaux (FRAIS et DÉPENSES)
 * Cet endpoint est utilisé par l'admin pour obtenir une copie complète des données
 * Contrairement à changes.php qui retourne seulement les modifications depuis une date,
 * cet endpoint retourne TOUTES les données
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Méthode non autorisée. Utilisez GET.',
        'entities' => [],
        'count' => 0
    ]);
    exit();
}

// Vérifier que le fichier de config existe
if (!file_exists(__DIR__ . '/../../../config/database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier de configuration database.php introuvable',
        'entities' => [],
        'count' => 0
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    error_log("[COMPTES_SPECIAUX] Download ALL request received");
    
    // Récupérer les paramètres de requête
    $userId = $_GET['user_id'] ?? 'unknown';
    $userRole = $_GET['user_role'] ?? 'agent';
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $type = $_GET['type'] ?? null; // Optionnel: filtrer par type (FRAIS ou DEPENSE)
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10000; // Limite élevée par défaut
    $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
    
    error_log("[COMPTES_SPECIAUX] User: $userId, Role: $userRole, Shop: " . ($shopId ?? 'ALL') . ", Type: " . ($type ?? 'ALL'));
    
    // Construire la requête SQL
    $sql = "
        SELECT 
            id, type, type_transaction, montant, description,
            shop_id, date_transaction, operation_id,
            agent_id, agent_username,
            created_at, last_modified_at, last_modified_by,
            is_synced, synced_at
        FROM comptes_speciaux
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par type (FRAIS ou DEPENSE) si spécifié
    if ($type !== null && in_array(strtoupper($type), ['FRAIS', 'DEPENSE'])) {
        $sql .= " AND type = :type";
        $params[':type'] = strtoupper($type);
        error_log("[COMPTES_SPECIAUX] Filtrage par type: $type");
    }
    
    // Filtre par shop_id si l'utilisateur n'est pas admin
    if ($userRole !== 'admin' && $shopId !== null) {
        $sql .= " AND shop_id = :shop_id";
        $params[':shop_id'] = $shopId;
        error_log("[COMPTES_SPECIAUX] Filtrage par shop_id: $shopId (mode agent)");
    } else {
        error_log("[COMPTES_SPECIAUX] Mode ADMIN: téléchargement de TOUS les comptes spéciaux");
    }
    
    // Ordonner par date de transaction (les plus récents en premier)
    $sql .= " ORDER BY date_transaction DESC, id DESC";
    
    // Limiter les résultats
    $sql .= " LIMIT :limit OFFSET :offset";
    
    // Compter le total avant pagination
    $countSql = str_replace(
        "SELECT \n            id, type, type_transaction, montant, description,\n            shop_id, date_transaction, operation_id,\n            agent_id, agent_username,\n            created_at, last_modified_at, last_modified_by,\n            is_synced, synced_at",
        "SELECT COUNT(*) as total",
        $sql
    );
    // Retirer LIMIT et ORDER BY pour le COUNT
    $countSql = preg_replace('/ ORDER BY.*$/', '', $countSql);
    $countSql = preg_replace('/ LIMIT.*$/', '', $countSql);
    
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Exécuter la requête principale
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[COMPTES_SPECIAUX] Transactions trouvées: " . count($transactions) . " / $totalCount total");
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedTransactions = [];
    $totalFrais = 0;
    $totalDepense = 0;
    
    foreach ($transactions as $t) {
        $formatted = [
            'id' => (int)$t['id'],
            'type' => $t['type'],
            'type_transaction' => $t['type_transaction'],
            'montant' => (float)$t['montant'],
            'description' => $t['description'],
            'shop_id' => $t['shop_id'] !== null ? (int)$t['shop_id'] : null,
            'date_transaction' => $t['date_transaction'],
            'operation_id' => $t['operation_id'] !== null ? (int)$t['operation_id'] : null,
            'agent_id' => $t['agent_id'] !== null ? (int)$t['agent_id'] : null,
            'agent_username' => $t['agent_username'],
            'created_at' => $t['created_at'],
            'last_modified_at' => $t['last_modified_at'],
            'last_modified_by' => $t['last_modified_by'],
            'is_synced' => (bool)$t['is_synced'],
            'synced_at' => $t['synced_at'],
        ];
        
        $formattedTransactions[] = $formatted;
        
        // Calculer les totaux
        if ($t['type'] === 'FRAIS') {
            $totalFrais += (float)$t['montant'];
        } else {
            $totalDepense += (float)$t['montant'];
        }
    }
    
    // Calculer les statistiques par type
    $statsSql = "
        SELECT 
            type,
            COUNT(*) as nombre,
            SUM(montant) as total
        FROM comptes_speciaux
        WHERE 1=1
    ";
    if ($userRole !== 'admin' && $shopId !== null) {
        $statsSql .= " AND shop_id = :shop_id";
    }
    $statsSql .= " GROUP BY type";
    
    $statsStmt = $pdo->prepare($statsSql);
    if ($userRole !== 'admin' && $shopId !== null) {
        $statsStmt->bindValue(':shop_id', $shopId);
    }
    $statsStmt->execute();
    $statsRows = $statsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    $stats = [
        'FRAIS' => ['nombre' => 0, 'total' => 0],
        'DEPENSE' => ['nombre' => 0, 'total' => 0],
    ];
    foreach ($statsRows as $row) {
        $stats[$row['type']] = [
            'nombre' => (int)$row['nombre'],
            'total' => (float)$row['total'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Téléchargement complet des comptes spéciaux réussi',
        'entities' => $formattedTransactions,
        'count' => count($formattedTransactions),
        'total_count' => (int)$totalCount,
        'has_more' => ($offset + $limit) < $totalCount,
        'offset' => $offset,
        'limit' => $limit,
        'stats' => $stats,
        'summary' => [
            'total_frais' => $stats['FRAIS']['total'],
            'nombre_frais' => $stats['FRAIS']['nombre'],
            'total_depense' => $stats['DEPENSE']['total'],
            'nombre_depense' => $stats['DEPENSE']['nombre'],
        ],
        'filter' => [
            'type' => $type,
            'shop_id' => $shopId,
            'user_role' => $userRole,
        ],
        'timestamp' => date('c')
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("[COMPTES_SPECIAUX] Download error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'entities' => [],
        'count' => 0,
        'timestamp' => date('c')
    ], JSON_UNESCAPED_UNICODE);
}
?>
