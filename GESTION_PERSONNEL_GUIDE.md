# 📋 Guide - Gestion du Personnel (Personnel Management System)

## 🎯 Vue d'ensemble

Le système de gestion du personnel permet la gestion complète des employés, salaires, avances, crédits et fiches de paie avec synchronisation serveur.

---

## 📁 Structure des Fichiers

### 1. Base de Données

**Fichier**: `database/create_personnel_management_tables.sql`

**Tables créées**:
- ✅ `personnel` - Informations des employés
- ✅ `salaires` - Paiements de salaires mensuels
- ✅ `avances_personnel` - Avances sur salaire
- ✅ `credits_personnel` - Crédits accordés aux employés
- ✅ `remboursements_credits` - Historique des remboursements
- ✅ `fiches_paie` - Fiches de paie générées

**Vues créées**:
- `v_personnel_actif` - Personnel actif avec soldes
- `v_rapport_salaires_mensuel` - Rapport mensuel des salaires

### 2. Modèles Dart

**Fichiers créés dans** `lib/models/`:

| Fichier | Description |
|---------|-------------|
| `personnel_model.dart` | Modèle des employés |
| `salaire_model.dart` | Modèle des salaires |
| `avance_personnel_model.dart` | Modèle des avances |
| `credit_personnel_model.dart` | Modèle des crédits |
| `fiche_paie_model.dart` | Modèle des fiches de paie |

---

## 🔧 Installation et Configuration

### Étape 1: Créer les tables dans la base de données

```bash
# Sur le serveur MySQL
mysql -u root -p ucash_db < database/create_personnel_management_tables.sql
```

### Étape 2: Vérifier la création des tables

```sql
USE ucash_db;
SHOW TABLES LIKE '%personnel%';
SHOW TABLES LIKE '%salaire%';
SHOW TABLES LIKE '%avance%';
SHOW TABLES LIKE '%credit%';
```

### Étape 3: Tester les données

```sql
-- Vérifier le personnel de test
SELECT * FROM personnel;

-- Vérifier la vue du personnel actif
SELECT * FROM v_personnel_actif;
```

---

## 📊 Structure des Données

### 1. Personnel (Employés)

**Informations personnelles**:
- Matricule unique
- Nom, Prénom, Téléphone, Email
- Date de naissance, Lieu de naissance
- Sexe, État civil, Nombre d'enfants

**Informations professionnelles**:
- Poste, Département
- Shop affecté (optionnel)
- Date d'embauche, Type de contrat (CDI/CDD/Stage)
- Statut (Actif/Suspendu/Congé/Démissionné)

**Informations salariales**:
- Salaire de base
- Primes (Transport, Logement, Fonction, Autres)
- Devise
- Informations bancaires

### 2. Salaires

**Composantes**:
- Salaire de base
- Primes (transport, logement, fonction, autres)
- Heures supplémentaires
- Bonus

**Déductions**:
- Avances déduites
- Crédits déduits
- Impôts
- Cotisation CNSS
- Autres déductions

**Calculs automatiques** (via triggers):
- Salaire brut = Base + Primes + HS + Bonus
- Total déductions = Somme des déductions
- Salaire net = Brut - Déductions

### 3. Avances

- Montant accordé
- Mode de remboursement (Mensuel/Unique/Progressif)
- Nombre de mois pour remboursement
- Suivi du montant remboursé/restant
- Statut (En_Cours/Remboursé/Annulé)

### 4. Crédits

- Montant du crédit
- Taux d'intérêt annuel
- Durée en mois
- Calcul automatique de la mensualité
- Date d'octroi et d'échéance
- Suivi des remboursements (principal + intérêts)
- Statut (En_Cours/Remboursé/En_Retard/Annulé)

---

## 💼 Fonctionnalités Principales

### 1. Gestion du Personnel

```dart
// Exemple: Ajouter un employé
final personnel = PersonnelModel(
  matricule: 'EMP004',
  nom: 'KABAMBA',
  prenom: 'Pierre',
  telephone: '+243999555666',
  email: 'pierre.kabamba@ucash.com',
  poste: 'Agent de Terrain',
  dateEmbauche: DateTime(2024, 12, 1),
  salaireBase: 400.00,
  primeTransport: 50.00,
  primeLogement: 100.00,
  typeContrat: 'CDI',
  statut: 'Actif',
);

// Sauvegarder dans la base locale
await PersonnelService.createPersonnel(personnel);

// Synchroniser avec le serveur
await SyncService.syncPersonnel();
```

### 2. Génération de Salaires Mensuels

