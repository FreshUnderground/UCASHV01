import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/agent_service.dart';
import '../services/flot_service.dart';
import '../services/sync_service.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/agent_clients_widget.dart';
import '../widgets/agent_transfers_widget.dart';
import '../widgets/agent_operations_list.dart';
import '../widgets/agent_capital_overview.dart';
import '../widgets/journal_caisse_widget.dart';
import '../widgets/flot_management_widget.dart';
import '../widgets/rapport_cloture_widget.dart';
import 'agent_login_page.dart';
import '../widgets/reports/agent_reports_widget.dart';
import '../widgets/agent_dashboard_widget.dart';
import '../widgets/agent_operations_widget.dart';
import '../widgets/rapportcloture.dart';
import '../widgets/agent_transactions_widget.dart';
import '../widgets/change_devise_widget.dart';
import '../widgets/agent_stats_cards.dart';

class AgentDashboardPage extends StatefulWidget {
  const AgentDashboardPage({super.key});

  @override
  State<AgentDashboardPage> createState() => _AgentDashboardPageState();
}

class _AgentDashboardPageState extends State<AgentDashboardPage> {
  int _selectedIndex = 0;
  
  final List<String> _menuItems = [
    'Dashboard',
    'Nouvelle Transaction',
    'Transactions',
    'Change de Devises',
    'Partenaires',
    'Journal de Caisse',
    'Rapports',
    'Gestion FLOT',
    'Clôture Journalière',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.add_circle_outline,
    Icons.list_alt,
    Icons.currency_exchange,
    Icons.people,
    Icons.account_balance_wallet,
    Icons.assessment,
    Icons.local_shipping,
    Icons.receipt_long,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final operationService = Provider.of<OperationService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    final agentService = Provider.of<AgentService>(context, listen: false);
    final flotService = Provider.of<FlotService>(context, listen: false);
    
    if (authService.currentAgent != null) {
      // IMPORTANT: Recharger TOUS les services après sync
      shopService.loadShops();
      agentService.loadAgents();
      operationService.loadOperations(agentId: authService.currentAgent!.id);
      flotService.loadFlots(shopId: authService.currentAgent!.shopId, isAdmin: false);
      
      debugPrint('🔄 _loadData: Rechargement des données après sync');
      debugPrint('   Agents disponibles: ${agentService.agents.length}');
      debugPrint('   Shops disponibles: ${shopService.shops.length}');
      debugPrint('   Opérations pour agent ${authService.currentAgent!.id}: ${operationService.operations.length}');
      debugPrint('   FLOTs pour shop ${authService.currentAgent!.shopId}: ${flotService.flots.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    
    return Consumer<AgentAuthService>(
      builder: (context, authService, child) {
        if (!authService.isAuthenticated) {
          return const AgentLoginPage();
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(authService),
          drawer: !isDesktop ? _buildDrawer() : null,
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(),
              Expanded(
                child: _buildMainContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AgentAuthService authService) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMobile ? 'UCASH Agent' : 'UCASH - Espace Agent',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          if (authService.currentShop != null)
            Text(
              authService.currentShop!.designation,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFDC2626),
      elevation: 0,
      actions: [
        // Menu utilisateur
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                _showProfileDialog();
                break;
              case 'change_password':
                _showChangePasswordDialog();
                break;
              case 'logout':
                _handleLogout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 8),
                  Text('Profil (${authService.currentAgent?.username})'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change_password',
              child: Row(
                children: [
                  Icon(Icons.lock),
                  SizedBox(width: 8),
                  Text('Changer mot de passe'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Déconnexion', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💸',
                    style: TextStyle(fontSize: 32),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'UCASH Agent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? const Color(0xFFDC2626).withOpacity(0.1) : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      _menuIcons[index],
                      color: isSelected ? const Color(0xFFDC2626) : Colors.grey[600],
                    ),
                    title: Text(
                      _menuItems[index],
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFDC2626) : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Container(
      width: isTablet ? 250 : 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: isTablet ? 120 : 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💸',
                    style: TextStyle(fontSize: isTablet ? 40 : 48),
                  ),
                  SizedBox(height: isTablet ? 8 : 12),
                  Text(
                    'UCASH Agent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 20 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Espace de travail',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isTablet ? 11 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 16),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 10 : 12,
                    vertical: isTablet ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? const Color(0xFFDC2626) : null,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 14 : 16,
                      vertical: isTablet ? 3 : 4,
                    ),
                    leading: Icon(
                      _menuIcons[index],
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: isTablet ? 20 : 22,
                    ),
                    title: Text(
                      _menuItems[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: isTablet ? 14 : 15,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: _getSelectedWidget(),
    );
  }

  Widget _getSelectedWidget() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const Center(child: Text('Nouvelle Transaction - À implémenter'));
      case 2:
        return const AgentTransactionsWidget();
      case 3:
        return const ChangeDeviseWidget();
      case 4:
        return const Center(child: Text('Partenaires - À implémenter'));
      case 5:
        return _buildJournalCaisseContent();
      case 6:
        return const AgentReportsWidget();
      case 7:
        return const FlotManagementWidget();
      case 8:
        return _buildRapportClotureContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du dashboard
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMobile ? 'Dashboard' : 'Dashboard Agent',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : (isTablet ? 26 : 28),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      isMobile ? 'Vos opérations' : 'Vue d\'ensemble de vos opérations',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : (isTablet ? 15 : 16),
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: _generateDailyReport,
                  icon: Icon(Icons.picture_as_pdf, size: isTablet ? 18 : 20),
                  label: Text(
                    isTablet ? 'Rapport' : 'Rapport PDF',
                    style: TextStyle(fontSize: isTablet ? 13 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 16,
                      vertical: isTablet ? 10 : 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Cartes de statistiques
          const AgentStatsCards(),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Vue d'ensemble du capital
          const AgentCapitalOverview(),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Dernières opérations
          const AgentOperationsList(),
        ],
      ),
    );
  }

  Widget _buildJournalCaisseContent() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final shopId = authService.currentAgent?.shopId;
    
    return JournalCaisseWidget(
      shopId: shopId,
      agentId: authService.currentAgent?.id,
    );
  }

  Widget _buildRapportClotureContent() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final shopId = authService.currentAgent?.shopId;
    
    return _buildClotureReport(shopId!);
  }

  Widget _buildClotureReport(int shopId) {
    return RapportCloture(shopId: shopId);
  }

  Future<void> _syncData() async {
    try {
      // Afficher un indicateur de chargement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('🔄 Synchronisation en cours...'),
            ],
          ),
          backgroundColor: Color(0xFF2196F3),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Appeler la synchronisation complète (même fonction que auto-sync)
      final syncService = SyncService();
      final currentAgent = Provider.of<AgentAuthService>(context, listen: false).currentAgent;
      final result = await syncService.syncAll(userId: currentAgent?.username ?? 'agent');
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Synchronisation réussie!'),
              backgroundColor: Color(0xFF388E3C),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Recharger les données locales
          _loadData();
        } else {
          throw Exception(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ Erreur de synchronisation: $e'),
                const SizedBox(height: 4),
                const Text(
                  '💡 Vérifiez votre connexion Internet et le serveur',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showProfileDialog() {
    // Implémenter le dialog de profil
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil Agent'),
        content: const Text('Dialog de profil à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    // Implémenter le dialog de changement de mot de passe
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: const Text('Dialog de changement de mot de passe à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AgentAuthService>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  void _generateDailyReport() {
    // Implémenter la génération de rapport PDF
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Génération du rapport PDF...'),
        backgroundColor: Color(0xFF388E3C),
      ),
    );
  }
}
