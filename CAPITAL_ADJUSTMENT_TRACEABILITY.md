# 📝 Système de Traçabilité des Ajustements de Capital

## 🎯 Objectif

Tracer **TOUS** les ajustements de capital effectués par l'admin avec une **traçabilité complète** dans l'audit log.

---

## 📦 Ce qui a été Implémenté

### ✅ **1. API Backend**

#### **`server/api/audit/log_capital_adjustment.php`**
- **Fonction**: Enregistrer un ajustement de capital avec traçabilité complète
- **Méthode**: POST
- **Paramètres**:
  ```json
  {
    "shop_id": 1,
    "adjustment_type": "INCREASE", // ou "DECREASE"
    "amount": 5000.00,
    "mode_paiement": "cash", // cash, airtel_money, mpesa, orange_money
    "reason": "Injection capital supplémentaire",
    "description": "Contexte additionnel (optionnel)",
    "admin_id": 1,
    "admin_username": "admin"
  }
  ```
- **Réponse**:
  ```json
  {
    "success": true,
    "message": "Ajustement de capital enregistré avec succès",
    "adjustment": {
      "audit_id": 123,
      "shop_id": 1,
      "shop_name": "Shop Centre",
      "adjustment_type": "INCREASE",
      "amount": 5000,
      "mode_paiement": "cash",
      "capital_before": 10000,
      "capital_after": 15000,
      "difference": 5000,
      "admin": "admin",
      "timestamp": "2025-12-11 12:00:00"
    },
    "details": {
      "cash": {
        "before": 5000,
        "after": 10000,
        "change": 5000
      },
      "airtel_money": {...},
      "mpesa": {...},
      "orange_money": {...}
    }
  }
  ```

#### **`server/api/audit/get_capital_adjustments.php`**
- **Fonction**: Récupérer l'historique des ajustements
- **Méthode**: GET
- **Paramètres (optionnels)**:
  - `shop_id`: Filtrer par shop
  - `admin_id`: Filtrer par admin
  - `start_date`: Date de début (format: YYYY-MM-DD)
  - `end_date`: Date de fin
  - `limit`: Nombre maximum de résultats (défaut: 50)
- **URL Exemple**:
  ```
  /api/audit/get_capital_adjustments.php?shop_id=1&limit=20
  ```

---

### ✅ **2. Service Flutter**

#### **`lib/services/capital_adjustment_service.dart`**
- **Classe**: `CapitalAdjustmentService` (Singleton + ChangeNotifier)
- **Méthodes principales**:

```dart
// Créer un ajustement
Future<Map<String, dynamic>?> createAdjustment({
  required ShopModel shop,
  required AdjustmentType adjustmentType,
  required double amount,
  required PaymentMode modePaiement,
  required String reason,
  String? description,
  required int adminId,
  required String adminUsername,
})

// Charger l'historique
Future<void> loadAdjustments({
  int? shopId,
  int? adminId,
  String? startDate,
  String? endDate,
  int limit = 50,
})
```

---

### ✅ **3. Widgets Flutter**

#### **`lib/widgets/capital_adjustment_dialog_tracked.dart`**
Widget de dialogue pour effectuer un ajustement de capital.

**Fonctionnalités**:
- ✅ Affichage du capital actuel (total + détails par mode)
- ✅ Choix du type (augmentation/diminution)
- ✅ Choix du mode de paiement (cash, Airtel, M-Pesa, Orange)
- ✅ Montant avec validation
- ✅ Raison obligatoire (minimum 10 caractères)
- ✅ Description optionnelle
- ✅ Aperçu en temps réel du résultat
- ✅ Enregistrement dans l'audit log
- ✅ Notification de succès avec détails

**Utilisation**:
```dart
showDialog(
  context: context,
  builder: (context) => CapitalAdjustmentDialogWithTracking(
    shop: selectedShop,
  ),
);
```

