<?php
// Script de test pour l'upload des transactions virtuelles
header('Content-Type: application/json; charset=utf-8');

// Données de test
$testData = [
    'entities' => [
        [
            'reference' => 'TEST_VT_' . time(),
            'montant_virtuel' => 100.00,
            'frais' => 2.00,
            'montant_cash' => 98.00,
            'devise' => 'USD',
            'sim_numero' => '0972345678',
            'shop_id' => 1,
            'shop_designation' => 'SHOP DURBA',
            'agent_id' => 1,
            'agent_username' => 'agent1',
            'statut' => 'enAttente',
            'date_enregistrement' => date('Y-m-d H:i:s'),
            'last_modified_at' => date('Y-m-d H:i:s'),
            'last_modified_by' => 'test_script'
        ]
    ],
    'user_id' => 'test_script',
    'timestamp' => date('c')
];

// Convertir en JSON
$jsonData = json_encode($testData, JSON_PRETTY_PRINT);
echo "Données envoyées:\n";
echo $jsonData . "\n\n";

// Envoyer la requête POST
$url = 'https://mahanaimeservice.investee-group.com/server/api/sync/virtual_transactions/upload.php';
$ch = curl_init($url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json'
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "Code HTTP: $httpCode\n";
echo "Erreur cURL: $error\n";
echo "Réponse du serveur:\n";
echo $response . "\n";

// Vérifier si la réponse est du JSON valide
if (!empty($response)) {
    $decoded = json_decode($response, true);
    if ($decoded === null) {
        echo "ERREUR: La réponse n'est pas du JSON valide!\n";
        echo "Contenu brut: " . substr($response, 0, 500) . "\n";
    } else {
        echo "Réponse JSON décodée avec succès\n";
        print_r($decoded);
    }
}
?>