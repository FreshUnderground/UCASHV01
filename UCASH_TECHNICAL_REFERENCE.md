# UCASH - Technical Reference Documentation

## System Architecture

### Overview
UCASH is built on a hybrid architecture combining local SQLite databases with centralized MySQL server storage, enabling both offline functionality and real-time synchronization.

### Core Components

#### Database Layer
- **Local Storage**: SQLite database for offline operations
- **Server Storage**: MySQL database for centralized data
- **Synchronization Engine**: Bidirectional sync between local and server
- **Conflict Resolution**: Automatic handling of data conflicts

#### Application Layer
- **Flutter Framework**: Cross-platform mobile and desktop application
- **Provider Pattern**: State management using Provider package
- **Service Layer**: Business logic encapsulation
- **Model Layer**: Data models with JSON serialization

#### Server Layer
- **PHP Backend**: RESTful API endpoints
- **MySQL Database**: Centralized data storage
- **Authentication**: Role-based access control
- **File Management**: Document and report storage

---

## Système de Gestion des Dettes Intershops

### Vue d'Ensemble
Le système UCASH implémente un mécanisme sophistiqué de gestion des dettes intershops basé sur une logique bidirectionnelle qui traite tous les flux financiers entre shops pour calculer automatiquement les créances et dettes.

### Composants Principaux
- **Service de Calcul**: `rapport_cloture_service.dart` - Algorithmes de calcul des dettes
- **Modèle de Données**: `rapport_cloture_model.dart` - Structure des données de dettes
- **Interface**: `rapportcloture.dart` - Affichage détaillé des positions inter-shops
- **Règlements Triangulaires**: Système avancé de compensation de dettes circulaires

### Types de Flux Traités
1. **Transferts**: Logique bidirectionnelle (montant brut)
2. **Flots**: Quatre scénarios (en attente/validés, envoyés/reçus)
3. **Opérations Cross-Shop**: Retraits et dépôts inter-shops
4. **Règlements Triangulaires**: Compensation automatique des dettes circulaires

### Calcul de la Situation Nette
```
Capital Net = Cash Disponible + Créances Inter-Shops - Dettes Inter-Shops 
              - Solde Frais - Transferts En Attente + Solde Net Partenaires
```

**Documentation Complète**: Voir `DETTES_INTERSHOPS_DOCUMENTATION.md` pour les détails techniques complets.

---

## Database Schema

### Core Tables

#### Users/Agents
```sql
agents (
  id INTEGER PRIMARY KEY,
  matricule TEXT UNIQUE,
  username TEXT UNIQUE,
  password TEXT,
  role TEXT,
  shop_id INTEGER,
  nom TEXT,
  prenom TEXT,
  telephone TEXT,
  created_at DATETIME
)
```

#### Shops
```sql
shops (
  id INTEGER PRIMARY KEY,
  designation TEXT,
  adresse TEXT,
  telephone TEXT,
  capital_initial REAL,
  created_at DATETIME
)
```

#### Operations
```sql
operations (
  id INTEGER PRIMARY KEY,
  reference TEXT UNIQUE,
  type TEXT,
  montant REAL,
  devise TEXT,
  shop_id INTEGER,
  agent_id INTEGER,
  client_id INTEGER,
  statut TEXT,
  date_creation DATETIME,
  date_validation DATETIME
)
```

#### Virtual Transactions
```sql
virtual_transactions (
  id INTEGER PRIMARY KEY,
  reference TEXT UNIQUE,
  telephone TEXT,
  montant REAL,
  devise TEXT,
  sim_numero TEXT,
  statut TEXT,
  date_enregistrement DATETIME,
  date_validation DATETIME
)
```

#### Personnel Management
```sql
personnel (
  id INTEGER PRIMARY KEY,
  matricule TEXT UNIQUE,
  nom TEXT,
  prenom TEXT,
  poste TEXT,
  salaire_base REAL,
  prime_transport REAL,
  prime_logement REAL,
  statut TEXT,
  date_embauche DATETIME
)
```

---

## API Endpoints

### Authentication
- `POST /api/auth/login` - User authentication
- `POST /api/auth/logout` - User logout
- `GET /api/auth/verify` - Session verification

### Data Synchronization
- `GET /api/sync/download/{table}` - Download table data
- `POST /api/sync/upload/{table}` - Upload table data
- `GET /api/sync/status` - Sync status check

