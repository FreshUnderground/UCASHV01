import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/pdf_service.dart';
import '../../services/printer_service.dart';
import '../../models/client_model.dart';
import '../../models/operation_model.dart';
import '../../models/shop_model.dart';
import '../../services/shop_service.dart';
import '../../services/auth_service.dart';
import '../pdf_viewer_dialog.dart';

class ReleveCompteClientReport extends StatefulWidget {
  final int clientId;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReleveCompteClientReport({
    super.key,
    required this.clientId,
    this.startDate,
    this.endDate,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientInfo(),
          const SizedBox(height: 24),
          _buildSoldeActuel(),
          const SizedBox(height: 24),
          _buildStatistiques(),
          const SizedBox(height: 24),
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
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDC2626),
                  radius: 30,
                  child: Text(
                    client['nom'].toString().isNotEmpty 
                        ? client['nom'].toString()[0].toUpperCase() 
                        : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relevé de Compte',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        client['nom'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      if (client['telephone'] != null)
                        Text(
                          client['telephone'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'UCASH',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Client ID: ${client['id']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (periode['debut'] != null && periode['fin'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Période: ${_formatDate(DateTime.parse(periode['debut']))} - ${_formatDate(DateTime.parse(periode['fin']))}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
          borderRadius: BorderRadius.circular(12),
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
              size: 48,
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
                      fontSize: 32,
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
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Dépôts',
            '${totaux['depots'].toStringAsFixed(2)} USD',
            Icons.add_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Retraits',
            '${totaux['retraits'].toStringAsFixed(2)} USD',
            Icons.remove_circle,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Envoyés',
            '${totaux['envoyes'].toStringAsFixed(2)} USD',
            Icons.send,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Reçus',
            '${totaux['recus'].toStringAsFixed(2)} USD',
            Icons.call_received,
            Colors.purple,
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
            padding: const EdgeInsets.all(16),
            child: Row(
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
                  onPressed: _exportToPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exporter en PDF',
                ),
                IconButton(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print),
                  tooltip: 'Imprimer',
                ),
              ],
            ),
          ),
          
          // Liste des transactions
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _buildTransactionItem(transaction);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final montant = transaction['montant'] as double;
    final commission = transaction['commission'] as double;
    final statut = transaction['statut'] as String;
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
      final periode = _reportData!['periode'] as Map<String, dynamic>;

      // Create client model from data
      final client = ClientModel.fromJson(clientData);

      // Convert transaction data to OperationModel objects
      final operationModels = <OperationModel>[];
      for (var transaction in transactions) {
        if (transaction is Map<String, dynamic>) {
          // Create a minimal OperationModel for PDF generation
          final operation = OperationModel(
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
      
      if (shop == null) {
        throw Exception('Shop non trouvé');
      }

      final effectiveStartDate = widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final effectiveEndDate = widget.endDate ?? DateTime.now();

      // Generate PDF using existing PDF service
      final pdf = await generateClientStatementPdf(
        client: client,
        operations: operationModels,
        shop: shop,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );

      // Afficher l'aperçu du PDF
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdf,
          title: 'Relevé ${client.nom}',
          fileName: 'releve_compte_${client.nom}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
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
      final periode = _reportData!['periode'] as Map<String, dynamic>;

      // Create client model from data
      final client = ClientModel.fromJson(clientData);

      // Convert transaction data to OperationModel objects
      final operationModels = <OperationModel>[];
      for (var transaction in transactions) {
        if (transaction is Map<String, dynamic>) {
          // Create a minimal OperationModel for PDF generation
          final operation = OperationModel(
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
      // TODO: Implement generateClientStatementPdf in PdfService
      // final pdfService = PdfService();
      // final pdf = await pdfService.generateClientStatementPdf(
      //   client: client,
      //   operations: operationModels,
      //   shop: shop ?? ShopModel(...),
      //   startDate: widget.startDate,
      //   endDate: widget.endDate,
      // );

      // Temporary: Show a message instead
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('🚧 Impression en cours de développement'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;

      // Print the PDF
      // await Printing.layoutPdf(
      //   onLayout: (PdfPageFormat format) async => pdf.save(),
      // );

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
}