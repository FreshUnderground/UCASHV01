import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../models/operation_model.dart';

class ClientTransactionHistory extends StatefulWidget {
  final int? limit;
  
  const ClientTransactionHistory({super.key, this.limit});

  @override
  State<ClientTransactionHistory> createState() => _ClientTransactionHistoryState();
}

class _ClientTransactionHistoryState extends State<ClientTransactionHistory> {
  String _filterType = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, OperationService>(
      builder: (context, authService, operationService, child) {
        final client = authService.currentClient;
        if (client == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune information partenaire disponible'),
            ),
          );
        }

        // Filtrer les opérations du client
        var clientOperations = operationService.operations
            .where((op) => op.clientId == client.id)
            .toList();

        // Appliquer les filtres
        clientOperations = _applyFilters(clientOperations);

        // Limiter si nécessaire
        if (widget.limit != null && clientOperations.length > widget.limit!) {
          clientOperations = clientOperations.take(widget.limit!).toList();
        }

        return Card(
          child: Column(
            children: [
              // Filtres (seulement si pas de limite)
              if (widget.limit == null) _buildFilters(),
              
              // Liste des transactions
              if (operationService.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (clientOperations.isEmpty)
                _buildEmptyState()
              else
                _buildTransactionsList(clientOperations),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Première ligne de filtres
          Row(
            children: [
              // Recherche
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Filtre par type
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'depot', child: Text('Dépôts')),
                    DropdownMenuItem(value: 'retrait', child: Text('Retraits')),
                    DropdownMenuItem(value: 'transfer_sent', child: Text('Envoyés')),
                    DropdownMenuItem(value: 'transfer_received', child: Text('Reçus')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterType = value ?? 'all';
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Deuxième ligne - Filtres de date
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null 
                              ? 'Du: ${_formatDate(_startDate!)}'
                              : 'Date de début',
                          style: TextStyle(
                            color: _startDate != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _endDate != null 
                              ? 'Au: ${_formatDate(_endDate!)}'
                              : 'Date de fin',
                          style: TextStyle(
                            color: _endDate != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune transaction trouvée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos transactions apparaîtront ici',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<OperationModel> operations) {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: operations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final operation = operations[index];
          return _buildTransactionItem(operation);
        },
      ),
    );
  }

  Widget _buildTransactionItem(OperationModel operation) {
    final isCredit = _isCredit(operation);
    final color = isCredit ? Colors.green : Colors.red;
    final icon = _getOperationIcon(operation.type);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        _getOperationTitle(operation.type),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateTime(operation.dateOp),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (operation.destinataire != null && operation.destinataire!.isNotEmpty)
            Text(
              'Destinataire: ${operation.destinataire}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(operation.statut).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getStatusLabel(operation.statut),
              style: TextStyle(
                color: _getStatusColor(operation.statut),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isCredit ? '+' : '-'}${operation.montantNet.toStringAsFixed(2)} USD',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (operation.commission > 0)
            Text(
              'Commission: ${operation.commission.toStringAsFixed(2)} USD',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
        ],
      ),
      onTap: () => _showTransactionDetails(operation),
    );
  }

  List<OperationModel> _applyFilters(List<OperationModel> operations) {
    var filtered = operations;

    // Filtre par type
    if (_filterType != 'all') {
      switch (_filterType) {
        case 'depot':
          filtered = filtered.where((op) => op.type == OperationType.depot).toList();
          break;
        case 'retrait':
          filtered = filtered.where((op) => op.type == OperationType.retrait).toList();
          break;
        case 'transfer_sent':
          filtered = filtered.where((op) => 
              op.type == OperationType.transfertNational ||
              op.type == OperationType.transfertInternationalSortant).toList();
          break;
        case 'transfer_received':
          filtered = filtered.where((op) => 
              op.type == OperationType.transfertInternationalEntrant).toList();
          break;
      }
    }

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((op) => 
          (op.destinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          op.id.toString().contains(_searchQuery) ||
          op.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) == true).toList();
    }

    // Filtre par date
    if (_startDate != null) {
      filtered = filtered.where((op) => op.dateOp.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((op) => op.dateOp.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }

    // Trier par date décroissante
    filtered.sort((a, b) => b.dateOp.compareTo(a.dateOp));

    return filtered;
  }

  bool _isCredit(OperationModel operation) {
    return operation.type == OperationType.depot ||
           operation.type == OperationType.transfertInternationalEntrant;
  }

  IconData _getOperationIcon(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return Icons.add_circle;
      case OperationType.retrait:
      case OperationType.retraitMobileMoney:
        return Icons.remove_circle;
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        return Icons.send;
      case OperationType.transfertInternationalEntrant:
        return Icons.call_received;
      case OperationType.virement:
        return Icons.swap_horiz;
    }
  }

  String _getOperationTitle(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return 'Dépôt';
      case OperationType.retrait:
        return 'Retrait';
      case OperationType.retraitMobileMoney:
        return 'Retrait Mobile Money';
      case OperationType.transfertNational:
        return 'Transfert National';
      case OperationType.transfertInternationalSortant:
        return 'Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return 'Transfert International Entrant';
      case OperationType.virement:
        return 'Virement';
    }
  }

  Color _getStatusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return Colors.orange;
      case OperationStatus.validee:
        return Colors.green;
      case OperationStatus.terminee:
        return Colors.green;
      case OperationStatus.annulee:
        return Colors.red;
    }
  }

  String _getStatusLabel(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return 'EN ATTENTE';
      case OperationStatus.validee:
        return 'VALIDÉE';
      case OperationStatus.terminee:
        return 'TERMINÉE';
      case OperationStatus.annulee:
        return 'ANNULÉE';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterType = 'all';
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
    });
  }

  void _showTransactionDetails(OperationModel operation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ${_getOperationTitle(operation.type)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID Transaction', operation.id.toString()),
              _buildDetailRow('Date', _formatDateTime(operation.dateOp)),
              _buildDetailRow('Type', _getOperationTitle(operation.type)),
              _buildDetailRow('Montant brut', '${operation.montantBrut.toStringAsFixed(2)} USD'),
              if (operation.commission > 0)
                _buildDetailRow('Commission', '${operation.commission.toStringAsFixed(2)} USD'),
              _buildDetailRow('Montant net', '${operation.montantNet.toStringAsFixed(2)} USD'),
              _buildDetailRow('Mode de paiement', operation.modePaiementLabel),
              if (operation.destinataire != null && operation.destinataire!.isNotEmpty)
                _buildDetailRow('Destinataire', operation.destinataire!),
              _buildDetailRow('Statut', _getStatusLabel(operation.statut)),
              if (operation.notes != null && operation.notes!.isNotEmpty)
                _buildDetailRow('Notes', operation.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
