<?php
// Test script to simulate admin validation request

echo "Testing Admin Validation Request\n";
echo "===============================\n\n";

// Simulate the data that would be sent by the mobile app
$testData = [
    'code_ops' => '251212115644101',
    'validated_by_admin_id' => 1,
    'validated_by_admin_name' => 'Test Admin'
];

echo "Sending test data:\n";
echo json_encode($testData, JSON_PRETTY_PRINT) . "\n\n";

// Convert to JSON
$jsonData = json_encode($testData);

// Use cURL to send the request to our endpoint
$url = 'http://localhost/server/api/sync/deletion_requests/admin_validate.php'; // Adjust URL as needed

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Content-Length: ' . strlen($jsonData)
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);

curl_close($ch);

echo "HTTP Response Code: $httpCode\n";
echo "Response:\n";
echo $response . "\n";

if ($error) {
    echo "cURL Error: $error\n";
}

echo "\nDone.\n";

?>