# 🔍 DEBUG: FLOTs ne se synchronisent pas

## 📋 Problème
Les FLOTs s'enregistrent localement avec `type = flotShopToShop` mais ne se synchronisent pas vers le serveur.

## ✅ Ce qui fonctionne déjà

1. ✅ **Enum Flutter** - `OperationType.flotShopToShop` existe à l'index 7
2. ✅ **PHP Conversion** - `upload.php` convertit index 7 → 'flotShopToShop'
3. ✅ **Filtre Download** - `transfer_sync_service.dart` filtre correctement les FLOTs
4. ✅ **Type dans le code** - Les FLOTs sont créés avec le bon type

## 🔍 Points de Vérification

### 1. Base de données MySQL

**Vérifier que la colonne `type` accepte 'flotShopToShop':**

```bash
# Ouvrir dans un navigateur
https://mahanaim.investee-group.com/server/migrate_flot_shop_to_shop.php
```

**OU exécuter manuellement:**
```sql
SHOW COLUMNS FROM operations LIKE 'type';
-- Doit afficher: enum('transfertNational','transfertInternationalSortant',...,'flotShopToShop')
```

**Si 'flotShopToShop' n'est PAS dans la liste:**
```sql
ALTER TABLE operations 
MODIFY COLUMN type ENUM(
    'transfertNational', 
    'transfertInternationalSortant', 
    'transfertInternationalEntrant', 
    'depot', 
    'retrait', 
    'virement', 
    'retraitMobileMoney',
    'flotShopToShop'
) NOT NULL;
```

### 2. Validation avant upload

**Fichier:** `lib/services/sync_service.dart` (lignes 423-437)

La validation actuelle vérifie:
- ✅ `type` présent
- ✅ `montant_net > 0`  
- ✅ `shop_source_id > 0`

**MAIS** ne vérifie PAS spécifiquement pour les FLOTs qui n'ont pas de client.

### 3. Logs à activer

**Dans Flutter:**
```dart
// Lors de la création du FLOT
debugPrint('🚚 CRÉATION FLOT:');
debugPrint('  type=${flot.type} (index=${flot.type.index})');
debugPrint('  montantNet=${flot.montantNet}');
debugPrint('  shopSourceId=${flot.shopSourceId}');
debugPrint('  shopDestinationId=${flot.shopDestinationId}');
debugPrint('  clientId=${flot.clientId}'); // Doit être NULL
debugPrint('  clientNom=${flot.clientNom}'); // Doit être NULL

// Lors de l'upload
debugPrint('📤 UPLOAD FLOT: code=${flot.codeOps}');
final json = flot.toJson();
debugPrint('  JSON type=${json['type']}'); // Doit être 7
```

**Sur le serveur PHP** (`server/api/sync/operations/upload.php`):

Les logs sont déjà activés (lignes 102-126). Vérifier les logs Apache:
```bash
# Windows (Laragon)
c:\laragon\www\logs\apache_error.log

# Linux
/var/log/apache2/error.log
```

Chercher ces lignes dans les logs:
```
[SYNC OP] NOUVELLE OPERATION RECUE
[SYNC OP] code_ops=FLOT...
[SYNC OP] type_index=7
Conversion: type_index=7 -> type=flotShopToShop
```

### 4. Test manuel d'upload

**Créer un test HTML pour uploader un FLOT:**

```html
<!DOCTYPE html>
<html>
<head><title>Test Upload FLOT</title></head>
<body>
    <h1>Test Upload FLOT</h1>
    <button onclick="testFlot()">Envoyer FLOT Test</button>
    <pre id="result"></pre>
    <script>
        async function testFlot() {
            const data = {
                entities: [{
                    id: 9999999,
                    code_ops: 'FLOT_TEST_' + Date.now(),
                    type: 7, // flotShopToShop
                    statut: 0, // enAttente
                    montant_brut: 1000,
                    montant_net: 1000,
                    commission: 0,
                    devise: 'USD',
                    client_id: null, // ← Pas de client
                    client_nom: null,
                    agent_id: 1,
                    agent_username: 'admin',
                    shop_source_id: 1764100003058,
                    shop_source_designation: 'Shop A',
                    shop_destination_id: 1764207354919,
                    shop_destination_designation: 'Shop B',
                    mode_paiement: 0, // cash
                    notes: 'Test FLOT depuis HTML',
                    last_modified_at: new Date().toIso8601String(),
                    date_op: new Date().toIso8601String()
                }],
                user_id: 'test_html',
                timestamp: new Date().toIso8601String()
            };

            try {
                const response = await fetch('https://mahanaim.investee-group.com/server/api/sync/operations/upload.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json'
                    },
                    body: JSON.stringify(data)
                });

                const result = await response.json();
                document.getElementById('result').textContent = JSON.stringify(result, null, 2);
                
                if (result.success) {
                    alert('✅ FLOT uploadé avec succès!');
                } else {
                    alert('❌ Erreur: ' + result.message);
                }
            } catch (error) {
                document.getElementById('result').textContent = 'ERREUR: ' + error;
            }
        }
    </script>
</body>
</html>
```

