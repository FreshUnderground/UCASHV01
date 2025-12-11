# 🔄 AGENT CRUD - Flow Diagrams

## 📊 Vue d'Ensemble du Système

```mermaid
graph TB
    subgraph "Flutter App (Client)"
        UI[UI Widgets]
        AS[AgentService]
        LDB[LocalDB<br/>SharedPreferences]
        SS[SyncService]
    end
    
    subgraph "Server (PHP + MySQL)"
        API[API Endpoints]
        DB[(MySQL Database)]
    end
    
    UI -->|CRUD Actions| AS
    AS -->|Save/Read| LDB
    AS -->|Trigger Sync| SS
    SS <-->|HTTP| API
    API <-->|SQL| DB
    
    style UI fill:#3b82f6,color:#fff
    style AS fill:#8b5cf6,color:#fff
    style LDB fill:#10b981,color:#fff
    style SS fill:#f59e0b,color:#fff
    style API fill:#ef4444,color:#fff
    style DB fill:#06b6d4,color:#fff
```

---

## ✅ CREATE (Créer un Agent)

### Flow Complet: Admin → Local → Serveur

```mermaid
sequenceDiagram
    participant U as 👤 Admin UI
    participant AS as AgentService
    participant LDB as LocalDB
    participant SS as SyncService
    participant API as Server API
    participant DB as MySQL

    U->>AS: createAgent(username, password, shopId)
    
    AS->>AS: Validate Data
    Note over AS: - Username unique?<br/>- Password >= 6 chars?<br/>- Shop exists?
    
    AS->>LDB: saveAgent(newAgent)
    LDB->>LDB: Generate ID (timestamp)
    LDB->>LDB: Save to SharedPreferences
    LDB-->>AS: Return savedAgent
    
    AS->>AS: Add to cache (_agents)
    AS->>AS: notifyListeners()
    AS-->>U: ✅ Success
    
    Note over U: Agent visible<br/>immédiatement
    
    AS->>SS: _syncInBackground()
    SS->>API: POST /agents/upload.php
    Note over API: JSON payload:<br/>{entities: [agent]}
    
    API->>DB: INSERT INTO agents
    DB-->>API: ID returned
    API->>DB: UPDATE is_synced=1
    API-->>SS: {success:true, uploaded:1}
    
    SS->>LDB: Update sync timestamp
    
    Note over SS,DB: Agent maintenant<br/>sur le serveur
```

**Temps Estimé**: 
- Local: ~10ms
- Sync: ~200ms (background)

---

## 📖 READ (Lire les Agents)

### Flow: Download Serveur → Merge Local

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant AS as AgentService
    participant LDB as LocalDB
    participant SS as SyncService
    participant API as Server API
    participant DB as MySQL

    U->>AS: loadAgents()
    
    alt Cache existe
        AS-->>U: Return cached _agents
        Note over U: Instant (0ms)
    else Pas de cache
        AS->>LDB: getAllAgents()
        LDB->>LDB: Read from SharedPreferences
        LDB-->>AS: List<AgentModel>
        AS->>AS: Cache result
        AS-->>U: ✅ Agents loaded
    end
    
    Note over U: Sync manuelle<br/>ou périodique
    
    U->>SS: syncAgents()
    SS->>LDB: getLastSyncTimestamp()
    LDB-->>SS: 2025-12-10T10:00:00
    
    SS->>API: GET /agents/changes.php?since=...
    
    alt User = ADMIN
        Note over API: Retourne TOUS<br/>les agents
    else User = AGENT
        Note over API: Filtre par<br/>shop_id
    end
    
    API->>DB: SELECT * FROM agents<br/>WHERE last_modified_at > :since
    DB-->>API: New/Updated agents
    API-->>SS: {entities: [...]}
    
    loop Pour chaque agent
        SS->>LDB: saveAgent(agent)
        Note over LDB: Merge ou<br/>Overwrite
    end
    
    SS->>LDB: setLastSyncTimestamp(now)
    SS->>AS: Trigger reload
    AS-->>U: ✅ Sync complete