#### **`lib/widgets/reports/capital_adjustments_history.dart`**
Widget pour afficher l'historique complet des ajustements.

**Fonctionnalités**:
- ✅ Liste des ajustements avec détails
- ✅ Filtre par période (date range)
- ✅ Rafraîchissement manuel
- ✅ Affichage de la raison et description
- ✅ Visualisation avant/après
- ✅ Identification de l'admin et date/heure
- ✅ Audit ID pour référence

**Utilisation**:
```dart
// Pour un shop spécifique
CapitalAdjustmentsHistory(shop: selectedShop)

// Pour tous les shops
CapitalAdjustmentsHistory()

// Pour un admin spécifique
CapitalAdjustmentsHistory(adminId: 1)
```

---

## 🔍 **Traçabilité Complète**

Chaque ajustement enregistre dans `audit_log`:

| Champ | Description | Exemple |
|-------|-------------|---------|
| **id** | ID unique de l'audit | 123 |
| **table_name** | Table concernée | 'shops' |
| **record_id** | ID du shop | 1 |
| **action** | Type d'action | 'CAPITAL_INCREASE' ou 'CAPITAL_DECREASE' |
| **old_values** | Valeurs avant modification (JSON) | `{"capital_actuel": 10000, "capital_cash": 5000, ...}` |
| **new_values** | Valeurs après modification (JSON) | `{"capital_actuel": 15000, "capital_cash": 10000, ...}` |
| **changed_fields** | Champs modifiés + métadonnées (JSON) | `{"adjustment_type": "INCREASE", "amount": 5000, "mode_paiement": "cash", "description": "..."}` |
| **user_id** | ID de l'admin | 1 |
| **user_role** | Rôle | 'ADMIN' |
| **username** | Nom d'utilisateur | 'admin' |
| **shop_id** | ID du shop concerné | 1 |
| **reason** | Raison de l'ajustement | 'Injection capital supplémentaire' |
| **created_at** | Date/heure | '2025-12-11 12:00:00' |

---

## 📊 **Requêtes SQL Utiles**

### 1. Voir tous les ajustements d'un shop
```sql
SELECT 
    al.id AS audit_id,
    al.created_at,
    al.action,
    al.reason,
    al.username AS admin,
    al.old_values->>'$.capital_actuel' AS capital_before,
    al.new_values->>'$.capital_actuel' AS capital_after,
    s.designation AS shop_name
FROM audit_log al
JOIN shops s ON al.record_id = s.id
WHERE al.table_name = 'shops'
  AND al.record_id = 1
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
ORDER BY al.created_at DESC;
```

### 2. Statistiques par admin
```sql
SELECT 
    username AS admin,
    COUNT(*) AS total_adjustments,
    SUM(CASE WHEN action = 'CAPITAL_INCREASE' THEN 1 ELSE 0 END) AS increases,
    SUM(CASE WHEN action = 'CAPITAL_DECREASE' THEN 1 ELSE 0 END) AS decreases
FROM audit_log
WHERE table_name = 'shops'
  AND action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
GROUP BY username
ORDER BY total_adjustments DESC;
```

### 3. Ajustements suspects (montants élevés)
```sql
SELECT 
    al.id,
    al.created_at,
    al.username,
    s.designation AS shop,
    al.action,
    JSON_EXTRACT(al.changed_fields, '$.amount') AS amount,
    al.reason
FROM audit_log al
JOIN shops s ON al.record_id = s.id
WHERE al.table_name = 'shops'
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
  AND JSON_EXTRACT(al.changed_fields, '$.amount') > 10000
ORDER BY JSON_EXTRACT(al.changed_fields, '$.amount') DESC;
```

### 4. Ajustements du jour
```sql
SELECT 
    al.id,
    al.created_at,
    al.username,
    s.designation,
    al.action,
    al.reason
FROM audit_log al
JOIN shops s ON al.record_id = s.id
WHERE al.table_name = 'shops'
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
  AND DATE(al.created_at) = CURDATE()
ORDER BY al.created_at DESC;
```

