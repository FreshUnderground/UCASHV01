<?php
// Script de test pour diagnostiquer l'erreur d'upload
header('Content-Type: application/json');
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/Database.php';

try {
    echo json_encode([
        'success' => true,
        'message' => 'Test de base réussi',
        'step' => 'Connexion DB...'
    ]);
    
    // Test connexion
    $db = Database::getInstance()->getConnection();
    
    echo json_encode([
        'success' => true,
        'message' => 'Connexion DB OK',
        'step' => 'Test des fonctions...'
    ]);
    
    // Test des fonctions de conversion
    function _convertOperationType($index) {
        $types = ['transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'depot', 'retrait', 'virement'];
        return $types[$index] ?? 'depot';
    }
    
    $testType = _convertOperationType(3);
    
    echo json_encode([
        'success' => true,
        'message' => 'Fonctions OK',
        'test_type' => $testType
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
}
?>
