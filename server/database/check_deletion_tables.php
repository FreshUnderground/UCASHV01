<?php
/**
 * Check if deletion tables exist
 */

header('Content-Type: application/json');

require_once __DIR__ . '/../../classes/Database.php';
require_once __DIR__ . '/../../config/database.php';

try {
    $database = Database::getInstance();
    $db = $database->getConnection();
    
    $tables = ['deletion_requests', 'operations_corbeille'];
    $result = [];
    
    foreach ($tables as $tableName) {
        $stmt = $db->query("SHOW TABLES LIKE '$tableName'");
        $exists = $stmt->fetch();
        
        $tableInfo = [
            'name' => $tableName,
            'exists' => (bool)$exists,
            'columns' => 0,
            'records' => 0
        ];
        
        if ($exists) {
            // Get column count
            $stmt = $db->query("DESCRIBE $tableName");
            $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $tableInfo['columns'] = count($columns);
            
            // Get record count
            $stmt = $db->query("SELECT COUNT(*) as count FROM $tableName");
            $count = $stmt->fetch(PDO::FETCH_ASSOC);
            $tableInfo['records'] = $count['count'];
        }
        
        $result[] = $tableInfo;
    }
    
    echo json_encode([
        'success' => true,
        'tables' => $result
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
