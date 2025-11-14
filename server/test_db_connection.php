<?php
require_once 'config/database.php';

try {
    // Test a simple query
    $stmt = $pdo->query("SELECT 1 as test");
    $result = $stmt->fetch();
    
    if ($result) {
        echo "Database connection successful!";
    } else {
        echo "Database connection failed!";
    }
} catch (Exception $e) {
    echo "Database connection error: " . $e->getMessage();
}
?>