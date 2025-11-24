<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo json_encode([
    'success' => true,
    'message' => 'API SIMs fonctionnelle',
    'endpoints' => [
        'GET /sims/list.php' => 'Lister toutes les SIMs',
        'GET /sims/get-details.php?sim_id=1' => 'Détails d\'une SIM par ID',
        'GET /sims/get-details.php?sim_numero=+243123456789' => 'Détails d\'une SIM par numéro',
        'POST /sims/update-solde.php' => 'Mettre à jour le solde d\'une SIM',
        'GET /operations/get-by-sim.php?sim_numero=+243123456789' => 'Opérations d\'une SIM',
        'POST /operations/servir.php' => 'Servir une opération'
    ],
    'timestamp' => date('Y-m-d H:i:s')
]);