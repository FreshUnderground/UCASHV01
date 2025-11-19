import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';
import 'report_filters_widget.dart';
import 'mouvements_caisse_report.dart';
import 'credits_inter_shops_report.dart';
import 'commissions_report.dart';

import 'admin_cloture_report.dart';
import 'admin_flot_report.dart';
import '../../utils/responsive_utils.dart';
import '../../theme/ucash_typography.dart';
import '../../theme/ucash_containers.dart';

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

  final List<Tab> _tabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Mouvements de Caisse'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits Inter-Shops'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture Journalière'),
    const Tab(icon: Icon(Icons.local_shipping), text: 'Mouvements FLOT'),
  ];

  final List<Tab> _mobileTabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Caisse'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
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
    return Column(
      children: [
        // Header avec titre et filtres
        Container(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(14),
            desktop: const EdgeInsets.all(16),
          ),
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
              // Header adaptatif
              _buildResponsiveHeader(context.isSmallScreen, context.screenType == ScreenType.tablet),
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              
              // Filtres
              ReportFiltersWidget(
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
            ],
          ),
        ),
        
        // Onglets adaptatifs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: _buildResponsiveTabs(context.isSmallScreen),
            labelColor: const Color(0xFFDC2626),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFFDC2626),
            isScrollable: true,
            labelPadding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 22, tablet: 24, desktop: 26),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
              Expanded(
                child: Text(
                  'Rapports Admin',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
          Container(
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tablet: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              desktop: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getFluidBorderRadius(context, mobile: 14, tablet: 15, desktop: 16),
              ),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, 
                  color: Colors.orange[700], 
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 12, tablet: 13, desktop: 14),
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 3, tablet: 3.5, desktop: 4)),
                Text(
                  'Tous les shops',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 10.5, desktop: 11),
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
          size: ResponsiveUtils.getFluidIconSize(context, mobile: 24, tablet: 26, desktop: 28),
        ),
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 11, desktop: 12)),
        Expanded(
          child: Text(
            isTablet ? 'Rapports Admin' : 'Rapports Administrateur',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 20, desktop: 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
        Container(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            tablet: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
            desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 18, tablet: 19, desktop: 20),
            ),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility,
                color: Colors.orange[700],
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 3, tablet: 3.5, desktop: 4)),
              Text(
                isTablet ? 'Tous shops' : 'Accès : Tous les shops',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
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