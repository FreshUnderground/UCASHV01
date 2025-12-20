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

// Fonction de conversion du statut Flutter vers MySQL
function _convertMultiMonthPaymentStatus($index) {
    // Flutter enum: enAttente=0, validee=1, annulee=2
    // MySQL ENUM: 'enAttente', 'validee', 'annulee'
    $statuses = ['enAttente', 'validee', 'annulee'];
    return $statuses[$index] ?? 'enAttente';
}

try {
    // Lire les données JSON
    $input = file_get_contents('php://input');
    if (empty($input)) {
        throw new Exception('Aucune donnée reçue');
    }

    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON invalide: ' . json_last_error_msg());
    }

    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Format de données invalide: entities manquant');
    }

    $entities = $data['entities'];
    
    // Connexion à la base de données
    $database = new Database();
    $pdo = $database->getConnection();
    
    if (!$pdo) {
        throw new Exception('Impossible de se connecter à la base de données');
    }

    $pdo->beginTransaction();

    $uploaded = 0;
    $updated = 0;
    $errors = [];

    foreach ($entities as $entity) {
        try {
            // Validation des champs obligatoires
            $requiredFields = ['reference', 'service_type', 'montant_mensuel', 'nombre_mois', 'montant_total', 'shop_id', 'agent_id'];
            foreach ($requiredFields as $field) {
                if (!isset($entity[$field])) {
                    throw new Exception("Champ obligatoire manquant: $field");
                }
            }

            // Convertir le statut si c'est un index
            if (isset($entity['statut']) && is_numeric($entity['statut'])) {
                $entity['statut'] = _convertMultiMonthPaymentStatus($entity['statut']);
            }

            // Vérifier si l'enregistrement existe déjà (par référence unique)
            $checkStmt = $pdo->prepare("SELECT id FROM multi_month_payments WHERE reference = ?");
            $checkStmt->execute([$entity['reference']]);
            $existingId = $checkStmt->fetchColumn();

            if ($existingId) {
                // Mise à jour
                $updateStmt = $pdo->prepare("
                    UPDATE multi_month_payments SET
                        service_type = ?,
                        service_description = ?,
                        montant_mensuel = ?,
                        nombre_mois = ?,
                        montant_total = ?,
                        devise = ?,
                        bonus = ?,
                        heures_supplementaires = ?,
                        taux_horaire_supp = ?,
                        montant_heures_supp = ?,
                        montant_final_avec_ajustements = ?,
                        date_debut = ?,
                        date_fin = ?,
                        client_id = ?,
                        client_nom = ?,
                        client_telephone = ?,
                        numero_compte = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        agent_id = ?,
                        agent_username = ?,
                        destinataire = ?,
                        telephone_destinataire = ?,
                        notes = ?,
                        statut = ?,
                        date_validation = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = ?
                ");

                $updateStmt->execute([
                    $entity['service_type'] ?? '',
                    $entity['service_description'] ?? '',
                    $entity['montant_mensuel'] ?? 0,
                    $entity['nombre_mois'] ?? 1,
                    $entity['montant_total'] ?? 0,
                    $entity['devise'] ?? 'USD',
                    $entity['bonus'] ?? 0,
                    $entity['heures_supplementaires'] ?? 0,
                    $entity['taux_horaire_supp'] ?? 0,
                    $entity['montant_heures_supp'] ?? 0,
                    $entity['montant_final_avec_ajustements'] ?? 0,
                    $entity['date_debut'] ?? null,
                    $entity['date_fin'] ?? null,
                    $entity['client_id'] ?? null,
                    $entity['client_nom'] ?? null,
                    $entity['client_telephone'] ?? null,
                    $entity['numero_compte'] ?? null,
                    $entity['shop_id'] ?? null,
                    $entity['shop_designation'] ?? null,
                    $entity['agent_id'] ?? null,
                    $entity['agent_username'] ?? null,
                    $entity['destinataire'] ?? null,
                    $entity['telephone_destinataire'] ?? null,
                    $entity['notes'] ?? null,
                    $entity['statut'] ?? 'enAttente',
                    $entity['date_validation'] ?? null,
                    $entity['last_modified_at'] ?? null,
                    $entity['last_modified_by'] ?? null,
                    $existingId
                ]);
                $updated++;
            } else {
                // Insertion
                $insertStmt = $pdo->prepare("
                    INSERT INTO multi_month_payments (
                        reference, service_type, service_description, montant_mensuel, nombre_mois, montant_total,
                        devise, bonus, heures_supplementaires, taux_horaire_supp, montant_heures_supp,
                        montant_final_avec_ajustements, date_debut, date_fin, client_id, client_nom,
                        client_telephone, numero_compte, shop_id, shop_designation, agent_id, agent_username,
                        destinataire, telephone_destinataire, notes, statut, date_creation, date_validation,
                        last_modified_at, last_modified_by, is_synced, synced_at
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW()
                    )
                ");

                $insertStmt->execute([
                    $entity['reference'],
                    $entity['service_type'] ?? '',
                    $entity['service_description'] ?? '',
                    $entity['montant_mensuel'] ?? 0,
                    $entity['nombre_mois'] ?? 1,
                    $entity['montant_total'] ?? 0,
                    $entity['devise'] ?? 'USD',
                    $entity['bonus'] ?? 0,
                    $entity['heures_supplementaires'] ?? 0,
                    $entity['taux_horaire_supp'] ?? 0,
                    $entity['montant_heures_supp'] ?? 0,
                    $entity['montant_final_avec_ajustements'] ?? 0,
                    $entity['date_debut'] ?? null,
                    $entity['date_fin'] ?? null,
                    $entity['client_id'] ?? null,
                    $entity['client_nom'] ?? null,
                    $entity['client_telephone'] ?? null,
                    $entity['numero_compte'] ?? null,
                    $entity['shop_id'] ?? null,
                    $entity['shop_designation'] ?? null,
                    $entity['agent_id'] ?? null,
                    $entity['agent_username'] ?? null,
                    $entity['destinataire'] ?? null,
                    $entity['telephone_destinataire'] ?? null,
                    $entity['notes'] ?? null,
                    $entity['statut'] ?? 'enAttente',
                    $entity['date_creation'] ?? null,
                    $entity['date_validation'] ?? null,
                    $entity['last_modified_at'] ?? null,
                    $entity['last_modified_by'] ?? null
                ]);
                $uploaded++;
            }

        } catch (Exception $e) {
            $errors[] = [
                'reference' => $entity['reference'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }

    $pdo->commit();

    // Réponse de succès
    echo json_encode([
        'success' => true,
        'message' => 'Synchronisation terminée',
        'uploaded' => $uploaded,
        'updated' => $updated,
        'total_processed' => count($entities),
        'errors' => $errors
    ]);

} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
}
?>
