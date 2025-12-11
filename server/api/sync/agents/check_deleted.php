<?php
/**
 * API Endpoint: Check Deleted Agents
 * 
 * Vérifie si des agents ont été supprimés du serveur.
 * Permet aux clients de synchroniser leurs listes locales en supprimant
 * les agents qui n'existent plus sur le serveur.
 * 
 * METHOD: POST
 * BODY: {
 *   "agent_ids": [1, 2, 3, 4, 5]
 * }
 * 
 * RESPONSE: {
 *   "success": true,
 *   "deleted_agents": [3, 5],
 *   "message": "2 agents supprimés trouvés"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Gérer les requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Méthode non autorisée. Utilisez POST.'
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données JSON invalides');
    }
    
    // Vérifier que agent_ids est fourni et est un tableau
    if (!isset($data['agent_ids']) || !is_array($data['agent_ids'])) {
        throw new Exception('Le paramètre "agent_ids" est requis et doit être un tableau');
    }
    
    $agentIds = $data['agent_ids'];
    
    // Si aucun ID fourni, retourner succès avec liste vide
    if (empty($agentIds)) {
        echo json_encode([
            'success' => true,
            'deleted_agents' => [],
            'message' => 'Aucun agent à vérifier'
        ]);
        exit;
    }
    
    // Créer les placeholders pour la requête SQL
    $placeholders = implode(',', array_fill(0, count($agentIds), '?'));
    
    // Requête pour trouver les agents qui existent encore sur le serveur
    $sql = "SELECT id FROM agents WHERE id IN ($placeholders)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($agentIds);
    
    // Récupérer les IDs des agents qui existent
    $existingIds = array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'id');
    $existingIds = array_map('intval', $existingIds);
    
    // Calculer les agents supprimés (présents localement mais pas sur le serveur)
    $deletedAgents = array_diff($agentIds, $existingIds);
    $deletedAgents = array_values($deletedAgents); // Réindexer le tableau
    
    // Log pour debugging
    error_log("🔍 Check deleted agents - Total: " . count($agentIds) . ", Existing: " . count($existingIds) . ", Deleted: " . count($deletedAgents));
    
    if (!empty($deletedAgents)) {
        error_log("🗑️ Agents supprimés détectés: " . implode(', ', $deletedAgents));
    }
    
    // Retourner la réponse
    echo json_encode([
        'success' => true,
        'deleted_agents' => $deletedAgents,
        'existing_count' => count($existingIds),
        'deleted_count' => count($deletedAgents),
        'message' => count($deletedAgents) > 0 
            ? count($deletedAgents) . ' agent(s) supprimé(s) trouvé(s)' 
            : 'Aucun agent supprimé'
    ]);
    
} catch (Exception $e) {
    error_log("❌ Erreur check_deleted agents: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'deleted_agents' => []
    ]);
}
?>

