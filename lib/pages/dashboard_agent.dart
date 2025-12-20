import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_model.dart';
import '../services/agent_auth_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/operation_service.dart';
import '../services/transfer_notification_service.dart';
import '../services/transfer_sync_service.dart';
import '../services/rapport_cloture_service.dart';
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
import '../widgets/agent_triangular_debt_settlement_widget.dart';
import '../widgets/reports/dettes_intershop_report.dart';
import '../widgets/cloture_required_dialog.dart';

import '../services/connectivity_service.dart';

class TrianglePainter extends CustomPainter {
  final Color color;

  const TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardAgentPage extends StatefulWidget {
  const DashboardAgentPage({super.key});

  @override
  State<DashboardAgentPage> createState() => _DashboardAgentPageState();
}

class _DashboardAgentPageState extends State<DashboardAgentPage> {
  int _selectedIndex = 0;
  List<DateTime>? _joursNonClotures; // Cache des jours non clôturés
  bool _isCheckingClosure = false;

  final List<String> _menuItems = [
    'Opérations',
    'Validations',
    'Rapports',
    'FLOT',
    'Frais',
    'VIRTUEL',
    'Dettes Intershop',
    'Regul.', // Règlement Triangulaire
    'Suppressions',
  ];

  // Index constants for easier maintenance
  static const int MENU_INDEX_OPERATIONS = 0;
  static const int MENU_INDEX_VALIDATIONS = 1;
  static const int MENU_INDEX_REPORTS = 2;
  static const int MENU_INDEX_FLOT = 3;
  static const int MENU_INDEX_FRAIS = 4;
  static const int MENU_INDEX_VIRTUEL = 5;
  static const int MENU_INDEX_DETTES_INTERSHOP = 6;
  static const int MENU_INDEX_TRIANGULAR = 7;
  static const int MENU_INDEX_SUPPRESSIONS = 8;

  // Liste des menus visibles (filtrée selon l'agent)
  List<int> _getVisibleMenuIndices(AgentModel? currentAgent) {
    final visibleMenus = <int>[];
    
    // Tous les menus sont visibles par défaut
    for (int i = 0; i < _menuItems.length; i++) {
      // Masquer le menu triangulaire si l'agent n'a pas de shopId
      if (i == MENU_INDEX_TRIANGULAR && (currentAgent?.shopId == null)) {
        continue; // Skip this menu
      }
      visibleMenus.add(i);
    }
    
    return visibleMenus;
  }

