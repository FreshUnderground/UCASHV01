# Guide d'Initialisation Système - Admin

## Vue d'ensemble

Le widget **Initialisation Système** permet à l'administrateur d'initialiser les soldes et crédits du système sans impact sur le cash disponible. Toutes les opérations d'initialisation sont marquées comme **ADMINISTRATIVES**.

---

## 🎯 Fonctionnalités Disponibles

### 1. 📱 Initialisation des Soldes Virtuels (SIMs)

Permet d'initialiser le solde virtuel d'une carte SIM.

#### Utilisation

1. **Accéder au menu**: Dashboard Admin → **Initialisation** → Onglet **Soldes Virtuels**
2. **Sélectionner la SIM**: Choisir la carte SIM à initialiser
3. **Saisir le montant**:
   - **Positif**: Ajoute au solde virtuel
   - **Négatif**: Déduit du solde virtuel
4. **Choisir la devise**: USD ou CDF
5. **Ajouter des notes** (optionnel)
6. **Cliquer sur "Initialiser Solde Virtuel"**

#### Exemple

```
SIM: 0970123456 - Airtel Money (Shop MOKU)
Montant: 50000 USD
Devise: USD
Notes: Initialisation solde virtuel de départ
```

**Résultat**:
- ✅ Une transaction virtuelle administrative est créée
- ✅ Le solde virtuel de la SIM est ajusté
- ❌ **AUCUN impact sur le cash disponible**

---

### 2. 👥 Initialisation des Comptes Clients

Permet d'initialiser le solde d'un compte client.

#### Utilisation

1. **Accéder au menu**: Dashboard Admin → **Initialisation** → Onglet **Comptes Clients**
2. **Sélectionner le client**: Choisir le client dont le compte doit être initialisé
3. **Sélectionner le shop**: Shop associé à l'initialisation
4. **Saisir le montant**:
   - **Positif**: Nous leur devons (crédit client)
   - **Négatif**: Ils nous doivent (dette client)
5. **Choisir le mode de paiement**: Cash, Airtel Money, MPESA, Orange Money
6. **Ajouter une observation** (optionnel)
7. **Cliquer sur "Initialiser Compte Client"**

#### Exemple 1: Client avec Crédit

```
Client: KABILA Jean - 0971234567
Shop: MOKU (#1)
Montant: 5000 USD (positif)
Mode: Cash
Observation: Solde d'ouverture de compte
```

**Résultat**:
- ✅ Le client a un crédit de 5000 USD
- ✅ Nous devons 5000 USD au client
- ❌ **AUCUN impact sur le cash disponible**

#### Exemple 2: Client avec Dette

```
Client: MUKENDI Marie - 0981234567
Shop: NGANGAZU (#2)
Montant: -2000 USD (négatif)
Mode: Cash
Observation: Dette antérieure
```

**Résultat**:
- ✅ Le client a une dette de 2000 USD
- ✅ Le client nous doit 2000 USD
- ❌ **AUCUN impact sur le cash disponible**

---

### 3. 🏪 Initialisation des Crédits Intershops

Permet d'initialiser les dettes/créances entre deux shops.

#### Utilisation

1. **Accéder au menu**: Dashboard Admin → **Initialisation** → Onglet **Crédits Intershops**
2. **Choisir le type de mouvement**:
   - **Créance**: Le shop source a une créance (on lui doit)
   - **Dette**: Le shop source a une dette (il doit)
3. **Sélectionner le Shop Source**: Premier shop concerné
4. **Sélectionner le Shop Destination**: Second shop concerné
5. **Saisir le montant**: Montant positif uniquement
6. **Ajouter une observation** (optionnel)
7. **Cliquer sur "Initialiser Crédit Intershop"**

#### Exemple 1: MOKU a une Créance sur NGANGAZU

```
Type: Créance
Shop Source: MOKU (#1)
Shop Destination: NGANGAZU (#2)
Montant: 10000 USD
Observation: Dette antérieure - Initialisation
```

**Résultat**:
- ✅ MOKU a une créance de 10000 USD
- ✅ NGANGAZU a une dette de 10000 USD envers MOKU
- ✅ NGANGAZU doit payer 10000 USD à MOKU

#### Exemple 2: MOKU a une Dette envers NGANGAZU

```
Type: Dette
Shop Source: MOKU (#1)
Shop Destination: NGANGAZU (#2)
Montant: 5000 USD
Observation: Dette antérieure
```

**Résultat**:
- ✅ MOKU a une dette de 5000 USD
- ✅ NGANGAZU a une créance de 5000 USD sur MOKU
- ✅ MOKU doit payer 5000 USD à NGANGAZU

---

## ⚠️ Caractéristiques Importantes

### Opérations Administratives

Toutes les opérations d'initialisation sont marquées comme **`is_administrative = true`**:

