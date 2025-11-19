import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/operation_model.dart';
import '../services/flot_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/local_db.dart';
import 'flot_dialog.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';
import 'package:intl/intl.dart';

/// Widget pour gérer les FLOTS (approvisionnement de liquidité entre shops)
class FlotManagementWidget extends StatefulWidget {
  const FlotManagementWidget({super.key});

  @override
  State<FlotManagementWidget> createState() => _FlotManagementWidgetState();
}

class _FlotManagementWidgetState extends State<FlotManagementWidget> {
  flot_model.StatutFlot? _filtreStatut;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chargerFlots();
    });
  }

  Future<void> _chargerFlots() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    
    debugPrint('🔄 Chargement des FLOTs - ShopID: $shopId, isAdmin: $isAdmin');
    
    await FlotService.instance.loadFlots(shopId: shopId, isAdmin: isAdmin);
    
    final flotService = Provider.of<FlotService>(context, listen: false);
    debugPrint('✅ FLOTs chargés: ${flotService.flots.length} total');
    
    if (shopId != null && !isAdmin) {
      final mesFlots = flotService.flots.where((f) => 
        f.shopSourceId == shopId || f.shopDestinationId == shopId
      ).toList();
      debugPrint('   → Mes FLOTs: ${mesFlots.length}');
      
      final flotsEnCours = mesFlots.where((f) => f.statut == flot_model.StatutFlot.enRoute).toList();
      debugPrint('   → En cours: ${flotsEnCours.length}');
      
      final flotsServis = mesFlots.where((f) => f.statut == flot_model.StatutFlot.servi).toList();
      debugPrint('   → Servis: ${flotsServis.length}');
      
      final flotsAnnules = mesFlots.where((f) => f.statut == flot_model.StatutFlot.annule).toList();
      debugPrint('   → Annulés: ${flotsAnnules.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade700, Colors.blue.shade600],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_shipping_rounded, size: 26),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Gestion des FLOT',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 18 : 22,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 24),
              onPressed: _chargerFlots,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildHeaderInfo(),
          _buildModernFiltres(),
          _buildListe(),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.shade600, Colors.blue.shade500],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _afficherDialogueNouveauFlot(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: Text(
            isMobile ? 'Nouveau' : 'Nouveau FLOT',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Consumer4<FlotService, AuthService, ShopService, OperationService>(
      builder: (context, flotService, authService, shopService, operationService, child) {
        final currentShopId = authService.currentUser?.shopId;
        if (currentShopId == null) return const SizedBox.shrink();
        
        final currentShop = shopService.getShopById(currentShopId);
        if (currentShop == null) return const SizedBox.shrink();
        
        // NOUVELLE LOGIQUE: Calculer les dettes et créances inter-shop
        final Map<int, double> soldesParShop = {};
        
        // 1. TRANSFERTS SERVIS PAR NOUS (shop source nous doit directement)
        for (final op in operationService.operations) {
          if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) &&
              op.shopDestinationId == currentShopId && // Nous servons le client
              op.devise == 'USD') {
            final autreShopId = op.shopSourceId; // Shop qui a reçu l'argent du client
            if (autreShopId != null) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + op.montantNet;
            }
          }
        }
        
        // 2. TRANSFERTS REÇUS/INITIÉS PAR NOUS (on doit à l'autre shop)
        for (final op in operationService.operations) {
          if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) &&
              op.shopSourceId == currentShopId && // Client nous a payé
              op.devise == 'USD') {
            final autreShopId = op.shopDestinationId; // Shop qui va servir
            if (autreShopId != null) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - op.montantNet;
            }
          }
        }
        
        // 3. FLOTS EN COURS - Deux sens selon qui a initié
        for (final flot in flotService.flots) {
          if (flot.statut == flot_model.StatutFlot.enRoute && flot.devise == 'USD') {
            if (flot.shopSourceId == currentShopId) {
              // NOUS avons envoyé en cours → Ils nous doivent rembourser
              final autreShopId = flot.shopDestinationId;
              if (autreShopId != null) {
                soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montant;
              }
            } else if (flot.shopDestinationId == currentShopId) {
              // ILS ont envoyé en cours → On leur doit rembourser
              final autreShopId = flot.shopSourceId;
              if (autreShopId != null) {
                soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montant;
              }
            }
          }
        }
        
        // 4. FLOTS REÇUS ET SERVIS (shopDestinationId = nous) → On leur doit rembourser
        for (final flot in flotService.flots) {
          if (flot.shopDestinationId == currentShopId &&
              flot.statut == flot_model.StatutFlot.servi &&
              flot.devise == 'USD') {
            final autreShopId = flot.shopSourceId;
            if (autreShopId != null) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montant;
            }
          }
        }
        
        // 5. FLOTS ENVOYÉS ET SERVIS (shopSourceId = nous) → Ils nous doivent rembourser
        for (final flot in flotService.flots) {
          if (flot.shopSourceId == currentShopId &&
              flot.statut == flot_model.StatutFlot.servi &&
              flot.devise == 'USD') {
            final autreShopId = flot.shopDestinationId;
            if (autreShopId != null) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montant;
            }
          }
        }
        
        // Calculer les totaux
        double totalCreance = 0.0; // Ils nous doivent (solde > 0)
        double totalDette = 0.0;   // On leur doit (solde < 0)
        
        for (final solde in soldesParShop.values) {
          if (solde > 0) {
            totalCreance += solde;
          } else if (solde < 0) {
            totalDette += solde.abs();
          }
        }
        
        return Card(
          margin: EdgeInsets.all(ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
          elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
            ),
          ),
          child: Padding(
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(20),
              desktop: const EdgeInsets.all(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Votre Position Financière',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
                if (context.isSmallScreen)
                  Column(
                    children: [
                      _buildFinancialCard(
                        title: 'Vous devez',
                        amount: totalDette,
                        color: Colors.red,
                        icon: Icons.arrow_upward,
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      _buildFinancialCard(
                        title: 'On vous doit',
                        amount: totalCreance,
                        color: Colors.green,
                        icon: Icons.arrow_downward,
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      _buildFinancialCard(
                        title: 'Solde net',
                        amount: totalCreance - totalDette,
                        color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                        icon: Icons.account_balance,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'Vous devez',
                          amount: totalDette,
                          color: Colors.red,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'On vous doit',
                          amount: totalCreance,
                          color: Colors.green,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'Solde net',
                          amount: totalCreance - totalDette,
                          color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                          icon: Icons.account_balance,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Container(
                  padding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.all(12),
                    tablet: const EdgeInsets.all(14),
                    desktop: const EdgeInsets.all(16),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info, 
                        color: Colors.blue, 
                        size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 18, desktop: 20),
                      ),
                      SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                      Expanded(
                        child: Text(
                          'ℹ️ Les approvisionnements (FLOT) réduisent vos dettes envers d\'autres shops',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFinancialCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModernFiltres() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.blue.shade400],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filtrer par statut',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildModernFilterChip(
                label: 'Tous',
                icon: Icons.apps_rounded,
                selected: _filtreStatut == null,
                color: Colors.grey.shade700,
                onTap: () => setState(() => _filtreStatut = null),
              ),
              _buildModernFilterChip(
                label: 'En Route',
                icon: Icons.local_shipping_rounded,
                selected: _filtreStatut == flot_model.StatutFlot.enRoute,
                color: Colors.orange.shade600,
                onTap: () => setState(() => _filtreStatut = flot_model.StatutFlot.enRoute),
              ),
              _buildModernFilterChip(
                label: 'Servi',
                icon: Icons.check_circle_rounded,
                selected: _filtreStatut == flot_model.StatutFlot.servi,
                color: Colors.green.shade600,
                onTap: () => setState(() => _filtreStatut = flot_model.StatutFlot.servi),
              ),
              _buildModernFilterChip(
                label: 'Annulé',
                icon: Icons.cancel_rounded,
                selected: _filtreStatut == flot_model.StatutFlot.annule,
                color: Colors.red.shade600,
                onTap: () => setState(() => _filtreStatut = flot_model.StatutFlot.annule),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: selected ? null : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListe() {
    return Consumer<FlotService>(
      builder: (context, flotService, child) {
        if (flotService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var flots = flotService.flots;
        
        // Appliquer le filtre
        if (_filtreStatut != null) {
          flots = flots.where((f) => f.statut == _filtreStatut).toList();
        }

        if (flots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(64),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun flot', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: flots.map((flot) => _buildFlotCard(flot)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFlotCard(flot_model.FlotModel flot) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    final isDestination = flot.shopDestinationId == currentShopId;
    final peutMarquerServi = isDestination && flot.statut == flot_model.StatutFlot.enRoute;
    final peutModifier = flot.shopSourceId == currentShopId && flot.statut == flot_model.StatutFlot.enRoute;
    final peutSupprimer = flot.shopSourceId == currentShopId && flot.statut == flot_model.StatutFlot.enRoute;
    final isMobile = MediaQuery.of(context).size.width < 600;

    Color statutColor;
    IconData statutIcon;
    String statutDescription;
    
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statutColor = Colors.orange.shade600;
        statutIcon = Icons.local_shipping_rounded;
        statutDescription = 'En attente de réception';
        break;
      case flot_model.StatutFlot.servi:
        statutColor = Colors.green.shade600;
        statutIcon = Icons.check_circle_rounded;
        statutDescription = 'Reçu par le destinataire';
        break;
      case flot_model.StatutFlot.annule:
        statutColor = Colors.red.shade600;
        statutIcon = Icons.cancel_rounded;
        statutDescription = 'Annulé';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: statutColor.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statutColor.withOpacity(0.1),
                    statutColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Circular icon with gradient
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [statutColor, statutColor.withOpacity(0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statutColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(statutIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  
                  // Status label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flot.statutLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: statutColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statutDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade600, Colors.blue.shade500],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${flot.montant.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          flot.devise,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Shops info with modern design
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildModernShopInfo(
                    title: 'Expéditeur',
                    shopName: flot.shopSourceDesignation,
                    isCurrentShop: flot.shopSourceId == currentShopId,
                    icon: Icons.upload_rounded,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_downward_rounded, color: Colors.grey.shade400, size: 20),
                  ),
                  const SizedBox(height: 16),
                  _buildModernShopInfo(
                    title: 'Destinataire',
                    shopName: flot.shopDestinationDesignation,
                    isCurrentShop: flot.shopDestinationId == currentShopId,
                    icon: Icons.download_rounded,
                    color: Colors.green.shade600,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dates in modern cards
            Row(
              children: [
                Expanded(
                  child: _buildModernDateCard(
                    icon: Icons.send_rounded,
                    label: 'Envoyé',
                    date: flot.dateEnvoi,
                    color: Colors.orange.shade600,
                  ),
                ),
                if (flot.dateReception != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernDateCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Reçu',
                      date: flot.dateReception!,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ],
            ),
            
            if (flot.reference != null || (flot.notes != null && flot.notes!.isNotEmpty)) ...[
              const SizedBox(height: 16),
              if (flot.reference != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag_rounded, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Réf: ${flot.reference}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (flot.notes != null && flot.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_rounded, size: 18, color: Colors.amber.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              flot.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            
            if (peutModifier || peutSupprimer || peutMarquerServi) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              
              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (peutModifier)
                    _buildModernActionButton(
                      label: 'Modifier',
                      icon: Icons.edit_rounded,
                      color: Colors.blue.shade600,
                      onPressed: () => _afficherDialogueModifierFlot(flot),
                    ),
                  if (peutSupprimer)
                    _buildModernActionButton(
                      label: 'Supprimer',
                      icon: Icons.delete_rounded,
                      color: Colors.red.shade600,
                      onPressed: () => _supprimerFlot(flot),
                    ),
                  if (peutMarquerServi)
                    _buildModernActionButton(
                      label: 'Marquer SERVI',
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade600,
                      onPressed: () => _marquerServi(flot),
                      gradient: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernShopInfo({
    required String title,
    required String shopName,
    required bool isCurrentShop,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                shopName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (isCurrentShop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.blue.shade500],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Vous',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModernDateCard({
    required IconData icon,
    required String label,
    required DateTime date,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool gradient = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: gradient
            ? LinearGradient(colors: [color, color.withOpacity(0.8)])
            : null,
        color: gradient ? null : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradient ? Colors.transparent : color.withOpacity(0.3)),
        boxShadow: gradient
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: gradient ? Colors.white : color,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gradient ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _marquerServi(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final agentId = authService.currentUser?.id;
    final agentUsername = authService.currentUser?.username;

    if (agentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la réception'),
        content: Text(
          'Confirmez-vous avoir reçu ${flot.montant.toStringAsFixed(2)} ${flot.devise} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FlotService.instance.marquerFlotServi(
        flotId: flot.id!,
        agentRecepteurId: agentId,
        agentRecepteurUsername: agentUsername,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Flot marqué comme servi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _afficherDialogueNouveauFlot() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FlotDialog(currentShopId: shopId),
    );

    if (result == true && mounted) {
      await _chargerFlots();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Flot créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Add this new method for editing a flot
  Future<void> _afficherDialogueModifierFlot(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    // Vérifier que l'utilisateur peut modifier ce flot
    if (flot.shopSourceId != shopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Vous ne pouvez modifier que vos propres flots')),
      );
      return;
    }

    if (flot.statut != flot_model.StatutFlot.enRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Seuls les flots en cours peuvent être modifiés')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FlotDialog(flot: flot, currentShopId: shopId),
    );

    if (result == true && mounted) {
      await _chargerFlots();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Flot mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Add this new method for deleting a flot
  Future<void> _supprimerFlot(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    // Vérifier que l'utilisateur peut supprimer ce flot
    if (flot.shopSourceId != shopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Vous ne pouvez supprimer que vos propres flots')),
      );
      return;
    }

    if (flot.statut != flot_model.StatutFlot.enRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Seuls les flots en cours peuvent être supprimés')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le flot de ${flot.montant.toStringAsFixed(2)} ${flot.devise} vers ${flot.shopDestinationDesignation} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await LocalDB.instance.deleteFlot(flot.id!); // This should work now
        await _chargerFlots();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Flot supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}