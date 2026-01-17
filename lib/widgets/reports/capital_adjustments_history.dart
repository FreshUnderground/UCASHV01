import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/capital_adjustment_service.dart';
import '../../models/shop_model.dart';

class CapitalAdjustmentsHistory extends StatefulWidget {
  final ShopModel? shop;
  final int? adminId;

  const CapitalAdjustmentsHistory({
    super.key,
    this.shop,
    this.adminId,
  });

  @override
  State<CapitalAdjustmentsHistory> createState() =>
      _CapitalAdjustmentsHistoryState();
}

class _CapitalAdjustmentsHistoryState extends State<CapitalAdjustmentsHistory> {
  DateTime? _startDate;
  DateTime? _endDate;
  int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadAdjustments();
  }

  Future<void> _loadAdjustments() async {
    await CapitalAdjustmentService.instance.loadAdjustments(
      shopId: widget.shop?.id,
      adminId: widget.adminId,
      startDate: _startDate?.toIso8601String().split('T')[0],
      endDate: _endDate?.toIso8601String().split('T')[0],
      limit: _limit,
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
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
      await _loadAdjustments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<CapitalAdjustmentService>(
      builder: (context, service, _) {
        return Card(
          elevation: 2,
          child: Column(
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.capitalAdjustmentHistory,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.shop != null)
                            Text(
                              widget.shop!.designation,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.date_range, color: Colors.white),
                      onPressed: _selectDateRange,
                      tooltip: l10n.filterByPeriod,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadAdjustments,
                      tooltip: l10n.refresh,
                    ),
                  ],
                ),
              ),

              // Filtres actifs
              if (_startDate != null || _endDate != null)
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: 16, color: Colors.blue[700]),
                      SizedBox(width: 8),
                      Text(
                        '${l10n.period}: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                        style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                      ),
                      Spacer(),
                      TextButton.icon(
                        icon: Icon(Icons.clear, size: 16),
                        label: Text(l10n.clearFilters),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadAdjustments();
                        },
                      ),
                    ],
                  ),
                ),

              // Contenu
              if (service.isLoading)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (service.errorMessage != null)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        '${l10n.error}: ${service.errorMessage}',
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text(l10n.retry),
                        onPressed: _loadAdjustments,
                      ),
                    ],
                  ),
                )
              else if (service.adjustments.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, color: Colors.grey, size: 64),
                      SizedBox(height: 16),
                      Text(
                        l10n.noAdjustmentsFound,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: service.adjustments.length,
                    itemBuilder: (context, index) {
                      final adjustment = service.adjustments[index];
                      return _buildAdjustmentCard(adjustment);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdjustmentCard(CapitalAdjustment adjustment) {
    final l10n = AppLocalizations.of(context)!;
    final isIncrease = adjustment.adjustmentType == AdjustmentType.increase;
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isIncrease ? Colors.green[100] : Colors.red[100],
          child: Icon(
            isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncrease ? Colors.green[700] : Colors.red[700],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                adjustment.adjustmentTypeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncrease ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
            Text(
              '${isIncrease ? '+' : '-'}${adjustment.amount.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isIncrease ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '🏪 ${adjustment.shopName}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  adjustment.adminUsername,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  dateFormatter.format(adjustment.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Raison
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.orange[800]),
                          SizedBox(width: 8),
                          Text(
                            '${l10n.reason}:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        adjustment.reason,
                        style: TextStyle(fontSize: 13),
                      ),
                      if (adjustment.description != null) ...[
                        SizedBox(height: 8),
                        Text(
                          adjustment.description!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Détails de l'ajustement
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailBox(
                        l10n.before,
                        '${adjustment.capitalBefore.toStringAsFixed(2)} USD',
                        Colors.grey,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward,
                      color: isIncrease ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailBox(
                        l10n.after,
                        '${adjustment.capitalAfter.toStringAsFixed(2)} USD',
                        isIncrease ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Mode de paiement
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 16, color: Colors.blue[700]),
                      SizedBox(width: 8),
                      Text(
                        '${l10n.mode}: ${adjustment.modePaiementLabel}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),

                // Audit ID
                Row(
                  children: [
                    Icon(Icons.fingerprint, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '${l10n.auditId}: ${adjustment.auditId}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
