import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../widgets/client_account_summary.dart';
import '../widgets/client_transaction_history.dart';
import '../widgets/client_profile_widget.dart';
import '../widgets/connectivity_indicator.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Tableau de bord',
    'Historique',
    'Profil',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.history,
    Icons.person,
  ];

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  void _loadClientData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentClient = authService.currentClient;
    
    if (currentClient != null) {
      // Charger les opérations du client
      Provider.of<OperationService>(context, listen: false)
          .loadClientOperations(currentClient.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Sidebar (desktop/tablet uniquement)
          if (!isMobile) _buildSidebar(),
          
          // Contenu principal
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Contenu
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom navigation (mobile uniquement)
      bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Container(
      height: isMobile ? 100 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (isTablet ? 20 : 24),
          vertical: isMobile ? 12 : 0,
        ),
        child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(isTablet),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final client = authService.currentClient;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour ${client?.nom ?? 'Partenaire'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Espace UCASH',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const ConnectivityIndicator(),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const CircleAvatar(
                    backgroundColor: Color(0xFFDC2626),
                    radius: 18,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Déconnexion', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFDC2626),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Solde: ${client?.solde.toStringAsFixed(2) ?? '0.00'} USD',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopHeader(bool isTablet) {
    return Row(
      children: [
        // Titre de la page
        Expanded(
          child: Consumer<AuthService>(
            builder: (context, authService, child) {
              final client = authService.currentClient;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour ${client?.nom ?? 'Partenaire'}',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  Text(
                    'Bienvenue dans votre espace UCASH',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        // Actions
        Row(
          children: [
            // Indicateur de connectivité
            const ConnectivityIndicator(),
            SizedBox(width: isTablet ? 12 : 16),
            
            // Solde rapide
            Consumer<AuthService>(
              builder: (context, authService, child) {
                final client = authService.currentClient;
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 14 : 16,
                    vertical: isTablet ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: const Color(0xFFDC2626),
                        size: isTablet ? 14 : 16,
                      ),
                      SizedBox(width: isTablet ? 6 : 8),
                      Text(
                        '${client?.solde.toStringAsFixed(2) ?? '0.00'} USD',
                        style: TextStyle(
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(width: isTablet ? 12 : 16),
            
            // Menu utilisateur
            PopupMenuButton<String>(
              icon: const CircleAvatar(
                backgroundColor: Color(0xFFDC2626),
                child: Icon(Icons.person, color: Colors.white),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Se déconnecter'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
          // Logo et titre
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
                    'UCASH Client',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Votre espace personnel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Menu
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

  Widget _buildBottomNavigation() {
    // S'assurer que currentIndex est valide
    final validIndex = _selectedIndex.clamp(0, _menuItems.length - 1);
    
    return BottomNavigationBar(
      currentIndex: validIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFDC2626),
      unselectedItemColor: Colors.grey,
      items: _menuItems.asMap().entries.map((entry) {
        return BottomNavigationBarItem(
          icon: Icon(_menuIcons[entry.key]),
          label: entry.value,
        );
      }).toList(),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildHistoryContent();
      case 2:
        return _buildProfileContent();
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
          // Résumé du compte
          const ClientAccountSummary(),
          SizedBox(height: isMobile ? 20 : 24),
          
          // Dernières transactions
          Text(
            'Dernières Transactions',
            style: TextStyle(
              fontSize: isMobile ? 18 : (isTablet ? 19 : 20),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          const ClientTransactionHistory(limit: 5),
        ],
      ),
    );
  }


  Widget _buildHistoryContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique des Transactions',
            style: TextStyle(
              fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Expanded(
            child: ClientTransactionHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mon Profil',
            style: TextStyle(
              fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          const ClientProfileWidget(),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/client-login');
      }
    }
  }
}