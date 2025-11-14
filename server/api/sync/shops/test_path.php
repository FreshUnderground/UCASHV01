<?php
echo "Current directory: " . getcwd() . "\n";
echo "Attempting to include: ../../../config/database.php\n";

if (file_exists('../../../config/database.php')) {
    echo "File exists!\n";
    require_once '../../../config/database.php';
    echo "Database included successfully!\n";
} else {
    echo "File does not exist!\n";
    echo "Looking in: " . realpath('../../../config/database.php') . "\n";
}
?>