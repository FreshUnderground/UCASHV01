<?php
/**
 * Script de diagnostic pour les uploads de SIMs
 * 
 * Ce script vérifie:
 * 1. La structure de la table sims
 * 2. Les contraintes de clés étrangères
 * 3. Les shops existants
 * 4. Les SIMs en attente de synchronisation
 */

header('Content-Type: text/plain; charset=utf-8');

require_once __DIR__ . '/config/database.php';

echo "========================================\n";
echo "DIAGNOSTIC UPLOAD SIMS\n";
echo "========================================\n\n";

try {
    // $pdo est défini dans database.php
    $conn = $pdo;
    
    // 1. Vérifier la structure de la table sims
    echo "1. STRUCTURE DE LA TABLE SIMS\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("DESCRIBE sims");
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $null = $row['Null'] == 'NO' ? 'NOT NULL' : 'NULL';
        $default = $row['Default'] ? "DEFAULT {$row['Default']}" : '';
        echo sprintf("%-25s %-15s %-10s %s\n", $row['Field'], $row['Type'], $null, $default);
    }
    echo "\n";
    
    // 2. Vérifier les contraintes de clés étrangères
    echo "2. CONTRAINTES DE CLÉS ÉTRANGÈRES\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("
        SELECT 
            CONSTRAINT_NAME,
            COLUMN_NAME,
            REFERENCED_TABLE_NAME,
            REFERENCED_COLUMN_NAME
        FROM information_schema.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'sims'
        AND REFERENCED_TABLE_NAME IS NOT NULL
    ");
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['COLUMN_NAME']} -> {$row['REFERENCED_TABLE_NAME']}({$row['REFERENCED_COLUMN_NAME']})\n";
    }
    echo "\n";
    
    // 3. Lister les shops existants
    echo "3. SHOPS DISPONIBLES\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("SELECT id, designation FROM shops ORDER BY id");
    $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($shops)) {
        echo "  ⚠️ AUCUN SHOP TROUVÉ DANS LA BASE DE DONNÉES!\n";
        echo "  Les SIMs ne pourront pas être insérées car shop_id a une contrainte de clé étrangère.\n";
    } else {
        foreach ($shops as $shop) {
            echo "  - Shop #{$shop['id']}: {$shop['designation']}\n";
        }
    }
    echo "\n";
    
    // 4. Compter les SIMs existantes
    echo "4. STATISTIQUES SIMS\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("SELECT COUNT(*) as total FROM sims");
    $total = $stmt->fetchColumn();
    echo "  Total SIMs: $total\n";
    
    if ($total > 0) {
        $stmt = $conn->query("
            SELECT 
                statut,
                COUNT(*) as count
            FROM sims
            GROUP BY statut
        ");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "    - {$row['statut']}: {$row['count']}\n";
        }
        
        echo "\n  Par shop:\n";
        $stmt = $conn->query("
            SELECT 
                s.shop_id,
                sh.designation,
                COUNT(*) as count
            FROM sims s
            LEFT JOIN shops sh ON s.shop_id = sh.id
            GROUP BY s.shop_id, sh.designation
        ");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $designation = $row['designation'] ?? 'SHOP INEXISTANT!';
            echo "    - Shop #{$row['shop_id']} ({$designation}): {$row['count']} SIMs\n";
        }
    }
    echo "\n";
    
    // 5. Vérifier les SIMs avec shop_id invalide
    echo "5. VÉRIFICATION DES DONNÉES INVALIDES\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("
        SELECT 
            s.id,
            s.numero,
            s.shop_id,
            sh.designation
        FROM sims s
        LEFT JOIN shops sh ON s.shop_id = sh.id
        WHERE sh.id IS NULL
        LIMIT 10
    ");
    $invalidSims = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($invalidSims)) {
        echo "  ✅ Aucune SIM avec shop_id invalide trouvée.\n";
    } else {
        echo "  ⚠️ SIMs avec shop_id invalide trouvées:\n";
        foreach ($invalidSims as $sim) {
            echo "    - SIM #{$sim['id']} ({$sim['numero']}): shop_id={$sim['shop_id']} (n'existe pas!)\n";
        }
    }
    echo "\n";
    
    // 6. Instructions de résolution
    echo "========================================\n";
    echo "RECOMMANDATIONS\n";
    echo "========================================\n\n";
    
    if (empty($shops)) {
        echo "⚠️ PROBLÈME CRITIQUE: Aucun shop dans la base de données!\n";
        echo "\nSOLUTION:\n";
        echo "1. Créer au moins un shop avant d'insérer des SIMs\n";
        echo "2. Ou désactiver temporairement la contrainte de clé étrangère\n\n";
    }
    
    if (!empty($invalidSims)) {
        echo "⚠️ Des SIMs existent avec des shop_id invalides!\n";
        echo "\nSOLUTION:\n";
        echo "1. Corriger les shop_id des SIMs existantes\n";
        echo "2. Ou supprimer ces SIMs invalides\n\n";
    }
    
    echo "✅ Pour uploader des SIMs depuis Flutter:\n";
    echo "  - Vérifier que le shop_id existe dans la liste ci-dessus\n";
    echo "  - S'assurer que numero et operateur sont fournis\n";
    echo "  - Vérifier les logs PHP pour les erreurs détaillées\n\n";
    
    echo "========================================\n";
    echo "DIAGNOSTIC TERMINÉ\n";
    echo "========================================\n";
    
} catch (Exception $e) {
    echo "\n❌ ERREUR: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}
