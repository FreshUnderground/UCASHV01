<?php
/**
 * Script de test pour upload comptes_speciaux
 * Test l'endpoint directement avec des données de test
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$testData = [
    'entities' => [
        [
            'id' => -1,
            'type' => 'FRAIS',
            'type_transaction' => 'DEBIT',
            'montant' => 100.00,
            'description' => 'Test upload',
            'shop_id' => 1,
            'date_transaction' => date('Y-m-d H:i:s'),
            'operation_id' => null,
            'agent_id' => 1,
            'agent_username' => 'test',
            'created_at' => date('Y-m-d H:i:s'),
            'last_modified_at' => date('Y-m-d H:i:s'),
            'last_modified_by' => 'test'
        ]
    ],
    'user_id' => 'test',
    'user_role' => 'admin',
    'timestamp' => date('c')
];

// URL de l'endpoint
$url = 'https://mahanaimeservice.investee-group.com/server/api/sync/comptes_speciaux/upload.php';

// Configuration de la requête
$options = [
    'http' => [
        'method' => 'POST',
        'header' => "Content-Type: application/json; charset=utf-8\r\n" .
                    "Accept: application/json\r\n",
        'content' => json_encode($testData),
        'timeout' => 30
    ],
    'ssl' => [
        'verify_peer' => false,
        'verify_peer_name' => false
    ]
];

echo "🧪 Test de l'endpoint comptes_speciaux upload\n";
echo "📍 URL: $url\n";
echo "📤 Données envoyées:\n";
echo json_encode($testData, JSON_PRETTY_PRINT) . "\n\n";

$context = stream_context_create($options);
$result = @file_get_contents($url, false, $context);

// Récupérer les headers de réponse
if (isset($http_response_header)) {
    echo "📥 Headers de réponse:\n";
    foreach ($http_response_header as $header) {
        echo "  $header\n";
    }
    echo "\n";
}

if ($result === false) {
    echo "❌ Erreur: Impossible de se connecter à l'endpoint\n";
    $error = error_get_last();
    if ($error) {
        echo "   Détails: {$error['message']}\n";
    }
} else {
    echo "📄 Réponse brute:\n";
    echo $result . "\n\n";
    
    // Tenter de décoder comme JSON
    $decoded = @json_decode($result, true);
    if ($decoded !== null) {
        echo "✅ Réponse JSON valide:\n";
        echo json_encode($decoded, JSON_PRETTY_PRINT) . "\n";
    } else {
        echo "⚠️ La réponse n'est pas du JSON valide\n";
        echo "   Premiers 500 caractères:\n";
        echo substr($result, 0, 500) . "\n";
    }
}
?>
