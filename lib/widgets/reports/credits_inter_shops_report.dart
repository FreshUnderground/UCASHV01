import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/report_service.dart';

class CreditsInterShopsReport extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const CreditsInterShopsReport({
    super.key,
    this.startDate,
    this.endDate,
  });

  @override
  State<CreditsInterShopsReport> createState() => _CreditsInterShopsReportState();
}

class _CreditsInterShopsReportState extends State<CreditsInterShopsReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(CreditsInterShopsReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
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
      final data = await reportService.generateCreditsInterShopsReport(
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
          _buildSoldesNets(),
          const SizedBox(height: 24),
          _buildMatrixCredits(),
          const SizedBox(height: 24),
          _buildTransfertsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Journal des Crédits Inter-Shops',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
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
            const SizedBox(height: 8),
            Text(
              'Ce rapport montre les dettes et créances entre shops suite aux transferts.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoldesNets() {
    final soldesNets = _reportData!['soldesNets'] as Map<String, double>;
    
    if (soldesNets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun crédit inter-shops',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucun transfert entre shops pour la période sélectionnée',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soldes Nets par Shop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...soldesNets.entries.map((entry) => _buildSoldeNetCard(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildSoldeNetCard(String shopNom, double solde) {
    final isPositif = solde >= 0;
    final color = isPositif ? Colors.green : Colors.red;
    final icon = isPositif ? Icons.trending_up : Icons.trending_down;
    final label = isPositif ? 'Créancier' : 'Débiteur';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              shopNom,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${solde.abs().toStringAsFixed(2)} USD',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixCredits() {
    final matrixCredits = _reportData!['matrixCredits'] as Map<String, Map<String, double>>;
    
    if (matrixCredits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Matrice des Crédits (Qui doit à qui)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildCreditMatrix(matrixCredits),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditMatrix(Map<String, Map<String, double>> matrix) {
    final shops = matrix.keys.toList();
    
    return DataTable(
      columns: [
        const DataColumn(label: Text('Shop Source')),
        ...shops.map((shop) => DataColumn(
          label: Text(
            shop,
            style: const TextStyle(fontSize: 12),
          ),
        )),
      ],
      rows: shops.map((shopSource) => DataRow(
        cells: [
          DataCell(Text(
            shopSource,
            style: const TextStyle(fontWeight: FontWeight.w600),
          )),
          ...shops.map((shopDest) {
            if (shopSource == shopDest) {
              return const DataCell(Text('-'));
            }
            final montant = matrix[shopSource]?[shopDest] ?? 0.0;
            return DataCell(
              montant > 0
                  ? Text(
                      '${montant.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const Text('0.00'),
            );
          }),
        ],
      )).toList(),
    );
  }

  Widget _buildTransfertsList() {
    final transferts = _reportData!['transferts'] as List<Map<String, dynamic>>;
    
    if (transferts.isEmpty) {
      return const SizedBox.shrink();
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
                  'Détail des Transferts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${transferts.length} transfert(s)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Shop Source')),
                DataColumn(label: Text('Shop Destination')),
                DataColumn(label: Text('Montant')),
                DataColumn(label: Text('Type')),
              ],
              rows: transferts.take(20).map((transfert) => DataRow(
                cells: [
                  DataCell(Text(_formatDateTime(transfert['date'] as DateTime))),
                  DataCell(Text(transfert['shopSource'])),
                  DataCell(Text(transfert['shopDestination'])),
                  DataCell(Text('${transfert['montant'].toStringAsFixed(2)} USD')),
                  DataCell(_buildTypeChip(transfert['type'])),
                ],
              )).toList(),
            ),
          ),
          if (transferts.length > 20)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Affichage des 20 premiers transferts sur ${transferts.length} au total',
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
