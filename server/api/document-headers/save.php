<?php
/**
 * API pour sauvegarder/mettre à jour l'en-tête des documents
 * POST /api/document-headers/save
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';

try {
    // Lire les données JSON
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data || !isset($data['company_name'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Données invalides: company_name est requis'
        ]);
        exit();
    }
    
    // Vérifier si un en-tête existe déjà
    $stmt = $pdo->query("SELECT id FROM document_headers WHERE is_active = 1 LIMIT 1");
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($existing) {
        // Mettre à jour l'en-tête existant
        $updateStmt = $pdo->prepare("
            UPDATE document_headers SET
                company_name = :company_name,
                company_slogan = :company_slogan,
                address = :address,
                phone = :phone,
                email = :email,
                website = :website,
                tax_number = :tax_number,
                registration_number = :registration_number,
                updated_at = NOW(),
                is_synced = 1,
                is_modified = 0,
                last_synced_at = NOW()
            WHERE id = :id
        ");
        
        $success = $updateStmt->execute([
            ':id' => $existing['id'],
            ':company_name' => $data['company_name'],
            ':company_slogan' => $data['company_slogan'] ?? null,
            ':address' => $data['address'] ?? null,
            ':phone' => $data['phone'] ?? null,
            ':email' => $data['email'] ?? null,
            ':website' => $data['website'] ?? null,
            ':tax_number' => $data['tax_number'] ?? null,
            ':registration_number' => $data['registration_number'] ?? null,
        ]);
        
        if ($success) {
            echo json_encode([
                'success' => true,
                'data' => ['id' => $existing['id']],
                'message' => 'En-tête mis à jour avec succès'
            ]);
        } else {
            throw new Exception('Échec de la mise à jour');
        }
        
    } else {
        // Créer un nouvel en-tête
        $insertStmt = $pdo->prepare("
            INSERT INTO document_headers (
                company_name, company_slogan, address, phone, email, website,
                tax_number, registration_number, is_active, created_at,
                is_synced, is_modified, last_synced_at
            ) VALUES (
                :company_name, :company_slogan, :address, :phone, :email, :website,
                :tax_number, :registration_number, 1, NOW(), 1, 0, NOW()
            )
        ");
        
        $success = $insertStmt->execute([
            ':company_name' => $data['company_name'],
            ':company_slogan' => $data['company_slogan'] ?? null,
            ':address' => $data['address'] ?? null,
            ':phone' => $data['phone'] ?? null,
            ':email' => $data['email'] ?? null,
            ':website' => $data['website'] ?? null,
            ':tax_number' => $data['tax_number'] ?? null,
            ':registration_number' => $data['registration_number'] ?? null,
        ]);
        
        if ($success) {
            $newId = $pdo->lastInsertId();
            echo json_encode([
                'success' => true,
                'data' => ['id' => $newId],
                'message' => 'En-tête créé avec succès'
            ]);
        } else {
            throw new Exception('Échec de la création');
        }
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur base de données: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur: ' . $e->getMessage()
    ]);
}
