<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les paramètres de requête
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    error_log("🔄 Changements personnel demandés depuis: $since, userId: $userId");
    
    $allChanges = [];
    
    // ========================================================================
    // 1. PERSONNEL (incluant les suppressions)
    // ========================================================================
    $sql = "SELECT * FROM personnel WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND (last_modified_at > :since OR deleted_at > :since_deleted)";
        $params[':since'] = $since;
        $params[':since_deleted'] = $since;
    }
    
    $sql .= " ORDER BY COALESCE(deleted_at, last_modified_at) ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $personnel = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($personnel as $p) {
        $p['_table'] = 'personnel';
        // Marquer les suppressions
        if (!empty($p['deleted_at'])) {
            $p['_deleted'] = true;
            $p['_deleted_at'] = $p['deleted_at'];
        }
        $allChanges[] = $p;
    }
    
    // ========================================================================
    // 2. SALAIRES (incluant les suppressions)
    // ========================================================================
    $sql = "SELECT s.*, p.nom AS personnel_nom, p.prenom AS personnel_prenom 
            FROM salaires s
            LEFT JOIN personnel p ON s.personnel_id = p.id
            WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND (s.last_modified_at > :since OR s.deleted_at > :since_deleted)";
        $params[':since'] = $since;
        $params[':since_deleted'] = $since;
    }
    
    $sql .= " ORDER BY COALESCE(s.deleted_at, s.last_modified_at) ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $salaires = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($salaires as $s) {
        $s['_table'] = 'salaires';
        // Marquer les suppressions
        if (!empty($s['deleted_at'])) {
            $s['_deleted'] = true;
            $s['_deleted_at'] = $s['deleted_at'];
        }
        $allChanges[] = $s;
    }
    
    // ========================================================================
    // 3. AVANCES (incluant les suppressions)
    // ========================================================================
    $sql = "SELECT a.*, p.nom AS personnel_nom, p.prenom AS personnel_prenom 
            FROM avances_personnel a
            LEFT JOIN personnel p ON a.personnel_id = p.id
            WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND (a.last_modified_at > :since OR a.deleted_at > :since_deleted)";
        $params[':since'] = $since;
        $params[':since_deleted'] = $since;
    }
    
    $sql .= " ORDER BY COALESCE(a.deleted_at, a.last_modified_at) ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $avances = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($avances as $a) {
        $a['_table'] = 'avances_personnel';
        // Marquer les suppressions
        if (!empty($a['deleted_at'])) {
            $a['_deleted'] = true;
            $a['_deleted_at'] = $a['deleted_at'];
        }
        $allChanges[] = $a;
    }
    
    // ========================================================================
    // 4. CRÉDITS
    // ========================================================================
    $sql = "SELECT c.*, p.nom AS personnel_nom, p.prenom AS personnel_prenom 
            FROM credits_personnel c
            LEFT JOIN personnel p ON c.personnel_id = p.id
            WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND c.last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    $sql .= " ORDER BY c.last_modified_at ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $credits = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($credits as $c) {
        $c['_table'] = 'credits_personnel';
        $allChanges[] = $c;
    }
    
    // ========================================================================
    // 5. REMBOURSEMENTS CRÉDITS
    // ========================================================================
    $sql = "SELECT * FROM remboursements_credits WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $remboursements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($remboursements as $r) {
        $r['_table'] = 'remboursements_credits';
        $allChanges[] = $r;
    }
    
    // ========================================================================
    // 6. RETENUES PERSONNEL (incluant les suppressions)
    // ========================================================================
    $sql = "SELECT r.*, p.nom AS personnel_nom, p.prenom AS personnel_prenom 
            FROM retenues_personnel r
            LEFT JOIN personnel p ON r.personnel_id = p.id
            WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND (r.last_modified_at > :since OR r.deleted_at > :since_deleted)";
        $params[':since'] = $since;
        $params[':since_deleted'] = $since;
    }
    
    $sql .= " ORDER BY COALESCE(r.deleted_at, r.last_modified_at) ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $retenues = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($retenues as $r) {
        $r['_table'] = 'retenues_personnel';
        // Marquer les suppressions
        if (!empty($r['deleted_at'])) {
            $r['_deleted'] = true;
            $r['_deleted_at'] = $r['deleted_at'];
        }
        $allChanges[] = $r;
    }
    
    // ========================================================================
    // 7. FICHES DE PAIE
    // ========================================================================
    $sql = "SELECT * FROM fiches_paie WHERE 1=1";
    $params = [];
    
    if ($since && !empty($since) && $since !== '2020-01-01T00:00:00.000') {
        $sql .= " AND last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at ASC LIMIT :limit";
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    
    $fiches = $stmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($fiches as $f) {
        $f['_table'] = 'fiches_paie';
        $allChanges[] = $f;
    }
    
    // ========================================================================
    // RETOURNER TOUS LES CHANGEMENTS
    // ========================================================================
    
    error_log("✅ Changements trouvés: " . count($allChanges) . " (Personnel: " . count($personnel) . 
              ", Salaires: " . count($salaires) . ", Avances: " . count($avances) . 
              ", Crédits: " . count($credits) . ", Remb: " . count($remboursements) . 
              ", Retenues: " . count($retenues) . ", Fiches: " . count($fiches) . ")");
    
    echo json_encode([
        'success' => true,
        'changes' => $allChanges,
        'count' => count($allChanges),
        'breakdown' => [
            'personnel' => count($personnel),
            'salaires' => count($salaires),
            'avances' => count($avances),
            'credits' => count($credits),
            'remboursements' => count($remboursements),
            'retenues' => count($retenues),
            'fiches_paie' => count($fiches)
        ]
    ]);
    
} catch (Exception $e) {
    error_log("❌ Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
