<?php
/**
 * API pour télécharger les crédits inter-shop tracking depuis le serveur
 * Endpoint: GET /api/credit-intershop-tracking/download
 * 
 * Paramètres optionnels (GET):
 * - shop_principal_id: Filtrer par shop principal
 * - shop_normal_id: Filtrer par shop normal
 * - shop_service_id: Filtrer par shop de service
 * - date_debut: Date début (YYYY-MM-DD)
 * - date_fin: Date fin (YYYY-MM-DD)
 * - last_sync: Récupérer uniquement les modifications après cette date
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

    // Construire la requête SQL avec filtres
    $sql = "SELECT * FROM credit_intershop_tracking WHERE 1=1";
    $params = [];

    // Filtre par shop principal
    if (isset($_GET['shop_principal_id']) && !empty($_GET['shop_principal_id'])) {
        $sql .= " AND shop_principal_id = :shop_principal_id";
        $params[':shop_principal_id'] = (int)$_GET['shop_principal_id'];
    }

    // Filtre par shop normal
    if (isset($_GET['shop_normal_id']) && !empty($_GET['shop_normal_id'])) {
        $sql .= " AND shop_normal_id = :shop_normal_id";
        $params[':shop_normal_id'] = (int)$_GET['shop_normal_id'];
    }

    // Filtre par shop de service
    if (isset($_GET['shop_service_id']) && !empty($_GET['shop_service_id'])) {
        $sql .= " AND shop_service_id = :shop_service_id";
        $params[':shop_service_id'] = (int)$_GET['shop_service_id'];
    }

    // Filtre par date début
    if (isset($_GET['date_debut']) && !empty($_GET['date_debut'])) {
        $sql .= " AND date_operation >= :date_debut";
        $params[':date_debut'] = $_GET['date_debut'];
    }

    // Filtre par date fin
    if (isset($_GET['date_fin']) && !empty($_GET['date_fin'])) {
        $sql .= " AND date_operation <= :date_fin";
        $params[':date_fin'] = $_GET['date_fin'];
    }

    // Filtre par dernière synchronisation
    if (isset($_GET['last_sync']) && !empty($_GET['last_sync'])) {
        $sql .= " AND (last_modified_at > :last_sync OR created_at > :last_sync)";
        $params[':last_sync'] = $_GET['last_sync'];
    }

    // Ordre chronologique
    $sql .= " ORDER BY date_operation DESC, id DESC";

    // Préparer et exécuter la requête
    $stmt = $conn->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    
    $stmt->execute();
    $trackings = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Convertir les valeurs numériques
    foreach ($trackings as &$tracking) {
        $tracking['id'] = (int)$tracking['id'];
        $tracking['shop_principal_id'] = (int)$tracking['shop_principal_id'];
        $tracking['shop_normal_id'] = (int)$tracking['shop_normal_id'];
        $tracking['shop_service_id'] = (int)$tracking['shop_service_id'];
        $tracking['montant_brut'] = (float)$tracking['montant_brut'];
        $tracking['montant_net'] = (float)$tracking['montant_net'];
        $tracking['commission'] = (float)$tracking['commission'];
        $tracking['operation_id'] = $tracking['operation_id'] ? (int)$tracking['operation_id'] : null;
        $tracking['is_synced'] = (bool)$tracking['is_synced'];
    }

    // Log de l'activité
    error_log("API credit-intershop-tracking/download: " . count($trackings) . " trackings récupérés");

    // Retourner les données
    echo json_encode([
        'success' => true,
        'trackings' => $trackings,
        'total' => count($trackings),
        'filters_applied' => count($params)
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur base de données',
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur PDO dans credit-intershop-tracking/download: " . $e->getMessage());
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur dans credit-intershop-tracking/download: " . $e->getMessage());
}
?>
