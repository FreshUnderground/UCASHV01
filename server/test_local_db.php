<?php
/**
 * Quick test to verify local database and tables
 */

header('Content-Type: application/json');

require_once __DIR__ . '/classes/Database.php';

try {
    $db = Database::getInstance();
    $conn = $db->getConnection();
    
    // Test connection
    $stmt = $conn->query("SELECT DATABASE() as db_name");
    $currentDb = $stmt->fetch();
    
    // Check deletion_requests table
    $stmt = $conn->query("SHOW TABLES LIKE 'deletion_requests'");
    $deletionTableExists = $stmt->fetch() ? true : false;
    
    // Check operations_corbeille table
    $stmt = $conn->query("SHOW TABLES LIKE 'operations_corbeille'");
    $corbeilleTableExists = $stmt->fetch() ? true : false;
    
    // Count records if tables exist
    $deletionCount = 0;
    $corbeilleCount = 0;
    
    if ($deletionTableExists) {
        $stmt = $conn->query("SELECT COUNT(*) as count FROM deletion_requests");
        $result = $stmt->fetch();
        $deletionCount = $result['count'];
    }
    
    if ($corbeilleTableExists) {
        $stmt = $conn->query("SELECT COUNT(*) as count FROM operations_corbeille");
        $result = $stmt->fetch();
        $corbeilleCount = $result['count'];
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Connected to database successfully',
        'database' => $currentDb['db_name'],
        'tables' => [
            'deletion_requests' => [
                'exists' => $deletionTableExists,
                'count' => $deletionCount
            ],
            'operations_corbeille' => [
                'exists' => $corbeilleTableExists,
                'count' => $corbeilleCount
            ]
        ]
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], JSON_PRETTY_PRINT);
}
