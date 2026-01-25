<?php
// VERSION DEBUG - Log vers fichier au lieu de sortie standard
ini_set('display_errors', '0'); // Ne pas afficher les erreurs dans la sortie
error_reporting(E_ALL);

// Log vers un fichier
$logFile = __DIR__ . '/../../logs/sim_upload_debug.log';
if (!file_exists(dirname($logFile))) {
    @mkdir(dirname($logFile), 0755, true);
}

function debugLog($message) {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
    error_log($message); // Aussi dans error_log PHP
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

debugLog("========== DEBUT DEBUG UPLOAD SIMS ==========");

// Essayer d'inclure database.php, sinon créer la connexion directement
try {
    @require_once __DIR__ . '/../../config/database.php';
    debugLog("database.php inclus avec succès");
} catch (Exception $e) {
    debugLog("database.php non trouvé: " . $e->getMessage());
}

// Si $pdo n'existe pas après l'inclusion, créer la connexion
if (!isset($pdo)) {
    debugLog("Création de la connexion PDO directement");
    $pdo = new PDO(
        "mysql:host=91.216.107.185;dbname=inves2504808_18xpitt;charset=utf8mb4",
        "inves2504808",
        "31nzzasdnh",
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
}

try {
    debugLog("Vérification \$pdo");
    if (!isset($pdo)) {
        throw new Exception('$pdo n\'est pas défini après inclusion de database.php');
    }
    
    debugLog("Type de \$pdo = " . gettype($pdo));
    debugLog("Classe de \$pdo = " . get_class($pdo));
    
    $conn = $pdo;
    
    debugLog("Test requête SQL");
    $testStmt = $conn->query("SELECT 1 as test");
    $testResult = $testStmt->fetch();
    debugLog("Test SQL OK: " . json_encode($testResult));
    
    // Lire les données JSON
    debugLog("Lecture php://input");
    $json = file_get_contents('php://input');
    debugLog("JSON reçu (longueur): " . strlen($json));
    
    if (strlen($json) > 0) {
        debugLog("JSON contenu: " . substr($json, 0, 200) . "...");
    }
    
    $data = json_decode($json, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Erreur JSON: ' . json_last_error_msg());
    }
    
    debugLog("JSON décodé OK");
    debugLog("Données = " . json_encode($data));
    
    if (!$data || !isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Format de données invalide');
    }
    
    $entities = $data['entities'];
    debugLog("Nombre d'entités = " . count($entities));
    
    $successCount = 0;
    $errorCount = 0;
    $errors = [];
    
    foreach ($entities as $index => $sim) {
        debugLog("Traitement SIM #$index");
        
        try {
            // Validation des champs obligatoires
            if (empty($sim['numero'])) {
                throw new Exception("Numéro de SIM manquant pour l'entité $index");
            }
            if (empty($sim['operateur'])) {
                throw new Exception("Opérateur manquant pour l'entité $index");
            }
            if (empty($sim['shop_id'])) {
                throw new Exception("shop_id manquant pour l'entité $index");
            }
            
            debugLog("Validation OK pour {$sim['numero']}");
            
            // Vérifier que le shop existe
            $shopCheckStmt = $conn->prepare("SELECT id FROM shops WHERE id = ? LIMIT 1");
            $shopCheckStmt->execute([$sim['shop_id']]);
            $shopExists = $shopCheckStmt->fetch();
            
            debugLog("Shop {$sim['shop_id']} existe = " . ($shopExists ? 'OUI' : 'NON'));
            
            if (!$shopExists) {
                throw new Exception("Le shop {$sim['shop_id']} n'existe pas");
            }
            
            $simId = $sim['id'] ?? null;
            
            // Vérifier si la SIM existe déjà
            $checkStmt = $conn->prepare("SELECT id FROM sims WHERE numero = ? LIMIT 1");
            $checkStmt->execute([$sim['numero']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            debugLog("SIM existe = " . ($existing ? 'OUI (ID: ' . $existing['id'] . ')' : 'NON'));
            
            if ($existing && (!$simId || $existing['id'] != $simId)) {
                $simId = $existing['id'];
            }
            
            if ($simId && $existing) {
                debugLog("UPDATE SIM {$sim['numero']}");
                // UPDATE
                $stmt = $conn->prepare("
                    UPDATE sims SET
                        numero = ?,
                        operateur = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        solde_initial = ?,
                        solde_actuel = ?,
                        statut = ?,
                        motif_suspension = ?,
                        date_creation = ?,
                        date_suspension = ?,
                        cree_par = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = ?
                ");
                
                $stmt->execute([
                    $sim['numero'],
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active',
                    $sim['motif_suspension'] ?? null,
                    $sim['date_creation'] ?? date('Y-m-d H:i:s'),
                    $sim['date_suspension'] ?? null,
                    $sim['cree_par'] ?? null,
                    $sim['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $sim['last_modified_by'] ?? null,
                    $simId
                ]);
                
                debugLog("UPDATE OK");
            } else {
                debugLog("INSERT SIM {$sim['numero']}");
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO sims (
                        numero, operateur, shop_id, shop_designation,
                        solde_initial, solde_actuel, statut, motif_suspension,
                        date_creation, date_suspension, cree_par,
                        last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $sim['numero'],
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active',
                    $sim['motif_suspension'] ?? null,
                    $sim['date_creation'] ?? date('Y-m-d H:i:s'),
                    $sim['date_suspension'] ?? null,
                    $sim['cree_par'] ?? null,
                    $sim['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $sim['last_modified_by'] ?? null
                ]);
                
                $simId = $conn->lastInsertId();
                debugLog("INSERT OK, nouveau ID = $simId");
            }
            
            $successCount++;
            
        } catch (Exception $e) {
            $errorCount++;
            $errorMsg = "Erreur SIM {$sim['numero']}: " . $e->getMessage();
            $errors[] = $errorMsg;
            debugLog("ERREUR - $errorMsg");
        }
    }
    
    debugLog("Traitement terminé");
    debugLog("Succès = $successCount, Erreurs = $errorCount");
    debugLog("========== FIN DEBUG UPLOAD SIMS ==========");
    
    http_response_code(200);
    echo json_encode([
        'success' => $errorCount == 0,
        'message' => $errorCount == 0 
            ? "Upload terminé: $successCount SIMs synchronisées"
            : "Upload partiel: $successCount SIMs synchronisées, $errorCount erreurs",
        'uploaded' => $successCount,
        'errors' => $errorCount,
        'error_details' => $errors,
        'log_file' => $logFile,
        'debug_mode' => true
    ]);
    
} catch (Exception $e) {
    debugLog("EXCEPTION GLOBALE");
    debugLog("Message = " . $e->getMessage());
    debugLog("Fichier = " . $e->getFile());
    debugLog("Ligne = " . $e->getLine());
    debugLog("Trace = " . $e->getTraceAsString());
    debugLog("========== FIN DEBUG (ERREUR) ==========");
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString(),
        'log_file' => $logFile
    ]);
}