### 5. Évolution complète d'un shop
```sql
SELECT 
    al.created_at,
    al.action,
    JSON_EXTRACT(al.changed_fields, '$.amount') AS amount,
    JSON_EXTRACT(al.changed_fields, '$.mode_paiement') AS mode,
    al.old_values->>'$.capital_actuel' AS capital_before,
    al.new_values->>'$.capital_actuel' AS capital_after,
    al.username,
    al.reason
FROM audit_log al
WHERE al.table_name = 'shops'
  AND al.record_id = 1
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
ORDER BY al.created_at ASC;
```

---

## 🧪 **Test Manuel**

### **Via API (cURL)**

#### Test 1: Augmentation de capital
```bash
curl -X POST http://localhost/UCASHV01/server/api/audit/log_capital_adjustment.php \
  -H "Content-Type: application/json" \
  -d '{
    "shop_id": 1,
    "adjustment_type": "INCREASE",
    "amount": 5000.00,
    "mode_paiement": "cash",
    "reason": "Test injection capital",
    "description": "Test manuel de l API",
    "admin_id": 1,
    "admin_username": "admin"
  }'
```

#### Test 2: Diminution de capital
```bash
curl -X POST http://localhost/UCASHV01/server/api/audit/log_capital_adjustment.php \
  -H "Content-Type: application/json" \
  -d '{
    "shop_id": 1,
    "adjustment_type": "DECREASE",
    "amount": 2000.00,
    "mode_paiement": "mpesa",
    "reason": "Test retrait capital",
    "admin_id": 1,
    "admin_username": "admin"
  }'
```

#### Test 3: Récupérer l'historique
```bash
curl http://localhost/UCASHV01/server/api/audit/get_capital_adjustments.php?shop_id=1&limit=10
```

---

## 🎨 **Intégration dans l'Interface Admin**

### **Exemple: Ajouter un bouton dans la page des shops**

```dart
// Dans admin_shops_page.dart ou similaire

// Import
import '../widgets/capital_adjustment_dialog_tracked.dart';
import '../widgets/reports/capital_adjustments_history.dart';

// Dans le menu d'actions d'un shop
PopupMenuButton<String>(
  itemBuilder: (context) => [
    PopupMenuItem(
      value: 'adjust_capital',
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet),
          SizedBox(width: 8),
          Text('Ajuster le Capital'),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'view_history',
      child: Row(
        children: [
          Icon(Icons.history),
          SizedBox(width: 8),
          Text('Voir l\'Historique'),
        ],
      ),
    ),
  ],
  onSelected: (value) {
    if (value == 'adjust_capital') {
      showDialog(
        context: context,
        builder: (context) => CapitalAdjustmentDialogWithTracking(
          shop: selectedShop,
        ),
      );
    } else if (value == 'view_history') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('Historique des Ajustements')),
            body: CapitalAdjustmentsHistory(shop: selectedShop),
          ),
        ),
      );
    }
  },
)
```

---

## ✅ **Avantages de cette Solution**

| Avantage | Description |
|----------|-------------|
| **📝 Traçabilité Complète** | Chaque modification est enregistrée dans `audit_log` avec QUI, QUAND, POURQUOI |
| **🔍 Audit Trail** | Impossible de modifier le capital sans laisser de trace |
| **📊 Historique Détaillé** | Visualisation complète de l'évolution du capital |
| **🔒 Sécurité** | Identification de l'admin, raison obligatoire |
| **⚖️ Réconciliation** | Comparaison facile entre capital système et capital réel |
| **🎯 Filtres Avancés** | Par shop, admin, période, montant |
| **📈 Statistiques** | Reporting sur les ajustements (qui, quand, combien) |
| **🔄 Intégration Sync** | Les modifications sont automatiquement synchronisées |

---

## 🚀 **Prochaines Étapes (Optionnel)**

