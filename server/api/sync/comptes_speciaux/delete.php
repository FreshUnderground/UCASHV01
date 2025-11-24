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
    
    if (!isset($data['id'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'ID de transaction manquant'
        ]);
        exit;
    }
    
    $transactionId = intval($data['id']);
    
    // Connexion à la base de données
    $db = new Database();
    $pdo = $db->getConnection();
    
    // Vérifier si la transaction existe
    $stmt = $pdo->prepare("SELECT id FROM comptes_speciaux WHERE id = ?");
    $stmt->execute([$transactionId]);
    $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$transaction) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'error' => 'Transaction non trouvée'
        ]);
        exit;
    }
    
    // Supprimer la transaction
    $stmt = $pdo->prepare("DELETE FROM comptes_speciaux WHERE id = ?");
    $result = $stmt->execute([$transactionId]);
    
    if ($result) {
        echo json_encode([
            'success' => true,
            'message' => 'Transaction supprimée avec succès',
            'id' => $transactionId
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Erreur lors de la suppression'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
