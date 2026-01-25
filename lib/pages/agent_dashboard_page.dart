import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../services/agent_auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/agent_service.dart';
import '../services/flot_service.dart';
import '../services/flot_notification_service.dart';
import '../services/sync_service.dart';
import '../services/transfer_sync_service.dart';
import '../widgets/agent_operations_list.dart';
import '../widgets/agent_capital_overview.dart';
import '../widgets/journal_caisse_widget.dart';
import '../widgets/flot_management_widget.dart';
import 'agent_login_page.dart';
import '../widgets/reports/agent_reports_widget.dart';
import '../widgets/rapportcloture.dart';
import '../widgets/agent_transactions_widget.dart';
import '../widgets/change_devise_widget.dart';
import '../widgets/agent_stats_cards.dart';
import '../widgets/comptes_speciaux_widget.dart';
import '../widgets/audit_history_widget.dart';
import '../widgets/reconciliation_report_widget.dart';
import '../widgets/retrait_mobile_money_widget.dart';
import '../widgets/reports/dettes_intershop_report.dart';

class AgentDashboardPage extends StatefulWidget {
  const AgentDashboardPage({super.key});

  @override
  State<AgentDashboardPage> createState() => _AgentDashboardPageState();
}

class _AgentDashboardPageState extends State<AgentDashboardPage> {
  int _selectedIndex = 0;
  bool _isDisposed = false; // Track disposal state
  FlotNotificationService? _flotNotificationService;

  final List<String> _menuItems = [
    'Dashboard',
    'Nouvelle Transaction',
    'Transactions',
    'Change de Devises',
    'Partenaires',
    'Journal de Caisse',
    'Rapports',
    'FLOT',
    'Clôture Journalière',
    'Frais',
    'Dettes Intershop',
    'Configuration',
    'Retrait Mobile Money',
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
    Icons.account_balance,
    Icons.swap_horiz,
    Icons.settings,
    Icons.mobile_friendly,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _loadData();
        _setupFlotNotifications();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _flotNotificationService?.stopMonitoring();
    _flotNotificationService?.onNewFlotDetected = null; // Clear callback
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isDisposed || !mounted) return;

