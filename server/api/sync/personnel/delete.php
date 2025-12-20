<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../../config/database.php';

try {
    // Lire les données JSON
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['deletions'])) {
        throw new Exception('Données de suppression manquantes');
    }
    
    $deletions = $input['deletions'];
    $processed = 0;
    $errors = [];
    
    // Connexion à la base de données
    $pdo = Database::getConnection();
    $pdo->beginTransaction();
    
    foreach ($deletions as $deletion) {
        try {
            $id = $deletion['id'];
            $type = $deletion['type'];
            $markedAt = $deletion['marked_at'];
            
            switch ($type) {
                case 'personnel':
                    // Soft delete - mettre le statut à 'Demissionne'
                    $stmt = $pdo->prepare("
                        UPDATE personnel 
                        SET statut = 'Demissionne', 
                            last_modified_at = NOW(),
                            deleted_at = ?
                        WHERE id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    
                    // Marquer les données liées comme supprimées
                    $stmt = $pdo->prepare("
                        UPDATE salaires 
                        SET deleted_at = ?
                        WHERE personnel_id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    
                    $stmt = $pdo->prepare("
                        UPDATE avances_personnel 
                        SET deleted_at = ?
                        WHERE personnel_id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    
                    $stmt = $pdo->prepare("
                        UPDATE retenues_personnel 
                        SET deleted_at = ?
                        WHERE personnel_id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    
                    break;
                    
                case 'salaire':
                    $stmt = $pdo->prepare("
                        UPDATE salaires 
                        SET deleted_at = ?
                        WHERE id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    break;
                    
                case 'avance_personnel':
                    $stmt = $pdo->prepare("
                        UPDATE avances_personnel 
                        SET deleted_at = ?
                        WHERE id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    break;
                    
                case 'retenue_personnel':
                    $stmt = $pdo->prepare("
                        UPDATE retenues_personnel 
                        SET deleted_at = ?
                        WHERE id = ?
                    ");
                    $stmt->execute([$markedAt, $id]);
                    break;
                    
                default:
                    throw new Exception("Type de suppression non supporté: $type");
            }
            
            $processed++;
            
        } catch (Exception $e) {
            $errors[] = [
                'id' => $deletion['id'] ?? 'unknown',
                'type' => $deletion['type'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    $pdo->commit();
    
    echo json_encode([
        'success' => true,
        'message' => "Suppressions traitées avec succès",
        'processed_count' => $processed,
        'error_count' => count($errors),
        'errors' => $errors,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    if (isset($pdo)) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur lors du traitement des suppressions: ' . $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>
