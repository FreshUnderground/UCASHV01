import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/audit_log_model.dart';
import '../services/audit_service.dart';

/// Widget pour afficher l'historique d'audit d'un enregistrement
class AuditHistoryWidget extends StatefulWidget {
  final String? tableName;
  final int? recordId;
  final int? userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showFilters;

  const AuditHistoryWidget({
    Key? key,
    this.tableName,
    this.recordId,
    this.userId,
    this.startDate,
    this.endDate,
    this.showFilters = false,
  }) : super(key: key);

  @override
  State<AuditHistoryWidget> createState() => _AuditHistoryWidgetState();
}

class _AuditHistoryWidgetState extends State<AuditHistoryWidget> {
  final AuditService _auditService = AuditService.instance;
  List<AuditLogModel> _audits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits() async {
    setState(() => _isLoading = true);
    await _auditService.loadAudits(
      tableName: widget.tableName,
      recordId: widget.recordId,
      userId: widget.userId,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
    setState(() {
      _audits = _auditService.audits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_audits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun historique',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _audits.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildAuditCard(_audits[index]),
    );
  }

  Widget _buildAuditCard(AuditLogModel audit) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showAuditDetails(audit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec action et utilisateur
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: audit.action.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      audit.action.icon,
                      color: audit.action.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audit.action.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${audit.tableName} #${audit.recordId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateFormat.format(audit.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Utilisateur
              if (audit.username != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      audit.username!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (audit.userRole != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          audit.userRole!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Champs modifiés
              if (audit.changedFields != null && audit.changedFields!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: audit.changedFields!
                      .map((field) => Chip(
                            label: Text(
                              field,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.orange[50],
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],

              // Raison
              if (audit.reason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          audit.reason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Indicateur de détails disponibles
              if (audit.oldValues != null || audit.newValues != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Voir les détails',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditDetails(AuditLogModel audit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(audit.action.icon, color: audit.action.color),
            const SizedBox(width: 12),
            Text(audit.action.label),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Table', audit.tableName),
              _buildDetailRow('Enregistrement', '#${audit.recordId}'),
              if (audit.username != null) _buildDetailRow('Utilisateur', audit.username!),
              if (audit.shopId != null) _buildDetailRow('Shop', '#${audit.shopId}'),
              
              if (audit.oldValues != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Anciennes valeurs:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatJson(audit.oldValues!),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],

              if (audit.newValues != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Nouvelles valeurs:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatJson(audit.newValues!),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}
