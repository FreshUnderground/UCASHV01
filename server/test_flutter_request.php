<?php
// Simulate the exact request that the Flutter app would make
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');
header('Access-Control-Max-Age: 86400');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Log the request for debugging
error_log("Flutter request received: " . $_SERVER['REQUEST_METHOD'] . " " . $_SERVER['REQUEST_URI']);
error_log("Request headers: " . print_r(getallheaders(), true));

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get the raw input
    $input = file_get_contents('php://input');
    error_log("Raw input: " . $input);
    
    // Try to decode JSON
    $data = json_decode($input, true);
    error_log("Decoded data: " . print_r($data, true));
    
    if (!$data) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid JSON data']);
        exit();
    }
    
    // Return success response
    echo json_encode([
        'success' => true,
        'message' => 'Request processed successfully',
        'received_data' => $data,
        'timestamp' => date('c')
    ]);
} else {
    // For GET requests, return a simple response
    echo json_encode([
        'success' => true,
        'message' => 'GET request processed successfully',
        'timestamp' => date('c')
    ]);
}
?>