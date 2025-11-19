import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';

/// Widget pour surveiller et afficher les opérations en attente
/// Démarre automatiquement la vérification toutes les 30 secondes
class PendingOpsMonitorWidget extends StatefulWidget {
  const PendingOpsMonitorWidget({super.key});

  @override
  State<PendingOpsMonitorWidget> createState() => _PendingOpsMonitorWidgetState();
}

class _PendingOpsMonitorWidgetState extends State<PendingOpsMonitorWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMonitoring();
    });
  }

  void _startMonitoring() {
    final operationService = Provider.of<OperationService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Démarrer la vérification automatique avec le shopId de l'utilisateur
    final shopId = authService.currentUser?.shopId;
    operationService.startPendingOpsCheck(shopId: shopId);
    
    debugPrint('✅ Surveillance des opérations en attente démarrée pour Shop $shopId');
  }

  @override
  void dispose() {
    // Arrêter la vérification automatique quand le widget est détruit
    final operationService = Provider.of<OperationService>(context, listen: false);
    operationService.stopPendingOpsCheck();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final pendingCount = operationService.pendingOpsCount;
        final isEnabled = operationService.isPendingOpsCheckEnabled;

        if (!isEnabled || pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$pendingCount transfert${pendingCount > 1 ? 's' : ''} en attente de validation',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.orange.shade700, size: 20),
                onPressed: () async {
                  await operationService.checkPendingOperationsNow();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vérification des transferts en cours...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                tooltip: 'Vérifier maintenant',
              ),
            ],
          ),
        );
      },
    );
  }
}