```dart
// Générer le salaire d'un employé pour un mois donné
final salaire = await SalaireService.genererSalaireMensuel(
  personnelId: 1,
  mois: 12,
  annee: 2024,
  heuresSupplementaires: 25.00,  // Optionnel
  bonus: 100.00,                  // Optionnel
);

// Le système calcule automatiquement:
// - Les avances à déduire
// - Les crédits à déduire
// - Le salaire brut et net
```

### 3. Gestion des Avances

```dart
// Accorder une avance
final avance = AvancePersonnelModel(
  reference: AvancePersonnelModel.generateReference(),
  personnelId: 1,
  montant: 150.00,
  dateAvance: DateTime.now(),
  modeRemboursement: 'Mensuel',
  nombreMoisRemboursement: 3,  // Remboursement sur 3 mois
  motif: 'Urgence familiale',
);

await AvanceService.createAvance(avance);

// Le système déduira automatiquement 50.00 par mois
// lors de la génération des salaires
```

### 4. Gestion des Crédits

```dart
// Accorder un crédit
final credit = CreditPersonnelModel(
  reference: CreditPersonnelModel.generateReference(),
  personnelId: 1,
  montantCredit: 1000.00,
  tauxInteret: 10.0,  // 10% par an
  dateOctroi: DateTime.now(),
  dateEcheance: DateTime.now().add(Duration(days: 365)),
  dureeMois: 12,
  motif: 'Achat moto',
);

// La mensualité est calculée automatiquement avec intérêts
print(credit.mensualite);  // Ex: 87.92 USD/mois
print(credit.montantTotalARembourser);  // Ex: 1055.00 USD
```

### 5. Génération de Fiches de Paie

```dart
// Générer une fiche de paie PDF
final fichePaie = await FichePaieService.genererFichePaie(
  salaireId: 1,
  personnelId: 1,
);

// Sauvegarder et imprimer
await FichePaieService.savePdf(fichePaie);
await FichePaieService.printFichePaie(fichePaie);
```

---

## 📱 Interface Utilisateur

### Menu Admin - Gestion du Personnel

L'interface sera accessible depuis le tableau de bord admin avec les sections suivantes:

#### 1. **Liste du Personnel**
- Tableau avec tous les employés
- Filtres: Statut, Poste, Département, Shop
- Recherche par nom, matricule, téléphone
- Actions: Ajouter, Modifier, Voir détails, Désactiver

#### 2. **Salaires Mensuels**
- Vue calendrier par mois/année
- Génération automatique des salaires
- Statut: En attente, Payé, Partiel
- Paiement individuel ou groupé

#### 3. **Avances & Crédits**
- Liste des avances en cours
- Liste des crédits en cours et en retard
- Suivi des remboursements
- Historique complet

#### 4. **Rapports**
- **Rapport Mensuel de Paiements**: 
  - Total des salaires par mois
  - Nombre d'employés payés
  - Déductions totales
  - Comparaison mois par mois
  
- **Rapport par Employé**:
  - Historique des salaires
  - Avances et crédits en cours
  - Total payé dans l'année

- **Rapport de Masse Salariale**:
  - Coût total du personnel par mois
  - Répartition par département
  - Évolution sur l'année

---

## 🔄 Synchronisation

### Tables à synchroniser

Toutes les tables incluent les colonnes de synchronisation:
- `last_modified_at`
- `last_modified_by`
- `is_synced`
- `synced_at`

### Endpoints API à créer

1. **Personnel**:
   - `POST /api/sync/personnel/upload.php`
   - `GET /api/sync/personnel/changes.php`

2. **Salaires**:
   - `POST /api/sync/salaires/upload.php`
   - `GET /api/sync/salaires/changes.php`

3. **Avances**:
   - `POST /api/sync/avances/upload.php`
   - `GET /api/sync/avances/changes.php`

4. **Crédits**:
   - `POST /api/sync/credits/upload.php`
   - `GET /api/sync/credits/changes.php`

---

## 📈 Rapports Disponibles

### 1. Rapport Mensuel de Paiements

**Contenu**:
- Période sélectionnée
- Nombre total d'employés
- Salaire brut total
- Déductions totales
- Salaire net total
- Montant payé
- Montant en attente
- Détail par employé

**Format**: PDF, Excel, Impression

### 2. Rapport de Masse Salariale

**Contenu**:
- Évolution mensuelle des coûts
- Répartition par département/shop
- Comparaison année N vs N-1
- Graphiques d'évolution

### 3. Rapport Individuel

**Contenu**:
- Informations de l'employé
- Historique des salaires (12 derniers mois)
- Avances en cours et historique
- Crédits en cours et historique
- Total année en cours

---

## 🛠️ Services à Implémenter

### 1. PersonnelService (`lib/services/personnel_service.dart`)

