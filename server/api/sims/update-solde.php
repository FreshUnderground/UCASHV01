<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Lire les données JSON
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data) {
        throw new Exception('Données JSON invalides');
    }
    
    $simId = $data['sim_id'] ?? null;
    $nouveauSolde = $data['nouveau_solde'] ?? null;
    $agentUsername = $data['agent_username'] ?? null;
    $motif = $data['motif'] ?? 'Mise à jour manuelle du solde';
    
    if (!$simId || !is_numeric($nouveauSolde)) {
        throw new Exception('ID de SIM et nouveau solde requis');
    }
    
    error_log("📱 [SIM Solde] Mise à jour solde SIM ID: $simId à $nouveauSolde USD");
    
    // 1. Récupérer le solde actuel pour créer un mouvement
    $stmt = $conn->prepare("SELECT solde_actuel, numero FROM sims WHERE id = ?");
    $stmt->execute([$simId]);
    $sim = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$sim) {
        throw new Exception('SIM non trouvée');
    }
    
    $ancienSolde = $sim['solde_actuel'];
    $simNumero = $sim['numero'];
    
    // 2. Mettre à jour le solde de la SIM
    $updateStmt = $conn->prepare("
        UPDATE sims SET
            solde_actuel = ?,
            last_modified_at = NOW(),
            last_modified_by = ?
        WHERE id = ?
    ");
    
    $updateStmt->execute([
        $nouveauSolde,
        $agentUsername,
        $simId
    ]);
    
    if ($updateStmt->rowCount() === 0) {
        throw new Exception('Échec de la mise à jour du solde');
    }
    
    // 3. Créer un mouvement de solde
    $movementStmt = $conn->prepare("
        INSERT INTO sim_solde_movements (
            sim_id,
            sim_numero,
            ancien_solde,
            nouveau_solde,
            difference,
            motif,
            agent_responsable,
            date_movement,
            is_synced,
            synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), 1, NOW())
    ");
    
    $difference = $nouveauSolde - $ancienSolde;
    
    $movementStmt->execute([
        $simId,
        $simNumero,
        $ancienSolde,
        $nouveauSolde,
        $difference,
        $motif,
        $agentUsername
    ]);
    
    $movementId = $conn->lastInsertId();
    error_log("📝 [SIM Solde] Mouvement créé (ID: $movementId) - Différence: $difference USD");
    
    echo json_encode([
        'success' => true,
        'message' => 'Solde mis à jour avec succès',
        'sim_id' => $simId,
        'ancien_solde' => $ancienSolde,
        'nouveau_solde' => $nouveauSolde,
        'movement_id' => $movementId
    ]);
    
} catch (Exception $e) {
    error_log("❌ [SIM Solde] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}