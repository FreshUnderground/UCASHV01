import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reconciliation_model.dart';
import '../services/reconciliation_service.dart';
import '../services/shop_service.dart';

/// Widget de rapport de réconciliation
class ReconciliationReportWidget extends StatefulWidget {
  final int? shopId;
  final bool showOnlyGaps;

  const ReconciliationReportWidget({
    Key? key,
    this.shopId,
    this.showOnlyGaps = false,
  }) : super(key: key);

  @override
  State<ReconciliationReportWidget> createState() => _ReconciliationReportWidgetState();
}

class _ReconciliationReportWidgetState extends State<ReconciliationReportWidget> {
  final ReconciliationService _reconciliationService = ReconciliationService.instance;
  List<ReconciliationModel> _reconciliations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReconciliations();
  }

  Future<void> _loadReconciliations() async {
    setState(() => _isLoading = true);
    await _reconciliationService.loadReconciliations(shopId: widget.shopId);
    setState(() {
      _reconciliations = widget.showOnlyGaps
          ? _reconciliationService.reconciliations
              .where((r) => (r.ecartPourcentage?.abs() ?? 0) > 0)
              .toList()
          : _reconciliationService.reconciliations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reconciliations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              widget.showOnlyGaps 
                  ? 'Aucun écart détecté' 
                  : 'Aucune réconciliation',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _reconciliations.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildReconciliationCard(_reconciliations[index]),
    );
  }

  Widget _buildReconciliationCard(ReconciliationModel reconciliation) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final shopService = Provider.of<ShopService>(context);
    final shop = shopService.shops.firstWhere(
      (s) => s.id == reconciliation.shopId,
      orElse: () => shopService.shops.first,
    );

    final alertLevel = reconciliation.alertLevel;
    final statusColor = _getStatusColor(reconciliation.statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getAlertColor(alertLevel),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showReconciliationDetails(reconciliation, shop.designation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec shop et date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.designation,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          dateFormat.format(reconciliation.dateReconciliation),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      reconciliation.statut.name,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Capital total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCapitalColumn(
                    'Capital Système',
                    reconciliation.capitalSystemeTotal,
                    Colors.grey[700]!,
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  _buildCapitalColumn(
                    'Capital Réel',
                    reconciliation.capitalReelTotal,
                    Colors.blue[700]!,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Écart
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getAlertColor(alertLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getAlertColor(alertLevel),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getAlertIcon(alertLevel),
                      color: _getAlertColor(alertLevel),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Écart: ${(reconciliation.ecartTotal ?? 0).toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getAlertColor(alertLevel),
                            ),
                          ),
                          Text(
                            '${(reconciliation.ecartPourcentage ?? 0).toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: _getAlertColor(alertLevel),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reconciliation.actionCorrectiveRequise)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTION REQUISE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Détails par mode de paiement
              if ((reconciliation.ecartPourcentage?.abs() ?? 0) > 0) ...[
                const SizedBox(height: 16),
                _buildPaymentModeDetails(reconciliation),
              ],

              // Notes
              if (reconciliation.notes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reconciliation.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapitalColumn(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} USD',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentModeDetails(ReconciliationModel reconciliation) {
    return Column(
      children: [
        _buildPaymentModeRow('CASH', reconciliation.ecartCash ?? 0),
        _buildPaymentModeRow('AIRTEL', reconciliation.ecartAirtel ?? 0),
        _buildPaymentModeRow('M-PESA', reconciliation.ecartMpesa ?? 0),
        _buildPaymentModeRow('ORANGE', reconciliation.ecartOrange ?? 0),
      ],
    );
  }

  Widget _buildPaymentModeRow(String mode, double ecart) {
    if (ecart == 0) return const SizedBox.shrink();

    final isPositive = ecart > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              mode,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${ecart.toStringAsFixed(2)} USD',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReconciliationStatut statut) {
    switch (statut) {
      case ReconciliationStatut.VALIDE:
        return Colors.green;
      case ReconciliationStatut.ECART_ACCEPTABLE:
        return Colors.blue;
      case ReconciliationStatut.ECART_ALERTE:
        return Colors.orange;
      case ReconciliationStatut.INVESTIGATION:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getAlertColor(ReconciliationAlertLevel level) {
    switch (level) {
      case ReconciliationAlertLevel.OK:
        return Colors.green;
      case ReconciliationAlertLevel.MINEUR:
        return Colors.blue;
      case ReconciliationAlertLevel.ATTENTION:
        return Colors.orange;
      case ReconciliationAlertLevel.CRITIQUE:
        return Colors.red;
    }
  }

  IconData _getAlertIcon(ReconciliationAlertLevel level) {
    switch (level) {
      case ReconciliationAlertLevel.OK:
        return Icons.check_circle;
      case ReconciliationAlertLevel.MINEUR:
        return Icons.info;
      case ReconciliationAlertLevel.ATTENTION:
        return Icons.warning;
      case ReconciliationAlertLevel.CRITIQUE:
        return Icons.error;
    }
  }

  void _showReconciliationDetails(ReconciliationModel reconciliation, String shopName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réconciliation - $shopName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO: Ajouter les détails complets
              Text('Date: ${DateFormat('dd/MM/yyyy').format(reconciliation.dateReconciliation)}'),
              const SizedBox(height: 16),
              Text('Capital Système: ${reconciliation.capitalSystemeTotal.toStringAsFixed(2)} USD'),
              Text('Capital Réel: ${reconciliation.capitalReelTotal.toStringAsFixed(2)} USD'),
              Text('Écart: ${(reconciliation.ecartTotal ?? 0).toStringAsFixed(2)} USD'),
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
}
