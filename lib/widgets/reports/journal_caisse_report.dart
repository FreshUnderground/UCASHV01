import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/journal_caisse_model.dart';
import '../../models/shop_model.dart';
import '../../models/operation_model.dart';
import '../../services/local_db.dart';
import '../../services/shop_service.dart';

class JournalCaisseReport extends StatefulWidget {
  final int shopId;
  final DateTime? startDate;
  final DateTime? endDate;

  const JournalCaisseReport({
    super.key,
    required this.shopId,
    this.startDate,
    this.endDate,
  });

  @override
  State<JournalCaisseReport> createState() => _JournalCaisseReportState();
}

class _JournalCaisseReportState extends State<JournalCaisseReport> {
  List<JournalCaisseModel> _journalEntries = [];
  ShopModel? _shop;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger le shop
      _shop = await LocalDB.instance.getShopById(widget.shopId);
      
      // Charger les entrées du journal
      var entries = await LocalDB.instance.getJournalEntriesByShop(widget.shopId);
      
      // Filtrer par date si nécessaire
      if (widget.startDate != null) {
        entries = entries.where((e) => e.dateAction.isAfter(widget.startDate!)).toList();
      }
      if (widget.endDate != null) {
        entries = entries.where((e) => e.dateAction.isBefore(widget.endDate!.add(const Duration(days: 1)))).toList();
      }
      
      // Trier par date
      entries.sort((a, b) => a.dateAction.compareTo(b.dateAction));
      
