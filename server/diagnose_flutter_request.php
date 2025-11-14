<?php
// Diagnose Flutter request
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Log all request information
error_log("=== FLUTTER REQUEST DIAGNOSIS ===");
error_log("Method: " . $_SERVER['REQUEST_METHOD']);
error_log("URI: " . $_SERVER['REQUEST_URI']);
error_log("Query String: " . ($_SERVER['QUERY_STRING'] ?? 'None'));
error_log("Content Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'None'));

// Log all headers
$headers = getallheaders();
error_log("Headers: " . json_encode($headers));

// Log raw input
$input = file_get_contents('php://input');
error_log("Raw Input: " . $input);

// Try to decode JSON if it's a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($input)) {
    $data = json_decode($input, true);
    if ($data) {
        error_log("JSON Decoded: " . json_encode($data));
    } else {
        error_log("JSON Decode Failed");
    }
}

// Return diagnostic information
echo json_encode([
    'success' => true,
    'message' => 'Request received and logged for diagnosis',
    'method' => $_SERVER['REQUEST_METHOD'],
    'uri' => $_SERVER['REQUEST_URI'],
    'query_string' => $_SERVER['QUERY_STRING'] ?? null,
    'content_type' => $_SERVER['CONTENT_TYPE'] ?? null,
    'headers' => $headers,
    'input_length' => strlen($input),
    'timestamp' => date('c')
]);
?>