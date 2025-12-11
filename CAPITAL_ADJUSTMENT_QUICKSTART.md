# 🚀 Démarrage Rapide - Traçabilité des Ajustements de Capital

## ⚡ En 5 Minutes

### 1️⃣ **Ajuster le Capital d'un Shop**

```dart
import '../widgets/capital_adjustment_dialog_tracked.dart';

// Dans votre code, quand vous voulez ajuster le capital:
showDialog(
  context: context,
  builder: (context) => CapitalAdjustmentDialogWithTracking(
    shop: selectedShop,
  ),
);
```

**C'est tout!** Le dialogue gère:
- ✅ Validation des données
- ✅ Enregistrement dans `audit_log`
- ✅ Mise à jour du shop
- ✅ Synchronisation
- ✅ Notification de succès

---

### 2️⃣ **Voir l'Historique des Ajustements**

```dart
import '../widgets/reports/capital_adjustments_history.dart';

// Pour un shop spécifique:
CapitalAdjustmentsHistory(shop: selectedShop)

// Pour tous les shops:
CapitalAdjustmentsHistory()
```

---

### 3️⃣ **Requête SQL Simple**

```sql
-- Voir tous les ajustements
SELECT * FROM audit_log 
WHERE table_name = 'shops' 
  AND action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
ORDER BY created_at DESC;
```

---

## 📸 Captures d'Écran du Flux

### **Étape 1: Bouton d'Ajustement**
```
┌─────────────────────────────────────────┐
│  Shop Centre Butembo          [...]     │
│  ─────────────────────────────────────  │
│  Capital actuel: 10,000 USD             │
│  Cash: 5,000  |  Airtel: 2,000          │
│  M-Pesa: 2,000  |  Orange: 1,000        │
│                                          │
│  [Ajuster le Capital] [Voir Historique] │
└─────────────────────────────────────────┘
```

### **Étape 2: Dialogue d'Ajustement**
```
┌─────────────────────────────────────────────┐
│  💰 Ajuster le Capital                      │
├─────────────────────────────────────────────┤
│  🏪 Shop Centre Butembo                     │
│  Capital actuel total: 10,000 USD           │
│  ─────────────────────────────────────────  │
│  Cash: 5,000 | Airtel: 2,000 | M-Pesa...  │
│                                              │
│  Type d'ajustement *                        │
│  ┌────────────────────────────────────┐    │
│  │ ⬆️ Augmentation du capital         │◄   │
│  └────────────────────────────────────┘    │
│                                              │
│  Mode de paiement *                         │
│  ┌────────────────────────────────────┐    │
│  │ 💵 Cash                            │◄   │
│  └────────────────────────────────────┘    │
│                                              │
│  Montant (USD) *                            │
│  ┌────────────────────────────────────┐    │
│  │ 5000.00                            │    │
│  └────────────────────────────────────┘    │
│                                              │
│  Raison *                                   │
│  ┌────────────────────────────────────┐    │
│  │ Injection capital supplémentaire   │    │
│  │ pour augmenter liquidité           │    │
│  └────────────────────────────────────┘    │
│                                              │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │
│  ┃ ℹ️ Aperçu de l'ajustement          ┃    │
│  ┃                                     ┃    │
│  ┃ Capital actuel:    10,000 USD       ┃    │
│  ┃ Ajustement:        +5,000 USD       ┃    │
│  ┃ ─────────────────────────────────   ┃    │
│  ┃ Nouveau capital:   15,000 USD       ┃    │
│  ┃ Nouveau Cash:      10,000 USD       ┃    │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │
│                                              │
│     [Annuler]  [Confirmer l'ajustement]    │
└─────────────────────────────────────────────┘
```

### **Étape 3: Confirmation**
```
┌─────────────────────────────────────────────┐
│  ✅ Ajustement de capital enregistré!       │
│  Capital: 10,000 → 15,000 USD               │
│  Audit ID: 123                              │
└─────────────────────────────────────────────┘
```

