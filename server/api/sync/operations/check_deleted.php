<?php
/**
 * API Endpoint: Check Deleted Operations
 * 
 * Vérifie si des opérations ont été supprimées du serveur en consultant la corbeille.
 * Permet aux clients de synchroniser leurs listes locales en supprimant
 * les opérations qui n'existent plus sur le serveur.
 * 
 * METHOD: POST
 * BODY: {
 *   "code_ops_list": ["251202160848312", "251202160848313", ...]
 * }
 * 
 * RESPONSE: {
 *   "success": true,
 *   "deleted_operations": ["251202160848312", ...],
 *   "message": "X opérations supprimées trouvées"
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
    
    // Valider les paramètres requis
    if (!isset($data['code_ops_list']) || !is_array($data['code_ops_list'])) {
        throw new Exception('Paramètre code_ops_list requis (tableau de codes d\'opérations)');
    }
    
    $codeOpsList = $data['code_ops_list'];
    
    if (empty($codeOpsList)) {
        echo json_encode([
            'success' => true,
            'deleted_operations' => [],
            'message' => 'Aucune opération à vérifier'
        ]);
        exit;
    }
    
    // Limiter la taille de la liste pour éviter les problèmes de performance
    if (count($codeOpsList) > 1000) {
        throw new Exception('Trop d\'opérations à vérifier (maximum 1000)');
    }
    
    // Connexion à la base de données
    $db = $pdo;
    
    // Préparer la requête pour vérifier quelles opérations ont été supprimées
    // On cherche les code_ops qui existent dans operations_corbeille mais pas dans operations
    $placeholders = str_repeat('?,', count($codeOpsList) - 1) . '?';
    
    $query = "
        SELECT oc.code_ops 
        FROM operations_corbeille oc
        WHERE oc.code_ops IN ($placeholders)
        AND NOT EXISTS (
            SELECT 1 FROM operations o WHERE o.code_ops = oc.code_ops
        )
    ";
    
    $stmt = $db->prepare($query);
    $stmt->execute($codeOpsList);
    
    $deletedOperations = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $deletedOperations[] = $row['code_ops'];
    }
    
    // Log de succès
    error_log("✅ Vérification des opérations supprimées: " . count($deletedOperations) . " trouvées sur " . count($codeOpsList));
    
    // Réponse de succès
    echo json_encode([
        'success' => true,
        'deleted_operations' => $deletedOperations,
        'total_checked' => count($codeOpsList),
        'total_deleted' => count($deletedOperations),
        'message' => count($deletedOperations) . ' opération(s) supprimée(s) trouvée(s)'
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("❌ Erreur vérification opérations supprimées: " . $e->getMessage());
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>