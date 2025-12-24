import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../widgets/admin_stats_cards.dart';
import '../widgets/shops_management.dart';
import '../widgets/taux_commissions_management.dart';
import '../widgets/agents_management_complete.dart';
import '../widgets/admin_clients_widget.dart';
import '../widgets/config_reports_widget.dart';
import '../widgets/reports/admin_reports_widget.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/footer_widget.dart';
import '../widgets/create_shop_dialog.dart';
import '../widgets/create_agent_dialog.dart';
import '../widgets/admin_help_widget.dart';
import '../widgets/help_button_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/comptes_speciaux_widget.dart';
import '../widgets/sync_monitor_widget.dart';
import '../widgets/audit_history_widget.dart';
import '../widgets/reconciliation_report_widget.dart';
import '../widgets/virtual_transactions_widget.dart' as virtual_widget;
import '../widgets/admin_management_widget.dart';
import '../widgets/admin_sim_management_widget.dart';
import '../widgets/language_selector.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';
import '../services/transfer_sync_service.dart';
import '../widgets/admin_deletion_widget.dart';
import '../widgets/admin_deletion_validation_widget.dart';
import '../widgets/trash_bin_widget.dart';
import '../services/deletion_service.dart';
import '../widgets/partner_net_position_widget.dart';
import '../widgets/reports/dettes_intershop_report.dart';
import '../widgets/admin_flot_dialog.dart';
import '../widgets/admin_initialization_widget.dart';
import '../widgets/gestion_personnel_widget.dart' as personnel;

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  int _selectedIndex = 0;
  bool _isSyncingClients = false;
  bool _isSyncingDeletions = false;  // ✅ NOUVEAU pour Suppressions
  bool _isSyncingTrash = false;      // ✅ NOUVEAU pour Corbeille
  bool _isSyncingRapports = false;   // ✅ NOUVEAU pour Rapports

  // Les clés de menu qui seront traduites dynamiquement
  List<String> _getMenuItems(AppLocalizations l10n) => [
    l10n.dashboard,           // 0
    l10n.expenses,            // 1
    l10n.shops,               // 2
    l10n.agents,              // 3
    'Administrateurs',        // 4
    'VIRTUEL',                // 5 - ✅ 6ème position (index 5)
    l10n.partners,            // 6
    l10n.ratesAndCommissions, // 7
    l10n.reports,             // 8
    'Dettes Intershop',       // 9
    l10n.configuration,       // 10
    'Suppressions',           // 11
    'Validations Admin',      // 12
    'Corbeille',              // 13
    'Initialisation',         // 14
    'Personnel',              // 15 - ✅ NOUVEAU
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,              // 0
    Icons.account_balance_wallet, // 1
    Icons.store,                  // 2
    Icons.people,                 // 3
    Icons.admin_panel_settings,   // 4
    Icons.mobile_friendly,        // 5 - ✅ VIRTUEL
    Icons.account_circle,         // 6
    Icons.currency_exchange,      // 7
    Icons.analytics,              // 8
    Icons.swap_horiz,             // 9
    Icons.settings,               // 10
    Icons.delete_outline,         // 11
    Icons.how_to_reg,             // 12 - Validations Admin
    Icons.restore_from_trash,     // 13
    Icons.settings_suggest,       // 14 - Initialisation
    Icons.badge,                  // 15 - Personnel
  ];

  @override
  void initState() {
    super.initState();
    // SyncService is now initialized in main.dart, so we don't need to initialize it here
    
    // Trigger synchronization of operation data when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerOperationSync();
    });
  }
  
  // Function to trigger synchronization of operation data
  void _triggerOperationSync() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Only proceed if user is an agent with a shop ID
      if (authService.currentUser?.role == 'AGENT' && authService.currentUser?.shopId != null) {
        final transferSyncService = TransferSyncService();
        debugPrint('🔄 Déclenchement de la synchronisation des opérations...');
        
        // Force a refresh from API to get latest operation data
        await transferSyncService.forceRefreshFromAPI();
        
        debugPrint('✅ Synchronisation des opérations terminée');
        
        // Show a snackbar to inform user
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.operationDataSynced),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('ℹ️ Synchronisation des opérations ignorée (admin ou shop ID non disponible)');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la synchronisation des opérations: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncError),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuItems = _getMenuItems(l10n);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: !isDesktop ? _buildDrawer() : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildResponsiveLayout(isDesktop, isMobile),
            ),
            if (!isMobile) const FooterWidget(),
          ],
        ),
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildResponsiveLayout(bool isDesktop, bool isMobile) {
    if (isDesktop) {
      return Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      );
    } else {
      return _buildMainContent();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return AppBar(
      title: Row(
        children: [
          // Logo UCASH
          Container(
            height: 40,
            width: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          if (!isMobile) const Text(
            'UCASH Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      actions: [
        // Sélecteur de langue compact
        const LanguageSelector(compact: true),
        const SizedBox(width: 8),
        
        // Bouton Documentation
        const AppBarHelpAction(),
        const SizedBox(width: 8),
        
        // Bouton Sync Monitor
        IconButton(
          icon: const Icon(Icons.sync_alt, color: Colors.white),
          tooltip: 'Synchronisation',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
                  child: const SyncMonitorWidget(),
                ),
              ),
            );
          },
        ),
        const ConnectivityIndicator(),
        const SizedBox(width: 16),
        Consumer<AuthService>(
          builder: (context, authService, child) {
            return PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: isMobile ? 28 : 32,
                ),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.person, size: isMobile ? 16 : 18, color: const Color(0xFFDC2626)),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        authService.displayName,
                        style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: isMobile ? 16 : 18, color: Colors.red),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        l10n.logout,
                        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDrawer() {
    final l10n = AppLocalizations.of(context)!;
    final menuItems = _getMenuItems(l10n);
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo UCASH
                  Container(
                    height: 60,
                    width: 60,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'UCASH Admin',
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
              itemCount: menuItems.length,
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
                      menuItems[index],
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFDC2626) : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () async {
                      if (index == 6) {
                        // Partenaires (index 6)
                        Navigator.pop(context);
                        await _handlePartenairesSelection();
                      } else if (index == 8) {
                        // Rapports (index 8) - Sync d'abord si online
                        Navigator.pop(context);
                        await _handleRapportsSelection();
                      } else if (index == 11) {
                        // Suppressions (index 11)
                        Navigator.pop(context);
                        await _handleSuppressionsSelection();
                      } else if (index == 12) {
                        // Validations Admin (index 12)
                        Navigator.pop(context);
                        await _handleValidationsAdminSelection();
                      } else if (index == 13) {
                        // Corbeille (index 13)
                        Navigator.pop(context);
                        await _handleCorbeilleSelection();
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                        Navigator.pop(context);
                      }
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
    final l10n = AppLocalizations.of(context)!;
    final menuItems = _getMenuItems(l10n);
    return Container(
      width: 280,
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
            height: 140,
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
                  const Text(
                    '💸',
                    style: TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'UCASH Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.adminPanel,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(
                      _menuIcons[index],
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 22,
                    ),
                    title: Text(
                      menuItems[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () async {
                      if (index == 6) {
                        // Partenaires (index 6)
                        await _handlePartenairesSelection();
                      } else if (index == 8) {
                        // Rapports (index 8) - Sync d'abord si online
                        await _handleRapportsSelection();
                      } else if (index == 11) {
                        // Suppressions (index 11)
                        await _handleSuppressionsSelection();
                      } else if (index == 12) {
                        // Validations Admin (index 12)
                        await _handleValidationsAdminSelection();
                      } else if (index == 13) {
                        // Corbeille (index 13)
                        await _handleCorbeilleSelection();
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
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
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildFraisDepensesContent();
      case 2:
        return _buildShopsContent();
      case 3:
        return _buildAgentsContent();
      case 4:
        return _buildAdminManagementContent();
      case 5:
        return _buildVirtuelContent();  // ✅ VIRTUEL à la 6ème position
      case 6:
        return _isSyncingClients ? _buildSyncingClientsIndicator() : _buildClientsContent();
      case 7:
        return _buildTauxCommissionsContent();
      case 8:
        return _isSyncingRapports ? _buildSyncingIndicator('Synchronisation des opérations...') : _buildReportsContent();
      case 9:
        return _buildDettesIntershopContent();
      case 10:
        return _buildConfigurationContent();
      case 11:
        return _isSyncingDeletions ? _buildSyncingIndicator('Synchronisation des opérations...') : const AdminDeletionPage();
      case 12:
        return const AdminDeletionValidationWidget();  // Validations Admin
      case 13:
        return _isSyncingTrash ? _buildSyncingIndicator('Chargement de la corbeille...') : const TrashBinWidget(showAll: true);
      case 14:
                return const AdminInitializationWidget();  // Initialisation
      case 15:
        return _buildPersonnelManagement();  // Personnel
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec message de bienvenue responsive
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return _buildResponsiveHeader(authService, isMobile, isTablet);
            },
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Cartes de statistiques principales (chargement différé)
          FutureBuilder(
            future: Future.delayed(const Duration(milliseconds: 100)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return const AdminStatsCards();
              }
              return Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFDC2626)),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      'Chargement des statistiques...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Actions rapides
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return context.adaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions Rapides',
            style: context.titleAccent,
          ),
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          _buildResponsiveActionGrid(),
        ],
      ),
    );
  }

  Widget _buildFluidActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
      ),
      child: Container(
        padding: context.fluidPadding(
          mobile: const EdgeInsets.all(12),
          tablet: const EdgeInsets.all(16),
          desktop: const EdgeInsets.all(20),
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
          ),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: context.fluidSpacing(mobile: 1, tablet: 1.5, desktop: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: context.fluidSpacing(mobile: 4, tablet: 6, desktop: 8),
              offset: Offset(0, context.fluidSpacing(mobile: 2, tablet: 3, desktop: 4)),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(
                context.fluidSpacing(mobile: 8, tablet: 12, desktop: 16),
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 12, desktop: 16),
                ),
              ),
              child: Icon(
                icon,
                size: context.fluidIcon(mobile: 20, tablet: 28, desktop: 32),
                color: color,
              ),
            ),
            context.verticalSpace(mobile: 8, tablet: 12, desktop: 16),
            Flexible(
              child: Text(
                title,
                style: context.label.copyWith(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: const ShopsManagement(),
    );
  }

  Widget _buildAgentsContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: const AgentsManagementComplete(),
    );
  }

  Widget _buildAdminManagementContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: const AdminManagementWidget(),
    );
  }

  Widget _buildClientsContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFDC2626),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFDC2626),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: Icon(Icons.people, size: isMobile ? 20 : 24),
                  text: 'Liste Partenaires',
                ),
                Tab(
                  icon: Icon(Icons.balance, size: isMobile ? 20 : 24),
                  text: 'Situation Nette',
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminClientsWidget(),
                PartnerNetPositionWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingClientsIndicator() {
    return _buildSyncingIndicator('Synchronisation des partenaires...');
  }

  Widget _buildSyncingIndicator(String message) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handler pour Rapports - Sync operations d'abord si online
  Future<void> _handleRapportsSelection() async {
    final connectivityService = ConnectivityService.instance;
    final hasConnection = connectivityService.isOnline;

    if (hasConnection) {
      setState(() {
        _isSyncingRapports = true;
        _selectedIndex = 8;  // Rapports (index 8)
      });

      try {
        debugPrint('🔄 [ADMIN RAPPORTS] Synchronisation des opérations...');
        
        // Synchroniser UNIQUEMENT la table operations via TransferSyncService
        final transferSyncService = Provider.of<TransferSyncService>(context, listen: false);
        await transferSyncService.forceRefreshFromAPI();
        
        debugPrint('✅ [ADMIN RAPPORTS] Opérations synchronisées');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Opérations synchronisées'),
                ],
              ),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ [ADMIN RAPPORTS] Erreur sync: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Synchronisation partielle - données locales')),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSyncingRapports = false;
          });
        }
      }
    } else {
      // Pas de connexion - afficher directement avec les données locales
      debugPrint('📡 [ADMIN RAPPORTS] Hors ligne - données locales');
      setState(() {
        _selectedIndex = 8;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('Mode hors-ligne - données locales'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handlePartenairesSelection() async {
    setState(() {
      _isSyncingClients = true;
      _selectedIndex = 6;  // Partenaires (index 6)
    });

    try {
      final connectivityService = ConnectivityService.instance;
      final hasConnection = connectivityService.isOnline;

      if (hasConnection) {
        debugPrint('📥 Synchronisation des partenaires depuis le serveur...');
        
        // NE PAS vider - juste synchroniser
        // Le serveur enverra les modifiés, LocalDB les mergera intelligemment
        debugPrint('🔄 Téléchargement des partenaires et opérations depuis le serveur...');
        
        // 🗑️ IMPORTANT: Réinitialiser le timestamp operations pour forcer téléchargement complet
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_operations');
        debugPrint('🗑️ Timestamp operations réinitialisé - téléchargement complet');
        
        final syncService = SyncService();
        
        // Télécharger clients ET opérations (dépôts/retraits) pour calculer les soldes
        await Future.wait([
          syncService.downloadTableData('clients', 'admin', 'admin'),
          syncService.downloadTableData('operations', 'admin', 'admin'),
        ]);
        
        // Recharger en mémoire
        final clientService = ClientService();
        final operationService = Provider.of<OperationService>(context, listen: false);
        await Future.wait([
          clientService.loadClients(),
          operationService.loadOperations(), // Charger TOUTES les opérations pour calculer soldes
        ]);
        
        debugPrint('✅ ${clientService.clients.length} partenaires chargés');
      } else {
        debugPrint('ℹ️ Hors ligne - affichage des partenaires locaux');
        // Charger depuis la base locale sans suppression
        final clientService = ClientService();
        await clientService.loadClients();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la synchronisation des partenaires: $e');
      // En cas d'erreur, charger depuis la base locale
      try {
        final clientService = ClientService();
        await clientService.loadClients();
        debugPrint('💾 Partenaires chargés depuis la base locale');
      } catch (localError) {
        debugPrint('❌ Erreur chargement local: $localError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingClients = false;
        });
      }
    }
  }

  Future<void> _handleSuppressionsSelection() async {
    setState(() {
      _isSyncingDeletions = true;  // ✅ Activer le loader
      _selectedIndex = 11;  // Suppressions (index 11)
    });

    try {
      final connectivityService = ConnectivityService.instance;
      final hasConnection = connectivityService.isOnline;

      if (hasConnection) {
        debugPrint('📥 Synchronisation des données pour suppressions...');
        
        // 🗑️ Réinitialiser le timestamp operations pour forcer téléchargement complet
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_operations');
        debugPrint('🗑️ Timestamp operations réinitialisé - téléchargement complet');
        
        final syncService = SyncService();
        
        // Télécharger TOUTES les opérations pour pouvoir les supprimer
        debugPrint('🔄 Téléchargement de toutes les opérations...');
        await syncService.downloadTableData('operations', 'admin', 'admin');
        
        // Recharger en mémoire
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations(); // Charger TOUTES les opérations
        
        debugPrint('✅ ${operationService.operations.length} opérations chargées');
      } else {
        debugPrint('ℹ️ Hors ligne - affichage des opérations locales');
        // Charger depuis la base locale (fallback)
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la synchronisation des opérations: $e');
      // En cas d'erreur, charger depuis la base locale (fallback)
      try {
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
        debugPrint('💾 Opérations chargées depuis la base locale');
      } catch (localError) {
        debugPrint('❌ Erreur chargement local: $localError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingDeletions = false;  // ✅ Désactiver le loader
        });
      }
    }
  }

  /// ✅ NOUVEAU: Handler pour Validations Admin
  Future<void> _handleValidationsAdminSelection() async {
    setState(() {
      _selectedIndex = 12;  // Validations Admin (index 12)
    });

    try {
      // Recharger les demandes de suppression
      final deletionService = Provider.of<DeletionService>(context, listen: false);
      await deletionService.loadDeletionRequests();
      debugPrint('✅ Demandes de suppression chargées pour validation admin');
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement des demandes: $e');
    }
  }

  Future<void> _handleCorbeilleSelection() async {
    setState(() {
      _isSyncingTrash = true;  // ✅ Activer le loader
      _selectedIndex = 13;  // Corbeille (index 13)
    });

    try {
      final connectivityService = ConnectivityService.instance;
      final hasConnection = connectivityService.isOnline;

      if (hasConnection) {
        debugPrint('📥 Synchronisation de la corbeille...');
        
        // Réinitialiser le timestamp operations pour forcer téléchargement complet
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_operations');
        debugPrint('🗑️ Timestamp operations réinitialisé');
        
        final syncService = SyncService();
        
        // Télécharger TOUTES les opérations (incluant celles en corbeille)
        debugPrint('🔄 Téléchargement des opérations...');
        await syncService.downloadTableData('operations', 'admin', 'admin');
        
        // Recharger en mémoire
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
        
        debugPrint('✅ Corbeille synchronisée');
      } else {
        debugPrint('ℹ️ Hors ligne - affichage de la corbeille locale');
        // Charger depuis la base locale (fallback)
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur synchronisation corbeille: $e');
      // Fallback local
      try {
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
        debugPrint('💾 Corbeille chargée depuis la base locale');
      } catch (localError) {
        debugPrint('❌ Erreur chargement local: $localError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingTrash = false;  // ✅ Désactiver le loader
        });
      }
    }
  }

  Widget _buildSimsContent() {
    return const AdminSimManagementWidget();
  }

  Widget _buildTauxCommissionsContent() {
    return const TauxCommissionsManagement();
  }

  Widget _buildReportsContent() {
    return const AdminReportsWidget();
  }

  Widget _buildDettesIntershopContent() {
    return DettesIntershopReport(
      shopId: null, // Admin peut voir tous les shops
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
    );
  }

  Widget _buildFraisDepensesContent() {
    return const ComptesSpeciauxWidget(
      isAdmin: true,
    );
  }

  Widget _buildSynchronisationContent() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return context.pageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec statut de synchronisation
              Row(
                children: [
                  Icon(
                    Icons.sync,
                    color: const Color(0xFFDC2626),
                    size: context.fluidIcon(mobile: 24, tablet: 28, desktop: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Synchronisation des Données',
                      style: TextStyle(
                        fontSize: context.fluidFont(mobile: 20, tablet: 24, desktop: 28),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  SyncStatusWidget(
                    userId: authService.currentUser?.username ?? 'admin',
                  ),
                ],
              ),
              
              context.verticalSpace(mobile: 24, tablet: 32, desktop: 40),
              
              // Widget de synchronisation principal
              DashboardSyncWidget(
                userId: authService.currentUser?.username ?? 'admin',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigurationContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  labelColor: const Color(0xFFDC2626),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFDC2626),
                  isScrollable: isMobile,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.settings, size: isMobile ? 18 : 22),
                      text: 'Paramètres',
                    ),
                    Tab(
                      icon: Icon(Icons.history, size: isMobile ? 18 : 22),
                      text: 'Audit Trail',
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_wallet, size: isMobile ? 18 : 22),
                      text: 'Réconciliation',
                    ),
                    Tab(
                      icon: Icon(Icons.sim_card, size: isMobile ? 18 : 22),
                      text: 'SIM',
                    ),
                    Tab(
                      icon: Icon(Icons.mobile_friendly, size: isMobile ? 18 : 22),
                      text: 'VIRTUEL',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: const ConfigReportsWidget(),
                ),
                _buildAuditTrailContent(),
                _buildReconciliationContent(),
                _buildSimsContent(),
                _buildVirtuelContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtuelContent() {
    return const virtual_widget.VirtualTransactionsWidget();
  }


  void _showAdminHelp() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: isMobile 
            ? const EdgeInsets.all(16) 
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: SizedBox(
          width: isMobile 
              ? double.infinity 
              : (isTablet ? size.width * 0.85 : size.width * 0.8),
          height: isMobile 
              ? size.height * 0.9 
              : (isTablet ? size.height * 0.85 : size.height * 0.8),
          child: Column(
            children: [
              // Header du dialog responsive
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMobile ? 'Guide Admin' : 'Guide Administrateur UCASH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : (isTablet ? 17 : 18),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close, 
                        color: Colors.white,
                        size: isMobile ? 20 : 24,
                      ),
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 32 : 40,
                        minHeight: isMobile ? 32 : 40,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenu scrollable
              const Expanded(
                child: SingleChildScrollView(
                  child: AdminHelpWidget(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveHeader(AuthService authService, bool isMobile, bool isTablet) {
    if (context.isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Admin',
            style: context.titleAccent,
          ),
          context.verticalSpace(mobile: 4, tablet: 6, desktop: 8),
          Text(
            'Bienvenue ${authService.displayName}',
            style: context.bodySecondary,
          ),
          context.verticalSpace(mobile: 8, tablet: 10, desktop: 12),
          context.badgeContainer(
            backgroundColor: const Color(0xFFDC2626).withOpacity(0.1),
            child: Text(
              DateTime.now().toString().split(' ')[0],
              style: context.badge.copyWith(
                color: const Color(0xFFDC2626),
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
                context.isTablet ? 'Dashboard Admin' : 'Dashboard Administrateur',
                style: context.titleAccent,
              ),
              context.verticalSpace(mobile: 4, tablet: 6, desktop: 8),
              Text(
                'Bienvenue ${authService.displayName}',
                style: context.bodySecondary,
              ),
            ],
          ),
        ),
        context.horizontalSpace(mobile: 8, tablet: 12, desktop: 16),
        context.badgeContainer(
          backgroundColor: const Color(0xFFDC2626).withOpacity(0.1),
          child: Text(
            DateTime.now().toString().split(' ')[0],
            style: context.badge.copyWith(
              color: const Color(0xFFDC2626),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveActionGrid() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    debugPrint('🔧 Building Action Grid - isMobile: $isMobile, isTablet: $isTablet, width: ${size.width}');
    
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = isMobile ? 2 : (isTablet ? 3 : 4);
        double childAspectRatio = isMobile ? 1.3 : (isTablet ? 1.2 : 1.1);
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
          mainAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
          childAspectRatio: childAspectRatio,
          children: [
            _buildFluidActionCard(
              title: 'Dépenses',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF059669),
              onTap: () => setState(() => _selectedIndex = 1),  // Index 1 = Dépenses
            ),
            _buildFluidActionCard(
              title: 'Agents',
              icon: Icons.people,
              color: const Color(0xFF7C3AED),
              onTap: () => setState(() => _selectedIndex = 3),  // Index 3 = Agents
            ),
            _buildFluidActionCard(
              title: 'Shops',
              icon: Icons.store,
              color: const Color(0xFFEC4899),
              onTap: () => setState(() => _selectedIndex = 2),  // Index 2 = Shops
            ),
            _buildFluidActionCard(
              title: 'Partenaires',
              icon: Icons.account_circle,
              color: const Color(0xFFF59E0B),
              onTap: () => _handlePartenairesSelection(),  // Index 4 = Partenaires
            ),
            _buildFluidActionCard(
              title: 'Configuration',
              icon: Icons.settings,
              color: const Color(0xFF0891B2),
              onTap: () => setState(() => _selectedIndex = 9),  // Index 9 = Configuration
            ),
            _buildFluidActionCard(
              title: 'Flot Administratif',
              icon: Icons.admin_panel_settings,
              color: const Color(0xFF9333EA),
              onTap: _showAdminFlotDialog,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuditTrailContent() {
    return const AuditHistoryWidget(
      showFilters: true,
    );
  }

  Widget _buildReconciliationContent() {
    return const ReconciliationReportWidget();
  }

  Future<void> _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
  }

  void _showCreateShopDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateShopDialog(),
    );
  }

  void _showCreateAgentDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateAgentDialog(),
    );
  }

  void _showAdminFlotDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AdminFlotDialog(),
    );
    
    if (result == true && mounted) {
      // Rafraîchir les données après la création du flot administratif
      setState(() {});
    }
  }

  // Mapper l'index desktop (13 items) vers l'index mobile (6 items)
  int _getMobileNavIndex(int desktopIndex) {
    // Desktop: 0=Dashboard, 1=Dépenses, 2=Shops, 3=Agents, 4=Administrateurs, 5=Partenaires,
    //          6=Taux, 7=Rapports, 8=Dettes, 9=Config, 10=Suppressions, 11=Validations Admin, 12=Corbeille
    // Mobile:  0=Dashboard, 1=Frais, 2=Shops, 3=Partenaires, 4=Rapports, 5=Config
    switch (desktopIndex) {
      case 0: return 0;  // Dashboard
      case 1: return 1;  // Dépenses → Frais
      case 2: return 2;  // Shops
      case 3: return 0;  // Agents → Dashboard (non disponible en mobile)
      case 4: return 0;  // Administrateurs → Dashboard (non disponible en mobile)
      case 5: return 3;  // Partenaires
      case 6: return 4;  // Taux → Rapports (regroupé)
      case 7: return 4;  // Rapports
      case 8: return 4;  // Dettes Intershop → Rapports (regroupé)
      case 9: return 5;  // Config
      case 10: return 5; // Suppressions → Config (regroupé)
      case 11: return 5; // Validations Admin → Config (regroupé)
      case 12: return 5; // Corbeille → Config (regroupé)
      default: return 0;
    }
  }

  // Mapper l'index mobile vers l'index desktop
  int _getDesktopIndexFromMobile(int mobileIndex) {
    // Mobile:  0=Dashboard, 1=Frais, 2=Shops, 3=Partenaires, 4=Rapports, 5=Config
    // Desktop: 0=Dashboard, 1=Dépenses, 2=Shops, 5=Partenaires, 7=Rapports, 9=Config
    switch (mobileIndex) {
      case 0: return 0;  // Dashboard
      case 1: return 1;  // Frais → Dépenses
      case 2: return 2;  // Shops
      case 3: return 5;  // Partenaires (index 5)
      case 4: return 7;  // Rapports (index 7)
      case 5: return 9;  // Config (index 9)
      default: return 0;
    }
  }

  Widget _buildBottomNavigation() {
    // S'assurer que currentIndex est valide
    final mobileIndex = _getMobileNavIndex(_selectedIndex);
    final validMobileIndex = mobileIndex.clamp(0, 5); // 6 items = indices 0-5
    
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
        currentIndex: validMobileIndex,
        onTap: (mobileIndex) async {
          final desktopIndex = _getDesktopIndexFromMobile(mobileIndex);
          if (desktopIndex == 5) {
            // Partenaires (index 5)
            await _handlePartenairesSelection();
          } else if (desktopIndex == 7) {
            // Rapports (index 7) - Sync d'abord si online
            await _handleRapportsSelection();
          } else {
            setState(() => _selectedIndex = desktopIndex);
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[0]),  // Dashboard (index 0)
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[1]),  // Dépenses/Frais (index 1)
            label: 'Frais',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[2]),  // Shops (index 2)
            label: 'Shops',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[5]),  // Partenaires (index 5)
            label: 'Partenaires',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[7]),  // Rapports (index 7)
            label: 'Rapports',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[9]),  // Config (index 9)
            label: 'Config',
          ),
        ],
      ),
    );
  }

  // Personnel Management Widget
  Widget _buildPersonnelManagement() {
    return const personnel.GestionPersonnelWidget();
  }
}