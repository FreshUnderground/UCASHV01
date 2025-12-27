# 💡 EXEMPLES PRATIQUES - SYNCHRONISATION OPTIMISÉE

## 🎯 **CAS D'USAGE CONCRETS**

### **1. AGENT EN DÉBUT DE JOURNÉE**
```dart
// Synchronisation matinale - Récupérer les nouvelles opérations
final result = await robustSync.performDeltaOperationsSync(
  mode: DeltaSyncManager.SyncMode.delta,
  statusFilter: DeltaSyncManager.StatusFilter.critical,
  limit: 150
);

print('📥 ${result.syncStats.newOperations} nouvelles opérations');
print('🔄 ${result.syncStats.updatedOperations} mises à jour');
```

### **2. VALIDATION D'OPÉRATIONS**
```dart
// Après validation - Récupérer seulement les changements de statut
final result = await robustSync.performDeltaOperationsSync(
  mode: DeltaSyncManager.SyncMode.updates_only,
  statusFilter: DeltaSyncManager.StatusFilter.recent,
  limit: 50
);
```

### **3. URGENCE - OPÉRATIONS EN ATTENTE**
```dart
// Mode urgence - Seulement les opérations critiques
final result = await robustSync.performDeltaOperationsSync(
  mode: DeltaSyncManager.SyncMode.delta,
  statusFilter: DeltaSyncManager.StatusFilter.pending,
  limit: 30
);
```

---

## 🌐 **EXEMPLES D'APPELS API**

### **1. SYNCHRONISATION DELTA BASIQUE**
```http
GET /server/api/sync/operations/delta_sync.php?
  user_id=123&
  user_role=agent&
  shop_id=456&
  sync_mode=delta&
  known_ids=1001,1002,1003,1004&
  limit=100&
  compress=true
```

**Réponse:**
```json
{
  "success": true,
  "entities": [
    {
      "id": 1005,
      "type": "depot",
      "montant_brut": 50000.0,
      "statut": "en_attente",
      "sync_action": "new"
    }
  ],
  "sync_stats": {
    "total_operations": 1,
    "new_operations": 1,
    "updated_operations": 0,
    "sync_hash": "a1b2c3d4"
  }
}
```

### **2. FILTRAGE INTELLIGENT - MODE CRITIQUE**
```http
GET /server/api/sync/operations/smart_filters.php?
  user_id=123&
  user_role=agent&
  shop_id=456&
  filter_strategy=smart&
  priority_mode=critical&
  limit=50
```

**Réponse:**
```json
{
  "success": true,
  "entities": [...],
  "statistics": {
    "en_attente": 15,
    "servi": 2,
    "annule": 0,
    "modified_operations": 3,
    "new_operations": 14
  },
  "recommendations": [
    "Beaucoup d'opérations en attente - traitement prioritaire recommandé"
  ]
}
```

### **3. FILTRAGE PAR STATUT SPÉCIFIQUE**
```http
GET /server/api/sync/operations/smart_filters.php?
  user_id=123&
  filter_strategy=status_based&
  include_only_statuses=en_attente,servi&
  modified_since=2024-12-24T08:00:00Z
```

---

## 📱 **INTÉGRATION FLUTTER COMPLÈTE**

### **1. Service de Synchronisation Personnalisé**
```dart
class OptimizedSyncService {
  final RobustSyncService _robustSync = RobustSyncService();
  
  /// Synchronisation intelligente selon le contexte
  Future<SyncResult> smartSync({
    required SyncContext context,
    int? customLimit,
  }) async {
    DeltaSyncManager.SyncMode mode;
    DeltaSyncManager.StatusFilter filter;
    int limit = customLimit ?? 100;
    
    switch (context) {
      case SyncContext.startup:
        mode = DeltaSyncManager.SyncMode.delta;
        filter = DeltaSyncManager.StatusFilter.critical;
        limit = 200;
        break;
        
      case SyncContext.afterValidation:
        mode = DeltaSyncManager.SyncMode.updates_only;
        filter = DeltaSyncManager.StatusFilter.recent;
        limit = 50;
        break;
        
      case SyncContext.emergency:
        mode = DeltaSyncManager.SyncMode.delta;
        filter = DeltaSyncManager.StatusFilter.pending;
        limit = 30;
        break;
        
      case SyncContext.periodic:
        mode = DeltaSyncManager.SyncMode.delta;
        filter = DeltaSyncManager.StatusFilter.balanced;
        limit = 100;
        break;
    }
    
    final result = await _robustSync.performDeltaOperationsSync(
      mode: mode,
      statusFilter: filter,
      limit: limit,
    );
    
    return SyncResult.fromDeltaResult(result, context);
  }
}

enum SyncContext {
  startup,
  afterValidation,
  emergency,
  periodic,
}
```

