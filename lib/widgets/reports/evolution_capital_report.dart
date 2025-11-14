import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';
import '../../services/shop_service.dart';

class EvolutionCapitalReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showAllShops;

  const EvolutionCapitalReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
    this.showAllShops = false,
  });

  @override
  State<EvolutionCapitalReport> createState() => _EvolutionCapitalReportState();
}

class _EvolutionCapitalReportState extends State<EvolutionCapitalReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(EvolutionCapitalReport oldWidget) {
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
        await _loadAllShopsCapital(reportService);
      } else if (widget.shopId != null) {
        final data = await reportService.generateEvolutionCapitalReport(
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

  Future<void> _loadAllShopsCapital(ReportService reportService) async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
    
    final allShops = shopService.shops;
    final shopsData = <Map<String, dynamic>>[];
    double totalCapital = 0;
    double totalCreances = 0;
    double totalDettes = 0;

    for (final shop in allShops) {
      try {
        final shopReport = await reportService.generateEvolutionCapitalReport(
          shopId: shop.id!,
          startDate: widget.startDate,
          endDate: widget.endDate,
        );
        
        final capital = shopReport['capital'] as Map<String, dynamic>;
        final creancesEtDettes = shopReport['creancesEtDettes'] as Map<String, dynamic>;
        
        shopsData.add({
          'shop': shopReport['shop'],
          'capital': capital,
          'creancesEtDettes': creancesEtDettes,
          'capitalNet': shopReport['capitalNet'],
        });
        
        totalCapital += capital['total'] as double;
        totalCreances += creancesEtDettes['creances'] as double;
        totalDettes += creancesEtDettes['dettes'] as double;
      } catch (e) {
        debugPrint('Erreur pour le shop ${shop.designation}: $e');
      }
    }

    setState(() {
      _reportData = {
        'isGlobal': true,
        'shops': shopsData,
        'totaux': {
          'capital': totalCapital,
          'creances': totalCreances,
          'dettes': totalDettes,
          'capitalNet': totalCapital + totalCreances - totalDettes,
        },
        'periode': {
          'debut': widget.startDate?.toIso8601String(),
          'fin': widget.endDate?.toIso8601String(),
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

    final isGlobal = _reportData!['isGlobal'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (isGlobal) ...[
            _buildGlobalSummary(),
            const SizedBox(height: 24),
            _buildAllShopsTable(),
          ] else ...[
            _buildCapitalBreakdown(),
            const SizedBox(height: 24),
            _buildOperationsList(),
            const SizedBox(height: 24),
            _buildCreancesEtDettes(),
            const SizedBox(height: 24),
            _buildCapitalNet(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    final isGlobal = _reportData!['isGlobal'] ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  isGlobal ? 'Évolution ' : 'Évolution du Capital',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isGlobal) ...[
              () {
                final shop = _reportData!['shop'] as Map<String, dynamic>;
                return Text(
                  'Shop: ${shop['designation']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                );
              }(),
            ],
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

  Widget _buildGlobalSummary() {
    final totaux = _reportData!['totaux'] as Map<String, dynamic>;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Capital Total',
            '${totaux['capital'].toStringAsFixed(2)} USD',
            Icons.account_balance,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Créances',
            '${totaux['creances'].toStringAsFixed(2)} USD',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Dettes',
            '${totaux['dettes'].toStringAsFixed(2)} USD',
            Icons.trending_down,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Capital Net',
            '${totaux['capitalNet'].toStringAsFixed(2)} USD',
            Icons.account_balance_wallet,
            totaux['capitalNet'] >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildAllShopsTable() {
    final shops = _reportData!['shops'] as List<Map<String, dynamic>>;
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Détail par Shop',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final reportService = Provider.of<ReportService>(context, listen: false);
                        await reportService.diagnosticDepotsRetraits();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Diagnostic terminé - Vérifiez les logs'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('Diagnostic'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final reportService = Provider.of<ReportService>(context, listen: false);
                        await reportService.createTestOperations();
                        await _loadReport(); // Recharger les données
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opérations de test créées - Rapport mis à jour'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Test Ops'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Cash')),
                DataColumn(label: Text('Airtel Money')),
                DataColumn(label: Text('M-Pesa')),
                DataColumn(label: Text('Orange Money')),
                DataColumn(label: Text('Total Capital')),
                DataColumn(label: Text('Créances')),
                DataColumn(label: Text('Dettes')),
                DataColumn(label: Text('Capital Net')),
              ],
              rows: shops.map((shopData) {
                final shop = shopData['shop'] as Map<String, dynamic>;
                final capital = shopData['capital'] as Map<String, dynamic>;
                final creancesEtDettes = shopData['creancesEtDettes'] as Map<String, dynamic>;
                final capitalNet = shopData['capitalNet'] as double;
                
                return DataRow(
                  cells: [
                    DataCell(Text(shop['designation'])),
                    DataCell(Text('${capital['cash'].toStringAsFixed(2)}')),
                    DataCell(Text('${capital['airtelMoney'].toStringAsFixed(2)}')),
                    DataCell(Text('${capital['mPesa'].toStringAsFixed(2)}')),
                    DataCell(Text('${capital['orangeMoney'].toStringAsFixed(2)}')),
                    DataCell(Text(
                      '${capital['total'].toStringAsFixed(2)} USD',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(
                      '${creancesEtDettes['creances'].toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.green),
                    )),
                    DataCell(Text(
                      '${creancesEtDettes['dettes'].toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.red),
                    )),
                    DataCell(Text(
                      '${capitalNet.toStringAsFixed(2)} USD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: capitalNet >= 0 ? Colors.green : Colors.red,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalBreakdown() {
    final capital = _reportData!['capital'] as Map<String, dynamic>;
    final impactFlotsRecus = (capital['impactFlotsRecus'] as double?) ?? 0.0;
    final impactFlotsServis = (capital['impactFlotsServis'] as double?) ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition du Capital',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Évolution du Capital avec Dépôts/Retraits et FLOT
            if ((capital['impactDepots'] != null && capital['impactRetraits'] != null &&
                (capital['impactDepots'] > 0 || capital['impactRetraits'] > 0)) ||
                (impactFlotsRecus > 0 || impactFlotsServis > 0)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Évolution du Capital',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEvolutionCard(
                            'Dépôts',
                            capital['impactDepots'] as double,
                            Icons.add_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEvolutionCard(
                            'Retraits',
                            capital['impactRetraits'] as double,
                            Icons.remove_circle,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEvolutionCard(
                            'FLOT Reçus',
                            impactFlotsRecus,
                            Icons.arrow_downward,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEvolutionCard(
                            'FLOT Servis',
                            impactFlotsServis,
                            Icons.arrow_upward,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEvolutionCard(
                            'Impact Net Client',
                            (capital['impactDepots'] as double) - (capital['impactRetraits'] as double),
                            Icons.account_balance,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEvolutionCard(
                            'Impact Net FLOT',
                            impactFlotsRecus - impactFlotsServis,
                            Icons.local_shipping,
                            Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEvolutionCard(
                            'Impact Total',
                            (capital['impactDepots'] as double) - (capital['impactRetraits'] as double) + 
                            impactFlotsRecus - impactFlotsServis,
                            Icons.summarize,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                Expanded(
                  child: _buildCapitalCard(
                    'Cash',
                    capital['cash'] as double,
                    Icons.money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCapitalCard(
                    'Airtel Money',
                    capital['airtelMoney'] as double,
                    Icons.phone_android,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCapitalCard(
                    'M-Pesa',
                    capital['mPesa'] as double,
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCapitalCard(
                    'Orange Money',
                    capital['orangeMoney'] as double,
                    Icons.payment,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.blue[700], size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Capital Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${capital['total'].toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
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
    );
  }

  Widget _buildCapitalCard(String type, double montant, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            type,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${montant.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreancesEtDettes() {
    final creancesEtDettes = _reportData!['creancesEtDettes'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Créances et Dettes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green[700], size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Créances',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${creancesEtDettes['creances'].toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'À recevoir',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.trending_down, color: Colors.red[700], size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Dettes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${creancesEtDettes['dettes'].toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        Text(
                          'À payer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.balance, color: Colors.blue[700], size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Solde Net',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${creancesEtDettes['net'].toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: creancesEtDettes['net'] >= 0 ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                        Text(
                          creancesEtDettes['net'] >= 0 ? 'Positif' : 'Négatif',
                          style: TextStyle(
                            fontSize: 12,
                            color: creancesEtDettes['net'] >= 0 ? Colors.green[600] : Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalNet() {
    final capitalNet = _reportData!['capitalNet'] as double;
    final capital = _reportData!['capital'] as Map<String, dynamic>;
    final creancesEtDettes = _reportData!['creancesEtDettes'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capital Net Final',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: capitalNet >= 0 
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [Colors.red[400]!, Colors.red[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    capitalNet >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Capital Net',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${capitalNet.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capital Total + Créances - Dettes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Formule de calcul
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calcul:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('Capital de Base: ${capital['base']?.toStringAsFixed(2) ?? '0.00'} USD'),
                  Text('+ Dépôts: ${capital['impactDepots']?.toStringAsFixed(2) ?? '0.00'} USD'),
                  Text('- Retraits: ${capital['impactRetraits']?.toStringAsFixed(2) ?? '0.00'} USD'),
                  Text('+ FLOT Reçus: ${((capital['impactFlotsRecus'] as double?) ?? 0.0).toStringAsFixed(2)} USD'),
                  Text('- FLOT Servis: ${((capital['impactFlotsServis'] as double?) ?? 0.0).toStringAsFixed(2)} USD'),
                  Text('= Capital Total: ${capital['total'].toStringAsFixed(2)} USD'),
                  Text('+ Créances: ${creancesEtDettes['creances'].toStringAsFixed(2)} USD'),
                  Text('- Dettes: ${creancesEtDettes['dettes'].toStringAsFixed(2)} USD'),
                  const Divider(),
                  Text(
                    '= Capital Net Final: ${capitalNet.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionCard(String type, double montant, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            type,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsList() {
    final operations = _reportData!['operations'] as List<dynamic>? ?? [];
    
    if (operations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
              const SizedBox(height: 8),
              Text(
                'Aucune opération de dépôt ou retrait sur cette période',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
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
                Icon(Icons.list_alt, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Liste des Opérations (Dépôts & Retraits)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${operations.length} opération${operations.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Client/Destinataire', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Montant Brut', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Commission', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Montant Servi', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: operations.map<DataRow>((op) {
                final opMap = op as Map<String, dynamic>;
                final type = opMap['type'] as String;
                final montantBrut = opMap['montantBrut'] as double;
                final commission = opMap['commission'] as double;
                final montantNet = opMap['montantNet'] as double;
                final destinataire = opMap['destinataire'] as String? ?? 'N/A';
                final modePaiement = opMap['modePaiement'] as String;
                final statut = opMap['statut'] as String;
                final dateOp = DateTime.parse(opMap['dateOp'] as String);
                
                // Déterminer la couleur selon le type d'opération
                Color typeColor;
                IconData typeIcon;
                String typeLabel;
                
                switch (type) {
                  case 'depot':
                    typeColor = Colors.green;
                    typeIcon = Icons.add_circle;
                    typeLabel = 'Dépôt';
                    break;
                  case 'retrait':
                    typeColor = Colors.red;
                    typeIcon = Icons.remove_circle;
                    typeLabel = 'Retrait';
                    break;
                  case 'transfertNational':
                  case 'transfertInternationalSortant':
                    typeColor = Colors.blue;
                    typeIcon = Icons.arrow_upward;
                    typeLabel = 'Transfert Sortant';
                    break;
                  case 'transfertInternationalEntrant':
                    typeColor = Colors.purple;
                    typeIcon = Icons.arrow_downward;
                    typeLabel = 'Transfert Entrant';
                    break;
                  case 'FLOT_RECU':
                    typeColor = Colors.purple;
                    typeIcon = Icons.local_shipping;
                    typeLabel = 'FLOT Reçu';
                    break;
                  case 'FLOT_SERVI':
                    typeColor = Colors.orange;
                    typeIcon = Icons.local_shipping;
                    typeLabel = 'FLOT Servi';
                    break;
                  default:
                    typeColor = Colors.grey;
                    typeIcon = Icons.help_outline;
                    typeLabel = type;
                }
                
                return DataRow(
                  cells: [
                    DataCell(Text(_formatDateTime(dateOp))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 16, color: typeColor),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        destinataire,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(Text('${montantBrut.toStringAsFixed(2)} USD')),
                    DataCell(
                      Text(
                        commission > 0 ? '${commission.toStringAsFixed(2)} USD' : '-',
                        style: TextStyle(
                          color: commission > 0 ? Colors.orange[700] : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${montantNet.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: typeColor,
                        ),
                      ),
                    ),
                    DataCell(Text(_getModePaiementLabel(modePaiement))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatutColor(statut).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatutLabel(statut),
                          style: TextStyle(
                            color: _getStatutColor(statut),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onSelectChanged: (selected) { // Add this block
                    if (selected != null && selected) {
                      _showOperationDetails(opMap); // Show details when row is selected
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getModePaiementLabel(String mode) {
    switch (mode) {
      case 'cash':
        return 'Cash';
      case 'airtelMoney':
        return 'Airtel Money';
      case 'mPesa':
        return 'M-Pesa';
      case 'orangeMoney':
        return 'Orange Money';
      default:
        return mode;
    }
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'validee':
        return Colors.green;
      case 'terminee':
        return Colors.green;
      case 'enAttente':
        return Colors.orange;
      case 'annulee':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatutLabel(String statut) {
    switch (statut) {
      case 'validee':
        return 'Validée';
      case 'terminee':
        return 'Terminée';
      case 'enAttente':
        return 'En attente';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showOperationDetails(Map<String, dynamic> operation) {
    final type = operation['type'] as String;
    final destinataire = operation['destinataire'] as String;
    final montantBrut = operation['montantBrut'] as double;
    final commission = operation['commission'] as double;
    final montantNet = operation['montantNet'] as double;
    final modePaiement = operation['modePaiement'] as String;
    final statut = operation['statut'] as String;
    final dateOp = DateTime.parse(operation['dateOp'] as String);
    final observation = operation['observation'] as String?; // Get observation field
    
    String typeLabel;
    switch (type) {
      case 'depot':
        typeLabel = 'Dépôt';
        break;
      case 'retrait':
        typeLabel = 'Retrait';
        break;
      case 'transfertNational':
      case 'transfertInternationalSortant':
        typeLabel = 'Transfert Sortant';
        break;
      case 'transfertInternationalEntrant':
        typeLabel = 'Transfert Entrant';
        break;
      case 'FLOT_RECU':
        typeLabel = 'FLOT Reçu';
        break;
      case 'FLOT_SERVI':
        typeLabel = 'FLOT Servi';
        break;
      default:
        typeLabel = type;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - $typeLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destinataire: $destinataire'),
            Text('Montant brut: ${montantBrut.toStringAsFixed(2)} USD'),
            if (commission > 0)
              Text('Commission: ${commission.toStringAsFixed(2)} USD'),
            Text('Montant net: ${montantNet.toStringAsFixed(2)} USD'),
            Text('Mode de paiement: ${_getModePaiementLabel(modePaiement)}'),
            Text('Statut: ${_getStatutLabel(statut)}'),
            Text('Date: ${_formatDateTime(dateOp)}'),
            if (observation != null && observation.isNotEmpty) // Show observation if available
              Text('Observation: $observation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}