<?php
/**
 * Run Deletion Tables Migration
 * Creates deletion_requests and operations_corbeille tables
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🚀 Starting deletion tables migration...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Read SQL file - try multiple possible paths
    $possiblePaths = [
        __DIR__ . '/../../database/create_deletion_tables.sql',
        __DIR__ . '/../../../database/create_deletion_tables.sql',
        __DIR__ . '/create_deletion_tables.sql',
        dirname(__DIR__, 2) . '/database/create_deletion_tables.sql'
    ];
    
    $sqlFile = null;
    foreach ($possiblePaths as $path) {
        if (file_exists($path)) {
            $sqlFile = $path;
            break;
        }
    }
    
    if (!$sqlFile) {
        echo "❌ SQL file not found in any of these locations:\n";
        foreach ($possiblePaths as $path) {
            echo "   - $path\n";
        }
        throw new Exception("SQL file create_deletion_tables.sql not found");
    }
    
    echo "📍 Using SQL file: $sqlFile\n";
    
    if (!file_exists($sqlFile)) {
        throw new Exception("SQL file not found: $sqlFile");
    }
    
    $sql = file_get_contents($sqlFile);
    
    if (!$sql) {
        throw new Exception("Failed to read SQL file");
    }
    
    echo "📄 SQL file loaded: " . strlen($sql) . " bytes\n\n";
    
    // Split by semicolons and execute each statement
    $statements = array_filter(
        array_map('trim', explode(';', $sql)),
        function($stmt) {
            // Skip empty statements, comments, and USE statements
            return !empty($stmt) && 
                   !preg_match('/^\s*--/', $stmt) &&
                   !preg_match('/^\s*USE\s+/', $stmt) &&
                   !preg_match('/^\s*SELECT\s+[\'"]/', $stmt);
        }
    );
    
    echo "📊 Found " . count($statements) . " SQL statements to execute\n\n";
    
    $success = 0;
    $failed = 0;
    
    foreach ($statements as $index => $statement) {
        try {
            $db->exec($statement);
            $success++;
            
            // Show progress for important statements
            if (preg_match('/CREATE TABLE.*`?(\w+)`?/i', $statement, $matches)) {
                echo "✅ Created table: {$matches[1]}\n";
            } elseif (preg_match('/CREATE INDEX.*`?(\w+)`?/i', $statement, $matches)) {
                echo "✅ Created index: {$matches[1]}\n";
            } elseif (preg_match('/ALTER TABLE/i', $statement)) {
                echo "✅ Altered table\n";
            } elseif (preg_match('/DESCRIBE\s+`?(\w+)`?/i', $statement, $matches)) {
                echo "ℹ️  Described table: {$matches[1]}\n";
            }
        } catch (PDOException $e) {
            // Only count as failure if it's not a "table already exists" error
            if (strpos($e->getMessage(), 'already exists') === false) {
                $failed++;
                echo "❌ Error in statement " . ($index + 1) . ": " . $e->getMessage() . "\n";
                echo "Statement: " . substr($statement, 0, 100) . "...\n";
            } else {
                echo "ℹ️  Table/index already exists (skipped)\n";
                $success++;
            }
        }
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "📊 Migration Summary:\n";
    echo "   ✅ Successful: $success\n";
    echo "   ❌ Failed: $failed\n";
    echo str_repeat("=", 60) . "\n\n";
    
    // Verify tables exist
    echo "🔍 Verifying tables...\n\n";
    
    $tables = ['deletion_requests', 'operations_corbeille'];
    
    foreach ($tables as $table) {
        $stmt = $db->query("SHOW TABLES LIKE '$table'");
        $exists = $stmt->fetch();
        
        if ($exists) {
            echo "✅ Table '$table' exists\n";
            
            // Show table structure
            $stmt = $db->query("DESCRIBE $table");
            $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo "   Columns: " . count($columns) . "\n";
            
            // Show record count
            $stmt = $db->query("SELECT COUNT(*) as count FROM $table");
            $count = $stmt->fetch(PDO::FETCH_ASSOC);
            echo "   Records: " . $count['count'] . "\n\n";
        } else {
            echo "❌ Table '$table' NOT found\n\n";
        }
    }
    
    echo "🎉 Migration completed successfully!\n";
    echo "You can now use the deletion system.\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
