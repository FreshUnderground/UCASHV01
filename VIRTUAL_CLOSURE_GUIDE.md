# 📱 Virtual Closure Creation Guide

## Overview

The Virtual Closure system in UCASH allows you to close out virtual transactions and SIM card balances at the end of each day. There are **two types** of virtual closures available:

1. **Global Virtual Closure** - Consolidates all virtual activity for the entire shop
2. **Per-SIM Virtual Closure** - Detailed closure for each individual SIM card

---

## 🎯 How to Access Virtual Closures

### For Agents

1. **Login** to the application as an AGENT
2. Navigate to **Virtual Transactions** section (from dashboard)
3. You'll see several tabs at the top:
   - **Transactions** - View all virtual transactions
   - **Retraits (Flots)** - Manage virtual withdrawals
   - **Dépôts Clients** - Client deposits
   - **Clôture** - **Global Virtual Closure** ⭐
   - **Rapport** - Reports with 4 sub-tabs:
     - Vue d'ensemble
     - Par SIM
     - Frais
     - **Clôture par SIM** ⭐ (Detailed per-SIM closure)

---

## 📊 Method 1: Global Virtual Closure

### What It Does
- Consolidates **ALL** virtual transactions for the shop on a specific date
- Calculates totals by operator (Airtel, Vodacom, Orange, etc.)
- Tracks captured, served, pending, and cancelled transactions
- Summarizes withdrawals and SIM balances
- Generates comprehensive daily reports

### Steps to Create

1. **Navigate** to the **"Clôture"** tab
2. **Select Date**: Click "Modifier" to choose the closure date (defaults to today)
3. **Review**: The system will show any existing closures for that date
4. **Create Closure**: Click **"Clôturer la Journée Virtuelle"** button
5. **Confirm**: A dialog will appear asking for confirmation
   - ⚠️ **Warning**: This action is irreversible
   - ✅ Click "Clôturer" to confirm
6. **Success**: You'll see a success message and the closure will appear in the list

### What Gets Calculated

```
📈 TRANSACTIONS
├── Captures (Créations): Count + Total Amount
├── Servies (Validated): Count + Total Amount + Fees + Cash Served
├── En Attente (Pending): Count + Total Amount
└── Annulées (Cancelled): Count + Total Amount

💰 WITHDRAWALS (FLOTS)
├── Total Withdrawals: Count + Amount
├── Reimbursed: Count + Amount
└── Pending: Count + Amount

📱 SIM BALANCES
├── By Operator: {Airtel: $X, Vodacom: $Y, ...}
├── SIM Count: {Airtel: 3, Vodacom: 2, ...}
└── Total SIM Balance: $XXXX

💵 FINANCIAL SUMMARY
├── Total Virtual Available: (Previous Balance + Captures - Withdrawals)
├── Cash Due to Clients: (Total Cash Served)
└── Total Daily Fees: (All fees collected)
```

### When to Use
- ✅ End of business day summary
- ✅ Quick overview of all virtual activity
- ✅ Administrative reporting
- ✅ When you don't need per-SIM details

---

## 🎯 Method 2: Per-SIM Virtual Closure (Detailed)

### What It Does
- Creates **individual closures** for EACH SIM card
- Tracks balances, cash available, and fees per SIM
- Allows manual entry of:
  - **Global Cash** (physical cash in register)
  - **SIM Balances** (virtual balances per SIM)
- **Automatically calculates** fees (no manual entry needed)

### Steps to Create

1. **Navigate** to **"Rapport"** tab → **"Clôture par SIM"** sub-tab
2. **Select Date**: Click "Modifier" to choose the closure date
3. **Review SIMs**: You'll see all active SIM cards with their current balances
4. **Click "Générer la Clôture"**: This starts the generation process
5. **Enter Data** in the dialog that appears:

#### 📝 Data Entry Dialog

##### A. Global Cash (Required)
```
💵 Cash Global (Caisse Physique)
└── Enter total physical cash in the register
    Example: $500.00
    Note: This will be distributed equally among SIMs
```

##### B. Per-SIM Data (Automatic + Manual)
For each SIM card, you'll see:

```
📱 SIM: 0810000001 (Airtel)
├── ✅ AUTOMATIC CALCULATIONS:
│   ├── Solde Antérieur: $150.00 (from previous closure)
│   ├── Frais Antérieur: $50.00 (accumulated fees before today)
│   ├── Frais du Jour: $25.00 (fees collected today)
│   └── Frais Total: $75.00 (= $50 + $25) ⚡ AUTO
│
└── 📝 MANUAL ENTRY FIELDS:
    ├── Solde Actuel: [Pre-filled, editable]
    │   └── Tip: Verify this matches your SIM balance
    └── Notes: [Optional]
        └── Add any comments for this SIM
```

