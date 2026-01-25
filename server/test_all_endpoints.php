<?php
// Test all synchronization endpoints
header('Content-Type: text/plain; charset=utf-8');

echo "🚀 Testing all synchronization endpoints...\n\n";

$baseUrl = 'https://safdal.investee-group.com/server/api/sync';
$endpoints = [
    'ping' => '/ping.php',
    'shops_upload' => '/shops/upload.php',
    'shops_changes' => '/shops/changes.php',
    'agents_upload' => '/agents/upload.php',
    'agents_changes' => '/agents/changes.php',
    'clients_upload' => '/clients/upload.php',
    'clients_changes' => '/clients/changes.php',
    'operations_upload' => '/operations/upload.php',
    'operations_changes' => '/operations/changes.php',
    'taux_upload' => '/taux/upload.php',
    'taux_changes' => '/taux/changes.php',
    'commissions_upload' => '/commissions/upload.php',
    'commissions_changes' => '/commissions/changes.php'
];

foreach ($endpoints as $name => $path) {
    echo "Testing $name...\n";
    
    $url = $baseUrl . $path;
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'timeout' => 10
        ]
    ]);
    
    try {
        $response = @file_get_contents($url, false, $context);
        if ($response !== false) {
            echo "✅ $name: Success\n";
        } else {
            echo "❌ $name: Failed\n";
        }
    } catch (Exception $e) {
        echo "❌ $name: Error - " . $e->getMessage() . "\n";
    }
    
    echo "\n";
}

echo "🎉 Endpoint testing completed!\n";
?>