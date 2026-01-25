<?php
// Simple test upload
$data = [
    'entities' => [
        [
            'id' => 1,
            'designation' => 'Test Shop',
            'localisation' => 'Test Location',
            'capital_initial' => 10000,
            'devise_principale' => 'USD',
            'devise_secondaire' => null,
            'capital_actuel' => 10000,
            'capital_cash' => 5000,
            'capital_airtel_money' => 2000,
            'capital_mpesa' => 2000,
            'capital_orange_money' => 1000,
            'capital_actuel_devise2' => null,
            'capital_cash_devise2' => null,
            'capital_airtel_money_devise2' => null,
            'capital_mpesa_devise2' => null,
            'capital_orange_money_devise2' => null,
            'creances' => 0,
            'dettes' => 0,
            'last_modified_at' => '2025-11-10T11:30:00Z',
            'last_modified_by' => 'test',
            'created_at' => '2025-11-10T11:30:00Z',
            'is_synced' => false,
            'synced_at' => null
        ]
    ],
    'user_id' => 'admin',
    'timestamp' => '2025-11-10T11:30:00Z'
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

$response = file_get_contents('https://safdal.investee-group.com/server/api/sync/shops/upload.php', false, $context);
echo $response;
?>