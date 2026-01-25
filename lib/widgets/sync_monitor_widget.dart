import 'dart:async';
import 'package:flutter/material.dart';
import '../services/robust_sync_service.dart';
import '../services/sync_service.dart';
import '../services/agent_service.dart';

/// Widget de monitoring de la synchronisation robuste
/// Affiche l'état, les statistiques et les erreurs en temps réel
class SyncMonitorWidget extends StatefulWidget {
  const SyncMonitorWidget({super.key});

  @override
  State<SyncMonitorWidget> createState() => _SyncMonitorWidgetState();
}

class _SyncMonitorWidgetState extends State<SyncMonitorWidget> {
  final RobustSyncService _robustSync = RobustSyncService();
  Timer? _refreshTimer;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();

    // Rafraîchir les stats toutes les 2 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadStats() {
    if (mounted) {
      setState(() {
        _stats = _robustSync.getStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _stats['isOnline'] ?? false;
    final isEnabled = _stats['isEnabled'] ?? false;
    final isFastSyncing = _stats['isFastSyncing'] ?? false;
    final isSlowSyncing = _stats['isSlowSyncing'] ?? false;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: isEnabled ? Colors.blue : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Synchronisation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEnabled ? 'Activée' : 'Désactivée',
                        style: TextStyle(
                          color: isEnabled ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Switch enable/disable
                Switch(
                  value: isEnabled,
                  onChanged: (value) {
                    _robustSync.setEnabled(value);
                    _loadStats();
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            // État de connexion
            _buildStatusRow(
              'État de connexion',
              isOnline ? 'En ligne' : 'Hors ligne',
              isOnline ? Colors.green : Colors.red,
              isOnline ? Icons.wifi : Icons.wifi_off,
            ),

            const SizedBox(height: 8),

            // État FAST SYNC
            _buildStatusRow(
              'FAST (2 min)',
              isFastSyncing ? 'En cours...' : 'En attente',
              isFastSyncing ? Colors.blue : Colors.grey,
              isFastSyncing ? Icons.sync : Icons.schedule,
            ),

            const SizedBox(height: 8),

            // État SLOW SYNC
            _buildStatusRow(
              'SLOW (10 min)',
              isSlowSyncing ? 'En cours...' : 'En attente',
              isSlowSyncing ? Colors.blue : Colors.grey,
              isSlowSyncing ? Icons.sync : Icons.schedule,
            ),

            const Divider(height: 24),

            // Statistiques
            const Text(
              'Statistiques',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'FAST',
                    _stats['fastSyncSuccess'] ?? 0,
                    _stats['fastSyncErrors'] ?? 0,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'SLOW',
                    _stats['slowSyncSuccess'] ?? 0,
                    _stats['slowSyncErrors'] ?? 0,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Dernières synchronisations
            _buildLastSyncInfo(
              'Dernière FAST SYNC',
              _stats['lastFastSync'],
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildLastSyncInfo(
              'Dernière SLOW SYNC',
              _stats['lastSlowSync'],
              Colors.purple,
            ),

            // Tables échouées
            if ((_stats['failedFastTables'] as List?)?.isNotEmpty == true ||
                (_stats['failedSlowTables'] as List?)?.isNotEmpty == true) ...[
              const Divider(height: 24),
              const Text(
                '⚠️ Tables échouées',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              if ((_stats['failedFastTables'] as List?)?.isNotEmpty == true)
                _buildFailedTables(
                  'FAST',
                  _stats['failedFastTables'] as List,
                  Colors.blue,
                ),
              if ((_stats['failedSlowTables'] as List?)?.isNotEmpty == true)
                _buildFailedTables(
                  'SLOW',
                  _stats['failedSlowTables'] as List,
                  Colors.purple,
                ),
            ],

            const Divider(height: 10),

            // Bouton sync manuelle complète
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isEnabled && isOnline
                    ? () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('🔄 Synchronisation manuelle en cours...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        await _robustSync.syncNow();
                        _loadStats();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Synchronisation terminée'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Synchroniser Tout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(7),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 🆕 Bouton FORCER DOWNLOAD AGENTS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isOnline
                    ? () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('👥 Téléchargement des agents...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        try {
                          final syncService = SyncService();

                          // Forcer le download des agents
                          await syncService.downloadTableData(
                              'agents', 'admin', 'admin');

                          // Recharger en mémoire
                          await AgentService.instance.loadAgents();

                          final agentCount =
                              AgentService.instance.agents.length;

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '✅ $agentCount agent(s) téléchargé(s)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.people_alt, size: 18),
                label: const Text('Forcer Download Agents'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(7),
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int success, int errors, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('$success',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text('$errors',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncInfo(String label, String? timestamp, Color color) {
    String displayText = 'Jamais';
    if (timestamp != null && timestamp.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(timestamp);
        final now = DateTime.now();
        final diff = now.difference(dateTime);

        if (diff.inSeconds < 60) {
          displayText = 'Il y a ${diff.inSeconds}s';
        } else if (diff.inMinutes < 60) {
          displayText = 'Il y a ${diff.inMinutes} min';
        } else {
          displayText = 'Il y a ${diff.inHours}h';
        }
      } catch (e) {
        displayText = 'Erreur';
      }
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFailedTables(String type, List tables, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tables.join(', '),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
