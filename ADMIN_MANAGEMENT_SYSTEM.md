# Système de Gestion des Administrateurs

## Vue d'ensemble

Le système UCASH permet désormais de gérer jusqu'à **2 administrateurs maximum**. Un administrateur par défaut temporaire est créé au premier lancement pour permettre la création des administrateurs personnalisés. **Cet admin par défaut est automatiquement supprimé dès qu'un premier administrateur personnalisé est créé.**

### 🔑 Admin Par Défaut Temporaire

- **Username:** `admin`
- **Password:** `admin123`
- **ID:** `0` (ID spécial)
- **Clé de stockage:** `admin_default_temp`
- **Durée de vie:** Jusqu'à la création du 1er admin personnalisé
- **Suppression:** Automatique lors de la prochaine session après création d'un admin

## Fonctionnalités

### 1. **Création d'Administrateurs** (Max 2)
- Interface de création d'administrateur avec formulaire
- Validation du nombre maximum (2 admins)
- Vérification de l'unicité du nom d'utilisateur
- Champs supportés:
  - Nom d'utilisateur (requis, unique)
  - Mot de passe (requis)
  - Nom complet (optionnel)
  - Téléphone (optionnel)

### 2. **Gestion des Administrateurs**
- Liste de tous les administrateurs
- Modification des informations (mot de passe, nom, téléphone)
- Suppression (impossible de supprimer le dernier admin)
- Indication de l'admin principal (ID 1)

### 3. **Stockage Local et Synchronisation**
- Stockage local dans SharedPreferences avec clés `admin_1`, `admin_2`
- Synchronisation bidirectionnelle avec MySQL
- Endpoints API dédiés pour upload/download

## Structure des Fichiers

### Frontend (Flutter)

#### 1. `lib/services/local_db.dart`
**Nouvelles méthodes ajoutées:**

```dart
static const int MAX_ADMINS = 2;

// Gestion des admins
Future<List<UserModel>> getAllAdmins()           // Récupère tous les admins
Future<int> countAdmins()                        // Compte les admins
Future<bool> canCreateAdmin()                    // Vérifie si on peut créer un admin
Future<Map<String, dynamic>> createAdmin(...)    // Crée un admin
Future<UserModel?> getAdminByUsername(String)    // Récupère par username
Future<UserModel?> getAdminById(int)             // Récupère par ID
Future<Map<String, dynamic>> updateAdmin(...)    // Met à jour un admin
Future<Map<String, dynamic>> deleteAdmin(int)    // Supprime un admin
```

**Modifications:**
- `initializeDefaultAdmin()` : Ne crée qu'un admin si aucun n'existe
- `ensureAdminExists()` : Vérifie qu'au moins un admin existe
- `getDefaultAdmin()` : Retourne le premier admin
- `getAgentByCredentials()` : Cherche d'abord dans les admins

#### 2. `lib/widgets/admin_management_widget.dart`
Widget complet de gestion des administrateurs avec:
- Liste des administrateurs avec avatar et détails
- Bouton de création (si < 2 admins)
- Modification et suppression
- Indicateurs visuels (badge "Principal", compteur admins)

#### 3. `lib/pages/dashboard_admin.dart`
**Modifications:**
- Ajout du menu "Administrateurs" (index 4)
- Icône: `Icons.admin_panel_settings`
- Méthode `_buildAdminManagementContent()`

### Backend (PHP)

#### 1. `server/api/sync/admins/download.php`
**Endpoint de téléchargement des admins**

```php
POST /server/api/sync/admins/download.php

// Request
{
  "last_sync_timestamp": "2025-12-05 10:00:00"  // optionnel
}

// Response
{
  "success": true,
  "count": 2,
  "max_admins": 2,
  "admins": [
    {
      "id": 1,
      "username": "admin",
      "password": "admin123",
      "role": "ADMIN",
      "nom": "Administrateur",
      "telephone": "+243...",
      "shop_id": null,
      "is_active": true,
      "created_at": "2025-12-01 10:00:00",
      "updated_at": "2025-12-05 12:00:00"
    }
  ],
  "timestamp": "2025-12-05 14:30:00"
}
```

#### 2. `server/api/sync/admins/upload.php`
**Endpoint d'envoi des admins**

