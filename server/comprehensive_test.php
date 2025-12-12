<?php
// Comprehensive test with multiple entities
header('Content-Type: application/json; charset=utf-8');

$data = [
    'entities' => [

    ],
    'user_id' => 'admin',
    'timestamp' => '2025-11-10 11:30:00'
];

// Convert to JSON
$json = json_encode($data);

// Send request to shops upload endpoint
$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($json)
        ],
        'content' => $json
    ]
]);

$response = file_get_contents('https://mahanaimeservice.investee-group.com/server/api/sync/shops/upload.php', false, $context);
echo $response;
?>