// Test CORS OPTIONS
async function testCORS() {
    try {
        const response = await fetch('https://mahanaim.investee-group.com/server/api/sync/triangular_debt_settlements/upload.php', {
            method: 'OPTIONS',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        });
        console.log('✅ CORS OPTIONS:', response.status, response.statusText);
        console.log('📋 Headers:', [...response.headers.entries()]);
        return response.ok;
    } catch (error) {
        console.error('❌ CORS Error:', error);
        return false;
    }
}

// Test Upload avec données réelles
async function testTriangularUpload() {
    const data = {
        "entities": [{
            "id": 1,
            "reference": "TRI20251221-83194",
            "shop_debtor_id": 1765124856371,
            "shop_debtor_designation": "shop kampala",
            "shop_intermediary_id": 1765485299073,
            "shop_intermediary_designation": "SHOP BUTEMBO",
            "shop_creditor_id": 1765124945851,
            "shop_creditor_designation": "shop kisangani",
            "montant": 7000,
            "devise": "USD",
            "date_reglement": "2025-12-21T07:36:23.194",
            "mode_paiement": null,
            "notes": null,
            "agent_id": 0,
            "agent_username": "admin",
            "created_at": "2025-12-21T07:36:23.194",
            "last_modified_at": "2025-12-21T07:36:23.194",
            "last_modified_by": "agent_0",
            "is_synced": 0,
            "synced_at": "2025-12-21T07:36:42.548",
            "entity_type": "triangular_debt_settlement",
            "sync_version": 1
        }],
        "user_id": "admin",
        "timestamp": new Date().toISOString()
    };

    try {
        console.log('📤 Sending data:', data);
        const response = await fetch('https://mahanaim.investee-group.com/server/api/sync/triangular_debt_settlements/upload.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(data)
        });

        const result = await response.text();
        console.log('📥 Response Status:', response.status, response.statusText);
        console.log('📥 Response Body:', result);
        
        try {
            const jsonResult = JSON.parse(result);
            console.log('✅ Parsed JSON:', jsonResult);
        } catch (e) {
            console.log('⚠️ Response is not JSON');
        }
        
        return response.ok;
    } catch (error) {
        console.error('❌ Upload Error:', error);
        return false;
    }
}

// Exécuter les tests
console.log('🔺 Début des tests Triangular Debt Settlements');
testCORS().then(corsOk => {
    if (corsOk) {
        console.log('✅ CORS OK, test upload...');
        testTriangularUpload();
    } else {
        console.log('❌ CORS failed, skipping upload test');
    }
});