**Important Notes:**
- ⚡ **Fees are AUTOMATIC** - calculated from served transactions
- 📊 Balances are pre-calculated but **can be adjusted** if needed
- 💵 Global cash is **split equally** among all SIMs

6. **Review** the generated closures showing all calculations
7. **Save**: Click **"Sauvegarder"** to save all closures
8. **Done**: You'll see a success message with the count of saved closures

### What Gets Calculated Per SIM

```
📱 PER SIM CLOSURE BREAKDOWN

💰 BALANCES
├── Solde Antérieur: (Balance from previous closure)
├── Solde Actuel: (Current balance - editable)
└── Cash Disponible: (Global cash ÷ Number of SIMs)

💸 FEES (AUTOMATIC)
├── Frais Antérieur: (Accumulated before today)
├── Frais du Jour: (Collected from today's served transactions)
└── Frais Total: (Antérieur + Du Jour) ⚡

📊 TRANSACTIONS TODAY
├── Captures: Count + Amount
├── Servies: Count + Amount + Cash
└── En Attente: Count + Amount

🔄 MOVEMENTS
├── Retraits: Count + Amount
└── Dépôts Clients: Count + Amount

FORMULA:
Solde Actuel = Solde Antérieur + Captures - Servies - Retraits - Dépôts
```

### When to Use
- ✅ Detailed SIM-by-SIM accounting
- ✅ When you need to track cash per SIM
- ✅ Reconciliation of physical vs virtual balances
- ✅ Audit trail for each SIM card
- ✅ When managing multiple operators

---

## ⚙️ Key Features

### Automatic Calculations
- ✅ **Fees**: Automatically summed from served transactions
- ✅ **Previous balances**: Retrieved from last closure
- ✅ **Transaction counts**: Calculated from daily activity
- ✅ **Movements**: Retraits and deposits are tracked

### Manual Entry
- 📝 **Global cash**: Physical cash in register
- 📝 **SIM balances**: Can adjust if needed
- 📝 **Notes**: Add comments per SIM or globally

### Data Persistence
- 💾 Saved to **LocalDB** (offline-first)
- 🔄 Syncs to **MySQL server** automatically
- 📱 Works offline, syncs when online

### Safety Features
- ⚠️ **Confirmation dialogs**: Prevent accidental closures
- 🔒 **Irreversible warning**: User is alerted
- 👮 **Admin only delete**: Only admins can delete closures
- 📅 **Date validation**: Can't close future dates

---

## 📋 Best Practices

### Daily Workflow

1. **Morning**:
   - Review previous day's closures
   - Verify all SIM balances are correct

2. **During Day**:
   - Process virtual transactions normally
   - Track physical cash movements

3. **End of Day**:
   - Count physical cash in register
   - Verify SIM balances on phones
   - Create closure (Global or Per-SIM)
   - Review generated report
   - Save and confirm

### Tips for Accuracy

