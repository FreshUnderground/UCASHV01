import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/operation_service.dart';
import '../services/transfer_notification_service.dart';
import '../services/transfer_sync_service.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/footer_widget.dart';
import '../widgets/reports/agent_reports_widget.dart' as reports;
import '../widgets/agent_operations_widget.dart';
import '../widgets/transfer_validation_widget.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/offline_banner.dart';
import '../widgets/flot_management_widget.dart';
import '../widgets/comptes_speciaux_widget.dart';
import '../widgets/sync_monitor_widget.dart';
import '../widgets/virtual_transactions_widget.dart' as virtual_widget;
import '../widgets/language_selector.dart';
import '../widgets/agent_deletion_validation_widget.dart';
import '../widgets/reports/dettes_intershop_report.dart';
import '../services/deletion_service.dart';

class DashboardAgentPage extends StatefulWidget {
  const DashboardAgentPage({super.key});

  @override
  State<DashboardAgentPage> createState() => _DashboardAgentPageState();
}

class _DashboardAgentPageState extends State<DashboardAgentPage> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Opérations',
    'Validations',
    'Rapports',
    'FLOT',
    'Frais',
    'VIRTUEL',
    'Dettes Intershop',
    'Suppressions',
  ];

  final List<IconData> _menuIcons = [
    Icons.account_balance_wallet,
    Icons.check_circle,
    Icons.receipt_long,
    Icons.local_shipping,
    Icons.account_balance,
    Icons.mobile_friendly,
    Icons.swap_horiz,
    Icons.delete_sweep,
  ];

  @override
  void initState() {
    super.initState();
    // SyncService is now initialized in main.dart, so we don't need to initialize it here
    
    // Initialize TransferSyncService with shop ID
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = authService.currentUser?.shopId;
      
      if (shopId != null && shopId > 0) {
        try {
          final transferSyncService = TransferSyncService();
          await transferSyncService.initialize(shopId);
          debugPrint('✅ TransferSyncService initialisé pour shop: $shopId');
        } catch (e) {
          debugPrint('⚠️ Erreur initialisation TransferSyncService: $e');
        }
      } else {
        debugPrint('⚠️ Shop ID non disponible pour initialisation TransferSyncService');
      }
      
      // Démarrer la surveillance des transferts entrants
      final operationService = Provider.of<OperationService>(context, listen: false);
      final transferNotificationService = TransferNotificationService();
      
      transferNotificationService.startMonitoring(
        authService: authService,
        getOperations: () => operationService.operations,
      );
      
      // Définir le callback pour les nouvelles notifications
      transferNotificationService.onNewTransferDetected = (title, message, transferId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notification_important, color: Colors.white),
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
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'VOIR',
                textColor: Colors.white,
                onPressed: () {
                  // Naviguer vers l'onglet Validations
                  setState(() {
                    _selectedIndex = 1; // Index 1 = Validations (Opérations=0, Validations=1, Rapports=2)
                  });
                },
              ),
            ),
          );
        }
      };
      
      // Trigger synchronization of operation data when dashboard opens
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Données des opérations synchronisées'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('ℹ️ Synchronisation des opérations ignorée (shop ID non disponible)');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la synchronisation des opérations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la synchronisation des opérations'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    // Arrêter la surveillance des transferts
    TransferNotificationService().stopMonitoring();
    super.dispose();
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



  PreferredSizeWidget _buildAppBar() {
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
            'UCASH Agent',
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
        if (!isMobile) const ConnectivityIndicator(),
        if (!isMobile) const SizedBox(width: 4),
        // Bouton de synchronisation manuelle
        ManualSyncButton(
          syncService: SyncService(),
          onSyncComplete: () {
            // Rafraîchir les données après sync
            setState(() {});
          },
        ),
        SizedBox(width: isMobile ? 4 : 8),
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
                    mainAxisSize: MainAxisSize.min,
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
                    mainAxisSize: MainAxisSize.min,
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
        SizedBox(width: isMobile ? 4 : 8),
      ],
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
                  // Logo UCASH
                  Container(
                    height: isMobile ? 50 : 60,
                    width: isMobile ? 50 : 60,
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
                  leading: Icon(_menuIcons[index]),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _menuItems[index],
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (index == 1) // Index 1 = Validations
                        _buildValidationBadge(),
                    ],
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
    return Container(
      width: 260,
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF48bb78), Color(0xFF38a169)],
              ),
            ),
            child: Column(
              children: [
                // Logo UCASH
                Container(
                  height: 70,
                  width: 70,
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
                const SizedBox(height: 12),
                const Text(
                  'UCASH Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF48bb78).withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _menuIcons[index],
                      color: isSelected ? const Color(0xFF38a169) : Colors.grey[600],
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _menuItems[index],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF38a169) : Colors.grey[800],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (index == 1) // Index 1 = Validations
                          _buildValidationBadge(),
                      ],
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

  Widget _buildBottomNavigation() {
    // Bottom navigation avec seulement 4 items: Operations, Validation, Rapports, FLOT
    final bottomNavItems = [
      {'index': 0, 'icon': _menuIcons[0], 'label': _menuItems[0]}, // Opérations
      {'index': 1, 'icon': _menuIcons[1], 'label': _menuItems[1]}, // Validations
      {'index': 2, 'icon': _menuIcons[2], 'label': _menuItems[2]}, // Rapports
      {'index': 3, 'icon': _menuIcons[3], 'label': _menuItems[3]}, // FLOT
    ];

    return BottomNavigationBar(
      currentIndex: (() {
        final index = bottomNavItems.indexWhere((item) => item['index'] == _selectedIndex);
        // Si _selectedIndex n'est pas dans bottomNavItems, retourner 0 (Opérations)
        if (index == -1) {
          debugPrint('⚠️ [BottomNav] _selectedIndex $_selectedIndex non trouvé dans bottomNavItems, defaulting to 0');
          return 0;
        }
        return index;
      })(),
      onTap: (bottomIndex) {
        setState(() {
          _selectedIndex = bottomNavItems[bottomIndex]['index'] as int;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF48bb78),
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      items: bottomNavItems.map((item) {
        final index = item['index'] as int;
        return BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item['icon'] as IconData),
              if (index == 1) // Index 1 = Validations
                Positioned(
                  right: -8,
                  top: -4,
                  child: _buildValidationBadge(),
                ),
            ],
          ),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildValidationBadge() {
    return Consumer<TransferSyncService>(
      builder: (context, transferSync, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) return const SizedBox.shrink();
        
        final pendingCount = transferSync.getPendingTransfersForShop(currentShopId).length;
        
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
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

Widget _buildMainContent() {
  final size = MediaQuery.of(context).size;
  final isMobile = size.width <= 768;

  // Widgets qui gèrent leur propre layout (ne pas les mettre dans SingleChildScrollView)
  final widgetsWithOwnLayout = [0, 1, 2, 3, 4, 5, 6, 7]; // Opérations, Validations, Rapports, FLOT, Frais, VIRTUEL, Dettes, Suppressions

  Widget content = switch (_selectedIndex) {
    0 => _buildOperationsContent(),   // Opérations
    1 => _buildValidationsContent(),  // Validations
    2 => _buildReportsContent(),      // Rapports
    3 => _buildFlotContent(),         // Gestion FLOT
    4 => _buildFraisContent(),        // Frais
    5 => _buildVirtuelContent(),      // VIRTUEL
    6 => _buildDettesIntershopContent(), // Dettes Intershop
    7 => const AgentDeletionValidationWidget(), // Suppressions
    _ => _buildOperationsContent(),
  };

  // Tous les widgets gèrent leur propre scroll
  return Padding(
    padding: EdgeInsets.all(isMobile ? 16 : 24),
    child: content,
  );
}

  Widget _buildOperationsContent() {
    return const AgentOperationsWidget();
  }

  Widget _buildValidationsContent() {
    return const TransferValidationWidget();
  }

  Widget _buildReportsContent() {
    return const reports.AgentReportsWidget();
  }

  Widget _buildFlotContent() {
    return const FlotManagementWidget();
  }

  Widget _buildFraisContent() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    return ComptesSpeciauxWidget(
      shopId: shopId,
      isAdmin: false,
    );
  }

  Widget _buildVirtuelContent() {
    return const virtual_widget.VirtualTransactionsWidget();
  }

  Widget _buildDettesIntershopContent() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    return DettesIntershopReport(
      shopId: shopId,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
    );
  }

  Future<void> _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
  }
}