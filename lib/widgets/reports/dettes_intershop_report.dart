import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';
import '../../utils/responsive_utils.dart';

/// Rapport des Mouvements des Dettes Intershop Journalier
/// Ce rapport affiche les mouvements quotidiens des dettes entre shops
class DettesIntershopReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;

  const DettesIntershopReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
  });

  @override
  State<DettesIntershopReport> createState() => _DettesIntershopReportState();
}

class _DettesIntershopReportState extends State<DettesIntershopReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;
  late DateTime _startDate;
  late DateTime _endDate;
  int? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.endDate ?? DateTime.now();
    _selectedShopId = widget.shopId;
    _loadReport();
  }

  @override
  void didUpdateWidget(DettesIntershopReport oldWidget) {
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
      final reportService = Provider.of<ReportService>(context, listen: false);
      final data = await reportService.generateDettesIntershopReport(
        shopId: _selectedShopId,
        startDate: _startDate,
        endDate: _endDate,
      );
      
      if (mounted) {
        setState(() {
          _reportData = data;
        });
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

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Génération du rapport en cours...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Erreur lors de la génération du rapport',
              style: TextStyle(fontSize: 18, color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_reportData == null) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 24),
          _buildSummaryCards(isMobile),
          const SizedBox(height: 24),
          _buildShopsBreakdown(isMobile),
          const SizedBox(height: 24),
          _buildMouvementsParJour(isMobile),
          const SizedBox(height: 24),
          _buildDetailsMouvements(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    final shopName = _reportData!['shopName'] as String?;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, 
                  color: const Color(0xFFDC2626), 
                  size: isMobile ? 24 : 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mouvements des Dettes Intershop',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (shopName != null) ...[
              Row(
                children: [
                  Icon(Icons.store, size: isMobile ? 14 : 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Shop: $shopName',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Sélecteurs de période
            _buildPeriodSelector(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(bool isMobile) {
    final isAdmin = widget.shopId == null; // Si shopId initial est null, c'est l'admin
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, size: isMobile ? 16 : 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Sélection de la période',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sélecteur de shop pour l'admin
          if (isAdmin) ...[
            _buildShopSelector(isMobile),
            const SizedBox(height: 12),
          ],
          // Sélecteurs de dates
          isMobile ? _buildMobileDateSelectors() : _buildDesktopDateSelectors(),
        ],
      ),
    );
  }

  Widget _buildShopSelector(bool isMobile) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final shops = shopService.shops;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedShopId,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.store, size: isMobile ? 16 : 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text('Tous les shops'),
                    ],
                  ),
                ),
                ...shops.map((shop) {
                  return DropdownMenuItem<int?>(
                    value: shop.id,
                    child: Row(
                      children: [
                        Icon(Icons.store, size: isMobile ? 16 : 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shop.designation,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedShopId = value;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopDateSelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildDateField(
            label: 'Date de début',
            date: _startDate,
            onTap: () => _selectStartDate(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateField(
            label: 'Date de fin',
            date: _endDate,
            onTap: () => _selectEndDate(),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _loadReport,
          icon: const Icon(Icons.search, size: 20),
          label: const Text('Actualiser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDateSelectors() {
    return Column(
      children: [
        _buildDateField(
          label: 'Date de début',
          date: _startDate,
          onTap: () => _selectStartDate(),
        ),
        const SizedBox(height: 12),
        _buildDateField(
          label: 'Date de fin',
          date: _endDate,
          onTap: () => _selectEndDate(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Actualiser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDC2626),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDC2626),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Widget _buildSummaryCards(bool isMobile) {
    final summary = _reportData!['summary'] as Map<String, dynamic>;
    final shopName = _reportData!['shopName'] as String?;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 1 : (constraints.maxWidth > 900 ? 4 : 2);
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isMobile ? 8 : 12,
          mainAxisSpacing: isMobile ? 8 : 12,
          childAspectRatio: isMobile ? 3 : 2.5,
          children: [
            _buildSummaryCard(
              'Total Créances',
              summary['totalCreances'] as double,
              Icons.trending_up,
              Colors.green,
              isMobile,
            ),
            _buildSummaryCard(
              'Total Dettes',
              summary['totalDettes'] as double,
              Icons.trending_down,
              Colors.red,
              isMobile,
            ),
            _buildSummaryCard(
              'Solde Net',
              summary['soldeNet'] as double,
              Icons.account_balance,
              summary['soldeNet'] >= 0 ? Colors.green : Colors.red,
              isMobile,
            ),
            _buildSummaryCard(
              'Mouvements',
              (summary['nombreMouvements'] as int).toDouble(),
              Icons.swap_horiz,
              Colors.blue,
              isMobile,
              isCount: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title, 
    double value, 
    IconData icon, 
    Color color,
    bool isMobile,
    {bool isCount = false}
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCount 
                ? value.toInt().toString()
                : '${value.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsBreakdown(bool isMobile) {
    final shopsNousDoivent = _reportData!['shopsNousDoivent'] as List<Map<String, dynamic>>?;
    final shopsNousDevons = _reportData!['shopsNousDevons'] as List<Map<String, dynamic>>?;
    final shopName = _reportData!['shopName'] as String?;
    
    // N'afficher cette section que si un shop spécifique est sélectionné
    if (shopName == null || shopName == 'Tous les shops') {
      return const SizedBox.shrink();
    }

    if ((shopsNousDoivent == null || shopsNousDoivent.isEmpty) &&
        (shopsNousDevons == null || shopsNousDevons.isEmpty)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune dette inter-shop',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ce shop n\'a ni créances ni dettes pour la période sélectionnée',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shops qui nous doivent (Créances)
        if (shopsNousDoivent != null && shopsNousDoivent.isNotEmpty)
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green[700], size: isMobile ? 20 : 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shops qui nous doivent',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shopsNousDoivent.length} shop(s)',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.green[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...shopsNousDoivent.map((shop) => _buildShopCard(
                    shop['shopName'] as String,
                    shop['creances'] as double,
                    shop['dettes'] as double,
                    shop['solde'] as double,
                    Colors.green,
                    isMobile,
                  )),
                ],
              ),
            ),
          ),
        
        if (shopsNousDoivent != null && shopsNousDoivent.isNotEmpty &&
            shopsNousDevons != null && shopsNousDevons.isNotEmpty)
          const SizedBox(height: 16),
        
        // Shops que nous devons (Dettes)
        if (shopsNousDevons != null && shopsNousDevons.isNotEmpty)
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_down, color: Colors.red[700], size: isMobile ? 20 : 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shops que nous devons',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shopsNousDevons.length} shop(s)',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.red[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...shopsNousDevons.map((shop) => _buildShopCard(
                    shop['shopName'] as String,
                    shop['creances'] as double,
                    shop['dettes'] as double,
                    shop['solde'] as double,
                    Colors.red,
                    isMobile,
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShopCard(
    String shopName,
    double creances,
    double dettes,
    double solde,
    Color color,
    bool isMobile,
  ) {
    final soldeAbs = solde.abs();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.store, size: isMobile ? 16 : 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shopName,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${soldeAbs.toStringAsFixed(2)} USD',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (creances > 0 && dettes > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShopDetailItem(
                    'Créances',
                    creances,
                    Colors.green,
                    isMobile,
                  ),
                  Container(
                    width: 1,
                    height: isMobile ? 30 : 35,
                    color: Colors.grey[300],
                  ),
                  _buildShopDetailItem(
                    'Dettes',
                    dettes,
                    Colors.red,
                    isMobile,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShopDetailItem(
    String label,
    double value,
    Color color,
    bool isMobile,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 10 : 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMouvementsParJour(bool isMobile) {
    final mouvementsParJour = _reportData!['mouvementsParJour'] as List<Map<String, dynamic>>;
    
    if (mouvementsParJour.isEmpty) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[50]!, Colors.purple[50]!],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.event_busy, size: 64, color: Colors.blue[300]),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aucun mouvement',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune transaction pour la période sélectionnée',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey[50]!],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header moderne avec gradient
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timeline,
                      color: Colors.white,
                      size: isMobile ? 24 : 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Évolution Quotidienne',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Suivi jour par jour des dettes',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${mouvementsParJour.length} jour(s)',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Liste des jours
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: mouvementsParJour.map((jour) => _buildJourCard(jour, isMobile)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourCard(Map<String, dynamic> jour, bool isMobile) {
    final date = jour['date'] as String;
    final creances = jour['creances'] as double;
    final dettes = jour['dettes'] as double;
    final solde = jour['solde'] as double;
    final detteAnterieure = jour['detteAnterieure'] as double? ?? 0.0;
    final soldeCumule = jour['soldeCumule'] as double? ?? solde;
    final nombreOps = jour['nombreOperations'] as int;

    final isPositive = soldeCumule >= 0;
    final cardColor = isPositive ? const Color(0xFF10b981) : const Color(0xFFef4444);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            isPositive ? Colors.green[50]! : Colors.red[50]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: cardColor.withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec date - Design moderne
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cardColor.withOpacity(0.1),
                      cardColor.withOpacity(0.05),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: cardColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: cardColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            size: isMobile ? 18 : 20,
                            color: cardColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(DateTime.parse(date)),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 17 : 20,
                                color: Colors.grey[900],
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$nombreOps transaction${nombreOps > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cardColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up : Icons.trending_down,
                            size: isMobile ? 14 : 16,
                            color: cardColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPositive ? 'Créancier' : 'Débiteur',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: cardColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Column(
                  children: [
                    // Dette antérieure - Design moderne avec glassmorphism
                    Container(
                      padding: EdgeInsets.all(isMobile ? 14 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.history,
                              size: isMobile ? 18 : 20,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dette Antérieure',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${detteAnterieure.toStringAsFixed(2)} USD',
                                  style: TextStyle(
                                    fontSize: isMobile ? 15 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: detteAnterieure >= 0 ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Mouvements du jour - Cards modernes
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernMetricCard(
                            'Créances',
                            creances,
                            Colors.green,
                            Icons.add_circle,
                            isMobile,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernMetricCard(
                            'Dettes',
                            dettes,
                            Colors.red,
                            Icons.remove_circle,
                            isMobile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Solde du jour
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.compare_arrows,
                                size: isMobile ? 18 : 20,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Solde du jour',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${solde.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: solde >= 0 ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Solde cumulé - Hero card
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cardColor,
                            cardColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPositive ? Icons.trending_up : Icons.trending_down,
                                  size: isMobile ? 20 : 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Solde Cumulé',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${soldeCumule.toStringAsFixed(2)} USD',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMetricCard(
    String label,
    double value,
    Color color,
    IconData icon,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsMouvements(bool isMobile) {
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    if (mouvements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Text(
                  'Détail des Mouvements',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${mouvements.length} mouvement(s)',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isMobile)
            ..._buildMobileMovementsList(mouvements)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildDesktopMovementsTable(mouvements),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMobileMovementsList(List<Map<String, dynamic>> mouvements) {
    return mouvements.take(20).map((mouvement) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(mouvement['date'] as DateTime),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildTypeChip(mouvement['typeMouvement'] as String, true),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow('De', mouvement['shopSource'] as String, Icons.store),
            const SizedBox(height: 4),
            _buildInfoRow('Vers', mouvement['shopDestination'] as String, Icons.store_mall_directory),
            const SizedBox(height: 4),
            _buildInfoRow(
              'Montant', 
              '${(mouvement['montant'] as double).toStringAsFixed(2)} USD',
              Icons.attach_money,
              isBold: true,
            ),
            if (mouvement['description'] != null && (mouvement['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                mouvement['description'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMovementsTable(List<Map<String, dynamic>> mouvements) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Shop Source')),
        DataColumn(label: Text('Shop Destination')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Montant')),
        DataColumn(label: Text('Description')),
      ],
      rows: mouvements.take(50).map((mouvement) => DataRow(
        cells: [
          DataCell(Text(_formatDateTime(mouvement['date'] as DateTime))),
          DataCell(Text(mouvement['shopSource'] as String)),
          DataCell(Text(mouvement['shopDestination'] as String)),
          DataCell(_buildTypeChip(mouvement['typeMouvement'] as String, false)),
          DataCell(Text(
            '${(mouvement['montant'] as double).toStringAsFixed(2)} USD',
            style: const TextStyle(fontWeight: FontWeight.bold),
          )),
          DataCell(Text(
            mouvement['description'] as String? ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          )),
        ],
      )).toList(),
    );
  }

  Widget _buildTypeChip(String type, bool isMobile) {
    Color color;
    String label;
    
    switch (type) {
      case 'transfert_servi':
        color = Colors.green;
        label = 'Transfert Servi';
        break;
      case 'transfert_initie':
        color = Colors.orange;
        label = 'Transfert Initié';
        break;
      case 'flot_envoye':
        color = Colors.blue;
        label = 'Flot Envoyé';
        break;
      case 'flot_recu':
        color = Colors.purple;
        label = 'Flot Reçu';
        break;
      default:
        color = Colors.grey;
        label = type;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8, 
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: isMobile ? 10 : 12,
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
}
