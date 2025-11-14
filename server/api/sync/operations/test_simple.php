<?php
// Test minimal pour identifier l'erreur
error_reporting(E_ALL);
ini_set('display_errors', 0); // Ne pas afficher les erreurs HTML
ini_set('log_errors', 1);

header('Content-Type: application/json');

// Test 1: Retour JSON basique
try {
    $result = ['success' => true, 'message' => 'Test 1: JSON basique OK'];
    echo json_encode($result);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
