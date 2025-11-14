import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/admin_stats_cards.dart';
import '../widgets/shops_management.dart';
import '../widgets/taux_commissions_management.dart';
import '../widgets/agents_management_complete.dart';
import '../widgets/config_reports_widget.dart';
import '../widgets/reports/admin_reports_widget.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/footer_widget.dart';
import '../widgets/create_shop_dialog.dart';
import '../widgets/create_agent_dialog.dart';
import '../widgets/admin_help_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Dashboard',
    'Shops',
    'Agents',
    'Taux & Commissions',
    'Rapports',
    'Synchronisation',
    'Configuration',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.store,
    Icons.people,
    Icons.currency_exchange,
    Icons.analytics,
    Icons.sync,
    Icons.settings,
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
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Titre
          Text(
            isMobile ? 'UCASH Admin' : 'UCASH - Administration',
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
        const SizedBox(width: 16),
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
                      setState(() {
                        _selectedIndex = index;
                      });
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
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '💸',
                    style: TextStyle(fontSize: 48),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'UCASH Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Panneau d\'administration',
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
              itemCount: _menuItems.length,
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
                      _menuItems[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
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
        return _buildShopsContent();
      case 2:
        return _buildAgentsContent();
      case 3:
        return _buildTauxCommissionsContent();
      case 4:
        return _buildReportsContent();
      case 5:
        return _buildSynchronisationContent();
      case 6:
        return _buildConfigurationContent();
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
    return const ShopsManagement();
  }

  Widget _buildAgentsContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestion des Agents',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFDC2626),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          const Expanded(
            child: AgentsManagementComplete(),
          ),
        ],
      ),
    );
  }

  Widget _buildTauxCommissionsContent() {
    return const TauxCommissionsManagement();
  }

  Widget _buildReportsContent() {
    return const AdminReportsWidget();
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
    
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: const ConfigReportsWidget(),
    );
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
    
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = isMobile ? 2 : (isTablet ? 3 : 4);
        double childAspectRatio = isMobile ? 1.2 : (isTablet ? 1.1 : 1.0);
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
          mainAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
          childAspectRatio: childAspectRatio,
          children: [
            _buildFluidActionCard(
              title: 'Nouveau Shop',
              icon: Icons.add_business,
              color: const Color(0xFF059669),
              onTap: () => _showCreateShopDialog(),
            ),
            _buildFluidActionCard(
              title: 'Nouvel Agent',
              icon: Icons.person_add,
              color: const Color(0xFF7C3AED),
              onTap: () => _showCreateAgentDialog(),
            ),
            _buildFluidActionCard(
              title: 'Rapports',
              icon: Icons.analytics,
              color: const Color(0xFFDC2626),
              onTap: () => setState(() => _selectedIndex = 4),
            ),
            _buildFluidActionCard(
              title: 'Configuration',
              icon: Icons.settings,
              color: const Color(0xFF0891B2),
              onTap: () => setState(() => _selectedIndex = 5),
            ),
          ],
        );
      },
    );
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
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[0]),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[1]),
            label: 'Shops',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[2]),
            label: 'Agents',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[3]),
            label: 'Taux',
          ),
          BottomNavigationBarItem(
            icon: Icon(_menuIcons[4]),
            label: 'Rapports',
          ),
        ],
      ),
    );
  }
}