  final List<IconData> _menuIcons = [
    Icons.account_balance_wallet,
    Icons.check_circle,
    Icons.receipt_long,
    Icons.local_shipping,
    Icons.account_balance,
    Icons.mobile_friendly,
    Icons.swap_horiz,
    Icons.change_circle, // NEW - Triangular settlement icon
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
          // Use the singleton instance from Provider instead of creating a new one
          final transferSyncService = Provider.of<TransferSyncService>(context, listen: false);
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
      
      // Vérifier les clôtures au démarrage
      _checkClotureAtStartup();
    });
  }
  
  // Function to trigger synchronization of operation data
  void _triggerOperationSync() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Only proceed if user is an agent with a shop ID
      if (authService.currentUser?.role == 'AGENT' && authService.currentUser?.shopId != null) {
        // Use the singleton instance from Provider instead of creating a new one
        final transferSyncService = Provider.of<TransferSyncService>(context, listen: false);
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
  
    // Vérifier les clôtures au démarrage
  Future<void> _checkClotureAtStartup() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId != null && shopId > 0) {
      final joursNonClotures = await RapportClotureService.instance.verifierAccesMenusAgent(shopId);
      if (mounted) {
        setState(() {
          _joursNonClotures = joursNonClotures;
        });
      }
    }
  }
  
  // Vérifier si l'accès au menu est autorisé (indices 0, 1, 3 = Operations, Validations, FLOT)
  // Retourne true si l'accès est autorisé, false sinon
  Future<bool> _verifierAccesMenu(int index) async {
    // Seuls les menus Operations (0), Validations (1), et FLOT (3) nécessitent la vérification
    if (index != 0 && index != 1 && index != 3) {
      return true; // Autres menus accessibles sans vérification
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null || shopId <= 0) {
      return true; // Pas de shop ID, on laisse passer
    }
    
    // TOUJOURS vérifier depuis LocalDB (pas de cache pour éviter les faux positifs)
    debugPrint('🔍 Vérification des clôtures pour shop $shopId...');
    setState(() => _isCheckingClosure = true);
    
    final joursNonClotures = await RapportClotureService.instance.verifierAccesMenusAgent(shopId);
    
    if (mounted) {
      setState(() {
        _joursNonClotures = joursNonClotures;
        _isCheckingClosure = false;
      });
    }
    
    // Si pas de jours non clôturés, accès autorisé
    if (joursNonClotures == null || joursNonClotures.isEmpty) {
      debugPrint('✅ Toutes les journées sont clôturées - accès autorisé');
      return true;
    }
    
    debugPrint('⚠️ ${joursNonClotures.length} jour(s) non clôturé(s) - affichage du dialog');
    
    // Afficher le dialog de clôture
    final result = await ClotureRequiredDialog.show(
      context,
      shopId: shopId,
      joursNonClotures: joursNonClotures,
    );
    
    if (result) {
      // Clôtures effectuées, attendre un peu et recharger le cache
      debugPrint('🔄 Re-vérification après clôture...');
      await Future.delayed(const Duration(milliseconds: 300));
      
      final newJoursNonClotures = await RapportClotureService.instance.verifierAccesMenusAgent(shopId);
      if (mounted) {
        setState(() {
          _joursNonClotures = newJoursNonClotures;
        });
      }
      
      // Vérifier si toutes les clôtures ont bien été enregistrées
      if (newJoursNonClotures == null || newJoursNonClotures.isEmpty) {
        debugPrint('✅ Toutes les clôtures confirmées - accès autorisé');
        return true;
      } else {
        debugPrint('⚠️ Encore ${newJoursNonClotures.length} jour(s) non clôturé(s)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Encore ${newJoursNonClotures.length} jour(s) à clôturer. Veuillez réessayer.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    }
    
    return false; // Accès refusé
  }
  
  /// Synchroniser les données avant d'accéder aux rapports/clôtures
  /// Seulement si la connexion internet est disponible
  Future<void> _syncBeforeCloture() async {
    // Vérifier la connectivité
    final isConnected = ConnectivityService.instance.isOnline;
    
    if (!isConnected) {
      debugPrint('📡 Pas de connexion - synchronisation ignorée');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('Mode hors-ligne - données locales uniquement'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Afficher le dialog de synchronisation
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF48bb78)),
            SizedBox(height: 24),
            Text(
              '🔄 Synchronisation en cours...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Récupération des dernières données',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
    
    try {
      debugPrint('🔄 [RAPPORTS] Synchronisation des opérations avant clôture...');
      
      // Synchroniser UNIQUEMENT la table operations via TransferSyncService
      final transferSyncService = Provider.of<TransferSyncService>(context, listen: false);
      await transferSyncService.forceRefreshFromAPI();
      
      debugPrint('✅ [RAPPORTS] Opérations synchronisées');
      
      // Fermer le dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Données synchronisées avec succès'),
              ],
            ),
            backgroundColor: Color(0xFF48bb78),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [RAPPORTS] Erreur sync: $e');
      
      // Fermer le dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning_amber, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Synchronisation partielle - utilisation des données locales')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
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
                      // Triangle indicateur de sélection
                      if (true)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: CustomPaint(
                            size: const Size(10, 20),
                            painter: const TrianglePainter(
                              color: Color(0xFF38a169),
                            ),
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
            child: Consumer<AgentAuthService>(
              builder: (context, agentAuthService, child) {
                final visibleMenuIndices = _getVisibleMenuIndices(agentAuthService.currentAgent);
                
                return ListView.builder(
                  itemCount: visibleMenuIndices.length,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemBuilder: (context, index) {
                    final actualIndex = visibleMenuIndices[index];
                    final isSelected = _selectedIndex == actualIndex;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF48bb78).withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _menuIcons[actualIndex],
                          color: isSelected ? const Color(0xFF38a169) : Colors.grey[600],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _menuItems[actualIndex],
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF38a169) : Colors.grey[800],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (actualIndex == 1) // Index 1 = Validations
                              _buildValidationBadge(),
                            // Indicateur de clôture requise pour menus bloqués
                            if ((actualIndex == 0 || actualIndex == 1 || actualIndex == 3) && 
                                _joursNonClotures != null && 
                                _joursNonClotures!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock, color: Colors.white, size: 12),
                              ),
                          ],
                        ),
                        onTap: () async {
                          final canAccess = await _verifierAccesMenu(actualIndex);
                          if (canAccess && mounted) {
                            // Si c'est le menu Rapports (index 2), synchroniser d'abord
                            if (actualIndex == 2) {
                              await _syncBeforeCloture();
                            }
                            if (mounted) {
                              setState(() {
                                _selectedIndex = actualIndex;
                              });
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final bottomNavItems = [
      {'index': 0, 'icon': _menuIcons[0], 'label': _menuItems[0]}, // Opérations
      {'index': 1, 'icon': _menuIcons[1], 'label': _menuItems[1]}, // Validations
      {'index': 2, 'icon': _menuIcons[2], 'label': _menuItems[2]}, // Rapports
      {'index': 3, 'icon': _menuIcons[3], 'label': _menuItems[3]}, // FLOT
    ];

    return BottomNavigationBar(
      currentIndex: (() {
        final index = bottomNavItems.indexWhere((item) => item['index'] == _selectedIndex);
        if (index == -1) {
          debugPrint('⚠️ [BottomNav] _selectedIndex $_selectedIndex non trouvé dans bottomNavItems, defaulting to 0');
          return 0;
        }
        return index;
      })(),
      onTap: (bottomIndex) async {
        final targetIndex = bottomNavItems[bottomIndex]['index'] as int;
        final canAccess = await _verifierAccesMenu(targetIndex);
        if (canAccess && mounted) {
          if (targetIndex == 2) {
            await _syncBeforeCloture();
          }
          if (mounted) {
            setState(() {
              _selectedIndex = targetIndex;
            });
          }
        }
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
              if (index == 3) // Index 3 = FLOT
                Positioned(
                  right: -8,
                  top: -4,
                  child: _buildFlotBadge(),
                ),
            ],
          ),
          label: item['label'] as String,
        );
      }).toList(),
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
            child: Consumer<AgentAuthService>(
              builder: (context, agentAuthService, child) {
                final visibleMenuIndices = _getVisibleMenuIndices(agentAuthService.currentAgent);
                
                return ListView.builder(
                  itemCount: visibleMenuIndices.length,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemBuilder: (context, index) {
                    final actualIndex = visibleMenuIndices[index];
                    final isSelected = _selectedIndex == actualIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF48bb78).withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _menuIcons[actualIndex],
                          color: isSelected ? const Color(0xFF38a169) : Colors.grey[600],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _menuItems[actualIndex],
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF38a169) : Colors.grey[800],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (actualIndex == 1) // Index 1 = Validations
                              _buildValidationBadge(),
                            // Indicateur de clôture requise pour menus bloqués
                            if ((actualIndex == 0 || actualIndex == 1 || actualIndex == 3) && 
                                _joursNonClotures != null && 
                                _joursNonClotures!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lock, color: Colors.white, size: 12),
                              ),
                          ],
                        ),
                        onTap: () async {
                          final canAccess = await _verifierAccesMenu(actualIndex);
                          if (canAccess && mounted) {
                            // Si c'est le menu Rapports (index 2), synchroniser d'abord
                            if (actualIndex == 2) {
                              await _syncBeforeCloture();
                            }
                            if (mounted) {
                              setState(() {
                                _selectedIndex = actualIndex;
                              });
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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

  Widget _buildFlotBadge() {
    return Consumer<TransferSyncService>(
      builder: (context, transferSync, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) return const SizedBox.shrink();
        
        // Get pending FLOTs count
        final pendingFlotsCount = transferSync.getPendingFlotsForShop(currentShopId).length;
        
        if (pendingFlotsCount == 0) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue, // Blue color for FLOTs to differentiate from validations
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$pendingFlotsCount',
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

  Widget content = switch (_selectedIndex) {
    0 => _buildOperationsContent(),   // Opérations
    1 => _buildValidationsContent(),  // Validations
    2 => _buildReportsContent(),      // Rapports
    3 => _buildFlotContent(),         // Gestion FLOT
    4 => _buildFraisContent(),        // Frais
    5 => _buildVirtuelContent(),      // VIRTUEL
    6 => _buildDettesIntershopContent(), // Dettes Intershop
    7 => const AgentTriangularDebtSettlementWidget(), // Règlement Triangulaire
    8 => const AgentDeletionValidationWidget(), // Suppressions
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