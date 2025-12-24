<?php
/**
 * API pour télécharger les crédits virtuels depuis le serveur
 * Endpoint: GET /api/credit-virtuels?shop_id=X&since=Y
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
    // Récupérer tous les crédits virtuels concernant ce shop
    // et modifiés depuis la date spécifiée
    $sql = "
        SELECT 
            id,
            reference,
            montant_credit,
            devise,
            beneficiaire_nom,
            beneficiaire_telephone,
            beneficiaire_adresse,
            type_beneficiaire,
            sim_numero,
            shop_id,
            shop_designation,
            agent_id,
            agent_username,
            statut,
            date_sortie,
            date_paiement,
            date_echeance,
            notes,
            montant_paye,
            mode_paiement,
            reference_paiement,
            last_modified_at,
            last_modified_by,
            is_synced,
            synced_at
        FROM credit_virtuels 
        WHERE shop_id = :shop_id
        AND (last_modified_at >= :since OR last_modified_at IS NULL)
        ORDER BY last_modified_at DESC, id DESC
        LIMIT 1000
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':shop_id', $shopId, PDO::PARAM_INT);
    $stmt->bindParam(':since', $since, PDO::PARAM_STR);
    
    $stmt->execute();
    $credits = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Convertir les données pour le format attendu par le client
    $result = [];
    foreach ($credits as $credit) {
        $result[] = [
            'id' => (int)$credit['id'],
            'reference' => $credit['reference'],
            'montant_credit' => (float)$credit['montant_credit'],
            'devise' => $credit['devise'] ?? 'USD',
            'beneficiaire_nom' => $credit['beneficiaire_nom'],
            'beneficiaire_telephone' => $credit['beneficiaire_telephone'],
            'beneficiaire_adresse' => $credit['beneficiaire_adresse'],
            'type_beneficiaire' => $credit['type_beneficiaire'] ?? 'shop',
            'sim_numero' => $credit['sim_numero'],
            'shop_id' => (int)$credit['shop_id'],
            'shop_designation' => $credit['shop_designation'],
            'agent_id' => (int)$credit['agent_id'],
            'agent_username' => $credit['agent_username'],
            'statut' => $credit['statut'],
            'date_sortie' => $credit['date_sortie'],
            'date_paiement' => $credit['date_paiement'],
            'date_echeance' => $credit['date_echeance'],
            'notes' => $credit['notes'],
            'montant_paye' => (float)($credit['montant_paye'] ?? 0.0),
            'mode_paiement' => $credit['mode_paiement'],
            'reference_paiement' => $credit['reference_paiement'],
            'last_modified_at' => $credit['last_modified_at'],
            'last_modified_by' => $credit['last_modified_by'],
            'is_synced' => (bool)$credit['is_synced'],
            'synced_at' => $credit['synced_at']
        ];
    }

    // Log de l'activité
    error_log("API credit-virtuels/download: Shop $shopId - " . count($result) . " crédits récupérés depuis $since");

    // Retourner les données
    echo json_encode($result, JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur base de données',
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur PDO dans credit-virtuels/download: " . $e->getMessage());
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    error_log("Erreur dans credit-virtuels/download: " . $e->getMessage());
}
?>
