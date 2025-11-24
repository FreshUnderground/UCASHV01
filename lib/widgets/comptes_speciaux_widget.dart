import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/compte_special_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../models/compte_special_model.dart';

/// Widget pour afficher et gérer les comptes spéciaux (FRAIS et DÉPENSE)
class ComptesSpeciauxWidget extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isAdmin;

  const ComptesSpeciauxWidget({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
    this.isAdmin = false,
  });

  @override
  State<ComptesSpeciauxWidget> createState() => _ComptesSpeciauxWidgetState();
}

class _ComptesSpeciauxWidgetState extends State<ComptesSpeciauxWidget> {
  final _numberFormat = NumberFormat('#,##0.00', 'fr_FR');
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedShopId;
  bool _showFilters = false; // Contrôle l'affichage des filtres

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.shopId;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await CompteSpecialService.instance.loadTransactions(shopId: _selectedShopId);
    setState(() {}); // Force rebuild
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CompteSpecialService>(
      builder: (context, service, child) {
        final stats = service.getStatistics(
          shopId: _selectedShopId,
          startDate: _startDate,
          endDate: _endDate,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final isMedium = constraints.maxWidth > 600;
            
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMedium ? 5 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec titre et filtres
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    
                    // Sélecteur de shop (admin seulement)
                    if (widget.isAdmin && _showFilters) ...[
                      _buildShopSelector(context, isWide),
                      const SizedBox(height: 16),
                    ],
                    
                    // Filtres de date
                    if (_showFilters) ...[
                      _buildDateFilters(context, isWide),
                      const SizedBox(height: 24),
                    ],
                    
                    // Cartes de résumé - Affichables/Masquables
                    if (_showFilters) ...[
                      _buildSummaryCards(stats, isWide, isMedium),
                      const SizedBox(height: 32),
                    ],
                    
                    // Boutons d'action - Responsive
                    _buildActionButtons(context, isWide, isMedium),
                    const SizedBox(height: 24),
                    
                    // Liste des transactions avec tabs
                    _buildTransactionsList(service, isWide),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Comptes FRAIS & DÉPENSE',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Bouton pour afficher/masquer les filtres
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
        ),
      ],
    );
  }

  Widget _buildShopSelector(BuildContext context, bool isWide) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final shops = ShopService.instance.shops;
        
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.store, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Shop:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedShopId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tous les shops'),
                      ),
                      ...shops.map((shop) => DropdownMenuItem<int?>(
                        value: shop.id,
                        child: Text(shop.designation),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedShopId = value;
                      });
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateFilters(BuildContext context, bool isWide) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide ? Row(
          children: [
            Icon(Icons.date_range, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            const Text(
              'Période:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDatePicker(
                label: 'Date de début',
                date: _startDate,
                onDateSelected: (date) {
                  setState(() => _startDate = date);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePicker(
                label: 'Date de fin',
                date: _endDate,
                onDateSelected: (date) {
                  setState(() => _endDate = date);
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Réinitialiser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.grey.shade800,
              ),
            ),
          ],
        ) : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Période:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDatePicker(
              label: 'Date de début',
              date: _startDate,
              onDateSelected: (date) {
                setState(() => _startDate = date);
              },
            ),
            const SizedBox(height: 8),
            _buildDatePicker(
              label: 'Date de fin',
              date: _endDate,
              onDateSelected: (date) {
                setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime?) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => onDateSelected(null),
                )
              : const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Sélectionner',
          style: TextStyle(
            color: date != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats, bool isWide, bool isMedium) {
    // Toujours afficher en 3 colonnes sur 1 ligne (sauf mobile)
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileSmall = constraints.maxWidth < 600;
        
        if (isMobileSmall) {
          // Sur petit mobile, afficher en colonne
          return Column(
            children: [
              _buildModernCard(
                title: 'Compte FRAIS',
                amount: stats['solde_frais'],
                count: stats['nombre_frais'],
                icon: Icons.trending_up,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                details: [
                  {'label': 'Commissions', 'value': stats['commissions_auto']},
                  {'label': 'Retraits', 'value': stats['retraits_frais']},
                ],
              ),
              const SizedBox(height: 16),
              _buildModernCard(
                title: 'Compte DÉPENSE',
                amount: stats['solde_depense'],
                count: stats['nombre_depenses'],
                icon: Icons.receipt_long,
                gradient: LinearGradient(
                  colors: stats['solde_depense'] >= 0 
                    ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                ),
                details: [
                  {'label': 'Dépôts', 'value': stats['depots_boss']},
                  {'label': 'Sorties', 'value': stats['sorties']},
                ],
              ),
            ],
          );
        }
        
        // Tablette et desktop: toujours 3 colonnes sur 1 ligne
        return Row(
          children: [
            Expanded(
              child: _buildModernCard(
                title: 'Compte FRAIS',
                amount: stats['solde_frais'],
                count: stats['nombre_frais'],
                icon: Icons.trending_up,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                details: [
                  {'label': 'Commissions', 'value': stats['commissions_auto']},
                  {'label': 'Retraits', 'value': stats['retraits_frais']},
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernCard(
                title: 'Compte DÉPENSE',
                amount: stats['solde_depense'],
                count: stats['nombre_depenses'],
                icon: Icons.receipt_long,
                gradient: LinearGradient(
                  colors: stats['solde_depense'] >= 0 
                    ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                ),
                details: [
                  {'label': 'Dépôts', 'value': stats['depots_boss']},
                  {'label': 'Sorties', 'value': stats['sorties']},
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernCard(
                title: 'Bénéfice Net',
                amount: stats['benefice_net'],
                count: null,
                icon: Icons.account_balance,
                gradient: LinearGradient(
                  colors: stats['benefice_net'] >= 0
                    ? [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]
                    : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                ),
                details: null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernCard({
    required String title,
    required double amount,
    required int? count,
    required IconData icon,
    required Gradient gradient,
    List<Map<String, dynamic>>? details,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  if (count != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: gradient.colors.first.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: gradient.colors.first,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${_numberFormat.format(amount)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                ...details.map((detail) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        detail['label'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '\$${_numberFormat.format(detail['value'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isWide, bool isMedium) {
    final transactionButtons = [
      // FRAIS - Retrait uniquement
      {
        'label': 'R/FRAIS',
        'icon': Icons.remove_circle_outline,
        'gradient': const LinearGradient(colors: [Color(0xFF059669), Color(0xFF047857)]),
        'onPressed': () => _showRetraitFraisDialog(context),
      },
      // DÉPENSE - Dépôt
      {
        'label': 'CASH',
        'icon': Icons.add_circle_outline,
        'gradient': const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
        'onPressed': () => _showDepotDepenseDialog(context),
      },
      // DÉPENSE - Sortie
      {
        'label': 'DEPENSES',
        'icon': Icons.remove_circle_outline,
        'gradient': const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
        'onPressed': () => _showSortieDepenseDialog(context),
      },
    ];
    
    final pdfButtons = [
      // PDF FRAIS
      {
        'label': 'PDF FRAIS',
        'icon': Icons.picture_as_pdf,
        'gradient': const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        'onPressed': () => _generatePdfFrais(context),
      },
      // PDF DÉPENSES
      {
        'label': 'PDF DÉPENSES',
        'icon': Icons.picture_as_pdf,
        'gradient': const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
        'onPressed': () => _generatePdfDepenses(context),
      },
    ];

    return Column(
      children: [
        // Ligne 1: Boutons de transactions (Retrait FRAIS, Dépôt Boss, Sortie/Dépense)
        Row(
          children: transactionButtons.map((btn) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildGradientButton(
                label: btn['label'] as String,
                icon: btn['icon'] as IconData,
                gradient: btn['gradient'] as Gradient,
                onPressed: btn['onPressed'] as VoidCallback,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        // Ligne 2: Boutons PDF
        Row(
          children: pdfButtons.map((btn) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildGradientButton(
                label: btn['label'] as String,
                icon: btn['icon'] as IconData,
                gradient: btn['gradient'] as Gradient,
                onPressed: btn['onPressed'] as VoidCallback,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(CompteSpecialService service, bool isWide) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const Material(
              color: Colors.transparent,
              child: TabBar(
                labelColor: Color(0xFFDC2626),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFFDC2626),
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: Icon(Icons.list), text: 'Toutes'),
                  Tab(icon: Icon(Icons.trending_up), text: 'FRAIS'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'DÉPENSE'),
                ],
              ),
            ),
            // Fix the layout issue by constraining the height
            SizedBox(
              height: 400, // Set a fixed height to prevent layout issues
              child: TabBarView(
                children: [
                  _buildTransactionsListView(
                    service.transactions.where((t) => 
                      (_selectedShopId == null || t.shopId == _selectedShopId) &&
                      (_startDate == null || t.dateTransaction.isAfter(_startDate!)) &&
                      (_endDate == null || t.dateTransaction.isBefore(_endDate!))
                    ).toList(),
                    isWide
                  ),
                  _buildTransactionsListView(service.getFrais(
                    shopId: _selectedShopId,
                    startDate: _startDate,
                    endDate: _endDate,
                  ), isWide),
                  _buildTransactionsListView(service.getDepenses(
                    shopId: _selectedShopId,
                    startDate: _startDate,
                    endDate: _endDate,
                  ), isWide),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsListView(List<CompteSpecialModel> transactions, bool isWide) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Aucune transaction',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isPositive = transaction.montant >= 0;
        
        return InkWell(
          onTap: widget.isAdmin ? () => _showTransactionDetails(context, transaction) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon avec gradient
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: transaction.type == TypeCompteSpecial.FRAIS
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    transaction.typeTransaction.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Description et détails
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateTransaction),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (transaction.agentUsername != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              transaction.agentUsername!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Montant et badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPositive ? '+' : ''}\$${_numberFormat.format(transaction.montant.abs())}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                   ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDepotDepenseDialog(BuildContext context) {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Dépôt Boss - Compte DÉPENSE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montantController,
              decoration: const InputDecoration(
                labelText: 'Montant (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant != null && descriptionController.text.isNotEmpty) {
                if (!context.mounted) return;
                final authService = Provider.of<AuthService>(context, listen: false);
                await CompteSpecialService.instance.depotDepense(
                  montant: montant,
                  description: descriptionController.text,
                  shopId: widget.shopId ?? authService.currentUser!.shopId!,
                  agentId: authService.currentUser?.id,
                  agentUsername: authService.currentUser?.username,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Dépôt enregistré')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showSortieDepenseDialog(BuildContext context) {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💸 Sortie - Compte DÉPENSE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montantController,
              decoration: const InputDecoration(
                labelText: 'Montant (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (ex: Salaires, Internet...)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant != null && descriptionController.text.isNotEmpty) {
                try {
                  if (!context.mounted) return;
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await CompteSpecialService.instance.sortieDepense(
                    montant: montant,
                    description: descriptionController.text,
                    shopId: widget.shopId ?? authService.currentUser!.shopId!,
                    agentId: authService.currentUser?.id,
                    agentUsername: authService.currentUser?.username,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Sortie enregistrée')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showRetraitFraisDialog(BuildContext context) {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➖ Retrait Boss - Compte FRAIS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montantController,
              decoration: const InputDecoration(
                labelText: 'Montant (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant != null && descriptionController.text.isNotEmpty) {
                try {
                  if (!context.mounted) return;
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await CompteSpecialService.instance.retraitFrais(
                    montant: montant,
                    description: descriptionController.text,
                    shopId: widget.shopId ?? authService.currentUser!.shopId!,
                    agentId: authService.currentUser?.id,
                    agentUsername: authService.currentUser?.username,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Retrait enregistré')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Retrait'),
          ),
        ],
      ),
    );
  }

  // Méthode supprimée - remplacée par _showSortieDepenseDialog

  void _showTransactionDetails(BuildContext context, CompteSpecialModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaction.type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Montant', '\$${_numberFormat.format(transaction.montant)}'),
            _buildDetailRow('Description', transaction.description),
            _buildDetailRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateTransaction)),
            if (transaction.agentUsername != null)
              _buildDetailRow('Agent', transaction.agentUsername!),
            if (transaction.operationId != null)
              _buildDetailRow('Opération', '#${transaction.operationId}'),
          ],
        ),
        actions: [
          if (widget.isAdmin)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('⚠️ Confirmer la suppression'),
                    content: const Text('Voulez-vous vraiment supprimer cette transaction? Cette action est irréversible.'),
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
                if (confirm == true && context.mounted) {
                  // Supprimer en local
                  final success = await CompteSpecialService.instance.deleteTransaction(
                    transaction.id!,
                    shopId: _selectedShopId,
                  );
                  
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Transaction supprimée'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Recharger les données
                    _loadData();
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Erreur lors de la suppression'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
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
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _generatePdfFrais(BuildContext context) async {
    final service = CompteSpecialService.instance;
    final frais = service.getFrais(
      shopId: _selectedShopId,
      startDate: _startDate,
      endDate: _endDate,
    );

    // Trier par date croissante
    frais.sort((a, b) => a.dateTransaction.compareTo(b.dateTransaction));

    final pdf = pw.Document();
    
    // Calculer le solde cumulatif
    double solde = 0;
    final transactionsWithSolde = frais.map((t) {
      solde += t.montant;
      return {
        'date': DateFormat('dd/MM/yyyy HH:mm').format(t.dateTransaction),
        'type': t.typeTransaction.label,
        'description': t.description,
        'montant': t.montant,
        'solde': solde,
      };
    }).toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // En-tête moderne
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF10B981), PdfColor.fromInt(0xFF059669)],
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RAPPORT FRAIS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Mouvements du compte FRAIS',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '💰',
                    style: const pw.TextStyle(fontSize: 32),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Informations de période
          if (_startDate != null || _endDate != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF3F4F6),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Icon(const pw.IconData(0xe878), size: 16),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Période: ${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Début'} - ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Fin'}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 20),
          
          // Tableau moderne des transactions
          pw.Table(
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFE5E7EB),
              width: 1,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // En-tête du tableau
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF10B981),
                ),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Description'),
                  _buildTableHeader('Montant', align: pw.TextAlign.right),
                  _buildTableHeader('Solde', align: pw.TextAlign.right),
                ],
              ),
              // Lignes de données
              ...transactionsWithSolde.asMap().entries.map((entry) {
                final index = entry.key;
                final t = entry.value;
                final isEven = index % 2 == 0;
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9FAFB),
                  ),
                  children: [
                    _buildTableCell(t['date'] as String),
                    _buildTableCell(t['type'] as String),
                    _buildTableCell(t['description'] as String),
                    _buildTableCell(
                      '\$${_numberFormat.format(t['montant'])}',
                      align: pw.TextAlign.right,
                      color: (t['montant'] as double) >= 0 ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFEF4444),
                    ),
                    _buildTableCell(
                      '\$${_numberFormat.format(t['solde'])}',
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Résumé final
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF10B981), PdfColor.fromInt(0xFF059669)],
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SOLDE FINAL',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '\$${_numberFormat.format(solde)}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Pied de page
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor.fromInt(0xFF6B7280),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Méthodes helper pour les PDFs
  pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }

  Future<void> _generatePdfDepenses(BuildContext context) async {
    final service = CompteSpecialService.instance;
    final depenses = service.getDepenses(
      shopId: _selectedShopId,
      startDate: _startDate,
      endDate: _endDate,
    );

    // Trier par date croissante
    depenses.sort((a, b) => a.dateTransaction.compareTo(b.dateTransaction));

    final pdf = pw.Document();
    
    // Calculer le solde cumulatif
    double solde = 0;
    final transactionsWithSolde = depenses.map((t) {
      solde += t.montant;
      return {
        'date': DateFormat('dd/MM/yyyy HH:mm').format(t.dateTransaction),
        'type': t.typeTransaction.label,
        'description': t.description,
        'montant': t.montant,
        'solde': solde,
      };
    }).toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // En-tête moderne
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF3B82F6), PdfColor.fromInt(0xFF2563EB)],
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RAPPORT DÉPENSES',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Mouvements du compte DÉPENSE',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '💸',
                    style: const pw.TextStyle(fontSize: 32),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Informations de période
          if (_startDate != null || _endDate != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF3F4F6),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Icon(const pw.IconData(0xe878), size: 16),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Période: ${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Début'} - ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Fin'}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 20),
          
          // Tableau moderne des transactions
          pw.Table(
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFE5E7EB),
              width: 1,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // En-tête du tableau
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF3B82F6),
                ),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Description'),
                  _buildTableHeader('Montant', align: pw.TextAlign.right),
                  _buildTableHeader('Solde', align: pw.TextAlign.right),
                ],
              ),
              // Lignes de données
              ...transactionsWithSolde.asMap().entries.map((entry) {
                final index = entry.key;
                final t = entry.value;
                final isEven = index % 2 == 0;
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9FAFB),
                  ),
                  children: [
                    _buildTableCell(t['date'] as String),
                    _buildTableCell(t['type'] as String),
                    _buildTableCell(t['description'] as String),
                    _buildTableCell(
                      '\$${_numberFormat.format(t['montant'])}',
                      align: pw.TextAlign.right,
                      color: (t['montant'] as double) >= 0 ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFEF4444),
                    ),
                    _buildTableCell(
                      '\$${_numberFormat.format(t['solde'])}',
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Résumé final
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: solde >= 0
                    ? [const PdfColor.fromInt(0xFF3B82F6), const PdfColor.fromInt(0xFF2563EB)]
                    : [const PdfColor.fromInt(0xFFEF4444), const PdfColor.fromInt(0xFFDC2626)],
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SOLDE FINAL',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '\$${_numberFormat.format(solde)}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Pied de page
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor.fromInt(0xFF6B7280),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