### **Étape 4: Historique**
```
┌─────────────────────────────────────────────┐
│  🕒 Historique des Ajustements de Capital   │
│  Shop Centre Butembo         [📅] [🔄]      │
├─────────────────────────────────────────────┤
│                                              │
│  ⬆️ Augmentation      +5,000 USD            │
│  🏪 Shop Centre Butembo                     │
│  👤 admin  |  ⏰ 11/12/2025 12:00           │
│                                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ℹ️ Raison:                                 │
│  Injection capital supplémentaire pour      │
│  augmenter liquidité                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                              │
│  Avant: 10,000 USD  →  Après: 15,000 USD   │
│  Mode: Cash                                 │
│  🔖 Audit ID: 123                           │
│                                              │
├─────────────────────────────────────────────┤
│                                              │
│  ⬇️ Diminution       -1,000 USD             │
│  🏪 Shop Centre Butembo                     │
│  👤 admin  |  ⏰ 10/12/2025 14:30           │
│  ...                                         │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 🎯 **Cas d'Usage Courants**

### **Cas 1: Augmentation de Capital (Injection de Fonds)**
```dart
// Scénario: L'investisseur injecte 50,000 USD en cash
// Action: Ouvrir le dialogue, sélectionner:
//   - Type: Augmentation
//   - Mode: Cash
//   - Montant: 50000
//   - Raison: "Injection capital investisseur - Ref: INV-2025-001"
```

### **Cas 2: Diminution de Capital (Retrait d'Investissement)**
```dart
// Scénario: Retrait partiel de 20,000 USD
// Action: Ouvrir le dialogue, sélectionner:
//   - Type: Diminution
//   - Mode: M-Pesa (si le retrait se fait via mobile money)
//   - Montant: 20000
//   - Raison: "Retrait partiel investissement - Décision AG du 10/12/2025"
```

### **Cas 3: Correction d'Erreur**
```dart
// Scénario: Erreur de saisie initiale détectée (capital trop élevé de 5000)
// Action: Ouvrir le dialogue, sélectionner:
//   - Type: Diminution
//   - Mode: Cash
//   - Montant: 5000
//   - Raison: "Correction erreur saisie initiale - Capital surévalué"
//   - Description: "Erreur détectée lors de l'inventaire physique"
```

### **Cas 4: Ajustement Après Inventaire**
```dart
// Scénario: Inventaire physique révèle 3000 USD de plus que prévu
// Action: Ouvrir le dialogue, sélectionner:
//   - Type: Augmentation
//   - Mode: Cash
//   - Montant: 3000
//   - Raison: "Ajustement post-inventaire physique du 11/12/2025"
//   - Description: "Écart positif découvert lors du comptage physique"
```

---

## 📊 **Requêtes SQL Pratiques**

### **Ajustements du jour**
```sql
SELECT 
    al.created_at AS date_heure,
    s.designation AS shop,
    al.action AS type,
    JSON_EXTRACT(al.changed_fields, '$.amount') AS montant,
    al.username AS admin,
    al.reason AS raison
FROM audit_log al
JOIN shops s ON al.record_id = s.id
WHERE al.table_name = 'shops'
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
  AND DATE(al.created_at) = CURDATE()
ORDER BY al.created_at DESC;
```

### **Top 10 plus gros ajustements**
```sql
SELECT 
    s.designation AS shop,
    al.action AS type,
    JSON_EXTRACT(al.changed_fields, '$.amount') AS montant,
    al.reason AS raison,
    al.created_at
FROM audit_log al
JOIN shops s ON al.record_id = s.id
WHERE al.table_name = 'shops'
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
ORDER BY JSON_EXTRACT(al.changed_fields, '$.amount') DESC
LIMIT 10;
```

### **Activité par admin**
```sql
SELECT 
    al.username,
    COUNT(*) AS nb_ajustements,
    SUM(CASE WHEN al.action = 'CAPITAL_INCREASE' THEN 1 ELSE 0 END) AS augmentations,
    SUM(CASE WHEN al.action = 'CAPITAL_DECREASE' THEN 1 ELSE 0 END) AS diminutions,
    SUM(JSON_EXTRACT(al.changed_fields, '$.amount')) AS total_montant
FROM audit_log al
WHERE al.table_name = 'shops'
  AND al.action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
GROUP BY al.username
ORDER BY nb_ajustements DESC;
```

---

## ✅ **Checklist Avant Production**

- [ ] Table `audit_log` existe et est accessible
- [ ] API `/api/audit/log_capital_adjustment.php` fonctionne (test avec cURL)
- [ ] API `/api/audit/get_capital_adjustments.php` fonctionne
- [ ] Service `CapitalAdjustmentService` est importé dans l'app
- [ ] Widget est intégré dans le dashboard admin
- [ ] Permissions admin configurées (seuls les admins peuvent ajuster)
- [ ] Tests effectués avec augmentation ET diminution
- [ ] Vérification que l'historique s'affiche correctement
- [ ] Vérification que les données sont dans `audit_log`

---

## 🐛 **Dépannage**

### Problème: "Utilisateur non connecté"
**Solution**: Vérifier que `AuthService.currentUser` n'est pas null

### Problème: L'historique est vide
**Solution**: 
1. Vérifier la requête SQL directement dans la base
2. Vérifier les filtres (shop_id, dates)
3. S'assurer que des ajustements ont été créés

### Problème: Erreur HTTP 500
**Solution**:
1. Vérifier les logs PHP (`server/error_log`)
2. Tester l'API avec cURL
3. Vérifier la connexion à la base de données

### Problème: Les modifications ne sont pas sauvegardées
**Solution**:
1. Vérifier que la table `shops` est bien mise à jour
2. Vérifier que `audit_log` contient l'entrée
3. Rafraîchir le cache des shops: `ShopService.loadShops(forceRefresh: true)`

---

## 📞 **Support**

Pour toute question ou problème, consultez:
- 📖 Documentation complète: `CAPITAL_ADJUSTMENT_TRACEABILITY.md`
- 💻 Exemples d'intégration: `lib/pages/capital_adjustment_example.dart`
- 🧪 Script de test: `server/test_capital_adjustment.php`

---

**Date:** 2025-12-11  
**Version:** 1.0.0  
**Statut:** ✅ Production Ready
