import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/compte_special_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/document_header_service.dart';
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
  bool _showFilters = false; // MODIFIÉ: Masquer les filtres par défaut

  @override
  void initState() {
    super.initState();
    // MODIFIÉ: Ne pas initialiser les dates par défaut (afficher toutes les données)
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Logique d'initialisation du shopId:
      // - Si widget.shopId est fourni, l'utiliser (cas admin qui navigue)
      // - Sinon, utiliser le shop de l'utilisateur connecté (cas agent)
      // - Pour l'admin sans shopId spécifié, laisser null pour voir tous les shops
      if (widget.shopId != null) {
        _selectedShopId = widget.shopId;
      } else if (!widget.isAdmin) {
        // Agent: TOUJOURS utiliser son propre shopId
        _selectedShopId = authService.currentUser?.shopId;
      } else {
        // Admin: null par défaut (tous les shops)
        _selectedShopId = null;
      }
      
      debugPrint('🏪 ComptesSpeciauxWidget initialisé:');
      debugPrint('   isAdmin: ${widget.isAdmin}');
      debugPrint('   shopId sélectionné: $_selectedShopId');
      debugPrint('   User shopId: ${authService.currentUser?.shopId}');
      debugPrint('   Période par défaut: ${_startDate?.toString().split(" ")[0]} au ${_endDate?.toString().split(" ")[0]}');
      
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
        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('$_selectedShopId-$_startDate-$_endDate'), // NOUVEAU: Force rebuild quand les filtres changent
          future: service.getStatistics(
            shopId: _selectedShopId,
            startDate: _startDate,
            endDate: _endDate,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final stats = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                
                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isMedium ? 5 : 3),
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
                        
                        // Cartes de résumé - Toujours visibles
                        _buildSummaryCards(stats, isWide, isMedium),
                        const SizedBox(height: 32),
                        
                        // Boutons d'action - Responsive
                        _buildActionButtons(context, isWide, isMedium),
                        const SizedBox(height: 24),
                        
                        // Liste des transactions avec tabs
                        _buildTransactionsList(service, isWide, stats),
                      ],
                    ),
                  ),
                );
              },
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
            padding: const EdgeInsets.all(4),
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
        padding: const EdgeInsets.all(4),
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
                  _loadData(); // Recharger les données après changement
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
                  _loadData(); // Recharger les données après changement
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
                _loadData(); // Recharger les données après réinitialisation
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
                _loadData(); // Recharger les données après changement
              },
            ),
            const SizedBox(height: 8),
            _buildDatePicker(
              label: 'Date de fin',
              date: _endDate,
              onDateSelected: (date) {
                setState(() => _endDate = date);
                _loadData(); // Recharger les données après changement
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
                  _loadData(); // Recharger les données après réinitialisation
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
                amount: stats['solde_frais_jour'] ?? stats['solde_frais'], // MODIFIÉ: Utiliser solde du jour
                count: stats['nombre_commissions'], // MODIFIÉ: Nombre de transferts servis
                icon: Icons.trending_up,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                details: [
                  {'label': 'Frais Antérieur', 'value': stats['frais_anterieur'] ?? 0.0},
                  {'label': '+ Frais encaissés', 'value': stats['frais_encaisses_jour'] ?? stats['commissions_auto']},
                  {'label': '- Sortie Frais', 'value': stats['sortie_frais_jour'] ?? stats['retraits_frais']},
                ],
                onTap: null, // TODO: Ajouter détails plus tard
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
                amount: stats['solde_frais_jour'] ?? stats['solde_frais'], // MODIFIÉ: Utiliser solde du jour
                count: stats['nombre_commissions'], // MODIFIÉ: Nombre de transferts servis
                icon: Icons.trending_up,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                details: [
                  {'label': 'Frais Antérieur', 'value': stats['frais_anterieur'] ?? 0.0},
                  {'label': '+ Frais encaissés', 'value': stats['frais_encaisses_jour'] ?? stats['commissions_auto']},
                  {'label': '- Sortie Frais', 'value': stats['sortie_frais_jour'] ?? stats['retraits_frais']},
                ],
                onTap: null, // TODO: Ajouter détails plus tard
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
    VoidCallback? onTap, // NOUVEAU: Callback pour afficher détails
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
        'label': 'Rapp. Frais',
        'icon': Icons.picture_as_pdf,
        'gradient': const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        'onPressed': () => _generatePdfFrais(context),
      },
      // PDF DÉPENSES
      {
        'label': 'Rapp. Dépenses',
        'icon': Icons.picture_as_pdf,
        'gradient': const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
        'onPressed': () => _generatePdfDepenses(context),
      },
      // PDF PAR ROUTE (admin uniquement)
      if (widget.isAdmin)
        {
          'label': 'Frais/Route',
          'icon': Icons.route,
          'gradient': const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          'onPressed': () => _generatePdfFraisParRoute(context),
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

  Widget _buildTransactionsList(CompteSpecialService service, bool isWide, Map<String, dynamic> stats) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: DefaultTabController(
        length: widget.isAdmin ? 5 : 3, // 5 tabs pour admin, 3 pour les autres
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                labelColor: const Color(0xFFDC2626),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFDC2626),
                indicatorWeight: 3,
                isScrollable: widget.isAdmin, // Scrollable si 5 tabs
                tabs: [
                  const Tab(icon: Icon(Icons.list), text: 'Toutes'),
                  const Tab(icon: Icon(Icons.trending_up), text: 'FRAIS'),
                  const Tab(icon: Icon(Icons.receipt_long), text: 'DÉPENSE'),
                  if (widget.isAdmin)
                    const Tab(icon: Icon(Icons.route), text: 'Par Route'),
                  if (widget.isAdmin)
                    const Tab(icon: Icon(Icons.store), text: 'Par Shop'),
                ],
              ),
            ),
            // Fix the layout issue by constraining the height
            SizedBox(
              height: 400, // Set a fixed height to prevent layout issues
              child: TabBarView(
                children: [
                  _buildMixedTransactionsView(service, stats, isWide), // MODIFIÉ: Vue mixte avec transferts servis
                  _buildFraisOperationsView(stats, isWide), // MODIFIÉ: Afficher transferts servis
                  _buildTransactionsListView(service.getDepenses(
                    shopId: _selectedShopId,
                    startDate: _startDate,
                    endDate: _endDate,
                  ), isWide),
                  if (widget.isAdmin)
                    _buildFraisParRouteView(service, isWide),
                  if (widget.isAdmin)
                    _buildFraisParShopView(service, isWide),
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
                        maxLines: 3, // Afficher jusqu'à 3 lignes
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
                    const SizedBox(height: 4),
                    // Badge du type de compte
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: transaction.type == TypeCompteSpecial.FRAIS
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        transaction.type == TypeCompteSpecial.FRAIS ? 'FRAIS' : 'DÉPENSE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: transaction.type == TypeCompteSpecial.FRAIS
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                        ),
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

  /// NOUVEAU: Afficher les opérations (transferts servis) qui ont généré les frais
  Widget _buildFraisOperationsView(Map<String, dynamic> stats, bool isWide) {
    final operations = stats['operations_frais'] as List<dynamic>? ?? [];
    
    if (operations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Aucun transfert servi',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Les frais s\'afficheront ici quand vous servez des transferts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: operations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final operation = operations[index] as Map<String, dynamic>;
        final commission = operation['commission'] as double;
        final date = operation['date'] as DateTime;
        final type = operation['type'] as String;
        
        // Convertir le type en label lisible
        String typeLabel;
        switch (type) {
          case 'transfertNational':
            typeLabel = 'Transfert National';
            break;
          case 'transfertInternationalEntrant':
            typeLabel = 'Intl. Entrant';
            break;
          case 'transfertInternationalSortant':
            typeLabel = 'Intl. Sortant';
            break;
          default:
            typeLabel = type;
        }
        
        return Container(
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              
              // Détails
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel, // MODIFIÉ: Afficher le label lisible
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Montant
              Text(
                '+${_numberFormat.format(commission)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// NOUVEAU: Vue mixte avec transactions de comptes spéciaux ET transferts servis
  Widget _buildMixedTransactionsView(CompteSpecialService service, Map<String, dynamic> stats, bool isWide) {
    debugPrint('🔍 _buildMixedTransactionsView - stats keys: ${stats.keys}');
    debugPrint('   operations_frais: ${stats['operations_frais']}');
    
    // Récupérer les transactions filtrées
    final transactions = service.transactions.where((t) {
      // Filtre par shop
      if (_selectedShopId != null && t.shopId != _selectedShopId) {
        return false;
      }
      
      // Filtre par date de début
      if (_startDate != null) {
        final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (t.dateTransaction.isBefore(startOfDay)) {
          return false;
        }
      }
      
      // Filtre par date de fin
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (t.dateTransaction.isAfter(endOfDay)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Récupérer les opérations de transferts
    final operations = stats['operations_frais'] as List<dynamic>? ?? [];
    
    if (transactions.isEmpty && operations.isEmpty) {
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
    
    // Créer une liste mixte
    final mixedList = <Map<String, dynamic>>[];
    
    // Ajouter les transactions
    for (var t in transactions) {
      mixedList.add({
        'type': 'transaction',
        'data': t,
        'date': t.dateTransaction,
      });
    }
    
    // Ajouter les opérations
    for (var op in operations) {
      final opMap = op as Map<String, dynamic>;
      mixedList.add({
        'type': 'operation',
        'data': opMap,
        'date': opMap['date'] as DateTime,
      });
    }
    
    // Trier par date décroissante
    mixedList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: mixedList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = mixedList[index];
        
        if (item['type'] == 'transaction') {
          // Afficher une transaction de compte spécial
          final transaction = item['data'] as CompteSpecialModel;
          final isPositive = transaction.montant >= 0;
          
          return InkWell(
            onTap: widget.isAdmin ? () => _showTransactionDetails(context, transaction) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
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
                  Container(
                    padding: const EdgeInsets.all(3),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateTransaction),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${_numberFormat.format(transaction.montant)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Afficher un transfert servi
          final operation = item['data'] as Map<String, dynamic>;
          final commission = operation['commission'] as double;
          final date = operation['date'] as DateTime;
          final type = operation['type'] as String;
          
          String typeLabel;
          switch (type) {
            case 'transfertNational':
              typeLabel = 'Transfert National';
              break;
            case 'transfertInternationalEntrant':
              typeLabel = 'Intl. Entrant';
              break;
            case 'transfertInternationalSortant':
              typeLabel = 'Intl. Sortant';
              break;
            default:
              typeLabel = type;
          }
          
          return Container(
            padding: const EdgeInsets.all(4),
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
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${_numberFormat.format(commission)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildTransactionsListViewAsync(Future<List<CompteSpecialModel>> transactionsFuture, bool isWide) {
    return FutureBuilder<List<CompteSpecialModel>>(
      future: transactionsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildTransactionsListView(snapshot.data!, isWide);
      },
    );
  }

  Widget _buildFraisParRouteView(CompteSpecialService service, bool isWide) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getFraisParRoute(
        shopId: _selectedShopId,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fraisParRoute = snapshot.data!;
        if (fraisParRoute.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune route trouvée',
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
          padding: const EdgeInsets.all(3),
          itemCount: fraisParRoute.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = fraisParRoute.entries.elementAt(index);
            final route = entry.key;
            final data = entry.value;
            final montant = data['montant'] as double;
            final count = data['count'] as int;
            final details = data['details'] as List;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade200, width: 1.5),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.route, color: Colors.white, size: 24),
                  ),
                  title: Text(
                    route,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$count transfert(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_numberFormat.format(montant)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const Text(
                        'Frais total',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Détails des transferts:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...details.map((detail) {
                            final destinataire = detail['destinataire'] as String;
                            final montantNet = detail['montantNet'] as double;
                            final commission = detail['commission'] as double;
                            final date = detail['date'] as DateTime;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          destinataire,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${montantNet.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Frais: \$${commission.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFraisParShopView(CompteSpecialService service, bool isWide) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: service.getFraisParShopDestination(
        shopId: _selectedShopId,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fraisParShop = snapshot.data!;
        if (fraisParShop.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun frais encaissé',
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
          padding: const EdgeInsets.all(4),
          itemCount: fraisParShop.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = fraisParShop.entries.elementAt(index);
            final shopName = entry.key;
            final data = entry.value;
            final montant = data['montant'] as double;
            final count = data['count'] as int;
            final details = data['details'] as List;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade200, width: 1.5),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 24),
                  ),
                  title: Text(
                    shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$count transfert(s) servi(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_numberFormat.format(montant)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const Text(
                        'Frais encaissés',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Détails des transferts:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...details.map((detail) {
                            final destinataire = detail['destinataire'] as String;
                            final montantNet = detail['montantNet'] as double;
                            final commission = detail['commission'] as double;
                            final date = detail['date'] as DateTime;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          destinataire,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${montantNet.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Frais: \$${commission.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

  void _showSortieDepenseDialog(BuildContext context) async {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    
    // NOUVEAU: Récupérer le solde disponible
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = widget.shopId ?? authService.currentUser?.shopId;
    
    debugPrint('\n🔍 Chargement dialogue Sortie DÉPENSE');
    debugPrint('   Shop ID: $shopId');
    
    final stats = await CompteSpecialService.instance.getStatistics(shopId: shopId);
    final soldeDisponible = stats['solde_depense'] ?? 0.0;
    
    debugPrint('   Stats reçues:');
    debugPrint('   - solde_depense: ${stats['solde_depense']}');
    debugPrint('   - depots_boss: ${stats['depots_boss']}');
    debugPrint('   - sorties: ${stats['sorties']}');
    debugPrint('   - Solde affiché: \$${soldeDisponible.toStringAsFixed(2)}');
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💸 Sortie - Compte DÉPENSE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NOUVEAU: Afficher le solde disponible
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solde disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '\$${_numberFormat.format(soldeDisponible)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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

  void _showRetraitFraisDialog(BuildContext context) async {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    
    // NOUVEAU: Récupérer le solde disponible
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = widget.shopId ?? authService.currentUser?.shopId;
    
    debugPrint('\n🔍 Chargement dialogue Retrait FRAIS');
    debugPrint('   Shop ID: $shopId');
    
    final stats = await CompteSpecialService.instance.getStatistics(shopId: shopId);
    
    // MODIFIÉ: Utiliser la même logique que retraitFrais()
    final soldeDisponible = stats['solde_frais_jour'] ?? stats['solde_frais'] ?? 0.0;
    
    debugPrint('   Stats reçues:');
    debugPrint('   - solde_frais_jour: ${stats['solde_frais_jour']}');
    debugPrint('   - solde_frais: ${stats['solde_frais']}');
    debugPrint('   - frais_encaisses_jour: ${stats['frais_encaisses_jour']}');
    debugPrint('   - Solde affiché: \$${soldeDisponible.toStringAsFixed(2)}');
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➖ Retrait Boss - Compte FRAIS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NOUVEAU: Afficher le solde disponible
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solde disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '\$${_numberFormat.format(soldeDisponible)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
    try {
      final service = CompteSpecialService.instance;
      
      // Vérifier et définir le shopId
      final authService = Provider.of<AuthService>(context, listen: false);
      debugPrint('🔍 DEBUG PDF FRAIS - Auth Info:');
      debugPrint('   currentUser: ${authService.currentUser}');
      debugPrint('   currentUser.shopId: ${authService.currentUser?.shopId}');
      debugPrint('   _selectedShopId: $_selectedShopId');
      
      final effectiveShopId = _selectedShopId ?? authService.currentUser?.shopId;
      
      debugPrint('   effectiveShopId: $effectiveShopId (type: ${effectiveShopId.runtimeType})');
      
      if (effectiveShopId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Veuillez sélectionner un shop'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Si les dates sont null, utiliser la date du jour par défaut
      final now = DateTime.now();
      final defaultStartDate = DateTime(now.year, now.month, now.day);
      final defaultEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final effectiveStartDate = _startDate ?? defaultStartDate;
      final effectiveEndDate = _endDate ?? defaultEndDate;
      
      debugPrint('🔄 Début génération PDF FRAIS');
      debugPrint('   NOW: $now');
      debugPrint('   Shop ID: $effectiveShopId (original: $_selectedShopId)');
      debugPrint('   Date début effective: $effectiveStartDate');
      debugPrint('   Date fin effective: $effectiveEndDate');
      debugPrint('   Date actuelle: ${DateTime.now()}');
      
      // CRITIQUE: Recharger les transactions pour s'assurer que les données sont à jour
      await service.loadTransactions(shopId: effectiveShopId);
      debugPrint('   ✅ Transactions rechargées');
      
      // Vérifier d'abord les statistiques pour le jour
      final stats = await service.getStatistics(
        shopId: effectiveShopId,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );
      debugPrint('   📊 Stats pour la période:');
      debugPrint('      - Solde Frais Jour: ${stats['solde_frais_jour']}');
      debugPrint('      - Frais Antérieur: ${stats['frais_anterieur']}');
      debugPrint('      - Frais Encaissés: ${stats['frais_encaisses_jour']}');
      debugPrint('      - Sortie Frais: ${stats['sortie_frais_jour']}');
      
      // getFraisAsync combine _transactions (retraits) + operations (commissions)
      final frais = await service.getFraisAsync(
        shopId: effectiveShopId,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );
      
      debugPrint('   📊 Nombre de frais récupérés: ${frais.length}');
      
      if (frais.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Aucune transaction FRAIS trouvée pour cette période'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Trier par date croissante
      frais.sort((a, b) => a.dateTransaction.compareTo(b.dateTransaction));
      debugPrint('   ✅ Tri effectué');

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
      
      debugPrint('   ✅ Soldes cumulatifs calculés');
      
      // Utiliser les mêmes statistiques que l'UI pour cohérence
      final totalEntrees = stats['frais_encaisses_jour'] ?? stats['commissions_auto'] ?? 0.0;
      final totalSorties = stats['sortie_frais_jour'] ?? stats['retraits_frais'] ?? 0.0;
      final soldeFinal = stats['solde_frais_jour'] ?? stats['solde_frais'] ?? 0.0;
      
      debugPrint('   📊 Stats - Entrées: $totalEntrees, Sorties: $totalSorties, Solde: $soldeFinal');
      
      // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
      final headerService = DocumentHeaderService();
      await headerService.initialize();
      final header = headerService.getHeaderOrDefault();
      
      // Générer le PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) => [
            // EN-TÊTE MODERNE
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColor.fromInt(0xFF10B981), PdfColor.fromInt(0xFF059669)],
                ),
                borderRadius: pw.BorderRadius.circular(12),
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
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          if (header.companySlogan?.isNotEmpty ?? false)
                            pw.Text(
                              header.companySlogan!,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.white,
                              ),
                            ),
                          if (header.address?.isNotEmpty ?? false)
                            pw.Text(
                              header.address!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                          if (header.phone?.isNotEmpty ?? false)
                            pw.Text(
                              header.phone!,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'RAPPORT COMPTE FRAIS',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Frais encaissés sur transferts servis',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(
                              '${frais.length}',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // INFORMATIONS PÉRIODE
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Icon(
                        const pw.IconData(0xe8df),
                        size: 16,
                        color: PdfColors.grey700,
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'Période: ${DateFormat('dd/MM/yyyy').format(effectiveStartDate)} - ${DateFormat('dd/MM/yyyy').format(effectiveEndDate)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // RÉSUMÉ FINANCIER
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildStatCard(
                    'ENTRÉES',
                    '\$${_numberFormat.format(totalEntrees)}',
                    const PdfColor.fromInt(0xFF10B981),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildStatCard(
                    'SORTIES',
                    '\$${_numberFormat.format(totalSorties)}',
                    const PdfColor.fromInt(0xFFEF4444),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildStatCard(
                    'SOLDE',
                    '\$${_numberFormat.format(soldeFinal)}',
                    const PdfColor.fromInt(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // TABLEAU DES TRANSACTIONS
            pw.Text(
              'DÉTAIL DES TRANSACTIONS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(4),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // En-tête
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
                ...transactionsWithSolde.map((t) {
                  final montant = t['montant'] as double;
                  final isSortie = montant < 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: transactionsWithSolde.indexOf(t).isEven 
                          ? PdfColors.white 
                          : PdfColors.grey50,
                    ),
                    children: [
                      _buildTableCell(t['date'] as String),
                      _buildTableCell(t['type'] as String),
                      _buildTableCell(
                        t['description'] as String,
                        fontSize: 8,
                      ),
                      _buildTableCell(
                        isSortie 
                            ? '-\$${_numberFormat.format(montant.abs())}'
                            : '\$${_numberFormat.format(montant)}',
                        align: pw.TextAlign.right,
                        color: isSortie 
                            ? const PdfColor.fromInt(0xFFEF4444) 
                            : const PdfColor.fromInt(0xFF10B981),
                        bold: true,
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
            
            // PIED DE PAGE
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${frais.length} transaction(s)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'UCASH - Rapport Frais',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      
      debugPrint('   ✅ PDF généré avec succès');
      
      // Afficher le PDF dans un dialog avec PdfPreview
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: PdfPreview(
                build: (format) => pdf.save(),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: 'Rapport_Frais_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
              ),
            ),
          ),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF généré avec succès: ${frais.length} transactions'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur génération PDF FRAIS: $e');
      debugPrint('   Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Méthodes helper pour les PDFs
  pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
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
    double fontSize = 9,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }
  
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.9),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: color.shade(-0.3),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfDepenses(BuildContext context) async {
    final service = CompteSpecialService.instance;
    
    // Vérifier et définir le shopId
    final authService = Provider.of<AuthService>(context, listen: false);
    final effectiveShopId = _selectedShopId ?? authService.currentUser?.shopId;
    
    if (effectiveShopId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Veuillez sélectionner un shop'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Si les dates sont null, utiliser la date du jour par défaut
    final now = DateTime.now();
    final defaultStartDate = DateTime(now.year, now.month, now.day);
    final defaultEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final effectiveStartDate = _startDate ?? defaultStartDate;
    final effectiveEndDate = _endDate ?? defaultEndDate;
    
    // CRITIQUE: Recharger les transactions pour s'assurer que les données sont à jour
    await service.loadTransactions(shopId: effectiveShopId);
    
    final depenses = service.getDepenses(
      shopId: effectiveShopId,
      startDate: effectiveStartDate,
      endDate: effectiveEndDate,
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
        margin: const pw.EdgeInsets.all(10),
        build: (context) => [
          // En-tête moderne
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
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
                  padding: const pw.EdgeInsets.all(4),
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
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF3F4F6),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Icon(const pw.IconData(0xe878), size: 16),
                pw.SizedBox(width: 8),
                pw.Text(
                  'Période: ${DateFormat('dd/MM/yyyy').format(effectiveStartDate)} - ${DateFormat('dd/MM/yyyy').format(effectiveEndDate)}',
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
            padding: const pw.EdgeInsets.all(4),
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

    // Afficher la prévisualisation dans un dialog avec PdfPreview
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: PdfPreview(
              build: (format) => pdf.save(),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: 'Rapport_Depenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _generatePdfFraisParRoute(BuildContext context) async {
    final service = CompteSpecialService.instance;
    final fraisParRoute = await service.getFraisParRoute(
      shopId: _selectedShopId,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (fraisParRoute.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Aucune route trouvée')),
        );
      }
      return;
    }

    final pdf = pw.Document();
    
    // Calculer le total global
    double totalGlobal = 0;
    int totalTransferts = 0;
    for (final data in fraisParRoute.values) {
      totalGlobal += data['montant'] as double;
      totalTransferts += data['count'] as int;
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (context) => [
          // En-tête moderne
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
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
                      'RAPPORT FRAIS PAR ROUTE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Routes de transfert et frais encaissés',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '🛣️',
                    style: const pw.TextStyle(fontSize: 28),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Informations de période
          if (_startDate != null || _endDate != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
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
          
          // Résumé global
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFD1FAE5),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFF10B981), width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      '${fraisParRoute.length}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF059669),
                      ),
                    ),
                    pw.Text(
                      'Routes',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      '$totalTransferts',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF059669),
                      ),
                    ),
                    pw.Text(
                      'Transferts',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      '\$${_numberFormat.format(totalGlobal)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF059669),
                      ),
                    ),
                    pw.Text(
                      'Total Frais',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Liste des routes avec détails
          ...fraisParRoute.entries.map((entry) {
            final route = entry.key;
            final data = entry.value;
            final montant = data['montant'] as double;
            final count = data['count'] as int;
            final details = data['details'] as List;
            
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: const PdfColor.fromInt(0xFF10B981), width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // En-tête de la route
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF10B981),
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(7),
                        topRight: pw.Radius.circular(7),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                route,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '$count transfert(s)',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '\$${_numberFormat.format(montant)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Détails des transferts
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    color: const PdfColor.fromInt(0xFFF0FDF4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Détails:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Table(
                          border: pw.TableBorder.all(
                            color: const PdfColor.fromInt(0xFFD1FAE5),
                            width: 0.5,
                          ),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(3),
                            1: const pw.FlexColumnWidth(2),
                            2: const pw.FlexColumnWidth(1.5),
                            3: const pw.FlexColumnWidth(1.5),
                          },
                          children: [
                            // En-tête du tableau
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFFD1FAE5),
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    'Destinataire',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    'Date',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    'Montant',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    'Frais',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            // Lignes de données
                            ...details.map((detail) {
                              final destinataire = detail['destinataire'] as String;
                              final montantNet = detail['montantNet'] as double;
                              final commission = detail['commission'] as double;
                              final date = detail['date'] as DateTime;
                              
                              return pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      destinataire,
                                      style: const pw.TextStyle(fontSize: 8),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      DateFormat('dd/MM HH:mm').format(date),
                                      style: const pw.TextStyle(fontSize: 8),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      '\$${montantNet.toStringAsFixed(2)}',
                                      style: const pw.TextStyle(fontSize: 8),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      '\$${commission.toStringAsFixed(2)}',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: const PdfColor.fromInt(0xFF10B981),
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          
          pw.SizedBox(height: 20),
          
          // Total final
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
                  'TOTAL FRAIS',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '\$${_numberFormat.format(totalGlobal)}',
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
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );

    // Afficher la prévisualisation dans un dialog avec PdfPreview
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: PdfPreview(
              build: (format) => pdf.save(),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: 'Rapport_Frais_Par_Route_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      );
    }
  }
}
