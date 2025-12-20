# UCASH - Documentation Utilisateur Complète (Français)

## Table des Matières
1. [Introduction](#introduction)
2. [Vue d'Ensemble du Système](#vue-densemble-du-système)
3. [Rôles Utilisateur](#rôles-utilisateur)
4. [Démarrage](#démarrage)
5. [Guide Administrateur](#guide-administrateur)
6. [Guide Agent](#guide-agent)
7. [Guide Client](#guide-client)
8. [Référence des Fonctionnalités](#référence-des-fonctionnalités)
9. [Dépannage](#dépannage)
10. [FAQ](#faq)

---

## Introduction

UCASH est une application complète de transfert d'argent et de gestion financière moderne conçue pour les opérations multi-devises (USD/CDF). Le système prend en charge trois types d'utilisateurs principaux : Administrateurs, Agents et Clients, chacun avec des rôles et permissions spécifiques.

### Fonctionnalités Clés
- **Support multi-devises** (USD/CDF)
- **Synchronisation en temps réel** entre appareils
- **Rapports complets** et analyses
- **Gestion des transactions virtuelles**
- **Système de gestion du personnel**
- **Support multilingue** (Anglais/Français)
- **Capacité hors ligne** avec synchronisation automatique
- **Sécurité avancée** avec contrôle d'accès basé sur les rôles

---

## Vue d'Ensemble du Système

### Architecture
UCASH fonctionne sur une architecture client-serveur avec :
- **Base de données SQLite locale** pour les opérations hors ligne
- **Serveur MySQL** pour le stockage centralisé des données
- **Synchronisation en temps réel** entre bases locales et serveur
- **API RESTful** pour l'échange de données

### Système de Devises
- **Devise Principale** : USD (Dollar Américain)
- **Devise Secondaire** : CDF (Franc Congolais)
- **Opérations Cash** : Toujours en USD
- **Transactions Virtuelles** : Support USD et CDF
- **Conversion Automatique** : Basée sur les taux de change actuels

---

## Rôles Utilisateur

### 1. Administrateur (ADMIN)
**Accès complet au système avec capacités pour :**
- Gérer les shops, agents et clients
- Configurer les taux et commissions
- Accéder à tous les rapports et analyses
- Gérer les paramètres système
- Traiter les suppressions et validations
- Superviser la gestion du personnel
- Surveiller la synchronisation système

### 2. Agent (AGENT)
**Opérations au niveau shop avec accès à :**
- Traiter les transactions (dépôts, retraits, transferts)
- Gérer les transactions virtuelles
- Traiter les validations clients
- Générer les rapports shop
- Gérer le personnel du shop
- Traiter les dettes inter-shop
- Effectuer les clôtures quotidiennes

### 3. Client (CLIENT)
**Accès limité pour la gestion de compte personnel :**
- Voir le solde et l'historique du compte
- Demander des transactions
- Voir les rapports de transactions personnelles
- Mettre à jour les informations personnelles

---

## Démarrage

### Configuration Requise
- **Système d'Exploitation** : Windows, Android, iOS
- **Connexion Internet** : Requise pour la synchronisation
- **Stockage** : Minimum 100MB d'espace libre
- **RAM** : Minimum 2GB recommandé

### Première Connexion
1. **Lancer l'application**
2. **Sélectionner le type d'utilisateur** : Admin, Agent ou Client
3. **Saisir les identifiants** :
   - Admin par défaut : `admin` / `admin123`
   - Identifiants agent fournis par l'administrateur
   - Identifiants client fournis par l'agent
4. **Sélection de langue** : Choisir Anglais ou Français
5. **Synchronisation initiale** se produit automatiquement

---

## Guide Administrateur

### Vue d'Ensemble du Tableau de Bord
Le tableau de bord admin fournit :
- **Statistiques système** et métriques clés
- **Vue d'ensemble des activités récentes**
- **Statut de synchronisation**
- **Accès rapide** aux fonctions principales

### Sections du Menu Principal

#### 1. Tableau de Bord
- Vue d'ensemble et statistiques système
- Résumé des transactions récentes
- Utilisateurs actifs et shops
- Indicateurs de santé système

#### 2. Gestion des Dépenses
- Suivre les dépenses opérationnelles
- Catégoriser les dépenses
- Générer des rapports de dépenses
- Surveillance budgétaire

#### 3. Gestion des Shops
**Créer un Nouveau Shop :**
1. Naviguer vers la section **Shops**
2. Cliquer sur **Ajouter Shop**
3. Remplir les informations requises
4. Sauvegarder et assigner des agents

#### 4. Gestion des Agents
**Ajouter un Nouvel Agent :**
1. Aller à la section **Agents**
2. Cliquer sur **Créer Agent**
3. Saisir les détails de l'agent
4. Générer le matricule automatique
5. Sauvegarder le profil agent

#### 5. VIRTUEL (Transactions Virtuelles)
**Onglet Vue d'Ensemble :**
- Statistiques quotidiennes des transactions virtuelles
- Répartition par devise (USD/CDF)
- Métriques de performance des opérateurs
- Suivi de disponibilité cash

**Onglet En Attente :**
- Voir les transactions virtuelles en attente
- Filtrer par date, montant, devise
- Traiter les validations en lot
- Exporter les transactions en attente

#### 6. Gestion du Personnel
**Gestion des Employés :**
- Ajouter de nouveaux employés
- Gérer les dossiers employés
- Suivre l'historique d'emploi
- Gérer les changements de statut

**Gestion des Salaires :**
- Traiter les salaires mensuels
- Gérer les ajustements salariaux
- Gérer les primes et déductions
- Générer les rapports de paie

---

## Guide Agent

### Vue d'Ensemble du Tableau de Bord
Le tableau de bord agent fournit :
- **Statistiques shop** et métriques de performance
- **Résumé des transactions quotidiennes**
- **Nombre de validations en attente**
- **Boutons d'action rapide**

### Sections du Menu Principal

#### 1. Opérations
**Traitement des Transactions :**
- **Dépôts** : Accepter les dépôts cash des clients
- **Retraits** : Traiter les retraits cash
- **Transferts** : Gérer les transferts d'argent
- **Change de Devise** : Convertir entre USD et CDF

#### 2. Validations
**Transactions en Attente :**
- Réviser les transactions en attente de validation
- Vérifier les détails des transactions
- Approuver ou rejeter les transactions
- Gérer les exceptions de validation

#### 3. Rapports
**Rapports Quotidiens :**
- Résumés des transactions
- Rapports de flux de trésorerie
- Gains de commission
- Rapports d'erreur

#### 4. FLOT (Gestion des Flottants)
**Opérations de Flottant :**
- Gérer le flottant cash du shop
- Demander des transferts de flottant
- Gérer la réconciliation des flottants
- Surveiller les niveaux de flottant

#### 5. VIRTUEL (Transactions Virtuelles)
**Gestion des Transactions Virtuelles :**
- Traiter les transactions mobile money
- Gérer les opérations de comptes virtuels
- Gérer les transactions basées SIM
- Surveiller les soldes virtuels

---

## Guide Client

### Accès au Compte
**Processus de Connexion :**
1. **Sélectionner Connexion Client** depuis l'écran principal
2. **Saisir le Nom d'Utilisateur** : Fourni par votre agent
3. **Saisir le Mot de Passe** : Défini lors de la création du compte
4. **Sélectionner la Langue** : Choisir la langue préférée
5. **Accéder au Tableau de Bord** : Voir la vue d'ensemble du compte

### Services Disponibles

#### 1. Informations du Compte
**Voir les Détails :**
- Informations personnelles
- Détails de contact
- Statut du compte
- Limites du compte

#### 2. Historique des Transactions
**Voir les Transactions :**
- Historique complet des transactions
- Filtrer par plage de dates
- Rechercher par type de transaction
- Exporter les rapports de transaction

---

## Référence des Fonctionnalités

### Système Multi-Devises
**Devises Supportées :**
- **USD (Dollar Américain)** : Devise principale
- **CDF (Franc Congolais)** : Devise secondaire

### Système de Synchronisation
**Synchronisation Automatique :**
- **Temps réel** : Synchronisation immédiate pour les opérations critiques
- **Programmée** : Synchronisation régulière toutes les quelques minutes
- **Manuelle** : Synchronisation initiée par l'utilisateur
- **Résolution de Conflits** : Gestion automatique des conflits de données

---

## Dépannage

### Problèmes Courants

#### Problèmes de Connexion
**Problème** : Impossible de se connecter au système
**Solutions :**
1. **Vérifier les Identifiants** : Vérifier nom d'utilisateur et mot de passe
2. **Vérifier Internet** : Assurer une connexion internet stable
3. **Vider le Cache** : Vider le cache et données de l'application
4. **Contacter le Support** : Si le problème persiste

#### Problèmes de Synchronisation
**Problème** : Les données ne se synchronisent pas correctement
**Solutions :**
1. **Vérifier la Connexion** : Vérifier la connectivité internet
2. **Synchronisation Manuelle** : Forcer la synchronisation manuelle
3. **Redémarrer l'App** : Fermer et redémarrer l'application
4. **Vérifier le Statut Serveur** : Vérifier la disponibilité du serveur

---

## FAQ

### Questions Générales

**Q : Qu'est-ce que UCASH ?**
R : UCASH est une application complète de transfert d'argent et de gestion financière supportant les opérations multi-devises avec synchronisation en temps réel.

**Q : Quelles devises sont supportées ?**
R : UCASH supporte USD (Dollar Américain) et CDF (Franc Congolais) avec capacités de conversion automatique.

**Q : Puis-je utiliser UCASH hors ligne ?**
R : Oui, UCASH a des capacités hors ligne. Les données se synchroniseront automatiquement quand la connexion internet sera restaurée.

---

*Cette documentation est régulièrement mise à jour. Veuillez vérifier la dernière version pour vous assurer d'avoir les informations actuelles.*

**Version du Document :** 1.0  
**Dernière Mise à Jour :** Décembre 2024  
**Langue :** Français
