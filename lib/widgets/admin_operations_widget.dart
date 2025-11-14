import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../models/operation_model.dart';
import 'package:intl/intl.dart';

class AdminOperationsWidget extends StatefulWidget {
  const AdminOperationsWidget({super.key});

  @override
  State<AdminOperationsWidget> createState() => _AdminOperationsWidgetState();
}

class _AdminOperationsWidgetState extends State<AdminOperationsWidget> {
  String _searchQuery = '';
  OperationType? _typeFilter;
  OperationStatus? _statusFilter;
  int? _shopFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    Provider.of<OperationService>(context, listen: false).loadOperations();
    Provider.of<ShopService>(context, listen: false).loadShops();
  }

  List<OperationModel> _filterOperations(List<OperationModel> operations) {
    return operations.where((op) {
      final matchesSearch = _searchQuery.isEmpty ||
          (op.destinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (op.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          op.id.toString().contains(_searchQuery);

      final matchesType = _typeFilter == null || op.type == _typeFilter;
      final matchesStatus = _statusFilter == null || op.statut == _statusFilter;
      final matchesShop = _shopFilter == null || 
          op.shopSourceId == _shopFilter || 
          op.shopDestinationId == _shopFilter;

      return matchesSearch && matchesType && matchesStatus && matchesShop;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildFilters(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          Expanded(
            child: _buildOperationsTable(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Gestion des Opérations',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Visualiser et annuler les opérations',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            if (!isMobile)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Action: ❌ Annuler une opération',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            if (isMobile)
              Column(
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 8),
                  _buildShopFilter(),
                  const SizedBox(height: 8),
                  _buildTypeFilter(),
                  const SizedBox(height: 8),
                  _buildStatusFilter(),
                ],
              )
            else
              Row(
                children: [
                  Expanded(flex: 2, child: _buildSearchField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildShopFilter()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTypeFilter()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusFilter()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Rechercher',
        hintText: 'ID, destinataire, référence...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildShopFilter() {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        return DropdownButtonFormField<int?>(
          value: _shopFilter,
          decoration: const InputDecoration(
            labelText: 'Shop',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les shops')),
            ...shopService.shops.map((shop) => DropdownMenuItem(
              value: shop.id,
              child: Text(shop.designation),
            )),
          ],
          onChanged: (value) => setState(() => _shopFilter = value),
        );
      },
    );
  }

  Widget _buildTypeFilter() {
    return DropdownButtonFormField<OperationType?>(
      value: _typeFilter,
      decoration: const InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Tous types')),
        DropdownMenuItem(value: OperationType.depot, child: Text('Dépôts')),
        DropdownMenuItem(value: OperationType.retrait, child: Text('Retraits')),
        DropdownMenuItem(value: OperationType.transfertNational, child: Text('Transferts Nat.')),
        DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Trans. Int. Sort.')),
        DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Trans. Int. Ent.')),
      ],
      onChanged: (value) => setState(() => _typeFilter = value),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<OperationStatus?>(
      value: _statusFilter,
      decoration: const InputDecoration(
        labelText: 'Statut',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Tous statuts')),
        DropdownMenuItem(value: OperationStatus.terminee, child: Text('Terminée')),
        DropdownMenuItem(value: OperationStatus.validee, child: Text('Validée')),
        DropdownMenuItem(value: OperationStatus.enAttente, child: Text('En attente')),
        DropdownMenuItem(value: OperationStatus.annulee, child: Text('Annulée')),
      ],
      onChanged: (value) => setState(() => _statusFilter = value),
    );
  }

  Widget _buildOperationsTable(bool isMobile) {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        if (operationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredOps = _filterOperations(operationService.operations);

        if (filteredOps.isEmpty) {
          return Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune opération trouvée',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (isMobile) {
          return _buildMobileList(filteredOps);
        }

        return _buildDesktopTable(filteredOps);
      },
    );
  }

  Widget _buildMobileList(List<OperationModel> operations) {
    return Card(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: operations.length,
        itemBuilder: (context, index) {
          final op = operations[index];
          return _buildMobileOperationCard(op);
        },
      ),
    );
  }

  Widget _buildMobileOperationCard(OperationModel op) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(op.statut).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(op.statut)),
                  ),
                  child: Text(
                    op.statutLabel,
                    style: TextStyle(
                      color: _getStatusColor(op.statut),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'ID: ${op.id}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              op.typeLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${op.montantNet.toStringAsFixed(2)} ${op.devise}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
            ),
            if (op.destinataire != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(op.destinataire!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(op.dateOp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (op.motifAnnulation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Motif: ${op.motifAnnulation}',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (op.statut != OperationStatus.annulee) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCancelDialog(op),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('Annuler l\'opération'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<OperationModel> operations) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 48,
          columns: const [
            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Destinataire', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Shop Source', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Motif Annulation', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: operations.map((op) => _buildDataRow(op)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(OperationModel op) {
    return DataRow(
      cells: [
        DataCell(Text(op.id.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(op.dateOp), style: const TextStyle(fontSize: 12))),
        DataCell(Text(op.typeLabel, style: const TextStyle(fontSize: 12))),
        DataCell(Text(op.destinataire ?? '-', style: const TextStyle(fontSize: 12))),
        DataCell(Text('${op.montantNet.toStringAsFixed(2)} ${op.devise}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        DataCell(Text(op.shopSourceDesignation ?? '-', style: const TextStyle(fontSize: 12))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(op.statut).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor(op.statut)),
            ),
            child: Text(
              op.statutLabel,
              style: TextStyle(
                color: _getStatusColor(op.statut),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          op.motifAnnulation != null
              ? Tooltip(
                  message: op.motifAnnulation!,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      op.motifAnnulation!,
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : const Text('-', style: TextStyle(fontSize: 12)),
        ),
        DataCell(
          op.statut != OperationStatus.annulee
              ? ElevatedButton.icon(
                  onPressed: () => _showCancelDialog(op),
                  icon: const Icon(Icons.cancel, size: 14),
                  label: const Text('Annuler', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                )
              : const Text('Déjà annulée', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ],
    );
  }

  Color _getStatusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.terminee:
        return Colors.green;
      case OperationStatus.validee:
        return Colors.blue;
      case OperationStatus.enAttente:
        return Colors.orange;
      case OperationStatus.annulee:
        return Colors.red;
    }
  }

  void _showCancelDialog(OperationModel operation) {
    final motifController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Annuler l\'opération'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opération ID: ${operation.id}'),
            const SizedBox(height: 4),
            Text('Type: ${operation.typeLabel}'),
            const SizedBox(height: 4),
            Text('Montant: ${operation.montantNet} ${operation.devise}'),
            const SizedBox(height: 16),
            const Text(
              'Cette action est irréversible!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motifController,
              decoration: const InputDecoration(
                labelText: 'Motif d\'annulation *',
                hintText: 'Ex: Erreur de saisie, fraude détectée...',
                border: OutlineInputBorder(),
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
              if (motifController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Veuillez indiquer le motif d\'annulation'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _cancelOperation(operation, motifController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOperation(OperationModel operation, String motif) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      
      final updatedOp = operation.copyWith(
        statut: OperationStatus.annulee,
        motifAnnulation: motif,
        annulePar: authService.currentUser?.id,
        dateAnnulation: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: authService.currentUser?.username ?? 'Admin',
      );

      final success = await operationService.updateOperation(updatedOp);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✅ Opération ${operation.id} annulée avec succès'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors de l\'annulation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
