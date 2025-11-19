# En-têtes Personnalisés des Documents

## Vue d'ensemble

Ce système permet de gérer des en-têtes personnalisés pour tous les documents générés (reçus, PDF, rapports) avec synchronisation automatique entre le serveur MySQL et les clients Flutter via SharedPreferences.

## Architecture

### 1. **Base de données (MySQL)**
- Table: `document_headers`
- Stocke les informations d'en-tête de l'entreprise
- Synchronisé avec tous les clients

### 2. **Stockage Local (SharedPreferences)**
- Clé: `document_header_active`
- Cache local pour accès rapide
- Fonctionne hors ligne

### 3. **Service de Synchronisation**
- `DocumentHeaderService`: Gère la sync bidirectionnelle
- Charge d'abord depuis local, puis sync avec serveur
- Sauvegarde locale immédiate, puis envoi au serveur

## Installation

### 1. Créer la table MySQL

Exécutez le script SQL:

```bash
mysql -u root -p ucash_db < database/create_document_headers_table.sql
```

Ou manuellement dans phpMyAdmin/Laragon:

```sql
-- Voir le fichier: database/create_document_headers_table.sql
```

### 2. API Endpoints

Les endpoints suivants sont disponibles:

- **GET** `/api/document-headers/active` - Récupérer l'en-tête actif
- **POST** `/api/document-headers/save` - Sauvegarder/Mettre à jour

## Utilisation

### Dans l'Interface Admin

1. Ouvrir le panneau admin
2. Aller dans **Configuration**
3. La section **"En-tête des Documents"** est en haut
4. Remplir les champs:
   - Nom de l'entreprise (requis)
   - Slogan
   - Adresse
   - Téléphone
   - Email
   - Site Web
   - Numéro Fiscal/TVA
   - Numéro d'Enregistrement
5. Cliquer sur **Sauvegarder**

### Dans le Code

#### Initialiser le service

```dart
final headerService = DocumentHeaderService();
await headerService.initialize();
```

#### Obtenir l'en-tête actuel

```dart
final header = headerService.getHeaderOrDefault();
print(header.companyName); // UCASH
print(header.companySlogan); // Votre partenaire de confiance
```

#### Utilisation dans les PDF

Le `PdfService` utilise automatiquement les en-têtes personnalisés:

```dart
final pdfService = PdfService();
final pdf = await pdfService.generateReceiptPdf(
  operation: operation,
  shop: shop,
  agent: agent,
);
```

L'en-tête sera automatiquement ajouté avec:
- Nom de l'entreprise
- Slogan (si configuré)
- Adresse (si configurée)
- Téléphone (si configuré)
- Email (si configuré)
- Site web (si configuré)

## Synchronisation

### Fonctionnement

1. **Chargement Initial**:
   - Charge depuis SharedPreferences (instantané)
   - Sync avec serveur MySQL (background)

2. **Sauvegarde**:
   - Sauvegarde locale immédiate (UX rapide)
   - Envoi au serveur (background)
   - Marque comme synchronisé après succès

3. **Hors Ligne**:
   - Fonctionne avec les données locales
   - Sync automatique dès reconnexion

### États de Synchronisation

- `isSynced`: true si synchronisé avec serveur
- `isModified`: true si modifié localement mais pas encore sync
- `lastSyncedAt`: Date de dernière synchronisation

## Modèle de Données

```dart
class DocumentHeaderModel {
  final int id;
  final String companyName;           // Requis
  final String? companySlogan;        // Optionnel
  final String? address;              // Optionnel
  final String? phone;                // Optionnel
  final String? email;                // Optionnel
  final String? website;              // Optionnel
  final String? logoPath;             // Optionnel (futur)
  final String? taxNumber;            // Optionnel
  final String? registrationNumber;   // Optionnel
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Champs de synchronisation
  final bool isSynced;
  final bool isModified;
  final DateTime? lastSyncedAt;
}
```

## API Reference

### GET /api/document-headers/active

Récupère l'en-tête actif.

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "company_name": "UCASH",
    "company_slogan": "Votre partenaire de confiance",
    "address": "123 Rue Example, Kinshasa",
    "phone": "+243 XXX XXX XXX",
    "email": "contact@ucash.cd",
    "website": "www.ucash.cd",
    "tax_number": "TVA123456",
    "registration_number": "RC789012",
    "is_active": 1,
    "created_at": "2025-01-01 10:00:00",
    "updated_at": "2025-01-15 14:30:00",
    "is_synced": 1,
    "is_modified": 0,
    "last_synced_at": "2025-01-15 14:30:00"
  },
  "message": "En-tête récupéré avec succès"
}
```

### POST /api/document-headers/save

Sauvegarde ou met à jour l'en-tête.

**Requête:**
```json
{
  "company_name": "UCASH",
  "company_slogan": "Votre partenaire de confiance",
  "address": "123 Rue Example, Kinshasa",
  "phone": "+243 XXX XXX XXX",
  "email": "contact@ucash.cd",
  "website": "www.ucash.cd",
  "tax_number": "TVA123456",
  "registration_number": "RC789012"
}
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "id": 1
  },
  "message": "En-tête mis à jour avec succès"
}
```

## Dépannage

### L'en-tête ne s'affiche pas sur les reçus

1. Vérifier que l'en-tête est configuré dans l'admin
2. Vérifier la synchronisation:
   ```dart
   final header = headerService.currentHeader;
   print('Synced: ${header?.isSynced}');
   ```
3. Forcer une synchronisation:
   ```dart
   await headerService.syncWithServer();
   ```

### Erreur de synchronisation

1. Vérifier que le serveur est accessible
2. Vérifier que la table `document_headers` existe
3. Vérifier les logs:
   - Flutter: Console de debug
   - Serveur: Logs PHP/Apache

### Réinitialiser les données

```dart
await headerService.clearCache();
await headerService.loadHeader();
```

## Évolutions Futures

- [ ] Support des logos (upload d'image)
- [ ] Gestion multi-langues
- [ ] Templates d'en-têtes multiples
- [ ] Personnalisation par shop
- [ ] Historique des modifications

## Fichiers Créés

### Flutter
- `lib/models/document_header_model.dart` - Modèle de données
- `lib/services/document_header_service.dart` - Service de gestion
- `lib/widgets/document_header_widget.dart` - Interface admin

### Server
- `server/api/document-headers/active.php` - API GET
- `server/api/document-headers/save.php` - API POST
- `database/create_document_headers_table.sql` - Script SQL

### Modifications
- `lib/services/pdf_service.dart` - Utilisation des en-têtes
- `lib/widgets/config_reports_widget.dart` - Intégration dans config
