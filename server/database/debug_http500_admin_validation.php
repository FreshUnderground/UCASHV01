<?php
/**
 * Debug HTTP 500 error in admin validation endpoint
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

try {
    echo "🔍 Debugging HTTP 500 error in admin validation...\n\n";
    
    // Test the endpoint directly with the exact data from the app
    $endpointUrl = 'https://mahanaimeservice.investee-group.com/server/api/sync/deletion_requests/admin_validate.php';
    $testData = [
        'code_ops' => '251211225017939',
        'validated_by_admin_id' => 1, // Assuming admin ID 1
        'validated_by_admin_name' => 'admin'
    ];
    
    echo "🧪 Testing endpoint with real data...\n";
    echo "URL: $endpointUrl\n";
    echo "Data: " . json_encode($testData) . "\n\n";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $endpointUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($testData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'User-Agent: UCASH-App/1.0'
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_VERBOSE, true);
    
    // Capture verbose output
    $verboseFile = fopen('php://temp', 'w+');
    curl_setopt($ch, CURLOPT_STDERR, $verboseFile);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    $info = curl_getinfo($ch);
    
    // Get verbose output
    rewind($verboseFile);
    $verboseOutput = stream_get_contents($verboseFile);
    fclose($verboseFile);
    
    curl_close($ch);
    
    echo "📡 Response Analysis:\n";
    echo "   HTTP Code: $httpCode\n";
    echo "   Response Length: " . strlen($response) . " bytes\n";
    echo "   Response: " . substr($response, 0, 500) . "\n";
    
    if ($error) {
        echo "   cURL Error: $error\n";
    }
    
    echo "\n📊 Connection Info:\n";
    echo "   Total Time: " . $info['total_time'] . "s\n";
    echo "   Connect Time: " . $info['connect_time'] . "s\n";
    echo "   SSL Verify Result: " . $info['ssl_verify_result'] . "\n";
    
    if ($httpCode === 500) {
        echo "\n❌ HTTP 500 Error Analysis:\n";
        
        // Check if response contains error details
        if (strpos($response, 'Fatal error') !== false) {
            echo "   🐛 PHP Fatal Error detected in response\n";
        }
        
        if (strpos($response, 'database') !== false || strpos($response, 'PDO') !== false) {
            echo "   🗄️ Database error detected\n";
        }
        
        if (strpos($response, 'config') !== false) {
            echo "   ⚙️ Configuration error detected\n";
        }
        
        // Try to parse JSON error response
        $jsonResponse = json_decode($response, true);
        if ($jsonResponse && isset($jsonResponse['message'])) {
            echo "   📝 Error Message: " . $jsonResponse['message'] . "\n";
        }
        
        // Check if it's a database path issue
        echo "\n🔍 Checking database configuration path...\n";
        
        // Test database config path from the endpoint location
        $configPaths = [
            '/htdocs/mahanaimeservice.investee-group.com/server/config/database.php',
            '/htdocs/mahanaimeservice.investee-group.com/config/database.php',
            '/var/www/mahanaimeservice.investee-group.com/server/config/database.php',
            '/var/www/mahanaimeservice.investee-group.com/config/database.php'
        ];
        
        foreach ($configPaths as $path) {
            if (file_exists($path)) {
                echo "   ✅ Found config: $path\n";
            } else {
                echo "   ❌ Missing: $path\n";
            }
        }
        
        // The endpoint uses: require_once __DIR__ . '/../../../../config/database.php';
        // From: /htdocs/mahanaimeservice.investee-group.com/server/api/sync/deletion_requests/admin_validate.php
        // Should resolve to: /htdocs/mahanaimeservice.investee-group.com/config/database.php
        $expectedConfigPath = '/htdocs/mahanaimeservice.investee-group.com/config/database.php';
        echo "\n🎯 Expected config path: $expectedConfigPath\n";
        
        if (file_exists($expectedConfigPath)) {
            echo "   ✅ Config file exists\n";
            
            // Test if config file is valid PHP
            $configContent = file_get_contents($expectedConfigPath);
            if (strpos($configContent, '<?php') === 0) {
                echo "   ✅ Config file has valid PHP syntax\n";
            } else {
                echo "   ❌ Config file missing PHP opening tag\n";
            }
            
            if (strpos($configContent, '$pdo') !== false) {
                echo "   ✅ Config file contains PDO variable\n";
            } else {
                echo "   ❌ Config file missing PDO variable\n";
            }
            
        } else {
            echo "   ❌ Config file missing - this is likely the cause of HTTP 500\n";
            
            // Check if we can find it elsewhere
            echo "\n🔍 Searching for database config files...\n";
            $searchPaths = [
                '/htdocs/mahanaimeservice.investee-group.com/',
                '/var/www/mahanaimeservice.investee-group.com/',
                __DIR__ . '/../'
            ];
            
            foreach ($searchPaths as $searchPath) {
                if (is_dir($searchPath)) {
                    $configFiles = glob($searchPath . '**/database.php', GLOB_BRACE);
                    foreach ($configFiles as $file) {
                        echo "   📄 Found config: $file\n";
                    }
                }
            }
        }
        
    } elseif ($httpCode === 404) {
        echo "\n❌ HTTP 404 - Endpoint not accessible\n";
        echo "   Check if the file was deployed to the correct location\n";
        
    } elseif ($httpCode === 200 || $httpCode === 400) {
        echo "\n✅ Endpoint is accessible (HTTP $httpCode)\n";
        if ($httpCode === 400) {
            echo "   This is expected for test data - endpoint is working\n";
        }
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 DIAGNOSIS SUMMARY:\n";
    
    if ($httpCode === 500) {
        echo "❌ HTTP 500 Error - Server-side issue\n";
        echo "🔧 LIKELY CAUSES:\n";
        echo "1. Missing database config file\n";
        echo "2. Incorrect config file path in endpoint\n";
        echo "3. Database connection failure\n";
        echo "4. PHP syntax error in endpoint or config\n";
        echo "\n🛠️ RECOMMENDED FIXES:\n";
        echo "1. Verify database config exists at expected path\n";
        echo "2. Check config file syntax and PDO setup\n";
        echo "3. Test database connection independently\n";
        echo "4. Check server error logs for detailed error\n";
    } else {
        echo "✅ Endpoint is accessible (HTTP $httpCode)\n";
        echo "ℹ️ The HTTP 500 may be intermittent or data-specific\n";
    }
    
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
}
?>
