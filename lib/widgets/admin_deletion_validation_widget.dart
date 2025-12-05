import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deletion_request_model.dart';
import '../services/deletion_service.dart';
import '../services/auth_service.dart';

/// Widget Admin: Valider les demandes de suppression (inter-admin)
class AdminDeletionValidationWidget extends StatelessWidget {
  const AdminDeletionValidationWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DeletionService>(
      builder: (context, service, _) {
        final pendingRequests = service.adminPendingRequests;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Validations Admin (${pendingRequests.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.loadDeletionRequests(),
              ),
            ],
          ),
          body: pendingRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'Aucune demande en attente de validation',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Les demandes de suppression apparaîtront ici\nune fois créées par les administrateurs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = pendingRequests[index];
                    return _buildRequestCard(context, request);
                  },
                ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, DeletionRequestModel request) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: const Icon(Icons.warning, color: Colors.orange),
        title: Text(
          '${request.operationType} - ${request.montant.toStringAsFixed(2)} ${request.devise}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandé par: ${request.requestedByAdminName}'),
            Text('Date: ${_formatDate(request.requestDate)}'),
            if (request.destinataire != null)
              Text('Destinataire: ${request.destinataire}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Code opération', request.codeOps),
                if (request.expediteur != null)
                  _buildDetailRow('Expéditeur', request.expediteur!),
                if (request.clientNom != null)
                  _buildDetailRow('Client', request.clientNom!),
                if (request.reason != null) ...[
                  const SizedBox(height: 8),
                  const Text('Raison:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(request.reason!),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _validateRequest(context, request, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Refuser'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _validateRequest(context, request, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
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

  void _validateRequest(BuildContext context, DeletionRequestModel request, bool approve) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Valider la suppression' : 'Refuser la suppression'),
        content: Text(
          approve
              ? 'Confirmer la validation de cette demande de suppression ?\nElle sera ensuite envoyée à l\'agent pour traitement final.'
              : 'Refuser cette demande de suppression ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final admin = authService.currentUser;
              
              if (admin == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin non connecté')),
                );
                return;
              }
              
              final deletionService = Provider.of<DeletionService>(context, listen: false);
              final success = await deletionService.validateAdminDeletionRequest(
                codeOps: request.codeOps,
                validatorAdminId: admin.id ?? 0,
                validatorAdminName: admin.username,
              );
              
              Navigator.pop(context);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(approve 
                        ? 'Demande validée avec succès' 
                        : 'Demande refusée'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la validation')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            child: Text(approve ? 'Confirmer' : 'Refuser'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}