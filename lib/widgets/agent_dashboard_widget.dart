import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/flot_service.dart';
import '../services/local_db.dart';
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

  void _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null && currentUser?.shopId != null) {
      // IMPORTANT: Charger les shops EN PREMIER pour éviter "shop inconnu"
      debugPrint('🏪 Chargement des shops...');
      await Provider.of<ShopService>(context, listen: false).loadShops();
      debugPrint('✅ Shops chargés');
      
      // Charger TOUS les clients (globaux - accessible depuis tous les shops)
      Provider.of<ClientService>(context, listen: false).loadClients();
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId!);
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
          // Actions rapides
          _buildQuickActions(),
          context.verticalSpace(mobile: 24, tablet: 32, desktop: 40),
          
          // Activité récente
          _buildRecentActivity(),
          
          // Transferts, Servis et En Attente
          _buildTransfersSection(),
          
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
        final isMobile = MediaQuery.of(context).size.width < 600;
        String greeting;
        
        if (hour < 12) {
          greeting = 'Bonjour';
        } else if (hour < 17) {
          greeting = 'Bon après-midi';
        } else {
          greeting = 'Bonsoir';
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A11CB).withOpacity(0.3),
                  blurRadius: isMobile ? 12 : 20,
                  offset: Offset(0, isMobile ? 6 : 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${currentUser?.username ?? 'Agent'} !',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 10),
                  Text(
                    'Voici un aperçu de votre activité',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 17,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 20),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 16,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                    ),
                    child: Text(
                      '${now.day}/${now.month}/${now.year} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isMobile = context.isSmallScreen;
    final isTablet = MediaQuery.of(context).size.width > 768 && MediaQuery.of(context).size.width <= 1024;
    final isSmallMobile = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: isMobile ? 8 : 12,
              offset: Offset(0, isMobile ? 2 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : (isTablet ? 12 : 14)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 24 : (isTablet ? 28 : 32),
                ),
              ),
              SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallMobile ? 11 : (isMobile ? 12 : (isTablet ? 13 : 15)),
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 6 : (isTablet ? 8 : 10)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallMobile ? 16 : (isMobile ? 18 : (isTablet ? 21 : 24)),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NOUVEAU: Carte statistique avec affichage USD + Devise Locale
  Widget _buildStatCardDualCurrency(
    String title, 
    double montantUSD, 
    double montantDeviseLocale, 
    String deviseLocale,
    IconData icon, 
    Color color,
  ) {
    final isMobile = context.isSmallScreen;
    final isTablet = MediaQuery.of(context).size.width > 768 && MediaQuery.of(context).size.width <= 1024;
    final isSmallMobile = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: isMobile ? 8 : 12,
              offset: Offset(0, isMobile ? 2 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : (isTablet ? 12 : 14)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 24 : (isTablet ? 28 : 32),
                ),
              ),
              SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallMobile ? 11 : (isMobile ? 12 : (isTablet ? 13 : 15)),
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 6 : (isTablet ? 8 : 10)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${montantUSD.toStringAsFixed(2)} \$',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 15 : (isMobile ? 16 : (isTablet ? 19 : 22)),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (montantDeviseLocale > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${montantDeviseLocale.toStringAsFixed(2)} $deviseLocale',
                    style: TextStyle(
                      fontSize: isSmallMobile ? 12 : (isMobile ? 13 : (isTablet ? 15 : 17)),
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: context.h3.copyWith(
            color: const Color(0xFF374151),
          ),
        ),
        context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
        context.gridContainer(
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 5,
          aspectRatio: context.isSmallScreen ? 1.2 : 0.9,
          children: [
            _buildActionCard(
              'Nouveau Transfert',
              Icons.send,
              const Color(0xFF6A11CB),
              () => _navigateToTransfers(),
            ),
            _buildActionCard(
              'Dépôt',
              Icons.add,
              const Color(0xFF2575FC),
              () => _navigateToOperations(),
            ),
            _buildActionCard(
              'Retrait',
              Icons.remove,
              const Color(0xFF20BF6B),
              () => _navigateToOperations(),
            ),
            _buildActionCard(
              'Change Devises',
              Icons.currency_exchange,
              const Color(0xFFF7B731),
              () => _safeNavigateToTab(3), // Index 3 = Change de Devises
            ),
            _buildActionCard(
              'Rapports',
              Icons.analytics,
              const Color(0xFF4B7BEC),
              () => _safeNavigateToTab(6), // Index 6 = Rapports
            ),
            _buildActionCard(
              'Frais',
              Icons.account_balance,
              const Color(0xFF8B5CF6),
              () => _safeNavigateToTab(9), // Index 9 = Frais
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: isMobile ? 8 : 12,
              offset: Offset(0, isMobile ? 2 : 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isMobile ? 24 : 32,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.shopId == null) {
          return const SizedBox.shrink();
        }

        // Filtrer par shopId pour afficher TOUTES les opérations du shop
        final recentOperations = operationService.operations
            .where((op) => op.shopSourceId == currentUser!.shopId || op.shopDestinationId == currentUser.shopId)
            .toList()
          ..sort((a, b) => b.dateOp.compareTo(a.dateOp)); // Trier par date décroissante
        
        final displayedOperations = recentOperations.take(5).toList();

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
            
            if (displayedOperations.isEmpty)
              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 600;
                  return Container(
                    padding: EdgeInsets.all(isMobile ? 20 : 32),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.swap_horiz_outlined, size: isMobile ? 36 : 48, color: Colors.grey),
                          SizedBox(height: isMobile ? 12 : 16),
                          Text(
                            'Aucune transaction récente',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          Text(
                            'Vos transactions apparaîtront ici',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 600;
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      itemCount: displayedOperations.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final operation = displayedOperations[index];
                        return _buildOperationItem(operation);
                      },
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildOperationItem(OperationModel operation) {
    final isMobile = MediaQuery.of(context).size.width < 600;
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: isMobile ? 6 : 8,
              offset: Offset(0, isMobile ? 1 : 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 8 : 12,
          ),
          leading: Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
            ),
            child: Icon(statusIcon, color: statusColor, size: isMobile ? 20 : 24),
          ),
          title: Text(
            '${operation.typeLabel} - ${operation.destinataire}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 13 : 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isMobile ? 4 : 6),
              Text(
                '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                '${operation.dateOp.day}/${operation.dateOp.month}/${operation.dateOp.year}',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            ),
            child: Text(
              _getStatusLabel(operation.statut),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 11 : 13,
              ),
            ),
          ),
          onTap: () => _navigateToOperations(),
        ),
      ),
    );
  }

  void _navigateToClients() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(1); // Index 1 = Opérations (nouveau mapping)
    }
  }

  void _navigateToOperations() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(1); // Index 1 = Opérations
    }
  }

  void _navigateToValidations() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(2); // Index 2 = Validations
    }
  }

  void _navigateToTransfers() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(2); // Index 2 = Validations (transferts = validations)
    }
  }

  void _navigateToReports() {
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(6); // Index 6 = Rapports (correct)
    }
  }

  // Navigation sécurisée avec vérification d'index
  void _safeNavigateToTab(int index) {
    if (widget.onTabChanged != null) {
      // Vérifier que l'index est dans les limites valides (0-8)
      if (index >= 0 && index <= 8) {
        widget.onTabChanged!(index);
      } else {
        debugPrint('⚠️ Erreur: Index $index hors limites (0-8)');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur de navigation'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
  Future<Map<String, dynamic>> _getOperationStats(OperationService operationService, FlotService flotService, int shopId) async {  // Changed parameter from agentId to shopId
    final today = DateTime.now();
    final shopService = Provider.of<ShopService>(context, listen: false);
    final currentShop = shopService.shops.firstWhere(
      (shop) => shop.id == shopId,
      orElse: () => ShopModel(designation: 'Inconnu', localisation: ''),
    );
    
    // UTILISE LES DONNEES LOCALES (operations deja chargees dans le service)
    // FILTRE PAR SHOP au lieu de agentId pour afficher toutes les operations du shop
    final todayOperations = operationService.operations.where((op) => 
      (op.shopSourceId == shopId || op.shopDestinationId == shopId) &&  // Changed filter to shopId
      op.dateOp.year == today.year &&
      op.dateOp.month == today.month &&
      op.dateOp.day == today.day
    ).toList();

    // Utiliser les FLOTs déjà chargés dans le service au lieu de recharger
    // FILTRE PAR SHOP: FLOTs envoyés depuis ce shop OU reçus vers ce shop
    final todayFlots = flotService.flots.where((flot) => 
      (flot.shopSourceId == shopId || flot.shopDestinationId == shopId) &&  // Changed filter to shopId
      flot.dateEnvoi.year == today.year &&
      flot.dateEnvoi.month == today.month &&
      flot.dateEnvoi.day == today.day
    ).toList();

    // CALCUL DU CASH DISPONIBLE DU JOUR selon la formule:
    // Cash Disponible = (Solde Antérieur + Dépôts + FLOT En Cours + FLOT Reçu + Transfert Reçu) - (Transfert Servi + Retraits + FLOT Servi)
    
    // 1. Solde Antérieur : Récupérer le solde SAISI de la clôture précédente
    double soldeAnterieurUSD = 0.0;
    double soldeAnterieurDeviseLocale = 0.0;
    
    try {
      // Chercher la clôture d'hier
      final yesterday = today.subtract(const Duration(days: 1));
      final clotureHier = await LocalDB.instance.getClotureCaisseByDate(shopId, yesterday);
      
      if (clotureHier != null) {
        // Utiliser le solde SAISI de la clôture d'hier comme solde antérieur d'aujourd'hui
        soldeAnterieurUSD = clotureHier.soldeSaisiTotal;
        // Note: Pour la devise locale, on devrait avoir des champs séparés dans ClotureCaisseModel
        // Pour l'instant, on utilise 0 car le modèle actuel ne stocke que l'USD
      } else {
        // Pas de clôture hier, utiliser le capital du shop comme fallback
        soldeAnterieurUSD = currentShop.capitalCash + currentShop.capitalAirtelMoney + 
                            currentShop.capitalMPesa + currentShop.capitalOrangeMoney;
        soldeAnterieurDeviseLocale = (currentShop.capitalCashDevise2 ?? 0) + 
                                     (currentShop.capitalAirtelMoneyDevise2 ?? 0) + 
                                     (currentShop.capitalMPesaDevise2 ?? 0) + 
                                     (currentShop.capitalOrangeMoneyDevise2 ?? 0);
      }
    } catch (e) {
      // En cas d'erreur, utiliser le capital du shop
      soldeAnterieurUSD = currentShop.capitalCash + currentShop.capitalAirtelMoney + 
                          currentShop.capitalMPesa + currentShop.capitalOrangeMoney;
      soldeAnterieurDeviseLocale = (currentShop.capitalCashDevise2 ?? 0) + 
                                   (currentShop.capitalAirtelMoneyDevise2 ?? 0) + 
                                   (currentShop.capitalMPesaDevise2 ?? 0) + 
                                   (currentShop.capitalOrangeMoneyDevise2 ?? 0);
    }
    
    // 2. Dépôts du jour (clients qui déposent)
    final depotsUSD = todayOperations
        .where((op) => op.type == OperationType.depot && op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    final depotsDeviseLocale = todayOperations
        .where((op) => op.type == OperationType.depot && (op.devise == 'CDF' || op.devise == 'UGX'))
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    
    // 3. FLOT Reçu (FLOTs vers nous: en cours + servis reçus aujourd'hui)
    final flotRecuUSD = todayFlots
        .where((flot) => flot.shopDestinationId == shopId && flot.devise == 'USD')
        .fold<double>(0.0, (sum, flot) => sum + flot.montant);
    final flotRecuDeviseLocale = todayFlots
        .where((flot) => flot.shopDestinationId == shopId && (flot.devise == 'CDF' || flot.devise == 'UGX'))
        .fold<double>(0.0, (sum, flot) => sum + flot.montant);
    
    // 4. FLOT Envoyé (FLOTs par nous: en cours + servis envoyés aujourd'hui)
    final flotEnvoyeUSD = todayFlots
        .where((flot) => flot.shopSourceId == shopId && flot.devise == 'USD')
        .fold<double>(0.0, (sum, flot) => sum + flot.montant);
    final flotEnvoyeDeviseLocale = todayFlots
        .where((flot) => flot.shopSourceId == shopId && (flot.devise == 'CDF' || flot.devise == 'UGX'))
        .fold<double>(0.0, (sum, flot) => sum + flot.montant);
    
    // 5. Transferts Reçus (client nous paie - ENTRÉE)
    final transfertRecuUSD = todayOperations
        .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) && 
                       op.shopSourceId == shopId && op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final transfertRecuDeviseLocale = todayOperations
        .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) && 
                       op.shopSourceId == shopId && (op.devise == 'CDF' || op.devise == 'UGX'))
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    
    // 6. Transferts Servis (on sert le client - SORTIE)
    final transfertServiUSD = todayOperations
        .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) && 
                       op.shopDestinationId == shopId && op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    final transfertServiDeviseLocale = todayOperations
        .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) && 
                       op.shopDestinationId == shopId && (op.devise == 'CDF' || op.devise == 'UGX'))
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    
    // 7. Retraits du jour (clients qui retirent)
    final retraitsUSD = todayOperations
        .where((op) => op.type == OperationType.retrait && op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    final retraitsDeviseLocale = todayOperations
        .where((op) => op.type == OperationType.retrait && (op.devise == 'CDF' || op.devise == 'UGX'))
        .fold<double>(0.0, (sum, op) => sum + op.montantNet);
    
    // FORMULE FINALE: Cash Disponible du Jour
    // (Solde Ant. + Depot + FLOT Recu + Transfert Recu) - (Retrait + FLOT Envoyé + Transfert Servi)
    final cashDisponibleJourUSD = (soldeAnterieurUSD + depotsUSD + flotRecuUSD + transfertRecuUSD) - 
                                  (retraitsUSD + flotEnvoyeUSD + transfertServiUSD);
    final cashDisponibleJourDeviseLocale = (soldeAnterieurDeviseLocale + depotsDeviseLocale + flotRecuDeviseLocale + transfertRecuDeviseLocale) - 
                                           (retraitsDeviseLocale + flotEnvoyeDeviseLocale + transfertServiDeviseLocale);

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
      // Cash Disponible du Jour (NOUVEAU - selon la formule)
      'cashDisponibleJourUSD': cashDisponibleJourUSD,
      'cashDisponibleJourDeviseLocale': cashDisponibleJourDeviseLocale,
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
      'totalCommissionsDeviseLocale': totalCommissionsCDF, // NOUVEAU: CDF par défaut
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
      'deviseLocale': currentShop.deviseSecondaire ?? 'CDF', // NOUVEAU: Pour compat
      'cashDisponibleDeviseLocale': currentShop.capitalCashDevise2 ?? 0, // NOUVEAU
      'cashDisponibleDevise2': currentShop.capitalCashDevise2 ?? 0,
      'airtelMoneyDevise2': currentShop.capitalAirtelMoneyDevise2 ?? 0,
      'mPesaDevise2': currentShop.capitalMPesaDevise2 ?? 0,
      'orangeMoneyDevise2': currentShop.capitalOrangeMoneyDevise2 ?? 0,
      'capitalTotalDevise2': capitalTotalDevise2,
      'hasDeviseSecondaire': currentShop.hasDeviseSecondaire,
    };
  }

  Widget _buildTransfersSection() {
    return Consumer3<OperationService, ShopService, AuthService>(
      builder: (context, operationService, shopService, authService, child) {
        final currentShopId = authService.currentUser?.shopId;
        if (currentShopId == null) return const SizedBox.shrink();
        
        // Filtrer les opérations pour le shop courant
        final operations = operationService.operations
            .where((op) => 
                op.shopSourceId == currentShopId || 
                op.shopDestinationId == currentShopId)
            .toList();
        
        // Grouper par source et destination
        final Map<String, List<OperationModel>> transfersByRoute = {};
        
        for (final op in operations) {
          if (op.type == OperationType.transfertNational || 
              op.type == OperationType.transfertInternationalSortant ||
              op.type == OperationType.transfertInternationalEntrant) {
            
            final sourceShop = shopService.getShopById(op.shopSourceId ?? 0);
            final destShop = shopService.getShopById(op.shopDestinationId ?? 0);
            
            final sourceName = sourceShop?.designation ?? 'Shop ${op.shopSourceId}';
            final destName = destShop?.designation ?? 'Shop ${op.shopDestinationId}';
            final routeKey = '$sourceName → $destName';
            
            if (!transfersByRoute.containsKey(routeKey)) {
              transfersByRoute[routeKey] = [];
            }
            transfersByRoute[routeKey]!.add(op);
          }
        }
        
        if (transfersByRoute.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transferts par Route',
              style: context.h3.copyWith(
                color: const Color(0xFF374151),
              ),
            ),
            context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transfersByRoute.length,
              itemBuilder: (context, index) {
                final routeKey = transfersByRoute.keys.elementAt(index);
                final operations = transfersByRoute[routeKey]!;
                
                // Calculer les stats pour cette route
                int servedCount = 0;
                int pendingCount = 0;
                double totalAmount = 0.0;
                
                for (final op in operations) {
                  if (op.statut == OperationStatus.validee) {
                    servedCount++;
                  } else if (op.statut == OperationStatus.enAttente) {
                    pendingCount++;
                  }
                  totalAmount += op.montantNet;
                }
                
                return Card(
                  margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: isMobile ? 8 : 12,
                          offset: Offset(0, isMobile ? 2 : 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.swap_horiz,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  routeKey,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Stats row
                          Row(
                            children: [
                              _buildTransferStatCard(
                                'Servis',
                                servedCount.toString(),
                                Icons.check_circle,
                                Colors.green,
                                isMobile,
                              ),
                              const SizedBox(width: 12),
                              _buildTransferStatCard(
                                'En Attente',
                                pendingCount.toString(),
                                Icons.hourglass_empty,
                                Colors.orange,
                                isMobile,
                              ),
                              const SizedBox(width: 12),
                              _buildTransferStatCard(
                                'Total',
                                '${totalAmount.toStringAsFixed(2)} \$',
                                Icons.attach_money,
                                const Color(0xFFDC2626),
                                isMobile,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Operations list
                          if (operations.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'Détails (${operations.length} transferts)',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: isMobile ? 120 : 150,
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                itemCount: operations.length > 3 ? 3 : operations.length,
                                itemBuilder: (context, i) {
                                  final op = operations[i];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(op.statut).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            _getStatusIcon(op.statut),
                                            color: _getStatusColor(op.statut),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${op.typeLabel} - ${op.destinataire ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: isMobile ? 11 : 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${op.montantNet.toStringAsFixed(2)} \$',
                                          style: TextStyle(
                                            fontSize: isMobile ? 11 : 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildTransferStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isMobile ? 16 : 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return Colors.orange;
      case OperationStatus.validee:
        return Colors.green;
      case OperationStatus.terminee:
        return Colors.blue;
      case OperationStatus.annulee:
        return Colors.red;
    }
  }
  
  IconData _getStatusIcon(OperationStatus status) {
    switch (status) {
      case OperationStatus.enAttente:
        return Icons.hourglass_empty;
      case OperationStatus.validee:
        return Icons.check_circle;
      case OperationStatus.terminee:
        return Icons.check_circle_outline;
      case OperationStatus.annulee:
        return Icons.cancel;
    }
  }
}
