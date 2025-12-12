<?php
// Debug script to capture and test the exact validation request data

// Enable all error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

echo "Debugging Deletion Request Validation\n";
echo "==================================\n\n";

// Log all incoming data
$rawInput = file_get_contents('php://input');
$headers = getallheaders();

echo "Raw Input:\n";
echo $rawInput . "\n\n";

echo "Headers:\n";
foreach ($headers as $key => $value) {
    echo "$key: $value\n";
}
echo "\n";

echo "$_SERVER data:\n";
echo "CONTENT_TYPE: " . ($_SERVER['CONTENT_TYPE'] ?? 'Not set') . "\n";
echo "REQUEST_METHOD: " . ($_SERVER['REQUEST_METHOD'] ?? 'Not set') . "\n\n";

// Parse the JSON data
$data = json_decode($rawInput, true);

echo "Parsed Data:\n";
if ($data === null) {
    echo "JSON decode error: " . json_last_error_msg() . "\n";
} else {
    print_r($data);
}

echo "\n";

// Now test with our fixed validation logic
require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    echo "✓ Database connection successful\n\n";
    
    if ($data && isset($data['code_ops'])) {
        $codeOps = $data['code_ops'];
        echo "Checking request: $codeOps\n";
        
        // Check if request exists
        $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
        $stmt->execute([$codeOps]);
        $request = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($request) {
            echo "✓ Request found in database\n";
            echo "Current status: " . ($request['statut'] ?? 'NULL') . "\n";
            echo "Requested by admin ID: " . ($request['requested_by_admin_id'] ?? 'NULL') . "\n";
            echo "Requested by admin name: " . ($request['requested_by_admin_name'] ?? 'NULL') . "\n\n";
            
            // Test the validation update
            if (isset($data['validated_by_admin_id']) && isset($data['validated_by_admin_name'])) {
                echo "Testing validation update...\n";
                
                $stmt = $db->prepare("
                    UPDATE deletion_requests SET
                        validated_by_admin_id = :admin_id,
                        validated_by_admin_name = :admin_name,
                        validation_admin_date = :validation_admin_date,
                        statut = :statut,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by
                    WHERE code_ops = :code_ops
                ");
                
                $now = date('Y-m-d H:i:s');
                
                $result = $stmt->execute([
                    ':admin_id' => $data['validated_by_admin_id'],
                    ':admin_name' => $data['validated_by_admin_name'],
                    ':validation_admin_date' => $now,
                    ':statut' => 'admin_validee',
                    ':last_modified_at' => $now,
                    ':last_modified_by' => "admin_" . $data['validated_by_admin_name'],
                    ':code_ops' => $codeOps
                ]);
                
                echo "Update result: " . ($result ? 'SUCCESS' : 'FAILED') . "\n";
                echo "Rows affected: " . $stmt->rowCount() . "\n";
                
                if ($result && $stmt->rowCount() > 0) {
                    echo "✓ Validation would be successful!\n";
                    
                    // Return success response like the real endpoint
                    header('Content-Type: application/json');
                    echo json_encode([
                        'success' => true,
                        'message' => "Demande validée par l'administrateur",
                        'code_ops' => $codeOps,
                        'statut' => 'admin_validee'
                    ]);
                    exit();
                } else {
                    echo "✗ Update failed - no rows affected\n";
                }
            } else {
                echo "Missing validation data in request\n";
            }
        } else {
            echo "✗ Request not found in database\n";
        }
    } else {
        echo "No valid code_ops in request data\n";
    }
    
} catch (Exception $e) {
    echo "Database error: " . $e->getMessage() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
}

echo "\nDebug complete.\n";

?>