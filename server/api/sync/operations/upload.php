<?php
// Activer la capture d'erreurs pour retourner du JSON
error_reporting(E_ALL);
ini_set('display_errors', 0); // Ne PAS afficher les erreurs en HTML
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

// Capturer les erreurs fatales
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erreur PHP fatale: ' . $error['message'],
            'file' => $error['file'],
            'line' => $error['line']
        ]);
    }
});

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/Database.php';

// Fonctions de conversion des index d'enum Flutter vers valeurs SQL
function _convertOperationType($index) {
    // Flutter enum: transfertNational=0, transfertInternationalSortant=1, transfertInternationalEntrant=2, depot=3, retrait=4, virement=5
    // MySQL ENUM: 'depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'virement'
    $types = ['transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'depot', 'retrait', 'virement'];
    return $types[$index] ?? 'depot';
}

function _convertModePaiement($index) {
    // Flutter enum: cash=0, airtelMoney=1, mPesa=2, orangeMoney=3
    // MySQL ENUM: 'cash', 'airtelMoney', 'mPesa', 'orangeMoney'
    $modes = ['cash', 'airtelMoney', 'mPesa', 'orangeMoney'];
    return $modes[$index] ?? 'cash';
}

function _convertStatut($index) {
    // Flutter enum: enAttente=0, validee=1, terminee=2, annulee=3
    // MySQL ENUM: 'enAttente', 'validee', 'terminee', 'annulee'
    $statuts = ['enAttente', 'validee', 'terminee', 'annulee'];
    return $statuts[$index] ?? 'terminee';
}

try {
    // Debug: Log request
    error_log("Upload request received");
    
    // Lire les données POST
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    // Debug: Log input data
    error_log("Input data: " . print_r($data, true));
    
    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Données invalides: entities requis');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $uploadedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    // Connexion à la base de données
    $db = Database::getInstance()->getConnection();
    
    // Debug: Test database connection
    try {
        $stmt = $db->query("SELECT 1");
        error_log("Database connection successful");
    } catch (Exception $e) {
        error_log("Database connection failed: " . $e->getMessage());
        throw new Exception("Database connection failed: " . $e->getMessage());
    }
    
    // Début de transaction
    $db->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
                // Logger les données brutes reçues pour débogage
                error_log("[SYNC OP] ID={$entity['id']}, agent_id={$entity['agent_id']}, agent_username=" . (isset($entity['agent_username']) ? "'{$entity['agent_username']}'" : 'NULL') . ", shop_source_designation=" . (isset($entity['shop_source_designation']) ? "'{$entity['shop_source_designation']}'" : 'NULL') . ", client_nom=" . (isset($entity['client_nom']) ? "'{$entity['client_nom']}'" : 'NULL'));
                
                // Convertir les index d'enum Flutter en valeurs SQL
                $type = _convertOperationType($entity['type'] ?? 0);
                $modePaiement = _convertModePaiement($entity['mode_paiement'] ?? 0);
                
                // CRITIQUE: Logger le statut AVANT conversion pour débogage
                $statutRaw = $entity['statut'] ?? 'MISSING';
                error_log("⚠️ STATUT DEBUG: raw_value=" . print_r($statutRaw, true) . ", is_set=" . (isset($entity['statut']) ? 'YES' : 'NO'));
                
                // Convertir le statut avec fallback sur 'terminee' (index 2) au lieu de 'enAttente' (index 0)
                $statutIndex = isset($entity['statut']) ? $entity['statut'] : 2;  // Défaut: terminee
                $statut = _convertStatut($statutIndex);
                
                // Logger les données converties
                error_log("Conversion: type_index={$entity['type']} -> type={$type}, mode_index={$entity['mode_paiement']} -> mode={$modePaiement}, statut_index={$statutIndex} -> statut={$statut}");
            
            // Résoudre client_id depuis client nom POUR TOUTES LES OPÉRATIONS
            $clientId = null;
            if (isset($entity['client_nom']) && !empty($entity['client_nom'])) {
                $clientStmt = $db->prepare("SELECT id FROM clients WHERE nom = :nom LIMIT 1");
                $clientStmt->execute([':nom' => $entity['client_nom']]);
                $client = $clientStmt->fetch(PDO::FETCH_ASSOC);
                if ($client) {
                    $clientId = $client['id'];
                    error_log("INFO: Client trouvé par nom '{$entity['client_nom']}' -> id={$clientId}");
                } else {
                    error_log("WARNING: Client non trouvé par nom '{$entity['client_nom']}'");
                }
            }
            // Si pas trouvé par nom et que client_id existe ET est dans la plage INT, l'utiliser
            if ($clientId === null && isset($entity['client_id']) && $entity['client_id'] <= 2147483647) {
                $clientId = $entity['client_id'];
                error_log("INFO: Utilisation client_id existant = {$clientId}");
            }
            
            // Résoudre agent_id depuis agent_username POUR TOUTES LES OPÉRATIONS (update et insert)
            $agentId = null;
            if (isset($entity['agent_username']) && !empty($entity['agent_username'])) {
                $agentStmt = $db->prepare("SELECT id FROM agents WHERE username = :username LIMIT 1");
                $agentStmt->execute([':username' => $entity['agent_username']]);
                $agent = $agentStmt->fetch(PDO::FETCH_ASSOC);
                if ($agent) {
                    $agentId = $agent['id'];
                }
            }
            // Si pas trouvé par username et que agent_id existe ET est dans la plage INT, l'utiliser
            if ($agentId === null && isset($entity['agent_id']) && $entity['agent_id'] <= 2147483647) {
                $agentId = $entity['agent_id'];
            }
            // Si toujours null, UTILISER UN AGENT PAR DÉFAUT au lieu de rejeter
            if ($agentId === null) {
                // Chercher ou créer un agent par défaut
                $defaultAgentStmt = $db->prepare("SELECT id FROM agents WHERE username = 'system_default' LIMIT 1");
                $defaultAgentStmt->execute();
                $defaultAgent = $defaultAgentStmt->fetch(PDO::FETCH_ASSOC);
                
                if (!$defaultAgent && $shopSourceId !== null) {
                    // Créer l'agent par défaut s'il n'existe pas
                    $createAgentStmt = $db->prepare("
                        INSERT INTO agents (shop_id, nom, username, password, is_active, created_at)
                        VALUES (:shop_id, 'Système', 'system_default', :password, 1, NOW())
                    ");
                    $createAgentStmt->execute([
                        ':shop_id' => $shopSourceId,
                        ':password' => password_hash('system123', PASSWORD_DEFAULT)
                    ]);
                    $agentId = $db->lastInsertId();
                    error_log("INFO: Agent par défaut créé avec ID = {$agentId}");
                } else if ($defaultAgent) {
                    $agentId = $defaultAgent['id'];
                    error_log("INFO: Utilisation agent par défaut ID = {$agentId} pour username='{$entity['agent_username']}'");
                } else {
                    throw new Exception("Impossible de créer l'agent par défaut (shop source non trouvé). Opération ID {$entity['id']} rejetée.");
                }
            }
            
            // Résoudre shop_source_id et shop_destination_id POUR TOUTES LES OPÉRATIONS
            $shopSourceId = null;
            if (isset($entity['shop_source_designation']) && !empty($entity['shop_source_designation'])) {
                $shopStmt = $db->prepare("SELECT id FROM shops WHERE designation = :designation LIMIT 1");
                $shopStmt->execute([':designation' => $entity['shop_source_designation']]);
                $shop = $shopStmt->fetch(PDO::FETCH_ASSOC);
                if ($shop) {
                    $shopSourceId = $shop['id'];
                }
            }
            // Si pas trouvé par designation et que shop_source_id existe ET est dans la plage INT, l'utiliser
            if ($shopSourceId === null && isset($entity['shop_source_id']) && $entity['shop_source_id'] <= 2147483647) {
                $shopSourceId = $entity['shop_source_id'];
            }
            // Si toujours null, REJETER l'opération
            if ($shopSourceId === null) {
                throw new Exception("Shop source non trouvé pour designation='{$entity['shop_source_designation']}'. Opération ID {$entity['id']} rejetée.");
            }
            
            $shopDestinationId = null;
            if (isset($entity['shop_destination_designation']) && !empty($entity['shop_destination_designation'])) {
                $shopStmt = $db->prepare("SELECT id FROM shops WHERE designation = :designation LIMIT 1");
                $shopStmt->execute([':designation' => $entity['shop_destination_designation']]);
                $shop = $shopStmt->fetch(PDO::FETCH_ASSOC);
                if ($shop) {
                    $shopDestinationId = $shop['id'];
                }
            } else {
                // Si pas de designation fournie, vérifier si l'ID est valide
                if (isset($entity['shop_destination_id']) && $entity['shop_destination_id'] <= 2147483647) {
                    $shopDestinationId = $entity['shop_destination_id'];
                }
            }
            
            // Vérifier si l'opération existe déjà
            $checkStmt = $db->prepare("
                SELECT id FROM operations 
                WHERE id = :id
            ");
            $checkStmt->execute([':id' => $entity['id'] ?? 0]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // Mise à jour de l'opération existante
                $updateStmt = $db->prepare("
                    UPDATE operations SET
                        type = :type,
                        montant_brut = :montant_brut,
                        montant_net = :montant_net,
                        commission = :commission,
                        devise = :devise,
                        client_id = :client_id,
                        client_nom = :client_nom,
                        shop_source_id = :shop_source_id,
                        shop_destination_id = :shop_destination_id,
                        agent_id = :agent_id,
                        mode_paiement = :mode_paiement,
                        statut = :statut,
                        reference = :reference,
                        notes = :notes,
                        destinataire = :destinataire,
                        telephone_destinataire = :telephone_destinataire,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by
                    WHERE id = :id
                ");
                
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':type' => $type,
                    ':montant_brut' => $entity['montant_brut'] ?? 0,
                    ':montant_net' => $entity['montant_net'] ?? 0,
                    ':commission' => $entity['commission'] ?? 0,
                    ':devise' => $entity['devise'] ?? 'USD',
                    ':client_id' => $clientId,
                    ':client_nom' => $entity['client_nom'] ?? null,
                    ':shop_source_id' => $shopSourceId,
                    ':shop_destination_id' => $shopDestinationId,
                    ':agent_id' => $agentId,
                    ':mode_paiement' => $modePaiement,
                    ':statut' => $statut,
                    ':reference' => $entity['reference'] ?? null,
                    ':notes' => $entity['notes'] ?? '',
                    ':destinataire' => $entity['destinataire'] ?? null,
                    ':telephone_destinataire' => $entity['telephone_destinataire'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId
                ]);
                
                // Marquer comme synchronisé après mise à jour réussie
                $syncStmt = $db->prepare("UPDATE operations SET is_synced = 1, synced_at = NOW() WHERE id = :id");
                $syncStmt->execute([':id' => $entity['id']]);
                
                $updatedCount++;
            } else {
                // Insertion d'une nouvelle opération
                // agent_id, shopSourceId, shopDestinationId déjà résolus plus haut
                
                // Vérifier si une opération similaire existe déjà (doublon logique)
                $checkDuplicateStmt = $db->prepare("
                    SELECT id FROM operations 
                    WHERE montant_brut = :montant_brut 
                    AND agent_id = :agent_id 
                    AND DATE(created_at) = DATE(:created_at)
                    AND type = :type
                    LIMIT 1
                ");
                
                $checkDuplicateStmt->execute([
                    ':montant_brut' => $entity['montant_brut'] ?? 0,
                    ':agent_id' => $agentId,
                    ':created_at' => $entity['date_op'] ?? date('Y-m-d H:i:s'),
                    ':type' => $type
                ]);
                
                $duplicate = $checkDuplicateStmt->fetch(PDO::FETCH_ASSOC);
                
                if ($duplicate) {
                    // Doublon détecté - ignorer silencieusement
                    error_log("WARNING: Doublon opération ignoré: montant={$entity['montant_brut']}, agent={$agentId}, type={$type}");
                    continue; // Passer à l'opération suivante
                }
                
                // shopSourceId, shopDestinationId, agentId déjà résolus plus haut
                
                // Logger toutes les données avant insertion
                error_log("Preparation INSERT: type={$type}, montant={$entity['montant_brut']}, shop_id={$shopSourceId}, shop_designation={$entity['shop_source_designation']}, agent_id={$agentId}, agent_username={$entity['agent_username']}, mode={$modePaiement}, statut={$statut}");
                
                $insertStmt = $db->prepare("
                    INSERT INTO operations (
                        type, montant_brut, montant_net, commission, devise,
                        client_id, client_nom, shop_source_id, shop_source_designation, shop_destination_id, shop_destination_designation, agent_id, agent_username,
                        mode_paiement, statut, reference, notes, destinataire, telephone_destinataire,
                        last_modified_at, last_modified_by, created_at
                    ) VALUES (
                        :type, :montant_brut, :montant_net, :commission, :devise,
                        :client_id, :client_nom, :shop_source_id, :shop_source_designation, :shop_destination_id, :shop_destination_designation, :agent_id, :agent_username,
                        :mode_paiement, :statut, :reference, :notes, :destinataire, :telephone_destinataire,
                        :last_modified_at, :last_modified_by, :created_at
                    )
                ");
                
                try {
                $insertStmt->execute([
                    ':type' => $type,
                    ':montant_brut' => $entity['montant_brut'] ?? 0,
                    ':montant_net' => $entity['montant_net'] ?? 0,
                    ':commission' => $entity['commission'] ?? 0,
                    ':devise' => $entity['devise'] ?? 'USD',
                    ':client_id' => $clientId,
                    ':client_nom' => $entity['client_nom'] ?? null,
                    ':shop_source_id' => $shopSourceId,
                    ':shop_source_designation' => $entity['shop_source_designation'] ?? null,
                    ':shop_destination_id' => $shopDestinationId,
                    ':shop_destination_designation' => $entity['shop_destination_designation'] ?? null,
                    ':agent_id' => $agentId,
                    ':agent_username' => $entity['agent_username'] ?? null,
                    ':mode_paiement' => $modePaiement,
                    ':statut' => $statut,
                    ':reference' => $entity['reference'] ?? null,
                    ':notes' => $entity['notes'] ?? '',
                    ':destinataire' => $entity['destinataire'] ?? null,
                    ':telephone_destinataire' => $entity['telephone_destinataire'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId,
                    ':created_at' => $entity['date_op'] ?? date('Y-m-d H:i:s')
                ]);
                
                // Vérifier si l'insertion a réellement réussi
                $insertId = $db->lastInsertId();
                if ($insertId > 0) {
                    // Marquer comme synchronisé après insertion réussie
                    $syncStmt = $db->prepare("UPDATE operations SET is_synced = 1, synced_at = NOW() WHERE id = :id");
                    $syncStmt->execute([':id' => $insertId]);
                    
                    $uploadedCount++;
                    error_log("SUCCESS: Opération insérée: ID={$insertId}, type={$type}, montant={$entity['montant_brut']}");
                } else {
                    error_log("WARNING: INSERT échoué: lastInsertId = 0");
                }
                } catch (PDOException $insertError) {
                    // Gérer les erreurs de duplication ou autre
                    if ($insertError->getCode() == 23000) {
                        // Erreur de duplication (duplicate key)
                        error_log("WARNING: Doublon ignoré: " . $insertError->getMessage());
                        continue; // Passer à l'opération suivante
                    } else {
                        // Autre erreur - logger et continuer
                        error_log("ERROR: Erreur INSERT: " . $insertError->getMessage());
                        error_log("   Données: type={$type}, montant={$entity['montant_brut']}, agent={$agentId}, shop={$shopSourceId}");
                        throw $insertError; // Re-lever l'exception pour le catch externe
                    }
                }
            } // Fermer le else (nouvelle opération)
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    } // Fermer le foreach
    
    // Commit de la transaction
    $db->commit();
    
    // Mettre à jour les métadonnées de synchronisation
    $metaStmt = $db->prepare("
        UPDATE sync_metadata 
        SET last_sync_date = NOW(), 
            sync_count = sync_count + 1,
            last_sync_user = :user_id
        WHERE table_name = 'operations'
    ");
    $metaStmt->execute([':user_id' => $userId]);
    
    $response = [
        'success' => true,
        'message' => 'Synchronisation réussie',
        'uploaded' => $uploadedCount,
        'updated' => $updatedCount,
        'total' => $uploadedCount + $updatedCount,
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    
    error_log("Upload error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>