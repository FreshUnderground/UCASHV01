# 🗑️ Système de Suppression d'Opérations - Guide Complet

## 📋 Vue d'ensemble

Système de suppression d'opérations avec validation en 2 étapes et corbeille de restauration.

### Workflow complet:
1. **Admin** crée une demande de suppression (avec filtres avancés)
2. **Agent** valide ou refuse la demande
3. Si validée: Opération déplacée vers corbeille + suppression locale et serveur
4. **Restauration** possible depuis la corbeille
5. **Synchronisation automatique** toutes les 2 minutes

---

## 🗄️ Structure de la Base de Données

### Tables créées:

#### 1. `deletion_requests`
Stocke les demandes de suppression créées par l'admin.

```sql
CREATE TABLE deletion_requests (
  id, code_ops, operation_type, montant, devise,
  destinataire, expediteur, client_nom,
  requested_by_admin_id, requested_by_admin_name,
  validated_by_agent_id, validated_by_agent_name,
  statut (en_attente|validee|refusee|annulee),
  ...
)
```

#### 2. `operations_corbeille`
Stocke les opérations supprimées avec possibilité de restauration.

```sql
CREATE TABLE operations_corbeille (
  id, code_ops, [copie complète de l'opération],
  deleted_by_admin_id, deleted_by_admin_name,
  validated_by_agent_id, validated_by_agent_name,
  is_restored, restored_at, restored_by,
  ...
)
```

**Fichier SQL:** `database/create_deletion_tables.sql`

---

## 🔧 Installation

### 1. Créer les tables dans MySQL

```bash
mysql -u root -p ucash_db < database/create_deletion_tables.sql
```

### 2. Démarrer l'auto-sync dans main.dart

```dart
import 'package:ucashv01/services/deletion_service.dart';

void main() async {
  // ... après initialisation de l'app
  
  // Démarrer la synchronisation automatique (toutes les 2 minutes)
  DeletionService.instance.startAutoSync();
  
  runApp(MyApp());
}
```

### 3. Ajouter le provider dans votre app

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => DeletionService.instance),
    // ... autres providers
  ],
  child: MaterialApp(...),
)
```

---

## 📱 Utilisation

### Pour l'Admin: Créer une demande de suppression

```dart
import 'package:ucashv01/widgets/admin_deletion_widget.dart';

// Naviguer vers la page admin
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AdminDeletionPage()),
);
```

**Fonctionnalités:**
- ✅ Filtres avancés (type, destinataire, expéditeur, client, montant)
- ✅ Sélection d'opérations à supprimer
- ✅ Raison de suppression (optionnelle)
- ✅ Création de demande → statut `en_attente`

### Pour l'Agent: Valider les demandes

```dart
import 'package:ucashv01/widgets/agent_deletion_validation_widget.dart';

// Naviguer vers validation agent
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AgentDeletionValidationWidget()),
);
```

**Actions:**
- ✅ Voir les demandes en attente
- ✅ Approuver → Suppression définitive + corbeille
- ✅ Refuser → Demande refusée

### Corbeille: Restaurer les opérations

```dart
import 'package:ucashv01/widgets/trash_bin_widget.dart';

// Naviguer vers la corbeille
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TrashBinWidget()),
);
```

**Fonctionnalités:**
- ✅ Voir toutes les opérations supprimées (non restaurées)
- ✅ Détails complets de l'opération
- ✅ Restauration en 1 clic

---

## 🔄 Synchronisation Automatique

### Timer Auto-Sync (Toutes les 2 minutes)

Le service `DeletionService` inclut un timer automatique:

```dart
// Démarrer
DeletionService.instance.startAutoSync();

// Arrêter
DeletionService.instance.stopAutoSync();

// Statut
bool isActive = DeletionService.instance.isAutoSyncEnabled;
DateTime? lastSync = DeletionService.instance.lastSyncTime;
```

**Ce qui est synchronisé:**
1. Demandes de suppression (upload + download)
2. Corbeille (download)
3. Statuts de validation

---

## 🛠️ API Endpoints

### 1. Upload Deletion Request
```
POST /api/sync/deletion_requests/upload.php
Body: JSON array of deletion requests
```

### 2. Download Deletion Requests
```
GET /api/sync/deletion_requests/download.php
Params: ?last_sync=YYYY-MM-DD&statut=en_attente
```

### 3. Validate/Reject Request
```
POST /api/sync/deletion_requests/validate.php
Body: {
  "code_ops": "...",
  "validated_by_agent_id": 123,
  "validated_by_agent_name": "agent1",
  "action": "approve" | "reject"
}
```

### 4. Download Corbeille
```
GET /api/sync/corbeille/download.php
Params: ?is_restored=0
```

### 5. Restore Operation
```
POST /api/sync/corbeille/restore.php
Body: {
  "code_ops": "...",
  "restored_by": "admin"
}
```

---

## 📊 Modèles de Données

### DeletionRequestModel
```dart
class DeletionRequestModel {
  final String codeOps;
  final String operationType;
  final double montant;
  final String? destinataire, expediteur, clientNom;
  final int requestedByAdminId;
  final String requestedByAdminName;
  final DeletionRequestStatus statut;
  // ... autres champs
}

