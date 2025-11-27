import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_containers.dart';

/// Widget d'affichage du statut de synchronisation
class SyncStatusWidget extends StatelessWidget {
  final bool showManualSyncButton;
  final String? userId;
  
  const SyncStatusWidget({
    super.key,
    this.showManualSyncButton = true,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService().syncStatusStream,
      initialData: SyncService().currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;
        
        return Container(
          padding: context.fluidPadding(
            mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
            ),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(status),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 16),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showManualSyncButton && status != SyncStatus.syncing) ...[
                const SizedBox(width: 12),
                _buildSyncButton(context, status),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_getStatusColor(status)),
          ),
        );
      case SyncStatus.success:
        return Icon(
          Icons.check_circle,
          color: _getStatusColor(status),
          size: 16,
        );
      case SyncStatus.error:
        return Icon(
          Icons.error,
          color: _getStatusColor(status),
          size: 16,
        );
      case SyncStatus.idle:
      default:
        return Icon(
          Icons.sync,
          color: _getStatusColor(status),
          size: 16,
        );
    }
  }

  Widget _buildSyncButton(BuildContext context, SyncStatus status) {
    return InkWell(
      onTap: () => _triggerManualSync(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync,
              color: const Color(0xFFDC2626),
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Sync',
              style: TextStyle(
                color: const Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.idle:
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Synchronisation en cours...';
      case SyncStatus.success:
        return 'Synchronisé';
      case SyncStatus.error:
        return 'Erreur de synchronisation';
      case SyncStatus.idle:
      default:
        return 'Prêt à synchroniser';
    }
  }

  void _triggerManualSync(BuildContext context) async {
    final syncService = SyncService();
    
    try {
      final result = await syncService.syncAll(userId: userId);
      
      if (!result.success) {
        _showSyncError(context, result.message);
      }
    } catch (e) {
      _showSyncError(context, e.toString());
    }
  }

  void _showSyncError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Erreur de synchronisation: $message'),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Widget de synchronisation pour les dashboards
class DashboardSyncWidget extends StatelessWidget {
  final String? userId;
  
  const DashboardSyncWidget({
    super.key,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return context.adaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync,
                color: const Color(0xFFDC2626),
                size: context.fluidIcon(mobile: 20, tablet: 24, desktop: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Synchronisation',
                  style: TextStyle(
                    fontSize: context.fluidFont(mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          
          // Statut de synchronisation
          SyncStatusWidget(
            showManualSyncButton: false,
            userId: userId,
          ),
          
          context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
          
          // Informations sur la synchronisation
          _buildSyncInfo(context),
          
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          
          // Boutons d'action
          _buildSyncActions(context),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(BuildContext context) {
    return Container(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(20),
      ),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
        ),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Synchronisation Automatique',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: context.fluidFont(mobile: 14, tablet: 16, desktop: 18),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vos données sont automatiquement synchronisées dès qu\'une connexion Internet est détectée. '
            'Vous pouvez également déclencher une synchronisation manuelle.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 16),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _triggerFullSync(context),
            icon: const Icon(Icons.sync),
            label: const Text('Synchroniser Maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _toggleAutoSync(context),
          icon: const Icon(Icons.settings),
          label: const Text('Config'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFDC2626)),
            padding: EdgeInsets.symmetric(
              vertical: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
              horizontal: context.fluidSpacing(mobile: 16, tablet: 20, desktop: 24),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _triggerFullSync(BuildContext context) async {
    final syncService = SyncService();
    
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final result = await syncService.syncAll(userId: userId);
      
      Navigator.of(context).pop(); // Fermer le loading
      
      if (result.success) {
        _showSyncSuccess(context);
      } else {
        _showSyncError(context, result.message);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le loading
      _showSyncError(context, e.toString());
    }
  }

  void _toggleAutoSync(BuildContext context) {
    // Afficher un dialog de configuration
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Synchronisation'),
        content: const Text(
          'La synchronisation automatique est activée par défaut. '
          'Elle se déclenche automatiquement dès qu\'une connexion Internet est détectée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSyncSuccess(BuildContext context) {
    // Rafraîchir les données utilisateur après sync réussie
    _refreshUserDataAfterSync();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Synchronisation réussie !'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Rafraîchir les données utilisateur après une synchronisation réussie
  void _refreshUserDataAfterSync() async {
    try {
      final authService = AuthService();
      await authService.refreshUserData();
      debugPrint('✅ Données utilisateur rafraîchies après sync (DashboardSyncWidget)');
    } catch (e) {
      debugPrint('⚠️ Erreur rafraîchissement données utilisateur: $e');
    }
  }

  void _showSyncError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Erreur: $message'),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
