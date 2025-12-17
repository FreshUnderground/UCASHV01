import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deletion_request_model.dart';
import '../services/deletion_service.dart';
import '../services/auth_service.dart';

/// Widget Agent: Valider les demandes de suppression (opérations + transactions virtuelles)
class AgentDeletionValidationWidget extends StatefulWidget {
  const AgentDeletionValidationWidget({Key? key}) : super(key: key);

  @override
  State<AgentDeletionValidationWidget> createState() => _AgentDeletionValidationWidgetState();
}

class _AgentDeletionValidationWidgetState extends State<AgentDeletionValidationWidget> {
  DeletionType _selectedFilter = DeletionType.all;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeletionService>(
      builder: (context, service, _) {
        final allRequests = service.getAllAgentPendingRequests(type: _selectedFilter);
        final operationsCount = service.pendingRequests.length;
        final virtualCount = service.pendingVirtualRequests.length;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Suppressions à valider (${allRequests.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  debugPrint('🔄 [AGENT] Refresh demandes suppressions...');
                  await service.syncAll();
                  debugPrint('✅ [AGENT] Refresh terminé');
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Filtres par type
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: SegmentedButton<DeletionType>(
                        segments: [
                          ButtonSegment(
                            value: DeletionType.all,
                            label: Text('Tout (${allRequests.length})'),
                          ),
                          ButtonSegment(
                            value: DeletionType.operations,
                            label: Text('Opérations ($operationsCount)'),
                          ),
                          ButtonSegment(
                            value: DeletionType.virtualTransactions,
                            label: Text('Virtuelles ($virtualCount)'),
                          ),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (Set<DeletionType> selection) {
                          setState(() {
                            _selectedFilter = selection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: allRequests.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'Aucune demande en attente',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Les demandes de suppression validées par\nles administrateurs apparaîtront ici.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: allRequests.length,
                        itemBuilder: (context, index) {
                          final request = allRequests[index];
                          return _buildRequestCard(context, request);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, dynamic request) {
    // Gérer les deux types: DeletionRequestModel et VirtualTransactionDeletionRequestModel
    final bool isVirtualTransaction = request.runtimeType.toString().contains('VirtualTransaction');
    
    final String identifier = isVirtualTransaction ? request.reference : request.codeOps;
    final String type = isVirtualTransaction ? request.transactionType : request.operationType;
    final double amount = request.montant;
    final String currency = request.devise;
    final String requestedBy = request.requestedByAdminName;
    final DateTime requestDate = request.requestDate;
    final String? validatedByAdmin = request.validatedByAdminName;
    final String? destinataire = isVirtualTransaction ? request.destinataire : request.destinataire;
    final String? expediteur = isVirtualTransaction ? request.expediteur : request.expediteur;
    final String? clientNom = request.clientNom;
    final String? reason = request.reason;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: Icon(
          isVirtualTransaction ? Icons.account_balance_wallet : Icons.swap_horiz, 
          color: isVirtualTransaction ? Colors.purple : Colors.orange
        ),
        title: Text(
          '${isVirtualTransaction ? "VT" : "OP"} - $type - ${amount.toStringAsFixed(2)} $currency',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandé par: $requestedBy'),
            if (validatedByAdmin != null)
              Text('Validé par admin: $validatedByAdmin'),
            Text('Date: ${_formatDate(requestDate)}'),
            if (destinataire != null)
              Text('Destinataire: $destinataire'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  isVirtualTransaction ? 'Référence' : 'Code opération', 
                  identifier
                ),
                if (expediteur != null)
                  _buildDetailRow('Expéditeur', expediteur)
                else if (!isVirtualTransaction && request.observation != null)
                  _buildDetailRow('Expéditeur', request.observation)
                else
                  _buildDetailRow('Expéditeur', 'Non spécifié'),
                if (clientNom != null)
                  _buildDetailRow('Client', clientNom),
                if (reason != null) ...[
                  const SizedBox(height: 8),
                  const Text('Raison:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(reason),
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
                      label: const Text('Approuver'),
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

  void _validateRequest(BuildContext context, dynamic request, bool approve) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approuver la suppression' : 'Refuser la suppression'),
        content: Text(
          approve
              ? 'Cette demande a été validée par un administrateur.\nConfirmer la suppression définitive de cette opération ?\nCette action est irréversible.'
              : 'Refuser cette demande de suppression validée par un administrateur ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final agent = authService.currentUser;
              
              if (agent == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Agent non connecté')),
                );
                return;
              }
              
              final deletionService = Provider.of<DeletionService>(context, listen: false);
              bool success;
              
              // Détecter le type de demande
              final bool isVirtualTransaction = request.runtimeType.toString().contains('VirtualTransaction');
              
              if (isVirtualTransaction) {
                // Validation pour les transactions virtuelles
                success = await deletionService.validateVirtualTransactionDeletionRequest(
                  reference: request.reference,
                  agentId: agent.id ?? 0,
                  agentName: agent.username,
                  approve: approve,
                );
              } else {
                // Validation pour les opérations
                success = await deletionService.validateDeletionRequest(
                  codeOps: request.codeOps,
                  agentId: agent.id ?? 0,
                  agentName: agent.username,
                  approve: approve,
                );
              }
              
              Navigator.pop(context);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(approve 
                        ? 'Opération supprimée avec succès' 
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
