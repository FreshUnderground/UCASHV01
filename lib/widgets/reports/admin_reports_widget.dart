import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';
import 'report_filters_widget.dart';
import 'mouvements_caisse_report.dart';
import '../rapport_cloture_widget.dart';
import 'historique_clotures_report.dart';
import 'credits_inter_shops_report.dart';
import 'commissions_report.dart';
import '../cloture_agent_widget.dart';

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
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture Journalière'),
    const Tab(icon: Icon(Icons.list_alt), text: 'Historique Clôtures'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits Inter-Shops'),
    const Tab(icon: Icon(Icons.local_shipping), text: 'Mouvements FLOT'),
  ];

  final List<Tab> _mobileTabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Caisse'),
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture'),
    const Tab(icon: Icon(Icons.list_alt), text: 'Clôtures'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.swap_horiz), text: 'Crédits'),
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
    final isMobile = context.isSmallScreen;
    final isTablet = context.screenType == ScreenType.tablet;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[50]!,
            Colors.grey[100]!,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header moderne avec effet glassmorphism
            Container(
              margin: context.fluidPadding(
                mobile: const EdgeInsets.all(4),
                tablet: const EdgeInsets.all(8),
                desktop: const EdgeInsets.all(12),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    blurRadius: context.fluidSpacing(mobile: 10, tablet: 15, desktop: 20),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec gradient
                  Container(
                    padding: context.fluidPadding(
                      mobile: const EdgeInsets.all(12),
                      tablet: const EdgeInsets.all(16),
                      desktop: const EdgeInsets.all(20),
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20)),
                        topRight: Radius.circular(ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20)),
                      ),
                    ),
                    child: _buildModernHeader(isMobile, isTablet),
                  ),
                  
                  // Filtres avec padding réduit sur mobile
                  Padding(
                    padding: context.fluidPadding(
                      mobile: const EdgeInsets.all(8),
                      tablet: const EdgeInsets.all(16),
                      desktop: const EdgeInsets.all(20),
                    ),
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
              ),
            ),
            
            // Onglets modernes avec design amélioré
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: context.fluidSpacing(mobile: 4, tablet: 8, desktop: 12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: _buildModernTabs(isMobile),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[700],
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    ),
                  ),
                  isScrollable: true,
                  labelPadding: context.fluidPadding(
                    mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  labelStyle: TextStyle(
                    fontSize: context.fluidFont(mobile: 11, tablet: 13, desktop: 14),
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: context.fluidFont(mobile: 10, tablet: 12, desktop: 13),
                    fontWeight: FontWeight.w500,
                  ),
                  onTap: (index) => _refreshCurrentReport(),
                ),
              ),
            ),
            
            SizedBox(height: context.fluidSpacing(mobile: 6, tablet: 12, desktop: 16)),
            
            // Contenu des rapports avec hauteur fixe
            Container(
              height: MediaQuery.of(context).size.height * 0.6,
              margin: EdgeInsets.symmetric(
                horizontal: context.fluidSpacing(mobile: 4, tablet: 8, desktop: 12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Mouvements de caisse (EXACTEMENT comme l'agent)
                    MouvementsCaisseReport(
                      shopId: _selectedShopId,
                      startDate: _startDate,
                      endDate: _endDate,
                      showAllShops: _selectedShopId == null,
                    ),
                    
                    // Clôture journalière (EXACTEMENT comme l'agent)
                    _selectedShopId != null
                      ? ClotureAgentWidget(
                          shopId: _selectedShopId!,
                          isAdminView: true, // Admin ne peut pas clôturer
                        )
                      : _buildSelectShopMessage(),
                    
                    // Historique des clôtures
                    HistoriqueCloturesReport(
                      shopId: _selectedShopId,
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
                    
                    // Crédits inter-shops
                    CreditsInterShopsReport(
                      shopId: _selectedShopId,
                      startDate: _startDate,
                      endDate: _endDate,
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
            ),
            
            SizedBox(height: context.fluidSpacing(mobile: 4, tablet: 8, desktop: 12)),
          ],
        ),
      ),
    );
  }

  void _refreshCurrentReport() {
    // Déclencher le rechargement du rapport actuel
    setState(() {});
  }

  Widget _buildModernHeader(bool isMobile, bool isTablet) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: context.fluidIcon(mobile: 20, tablet: 24, desktop: 26),
                ),
              ),
              context.horizontalSpace(mobile: 8, tablet: 12, desktop: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapports Admin',
                      style: TextStyle(
                        fontSize: context.fluidFont(mobile: 15, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tableaux de bord avancés',
                      style: TextStyle(
                        fontSize: context.fluidFont(mobile: 10, tablet: 12, desktop: 13),
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  _selectedShopId == null ? 'Tous les shops' : 'Shop sélectionné',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
        Container(
          padding: context.fluidPadding(
            mobile: const EdgeInsets.all(10),
            tablet: const EdgeInsets.all(12),
            desktop: const EdgeInsets.all(14),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
            ),
          ),
          child: Icon(
            Icons.analytics,
            color: Colors.white,
            size: context.fluidIcon(mobile: 24, tablet: 28, desktop: 32),
          ),
        ),
        context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTablet ? 'Rapports Admin' : 'Rapports Administrateur',
                style: TextStyle(
                  fontSize: context.fluidFont(mobile: 20, tablet: 22, desktop: 26),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Analyse et suivi des performances',
                style: TextStyle(
                  fontSize: context.fluidFont(mobile: 12, tablet: 13, desktop: 14),
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        context.horizontalSpace(mobile: 8, tablet: 12, desktop: 14),
        Container(
          padding: context.fluidPadding(
            mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.store,
                color: Colors.white,
                size: context.fluidIcon(mobile: 14, tablet: 16, desktop: 17),
              ),
              context.horizontalSpace(mobile: 4, tablet: 6, desktop: 7),
              Text(
                _selectedShopId == null 
                    ? (isTablet ? 'Tous shops' : 'Tous les shops')
                    : 'Shop filtré',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.fluidFont(mobile: 11, tablet: 12, desktop: 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Tab> _buildModernTabs(bool isMobile) {
    final tabs = isMobile ? _mobileTabs : _tabs;
    return tabs.map((tab) {
      return Tab(
        icon: tab.icon,
        child: Text(
          tab.text!,
          style: TextStyle(
            fontSize: context.fluidFont(mobile: 10, tablet: 11, desktop: 12),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSelectShopMessage() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[100]!, Colors.blue[50]!],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.store,
                size: 64,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sélectionnez un Shop',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Utilisez le filtre ci-dessus pour sélectionner un shop spécifique',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'La clôture journalière nécessite un shop spécifique',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}