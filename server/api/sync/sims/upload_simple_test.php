<?php
// Version ultra simple pour tester l'upload
error_reporting(E_ALL);
ini_set('display_errors', '1');

echo "Content-Type: text/plain\n\n";
echo "=== TEST UPLOAD SIMS ===\n\n";

try {
    echo "1. Connexion à la base de données...\n";
    
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
    
    echo "2. ✅ Connexion OK\n\n";
    
    echo "3. Lecture des données POST...\n";
    $json = file_get_contents('php://input');
    echo "4. JSON reçu (longueur): " . strlen($json) . "\n";
    
    if (strlen($json) > 0) {
        echo "5. Contenu: " . substr($json, 0, 200) . "...\n\n";
        
        $data = json_decode($json, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Erreur JSON: ' . json_last_error_msg());
        }
        
        echo "6. ✅ JSON décodé\n";
        echo "7. Nombre d'entités: " . count($data['entities']) . "\n\n";
        
        foreach ($data['entities'] as $index => $sim) {
            echo "8. Traitement SIM #$index: {$sim['numero']}\n";
            echo "   - Opérateur: {$sim['operateur']}\n";
            echo "   - Shop ID: {$sim['shop_id']}\n";
            
            // Vérifier le shop
            $stmt = $pdo->prepare("SELECT id FROM shops WHERE id = ?");
            $stmt->execute([$sim['shop_id']]);
            $shop = $stmt->fetch();
            
            if (!$shop) {
                echo "   ❌ Shop {$sim['shop_id']} n'existe pas!\n\n";
                continue;
            }
            
            echo "   ✅ Shop existe\n";
            
            // Vérifier si SIM existe
            $stmt = $pdo->prepare("SELECT id FROM sims WHERE numero = ?");
            $stmt->execute([$sim['numero']]);
            $existing = $stmt->fetch();
            
            if ($existing) {
                echo "   ℹ️ SIM existe déjà (ID: {$existing['id']})\n";
                echo "   → UPDATE\n";
                
                $stmt = $pdo->prepare("
                    UPDATE sims SET
                        operateur = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        solde_initial = ?,
                        solde_actuel = ?,
                        statut = ?,
                        last_modified_at = NOW()
                    WHERE numero = ?
                ");
                
                $stmt->execute([
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active',
                    $sim['numero']
                ]);
                
                echo "   ✅ UPDATE OK\n\n";
            } else {
                echo "   → INSERT\n";
                
                $stmt = $pdo->prepare("
                    INSERT INTO sims (
                        numero, operateur, shop_id, shop_designation,
                        solde_initial, solde_actuel, statut,
                        date_creation, last_modified_at,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1, NOW())
                ");
                
                $stmt->execute([
                    $sim['numero'],
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active'
                ]);
                
                $newId = $pdo->lastInsertId();
                echo "   ✅ INSERT OK (ID: $newId)\n\n";
            }
        }
        
        echo "=== SUCCESS ===\n";
        
    } else {
        echo "5. ⚠️ Aucune donnée POST reçue\n";
        echo "   Utilisez POST avec Content-Type: application/json\n";
    }
    
} catch (PDOException $e) {
    echo "\n❌ ERREUR PDO:\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Code: " . $e->getCode() . "\n";
} catch (Exception $e) {
    echo "\n❌ ERREUR:\n";
    echo "Message: " . $e->getMessage() . "\n";
}
