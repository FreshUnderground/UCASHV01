<?php
/**
 * API de synchronisation - Upload Personnel
 * Reçoit les données de personnel depuis l'application mobile
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../../db_connect.php';

try {
    // Lire les données POST
    $json = file_get_contents('php://input');
    $request = json_decode($json, true);

    if (!isset($request['data']) || !is_array($request['data'])) {
        throw new Exception('Invalid request format');
    }

    $data = $request['data'];
    $insertedCount = 0;
    $updatedCount = 0;
    $errorCount = 0;

    foreach ($data as $personnel) {
        try {
            // Vérifier si le personnel existe déjà
            $stmt = $pdo->prepare("SELECT id FROM personnel WHERE id = ?");
            $stmt->execute([$personnel['id']]);
            $exists = $stmt->fetch();

            if ($exists) {
                // Mise à jour
                $stmt = $pdo->prepare("
                    UPDATE personnel SET
                        matricule = ?,
                        nom = ?,
                        prenom = ?,
                        telephone = ?,
                        email = ?,
                        adresse = ?,
                        date_naissance = ?,
                        lieu_naissance = ?,
                        sexe = ?,
                        etat_civil = ?,
                        nombre_enfants = ?,
                        poste = ?,
                        departement = ?,
                        shop_id = ?,
                        date_embauche = ?,
                        date_fin_contrat = ?,
                        type_contrat = ?,
                        statut = ?,
                        salaire_base = ?,
                        devise_salaire = ?,
                        prime_transport = ?,
                        prime_logement = ?,
                        prime_fonction = ?,
                        autres_primes = ?,
                        numero_compte_bancaire = ?,
                        banque = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = ?
                ");
                $stmt->execute([
                    $personnel['matricule'],
                    $personnel['nom'],
                    $personnel['prenom'],
                    $personnel['telephone'],
                    $personnel['email'] ?? null,
                    $personnel['adresse'] ?? null,
                    $personnel['date_naissance'] ?? null,
                    $personnel['lieu_naissance'] ?? null,
                    $personnel['sexe'] ?? 'M',
                    $personnel['etat_civil'] ?? 'Celibataire',
                    $personnel['nombre_enfants'] ?? 0,
                    $personnel['poste'],
                    $personnel['departement'] ?? null,
                    $personnel['shop_id'] ?? null,
                    $personnel['date_embauche'],
                    $personnel['date_fin_contrat'] ?? null,
                    $personnel['type_contrat'] ?? 'CDI',
                    $personnel['statut'] ?? 'Actif',
                    $personnel['salaire_base'] ?? 0,
                    $personnel['devise_salaire'] ?? 'USD',
                    $personnel['prime_transport'] ?? 0,
                    $personnel['prime_logement'] ?? 0,
                    $personnel['prime_fonction'] ?? 0,
                    $personnel['autres_primes'] ?? 0,
                    $personnel['numero_compte_bancaire'] ?? null,
                    $personnel['banque'] ?? null,
                    $personnel['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $personnel['last_modified_by'] ?? 'system',
                    $personnel['id']
                ]);
                $updatedCount++;
            } else {
                // Insertion
                $stmt = $pdo->prepare("
                    INSERT INTO personnel (
                        id, matricule, nom, prenom, telephone, email, adresse,
                        date_naissance, lieu_naissance, sexe, etat_civil, nombre_enfants,
                        poste, departement, shop_id, date_embauche, date_fin_contrat,
                        type_contrat, statut, salaire_base, devise_salaire,
                        prime_transport, prime_logement, prime_fonction, autres_primes,
                        numero_compte_bancaire, banque, last_modified_at, last_modified_by,
                        is_synced, synced_at, created_at
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                        ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), NOW()
                    )
                ");
                $stmt->execute([
                    $personnel['id'],
                    $personnel['matricule'],
                    $personnel['nom'],
                    $personnel['prenom'],
                    $personnel['telephone'],
                    $personnel['email'] ?? null,
                    $personnel['adresse'] ?? null,
                    $personnel['date_naissance'] ?? null,
                    $personnel['lieu_naissance'] ?? null,
                    $personnel['sexe'] ?? 'M',
                    $personnel['etat_civil'] ?? 'Celibataire',
                    $personnel['nombre_enfants'] ?? 0,
                    $personnel['poste'],
                    $personnel['departement'] ?? null,
                    $personnel['shop_id'] ?? null,
                    $personnel['date_embauche'],
                    $personnel['date_fin_contrat'] ?? null,
                    $personnel['type_contrat'] ?? 'CDI',
                    $personnel['statut'] ?? 'Actif',
                    $personnel['salaire_base'] ?? 0,
                    $personnel['devise_salaire'] ?? 'USD',
                    $personnel['prime_transport'] ?? 0,
                    $personnel['prime_logement'] ?? 0,
                    $personnel['prime_fonction'] ?? 0,
                    $personnel['autres_primes'] ?? 0,
                    $personnel['numero_compte_bancaire'] ?? null,
                    $personnel['banque'] ?? null,
                    $personnel['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $personnel['last_modified_by'] ?? 'system'
                ]);
                $insertedCount++;
            }
        } catch (PDOException $e) {
            error_log("Error syncing personnel ID " . ($personnel['id'] ?? 'unknown') . ": " . $e->getMessage());
            $errorCount++;
        }
    }

    echo json_encode([
        'success' => true,
        'message' => "Sync completed: $insertedCount inserted, $updatedCount updated, $errorCount errors",
        'stats' => [
            'inserted' => $insertedCount,
            'updated' => $updatedCount,
            'errors' => $errorCount,
            'total' => count($data)
        ]
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