### **2. Widget de Monitoring**
```dart
class SyncMonitorWidget extends StatefulWidget {
  @override
  _SyncMonitorWidgetState createState() => _SyncMonitorWidgetState();
}

class _SyncMonitorWidgetState extends State<SyncMonitorWidget> {
  CacheStats? _cacheStats;
  
  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }
  
  Future<void> _loadCacheStats() async {
    final stats = await DeltaSyncManager.getCacheStats();
    setState(() {
      _cacheStats = stats;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cacheStats == null) {
      return CircularProgressIndicator();
    }
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Statistiques de Synchronisation',
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            Text('Opérations connues: ${_cacheStats!.knownOperationsCount}'),
            Text('Taille du cache: ${(_cacheStats!.cacheSize / 1024).toStringAsFixed(1)} KB'),
            Text('Dernière sync: ${_formatTimestamp(_cacheStats!.lastSyncTimestamp)}'),
            SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _performSmartSync,
                  child: Text('🔄 Sync Intelligente'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resetCache,
                  child: Text('🗑️ Reset Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _performSmartSync() async {
    try {
      final optimizedSync = OptimizedSyncService();
      final result = await optimizedSync.smartSync(
        context: SyncContext.periodic,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sync réussie: ${result.totalOperations} opérations'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadCacheStats(); // Rafraîchir les stats
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _resetCache() async {
    await DeltaSyncManager.resetSyncCache();
    _loadCacheStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🗑️ Cache réinitialisé'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Jamais';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inHours < 1) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return 'Il y a ${difference.inDays} jours';
      }
    } catch (e) {
      return 'Format invalide';
    }
  }
}
```

---

## 🔧 **CONFIGURATION AVANCÉE**

### **1. Configuration Personnalisée par Environnement**

#### **Développement (.env.dev)**
```env
API_MAX_RESULTS=100
API_DEFAULT_LIMIT=50
ENABLE_COMPRESSION=false
DEBUG_MODE=true
LOG_LEVEL=DEBUG
```

#### **Production (.env.prod)**
```env
API_MAX_RESULTS=500
API_DEFAULT_LIMIT=100
ENABLE_COMPRESSION=true
DEBUG_MODE=false
LOG_LEVEL=ERROR
```

### **2. Stratégies de Synchronisation par Rôle**

#### **Pour les Agents**
```dart
// Agents - Focus sur leurs opérations
final result = await robustSync.performDeltaOperationsSync(
  mode: DeltaSyncManager.SyncMode.delta,
  statusFilter: DeltaSyncManager.StatusFilter.critical,
  limit: 100, // Limite modérée
);
```

#### **Pour les Administrateurs**
```dart
// Admins - Vue globale
final result = await robustSync.performDeltaOperationsSync(
  mode: DeltaSyncManager.SyncMode.delta,
  statusFilter: DeltaSyncManager.StatusFilter.balanced,
  limit: 200, // Limite plus élevée
);
```

---

## 📊 **MÉTRIQUES ET MONITORING**

