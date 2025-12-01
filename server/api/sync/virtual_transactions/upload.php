<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

// Activer l'affichage des erreurs PHP pour le debugging (à désactiver en production)
// error_reporting(E_ALL);
// ini_set('display_errors', 1);

require_once '../../../config/database.php';
require_once '../../../classes/SyncManager.php';

try {
    // Récupération des données JSON
    $input = file_get_contents('php://input');
    
    // Log the raw input for debugging
    error_log("Virtual transactions upload - Raw input: " . substr($input, 0, 1000));
    
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['entities'])) {
        throw new Exception('Données JSON invalides: ' . substr($input, 0, 200));
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('c');
    
    $syncManager = new SyncManager($pdo);
    $uploaded = 0;
    $errors = [];
    
    foreach ($entities as $index => $entity) {
        try {
            // Log entity data for debugging
            error_log("Processing virtual transaction entity $index: " . json_encode($entity));
            
            // Validation basique des champs requis
            if (empty($entity['reference'])) {
                throw new Exception('Référence manquante pour l\'entité ' . $index);
            }
            
            if (!isset($entity['montant_virtuel']) || $entity['montant_virtuel'] <= 0) {
                throw new Exception('Montant virtuel invalide pour l\'entité ' . $index);
            }
            
            if (empty($entity['sim_numero'])) {
                throw new Exception('Numéro SIM manquant pour l\'entité ' . $index);
            }
            
            if (empty($entity['shop_id']) || $entity['shop_id'] <= 0) {
                throw new Exception('Shop ID invalide pour l\'entité ' . $index);
            }
            
            if (empty($entity['agent_id']) || $entity['agent_id'] <= 0) {
                throw new Exception('Agent ID invalide pour l\'entité ' . $index);
            }
            
            // Ajouter les métadonnées de synchronisation (sans is_synced)
            $entity['last_modified_at'] = $timestamp;
            $entity['last_modified_by'] = $userId;
            
            // Sauvegarder l'entité (is_synced sera mis à jour après insertion réussie)
            $syncManager->saveVirtualTransaction($entity);
            $uploaded++;
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? $entity['reference'] ?? 'unknown',
                'error' => $e->getMessage(),
                'entity_data' => array_slice($entity, 0, 5) // Log only first 5 fields for security
            ];
            error_log("Error processing virtual transaction: " . $e->getMessage());
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload terminé',
        'uploaded' => $uploaded,
        'total' => count($entities),
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Virtual transactions upload error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>