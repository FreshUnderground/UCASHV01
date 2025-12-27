@echo off
REM ========================================
REM Test Script: Agent CRUD Operations
REM ========================================
echo.
echo ========================================
echo  UCASH V01 - TEST AGENT CRUD
echo ========================================
echo.

REM Colors
set GREEN=[92m
set RED=[91m
set YELLOW=[93m
set BLUE=[94m
set RESET=[0m

echo %BLUE%1. Verification de la structure de la base de donnees%RESET%
echo.
echo Verification table agents...
php -r "require 'server/config/database.php'; $stmt = $pdo->query('DESCRIBE agents'); while($row = $stmt->fetch()) { echo $row['Field'] . ' - ' . $row['Type'] . PHP_EOL; }"
echo.

echo %BLUE%2. Test CREATE - Creation d'un agent de test%RESET%
echo.
php -r "require 'server/config/database.php'; try { $stmt = $pdo->prepare('INSERT INTO agents (username, password, nom, shop_id, role, is_active, created_at, last_modified_at, last_modified_by) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), ?)'); $result = $stmt->execute(['test_agent_'.time(), 'test123', 'Agent Test', 1, 'AGENT', 1, 'admin']); echo $result ? '%GREEN%SUCCESS: Agent cree avec ID ' . $pdo->lastInsertId() . '%RESET%' : '%RED%ERREUR: Echec creation%RESET%'; } catch(Exception $e) { echo '%RED%ERREUR: ' . $e->getMessage() . '%RESET%'; }"
echo.

echo %BLUE%3. Test READ - Lecture de tous les agents%RESET%
echo.
php -r "require 'server/config/database.php'; $stmt = $pdo->query('SELECT COUNT(*) as total FROM agents'); $row = $stmt->fetch(); echo '%GREEN%Total agents: ' . $row['total'] . '%RESET%' . PHP_EOL; $stmt = $pdo->query('SELECT id, username, nom, shop_id, role, is_active FROM agents LIMIT 5'); while($row = $stmt->fetch()) { echo '  - ID:' . $row['id'] . ' | ' . $row['username'] . ' | Shop:' . $row['shop_id'] . ' | Role:' . $row['role'] . ' | Active:' . ($row['is_active'] ? 'Oui' : 'Non') . PHP_EOL; }"
echo.

echo %BLUE%4. Test UPDATE - Modification d'un agent%RESET%
echo.
php -r "require 'server/config/database.php'; try { $stmt = $pdo->query('SELECT id FROM agents ORDER BY id DESC LIMIT 1'); $agent = $stmt->fetch(); if($agent) { $stmt = $pdo->prepare('UPDATE agents SET nom = ?, last_modified_at = NOW() WHERE id = ?'); $result = $stmt->execute(['Agent Modifie Test', $agent['id']]); echo $result ? '%GREEN%SUCCESS: Agent ID ' . $agent['id'] . ' modifie%RESET%' : '%RED%ERREUR: Echec modification%RESET%'; } else { echo '%YELLOW%WARNING: Aucun agent trouve%RESET%'; } } catch(Exception $e) { echo '%RED%ERREUR: ' . $e->getMessage() . '%RESET%'; }"
echo.

echo %BLUE%5. Test SOFT DELETE - Desactivation d'un agent%RESET%
echo.
php -r "require 'server/config/database.php'; try { $stmt = $pdo->query('SELECT id FROM agents WHERE is_active = 1 ORDER BY id DESC LIMIT 1'); $agent = $stmt->fetch(); if($agent) { $stmt = $pdo->prepare('UPDATE agents SET is_active = 0, last_modified_at = NOW() WHERE id = ?'); $result = $stmt->execute([$agent['id']]); echo $result ? '%GREEN%SUCCESS: Agent ID ' . $agent['id'] . ' desactive%RESET%' : '%RED%ERREUR: Echec desactivation%RESET%'; } else { echo '%YELLOW%WARNING: Aucun agent actif trouve%RESET%'; } } catch(Exception $e) { echo '%RED%ERREUR: ' . $e->getMessage() . '%RESET%'; }"
echo.

echo %BLUE%6. Test API UPLOAD - Simulation upload depuis Flutter%RESET%
echo.
curl -X POST https://mahanaim.investee-group.com/server/api/sync/agents/upload.php -H "Content-Type: application/json" -d "{\"entities\":[{\"id\":999999999,\"username\":\"api_test\",\"password\":\"test123\",\"nom\":\"API Test Agent\",\"shop_id\":1,\"role\":\"AGENT\",\"is_active\":1,\"last_modified_at\":\"2025-12-11 10:00:00\",\"last_modified_by\":\"test\"}],\"user_id\":\"admin\"}"
echo.

echo %BLUE%7. Test API DOWNLOAD - Simulation download vers Flutter%RESET%
echo.
curl -X GET "https://mahanaim.investee-group.com/server/api/sync/agents/changes.php?user_role=admin&limit=5"
echo.

echo.
echo %GREEN%========================================%RESET%
echo %GREEN% TESTS TERMINES%RESET%
echo %GREEN%========================================%RESET%
echo.
echo Pour plus de details, consultez:
echo - AGENT_CRUD_VERIFICATION.md (documentation complete)
echo - lib/services/agent_service.dart (code source)
echo - server/api/sync/agents/ (API endpoints)
echo.
pause