```dart
class PersonnelService {
  // CRUD Operations
  static Future<PersonnelModel> createPersonnel(PersonnelModel personnel);
  static Future<PersonnelModel> updatePersonnel(PersonnelModel personnel);
  static Future<void> deletePersonnel(int id);
  static Future<PersonnelModel?> getPersonnelById(int id);
  static Future<List<PersonnelModel>> getAllPersonnel();
  static Future<List<PersonnelModel>> getPersonnelActif();
  static Future<List<PersonnelModel>> getPersonnelByShop(int shopId);
  
  // Recherche et filtres
  static Future<List<PersonnelModel>> searchPersonnel(String query);
  static Future<List<PersonnelModel>> filterByStatut(String statut);
  static Future<List<PersonnelModel>> filterByPoste(String poste);
  
  // Statistiques
  static Future<int> countPersonnelActif();
  static Future<double> getMasseSalarialeTotal();
}
```

### 2. SalaireService (`lib/services/salaire_service.dart`)

```dart
class SalaireService {
  // Génération de salaires
  static Future<SalaireModel> genererSalaireMensuel({
    required int personnelId,
    required int mois,
    required int annee,
    double heuresSupplementaires = 0,
    double bonus = 0,
  });
  
  // Paiement
  static Future<void> payerSalaire(int salaireId, double montant);
  static Future<void> payerTousLesSalaires(int mois, int annee);
  
  // Consultation
  static Future<List<SalaireModel>> getSalairesByPersonnel(int personnelId);
  static Future<List<SalaireModel>> getSalairesByPeriode(int mois, int annee);
  static Future<SalaireModel?> getSalaireById(int id);
  
  // Rapports
  static Future<Map<String, dynamic>> getRapportMensuel(int mois, int annee);
  static Future<List<Map<String, dynamic>>> getRapportAnnuel(int annee);
}
```

### 3. AvanceService (`lib/services/avance_service.dart`)

```dart
class AvanceService {
  // CRUD
  static Future<AvancePersonnelModel> createAvance(AvancePersonnelModel avance);
  static Future<AvancePersonnelModel> updateAvance(AvancePersonnelModel avance);
  static Future<void> annulerAvance(int id);
  
  // Remboursement
  static Future<void> enregistrerRemboursement(int avanceId, double montant);
  static Future<List<AvancePersonnelModel>> getAvancesEnCours(int personnelId);
  static Future<double> getTotalAvancesRestantes(int personnelId);
  
  // Déduction automatique lors de la génération du salaire
  static Future<double> calculerDeductionMensuelle(int personnelId, int mois, int annee);
}
```

### 4. CreditService (`lib/services/credit_service.dart`)

```dart
class CreditService {
  // CRUD
  static Future<CreditPersonnelModel> createCredit(CreditPersonnelModel credit);
  static Future<CreditPersonnelModel> updateCredit(CreditPersonnelModel credit);
  static Future<void> annulerCredit(int id);
  
  // Remboursement
  static Future<void> enregistrerRemboursement({
    required int creditId,
    required double montantPrincipal,
    required double montantInteret,
  });
  
  static Future<List<CreditPersonnelModel>> getCreditsEnCours(int personnelId);
  static Future<List<CreditPersonnelModel>> getCreditsEnRetard();
  static Future<double> getTotalCreditsRestants(int personnelId);
  
  // Calculs
  static Future<Map<String, dynamic>> calculerEcheancier(CreditPersonnelModel credit);
}
```

### 5. FichePaieService (`lib/services/fiche_paie_service.dart`)

```dart
class FichePaieService {
  // Génération
  static Future<FichePaieModel> genererFichePaie({
    required int salaireId,
    required int personnelId,
  });
  
  // PDF
  static Future<Uint8List> generatePdf(FichePaieModel fiche, SalaireModel salaire, PersonnelModel personnel);
  static Future<void> savePdf(FichePaieModel fiche);
  static Future<void> printFichePaie(FichePaieModel fiche);
  static Future<void> emailFichePaie(FichePaieModel fiche, String email);
}
```

---

## 📝 Formules de Calcul

### 1. Salaire Net

```
Salaire Brut = Salaire Base + Prime Transport + Prime Logement + 
               Prime Fonction + Autres Primes + Heures Supplémentaires + Bonus

Total Déductions = Avances Déduites + Crédits Déduits + Impôts + 
                   Cotisation CNSS + Autres Déductions

Salaire Net = Salaire Brut - Total Déductions
```

### 2. Mensualité de Crédit (avec intérêt)

```dart
// Formule d'amortissement
final tauxMensuel = tauxAnnuel / 12 / 100;
final mensualite = montant * 
    (tauxMensuel * pow(1 + tauxMensuel, dureeMois)) / 
    (pow(1 + tauxMensuel, dureeMois) - 1);
```

### 3. Déduction Mensuelle d'Avance

