import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/operation_model.dart';
import '../models/client_model.dart';
import '../models/shop_model.dart';

/// Service PDF pour générer des reçus et rapports d'opérations
class PdfService {
  /// Génère un PDF de reçu pour une opération
  Future<pw.Document> generateReceiptPdf({
    required OperationModel operation,
    ShopModel? shop,
    dynamic agent,  // AgentModel optionnel
    String? clientName,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'UCASH',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      if (shop != null)
                        pw.Text(
                          shop.designation,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'REÇU',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Informations opération
                _buildInfoRow('Type', operation.typeLabel),
                _buildInfoRow('Référence', operation.reference ?? 'N/A'),
                _buildInfoRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(operation.dateOp)),
                
                pw.Divider(),
                
                if (operation.destinataire != null)
                  _buildInfoRow('Destinataire', operation.destinataire!),
                if (operation.clientNom != null)
                  _buildInfoRow('Client', operation.clientNom!),
                
                pw.Divider(),
                
                // Montants
                _buildInfoRow('Montant brut', '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}'),
                if (operation.commission > 0)
                  _buildInfoRow('Commission', '${operation.commission.toStringAsFixed(2)} ${operation.devise}'),
                _buildInfoRow('Montant net', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}', bold: true),
                
                pw.Divider(),
                
                _buildInfoRow('Mode de paiement', operation.modePaiementLabel),
                _buildInfoRow('Statut', operation.statutLabel),
                
                pw.Spacer(),
                
                // Pied de page
                pw.Center(
                  child: pw.Text(
                    'Merci pour votre confiance',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de rapport d'opérations pour un agent
  Future<pw.Document> generateOperationsReportPdf({
    required List<OperationModel> operations,
    required ShopModel shop,
    dynamic agent,  // AgentModel optionnel
    String? filterType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calculs
    final totalBrut = operations.fold<double>(0, (sum, op) => sum + op.montantBrut);
    final totalCommissions = operations.fold<double>(0, (sum, op) => sum + op.commission);
    final totalNet = operations.fold<double>(0, (sum, op) => sum + op.montantNet);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // En-tête
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UCASH', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(shop.designation, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('RAPPORT OPÉRATIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    if (startDate != null && endDate != null)
                      pw.Text(
                        '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Résumé
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Opérations', '${operations.length}'),
                _buildSummaryItem('Total Brut', '${totalBrut.toStringAsFixed(2)} USD'),
                _buildSummaryItem('Commissions', '${totalCommissions.toStringAsFixed(2)} USD'),
                _buildSummaryItem('Total Net', '${totalNet.toStringAsFixed(2)} USD'),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Tableau des opérations
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Destinataire'),
                  _buildTableHeader('Montant'),
                  _buildTableHeader('Statut'),
                ],
              ),
              // Données
              ...operations.map((op) => pw.TableRow(
                children: [
                  _buildTableCell(DateFormat('dd/MM HH:mm').format(op.dateOp)),
                  _buildTableCell(op.typeLabel),
                  _buildTableCell(op.destinataire ?? op.clientNom ?? '-'),
                  _buildTableCell('${op.montantNet.toStringAsFixed(2)} ${op.devise}'),
                  _buildTableCell(op.statutLabel),
                ],
              )),
            ],
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de relevé de compte client
  Future<pw.Document> generateClientStatementPdf({
    required ClientModel client,
    required List<OperationModel> operations,
    required ShopModel shop,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calculer les totaux
    final depotsUSD = operations.where((op) => op.type == OperationType.depot && op.devise == 'USD').fold<double>(0, (sum, op) => sum + op.montantNet);
    final retraitsUSD = operations.where((op) => op.type == OperationType.retrait && op.devise == 'USD').fold<double>(0, (sum, op) => sum + op.montantNet);
    final depotsCDF = operations.where((op) => op.type == OperationType.depot && op.devise == 'CDF').fold<double>(0, (sum, op) => sum + op.montantNet);
    final retraitsCDF = operations.where((op) => op.type == OperationType.retrait && op.devise == 'CDF').fold<double>(0, (sum, op) => sum + op.montantNet);
    
    // Trier les opérations par date
    final sortedOps = List<OperationModel>.from(operations);
    sortedOps.sort((a, b) => a.dateOp.compareTo(b.dateOp));
    
    // Calculer le solde cumulé
    double soldeUSD = 0;
    double soldeCDF = 0;
    final opsWithBalance = sortedOps.map((op) {
      if (op.devise == 'USD') {
        if (op.type == OperationType.depot) {
          soldeUSD += op.montantNet;
        } else if (op.type == OperationType.retrait) {
          soldeUSD -= op.montantNet;
        }
        return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
      } else if (op.devise == 'CDF') {
        if (op.type == OperationType.depot) {
          soldeCDF += op.montantNet;
        } else if (op.type == OperationType.retrait) {
          soldeCDF -= op.montantNet;
        }
        return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
      }
      return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
    }).toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // En-tête UCASH
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UCASH', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(shop.designation, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                  ],
                ),
                pw.Text(
                  'RELEVÉ DE COMPTE',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Informations client
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  client.nom.toUpperCase(),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('N° Compte: ${client.numeroCompte}', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text('Téléphone: ${client.telephone}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    if (startDate != null && endDate != null)
                      pw.Text(
                        'Période: Du ${DateFormat('dd/MM/yyyy').format(startDate)} au ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // RÉSUMÉ DES MOUVEMENTS
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RÉSUMÉ DES MOUVEMENTS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    if (depotsUSD > 0 || retraitsUSD > 0)
                      pw.Column(
                        children: [
                          pw.Text('Dépôts USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${depotsUSD.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsUSD > 0 || retraitsUSD > 0)
                      pw.Column(
                        children: [
                          pw.Text('Retraits USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${retraitsUSD.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsUSD > 0 || retraitsUSD > 0)
                      pw.Column(
                        children: [
                          pw.Text('Solde USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${(depotsUSD - retraitsUSD).toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Dépôts CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${depotsCDF.toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Retraits CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${retraitsCDF.toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Solde CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${(depotsCDF - retraitsCDF).toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // HISTORIQUE DES TRANSACTIONS
          pw.Text(
            'HISTORIQUE DES TRANSACTIONS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),  // Date
              1: const pw.FlexColumnWidth(1.5),  // Type
              2: const pw.FlexColumnWidth(2.5),  // Observation
              3: const pw.FlexColumnWidth(1.5),  // Reçu
              4: const pw.FlexColumnWidth(1.5),  // Payé
              5: const pw.FlexColumnWidth(1.5),  // Solde
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Observation'),
                  _buildTableHeader('Reçu (Dépôt)'),
                  _buildTableHeader('Payé (Retrait)'),
                  _buildTableHeader('Cumul'),
                ],
              ),
              // Données
              ...opsWithBalance.map((item) {
                final op = item['op'] as OperationModel;
                final soldeU = item['soldeUSD'] as double;
                final soldeC = item['soldeCDF'] as double;
                final isDepo = op.type == OperationType.depot;
                final devise = op.devise == 'USD' ? '\$' : 'FC';
                final soldeActuel = op.devise == 'USD' ? soldeU : soldeC;
                
                return pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('dd/MM/yyyy').format(op.dateOp)),
                    _buildTableCell(op.type == OperationType.depot ? 'Dépôt' : 'Retrait'),
                    _buildTableCell(op.notes ?? op.destinataire ?? '-'),
                    _buildTableCell(isDepo ? '${op.montantNet.toStringAsFixed(2)} $devise' : '--'),
                    _buildTableCell(!isDepo ? '${op.montantNet.toStringAsFixed(2)} $devise' : '--'),
                    _buildTableCell('${soldeActuel.toStringAsFixed(2)} $devise'),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Pied de page
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Édité le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'UCASH - ${shop.designation}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  // Helpers
  pw.Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
  
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
  
  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }
}
