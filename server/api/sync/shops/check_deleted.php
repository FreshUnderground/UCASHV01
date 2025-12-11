<?php
/**
 * API Endpoint: Check Deleted Shops
 * 
 * Vérifie si des shops ont été supprimés du serveur.
 * Permet aux clients de synchroniser leurs listes locales en supprimant
 * les shops qui n'existent plus sur le serveur.
 * 
 * METHOD: POST
 * BODY: {
 *   "shop_ids": [1, 2, 3, 4, 5]
 * }
 * 
 * RESPONSE: {
 *   "success": true,
 *   "deleted_shops": [3, 5],
 *   "message": "2 shops supprimés trouvés"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Gérer les requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Méthode non autorisée. Utilisez POST.'
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données JSON invalides');
    }
    
    // Vérifier que shop_ids est fourni et est un tableau
    if (!isset($data['shop_ids']) || !is_array($data['shop_ids'])) {
        throw new Exception('Le paramètre "shop_ids" est requis et doit être un tableau');
    }
    
    $shopIds = $data['shop_ids'];
    
    // Si aucun ID fourni, retourner succès avec liste vide
    if (empty($shopIds)) {
        echo json_encode([
            'success' => true,
            'deleted_shops' => [],
            'message' => 'Aucun shop à vérifier'
        ]);
        exit;
    }
    
    // Créer les placeholders pour la requête SQL
    $placeholders = implode(',', array_fill(0, count($shopIds), '?'));
    
    // Requête pour trouver les shops qui existent encore sur le serveur
    $sql = "SELECT id FROM shops WHERE id IN ($placeholders)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($shopIds);
    
    // Récupérer les IDs des shops qui existent
    $existingIds = array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'id');
    $existingIds = array_map('intval', $existingIds);
    
    // Calculer les shops supprimés (présents localement mais pas sur le serveur)
    $deletedShops = array_diff($shopIds, $existingIds);
    $deletedShops = array_values($deletedShops); // Réindexer le tableau
    
    // Log pour debugging
    error_log("🔍 Check deleted shops - Total: " . count($shopIds) . ", Existing: " . count($existingIds) . ", Deleted: " . count($deletedShops));
    
    if (!empty($deletedShops)) {
        error_log("🗑️ Shops supprimés détectés: " . implode(', ', $deletedShops));
    }
    
    // Retourner la réponse
    echo json_encode([
        'success' => true,
        'deleted_shops' => $deletedShops,
        'existing_count' => count($existingIds),
        'deleted_count' => count($deletedShops),
        'message' => count($deletedShops) > 0 
            ? count($deletedShops) . ' shop(s) supprimé(s) trouvé(s)' 
            : 'Aucun shop supprimé'
    ]);
    
} catch (Exception $e) {
    error_log("❌ Erreur check_deleted shops: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'deleted_shops' => []
    ]);
}
?>

