<?php
/**
 * Script pour corriger les statuts des demandes de suppression
 * Corrige les demandes qui ont un validateur admin mais un statut incorrect
 */

require_once __DIR__ . '/config/database.php';

try {
    echo "🔧 Correction des statuts des demandes de suppression...\n\n";
    
    // ÉTAPE 1: Vérifier l'état actuel
    echo "📋 ÉTAPE 1: État actuel des demandes...\n";
    $checkStmt = $pdo->query("
        SELECT code_ops, statut, validated_by_admin_id, validated_by_admin_name, 
               validated_by_agent_id, validated_by_agent_name, created_at
        FROM deletion_requests 
        ORDER BY created_at DESC 
        LIMIT 10
    ");
    $allRequests = $checkStmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($allRequests as $req) {
        echo "📄 {$req['code_ops']} | Statut: '{$req['statut']}' | Admin: " . ($req['validated_by_admin_name'] ?? 'NULL') . " | Agent: " . ($req['validated_by_agent_name'] ?? 'NULL') . "\n";
    }
    
    // ÉTAPE 2: Corriger les demandes avec statut vide mais validateur admin
    echo "\n📋 ÉTAPE 2: Correction des statuts vides avec validateur admin...\n";
    $fixEmptyStmt = $pdo->prepare("
        UPDATE deletion_requests 
        SET statut = 'admin_validee' 
        WHERE (statut = '' OR statut IS NULL) 
        AND validated_by_admin_id IS NOT NULL
        AND validated_by_agent_id IS NULL
    ");
    
    $result1 = $fixEmptyStmt->execute();
    echo "✅ Demandes avec statut vide corrigées: " . $fixEmptyStmt->rowCount() . "\n";
    
    // ÉTAPE 3: Corriger les demandes en_attente qui ont un validateur admin
    echo "\n📋 ÉTAPE 3: Correction des demandes en_attente avec validateur admin...\n";
    $fixEnAttenteStmt = $pdo->prepare("
        UPDATE deletion_requests 
        SET statut = 'admin_validee' 
        WHERE statut = 'en_attente' 
        AND validated_by_admin_id IS NOT NULL
        AND validated_by_agent_id IS NULL
    ");
    
    $result2 = $fixEnAttenteStmt->execute();
    echo "✅ Demandes en_attente avec admin corrigées: " . $fixEnAttenteStmt->rowCount() . "\n";
    
    // ÉTAPE 4: Corriger la demande spécifique mentionnée
    echo "\n📋 ÉTAPE 4: Correction de la demande spécifique 251211224943822...\n";
    $specificStmt = $pdo->prepare("
        SELECT code_ops, statut, validated_by_admin_id, validated_by_admin_name 
        FROM deletion_requests 
        WHERE code_ops = '251211224943822'
    ");
    $specificStmt->execute();
    $specificRequest = $specificStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($specificRequest) {
        echo "📄 Demande trouvée: {$specificRequest['code_ops']}\n";
        echo "   Statut actuel: '{$specificRequest['statut']}'\n";
        echo "   Admin validateur: " . ($specificRequest['validated_by_admin_name'] ?? 'NULL') . "\n";
        
        if ($specificRequest['validated_by_admin_id'] && $specificRequest['statut'] !== 'admin_validee') {
            $fixSpecificStmt = $pdo->prepare("
                UPDATE deletion_requests 
                SET statut = 'admin_validee' 
                WHERE code_ops = '251211224943822'
            ");
            $fixSpecificStmt->execute();
            echo "✅ Statut corrigé pour 251211224943822\n";
        } else {
            echo "ℹ️ Demande 251211224943822 déjà correcte\n";
        }
    } else {
        echo "❌ Demande 251211224943822 non trouvée\n";
    }
    
    // ÉTAPE 5: Vérification finale
    echo "\n📋 ÉTAPE 5: Vérification finale - Demandes pour validation agent...\n";
    $finalStmt = $pdo->query("
        SELECT code_ops, operation_type, montant, devise, validated_by_admin_name
        FROM deletion_requests 
        WHERE statut = 'admin_validee'
        ORDER BY created_at DESC
    ");
    $agentRequests = $finalStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "🎯 DEMANDES DISPONIBLES POUR VALIDATION AGENT: " . count($agentRequests) . "\n";
    
    if (count($agentRequests) > 0) {
        echo "✅ Ces demandes devraient maintenant apparaître pour l'agent:\n";
        foreach ($agentRequests as $req) {
            echo "   📄 {$req['code_ops']} - {$req['operation_type']} - {$req['montant']} {$req['devise']} - Admin: {$req['validated_by_admin_name']}\n";
        }
    } else {
        echo "❌ Aucune demande disponible pour l'agent!\n";
    }
    
    // ÉTAPE 6: Statistiques finales
    echo "\n📊 STATISTIQUES FINALES:\n";
    $statsStmt = $pdo->query("
        SELECT statut, COUNT(*) as count 
        FROM deletion_requests 
        GROUP BY statut
        ORDER BY count DESC
    ");
    $stats = $statsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($stats as $stat) {
        echo "   {$stat['statut']}: {$stat['count']} demandes\n";
    }
    
    echo "\n✅ Correction terminée!\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    echo "   Fichier: " . $e->getFile() . "\n";
    echo "   Ligne: " . $e->getLine() . "\n";
}
?>
