# 📱 UCASH - Guide Utilisateur

## Table des Matières
1. [Introduction](#introduction)
2. [Connexion](#connexion)
3. [Tableau de Bord](#tableau-de-bord)
4. [Gestion des Opérations](#gestion-des-opérations)
5. [Gestion des Clients](#gestion-des-clients)
6. [Synchronisation](#synchronisation)
7. [Configuration](#configuration)
8. [Journal de Caisse](#journal-de-caisse)

---

## Introduction

**UCASH** est une application de gestion de transferts d'argent qui permet de :
- Effectuer des transferts nationaux et internationaux
- Gérer les dépôts et retraits clients
- Suivre les opérations en temps réel
- Synchroniser les données entre plusieurs shops
- Consulter le journal de caisse

### Types d'Utilisateurs

#### 🔧 **Agent**
- Créer des opérations (transferts, dépôts, retraits)
- Gérer les clients
- Valider les transferts entrants
- Consulter le journal de caisse
- Changer son mot de passe

#### 👤 **Client**
- Consulter son solde
- Voir l'historique de ses opérations
- Effectuer des virements internes

#### 👨‍💼 **Admin**
- Toutes les fonctions Agent
- Gérer les shops
- Gérer les agents
- Configurer les taux de change
- Configurer les commissions
- Accès aux rapports

---

## Connexion

### Première Connexion

1. **Lancer l'application UCASH**
2. **Saisir vos identifiants :**
   - **Nom d'utilisateur** : Fourni par votre administrateur
   - **Mot de passe** : Mot de passe initial (à changer lors de la première connexion)
3. **Cliquer sur "Se connecter"**

### Compte Admin par Défaut
```
Username: admin
Password: admin123
```
⚠️ **Important** : Changez ce mot de passe dès la première connexion !

### Déconnexion
- Cliquez sur l'icône de profil en haut à droite
- Sélectionnez **"Déconnexion"**

---

## Tableau de Bord

Le tableau de bord affiche :

### 📊 Statistiques du Jour
- **Transferts Nationaux** : Nombre et montant total
- **Transferts Internationaux** : Sortants et entrants
- **Dépôts** : Montant total des dépôts
- **Retraits** : Montant total des retraits
- **Commissions** : Total des commissions gagnées

### 💰 Capital du Shop
- Capital en USD
- Capital en CDF
- Capital en EUR

### 📋 Opérations Récentes
Liste des 10 dernières opérations avec :
- Type d'opération
- Montant
- Client/Destinataire
- Statut
- Date

---

## Gestion des Opérations

### 1️⃣ Transfert National

**Créer un transfert national :**

1. Cliquez sur **"Nouvelle Opération"** → **"Transfert National"**
2. Remplissez le formulaire :
   - **Expéditeur** : Nom complet
   - **Téléphone Expéditeur** : Format international (+243...)
   - **Destinataire** : Nom complet
   - **Téléphone Destinataire** : Format international
   - **Shop Destination** : Choisir le shop qui servira l'argent
   - **Montant** : Montant à envoyer
   - **Devise** : USD, CDF, ou EUR
   - **Mode de Paiement** : Cash, Mobile Money, ou Bancaire
3. Vérifiez la **commission** calculée automatiquement
4. Cliquez sur **"Créer le Transfert"**

**États d'un transfert :**
- 🟡 **EN ATTENTE** : Créé, en attente de validation par le shop destination
- 🟢 **SERVIE** : Argent remis au destinataire
- 🔴 **ANNULÉE** : Transfert annulé

### 2️⃣ Transfert International

#### Transfert Sortant (vers l'étranger)

1. Cliquez sur **"Transfert International Sortant"**
2. Remplissez :
   - Informations expéditeur
   - Informations destinataire
   - **Pays de destination**
   - Shop destination (à l'étranger)
   - Montant et devise
3. Commission calculée automatiquement
4. Cliquez sur **"Créer"**

#### Transfert Entrant (depuis l'étranger)

1. Cliquez sur **"Transfert International Entrant"**
2. Remplissez les informations
3. **Pas de commission** sur les transferts entrants
4. Cliquez sur **"Créer"**

### 3️⃣ Dépôt Client

**Déposer de l'argent sur le compte d'un client :**

1. Cliquez sur **"Dépôt"**
2. Sélectionnez le **client** (ou créez-en un nouveau)
3. Saisissez le **montant**
4. Choisissez la **devise**
5. Choisissez le **mode de paiement**
6. Cliquez sur **"Déposer"**

📌 Le solde du client augmente immédiatement.

### 4️⃣ Retrait Client

**Retirer de l'argent du compte d'un client :**

1. Cliquez sur **"Retrait"**
2. Sélectionnez le **client**
3. Vérifiez son **solde disponible**
4. Saisissez le **montant** à retirer
5. Choisissez la **devise**
6. Choisissez le **mode de paiement**
7. Cliquez sur **"Retirer"**

⚠️ Le retrait échouera si le solde est insuffisant.

### 5️⃣ Valider un Transfert Entrant

**Quand vous recevez un transfert destiné à votre shop :**

1. Allez dans **"Opérations"**
2. Filtrez par **"EN ATTENTE"**
3. Trouvez le transfert
4. Cliquez sur **"Valider"** ou **"Servir"**
5. Choisissez le **mode de paiement** (comment vous remettez l'argent)
6. Confirmez

📌 Le transfert passe à l'état **SERVIE** et votre capital diminue.

---

## Gestion des Clients

### Créer un Nouveau Client

1. Allez dans **"Clients"**
2. Cliquez sur **"Nouveau Client"**
3. Remplissez :
   - **Nom complet**
   - **Téléphone** : Format international (+243...)
   - **Adresse** : Adresse complète
4. Cliquez sur **"Créer"**

### Consulter un Client

1. Cherchez le client dans la liste
2. Cliquez sur sa carte
3. Vous verrez :
   - **Solde actuel** en USD
   - **Historique des opérations**
   - **Statistiques** : Total dépôts, retraits, virements

### Effectuer un Virement Interne (Client → Client)

1. Allez dans **"Clients"**
2. Sélectionnez le client source
3. Cliquez sur **"Virement"**
4. Choisissez le **client destinataire**
5. Saisissez le **montant**
6. Confirmez

📌 Pas de commission sur les virements internes.

---

## Synchronisation

### Pourquoi Synchroniser ?

La synchronisation permet de :
- ✅ Envoyer vos opérations au serveur central
- ✅ Recevoir les opérations des autres shops
- ✅ Mettre à jour les taux de change
- ✅ Partager les données entre tous les shops

### Synchronisation Automatique

L'application se synchronise **automatiquement toutes les 30 secondes** si :
- ✅ Connexion Internet disponible
- ✅ Serveur accessible

### Synchronisation Manuelle

1. Cliquez sur l'icône **"Synchroniser"** (🔄) en haut à droite
2. Attendez que la synchronisation se termine
3. Un message confirme le succès ou affiche les erreurs

### États de Synchronisation

- 🟢 **Synchronisé** : Toutes les données sont à jour
- 🟡 **En attente** : Données non encore envoyées au serveur
- 🔴 **Erreur** : Échec de synchronisation (vérifiez votre connexion)

### Mode Hors Ligne

L'application fonctionne **même sans Internet** :
- Vous pouvez créer des opérations
- Elles seront **mises en file d'attente**
- Elles se synchroniseront **automatiquement** dès le retour de la connexion

---

## Configuration

### Accéder à la Configuration

1. Cliquez sur **"Configuration"** dans le menu

### 🔄 Configuration Synchronisation

**Modifier l'URL de l'API :**

1. Allez dans **"Configuration Synchronisation"**
2. Modifiez l'**URL de l'API** si nécessaire
   - Par défaut : `https://safdal.investee-group.com/server/api`
   - Pour test local : `https://safdal.investee-group.com/server/api`
3. Cliquez sur **"Sauvegarder"**
4. Cliquez sur **"Réinitialiser"** pour revenir à l'URL par défaut

### 🔒 Changer le Mot de Passe

1. Allez dans **"Changer le Mot de Passe"**
2. Saisissez :
   - **Mot de passe actuel**
   - **Nouveau mot de passe** (minimum 4 caractères)
   - **Confirmer le nouveau mot de passe**
3. Cliquez sur **"Modifier le Mot de Passe"**

⚠️ **Important** : Mémorisez bien votre nouveau mot de passe !

### 💱 Taux de Change (Admin uniquement)

1. Allez dans **"Taux de Change"**
2. Cliquez sur **"Nouveau Taux"**
3. Définissez :
   - **Devise** : USD, CDF, EUR
   - **Taux** : Valeur du taux
   - **Type** : ACHAT ou VENTE
4. Cliquez sur **"Créer"**

### 💰 Commissions (Admin uniquement)

1. Allez dans **"Commissions"**
2. Modifiez les taux de commission :
   - **Transferts Sortants** : % sur le montant envoyé
   - **Transferts Entrants** : Généralement 0%
3. Sauvegardez

---

## Journal de Caisse

### Accéder au Journal

1. Allez dans **"Configuration"**
2. Cliquez sur **"Ouvrir le Journal"**

### Que contient le Journal ?

Le journal affiche toutes les **entrées** et **sorties** d'argent :

#### 📥 **ENTRÉE** (Argent qui rentre)
- Dépôt client
- Transfert national créé (client paie)
- Transfert international créé

#### 📤 **SORTIE** (Argent qui sort)
- Retrait client
- Transfert validé/servi (vous remettez l'argent)

### Colonnes du Journal

- **Date/Heure** : Quand l'opération a eu lieu
- **Libellé** : Description de l'opération
- **Type** : ENTRÉE ou SORTIE
- **Montant** : Montant concerné
- **Mode** : Cash, Mobile Money, Bancaire
- **Agent** : Qui a effectué l'opération

### Filtrer le Journal

Vous pouvez filtrer par :
- **Date** : Aujourd'hui, cette semaine, ce mois
- **Type** : Entrées seulement ou Sorties seulement
- **Mode de paiement** : Cash, Mobile Money, Bancaire

---

## Résolution de Problèmes

### ❌ Impossible de se connecter

**Solutions :**
1. Vérifiez votre nom d'utilisateur et mot de passe
2. Vérifiez votre connexion Internet
3. Contactez votre administrateur

### ❌ Erreur de synchronisation

**Solutions :**
1. Vérifiez votre connexion Internet
2. Réessayez manuellement (icône 🔄)
3. Vérifiez l'URL de l'API dans Configuration
4. Contactez le support technique

### ❌ Client non trouvé

**Solution :**
- Le client n'existe peut-être pas encore dans votre shop
- Créez-le d'abord avant d'effectuer l'opération

### ❌ Solde insuffisant (retrait)

**Solution :**
- Vérifiez le solde du client
- Le client doit d'abord déposer de l'argent

### ❌ Capital insuffisant (validation transfert)

**Solution :**
- Votre shop n'a pas assez de capital pour servir le transfert
- Contactez votre gestionnaire pour réapprovisionner

---

## Bonnes Pratiques

### ✅ Sécurité

1. **Ne partagez JAMAIS votre mot de passe**
2. **Déconnectez-vous** après chaque session
3. **Changez votre mot de passe régulièrement**
4. **Vérifiez toujours** les montants avant de valider

### ✅ Opérations

1. **Vérifiez les numéros de téléphone** avant de créer un transfert
2. **Confirmez l'identité du client** avant de servir un transfert
3. **Synchronisez régulièrement** pour voir les transferts entrants
4. **Consultez le journal de caisse** quotidiennement

### ✅ Clients

1. **Enregistrez tous les clients** dans le système
2. **Vérifiez le solde** avant un retrait
3. **Demandez une pièce d'identité** pour les gros montants

---

## Support

### Besoin d'aide ?

**Contactez votre administrateur système :**
- Pour les problèmes de connexion
- Pour réinitialiser votre mot de passe
- Pour les erreurs techniques
- Pour les questions sur les commissions

### Signaler un Bug

Si vous rencontrez un problème technique :
1. Notez le **message d'erreur** exact
2. Notez ce que vous **faisiez** quand l'erreur est apparue
3. Contactez le support avec ces informations

---

## Glossaire

| Terme | Définition |
|-------|------------|
| **Agent** | Employé qui gère les opérations dans un shop |
| **Shop** | Point de vente/bureau de transfert d'argent |
| **Client** | Personne ayant un compte dans le système |
| **Transfert National** | Envoi d'argent vers un autre shop du même pays |
| **Transfert International** | Envoi d'argent vers un shop à l'étranger |
| **Commission** | Frais prélevés sur un transfert |
| **Capital** | Argent disponible dans la caisse du shop |
| **Solde** | Argent disponible sur le compte d'un client |
| **Synchronisation** | Échange de données avec le serveur central |
| **Mode de Paiement** | Comment l'argent est payé/reçu (Cash, Mobile Money, Bancaire) |
| **Journal de Caisse** | Registre de tous les mouvements d'argent |
| **EN ATTENTE** | Transfert créé mais pas encore servi |
| **SERVIE** | Transfert dont l'argent a été remis au destinataire |

---

**Version :** 1.0.0  
**Dernière mise à jour :** Novembre 2025  
**Application :** UCASH - Système de Gestion de Transferts d'Argent
