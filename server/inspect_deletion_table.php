<?php
// Script to inspect the deletion_requests table structure

error_reporting(E_ALL);
ini_set('log_errors', '1');

echo "Inspecting deletion_requests Table Structure\n";
echo "==========================================\n\n";

// Include config for database connection
require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    echo "✓ Database connection successful\n\n";
    
    // Check if deletion_requests table exists
    $stmt = $db->query("SHOW TABLES LIKE 'deletion_requests'");
    $tableExists = $stmt->fetch();
    if (!$tableExists) {
        echo "✗ deletion_requests table does not exist\n";
        exit(1);
    }
    
    echo "✓ deletion_requests table exists\n\n";
    
    // Describe the table structure
    echo "Table Structure:\n";
    $stmt = $db->query("DESCRIBE deletion_requests");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($columns as $column) {
        echo "- {$column['Field']}: {$column['Type']}";
        if ($column['Null'] === 'NO') {
            echo " (NOT NULL)";
        }
        if ($column['Key'] === 'PRI') {
            echo " (PRIMARY KEY)";
        } elseif ($column['Key'] === 'UNI') {
            echo " (UNIQUE)";
        }
        if ($column['Default'] !== null) {
            echo " (DEFAULT: {$column['Default']})";
        }
        echo "\n";
    }
    
    echo "\nEnum values for 'statut' column:\n";
    // Get the enum values for the statut column
    foreach ($columns as $column) {
        if ($column['Field'] === 'statut' && strpos($column['Type'], 'enum') !== false) {
            // Extract enum values
            preg_match_all("/'([^']+)'/", $column['Type'], $matches);
            if (isset($matches[1])) {
                foreach ($matches[1] as $value) {
                    echo "- '$value'\n";
                }
            }
        }
    }
    
    echo "\nIndex Information:\n";
    $stmt = $db->query("SHOW INDEX FROM deletion_requests");
    $indexes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $indexNames = [];
    foreach ($indexes as $index) {
        $name = $index['Key_name'];
        if (!isset($indexNames[$name])) {
            $indexNames[$name] = [
                'columns' => [],
                'unique' => $index['Non_unique'] == 0,
                'type' => $index['Index_type']
            ];
        }
        $indexNames[$name]['columns'][] = $index['Column_name'];
    }
    
    foreach ($indexNames as $name => $info) {
        echo "- $name: " . implode(', ', $info['columns']);
        if ($info['unique']) {
            echo " (UNIQUE)";
        }
        echo " [{$info['type']}]\n";
    }
    
    echo "\nCurrent Data Sample:\n";
    // Get a sample of data
    $stmt = $db->query("SELECT * FROM deletion_requests ORDER BY request_date DESC LIMIT 3");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($rows)) {
        echo "No data found in table\n";
    } else {
        foreach ($rows as $i => $row) {
            echo "Row " . ($i + 1) . ":\n";
            foreach ($row as $key => $value) {
                echo "  $key: " . ($value === null ? 'NULL' : $value) . "\n";
            }
            echo "\n";
        }
    }
    
} catch (Exception $e) {
    echo "✗ Database error: " . $e->getMessage() . "\n";
    exit(1);
}

?>