```

**Filtres selon Rôle**:
- **ADMIN**: Voit tous les agents (tous shops)
- **AGENT**: Voit seulement agents de son shop

---

## 🔄 UPDATE (Modifier un Agent)

### Flow: Edit Local → Sync Serveur

```mermaid
sequenceDiagram
    participant U as 👤 Admin
    participant ED as EditDialog
    participant AS as AgentService
    participant LDB as LocalDB
    participant SS as SyncService
    participant API as Server API
    participant DB as MySQL

    U->>ED: Click Edit Button
    ED->>ED: Load agent data
    ED-->>U: Show Edit Form
    
    U->>ED: Modify fields + Submit
    ED->>ED: Validate form
    
    ED->>AS: updateAgent(modifiedAgent)
    
    AS->>AS: Set lastModifiedAt = now()
    AS->>LDB: updateAgent(agent)
    LDB->>LDB: Overwrite in SharedPreferences
    LDB-->>AS: ✅ Success
    
    AS->>AS: Update cache by index
    AS->>AS: notifyListeners()
    AS-->>ED: ✅ Success
    
    ED-->>U: Show success message
    
    Note over U: Modification visible<br/>immédiatement
    
    AS->>SS: _syncInBackground()
    SS->>API: POST /agents/upload.php
    
    API->>DB: UPDATE agents SET ... WHERE id=:id
    Note over DB: Server fait autorité<br/>(last write wins)
    
    DB-->>API: Rows affected: 1
    API->>DB: UPDATE is_synced=1
    API-->>SS: {success:true, updated:1}
    
    Note over SS,DB: Modification<br/>synchronisée
```

**Champs Modifiables**:
- ✅ username
- ✅ password
- ✅ shopId
- ✅ nom
- ✅ telephone
- ✅ isActive (toggle rapide)

---

## 🗑️ DELETE (Supprimer un Agent)

### Flow: Soft Delete (Recommandé)

```mermaid
sequenceDiagram
    participant U as 👤 Admin
    participant AS as AgentService
    participant LDB as LocalDB
    participant SS as SyncService
    participant API as Server API
    participant DB as MySQL

    U->>AS: deleteAgent(agentId)
    
    AS->>U: Confirm deletion?
    U-->>AS: Yes, delete
    
    alt Soft Delete (Recommandé)
        Note over AS: Préserve intégrité<br/>données historiques
        
        AS->>AS: agent.isActive = false
        AS->>LDB: updateAgent(agent)
        LDB-->>AS: ✅ Updated
        
        AS->>AS: Keep in cache<br/>(filter in UI)
        AS-->>U: ✅ Agent désactivé
        
        AS->>SS: _syncInBackground()
        SS->>API: POST /agents/upload.php
        API->>DB: UPDATE agents<br/>SET is_active=0<br/>WHERE id=:id
        DB-->>API: Success
        
        Note over DB: Agent désactivé<br/>mais préservé
        
    else Hard Delete (Non recommandé)
        Note over AS: ⚠️ Perte données<br/>Risque erreur FK
        
        AS->>LDB: deleteAgent(agentId)
        LDB->>LDB: Remove from SharedPreferences
        LDB-->>AS: ✅ Deleted
        
        AS->>AS: Remove from cache
        AS-->>U: ✅ Agent supprimé
        
        Note over AS: PAS de sync serveur<br/>(locale seulement)
        
        Note over API: ⚠️ Agent reste<br/>sur serveur
    end
```

**⚠️ Important**: 
- Soft delete préserve les relations (operations, clients, etc.)
- Hard delete local seulement (pas propagé au serveur)
- Utiliser `is_active = false` en production

---

## 🔐 FILTRAGE PAR RÔLE

### Admin vs Agent - Accès Différencié

```mermaid
graph TB
    User{User Role?}
    
    User -->|ADMIN| AdminAccess[Accès Complet]
    User -->|AGENT| AgentAccess[Accès Limité]
    
    AdminAccess --> AllShops[Voir TOUS les agents<br/>de TOUS les shops]
    AdminAccess --> CRUD[CREATE/READ/UPDATE/DELETE]
    AdminAccess --> ManageOthers[Gérer autres agents]
    
    AgentAccess --> OwnShop[Voir agents de<br/>SON SHOP uniquement]
    AgentAccess --> ReadOnly[READ ONLY]
    AgentAccess --> NoManage[Pas de gestion]
    
    style User fill:#f59e0b,color:#fff
    style AdminAccess fill:#10b981,color:#fff
    style AgentAccess fill:#ef4444,color:#fff
    style CRUD fill:#3b82f6,color:#fff
    style ReadOnly fill:#94a3b8,color:#fff
