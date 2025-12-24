<?php
/**
 * API pour traitement par lots des crédits virtuels
 * Endpoint: POST /api/credit-virtuels/batch
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

    if (!isset($data['credits']) || !is_array($data['credits'])) {
        throw new Exception('Tableau credits requis', 400);
    }

    if (!isset($data['shop_id'])) {
        throw new Exception('shop_id requis', 400);
    }

    $shopId = (int)$data['shop_id'];
    $credits = $data['credits'];

    // Connexion à la base de données
    $db = new Database();
    $conn = $db->getConnection();

    // Commencer une transaction
    $conn->beginTransaction();

    $processedCredits = [];
    $errors = [];

    foreach ($credits as $index => $creditData) {
        try {
            // Validation des données requises
            $requiredFields = ['reference', 'montant_credit', 'beneficiaire_nom', 'sim_numero', 'shop_id', 'agent_id', 'date_sortie'];
            foreach ($requiredFields as $field) {
                if (!isset($creditData[$field]) || $creditData[$field] === '') {
                    throw new Exception("Champ requis manquant ou vide: $field");
                }
            }

            // Vérifier si le crédit existe déjà par ID ou par référence unique
            $existingCredit = null;
            if (isset($creditData['id']) && $creditData['id']) {
                $checkSql = "SELECT id, last_modified_at FROM credit_virtuels WHERE id = :id";
                $checkStmt = $conn->prepare($checkSql);
                $checkStmt->bindParam(':id', $creditData['id'], PDO::PARAM_INT);
                $checkStmt->execute();
                $existingCredit = $checkStmt->fetch(PDO::FETCH_ASSOC);
            } else {
                // Vérifier par référence si pas d'ID
                $checkSql = "SELECT id, last_modified_at FROM credit_virtuels WHERE reference = :reference AND shop_id = :shop_id";
                $checkStmt = $conn->prepare($checkSql);
                $checkStmt->bindParam(':reference', $creditData['reference'], PDO::PARAM_STR);
                $checkStmt->bindParam(':shop_id', $creditData['shop_id'], PDO::PARAM_INT);
                $checkStmt->execute();
                $existingCredit = $checkStmt->fetch(PDO::FETCH_ASSOC);
            }

            $serverId = null;
            $action = 'created';

            if ($existingCredit) {
                // Vérifier si la version locale est plus récente
                $serverModified = $existingCredit['last_modified_at'] ? strtotime($existingCredit['last_modified_at']) : 0;
                $localModified = isset($creditData['last_modified_at']) ? strtotime($creditData['last_modified_at']) : time();

                if ($localModified > $serverModified) {
                    // Mise à jour
                    $sql = "
                        UPDATE credit_virtuels SET
                            reference = :reference,
                            montant_credit = :montant_credit,
                            devise = :devise,
                            beneficiaire_nom = :beneficiaire_nom,
                            beneficiaire_telephone = :beneficiaire_telephone,
                            beneficiaire_adresse = :beneficiaire_adresse,
                            type_beneficiaire = :type_beneficiaire,
                            sim_numero = :sim_numero,
                            shop_id = :shop_id,
                            shop_designation = :shop_designation,
                            agent_id = :agent_id,
                            agent_username = :agent_username,
                            statut = :statut,
                            date_sortie = :date_sortie,
                            date_paiement = :date_paiement,
                            date_echeance = :date_echeance,
                            notes = :notes,
                            montant_paye = :montant_paye,
                            mode_paiement = :mode_paiement,
                            reference_paiement = :reference_paiement,
                            last_modified_at = :last_modified_at,
                            last_modified_by = :last_modified_by,
                            is_synced = 1,
                            synced_at = NOW()
                        WHERE id = :id
                    ";
                    $stmt = $conn->prepare($sql);
                    $stmt->bindParam(':id', $existingCredit['id'], PDO::PARAM_INT);
                    $serverId = $existingCredit['id'];
                    $action = 'updated';
                } else {
                    // Version serveur plus récente, ignorer
                    $serverId = $existingCredit['id'];
                    $action = 'skipped';
                }
            } else {
                // Insertion
                $sql = "
                    INSERT INTO credit_virtuels (
                        reference, montant_credit, devise, beneficiaire_nom, beneficiaire_telephone,
                        beneficiaire_adresse, type_beneficiaire, sim_numero, shop_id, shop_designation,
                        agent_id, agent_username, statut, date_sortie, date_paiement, date_echeance,
                        notes, montant_paye, mode_paiement, reference_paiement, last_modified_at,
                        last_modified_by, is_synced, synced_at
                    ) VALUES (
                        :reference, :montant_credit, :devise, :beneficiaire_nom, :beneficiaire_telephone,
                        :beneficiaire_adresse, :type_beneficiaire, :sim_numero, :shop_id, :shop_designation,
                        :agent_id, :agent_username, :statut, :date_sortie, :date_paiement, :date_echeance,
                        :notes, :montant_paye, :mode_paiement, :reference_paiement, :last_modified_at,
                        :last_modified_by, 1, NOW()
                    )
                ";
                $stmt = $conn->prepare($sql);
            }

            if ($action !== 'skipped') {
                // Bind des paramètres
                $stmt->bindParam(':reference', $creditData['reference'], PDO::PARAM_STR);
                $stmt->bindParam(':montant_credit', $creditData['montant_credit'], PDO::PARAM_STR);
                
                $devise = $creditData['devise'] ?? 'USD';
                $stmt->bindParam(':devise', $devise, PDO::PARAM_STR);
                
                $stmt->bindParam(':beneficiaire_nom', $creditData['beneficiaire_nom'], PDO::PARAM_STR);
                $stmt->bindParam(':beneficiaire_telephone', $creditData['beneficiaire_telephone'], PDO::PARAM_STR);
                $stmt->bindParam(':beneficiaire_adresse', $creditData['beneficiaire_adresse'], PDO::PARAM_STR);
                
                $typeBeneficiaire = $creditData['type_beneficiaire'] ?? 'shop';
                $stmt->bindParam(':type_beneficiaire', $typeBeneficiaire, PDO::PARAM_STR);
                
                $stmt->bindParam(':sim_numero', $creditData['sim_numero'], PDO::PARAM_STR);
                $stmt->bindParam(':shop_id', $creditData['shop_id'], PDO::PARAM_INT);
                $stmt->bindParam(':shop_designation', $creditData['shop_designation'], PDO::PARAM_STR);
                $stmt->bindParam(':agent_id', $creditData['agent_id'], PDO::PARAM_INT);
                $stmt->bindParam(':agent_username', $creditData['agent_username'], PDO::PARAM_STR);
                
                $statut = $creditData['statut'] ?? 'accorde';
                $stmt->bindParam(':statut', $statut, PDO::PARAM_STR);
                
                $stmt->bindParam(':date_sortie', $creditData['date_sortie'], PDO::PARAM_STR);
                $stmt->bindParam(':date_paiement', $creditData['date_paiement'], PDO::PARAM_STR);
                $stmt->bindParam(':date_echeance', $creditData['date_echeance'], PDO::PARAM_STR);
                $stmt->bindParam(':notes', $creditData['notes'], PDO::PARAM_STR);
                
                $montantPaye = $creditData['montant_paye'] ?? 0.0;
                $stmt->bindParam(':montant_paye', $montantPaye, PDO::PARAM_STR);
                
                $stmt->bindParam(':mode_paiement', $creditData['mode_paiement'], PDO::PARAM_STR);
                $stmt->bindParam(':reference_paiement', $creditData['reference_paiement'], PDO::PARAM_STR);
                
                $lastModified = $creditData['last_modified_at'] ?? date('Y-m-d H:i:s');
                $stmt->bindParam(':last_modified_at', $lastModified, PDO::PARAM_STR);
                
                $lastModifiedBy = $creditData['last_modified_by'] ?? 'sync_service';
                $stmt->bindParam(':last_modified_by', $lastModifiedBy, PDO::PARAM_STR);

                $stmt->execute();

                if ($action === 'created') {
                    $serverId = $conn->lastInsertId();
                }
            }

            $processedCredits[] = [
                'local_id' => $creditData['id'] ?? null,
                'server_id' => (int)$serverId,
                'action' => $action,
                'reference' => $creditData['reference'],
                'montant_credit' => $creditData['montant_credit']
            ];

        } catch (Exception $e) {
            $errors[] = [
                'index' => $index,
                'credit_id' => $creditData['id'] ?? 'unknown',
                'reference' => $creditData['reference'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }

    // Valider la transaction
    $conn->commit();
    
    // Statistiques
    $stats = [
        'created' => count(array_filter($processedCredits, fn($c) => $c['action'] === 'created')),
        'updated' => count(array_filter($processedCredits, fn($c) => $c['action'] === 'updated')),
        'skipped' => count(array_filter($processedCredits, fn($c) => $c['action'] === 'skipped')),
        'errors' => count($errors)
    ];
    
    // Log de l'activité
    error_log("API credit-virtuels/batch: Shop $shopId - " . json_encode($stats));
    
    // Retourner le résultat
    echo json_encode([
        'success' => true,
        'synced_credits' => $processedCredits,
        'errors' => $errors,
        'statistics' => $stats,
        'total_processed' => count($processedCredits),
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
    error_log("Erreur PDO dans credit-virtuels/batch: " . $e->getMessage());
    
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
    error_log("Erreur dans credit-virtuels/batch: " . $e->getMessage());
}
?>
