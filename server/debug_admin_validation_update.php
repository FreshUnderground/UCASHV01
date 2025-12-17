<?php
/**
 * Debug script to test admin validation database update
 */

require_once __DIR__ . '/config/database.php';

try {
    $codeOps = '251211224943822';
    $adminId = 0;
    $adminName = 'admin';
    
    echo "=== DEBUG ADMIN VALIDATION UPDATE ===\n";
    
    // Check current status
    $checkStmt = $pdo->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
    $checkStmt->execute([$codeOps]);
    $current = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    echo "AVANT mise à jour:\n";
    echo "  Statut: " . ($current['statut'] ?? 'NULL') . "\n";
    echo "  Admin ID: " . ($current['validated_by_admin_id'] ?? 'NULL') . "\n";
    echo "  Admin Name: " . ($current['validated_by_admin_name'] ?? 'NULL') . "\n\n";
    
    // Test the exact same query as in admin_validate.php
    $stmt = $pdo->prepare("
        UPDATE deletion_requests SET
            validated_by_admin_id = :admin_id,
            validated_by_admin_name = :admin_name,
            validation_admin_date = :validation_admin_date,
            statut = :statut,
            last_modified_at = :last_modified_at,
            last_modified_by = :last_modified_by
        WHERE code_ops = :code_ops
    ");
    
    $now = date('Y-m-d H:i:s');
    
    echo "Exécution de la requête UPDATE...\n";
    echo "Paramètres:\n";
    echo "  admin_id: $adminId\n";
    echo "  admin_name: $adminName\n";
    echo "  statut: 'admin_validee'\n";
    echo "  code_ops: $codeOps\n\n";
    
    $result = $stmt->execute([
        ':admin_id' => $adminId,
        ':admin_name' => $adminName,
        ':validation_admin_date' => $now,
        ':statut' => 'admin_validee',
        ':last_modified_at' => $now,
        ':last_modified_by' => "admin_$adminName",
        ':code_ops' => $codeOps
    ]);
    
    echo "Résultat execute(): " . ($result ? 'TRUE' : 'FALSE') . "\n";
    echo "Lignes affectées: " . $stmt->rowCount() . "\n\n";
    
    // Check after update
    $checkStmt->execute([$codeOps]);
    $after = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    echo "APRÈS mise à jour:\n";
    echo "  Statut: " . ($after['statut'] ?? 'NULL') . "\n";
    echo "  Admin ID: " . ($after['validated_by_admin_id'] ?? 'NULL') . "\n";
    echo "  Admin Name: " . ($after['validated_by_admin_name'] ?? 'NULL') . "\n";
    echo "  Validation Date: " . ($after['validation_admin_date'] ?? 'NULL') . "\n";
    
    // Check if enum values are valid
    echo "\n=== ENUM VALUES CHECK ===\n";
    $enumStmt = $pdo->query("SHOW COLUMNS FROM deletion_requests LIKE 'statut'");
    $enumInfo = $enumStmt->fetch(PDO::FETCH_ASSOC);
    echo "Enum definition: " . $enumInfo['Type'] . "\n";
    
} catch (Exception $e) {
    echo "ERREUR: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
}
?>
