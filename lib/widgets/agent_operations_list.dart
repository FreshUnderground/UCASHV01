import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../services/operation_service.dart';
import '../models/operation_model.dart';

class AgentOperationsList extends StatelessWidget {
  const AgentOperationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AgentAuthService, OperationService>(
      builder: (context, authService, operationService, child) {
        if (authService.currentAgent == null) {
          return const SizedBox.shrink();
        }

        final operations = operationService.operations
            .where((op) => op.agentId == authService.currentAgent!.id)
            .take(10)
            .toList();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.list_alt,
                      color: Color(0xFF1976D2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dernières Opérations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        Text(
                          'Les 10 dernières transactions effectuées',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Navigation vers la liste complète des opérations
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Voir tout'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (operations.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune opération récente',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les opérations que vous effectuez apparaîtront ici',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: operations.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final operation = operations[index];
                    return _buildOperationTile(operation);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperationTile(OperationModel operation) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getOperationColor(operation.type).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getOperationIcon(operation.type),
          color: _getOperationColor(operation.type),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              operation.typeLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(operation.statut).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              operation.statutLabel,
              style: TextStyle(
                color: _getStatusColor(operation.statut),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (operation.destinataire != null)
            Text(
              'Destinataire: ${operation.destinataire}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                _formatDateTime(operation.dateOp),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  operation.modePaiementLabel,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_formatCurrency(operation.montantNet)} ${operation.devise}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _getAmountColor(operation.type),
            ),
          ),
          if (operation.commission > 0)
            Text(
              'Commission: ${_formatCurrency(operation.commission)} ${operation.devise}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getOperationIcon(OperationType type) {
    switch (type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
      case OperationType.transfertInternationalEntrant:
        return Icons.send;
      case OperationType.depot:
        return Icons.arrow_downward;
      case OperationType.retrait:
      case OperationType.retraitMobileMoney:
        return Icons.arrow_upward;
      case OperationType.virement:
        return Icons.swap_horiz;
    }
  }

  Color _getOperationColor(OperationType type) {
    switch (type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
      case OperationType.transfertInternationalEntrant:
        return const Color(0xFF1976D2);
      case OperationType.depot:
        return const Color(0xFF388E3C);
      case OperationType.retrait:
      case OperationType.retraitMobileMoney:
        return const Color(0xFFFF9800);
      case OperationType.virement:
        return const Color(0xFF9C27B0);
    }
  }

  Color _getStatusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return const Color(0xFFFF9800);
      case OperationStatus.validee:
        return const Color(0xFF388E3C);
      case OperationStatus.terminee:
        return const Color(0xFF388E3C);
      case OperationStatus.annulee:
        return const Color(0xFFDC2626);
    }
  }

  Color _getAmountColor(OperationType type) {
    switch (type) {
      case OperationType.depot:
      case OperationType.transfertInternationalEntrant:
        return const Color(0xFF388E3C); // Vert pour les entrées
      case OperationType.retrait:
      case OperationType.retraitMobileMoney:
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        return const Color(0xFFDC2626); // Rouge pour les sorties
      case OperationType.virement:
        return const Color(0xFF1976D2); // Bleu pour les virements
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Aujourd\'hui ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hier ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} jours';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
