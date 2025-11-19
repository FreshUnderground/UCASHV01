import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/responsive_utils.dart';
import '../services/transaction_service.dart';
import '../services/auth_service.dart';
import '../services/rates_service.dart';
import '../models/transaction_model.dart';
import 'change_devise_dialog.dart';

class ChangeDeviseWidget extends StatefulWidget {
  const ChangeDeviseWidget({super.key});

  @override
  State<ChangeDeviseWidget> createState() => _ChangeDeviseWidgetState();
}

class _ChangeDeviseWidgetState extends State<ChangeDeviseWidget> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _deviseFilter = 'all'; // all, USD, CDF, UGX

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
      // Recharger les taux au démarrage
      Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
    });
  }

  void _loadTransactions() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    debugPrint('🔄 ChangeDeviseWidget: Chargement des transactions pour agent ID: ${currentUser?.id}');
    if (currentUser?.id != null) {
      Provider.of<TransactionService>(context, listen: false).loadTransactions(agentId: currentUser!.id!);
    } else {
      debugPrint('❌ ChangeDeviseWidget: Aucun utilisateur connecté');
      // Charger toutes les transactions si pas d'agent spécifique
      Provider.of<TransactionService>(context, listen: false).loadTransactions();
    }
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    return transactions.where((transaction) {
      final matchesSearch = _searchQuery.isEmpty ||
          (transaction.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (transaction.nomDestinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      final matchesStatus = _statusFilter == 'all' || transaction.statut == _statusFilter;
      
      final matchesDevise = _deviseFilter == 'all' || 
          transaction.deviseSource == _deviseFilter || 
          transaction.deviseDestination == _deviseFilter;
      
      return matchesSearch && matchesStatus && matchesDevise;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          _buildStats(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          Expanded(child: _buildTransactionsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 16),
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(16),
          tablet: const EdgeInsets.all(20),
          desktop: const EdgeInsets.all(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
                    ),
                  ),
                  child: Icon(
                    Icons.currency_exchange,
                    color: const Color(0xFF2196F3),
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 24, tablet: 28, desktop: 32),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change de Devises',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 3, tablet: 4, desktop: 5)),
                      Text(
                        'Gérez vos opérations de change USD ↔ CDF ↔ UGX',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!context.isSmallScreen)
                  ElevatedButton.icon(
                    onPressed: _showCreateChangeDialog,
                    icon: Icon(
                      Icons.add, 
                      size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                    label: Text(
                      'Nouveau Change',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (context.isSmallScreen)
              Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                  ElevatedButton.icon(
                    onPressed: _showCreateChangeDialog,
                    icon: Icon(
                      Icons.add, 
                      size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                    label: Text(
                      'Nouveau Change',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
            const Divider(),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            
            // Filtres
            if (context.isSmallScreen)
              Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher par référence, destinataire...',
                      prefixIcon: Icon(
                        Icons.search, 
                        color: const Color(0xFF2196F3),
                        size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _deviseFilter,
                          decoration: InputDecoration(
                            labelText: 'Devise',
                            prefixIcon: Icon(
                              Icons.attach_money, 
                              color: const Color(0xFF2196F3),
                              size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Toutes')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                            DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _deviseFilter = value ?? 'all';
                            });
                          },
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Statut',
                            prefixIcon: Icon(
                              Icons.filter_list, 
                              color: const Color(0xFF2196F3),
                              size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
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
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _loadTransactions,
                        icon: Icon(
                          Icons.refresh,
                          color: const Color(0xFF2196F3),
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                        tooltip: 'Actualiser',
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher par référence, destinataire...',
                        prefixIcon: Icon(
                          Icons.search, 
                          color: const Color(0xFF2196F3),
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deviseFilter,
                      decoration: InputDecoration(
                        labelText: 'Devise',
                        prefixIcon: Icon(
                          Icons.attach_money, 
                          color: const Color(0xFF2196F3),
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Toutes')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                        DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _deviseFilter = value ?? 'all';
                        });
                      },
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: Icon(
                          Icons.filter_list, 
                          color: const Color(0xFF2196F3),
                          size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                  SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  
                  IconButton(
                    onPressed: _loadTransactions,
                    icon: Icon(
                      Icons.refresh, 
                      color: const Color(0xFF2196F3),
                      size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    ),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Consumer2<TransactionService, RatesService>(
      builder: (context, transactionService, ratesService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null) {
          return const SizedBox.shrink();
        }
        
        final stats = transactionService.getTransactionStats(agentId: currentUser!.id!);
        
        // Récupérer les taux actuels
        final tauxUSDtoCDF = ratesService.getTauxByDeviseAndType('CDF', 'MOYEN');
        final tauxUSDtoUGX = ratesService.getTauxByDeviseAndType('UGX', 'MOYEN');
        
        return Card(
          elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 16),
            ),
          ),
          child: Padding(
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(20),
              desktop: const EdgeInsets.all(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistiques & Taux du Jour',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                if (context.isSmallScreen)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Changes',
                              '${stats['totalTransactions']}',
                              Icons.swap_horiz,
                              const Color(0xFF2196F3),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                          Expanded(
                            child: _buildStatCard(
                              'Aujourd\'hui',
                              '${stats['transactionsToday']}',
                              Icons.today,
                              const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Montant Total',
                              '${stats['totalMontant'].toStringAsFixed(0)} USD',
                              Icons.monetization_on,
                              const Color(0xFFFF9800),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                          Expanded(
                            child: _buildStatCard(
                              'Commissions',
                              '${stats['totalCommissions'].toStringAsFixed(0)} USD',
                              Icons.trending_up,
                              const Color(0xFF9C27B0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Changes',
                          '${stats['totalTransactions']}',
                          Icons.swap_horiz,
                          const Color(0xFF2196F3),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                      Expanded(
                        child: _buildStatCard(
                          'Aujourd\'hui',
                          '${stats['transactionsToday']}',
                          Icons.today,
                          const Color(0xFF4CAF50),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                      Expanded(
                        child: _buildStatCard(
                          'Montant Total',
                          '${stats['totalMontant'].toStringAsFixed(0)} USD',
                          Icons.monetization_on,
                          const Color(0xFFFF9800),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                      Expanded(
                        child: _buildStatCard(
                          'Commissions',
                          '${stats['totalCommissions'].toStringAsFixed(0)} USD',
                          Icons.trending_up,
                          const Color(0xFF9C27B0),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                const Divider(),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                
                // Taux de change actuels
                if (context.isSmallScreen)
                  Column(
                    children: [
                      _buildTauxCard(
                        'USD → CDF',
                        tauxUSDtoCDF != null ? '1 USD = ${tauxUSDtoCDF.taux.toStringAsFixed(2)} CDF' : 'Non configuré',
                        Icons.arrow_forward,
                        Colors.green,
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                      _buildTauxCard(
                        'USD → UGX',
                        tauxUSDtoUGX != null ? '1 USD = ${tauxUSDtoUGX.taux.toStringAsFixed(0)} UGX' : 'Non configuré',
                        Icons.arrow_forward,
                        Colors.orange,
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTauxCard(
                        'USD → CDF',
                        tauxUSDtoCDF != null ? '1 USD = ${tauxUSDtoCDF.taux.toStringAsFixed(2)} CDF' : 'Non configuré',
                        Icons.arrow_forward,
                        Colors.green,
                      ),
                      _buildTauxCard(
                        'USD → UGX',
                        tauxUSDtoUGX != null ? '1 USD = ${tauxUSDtoUGX.taux.toStringAsFixed(0)} UGX' : 'Non configuré',
                        Icons.arrow_forward,
                        Colors.orange,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 8, desktop: 10),
            offset: Offset(0, ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4)),
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(12),
          tablet: const EdgeInsets.all(14),
          desktop: const EdgeInsets.all(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 4, tablet: 6, desktop: 8),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 20, desktop: 24),
                  ),
                ),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 18, desktop: 20),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 12, desktop: 13),
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTauxCard(String title, String taux, IconData icon, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 8, desktop: 10),
            offset: Offset(0, ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4)),
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: color, 
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 20, desktop: 24),
            ),
            SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 8, desktop: 10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 12, desktop: 13),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4)),
                Text(
                  taux,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Consumer<TransactionService>(
      builder: (context, transactionService, child) {
        debugPrint('📊 ChangeDeviseWidget: Nombre total de transactions: ${transactionService.transactions.length}');
        final filteredTransactions = _filterTransactions(transactionService.transactions);
        debugPrint('📊 ChangeDeviseWidget: Transactions filtrées: ${filteredTransactions.length}');

        if (transactionService.isLoading) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (filteredTransactions.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.currency_exchange_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      transactionService.transactions.isEmpty 
                          ? 'Aucune transaction de change'
                          : 'Aucun change trouvé avec ces filtres',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliquez sur "Nouveau Change" pour commencer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Historique des Changes (${filteredTransactions.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTransactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  color: Color(0xFF2196F3),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.typeDisplay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Réf: ${transaction.reference ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      transaction.statutDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  Icons.person_outline,
                  'Destinataire',
                  transaction.nomDestinataire ?? 'Non spécifié',
                ),
              ),
              Expanded(
                child: _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt ?? DateTime.now()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant envoyé:',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(
                      '${transaction.montant.toStringAsFixed(2)} ${transaction.deviseSource}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux de change:',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '1 ${transaction.deviseSource} = ${transaction.tauxChange.toStringAsFixed(2)} ${transaction.deviseDestination}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant converti:',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(
                      '${transaction.montantConverti.toStringAsFixed(2)} ${transaction.deviseDestination}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                if (transaction.commission > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Commission:',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      Text(
                        '${transaction.commission.toStringAsFixed(2)} ${transaction.deviseSource}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFFF9800)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  void _showCreateChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => const ChangeDeviseDialog(),
    ).then((_) {
      // Recharger les transactions après fermeture du dialogue
      _loadTransactions();
    });
  }
}
