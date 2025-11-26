<?php
/**
 * Script d'initialisation des tables AUDIT et RECONCILIATION
 * À exécuter une seule fois sur le serveur de production
 */

require_once __DIR__ . '/../config/database.php';

echo "🚀 Initialisation des tables AUDIT TRAIL et RÉCONCILIATION...\n\n";

try {
    // Lire le fichier SQL
    $sqlFile = __DIR__ . '/../database/create_audit_and_reconciliation.sql';
    
    if (!file_exists($sqlFile)) {
        throw new Exception("Fichier SQL introuvable: $sqlFile");
    }

    $sql = file_get_contents($sqlFile);
    
    // Diviser en requêtes individuelles (en enlevant les commentaires)
    $statements = array_filter(
        array_map('trim', explode(';', $sql)),
        function($stmt) {
            // Ignorer les commentaires et lignes vides
            $stmt = trim($stmt);
            return !empty($stmt) && 
                   !str_starts_with($stmt, '--') && 
                   !str_starts_with($stmt, '/*') &&
                   !str_starts_with($stmt, 'SELECT ');
        }
    );

    echo "📝 Nombre de requêtes à exécuter: " . count($statements) . "\n\n";

    $successCount = 0;
    $errorCount = 0;

    foreach ($statements as $index => $statement) {
        try {
            // Extraire le type de requête pour l'affichage
            $type = 'QUERY';
            if (preg_match('/^CREATE TABLE\s+(?:IF NOT EXISTS\s+)?`?(\w+)`?/i', $statement, $matches)) {
                $type = "CREATE TABLE {$matches[1]}";
            } elseif (preg_match('/^CREATE\s+(?:OR REPLACE\s+)?VIEW\s+`?(\w+)`?/i', $statement, $matches)) {
                $type = "CREATE VIEW {$matches[1]}";
            } elseif (preg_match('/^ALTER TABLE\s+`?(\w+)`?/i', $statement, $matches)) {
                $type = "ALTER TABLE {$matches[1]}";
            } elseif (preg_match('/^INSERT INTO\s+`?(\w+)`?/i', $statement, $matches)) {
                $type = "INSERT INTO {$matches[1]}";
            }

            echo "   [" . ($index + 1) . "] Exécution: $type... ";

            $pdo->exec($statement . ';');
            echo "✅\n";
            $successCount++;

        } catch (PDOException $e) {
            // Ignorer les erreurs "table already exists" et "view already exists"
            if (str_contains($e->getMessage(), 'already exists') || 
                str_contains($e->getMessage(), 'Duplicate column name')) {
                echo "⚠️ (déjà existe)\n";
            } else {
                echo "❌\n";
                echo "      Erreur: " . $e->getMessage() . "\n";
                $errorCount++;
            }
        }
    }

    echo "\n" . str_repeat('=', 60) . "\n";
    echo "✅ Requêtes réussies: $successCount\n";
    if ($errorCount > 0) {
        echo "❌ Requêtes échouées: $errorCount\n";
    }
    echo str_repeat('=', 60) . "\n\n";

    // Vérifier que les tables ont bien été créées
    echo "🔍 Vérification des tables créées:\n\n";

    $tables = ['audit_log', 'reconciliations', 'reconciliation_items'];
    foreach ($tables as $table) {
        $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
        if ($stmt->rowCount() > 0) {
            // Compter les enregistrements
            $countStmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
            $count = $countStmt->fetch(PDO::FETCH_ASSOC)['count'];
            echo "   ✅ Table `$table` existe ($count enregistrements)\n";
        } else {
            echo "   ❌ Table `$table` MANQUANTE\n";
        }
    }

    echo "\n🔍 Vérification des vues créées:\n\n";

    $views = ['v_reconciliations_ecarts', 'v_audit_summary', 'v_reconciliations_recent'];
    foreach ($views as $view) {
        $stmt = $pdo->query("SHOW FULL TABLES WHERE Table_Type = 'VIEW' AND Tables_in_" . $pdo->query("SELECT DATABASE()")->fetchColumn() . " = '$view'");
        if ($stmt->rowCount() > 0) {
            echo "   ✅ Vue `$view` existe\n";
        } else {
            echo "   ⚠️ Vue `$view` non trouvée (normal si erreur lors de la création)\n";
        }
    }

    echo "\n" . str_repeat('=', 60) . "\n";
    echo "🎉 Initialisation terminée avec succès !\n";
    echo str_repeat('=', 60) . "\n\n";

    echo "📚 DOCUMENTATION:\n\n";
    echo "1. AUDIT TRAIL:\n";
    echo "   - Table: audit_log\n";
    echo "   - Vue: v_audit_summary (statistiques)\n";
    echo "   - API: /api/audit/create.php (POST)\n";
    echo "   - API: /api/audit/get-history.php (GET)\n\n";

    echo "2. RÉCONCILIATION BANCAIRE:\n";
    echo "   - Table: reconciliations\n";
    echo "   - Table: reconciliation_items (détails)\n";
    echo "   - Vue: v_reconciliations_ecarts (écarts significatifs)\n";
    echo "   - Vue: v_reconciliations_recent (dernières par shop)\n";
    echo "   - API: /api/reconciliation/create.php (POST)\n";
    echo "   - API: /api/reconciliation/list.php (GET)\n\n";

    echo "3. UTILISATION:\n";
    echo "   - L'audit trail enregistre automatiquement toutes les modifications\n";
    echo "   - La réconciliation compare capital système vs réel\n";
    echo "   - Les écarts sont calculés automatiquement (colonnes GENERATED)\n";
    echo "   - 4 niveaux d'alerte: OK / MINEUR / ATTENTION / CRITIQUE\n\n";

} catch (Exception $e) {
    echo "\n❌ ERREUR FATALE:\n";
    echo $e->getMessage() . "\n\n";
    exit(1);
}
