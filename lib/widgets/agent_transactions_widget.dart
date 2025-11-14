import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/transaction_service.dart';
import '../services/auth_service.dart';
import '../models/transaction_model.dart';
import 'create_transaction_dialog_responsive.dart';

class AgentTransactionsWidget extends StatefulWidget {
  const AgentTransactionsWidget({super.key});

  @override
  State<AgentTransactionsWidget> createState() => _AgentTransactionsWidgetState();
}

class _AgentTransactionsWidgetState extends State<AgentTransactionsWidget> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, EN_ATTENTE, CONFIRMEE, TERMINEE, ANNULEE

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  void _loadTransactions() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null) {
      Provider.of<TransactionService>(context, listen: false).loadTransactions(agentId: currentUser!.id!);
    }
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    return transactions.where((transaction) {
      final matchesSearch = _searchQuery.isEmpty ||
          (transaction.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (transaction.nomDestinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      final matchesStatus = _statusFilter == 'all' || transaction.statut == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec recherche et filtres
        _buildHeader(),
        const SizedBox(height: 16),
        
        // Statistiques
        _buildStats(),
        const SizedBox(height: 16),
        
        // Liste des transactions
        Expanded(child: _buildTransactionsList()),
      ],
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
                  'Mes Transactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateTransactionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle Transaction'),
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
                      hintText: 'Rechercher par référence ou destinataire...',
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
                      DropdownMenuItem(value: 'CONFIRMEE', child: Text('Confirmée')),
                      DropdownMenuItem(value: 'TERMINEE', child: Text('Terminée')),
                      DropdownMenuItem(value: 'ANNULEE', child: Text('Annulée')),
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
                  onPressed: _loadTransactions,
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

  Widget _buildStats() {
    return Consumer<TransactionService>(
      builder: (context, transactionService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null) {
          return const SizedBox.shrink();
        }
        
        final stats = transactionService.getTransactionStats(agentId: currentUser!.id!);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Transactions',
                  '${stats['totalTransactions']}',
                  Icons.swap_horiz,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Aujourd\'hui',
                  '${stats['transactionsToday']}',
                  Icons.today,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Montant Total',
                  '${stats['totalMontant'].toStringAsFixed(0)} USD',
                  Icons.attach_money,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Commissions',
                  '${stats['totalCommissions'].toStringAsFixed(0)} USD',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildTransactionsList() {
    return Consumer<TransactionService>(
      builder: (context, transactionService, child) {
        if (transactionService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (transactionService.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${transactionService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadTransactions,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final filteredTransactions = _filterTransactions(transactionService.transactions);

        if (filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz_outlined, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  transactionService.transactions.isEmpty 
                      ? 'Aucune transaction effectuée'
                      : 'Aucune transaction trouvée avec ces critères',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cliquez sur "Nouvelle Transaction" pour créer une transaction',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateTransactionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle Transaction'),
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
            itemCount: filteredTransactions.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final transaction = filteredTransactions[index];
              return _buildTransactionItem(transaction);
            },
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    Color statusColor;
    IconData statusIcon;
    
    switch (transaction.statut) {
      case 'EN_ATTENTE':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'CONFIRMEE':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'TERMINEE':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ANNULEE':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(statusIcon, color: statusColor),
      ),
      title: Text(
        '${transaction.typeDisplay} - ${transaction.reference ?? 'N/A'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Montant: ${transaction.montant.toStringAsFixed(2)} ${transaction.deviseSource}'),
          if (transaction.nomDestinataire != null)
            Text('Destinataire: ${transaction.nomDestinataire}'),
          if (transaction.telephoneDestinataire != null)
            Text('Tél: ${transaction.telephoneDestinataire}'),
          Text(
            'Statut: ${transaction.statutDisplay}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (transaction.createdAt != null)
            Text(
              'Créé le: ${transaction.createdAt!.day}/${transaction.createdAt!.month}/${transaction.createdAt!.year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
          if (transaction.statut == 'EN_ATTENTE')
            const PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: [
                  Icon(Icons.cancel, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Annuler', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
        onSelected: (value) => _handleTransactionAction(value, transaction),
      ),
    );
  }

  void _handleTransactionAction(String action, TransactionModel transaction) {
    switch (action) {
      case 'details':
        _showTransactionDetails(transaction);
        break;
      case 'cancel':
        _cancelTransaction(transaction);
        break;
    }
  }

  void _showCreateTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateTransactionDialogResponsive(),
    ).then((result) {
      if (result == true) {
        _loadTransactions();
      }
    });
  }

  void _showTransactionDetails(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ${transaction.reference}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${transaction.typeDisplay}'),
            Text('Montant: ${transaction.montant} ${transaction.deviseSource}'),
            if (transaction.deviseSource != transaction.deviseDestination)
              Text('Converti: ${transaction.montantConverti} ${transaction.deviseDestination}'),
            Text('Commission: ${transaction.commission} ${transaction.deviseSource}'),
            Text('Total: ${transaction.montantTotal} ${transaction.deviseSource}'),
            if (transaction.nomDestinataire != null)
              Text('Destinataire: ${transaction.nomDestinataire}'),
            Text('Statut: ${transaction.statutDisplay}'),
            if (transaction.notes != null)
              Text('Notes: ${transaction.notes}'),
          ],
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

  Future<void> _cancelTransaction(TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la transaction'),
        content: Text(
          'Êtes-vous sûr de vouloir annuler la transaction "${transaction.reference}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler la transaction'),
          ),
        ],
      ),
    );

    if (confirmed == true && transaction.id != null) {
      final transactionService = Provider.of<TransactionService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await transactionService.cancelTransaction(transaction.id!, authService.currentUser?.shopId ?? 0);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction annulée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
