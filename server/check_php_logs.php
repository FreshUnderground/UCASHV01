<?php
// Check PHP log configuration and recent errors

echo "<pre>";
echo "PHP Log Configuration\n";
echo "===================\n\n";

// Display PHP log settings
echo "error_log: " . ini_get('error_log') . "\n";
echo "log_errors: " . ini_get('log_errors') . "\n";
echo "display_errors: " . ini_get('display_errors') . "\n";
echo "error_reporting: " . ini_get('error_reporting') . "\n";

echo "\nRecent PHP Errors (last 50 lines):\n";
echo str_repeat("-", 40) . "\n";

// Try to read the error log
$errorLog = ini_get('error_log');
if ($errorLog && file_exists($errorLog)) {
    $lines = file($errorLog, FILE_IGNORE_NEW_LINES);
    $recentLines = array_slice($lines, -50);
    
    foreach ($recentLines as $line) {
        if (strpos($line, '[DELETION_REQUESTS]') !== false) {
            echo "<span style='color: blue; font-weight: bold;'>" . htmlspecialchars($line) . "</span>\n";
        } elseif (strpos($line, 'PHP') !== false && (strpos($line, 'Error') !== false || strpos($line, 'Warning') !== false)) {
            echo "<span style='color: red;'>" . htmlspecialchars($line) . "</span>\n";
        } else {
            echo htmlspecialchars($line) . "\n";
        }
    }
} else {
    echo "Could not find or access PHP error log.\n";
    echo "Tried: $errorLog\n";
}

echo "\n\nDirectory listing:\n";
echo str_repeat("-", 40) . "\n";
$files = scandir(__DIR__);
foreach ($files as $file) {
    if (is_file(__DIR__ . '/' . $file)) {
        $size = filesize(__DIR__ . '/' . $file);
        echo sprintf("%-30s %10d bytes\n", $file, $size);
    }
}

echo "</pre>";

?>