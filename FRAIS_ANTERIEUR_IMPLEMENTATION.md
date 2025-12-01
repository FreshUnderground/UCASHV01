# Implémentation du Solde Frais Antérieur

## Objectif
Enregistrer automatiquement le solde FRAIS lors de la clôture journalière pour l'utiliser comme "Frais Antérieur" le jour suivant.

## Formule du Solde Frais
```
Solde Frais = Frais Antérieur + Frais encaissés du jour - Sortie Frais du jour
```

## Modifications Apportées

### 1. Modèles de Données

#### `lib/models/cloture_caisse_model.dart`
- ✅ Ajout du champ `soldeFraisAnterieur` (double)
- ✅ Mise à jour des méthodes `fromJson()`, `toJson()`, et `copyWith()`
- Ce champ enregistre le solde FRAIS actuel au moment de la clôture

#### `lib/models/rapport_cloture_model.dart`
- ✅ Ajout du champ `soldeFraisAnterieur` 
- Ce champ est utilisé pour afficher le solde FRAIS du jour précédent dans le rapport

### 2. Service de Rapport de Clôture

#### `lib/services/rapport_cloture_service.dart`

**Récupération du Solde Antérieur (`_getSoldeAnterieur`)**
- ✅ Modifié pour retourner également `soldeFraisAnterieur` de la clôture précédente
- Si aucune clôture précédente, retourne 0.0

**Génération du Rapport (`genererRapport`)**
- ✅ Récupère `soldeFraisAnterieur` de la clôture du jour précédent
- ✅ Transmet ce solde au modèle `RapportClotureModel`

**Clôture de Journée (`cloturerJournee`)**
- ✅ Récupère le solde FRAIS actuel via `CompteSpecialService`
- ✅ Enregistre ce solde dans `soldeFraisAnterieur` de la clôture créée
- ✅ Log du solde FRAIS enregistré pour traçabilité

### 3. Interface Utilisateur

#### `lib/widgets/rapportcloture.dart`
- ✅ Modification de la section "4️⃣ Compte FRAIS" pour afficher:
  - **Frais Antérieur** : Solde du jour précédent
  - **+ Frais encaissés** : Frais collectés aujourd'hui
  - **Détail par Shop** : Groupement des frais par shop source
  - **- Sortie Frais du jour** : Retraits effectués
  - **= Solde Frais du jour** : Calcul avec la formule complète
  - **Solde FRAIS total (cumulé)** : Solde global du compte

### 4. Base de Données

#### Migration SQL : `database/add_solde_frais_anterieur_to_cloture.sql`
```sql
ALTER TABLE cloture_caisse
ADD COLUMN solde_frais_anterieur DECIMAL(15,2) NOT NULL DEFAULT 0.00 
COMMENT 'Solde du compte FRAIS au moment de la clôture'
AFTER date_cloture;
```

#### Synchronisation Serveur : `server/api/sync/cloture_caisse/upload.php`
- ✅ Mise à jour des requêtes UPDATE et INSERT pour inclure `solde_frais_anterieur`
- ✅ Support de la synchronisation bidirectionnelle

## Flux de Fonctionnement

### Jour J-1 (Clôture)
1. L'agent clôture la journée J-1
2. Le système récupère le solde FRAIS actuel du shop (ex: 150 USD)
3. Ce solde est enregistré dans `cloture_caisse.solde_frais_anterieur` pour J-1

### Jour J (Rapport)
1. L'agent ouvre le rapport de clôture pour le jour J
2. Le système récupère la clôture de J-1
3. Le `soldeFraisAnterieur` (150 USD) est affiché comme "Frais Antérieur"
4. Les frais encaissés du jour J sont calculés (ex: 25 USD)
5. Les sorties frais du jour J sont récupérées (ex: 10 USD)
6. **Solde Frais du jour J = 150 + 25 - 10 = 165 USD**

### Jour J (Clôture)
1. Lors de la clôture du jour J, le système récupère le solde FRAIS actuel (165 USD)
2. Ce solde est enregistré pour servir de "Frais Antérieur" pour J+1

## Avantages

✅ **Automatique** : Plus besoin de saisir manuellement le solde antérieur
✅ **Traçabilité** : Chaque clôture enregistre le solde FRAIS exact
✅ **Précision** : La formule complète est appliquée automatiquement
✅ **Cohérence** : Le solde antérieur correspond toujours à la clôture précédente
✅ **Transparence** : L'affichage montre clairement le calcul étape par étape

## Logs de Débogage

Le système génère des logs détaillés:
```
📋 Solde antérieur trouvé (clôture du 2024-11-30):
   ...
   FRAIS ANTÉRIEUR: 150.00 USD

💰 Solde FRAIS actuel à enregistrer: 165.00 USD

✅ Journée clôturée avec succès pour le 2024-12-01
   ...
   Solde FRAIS enregistré: 165.00 USD
```

## Migration

### Pour les données existantes
Les clôtures existantes auront `solde_frais_anterieur = 0.00` par défaut.
Le système commencera à enregistrer le solde FRAIS à partir de la prochaine clôture.

### Pour synchroniser avec le serveur
1. Exécuter la migration SQL sur le serveur MySQL
2. Les nouvelles clôtures incluront automatiquement le champ
3. La synchronisation bidirectionnelle est supportée

## Tests Recommandés

1. ✅ Créer une clôture et vérifier que `soldeFraisAnterieur` est enregistré
2. ✅ Ouvrir le rapport du jour suivant et vérifier l'affichage du solde antérieur
3. ✅ Vérifier que la formule de calcul est correcte
4. ✅ Tester la synchronisation avec le serveur
5. ✅ Vérifier les logs pour la traçabilité

## Date de Mise en Production
Décembre 2024

## Auteur
Implémenté suite à la demande utilisateur pour automatiser le suivi des frais antérieurs.