✅ **Count cash carefully** before entering
✅ **Verify SIM balances** on actual phones
✅ **Check fees** - they should match transaction history
✅ **Add notes** for any discrepancies
✅ **Review** before saving (can't undo!)
✅ **Keep** closure reports for audits

### Troubleshooting

**Problem**: "This virtual day is already closed"
- **Solution**: You've already created a closure for this date. Check the "Historique" or delete the old one (admin only)

**Problem**: "No SIMs found for this shop"
- **Solution**: Ensure SIM cards are properly configured and assigned to your shop

**Problem**: Fees don't match expected
- **Solution**: Fees are calculated from SERVED transactions only. Check your served transaction list.

**Problem**: Balance doesn't match phone
- **Solution**: You can manually adjust the balance in the entry dialog

---

## 🎨 User Interface

### Global Closure UI
```
┌─────────────────────────────────────────┐
│ 📱 Date de clôture virtuelle            │
│ [DD/MM/YYYY]              [Modifier]    │
│                                          │
│ [Clôturer la Journée Virtuelle]        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 📱 DD/MM/YYYY                 [🗑️]      │
│ 👤 cloture_par_username                 │
│                                          │
│ Captures  Servies  Frais                │
│   [12]     [10]    [$50]                │
│                                          │
│ Retraits  En Attente  Solde SIMs       │
│   [3]       [2]        [$500]           │
└─────────────────────────────────────────┘
```

### Per-SIM Closure UI
```
BEFORE GENERATION:
┌─────────────────────────────────────────┐
│ 📱 Clôture Virtuelle par SIM            │
│ 3 SIM(s) actives                        │
├─────────────────────────────────────────┤
│ 📅 Date de clôture: DD/MM/YYYY          │
│                         [Modifier] [🕐] │
├─────────────────────────────────────────┤
│                                          │
│  ┌───────────────────────────────┐     │
│  │ 📱 0810000001                  │     │
│  │ [Airtel]                       │     │
│  │ Solde Actuel: $150.00         │     │
│  │ ├─ Shop: ID 1                 │     │
│  │ ├─ Statut: Actif              │     │
│  │ └─ Type: Virtuel              │     │
│  └───────────────────────────────┘     │
│                                          │
│  [Similar cards for other SIMs...]      │
│                                          │
├─────────────────────────────────────────┤
│         [Générer la Clôture]            │
└─────────────────────────────────────────┘

AFTER GENERATION (Preview before save):
┌─────────────────────────────────────────┐
│  📱 0810000001 (Airtel)                 │
│                                          │
│  💰 Soldes                               │
│  ├─ Solde Antérieur:     $150.00       │
│  ├─ Solde Actuel:        $200.00 ✅     │
│  └─ Cash Disponible:     $166.67        │
│                                          │
│  💸 Frais                                │
│  ├─ Frais Antérieur:     $50.00        │
│  ├─ Frais du Jour:       $25.00        │
│  └─ Frais Total:         $75.00 ⚡      │
│                                          │
│  📊 Transactions du Jour                │
│  ├─ Captures:    5 ($250.00)           │
│  ├─ Servies:     4 ($200.00)           │
│  ├─ Cash Servi:  $180.00               │
│  └─ En Attente:  1 ($50.00)            │
│                                          │
│  🔄 Mouvements                           │
│  ├─ Retraits:    2 ($100.00)           │
│  └─ Dépôts:      1 ($50.00)            │
└─────────────────────────────────────────┘

[Annuler]  [Sauvegarder] ✅
```

---

## 📊 Reports & History

### Viewing History
- Click the **🕐 Historique** button (top-right in Per-SIM view)
- View past closures filtered by:
  - Date range
  - SIM number
  - Shop

### PDF Export (Coming Soon)
The system includes [`ClotureVirtuelleParSimPDFService`](c:\laragon1\www\UCASHV01\lib\services\cloture_virtuelle_pdf_service.dart) for generating PDF reports.

---

## 🔧 Technical Details

### Database Tables
- **Global**: `cloture_virtuelle` (SharedPreferences/LocalDB)
- **Per-SIM**: Uses LocalDB with prefix `cloture_virtuelle_par_sim_`

### Services Used
- [`ClotureVirtuelleService`](c:\laragon1\www\UCASHV01\lib\services\cloture_virtuelle_service.dart) - Global closures
- [`ClotureVirtuelleParSimService`](c:\laragon1\www\UCASHV01\lib\services\cloture_virtuelle_par_sim_service.dart) - Per-SIM closures
- [`LocalDB`](c:\laragon1\www\UCASHV01\lib\services\local_db.dart) - Data persistence

### Models
- [`ClotureVirtuelleModel`](c:\laragon1\www\UCASHV01\lib\models\cloture_virtuelle_model.dart)
- [`ClotureVirtuelleParSimModel`](c:\laragon1\www\UCASHV01\lib\models\cloture_virtuelle_par_sim_model.dart)

---

## ❓ FAQ

**Q: Can I edit a closure after saving?**
A: No, closures are designed to be immutable. Only admins can delete them.

**Q: What if I made a mistake?**
A: Contact your administrator to delete the closure, then recreate it.

**Q: Why are fees automatic?**
A: To prevent errors and ensure consistency with actual transaction data.

**Q: Can I close multiple days at once?**
A: No, each day must be closed separately.

**Q: What happens if I don't close a day?**
A: Nothing critical, but you won't have historical records. You can close past dates.

**Q: Do closures sync to the server?**
A: Yes, they sync automatically when you have internet connection.

---

## 🎓 Quick Start Summary

### For Quick Daily Closure:
1. Go to **Virtual Transactions** → **Clôture** tab
2. Click **"Clôturer la Journée Virtuelle"**
3. Confirm
4. Done! ✅

### For Detailed SIM Accounting:
1. Go to **Virtual Transactions** → **Rapport** → **"Clôture par SIM"**
2. Click **"Générer la Clôture"**
3. Enter **Global Cash** amount
4. Review **auto-calculated** balances and fees
5. Adjust if needed, add notes
6. Click **"Sauvegarder"**
7. Done! ✅

---

## 🆘 Support

If you encounter issues:
1. Check this guide
2. Review error messages
3. Verify data (SIMs exist, transactions are valid)
4. Contact administrator
5. Check logs (debug console)

---

**Last Updated**: December 3, 2025
**Version**: 1.0
**Author**: UCASH Development Team
