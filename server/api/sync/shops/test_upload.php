<?php
// Test the shops upload endpoint directly
$url = 'https://safdal.investee-group.com/server/api/sync/shops/upload.php';

// Create test data
$data = [
    'entities' => [],
    'user_id' => 'admin',
    'timestamp' => '2025-11-10T10:40:00Z'
];

// Convert to JSON
$jsonData = json_encode($data);

// Create context for the request
$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($jsonData)
        ],
        'content' => $jsonData
    ]
]);

// Make the request
$response = file_get_contents($url, false, $context);

// Output the response
echo "Response: " . $response . "\n";
echo "HTTP Status: " . implode(' ', $http_response_header) . "\n";
?>