### Operations Management
- `GET /api/operations` - List operations
- `POST /api/operations` - Create operation
- `PUT /api/operations/{id}` - Update operation
- `DELETE /api/operations/{id}` - Delete operation

### Virtual Transactions
- `GET /api/virtual-transactions` - List virtual transactions
- `POST /api/virtual-transactions` - Create virtual transaction
- `PUT /api/virtual-transactions/{id}/validate` - Validate transaction

---

## Service Architecture

### Core Services

#### AuthService
**Purpose**: User authentication and session management
**Key Methods**:
- `login(username, password)` - Authenticate user
- `logout()` - End user session
- `checkSavedSession()` - Restore saved session
- `refreshUserData()` - Update user information

#### SyncService
**Purpose**: Data synchronization between local and server
**Key Methods**:
- `syncAll()` - Synchronize all data
- `downloadTableData(table)` - Download specific table
- `uploadTableData(table)` - Upload specific table
- `resolveConflicts()` - Handle sync conflicts

#### OperationService
**Purpose**: Transaction processing and management
**Key Methods**:
- `createOperation(operation)` - Create new transaction
- `validateOperation(id)` - Validate transaction
- `getOperations(filters)` - Retrieve filtered operations
- `generateReference()` - Generate unique reference

#### VirtualTransactionService
**Purpose**: Virtual transaction management
**Key Methods**:
- `createVirtualTransaction(transaction)` - Create virtual transaction
- `validateVirtualTransaction(id)` - Validate virtual transaction
- `getDailyStats()` - Get daily statistics
- `processSimClosure()` - Process SIM closure

#### PersonnelService
**Purpose**: Employee management
**Key Methods**:
- `createPersonnel(personnel)` - Add new employee
- `generateMatricule()` - Generate employee ID
- `updatePersonnel(personnel)` - Update employee data
- `calculateSalary(personnelId, period)` - Calculate salary

---

## Multi-Currency System

### Currency Rules
- **Primary Currency**: USD (United States Dollar)
- **Secondary Currency**: CDF (Congolese Franc)
- **Cash Operations**: Always processed in USD
- **Virtual Transactions**: Support both USD and CDF

### Currency Service
```dart
class CurrencyService {
  static const String USD = 'USD';
  static const String CDF = 'CDF';
  
  String formatMontant(double amount, String currency) {
    if (currency == CDF) {
      return '${amount.toStringAsFixed(0)} CDF';
    }
    return '${amount.toStringAsFixed(2)} USD';
  }
  
  double convertCurrency(double amount, String from, String to) {
    // Implementation for currency conversion
  }
}
```

### Display Rules
- **Cash Amounts**: Always display as "USD"
- **Virtual Amounts**: Display in original currency
- **Mixed Transactions**: Show currency breakdown
- **Conversion**: Automatic based on current rates

---

## Synchronization System

### Sync Strategy
1. **Real-time Sync**: Critical operations sync immediately
2. **Scheduled Sync**: Regular sync every 2-5 minutes
3. **Manual Sync**: User-initiated synchronization
4. **Conflict Resolution**: Automatic handling with logging

### Sync Process
```dart
class SyncResult {
  bool success;
  String message;
  int recordsProcessed;
  List<String> errors;
}

Future<SyncResult> syncTable(String tableName) async {
  // 1. Get last sync timestamp
  // 2. Download changes from server
  // 3. Apply changes to local database
  // 4. Upload local changes to server
  // 5. Update sync timestamp
  // 6. Handle conflicts if any
}
```

### Conflict Resolution
- **Last Write Wins**: Default strategy for most conflicts
- **Manual Resolution**: Complex conflicts flagged for review
- **Audit Trail**: All conflicts logged for review
- **Rollback Capability**: Ability to revert problematic syncs

---

## Security Implementation

### Authentication
- **Role-based Access**: ADMIN, AGENT, CLIENT roles
- **Session Management**: Secure session handling
- **Password Policies**: Strong password requirements
- **Account Lockout**: Protection against brute force

### Data Protection
- **Encryption**: Sensitive data encrypted at rest
- **Secure Transport**: HTTPS for all API communications
- **Access Logging**: Complete audit trail
- **Data Validation**: Input validation and sanitization

