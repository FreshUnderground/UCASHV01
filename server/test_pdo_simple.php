<?php
// Test ultra simple - affiche toutes les erreurs
error_reporting(E_ALL);
ini_set('display_errors', '1');

echo "Content-Type: text/plain\n\n";
echo "=== TEST CONNEXION PDO ===\n\n";

try {
    echo "1. Tentative de connexion...\n";
    
    $pdo = new PDO(
        "mysql:host=91.216.107.185;dbname=inves2504808_1n6a7b;charset=utf8mb4",
        "inves2504808",
        "31nzzasdnh",
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
    
    echo "2. ✅ Connexion réussie!\n";
    echo "3. Type: " . get_class($pdo) . "\n\n";
    
    echo "4. Test requête SELECT...\n";
    $stmt = $pdo->query("SELECT 1 as test");
    $result = $stmt->fetch();
    echo "5. ✅ Requête OK: " . json_encode($result) . "\n\n";
    
    echo "6. Test requête shops...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM shops");
    $result = $stmt->fetch();
    echo "7. ✅ Shops count: " . $result['count'] . "\n\n";
    
    echo "8. Test requête sims...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM sims");
    $result = $stmt->fetch();
    echo "9. ✅ SIMs count: " . $result['count'] . "\n\n";
    
    echo "=== TOUT FONCTIONNE! ===\n";
    
} catch (PDOException $e) {
    echo "\n❌ ERREUR PDO:\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Code: " . $e->getCode() . "\n";
    echo "Fichier: " . $e->getFile() . "\n";
    echo "Ligne: " . $e->getLine() . "\n";
} catch (Exception $e) {
    echo "\n❌ ERREUR:\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Fichier: " . $e->getFile() . "\n";
    echo "Ligne: " . $e->getLine() . "\n";
}
