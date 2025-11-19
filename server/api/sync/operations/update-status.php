<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Utiliser la connexion $pdo fournie par database.php
    error_log("[UPDATE-STATUS] Démarrage...");
    
    if (!isset($pdo)) {
        throw new Exception('Connexion base de données non disponible');
    }
    
    error_log("[UPDATE-STATUS] Connexion DB OK");
    
    // Lire les données JSON
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (empty($data['code_ops']) || empty($data['statut'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Code opération et statut requis'
        ]);
        exit;
    }
    
    $code_ops = $data['code_ops'];
    $new_status = $data['statut'];
    
    // Log pour debug
    error_log("[UPDATE-STATUS] Code: $code_ops, Nouveau statut: $new_status");
    
    // Valider le statut - utiliser les valeurs ENUM réelles de la table
    $valid_statuses = ['enAttente', 'validee', 'terminee'];
    if (!in_array($new_status, $valid_statuses)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Statut invalide. Valeurs acceptées: enAttente, validee, terminee'
        ]);
        exit;
    }
    
    // Vérifier que l'opération existe
    $check_query = "SELECT id, statut FROM operations WHERE code_ops = :code_ops LIMIT 1";
    $check_stmt = $pdo->prepare($check_query);
    $check_stmt->bindParam(':code_ops', $code_ops);
    $check_stmt->execute();
    
    $operation = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$operation) {
        error_log("[UPDATE-STATUS] Opération non trouvée: $code_ops");
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Opération non trouvée'
        ]);
        exit;
    }
    
    error_log("[UPDATE-STATUS] Opération trouvée. Ancien statut: {$operation['statut']}");
    
    // Mettre à jour le statut
    $update_query = "UPDATE operations 
                     SET statut = :statut, 
                         last_modified_at = NOW()
                     WHERE code_ops = :code_ops";
    
    $update_stmt = $pdo->prepare($update_query);
    $update_stmt->bindParam(':statut', $new_status);
    $update_stmt->bindParam(':code_ops', $code_ops);
    
    if ($update_stmt->execute()) {
        // Vérifier que la mise à jour a bien eu lieu
        $affected_rows = $update_stmt->rowCount();
        
        error_log("[UPDATE-STATUS] Mise à jour réussie. Lignes affectées: $affected_rows");
        
        echo json_encode([
            'success' => true,
            'message' => 'Statut mis à jour avec succès',
            'data' => [
                'code_ops' => $code_ops,
                'old_status' => $operation['statut'],
                'new_status' => $new_status,
                'affected_rows' => $affected_rows
            ]
        ]);
    } else {
        error_log("[UPDATE-STATUS] Échec de l'exécution de la requête");
        throw new Exception('Erreur lors de la mise à jour');
    }
    
} catch (PDOException $e) {
    error_log("[UPDATE-STATUS] Erreur PDO: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => 'PDOException'
    ]);
} catch (Exception $e) {
    error_log("[UPDATE-STATUS] Erreur: " . $e->getMessage());
    error_log("[UPDATE-STATUS] Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_type' => 'Exception'
    ]);
}
