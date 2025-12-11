import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';
import '../../services/document_header_service.dart';
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
  bool _showFilters = false; // Filters hidden by default
  bool _showEvolutionQuotidienne = false; // Evolution section hidden by default
  bool _showDetailsMouvements = false; // Details section hidden by default
  String _groupByOption = 'typeOps'; // Grouping option: 'typeOps', 'shopSource', 'shopDestination'
  String? _expandedShopName; // Track which shop card is expanded for detailed view
  bool _localDatesModified = false; // Track if user modified dates locally

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.endDate ?? DateTime.now();
    _selectedShopId = widget.shopId;
    _showFilters = false; // Ensure filters are hidden by default
    _showEvolutionQuotidienne = false; // Ensure evolution section is hidden by default
    _showDetailsMouvements = false; // Ensure details section is hidden by default
    _loadReport();
  }

  @override
  void didUpdateWidget(DettesIntershopReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update dates from parent if user hasn't modified them locally
    if (!_localDatesModified) {
      if (oldWidget.shopId != widget.shopId ||
          oldWidget.startDate != widget.startDate ||
          oldWidget.endDate != widget.endDate) {
        // Update internal dates from widget props
        if (widget.startDate != null) {
          _startDate = widget.startDate!;
        }
        if (widget.endDate != null) {
          _endDate = widget.endDate!;
        }
        _selectedShopId = widget.shopId;
        _loadReport();
      }
    } else if (oldWidget.shopId != widget.shopId) {
      // Shop changed but dates are local, only update shop
      _selectedShopId = widget.shopId;
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
            // Bouton pour afficher/masquer les filtres
            _buildFilterToggle(isMobile),
            // Boutons PDF
            const SizedBox(height: 12),
            _buildPdfButtons(isMobile),
            // Sélecteurs de période (conditionnels)
            if (_showFilters) ...[  
              const SizedBox(height: 12),
              _buildPeriodSelector(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  /// Bouton pour afficher/masquer les filtres
  Widget _buildFilterToggle(bool isMobile) {
    return InkWell(
      onTap: () {
        setState(() {
          _showFilters = !_showFilters;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 14,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: _showFilters ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showFilters ? Colors.blue[300]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: isMobile ? 18 : 20,
                  color: _showFilters ? Colors.blue[700] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: _showFilters ? Colors.blue[900] : Colors.grey[700],
                  ),
                ),
              ],
            ),
            Icon(
              _showFilters ? Icons.expand_less : Icons.expand_more,
              size: isMobile ? 20 : 24,
              color: _showFilters ? Colors.blue[700] : Colors.grey[600],
            ),
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
        _localDatesModified = true; // User modified dates locally
      });
      // User will click "Actualiser" to reload
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
        _localDatesModified = true; // User modified dates locally
      });
      // User will click "Actualiser" to reload
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
        // Shops qui Nous qui Doivent (Créances)
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
                          'Shops qui Nous qui Doivent',
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
        
        // Shops que Nous que Devons (Dettes)
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
                          'Shops que Nous que Devons',
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
    final isExpanded = _expandedShopName == shopName;
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    // Filter movements for this specific shop
    final shopMouvements = mouvements.where((m) {
      final source = m['shopSource'] as String;
      final dest = m['shopDestination'] as String;
      return source == shopName || dest == shopName;
    }).toList();
    
    // Categorize movements by type
    double flotRecu = 0.0;
    double flotEnvoye = 0.0;
    double transfertInitie = 0.0;
    double transfertServi = 0.0;
    int flotRecuCount = 0;
    int flotEnvoyeCount = 0;
    int transfertInitieCount = 0;
    int transfertServiCount = 0;
    
    for (final m in shopMouvements) {
      final type = m['typeMouvement'] as String;
      final montant = m['montant'] as double;
      final source = m['shopSource'] as String;
      final dest = m['shopDestination'] as String;
      
      switch (type) {
        case 'flot_recu':
          if (source == shopName) {
            flotRecu += montant;
            flotRecuCount++;
          }
          break;
        case 'flot_envoye':
          if (dest == shopName) {
            flotEnvoye += montant;
            flotEnvoyeCount++;
          }
          break;
        case 'transfert_initie':
          if (dest == shopName) {
            transfertInitie += montant;
            transfertInitieCount++;
          }
          break;
        case 'transfert_servi':
          if (source == shopName) {
            transfertServi += montant;
            transfertServiCount++;
          }
          break;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header cliquable
          InkWell(
            onTap: () {
              setState(() {
                _expandedShopName = isExpanded ? null : shopName;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(11),
              topRight: const Radius.circular(11),
              bottomLeft: isExpanded ? Radius.zero : const Radius.circular(11),
              bottomRight: isExpanded ? Radius.zero : const Radius.circular(11),
            ),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(11),
                  topRight: const Radius.circular(11),
                  bottomLeft: isExpanded ? Radius.zero : const Radius.circular(11),
                  bottomRight: isExpanded ? Radius.zero : const Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.store, size: isMobile ? 16 : 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${shopMouvements.length} opération${shopMouvements.length > 1 ? 's' : ''} - Cliquer pour détails',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${solde >= 0 ? '+' : ''}${soldeAbs.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        solde >= 0 ? 'Nous doit' : 'On doit',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                    size: isMobile ? 22 : 26,
                  ),
                ],
              ),
            ),
          ),
          // Détail expandé
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: color.withOpacity(0.3))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Situation détaillée avec $shopName',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grille des types de mouvements
                  Wrap(
                    spacing: isMobile ? 8 : 12,
                    runSpacing: isMobile ? 8 : 12,
                    children: [
                      _buildMovementTypeCard(
                        'Flot Reçu',
                        'Du shop',
                        flotRecu,
                        flotRecuCount,
                        Colors.purple,
                        Icons.inbox,
                        isMobile,
                        isCredit: false,
                      ),
                      _buildMovementTypeCard(
                        'Flot Envoyé',
                        'Au shop',
                        flotEnvoye,
                        flotEnvoyeCount,
                        Colors.blue,
                        Icons.send,
                        isMobile,
                        isCredit: true,
                      ),
                      _buildMovementTypeCard(
                        'Transfert',
                        'Vers shop',
                        transfertInitie,
                        transfertInitieCount,
                        Colors.orange,
                        Icons.call_made,
                        isMobile,
                        isCredit: false,
                      ),
                      _buildMovementTypeCard(
                        'Servi',
                        'Pour shop',
                        transfertServi,
                        transfertServiCount,
                        Colors.green,
                        Icons.call_received,
                        isMobile,
                        isCredit: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Résumé final
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOLDE ACTUEL',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              solde >= 0 
                                  ? '$shopName nous doit' 
                                  : 'Nous devons à $shopName',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${soldeAbs.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ),
    );
  }

  Widget _buildMovementTypeCard(
    String title,
    String subtitle,
    double amount,
    int count,
    Color color,
    IconData icon,
    bool isMobile,
    {bool isCredit = false}
  ) {
    return Container(
      width: isMobile ? double.infinity : 180,
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '$subtitle ($count)',
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green[700] : Colors.red[700],
            ),
          ),
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
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    if (mouvementsParJour.isEmpty) {
      return const SizedBox.shrink();
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
            // Header cliquable pour toggle
            InkWell(
              onTap: () {
                setState(() {
                  _showEvolutionQuotidienne = !_showEvolutionQuotidienne;
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: _showEvolutionQuotidienne ? Radius.zero : const Radius.circular(16),
                    bottomRight: _showEvolutionQuotidienne ? Radius.zero : const Radius.circular(16),
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
                            'Évolution Quotidienne par Shop',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Suivi jour par jour des dettes - Groupé par shop',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${mouvementsParJour.length} jour(s)',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _showEvolutionQuotidienne ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: isMobile ? 24 : 28,
                    ),
                  ],
                ),
              ),
            ),
            // Contenu conditionnel
            if (_showEvolutionQuotidienne)
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: _buildDaysWithCumulativeBalances(mouvementsParJour, mouvements, isMobile),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build all days with cumulative shop balances
  List<Widget> _buildDaysWithCumulativeBalances(
    List<Map<String, dynamic>> mouvementsParJour,
    List<Map<String, dynamic>> allMouvements,
    bool isMobile,
  ) {
    // Sort days chronologically (oldest first)
    final sortedDays = List<Map<String, dynamic>>.from(mouvementsParJour)
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    
    // Track cumulative balance per shop across all days
    final Map<String, double> shopCumulativeBalances = {};
    
    final List<Widget> dayWidgets = [];
    
    for (final jour in sortedDays) {
      final date = jour['date'] as String;
      
      // Filter movements for this day
      final dayMouvements = allMouvements.where((m) {
        final mDate = m['date'] as DateTime;
        return mDate.toIso8601String().split('T')[0] == date;
      }).toList();
      
      // Get unique shops involved in this day's movements
      final Set<String> shopsInvolved = {};
      for (final m in dayMouvements) {
        shopsInvolved.add(m['shopSource'] as String);
        shopsInvolved.add(m['shopDestination'] as String);
      }
      
      // Also include shops with existing cumulative balances (from previous days)
      shopsInvolved.addAll(shopCumulativeBalances.keys);
      
      // Remove current shop from list
      final currentShopName = _reportData!['shopName'] as String?;
      if (currentShopName != null) {
        shopsInvolved.remove(currentShopName);
      }
      
      // Calculate data per shop with cumulative balance
      final List<Map<String, dynamic>> shopsData = [];
      
      for (final shopName in shopsInvolved) {
        // Get previous balance for this shop (from previous days)
        final soldeAnterieur = shopCumulativeBalances[shopName] ?? 0.0;
        
        // Get movements for this shop
        final shopMovs = dayMouvements.where((m) {
          final source = m['shopSource'] as String;
          final dest = m['shopDestination'] as String;
          return source == shopName || dest == shopName;
        }).toList();
        
        // Skip if no operations AND no previous balance
        if (shopMovs.isEmpty && soldeAnterieur == 0.0) continue;
        
        double flotEnvoye = 0.0;
        double flotRecu = 0.0;
        double transfertInitie = 0.0;
        double servis = 0.0;
        double frais = 0.0;
        
        for (final m in shopMovs) {
          final type = m['typeMouvement'] as String;
          final montant = m['montant'] as double;
          final source = m['shopSource'] as String;
          final dest = m['shopDestination'] as String;
          final commission = (m['commission'] as num?)?.toDouble() ?? 0.0;
          
          switch (type) {
            case 'flot_envoye':
              if (dest == shopName) flotEnvoye += montant;
              break;
            case 'flot_recu':
              if (source == shopName) flotRecu += montant;
              break;
            case 'transfert_initie':
              if (dest == shopName) transfertInitie += montant;
              break;
            case 'transfert_servi':
              if (source == shopName) servis += montant;
              break;
          }
          // Accumulate commissions/fees
          frais += commission;
        }
        
        // Calculate new balance using the correct formula matching daily closure report:
        // The balance is now calculated correctly in the service, so we just use the cumulative balance
        final soldeFin = shopCumulativeBalances[shopName] ?? 0.0;        
        // Update cumulative balance for next day
        // The balance is already calculated in the service, so we just store it
        shopCumulativeBalances[shopName] = soldeFin;        
        shopsData.add({
          'shop': shopName,
          'soldeAnterieur': soldeAnterieur,
          'flotEnvoye': flotEnvoye,
          'flotRecu': flotRecu,
          'transfertInitie': transfertInitie,
          'servis': servis,
          'frais': frais,
          'soldeFin': soldeFin,
          'count': shopMovs.length,
        });
      }
      
      // Sort by absolute balance
      shopsData.sort((a, b) => (b['soldeFin'] as double).abs().compareTo((a['soldeFin'] as double).abs()));
      
      // Build the day widget
      dayWidgets.add(_buildDayCardWithCumulativeShops(jour, shopsData, isMobile));
    }
    
    // Return in reverse order (most recent first)
    return dayWidgets.reversed.toList();
  }

  Widget _buildDayCardWithCumulativeShops(
    Map<String, dynamic> jour,
    List<Map<String, dynamic>> shopsData,
    bool isMobile,
  ) {
    final date = jour['date'] as String;
    final creances = jour['creances'] as double;
    final dettes = jour['dettes'] as double;
    final solde = jour['solde'] as double;
    final soldeCumule = jour['soldeCumule'] as double? ?? solde;
    final nombreOps = jour['nombreOperations'] as int;

    final isPositive = soldeCumule >= 0;
    final cardColor = isPositive ? const Color(0xFF10b981) : const Color(0xFFef4444);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withOpacity(0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: isMobile ? 18 : 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(DateTime.parse(date)),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        nombreOps > 0 
                          ? '$nombreOps opération${nombreOps > 1 ? 's' : ''} \u2022 ${shopsData.length} shop${shopsData.length > 1 ? 's' : ''}'
                          : shopsData.isNotEmpty 
                            ? 'Solde reporté \u2022 ${shopsData.length} shop${shopsData.length > 1 ? 's' : ''}'
                            : 'Aucune opération',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${soldeCumule >= 0 ? '+' : ''}${soldeCumule.toStringAsFixed(0)} USD',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Shops breakdown with cumulative
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Évolution par Shop:',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 10),
                ...shopsData.map((data) => _buildShopCumulativeCard(
                  data['shop'] as String,
                  data['soldeAnterieur'] as double,
                  data['flotEnvoye'] as double,
                  data['flotRecu'] as double,
                  data['transfertInitie'] as double,
                  data['servis'] as double,
                  data['frais'] as double,
                  data['soldeFin'] as double,
                  data['count'] as int,
                  isMobile,
                )),
              ],
            ),
          ),
          // Totaux du jour
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDayTotalItem('Créances', creances, Colors.green, isMobile),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildDayTotalItem('Dettes', dettes, Colors.red, isMobile),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildDayTotalItem('Solde Jour', solde, solde >= 0 ? Colors.green : Colors.red, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCumulativeCard(
    String shop,
    double soldeAnterieur,
    double flotEnvoye,
    double flotRecu,
    double transfertInitie,
    double servis,
    double frais,
    double soldeFin,
    int count,
    bool isMobile,
  ) {
    final isPositive = soldeFin >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Shop header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.store, size: isMobile ? 16 : 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Text(
                  '($count op.)',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Details with formula
          Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: Column(
              children: [
                // Solde Antérieur (subtracted in formula)
                _buildFormulaRow(
                  'Solde Antérieur',
                  soldeAnterieur,
                  '-',
                  Colors.grey[700]!,
                  isMobile,
                  isBold: true,
                ),                const Divider(height: 8),
                // + Flot Reçu
                if (flotRecu > 0)
                  _buildFormulaRow('+ Flot Reçu', flotRecu, '+', Colors.purple, isMobile),
                // - Flot Envoyé
                if (flotEnvoye > 0)
                  _buildFormulaRow('- Flot Envoyé', flotEnvoye, '-', Colors.blue, isMobile),                // + Transfert Initié (we initiate, they owe us)
                if (transfertInitie > 0)
                  _buildFormulaRow('+ Transfert Initié', transfertInitie, '+', Colors.orange, isMobile),
                // - Servis (we serve for them, we owe them)
                if (servis > 0)
                  _buildFormulaRow('- Servis', servis, '-', Colors.teal, isMobile),
                // + Frais
                if (frais > 0)
                  _buildFormulaRow('- Frais du Jour', frais, '-', Colors.amber[700]!, isMobile),                const Divider(height: 8),
                // = Solde Fin
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '= SOLDE FIN',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${soldeFin.toStringAsFixed(0)} USD',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Formula explanation
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Calcul: Solde basé sur les flux réels entre shops (comme dans le rapport de clôture)',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaRow(String label, double value, String sign, Color color, bool isMobile, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 3),
      child: Row(
        children: [
          if (sign.isNotEmpty)
            Container(
              width: isMobile ? 6 : 8,
              height: isMobile ? 6 : 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            '${sign == '+' ? '+' : (sign == '-' ? '-' : '')}${value.toStringAsFixed(0)} USD',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: sign == '+' ? Colors.green[700] : (sign == '-' ? Colors.red[700] : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  /// Build day card with breakdown by shop
  Widget _buildJourCardWithShopBreakdown(Map<String, dynamic> jour, List<Map<String, dynamic>> allMouvements, bool isMobile) {
    final date = jour['date'] as String;
    final creances = jour['creances'] as double;
    final dettes = jour['dettes'] as double;
    final solde = jour['solde'] as double;
    final soldeCumule = jour['soldeCumule'] as double? ?? solde;
    final nombreOps = jour['nombreOperations'] as int;

    final isPositive = soldeCumule >= 0;
    final cardColor = isPositive ? const Color(0xFF10b981) : const Color(0xFFef4444);
    
    // Filter movements for this day
    final dayMouvements = allMouvements.where((m) {
      final mDate = m['date'] as DateTime;
      return mDate.toIso8601String().split('T')[0] == date;
    }).toList();
    
    // Get unique shops involved in this day's movements
    final Set<String> shopsInvolved = {};
    for (final m in dayMouvements) {
      shopsInvolved.add(m['shopSource'] as String);
      shopsInvolved.add(m['shopDestination'] as String);
    }
    // Remove current shop from list
    final currentShopName = _reportData!['shopName'] as String?;
    if (currentShopName != null) {
      shopsInvolved.remove(currentShopName);
    }
    
    // Calculate data per shop
    final List<Map<String, dynamic>> shopsData = [];
    for (final shopName in shopsInvolved) {
      // Get movements for this shop
      final shopMovs = dayMouvements.where((m) {
        final source = m['shopSource'] as String;
        final dest = m['shopDestination'] as String;
        return source == shopName || dest == shopName;
      }).toList();
      
      if (shopMovs.isEmpty) continue;
      
      double flotEnvoye = 0.0;
      double flotRecu = 0.0;
      double transfertInitie = 0.0;
      double servis = 0.0;
      
      for (final m in shopMovs) {
        final type = m['typeMouvement'] as String;
        final montant = m['montant'] as double;
        final source = m['shopSource'] as String;
        final dest = m['shopDestination'] as String;
        
        switch (type) {
          case 'flot_envoye':
            if (dest == shopName) flotEnvoye += montant;
            break;
          case 'flot_recu':
            if (source == shopName) flotRecu += montant;
            break;
          case 'transfert_initie':
            if (dest == shopName) transfertInitie += montant;
            break;
          case 'transfert_servi':
            if (source == shopName) servis += montant;
            break;
        }
      }
      
      final shopSolde = flotEnvoye - flotRecu - transfertInitie + servis;
      
      shopsData.add({
        'shop': shopName,
        'flotEnvoye': flotEnvoye,
        'flotRecu': flotRecu,
        'transfertInitie': transfertInitie,
        'servis': servis,
        'solde': shopSolde,
        'count': shopMovs.length,
      });
    }
    
    // Sort by absolute solde
    shopsData.sort((a, b) => (b['solde'] as double).abs().compareTo((a['solde'] as double).abs()));

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withOpacity(0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: isMobile ? 18 : 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(DateTime.parse(date)),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        nombreOps > 0 
                          ? '$nombreOps opération${nombreOps > 1 ? 's' : ''} \u2022 ${shopsData.length} shop${shopsData.length > 1 ? 's' : ''}'
                          : shopsData.isNotEmpty 
                            ? 'Solde reporté \u2022 ${shopsData.length} shop${shopsData.length > 1 ? 's' : ''}'
                            : 'Aucune opération',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${soldeCumule >= 0 ? '+' : ''}${soldeCumule.toStringAsFixed(0)} USD',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Shops breakdown
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détail par Shop:',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 10),
                ...shopsData.map((data) => _buildShopDayDetailCard(
                  data['shop'] as String,
                  data['flotEnvoye'] as double,
                  data['flotRecu'] as double,
                  data['transfertInitie'] as double,
                  data['servis'] as double,
                  data['solde'] as double,
                  data['count'] as int,
                  isMobile,
                )),
              ],
            ),
          ),
          // Totaux du jour
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDayTotalItem('Créances', creances, Colors.green, isMobile),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildDayTotalItem('Dettes', dettes, Colors.red, isMobile),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildDayTotalItem('Solde Jour', solde, solde >= 0 ? Colors.green : Colors.red, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopDayDetailCard(
    String shop,
    double flotEnvoye,
    double flotRecu,
    double transfertInitie,
    double servis,
    double solde,
    int count,
    bool isMobile,
  ) {
    final isPositive = solde >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Shop header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.store, size: isMobile ? 16 : 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${solde.toStringAsFixed(0)} USD',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: Column(
              children: [
                if (flotEnvoye > 0)
                  _buildDetailRow('+ Flot Envoyé', flotEnvoye, Colors.blue, '+', isMobile),
                if (flotRecu > 0)
                  _buildDetailRow('- Flot Reçu', flotRecu, Colors.purple, '-', isMobile),
                if (transfertInitie > 0)
                  _buildDetailRow('- Transfert Initié', transfertInitie, Colors.orange, '-', isMobile),
                if (servis > 0)
                  _buildDetailRow('+ Servis', servis, Colors.teal, '+', isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, Color iconColor, String sign, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 3),
      child: Row(
        children: [
          Container(
            width: isMobile ? 6 : 8,
            height: isMobile ? 6 : 8,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            '$sign${value.toStringAsFixed(0)} USD',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: sign == '+' ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopBreakdownRow(String shop, double creances, double dettes, int count, bool isMobile) {
    final solde = creances - dettes;
    final isPositive = solde >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? Colors.green : Colors.red).withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with shop name and final balance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.store, size: isMobile ? 14 : 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shop,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${solde.toStringAsFixed(0)} USD',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Summary line with operations count
          Row(
            children: [
              Text(
                '$count opération${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              if (creances > 0)
                Text(
                  'Créances: +${creances.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (creances > 0 && dettes > 0)
                Text('  |  ', style: TextStyle(color: Colors.grey[300])),
              if (dettes > 0)
                Text(
                  'Dettes: -${dettes.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build detailed shop evolution for a day showing all movement types
  Widget _buildShopDayEvolution(
    String shop,
    String date,
    List<Map<String, dynamic>> dayMouvements,
    double soldeAnterieur,
    bool isMobile,
  ) {
    // Filter movements for this shop
    final shopMouvements = dayMouvements.where((m) {
      final source = m['shopSource'] as String;
      final dest = m['shopDestination'] as String;
      return source == shop || dest == shop;
    }).toList();

    // Calculate each type
    double flotEnvoye = 0.0; // + Créance
    double flotRecu = 0.0;   // - Dette
    double transfertInitie = 0.0; // - Dette
    double servis = 0.0;     // + Créance
    int flotEnvoyeCount = 0;
    int flotRecuCount = 0;
    int transfertInitieCount = 0;
    int servisCount = 0;

    for (final m in shopMouvements) {
      final type = m['typeMouvement'] as String;
      final montant = m['montant'] as double;
      final source = m['shopSource'] as String;
      final dest = m['shopDestination'] as String;

      switch (type) {
        case 'flot_envoye':
          if (dest == shop) {
            flotEnvoye += montant;
            flotEnvoyeCount++;
          }
          break;
        case 'flot_recu':
          if (source == shop) {
            flotRecu += montant;
            flotRecuCount++;
          }
          break;
        case 'transfert_initie':
          if (dest == shop) {
            transfertInitie += montant;
            transfertInitieCount++;
          }
          break;
        case 'transfert_servi':
          if (source == shop) {
            servis += montant;
            servisCount++;
          }
          break;
      }
    }

    // Calculate final balance
    // Solde = Antérieur + FlotEnvoyé - FlotReçu - TransfertInitié + Servis
    final soldeFin = soldeAnterieur + flotEnvoye - flotRecu - transfertInitie + servis;
    final isPositive = soldeFin >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header avec nom du shop
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.store, size: isMobile ? 14 : 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Text(
                  '${shopMouvements.length} op.',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Détail des mouvements
          Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: Column(
              children: [
                // Solde Antérieur
                _buildEvolutionLine(
                  'Solde Antérieur',
                  soldeAnterieur,
                  null,
                  Colors.grey,
                  isMobile,
                  isBold: true,
                ),
                const Divider(height: 12),
                // + Flot Envoyé
                if (flotEnvoyeCount > 0)
                  _buildEvolutionLine(
                    '+ Flot Envoyé ($flotEnvoyeCount)',
                    flotEnvoye,
                    '+',
                    Colors.blue,
                    isMobile,
                  ),
                // - Flot Reçu
                if (flotRecuCount > 0)
                  _buildEvolutionLine(
                    '- Flot Reçu ($flotRecuCount)',
                    flotRecu,
                    '-',
                    Colors.purple,
                    isMobile,
                  ),
                // - Transfert Initié
                if (transfertInitieCount > 0)
                  _buildEvolutionLine(
                    '- Transfert Initié ($transfertInitieCount)',
                    transfertInitie,
                    '-',
                    Colors.orange,
                    isMobile,
                  ),
                // + Servis
                if (servisCount > 0)
                  _buildEvolutionLine(
                    '+ Servis ($servisCount)',
                    servis,
                    '+',
                    Colors.green,
                    isMobile,
                  ),
                const Divider(height: 12),
                // = Solde Final
                _buildEvolutionLine(
                  '= SOLDE FIN',
                  soldeFin,
                  null,
                  isPositive ? Colors.green : Colors.red,
                  isMobile,
                  isBold: true,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionLine(
    String label,
    double value,
    String? sign,
    Color color,
    bool isMobile,
    {bool isBold = false, bool isTotal = false}
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? color : Colors.grey[700],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTotal ? 10 : 6,
              vertical: isTotal ? 4 : 2,
            ),
            decoration: isTotal ? BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ) : null,
            child: Text(
              '${sign ?? ''}${value.toStringAsFixed(0)} USD',
              style: TextStyle(
                fontSize: isMobile ? (isTotal ? 13 : 11) : (isTotal ? 14 : 12),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isTotal ? Colors.white : (sign == '+' ? Colors.green[700] : (sign == '-' ? Colors.red[700] : color)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTotalItem(String label, double value, Color color, bool isMobile) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 10 : 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(0)} USD',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cliquable pour toggle
          InkWell(
            onTap: () {
              setState(() {
                _showDetailsMouvements = !_showDetailsMouvements;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: _showDetailsMouvements ? Radius.zero : const Radius.circular(16),
              bottomRight: _showDetailsMouvements ? Radius.zero : const Radius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563eb), Color(0xFF1d4ed8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: _showDetailsMouvements ? Radius.zero : const Radius.circular(16),
                  bottomRight: _showDetailsMouvements ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.list_alt,
                      color: Colors.white,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Détail des Mouvements',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Groupé par ${_getGroupByLabel()}',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${mouvements.length} op.',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showDetailsMouvements ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ],
              ),
            ),
          ),
          // Contenu conditionnel
          if (_showDetailsMouvements) ...[
            // Sélecteur de groupement
            _buildGroupBySelector(isMobile),
            // Liste groupée
            _buildGroupedMovementsList(mouvements, isMobile),
          ],
        ],
      ),
    );
  }

  String _getGroupByLabel() {
    switch (_groupByOption) {
      case 'typeOps': return 'Type d\'opération';
      case 'shopSource': return 'Shop source';
      case 'shopDestination': return 'Shop destination';
      default: return 'Type';
    }
  }

  Widget _buildGroupBySelector(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Text(
            'Grouper par:',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGroupByChip('typeOps', 'Type Opération', Icons.category, isMobile),
                  const SizedBox(width: 8),
                  _buildGroupByChip('shopSource', 'Shop Source', Icons.store, isMobile),
                  const SizedBox(width: 8),
                  _buildGroupByChip('shopDestination', 'Shop Destination', Icons.store_mall_directory, isMobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupByChip(String value, String label, IconData icon, bool isMobile) {
    final isSelected = _groupByOption == value;
    return InkWell(
      onTap: () {
        setState(() {
          _groupByOption = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563eb) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563eb) : Colors.grey[400]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isMobile ? 14 : 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedMovementsList(List<Map<String, dynamic>> mouvements, bool isMobile) {
    // Group movements based on selected option
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final m in mouvements) {
      String key;
      switch (_groupByOption) {
        case 'shopSource':
          key = m['shopSource'] as String? ?? 'Inconnu';
          break;
        case 'shopDestination':
          key = m['shopDestination'] as String? ?? 'Inconnu';
          break;
        case 'typeOps':
        default:
          key = m['typeMouvement'] as String? ?? 'Autre';
          break;
      }
      grouped.putIfAbsent(key, () => []).add(m);
    }

    // Sort groups by total amount
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final totalA = grouped[a]!.fold<double>(0, (sum, m) => sum + (m['montant'] as double));
        final totalB = grouped[b]!.fold<double>(0, (sum, m) => sum + (m['montant'] as double));
        return totalB.compareTo(totalA);
      });

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: sortedKeys.map((key) {
          final items = grouped[key]!;
          final total = items.fold<double>(0, (sum, m) => sum + (m['montant'] as double));
          final creances = items.where((m) => m['isCreance'] == true).fold<double>(0, (sum, m) => sum + (m['montant'] as double));
          final dettes = items.where((m) => m['isCreance'] != true).fold<double>(0, (sum, m) => sum + (m['montant'] as double));
          
          return _buildGroupCard(key, items, total, creances, dettes, isMobile);
        }).toList(),
      ),
    );
  }

  Widget _buildGroupCard(String groupName, List<Map<String, dynamic>> items, double total, double creances, double dettes, bool isMobile) {
    String displayName = groupName;
    Color groupColor = Colors.blue;
    IconData groupIcon = Icons.category;

    // Customize display based on group type
    if (_groupByOption == 'typeOps') {
      switch (groupName) {
        case 'transfert_servi':
          displayName = 'Transfert Servi';
          groupColor = Colors.green;
          groupIcon = Icons.call_received;
          break;
        case 'transfert_initie':
          displayName = 'Transfert Initié';
          groupColor = Colors.orange;
          groupIcon = Icons.call_made;
          break;
        case 'flot_envoye':
          displayName = 'Flot Envoyé';
          groupColor = Colors.blue;
          groupIcon = Icons.send;
          break;
        case 'flot_recu':
          displayName = 'Flot Reçu';
          groupColor = Colors.purple;
          groupIcon = Icons.inbox;
          break;
      }
    } else {
      groupIcon = Icons.store;
      groupColor = creances >= dettes ? Colors.green : Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: groupColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: groupColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Group header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: groupColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: groupColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(groupIcon, color: Colors.white, size: isMobile ? 16 : 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '${items.length} opération${items.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (creances > 0)
                      Text(
                        '+${creances.toStringAsFixed(0)} USD',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    if (dettes > 0)
                      Text(
                        '-${dettes.toStringAsFixed(0)} USD',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Items list (show first 5)
          ...items.take(isMobile ? 3 : 5).map((m) => _buildMouvementItem(m, isMobile)),
          if (items.length > (isMobile ? 3 : 5))
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '+ ${items.length - (isMobile ? 3 : 5)} autre${items.length - (isMobile ? 3 : 5) > 1 ? 's' : ''}...',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMouvementItem(Map<String, dynamic> m, bool isMobile) {
    final isCreance = m['isCreance'] == true;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            _formatDate(m['date'] as DateTime),
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${m['shopSource']} → ${m['shopDestination']}',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${isCreance ? '+' : '-'}${(m['montant'] as double).toStringAsFixed(0)} USD',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: isCreance ? Colors.green[700] : Colors.red[700],
            ),
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

  /// Build PDF action buttons
  Widget _buildPdfButtons(bool isMobile) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _partagerPDF,
          icon: const Icon(Icons.share, size: 18),
          label: Text(isMobile ? 'Partager' : 'Partager PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _imprimerPDF,
          icon: const Icon(Icons.print, size: 18),
          label: Text(isMobile ? 'Imprimer' : 'Imprimer PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Share PDF
  Future<void> _partagerPDF() async {
    if (_reportData == null) return;

    try {
      final pdf = await _generatePdf();
      final pdfBytes = await pdf.save();
      final fileName = 'dettes_intershop_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF partagé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur partage: $e')),
        );
      }
    }
  }

  /// Print PDF
  Future<void> _imprimerPDF() async {
    if (_reportData == null) return;

    try {
      final pdf = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur impression: $e')),
        );
      }
    }
  }

  /// Generate PDF document
  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final summary = _reportData!['summary'] as Map<String, dynamic>;
    final shopName = _reportData!['shopName'] as String?;
    final shopsNousDoivent = _reportData!['shopsNousDoivent'] as List<Map<String, dynamic>>? ?? [];
    final shopsNousDevons = _reportData!['shopsNousDevons'] as List<Map<String, dynamic>>? ?? [];
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    final mouvementsParJour = _reportData!['mouvementsParJour'] as List<Map<String, dynamic>>;
    
    // Load header from DocumentHeaderService
    final headerService = DocumentHeaderService();
    await headerService.initialize();
    final header = headerService.getHeaderOrDefault();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.red700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          header.companyName,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (header.address != null)
                          pw.Text(
                            header.address!,
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (header.phone != null)
                          pw.Text(
                            'Tél: ${header.phone!}',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        if (header.email != null)
                          pw.Text(
                            'Email: ${header.email!}',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'RAPPORT DES DETTES INTERSHOP',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (shopName != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Shop: $shopName',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
                pw.SizedBox(height: 4),
                pw.Text(
                  'Période: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  'Généré le: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Summary
          pw.Text(
            'RÉSUMÉ',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Créances',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${(summary['totalCreances'] as double).toStringAsFixed(2)} USD',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Dettes',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${(summary['totalDettes'] as double).toStringAsFixed(2)} USD',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Solde Net',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${(summary['soldeNet'] as double).toStringAsFixed(2)} USD',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Shops breakdown
          if (shopsNousDoivent.isNotEmpty || shopsNousDevons.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'DÉTAIL PAR SHOP',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 10),
            
            if (shopsNousDoivent.isNotEmpty) ...[
              pw.Text(
                'Shops qui nous doivent:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
              pw.SizedBox(height: 5),
              ...shopsNousDoivent.map((shop) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      shop['shopName'] as String,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '${(shop['solde'] as double).toStringAsFixed(2)} USD',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            if (shopsNousDevons.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Shops que nous devons:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                ),
              ),
              pw.SizedBox(height: 5),
              ...shopsNousDevons.map((shop) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      shop['shopName'] as String,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '${(shop['solde'] as double).abs().toStringAsFixed(2)} USD',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
          
          // Daily movements
          if (mouvementsParJour.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'ÉVOLUTION QUOTIDIENNE',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Créances', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Dettes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Solde', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Nb Ops', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                  ],
                ),
                ...mouvementsParJour.take(30).map((jour) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(jour['date'] as String, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${(jour['creances'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${(jour['dettes'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${(jour['solde'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${jour['nombreOperations']}', style: const pw.TextStyle(fontSize: 7)),
                    ),
                  ],
                )),
              ],
            ),
          ],
          
          // Movements details (limited to first 20)
          if (mouvements.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'DÉTAILS DES MOUVEMENTS (20 premiers)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('De', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Vers', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Montant', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                    ),
                  ],
                ),
                ...mouvements.take(20).map((mouvement) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        _formatDateTime(mouvement['date'] as DateTime),
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        mouvement['shopSource'] as String,
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        mouvement['shopDestination'] as String,
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        _getTypeLabel(mouvement['typeMouvement'] as String),
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '${(mouvement['montant'] as double).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                  ],
                )),
              ],
            ),
            if (mouvements.length > 20)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  '... et ${mouvements.length - 20} autres mouvements',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
          ],
          
          // Footer
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'UCASH - Système de Gestion Financière',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.Text(
                'Page 1',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  String _getTypeLabel(String type) {
    switch (type) {
      case 'transfert_servi':
        return 'Transfert Servi';
      case 'transfert_initie':
        return 'Transfert Initié';
      case 'flot_envoye':
        return 'Flot Envoyé';
      case 'flot_recu':
        return 'Flot Reçu';
      default:
        return type;
    }
  }
}
