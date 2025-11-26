import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/robust_sync_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  final bool showLabel;
  final double size;
  
  const SyncStatusIndicator({
    super.key,
    this.showLabel = true,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RobustSyncService>(
      builder: (context, syncService, child) {
        final stats = syncService.getStats();
        final isOnline = stats['isOnline'] as bool;
        final isSyncing = stats['isFastSyncing'] as bool || stats['isSlowSyncing'] as bool;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline 
                  ? (isSyncing ? Colors.orange : Colors.green)
                  : Colors.red,
              ),
              child: isSyncing
                ? SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOnline ? Colors.white : Colors.grey,
                      ),
                    ),
                  )
                : null,
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                isOnline 
                  ? (isSyncing ? 'Synchronisation...' : 'En ligne')
                  : 'Hors ligne',
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline 
                    ? (isSyncing ? Colors.orange : Colors.green)
                    : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}