enum DeletionRequestStatus {
  enAttente, validee, refusee, annulee
}
```

### OperationCorbeilleModel
```dart
class OperationCorbeilleModel {
  final String codeOps;
  final String type;
  // ... copie complète de l'opération
  final String? deletedByAdminName;
  final String? validatedByAgentName;
  final bool isRestored;
  final DateTime? restoredAt;
  // ... autres champs
}
```

---

## 🎯 Workflow Détaillé

### Scénario complet:

1. **Admin** ouvre `AdminDeletionPage`
2. Filtre les opérations (ex: tous les dépôts > 1000 USD)
3. Sélectionne une opération à supprimer
4. Entre la raison: "Erreur de saisie"
5. Crée la demande → `DeletionRequest` créée avec statut `en_attente`
6. **Synchronisation automatique (2 min)** → Upload vers serveur

7. **Agent** ouvre `AgentDeletionValidationWidget`
8. Voit la demande en attente
9. Lit les détails et la raison
10. Approuve la suppression
11. → Opération copiée vers `operations_corbeille`
12. → Opération supprimée de `operations`
13. → Demande mise à jour: statut `validee`
14. **Synchronisation automatique (2 min)** → Upload vers serveur

15. **Admin** (ou autre) ouvre `TrashBinWidget`
16. Voit l'opération supprimée dans la corbeille
17. Décide de restaurer
18. Clique sur "Restaurer"
19. → Opération restaurée dans `operations`
20. → Corbeille mise à jour: `is_restored = true`

---

## ⚙️ Configuration

### Modifier le délai de synchronisation

Dans `deletion_service.dart`, ligne 82:
```dart
// Actuellement: 2 minutes
_autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
  syncAll();
});

// Pour changer à 5 minutes:
_autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
  syncAll();
});
```

---

## 🔒 Sécurité

### Permissions:
- **Admin** : Peut créer des demandes de suppression
- **Agent** : Peut valider ou refuser les demandes
- **Tous** : Peuvent restaurer depuis la corbeille (configurable)

### Traçabilité:
- Chaque suppression enregistre:
  - Qui a demandé (admin)
  - Qui a validé (agent)
  - Quand (dates complètes)
  - Pourquoi (raison)

---

## 🐛 Dépannage

### Les demandes ne se synchronisent pas

```dart
// Vérifier le statut
final service = DeletionService.instance;
print('Auto-sync actif: ${service.isAutoSyncEnabled}');
print('Dernier sync: ${service.lastSyncTime}');

// Forcer une synchronisation
await service.syncAll();
```

### Opération non supprimée après validation

1. Vérifier que l'API PHP est accessible
2. Vérifier les logs serveur
3. Vérifier que `code_ops` est unique et correct
4. Forcer un reload:
   ```dart
   await OperationService.instance.loadOperations();
   ```

### Corbeille vide alors qu'il y a des suppressions

```dart
// Forcer le rechargement
await DeletionService.instance.loadCorbeille();
```

---

## 📁 Fichiers Créés

### Base de données:
- `database/create_deletion_tables.sql`

### Modèles Flutter:
- `lib/models/deletion_request_model.dart`

### Services Flutter:
- `lib/services/deletion_service.dart`

### Widgets Flutter:
- `lib/widgets/admin_deletion_widget.dart` (Admin)
- `lib/widgets/agent_deletion_validation_widget.dart` (Agent)
- `lib/widgets/trash_bin_widget.dart` (Corbeille)

### API PHP:
- `server/api/sync/deletion_requests/upload.php`
- `server/api/sync/deletion_requests/download.php`
- `server/api/sync/deletion_requests/validate.php`
- `server/api/sync/corbeille/download.php`
- `server/api/sync/corbeille/restore.php`

---

## ✅ Checklist d'implémentation

- [x] Tables MySQL créées
- [x] Modèles Flutter créés
- [x] Service de suppression avec auto-sync (2 min)
- [x] API PHP endpoints
- [x] UI Admin (filtres + création demande)
- [x] UI Agent (validation/refus)
- [x] UI Corbeille (restauration)
- [x] Synchronisation automatique
- [ ] Tester le workflow complet
- [ ] Déployer sur le serveur de production

---

## 🚀 Prochaines Étapes

1. Créer les tables dans votre base de données MySQL
2. Intégrer les widgets dans votre app
3. Démarrer l'auto-sync dans `main.dart`
4. Tester le workflow complet
5. Déployer les fichiers PHP sur votre serveur

---

**Système créé le:** 28 novembre 2025  
**Version:** 1.0  
**Auteur:** Qoder AI Assistant
