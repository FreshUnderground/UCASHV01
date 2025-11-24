// ignore_for_file: override_on_non_overriding_member

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';
import '../data/initial_rates_data.dart';
import 'commission_dialog_modern.dart';

class TauxCommissionsManagement extends StatefulWidget {
  const TauxCommissionsManagement({super.key});

  @override
  State<TauxCommissionsManagement> createState() => _TauxCommissionsManagementState();
}

class _TauxCommissionsManagementState extends State<TauxCommissionsManagement> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
    });
  }

  @override
  Future<void> onSyncCompleted() async {
    Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isMobile ? 'Taux & Commissions' : 'Gestion Taux & Commissions',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: isMobile ? [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              } else if (value == 'real_data') {
                _initializeRealData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Actualiser'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'real_data',
                child: Row(
                  children: [
                    Icon(Icons.data_usage, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Données Réelles'),
                  ],
                ),
              ),
            ],
          ),
        ] : [
          TextButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Actualiser', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _initializeRealData,
            icon: const Icon(Icons.data_usage),
            label: const Text('Données Réelles'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(isTablet),
      bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildMobileLayout() {
    return _selectedIndex == 0 ? _buildTauxContent() : _buildCommissionsContent();
  }

  Widget _buildDesktopLayout(bool isTablet) {
    return Row(
      children: [
        // Menu latéral adaptatif
        Container(
          width: isTablet ? 200 : 250,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: const Color(0xFFDC2626),
                      size: isTablet ? 20 : 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configuration',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              _buildMenuItem(0, Icons.currency_exchange, 'Taux de Change', isTablet),
              _buildMenuItem(1, Icons.percent, 'Commissions', isTablet),
            ],
          ),
        ),
        // Contenu principal
        Expanded(
          child: _selectedIndex == 0 ? _buildTauxContent() : _buildCommissionsContent(),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_exchange),
            label: 'Taux',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.percent),
            label: 'Commissions',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title, bool isTablet) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? const Color(0xFFDC2626).withOpacity(0.1) : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 16,
          vertical: isTablet ? 4 : 8,
        ),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFFDC2626) : Colors.grey,
          size: isTablet ? 20 : 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFFDC2626) : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: isTablet ? 13 : 14,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildTauxContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec titre et bouton
          _buildSectionHeader(
            title: 'Taux de Change',
            subtitle: 'Gérez les taux de change pour les devises',
            buttonText: 'Nouveau Taux',
            buttonIcon: Icons.add,
            onPressed: _showCreateTauxDialog,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Contenu principal
          Expanded(
            child: Consumer<RatesService>(
              builder: (context, ratesService, child) {
                if (ratesService.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFDC2626)),
                        SizedBox(height: 16),
                        Text('Chargement des taux...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final taux = ratesService.taux;
                      return _buildTauxList(taux, isMobile, isTablet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionsContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec titre et bouton
          _buildSectionHeader(
            title: 'Commissions',
            subtitle: 'Configurez les commissions pour les transferts',
            buttonText: 'Nouvelle Commission',
            buttonIcon: Icons.add,
            onPressed: _showCreateCommissionDialog,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Contenu principal
          Expanded(
            child: Consumer<RatesService>(
              builder: (context, ratesService, child) {
                if (ratesService.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFDC2626)),
                        SizedBox(height: 16),
                        Text('Chargement des commissions...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final commissions = ratesService.commissions;
                  return _buildCommissionsList(commissions, isMobile, isTablet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getDeviseColor(String devise) {
    switch (devise) {
      case 'USD': return Colors.green;
      case 'EUR': return Colors.blue;
      case 'GBP': return Colors.purple;
      case 'CAD': return Colors.red;
      case 'CHF': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'NATIONAL': return 'National';
      case 'INTERNATIONAL_ENTRANT': return 'International Entrant';
      case 'INTERNATIONAL_SORTANT': return 'International Sortant';
      default: return type;
    }
  }

  String _getCommissionTypeLabel(String type) {
    return type == 'ENTRANT' ? 'Entrant (vers RDC)' : 'Sortant (depuis RDC)';
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(buttonIcon),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(buttonIcon),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTauxList(List<TauxModel> taux, bool isMobile, bool isTablet) {
    if (isMobile) {
      return ListView.builder(
        itemCount: taux.length,
        itemBuilder: (context, index) {
          final tauxItem = taux[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getDeviseColor(tauxItem.deviseCible),
                        radius: 20,
                        child: Text(
                          tauxItem.deviseCible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tauxItem.taux.toStringAsFixed(0)} CDF',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getTypeLabel(tauxItem.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditTauxDialog(tauxItem),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifier'),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteTaux(tauxItem),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Supprimer'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    return ListView.builder(
      itemCount: taux.length,
      itemBuilder: (context, index) {
        final tauxItem = taux[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: isTablet ? 4 : 8,
            ),
            leading: CircleAvatar(
              backgroundColor: _getDeviseColor(tauxItem.deviseCible),
              child: Text(
                '${tauxItem.deviseSource}->${tauxItem.deviseCible}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
            title: Text('${tauxItem.taux.toStringAsFixed(0)} CDF'),
            subtitle: Text(_getTypeLabel(tauxItem.type)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showEditTauxDialog(tauxItem),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                ),
                IconButton(
                  onPressed: () => _deleteTaux(tauxItem),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommissionsList(List<CommissionModel> commissions, bool isMobile, bool isTablet) {
    if (isMobile) {
      return ListView.builder(
        itemCount: commissions.length,
        itemBuilder: (context, index) {
          final commission = commissions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: commission.type == 'ENTRANT' ? Colors.green : Colors.orange,
                        radius: 20,
                        child: Icon(
                          commission.type == 'ENTRANT' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commission.description,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getCommissionTypeLabel(commission.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: commission.type == 'ENTRANT' ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          commission.type == 'ENTRANT' ? 'GRATUIT' : '${commission.taux.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditCommissionDialog(commission),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifier'),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteCommission(commission),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Supprimer'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    return ListView.builder(
      itemCount: commissions.length,
      itemBuilder: (context, index) {
        final commission = commissions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: isTablet ? 4 : 8,
            ),
            leading: CircleAvatar(
              backgroundColor: commission.type == 'ENTRANT' ? Colors.green : Colors.orange,
              child: Icon(
                commission.type == 'ENTRANT' ? Icons.arrow_downward : Icons.arrow_upward,
                color: Colors.white,
              ),
            ),
            title: Text(commission.description),
            subtitle: Text(_getCommissionTypeLabel(commission.type)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  commission.type == 'ENTRANT' ? 'GRATUIT' : '${commission.taux.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: commission.type == 'ENTRANT' ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showEditCommissionDialog(commission),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                ),
                IconButton(
                  onPressed: () => _deleteCommission(commission),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _refreshData() {
    Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Données actualisées!')),
    );
  }


  Future<void> _initializeRealData() async {
    final ratesService = Provider.of<RatesService>(context, listen: false);
    
    // Ajouter les taux réels
    final initialTaux = InitialRatesData.getInitialTaux();
    for (final taux in initialTaux) {
      await ratesService.createTaux(
        devise: taux.deviseCible,
        taux: taux.taux,
        type: taux.type,
      );
    }
    
    // Ajouter les commissions réelles
    final initialCommissions = InitialRatesData.getInitialCommissions();
    for (final commission in initialCommissions) {
      await ratesService.createCommission(
        type: commission.type,
        taux: commission.taux,
        description: commission.description,
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données réelles chargées!')),
      );
    }
  }

  void _showCreateTauxDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateTauxDialog(),
    );
  }

  void _showEditTauxDialog(TauxModel taux) {
    showDialog(
      context: context,
      builder: (context) => _EditTauxDialog(taux: taux),
    );
  }

  void _showCreateCommissionDialog() {
    showDialog(
      context: context,
      builder: (context) => const ModernCommissionDialog(),
    );
  }

  void _showEditCommissionDialog(CommissionModel commission) {
    showDialog(
      context: context,
      builder: (context) => ModernCommissionDialog(commission: commission),
    );
  }

  Future<void> _deleteTaux(TauxModel taux) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le taux'),
        content: Text('Supprimer le taux ${taux.deviseSource} -> ${taux.deviseCible} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RatesService>(context, listen: false).deleteTaux(taux.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taux supprimé!')),
        );
      }
    }
  }

  Future<void> _deleteCommission(CommissionModel commission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la commission'),
        content: Text('Supprimer la commission ${commission.type} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RatesService>(context, listen: false).deleteCommission(commission.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commission supprimée!')),
        );
      }
    }
  }
}

// Dialogs simplifiés
class _CreateTauxDialog extends StatefulWidget {
  @override
  State<_CreateTauxDialog> createState() => _CreateTauxDialogState();
}

class _CreateTauxDialogState extends State<_CreateTauxDialog> {
  final _deviseController = TextEditingController();
  final _tauxController = TextEditingController();
  String _selectedType = 'NATIONAL';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Dialog(
      insetPadding: isMobile 
          ? const EdgeInsets.all(16) 
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: isMobile ? double.infinity : 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_exchange, color: const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Nouveau Taux',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _deviseController,
              decoration: InputDecoration(
                labelText: 'Devise (ex: USD)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tauxController,
              decoration: InputDecoration(
                labelText: 'Taux (ex: 2850)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.trending_up),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'NATIONAL', child: Text('National')),
                DropdownMenuItem(value: 'INTERNATIONAL_ENTRANT', child: Text('International Entrant')),
                DropdownMenuItem(value: 'INTERNATIONAL_SORTANT', child: Text('International Sortant')),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createTaux,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Créer le taux'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _createTaux,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Créer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTaux() async {
    if (_deviseController.text.isNotEmpty && _tauxController.text.isNotEmpty) {
      await Provider.of<RatesService>(context, listen: false).createTaux(
        devise: _deviseController.text.toUpperCase(),
        taux: double.parse(_tauxController.text),
        type: _selectedType,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taux créé!')),
        );
      }
    }
  }
}

class _EditTauxDialog extends StatefulWidget {
  final TauxModel taux;
  const _EditTauxDialog({required this.taux});

  @override
  State<_EditTauxDialog> createState() => _EditTauxDialogState();
}

class _EditTauxDialogState extends State<_EditTauxDialog> {
  late final TextEditingController _deviseController;
  late final TextEditingController _tauxController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _deviseController = TextEditingController(text: widget.taux.deviseCible);
    _tauxController = TextEditingController(text: widget.taux.taux.toString());
    _selectedType = widget.taux.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier Taux'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _deviseController,
            decoration: const InputDecoration(labelText: 'Devise'),
          ),
          TextField(
            controller: _tauxController,
            decoration: const InputDecoration(labelText: 'Taux'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'NATIONAL', child: Text('National')),
              DropdownMenuItem(value: 'INTERNATIONAL_ENTRANT', child: Text('International Entrant')),
              DropdownMenuItem(value: 'INTERNATIONAL_SORTANT', child: Text('International Sortant')),
            ],
            onChanged: (value) => setState(() => _selectedType = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _updateTaux,
          child: const Text('Modifier'),
        ),
      ],
    );
  }

  Future<void> _updateTaux() async {
    final updatedTaux = widget.taux.copyWith(
      deviseCible: _deviseController.text.toUpperCase(),
      taux: double.parse(_tauxController.text),
      type: _selectedType,
    );
    
    await Provider.of<RatesService>(context, listen: false).updateTaux(updatedTaux);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taux modifié!')),
      );
    }
  }
}

class _CreateCommissionDialog extends StatefulWidget {
  @override
  State<_CreateCommissionDialog> createState() => _CreateCommissionDialogState();
}

class _CreateCommissionDialogState extends State<_CreateCommissionDialog> {
  final _descriptionController = TextEditingController();
  final _tauxController = TextEditingController();
  String _selectedType = 'SORTANT';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Dialog(
      insetPadding: isMobile 
          ? const EdgeInsets.all(16) 
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: isMobile ? double.infinity : 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.percent, color: const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Nouvelle Commission',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Type de transaction',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(
                  _selectedType == 'ENTRANT' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: _selectedType == 'ENTRANT' ? Colors.green : Colors.orange,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'ENTRANT', child: Text('Entrant (vers RDC)')),
                DropdownMenuItem(value: 'SORTANT', child: Text('Sortant (depuis RDC)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  if (value == 'ENTRANT') {
                    _tauxController.text = '0';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.description),
                hintText: 'Ex: Commission transfert international',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tauxController,
              decoration: InputDecoration(
                labelText: 'Taux (%)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.percent),
                enabled: _selectedType != 'ENTRANT',
                helperText: _selectedType == 'ENTRANT' 
                    ? 'Les transferts entrants sont gratuits (0%)'
                    : 'Taux de commission appliqué',
              ),
              keyboardType: TextInputType.number,
            ),
            if (_selectedType == 'ENTRANT') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les transferts entrants vers la RDC sont gratuits pour encourager les envois.',
                        style: TextStyle(color: Colors.green[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (isMobile) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createCommission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Créer la commission'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _createCommission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Créer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCommission() async {
    if (_descriptionController.text.isNotEmpty) {
      await Provider.of<RatesService>(context, listen: false).createCommission(
        type: _selectedType,
        taux: _selectedType == 'ENTRANT' ? 0.0 : double.parse(_tauxController.text),
        description: _descriptionController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commission créée!')),
        );
      }
    }
  }
}

class _EditCommissionDialog extends StatefulWidget {
  final CommissionModel commission;
  const _EditCommissionDialog({required this.commission});

  @override
  State<_EditCommissionDialog> createState() => _EditCommissionDialogState();
}

class _EditCommissionDialogState extends State<_EditCommissionDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _tauxController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.commission.description);
    _tauxController = TextEditingController(text: widget.commission.taux.toString());
    _selectedType = widget.commission.type;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier Commission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'ENTRANT', child: Text('Entrant (vers RDC)')),
              DropdownMenuItem(value: 'SORTANT', child: Text('Sortant (depuis RDC)')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
                if (value == 'ENTRANT') {
                  _tauxController.text = '0';
                }
              });
            },
          ),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextField(
            controller: _tauxController,
            decoration: const InputDecoration(labelText: 'Taux (%)'),
            keyboardType: TextInputType.number,
            enabled: _selectedType != 'ENTRANT',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _updateCommission,
          child: const Text('Modifier'),
        ),
      ],
    );
  }

  Future<void> _updateCommission() async {
    final updatedCommission = widget.commission.copyWith(
      type: _selectedType,
      taux: _selectedType == 'ENTRANT' ? 0.0 : double.parse(_tauxController.text),
      description: _descriptionController.text,
    );
    
    await Provider.of<RatesService>(context, listen: false).updateCommission(updatedCommission);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission modifiée!')),
      );
    }
  }
}
