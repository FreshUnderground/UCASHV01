<?php
/**
 * 🔧 Script temporaire pour initialiser les tables SIMS et Virtual Transactions
 * 
 * ⚠️ À SUPPRIMER après exécution!
 * 
 * Ce fichier permet d'exécuter facilement l'initialisation via navigateur
 * Accédez simplement à: https://votre-domaine.com/server/run_init_sims.php
 */

echo "<html><head><title>Initialisation Tables SIMS</title>";
echo "<style>body{font-family:monospace;background:#1e1e1e;color:#00ff00;padding:20px;} .error{color:#ff0000;} .success{color:#00ff00;} .info{color:#00aaff;}</style>";
echo "</head><body>";
echo "<h1>🔧 Initialisation des Tables SIMS et Virtual Transactions</h1>";
echo "<pre>";

try {
    require_once __DIR__ . '/init_sims_virtual_transactions.php';
    
    echo "\n\n<span class='success'>";
    echo "========================================\n";
    echo "✅ SUCCÈS!\n";
    echo "========================================\n";
    echo "Les tables ont été créées/vérifiées avec succès.\n\n";
    echo "Prochaines étapes:\n";
    echo "1. Testez la synchronisation dans l'application\n";
    echo "2. ⚠️ SUPPRIMEZ ce fichier (run_init_sims.php) pour des raisons de sécurité!\n";
    echo "</span>";
    
} catch (Exception $e) {
    echo "\n\n<span class='error'>";
    echo "========================================\n";
    echo "❌ ERREUR!\n";
    echo "========================================\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Code: " . $e->getCode() . "\n";
    echo "\nVérifiez:\n";
    echo "- Les permissions du fichier\n";
    echo "- La configuration database.php\n";
    echo "- Les logs PHP de votre serveur\n";
    echo "</span>";
}

echo "</pre>";
echo "<hr>";
echo "<p class='info'>📅 Exécuté le: " . date('Y-m-d H:i:s') . "</p>";
echo "<p class='error'>⚠️ N'oubliez pas de SUPPRIMER ce fichier après utilisation!</p>";
echo "</body></html>";
