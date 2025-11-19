<?php
/**
 * API pour récupérer l'en-tête actif des documents
 * GET /api/document-headers/active
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    // Récupérer l'en-tête actif
    $stmt = $pdo->prepare("
        SELECT * FROM document_headers 
        WHERE is_active = 1 
        ORDER BY id DESC 
        LIMIT 1
    ");
    
    $stmt->execute();
    $header = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($header) {
        echo json_encode([
            'success' => true,
            'data' => $header,
            'message' => 'En-tête récupéré avec succès'
        ]);
    } else {
        // Retourner un en-tête par défaut si aucun n'existe
        echo json_encode([
            'success' => true,
            'data' => [
                'id' => 0,
                'company_name' => 'UCASH',
                'company_slogan' => 'Votre partenaire de confiance',
                'address' => '',
                'phone' => '',
                'email' => '',
                'website' => '',
                'logo_path' => null,
                'tax_number' => null,
                'registration_number' => null,
                'is_active' => 1,
                'created_at' => date('Y-m-d H:i:s'),
                'updated_at' => null,
                'is_synced' => 0,
                'is_modified' => 0,
                'last_synced_at' => null
            ],
            'message' => 'En-tête par défaut retourné'
        ]);
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
