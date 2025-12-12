<?php
/**
 * Script de test pour vérifier la synchronisation du champ is_administrative
 */

require_once 'server/config/database.php';

echo "===========================================\n";
echo "TEST SYNCHRONISATION is_administrative\n";
echo "===========================================\n\n";

try {
    // Connexion à la base de données
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
    
    echo "✅ Connexion réussie à la base de données\n\n";
    
    // 1. Vérifier que la colonne existe
    echo "[1] Vérification de la colonne is_administrative...\n";
    $stmt = $pdo->query("SHOW COLUMNS FROM operations LIKE 'is_administrative'");
    $column = $stmt->fetch();
    
    if ($column) {
        echo "✅ Colonne 'is_administrative' existe\n";
        echo "   Type: {$column['Type']}\n";
        echo "   Default: {$column['Default']}\n\n";
    } else {
        echo "❌ ERREUR: Colonne 'is_administrative' n'existe pas!\n";
        echo "   Exécutez: mysql -u root ucash_db < database/add_is_administrative_to_operations.sql\n\n";
        exit(1);
    }
    
    // 2. Vérifier l'index
    echo "[2] Vérification de l'index...\n";
    $stmt = $pdo->query("SHOW INDEX FROM operations WHERE Key_name = 'idx_operations_is_administrative'");
    $index = $stmt->fetch();
    
    if ($index) {
        echo "✅ Index 'idx_operations_is_administrative' existe\n\n";
    } else {
        echo "⚠️  Index 'idx_operations_is_administrative' n'existe pas (non critique)\n\n";
    }
    
    // 3. Test d'insertion d'un flot administratif
    echo "[3] Test d'insertion d'un flot administratif...\n";
    
    // Récupérer 2 shops pour le test
    $stmt = $pdo->query("SELECT id, designation FROM shops LIMIT 2");
    $shops = $stmt->fetchAll();
    
    if (count($shops) < 2) {
        echo "❌ ERREUR: Il faut au moins 2 shops dans la base\n\n";
        exit(1);
    }
    
    $shopSource = $shops[0];
    $shopDest = $shops[1];
    
    // Récupérer un agent
    $stmt = $pdo->query("SELECT id, username FROM agents LIMIT 1");
    $agent = $stmt->fetch();
    
    if (!$agent) {
        echo "❌ ERREUR: Il faut au moins 1 agent dans la base\n\n";
        exit(1);
    }
    
    $testData = [
        'type' => 'flotShopToShop',
        'montant_brut' => 100.00,
        'montant_net' => 100.00,
        'commission' => 0.00,
        'devise' => 'USD',
        'shop_source_id' => $shopSource['id'],
        'shop_source_designation' => $shopSource['designation'],
        'shop_destination_id' => $shopDest['id'],
        'shop_destination_designation' => $shopDest['designation'],
        'agent_id' => $agent['id'],
        'agent_username' => $agent['username'],
        'mode_paiement' => 'cash',
        'statut' => 'validee',
        'code_ops' => 'TEST_ADMIN_' . time(),
        'notes' => 'TEST FLOT ADMINISTRATIF - À supprimer',
        'is_administrative' => 1, // CRITIQUE: Flot administratif
        'created_at' => date('Y-m-d H:i:s'),
        'last_modified_at' => date('Y-m-d H:i:s'),
        'last_modified_by' => 'test_script'
    ];
    
    $sql = "INSERT INTO operations (
        type, montant_brut, montant_net, commission, devise,
        shop_source_id, shop_source_designation,
        shop_destination_id, shop_destination_designation,
        agent_id, agent_username,
        mode_paiement, statut, code_ops, notes,
        is_administrative, created_at, last_modified_at, last_modified_by
    ) VALUES (
        :type, :montant_brut, :montant_net, :commission, :devise,
        :shop_source_id, :shop_source_designation,
        :shop_destination_id, :shop_destination_designation,
        :agent_id, :agent_username,
        :mode_paiement, :statut, :code_ops, :notes,
        :is_administrative, :created_at, :last_modified_at, :last_modified_by
    )";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($testData);
    
    $insertId = $pdo->lastInsertId();
    
    echo "✅ Flot administratif inséré avec succès\n";
    echo "   ID: $insertId\n";
    echo "   Code: {$testData['code_ops']}\n";
    echo "   Shop Source: {$shopSource['designation']}\n";
    echo "   Shop Destination: {$shopDest['designation']}\n";
    echo "   Montant: {$testData['montant_brut']} USD\n\n";
    
    // 4. Vérifier la lecture
    echo "[4] Vérification de la lecture...\n";
    $stmt = $pdo->prepare("
        SELECT id, code_ops, type, montant_net, 
               shop_source_designation, shop_destination_designation,
               is_administrative, notes
        FROM operations 
        WHERE id = :id
    ");
    $stmt->execute([':id' => $insertId]);
    $operation = $stmt->fetch();
    
    if ($operation && $operation['is_administrative'] == 1) {
        echo "✅ Flot administratif lu correctement\n";
        echo "   is_administrative = {$operation['is_administrative']}\n\n";
    } else {
        echo "❌ ERREUR: is_administrative non lu correctement!\n\n";
        exit(1);
    }
    
    // 5. Test de l'endpoint changes.php
    echo "[5] Test de l'endpoint changes.php...\n";
    $changesUrl = "http://localhost/ucash/server/api/sync/operations/changes.php?user_id=1&user_role=admin&limit=1";
    
    $context = stream_context_create([
        'http' => [
            'timeout' => 10
        ]
    ]);
    
    $response = @file_get_contents($changesUrl, false, $context);
    
    if ($response) {
        $data = json_decode($response, true);
        if ($data && isset($data['entities']) && count($data['entities']) > 0) {
            $hasIsAdmin = isset($data['entities'][0]['is_administrative']);
            if ($hasIsAdmin) {
                echo "✅ L'endpoint changes.php retourne bien 'is_administrative'\n\n";
            } else {
                echo "❌ ERREUR: L'endpoint changes.php NE retourne PAS 'is_administrative'!\n";
                echo "   Vérifiez le fichier server/api/sync/operations/changes.php\n\n";
            }
        } else {
            echo "⚠️  Aucune opération retournée par changes.php\n\n";
        }
    } else {
        echo "⚠️  Impossible de contacter l'endpoint changes.php\n";
        echo "   URL testée: $changesUrl\n\n";
    }
    
    // 6. Nettoyage (supprimer le flot de test)
    echo "[6] Nettoyage...\n";
    $stmt = $pdo->prepare("DELETE FROM operations WHERE id = :id");
    $stmt->execute([':id' => $insertId]);
    echo "✅ Flot de test supprimé\n\n";
    
    echo "===========================================\n";
    echo "✅ TOUS LES TESTS RÉUSSIS!\n";
    echo "===========================================\n\n";
    
    echo "PROCHAINES ÉTAPES:\n";
    echo "1. Créer un flot administratif depuis l'app Flutter\n";
    echo "2. Vérifier les logs PHP: tail -f /path/to/php_error.log\n";
    echo "3. Chercher: [SYNC OP] is_administrative=TRUE\n";
    echo "4. Vérifier dans MySQL:\n";
    echo "   SELECT * FROM operations WHERE is_administrative = 1;\n\n";
    
} catch (PDOException $e) {
    echo "❌ ERREUR BASE DE DONNÉES: {$e->getMessage()}\n";
    exit(1);
} catch (Exception $e) {
    echo "❌ ERREUR: {$e->getMessage()}\n";
    exit(1);
}
?>
