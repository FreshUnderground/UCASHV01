import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/flot_service.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../widgets/dashboard_card.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class AgentDashboardWidget extends StatefulWidget {
  final Function(int)? onTabChanged;
  
  const AgentDashboardWidget({super.key, this.onTabChanged});

  @override
  State<AgentDashboardWidget> createState() => _AgentDashboardWidgetState();
}

class _AgentDashboardWidgetState extends State<AgentDashboardWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null && currentUser?.shopId != null) {
      // Charger TOUS les clients (globaux - accessible depuis tous les shops)
      Provider.of<ClientService>(context, listen: false).loadClients();
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId!);
      Provider.of<ShopService>(context, listen: false).loadShops();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final padding = isMobile ? 16.0 : (size.width <= 1024 ? 20.0 : 24.0);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message de bienvenue
          _buildWelcomeSection(),
          context.verticalSpace(mobile: 24, tablet: 32, desktop: 40),
          
          // Statistiques principales
          _buildMainStats(),
          context.verticalSpace(mobile: 24, tablet: 32, desktop: 40),
          
          // Actions rapides
          _buildQuickActions(),
          context.verticalSpace(mobile: 24, tablet: 32, desktop: 40),
          
          // Activité récente
          _buildRecentActivity(),
          
          // Espace en bas pour éviter le collé au bord
          SizedBox(height: padding),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final currentUser = authService.currentUser;
        final now = DateTime.now();
        final hour = now.hour;
        String greeting;
        
        if (hour < 12) {
          greeting = 'Bonjour';
        } else if (hour < 17) {
          greeting = 'Bon après-midi';
        } else {
          greeting = 'Bonsoir';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, ${currentUser?.username ?? 'Agent'} !',
              style: context.h1.copyWith(
                color: const Color(0xFF2D3748),
              ),
            ),
            context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
            Text(
              'Voici un aperçu de votre activité',
              style: context.bodySecondary,
            ),
            context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
            context.badgeContainer(
              backgroundColor: const Color(0xFFDC2626).withOpacity(0.1),
              child: Text(
                '${now.day}/${now.month}/${now.year} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: context.badge.copyWith(
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainStats() {
    return Consumer4<ClientService, OperationService, ShopService, FlotService>(
      builder: (context, clientService, operationService, shopService, flotService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null || currentUser?.shopId == null) {
          return _buildLoadingStats();
        }

        final clientStats = _getClientStats(clientService, currentUser!.shopId!);
        final shopStats = _getShopStats(shopService, currentUser.shopId!);
        
        // Use FutureBuilder to handle async operation stats
        return FutureBuilder<Map<String, dynamic>>(
          future: _getOperationStats(operationService, flotService, currentUser.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingStats();
            }
            
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }
            
            final operationStats = snapshot.data!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistiques du jour',
                  style: context.h3.copyWith(
                    color: const Color(0xFF374151),
                  ),
                ),
                context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
                
                // Grille de statistiques responsive
                context.gridContainer(
                  mobileColumns: 2,
                  tabletColumns: 2,
                  desktopColumns: 4,
                  aspectRatio: context.isSmallScreen ? 1.2 : 1.0,
                  children: [
                    _buildStatCard(
                      'Clients Actifs',
                      '${clientStats['activeClients']}',
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Opérations Aujourd\'hui',
                      '${operationStats['operationsToday']}',
                      Icons.swap_horiz,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Cash en Caisse',
                      '${shopStats['cashDisponible'].toStringAsFixed(0)} USD',
                      Icons.account_balance_wallet,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Commissions Gagnées',
                      '${operationStats['totalCommissions'].toStringAsFixed(0)} USD',
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques du jour',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Clients Actifs',
                '...',
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Transactions Aujourd\'hui',
                '...',
                Icons.swap_horiz,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return context.statContainer(
      backgroundColor: Colors.white,
      borderColor: color.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon, 
                color: color, 
                size: context.fluidIcon(mobile: 20, tablet: 24, desktop: 28),
              ),
              Flexible(
                child: Text(
                  value,
                  style: context.statValue.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
          Text(
            title,
            style: context.statLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: context.h3.copyWith(
            color: const Color(0xFF374151),
          ),
        ),
        context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
        
        context.gridContainer(
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 3,
          aspectRatio: context.isSmallScreen ? 1.1 : 1.0,
          children: [
            DashboardCard(
              title: 'Nouveau Client',
              icon: Icons.person_add,
              color: Colors.blue,
              onTap: () => _navigateToClients(),
            ),
            DashboardCard(
              title: 'Nouvelle Opération',
              icon: Icons.add_circle_outline,
              color: Colors.green,
              onTap: () => _navigateToOperations(),
            ),
            DashboardCard(
              title: 'Mes Clients',
              icon: Icons.people,
              color: Colors.orange,
              onTap: () => _navigateToClients(),
            ),
            DashboardCard(
              title: 'Validations',
              icon: Icons.check_circle,
              color: Colors.purple,
              onTap: () => _navigateToValidations(),
            ),
            DashboardCard(
              title: 'Transferts',
              icon: Icons.send,
              color: Colors.indigo,
              onTap: () => _navigateToTransfers(),
            ),
            DashboardCard(
              title: 'Rapports',
              icon: Icons.analytics,
              color: Colors.teal,
              onTap: () => _navigateToReports(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.id == null) {
          return const SizedBox.shrink();
        }

        final recentOperations = operationService.operations
            .where((op) => op.agentId == currentUser!.id)
            .take(5)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activité récente',
                  style: context.h3.copyWith(
                    color: const Color(0xFF374151),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToOperations(),
                  child: Text('Voir tout', style: context.button.copyWith(color: const Color(0xFFDC2626))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (recentOperations.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.swap_horiz_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune transaction récente',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vos transactions apparaîtront ici',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: recentOperations.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final operation = recentOperations[index];
                    return _buildOperationItem(operation);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOperationItem(OperationModel operation) {
    Color statusColor;
    IconData statusIcon;
    
    switch (operation.statut) {
      case OperationStatus.enAttente:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case OperationStatus.validee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case OperationStatus.terminee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case OperationStatus.annulee:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Text(
        '${operation.typeLabel} - ${operation.destinataire}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getStatusLabel(operation.statut),
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
      onTap: () => _navigateToOperations(),
    );
  }

  void _navigateToClients() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(1); // Index 1 = Clients (identique pour mobile et desktop)
    }
  }

  void _navigateToOperations() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(2); // Index 2 = Opérations (identique pour mobile et desktop)
    }
  }

  void _navigateToValidations() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(3); // Index 3 = Validations (identique pour mobile et desktop)
    }
  }

  void _navigateToTransfers() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(4); // Index 4 = Transferts (desktop seulement)
    }
  }

  void _navigateToReports() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(6); // Index 6 = Rapports (sera mappé correctement pour mobile)
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showNavigationSnackBar(String tabName, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Cliquez sur l\'onglet "$tabName" pour accéder')),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // Calculer les statistiques des clients DEPUIS DONNEES LOCALES
  Map<String, dynamic> _getClientStats(ClientService clientService, int shopId) {
    // UTILISE LES DONNEES LOCALES (clients deja charges dans le service)
    final clients = clientService.clients.where((c) => c.shopId == shopId).toList();
    final activeClients = clients.where((c) => c.isActive).length;
    
    return {
      'totalClients': clients.length,
      'activeClients': activeClients,
      'inactiveClients': clients.length - activeClients,
    };
  }

  // Obtenir le libellé du statut
  String _getStatusLabel(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return 'En attente';
      case OperationStatus.validee:
        return 'Validée';
      case OperationStatus.terminee:
        return 'Terminée';
      case OperationStatus.annulee:
        return 'Annulée';
    }
  }

  // Calculer les statistiques des operations DEPUIS DONNEES LOCALES
  Future<Map<String, dynamic>> _getOperationStats(OperationService operationService, FlotService flotService, int agentId) async {
    final today = DateTime.now();
    // UTILISE LES DONNEES LOCALES (operations deja chargees dans le service)
    final todayOperations = operationService.operations.where((op) => 
      op.agentId == agentId &&
      op.dateOp.year == today.year &&
      op.dateOp.month == today.month &&
      op.dateOp.day == today.day
    ).toList();

    // Charger les FLOTs pour cet agent
    await flotService.loadFlots();
    final todayFlots = flotService.flots.where((flot) => 
      (flot.agentEnvoyeurId == agentId || flot.agentRecepteurId == agentId) &&
      flot.dateEnvoi.year == today.year &&
      flot.dateEnvoi.month == today.month &&
      flot.dateEnvoi.day == today.day
    ).toList();

    // CALCUL REEL: Montants par devise (utiliser le bon montant selon le type)
    double totalMontantUSD = 0.0;
    double totalMontantCDF = 0.0;
    double totalMontantUGX = 0.0;
    
    for (final op in todayOperations) {
      // Pour les transferts SOURCE, utiliser montantBrut (total reçu du client)
      // Pour les autres, utiliser montantNet
      final montant = (op.type == OperationType.transfertNational || 
                       op.type == OperationType.transfertInternationalSortant)
          ? op.montantBrut // TOTAL reçu pour les transferts sortants
          : op.montantNet; // Net pour les autres
      
      if (op.devise == 'USD') {
        totalMontantUSD += montant;
      } else if (op.devise == 'CDF') {
        totalMontantCDF += montant;
      } else if (op.devise == 'UGX') {
        totalMontantUGX += montant;
      }
    }
    
    // Ajouter les montants des FLOTs
    for (final flot in todayFlots) {
      if (flot.devise == 'USD') {
        totalMontantUSD += flot.montant;
      } else if (flot.devise == 'CDF') {
        totalMontantCDF += flot.montant;
      } else if (flot.devise == 'UGX') {
        totalMontantUGX += flot.montant;
      }
    }
    
    // CALCUL REEL: Commissions par devise (seulement pour les opérations, pas les FLOTs)
    final totalCommissionsUSD = todayOperations
        .where((op) => op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final totalCommissionsCDF = todayOperations
        .where((op) => op.devise == 'CDF')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final totalCommissionsUGX = todayOperations
        .where((op) => op.devise == 'UGX')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    
    // Compter par type d'operation
    final depots = todayOperations.where((op) => op.type == OperationType.depot).length;
    final retraits = todayOperations.where((op) => op.type == OperationType.retrait).length;
    final transferts = todayOperations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).length;
    
    // Compter les FLOTs
    final flots = todayFlots.length;

    return {
      'operationsToday': todayOperations.length + flots, // Inclure les FLOTs dans le total
      // Montants par devise
      'totalMontantUSD': totalMontantUSD,
      'totalMontantCDF': totalMontantCDF,
      'totalMontantUGX': totalMontantUGX,
      'totalMontant': totalMontantUSD, // Pour compatibilite (USD par defaut)
      // Commissions par devise
      'totalCommissionsUSD': totalCommissionsUSD,
      'totalCommissionsCDF': totalCommissionsCDF,
      'totalCommissionsUGX': totalCommissionsUGX,
      'totalCommissions': totalCommissionsUSD, // Pour compatibilite (USD par defaut)
      // Par type
      'depots': depots,
      'retraits': retraits,
      'transferts': transferts,
      'flots': flots, // Ajout des FLOTs
    };
  }

  // Calculer les statistiques du shop (cash en caisse) DEPUIS DONNEES LOCALES MULTI-DEVISES
  Map<String, dynamic> _getShopStats(ShopService shopService, int shopId) {
    
    // UTILISE LES DONNEES LOCALES (shops deja charges dans le service)
    final currentShop = shopService.shops.firstWhere(
      (shop) => shop.id == shopId,
      orElse: () => ShopModel(designation: 'Inconnu', localisation: ''),
    );

    // CALCUL REEL: Capital total devise principale (USD)
    final capitalTotalUSD = currentShop.capitalCash + currentShop.capitalAirtelMoney + 
                           currentShop.capitalMPesa + currentShop.capitalOrangeMoney;
    
    // CALCUL REEL: Capital total devise secondaire (CDF ou UGX)
    final capitalTotalDevise2 = (currentShop.capitalCashDevise2 ?? 0) + 
                                (currentShop.capitalAirtelMoneyDevise2 ?? 0) + 
                                (currentShop.capitalMPesaDevise2 ?? 0) + 
                                (currentShop.capitalOrangeMoneyDevise2 ?? 0);

    return {
      // Devise principale (USD)
      'cashDisponible': currentShop.capitalCash,
      'airtelMoney': currentShop.capitalAirtelMoney,
      'mPesa': currentShop.capitalMPesa,
      'orangeMoney': currentShop.capitalOrangeMoney,
      'capitalTotal': capitalTotalUSD,
      // Devise secondaire (CDF ou UGX)
      'devisePrincipale': currentShop.devisePrincipale,
      'deviseSecondaire': currentShop.deviseSecondaire,
      'cashDisponibleDevise2': currentShop.capitalCashDevise2 ?? 0,
      'airtelMoneyDevise2': currentShop.capitalAirtelMoneyDevise2 ?? 0,
      'mPesaDevise2': currentShop.capitalMPesaDevise2 ?? 0,
      'orangeMoneyDevise2': currentShop.capitalOrangeMoneyDevise2 ?? 0,
      'capitalTotalDevise2': capitalTotalDevise2,
      'hasDeviseSecondaire': currentShop.hasDeviseSecondaire,
    };
  }
}