### **1. Dashboard de Performance**
```dart
class SyncPerformanceDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SyncHealthMetric>>(
      future: _getHealthMetrics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final metrics = snapshot.data!;
        final latestMetric = metrics.last;
        
        return Column(
          children: [
            _buildMetricCard('Latence', '${latestMetric.syncLatency.inSeconds}s'),
            _buildMetricCard('Taux d\'erreur', '${(latestMetric.errorRate * 100).toStringAsFixed(1)}%'),
            _buildMetricCard('Taille de la queue', '${latestMetric.queueSize}'),
            if (latestMetric.needsIntervention)
              Card(
                color: Colors.red[100],
                child: ListTile(
                  leading: Icon(Icons.warning, color: Colors.red),
                  title: Text('⚠️ Intervention Nécessaire'),
                  subtitle: Text('Performance dégradée détectée'),
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildMetricCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        )),
      ),
    );
  }
}
```

### **2. Alertes Automatiques**
```dart
class SyncAlertManager {
  static void checkAndAlert(DeltaSyncResult result) {
    final stats = result.syncStats;
    
    // Alerte: Trop d'opérations en attente
    if (stats.totalOperations > 100) {
      _showAlert(
        '⚠️ Volume Élevé',
        '${stats.totalOperations} opérations détectées. Considérer un filtrage plus strict.',
        AlertType.warning,
      );
    }
    
    // Alerte: Beaucoup de modifications
    if (stats.updatedOperations > stats.newOperations * 2) {
      _showAlert(
        '🔄 Nombreuses Modifications',
        'Beaucoup d\'opérations ont été modifiées. Vérifier les validations récentes.',
        AlertType.info,
      );
    }
    
    // Alerte: Synchronisation réussie
    if (stats.totalOperations > 0) {
      _showAlert(
        '✅ Synchronisation Réussie',
        '${stats.newOperations} nouvelles, ${stats.updatedOperations} mises à jour',
        AlertType.success,
      );
    }
  }
  
  static void _showAlert(String title, String message, AlertType type) {
    // Implémentation des notifications
    // Peut utiliser SnackBar, Dialog, ou notifications push
  }
}

enum AlertType { success, warning, error, info }
```

---

## 🎯 **OPTIMISATIONS SPÉCIFIQUES**

### **1. Optimisation par Heure de la Journée**
```dart
class TimeBasedSyncStrategy {
  static DeltaSyncManager.StatusFilter getOptimalFilter() {
    final hour = DateTime.now().hour;
    
    if (hour >= 8 && hour <= 10) {
      // Matin - Beaucoup d'activité
      return DeltaSyncManager.StatusFilter.critical;
    } else if (hour >= 11 && hour <= 16) {
      // Journée - Activité normale
      return DeltaSyncManager.StatusFilter.balanced;
    } else {
      // Soir/Nuit - Moins d'activité
      return DeltaSyncManager.StatusFilter.pending;
    }
  }
  
  static int getOptimalLimit() {
    final hour = DateTime.now().hour;
    
    if (hour >= 8 && hour <= 10) {
      return 150; // Plus de données le matin
    } else if (hour >= 11 && hour <= 16) {
      return 100; // Normal en journée
    } else {
      return 50;  // Moins le soir
    }
  }
}
```

### **2. Optimisation par Connexion Réseau**
```dart
class NetworkAwareSyncStrategy {
  static Future<SyncConfig> getOptimalConfig() async {
    final connectivity = await Connectivity().checkConnectivity();
    
    switch (connectivity) {
      case ConnectivityResult.wifi:
        return SyncConfig(
          limit: 200,
          compress: true,
          mode: DeltaSyncManager.SyncMode.delta,
        );
        
      case ConnectivityResult.mobile:
        return SyncConfig(
          limit: 50,
          compress: true,
          mode: DeltaSyncManager.SyncMode.updates_only,
        );
        
      default:
        throw Exception('Pas de connexion réseau');
    }
  }
}

class SyncConfig {
  final int limit;
  final bool compress;
  final DeltaSyncManager.SyncMode mode;
  
  SyncConfig({
    required this.limit,
    required this.compress,
    required this.mode,
  });
}
```

---

*Ces exemples montrent comment utiliser efficacement le système de synchronisation optimisée dans différents contextes réels.*
