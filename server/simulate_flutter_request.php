<?php
// Simulate what the Flutter app might be sending incorrectly

echo "Simulating Potential Flutter App Requests\n";
echo "======================================\n\n";

// Test different data formats that the Flutter app might be sending

$testCases = [
    'Correct Format' => [
        'code_ops' => '251212115644101',
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => 'Test Admin'
    ],
    
    'CamelCase Fields' => [
        'codeOps' => '251212115644101',
        'validatedByAdminId' => 1,
        'validatedByAdminName' => 'Test Admin'
    ],
    
    'Mixed Case Fields' => [
        'code_ops' => '251212115644101',
        'validatedByAdminId' => 1,
        'validated_by_admin_name' => 'Test Admin'
    ],
    
    'String Numbers' => [
        'code_ops' => '251212115644101',
        'validated_by_admin_id' => '1',
        'validated_by_admin_name' => 'Test Admin'
    ],
    
    'Missing Fields' => [
        'code_ops' => '251212115644101',
        'validated_by_admin_name' => 'Test Admin'
        // Missing validated_by_admin_id
    ],
    
    'Empty Values' => [
        'code_ops' => '251212115644101',
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => ''
    ]
];

foreach ($testCases as $caseName => $data) {
    echo "Testing: $caseName\n";
    echo "Data: " . json_encode($data) . "\n";
    
    // Simulate our parsing logic
    $codeOps = $data['code_ops'] ?? $data['codeOps'] ?? null;
    $adminId = $data['validated_by_admin_id'] ?? $data['validatedByAdminId'] ?? null;
    $adminName = $data['validated_by_admin_name'] ?? $data['validatedByAdminName'] ?? null;
    
    echo "Parsed - codeOps: " . ($codeOps ?? 'NULL') . 
         ", adminId: " . ($adminId ?? 'NULL') . 
         ", adminName: " . ($adminName ?? 'NULL') . "\n";
    
    $isValid = !empty($codeOps) && !empty($adminId) && !empty($adminName);
    echo "Valid: " . ($isValid ? 'YES' : 'NO') . "\n\n";
}

echo "Most likely issue: The Flutter app is probably sending data with different field names or missing fields.\n";
echo "The enhanced server code should now handle these cases and provide better error messages.\n";

?>