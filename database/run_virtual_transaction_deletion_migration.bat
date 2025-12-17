@echo off
echo Executing virtual transaction deletion tables migration...
echo.

REM Change to the database directory
cd /d "c:\laragon1\www\UCASHV01\database"

REM Execute the SQL script using mysql command
mysql -u root -p ucash_db < create_virtual_transaction_deletion_tables.sql

if %errorlevel% equ 0 (
    echo.
    echo ✅ Migration executed successfully!
    echo Tables created:
    echo   - virtual_transaction_deletion_requests
    echo   - virtual_transactions_corbeille
) else (
    echo.
    echo ❌ Migration failed with error code %errorlevel%
)

echo.
pause
