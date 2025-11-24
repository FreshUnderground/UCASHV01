# Gestion des IDs Négatifs pour les Shops Locaux

## Problème

Lors de la création d'un nouveau shop dans l'application locale, un ID temporaire est généré (timestamp). Lors de la synchronisation avec le serveur, ce shop reçoit un ID différent généré par MySQL AUTO_INCREMENT. Cela cause des problèmes de clés étrangères lors de l'insertion de clôtures de caisse et d'autres entités liées.

## Solution

Utiliser des IDs négatifs pour les shops locaux afin de les distinguer des IDs positifs générés par MySQL.

## Implémentation

### 1. Génération d'IDs Locaux

Dans l'application Flutter, les shops locaux reçoivent des IDs négatifs :

```dart
// Générer un ID unique négatif pour les shops locaux
final shopId = -(DateTime.now().millisecondsSinceEpoch);
```

### 2. API Serveur

Le SyncManager PHP a été modifié pour gérer les IDs négatifs :

1. **Insertion** : Lorsqu'un shop avec un ID négatif est envoyé, le serveur :
   - Vérifie s'il existe déjà un shop avec la même désignation
   - Si oui, utilise l'ID existant
   - Si non, insère avec l'ID négatif spécifié

2. **Mise à jour** : Lorsqu'un shop avec un ID négatif est mis à jour :
   - Vérifie s'il existe un shop avec la même désignation et un ID positif
   - Si oui, utilise cet ID pour la mise à jour
   - Si non, convertit l'ID négatif en ID positif AUTO_INCREMENT

### 3. Configuration MySQL

La table `shops` a été configurée avec `AUTO_INCREMENT = 1000000` pour éviter les conflits avec les IDs négatifs.

## Avantages

1. **Pas d'attente de synchronisation** : Les entités liées peuvent être créées immédiatement
2. **Pas de contraintes de clés étrangères violées** : Les IDs négatifs ne conflitent pas avec les IDs MySQL
3. **Synchronisation transparente** : Le système gère automatiquement la conversion des IDs

## Scripts de Mise à Jour

### update_auto_increment.php

Met à jour la valeur AUTO_INCREMENT de la table shops à 1000000.

### update_negative_ids.php

Vérifie et convertit les shops existants avec des IDs négatifs.

## Workflow

1. **Création locale** :
   - L'utilisateur crée un shop
   - L'application génère un ID négatif
   - Le shop est sauvegardé localement

2. **Synchronisation** :
   - Le shop est envoyé au serveur avec son ID négatif
   - Le serveur vérifie les doublons par désignation
   - Le serveur insère ou met à jour avec l'ID approprié

3. **Utilisation** :
   - Les clôtures de caisse et autres entités liées peuvent être créées immédiatement
   - Elles référencent l'ID négatif local
   - Après synchronisation, elles sont automatiquement mises à jour avec l'ID serveur

## Gestion des Conflits

Si deux utilisateurs créent un shop avec la même désignation :
1. Le premier est synchronisé avec succès
2. Le second est détecté comme doublon lors de la synchronisation
3. Le système utilise l'ID existant pour le second shop
4. Les entités liées sont mises à jour automatiquement

## Maintenance

Pour mettre à jour une base de données existante :
1. Exécuter `update_auto_increment.php`
2. Exécuter `update_negative_ids.php` si nécessaire