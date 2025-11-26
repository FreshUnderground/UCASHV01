<?php
/**
 * API: Créer une réconciliation bancaire
 * POST /api/reconciliation/create.php
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

try {
    $data = json_decode(file_get_contents('php://input'), true);

    // Validation des données requises
    $requiredFields = ['shop_id', 'date_reconciliation'];
    foreach ($requiredFields as $field) {
        if (!isset($data[$field])) {
            throw new Exception("Champ requis manquant: $field");
        }
    }

    $shopId = $data['shop_id'];
    $dateReconciliation = $data['date_reconciliation'];

    // Vérifier qu'une réconciliation n'existe pas déjà pour cette date
    $checkStmt = $pdo->prepare("SELECT id FROM reconciliations WHERE shop_id = :shop_id AND date_reconciliation = :date_reconciliation");
    $checkStmt->execute([
        ':shop_id' => $shopId,
        ':date_reconciliation' => $dateReconciliation,
    ]);

    if ($checkStmt->fetch()) {
        throw new Exception("Une réconciliation existe déjà pour ce shop à cette date");
    }

    // Récupérer le capital système depuis la table shops
    $shopStmt = $pdo->prepare("SELECT * FROM shops WHERE id = :id");
    $shopStmt->execute([':id' => $shopId]);
    $shop = $shopStmt->fetch(PDO::FETCH_ASSOC);

    if (!$shop) {
        throw new Exception("Shop introuvable");
    }

    $capitalSystemeCash = $shop['capital_cash'] ?? 0;
    $capitalSystemeAirtel = $shop['capital_airtel_money'] ?? 0;
    $capitalSystemeMpesa = $shop['capital_mpesa'] ?? 0;
    $capitalSystemeOrange = $shop['capital_orange_money'] ?? 0;
    $capitalSystemeTotal = $capitalSystemeCash + $capitalSystemeAirtel + $capitalSystemeMpesa + $capitalSystemeOrange;

    // Capital réel (compté)
    $capitalReelCash = $data['capital_reel_cash'] ?? 0;
    $capitalReelAirtel = $data['capital_reel_airtel'] ?? 0;
    $capitalReelMpesa = $data['capital_reel_mpesa'] ?? 0;
    $capitalReelOrange = $data['capital_reel_orange'] ?? 0;
    $capitalReelTotal = $capitalReelCash + $capitalReelAirtel + $capitalReelMpesa + $capitalReelOrange;

    // Déterminer le statut basé sur l'écart
    $ecartTotal = $capitalReelTotal - $capitalSystemeTotal;
    $ecartPourcentage = $capitalSystemeTotal > 0 ? ($ecartTotal / $capitalSystemeTotal * 100) : 0;
    $ecartPct = abs($ecartPourcentage);

    if ($ecartPct == 0) {
        $statut = 'VALIDE';
    } elseif ($ecartPct <= 1) {
        $statut = 'ECART_ACCEPTABLE';
    } elseif ($ecartPct <= 5) {
        $statut = 'ECART_ALERTE';
    } else {
        $statut = 'INVESTIGATION';
    }

    $actionCorrectiveRequise = $ecartPct > 2 ? 1 : 0;

    // Insérer la réconciliation
    $sql = "INSERT INTO reconciliations (
        shop_id, date_reconciliation, periode,
        capital_systeme_cash, capital_systeme_airtel, capital_systeme_mpesa, capital_systeme_orange, capital_systeme_total,
        capital_reel_cash, capital_reel_airtel, capital_reel_mpesa, capital_reel_orange, capital_reel_total,
        statut, notes, justification,
        devise_secondaire, capital_systeme_devise2, capital_reel_devise2,
        action_corrective_requise, action_corrective_prise,
        created_by, created_at
    ) VALUES (
        :shop_id, :date_reconciliation, :periode,
        :capital_systeme_cash, :capital_systeme_airtel, :capital_systeme_mpesa, :capital_systeme_orange, :capital_systeme_total,
        :capital_reel_cash, :capital_reel_airtel, :capital_reel_mpesa, :capital_reel_orange, :capital_reel_total,
        :statut, :notes, :justification,
        :devise_secondaire, :capital_systeme_devise2, :capital_reel_devise2,
        :action_corrective_requise, :action_corrective_prise,
        :created_by, NOW()
    )";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':shop_id' => $shopId,
        ':date_reconciliation' => $dateReconciliation,
        ':periode' => $data['periode'] ?? 'DAILY',
        ':capital_systeme_cash' => $capitalSystemeCash,
        ':capital_systeme_airtel' => $capitalSystemeAirtel,
        ':capital_systeme_mpesa' => $capitalSystemeMpesa,
        ':capital_systeme_orange' => $capitalSystemeOrange,
        ':capital_systeme_total' => $capitalSystemeTotal,
        ':capital_reel_cash' => $capitalReelCash,
        ':capital_reel_airtel' => $capitalReelAirtel,
        ':capital_reel_mpesa' => $capitalReelMpesa,
        ':capital_reel_orange' => $capitalReelOrange,
        ':capital_reel_total' => $capitalReelTotal,
        ':statut' => $statut,
        ':notes' => $data['notes'] ?? null,
        ':justification' => $data['justification'] ?? null,
        ':devise_secondaire' => $data['devise_secondaire'] ?? null,
        ':capital_systeme_devise2' => $shop['capital_actuel_devise2'] ?? null,
        ':capital_reel_devise2' => $data['capital_reel_devise2'] ?? null,
        ':action_corrective_requise' => $actionCorrectiveRequise,
        ':action_corrective_prise' => $data['action_corrective_prise'] ?? null,
        ':created_by' => $data['created_by'] ?? null,
    ]);

    $reconciliationId = $pdo->lastInsertId();

    // Récupérer la réconciliation complète (avec écarts calculés)
    $reconciliationStmt = $pdo->prepare("SELECT * FROM reconciliations WHERE id = :id");
    $reconciliationStmt->execute([':id' => $reconciliationId]);
    $reconciliation = $reconciliationStmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'message' => 'Réconciliation créée',
        'reconciliation' => $reconciliation,
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