### **1. Alertes Automatiques**
Créer un système d'alerte pour les ajustements suspects:
```sql
-- Trigger qui envoie une alerte si montant > 10000
DELIMITER //
CREATE TRIGGER alert_large_adjustments
AFTER INSERT ON audit_log
FOR EACH ROW
BEGIN
  IF NEW.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE') 
     AND JSON_EXTRACT(NEW.changed_fields, '$.amount') > 10000 THEN
    -- Envoyer notification ou enregistrer dans une table d'alertes
    INSERT INTO alerts (type, message, created_at)
    VALUES ('LARGE_CAPITAL_ADJUSTMENT', 
            CONCAT('Ajustement de ', JSON_EXTRACT(NEW.changed_fields, '$.amount'), 
                   ' USD par ', NEW.username),
            NOW());
  END IF;
END//
DELIMITER ;
```

### **2. Rapport PDF d'Audit**
Générer un PDF récapitulatif des ajustements pour une période donnée.

### **3. Dashboard de Surveillance**
Widget affichant en temps réel:
- Nombre d'ajustements du jour
- Montant total ajusté
- Alertes actives
- Graph d'évolution

### **4. Approbation à Deux Niveaux**
Ajuster > 5000 USD nécessite une validation d'un deuxième admin.

---

## 📚 **Fichiers Créés**

1. ✅ `server/api/audit/log_capital_adjustment.php` (226 lignes)
2. ✅ `server/api/audit/get_capital_adjustments.php` (157 lignes)
3. ✅ `lib/services/capital_adjustment_service.dart` (257 lignes)
4. ✅ `lib/widgets/capital_adjustment_dialog_tracked.dart` (497 lignes)
5. ✅ `lib/widgets/reports/capital_adjustments_history.dart` (435 lignes)
6. ✅ `server/test_capital_adjustment.php` (224 lignes)
7. ✅ `CAPITAL_ADJUSTMENT_TRACEABILITY.md` (ce document)

**Total: ~1,796 lignes de code + documentation**

---

## 🎓 **Comment Ça Marche?**

### **Flux Complet d'un Ajustement**

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ADMIN ouvre le dialogue d'ajustement                    │
│    (CapitalAdjustmentDialogWithTracking)                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. ADMIN remplit le formulaire:                            │
│    - Type: Augmentation/Diminution                         │
│    - Mode: Cash/Airtel/M-Pesa/Orange                       │
│    - Montant: 5000 USD                                      │
│    - Raison: "Injection capital supplémentaire"            │
│    - Description (optionnel)                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Validation et aperçu en temps réel                      │
│    Capital actuel: 10,000 USD                              │
│    Ajustement:     +5,000 USD (Cash)                       │
│    Nouveau capital: 15,000 USD                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. ADMIN confirme → Appel API                              │
│    POST /api/audit/log_capital_adjustment.php              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. SERVEUR:                                                 │
│    a) Lit les valeurs AVANT modification                   │
│    b) Calcule les nouvelles valeurs                        │
│    c) Met à jour la table shops                            │
│    d) ✅ Enregistre dans audit_log                         │
│       - old_values (JSON)                                   │
│       - new_values (JSON)                                   │
│       - reason, admin, timestamp                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Réponse SUCCESS avec détails                            │
│    - Audit ID: 123                                          │
│    - Capital before: 10,000                                 │
│    - Capital after: 15,000                                  │
│    - Details par mode de paiement                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. FLUTTER:                                                 │
│    - Rafraîchit les shops (ShopService.loadShops())        │
│    - Affiche notification de succès                        │
│    - Ferme le dialogue                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. L'historique est maintenant visible dans                │
│    CapitalAdjustmentsHistory widget                        │
└─────────────────────────────────────────────────────────────┘
```

---

**Date de création:** 2025-12-11  
**Version:** 1.0.0  
**Statut:** ✅ Prêt pour Production  
**Auteur:** Qoder AI Assistant
