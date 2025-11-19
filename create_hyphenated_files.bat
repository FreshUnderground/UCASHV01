@echo off
echo Creating hyphenated versions of transfer sync files...

copy /Y "server\api\sync\operations\pending_transfers.php" "server\api\sync\operations\pending-transfers.php"
copy /Y "server\api\sync\operations\upload_transfer.php" "server\api\sync\operations\upload-transfer.php"
copy /Y "server\api\sync\operations\update_status.php" "server\api\sync\operations\update-status.php"

echo.
echo Files copied successfully!
echo.
echo Next step: Deploy these files to the server
echo.
pause
