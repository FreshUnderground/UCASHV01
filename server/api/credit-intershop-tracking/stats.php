<?php
/**
 * API pour obtenir les statistiques et rapports de consolidation des dettes inter-shop
 * Endpoint: GET /api/credit-intershop-tracking/stats
 * 
 * Paramètres optionnels (GET):
 * - shop_principal_id: ID du shop principal (ex: Durba)
 * - shop_service_id: ID du shop de service (ex: Kampala)
 * - date_debut: Date début (YYYY-MM-DD)
 * - date_fin: Date fin (YYYY-MM-DD)
 * - report_type: Type de rapport (debts_breakdown, consolidated_debt, full_report)
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Gérer les requêtes OPTIONS (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    // Vérifier la méthode HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Méthode non autorisée', 405);
    }

    // Connexion à la base de données
    $db = new Database();
    $conn = $db->getConnection();

    $reportType = $_GET['report_type'] ?? 'full_report';
    $shopPrincipalId = isset($_GET['shop_principal_id']) ? (int)$_GET['shop_principal_id'] : null;
    $shopServiceId = isset($_GET['shop_service_id']) ? (int)$_GET['shop_service_id'] : null;
    $dateDebut = $_GET['date_debut'] ?? null;
    $dateFin = $_GET['date_fin'] ?? null;

    $response = ['success' => true];

    // === RAPPORT 1: DETTES PAR SHOP NORMAL (Breakdown) ===
    if ($reportType === 'debts_breakdown' || $reportType === 'full_report') {
        $sql = "
            SELECT 
                shop_normal_id,
                shop_normal_designation,
                COUNT(*) as nombre_operations,
                SUM(montant_brut) as total_montant_brut,
                SUM(montant_net) as total_montant_net,
                SUM(commission) as total_commission,
                MIN(date_operation) as premiere_operation,
                MAX(date_operation) as derniere_operation
            FROM credit_intershop_tracking
            WHERE 1=1
        ";
        $params = [];

        if ($shopPrincipalId) {
            $sql .= " AND shop_principal_id = :shop_principal_id";
            $params[':shop_principal_id'] = $shopPrincipalId;
        }

        if ($dateDebut) {
            $sql .= " AND date_operation >= :date_debut";
            $params[':date_debut'] = $dateDebut;
        }

        if ($dateFin) {
            $sql .= " AND date_operation <= :date_fin";
            $params[':date_fin'] = $dateFin;
        }

        $sql .= " GROUP BY shop_normal_id, shop_normal_designation ORDER BY total_montant_brut DESC";

        $stmt = $conn->prepare($sql);
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->execute();
        $debtsBreakdown = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Convertir les valeurs numériques
        foreach ($debtsBreakdown as &$debt) {
            $debt['shop_normal_id'] = (int)$debt['shop_normal_id'];
            $debt['nombre_operations'] = (int)$debt['nombre_operations'];
            $debt['total_montant_brut'] = (float)$debt['total_montant_brut'];
            $debt['total_montant_net'] = (float)$debt['total_montant_net'];
            $debt['total_commission'] = (float)$debt['total_commission'];
        }

        $response['debts_breakdown'] = $debtsBreakdown;
    }

    // === RAPPORT 2: DETTE CONSOLIDÉE (Durba → Kampala) ===
    if ($reportType === 'consolidated_debt' || $reportType === 'full_report') {
        $sql = "
            SELECT 
                shop_principal_id,
                shop_principal_designation,
                shop_service_id,
                shop_service_designation,
                COUNT(*) as nombre_operations,
                SUM(montant_brut) as total_dette_consolidee,
                SUM(montant_net) as total_montant_net,
                SUM(commission) as total_commission,
                MIN(date_operation) as premiere_operation,
                MAX(date_operation) as derniere_operation
            FROM credit_intershop_tracking
            WHERE 1=1
        ";
        $params = [];

        if ($shopPrincipalId) {
            $sql .= " AND shop_principal_id = :shop_principal_id";
            $params[':shop_principal_id'] = $shopPrincipalId;
        }

        if ($shopServiceId) {
            $sql .= " AND shop_service_id = :shop_service_id";
            $params[':shop_service_id'] = $shopServiceId;
        }

        if ($dateDebut) {
            $sql .= " AND date_operation >= :date_debut";
            $params[':date_debut'] = $dateDebut;
        }

        if ($dateFin) {
            $sql .= " AND date_operation <= :date_fin";
            $params[':date_fin'] = $dateFin;
        }

        $sql .= " GROUP BY shop_principal_id, shop_principal_designation, shop_service_id, shop_service_designation";

        $stmt = $conn->prepare($sql);
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->execute();
        $consolidatedDebt = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($consolidatedDebt) {
            $consolidatedDebt['shop_principal_id'] = (int)$consolidatedDebt['shop_principal_id'];
            $consolidatedDebt['shop_service_id'] = (int)$consolidatedDebt['shop_service_id'];
            $consolidatedDebt['nombre_operations'] = (int)$consolidatedDebt['nombre_operations'];
            $consolidatedDebt['total_dette_consolidee'] = (float)$consolidatedDebt['total_dette_consolidee'];
            $consolidatedDebt['total_montant_net'] = (float)$consolidatedDebt['total_montant_net'];
            $consolidatedDebt['total_commission'] = (float)$consolidatedDebt['total_commission'];
        }

        $response['consolidated_debt'] = $consolidatedDebt;
    }

    // === RAPPORT 3: STATISTIQUES GLOBALES ===
    if ($reportType === 'full_report') {
        $sql = "
            SELECT 
                COUNT(*) as total_operations,
                COUNT(DISTINCT shop_principal_id) as nombre_shops_principaux,
                COUNT(DISTINCT shop_normal_id) as nombre_shops_normaux,
                COUNT(DISTINCT shop_service_id) as nombre_shops_service,
                SUM(montant_brut) as total_montant_brut,
                SUM(montant_net) as total_montant_net,
                SUM(commission) as total_commission,
                AVG(montant_brut) as moyenne_montant_brut,
                MIN(date_operation) as premiere_operation,
                MAX(date_operation) as derniere_operation,
                COUNT(DISTINCT DATE(date_operation)) as nombre_jours_activite
            FROM credit_intershop_tracking
            WHERE 1=1
        ";
        $params = [];

        if ($shopPrincipalId) {
            $sql .= " AND shop_principal_id = :shop_principal_id";
            $params[':shop_principal_id'] = $shopPrincipalId;
        }

        if ($dateDebut) {
            $sql .= " AND date_operation >= :date_debut";
            $params[':date_debut'] = $dateDebut;
        }

        if ($dateFin) {
            $sql .= " AND date_operation <= :date_fin";
            $params[':date_fin'] = $dateFin;
        }

        $stmt = $conn->prepare($sql);
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        $stmt->execute();
        $globalStats = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($globalStats) {
            $globalStats['total_operations'] = (int)$globalStats['total_operations'];
            $globalStats['nombre_shops_principaux'] = (int)$globalStats['nombre_shops_principaux'];
            $globalStats['nombre_shops_normaux'] = (int)$globalStats['nombre_shops_normaux'];
            $globalStats['nombre_shops_service'] = (int)$globalStats['nombre_shops_service'];
            $globalStats['total_montant_brut'] = (float)$globalStats['total_montant_brut'];
            $globalStats['total_montant_net'] = (float)$globalStats['total_montant_net'];
            $globalStats['total_commission'] = (float)$globalStats['total_commission'];
            $globalStats['moyenne_montant_brut'] = (float)$globalStats['moyenne_montant_brut'];
            $globalStats['nombre_jours_activite'] = (int)$globalStats['nombre_jours_activite'];
        }

        $response['global_stats'] = $globalStats;
    }

    // Log de l'activité
    error_log("API credit-intershop-tracking/stats: Type de rapport: $reportType");

    // Retourner les statistiques
    echo json_encode($response, JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur base de données',
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur PDO dans credit-intershop-tracking/stats: " . $e->getMessage());
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur dans credit-intershop-tracking/stats: " . $e->getMessage());
}
?>
