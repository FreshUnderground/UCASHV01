import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/footer_widget.dart';
import '../widgets/agent_clients_widget.dart';
import '../widgets/agent_transfers_widget.dart';
import '../widgets/reports/agent_reports_widget.dart' as reports;
import '../widgets/agent_dashboard_widget.dart';
import '../widgets/agent_operations_widget.dart';
import '../widgets/transfer_validation_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/journal_caisse_widget.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/offline_banner.dart';
import '../services/operation_service.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_containers.dart';

class DashboardAgentPage extends StatefulWidget {
  const DashboardAgentPage({super.key});

  @override
  State<DashboardAgentPage> createState() => _DashboardAgentPageState();
}

class _DashboardAgentPageState extends State<DashboardAgentPage> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Tableau de bord',
    'Clients',
    'Opérations',
    'Validations',
    'Rapports',
    'Synchronisation',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.account_balance_wallet,
    Icons.check_circle,
    Icons.receipt_long,
    Icons.analytics,
    Icons.sync,
  ];

  @override
  void initState() {
    super.initState();
    // SyncService is now initialized in main.dart, so we don't need to initialize it here
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isMobile = size.width <= 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: !isDesktop ? _buildDrawer() : null,
      body: SafeArea(
        child: Column(
          children: [
            // Bannière offline
            OfflineBanner(syncService: SyncService()),
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return AppBar(
      title: Row(
        children: [
          // Logo/Icône UCASH
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Titre
          Text(
            isMobile ? 'UCASH' : 'UCASH - Espace Agent',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: isMobile ? 18 : 20,
              letterSpacing: 0.5,
            ),
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
        const ConnectivityIndicator(),
        SizedBox(width: isMobile ? 4 : 8),
        // Indicateur de synchronisation automatique
        SyncIndicator(syncService: SyncService()),
        SizedBox(width: isMobile ? 4 : 8),
        // Bouton de synchronisation manuelle
        ManualSyncButton(
          syncService: SyncService(),
          onSyncComplete: () {
            // Rafraîchir les données après sync
            setState(() {});
          },
        ),
        SizedBox(width: isMobile ? 8 : 16),
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
                      Flexible(
                        child: Text(
                          authService.displayName,
                          style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        'Déconnexion',
                        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(width: isMobile ? 8 : 16),
      ],
    );
  }

  Widget _buildDrawer() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 480;
    
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF48bb78), Color(0xFF38a169)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💸',
                    style: TextStyle(fontSize: isMobile ? 36 : 40),
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  Text(
                    'UCASH Agent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(_menuIcons[index], size: isMobile ? 20 : 24),
                  title: Text(
                    _menuItems[index],
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  selected: _selectedIndex == index,
                  selectedTileColor: Colors.green[50],
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    Navigator.pop(context);
                  },
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
      width: isTablet ? 230 : 250,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF48bb78), Color(0xFF38a169)],
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Text(
                    '💸',
                    style: TextStyle(fontSize: isTablet ? 36 : 40),
                  ),
                  SizedBox(height: isTablet ? 6 : 8),
                  Text(
                    'UCASH Agent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(
                    _menuIcons[index],
                    size: isTablet ? 20 : 24,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _menuItems[index],
                          style: TextStyle(fontSize: isTablet ? 13 : 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (index == 3) // Index de "Validations"
                        _buildValidationBadge(),
                    ],
                  ),
                  selected: _selectedIndex == index,
                  selectedTileColor: Colors.green[50],
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
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
    
    // Widgets qui ont déjà leur propre scroll
    final widgetsWithOwnScroll = [0]; // Dashboard uniquement
    
    Widget content = switch (_selectedIndex) {
      0 => _buildDashboardContent(),
      1 => _buildClientsContent(),
      2 => _buildOperationsContent(),
      3 => _buildValidationsContent(),
      4 => _buildReportsContent(),
      6 => _buildSynchronisationContent(),
      _ => _buildDashboardContent(),
    };
    
    // Ajouter scroll si le widget n'en a pas déjà
    if (!widgetsWithOwnScroll.contains(_selectedIndex)) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: content,
        ),
      );
    }
    
    return content;
  }

  Widget _buildDashboardContent() {
    return AgentDashboardWidget(
      onTabChanged: (index) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _selectedIndex = index;
          });
        });
      },
    );
  }


  Widget _buildClientsContent() {
    return const AgentClientsWidget();
  }

  Widget _buildOperationsContent() {
    return const AgentOperationsWidget();
  }

  Widget _buildValidationsContent() {
    return const TransferValidationWidget();
  }

  Widget _buildTransfersContent() {
    return const AgentTransfersWidget();
  }

  Widget _buildReportsContent() {
    return const reports.AgentReportsWidget();
  }

  Widget _buildSynchronisationContent() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    userId: authService.currentUser?.username ?? 'agent',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Widget de synchronisation principal
              DashboardSyncWidget(
                userId: authService.currentUser?.username ?? 'agent',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValidationBadge() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) return const SizedBox.shrink();
        
        final pendingCount = operationService.operations.where((operation) {
          return operation.statut == OperationStatus.enAttente &&
                 (operation.type == OperationType.transfertNational ||
                  operation.type == OperationType.transfertInternationalSortant ||
                  operation.type == OperationType.transfertInternationalEntrant) &&
                 operation.shopDestinationId == currentShopId;
        }).length;
        
        if (pendingCount == 0) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$pendingCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
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
        currentIndex: _getMobileNavIndex(_selectedIndex),
        onTap: (mobileIndex) {
          // Mapper l'index mobile vers l'index desktop
          final desktopIndex = _getDesktopIndexFromMobile(mobileIndex);
          setState(() => _selectedIndex = desktopIndex);
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(_menuIcons[0]),
                if (_selectedIndex == 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[1]),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[2]),
            label: 'Opérations',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(_menuIcons[3]),
                Consumer<OperationService>(
                  builder: (context, operationService, child) {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final currentShopId = authService.currentUser?.shopId;
                    
                    if (currentShopId == null) return const SizedBox.shrink();
                    
                    final pendingCount = operationService.operations.where((operation) {
                      return operation.statut == OperationStatus.enAttente &&
                             (operation.type == OperationType.transfertNational ||
                              operation.type == OperationType.transfertInternationalSortant ||
                              operation.type == OperationType.transfertInternationalEntrant) &&
                             operation.shopDestinationId == currentShopId;
                    }).length;
                    
                    if (pendingCount == 0) return const SizedBox.shrink();
                    
                    return Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            label: 'Validations',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[6]), // Index 6 = Reports
            label: 'Rapports',
          ),
        ],
      ),
    );
  }

  // Mapper l'index desktop (0-7) vers mobile (0-4)
  int _getMobileNavIndex(int desktopIndex) {
    // Desktop: 0=Dashboard, 1=Clients, 2=Operations, 3=Validations, 4=Transfers, 5=Journal, 6=Reports, 7=Sync
    // Mobile:  0=Dashboard, 1=Clients, 2=Operations, 3=Validations, 4=Reports
    switch (desktopIndex) {
      case 0: return 0; // Dashboard
      case 1: return 1; // Clients
      case 2: return 2; // Operations
      case 3: return 3; // Validations
      case 6: return 4; // Reports
      default: return 0; // Autres (Transfers, Journal, Sync) -> Dashboard
    }
  }

  // Mapper l'index mobile (0-4) vers desktop (0-7)
  int _getDesktopIndexFromMobile(int mobileIndex) {
    // Mobile -> Desktop mapping
    switch (mobileIndex) {
      case 0: return 0; // Dashboard
      case 1: return 1; // Clients
      case 2: return 2; // Operations
      case 3: return 3; // Validations
      case 4: return 6; // Reports
      default: return 0;
    }
  }

  Future<void> _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
  }
}