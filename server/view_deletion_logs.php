<?php
// Script to view deletion request logs

header('Content-Type: text/plain');

echo "Deletion Requests Logs\n";
echo "====================\n\n";

// Check if there are any log files in common locations
$logFiles = [
    '/var/log/apache2/error.log',
    '/var/log/httpd/error_log',
    '/usr/local/apache2/logs/error_log',
    'C:/laragon/bin/apache/httpd-2.4.48-win64-VS16/logs/error.log',
    'C:/laragon/etc/apache2/logs/access.log',
    'C:/laragon/etc/apache2/logs/error.log',
    '/tmp/php_errors.log',
    'php://stderr'
];

echo "Searching for deletion request logs...\n\n";

// Search in the current directory for any log files
$currentDir = __DIR__;
$files = scandir($currentDir);

foreach ($files as $file) {
    if (strpos($file, '.log') !== false || strpos($file, 'error') !== false) {
        echo "Found potential log file: $file\n";
    }
}

// Try to read PHP error log
$errorLog = ini_get('error_log');
if ($errorLog && file_exists($errorLog)) {
    echo "\nReading PHP error log: $errorLog\n";
    echo str_repeat('-', 50) . "\n";
    
    $lines = file($errorLog, FILE_IGNORE_NEW_LINES);
    $deletionLogs = [];
    
    foreach ($lines as $line) {
        if (strpos($line, '[DELETION_REQUESTS]') !== false) {
            $deletionLogs[] = $line;
        }
    }
    
    if (count($deletionLogs) > 0) {
        // Show last 20 deletion logs
        $recentLogs = array_slice($deletionLogs, -20);
        foreach ($recentLogs as $log) {
            echo $log . "\n";
        }
    } else {
        echo "No deletion request logs found in PHP error log\n";
    }
} else {
    echo "\nCould not locate PHP error log\n";
}

// Also check server error logs
echo "\n" . str_repeat('=', 50) . "\n";
echo "Checking for recent deletion request activity:\n\n";

// Try to read the last few lines of the current script to see if we can find logs
$selfContent = file(__FILE__);
foreach ($selfContent as $lineNum => $line) {
    if (strpos($line, '[DELETION_REQUESTS]') !== false) {
        echo "Line " . ($lineNum + 1) . ": " . trim($line) . "\n";
    }
}

echo "\nDone.\n";

?>