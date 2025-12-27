#!/bin/bash

# Script de test de la synchronisation UCASH
# Usage: ./test_sync.sh

echo "🔄 Test de la Synchronisation UCASH"
echo "===================================="
echo ""

# Configuration
BASE_URL="https://mahanaim.investee-group.com/server/api/sync"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Ping serveur
echo "📡 Test 1: Connectivité au serveur..."
response=$(curl -s -w "%{http_code}" -o /tmp/ping_response.json "${BASE_URL}/ping.php")
http_code="${response: -3}"

if [ "$http_code" == "200" ]; then
    echo -e "${GREEN}✅ Serveur accessible${NC}"
    cat /tmp/ping_response.json | python3 -m json.tool
else
    echo -e "${RED}❌ Serveur non accessible (HTTP $http_code)${NC}"
    exit 1
fi

echo ""

# Test 2: Upload d'une opération de test
echo "📤 Test 2: Upload d'une opération..."
cat > /tmp/test_operation.json <<EOF
{
  "entities": [
    {
      "id": 9999,
      "type": "depot",
      "montantBrut": 100.00,
      "montantNet": 97.00,
      "commission": 3.00,
      "clientId": 1,
      "shopSourceId": 1,
      "agentId": 1,
      "modePaiement": "cash",
      "statut": "terminee",
      "reference": "TEST_SYNC_001",
      "notes": "Test de synchronisation automatique",
      "dateOp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "lastModifiedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "lastModifiedBy": "test_script"
    }
  ],
  "user_id": "test_script",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

response=$(curl -s -w "%{http_code}" -o /tmp/upload_response.json \
    -X POST "${BASE_URL}/operations/upload.php" \
    -H "Content-Type: application/json" \
    -d @/tmp/test_operation.json)
http_code="${response: -3}"

if [ "$http_code" == "200" ]; then
    success=$(cat /tmp/upload_response.json | python3 -c "import sys, json; print(json.load(sys.stdin)['success'])" 2>/dev/null)
    if [ "$success" == "True" ]; then
        echo -e "${GREEN}✅ Upload réussi${NC}"
        cat /tmp/upload_response.json | python3 -m json.tool
    else
        echo -e "${YELLOW}⚠️  Upload avec avertissement${NC}"
        cat /tmp/upload_response.json | python3 -m json.tool
    fi
else
    echo -e "${RED}❌ Erreur upload (HTTP $http_code)${NC}"
    cat /tmp/upload_response.json
fi

echo ""

# Test 3: Download des opérations
echo "📥 Test 3: Download des opérations..."
since_date=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%SZ")
response=$(curl -s -w "%{http_code}" -o /tmp/download_response.json \
    "${BASE_URL}/operations/changes.php?since=${since_date}&user_id=test_script&limit=5")
http_code="${response: -3}"

if [ "$http_code" == "200" ]; then
    count=$(cat /tmp/download_response.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))" 2>/dev/null)
    echo -e "${GREEN}✅ Download réussi - $count opérations récupérées${NC}"
    cat /tmp/download_response.json | python3 -m json.tool | head -n 30
else
    echo -e "${RED}❌ Erreur download (HTTP $http_code)${NC}"
    cat /tmp/download_response.json
fi

echo ""

# Test 4: Vérification MySQL
echo "🗄️  Test 4: Vérification de la base de données..."
echo "SELECT COUNT(*) as total_operations FROM operations;" | mysql -u root ucash 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Base de données accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Impossible de se connecter à MySQL (vérifiez les credentials)${NC}"
fi

echo ""

# Test 5: Statut de synchronisation
echo "📊 Test 5: Statut de synchronisation..."
echo "SELECT * FROM v_sync_status;" | mysql -u root ucash -t 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Métadonnées de sync accessibles${NC}"
else
    echo -e "${YELLOW}⚠️  Vue v_sync_status non trouvée${NC}"
fi

echo ""

# Nettoyage
rm -f /tmp/ping_response.json /tmp/test_operation.json /tmp/upload_response.json /tmp/download_response.json

echo "===================================="
echo -e "${GREEN}✅ Tests de synchronisation terminés${NC}"
echo ""
echo "📝 Prochaines étapes:"
echo "  1. Lancer l'application Flutter"
echo "  2. Vérifier les logs de synchronisation (toutes les 30s)"
echo "  3. Observer l'indicateur de sync dans l'AppBar"
echo ""
