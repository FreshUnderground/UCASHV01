import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';

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
      final reportService = Provider.of<ReportService>(context, listen: false);
      
      if (widget.showAllShops && widget.shopId == null) {
        // Charger les rapports de tous les shops
        await _loadAllShopsReport(reportService);
      } else if (widget.shopId != null) {
        // Charger le rapport d'un shop spécifique
        final data = await reportService.generateMouvementsCaisseReport(
          shopId: widget.shopId!,
          startDate: widget.startDate,
          endDate: widget.endDate,
        );
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

  Future<void> _loadAllShopsReport(ReportService reportService) async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
    
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
      try {
        final shopReport = await reportService.generateMouvementsCaisseReport(
          shopId: shop.id!,
          startDate: widget.startDate,
          endDate: widget.endDate,
        );
        
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildMovementsTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final shop = _reportData!['shop'] as Map<String, dynamic>;
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Mvts de Caisse',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Shop: ${shop['designation']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (periode['debut'] != null && periode['fin'] != null)
              Text(
                'Période: ${_formatDate(DateTime.parse(periode['debut']))} - ${_formatDate(DateTime.parse(periode['fin']))}',
                style: TextStyle(color: Colors.grey[600]),
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
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Sorties',
                '${totaux['sorties'].toStringAsFixed(2)} USD',
                Icons.arrow_upward,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Solde Net',
                '${totaux['solde'].toStringAsFixed(2)} USD',
                Icons.account_balance_wallet,
                totaux['solde'] >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 16),
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
        
        const SizedBox(height: 16),
        
        // Répartition par mode de paiement
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répartition par Mode de Paiement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildModeCard('Cash', parMode['Cash'] ?? 0, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeCard('Airtel Money', parMode['AirtelMoney'] ?? 0, Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeCard('M-Pesa', parMode['MPesa'] ?? 0, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildModeCard('Orange Money', parMode['OrangeMoney'] ?? 0, Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
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

  Widget _buildModeCard(String mode, double montant, Color color) {
    // Icônes selon le mode de paiement
    IconData modeIcon;
    switch (mode) {
      case 'Cash':
        modeIcon = Icons.money;
        break;
      case 'Airtel Money':
        modeIcon = Icons.phone_android;
        break;
      case 'M-Pesa':
        modeIcon = Icons.account_balance_wallet;
        break;
      case 'Orange Money':
        modeIcon = Icons.payment;
        break;
      default:
        modeIcon = Icons.credit_card;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(modeIcon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            mode,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${montant.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTable() {
    final mouvements = _reportData!['mouvements'] as List<Map<String, dynamic>>;
    
    if (mouvements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun mouvement trouvé',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune opération n\'a été effectuée pour la période sélectionnée',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Détail des Mouvements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // TODO: Implémenter l'export
                  },
                  icon: const Icon(Icons.download),
                  tooltip: 'Exporter',
                ),
                IconButton(
                  onPressed: () {
                    // TODO: Implémenter l'impression
                  },
                  icon: const Icon(Icons.print),
                  tooltip: 'Imprimer',
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Date')),
                if (widget.showAllShops) const DataColumn(label: Text('Shop')),
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Client/Destinataire')),
                const DataColumn(label: Text('Agent')),
                const DataColumn(label: Text('Montant Brut')),
                const DataColumn(label: Text('Commission')),
                const DataColumn(label: Text('Montant Servi')),
                const DataColumn(label: Text('Mode')),
                const DataColumn(label: Text('Statut')),
              ],
              rows: mouvements.take(50).map((mouvement) => DataRow(
                cells: [
                  DataCell(Text(_formatDateTime(mouvement['date'] as DateTime))),
                  if (widget.showAllShops) DataCell(Text(mouvement['shopNom'] ?? '')),
                  DataCell(_buildTypeChip(mouvement['type'])),
                  DataCell(Text(mouvement['destinataire'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(mouvement['agent'])),
                  DataCell(Text('${mouvement['montantBrut'].toStringAsFixed(2)} USD')),
                  DataCell(Text(
                    mouvement['commission'] > 0 ? '${mouvement['commission'].toStringAsFixed(2)} USD' : '-',
                    style: TextStyle(color: mouvement['commission'] > 0 ? Colors.orange[700] : Colors.grey),
                  )),
                  DataCell(Text(
                    '${mouvement['montantNet'].toStringAsFixed(2)} USD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: mouvement['typeDirection'] == 'entree' ? Colors.green[700] : Colors.red[700],
                    ),
                  )),
                  DataCell(_buildModeChip(mouvement['mode'])),
                  DataCell(_buildStatusChip(mouvement['statut'])),
                ],
              )).toList(),
            ),
          ),
          if (mouvements.length > 50)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Affichage des 50 premiers mouvements sur ${mouvements.length} au total',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: Colors.blue[700],
          fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        statut,
        style: TextStyle(
          color: color,
          fontSize: 12,
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
