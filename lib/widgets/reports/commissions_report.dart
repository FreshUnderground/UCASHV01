import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';

class CommissionsReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showAllShops;

  const CommissionsReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
    this.showAllShops = false,
  });

  @override
  State<CommissionsReport> createState() => _CommissionsReportState();
}

class _CommissionsReportState extends State<CommissionsReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(CommissionsReport oldWidget) {
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
      final data = await reportService.generateCommissionsReport(
        shopId: widget.shopId,
        startDate: widget.startDate,
        endDate: widget.endDate,
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
          _buildCommissionsParType(),
          const SizedBox(height: 24),
          _buildCommissionsParShop(),
          const SizedBox(height: 24),
          _buildOperationsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    final totalCommissions = _reportData!['totalCommissions'] as double;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Commissions Encaissées',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Text(
                    'Total: ${totalCommissions.toStringAsFixed(2)} USD',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
    final totalCommissions = _reportData!['totalCommissions'] as double;
    final operations = _reportData!['operations'] as List<Map<String, dynamic>>;
    final commissionsParType = _reportData!['commissionsParType'] as Map<String, double>;
    
    final moyenneCommission = operations.isNotEmpty ? totalCommissions / operations.length : 0.0;
    final operationsAvecCommission = operations.where((op) => op['commission'] > 0).length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Commissions',
            '${totalCommissions.toStringAsFixed(2)} USD',
            Icons.attach_money,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Opérations Payantes',
            '$operationsAvecCommission',
            Icons.receipt,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Commission Moyenne',
            '${moyenneCommission.toStringAsFixed(2)} USD',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Transferts Sortants',
            '${(commissionsParType['transfertNational'] ?? 0) + (commissionsParType['transfertInternationalSortant'] ?? 0)}',
            Icons.send,
            Colors.purple,
          ),
        ),
      ],
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

  Widget _buildCommissionsParType() {
    final commissionsParType = _reportData!['commissionsParType'] as Map<String, double>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commissions par Type de Transfert',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildTypeCommissionCard(
              'Transferts Nationaux',
              commissionsParType['transfertNational'] ?? 0,
              Icons.location_on,
              Colors.blue,
              '3.5% sur les transferts internes RDC',
            ),
            const SizedBox(height: 8),
            
            _buildTypeCommissionCard(
              'Transferts Internationaux Sortants',
              commissionsParType['transfertInternationalSortant'] ?? 0,
              Icons.flight_takeoff,
              Colors.purple,
              '3.5% sur les envois vers l\'étranger',
            ),
            const SizedBox(height: 8),
            
            _buildTypeCommissionCard(
              'Transferts Internationaux Entrants',
              commissionsParType['transfertInternationalEntrant'] ?? 0,
              Icons.flight_land,
              Colors.teal,
              '0% - Gratuit pour attirer les transferts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCommissionCard(String type, double commission, IconData icon, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${commission.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionsParShop() {
    final commissionsParShop = _reportData!['commissionsParShop'] as Map<String, double>;
    
    if (commissionsParShop.isEmpty || !widget.showAllShops) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commissions par Shop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ...commissionsParShop.entries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(2)} USD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsList() {
    final operations = _reportData!['operations'] as List<Map<String, dynamic>>;
    
    if (operations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.money_off_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune commission encaissée',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune opération génératrice de commission pour la période sélectionnée',
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
                  'Détail des Opérations avec Commission',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${operations.length} opération(s)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Date')),
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Montant')),
                const DataColumn(label: Text('Commission')),
                if (widget.showAllShops) const DataColumn(label: Text('Shop')),
                const DataColumn(label: Text('Agent')),
              ],
              rows: operations.take(30).map((operation) => DataRow(
                cells: [
                  DataCell(Text(_formatDateTime(operation['date'] as DateTime))),
                  DataCell(_buildTypeChip(operation['type'])),
                  DataCell(Text('${operation['montant'].toStringAsFixed(2)} USD')),
                  DataCell(Text(
                    '${operation['commission'].toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  )),
                  if (widget.showAllShops) DataCell(Text(operation['shop'])),
                  DataCell(Text(operation['agent'])),
                ],
              )).toList(),
            ),
          ),
          if (operations.length > 30)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Affichage des 30 premières opérations sur ${operations.length} au total',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color color;
    switch (type) {
      case 'transfertNational':
        color = Colors.blue;
        break;
      case 'transfertInternationalSortant':
        color = Colors.purple;
        break;
      case 'transfertInternationalEntrant':
        color = Colors.teal;
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
        type,
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
