import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import 'transfer_destination_dialog.dart';
import '../services/auth_service.dart';
import '../models/operation_model.dart';
import '../services/client_service.dart';
import 'simple_transfer_dialog.dart';

class AgentTransfersWidget extends StatefulWidget {
  const AgentTransfersWidget({super.key});

  @override
  State<AgentTransfersWidget> createState() => _AgentTransfersWidgetState();
}

class _AgentTransfersWidgetState extends State<AgentTransfersWidget> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOperations();
    });
  }
  
  void _loadOperations() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null) {
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId);
    }
  }
  
  List<OperationModel> _getFilteredTransfers(OperationService operationService, AuthService authService) {
    final currentUser = authService.currentUser;
    if (currentUser == null) return [];
    
    // Filtrer les transferts (nationaux et internationaux)
    var transfers = operationService.operations.where((op) {
      return (op.type == OperationType.transfertNational ||
              op.type == OperationType.transfertInternationalSortant ||
              op.type == OperationType.transfertInternationalEntrant) &&
             op.agentId == currentUser.id;
    }).toList();
    
    // Appliquer les filtres de recherche
    if (_searchQuery.isNotEmpty) {
      transfers = transfers.where((op) {
        final dest = op.destinataire?.toLowerCase() ?? '';
        final id = op.id?.toString() ?? '';
        return dest.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery);
      }).toList();
    }
    
    // Appliquer le filtre de statut
    if (_statusFilter != 'all') {
      transfers = transfers.where((op) {
        switch (_statusFilter) {
          case 'EN_ATTENTE':
            return op.statut == OperationStatus.enAttente;
          case 'VALIDEE':
            return op.statut == OperationStatus.validee;
          default:
            return true;
        }
      }).toList();
    }
    
    // Trier par date décroissante
    transfers.sort((a, b) => b.dateOp.compareTo(a.dateOp));
    
    return transfers;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final padding = isMobile ? 16.0 : (size.width <= 1024 ? 20.0 : 24.0);
    
    return Consumer2<OperationService, AuthService>(
      builder: (context, operationService, authService, child) {
        final transfers = _getFilteredTransfers(operationService, authService);
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec recherche et filtres
              _buildHeader(),
              const SizedBox(height: 16),
              
              // Statistiques
              _buildStats(transfers),
              const SizedBox(height: 16),
              
              // Liste des transferts - hauteur fixe
              SizedBox(
                height: 400,
                child: _buildTransfersList(transfers),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mes Transferts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTransfertDestinationDialog(),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Nouveau Transfert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Barre de recherche et filtres
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par destinataire ou référence...',
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
                
                // Filtre par statut
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(value: 'EN_ATTENTE', child: Text('En attente')),
                      DropdownMenuItem(value: 'VALIDEE', child: Text('Validée')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value ?? 'all';
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Bouton actualiser
                IconButton(
                  onPressed: () {
                    setState(() {
                      // Actualiser les données
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _showTransfertDestinationDialog() {
    showDialog(
      context: context,
      builder: (context) => const TransferDestinationDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }

  Widget _buildStats(List<OperationModel> transfers) {
    final totalTransfers = transfers.length;
    final totalMontant = transfers.fold<double>(0, (sum, t) => sum + t.montantBrut);
    final enAttente = transfers.where((t) => t.statut == OperationStatus.enAttente).length;
    final validees = transfers.where((t) => t.statut == OperationStatus.validee).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatCard(
              'Total Transferts',
              '$totalTransfers',
              Icons.send,
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Montant Total',
              '${totalMontant.toStringAsFixed(0)} USD',
              Icons.attach_money,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'En Attente',
              '$enAttente',
              Icons.hourglass_empty,
              Colors.orange,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Validées',
              '$validees',
              Icons.check_circle,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersList(List<OperationModel> transfers) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_outlined, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Aucun transfert trouvé',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cliquez sur "Nouveau Transfert" pour envoyer de l\'argent',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showTransfertDestinationDialog(),
              icon: const Icon(Icons.send),
              label: const Text('Nouveau Transfert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transfers.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final transfer = transfers[index];
          return _buildTransferItem(transfer);
        },
      ),
    );
  }

  Widget _buildTransferItem(OperationModel transfer) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (transfer.statut) {
      case OperationStatus.enAttente:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'En attente';
        break;
      case OperationStatus.validee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Validée';
        break;
      case OperationStatus.terminee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Terminée';
        break;
      case OperationStatus.annulee:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Annulée';
        break;
    }
    
    // Nom du type de transfert
    String typeText;
    switch (transfer.type) {
      case OperationType.transfertNational:
        typeText = 'National';
        break;
      case OperationType.transfertInternationalSortant:
        typeText = 'International Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeText = 'International Entrant';
        break;
      default:
        typeText = 'Transfert';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(statusIcon, color: statusColor),
      ),
      title: Text(
        'Transfert $typeText',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Montant: ${transfer.montantBrut.toStringAsFixed(2)} ${transfer.devise}'),
          Text('ID: ${transfer.id ?? "N/A"}'),
          Text(
            'Statut: $statusText',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Date: ${_formatDate(transfer.dateOp)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (transfer.notes != null && transfer.notes!.isNotEmpty)
            Text(
              'Note: ${transfer.notes}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'details',
            child: Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Text('Détails'),
              ],
            ),
          ),
        ],
        onSelected: (value) => _showTransferDetails(transfer),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showTransferDetails(OperationModel transfer) {
    // Type de transfert
    String typeText;
    switch (transfer.type) {
      case OperationType.transfertNational:
        typeText = 'National';
        break;
      case OperationType.transfertInternationalSortant:
        typeText = 'International Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeText = 'International Entrant';
        break;
      default:
        typeText = 'Transfert';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ID ${transfer.id ?? "N/A"}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', typeText),
              _buildDetailRow('Montant brut', '${transfer.montantBrut.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Montant net', '${transfer.montantNet.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Commission', '${transfer.commission.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Mode de paiement', _getModePaiementText(transfer.modePaiement)),
              _buildDetailRow('Statut', _getStatutText(transfer.statut)),
              _buildDetailRow('Date', _formatDate(transfer.dateOp)),
              _buildDetailRow('ID', transfer.id?.toString() ?? 'N/A'),
              if (transfer.notes != null && transfer.notes!.isNotEmpty)
                _buildDetailRow('Notes', transfer.notes!),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _getModePaiementText(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'M-Pesa';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }
  
  String _getStatutText(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return 'En attente';
      case OperationStatus.validee:
        return 'Validée';
      case OperationStatus.terminee:
        return 'Terminée';
      case OperationStatus.annulee:
        return 'Annulée';
    }
  }
}
