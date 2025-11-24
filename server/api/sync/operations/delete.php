<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Lire les données JSON
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Accepter soit 'codeOps' (recommandé) soit 'id' (fallback)
    if (!isset($data['codeOps']) && !isset($data['id'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'codeOps ou ID d\'opération manquant'
        ]);
        exit;
    }
    
    // Connexion à la base de données
    $db = new Database();
    $pdo = $db->getConnection();
    
    // Prioriser codeOps pour la suppression (identifiant unique cross-platform)
    if (isset($data['codeOps'])) {
        $codeOps = $data['codeOps'];
        
        // Vérifier si l'opération existe
        $stmt = $pdo->prepare("SELECT id, codeOps FROM operations WHERE codeOps = ?");
        $stmt->execute([$codeOps]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$operation) {
            http_response_code(404);
            echo json_encode([
                'success' => false,
                'error' => 'Opération non trouvée avec codeOps: ' . $codeOps
            ]);
            exit;
        }
        
        // Supprimer l'opération par codeOps
        $stmt = $pdo->prepare("DELETE FROM operations WHERE codeOps = ?");
        $result = $stmt->execute([$codeOps]);
        
        if ($result) {
            echo json_encode([
                'success' => true,
                'message' => 'Opération supprimée avec succès',
                'codeOps' => $codeOps,
                'id' => $operation['id']
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'error' => 'Erreur lors de la suppression'
            ]);
        }
    } else {
        // Fallback: utiliser id (moins fiable car auto-increment)
        $operationId = intval($data['id']);
        
        // Vérifier si l'opération existe
        $stmt = $pdo->prepare("SELECT id FROM operations WHERE id = ?");
        $stmt->execute([$operationId]);
        $operation = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$operation) {
            http_response_code(404);
            echo json_encode([
                'success' => false,
                'error' => 'Opération non trouvée'
            ]);
            exit;
        }
        
        // Supprimer l'opération
        $stmt = $pdo->prepare("DELETE FROM operations WHERE id = ?");
        $result = $stmt->execute([$operationId]);
        
        if ($result) {
            echo json_encode([
                'success' => true,
                'message' => 'Opération supprimée avec succès',
                'id' => $operationId
            ]);
        } else {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'error' => 'Erreur lors de la suppression'
            ]);
        }
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