      setState(() {
        _journalEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement rapport: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final padding = isMobile ? 16.0 : 24.0;

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

    if (_shop == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text('Shop non trouvé', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 20 : 24),
          _buildSummaryCards(isMobile),
          SizedBox(height: isMobile ? 20 : 24),
          _buildMovementsByMode(isMobile),
          SizedBox(height: isMobile ? 20 : 24),
          _buildJournalEntries(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📒 Journal de Caisse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shop!.designation,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.startDate != null || widget.endDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '📅 ${widget.startDate != null ? _formatDate(widget.startDate!) : 'Début'} → ${widget.endDate != null ? _formatDate(widget.endDate!) : "Aujourd'hui"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isMobile) {
    // Calculer les totaux globaux
    final totalEntrees = _journalEntries
        .where((e) => e.type == TypeMouvement.entree)
        .fold<double>(0, (sum, e) => sum + e.montant);
    final totalSorties = _journalEntries
        .where((e) => e.type == TypeMouvement.sortie)
        .fold<double>(0, (sum, e) => sum + e.montant);
    final soldeNet = totalEntrees - totalSorties;

    if (isMobile) {
      return Column(
        children: [
          _buildSummaryCard(
            '💰 Total Entrées',
            '${totalEntrees.toStringAsFixed(2)} USD',
            Icons.arrow_downward,
            Colors.green,
            isMobile,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            '💸 Total Sorties',
            '${totalSorties.toStringAsFixed(2)} USD',
            Icons.arrow_upward,
            Colors.red,
            isMobile,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            '📊 Solde Net',
            '${soldeNet.toStringAsFixed(2)} USD',
            Icons.account_balance_wallet,
            soldeNet >= 0 ? Colors.blue : Colors.orange,
            isMobile,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            '📝 Opérations',
            '${_journalEntries.length}',
            Icons.list_alt,
            Colors.purple,
            isMobile,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            '💰 Total Entrées',
            '${totalEntrees.toStringAsFixed(2)} USD',
            Icons.arrow_downward,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '💸 Total Sorties',
            '${totalSorties.toStringAsFixed(2)} USD',
            Icons.arrow_upward,
            Colors.red,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '📊 Solde Net',
            '${soldeNet.toStringAsFixed(2)} USD',
            Icons.account_balance_wallet,
            soldeNet >= 0 ? Colors.blue : Colors.orange,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            '📝 Opérations',
            '${_journalEntries.length}',
            Icons.list_alt,
            Colors.purple,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
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



  Widget _buildMovementsByMode(bool isMobile) {
    // Calculer les totaux par mode
    final Map<ModePaiement, Map<String, double>> totauxParMode = {};
    
    for (var mode in ModePaiement.values) {
      final entrees = _journalEntries
          .where((e) => e.mode == mode && e.type == TypeMouvement.entree)
          .fold<double>(0, (sum, e) => sum + e.montant);
      final sorties = _journalEntries
          .where((e) => e.mode == mode && e.type == TypeMouvement.sortie)
          .fold<double>(0, (sum, e) => sum + e.montant);
      
      totauxParMode[mode] = {
        'entrees': entrees,
        'sorties': sorties,
        'solde': entrees - sorties,
      };
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 8),
                Text(
                  '💳 Mouvements par Mode de Paiement',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ...totauxParMode.entries.map((entry) {
              return Column(
                children: [
                  _buildModeRow(entry.key, entry.value, isMobile),
                  if (entry.key != ModePaiement.values.last) 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModeRow(ModePaiement mode, Map<String, double> totaux, bool isMobile) {
    final entrees = totaux['entrees']!;
    final sorties = totaux['sorties']!;
    final solde = totaux['solde']!;
    
    // Icône selon le mode
    IconData modeIcon;
    Color modeColor;
    switch (mode) {
      case ModePaiement.cash:
        modeIcon = Icons.money;
        modeColor = Colors.green;
        break;
      case ModePaiement.airtelMoney:
        modeIcon = Icons.phone_android;
        modeColor = Colors.red;
        break;
      case ModePaiement.mPesa:
        modeIcon = Icons.account_balance_wallet;
        modeColor = Colors.green[700]!;
        break;
      case ModePaiement.orangeMoney:
        modeIcon = Icons.phone_iphone;
        modeColor = Colors.orange;
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(modeIcon, color: modeColor, size: 20),
            const SizedBox(width: 8),
            Text(
              _getModeLabel(mode),
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: modeColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (isMobile)
          Column(
            children: [
              _buildStatChip('✅ Entrées', entrees, Colors.green),
              const SizedBox(height: 8),
              _buildStatChip('❌ Sorties', sorties, Colors.red),
              const SizedBox(height: 8),
              _buildStatChip('📊 Solde', solde, solde >= 0 ? Colors.blue : Colors.orange),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildStatChip('✅ Entrées', entrees, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip('❌ Sorties', sorties, Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip('📊 Solde', solde, solde >= 0 ? Colors.blue : Colors.orange),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} \$',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalEntries(bool isMobile) {
    if (_journalEntries.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun mouvement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune opération enregistrée pour cette période',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculer le solde cumulé
    double soldeCumule = 0;
    final entriesWithBalance = _journalEntries.map((entry) {
      soldeCumule += entry.type == TypeMouvement.entree ? entry.montant : -entry.montant;
      return {
        'entry': entry,
        'balance': soldeCumule,
      };
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📋 Détail des Mouvements',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_journalEntries.length} ops',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Table header (desktop only)
            if (!isMobile) _buildTableHeader(),
            
            // Entries
            ...entriesWithBalance.map((item) {
              final entry = item['entry'] as JournalCaisseModel;
              final balance = item['balance'] as double;
              return _buildEntryRow(entry, balance, isMobile);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Expanded(flex: 3, child: Text('Libellé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Expanded(flex: 2, child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Expanded(flex: 2, child: Text('Entrée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Expanded(flex: 2, child: Text('Sortie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Expanded(flex: 2, child: Text('Solde', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildEntryRow(JournalCaisseModel entry, double balance, bool isMobile) {
    final isEntree = entry.type == TypeMouvement.entree;
    
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(entry.dateAction),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEntree ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isEntree ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.libelle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              entry.modeLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  '${isEntree ? '+' : '-'}${entry.montant.toStringAsFixed(2)} USD',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isEntree ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solde:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  '${balance.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
            child: Text(
              entry.modeLabel,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isEntree ? '${entry.montant.toStringAsFixed(2)}' : '-',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              !isEntree ? '${entry.montant.toStringAsFixed(2)}' : '-',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              balance.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getModeLabel(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'M-Pesa';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }
}
