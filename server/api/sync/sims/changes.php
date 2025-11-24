<?php
// Désactiver l'affichage des erreurs pour éviter de corrompre le JSON
ini_set('display_errors', '0');
error_reporting(E_ALL);

// Capturer TOUTES les erreurs et les convertir en JSON
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Récupérer le paramètre 'since' (timestamp de dernière sync)
    $since = $_GET['since'] ?? '2020-01-01T00:00:00.000';
    
    error_log("📱 [SIMs Changes] Requête depuis: $since");
    
    // Récupérer toutes les SIMs modifiées depuis le timestamp
    $stmt = $conn->prepare("
        SELECT 
            id,
            numero,
            operateur,
            shop_id,
            shop_designation,
            solde_initial,
            solde_actuel,
            statut,
            motif_suspension,
            date_creation,
            date_suspension,
            cree_par,
            last_modified_at,
            last_modified_by,
            is_synced,
            synced_at
        FROM sims
        WHERE last_modified_at >= ?
        ORDER BY last_modified_at ASC
    ");
    
    $stmt->execute([$since]);
    $sims = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("📱 [SIMs Changes] " . count($sims) . " SIMs trouvées");
    
    echo json_encode([
        'success' => true,
        'entities' => $sims,
        'count' => count($sims),
        'since' => $since,
        'timestamp' => date('c')
    ]);
    
} catch (PDOException $e) {
    error_log("❌ [SIMs Changes] Erreur de base de données: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur de base de données: ' . $e->getMessage(),
        'entities' => [],
        'timestamp' => date('c')
    ]);
} catch (Exception $e) {
    error_log("❌ [SIMs Changes] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'entities' => [],
        'timestamp' => date('c')
    ]);
}