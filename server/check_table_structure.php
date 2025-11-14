<?php
require_once 'config/database.php';
require_once 'classes/Database.php';

try {
    $db = Database::getInstance();
    $pdo = $db->getConnection();

    // Check the structure of the operations table
    $stmt = $pdo->prepare("DESCRIBE operations");
    $stmt->execute();
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo "Operations table structure:\n";
    foreach ($columns as $column) {
        echo "- " . $column['Field'] . " (" . $column['Type'] . ")\n";
    }
    
    echo "\n";

    // Check the structure of the sync_metadata table
    $stmt = $pdo->prepare("DESCRIBE sync_metadata");
    $stmt->execute();
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo "Sync_metadata table structure:\n";
    foreach ($columns as $column) {
        echo "- " . $column['Field'] . " (" . $column['Type'] . ")\n";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>