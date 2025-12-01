<?php
// Test minimal pour identifier l'erreur
error_reporting(E_ALL);
ini_set('display_errors', '1');

echo "Content-Type: text/plain\n\n";
echo "TEST 1: Script démarré\n";

try {
    echo "TEST 2: Inclusion database.php\n";
    require_once __DIR__ . '/../../config/database.php';
    echo "TEST 3: database.php inclus avec succès\n";
    
    echo "TEST 4: Vérification \$pdo\n";
    if (isset($pdo)) {
        echo "TEST 5: \$pdo existe, type = " . gettype($pdo) . "\n";
        echo "TEST 6: Classe = " . get_class($pdo) . "\n";
        
        echo "TEST 7: Test requête SQL\n";
        $result = $pdo->query("SELECT 1 as test");
        $row = $result->fetch();
        echo "TEST 8: SQL OK, résultat = " . json_encode($row) . "\n";
        
        echo "\n✅ TOUT FONCTIONNE!\n";
    } else {
        echo "❌ \$pdo n'existe pas!\n";
    }
    
} catch (Exception $e) {
    echo "\n❌ ERREUR: " . $e->getMessage() . "\n";
    echo "Fichier: " . $e->getFile() . "\n";
    echo "Ligne: " . $e->getLine() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}
