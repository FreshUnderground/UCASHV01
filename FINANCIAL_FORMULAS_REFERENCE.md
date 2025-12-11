# 🧮 UCASH Financial Formulas Reference

This document provides a centralized reference for all financial formulas used throughout the UCASH system.

## 📋 Table of Contents
1. [Cash Availability Formula](#cash-availability-formula)
2. [Client Balance Calculation](#client-balance-calculation)
3. [Commission Calculations](#commission-calculations)
4. [Virtual Closure Formulas](#virtual-closure-formulas)
5. [Special Accounts (FRAIS)](#special-accounts-frais)
6. [Inter-Shop Debt Calculations](#inter-shop-debt-calculations)
7. [Capital Calculation](#capital-calculation)

## Cash Availability Formula

### Primary Formula
```
Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + Transfert Reçu) 
                - (Retraits + FLOT Envoyé + Transfert Servi + Retraits FRAIS)
```

### Components Detail
**Entrées (Increase cash):**
- Solde Antérieur: Previous day's closing balance
- Dépôts: Client deposits (OperationType.depot) using montantNet
- FLOT Reçu: FLOTs where shopDestinationId = our shop
- Transfert Reçu: Operations where shopSourceId = our shop (transfertNational, transfertInternationalSortant) using montantBrut

**Sorties (Decrease cash):**
- Retraits: Client withdrawals (OperationType.retrait, OperationType.retraitMobileMoney) using montantNet
- FLOT Envoyé: FLOTs where shopSourceId = our shop
- Transfert Servi: Operations where shopDestinationId = our shop (transfertNational, transfertInternationalEntrant) using montantNet - **ONLY with status `validee` (served operations)**
- Retraits FRAIS: Special account withdrawals (TypeTransactionCompte.RETRAIT)

**⚠️ IMPORTANT**: Transfers with status `enAttente` (pending) are NOT counted in cash movements. Only served transfers (status = `validee`) impact cash flow.

## Client Balance Calculation

### Formula Logic
- **Deposits**: Increase balance by `montantNet`
- **Withdrawals**: Decrease balance by `montantNet`
- **Outgoing transfers**: Decrease balance by `montantBrut` (what customer pays)
- **Incoming international transfers**: Increase balance by `montantNet` (what beneficiary receives)

## Commission Calculations

### Standard Commission Formula
```
commission = montantNet * (taux / 100)
```

### Commission Types
1. **Outgoing transfers**: Applied to montantNet
2. **Incoming international transfers**: 0% commission
3. **Deposits and withdrawals**: 0% commission
4. **FLOT shop-to-shop transfers**: 0% commission

### Shop-to-Shop Commission Hierarchy
1. Route-specific commission: (source_shop_id, destination_shop_id)
2. Source-only commission: (source_shop_id, destination_shop_id=NULL)
3. Global commission: (source_shop_id=NULL, destination_shop_id=NULL)

## Virtual Closure Formulas

### Per-SIM Closure Formula
```
Solde Actuel = Solde Antérieur + Captures - Servies - Retraits - Dépôts
```

### Fee Calculation
Fees are automatically calculated from served transactions:
```
Frais Total = Frais Antérieur + Frais du Jour
```

## Special Accounts (FRAIS)

### Balance Formula
```
Solde FRAIS = Frais Antérieur + Frais encaissés du jour - Sortie Frais du jour
```

### Components
- **Frais encaissés**: Commissions earned from serving transfers
- **Retraits FRAIS**: Withdrawals from the FRAIS account

## Inter-Shop Debt Calculations

### Debt Logic
When Shop A initiates a transfer to Shop B:
- Shop A owes Shop B the gross amount (`montantBrut`)

When Shop A sends a FLOT to Shop B:
- Shop B owes Shop A the amount sent

### Compensation Formula
```
Net Debt = Total Amount Shop A owes Shop B - Total Amount Shop B owes Shop A
```

## Capital Calculation

### Primary Formula
```
Capital Net = Cash Disponible + Créances - Dettes - Frais Retirés
```

### Components
- **Cash Disponible**: Calculated using cash availability formula
- **Créances**: Client negative balances + Inter-shop debts owed to this shop
- **Dettes**: Client positive balances + Inter-shop debts this shop owes
- **Frais Retirés**: Withdrawals from FRAIS account