### Permission Matrix
```
Feature               | ADMIN | AGENT | CLIENT
---------------------|-------|-------|--------
Manage Shops         |   ✓   |   ✗   |   ✗
Manage Agents        |   ✓   |   ✗   |   ✗
Process Transactions |   ✓   |   ✓   |   ✗
View Reports         |   ✓   |   ✓   |   ✓
Manage Personnel     |   ✓   |   ✓   |   ✗
System Configuration |   ✓   |   ✗   |   ✗
```

---

## Error Handling

### Error Categories
1. **Network Errors**: Connection issues, timeouts
2. **Validation Errors**: Data validation failures
3. **Business Logic Errors**: Rule violations
4. **System Errors**: Database, file system issues

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid transaction amount",
    "details": {
      "field": "montant",
      "value": "-100",
      "constraint": "must_be_positive"
    }
  }
}
```

### Logging Strategy
- **Error Logging**: All errors logged with context
- **Performance Logging**: Slow operations tracked
- **Audit Logging**: User actions recorded
- **Debug Logging**: Development and troubleshooting

---

## Performance Optimization

### Database Optimization
- **Indexing**: Strategic indexes on frequently queried columns
- **Query Optimization**: Efficient SQL queries
- **Connection Pooling**: Reuse database connections
- **Batch Operations**: Group related operations

### Application Optimization
- **Lazy Loading**: Load data on demand
- **Caching**: Cache frequently accessed data
- **Pagination**: Limit large result sets
- **Background Processing**: Non-blocking operations

### Network Optimization
- **Compression**: Compress API responses
- **Caching**: HTTP caching headers
- **Batch Requests**: Combine multiple requests
- **Connection Reuse**: HTTP connection pooling

---

## Deployment Architecture

### Development Environment
- **Local Database**: SQLite for development
- **Mock Services**: Simulated external services
- **Debug Logging**: Verbose logging enabled
- **Hot Reload**: Flutter hot reload for rapid development

### Production Environment
- **Load Balancer**: Distribute traffic across servers
- **Database Cluster**: MySQL master-slave setup
- **Monitoring**: Application and infrastructure monitoring
- **Backup Strategy**: Regular automated backups

### Deployment Process
1. **Code Review**: Peer review of all changes
2. **Testing**: Automated and manual testing
3. **Staging Deployment**: Deploy to staging environment
4. **Production Deployment**: Controlled production rollout
5. **Monitoring**: Post-deployment monitoring

---

## Integration Points

### External Services
- **SMS Gateway**: Transaction notifications
- **Email Service**: Report delivery
- **Payment Processors**: External payment integration
- **Banking APIs**: Account verification

### File Management
- **Document Storage**: PDF reports and documents
- **Image Handling**: Profile pictures, signatures
- **Backup Files**: Database and configuration backups
- **Log Files**: Application and error logs

---

## Maintenance and Monitoring

### Health Checks
- **Database Connectivity**: Monitor database connections
- **API Endpoints**: Check API response times
- **Sync Status**: Monitor synchronization health
- **Storage Usage**: Track disk space usage

### Performance Metrics
- **Response Times**: API and database response times
- **Transaction Volume**: Daily transaction counts
- **Error Rates**: Error frequency and types
- **User Activity**: Active user statistics

### Backup Strategy
- **Database Backups**: Daily automated backups
- **Configuration Backups**: System configuration snapshots
- **Document Backups**: User documents and reports
- **Recovery Testing**: Regular backup restoration tests

---

## Development Guidelines

### Code Standards
- **Naming Conventions**: Consistent naming patterns
- **Documentation**: Comprehensive code documentation
- **Testing**: Unit and integration tests
- **Version Control**: Git with feature branches

### Architecture Patterns
- **MVVM Pattern**: Model-View-ViewModel separation
- **Repository Pattern**: Data access abstraction
- **Service Layer**: Business logic encapsulation
- **Dependency Injection**: Loose coupling via DI

### Best Practices
- **Error Handling**: Comprehensive error handling
- **Logging**: Structured logging throughout
- **Security**: Security-first development approach
- **Performance**: Performance considerations in design

---

*This technical reference provides comprehensive information about UCASH system architecture, implementation details, and development guidelines.*

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Audience:** Developers, System Administrators, Technical Staff
