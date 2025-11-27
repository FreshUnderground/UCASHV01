import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

/// Widget d'indicateur de synchronisation automatique
/// Affiche le statut de sync et le temps restant avant la prochaine sync
class SyncIndicator extends StatefulWidget {
  final SyncService syncService;
  
  const SyncIndicator({
    super.key,
    required this.syncService,
  });

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  SyncStatus _currentStatus = SyncStatus.idle;
  Duration? _timeRemaining;
  Timer? _updateTimer;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    
    // Écouter les changements de statut de sync
    _syncSubscription = widget.syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
    
    // Mettre à jour le temps restant chaque seconde
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining = widget.syncService.getTimeUntilNextSync();
        });
      }
    });
    
    _currentStatus = widget.syncService.currentStatus;
    _timeRemaining = widget.syncService.getTimeUntilNextSync();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.syncService.pendingSyncCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône de statut avec animation
          _buildStatusIcon(),
          const SizedBox(width: 8),
          
          // Texte de statut
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentStatus == SyncStatus.offline && pendingCount > 0)
                Text(
                  '$pendingCount en attente',
                  style: TextStyle(
                    color: _getStatusColor().withOpacity(0.7),
                    fontSize: 10,
                  ),
                )
              else if (_timeRemaining != null && _currentStatus != SyncStatus.syncing && _currentStatus != SyncStatus.offline)
                Text(
                  'Prochaine sync: ${_formatDuration(_timeRemaining!)}',
                  style: TextStyle(
                    color: _getStatusColor().withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_currentStatus) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
          ),
        );
      case SyncStatus.success:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: _getStatusColor(),
        );
      case SyncStatus.error:
        return Icon(
          Icons.error,
          size: 16,
          color: _getStatusColor(),
        );
      case SyncStatus.offline:
        return Icon(
          Icons.cloud_off,
          size: 16,
          color: _getStatusColor(),
        );
      case SyncStatus.idle:
      default:
        return Icon(
          Icons.sync,
          size: 16,
          color: _getStatusColor(),
        );
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.offline:
        return Colors.orange;
      case SyncStatus.idle:
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_currentStatus) {
      case SyncStatus.syncing:
        return 'Synchronisation...';
      case SyncStatus.success:
        return 'Synchronisé';
      case SyncStatus.error:
        return 'Erreur de sync';
      case SyncStatus.offline:
        return 'Hors ligne';
      case SyncStatus.idle:
      default:
        return 'En attente';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative || duration.inSeconds == 0) {
      return 'maintenant';
    }
    
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = duration.inMinutes;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }
}

/// Widget bouton pour forcer une synchronisation manuelle
class ManualSyncButton extends StatefulWidget {
  final SyncService syncService;
  final VoidCallback? onSyncComplete;
  
  const ManualSyncButton({
    super.key,
    required this.syncService,
    this.onSyncComplete,
  });

  @override
  State<ManualSyncButton> createState() => _ManualSyncButtonState();
}

class _ManualSyncButtonState extends State<ManualSyncButton> {
  bool _isSyncing = false;

  Future<void> _handleManualSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await widget.syncService.syncAll();
      
      if (mounted) {
        final message = result.success 
            ? 'Synchronisation réussie ✓' 
            : 'Erreur: ${result.message}';
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: result.success ? Colors.green : Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
        
        if (result.success) {
          // Rafraîchir les données utilisateur après sync
          try {
            final authService = AuthService();
            await authService.refreshUserData();
            debugPrint('✅ Données utilisateur rafraîchies après sync');
          } catch (e) {
            debugPrint('⚠️ Erreur rafraîchissement données utilisateur: $e');
          }
          
          if (widget.onSyncComplete != null) {
            widget.onSyncComplete!();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isSyncing ? null : _handleManualSync,
      icon: _isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      tooltip: 'Synchroniser maintenant',
      color: Colors.blue,
    );
  }
}
