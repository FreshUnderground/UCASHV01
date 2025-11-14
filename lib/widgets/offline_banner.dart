import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

/// Widget de bannière pour afficher le mode offline et les opérations en attente
class OfflineBanner extends StatefulWidget {
  final SyncService syncService;
  
  const OfflineBanner({
    super.key,
    required this.syncService,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<SyncStatus>? _syncSubscription;
  bool _isOffline = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Écouter les changements de statut
    _syncSubscription = widget.syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isOffline = status == SyncStatus.offline;
          _pendingCount = widget.syncService.pendingSyncCount;
        });
      }
    });
    
    // État initial
    _isOffline = widget.syncService.currentStatus == SyncStatus.offline;
    _pendingCount = widget.syncService.pendingSyncCount;
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.orange[100],
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          border: Border(
            bottom: BorderSide(
              color: Colors.orange[300]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: Colors.orange[900],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode hors ligne',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                      fontSize: 14,
                    ),
                  ),
                  if (_pendingCount > 0)
                    Text(
                      '$_pendingCount opération${_pendingCount > 1 ? 's' : ''} en attente de synchronisation',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      'Vous pouvez continuer à travailler. Les données seront synchronisées automatiquement.',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () async {
                // Tenter de synchroniser
                final result = await widget.syncService.syncAll();
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.success 
                                ? 'Synchronisation réussie ✓' 
                                : 'Toujours hors ligne',
                          ),
                          backgroundColor: result.success ? Colors.green : Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange[900],
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
