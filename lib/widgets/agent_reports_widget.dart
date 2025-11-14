import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';
import '../models/operation_model.dart';
import '../utils/responsive_utils.dart';

class AgentReportsWidget extends StatefulWidget {
  const AgentReportsWidget({super.key});

  @override
  State<AgentReportsWidget> createState() => _AgentReportsWidgetState();
}

class _AgentReportsWidgetState extends State<AgentReportsWidget> {
  String _selectedPeriod = 'today'; // today, week, month, year

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null && currentUser?.shopId != null) {
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId!);
      // Charger TOUS les clients (globaux - accessible depuis tous les shops)
      Provider.of<ClientService>(context, listen: false).loadClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    
    return SingleChildScrollView(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      child: Column(
        children: [
          // Header avec sélection de période
          _buildHeader(),
          SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),
          
          // Statistiques générales
          _buildGeneralStats(),
          SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),
          
          // Graphiques et détails - Responsive layout
          if (isMobile)
            // Mobile: Stack vertical
            Column(
              children: [
                _buildTransactionStats(),
                const SizedBox(height: 16),
                _buildClientStats(),
              ],
            )
          else
            // Tablet/Desktop: Row horizontal
            SizedBox(
              height: 500,
              child: Row(
                children: [
                  Expanded(child: _buildTransactionStats()),
                  SizedBox(width: isTablet ? 16 : 24),
                  Expanded(child: _buildClientStats()),
                ],
              ),
            ),
          SizedBox(height: isMobile ? 16 : isTablet ? 20 : 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = context.isMobile;
    
    return Card(
      child: Padding(
        padding: context.fluidPadding(
          mobile: const EdgeInsets.all(16),
          tablet: const EdgeInsets.all(18),
          desktop: const EdgeInsets.all(20),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapports & Statistiques',
                    style: TextStyle(
                      fontSize: context.fluidFont(mobile: 18, tablet: 22, desktop: 24),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sélecteur de période
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                        DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
                        DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                        DropdownMenuItem(value: 'year', child: Text('Cette année')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPeriod = value ?? 'today';
                        });
                      },
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rapports & Statistiques',
                    style: TextStyle(
                      fontSize: context.fluidFont(mobile: 18, tablet: 22, desktop: 24),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  
                  // Sélecteur de période
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                        DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
                        DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                        DropdownMenuItem(value: 'year', child: Text('Cette année')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPeriod = value ?? 'today';
                        });
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGeneralStats() {
    final isMobile = context.isMobile;
    
    return Consumer2<OperationService, ClientService>(
      builder: (context, operationService, clientService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null) {
          return const SizedBox.shrink();
        }
        
        final operationStats = _getOperationStats(operationService, currentUser!.id!);
        final clientStats = _getClientStats(clientService, currentUser.shopId ?? 0);
        
        return Card(
          child: Padding(
            padding: context.fluidPadding(
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(18),
              desktop: const EdgeInsets.all(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vue d\'ensemble',
                  style: TextStyle(
                    fontSize: context.fluidFont(mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF374151),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                
                // Mobile: Grid 2x2, Desktop: Row 1x4
                isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              _buildStatCard(
                                'Clients Actifs',
                                '${clientStats['activeClients']}',
                                Icons.people,
                                Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Opérations',
                                '${operationStats['totalTransactions']}',
                                Icons.swap_horiz,
                                Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                'Volume',
                                '${operationStats['totalMontant'].toStringAsFixed(0)}\u0024',
                                Icons.attach_money,
                                Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Commissions',
                                '${operationStats['totalCommissions'].toStringAsFixed(0)}\u0024',
                                Icons.trending_up,
                                Colors.purple,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          _buildStatCard(
                            'Clients Actifs',
                            '${clientStats['activeClients']}',
                            Icons.people,
                            Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Opérations Totales',
                            '${operationStats['totalTransactions']}',
                            Icons.swap_horiz,
                            Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Volume Total',
                            '${operationStats['totalMontant'].toStringAsFixed(0)} USD',
                            Icons.attach_money,
                            Colors.orange,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Commissions Gagnées',
                            '${operationStats['totalCommissions'].toStringAsFixed(0)} USD',
                            Icons.trending_up,
                            Colors.purple,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isMobile = context.isMobile;
    
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 16 : 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 11 : 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionStats() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null) {
          return const Card(
            child: Center(child: Text('Données non disponibles')),
          );
        }
        
        final stats = _getOperationStats(operationService, currentUser!.id!);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Répartition des Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Types d'opérations
                  _buildTransactionTypeItem('Transferts', stats['transferts'], Colors.red),
                  const SizedBox(height: 12),
                  _buildTransactionTypeItem('Dépôts', stats['depots'], Colors.green),
                  const SizedBox(height: 12),
                  _buildTransactionTypeItem('Retraits', stats['retraits'], Colors.orange),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  // Montant moyen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Montant moyen par transaction:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${stats['montantMoyen'].toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionTypeItem(String type, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            type,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientStats() {
    return Consumer<ClientService>(
      builder: (context, clientService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.shopId == null) {
          return const Card(
            child: Center(child: Text('Données non disponibles')),
          );
        }
        
        final stats = clientService.getClientsStats(currentUser!.shopId!);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Statistiques Clients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Graphique en barres simple
                  _buildClientBar('Total Clients', stats['totalClients'], stats['totalClients'], Colors.blue),
                  const SizedBox(height: 16),
                  _buildClientBar('Clients Actifs', stats['activeClients'], stats['totalClients'], Colors.green),
                  const SizedBox(height: 16),
                  _buildClientBar('Avec Comptes', stats['withAccounts'], stats['totalClients'], Colors.orange),
                  const SizedBox(height: 16),
                  _buildClientBar('Sans Comptes', stats['withoutAccounts'], stats['totalClients'], Colors.grey),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  // Taux de conversion
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Taux de création de comptes:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        stats['totalClients'] > 0 
                            ? '${((stats['withAccounts'] / stats['totalClients']) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientBar(String label, int value, int maxValue, Color color) {
    final percentage = maxValue > 0 ? value / maxValue : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Calculer les statistiques des clients
  Map<String, dynamic> _getClientStats(ClientService clientService, int shopId) {
    final clients = clientService.clients.where((c) => c.shopId == shopId).toList();
    final activeClients = clients.where((c) => c.isActive).length;
    
    return {
      'totalClients': clients.length,
      'activeClients': activeClients,
      'inactiveClients': clients.length - activeClients,
    };
  }

  // Calculer les statistiques des opérations selon la période
  Map<String, dynamic> _getOperationStats(OperationService operationService, int agentId) {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    final periodOperations = operationService.operations.where((op) => 
      op.agentId == agentId &&
      op.dateOp.isAfter(startDate.subtract(const Duration(days: 1)))
    ).toList();

    final totalMontant = periodOperations.fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final totalCommissions = periodOperations.fold<double>(0.0, (sum, op) => sum + op.commission);
    
    // Compter par type d'opération
    final depots = periodOperations.where((op) => op.type == OperationType.depot).length;
    final retraits = periodOperations.where((op) => op.type == OperationType.retrait).length;
    final transferts = periodOperations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).length;

    return {
      'totalTransactions': periodOperations.length,
      'totalMontant': totalMontant,
      'totalCommissions': totalCommissions,
      'depots': depots,
      'retraits': retraits,
      'transferts': transferts,
      'montantMoyen': periodOperations.isNotEmpty ? totalMontant / periodOperations.length : 0.0,
    };
  }
}
