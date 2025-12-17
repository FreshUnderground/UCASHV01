<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../../classes/Database.php';
require_once __DIR__ . '/../../../config/database.php';

try {
    $database = Database::getInstance();
    $pdo = $database->getConnection();
    
    // Récupérer les paramètres de requête
    $shopId = isset($_GET['shop_id']) ? (int)$_GET['shop_id'] : null;
    $lastSync = isset($_GET['last_sync']) ? $_GET['last_sync'] : null;
    $simNumero = isset($_GET['sim_numero']) ? $_GET['sim_numero'] : null;
    $statut = isset($_GET['statut']) ? $_GET['statut'] : null;
    $dateDebut = isset($_GET['date_debut']) ? $_GET['date_debut'] : null;
    $dateFin = isset($_GET['date_fin']) ? $_GET['date_fin'] : null;
    $beneficiaire = isset($_GET['beneficiaire']) ? $_GET['beneficiaire'] : null;
    
    // Construire la requête SQL
    $sql = "SELECT * FROM credit_virtuel WHERE 1=1";
    $params = [];
    
    // Filtrer par shop si spécifié
    if ($shopId !== null) {
        $sql .= " AND shop_id = ?";
        $params[] = $shopId;
    }
    
    // Filtrer par SIM si spécifié
    if ($simNumero !== null) {
        $sql .= " AND sim_numero = ?";
        $params[] = $simNumero;
    }
    
    // Filtrer par statut si spécifié
    if ($statut !== null) {
        $sql .= " AND statut = ?";
        $params[] = $statut;
    }
    
    // Filtrer par bénéficiaire si spécifié
    if ($beneficiaire !== null) {
        $sql .= " AND (beneficiaire_nom LIKE ? OR beneficiaire_telephone LIKE ?)";
        $searchTerm = '%' . $beneficiaire . '%';
        $params[] = $searchTerm;
        $params[] = $searchTerm;
    }
    
    // Filtrer par date de début (date_sortie)
    if ($dateDebut !== null) {
        $sql .= " AND date_sortie >= ?";
        $params[] = $dateDebut;
    }
    
    // Filtrer par date de fin (date_sortie)
    if ($dateFin !== null) {
        $sql .= " AND date_sortie <= ?";
        $params[] = $dateFin;
    }
    
    // Filtrer par date de dernière synchronisation si spécifiée
    if ($lastSync !== null) {
        $sql .= " AND last_modified_at > ?";
        $params[] = $lastSync;
    }
    
    // Ordonner par date de modification
    $sql .= " ORDER BY last_modified_at DESC";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $credits = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les valeurs booléennes
    foreach ($credits as &$credit) {
        $credit['is_synced'] = (bool)$credit['is_synced'];
        
        // Convertir les montants en nombres
        $credit['montant_credit'] = (float)$credit['montant_credit'];
        $credit['montant_paye'] = (float)$credit['montant_paye'];
        
        // Calculer le montant restant
        $credit['montant_restant'] = $credit['montant_credit'] - $credit['montant_paye'];
        
        // Vérifier si en retard
        $credit['est_en_retard'] = false;
        if ($credit['date_echeance'] && $credit['statut'] !== 'paye' && $credit['statut'] !== 'annule') {
            $dateEcheance = new DateTime($credit['date_echeance']);
            $maintenant = new DateTime();
            $credit['est_en_retard'] = $maintenant > $dateEcheance;
        }
    }
    
    echo json_encode([
        'success' => true,
        'data' => $credits,
        'count' => count($credits),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>
