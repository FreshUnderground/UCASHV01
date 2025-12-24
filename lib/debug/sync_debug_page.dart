import 'package:flutter/material.dart';
import '../utils/sync_recovery_utils.dart';
import '../services/robust_sync_service.dart';

/// Page de débogage pour la synchronisation
/// Permet de diagnostiquer et résoudre les problèmes de sync
class SyncDebugPage extends StatefulWidget {
  const SyncDebugPage({Key? key}) : super(key: key);

  @override
  State<SyncDebugPage> createState() => _SyncDebugPageState();
}

class _SyncDebugPageState extends State<SyncDebugPage> {
  Map<String, dynamic>? _diagnosticInfo;
  bool _isLoading = false;
  String _lastAction = '';

  @override
  void initState() {
    super.initState();
    _refreshDiagnostic();
  }

  void _refreshDiagnostic() {
    setState(() {
      _diagnosticInfo = SyncRecoveryUtils.getDiagnosticInfo();
    });
  }

  Future<void> _forceResetAndSync() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Force reset et sync en cours...';
    });

    try {
      await SyncRecoveryUtils.forceResetAndSync();
      setState(() {
        _lastAction = '✅ Force reset et sync terminés avec succès';
      });
    } catch (e) {
      setState(() {
        _lastAction = '❌ Erreur lors du force reset: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _refreshDiagnostic();
    }
  }

  Future<void> _fixTriangularSync() async {
    setState(() {
      _isLoading = true;
      _lastAction = 'Fix triangular debt settlements en cours...';
    });

    try {
      await SyncRecoveryUtils.fixTriangularDebtSettlementsSync();
      setState(() {
        _lastAction = '✅ Fix triangular debt settlements terminé';
      });
    } catch (e) {
      setState(() {
        _lastAction = '❌ Erreur lors du fix triangular: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _refreshDiagnostic();
    }
  }

  void _showFailedTables() {
    SyncRecoveryUtils.showFailedTablesStatus();
    setState(() {
      _lastAction = '📋 Statut des tables affiché dans les logs';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Debug'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // État du circuit breaker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État du Circuit Breaker',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_diagnosticInfo != null) ...[
                      _buildStatusRow('Circuit Breaker', 
                        _diagnosticInfo!['isCircuitBreakerOpen'] ? '🔴 OUVERT' : '🟢 FERMÉ'),
                      _buildStatusRow('En ligne', 
                        _diagnosticInfo!['isOnline'] ? '🟢 OUI' : '🔴 NON'),
                      _buildStatusRow('Sync activée', 
                        _diagnosticInfo!['isEnabled'] ? '🟢 OUI' : '🔴 NON'),
                      _buildStatusRow('Échecs', 
                        '${_diagnosticInfo!['failureCount']}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions de récupération
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions de Récupération',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _forceResetAndSync,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Force Reset & Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fixTriangularSync,
                        icon: const Icon(Icons.build),
                        label: const Text('Fix Triangular Debt Settlements'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showFailedTables,
                        icon: const Icon(Icons.list),
                        label: const Text('Afficher Tables Échouées'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Dernière action
            if (_lastAction.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dernière Action',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_lastAction),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Bouton de rafraîchissement
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _refreshDiagnostic,
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir Diagnostic'),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