```
Mode Mensuel: 
  Déduction = Montant Total / Nombre de Mois

Mode Unique:
  Déduction = Montant Total (déduit en une fois)

Mode Progressif:
  Déduction variable selon planning défini
```

---

## 🔐 Permissions et Sécurité

### Rôles

1. **ADMIN**: Accès complet
   - Gestion du personnel
   - Génération des salaires
   - Accord d'avances et crédits
   - Tous les rapports

2. **COMPTABLE**: Accès limité
   - Consultation du personnel
   - Génération des salaires
   - Rapports financiers

3. **AGENT**: Consultation uniquement
   - Voir sa propre fiche
   - Voir ses propres salaires
   - Voir ses avances et crédits

---

## 🎨 UI/UX Design Guidelines

### Couleurs

- **Personnel actif**: Vert (#4CAF50)
- **En attente**: Orange (#FF9800)
- **Payé**: Bleu (#2196F3)
- **En retard**: Rouge (#F44336)
- **Désactivé**: Gris (#9E9E9E)

### Icônes

- Personnel: `Icons.people`
- Salaire: `Icons.attach_money`
- Avance: `Icons.fast_forward`
- Crédit: `Icons.credit_card`
- Fiche de paie: `Icons.description`
- Rapport: `Icons.assessment`

---

## 📊 Exemple de Rapport Mensuel

```
═══════════════════════════════════════════════
          RAPPORT MENSUEL DES PAIEMENTS
        Décembre 2024 (12/2024)
═══════════════════════════════════════════════

📊 RÉSUMÉ FINANCIER
─────────────────────────────────────────────
Nombre d'employés payés:           15
Salaire brut total:         7,500.00 USD
Total déductions:           1,200.00 USD
Salaire net total:          6,300.00 USD
Montant payé:               6,000.00 USD
En attente de paiement:       300.00 USD

📋 DÉTAIL PAR EMPLOYÉ
─────────────────────────────────────────────
Matricule  Nom Complet        Brut    Net    Statut
EMP001     MUKENDI Jean      450.00  400.00   Payé
EMP002     KABILA Marie      650.00  600.00   Payé
EMP003     TSHISEKEDI Paul   850.00  750.00   Payé
...

💰 DÉDUCTIONS
─────────────────────────────────────────────
Avances déduites:             450.00 USD
Crédits déduits:              350.00 USD
Impôts:                       250.00 USD
Cotisation CNSS:              150.00 USD
───────────────────────────────────────────
TOTAL DÉDUCTIONS:           1,200.00 USD

═══════════════════════════════════════════════
Généré le: 17/12/2024 à 14:30
Par: ADMIN
═══════════════════════════════════════════════
```

---

## ✅ Checklist d'Implémentation

### Phase 1: Base de données ✅
- [x] Créer les tables SQL
- [x] Créer les triggers
- [x] Créer les vues
- [x] Insérer données de test

### Phase 2: Modèles Dart ✅
- [x] PersonnelModel
- [x] SalaireModel
- [x] AvancePersonnelModel
- [x] CreditPersonnelModel
- [x] FichePaieModel

### Phase 3: Services (À faire)
- [ ] PersonnelService
- [ ] SalaireService
- [ ] AvanceService
- [ ] CreditService
- [ ] FichePaieService

### Phase 4: Interface UI (À faire)
- [ ] Page Gestion du Personnel
- [ ] Page Salaires Mensuels
- [ ] Page Avances & Crédits
- [ ] Page Rapports
- [ ] Widgets réutilisables

### Phase 5: Synchronisation (À faire)
- [ ] API endpoints serveur
- [ ] Logique de sync dans SyncService
- [ ] Tests de synchronisation

### Phase 6: Rapports & PDF (À faire)
- [ ] Génération PDF fiches de paie
- [ ] Rapport mensuel PDF
- [ ] Rapport annuel Excel
- [ ] Envoi par email

### Phase 7: Tests & Validation (À faire)
- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Validation avec données réelles
- [ ] Documentation utilisateur

---

## 🚀 Démarrage Rapide

### 1. Installation de la base de données

```bash
cd c:\laragon1\www\UCASHV01\database
mysql -u root -p ucash_db < create_personnel_management_tables.sql
```

### 2. Vérification

```sql
USE ucash_db;
SELECT * FROM personnel;
SELECT * FROM v_personnel_actif;
```

### 3. Prochaines étapes

1. Implémenter les services Dart
2. Créer l'interface utilisateur
3. Développer les endpoints API
4. Tester la synchronisation
5. Générer les rapports PDF

---

## 📞 Support

Pour toute question ou problème:
- Consulter ce guide
- Vérifier les modèles Dart
- Examiner le schéma SQL
- Tester avec les données de démonstration

---

## 📄 Licence

Système propriétaire UCASH V01
© 2024 - Tous droits réservés
