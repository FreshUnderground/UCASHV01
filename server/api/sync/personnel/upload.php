<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Lire les données POST
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Données invalides: entities requis');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $uploadedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    // Début de transaction
    $pdo->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
            $tableName = $entity['_table'] ?? 'personnel';
            
            // Router vers la bonne table
            switch ($tableName) {
                case 'personnel':
                    handlePersonnel($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                case 'salaires':
                    handleSalaire($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                case 'avances_personnel':
                    handleAvance($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                case 'credits_personnel':
                    handleCredit($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                case 'remboursements_credits':
                    handleRemboursement($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                case 'fiches_paie':
                    handleFichePaie($pdo, $entity, $userId, $uploadedCount, $updatedCount);
                    break;
                default:
                    throw new Exception("Table inconnue: $tableName");
            }
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'table' => $tableName ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    // Valider la transaction
    $pdo->commit();
    
    echo json_encode([
        'success' => true,
        'uploaded_count' => $uploadedCount,
        'updated_count' => $updatedCount,
        'errors' => $errors
    ]);
    
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

// ============================================================================
// FONCTIONS DE GESTION PAR TABLE
// ============================================================================

function handlePersonnel($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    $checkStmt = $pdo->prepare("SELECT id FROM personnel WHERE id = :id");
    $checkStmt->execute([':id' => $entity['id'] ?? 0]);
    $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($exists) {
        // UPDATE
        $stmt = $pdo->prepare("
            UPDATE personnel SET
                matricule = :matricule,
                nom = :nom,
                prenom = :prenom,
                telephone = :telephone,
                email = :email,
                adresse = :adresse,
                date_naissance = :date_naissance,
                lieu_naissance = :lieu_naissance,
                sexe = :sexe,
                etat_civil = :etat_civil,
                nombre_enfants = :nombre_enfants,
                numero_cnss = :numero_cnss,
                numero_compte_bancaire = :numero_compte_bancaire,
                banque = :banque,
                poste = :poste,
                departement = :departement,
                type_contrat = :type_contrat,
                date_embauche = :date_embauche,
                date_fin_contrat = :date_fin_contrat,
                salaire_base = :salaire_base,
                prime_transport = :prime_transport,
                prime_logement = :prime_logement,
                prime_fonction = :prime_fonction,
                autres_primes = :autres_primes,
                devise_salaire = :devise_salaire,
                mode_paiement = :mode_paiement,
                statut = :statut,
                motif_depart = :motif_depart,
                date_depart = :date_depart,
                notes = :notes,
                last_modified_at = :last_modified_at,
                last_modified_by = :last_modified_by
            WHERE id = :id
        ");
        
        $stmt->execute([
            ':id' => $entity['id'],
            ':matricule' => $entity['matricule'] ?? '',
            ':nom' => $entity['nom'] ?? '',
            ':prenom' => $entity['prenom'] ?? '',
            ':telephone' => $entity['telephone'] ?? '',
            ':email' => $entity['email'] ?? null,
            ':adresse' => $entity['adresse'] ?? null,
            ':date_naissance' => $entity['date_naissance'] ?? null,
            ':lieu_naissance' => $entity['lieu_naissance'] ?? null,
            ':sexe' => $entity['sexe'] ?? 'M',
            ':etat_civil' => $entity['etat_civil'] ?? 'Celibataire',
            ':nombre_enfants' => $entity['nombre_enfants'] ?? 0,
            ':numero_cnss' => $entity['numero_cnss'] ?? null,
            ':numero_compte_bancaire' => $entity['numero_compte_bancaire'] ?? null,
            ':banque' => $entity['banque'] ?? null,
            ':poste' => $entity['poste'] ?? '',
            ':departement' => $entity['departement'] ?? null,
            ':type_contrat' => $entity['type_contrat'] ?? 'CDI',
            ':date_embauche' => $entity['date_embauche'] ?? date('Y-m-d'),
            ':date_fin_contrat' => $entity['date_fin_contrat'] ?? null,
            ':salaire_base' => $entity['salaire_base'] ?? 0,
            ':prime_transport' => $entity['prime_transport'] ?? 0,
            ':prime_logement' => $entity['prime_logement'] ?? 0,
            ':prime_fonction' => $entity['prime_fonction'] ?? 0,
            ':autres_primes' => $entity['autres_primes'] ?? 0,
            ':devise_salaire' => $entity['devise_salaire'] ?? 'USD',
            ':mode_paiement' => $entity['mode_paiement'] ?? 'Especes',
            ':statut' => $entity['statut'] ?? 'Actif',
            ':motif_depart' => $entity['motif_depart'] ?? null,
            ':date_depart' => $entity['date_depart'] ?? null,
            ':notes' => $entity['notes'] ?? null,
            ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
            ':last_modified_by' => $userId
        ]);
        
        $syncStmt = $pdo->prepare("UPDATE personnel SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
        $syncStmt->execute([
            ':id' => $entity['id'],
            ':synced_at' => $entity['synced_at'] ?? date('c')
        ]);
        
        $updatedCount++;
    } else {
        // INSERT
        $stmt = $pdo->prepare("
            INSERT INTO personnel (
                id, matricule, nom, prenom, telephone, email, adresse,
                date_naissance, lieu_naissance, sexe, etat_civil, nombre_enfants,
                numero_cnss, numero_compte_bancaire, banque,
                poste, departement, type_contrat, date_embauche, date_fin_contrat,
                salaire_base, prime_transport, prime_logement, prime_fonction, autres_primes,
                devise_salaire, mode_paiement, statut, motif_depart, date_depart, notes,
                last_modified_at, last_modified_by, created_at
            ) VALUES (
                :id, :matricule, :nom, :prenom, :telephone, :email, :adresse,
                :date_naissance, :lieu_naissance, :sexe, :etat_civil, :nombre_enfants,
                :numero_cnss, :numero_compte_bancaire, :banque,
                :poste, :departement, :type_contrat, :date_embauche, :date_fin_contrat,
                :salaire_base, :prime_transport, :prime_logement, :prime_fonction, :autres_primes,
                :devise_salaire, :mode_paiement, :statut, :motif_depart, :date_depart, :notes,
                :last_modified_at, :last_modified_by, :created_at
            )
        ");
        
        $stmt->execute([
            ':id' => $entity['id'],
            ':matricule' => $entity['matricule'] ?? '',
            ':nom' => $entity['nom'] ?? '',
            ':prenom' => $entity['prenom'] ?? '',
            ':telephone' => $entity['telephone'] ?? '',
            ':email' => $entity['email'] ?? null,
            ':adresse' => $entity['adresse'] ?? null,
            ':date_naissance' => $entity['date_naissance'] ?? null,
            ':lieu_naissance' => $entity['lieu_naissance'] ?? null,
            ':sexe' => $entity['sexe'] ?? 'M',
            ':etat_civil' => $entity['etat_civil'] ?? 'Celibataire',
            ':nombre_enfants' => $entity['nombre_enfants'] ?? 0,
            ':numero_cnss' => $entity['numero_cnss'] ?? null,
            ':numero_compte_bancaire' => $entity['numero_compte_bancaire'] ?? null,
            ':banque' => $entity['banque'] ?? null,
            ':poste' => $entity['poste'] ?? '',
            ':departement' => $entity['departement'] ?? null,
            ':type_contrat' => $entity['type_contrat'] ?? 'CDI',
            ':date_embauche' => $entity['date_embauche'] ?? date('Y-m-d'),
            ':date_fin_contrat' => $entity['date_fin_contrat'] ?? null,
            ':salaire_base' => $entity['salaire_base'] ?? 0,
            ':prime_transport' => $entity['prime_transport'] ?? 0,
            ':prime_logement' => $entity['prime_logement'] ?? 0,
            ':prime_fonction' => $entity['prime_fonction'] ?? 0,
            ':autres_primes' => $entity['autres_primes'] ?? 0,
            ':devise_salaire' => $entity['devise_salaire'] ?? 'USD',
            ':mode_paiement' => $entity['mode_paiement'] ?? 'Especes',
            ':statut' => $entity['statut'] ?? 'Actif',
            ':motif_depart' => $entity['motif_depart'] ?? null,
            ':date_depart' => $entity['date_depart'] ?? null,
            ':notes' => $entity['notes'] ?? null,
            ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
            ':last_modified_by' => $userId,
            ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
        ]);
        
        $syncStmt = $pdo->prepare("UPDATE personnel SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
        $syncStmt->execute([
            ':id' => $entity['id'],
            ':synced_at' => $entity['synced_at'] ?? date('c')
        ]);
        
        $uploadedCount++;
    }
}

function handleSalaire($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    $checkStmt = $pdo->prepare("SELECT id FROM salaires WHERE id = :id");
    $checkStmt->execute([':id' => $entity['id'] ?? 0]);
    $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($exists) {
        $stmt = $pdo->prepare("
            UPDATE salaires SET
                personnel_id = :personnel_id,
                mois = :mois,
                annee = :annee,
                salaire_base = :salaire_base,
                prime_transport = :prime_transport,
                prime_logement = :prime_logement,
                prime_fonction = :prime_fonction,
                autres_primes = :autres_primes,
                heures_supplementaires = :heures_supplementaires,
                bonus = :bonus,
                salaire_brut = :salaire_brut,
                avances_deduites = :avances_deduites,
                credits_deduits = :credits_deduits,
                impots = :impots,
                cotisation_cnss = :cotisation_cnss,
                autres_deductions = :autres_deductions,
                total_deductions = :total_deductions,
                salaire_net = :salaire_net,
                devise = :devise,
                montant_paye = :montant_paye,
                montant_restant = :montant_restant,
                statut = :statut,
                mode_paiement = :mode_paiement,
                date_paiement = :date_paiement,
                notes = :notes,
                last_modified_at = :last_modified_at,
                last_modified_by = :last_modified_by
            WHERE id = :id
        ");
        
        $stmt->execute([
            ':id' => $entity['id'],
            ':personnel_id' => $entity['personnel_id'],
            ':mois' => $entity['mois'],
            ':annee' => $entity['annee'],
            ':salaire_base' => $entity['salaire_base'] ?? 0,
            ':prime_transport' => $entity['prime_transport'] ?? 0,
            ':prime_logement' => $entity['prime_logement'] ?? 0,
            ':prime_fonction' => $entity['prime_fonction'] ?? 0,
            ':autres_primes' => $entity['autres_primes'] ?? 0,
            ':heures_supplementaires' => $entity['heures_supplementaires'] ?? 0,
            ':bonus' => $entity['bonus'] ?? 0,
            ':salaire_brut' => $entity['salaire_brut'] ?? 0,
            ':avances_deduites' => $entity['avances_deduites'] ?? 0,
            ':credits_deduits' => $entity['credits_deduits'] ?? 0,
            ':impots' => $entity['impots'] ?? 0,
            ':cotisation_cnss' => $entity['cotisation_cnss'] ?? 0,
            ':autres_deductions' => $entity['autres_deductions'] ?? 0,
            ':total_deductions' => $entity['total_deductions'] ?? 0,
            ':salaire_net' => $entity['salaire_net'] ?? 0,
            ':devise' => $entity['devise'] ?? 'USD',
            ':montant_paye' => $entity['montant_paye'] ?? 0,
            ':montant_restant' => $entity['montant_restant'] ?? 0,
            ':statut' => $entity['statut'] ?? 'En_Attente',
            ':mode_paiement' => $entity['mode_paiement'] ?? null,
            ':date_paiement' => $entity['date_paiement'] ?? null,
            ':notes' => $entity['notes'] ?? null,
            ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
            ':last_modified_by' => $userId
        ]);
        
        $syncStmt = $pdo->prepare("UPDATE salaires SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
        $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
        
        $updatedCount++;
    } else {
        $stmt = $pdo->prepare("
            INSERT INTO salaires (
                id, personnel_id, mois, annee,
                salaire_base, prime_transport, prime_logement, prime_fonction,
                autres_primes, heures_supplementaires, bonus, salaire_brut,
                avances_deduites, credits_deduits, impots, cotisation_cnss,
                autres_deductions, total_deductions, salaire_net, devise,
                montant_paye, montant_restant, statut, mode_paiement,
                date_paiement, notes, last_modified_at, last_modified_by, created_at
            ) VALUES (
                :id, :personnel_id, :mois, :annee,
                :salaire_base, :prime_transport, :prime_logement, :prime_fonction,
                :autres_primes, :heures_supplementaires, :bonus, :salaire_brut,
                :avances_deduites, :credits_deduits, :impots, :cotisation_cnss,
                :autres_deductions, :total_deductions, :salaire_net, :devise,
                :montant_paye, :montant_restant, :statut, :mode_paiement,
                :date_paiement, :notes, :last_modified_at, :last_modified_by, :created_at
            )
        ");
        
        $stmt->execute([
            ':id' => $entity['id'],
            ':personnel_id' => $entity['personnel_id'],
            ':mois' => $entity['mois'],
            ':annee' => $entity['annee'],
            ':salaire_base' => $entity['salaire_base'] ?? 0,
            ':prime_transport' => $entity['prime_transport'] ?? 0,
            ':prime_logement' => $entity['prime_logement'] ?? 0,
            ':prime_fonction' => $entity['prime_fonction'] ?? 0,
            ':autres_primes' => $entity['autres_primes'] ?? 0,
            ':heures_supplementaires' => $entity['heures_supplementaires'] ?? 0,
            ':bonus' => $entity['bonus'] ?? 0,
            ':salaire_brut' => $entity['salaire_brut'] ?? 0,
            ':avances_deduites' => $entity['avances_deduites'] ?? 0,
            ':credits_deduits' => $entity['credits_deduits'] ?? 0,
            ':impots' => $entity['impots'] ?? 0,
            ':cotisation_cnss' => $entity['cotisation_cnss'] ?? 0,
            ':autres_deductions' => $entity['autres_deductions'] ?? 0,
            ':total_deductions' => $entity['total_deductions'] ?? 0,
            ':salaire_net' => $entity['salaire_net'] ?? 0,
            ':devise' => $entity['devise'] ?? 'USD',
            ':montant_paye' => $entity['montant_paye'] ?? 0,
            ':montant_restant' => $entity['montant_restant'] ?? 0,
            ':statut' => $entity['statut'] ?? 'En_Attente',
            ':mode_paiement' => $entity['mode_paiement'] ?? null,
            ':date_paiement' => $entity['date_paiement'] ?? null,
            ':notes' => $entity['notes'] ?? null,
            ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
            ':last_modified_by' => $userId,
            ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
        ]);
        
        $syncStmt = $pdo->prepare("UPDATE salaires SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
        $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
        
        $uploadedCount++;
    }
}

function handleAvance($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    $checkStmt = $pdo->prepare("SELECT id FROM avances_personnel WHERE id = :id");
    $checkStmt->execute([':id' => $entity['id'] ?? 0]);
    $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    $fields = [
        'id' => $entity['id'],
        'personnel_id' => $entity['personnel_id'],
        'montant_avance' => $entity['montant_avance'] ?? 0,
        'montant_rembourse' => $entity['montant_rembourse'] ?? 0,
        'montant_restant' => $entity['montant_restant'] ?? 0,
        'mode_remboursement' => $entity['mode_remboursement'] ?? 'Mensuel',
        'duree_remboursement_mois' => $entity['duree_remboursement_mois'] ?? 1,
        'mensualite' => $entity['mensualite'] ?? 0,
        'date_avance' => $entity['date_avance'] ?? date('Y-m-d'),
        'statut' => $entity['statut'] ?? 'En_Cours',
        'notes' => $entity['notes'] ?? null,
        'last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
        'last_modified_by' => $userId
    ];
    
    if ($exists) {
        $stmt = $pdo->prepare("
            UPDATE avances_personnel SET
                personnel_id = :personnel_id, montant_avance = :montant_avance,
                montant_rembourse = :montant_rembourse, montant_restant = :montant_restant,
                mode_remboursement = :mode_remboursement, duree_remboursement_mois = :duree_remboursement_mois,
                mensualite = :mensualite, date_avance = :date_avance, statut = :statut,
                notes = :notes, last_modified_at = :last_modified_at, last_modified_by = :last_modified_by
            WHERE id = :id
        ");
        $stmt->execute($fields);
        $updatedCount++;
    } else {
        $fields['created_at'] = $entity['created_at'] ?? date('Y-m-d H:i:s');
        $stmt = $pdo->prepare("
            INSERT INTO avances_personnel (
                id, personnel_id, montant_avance, montant_rembourse, montant_restant,
                mode_remboursement, duree_remboursement_mois, mensualite, date_avance,
                statut, notes, last_modified_at, last_modified_by, created_at
            ) VALUES (
                :id, :personnel_id, :montant_avance, :montant_rembourse, :montant_restant,
                :mode_remboursement, :duree_remboursement_mois, :mensualite, :date_avance,
                :statut, :notes, :last_modified_at, :last_modified_by, :created_at
            )
        ");
        $stmt->execute($fields);
        $uploadedCount++;
    }
    
    $syncStmt = $pdo->prepare("UPDATE avances_personnel SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
    $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
}

function handleCredit($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    $checkStmt = $pdo->prepare("SELECT id FROM credits_personnel WHERE id = :id");
    $checkStmt->execute([':id' => $entity['id'] ?? 0]);
    $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    $fields = [
        'id' => $entity['id'],
        'personnel_id' => $entity['personnel_id'],
        'montant_credit' => $entity['montant_credit'] ?? 0,
        'taux_interet_annuel' => $entity['taux_interet_annuel'] ?? 0,
        'duree_mois' => $entity['duree_mois'] ?? 1,
        'mensualite' => $entity['mensualite'] ?? 0,
        'montant_total_a_rembourser' => $entity['montant_total_a_rembourser'] ?? 0,
        'montant_rembourse' => $entity['montant_rembourse'] ?? 0,
        'montant_restant' => $entity['montant_restant'] ?? 0,
        'date_octroi' => $entity['date_octroi'] ?? date('Y-m-d'),
        'date_echeance' => $entity['date_echeance'] ?? null,
        'statut' => $entity['statut'] ?? 'En_Cours',
        'notes' => $entity['notes'] ?? null,
        'last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
        'last_modified_by' => $userId
    ];
    
    if ($exists) {
        $stmt = $pdo->prepare("
            UPDATE credits_personnel SET
                personnel_id = :personnel_id, montant_credit = :montant_credit,
                taux_interet_annuel = :taux_interet_annuel, duree_mois = :duree_mois,
                mensualite = :mensualite, montant_total_a_rembourser = :montant_total_a_rembourser,
                montant_rembourse = :montant_rembourse, montant_restant = :montant_restant,
                date_octroi = :date_octroi, date_echeance = :date_echeance,
                statut = :statut, notes = :notes,
                last_modified_at = :last_modified_at, last_modified_by = :last_modified_by
            WHERE id = :id
        ");
        $stmt->execute($fields);
        $updatedCount++;
    } else {
        $fields['created_at'] = $entity['created_at'] ?? date('Y-m-d H:i:s');
        $stmt = $pdo->prepare("
            INSERT INTO credits_personnel (
                id, personnel_id, montant_credit, taux_interet_annuel, duree_mois,
                mensualite, montant_total_a_rembourser, montant_rembourse, montant_restant,
                date_octroi, date_echeance, statut, notes,
                last_modified_at, last_modified_by, created_at
            ) VALUES (
                :id, :personnel_id, :montant_credit, :taux_interet_annuel, :duree_mois,
                :mensualite, :montant_total_a_rembourser, :montant_rembourse, :montant_restant,
                :date_octroi, :date_echeance, :statut, :notes,
                :last_modified_at, :last_modified_by, :created_at
            )
        ");
        $stmt->execute($fields);
        $uploadedCount++;
    }
    
    $syncStmt = $pdo->prepare("UPDATE credits_personnel SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
    $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
}

function handleRemboursement($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    // Simple insert (pas d'update car immutable)
    $stmt = $pdo->prepare("
        INSERT IGNORE INTO remboursements_credits (
            id, credit_id, montant, date_remboursement, mode_paiement,
            salaire_id, notes, last_modified_at, last_modified_by, created_at
        ) VALUES (
            :id, :credit_id, :montant, :date_remboursement, :mode_paiement,
            :salaire_id, :notes, :last_modified_at, :last_modified_by, :created_at
        )
    ");
    
    $stmt->execute([
        ':id' => $entity['id'],
        ':credit_id' => $entity['credit_id'],
        ':montant' => $entity['montant'] ?? 0,
        ':date_remboursement' => $entity['date_remboursement'] ?? date('Y-m-d'),
        ':mode_paiement' => $entity['mode_paiement'] ?? 'Deduction_Salaire',
        ':salaire_id' => $entity['salaire_id'] ?? null,
        ':notes' => $entity['notes'] ?? null,
        ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
        ':last_modified_by' => $userId,
        ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
    ]);
    
    $syncStmt = $pdo->prepare("UPDATE remboursements_credits SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
    $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
    
    $uploadedCount++;
}

function handleFichePaie($pdo, $entity, $userId, &$uploadedCount, &$updatedCount) {
    $stmt = $pdo->prepare("
        INSERT IGNORE INTO fiches_paie (
            id, salaire_id, personnel_id, mois, annee, fichier_pdf, notes,
            last_modified_at, last_modified_by, created_at
        ) VALUES (
            :id, :salaire_id, :personnel_id, :mois, :annee, :fichier_pdf, :notes,
            :last_modified_at, :last_modified_by, :created_at
        )
    ");
    
    $stmt->execute([
        ':id' => $entity['id'],
        ':salaire_id' => $entity['salaire_id'],
        ':personnel_id' => $entity['personnel_id'],
        ':mois' => $entity['mois'],
        ':annee' => $entity['annee'],
        ':fichier_pdf' => $entity['fichier_pdf'] ?? null,
        ':notes' => $entity['notes'] ?? null,
        ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
        ':last_modified_by' => $userId,
        ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
    ]);
    
    $syncStmt = $pdo->prepare("UPDATE fiches_paie SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
    $syncStmt->execute([':id' => $entity['id'], ':synced_at' => $entity['synced_at'] ?? date('c')]);
    
    $uploadedCount++;
}