```

### Implémentation Filtrage API

```php
// Dans agents/changes.php
if ($userRole !== 'admin' && $shopId) {
    // AGENT: Filtre par shop
    $sql .= " AND a.shop_id = :shop_id";
    $params[':shop_id'] = $shopId;
} else if ($userRole === 'admin') {
    // ADMIN: Pas de filtre
    // Accès à tous les agents
}
```

---

## 🔄 SYNCHRONISATION BIDIRECTIONNELLE

### Upload + Download Flow

```mermaid
graph LR
    subgraph "Local (Flutter)"
        L1[Agent créé/modifié]
        L2[Marqué pour sync]
        L3[SharedPreferences]
    end
    
    subgraph "Sync Service"
        S1{Sync Trigger}
        S2[Upload Local → Server]
        S3[Download Server → Local]
        S4[Merge Data]
    end
    
    subgraph "Server (MySQL)"
        R1[Receive Upload]
        R2[UPDATE/INSERT]
        R3[Mark Synced]
        R4[Return Changes]
    end
    
    L1 --> L2
    L2 --> L3
    
    L3 --> S1
    S1 --> S2
    S2 --> R1
    R1 --> R2
    R2 --> R3
    
    S1 --> S3
    S3 --> R4
    R4 --> S4
    S4 --> L3
    
    style L1 fill:#3b82f6,color:#fff
    style S1 fill:#f59e0b,color:#fff
    style R2 fill:#ef4444,color:#fff
    style S4 fill:#10b981,color:#fff
```

**Stratégie Conflits**: Last Write Wins
- Serveur fait autorité
- Timestamp `last_modified_at` détermine version

---

## 📱 INTERFACES UTILISATEUR

### Create Agent Dialog

```
┌─────────────────────────────────┐
│ ➕ Nouvel Agent                │
├─────────────────────────────────┤
│                                 │
│ 👤 Username: [______________]   │
│    Min 3 caractères, unique     │
│                                 │
│ 🔒 Password: [______________]   │
│    Min 6 caractères             │
│                                 │
│ 🏪 Shop:     [Dropdown ▼    ]   │
│    Sélection obligatoire        │
│                                 │
│ ❌ Erreur: Username existe déjà │
│                                 │
├─────────────────────────────────┤
│         [Annuler]  [Créer ✓]   │
└─────────────────────────────────┘
```

### Agents List (Desktop)

```
╔══════════════════════════════════════════════════════════╗
║  GESTION DES AGENTS                     [🔍 Recherche]  ║
╠══════════════════════════════════════════════════════════╣
║ 👤 Agent | 🏪 Shop | 📞 Contact | 🟢 Statut | Actions   ║
╟──────────┼─────────┼───────────┼──────────┼─────────────╢
║ agent1   │ Shop A  │ +243...   │ ✅ Actif  │ ✏️ 🗑️ 🔄   ║
║ agent2   │ Shop B  │ +243...   │ ❌ Inact. │ ✏️ 🗑️ 🔄   ║
║ admin    │ -       │ -         │ ✅ Actif  │ 👑 ADMIN   ║
╚══════════════════════════════════════════════════════════╝
```

---

## 🎯 Points Clés de Vérification

### ✅ Checklist Complète

**LOCAL (Admin)**:
- [x] CREATE avec validation
- [x] READ avec cache
- [x] UPDATE immédiat
- [x] DELETE avec confirmation
- [x] UI responsive
- [x] Messages d'erreur

**SERVEUR**:
- [x] API upload fonctionnelle
- [x] API download fonctionnelle
- [x] Contraintes DB respectées
- [x] Sync incrémentale
- [x] Gestion erreurs

**AGENT**:
- [x] Vue filtrée par shop
- [x] Pas de CRUD (read-only)
- [x] Interface masquée
- [x] Sync automatique

**SYNC**:
- [x] Bidirectionnelle
- [x] Incrémentale (par date)
- [x] Gestion conflits
- [x] Background non-bloquant
- [x] Logs détaillés

---

## 🚀 Conclusion

Le système CRUD Agent est **opérationnel à 100%** dans tous les contextes:

1. ✅ **Admin Local**: Full CRUD avec UI complète
2. ✅ **Serveur**: API robuste avec sync bidirectionnelle
3. ✅ **Agent**: Vue read-only filtrée par shop

**Performance**: Optimisée (cache, index, sync incrémentale)  
**Fiabilité**: Gestion erreurs + transactions atomiques  
**Sécurité**: Validation + filtrage rôle  
**Maintenabilité**: Code structuré + documentation complète

Pour plus de détails techniques, voir: [`AGENT_CRUD_VERIFICATION.md`](AGENT_CRUD_VERIFICATION.md)
