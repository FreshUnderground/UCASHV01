@echo off
echo ========================================
echo TEST DELETION SYNC - Agents et Shops
echo ========================================
echo.

REM Configuration
set BASE_URL=https://mahanaimeservice.investee-group.com/server/api/sync
set AGENTS_URL=%BASE_URL%/agents/check_deleted.php
set SHOPS_URL=%BASE_URL%/shops/check_deleted.php

echo [1/4] Test Check Deleted Agents - Valid Request
echo.
curl -X POST "%AGENTS_URL%" ^
  -H "Content-Type: application/json" ^
  -d "{\"agent_ids\": [1, 2, 3, 999, 1000]}"
echo.
echo.

echo [2/4] Test Check Deleted Shops - Valid Request
echo.
curl -X POST "%SHOPS_URL%" ^
  -H "Content-Type: application/json" ^
  -d "{\"shop_ids\": [1, 2, 3, 999, 1000]}"
echo.
echo.

echo [3/4] Test Empty Array - Agents
echo.
curl -X POST "%AGENTS_URL%" ^
  -H "Content-Type: application/json" ^
  -d "{\"agent_ids\": []}"
echo.
echo.

echo [4/4] Test Invalid Method - GET (should fail)
echo.
curl -X GET "%AGENTS_URL%"
echo.
echo.

echo ========================================
echo Tests termines!
echo ========================================
pause
