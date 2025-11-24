<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Récupérer le paramètre
    $simId = $_GET['sim_id'] ?? null;
    $simNumero = $_GET['sim_numero'] ?? null;
    
    if (!$simId && !$simNumero) {
        throw new Exception('ID ou numéro de SIM requis');
    }
    
    error_log("📱 [SIM Details] Requête pour SIM: " . ($simId ?? $simNumero));
    
    // Récupérer les détails de la SIM
    if ($simId) {
        $stmt = $conn->prepare("
            SELECT 
                s.id,
                s.numero,
                s.operateur,
                s.shop_id,
                s.shop_designation,
                s.solde_initial,
                s.solde_actuel,
                s.statut,
                s.motif_suspension,
                s.date_creation,
                s.date_suspension,
                s.cree_par,
                s.last_modified_at,
                s.last_modified_by,
                sh.designation as shop_nom,
                sh.localisation as shop_localisation
            FROM sims s
            LEFT JOIN shops sh ON s.shop_id = sh.id
            WHERE s.id = ?
        ");
        $stmt->execute([$simId]);
    } else {
        $stmt = $conn->prepare("
            SELECT 
                s.id,
                s.numero,
                s.operateur,
                s.shop_id,
                s.shop_designation,
                s.solde_initial,
                s.solde_actuel,
                s.statut,
                s.motif_suspension,
                s.date_creation,
                s.date_suspension,
                s.cree_par,
                s.last_modified_at,
                s.last_modified_by,
                sh.designation as shop_nom,
                sh.localisation as shop_localisation
            FROM sims s
            LEFT JOIN shops sh ON s.shop_id = sh.id
            WHERE s.numero = ?
        ");
        $stmt->execute([$simNumero]);
    }
    
    $sim = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$sim) {
        throw new Exception('SIM non trouvée');
    }
    
    // Récupérer les 5 dernières opérations liées à cette SIM
    $opStmt = $conn->prepare("
        SELECT 
            id,
            type,
            montant_brut,
            commission,
            montant_net,
            devise,
            destinataire,
            telephone_destinataire,
            reference,
            mode_paiement,
            statut,
            code_ops,
            date_op,
            date_validation,
            shop_source_designation,
            shop_destination_designation
        FROM operations
        WHERE telephone_destinataire = ?
        ORDER BY date_op DESC
        LIMIT 5
    ");
    $opStmt->execute([$sim['numero']]);
    $operations = $opStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Récupérer les 5 derniers mouvements de solde
    $movementStmt = $conn->prepare("
        SELECT 
            id,
            ancien_solde,
            nouveau_solde,
            difference,
            motif,
            agent_responsable,
            date_movement
        FROM sim_solde_movements
        WHERE sim_id = ?
        ORDER BY date_movement DESC
        LIMIT 5
    ");
    $movementStmt->execute([$sim['id']]);
    $soldeMovements = $movementStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'sim' => $sim,
        'recent_operations' => $operations,
        'recent_solde_movements' => $soldeMovements
    ]);
    
} catch (Exception $e) {
    error_log("❌ [SIM Details] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}