<?php
require_once 'config/database.php';
require_once 'classes/SyncManager.php';

try {
    $syncManager = new SyncManager($pdo);
    echo "SyncManager instantiated successfully!";
} catch (Exception $e) {
    echo "SyncManager error: " . $e->getMessage();
}
?>