- ✅ **N'impactent PAS le cash disponible**
- ✅ **N'apparaissent PAS dans les rapports de cash**
- ✅ **Sont exclues des calculs de cash disponible**
- ✅ **Sont tracées dans l'historique avec la mention "ADMINISTRATIVE"**

### Cas d'Usage

#### 1. Migration de Système

Lors de la migration depuis un ancien système:
```
- Initialiser les soldes clients existants
- Initialiser les soldes virtuels des SIMs
- Initialiser les dettes/créances intershops
```

#### 2. Correction de Soldes

Pour corriger des erreurs de solde:
```
- Ajuster un solde client incorrect
- Corriger un solde virtuel erroné
- Rectifier une dette intershop
```

#### 3. Ouverture de Nouveaux Comptes

Pour les clients existants qui ouvrent un compte:
```
- Initialiser avec leur solde réel actuel
- Ne pas impacter le cash disponible du shop
```

---

## 🔍 Traçabilité

### Soldes Virtuels

Les transactions d'initialisation virtuelle:
- Référence: `INIT-VIRT-{timestamp}`
- Statut: `validée`
- `is_administrative`: `true`
- Montant cash: `0.00`

### Comptes Clients

Les opérations d'initialisation client:
- Type: `depot`
- `is_administrative`: `true`
- Observation: Contient "initialisation" ou "ouverture"
- Impact: Solde client modifié, cash inchangé

### Crédits Intershops

Les ajustements intershop:
- Modifie directement `creances` et `dettes` des shops
- `last_modified_by`: `admin_init_intershop`
- Pas d'opération créée, modification directe des shops

---

## 📊 Rapports et Vérifications

### Vérifier les Initialisations

#### Dans le Rapport Clients
```sql
SELECT * FROM operations 
WHERE is_administrative = 1 
AND type = 'depot'
AND (observation LIKE '%initialisation%' OR observation LIKE '%ouverture%')
ORDER BY date_op DESC;
```

#### Dans les Transactions Virtuelles
```sql
SELECT * FROM virtual_transactions
WHERE is_administrative = 1
AND reference LIKE 'INIT-VIRT-%'
ORDER BY date_enregistrement DESC;
```

#### Dans les Shops (Dettes/Créances)
```sql
SELECT 
    id,
    designation,
    dettes,
    creances,
    (creances - dettes) as solde_net
FROM shops
WHERE last_modified_by = 'admin_init_intershop'
ORDER BY id;
```

---

## ✅ Bonnes Pratiques

### 1. Documentation

- Toujours ajouter une observation claire
- Mentionner la raison de l'initialisation
- Dater l'observation si nécessaire

### 2. Validation

- Vérifier les montants avant validation
- Confirmer les shops/clients sélectionnés
- Vérifier le type de mouvement (créance/dette)

### 3. Traçabilité

- Noter les initialisations dans un registre
- Garder une trace externe des raisons
- Faire des captures d'écran si nécessaire

### 4. Synchronisation

- Les initialisations sont automatiquement synchronisées
- Vérifier la synchronisation après chaque initialisation
- S'assurer que tous les appareils reçoivent les mises à jour

---

## 🚨 Attention

### ⚠️ Ces Opérations NE PEUVENT PAS Être Annulées Automatiquement

Les initialisations sont des opérations administratives permanentes. Pour corriger:

1. **Solde Virtuel**: Créer une nouvelle initialisation avec le montant inverse
2. **Compte Client**: Créer une nouvelle initialisation corrective
3. **Crédit Intershop**: Créer un ajustement inverse

### ⚠️ Vérifications Avant Initialisation

- ✅ Confirmer que le montant est correct
- ✅ Vérifier que le client/shop/SIM est correct
- ✅ S'assurer du type de mouvement (créance/dette)
- ✅ Documenter la raison dans les notes

---

## 📱 Accès au Menu

**Chemin**: Dashboard Admin → Menu latéral → **Initialisation**

**Permissions**: Réservé aux administrateurs uniquement

**Icon**: 🔧 (Settings Suggest)

---

## 🔗 Liens Connexes

- **Guide Utilisateur**: [GUIDE_UTILISATEUR.md](./GUIDE_UTILISATEUR.md)
- **Logique Administrative**: [ADMINISTRATIVE_LOGIC_COMPLETE.md](./ADMINISTRATIVE_LOGIC_COMPLETE.md)
- **Gestion des Clients**: [CLIENT_SHOP_INFO_DOCUMENTATION.md](./CLIENT_SHOP_INFO_DOCUMENTATION.md)
- **Dettes Intershop**: [DETTES_INTERSHOP_RAPPORT.md](./DETTES_INTERSHOP_RAPPORT.md)

---

**Date**: Décembre 2024  
**Version**: 1.0  
**Status**: ✅ Opérationnel
