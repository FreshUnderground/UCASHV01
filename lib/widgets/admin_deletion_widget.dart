import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../models/deletion_request_model.dart';
import '../services/deletion_service.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';
import 'edit_operation_dialog.dart';

/// Page Admin: Gestion des suppressions d'opérations
class AdminDeletionPage extends StatefulWidget {
  const AdminDeletionPage({super.key});

  @override
  State<AdminDeletionPage> createState() => _AdminDeletionPageState();
}

class _AdminDeletionPageState extends State<AdminDeletionPage> {
  // Filtres
  OperationType? _filterType;
  String _filterDestinataire = '';
  String _filterExpediteur = '';
  String _filterClient = '';
  double? _filterMontantMin;
  double? _filterMontantMax;
  
  List<OperationModel> get _filteredOperations {
    final operationService = Provider.of<OperationService>(context, listen: false);
    var ops = operationService.operations;
    
    // Appliquer les filtres
    if (_filterType != null) {
      ops = ops.where((op) => op.type == _filterType).toList();
    }
    
    if (_filterDestinataire.isNotEmpty) {
      ops = ops.where((op) => 
        op.destinataire?.toLowerCase().contains(_filterDestinataire.toLowerCase()) ?? false
      ).toList();
    }
    
    if (_filterExpediteur.isNotEmpty) {
      ops = ops.where((op) => 
        op.clientNom?.toLowerCase().contains(_filterExpediteur.toLowerCase()) ?? false
      ).toList();
    }
    
    if (_filterClient.isNotEmpty) {
      ops = ops.where((op) => 
        (op.clientNom?.toLowerCase().contains(_filterClient.toLowerCase()) ?? false) ||
        (op.destinataire?.toLowerCase().contains(_filterClient.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (_filterMontantMin != null) {
      ops = ops.where((op) => op.montantNet >= _filterMontantMin!).toList();
    }
    
    if (_filterMontantMax != null) {
      ops = ops.where((op) => op.montantNet <= _filterMontantMax!).toList();
    }
    
    return ops;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppression d\'Opérations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (mounted) {
                await Provider.of<OperationService>(context, listen: false).loadOperations();
                await Provider.of<DeletionService>(context, listen: false).loadDeletionRequests();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Section Filtres
          _buildFiltersSection(),
          
          // Liste des opérations
          Expanded(
            child: _buildOperationsList(),
          ),
          
          // Statut Auto-Sync
          _buildAutoSyncStatus(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: const Text('Filtres', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.filter_list),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Filtre Type d'opération
                DropdownButtonFormField<OperationType>(
                  value: _filterType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'opération',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    ...OperationType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(_getTypeLabel(type)),
                    )),
                  ],
                  onChanged: (value) => setState(() => _filterType = value),
                ),
                const SizedBox(height: 8),
                
                // Filtre Destinataire
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Destinataire',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  onChanged: (value) => setState(() => _filterDestinataire = value),
                ),
                const SizedBox(height: 8),
                
                // Filtre Expéditeur/Client
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Expéditeur/Client',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (value) => setState(() => _filterExpediteur = value),
                ),
                const SizedBox(height: 8),
                
                // Filtre Montant
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Montant min',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setState(() => 
                          _filterMontantMin = double.tryParse(value)
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Montant max',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setState(() => 
                          _filterMontantMax = double.tryParse(value)
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _filterType = null;
                    _filterDestinataire = '';
                    _filterExpediteur = '';
                    _filterClient = '';
                    _filterMontantMin = null;
                    _filterMontantMax = null;
                  }),
                  icon: const Icon(Icons.clear),
                  label: const Text('Réinitialiser filtres'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsList() {
    final filteredOps = _filteredOperations;
    
    if (filteredOps.isEmpty) {
      return const Center(
        child: Text('Aucune opération trouvée'),
      );
    }
    
    return ListView.builder(
      itemCount: filteredOps.length,
      itemBuilder: (context, index) {
        final operation = filteredOps[index];
        return _buildOperationCard(operation);
      },
    );
  }

  Widget _buildOperationCard(OperationModel operation) {
    final deletionService = Provider.of<DeletionService>(context);
    
    // Vérifier si une demande existe déjà
    final existingRequest = deletionService.deletionRequests
        .where((r) => r.codeOps == operation.codeOps)
        .firstOrNull;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(operation.type),
          child: Icon(_getTypeIcon(operation.type), color: Colors.white),
        ),
        title: Text(
          '${operation.typeLabel} - ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (operation.destinataire != null)
              Text('Destinataire: ${operation.destinataire}'),
            if (operation.clientNom != null)
              Text('Client: ${operation.clientNom}'),
            Text('Code: ${operation.codeOps}'),
            Text('Date: ${_formatDate(operation.dateOp)}'),
            if (existingRequest != null)
              Chip(
                label: Text(existingRequest.statutLabel),
                backgroundColor: _getStatusColor(existingRequest.statut),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingRequest != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Détails'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Modifier'),
                    ],
                  ),
                ),
                if (existingRequest == null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Supprimer'),
                      ],
                    ),
                  ),
                if (existingRequest != null)
                  const PopupMenuItem(
                    value: 'request_details',
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Détails demande'),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                if (value == 'details') {
                  _showOperationDetails(operation);
                } else if (value == 'edit') {
                  _showEditDialog(operation);
                } else if (value == 'delete') {
                  _showDeletionDialog(operation);
                } else if (value == 'request_details') {
                  _showRequestDetails(existingRequest!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletionDialog(OperationModel operation) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demande de suppression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opération: ${operation.typeLabel}'),
            Text('Montant: ${operation.montantNet} ${operation.devise}'),
            Text('Code: ${operation.codeOps}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison de la suppression',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
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
              final admin = authService.currentUser;
              
              if (admin == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin non connecté')),
                );
                return;
              }
              
              if (mounted) {
                final deletionService = Provider.of<DeletionService>(context, listen: false);
                final success = await deletionService.createDeletionRequest(
                  operation: operation,
                  adminId: admin.id ?? 0,
                  adminName: admin.username,
                  reason: reasonController.text.isEmpty ? null : reasonController.text,
                );
                
                Navigator.pop(context);
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demande de suppression créée')),
                  );
                  setState(() {});
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Créer demande'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(OperationModel operation) async {
    await showDialog(
      context: context,
      builder: (context) => EditOperationDialog(
        transaction: {
          'code_ops': operation.codeOps,
          'montant': operation.montantNet,
          'observation': operation.observation,
          'type': operation.type.name,
          'date_op': operation.dateOp,
        },
      ),
    );
    
    // Recharger les opérations après la fermeture du dialogue
    if (mounted) {
      await Provider.of<OperationService>(context, listen: false).loadOperations();
      setState(() {});
    }
  }

  void _showRequestDetails(DeletionRequestModel request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails de la demande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${request.codeOps}'),
            Text('Type: ${request.operationType}'),
            Text('Montant: ${request.montant} ${request.devise}'),
            const SizedBox(height: 8),
            Text('Statut: ${request.statutLabel}', 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getStatusTextColor(request.statut),
              ),
            ),
            const SizedBox(height: 8),
            Text('Demandé par: ${request.requestedByAdminName}'),
            Text('Date: ${_formatDate(request.requestDate)}'),
            if (request.reason != null && request.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Raison:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(request.reason!),
            ],
            if (request.validatedByAgentName != null) ...[
              const SizedBox(height: 8),
              Text('Validé par: ${request.validatedByAgentName}'),
              if (request.validationDate != null)
                Text('Date validation: ${_formatDate(request.validationDate!)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showOperationDetails(OperationModel operation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ${operation.codeOps}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Code Ops', operation.codeOps),
              const Divider(),
              _buildDetailRow('Type', operation.typeLabel),
              const Divider(),
              _buildDetailRow('Montant Brut', '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}'),
              if (operation.commission > 0) ...[
                _buildDetailRow('Commission', '${operation.commission.toStringAsFixed(2)} ${operation.devise}'),
              ],
              _buildDetailRow('Montant Net', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}'),
              const Divider(),
              if (operation.shopSourceId != null)
                _buildDetailRow('Shop Source', 'ID: ${operation.shopSourceId}${operation.shopSourceDesignation != null ? ' - ${operation.shopSourceDesignation}' : ''}'),
              if (operation.shopDestinationId != null)
                _buildDetailRow('Shop Destination', 'ID: ${operation.shopDestinationId}${operation.shopDestinationDesignation != null ? ' - ${operation.shopDestinationDesignation}' : ''}'),
              const Divider(),
              _buildDetailRow('Agent', operation.agentUsername ?? 'ID: ${operation.agentId}'),
              const Divider(),
              if (operation.clientNom != null)
                _buildDetailRow('Client', operation.clientNom!),
              if (operation.destinataire != null)
                _buildDetailRow('Destinataire', operation.destinataire!),
              if (operation.telephoneDestinataire != null)
                _buildDetailRow('Téléphone', operation.telephoneDestinataire!),
              const Divider(),
              _buildDetailRow('Mode Paiement', operation.modePaiementLabel),
              _buildDetailRow('Statut', operation.statutLabel),
              const Divider(),
              _buildDetailRow('Date Opération', _formatDate(operation.dateOp)),
              if (operation.dateValidation != null)
                _buildDetailRow('Date Validation', _formatDate(operation.dateValidation!)),
              if (operation.createdAt != null)
                _buildDetailRow('Créé le', _formatDate(operation.createdAt!)),
              if (operation.lastModifiedAt != null)
                _buildDetailRow('Modifié le', _formatDate(operation.lastModifiedAt!)),
              if (operation.lastModifiedBy != null)
                _buildDetailRow('Modifié par', operation.lastModifiedBy!),
              if (operation.notes != null && operation.notes!.isNotEmpty) ...[
                const Divider(),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(operation.notes!),
              ],
              if (operation.observation != null && operation.observation!.isNotEmpty) ...[
                const Divider(),
                const Text('Observation:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(operation.observation!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncStatus() {
    return Consumer<DeletionService>(
      builder: (context, service, _) {
        return Container(
          padding: const EdgeInsets.all(8),
          color: service.isAutoSyncEnabled ? Colors.green.shade100 : Colors.grey.shade200,
          child: Row(
            children: [
              Icon(
                service.isAutoSyncEnabled ? Icons.sync : Icons.sync_disabled,
                color: service.isAutoSyncEnabled ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                service.isAutoSyncEnabled 
                    ? 'Auto-sync: Actif (2 min)' 
                    : 'Auto-sync: Inactif',
              ),
              const Spacer(),
              if (service.lastSyncTime != null)
                Text(
                  'Dernier sync: ${_formatTime(service.lastSyncTime!)}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getTypeLabel(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return 'Dépôt';
      case OperationType.retrait:
        return 'Retrait';
      case OperationType.transfertNational:
        return 'Transfert National';
      case OperationType.transfertInternationalSortant:
        return 'Transfert Sortant';
      case OperationType.transfertInternationalEntrant:
        return 'Transfert Entrant';
      case OperationType.flotShopToShop:
        return 'FLOT Shop-to-Shop';
      default:
        return type.name;
    }
  }

  Color _getTypeColor(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return Colors.green;
      case OperationType.retrait:
        return Colors.orange;
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        return Colors.red;
      case OperationType.transfertInternationalEntrant:
        return Colors.blue;
      case OperationType.flotShopToShop:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return Icons.add_circle;
      case OperationType.retrait:
        return Icons.remove_circle;
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        return Icons.send;
      case OperationType.transfertInternationalEntrant:
        return Icons.call_received;
      case OperationType.flotShopToShop:
        return Icons.local_shipping;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getStatusColor(DeletionRequestStatus statut) {
    switch (statut) {
      case DeletionRequestStatus.enAttente:
        return Colors.orange.shade200;
      case DeletionRequestStatus.adminValidee:
      case DeletionRequestStatus.agentValidee:
        return Colors.green.shade200;
      case DeletionRequestStatus.refusee:
        return Colors.red.shade200;
      case DeletionRequestStatus.annulee:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(DeletionRequestStatus statut) {
    switch (statut) {
      case DeletionRequestStatus.enAttente:
        return Colors.orange;
      case DeletionRequestStatus.adminValidee:
      case DeletionRequestStatus.agentValidee:
        return Colors.green;
      case DeletionRequestStatus.refusee:
        return Colors.red;
      case DeletionRequestStatus.annulee:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
