import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/pdf_service.dart';
import '../services/shop_service.dart';
import '../services/agent_auth_service.dart';
import '../services/agent_service.dart';
import '../services/flot_service.dart';
import '../services/transfer_sync_service.dart';
import '../models/operation_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../services/printer_service.dart';
import '../utils/auto_print_helper.dart';

import 'transfer_destination_dialog.dart';
import 'depot_dialog.dart';
import 'retrait_dialog.dart';
import 'operations_help_widget.dart';
import 'pdf_viewer_dialog.dart';


class AgentOperationsWidget extends StatefulWidget {
  const AgentOperationsWidget({super.key});

  @override
  State<AgentOperationsWidget> createState() => _AgentOperationsWidgetState();
}

class _AgentOperationsWidgetState extends State<AgentOperationsWidget> {
  String _searchQuery = '';
  OperationType? _typeFilter;
  bool _showFiltersAndStats = false; // Contrôle l'affichage des stats et filtres (masqué par défaut)
  String _categoryFilter = 'all'; // all, pending, my_transfers, my_withdrawals, my_served, my_deposits, my_flots
  // ❌ REMOVED: bool _includeFlots - FLOT operations now ONLY visible in 'my_flots' category

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOperations();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for shop changes to auto-refresh cash disponible
    Provider.of<ShopService>(context, listen: true);
  }

  void _loadOperations() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null) {
      // 1️⃣ D'ABORD: Synchroniser depuis l'API pour obtenir toutes les opérations fraîches
      final transferSync = Provider.of<TransferSyncService>(context, listen: false);
      debugPrint('🔄 [MES OPS] Synchronisation des opérations depuis l\'API...');
      await transferSync.forceRefreshFromAPI();
      debugPrint('✅ [MES OPS] Synchronisation terminée');
      
      // 2️⃣ ENSUITE: Charger les opérations filtrées par shop depuis LocalDB
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId!);
      debugPrint('📋 [MES OPS] Chargement des opérations pour shop ${currentUser.shopId}');
      
      // 3️⃣ CHARGER LES FLOTS: Charger les FLOTs pour ce shop
      await FlotService.instance.loadFlots(shopId: currentUser.shopId);
      debugPrint('📦 [MES OPS] Chargement des FLOTs pour shop ${currentUser.shopId}');
    }
  }

  Future<void> _generateReportPdf() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final agentAuthService = Provider.of<AgentAuthService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      final currentAgent = agentAuthService.currentAgent;
      
      if (currentUser == null || currentAgent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur: Utilisateur non connecté'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final shop = shopService.shops.firstWhere((s) => s.id == currentUser.shopId);
      final operations = _getFilteredOperations(operationService.operations);
      
      final pdfService = PdfService();
      final pdfDoc = await pdfService.generateOperationsReportPdf(
        operations: operations,
        shop: shop,
        agent: currentAgent,
        filterType: _typeFilter?.toString(),
      );
      
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDoc,
          title: 'Rapport d\'Opérations',
          fileName: 'rapport_operations_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<OperationModel> _getFilteredOperations(List<OperationModel> operations) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId ?? 0;
    
    return operations.where((operation) {
      // 1. Filter by search query
      final matchesSearch = _searchQuery.isEmpty ||
          (operation.destinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          operation.id.toString().contains(_searchQuery) ||
          (operation.codeOps?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // 2. Filter by operation type
      final matchesType = _typeFilter == null || operation.type == _typeFilter;
      
      
      // 4. Filter by category
      bool matchesCategory = true;
      switch (_categoryFilter) {
        case 'pending':
          // Operations en attente (transfers waiting for validation) - NO FLOT
          matchesCategory = 
              operation.statut == OperationStatus.enAttente &&
              operation.shopDestinationId == shopId; // Transfers I need to serve
          break;
        case 'my_transfers':
          // My sent transfers (all statuses) - NO FLOT
          matchesCategory = 
              (operation.type == OperationType.transfertNational ||
               operation.type == OperationType.transfertInternationalEntrant ||
               operation.type == OperationType.transfertInternationalSortant) &&
              operation.shopSourceId == shopId; // Transfers I sent
          break;
        case 'my_withdrawals':
          // My withdrawals - NO FLOT
          matchesCategory = operation.type == OperationType.retrait &&
              operation.shopSourceId == shopId;
          break;
        case 'my_served':
          // Transfers I validated/served - NO FLOT
          matchesCategory = 
              (operation.type == OperationType.transfertNational ||
               operation.type == OperationType.transfertInternationalEntrant ||
               operation.type == OperationType.transfertInternationalSortant) &&
              (operation.statut == OperationStatus.validee) &&
              operation.shopDestinationId == shopId; // Transfers I validated
          break;
        case 'my_deposits':
          // My deposits - NO FLOT
          matchesCategory = operation.type == OperationType.depot &&
              operation.shopSourceId == shopId;
          break;
        case 'my_flots':
          // My FLOTs (virements) ONLY
          matchesCategory = operation.type == OperationType.virement &&
              operation.shopSourceId == shopId;
          break;
        case 'all':
        default:
          matchesCategory = true;
      }
      
      return matchesSearch && matchesType && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    // ✨ Padding réduit pour maximiser l'espace
    final padding = isMobile ? 4.0 : 8.0;
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header avec boutons d'actions - Compact sur mobile
          _buildHeader(),
          SizedBox(height: isMobile ? 6 : 12),
          
          // Category Filter Tabs (like En attente/Mes Validations)
          _buildCategoryTabs(),
          SizedBox(height: isMobile ? 6 : 12),
          
          // Statistiques - Affichées uniquement si _showFiltersAndStats est true (Désactivé pour plus d'espace)
          // if (_showFiltersAndStats) ...[
          //   _buildStats(),
          //   SizedBox(height: isMobile ? 8 : 24),
          // ],
          
          // Liste des opérations - Prend l'espace nécessaire
          Flexible(
            fit: FlexFit.loose,
            child: _buildOperationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 10 : 12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre avec icône - Plus compact sur mobile
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: const Color(0xFFDC2626),
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    'Mes Opérations',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 6 : 12),
              
              // Boutons d'actions - Responsive
              if (isMobile)
                // Sur mobile: Boutons sur une seule ligne
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        onPressed: () => _showDepotDialog(),
                        icon: Icons.add_circle,
                        label: 'Dépôt',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        onPressed: () => _showRetraitDialog(),
                        icon: Icons.remove_circle,
                        label: 'Retrait',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        onPressed: () => _showTransfertDestinationDialog(),
                        icon: Icons.send,
                        label: 'Transf.',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      onPressed: () => _showDepotDialog(),
                      icon: Icons.add_circle,
                      label: 'Dépôt',
                      color: Colors.green,
                    ),
                    _buildActionButton(
                      onPressed: () => _showRetraitDialog(),
                      icon: Icons.remove_circle,
                      label: 'Retrait',
                      color: Colors.orange,
                    ),
                    _buildActionButton(
                      onPressed: () => _showTransfertDestinationDialog(),
                      icon: Icons.send,
                      label: isTablet ? 'Transfert' : 'Transfert Destination',
                      color: Colors.purple,
                    ),
                    _buildActionButton(
                      onPressed: _generateReportPdf,
                      icon: Icons.picture_as_pdf,
                      label: 'Rapport PDF',
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              SizedBox(height: isMobile ? 6 : 10),
              
              // Bouton pour afficher/masquer les filtres et stats - Plus compact
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _showFiltersAndStats = !_showFiltersAndStats;
                      });
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 16,
                      vertical: isMobile ? 4 : 8,
                    ),
                  ),
                  icon: Icon(
                    _showFiltersAndStats ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFFDC2626),
                    size: isMobile ? 18 : 24,
                  ),
                  label: Text(
                    _showFiltersAndStats ? 'Masquer' : 'Filtres',
                    style: TextStyle(
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ),
              ),
              
              // Barre de recherche et filtres - Affichés uniquement si _showFiltersAndStats est true
              if (_showFiltersAndStats) ...[
                SizedBox(height: isMobile ? 12 : 16),
              if (isMobile)
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<OperationType?>(
                            value: _typeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Toutes')),
                              DropdownMenuItem(value: OperationType.depot, child: Text('Dépôts')),
                              DropdownMenuItem(value: OperationType.retrait, child: Text('Retraits')),
                              DropdownMenuItem(value: OperationType.transfertNational, child: Text('Nationaux')),
                              DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Sortants')),
                              DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Entrants')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _typeFilter = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _loadOperations,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualiser',
                          color: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Rechercher par client, destinataire ou référence...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<OperationType?>(
                        value: _typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Type d\'opération',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Toutes')),
                          DropdownMenuItem(value: OperationType.depot, child: Text('Dépôts')),
                          DropdownMenuItem(value: OperationType.retrait, child: Text('Retraits')),
                          DropdownMenuItem(value: OperationType.transfertNational, child: Text('Transferts Nationaux')),
                          DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Transferts Sortants')),
                          DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Transferts Entrants')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _typeFilter = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _loadOperations,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              ], // Fin du if _showFiltersAndStats
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 6 : 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryTabButton(
                label: 'Toutes',
                icon: Icons.list,
                value: 'all',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'En attente',
                icon: Icons.pending_actions,
                value: 'pending',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'Mes Transferts',
                icon: Icons.send,
                value: 'my_transfers',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'Mes Retraits',
                icon: Icons.remove_circle,
                value: 'my_withdrawals',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'Mes Servis',
                icon: Icons.check_circle,
                value: 'my_served',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'Mes Dépôts',
                icon: Icons.add_circle,
                value: 'my_deposits',
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              _buildCategoryTabButton(
                label: 'Mes Flots',
                icon: Icons.swap_horiz,
                value: 'my_flots',
                isMobile: isMobile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabButton({
    required String label,
    required IconData icon,
    required String value,
    required bool isMobile,
  }) {
    final isSelected = _categoryFilter == value;
    
    return ElevatedButton.icon(
        onPressed: () {
          if (mounted) {
            setState(() {
              _categoryFilter = value;
            });
          }
        },
        icon: Icon(
          icon,
          size: isMobile ? 14 : 16,
          color: isSelected ? Colors.white : const Color(0xFFDC2626),
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFDC2626),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFDC2626) : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFFDC2626),
          side: BorderSide(
            color: const Color(0xFFDC2626),
            width: isSelected ? 2 : 1,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isSelected ? 4 : 0,
        ),
      );
  }

  // Helper pour créer un bouton d'action
  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isMobile ? 16 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 10 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }

  // Widget _buildStats() {
  //   final size = MediaQuery.of(context).size;
  //   final isMobile = size.width <= 768;
    
  //   return Consumer3<OperationService, AuthService, ShopService>(
  //     builder: (context, operationService, authService, shopService, child) {
  //       final operations = operationService.operations;
        
  //       // Also get FLOTs for this shop
  //       final currentUser = authService.currentUser;
  //       final flotService = FlotService.instance;
        
  //       // Filter FLOTs by current shop (source or destination)
  //       List<flot_model.FlotModel> shopFlots = [];
  //       if (currentUser?.shopId != null) {
  //         shopFlots = flotService.flots.where((f) => 
  //           f.shopSourceId == currentUser!.shopId || 
  //           f.shopDestinationId == currentUser.shopId
  //         ).toList();
  //       } else {
  //         shopFlots = flotService.flots;
  //       }
        
  //       // Total operations should include both operations and FLOTs
  //       final totalOperations = operations.length + shopFlots.length;
        
  //       final depots = operations.where((op) => op.type == OperationType.depot).length;
  //       final retraits = operations.where((op) => op.type == OperationType.retrait).length;
  //       final transferts = operations.where((op) => 
  //         op.type == OperationType.transfertNational ||
  //         op.type == OperationType.transfertInternationalSortant ||
  //         op.type == OperationType.transfertInternationalEntrant
  //       ).length;
        
  //       // Add FLOT count
  //       final flotsCount = shopFlots.length;

  //       // Get cash disponible from shop stats
  //       double cashDisponibleUSD = 0;
  //       double cashDisponibleCDF = 0;
  //       if (currentUser?.shopId != null) {
  //         final shopStats = _getShopStats(shopService, currentUser!.shopId!);
  //         cashDisponibleUSD = shopStats['capitalTotal'] as double;
  //         cashDisponibleCDF = shopStats['capitalTotalDevise2'] as double;
  //       }

  //       if (isMobile) {
  //         // Layout mobile : Grid 3 colonnes x 2 lignes - Scrollable
  //         return SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Column(
  //             children: [
  //               // Ligne 1 : Total, Dépôts, Retraits
  //               Row(
  //                 children: [
  //                   SizedBox(
  //                     width: 80,
  //                     child: _buildStatCard(
  //                       'Total',
  //                       '$totalOperations',
  //                       Icons.analytics,
  //                       Colors.blue,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 6),
  //                   SizedBox(
  //                     width: 100,
  //                     child: _buildStatCard(
  //                       'Dépôts',
  //                       '$depots',
  //                       Icons.add_circle,
  //                       Colors.green,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 6),
  //                   SizedBox(
  //                     width: 100,
  //                     child: _buildStatCard(
  //                       'Retraits',
  //                       '$retraits',
  //                       Icons.remove_circle,
  //                       Colors.orange,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 6),
  //               // Ligne 2 : Transferts, FLOTs, Cash Disponible (3 colonnes)
  //               Row(
  //                 children: [
  //                   SizedBox(
  //                     width: 100,
  //                     child: _buildStatCard(
  //                       'Transferts',
  //                       '$transferts',
  //                       Icons.send,
  //                       const Color(0xFFDC2626),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 6),
  //                   SizedBox(
  //                     width: 100,
  //                     child: _buildStatCard(
  //                       'FLOTs',
  //                       '$flotsCount',
  //                       Icons.local_shipping,
  //                       const Color(0xFF9C27B0),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 6),
  //                   SizedBox(
  //                     width: 100,
  //                     child: _buildMultiDeviseCard(
  //                       'Cash Disponible',
  //                       cashDisponibleUSD,
  //                       cashDisponibleCDF,
  //                       Icons.account_balance_wallet,
  //                       Colors.purple,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         );
  //       } else {
  //         // Layout desktop : Row - Scrollable
  //         return SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Card(
  //             elevation: 2,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //             child: Padding(
  //               padding: const EdgeInsets.all(16),
  //               child: Row(
  //                 children: [
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildStatCard(
  //                       'Total Opérations',
  //                       '$totalOperations',
  //                       Icons.analytics,
  //                       Colors.blue,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildStatCard(
  //                       'Dépôts',
  //                       '$depots',
  //                       Icons.add_circle,
  //                       Colors.green,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildStatCard(
  //                       'Retraits',
  //                       '$retraits',
  //                       Icons.remove_circle,
  //                       Colors.orange,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildStatCard(
  //                       'Transferts',
  //                       '$transferts',
  //                       Icons.send,
  //                       const Color(0xFFDC2626),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildStatCard(
  //                       'FLOTs',
  //                       '$flotsCount',
  //                       Icons.local_shipping,
  //                       const Color(0xFF9C27B0),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   SizedBox(
  //                     width: 150,
  //                     child: _buildMultiDeviseCard(
  //                       'Cash Disponible',
  //                       cashDisponibleUSD,
  //                       cashDisponibleCDF,
  //                       Icons.account_balance_wallet,
  //                       Colors.purple,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       }
  //     },
  //   );
  // }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isSmallMobile = size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: isMobile ? 4 : 8,
            offset: Offset(0, isMobile ? 1 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 28),
          SizedBox(height: isMobile ? 3 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallMobile ? 13 : (isMobile ? 14 : 18),
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 3),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 11),
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Card pour affichage multi-devises
  Widget _buildMultiDeviseCard(String title, double montantUSD, double montantCDF, IconData icon, Color color) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isSmallMobile = size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: isMobile ? 4 : 8,
            offset: Offset(0, isMobile ? 1 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 28),
          SizedBox(height: isMobile ? 2 : 4),
          // USD
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${montantUSD.toStringAsFixed(0)} \$',
              style: TextStyle(
                fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 16),
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          // CDF
          if (montantCDF > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${montantCDF.toStringAsFixed(0)} FC',
                style: TextStyle(
                  fontSize: isSmallMobile ? 10 : (isMobile ? 11 : 14),
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
                maxLines: 1,
              ),
            ),
          SizedBox(height: isMobile ? 2 : 3),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallMobile ? 9 : (isMobile ? 10 : 11),
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsList() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        if (operationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (operationService.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${operationService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadOperations,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final filteredOperations = _getFilteredOperations(operationService.operations);

        // Get FLOTs for current shop
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        final flotService = FlotService.instance;
        
        // Filter FLOTs by current shop (source or destination)
        List<flot_model.FlotModel> shopFlots = [];
        if (currentUser?.shopId != null) {
          shopFlots = flotService.flots.where((f) => 
            f.shopSourceId == currentUser!.shopId || 
            f.shopDestinationId == currentUser.shopId
          ).toList();
        } else {
          shopFlots = flotService.flots;
        }

        // Combine operations and FLOTs for display
        final allItems = <dynamic>[...filteredOperations, ...shopFlots];
        
        // Sort by date (most recent first)
        allItems.sort((a, b) {
          DateTime dateA, dateB;
          
          if (a is OperationModel) {
            dateA = a.dateOp;
          } else if (a is flot_model.FlotModel) {
            dateA = a.dateReception ?? a.dateEnvoi;
          } else {
            dateA = DateTime.now();
          }
          
          if (b is OperationModel) {
            dateB = b.dateOp;
          } else if (b is flot_model.FlotModel) {
            dateB = b.dateReception ?? b.dateEnvoi;
          } else {
            dateB = DateTime.now();
          }
          
          return dateB.compareTo(dateA);
        });

        if (allItems.isEmpty) {
          return operationService.operations.isEmpty 
              ? const SingleChildScrollView(child: OperationsHelpWidget())
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune opération trouvée avec ces critères',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Modifiez vos critères de recherche ou créez une nouvelle opération',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
        }

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: ListView.separated(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            itemCount: allItems.length,
            separatorBuilder: (context, index) => Divider(height: isMobile ? 12 : 16),
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item is OperationModel) {
                return _buildOperationItem(item);
              } else if (item is flot_model.FlotModel) {
                return _buildFlotItem(item);
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildOperationItem(OperationModel operation) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isSmallMobile = size.width < 600;
    
    // Tailles responsive
    final iconSize = isSmallMobile ? 18.0 : (isMobile ? 20.0 : (isTablet ? 24.0 : 28.0));
    final titleFontSize = isSmallMobile ? 12.0 : (isMobile ? 13.0 : (isTablet ? 14.0 : 16.0));
    final amountFontSize = isSmallMobile ? 13.0 : (isMobile ? 14.0 : (isTablet ? 15.0 : 16.0));
    final detailFontSize = isSmallMobile ? 10.0 : (isMobile ? 11.0 : (isTablet ? 12.0 : 13.0));
    final tagFontSize = isSmallMobile ? 8.0 : (isMobile ? 9.0 : 10.0);
    final iconPadding = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 10.0);
    final cardPadding = isSmallMobile ? 6.0 : (isMobile ? 8.0 : (isTablet ? 12.0 : 16.0));
    final cardVerticalPadding = isSmallMobile ? 4.0 : (isMobile ? 6.0 : (isTablet ? 8.0 : 4.0));
    
    Color typeColor;
    IconData typeIcon;
    String typeText;
    
    switch (operation.type) {
      case OperationType.depot:
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        typeText = 'Dépôt';
        break;
      case OperationType.retrait:
        typeColor = Colors.orange;
        typeIcon = Icons.remove_circle;
        typeText = 'Retrait';
        break;
      case OperationType.retraitMobileMoney:
        typeColor = Colors.orange;
        typeIcon = Icons.mobile_friendly;
        typeText = 'Retrait MM';
        break;
      case OperationType.transfertNational:
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.send;
        typeText = 'Transfert National';
        break;
      case OperationType.transfertInternationalSortant:
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.send;
        typeText = 'Transfert Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeColor = Colors.blue;
        typeIcon = Icons.call_received;
        typeText = 'Transfert Entrant';
        break;
      case OperationType.virement:
        typeColor = Colors.purple;
        typeIcon = Icons.swap_horiz;
        typeText = 'Virement';
        break;
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (operation.statut) {
      case OperationStatus.validee:
        statusColor = Colors.green;
        statusText = 'Validée';
        statusIcon = Icons.check_circle;
        break;
      case OperationStatus.terminee:
        statusColor = Colors.green;
        statusText = 'Terminée';
        statusIcon = Icons.check_circle_outline;
        break;
      case OperationStatus.enAttente:
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case OperationStatus.annulee:
        statusColor = Colors.red;
        statusText = 'Annulée';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallMobile ? 4 : (isMobile ? 6 : 8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : (isMobile ? 8 : 12)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: isSmallMobile ? 1 : (isMobile ? 2 : 4),
            offset: Offset(0, isSmallMobile ? 0.5 : (isMobile ? 1 : 2)),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: cardPadding,
          vertical: cardVerticalPadding,
        ),
        leading: Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          child: Icon(typeIcon, color: typeColor, size: iconSize),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                operation.destinataire != null 
                    ? '${operation.destinataire}'
                    : typeText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: titleFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 5 : 8, 
                vertical: isMobile ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  color: typeColor,
                  fontSize: tagFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: isMobile ? 6 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Montant principal avec icône
              Row(
                children: [
                  Icon(Icons.attach_money, size: isMobile ? 12 : 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: amountFontSize,
                      color: typeColor,
                    ),
                  ),
                  if (operation.commission > 0)
                    Text(
                      '  -${operation.commission.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: detailFontSize,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 4 : 6),
              
              // Source et Destination pour les FLOT (virement)
              if (operation.type == OperationType.virement)
                Row(
                  children: [
                    Icon(Icons.arrow_upward, size: isMobile ? 11 : 13, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getShopName(operation.shopSourceId),
                        style: TextStyle(
                          fontSize: detailFontSize,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: isMobile ? 11 : 13, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_downward, size: isMobile ? 11 : 13, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getShopName(operation.shopDestinationId),
                        style: TextStyle(
                          fontSize: detailFontSize,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (operation.type == OperationType.virement)
                SizedBox(height: isMobile ? 4 : 6),
              
              // Mode de paiement + Statut
              Row(
                children: [
                  // Mode
                  Icon(
                    _getPaymentIcon(operation.modePaiement),
                    size: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    operation.modePaiementLabel,
                    style: TextStyle(
                      fontSize: detailFontSize,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  // Statut
                  Icon(statusIcon, size: isMobile ? 12 : 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: detailFontSize,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 4 : 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: isMobile ? 12 : 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(operation.dateOp),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 3 : 4),
              // CodeOps - Taille réduite
              if (operation.codeOps != null)
                Row(
                  children: [
                    Icon(Icons.code, size: isMobile ? 10 : 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      operation.codeOps!,
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 10,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600], size: isMobile ? 18 : 24),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Détails'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'reprint',
              child: Row(
                children: [
                  Icon(Icons.print, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Reimprimer'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'reprint') {
              _reprintOperationReceipt(operation);
            } else {
              _handleOperationAction(value, operation);
            }
          },
        ),
      ),
    );
  }

  IconData _getPaymentIcon(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return Icons.money;
      case ModePaiement.airtelMoney:
        return Icons.phone_android;
      case ModePaiement.mPesa:
        return Icons.account_balance_wallet;
      case ModePaiement.orangeMoney:
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleOperationAction(String action, OperationModel operation) {
    switch (action) {
      case 'details':
        _showOperationDetails(operation);
        break;
    }
  }

  void _reprintOperationReceipt(OperationModel operation) async {
    try {
      // Récupérer les services nécessaires
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      // Obtenir le shop de l'agent
      final shopId = authService.currentUser?.shopId;
      if (shopId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Shop non trouvé')),
          );
        }
        return;
      }
      
      final shop = shopService.getShopById(shopId);
      if (shop == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Shop non trouvé')),
          );
        }
        return;
      }
      
      // Obtenir l'agent
      final user = authService.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Agent non trouvé')),
          );
        }
        return;
      }
      
      // Convertir UserModel en AgentModel
      final agent = AgentModel(
        id: user.id,
        username: user.username,
        password: user.password,
        shopId: user.shopId ?? 0,
        nom: user.nom,
        telephone: user.telephone,
      );
      
      // Enrichir l'opération avec les noms de shops si manquants (pour les transferts)
      OperationModel enrichedOperation = operation;
      if (operation.type == OperationType.transfertNational ||
          operation.type == OperationType.transfertInternationalSortant ||
          operation.type == OperationType.transfertInternationalEntrant) {
        
        String? sourceDesignation = operation.shopSourceDesignation;
        String? destDesignation = operation.shopDestinationDesignation;
        
        // Enrichir shop source si manquant
        if ((sourceDesignation == null || sourceDesignation.isEmpty) && operation.shopSourceId != null) {
          final sourceShop = shopService.getShopById(operation.shopSourceId!);
          if (sourceShop != null) {
            sourceDesignation = sourceShop.designation;
          }
        }
        
        // Enrichir shop destination si manquant
        if ((destDesignation == null || destDesignation.isEmpty) && operation.shopDestinationId != null) {
          final destShop = shopService.getShopById(operation.shopDestinationId!);
          if (destShop != null) {
            destDesignation = destShop.designation;
          }
        }
        
        // Créer une copie enrichie si nécessaire
        if (sourceDesignation != operation.shopSourceDesignation || 
            destDesignation != operation.shopDestinationDesignation) {
          enrichedOperation = operation.copyWith(
            shopSourceDesignation: sourceDesignation,
            shopDestinationDesignation: destDesignation,
          );
        }
      }
      
      // Utiliser AutoPrintHelper au lieu de la méthode native qui ne marche pas
      if (mounted) {
        final success = await AutoPrintHelper.autoPrintWithDialog(
          context: context,
          operation: enrichedOperation,
          shop: shop,
          agent: agent,
          clientName: operation.destinataire,
        );
        
      }
    } catch (e) {

    }
  }
  
  String _getOperationTypeText(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return '📥 Dépôt';
      case OperationType.retrait:
        return '📤 Retrait';
      case OperationType.transfertNational:
        return '🔄 Transfert National';
      case OperationType.transfertInternationalSortant:
        return '🌍 Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return '🌍 Transfert International Entrant';
      case OperationType.virement:
        return '💸 Virement';
      default:
        return 'Opération';
    }
  }

  Widget _buildFlotItem(flot_model.FlotModel flot) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    Color typeColor;
    IconData typeIcon;
    String typeText;
    String directionText;
    
    // Determine if this is an incoming or outgoing FLOT for the current shop
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentShopSource = currentUser?.shopId != null && flot.shopSourceId == currentUser!.shopId;
    final isCurrentShopDestination = currentUser?.shopId != null && flot.shopDestinationId == currentUser!.shopId;
    
    if (isCurrentShopSource) {
      // Outgoing FLOT (sent by current shop)
      typeColor = Colors.orange;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT Envoyé';
      directionText = 'Vers: ${flot.getShopDestinationDesignation(Provider.of<ShopService>(context, listen: false).shops)}';
    } else if (isCurrentShopDestination) {
      // Incoming FLOT (received by current shop)
      typeColor = Colors.green;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT Reçu';
      directionText = 'De: ${flot.getShopSourceDesignation(Provider.of<ShopService>(context, listen: false).shops)}';
    } else {
      // Should not happen with proper filtering
      typeColor = Colors.grey;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT';
      directionText = 'Inconnu';
    }
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statusColor = Colors.orange;
        statusText = 'En Route';
        statusIcon = Icons.pending;
        break;
      case flot_model.StatutFlot.servi:
        statusColor = Colors.green;
        statusText = 'Servi';
        statusIcon = Icons.check_circle;
        break;
      case flot_model.StatutFlot.annule:
        statusColor = Colors.red;
        statusText = 'Annulé';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 4,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(typeIcon, color: typeColor, size: isMobile ? 24 : 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                directionText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 15 : 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Montant principal avec icône
              Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${flot.montant.toStringAsFixed(2)} ${flot.devise}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 15 : 16,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Mode de paiement + Statut
              Row(
                children: [
                  // Mode
                  Icon(
                    _getFlotPaymentIcon(flot.modePaiement),
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getFlotModePaiementLabel(flot.modePaiement),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Statut
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatFlotDate(flot),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Détails'),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleFlotAction(value, flot),
        ),
      ),
    );
  }

  IconData _getFlotPaymentIcon(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return Icons.money;
      case flot_model.ModePaiement.airtelMoney:
        return Icons.phone_android;
      case flot_model.ModePaiement.mPesa:
        return Icons.account_balance_wallet;
      case flot_model.ModePaiement.orangeMoney:
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  String _getFlotModePaiementLabel(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return 'Cash';
      case flot_model.ModePaiement.airtelMoney:
        return 'Airtel Money';
      case flot_model.ModePaiement.mPesa:
        return 'M-Pesa';
      case flot_model.ModePaiement.orangeMoney:
        return 'Orange Money';
      default:
        return 'Cash';
    }
  }

  String _formatFlotDate(flot_model.FlotModel flot) {
    final date = flot.dateReception ?? flot.dateEnvoi;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleFlotAction(String action, flot_model.FlotModel flot) {
    switch (action) {
      case 'details':
        _showFlotDetails(flot);
        break;
    }
  }

  void _showFlotDetails(flot_model.FlotModel flot) {
    String statusInfo = '';
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statusInfo = 'Statut: En Route (en attente de réception)';
        break;
      case flot_model.StatutFlot.servi:
        statusInfo = 'Statut: Servi (reçu par le shop destination)';
        break;
      case flot_model.StatutFlot.annule:
        statusInfo = 'Statut: Annulé';
        break;
    }
    
    String dateInfo = '';
    if (flot.statut == flot_model.StatutFlot.servi && flot.dateReception != null) {
      dateInfo = 'Date de réception: ${_formatFlotDate(flot)}';
    } else {
      dateInfo = 'Date d\'envoi: ${_formatDate(flot.dateEnvoi)}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails FLOT - ${flot.reference}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: ${flot.montant} ${flot.devise}'),
            const SizedBox(height: 8),
            // Afficher source et destination (avec résolution si nécessaire)
            Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('De: ', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(
                    flot.getShopSourceDesignation(Provider.of<ShopService>(context, listen: false).shops),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.send, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Envoyé vers: ', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(
                    flot.getShopDestinationDesignation(Provider.of<ShopService>(context, listen: false).shops),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mode de paiement: ${_getFlotModePaiementLabel(flot.modePaiement)}'),
            Text(statusInfo),
            Text(dateInfo),
            if (flot.notes != null && flot.notes!.isNotEmpty)
              Text('Notes: ${flot.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showDepotDialog() {
    showDialog(
      context: context,
      builder: (context) => const DepotDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }

  void _showRetraitDialog() {
    showDialog(
      context: context,
      builder: (context) => const RetraitDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }



  void _showTransfertDestinationDialog() {
    showDialog(
      context: context,
      builder: (context) => const TransferDestinationDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }

  // Helper method to get shop name by ID
  String _getShopName(int? shopId) {
    if (shopId == null) return 'Non spécifié';
    
    final shopService = Provider.of<ShopService>(context, listen: false);
    final shop = shopService.shops.firstWhere(
      (s) => s.id == shopId,
      orElse: () => ShopModel(designation: 'Shop #$shopId', localisation: ''),
    );
    return shop.designation;
  }

  void _showOperationDetails(OperationModel operation) {
    final agentService = Provider.of<AgentService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final agent = agentService.getAgentById(operation.agentId);
    final agentName = agent?.nom ?? agent?.username ?? operation.lastModifiedBy ?? 'Agent inconnu';
    
    // Get shop names for FLOT operations
    String? shopSourceName;
    String? shopDestinationName;
    String? flotDirectionInfo;
    
    if (operation.type == OperationType.virement) {
      // For FLOT (virement), get both source and destination shops
      if (operation.shopSourceId != null) {
        final sourceShop = shopService.shops.firstWhere(
          (s) => s.id == operation.shopSourceId,
          orElse: () => ShopModel(designation: 'Shop #${operation.shopSourceId}', localisation: ''),
        );
        shopSourceName = sourceShop.designation;
      }
      
      if (operation.shopDestinationId != null) {
        final destShop = shopService.shops.firstWhere(
          (s) => s.id == operation.shopDestinationId,
          orElse: () => ShopModel(designation: 'Shop #${operation.shopDestinationId}', localisation: ''),
        );
        shopDestinationName = destShop.designation;
      }
      
      // Determine direction based on current shop
      final currentUser = authService.currentUser;
      final isCurrentShopSource = currentUser?.shopId != null && operation.shopSourceId == currentUser!.shopId;
      final isCurrentShopDestination = currentUser?.shopId != null && operation.shopDestinationId == currentUser!.shopId;
      
      if (isCurrentShopSource && shopDestinationName != null) {
        flotDirectionInfo = 'Envoyé vers: $shopDestinationName';
      } else if (isCurrentShopDestination && shopSourceName != null) {
        flotDirectionInfo = 'Reçu de: $shopSourceName';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ${operation.codeOps ?? "ID ${operation.id}"}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (operation.codeOps != null)
                Text('Code: ${operation.codeOps}'),
              Text('Type: ${operation.typeLabel}'),
              
              // Show source and destination for FLOT operations
              if (operation.type == OperationType.virement && (shopSourceName != null || shopDestinationName != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (shopSourceName != null)
                        Row(
                          children: [
                            const Icon(Icons.store, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('De: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                shopSourceName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      if (shopSourceName != null && shopDestinationName != null)
                        const SizedBox(height: 4),
                      if (shopDestinationName != null)
                        Row(
                          children: [
                            const Icon(Icons.send, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Envoy\u00e9 vers: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                shopDestinationName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              
              // Expéditeur - From observation field
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Expéditeur: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(
                      operation.observation != null && operation.observation!.isNotEmpty
                          ? operation.observation!
                          : (operation.clientNom != null && operation.clientNom!.isNotEmpty
                              ? operation.clientNom!
                              : 'Non spécifié'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (operation.observation != null && operation.observation!.isNotEmpty) ||
                                (operation.clientNom != null && operation.clientNom!.isNotEmpty)
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (operation.destinataire != null)
                Text('Destinataire: ${operation.destinataire}'),
              Text('Montant brut: ${operation.montantBrut} ${operation.devise}'),
              if (operation.commission > 0)
                Text('Commission: ${operation.commission} ${operation.devise}'),
              Text('Montant net: ${operation.montantNet} ${operation.devise}'),
              Text('Mode de paiement: ${operation.modePaiementLabel}'),
              Text('Statut: ${operation.statutLabel}'),
              Text('Agent: $agentName'),
              Text('Date: ${_formatDate(operation.dateOp)}'),
              if (operation.notes != null)
                Text('Notes: ${operation.notes}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
