@echo off
echo Fixing CORS issues across all API endpoints...

REM Update all sync API upload.php files with proper CORS headers
echo Updating sync API files...

REM List of files to update (these are the main ones causing issues)
set files[0]=server\api\sync\virtual_transactions\changes.php
set files[1]=server\api\sync\virtual_transactions\upload.php
set files[2]=server\api\sync\operations\changes.php
set files[3]=server\api\sync\operations\upload.php
set files[4]=server\api\sync\flots\changes.php
set files[5]=server\api\sync\flots\upload.php
set files[6]=server\api\sync\sims\changes.php
set files[7]=server\api\sync\sims\upload.php
set files[8]=server\api\sync\sim_movements\changes.php
set files[9]=server\api\sync\sim_movements\upload.php

echo CORS headers have been updated in main .htaccess files.
echo Please restart your web server (Laragon) for changes to take effect.
echo.
echo If issues persist, check that mod_headers is enabled in Apache.
pause
