<?php
/**
 * API pour uploader les crédits inter-shop tracking vers le serveur
 * Endpoint: POST /api/credit-intershop-tracking/upload
 * 
 * LOGIQUE MÉTIER:
 * - Suit les dettes internes entre shops normaux et shop principal
 * - Permet la consolidation des dettes au niveau du shop principal
 * 
 * FLUX:
 * - Shop Normal (C, D, E, F) initie transfert → Kampala sert
 * - Dette INTERNE: Shop Normal doit à Durba (principale)
 * - Dette EXTERNE: Durba doit à Kampala (consolidée)
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

    if (!isset($data['trackings']) || !is_array($data['trackings'])) {
        throw new Exception('Tableau trackings requis', 400);
    }

    $trackings = $data['trackings'];

    // Connexion à la base de données
    $db = new Database();
    $conn = $db->getConnection();

    // Commencer une transaction
    $conn->beginTransaction();

    $syncedTrackings = [];
    $errors = [];

    foreach ($trackings as $trackingData) {
        try {
            // Validation des données requises
            $requiredFields = [
                'shop_principal_id', 'shop_normal_id', 'shop_service_id',
                'montant_brut', 'montant_net', 'commission', 'date_operation', 'date_consolidation'
            ];
            
            foreach ($requiredFields as $field) {
                if (!isset($trackingData[$field])) {
                    throw new Exception("Champ requis manquant: $field");
                }
            }

            // Vérifier si le tracking existe déjà
            $checkSql = "SELECT id FROM credit_intershop_tracking WHERE id = :id";
            $checkStmt = $conn->prepare($checkSql);
            $checkStmt->bindParam(':id', $trackingData['id'], PDO::PARAM_INT);
            $checkStmt->execute();
            $existingTracking = $checkStmt->fetch();

            if ($existingTracking) {
                // Mise à jour
                $sql = "
                    UPDATE credit_intershop_tracking SET
                        shop_principal_id = :shop_principal_id,
                        shop_principal_designation = :shop_principal_designation,
                        shop_normal_id = :shop_normal_id,
                        shop_normal_designation = :shop_normal_designation,
                        shop_service_id = :shop_service_id,
                        shop_service_designation = :shop_service_designation,
                        montant_brut = :montant_brut,
                        montant_net = :montant_net,
                        commission = :commission,
                        devise = :devise,
                        operation_id = :operation_id,
                        operation_reference = :operation_reference,
                        date_operation = :date_operation,
                        date_consolidation = :date_consolidation,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = :id
                ";
                $stmt = $conn->prepare($sql);
                $stmt->bindParam(':id', $trackingData['id'], PDO::PARAM_INT);
            } else {
                // Insertion
                $sql = "
                    INSERT INTO credit_intershop_tracking (
                        shop_principal_id, shop_principal_designation,
                        shop_normal_id, shop_normal_designation,
                        shop_service_id, shop_service_designation,
                        montant_brut, montant_net, commission, devise,
                        operation_id, operation_reference,
                        date_operation, date_consolidation,
                        last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (
                        :shop_principal_id, :shop_principal_designation,
                        :shop_normal_id, :shop_normal_designation,
                        :shop_service_id, :shop_service_designation,
                        :montant_brut, :montant_net, :commission, :devise,
                        :operation_id, :operation_reference,
                        :date_operation, :date_consolidation,
                        :last_modified_at, :last_modified_by,
                        1, NOW()
                    )
                ";
                $stmt = $conn->prepare($sql);
            }

            // Bind des paramètres
            $stmt->bindParam(':shop_principal_id', $trackingData['shop_principal_id'], PDO::PARAM_INT);
            $stmt->bindParam(':shop_principal_designation', $trackingData['shop_principal_designation'], PDO::PARAM_STR);
            $stmt->bindParam(':shop_normal_id', $trackingData['shop_normal_id'], PDO::PARAM_INT);
            $stmt->bindParam(':shop_normal_designation', $trackingData['shop_normal_designation'], PDO::PARAM_STR);
            $stmt->bindParam(':shop_service_id', $trackingData['shop_service_id'], PDO::PARAM_INT);
            $stmt->bindParam(':shop_service_designation', $trackingData['shop_service_designation'], PDO::PARAM_STR);
            $stmt->bindParam(':montant_brut', $trackingData['montant_brut'], PDO::PARAM_STR);
            $stmt->bindParam(':montant_net', $trackingData['montant_net'], PDO::PARAM_STR);
            $stmt->bindParam(':commission', $trackingData['commission'], PDO::PARAM_STR);
            $stmt->bindParam(':devise', $trackingData['devise'] ?? 'USD', PDO::PARAM_STR);
            $stmt->bindParam(':operation_id', $trackingData['operation_id'], PDO::PARAM_INT);
            $stmt->bindParam(':operation_reference', $trackingData['operation_reference'], PDO::PARAM_STR);
            $stmt->bindParam(':date_operation', $trackingData['date_operation'], PDO::PARAM_STR);
            $stmt->bindParam(':date_consolidation', $trackingData['date_consolidation'], PDO::PARAM_STR);
            $stmt->bindParam(':last_modified_at', $trackingData['last_modified_at'], PDO::PARAM_STR);
            $stmt->bindParam(':last_modified_by', $trackingData['last_modified_by'], PDO::PARAM_STR);

            $stmt->execute();

            // Récupérer l'ID du tracking (nouveau ou existant)
            $serverId = $existingTracking ? $trackingData['id'] : $conn->lastInsertId();

            $syncedTrackings[] = [
                'id' => $trackingData['id'], // ID local
                'server_id' => (int)$serverId, // ID serveur
                'status' => $existingTracking ? 'updated' : 'created'
            ];

        } catch (Exception $e) {
            $errors[] = [
                'tracking_id' => $trackingData['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }

    // Valider la transaction si pas d'erreurs critiques
    if (empty($errors) || count($syncedTrackings) > 0) {
        $conn->commit();
        
        // Log de l'activité
        error_log("API credit-intershop-tracking/upload: " . count($syncedTrackings) . " trackings synchronisés, " . count($errors) . " erreurs");
        
        // Retourner le résultat
        echo json_encode([
            'success' => true,
            'synced_trackings' => $syncedTrackings,
            'errors' => $errors,
            'total_synced' => count($syncedTrackings),
            'total_errors' => count($errors)
        ], JSON_UNESCAPED_UNICODE);
        
    } else {
        $conn->rollback();
        throw new Exception('Trop d\'erreurs lors de la synchronisation');
    }

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
    error_log("Erreur PDO dans credit-intershop-tracking/upload: " . $e->getMessage());
    
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
    error_log("Erreur dans credit-intershop-tracking/upload: " . $e->getMessage());
}
?>
