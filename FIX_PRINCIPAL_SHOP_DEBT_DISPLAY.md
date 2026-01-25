# Fix: Principal Shop Not Displaying Debt to Transfer Shop from Normal Shop

## 🐛 Problem Description

**Issue**: The principal shop (e.g., DURBA/BUTEMBO) is NOT displaying the debt it owes to the transfer shop (e.g., KAMPALA) when normal shops initiate transfers to the transfer shop.

### Expected Behavior

When a **Normal Shop** (e.g., Shop C) initiates a transfer to the **Transfer Shop** (Kampala), the system should use **consolidation logic**:

```
┌───────────┐        ┌──────────────┐        ┌──────────┐
│  Shop C   │───────▶│ DURBA        │───────▶│ KAMPALA  │
│ (Normal)  │  100   │ (Principal)  │  100   │(Transfer)│
└───────────┘        └──────────────┘        └──────────┘
```

**Expected debts in DURBA's view:**
1. ✅ **CRÉANCE (Credit)**: Shop C owes 100 USD to DURBA
2. ❌ **DETTE (Debt)**: DURBA owes 100 USD to KAMPALA ← **NOT SHOWING!**

### Current Behavior

The principal shop view shows:
- ✅ Credits from normal shops (working correctly)
- ❌ Debts to transfer shop (NOT showing) ← **This is the problem!**

## 🔍 Root Cause Analysis

The issue is in the report generation logic in [report_service.dart](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/lib/services/report_service.dart).

### Consolidation Logic (Lines 1325-1424)

The consolidation logic exists and is correct at lines 1351-1410:

```dart
} else if (shopId == mainShop.id) {
  // Vue du shop principal: Dettes/créances séparées
  
  // Dette externe: On doit au shop de transfert
  final mouvementExterne = {
    'date': transfert.dateOp,
    'shopSource': mainShop.designation,
    'shopDestination': serviceShop.designation,
    'montant': transfert.montantBrut,
    'commission': transfert.commission,
    'typeMouvement': 'dette_externe',
    'description': 'Dette externe (consolidé) - Nous devons ${transfert.montantBrut.toStringAsFixed(2)} USD à ${serviceShop.designation} (pour ${shopSource.designation})',
    'isCreance': false,
    // ...
  };
  mouvements.add(mouvementExterne);
  totalDettes += transfert.montantBrut;
  
  // Créance interne: Shop normal nous doit
  final mouvementInterne = {
    'date': transfert.dateOp,
    'shopSource': shopSource.designation,
    'shopDestination': mainShop.designation,
    'montant': transfert.montantBrut,
    'typeMouvement': 'creance_interne',
    'description': 'Créance interne (consolidé) - ${shopSource.designation} nous doit ${transfert.montantBrut.toStringAsFixed(2)} USD',
    'isCreance': true,
    // ...
  };
  mouvements.add(mouvementInterne);
  totalCreances += transfert.montantBrut;
}
```

**This logic is CORRECT and should work!**

### Possible Causes

The consolidation might not be triggered due to:

1. **Shop flags not set correctly in database**:
   - `isPrincipal` flag might be `false` or `NULL` for the principal shop
   - `isTransferShop` flag might be `false` or `NULL` for the transfer shop

2. **Fallback logic not working**:
   - The fallback identification by name (lines 1236-1251) might not be matching

3. **Consolidation condition not met** (line 1307-1310):
   ```dart
   bool requiresConsolidation = serviceShop != null &&
       mainShop != null &&
       transfert.shopDestinationId == serviceShop.id &&
       transfert.shopSourceId != mainShop.id;
   ```

## 🔧 Diagnostic Steps Added

### 1. Enhanced Debug Logging

Added more verbose debug output to track:
- Which transfers are being processed
- Which transfers are being skipped
- When consolidation logic is triggered
- What movements are being created

**Changes in [report_service.dart](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/lib/services/report_service.dart)**:

```dart
// Line 1293-1302: Enhanced skip logging
if (shopId != null &&
    transfert.shopSourceId != shopId &&
    transfert.shopDestinationId != shopId &&
    mainShop?.id != shopId) {
  debugPrint(
      '   ⏭️ SKIP: Transfert ne concerne pas le shop $shopId (source=${transfert.shopSourceId}, dest=${transfert.shopDestinationId}, mainShop=${mainShop?.id})');
  continue;
}

debugPrint('   ✅ PROCESSING: Transfert concerne shop $shopId ou mainShop=${mainShop?.id}');

// Line 1357-1360: Enhanced consolidation logging
debugPrint(
    '   ✅ VUE SHOP PRINCIPAL (${mainShop.designation}): Dette externe à ${serviceShop.designation}, créance de ${shopSource.designation}');
debugPrint(
    '   📦 Création de 2 mouvements: (1) DETTE externe ${transfert.montantBrut} USD à ${serviceShop.designation}, (2) CRÉANCE interne ${transfert.montantBrut} USD de ${shopSource.designation}');
```

### 2. Diagnostic Test Script

Created [test_principal_shop_debt.dart](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/bin/test_principal_shop_debt.dart) to:
- List all shops with their flags (`isPrincipal`, `isTransferShop`)
- Identify which shop is principal and which is transfer shop
- Find all transfers that should trigger consolidation
- Generate the debt report for the principal shop
- Verify if the debt to transfer shop appears

**Usage**:
```bash
dart run bin/test_principal_shop_debt.dart
```

## 🎯 Next Steps to Diagnose

1. **Run the diagnostic script**:
   ```bash
   cd c:\Users\DIEU-MERCI\Documents\projet\UCASHV01
   dart run bin/test_principal_shop_debt.dart
   ```

2. **Check the output** for:
   - Are shops correctly flagged as `isPrincipal` and `isTransferShop`?
   - Are consolidation transfers being identified?
   - Is the debt to transfer shop appearing in the report?

3. **Check the Flutter debug console** when viewing the Dettes Intershop report:
   - Look for `🔍 TRANSFERT:` messages
   - Look for `📦 CONSOLIDATION pour` messages
   - Look for `✅ VUE SHOP PRINCIPAL` messages
   - Look for `📦 Création de 2 mouvements` messages

## 🔨 Potential Fixes

### Fix 1: Ensure Shop Flags Are Set

If shops are not properly flagged, update the database:

```sql
-- Identify principal shop (e.g., DURBA/BUTEMBO)
UPDATE shops 
SET is_principal = 1 
WHERE designation LIKE '%BUTEMBO%' OR designation LIKE '%DURBA%';

-- Identify transfer shop (e.g., KAMPALA)
UPDATE shops 
SET is_transfer_shop = 1 
WHERE designation LIKE '%KAMPALA%';
```

### Fix 2: Strengthen Fallback Logic

If the issue persists, we can strengthen the fallback logic to be more robust in identifying shops by name patterns.

### Fix 3: Review Filtering Logic

If the filter at line 1293-1298 is still problematic, we can adjust it to ensure consolidation transfers are always processed for the principal shop view.

## 📊 Testing Checklist

After applying fixes, verify:

- [ ] Principal shop view shows debt to transfer shop
- [ ] Principal shop view shows credits from normal shops
- [ ] Normal shop view shows debt to principal shop (not to transfer shop directly)
- [ ] Transfer shop view shows credit from principal shop (consolidated)
- [ ] Global view shows all relationships correctly

## 📝 Files Modified

1. **[lib/services/report_service.dart](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/lib/services/report_service.dart)**
   - Enhanced debug logging for filtering (lines 1293-1302)
   - Enhanced debug logging for consolidation (lines 1357-1360)

2. **[bin/test_principal_shop_debt.dart](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/bin/test_principal_shop_debt.dart)** (NEW)
   - Diagnostic script to identify the root cause

---

**Date**: 18 January 2026  
**Status**: 🔍 Diagnostic phase  
**Next Action**: Run diagnostic script and analyze output
