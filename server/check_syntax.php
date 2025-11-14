<?php
// Check syntax of shops upload.php
$output = shell_exec('php -l server/api/sync/shops/upload.php 2>&1');
echo $output;
?>