import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';
import 'report_filters_widget.dart';
import 'mouvements_caisse_report.dart';
import 'credits_inter_shops_report.dart';
import 'commissions_report.dart';
import 'evolution_capital_report.dart';
import 'admin_cloture_report.dart';
import 'admin_flot_report.dart';

class AdminReportsWidget extends StatefulWidget {
  const AdminReportsWidget({super.key});

  @override
  State<AdminReportsWidget> createState() => _AdminReportsWidgetState();
}

class _AdminReportsWidgetState extends State<AdminReportsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedShopId;
  bool _showFilters = true; // Toggle pour afficher/cacher les filtres

  final List<Tab> _tabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Mouvements de Caisse'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits Inter-Shops'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.trending_up), text: 'Évolution Capital'),
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture Journalière'),
    const Tab(icon: Icon(Icons.local_shipping), text: 'Mouvements FLOT'),
  ];

  final List<Tab> _mobileTabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Caisse'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.trending_up), text: 'Capital'),
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture'),
    const Tab(icon: Icon(Icons.local_shipping), text: 'FLOT'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Column(
      children: [
        // Header avec titre et filtres
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec bouton toggle filtres
              Row(
                children: [
                  Expanded(child: _buildResponsiveHeader(isMobile, isTablet)),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                      color: const Color(0xFFDC2626),
                    ),
                    tooltip: _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
                    style: IconButton.styleFrom(
                      backgroundColor: _showFilters ? Colors.red.shade50 : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              
              // Filtres (avec animation)
              if (_showFilters) ...[
                SizedBox(height: isMobile ? 12 : 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: ReportFiltersWidget(
                    showShopFilter: true,
                    selectedShopId: _selectedShopId,
                    startDate: _startDate,
                    endDate: _endDate,
                    onShopChanged: (shopId) {
                      setState(() {
                        _selectedShopId = shopId;
                      });
                      _refreshCurrentReport();
                    },
                    onDateRangeChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                      _refreshCurrentReport();
                    },
                    onReset: () {
                      setState(() {
                        _selectedShopId = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _refreshCurrentReport();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Onglets adaptatifs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: _buildResponsiveTabs(isMobile),
            labelColor: const Color(0xFFDC2626),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFFDC2626),
            isScrollable: true,
            labelPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            onTap: (index) => _refreshCurrentReport(),
          ),
        ),
        
        // Contenu des onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Mouvements de caisse
              MouvementsCaisseReport(
                shopId: _selectedShopId,
                startDate: _startDate,
                endDate: _endDate,
                showAllShops: _selectedShopId == null,
              ),
              
              // Crédits inter-shops
              CreditsInterShopsReport(
                startDate: _startDate,
                endDate: _endDate,
              ),
              
              // Commissions
              CommissionsReport(
                shopId: _selectedShopId,
                startDate: _startDate,
                endDate: _endDate,
                showAllShops: _selectedShopId == null,
              ),
              
              // Évolution capital
              EvolutionCapitalReport(
                shopId: _selectedShopId,
                startDate: _startDate,
                endDate: _endDate,
                showAllShops: _selectedShopId == null,
              ),
              
              // Clôture journalière
              AdminClotureReport(
                shopId: _selectedShopId,
                date: DateTime.now(),
              ),
              
              // Mouvements FLOT
              AdminFlotReport(
                shopId: _selectedShopId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _refreshCurrentReport() {
    // Déclencher le rechargement du rapport actuel
    setState(() {});
  }

  Widget _buildResponsiveHeader(bool isMobile, bool isTablet) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rapports Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, color: Colors.orange[700], size: 14),
                const SizedBox(width: 4),
                Text(
                  'Tous les shops',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.admin_panel_settings,
          color: Colors.orange[700],
          size: isTablet ? 26 : 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isTablet ? 'Rapports Admin' : 'Rapports Administrateur',
            style: TextStyle(
              fontSize: isTablet ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 12,
            vertical: isTablet ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility,
                color: Colors.orange[700],
                size: isTablet ? 14 : 16,
              ),
              const SizedBox(width: 4),
              Text(
                isTablet ? 'Tous shops' : 'Accès : Tous les shops',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: isTablet ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Tab> _buildResponsiveTabs(bool isMobile) {
    return isMobile ? _mobileTabs : _tabs;
  }
}