<?php
/**
 * API pour traitement par lots des retraits virtuels
 * Endpoint: POST /api/retrait-virtuels/batch
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Gérer les requêtes OPTIONS (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    // Vérifier la méthode HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Méthode non autorisée', 405);
    }

    // Récupérer les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data) {
        throw new Exception('Données JSON invalides', 400);
    }

    if (!isset($data['retraits']) || !is_array($data['retraits'])) {
        throw new Exception('Tableau retraits requis', 400);
    }

    if (!isset($data['shop_id'])) {
        throw new Exception('shop_id requis', 400);
    }

    $shopId = (int)$data['shop_id'];
    $retraits = $data['retraits'];

    // Connexion à la base de données
    $db = new Database();
    $conn = $db->getConnection();

    // Commencer une transaction
    $conn->beginTransaction();

    $processedRetraits = [];
    $errors = [];

    foreach ($retraits as $index => $retraitData) {
        try {
            // Validation des données requises
            $requiredFields = ['sim_numero', 'shop_source_id', 'shop_debiteur_id', 'montant', 'agent_id', 'date_retrait'];
            foreach ($requiredFields as $field) {
                if (!isset($retraitData[$field]) || $retraitData[$field] === '') {
                    throw new Exception("Champ requis manquant ou vide: $field");
                }
            }

            // Vérifier si le retrait existe déjà par ID ou par combinaison unique
            $existingRetrait = null;
            if (isset($retraitData['id']) && $retraitData['id']) {
                $checkSql = "SELECT id, last_modified_at FROM retrait_virtuels WHERE id = :id";
                $checkStmt = $conn->prepare($checkSql);
                $checkStmt->bindParam(':id', $retraitData['id'], PDO::PARAM_INT);
                $checkStmt->execute();
                $existingRetrait = $checkStmt->fetch(PDO::FETCH_ASSOC);
            }

            $serverId = null;
            $action = 'created';

            if ($existingRetrait) {
                // Vérifier si la version locale est plus récente
                $serverModified = $existingRetrait['last_modified_at'] ? strtotime($existingRetrait['last_modified_at']) : 0;
                $localModified = isset($retraitData['last_modified_at']) ? strtotime($retraitData['last_modified_at']) : time();

                if ($localModified > $serverModified) {
                    // Mise à jour
                    $sql = "
                        UPDATE retrait_virtuels SET
                            sim_numero = :sim_numero,
                            sim_operateur = :sim_operateur,
                            shop_source_id = :shop_source_id,
                            shop_source_designation = :shop_source_designation,
                            shop_debiteur_id = :shop_debiteur_id,
                            shop_debiteur_designation = :shop_debiteur_designation,
                            montant = :montant,
                            devise = :devise,
                            solde_avant = :solde_avant,
                            solde_apres = :solde_apres,
                            agent_id = :agent_id,
                            agent_username = :agent_username,
                            notes = :notes,
                            statut = :statut,
                            date_retrait = :date_retrait,
                            date_remboursement = :date_remboursement,
                            flot_remboursement_id = :flot_remboursement_id,
                            last_modified_at = :last_modified_at,
                            last_modified_by = :last_modified_by,
                            is_synced = 1,
                            synced_at = NOW()
                        WHERE id = :id
                    ";
                    $stmt = $conn->prepare($sql);
                    $stmt->bindParam(':id', $retraitData['id'], PDO::PARAM_INT);
                    $serverId = $retraitData['id'];
                    $action = 'updated';
                } else {
                    // Version serveur plus récente, ignorer
                    $serverId = $existingRetrait['id'];
                    $action = 'skipped';
                }
            } else {
                // Insertion
                $sql = "
                    INSERT INTO retrait_virtuels (
                        sim_numero, sim_operateur, shop_source_id, shop_source_designation,
                        shop_debiteur_id, shop_debiteur_designation, montant, devise,
                        solde_avant, solde_apres, agent_id, agent_username, notes,
                        statut, date_retrait, date_remboursement, flot_remboursement_id,
                        last_modified_at, last_modified_by, is_synced, synced_at
                    ) VALUES (
                        :sim_numero, :sim_operateur, :shop_source_id, :shop_source_designation,
                        :shop_debiteur_id, :shop_debiteur_designation, :montant, :devise,
                        :solde_avant, :solde_apres, :agent_id, :agent_username, :notes,
                        :statut, :date_retrait, :date_remboursement, :flot_remboursement_id,
                        :last_modified_at, :last_modified_by, 1, NOW()
                    )
                ";
                $stmt = $conn->prepare($sql);
            }

            if ($action !== 'skipped') {
                // Bind des paramètres
                $stmt->bindParam(':sim_numero', $retraitData['sim_numero'], PDO::PARAM_STR);
                $stmt->bindParam(':sim_operateur', $retraitData['sim_operateur'], PDO::PARAM_STR);
                $stmt->bindParam(':shop_source_id', $retraitData['shop_source_id'], PDO::PARAM_INT);
                $stmt->bindParam(':shop_source_designation', $retraitData['shop_source_designation'], PDO::PARAM_STR);
                $stmt->bindParam(':shop_debiteur_id', $retraitData['shop_debiteur_id'], PDO::PARAM_INT);
                $stmt->bindParam(':shop_debiteur_designation', $retraitData['shop_debiteur_designation'], PDO::PARAM_STR);
                $stmt->bindParam(':montant', $retraitData['montant'], PDO::PARAM_STR);
                
                $devise = $retraitData['devise'] ?? 'USD';
                $stmt->bindParam(':devise', $devise, PDO::PARAM_STR);
                
                $stmt->bindParam(':solde_avant', $retraitData['solde_avant'], PDO::PARAM_STR);
                $stmt->bindParam(':solde_apres', $retraitData['solde_apres'], PDO::PARAM_STR);
                $stmt->bindParam(':agent_id', $retraitData['agent_id'], PDO::PARAM_INT);
                $stmt->bindParam(':agent_username', $retraitData['agent_username'], PDO::PARAM_STR);
                $stmt->bindParam(':notes', $retraitData['notes'], PDO::PARAM_STR);
                
                $statut = $retraitData['statut'] ?? 'enAttente';
                $stmt->bindParam(':statut', $statut, PDO::PARAM_STR);
                
                $stmt->bindParam(':date_retrait', $retraitData['date_retrait'], PDO::PARAM_STR);
                $stmt->bindParam(':date_remboursement', $retraitData['date_remboursement'], PDO::PARAM_STR);
                $stmt->bindParam(':flot_remboursement_id', $retraitData['flot_remboursement_id'], PDO::PARAM_INT);
                
                $lastModified = $retraitData['last_modified_at'] ?? date('Y-m-d H:i:s');
                $stmt->bindParam(':last_modified_at', $lastModified, PDO::PARAM_STR);
                
                $lastModifiedBy = $retraitData['last_modified_by'] ?? 'sync_service';
                $stmt->bindParam(':last_modified_by', $lastModifiedBy, PDO::PARAM_STR);

                $stmt->execute();

                if ($action === 'created') {
                    $serverId = $conn->lastInsertId();
                }
            }

            $processedRetraits[] = [
                'local_id' => $retraitData['id'] ?? null,
                'server_id' => (int)$serverId,
                'action' => $action,
                'sim_numero' => $retraitData['sim_numero'],
                'montant' => $retraitData['montant']
            ];

        } catch (Exception $e) {
            $errors[] = [
                'index' => $index,
                'retrait_id' => $retraitData['id'] ?? 'unknown',
                'sim_numero' => $retraitData['sim_numero'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }

    // Valider la transaction
    $conn->commit();
    
    // Statistiques
    $stats = [
        'created' => count(array_filter($processedRetraits, fn($r) => $r['action'] === 'created')),
        'updated' => count(array_filter($processedRetraits, fn($r) => $r['action'] === 'updated')),
        'skipped' => count(array_filter($processedRetraits, fn($r) => $r['action'] === 'skipped')),
        'errors' => count($errors)
    ];
    
    // Log de l'activité
    error_log("API retrait-virtuels/batch: Shop $shopId - " . json_encode($stats));
    
    // Retourner le résultat
    echo json_encode([
        'success' => true,
        'synced_retraits' => $processedRetraits,
        'errors' => $errors,
        'statistics' => $stats,
        'total_processed' => count($processedRetraits),
        'total_errors' => count($errors)
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    if (isset($conn)) {
        $conn->rollback();
    }
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur base de données',
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur PDO dans retrait-virtuels/batch: " . $e->getMessage());
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback();
    }
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur dans retrait-virtuels/batch: " . $e->getMessage());
}
?>
