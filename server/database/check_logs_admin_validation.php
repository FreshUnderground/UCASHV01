<?php
/**
 * Check logs to understand HTTP 400 errors from admin validation
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

try {
    echo "🔍 Checking logs for admin validation errors...\n\n";
    
    // Common log file locations
    $logFiles = [
        '/var/log/apache2/error.log',
        '/var/log/nginx/error.log', 
        '/var/log/php_errors.log',
        '/tmp/php_errors.log',
        ini_get('error_log'),
        __DIR__ . '/../logs/error.log',
        __DIR__ . '/../../logs/error.log'
    ];
    
    // Add system-specific paths
    if (PHP_OS_FAMILY === 'Windows') {
        $logFiles[] = 'C:\\xampp\\apache\\logs\\error.log';
        $logFiles[] = 'C:\\laragon\\tmp\\error.log';
        $logFiles[] = 'C:\\wamp\\logs\\php_error.log';
    }
    
    echo "📋 Searching for log files...\n";
    $foundLogs = [];
    
    foreach ($logFiles as $logFile) {
        if ($logFile && file_exists($logFile) && is_readable($logFile)) {
            $foundLogs[] = $logFile;
            echo "✅ Found: $logFile\n";
        }
    }
    
    if (empty($foundLogs)) {
        echo "❌ No accessible log files found\n";
        echo "📝 Current error_log setting: " . ini_get('error_log') . "\n";
        echo "📝 Log errors enabled: " . (ini_get('log_errors') ? 'YES' : 'NO') . "\n";
        
        // Try to create a test log entry
        error_log("[TEST] Admin validation log test - " . date('Y-m-d H:i:s'));
        echo "🧪 Test log entry created\n";
        
        // Check if we can find recent deletion request logs
        echo "\n🔍 Checking for deletion request logs in common locations...\n";
        
        // Try to find logs with deletion request entries
        $searchPattern = "DELETION_REQUESTS";
        $possibleLogs = glob('/var/log/*error*') + glob('/tmp/*log*') + glob(__DIR__ . '/../*log*');
        
        foreach ($possibleLogs as $logFile) {
            if (is_file($logFile) && is_readable($logFile)) {
                $content = file_get_contents($logFile);
                if (strpos($content, $searchPattern) !== false) {
                    echo "✅ Found deletion logs in: $logFile\n";
                    $foundLogs[] = $logFile;
                }
            }
        }
    }
    
    if (!empty($foundLogs)) {
        echo "\n📊 Analyzing recent logs for DELETION_REQUESTS entries...\n";
        
        foreach ($foundLogs as $logFile) {
            echo "\n--- Analyzing: $logFile ---\n";
            
            // Read last 1000 lines to find recent entries
            $lines = [];
            $handle = fopen($logFile, 'r');
            if ($handle) {
                // Go to end of file
                fseek($handle, -8192, SEEK_END); // Read last 8KB
                $content = fread($handle, 8192);
                fclose($handle);
                
                $lines = explode("\n", $content);
                $lines = array_filter($lines); // Remove empty lines
            }
            
            $deletionEntries = [];
            foreach ($lines as $line) {
                if (strpos($line, 'DELETION_REQUESTS') !== false) {
                    $deletionEntries[] = $line;
                }
            }
            
            if (!empty($deletionEntries)) {
                echo "🔍 Found " . count($deletionEntries) . " deletion request log entries:\n";
                
                // Show last 10 entries
                $recentEntries = array_slice($deletionEntries, -10);
                foreach ($recentEntries as $entry) {
                    echo "   $entry\n";
                }
                
                // Look for specific error patterns
                $errorPatterns = [
                    'Missing required fields' => 'Missing field validation',
                    'code_ops=' => 'Code ops processing',
                    'admin_id=' => 'Admin ID processing', 
                    'JSON decode error' => 'JSON parsing issues',
                    'Raw input received' => 'Input data',
                    'HTTP 400' => 'HTTP 400 responses',
                    'No rows updated' => 'Database update failures'
                ];
                
                echo "\n🔍 Error pattern analysis:\n";
                foreach ($errorPatterns as $pattern => $description) {
                    $count = 0;
                    foreach ($deletionEntries as $entry) {
                        if (strpos($entry, $pattern) !== false) {
                            $count++;
                        }
                    }
                    if ($count > 0) {
                        echo "   ⚠️ $description: $count occurrences\n";
                    }
                }
                
            } else {
                echo "ℹ️ No deletion request entries found in recent logs\n";
            }
        }
    }
    
    // Provide instructions for manual log checking
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "📋 MANUAL LOG CHECKING INSTRUCTIONS:\n";
    echo "1. Check your web server error logs for [DELETION_REQUESTS] entries\n";
    echo "2. Look for recent entries when you tried admin validation\n";
    echo "3. Key things to look for:\n";
    echo "   - 'Raw input received' - shows what data the app sent\n";
    echo "   - 'Missing required fields' - indicates field validation issues\n";
    echo "   - 'JSON decode error' - shows JSON parsing problems\n";
    echo "   - 'No rows updated' - indicates database update failures\n";
    echo "\n";
    echo "🔧 COMMON FIXES:\n";
    echo "1. If 'Missing required fields' → Check app payload format\n";
    echo "2. If 'JSON decode error' → Check Content-Type headers\n";
    echo "3. If 'No rows updated' → Check if request already validated\n";
    echo "4. If no logs → Check if endpoint file exists and is accessible\n";
    echo str_repeat("=", 60) . "\n";
    
    // Test the endpoint directly
    echo "\n🧪 Testing endpoint accessibility:\n";
    $endpointUrl = 'https://safdal.investee-group.com/server/api/sync/deletion_requests/admin_validate.php';
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $endpointUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'code_ops' => 'TEST123',
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => 'test_admin'
    ]));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    echo "📡 Test endpoint response:\n";
    echo "   HTTP Code: $httpCode\n";
    echo "   Response: " . substr($response, 0, 200) . "\n";
    if ($error) {
        echo "   cURL Error: $error\n";
    }
    
    if ($httpCode === 404) {
        echo "❌ Endpoint returns 404 - file may not exist or path incorrect\n";
    } elseif ($httpCode === 400) {
        echo "⚠️ Endpoint returns 400 - this is expected for test data\n";
        echo "✅ Endpoint is accessible and processing requests\n";
    } elseif ($httpCode === 200) {
        echo "✅ Endpoint accessible and working\n";
    }
    
} catch (Exception $e) {
    echo "💥 ERROR: " . $e->getMessage() . "\n";
}
?>
