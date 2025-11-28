import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../services/report_service.dart';
import '../../services/operation_service.dart';
import '../../services/shop_service.dart';
import '../../services/flot_service.dart';
import '../../services/local_db.dart';
import '../../models/shop_model.dart';
import '../../models/operation_model.dart';
import '../../utils/responsive_utils.dart';
import '../../theme/ucash_typography.dart';
import '../../theme/ucash_containers.dart';
import '../pdf_viewer_dialog.dart';

class MouvementsCaisseReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showAllShops;

  const MouvementsCaisseReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
    this.showAllShops = false,
  });

  @override
  State<MouvementsCaisseReport> createState() => _MouvementsCaisseReportState();
}

class _MouvementsCaisseReportState extends State<MouvementsCaisseReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(MouvementsCaisseReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use OperationService to get the same operations as "Mes Ops"
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final flotService = Provider.of<FlotService>(context, listen: false);
      
      if (widget.shopId != null) {
        // Load operations for specific shop (same as Mes Ops)
        await operationService.loadOperations(shopId: widget.shopId!);
        if (!mounted) return;
        
        // Load flots for calculating cash disponible
        await flotService.loadFlots(shopId: widget.shopId, isAdmin: false);
        if (!mounted) return;
        
        final operations = operationService.operations;
        
        // Get shop info
        await shopService.loadShops();
        if (!mounted) return;
        
        final shop = shopService.shops.firstWhere(
          (s) => s.id == widget.shopId,
          orElse: () => ShopModel(designation: 'Inconnu', localisation: ''),
        );
        
        // Build report data from operations
        final reportData = await _buildReportFromOperations(operations, shop, flotService);
        
        if (!mounted) return;
        setState(() {
          _reportData = reportData;
        });
      } else if (widget.showAllShops) {
        // For all shops, use the existing logic
        final reportService = Provider.of<ReportService>(context, listen: false);
        await _loadAllShopsReport(reportService);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Build report data from operations (same as displayed in Mes Ops)
  Future<Map<String, dynamic>> _buildReportFromOperations(List<OperationModel> operations, ShopModel shop, FlotService flotService) async {
    double totalEntrees = 0;
    double totalSorties = 0;
    Map<String, double> totauxParMode = {
      'Cash': 0,
      'AirtelMoney': 0,
      'MPesa': 0,
      'OrangeMoney': 0,
    };
    
    final mouvements = <Map<String, dynamic>>[];
    
    // Filter by date range if provided
    var filteredOps = operations;
    if (widget.startDate != null) {
      filteredOps = filteredOps.where((op) => op.dateOp.isAfter(widget.startDate!) || op.dateOp.isAtSameMomentAs(widget.startDate!)).toList();
    }
    if (widget.endDate != null) {
      final endOfDay = DateTime(widget.endDate!.year, widget.endDate!.month, widget.endDate!.day, 23, 59, 59);
      filteredOps = filteredOps.where((op) => op.dateOp.isBefore(endOfDay) || op.dateOp.isAtSameMomentAs(endOfDay)).toList();
    }
    
    // CALCUL DU CASH DISPONIBLE DU JOUR selon la formule:
    // Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + FLOT En Cours + Transfert Reçu) - (Retraits + FLOT Servi + Transfert Servi)
    double cashDisponibleJour = 0.0;
    
    try {
      // 1. Solde Antérieur : Récupérer le solde SAISI de la clôture précédente
      double soldeAnterieur = 0.0;
      final dateDebut = widget.startDate ?? DateTime.now();
      final yesterday = dateDebut.subtract(const Duration(days: 1));
      final clotureHier = await LocalDB.instance.getClotureCaisseByDate(widget.shopId!, yesterday);
      
      if (clotureHier != null) {
        soldeAnterieur = clotureHier.soldeSaisiTotal;
      } else {
        // Pas de clôture hier, utiliser le capital du shop
        soldeAnterieur = shop.capitalCash + shop.capitalAirtelMoney + shop.capitalMPesa + shop.capitalOrangeMoney;
      }
      
      // 2. Dépôts du jour
      final depots = filteredOps
          .where((op) => op.type == OperationType.depot && op.devise == 'USD')
          .fold<double>(0.0, (sum, op) => sum + op.montantNet);
      
      // 3. Retraits du jour
      final retraits = filteredOps
          .where((op) => op.type == OperationType.retrait && op.devise == 'USD')
          .fold<double>(0.0, (sum, op) => sum + op.montantNet);
      
      // 4. FLOTs du jour (filtrés par la plage de dates)
      final todayFlots = flotService.flots.where((flot) {
        final flotDate = flot.dateOp;
        final isInRange = (widget.startDate == null || flotDate.isAfter(widget.startDate!) || flotDate.isAtSameMomentAs(widget.startDate!)) &&
                          (widget.endDate == null || flotDate.isBefore(widget.endDate!) || flotDate.isAtSameMomentAs(widget.endDate!));
        return (flot.shopSourceId == widget.shopId || flot.shopDestinationId == widget.shopId) && isInRange;
      }).toList();
      
      // FLOT Reçu (reçus et servis)
      final flotRecu = todayFlots
          .where((flot) => flot.shopDestinationId == widget.shopId && flot.statut == OperationStatus.validee && flot.devise == 'USD')
          .fold<double>(0.0, (sum, flot) => sum + flot.montantNet);
      
      // FLOT En Cours (en route vers ce shop)
      final flotEnCours = todayFlots
          .where((flot) => flot.shopDestinationId == widget.shopId && flot.statut == OperationStatus.enAttente && flot.devise == 'USD')
          .fold<double>(0.0, (sum, flot) => sum + flot.montantNet);
      
      // FLOT Servi (envoyés et servis)
      final flotServi = todayFlots
          .where((flot) => flot.shopSourceId == widget.shopId && flot.statut == OperationStatus.validee && flot.devise == 'USD')
          .fold<double>(0.0, (sum, flot) => sum + flot.montantNet);
      
      // 5. Transferts Reçus
      final transfertRecu = filteredOps
          .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) && 
                         op.shopDestinationId == widget.shopId && op.devise == 'USD')
          .fold<double>(0.0, (sum, op) => sum + op.montantNet);
      
      // 6. Transferts Servis
      final transfertServi = filteredOps
          .where((op) => (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) && 
                         op.shopSourceId == widget.shopId && op.devise == 'USD')
          .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
      
      // FORMULE FINALE
      cashDisponibleJour = (soldeAnterieur + depots + flotRecu + flotEnCours + transfertRecu) - 
                           (retraits + flotServi + transfertServi);
    } catch (e) {
      debugPrint('Erreur calcul cash disponible: $e');
      // En cas d'erreur, utiliser le capital du shop
      cashDisponibleJour = shop.capitalCash + shop.capitalAirtelMoney + shop.capitalMPesa + shop.capitalOrangeMoney;
    }
    
    for (final operation in filteredOps) {
      // Determine if it's an entry or exit for this shop
      final isEntree = _isEntreeForShop(operation, widget.shopId!);
      final montantBrut = operation.montantBrut;
      final montantNet = operation.montantNet;
      final commission = operation.commission;
      
      // Calculate amount for totals
      double montant;
      if (operation.shopSourceId == widget.shopId && 
          (operation.type == OperationType.transfertNational ||
           operation.type == OperationType.transfertInternationalSortant)) {
        // Transfer SOURCE: entry of total amount (brut)
        montant = montantBrut;
      } else {
        // Other cases: net amount
        montant = montantNet;
      }
      
      if (isEntree) {
        totalEntrees += montant;
      } else {
        totalSorties += montant;
      }
      
      // Add to mode totals
      final mode = operation.modePaiement.name;
      totauxParMode[mode] = (totauxParMode[mode] ?? 0) + montant;
      
      mouvements.add({
        'date': operation.dateOp,
        'type': operation.type.name,
        'typeDirection': isEntree ? 'entree' : 'sortie',
        'agent': operation.lastModifiedBy ?? 'N/A',
        'montantBrut': montantBrut,
        'montantNet': montantNet,
        'commission': commission,
        'montant': montant,
        'devise': operation.devise,
        'mode': mode,
        'statut': operation.statut.name,
        'destinataire': operation.destinataire ?? operation.clientNom ?? 'N/A',
      });
    }
    
    // Sort by date descending
    mouvements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    return {
      'shop': shop.toJson(),
      'periode': {
        'debut': widget.startDate?.toIso8601String(),
        'fin': widget.endDate?.toIso8601String(),
      },
      'mouvements': mouvements,
      'totaux': {
        'entrees': totalEntrees,
        'sorties': totalSorties,
        'solde': totalEntrees - totalSorties,
        'cashDisponibleJour': cashDisponibleJour, // NOUVEAU: Cash disponible calculé
        'parMode': totauxParMode,
      },
      'statistiques': {
        'nombreOperations': mouvements.length,
        'moyenneParOperation': mouvements.isNotEmpty ? (totalEntrees + totalSorties) / mouvements.length : 0,
      },
    };
  }

  // Determine if operation is an entry for the shop
  bool _isEntreeForShop(OperationModel operation, int shopId) {
    switch (operation.type) {
      case OperationType.depot:
        return operation.shopSourceId == shopId; // Deposit is entry
      case OperationType.retrait:
        return false; // Withdrawal is exit
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Transfer created by this shop = entry (receives money from client)
        return operation.shopSourceId == shopId;
      case OperationType.transfertInternationalEntrant:
        // Transfer received by this shop = exit (serves money to beneficiary)
        return operation.shopDestinationId == shopId && operation.shopSourceId != shopId;
      case OperationType.virement:
        return operation.shopSourceId == shopId;
      default:
        return false;
    }
  }

  Future<void> _loadAllShopsReport(ReportService reportService) async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
    if (!mounted) return;
    
    final allShops = shopService.shops;
    final allMovements = <Map<String, dynamic>>[];
    double totalEntrees = 0;
    double totalSorties = 0;
    Map<String, double> totauxParMode = {
      'Cash': 0,
      'AirtelMoney': 0,
      'MPesa': 0,
      'OrangeMoney': 0,
    };

    for (final shop in allShops) {
      if (!mounted) return;
      
      try {
        final shopReport = await reportService.generateMouvementsCaisseReport(
          shopId: shop.id!,
          startDate: widget.startDate,
          endDate: widget.endDate,
        );
        if (!mounted) return;
        
        final movements = shopReport['mouvements'] as List<Map<String, dynamic>>;
        for (final movement in movements) {
          movement['shopNom'] = shop.designation; // Ajouter le nom du shop
          allMovements.add(movement);
        }
        
        final totaux = shopReport['totaux'] as Map<String, dynamic>;
        totalEntrees += totaux['entrees'] as double;
        totalSorties += totaux['sorties'] as double;
        
        final parMode = totaux['parMode'] as Map<String, double>;
        parMode.forEach((mode, montant) {
          totauxParMode[mode] = (totauxParMode[mode] ?? 0) + montant;
        });
      } catch (e) {
        debugPrint('Erreur pour le shop ${shop.designation}: $e');
      }
    }

    // Trier les mouvements par date décroissante
    allMovements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (!mounted) return;
    setState(() {
      _reportData = {
        'shop': {'designation': 'Tous les shops'},
        'periode': {
          'debut': widget.startDate?.toIso8601String(),
          'fin': widget.endDate?.toIso8601String(),
        },
        'mouvements': allMovements,
        'totaux': {
          'entrees': totalEntrees,
          'sorties': totalSorties,
          'solde': totalEntrees - totalSorties,
          'parMode': totauxParMode,
        },
        'statistiques': {
          'nombreOperations': allMovements.length,
          'moyenneParOperation': allMovements.isNotEmpty ? (totalEntrees + totalSorties) / allMovements.length : 0,
        },
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 5, desktop: 6),
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
            Text(
              'Génération du rapport en cours...',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline, 
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 48, tablet: 56, desktop: 64),
              color: Colors.red[400],
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
            Text(
              'Erreur lors de la génération du rapport',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                color: Colors.red[600],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              _errorMessage!, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                padding: ResponsiveUtils.getFluidPadding(
                  context,
                  mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                  ),
                ),
              ),
              child: Text(
                'Réessayer',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_reportData == null) {
      return Center(
        child: Text(
          'Aucune donnée disponible',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 18, desktop: 20),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 20, tablet: 22, desktop: 24)),
          _buildSummaryCards(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 20, tablet: 22, desktop: 24)),
          _buildMovementsTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final shop = _reportData!['shop'] as Map<String, dynamic>;
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    
    return Card(
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
            Row(
              children: [
                Icon(
                  Icons.account_balance, 
                  color: Colors.blue[700],
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 24, tablet: 28, desktop: 32),
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Mvts de Caisse',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 20, tablet: 22, desktop: 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              'Shop: ${shop['designation']}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 17, desktop: 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (periode['debut'] != null && periode['fin'] != null)
              Text(
                'Période: ${_formatDate(DateTime.parse(periode['debut']))} - ${_formatDate(DateTime.parse(periode['fin']))}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totaux = _reportData!['totaux'] as Map<String, dynamic>;
    final statistiques = _reportData!['statistiques'] as Map<String, dynamic>;
    final parMode = totaux['parMode'] as Map<String, double>;

    return Column(
      children: [
        // Cartes principales
        if (context.isSmallScreen)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Entrées',
                      '${totaux['entrees'].toStringAsFixed(2)} USD',
                      Icons.arrow_downward,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Expanded(
                    child: _buildSummaryCard(
                      'Sorties',
                      '${totaux['sorties'].toStringAsFixed(2)} USD',
                      Icons.arrow_upward,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Solde Net',
                      '${totaux['solde'].toStringAsFixed(2)} USD',
                      Icons.account_balance_wallet,
                      totaux['solde'] >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Expanded(
                    child: _buildSummaryCard(
                      'Opérations',
                      '${statistiques['nombreOperations']}',
                      Icons.receipt_long,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Entrées',
                  '${totaux['entrees'].toStringAsFixed(2)} USD',
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Expanded(
                child: _buildSummaryCard(
                  'Sorties',
                  '${totaux['sorties'].toStringAsFixed(2)} USD',
                  Icons.arrow_upward,
                  Colors.red,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Expanded(
                child: _buildSummaryCard(
                  'Solde Net',
                  '${totaux['solde'].toStringAsFixed(2)} USD',
                  Icons.account_balance_wallet,
                  totaux['solde'] >= 0 ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Expanded(
                child: _buildSummaryCard(
                  'Opérations',
                  '${statistiques['nombreOperations']}',
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
            ],
          ),
        
        // SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
        
        // // Répartition par mode de paiement
        // Card(
        //   elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(
        //       ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        //     ),
        //   ),
        //   child: Padding(
        //     padding: ResponsiveUtils.getFluidPadding(
        //       context,
        //       mobile: const EdgeInsets.all(16),
        //       tablet: const EdgeInsets.all(20),
        //       desktop: const EdgeInsets.all(24),
        //     ),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           'Répartition par Mode de Paiement',
        //           style: TextStyle(
        //             fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 17, desktop: 18),
        //             fontWeight: FontWeight.bold,
        //           ),
        //         ),
        //         SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
        //         if (context.isSmallScreen)
        //           Column(
        //             children: [
        //               Row(
        //                 children: [
        //                   Expanded(child: _buildModeCard('Cash', parMode['Cash'] ?? 0, null)),
        //                   SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
        //                   Expanded(child: _buildModeCard('Airtel Money', parMode['AirtelMoney'] ?? 0, null)),
        //                 ],
        //               ),
        //               SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        //               Row(
        //                 children: [
        //                   Expanded(child: _buildModeCard('M-Pesa', parMode['MPesa'] ?? 0, null)),
        //                   SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
        //                   Expanded(child: _buildModeCard('Orange Money', parMode['OrangeMoney'] ?? 0, null)),
        //                 ],
        //               ),
        //             ],
        //           )
        //         else
        //           Row(
        //             children: [
        //               Expanded(child: _buildModeCard('Cash', parMode['Cash'] ?? 0, null)),
        //               SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        //               Expanded(child: _buildModeCard('Airtel Money', parMode['AirtelMoney'] ?? 0, null)),
        //               SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        //               Expanded(child: _buildModeCard('M-Pesa', parMode['MPesa'] ?? 0, null)),
        //               SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        //               Expanded(child: _buildModeCard('Orange Money', parMode['OrangeMoney'] ?? 0, null)),
        //             ],
        //           ),
        //       ],
        //     ),
        //   ),
        // ),
     
     
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 16, tablet: 18, desktop: 20),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getFluidBorderRadius(context, mobile: 16, tablet: 18, desktop: 20),
          ),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(8),
          tablet: const EdgeInsets.all(15),
          desktop: const EdgeInsets.all(20),
        ),
        child: Column(
          children: [
            Container(
              padding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.all(12),
                tablet: const EdgeInsets.all(14),
                desktop: const EdgeInsets.all(16),
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                color: color, 
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 28, tablet: 32, desktop: 36),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 18, desktop: 20),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 5, desktop: 6)),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(String mode, double montantUSD, double? montantDeviseLocale) {
    // Icônes selon le mode de paiement
    IconData modeIcon;
    Color color;
    switch (mode) {
      case 'Cash':
        modeIcon = Icons.money;
        color = Colors.green;
        break;
      case 'Airtel Money':
        modeIcon = Icons.phone_android;
        color = Colors.red;
        break;
      case 'M-Pesa':
        modeIcon = Icons.account_balance_wallet;
        color = Colors.green;
        break;
      case 'Orange Money':
        modeIcon = Icons.payment;
        color = Colors.orange;
        break;
      default:
        modeIcon = Icons.credit_card;
        color = Colors.blue;
    }
    
    // Déterminer le symbole de la devise locale
    String deviseLocaleSymbol = 'FC';
    if (montantDeviseLocale != null && montantDeviseLocale > 0) {
      // Obtenir la devise locale du shop
      if (widget.shopId != null) {
        try {
          final shopService = Provider.of<ShopService>(context, listen: false);
          final currentShop = shopService.shops.firstWhere(
            (shop) => shop.id == widget.shopId,
            orElse: () => ShopModel(designation: 'Inconnu', localisation: ''),
          );
          
          if (currentShop.deviseSecondaire != null && currentShop.deviseSecondaire!.isNotEmpty) {
            deviseLocaleSymbol = currentShop.deviseSecondaire!;
          }
        } catch (e) {
          // Utiliser FC par défaut en cas d'erreur
          debugPrint('⚠️ Erreur récupération devise locale: $e');
        }
      }
    }
    
    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(14),
        desktop: const EdgeInsets.all(16),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            modeIcon, 
            color: color, 
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 24, tablet: 28, desktop: 32),
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            mode,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
          // Montant USD
          Text(
            '${montantUSD.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 17, desktop: 18),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 12, desktop: 13),
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.7),
            ),
          ),
          // Montant Devise Locale
          if (montantDeviseLocale != null && montantDeviseLocale > 0)
            Column(
              children: [
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 4, tablet: 5, desktop: 6)),
                Text(
                  '${montantDeviseLocale.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
                Text(
                  deviseLocaleSymbol,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMovementsTable() {
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    if (mouvements.isEmpty) {
      return Card(
        elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
          ),
        ),
        child: Padding(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.all(24),
            tablet: const EdgeInsets.all(28),
            desktop: const EdgeInsets.all(32),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined, 
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 48, tablet: 56, desktop: 64),
                  color: Colors.grey[400],
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
                Text(
                  'Aucun mouvement trouvé',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 20, desktop: 22),
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Aucune opération n\'a été effectuée pour la période sélectionnée',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(20),
              desktop: const EdgeInsets.all(24),
            ),
            child: Row(
              children: [
                Text(
                  'Mouvements',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _generateAndPreviewPdf,
                  icon: Icon(
                    Icons.visibility,
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    color: Colors.blue,
                  ),
                  tooltip: 'Prévisualiser PDF',
                ),
                IconButton(
                  onPressed: _telechargerPDF,
                  icon: Icon(
                    Icons.download,
                    size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    color: Colors.green,
                  ),
                  tooltip: 'Télécharger PDF',
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                if (widget.showAllShops) DataColumn(
                  label: Text(
                    'Shop',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Type',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Client/Destinataire',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Agent',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Montant Brut',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Commission',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Montant Servi',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Mode',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Statut',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                  ),
                ),
              ],
              rows: mouvements.take(50).map((mouvement) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      _formatDateTime(mouvement['date'] as DateTime),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      ),
                    ),
                  ),
                  if (widget.showAllShops) DataCell(
                    Text(
                      mouvement['shopNom'] ?? '',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      ),
                    ),
                  ),
                  DataCell(_buildTypeChip(mouvement['type'])),
                  DataCell(
                    Text(
                      mouvement['destinataire'] ?? 'N/A', 
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      mouvement['agent'],
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${mouvement['montantBrut'].toStringAsFixed(2)} USD',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      mouvement['commission'] > 0 ? '${mouvement['commission'].toStringAsFixed(2)} USD' : '-',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                        color: mouvement['commission'] > 0 ? Colors.orange[700] : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${mouvement['montantNet'].toStringAsFixed(2)} USD',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 14, desktop: 15),
                        fontWeight: FontWeight.bold,
                        color: mouvement['typeDirection'] == 'entree' ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                  DataCell(_buildModeChip(mouvement['mode'])),
                  DataCell(_buildStatusChip(mouvement['statut'])),
                ],
              )).toList(),
            ),
          ),
          if (mouvements.length > 50)
            Padding(
              padding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.all(16),
                tablet: const EdgeInsets.all(20),
                desktop: const EdgeInsets.all(24),
              ),
              child: Text(
                'Affichage des 50 premiers mouvements sur ${mouvements.length} au total',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 11, tablet: 13, desktop: 14),
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color color;
    String label;
    IconData icon;
    
    switch (type) {
      case 'depot':
        color = Colors.green;
        label = 'Dépôt';
        icon = Icons.add_circle;
        break;
      case 'retrait':
        color = Colors.orange;
        label = 'Retrait';
        icon = Icons.remove_circle;
        break;
      case 'transfertNational':
        color = Colors.blue;
        label = 'Transfert National';
        icon = Icons.swap_horiz;
        break;
      case 'transfertInternationalSortant':
        color = Colors.purple;
        label = 'Transfert Sortant';
        icon = Icons.arrow_upward;
        break;
      case 'transfertInternationalEntrant':
        color = Colors.teal;
        label = 'Transfert Entrant';
        icon = Icons.arrow_downward;
        break;
      case 'virement':
        color = Colors.indigo;
        label = 'Virement';
        icon = Icons.compare_arrows;
        break;
      default:
        color = Colors.grey;
        label = type;
        icon = Icons.help_outline;
    }

    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tablet: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 12, tablet: 13, desktop: 14),
            color: color,
          ),
          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 3, tablet: 4, desktop: 5)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode) {
    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        tablet: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        desktop: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: Colors.blue[700],
          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String statut) {
    Color color;
    switch (statut) {
      case 'validee':
        color = Colors.green;
        break;
      case 'terminee':
        color = Colors.green;
        break;
      case 'enAttente':
        color = Colors.orange;
        break;
      case 'annulee':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        tablet: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        desktop: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        statut,
        style: TextStyle(
          color: color,
          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Generate and preview PDF
  Future<void> _generateAndPreviewPdf() async {
    if (_reportData == null) return;

    try {
      final pdf = await _generatePdf();
      
      // Show PDF preview with print/download options (same as clôture journalière)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'mouvements_caisse_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Download PDF - Show preview first, then allow download/share
  Future<void> _telechargerPDF() async {
    if (_reportData == null) return;

    try {
      final pdf = await _generatePdf();
      
      // Show PDF viewer in fullscreen (using Navigator.push instead of dialog)
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerDialog(
              pdfDocument: pdf,
              title: 'Mouvements de Caisse',
              fileName: _getPdfFileName().replaceAll('.pdf', ''),
            ),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPdfFileName() {
    final shop = _reportData!['shop'] as Map<String, dynamic>;
    final shopName = shop['designation'] ?? 'shop';
    return 'mouvements_caisse_${shopName}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
  }

  // Generate PDF document
  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final shop = _reportData!['shop'] as Map<String, dynamic>;
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    final totaux = _reportData!['totaux'] as Map<String, dynamic>;
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MOUVEMENTS DE CAISSE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Shop: ${shop['designation']}',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                ),
                if (periode['debut'] != null && periode['fin'] != null)
                  pw.Text(
                    'Période: ${_formatDate(DateTime.parse(periode['debut']))} - ${_formatDate(DateTime.parse(periode['fin']))}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                  ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Summary cards
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfSummaryCard('Entrées', '${totaux['entrees'].toStringAsFixed(2)} USD', PdfColors.green),
              _buildPdfSummaryCard('Sorties', '${totaux['sorties'].toStringAsFixed(2)} USD', PdfColors.red),
              _buildPdfSummaryCard('Solde Net', '${totaux['solde'].toStringAsFixed(2)} USD', 
                totaux['solde'] >= 0 ? PdfColors.green : PdfColors.red),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Movements table
          pw.Text(
            'Détail des Mouvements',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildPdfTableHeader('Date'),
                  _buildPdfTableHeader('Type'),
                  _buildPdfTableHeader('Client/Dest.'),
                  _buildPdfTableHeader('Montant Brut'),
                  _buildPdfTableHeader('Commission'),
                  _buildPdfTableHeader('Montant Servi'),
                ],
              ),
              // Data rows (limit to 30 for PDF)
              ...mouvements.take(30).map((mouvement) => pw.TableRow(
                children: [
                  _buildPdfTableCell(_formatDateTime(mouvement['date'] as DateTime)),
                  _buildPdfTableCell(_getTypeLabel(mouvement['type'])),
                  _buildPdfTableCell(mouvement['destinataire'] ?? 'N/A'),
                  _buildPdfTableCell('${mouvement['montantBrut'].toStringAsFixed(2)}'),
                  _buildPdfTableCell(mouvement['commission'] > 0 
                    ? '${mouvement['commission'].toStringAsFixed(2)}' : '-'),
                  _buildPdfTableCell(
                    '${mouvement['montantNet'].toStringAsFixed(2)}',
                    color: mouvement['typeDirection'] == 'entree' ? PdfColors.green : PdfColors.red,
                  ),
                ],
              )),
            ],
          ),
          
          if (mouvements.length > 30)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Affichage des 30 premiers mouvements sur ${mouvements.length} au total',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          
          pw.SizedBox(height: 20),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildPdfSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfTableCell(String text, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'depot':
        return 'Dépôt';
      case 'retrait':
        return 'Retrait';
      case 'transfertNational':
        return 'Transfert National';
      case 'transfertInternationalSortant':
        return 'Transfert Sortant';
      case 'transfertInternationalEntrant':
        return 'Transfert Entrant';
      case 'virement':
        return 'Virement';
      default:
        return type;
    }
  }
}