    try {
      if (!_isDisposed && mounted) {
        setState(() {});
      }

      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final operationService =
          Provider.of<OperationService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final agentService = Provider.of<AgentService>(context, listen: false);
      final flotService = Provider.of<FlotService>(context, listen: false);
      final transferSyncService =
          Provider.of<TransferSyncService>(context, listen: false);

      if (authService.currentAgent != null) {
        // Initialize TransferSyncService with the current shop ID (only if not already initialized)
        final shopId = authService.currentAgent!.shopId;
        if (shopId != null && shopId > 0) {
          // Check if already initialized by comparing shop IDs
          // This is a simple check - in a real app you might want a more robust solution
          try {
            await transferSyncService.initialize(shopId);
            debugPrint('🔄 TransferSyncService initialized for shop: $shopId');
          } catch (e) {
            debugPrint(
                '⚠️ TransferSyncService already initialized or error: $e');
          }
        }

        // Build the list of futures to wait for
        final futures = <Future>[
          shopService.loadShops(),
          agentService.loadAgents(),
          operationService.loadOperations(
              agentId: authService.currentAgent!.id),
        ];

        // Add flotService.loadFlots only if shopId is not null
        if (shopId != null) {
          futures.add(flotService.loadFlots(shopId: shopId, isAdmin: false));
        }

        // IMPORTANT: Recharger TOUS les services après sync
        await Future.wait(futures);

        debugPrint('🔄 _loadData: Rechargement des données après sync');
        debugPrint('   Agents disponibles: ${agentService.agents.length}');
        debugPrint('   Shops disponibles: ${shopService.shops.length}');
        debugPrint(
            '   Opérations pour agent ${authService.currentAgent!.id}: ${operationService.operations.length}');
        if (shopId != null) {
          debugPrint(
              '   FLOTs pour shop $shopId: ${flotService.flots.length} (maintenant gérés comme operations)');
        }
      }
    } catch (e) {
      debugPrint('❌ [AgentDashboard] Erreur chargement données: $e');

      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur chargement: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {});
      }
    }
  }

  /// Configure les notifications pour les flots entrants
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  void _setupFlotNotifications() {
    if (_isDisposed || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) return;

      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final flotService = Provider.of<FlotService>(context, listen: false);
      _flotNotificationService = FlotNotificationService();

      _flotNotificationService!.startMonitoring(
        shopId: authService.currentAgent?.shopId ?? 0,
        getFlots: () => flotService
            .flots, // Returns List<OperationModel> filtered by flotShopToShop (flots sont maintenant des operations)
      );

      // Définir le callback pour les nouvelles notifications de flots
      _flotNotificationService!.onNewFlotDetected = (title, message, flotId) {
        // CRITICAL: Check if widget is still mounted before accessing context
        if (_isDisposed || !mounted) {
          debugPrint('⚠️ [FLOT-NOTIF] Widget disposed, ignoring notification');
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(message),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(
                0xFF2563EB), // Bleu pour différencier des transferts
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'VOIR',
              textColor: Colors.white,
              onPressed: () {
                if (!_isDisposed && mounted) {
                  // Naviguer vers l'onglet FLOT
                  setState(() {
                    _selectedIndex = 7; // Index 7 = FLOT
                  });
                }
              },
            ),
          ),
        );
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isMobile = size.width <= 768;

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
          bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? const Color(0xFFDC2626).withOpacity(0.1)
                        : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      _menuIcons[index],
                      color: isSelected
                          ? const Color(0xFFDC2626)
                          : Colors.grey[600],
                    ),
                    title: Text(
                      _menuItems[index],
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : Colors.grey[800],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 14 : 16,
                      vertical: isTablet ? 3 : 4,
                    ),
                    leading: _buildMenuIcon(index, isSelected, isTablet),
                    title: Text(
                      _menuItems[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
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

  /// Construit l'icône du menu avec badge de notification pour FLOT (index 7)
  Widget _buildMenuIcon(int index, bool isSelected, bool isTablet) {
    // Index 7 = FLOT
    if (index == 7) {
      // Use the singleton instance directly instead of Provider
      final transferSync = TransferSyncService();
      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final currentShopId = authService.currentAgent?.shopId;

      // Obtenir le nombre de FLOTs en attente depuis TransferSyncService pour plus de précision
      final pendingFlotsCount = currentShopId != null
          ? transferSync.getPendingFlotsForShop(currentShopId).length
          : 0;

      // Debug logging for sidebar comparison
      debugPrint(
          '🔍 [SIDEBAR-FLOT] Shop ID: $currentShopId, Pending FLOTs count: $pendingFlotsCount');

      if (pendingFlotsCount > 0) {
        return badges.Badge(
          badgeContent: Text(
            pendingFlotsCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Colors.red,
          ),
          child: Icon(_menuIcons[7]),
        );
      }

      return Icon(_menuIcons[7]);
    }

    // Icône normale pour les autres items
    return Icon(
      _menuIcons[index],
      color: isSelected ? Colors.white : Colors.grey[600],
      size: isTablet ? 20 : 22,
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
        return const Center(
            child: Text('Nouvelle Transaction - À implémenter'));
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
      case 9:
        return _buildFraisContent();
      case 10:
        return _buildDettesIntershopContent();
      case 11:
        return _buildConfigurationContent();
      case 12:
        return _buildRetraitMobileMoneyContent();
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
                      isMobile
                          ? 'Vos opérations'
                          : 'Vue d\'ensemble de vos opérations',
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

  Widget _buildFraisContent() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final shopId = authService.currentAgent?.shopId;

    return ComptesSpeciauxWidget(
      shopId: shopId,
      isAdmin: false,
    );
  }

  Widget _buildDettesIntershopContent() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    // Changed: Pass null to show global view like admin
    // This ensures agents see the same data as admin - all intershop debts
    final shopId = null; // authService.currentAgent?.shopId;

    return DettesIntershopReport(
      shopId: shopId,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
    );
  }

  Widget _buildConfigurationContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFFDC2626),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFDC2626),
              tabs: [
                Tab(
                  icon: Icon(Icons.history),
                  text: 'Audit Trail',
                ),
                Tab(
                  icon: Icon(Icons.account_balance_wallet),
                  text: 'Réconciliation',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAuditTrailContent(),
                _buildReconciliationContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailContent() {
    return const AuditHistoryWidget(
      showFilters: true,
    );
  }

  Widget _buildReconciliationContent() {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final shopId = authService.currentAgent?.shopId;

    return ReconciliationReportWidget(
      shopId: shopId,
      showOnlyGaps: false,
    );
  }

  Widget _buildRetraitMobileMoneyContent() {
    return const RetraitMobileMoneyWidget();
  }

  Widget _buildBottomNavigation() {
    // Map pour convertir entre l'index desktop (13 items) et l'index mobile (6 items)
    int getMobileNavIndex(int desktopIndex) {
      // Dashboard=0, Rapports=1, FLOT=2, Frais=3, VIRTUEL=4, Config=5
      switch (desktopIndex) {
        case 0:
          return 0; // Dashboard
        case 6:
          return 1; // Rapports
        case 7:
          return 2; // FLOT
        case 9:
          return 3; // Frais
        case 12:
          return 4; // VIRTUEL (Retrait Mobile Money)
        case 11:
          return 5; // Config
        default:
          // Pour les items non mappés (1,2,3,4,5,8,10), retourner Dashboard
          debugPrint(
              '⚠️ [BottomNav] Index desktop $desktopIndex non mappé -> Dashboard');
          return 0;
      }
    }

    int getDesktopIndexFromMobile(int mobileIndex) {
      switch (mobileIndex) {
        case 0:
          return 0; // Dashboard
        case 1:
          return 6; // Rapports
        case 2:
          return 7; // FLOT
        case 3:
          return 9; // Frais
        case 4:
          return 12; // VIRTUEL
        case 5:
          return 11; // Config
        default:
          return 0;
      }
    }

    // S'assurer que currentIndex est valide AVANT de construire le widget
    final mobileIndex = getMobileNavIndex(_selectedIndex);
    // Double sécurité: clamp entre 0 et 5 (6 items)
    final validMobileIndex = mobileIndex.clamp(0, 5);

    if (mobileIndex != validMobileIndex) {
      debugPrint(
          '⚠️ [BottomNav] Index invalidé: $mobileIndex -> $validMobileIndex');
    }

    return BottomNavigationBar(
      currentIndex: validMobileIndex,
      onTap: (mobileIndex) {
        final desktopIndex = getDesktopIndexFromMobile(mobileIndex);
        setState(() => _selectedIndex = desktopIndex);
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
          icon: Icon(_menuIcons[0]),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(_menuIcons[6]),
          label: 'Rapports',
        ),
        BottomNavigationBarItem(
          icon: _buildFlotIconWithBadge(),
          label: 'FLOT',
        ),
        BottomNavigationBarItem(
          icon: Icon(_menuIcons[9]),
          label: 'Frais',
        ),
        BottomNavigationBarItem(
          icon: Icon(_menuIcons[12]),
          label: 'VIRTUEL',
        ),
        BottomNavigationBarItem(
          icon: Icon(_menuIcons[11]),
          label: 'Config',
        ),
      ],
    );
  }

  Widget _buildFlotIconWithBadge() {
    return Consumer<TransferSyncService>(
        builder: (context, transferSync, child) {
      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final currentShopId = authService.currentAgent?.shopId;

      // Use TransferSyncService for consistency with sidebar implementation
      final pendingFlotsCount = currentShopId != null
          ? transferSync.getPendingFlotsForShop(currentShopId).length
          : 0;

      // Debug logging to help diagnose the issue
      debugPrint(
          '🔍 [FLOT-BADGE] Shop ID: $currentShopId, Pending FLOTs count: $pendingFlotsCount');
      if (currentShopId != null) {
        final allPendingFlots =
            transferSync.getPendingFlotsForShop(currentShopId);
        debugPrint(
            '🔍 [FLOT-BADGE] All pending FLOTs for shop $currentShopId:');
        for (var i = 0; i < allPendingFlots.length; i++) {
          final flot = allPendingFlots[i];
          debugPrint(
              '   #$i: codeOps=${flot.codeOps}, type=${flot.type?.name}, status=${flot.statut?.name}, dest=${flot.shopDestinationId}');
        }
      }

      if (pendingFlotsCount > 0) {
        return badges.Badge(
          badgeContent: Text(
            pendingFlotsCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Color(0xFF2563EB),
          ),
          child: Icon(_menuIcons[7]),
        );
      }

      return Icon(_menuIcons[7]);
    });
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
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
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
      final currentAgent =
          Provider.of<AgentAuthService>(context, listen: false).currentAgent;
      final result =
          await syncService.syncAll(userId: currentAgent?.username ?? 'agent');

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
        content:
            const Text('Dialog de changement de mot de passe à implémenter'),
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