```php
POST /server/api/sync/admins/upload.php

// Request
{
  "user_id": "admin",
  "admins": [
    {
      "username": "admin",
      "password": "admin123",
      "role": "ADMIN",
      "nom": "Admin Principal",
      "telephone": "+243..."
    },
    {
      "username": "admin2",
      "password": "secure123",
      "role": "ADMIN",
      "nom": "Admin Secondaire",
      "telephone": "+243..."
    }
  ]
}

// Response
{
  "success": true,
  "message": "Synchronisation réussie",
  "stats": {
    "created": 1,
    "updated": 1,
    "total": 2,
    "max": 2,
    "errors": 0
  },
  "admins": [...],
  "errors": [],
  "timestamp": "2025-12-05 14:30:00"
}
```

## Base de Données

### Table `users` (MySQL)

```sql
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('ADMIN') NOT NULL DEFAULT 'ADMIN',
    nom VARCHAR(100) NULL,
    prenom VARCHAR(100) NULL,
    email VARCHAR(100) NULL,
    telephone VARCHAR(20) NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_username (username),
    INDEX idx_role (role),
    INDEX idx_active (is_active)
);
```

**Contraintes:**
- Maximum 2 entrées avec `role = 'ADMIN'`
- Username unique
- Automatiquement verrouillé côté API
- Pas de lien avec shop (admins n'ont pas de shop)

## Flux de Travail

### 1. **Initialisation de l'Application**

```
1. App démarre
2. LocalDB.initializeDefaultAdmin()
   - Vérifie si au moins 1 admin personnalisé existe
   - Si non : crée admin temporaire (id=0, key=admin_default_temp)
   - Si oui : ne fait rien (les admins personnalisés existent déjà)
3. LocalDB.ensureAdminExists()
   - Vérifie qu'au moins 1 admin existe (temporaire ou personnalisé)
4. LocalDB.cleanupDefaultAdminOnStartup()
   - Si des admins personnalisés existent : supprime l'admin temporaire
   - Sinon : garde l'admin temporaire pour permettre la connexion
```

### 2. **Création du Premier Admin Personnalisé**

```
1. User se connecte avec admin/admin123 (admin temporaire)
2. User accède à "Gestion des Administrateurs"
3. Interface affiche:
   - ⚠️ "Admin par défaut actif"
   - "Username: admin / Password: admin123"
   - Message : "L'admin par défaut sera automatiquement supprimé
     dès que vous créerez votre premier administrateur personnalisé."
4. User clique "Créer votre 1er Administrateur"
5. Dialog de création s'affiche
6. User remplit le formulaire (username, password, nom, téléphone)
7. LocalDB.createAdmin()
   - Crée le nouvel admin avec ID=1
   - Sauvegarde dans SharedPreferences (admin_1)
   - Appelle _removeDefaultAdminIfNeeded()
     -> Supprime l'admin temporaire (admin_default_temp)
   - Retourne succès
8. Message : "Administrateur créé avec succès"
9. Liste se met à jour : affiche le nouvel admin
10. Au prochain démarrage : cleanupDefaultAdminOnStartup() confirme la suppression
```

### 3. **Création du Deuxième Admin**

```
1. User connecté avec le 1er admin personnalisé
2. User accède à "Gestion des Administrateurs"
3. Interface affiche: 1 admin avec bouton "Créer Admin"
4. User clique "Créer Admin"
5. Vérification: countAdmins() < 2 ? ✓
6. Dialog de création s'affiche
7. User remplit le formulaire
8. LocalDB.createAdmin()
   - Crée l'admin avec ID=2
   - Sauvegarde dans SharedPreferences (admin_2)
   - Appelle _removeDefaultAdminIfNeeded() (déjà supprimé)
   - Retourne succès
9. Interface affiche: 2/2 admins (bouton "Créer" désactivé)
```

### 4. **Suppression d'un Admin**

```
1. User clique "Supprimer" sur un admin
2. Dialog de confirmation
3. Vérification: countAdmins() > 1 ?
4. Si oui: LocalDB.deleteAdmin()
   - Supprime de SharedPreferences
   - Retourne succès/erreur
5. Si non: Erreur "Impossible de supprimer le dernier admin"
```

### 4. **Connexion**

```
1. User entre username/password
2. AuthService.login()
3. LocalDB.getAgentByCredentials()
   - Cherche d'abord dans admins personnalisés (admin_1, admin_2)
   - Si non trouvé : cherche dans admin temporaire (admin_default_temp)
   - Si non trouvé : cherche dans agents
4. Si admin trouvé: authentification réussie
5. Redirection vers dashboard admin
```

## Règles de Gestion

### ✅ **Règles Appliquées**

1. **Maximum 2 administrateurs** - Vérifié à la création
2. **Au moins 1 administrateur** - Impossible de supprimer le dernier
3. **Usernames uniques** - Vérifié à la création
4. **Admin principal protégé** - Username non modifiable (ID=1)
5. **Pas de shop pour admins** - `shop_id` toujours `null`

### 🔐 **Sécurité**

- Mots de passe stockés en clair (à améliorer avec hash en production)
- Validation côté client et serveur
- Transactions MySQL pour garantir l'intégrité
- Rollback automatique en cas d'erreur

## Interface Utilisateur

### Page "Administrateurs"

```
┌─────────────────────────────────────────────────────┐
│ 🔐 Gestion des Administrateurs                     │
│    Maximum 2 administrateurs         [🔄] [+ Créer]│
├─────────────────────────────────────────────────────┤
│                                                      │
│ (A) admin          [Principal]                      │
│     Nom: Administrateur Principal                   │
│     Tél: +243...                                    │
│     Créé le: 01/12/2025                            │
│                                     [✏️ Modifier]   │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│ (A) admin2                                          │
│     Nom: Admin Secondaire                          │
│     Tél: +243...                                    │
│     Créé le: 05/12/2025                            │
│                           [✏️ Modifier] [🗑️ Supprimer]│
│                                                      │
└─────────────────────────────────────────────────────┘

Admins: 2/2 ✅ Quota atteint
```

## Migration depuis l'Ancien Système

L'ancien système générait automatiquement un admin. Le nouveau système:

1. **Détecte** l'ancien admin (clé `admin_default` ou `agent_admin`)
2. **Migre** automatiquement vers `admin_1`
3. **Permet** la création d'un 2ème admin via l'interface

## Tests

### Test 1: Création du 1er Admin
```dart
// Aucun admin existant
final result = await LocalDB.instance.createAdmin(
  username: 'admin',
  password: 'admin123',
);
// ✅ Attendu: success=true, admin créé avec ID=1
```

### Test 2: Création du 2ème Admin
```dart
// 1 admin existant
final result = await LocalDB.instance.createAdmin(
  username: 'admin2',
  password: 'secure123',
);
// ✅ Attendu: success=true, admin créé avec ID=2
```

### Test 3: Tentative de créer un 3ème Admin
```dart
// 2 admins existants
final result = await LocalDB.instance.createAdmin(
  username: 'admin3',
  password: 'test123',
);
// ❌ Attendu: success=false, message="Nombre maximum d'administrateurs atteint (2 max)"
```

### Test 4: Suppression du dernier Admin
```dart
// 1 seul admin existant
final result = await LocalDB.instance.deleteAdmin(1);
// ❌ Attendu: success=false, message="Impossible de supprimer le dernier administrateur"
```

### Test 5: Username en double
```dart
// Admin "admin" existe déjà
final result = await LocalDB.instance.createAdmin(
  username: 'admin',
  password: 'newpass',
);
// ❌ Attendu: success=false, message="Ce nom d'utilisateur existe déjà"
```

## Améliorations Futures

1. **Hachage des mots de passe** - bcrypt/argon2
2. **Logs d'audit** - Tracer toutes les modifications
3. **Permissions granulaires** - Différents niveaux d'admin
4. **Email de notification** - Alertes lors de création/suppression
5. **2FA (Two-Factor Auth)** - Sécurité renforcée
6. **Expiration de session** - Déconnexion automatique

## Dépannage

### Problème: "Aucun administrateur trouvé"
**Solution:** Relancer l'app pour déclencher `initializeDefaultAdmin()`

### Problème: "Impossible de créer un admin"
**Vérifier:**
1. Le nombre d'admins actuels (`countAdmins()`)
2. L'unicité du username
3. Les logs de debug

### Problème: "Erreur de synchronisation"
**Vérifier:**
1. La connexion réseau
2. L'URL du serveur
3. La table `users` dans MySQL
4. Les logs PHP dans `error_log`

## Conclusion

Le système de gestion des administrateurs offre désormais:
- ✅ Contrôle total sur les admins (max 2)
- ✅ Interface intuitive de gestion
- ✅ Synchronisation avec le serveur
- ✅ Sécurité et validation robustes
- ✅ Migration transparente depuis l'ancien système

---
**Date de mise en œuvre:** 5 décembre 2025  
**Version:** 1.0  
**Auteur:** Système UCASH
