import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_corbeille_model.dart';
import '../services/deletion_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

/// Widget Corbeille: Restaurer les opérations supprimées
class TrashBinWidget extends StatelessWidget {
  final bool
      showAll; // Si true, affiche TOUT (admin), sinon seulement les non-synced (agent)

  const TrashBinWidget({Key? key, this.showAll = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeletionService>(
      builder: (context, service, _) {
        // Admin: afficher TOUS les éléments (synchronisés ou non)
        // Agent: afficher seulement les éléments en attente de sync
        final trash = showAll ? service.allTrash : service.activeTrash;

        return Scaffold(
          appBar: AppBar(
            title: Text('${l10n.trashBin} (${trash.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.loadCorbeille(),
              ),
            ],
          ),
          body: trash.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(l10n.emptyTrash,
                          style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: trash.length,
                  itemBuilder: (context, index) {
                    final item = trash[index];
                    return _buildTrashCard(context, item, l10n);
                  },
                ),
        );
      },
    );
  }

  Widget _buildTrashCard(BuildContext context, OperationCorbeilleModel item,
      AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.all(8),
      // Bordure verte si synchronisé (sur le serveur)
      color: item.isSynced ? Colors.green[50] : null,
      child: ExpansionTile(
        leading: Icon(
          Icons.delete,
          color: item.isSynced ? Colors.green : Colors.red,
        ),
        title: Text(
          '${item.type} - ${item.montantNet.toStringAsFixed(2)} ${item.devise}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.code}: ${item.codeOps}'),
            Text('${l10n.deletedOn}: ${_formatDate(item.deletedAt)}'),
            if (item.deletedByAdminName != null)
              Text('${l10n.deletedBy}: ${item.deletedByAdminName}'),
            // Indicateur de synchronisation
            if (item.isSynced)
              Row(
                children: [
                  const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    l10n.syncedOnServer,
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.cloud_upload,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.waitingForSync,
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.destinataire != null)
                  _buildDetailRow(l10n.recipient, item.destinataire!, l10n),
                if (item.clientNom != null)
                  _buildDetailRow(l10n.client, item.clientNom!, l10n),
                if (item.agentUsername != null)
                  _buildDetailRow(l10n.agent, item.agentUsername!, l10n),
                _buildDetailRow(l10n.grossAmount,
                    '${item.montantBrut} ${item.devise}', l10n),
                _buildDetailRow(
                    l10n.commission, '${item.commission} ${item.devise}', l10n),
                _buildDetailRow(
                    l10n.netAmount, '${item.montantNet} ${item.devise}', l10n),
                _buildDetailRow(
                    l10n.operationDate, _formatDate(item.dateOp), l10n),
                if (item.deletionReason != null) ...[
                  const SizedBox(height: 8),
                  Text('${l10n.deletionReason}:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.deletionReason!),
                ],
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _restoreOperation(context, item, l10n),
                    icon: const Icon(Icons.restore),
                    label: Text(l10n.restoreThisOperation),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _restoreOperation(BuildContext context, OperationCorbeilleModel item,
      AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreOperation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmRestore),
            const SizedBox(height: 8),
            Text('${l10n.code}: ${item.codeOps}'),
            Text('${l10n.amount}: ${item.montantNet} ${item.devise}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final user = authService.currentUser;

              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.userNotConnected)),
                );
                return;
              }

              final deletionService =
                  Provider.of<DeletionService>(context, listen: false);
              final success = await deletionService.restoreOperation(
                codeOps: item.codeOps,
                restoredBy: 'admin_${user.username}',
              );

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.operationRestored)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.errorRestoring)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l10n.restoreOperation),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