Sauvegarder comme `test_flot_upload.html` et ouvrir dans un navigateur.

## 🐛 Erreurs Possibles

### Erreur 1: "Data type mismatch for ENUM"
**Cause:** MySQL n'accepte pas 'flotShopToShop' car l'ENUM n'a pas été mis à jour  
**Solution:** Exécuter la migration SQL ci-dessus

### Erreur 2: "shop_destination_id manquant"
**Cause:** Validation PHP rejette les FLOTs sans destination  
**Solution:** Vérifier que `shop_destination_id` est bien envoyé dans le JSON

### Erreur 3: "Client non trouvé"
**Cause:** Le serveur essaie de résoudre `client_nom` alors qu'il est NULL pour les FLOTs  
**Solution:** Modifier `upload.php` pour accepter `client_id = NULL` pour les FLOTs

### Erreur 4: "Agent non trouvé"
**Cause:** `agent_id` ou `agent_username` invalide  
**Solution:** Vérifier que l'agent existe dans la base

## 🔧 Actions Correctives

### Si le FLOT ne s'upload PAS:

1. **Vérifier les logs Flutter:**
   ```
   flutter run --verbose
   # Chercher: "📤 Upload operations..."
   # Chercher: "❌ Validation: ..."
   ```

2. **Vérifier les logs PHP:**
   ```bash
   tail -f c:\laragon\www\logs\apache_error.log
   # Chercher: "[SYNC OP] NOUVELLE OPERATION"
   # Chercher: "type_index=7 -> type=flotShopToShop"
   ```

3. **Vérifier directement dans MySQL:**
   ```sql
   SELECT * FROM operations WHERE type = 'flotShopToShop' ORDER BY created_at DESC LIMIT 5;
   ```

4. **Si MySQL rejette avec "Data type mismatch":**
   - ⚠️ La migration n'a PAS été exécutée
   - Exécuter: `migrate_flot_shop_to_shop.php`

5. **Si PHP rejette avec "Validation failed":**
   - Vérifier que `client_nom` peut être NULL
   - Vérifier que `shop_destination_id` est présent
   - Vérifier que `agent_id` existe

## 📊 Commandes de Diagnostic

```sql
-- 1. Vérifier structure de la colonne type
SHOW COLUMNS FROM operations LIKE 'type';

-- 2. Compter les FLOTs existants
SELECT COUNT(*) FROM operations WHERE type = 'flotShopToShop';

-- 3. Afficher les 5 derniers FLOTs
SELECT code_ops, shop_source_designation, shop_destination_designation, 
       montant_net, statut, created_at 
FROM operations 
WHERE type = 'flotShopToShop' 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Vérifier si des FLOTs sont rejetés (chercher dans les logs)
-- (Pas de table d'erreurs, vérifier logs PHP)
```

## ✅ Checklist

- [ ] Migration SQL exécutée (`flotShopToShop` dans l'ENUM)
- [ ] Flutter compile sans erreur
- [ ] Test manuel d'upload fonctionne
- [ ] Les FLOTs apparaissent dans MySQL
- [ ] Les FLOTs se download correctement
- [ ] La validation fonctionne (enAttente → validee)

## 📞 Support

Si après toutes ces vérifications le problème persiste, fournir:
1. Les logs Flutter lors de la création du FLOT
2. Les logs PHP lors de l'upload
3. Le résultat de `SHOW COLUMNS FROM operations LIKE 'type';`
4. Un exemple de JSON envoyé par Flutter
