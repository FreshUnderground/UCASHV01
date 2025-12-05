import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/journal_caisse_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/reports_pdf_service.dart';
import '../services/shop_service.dart';
import '../services/agent_service.dart';

import '../utils/responsive_utils.dart';
import '../theme/ucash_containers.dart';
import '../widgets/pdf_viewer_dialog.dart';
import '../widgets/capital_adjustment_dialog.dart';
import '../widgets/reports/mouvements_caisse_report.dart';

class JournalCaisseWidget extends StatefulWidget {
  final int? shopId;
  final int? agentId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final bool isAdminView; // Si true, désactive certaines actions (ajuster capital, clôture)

  const JournalCaisseWidget({
    super.key,
    this.shopId,
    this.agentId,
    this.initialStartDate,
    this.initialEndDate,
    this.isAdminView = false,
  });

  @override
  State<JournalCaisseWidget> createState() => _JournalCaisseWidgetState();
}

class _JournalCaisseWidgetState extends State<JournalCaisseWidget> {
  List<JournalCaisseModel> _journalEntries = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  ModePaiement? _selectedMode;
  TypeMouvement? _selectedType;
  int _selectedTabIndex = 0; // 0 = Journal Entries, 1 = Cash Movement Report

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _loadJournalEntries();
  }

  @override
  void didUpdateWidget(JournalCaisseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.initialStartDate != widget.initialStartDate ||
        oldWidget.initialEndDate != widget.initialEndDate) {
      _startDate = widget.initialStartDate;
      _endDate = widget.initialEndDate;
      _loadJournalEntries();
    }
  }

  Future<void> _loadJournalEntries() async {
    setState(() => _isLoading = true);

    try {
      List<JournalCaisseModel> entries;

      debugPrint('📊 JOURNAL CAISSE - Chargement...');
      debugPrint('   shopId: ${widget.shopId}');
      debugPrint('   agentId: ${widget.agentId}');

      if (widget.shopId != null) {
        entries =
            await LocalDB.instance.getJournalEntriesByShop(widget.shopId!);
        debugPrint('   ✅ ${entries.length} entrées pour shop ${widget.shopId}');
      } else if (widget.agentId != null) {
        entries =
            await LocalDB.instance.getJournalEntriesByAgent(widget.agentId!);
        debugPrint('   ✅ ${entries.length} entrées pour agent ${widget.agentId}');
      } else {
        entries = await LocalDB.instance.getAllJournalEntries();
        debugPrint('   ✅ ${entries.length} entrées totales');
      }

      // Appliquer les filtres
      if (_startDate != null) {
        final beforeFilter = entries.length;
        entries =
            entries.where((e) => e.dateAction.isAfter(_startDate!)).toList();
        debugPrint('   🔍 Filtre date début: $beforeFilter → ${entries.length}');
      }
      if (_endDate != null) {
        final beforeFilter = entries.length;
        entries = entries
            .where((e) =>
                e.dateAction.isBefore(_endDate!.add(const Duration(days: 1))))
            .toList();
        debugPrint('   🔍 Filtre date fin: $beforeFilter → ${entries.length}');
      }
      if (_selectedMode != null) {
        final beforeFilter = entries.length;
        entries = entries.where((e) => e.mode == _selectedMode).toList();
        debugPrint('   🔍 Filtre mode: $beforeFilter → ${entries.length}');
      }
      if (_selectedType != null) {
        final beforeFilter = entries.length;
        entries = entries.where((e) => e.type == _selectedType).toList();
        debugPrint('   🔍 Filtre type: $beforeFilter → ${entries.length}');
      }

      // Trier par date décroissante
      entries.sort((a, b) => b.dateAction.compareTo(a.dateAction));
      
      debugPrint('📊 JOURNAL CAISSE - ${entries.length} entrées finales à afficher');
      if (entries.isEmpty) {
        debugPrint('⚠️ AUCUNE DONNÉE - Vérifiez:');
        debugPrint('   1. Y a-t-il des opérations créées?');
        debugPrint('   2. Les entrées journal sont-elles générées?');
        debugPrint('   3. Les filtres sont-ils trop restrictifs?');
      }

      setState(() {
        _journalEntries = entries;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur chargement journal: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors du chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showCapitalAdjustmentDialog() {
    if (widget.shopId != null) {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shop = shopService.shops.firstWhere(
        (s) => s.id == widget.shopId,
        orElse: () => throw Exception('Shop non trouvé'),
      );
      
      showDialog(
        context: context,
        builder: (context) => CapitalAdjustmentDialog(shop: shop),
      ).then((result) {
        if (result == true) {
          _loadJournalEntries();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          _buildFilters(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          _buildTabBar(),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
          if (_selectedTabIndex == 0) ...[
            _buildSummaryCards(),
            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildJournalTable(),
            ),
          ] else ...[
            Expanded(
              child: MouvementsCaisseReport(
                shopId: widget.shopId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Add tab bar method
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 20, tablet: 22, desktop: 25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                padding: ResponsiveUtils.getFluidPadding(
                  context,
                  mobile: const EdgeInsets.symmetric(vertical: 10),
                  tablet: const EdgeInsets.symmetric(vertical: 11),
                  desktop: const EdgeInsets.symmetric(vertical: 12),
                ),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getFluidBorderRadius(context, mobile: 20, tablet: 22, desktop: 25),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Journal de Caisse',
                    style: TextStyle(
                      color: _selectedTabIndex == 0 ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: ResponsiveUtils.getFluidPadding(
                  context,
                  mobile: const EdgeInsets.symmetric(vertical: 10),
                  tablet: const EdgeInsets.symmetric(vertical: 11),
                  desktop: const EdgeInsets.symmetric(vertical: 12),
                ),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getFluidBorderRadius(context, mobile: 20, tablet: 22, desktop: 25),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Rapport Mouvements',
                    style: TextStyle(
                      color: _selectedTabIndex == 1 ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 500;
        
        if (isVeryNarrow) {
          // Stack header elements vertically on narrow screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: const Color(0xFFDC2626),
                    size: context.fluidIcon(mobile: 28, tablet: 32, desktop: 36),
                  ),
                  context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journal de Caisse',
                          style: TextStyle(
                            fontSize:
                                context.fluidFont(mobile: 22, tablet: 26, desktop: 30),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        context.verticalSpace(mobile: 4, tablet: 6, desktop: 8),
                        Text(
                          'Entrées et sorties Cash/Virtuel',
                          style: TextStyle(
                            fontSize:
                                context.fluidFont(mobile: 13, tablet: 14, desktop: 16),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
              // Boutons d'actions in a wrap for narrow screens
              Wrap(
                spacing: 8,
                children: [
                  // IMPORTANT: Admin ne peut pas ajuster le capital
                  if (widget.shopId != null && !widget.isAdminView)
                    IconButton(
                      onPressed: _showCapitalAdjustmentDialog,
                      icon: Icon(
                        Icons.account_balance,
                        size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                      ),
                      tooltip: 'Ajuster Capital',
                    ),
                  IconButton(
                    onPressed: _exportToExcel,
                    icon: Icon(
                      Icons.download,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Exporter vers Excel',
                  ),
                  IconButton(
                    onPressed: _printJournal,
                    icon: Icon(
                      Icons.print,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Imprimer',
                  ),
                  IconButton(
                    onPressed: _onFilterChanged, // Updated to use the new method
                    icon: Icon(
                      Icons.refresh,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ],
          );
        } else {
          // Original layout for wider screens
          return Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: const Color(0xFFDC2626),
                size: context.fluidIcon(mobile: 28, tablet: 32, desktop: 36),
              ),
              context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journal de Caisse',
                      style: TextStyle(
                        fontSize:
                            context.fluidFont(mobile: 22, tablet: 26, desktop: 30),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    context.verticalSpace(mobile: 4, tablet: 6, desktop: 8),
                    Text(
                      'Entrées et sorties Cash/Virtuel',
                      style: TextStyle(
                        fontSize:
                            context.fluidFont(mobile: 13, tablet: 14, desktop: 16),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Boutons d'actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IMPORTANT: Admin ne peut pas ajuster le capital
                  if (widget.shopId != null && !widget.isAdminView)
                    IconButton(
                      onPressed: _showCapitalAdjustmentDialog,
                      icon: Icon(
                        Icons.account_balance,
                        size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                      ),
                      tooltip: 'Ajuster Capital',
                    ),
                  IconButton(
                    onPressed: _exportToExcel,
                    icon: Icon(
                      Icons.download,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Exporter vers Excel',
                  ),
                  IconButton(
                    onPressed: _printJournal,
                    icon: Icon(
                      Icons.print,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Imprimer',
                  ),
                  IconButton(
                    onPressed: _onFilterChanged, // Updated to use the new method
                    icon: Icon(
                      Icons.refresh,
                      size: context.fluidIcon(mobile: 22, tablet: 24, desktop: 26),
                    ),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  void _onFilterChanged() {
    // For the journal entries, we reload them
    _loadJournalEntries();
    // For the cash movement report, it will automatically update when the widget rebuilds
    // because it receives the updated dates as parameters
    setState(() {}); // Trigger rebuild to update both tabs
  }

  Widget _buildFilters() {
    final isMobile = context.isSmallScreen;

    return context.adaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: const Color(0xFFDC2626),
                size: context.fluidIcon(mobile: 20, tablet: 22, desktop: 24),
              ),
              const SizedBox(width: 8),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: context.fluidFont(mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 400;
              return Wrap(
                spacing: isMobile ? 8 : 12,
                runSpacing: isMobile ? 8 : 12,
                children: [
                  // Filtre par type
                  _buildFilterChip(
                    label: 'Type',
                    icon: Icons.swap_vert,
                    child: DropdownButton<TypeMouvement?>(
                      value: _selectedType,
                      hint: const Text('Tous'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous')),
                        ...TypeMouvement.values.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type == TypeMouvement.entree
                                  ? 'Entrées'
                                  : 'Sorties'),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                        _onFilterChanged(); // Use the new method
                      },
                      underline: const SizedBox(),
                      isExpanded: isVeryNarrow,
                      itemHeight: isVeryNarrow ? null : kMinInteractiveDimension,
                    ),
                  ),

                  // Filtre par mode de paiement
                  _buildFilterChip(
                    label: 'Mode',
                    icon: Icons.payment,
                    child: DropdownButton<ModePaiement?>(
                      value: _selectedMode,
                      hint: const Text('Tous'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous')),
                        DropdownMenuItem(
                            value: ModePaiement.cash, child: Text('Cash')),
                        DropdownMenuItem(
                            value: ModePaiement.airtelMoney,
                            child: Text('Airtel Money')),
                        DropdownMenuItem(
                            value: ModePaiement.mPesa, child: Text('M-Pesa')),
                        DropdownMenuItem(
                            value: ModePaiement.orangeMoney,
                            child: Text('Orange Money')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedMode = value);
                        _onFilterChanged(); // Use the new method
                      },
                      underline: const SizedBox(),
                      isExpanded: isVeryNarrow,
                      itemHeight: isVeryNarrow ? null : kMinInteractiveDimension,
                    ),
                  ),

                  // Filtre par date
                  _buildFilterChip(
                    label: 'Date',
                    icon: Icons.calendar_today,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _selectStartDate,
                          child: Text(
                            _startDate == null
                                ? 'Début'
                                : _formatDate(_startDate!),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Text(' → '),
                        TextButton(
                          onPressed: _selectEndDate,
                          child: Text(
                            _endDate == null ? 'Fin' : _formatDate(_endDate!),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (_startDate != null || _endDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clearDateFilters,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: EdgeInsets.symmetric(
        horizontal: context.fluidSpacing(mobile: 12, tablet: 14, desktop: 16),
        vertical: context.fluidSpacing(mobile: 8, tablet: 10, desktop: 12),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: context.fluidFont(mobile: 12, tablet: 13, desktop: 14),
              color: Colors.grey[700],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalEntrees = _journalEntries
        .where((e) => e.type == TypeMouvement.entree)
        .fold<double>(0, (sum, e) => sum + e.montant);

    final totalSorties = _journalEntries
        .where((e) => e.type == TypeMouvement.sortie)
        .fold<double>(0, (sum, e) => sum + e.montant);

    // Obtenir le capital initial du shop
    double capitalInitial = 0.0;
    if (widget.shopId != null) {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shop = shopService.shops.firstWhere(
        (s) => s.id == widget.shopId,
        orElse: () => ShopModel(
          id: widget.shopId ?? 0,
          designation: '',
          localisation: '',
          capitalInitial: 0.0,
        ),
      );
      capitalInitial = shop.capitalInitial;
    }

    final solde = capitalInitial + totalEntrees - totalSorties;

    // Calcul par mode de paiement
    final Map<ModePaiement, double> totauxParMode = {};
    for (var mode in ModePaiement.values) {
      final entrees = _journalEntries
          .where((e) => e.mode == mode && e.type == TypeMouvement.entree)
          .fold<double>(0, (sum, e) => sum + e.montant);
      final sorties = _journalEntries
          .where((e) => e.mode == mode && e.type == TypeMouvement.sortie)
          .fold<double>(0, (sum, e) => sum + e.montant);
      totauxParMode[mode] = entrees - sorties;
    }

    return context.gridContainer(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      aspectRatio: 2.2, // Increased to avoid overflow
      children: [
        _buildStatCard(
          title: 'Capital Initial',
          amount: capitalInitial,
          color: Colors.indigo,
          icon: Icons.savings,
        ),
        _buildStatCard(
          title: 'Total Entrées',
          amount: totalEntrees,
          color: Colors.green,
          icon: Icons.arrow_downward,
        ),
        _buildStatCard(
          title: 'Total Sorties',
          amount: totalSorties,
          color: Colors.red,
          icon: Icons.arrow_upward,
        ),
        _buildStatCard(
          title: 'Solde Actuel',
          amount: solde,
          color: solde >= 0 ? Colors.blue : Colors.orange,
          icon: Icons.account_balance_wallet,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    bool isCount = false,
  }) {
    return Container(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(18),
        desktop: const EdgeInsets.all(22),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: context.fluidIcon(mobile: 30, tablet: 34, desktop: 38),
            ),
          ),
          context.verticalSpace(mobile: 10, tablet: 12, desktop: 14),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: context.fluidFont(mobile: 12, tablet: 13, desktop: 14),
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isCount
                    ? amount.toInt().toString()
                    : '${amount.toStringAsFixed(2)} USD',
                style: TextStyle(
                  fontSize: context.fluidFont(mobile: 18, tablet: 20, desktop: 24),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalTable() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du journal de caisse...'),
          ],
        ),
      );
    }

    if (_journalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucune entrée de journal',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Veuillez effectuer des opérations pour générer des entrées',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // En-tête du tableau
          _buildTableHeader(),
          const Divider(height: 1),

          // Contenu scrollable
          Expanded(
            child: ListView.builder(
              itemCount: _journalEntries.length,
              itemBuilder: (context, index) {
                final entry = _journalEntries[index];
                return _buildJournalRow(entry, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final isMobile = context.isSmallScreen;

    if (isMobile) {
      return Container(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(10),
          tablet: const EdgeInsets.all(11),
          desktop: const EdgeInsets.all(12),
        ),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(
              ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 11, desktop: 12),
            ),
          ),
        ),
        child: Text(
          'Mouvements de caisse',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 13.5, desktop: 14),
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      );
    }

    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildHeaderCell('Date')),
          Expanded(flex: 3, child: _buildHeaderCell('Libellé')),
          Expanded(flex: 2, child: _buildHeaderCell('Type')),
          Expanded(flex: 2, child: _buildHeaderCell('Mode')),
          Expanded(flex: 2, child: _buildHeaderCell('Montant')),
          Expanded(flex: 1, child: _buildHeaderCell('Action')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  Widget _buildJournalRow(JournalCaisseModel entry, int index) {
    final isMobile = context.isSmallScreen;
    final isEntree = entry.type == TypeMouvement.entree;
    final color = isEntree ? Colors.green : Colors.red;

    if (isMobile) {
      return _buildMobileRow(entry, color, isEntree);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey[50] : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        borderRadius: index == 0 
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(entry.dateAction),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              entry.libelle,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.typeLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.modeLabel,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isEntree ? '+' : '-'}${entry.montant.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              onPressed: () => _showEntryDetails(entry),
              tooltip: 'Détails',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(JournalCaisseModel entry, Color color, bool isEntree) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec type badge
            Row(
              children: [
                // Icône circulaire
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEntree ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Libellé
                Expanded(
                  child: Text(
                    entry.libelle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    entry.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 20),
            
            // Informations
            LayoutBuilder(
              builder: (context, constraints) {
                final isVeryNarrow = constraints.maxWidth < 300;
                
                if (isVeryNarrow) {
                  // Stack information vertically on very narrow screens
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date et mode
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(entry.dateAction),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getModeIcon(entry.mode),
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.modeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Montant
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isEntree ? '+' : '-'}${entry.montant.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                'USD',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Original layout for wider screens
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date et mode
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(entry.dateAction),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _getModeIcon(entry.mode),
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.modeLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Montant et action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isEntree ? '+' : '-'}${entry.montant.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            'USD',
                            style: TextStyle(
                              fontSize: 12,
                              color: color.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              }
            ),
            
            const SizedBox(height: 10),
            
            // Bouton détails
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showEntryDetails(entry),
                icon: Icon(Icons.info_outline, size: 16, color: color),
                label: Text(
                  'Voir détails',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getModeIcon(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return Icons.money;
      case ModePaiement.airtelMoney:
        return Icons.phone_android;
      case ModePaiement.mPesa:
        return Icons.account_balance_wallet;
      case ModePaiement.orangeMoney:
        return Icons.payment;
    }
  }

  void _showEntryDetails(JournalCaisseModel entry) {
    final agentService = Provider.of<AgentService>(context, listen: false);
    final agent = agentService.getAgentById(entry.agentId);
    final agentName = agent?.nom ?? agent?.username ?? entry.lastModifiedBy ?? 'Agent inconnu';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails de l\'entrée'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Libellé', entry.libelle),
              _buildDetailRow('Type', entry.typeLabel),
              _buildDetailRow('Mode', entry.modeLabel),
              _buildDetailRow(
                  'Montant', '${entry.montant.toStringAsFixed(2)} USD'),
              _buildDetailRow('Agent', agentName),
              _buildDetailRow('Date', _formatDateTime(entry.dateAction)),
              if (entry.notes != null && entry.notes!.isNotEmpty)
                _buildDetailRow('Notes', entry.notes!),
              if (entry.lastModifiedBy != null)
                _buildDetailRow('Modifié par', entry.lastModifiedBy!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadJournalEntries();
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _startDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() => _startDate = picked);
      _onFilterChanged(); // Use the new method
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _endDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() => _endDate = picked);
      _onFilterChanged(); // Use the new method
    }
  }

  void _clearDateFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _onFilterChanged(); // Use the new method
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getModeLabel(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }

  // Export vers Excel (CSV)
  Future<void> _exportToExcel() async {
    try {
      // Créer le contenu CSV
      final buffer = StringBuffer();

      // En-têtes
      buffer.writeln('Date;Libellé;Type;Mode;Montant;Notes');

      // Données
      for (final entry in _journalEntries) {
        buffer.writeln('${_formatDateTime(entry.dateAction)};'
            '${entry.libelle};'
            '${entry.typeLabel};'
            '${entry.modeLabel};'
            '${entry.montant.toStringAsFixed(2)};'
            '${entry.notes ?? ""}');
      }

      // Sauvegarder le fichier
      final String csvContent = buffer.toString();
      final String fileName =
          'journal_caisse_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Utiliser share pour permettre le téléchargement
      await _shareFile(csvContent, fileName, 'text/csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Journal exporté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Imprimer le journal
  Future<void> _printJournal() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final shop = shopService.shops.firstWhere(
        (s) => s.id == currentUser.shopId,
        orElse: () => shopService.shops.first,
      );
      
      // Générer le PDF
      final pdfDoc = await generateJournalCaisseReportPdf(
        entries: _journalEntries,
        shop: shop,
        startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        endDate: _endDate ?? DateTime.now(),
      );
      
      // Afficher le PDF dans un dialog
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDoc,
          title: 'Journal de Caisse',
          fileName: 'journal_caisse_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'impression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Partager un fichier (Web et Mobile compatible)
  Future<void> _shareFile(
      String content, String fileName, String mimeType) async {
    try {
      // Pour le web, utiliser l'import conditionnel
      if (kIsWeb) {
        // Sur Web, on peut télécharger directement
        // Utiliser JavaScript interop au lieu de dart:html
        _downloadFileWeb(content, fileName);
      } else {
        // Pour mobile, afficher un message pour l'instant
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📄 Export disponible sur version Web'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Téléchargement Web sans dart:html
  void _downloadFileWeb(String content, String fileName) {
    // Cette fonction sera remplacée par une implémentation Web spécifique si nécessaire
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📄 Fichier prêt: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
