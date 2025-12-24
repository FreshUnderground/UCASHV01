<?php
/**
 * API pour télécharger les retraits virtuels depuis le serveur
 * Endpoint: GET /api/retrait-virtuels?shop_id=X&since=Y
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Gérer les requêtes OPTIONS (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    // Vérifier la méthode HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Méthode non autorisée', 405);
    }

    // Récupérer les paramètres
    $shopId = isset($_GET['shop_id']) ? (int)$_GET['shop_id'] : null;
    $since = isset($_GET['since']) ? $_GET['since'] : '2020-01-01T00:00:00.000';

    if (!$shopId) {
        throw new Exception('shop_id requis', 400);
    }

    // Connexion à la base de données
    $db = new Database();
    $conn = $db->getConnection();

    // Préparer la requête SQL
    // Récupérer tous les retraits virtuels concernant ce shop (source ou débiteur)
    // et modifiés depuis la date spécifiée
    $sql = "
        SELECT 
            id,
            sim_numero,
            sim_operateur,
            shop_source_id,
            shop_source_designation,
            shop_debiteur_id,
            shop_debiteur_designation,
            montant,
            devise,
            solde_avant,
            solde_apres,
            agent_id,
            agent_username,
            notes,
            statut,
            date_retrait,
            date_remboursement,
            flot_remboursement_id,
            last_modified_at,
            last_modified_by,
            is_synced,
            synced_at
        FROM retrait_virtuels 
        WHERE (shop_source_id = :shop_id OR shop_debiteur_id = :shop_id)
        AND (last_modified_at >= :since OR last_modified_at IS NULL)
        ORDER BY last_modified_at DESC, id DESC
        LIMIT 1000
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':shop_id', $shopId, PDO::PARAM_INT);
    $stmt->bindParam(':since', $since, PDO::PARAM_STR);
    
    $stmt->execute();
    $retraits = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Convertir les données pour le format attendu par le client
    $result = [];
    foreach ($retraits as $retrait) {
        $result[] = [
            'id' => (int)$retrait['id'],
            'sim_numero' => $retrait['sim_numero'],
            'sim_operateur' => $retrait['sim_operateur'],
            'shop_source_id' => (int)$retrait['shop_source_id'],
            'shop_source_designation' => $retrait['shop_source_designation'],
            'shop_debiteur_id' => (int)$retrait['shop_debiteur_id'],
            'shop_debiteur_designation' => $retrait['shop_debiteur_designation'],
            'montant' => (float)$retrait['montant'],
            'devise' => $retrait['devise'] ?? 'USD',
            'solde_avant' => (float)$retrait['solde_avant'],
            'solde_apres' => (float)$retrait['solde_apres'],
            'agent_id' => (int)$retrait['agent_id'],
            'agent_username' => $retrait['agent_username'],
            'notes' => $retrait['notes'],
            'statut' => $retrait['statut'],
            'date_retrait' => $retrait['date_retrait'],
            'date_remboursement' => $retrait['date_remboursement'],
            'flot_remboursement_id' => $retrait['flot_remboursement_id'] ? (int)$retrait['flot_remboursement_id'] : null,
            'last_modified_at' => $retrait['last_modified_at'],
            'last_modified_by' => $retrait['last_modified_by'],
            'is_synced' => (bool)$retrait['is_synced'],
            'synced_at' => $retrait['synced_at']
        ];
    }

    // Log de l'activité
    error_log("API retrait-virtuels/download: Shop $shopId - " . count($result) . " retraits récupérés depuis $since");

    // Retourner les données
    echo json_encode($result, JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur base de données',
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur PDO dans retrait-virtuels/download: " . $e->getMessage());
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur dans retrait-virtuels/download: " . $e->getMessage());
}
?>
