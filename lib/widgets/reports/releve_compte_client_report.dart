// ignore_for_file: unnecessary_string_interpolations

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../services/report_service.dart';
import '../../services/pdf_service.dart';
import '../../services/operation_service.dart';
import '../../models/client_model.dart';
import '../../models/operation_model.dart';
import '../../models/shop_model.dart';
import '../../services/shop_service.dart';
import '../../services/auth_service.dart';

class ReleveCompteClientReport extends StatefulWidget {
  final int clientId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isAdmin;

  const ReleveCompteClientReport({
    super.key,
    required this.clientId,
    this.startDate,
    this.endDate,
    this.isAdmin = false,
  });

  @override
  State<ReleveCompteClientReport> createState() => _ReleveCompteClientReportState();
}

class _ReleveCompteClientReportState extends State<ReleveCompteClientReport> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(ReleveCompteClientReport oldWidget) {
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
      final data = await reportService.generateReleveCompteClient(
        clientId: widget.clientId,
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
            Text('Génération du relevé en cours...'),
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
              'Erreur lors de la génération du relevé',
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
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientInfo(),
          const SizedBox(height: 8),
          _buildSoldeActuel(),
          const SizedBox(height: 8),
          _buildStatistiques(),
          const SizedBox(height: 8),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    final client = _reportData!['client'] as Map<String, dynamic>;
    final periode = _reportData!['periode'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (periode['debut'] != null && periode['fin'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Période: Du ${_formatDate(DateTime.parse(periode['debut']))} au ${_formatDate(DateTime.parse(periode['fin']))}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSoldeActuel() {
    final soldeActuel = _reportData!['soldeActuel'] as double;
    
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          gradient: LinearGradient(
            colors: soldeActuel >= 0 
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.red[400]!, Colors.red[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 38,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solde Actuel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${soldeActuel.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    soldeActuel >= 0 ? 'Compte Créditeur' : 'Compte Débiteur',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              soldeActuel >= 0 ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistiques() {
    final totaux = _reportData!['totaux'] as Map<String, dynamic>;
    final soldeActuel = _reportData!['soldeActuel'] as double;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Dépôts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totaux['depots'].toStringAsFixed(2)} \$',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Retraits',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${totaux['retraits'].toStringAsFixed(2)} \$',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Solde',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${soldeActuel.toStringAsFixed(2)} \$',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: soldeActuel >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                fontSize: 16,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final transactions = _reportData!['transactions'] as List<Map<String, dynamic>>;
    
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune transaction',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune transaction trouvée pour la période sélectionnée',
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
            padding: const EdgeInsets.all(2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                if (isMobile) {
                  // Mobile layout: Stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historique',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${transactions.length} transaction(s)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ),
                          IconButton(
                            onPressed: _previewPdf,
                            icon: const Icon(Icons.visibility, size: 20),
                            tooltip: 'Prévisualiser',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: _exportToPdf,
                            icon: const Icon(Icons.download, size: 20),
                            tooltip: 'Télécharger PDF',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: _printReport,
                            icon: const Icon(Icons.print, size: 20),
                            tooltip: 'Imprimer',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Desktop layout: Single row
                  return Row(
                    children: [
                      const Text(
                        'Historique des Transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${transactions.length} transaction(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _previewPdf,
                        icon: const Icon(Icons.visibility),
                        tooltip: 'Prévisualiser',
                      ),
                      IconButton(
                        onPressed: _exportToPdf,
                        icon: const Icon(Icons.download),
                        tooltip: 'Télécharger PDF',
                      ),
                      IconButton(
                        onPressed: _printReport,
                        icon: const Icon(Icons.print),
                        tooltip: 'Imprimer',
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          
          // Historique des transactions
          
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Bord. Réçu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Bord. Payé',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reçu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Payé',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Solde',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (widget.isAdmin)
                  const SizedBox(
                    width: 40,
                    child: Text(
                      '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(thickness: 1, height: 1),
          
          // Liste des transactions avec solde cumulé
          _buildTransactionsListWithBalance(transactions),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final montant = transaction['montant'] as double;
    final commission = transaction['commission'] as double;
    final date = transaction['date'] as DateTime;
    
    Color typeColor;
    IconData typeIcon;
    bool isCredit = false;
    
    switch (type) {
      case 'depot':
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        isCredit = true;
        break;
      case 'retrait':
        typeColor = Colors.orange;
        typeIcon = Icons.remove_circle;
        isCredit = false;
        break;
      case 'transfertInternationalEntrant':
        typeColor = Colors.purple;
        typeIcon = Icons.call_received;
        isCredit = true;
        break;
      case 'transfertNational':
      case 'transfertInternationalSortant':
        typeColor = Colors.blue;
        typeIcon = Icons.send;
        isCredit = false;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.swap_horiz;
        isCredit = false;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: typeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: typeColor.withOpacity(0.3)),
        ),
        child: Icon(typeIcon, color: typeColor, size: 20),
      ),
      title: Row(
        children: [
          Text(
            _getTypeLabel(type),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '${isCredit ? '+' : '-'}${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green : Colors.red,
              fontSize: 16,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateTime(date),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (commission > 0)
            Text(
              'Commission: ${commission.toStringAsFixed(2)} USD',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          // Show observation instead of destinataire
          if (transaction['observation'] != null && transaction['observation'].toString().isNotEmpty)
            Text(
              transaction['observation'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            )
          else if (transaction['destinataire'] != null && transaction['destinataire'].toString().isNotEmpty)
            Text(
              'Destinataire: ${transaction['destinataire']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          if (transaction['notes'] != null && transaction['notes'].toString().isNotEmpty)
            Text(
              transaction['notes'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'depot':
        return 'Dépôt';
      case 'retrait':
        return 'Retrait';
      case 'transfert_sortant':
        return 'Transfert Sortant';
      case 'transfert_entrant':
        return 'Transfert Entrant';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Export the report to PDF
  Future<void> _exportToPdf() async {
    if (_reportData == null) return;

    try {
      // Show loading indicator
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Génération du PDF en cours...')),
      );

      // Get required data
      final clientData = _reportData!['client'] as Map<String, dynamic>;
      final transactions = _reportData!['transactions'] as List<dynamic>;

      // Create client model from data
      final client = ClientModel.fromJson(clientData);

      // Convert transaction data to OperationModel objects
      final operationModels = <OperationModel>[];
      for (var transaction in transactions) {
        if (transaction is Map<String, dynamic>) {
          // Create a minimal OperationModel for PDF generation
          final operation = OperationModel(
            codeOps: '', // Sera généré automatiquement si nécessaire
            id: transaction['id'] as int?,
            type: _mapStringToOperationType(transaction['type'] as String),
            montantBrut: transaction['montant'] as double? ?? 0.0,
            montantNet: transaction['montant'] as double? ?? 0.0,
            commission: transaction['commission'] as double? ?? 0.0,
            devise: 'USD',
            statut: _mapStringToOperationStatus(transaction['statut'] as String? ?? 'terminee'),
            dateOp: transaction['date'] as DateTime,
            modePaiement: ModePaiement.cash,
            clientId: client.id,
            agentId: 1, // Default agent ID
            destinataire: transaction['destinataire'] as String?,
            notes: transaction['notes'] as String?,
            observation: transaction['observation'] as String?,
          );
          operationModels.add(operation);
        }
      }

      // Get shop and agent data
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final agent = authService.currentUser!;
      final shop = shopService.getShopById(agent.shopId ?? 0);

      // Generate PDF using existing PDF service
      final pdfService = PdfService();
      final pdf = await pdfService.generateClientStatementPdf(
        client: client,
        operations: operationModels,
        shop: shop ?? ShopModel(
          id: agent.shopId ?? 0,
          designation: 'Shop Inconnu',
          localisation: 'Localisation Inconnue',
          capitalInitial: 0.0,
          capitalActuel: 0.0,
          capitalCash: 0.0,
          capitalAirtelMoney: 0.0,
          capitalMPesa: 0.0,
          capitalOrangeMoney: 0.0,
          createdAt: DateTime.now(),
        ),
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      // Save or share the PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'releve_compte_${client.nom}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('PDF généré avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF: $e')),
        );
      }
    }
  }

  // Print the report
  Future<void> _printReport() async {
    if (_reportData == null) return;

    try {
      // Show loading indicator
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Préparation de l\'impression...')),
      );

      // Get required data
      final clientData = _reportData!['client'] as Map<String, dynamic>;
      final transactions = _reportData!['transactions'] as List<dynamic>;

      // Create client model from data
      final client = ClientModel.fromJson(clientData);

      // Convert transaction data to OperationModel objects
      final operationModels = <OperationModel>[];
      for (var transaction in transactions) {
        if (transaction is Map<String, dynamic>) {
          // Create a minimal OperationModel for PDF generation
          final operation = OperationModel(
            codeOps: '', // Sera généré automatiquement si nécessaire
            id: transaction['id'] as int?,
            type: _mapStringToOperationType(transaction['type'] as String),
            montantBrut: transaction['montant'] as double? ?? 0.0,
            montantNet: transaction['montant'] as double? ?? 0.0,
            commission: transaction['commission'] as double? ?? 0.0,
            devise: 'USD',
            statut: _mapStringToOperationStatus(transaction['statut'] as String? ?? 'terminee'),
            dateOp: transaction['date'] as DateTime,
            modePaiement: ModePaiement.cash,
            clientId: client.id,
            agentId: 1, // Default agent ID
            destinataire: transaction['destinataire'] as String?,
            notes: transaction['notes'] as String?,
            observation: transaction['observation'] as String?,
          );
          operationModels.add(operation);
        }
      }

      // Get shop and agent data
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final agent = authService.currentUser!;
      final shop = shopService.getShopById(agent.shopId ?? 0);

      // Generate PDF using existing PDF service
      final pdfService = PdfService();
      final pdf = await pdfService.generateClientStatementPdf(
        client: client,
        operations: operationModels,
        shop: shop ?? ShopModel(
          id: agent.shopId ?? 0,
          designation: 'Shop Inconnu',
          localisation: 'Localisation Inconnue',
          capitalInitial: 0.0,
          capitalActuel: 0.0,
          capitalCash: 0.0,
          capitalAirtelMoney: 0.0,
          capitalMPesa: 0.0,
          capitalOrangeMoney: 0.0,
          createdAt: DateTime.now(),
        ),
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Impression envoyée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression: $e')),
        );
      }
    }
  }

  // Helper method to map string to OperationType
  OperationType _mapStringToOperationType(String type) {
    switch (type) {
      case 'depot':
        return OperationType.depot;
      case 'retrait':
        return OperationType.retrait;
      case 'transfertNational':
        return OperationType.transfertNational;
      case 'transfertInternationalSortant':
        return OperationType.transfertInternationalSortant;
      case 'transfertInternationalEntrant':
        return OperationType.transfertInternationalEntrant;
      default:
        return OperationType.depot;
    }
  }

  // Helper method to map string to OperationStatus
  OperationStatus _mapStringToOperationStatus(String status) {
    switch (status) {
      case 'enAttente':
        return OperationStatus.enAttente;
      case 'validee':
        return OperationStatus.validee;
      case 'terminee':
        return OperationStatus.terminee;
      case 'annulee':
        return OperationStatus.annulee;
      default:
        return OperationStatus.terminee;
    }
  }

  // Preview the PDF before downloading
  Future<void> _previewPdf() async {
    if (_reportData == null) return;

    try {
      // Show loading indicator
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Generation de l\'apercu PDF en cours...')),
      );

      // Get required data
      final clientData = _reportData!['client'] as Map<String, dynamic>;
      final transactions = _reportData!['transactions'] as List<dynamic>;

      // Create client model from data
      final client = ClientModel.fromJson(clientData);

      // Convert transaction data to OperationModel objects
      final operationModels = <OperationModel>[];
      for (var transaction in transactions) {
        if (transaction is Map<String, dynamic>) {
          // Create a minimal OperationModel for PDF generation
          final operation = OperationModel(
            codeOps: '', // Sera généré automatiquement si nécessaire
            id: transaction['id'] as int?,
            type: _mapStringToOperationType(transaction['type'] as String),
            montantBrut: transaction['montant'] as double? ?? 0.0,
            montantNet: transaction['montant'] as double? ?? 0.0,
            commission: transaction['commission'] as double? ?? 0.0,
            devise: 'USD',
            statut: _mapStringToOperationStatus(transaction['statut'] as String? ?? 'terminee'),
            dateOp: transaction['date'] as DateTime,
            modePaiement: ModePaiement.cash,
            clientId: client.id,
            agentId: 1, // Default agent ID
            destinataire: transaction['destinataire'] as String?,
            notes: transaction['notes'] as String?,
            observation: transaction['observation'] as String?,
          );
          operationModels.add(operation);
        }
      }

      // Get shop and agent data
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final agent = authService.currentUser!;
      final shop = shopService.getShopById(agent.shopId ?? 0);

      // Generate PDF using existing PDF service
      final pdfService = PdfService();
      final pdf = await pdfService.generateClientStatementPdf(
        client: client,
        operations: operationModels,
        shop: shop ?? ShopModel(
          id: agent.shopId ?? 0,
          designation: 'Shop Inconnu',
          localisation: 'Localisation Inconnue',
          capitalInitial: 0.0,
          capitalActuel: 0.0,
          capitalCash: 0.0,
          capitalAirtelMoney: 0.0,
          capitalMPesa: 0.0,
          capitalOrangeMoney: 0.0,
          createdAt: DateTime.now(),
        ),
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final pdfBytes = await pdf.save();

      // Afficher le PDF dans une boîte de dialogue de prévisualisation
      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  // En-tête
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFDC2626),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Prévisualisation Relevé de Compte',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Viewer PDF
                  Expanded(
                    child: PdfPreview(
                      build: (format) => pdfBytes,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      actions: [
                        PdfPreviewAction(
                          icon: const Icon(Icons.share),
                          onPressed: (context, build, pageFormat) async {
                            // Partager le PDF
                            final clientData = _reportData!['client'] as Map<String, dynamic>;
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename: 'releve_compte_${clientData['nom']}_${DateTime.now().toString().split(' ')[0]}.pdf',
                            );
                          },
                        ),
                        PdfPreviewAction(
                          icon: const Icon(Icons.print),
                          onPressed: (context, build, pageFormat) async {
                            // Imprimer directement
                            await Printing.layoutPdf(
                              onLayout: (format) => pdfBytes,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la generation de l\'apercu PDF: $e')),
        );
      }
    }
  }

  Widget _buildTransactionsListWithBalance(List<Map<String, dynamic>> transactions) {
    // Sort transactions by date
    final sortedTransactions = List<Map<String, dynamic>>.from(transactions)
      ..sort((a, b) => DateTime.parse(a['date'].toString()).compareTo(DateTime.parse(b['date'].toString())));
    
    double runningBalance = 0;
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedTransactions.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final transaction = sortedTransactions[index];
        final type = transaction['type'] as String;
        final montant = transaction['montant'] as double;
        final date = transaction['date'] as DateTime;
        
        bool isCredit = (type == 'depot' || type == 'transfertInternationalEntrant');
        
        if (isCredit) {
          runningBalance += montant;
        } else {
          runningBalance -= montant;
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isCredit ? (transaction['observation']?.toString() ?? '--') : '--',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[800],
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  !isCredit ? (transaction['observation']?.toString() ?? '--') : '--',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[800],
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isCredit ? '${montant.toStringAsFixed(2)}' : '--',
                  style: TextStyle(
                    fontSize: 10,
                    color: isCredit ? Colors.green : Colors.grey[700],
                    fontWeight: isCredit ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  !isCredit ? '${montant.toStringAsFixed(2)}' : '--',
                  style: TextStyle(
                    fontSize: 10,
                    color: !isCredit ? Colors.red : Colors.grey[700],
                    fontWeight: !isCredit ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${runningBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: runningBalance >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              if (widget.isAdmin)
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteOperation(transaction),
                    tooltip: 'Supprimer',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteOperation(Map<String, dynamic> transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmer la suppression'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette opération? Cette action est irréversible.',
        ),
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

    if (confirm != true) return;

    try {
      // Get operation ID from transaction
      final operationId = transaction['id'] as int?;
      if (operationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible de supprimer: ID d\'opération manquant'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Delete the operation
      await OperationService().deleteOperation(operationId);

      // Reload the report
      await _loadReport();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Opération supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
