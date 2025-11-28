import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deletion_request_model.dart';
import '../models/operation_corbeille_model.dart';
import '../services/deletion_service.dart';
import '../services/auth_service.dart';

/// Widget Corbeille: Restaurer les opérations supprimées
class TrashBinWidget extends StatelessWidget {
  const TrashBinWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DeletionService>(
      builder: (context, service, _) {
        final trash = service.activeTrash;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Corbeille (${trash.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.loadCorbeille(),
              ),
            ],
          ),
          body: trash.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Corbeille vide', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: trash.length,
                  itemBuilder: (context, index) {
                    final item = trash[index];
                    return _buildTrashCard(context, item);
                  },
                ),
        );
      },
    );
  }

  Widget _buildTrashCard(BuildContext context, OperationCorbeilleModel item) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: Text(
          '${item.type} - ${item.montantNet.toStringAsFixed(2)} ${item.devise}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${item.codeOps}'),
            Text('Supprimé le: ${_formatDate(item.deletedAt)}'),
            if (item.deletedByAdminName != null)
              Text('Par: ${item.deletedByAdminName}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.destinataire != null)
                  _buildDetailRow('Destinataire', item.destinataire!),
                if (item.clientNom != null)
                  _buildDetailRow('Client', item.clientNom!),
                if (item.agentUsername != null)
                  _buildDetailRow('Agent', item.agentUsername!),
                _buildDetailRow('Montant brut', '${item.montantBrut} ${item.devise}'),
                _buildDetailRow('Commission', '${item.commission} ${item.devise}'),
                _buildDetailRow('Montant net', '${item.montantNet} ${item.devise}'),
                _buildDetailRow('Date opération', _formatDate(item.dateOp)),
                
                if (item.deletionReason != null) ...[
                  const SizedBox(height: 8),
                  const Text('Raison suppression:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.deletionReason!),
                ],
                
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _restoreOperation(context, item),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurer cette opération'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  void _restoreOperation(BuildContext context, OperationCorbeilleModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer l\'opération'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirmer la restauration de cette opération ?'),
            const SizedBox(height: 8),
            Text('Code: ${item.codeOps}'),
            Text('Montant: ${item.montantNet} ${item.devise}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final user = authService.currentUser;
              
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisateur non connecté')),
                );
                return;
              }
              
              final deletionService = Provider.of<DeletionService>(context, listen: false);
              final success = await deletionService.restoreOperation(
                codeOps: item.codeOps,
                restoredBy: 'admin_${user.username}',
              );
              
              Navigator.pop(context);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opération restaurée avec succès')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la restauration')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
