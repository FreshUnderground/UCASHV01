import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../models/shop_model.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/client_model.dart';

/// Génère un PDF de rapport de clôture journalière inspiré de l'UI
Future<pw.Document> generateDailyClosureReportPdf({
  required RapportClotureModel rapport,
  required ShopModel shop,
}) async {
  final pdf = pw.Document();
  
  final formattedDate = DateFormat('dd/MM/yyyy').format(rapport.dateRapport);
  
  // PAGE UNIQUE - Structure claire comme l'UI
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // EN-TÊTE - Style UCASH
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.red700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
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
                    pw.Text(
                      shop.designation,
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'RAPPORT DE CLÔTURE',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      formattedDate,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.yellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // CASH DISPONIBLE - Carte principale verte (comme l'UI)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green700, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '💰 CASH DISPONIBLE TOTAL',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '${rapport.cashDisponibleTotal.toStringAsFixed(2)} USD',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.Divider(color: PdfColors.green700),
                pw.SizedBox(height: 8),
                _buildRow('Cash', rapport.cashDisponibleCash),
                _buildRow('Airtel Money', rapport.cashDisponibleAirtelMoney),
                _buildRow('M-Pesa', rapport.cashDisponibleMPesa),
                _buildRow('Orange Money', rapport.cashDisponibleOrangeMoney),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // DEUX COLONNES - Comme l'UI
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // COLONNE GAUCHE
              pw.Expanded(
                child: pw.Column(
                  children: [
                    // Solde Antérieur
                    _buildSection(
                      '1️⃣ Solde Antérieur',
                      [
                        _buildRow('Cash', rapport.soldeAnterieurCash),
                        _buildRow('Airtel Money', rapport.soldeAnterieurAirtelMoney),
                        _buildRow('M-Pesa', rapport.soldeAnterieurMPesa),
                        _buildRow('Orange Money', rapport.soldeAnterieurOrangeMoney),
                        pw.Divider(),
                        _buildRow('TOTAL', rapport.soldeAnterieurTotal, bold: true),
                      ],
                      PdfColors.grey700,
                    ),
                    pw.SizedBox(height: 12),
                    // FLOT
                    _buildSection(
                      '2️⃣ Flots',
                      [
                        _buildRow('Reçus', rapport.flotRecu, color: PdfColors.green700),
                        _buildRow('En cours', rapport.flotEnCours, color: PdfColors.orange700),
                        _buildRow('Servis', rapport.flotServi, color: PdfColors.red700, prefix: '-'),
                                        
                        // Détails des FLOTs reçus
                        if (rapport.flotsRecusDetails.isNotEmpty) ...[
                          pw.SizedBox(height: 8),
                          pw.Text('FLOTs Reçus Détails:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(),
                          ...rapport.flotsRecusDetails.map((flot) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('${flot.shopSourceDesignation}', style: pw.TextStyle(fontSize: 8)),
                                      pw.Text('${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                                    ],
                                  ),
                                ),
                                pw.Text(
                                  '${flot.montant.toStringAsFixed(2)} USD',
                                  style: pw.TextStyle(
                                    color: PdfColors.green700,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ],
                                        
                        // Détails des FLOTs envoyés
                        if (rapport.flotsEnvoyes.isNotEmpty) ...[
                          pw.SizedBox(height: 8),
                          pw.Text('FLOTs Envoyés Détails:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(),
                          ...rapport.flotsEnvoyes.map((flot) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('${flot.shopDestinationDesignation}', style: pw.TextStyle(fontSize: 8)),
                                      pw.Text('${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement} (${flot.statut})', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                                    ],
                                  ),
                                ),
                                pw.Text(
                                  '${flot.montant.toStringAsFixed(2)} USD',
                                  style: pw.TextStyle(
                                    color: PdfColors.red700,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ],
                                        
                        // Détails des FLOTs en cours
                        if (rapport.flotsEnCoursDetails.isNotEmpty) ...[
                          pw.SizedBox(height: 8),
                          pw.Text('FLOTs En Cours Détails:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(),
                          ...rapport.flotsEnCoursDetails.map((flot) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('${flot.shopDestinationDesignation}', style: pw.TextStyle(fontSize: 8)),
                                      pw.Text('${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                                    ],
                                  ),
                                ),
                                pw.Text(
                                  '${flot.montant.toStringAsFixed(2)} USD',
                                  style: pw.TextStyle(
                                    color: PdfColors.orange700,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ],
                      ],
                      PdfColors.purple700,
                    ),
                    pw.SizedBox(height: 12),
                    // Transferts
                    _buildSection(
                      '3️⃣ Transferts',
                      [
                        _buildRow('Reçus', rapport.transfertsRecus, color: PdfColors.green700),
                        _buildRow('Servis', rapport.transfertsServis, color: PdfColors.red700, prefix: '-'),
                      ],
                      PdfColors.blue700,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              // COLONNE DROITE
              pw.Expanded(
                child: pw.Column(
                  children: [
                    // Opérations Clients
                    _buildSection(
                      '4️⃣ Opérations Clients',
                      [
                        _buildRow('Dépôts', rapport.depotsClients, color: PdfColors.green700),
                        _buildRow('Retraits', rapport.retraitsClients, color: PdfColors.red700, prefix: '-'),
                      ],
                      PdfColors.orange700,
                    ),
                    pw.SizedBox(height: 12),
                    // Clients Nous Doivent
                    _buildSection(
                      '5️⃣ Clients Nous Doivent',
                      [
                        pw.Text('${rapport.clientsNousDoivent.length} client(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        // Show detailed client list like UI
                        ...rapport.clientsNousDoivent.map((client) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text(client.nom, style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Text(
                                '${client.solde.toStringAsFixed(2)} USD',
                                style: pw.TextStyle(
                                  color: PdfColors.red700,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        pw.Divider(),
                        _buildRow('TOTAL Dettes', rapport.totalClientsNousDoivent, color: PdfColors.red700, bold: true),
                      ],
                      PdfColors.red700,
                    ),
                    pw.SizedBox(height: 12),
                    // Clients Nous Devons
                    _buildSection(
                      '6️⃣ Clients Nous Devons',
                      [
                        pw.Text('${rapport.clientsNousDevons.length} client(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        // Show detailed client list like UI
                        ...rapport.clientsNousDevons.map((client) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text(client.nom, style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Text(
                                '${client.solde.toStringAsFixed(2)} USD',
                                style: pw.TextStyle(
                                  color: PdfColors.green700,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        pw.Divider(),
                        _buildRow('TOTAL Créances', rapport.totalClientsNousDevons, color: PdfColors.green700, bold: true),
                      ],
                      PdfColors.green700,
                    ),
                    pw.SizedBox(height: 12),
                    // Shops Nous Doivent
                    _buildSection(
                      '7️⃣ Shops Nous Doivent',
                      [
                        pw.Text('${rapport.shopsNousDoivent.length} shop(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        // Show detailed shop list like UI
                        ...rapport.shopsNousDoivent.map((shop) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text('${shop.designation} (${shop.localisation})', style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Text(
                                '${shop.montant.toStringAsFixed(2)} USD',
                                style: pw.TextStyle(
                                  color: PdfColors.orange700,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        pw.Divider(),
                        _buildRow('TOTAL', rapport.totalShopsNousDoivent, color: PdfColors.orange700, bold: true),
                      ],
                      PdfColors.orange700,
                    ),
                    pw.SizedBox(height: 12),
                    // Shops Nous Devons
                    _buildSection(
                      '8️⃣ Shops Nous Devons',
                      [
                        pw.Text('${rapport.shopsNousDevons.length} shop(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        // Show detailed shop list like UI
                        ...rapport.shopsNousDevons.map((shop) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text('${shop.designation} (${shop.localisation})', style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Text(
                                '${shop.montant.toStringAsFixed(2)} USD',
                                style: pw.TextStyle(
                                  color: PdfColors.purple700,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        pw.Divider(),
                        _buildRow('TOTAL', rapport.totalShopsNousDevons, color: PdfColors.purple700, bold: true),
                      ],
                      PdfColors.purple700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 16),
          
          // CAPITAL NET - Carte finale bleue (comme l'UI)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              border: pw.Border.all(color: PdfColors.blue700, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '📈 CAPITAL NET FINAL',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Formule: Cash Disponible + Ceux qui nous doivent - Ceux que nous devons',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '${rapport.capitalNet.toStringAsFixed(2)} USD',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: rapport.capitalNet >= 0 ? PdfColors.blue900 : PdfColors.red900,
                  ),
                ),
                pw.Divider(color: PdfColors.blue700),
                pw.SizedBox(height: 8),
                _buildRow('Cash Disponible', rapport.cashDisponibleTotal, color: PdfColors.green700),
                _buildRow('+ Clients Nous Doivent', rapport.totalClientsNousDoivent, color: PdfColors.red700),
                _buildRow('+ Shops Nous Doivent', rapport.totalShopsNousDoivent, color: PdfColors.orange700),
                _buildRow('- Clients Nous Devons', -rapport.totalClientsNousDevons, color: PdfColors.green700),
                _buildRow('- Shops Nous Devons', -rapport.totalShopsNousDevons, color: PdfColors.purple700),
                pw.Divider(thickness: 2, color: PdfColors.blue700),
                _buildRow('= CAPITAL NET', rapport.capitalNet, color: rapport.capitalNet >= 0 ? PdfColors.blue700 : PdfColors.red700, bold: true),
              ],
            ),
          ),
          
          pw.Spacer(),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Généré par: ${rapport.generePar ?? "Système"}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Le ${DateFormat('dd/MM/yyyy HH:mm').format(rapport.dateGeneration)}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  return pdf;
}

/// Section avec bordure colorée - Comme les Card dans l'UI
pw.Widget _buildSection(String title, List<pw.Widget> children, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color, width: 1.5),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

/// Ligne de données - Comme dans l'UI
pw.Widget _buildRow(String label, double montant, {bool bold = false, PdfColor? color, String prefix = ''}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: bold ? 11 : 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '$prefix${montant.toStringAsFixed(2)} USD',
          style: pw.TextStyle(
            fontSize: bold ? 11 : 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Classe PdfService pour compatibilité avec le code existant
class PdfService {
  /// Génère un PDF de reçu pour une opération
  Future<pw.Document> generateReceiptPdf({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Column(
          children: [
            // En-tête UCASH
            pw.Text(
              'UCASH',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              shop.designation,
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Agent: ${agent.nom ?? agent.username}',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            
            // Informations de l'opération
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Opération:', style: pw.TextStyle(fontSize: 10)),
                pw.Text(operation.typeLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:', style: pw.TextStyle(fontSize: 10)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(operation.dateOp), style: pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ID:', style: pw.TextStyle(fontSize: 10)),
                pw.Text(operation.id?.toString() ?? 'N/A', style: pw.TextStyle(fontSize: 10)),
              ],
            ),
            
            pw.SizedBox(height: 8),
            pw.Divider(),
            
            // Montants
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Montant:', style: pw.TextStyle(fontSize: 10)),
                pw.Text('${operation.montantBrut.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            if (operation.commission > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Commission:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text('${operation.commission.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Montant Net:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('${operation.montantNet.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            
            pw.SizedBox(height: 8),
            pw.Divider(),
            
            // Informations client
            if (clientName != null)
              pw.Column(
                children: [
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Client:', style: pw.TextStyle(fontSize: 10)),
                      pw.Text(clientName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              
            if (operation.destinataire != null)
              pw.Column(
                children: [
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Destinataire:', style: pw.TextStyle(fontSize: 10)),
                      pw.Text(operation.destinataire!, style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              
            if (operation.observation != null)
              pw.Column(
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text('Observation:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(operation.observation!, style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              
            if (operation.notes != null)
              pw.Column(
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text('Notes:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(operation.notes!, style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              
            pw.SizedBox(height: 16),
            pw.Divider(),
            
            // Message de remerciement
            pw.SizedBox(height: 8),
            pw.Text(
              'Merci de votre confiance!',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Service rendu le ${DateFormat('dd/MM/yyyy').format(operation.dateOp)}',
              style: pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            
            pw.SizedBox(height: 8),
            pw.Text(
              '----------------',
              style: pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
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
    double totalDepots = 0;
    double totalRetraits = 0;
    double totalEnvoyes = 0;
    double totalRecus = 0;
    double soldeActuel = 0;
    
    for (var op in operations) {
      switch (op.type) {
        case OperationType.depot:
          totalDepots += op.montantNet;
          soldeActuel += op.montantNet;
          break;
        case OperationType.retrait:
          totalRetraits += op.montantNet;
          soldeActuel -= op.montantNet;
          break;
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          totalEnvoyes += op.montantNet;
          soldeActuel -= op.montantNet;
          break;
        case OperationType.transfertInternationalEntrant:
          totalRecus += op.montantNet;
          soldeActuel += op.montantNet;
          break;
        default:
          break;
      }
    }
    
    final formattedStartDate = startDate != null ? DateFormat('dd/MM/yyyy').format(startDate) : 'Début';
    final formattedEndDate = endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Aujourd\'hui';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
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
                      pw.Text(
                        shop.designation,
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RELEVÉ DE COMPTE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        '${formattedStartDate} - ${formattedEndDate}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // Informations client
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    client.nom,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'N° Compte: ${client.numeroCompte ?? client.id}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  if (client.telephone != null)
                    pw.Text(
                      'Téléphone: ${client.telephone}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Divider(),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Période: Du ${formattedStartDate} au ${formattedEndDate}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // Résumé des mouvements
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Dépôts USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('${totalDepots.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Retraits USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('${totalRetraits.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, color: PdfColors.orange700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Solde USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('${soldeActuel.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, color: soldeActuel >= 0 ? PdfColors.green700 : PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 16),
            
            // Historique des transactions
            pw.SizedBox(height: 16),
            pw.Text(
              'HISTORIQUE DES TRANSACTIONS',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            
            // Calculate running balance
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', bold: true),
                    _buildTableCell('Type', bold: true),
                    _buildTableCell('Observation', bold: true),
                    _buildTableCell('Reçu (Dépôt)', bold: true),
                    _buildTableCell('Payé (Retrait)', bold: true),
                    _buildTableCell('Solde USD', bold: true),
                  ],
                ),
                ...(() {
                  double runningBalance = 0;
                  List<pw.TableRow> rows = [];
                  
                  // Sort operations by date
                  final sortedOperations = List<OperationModel>.from(operations)
                    ..sort((a, b) => a.dateOp.compareTo(b.dateOp));
                  
                  for (var op in sortedOperations.take(40)) {
                    bool isCredit = op.type == OperationType.depot || 
                                   op.type == OperationType.transfertInternationalEntrant;
                    
                    if (isCredit) {
                      runningBalance += op.montantNet;
                    } else {
                      runningBalance -= op.montantNet;
                    }
                    
                    rows.add(pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('dd/MM/yyyy').format(op.dateOp)),
                        _buildTableCell(_getTypeLabel(op.type)),
                        _buildTableCell(op.destinataire ?? op.observation ?? '-'),
                        _buildTableCell(isCredit ? '${op.montantNet.toStringAsFixed(2)} \$' : '--', 
                                      color: isCredit ? PdfColors.green700 : null),
                        _buildTableCell(!isCredit ? '${op.montantNet.toStringAsFixed(2)} \$' : '--', 
                                      color: !isCredit ? PdfColors.red700 : null),
                        _buildTableCell('${runningBalance.toStringAsFixed(2)} \$', 
                                      color: runningBalance >= 0 ? PdfColors.green700 : PdfColors.red700),
                      ],
                    ));
                  }
                  return rows;
                })(),
              ],
            ),
            
            if (operations.length > 40)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '... et ${operations.length - 40} autre(s) transaction(s)',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ),
              
            pw.Spacer(),
            
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Page 1 sur 1',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de rapport d'opérations
  Future<pw.Document> generateOperationsReportPdf({
    required List<OperationModel> operations,
    required ShopModel shop,
    required AgentModel agent,
    String? filterType,
  }) async {
    final pdf = pw.Document();
    
    // Calculer les totaux
    double totalDepots = 0;
    double totalRetraits = 0;
    double totalTransferts = 0;
    
    for (var op in operations) {
      if (op.type == OperationType.depot) {
        totalDepots += op.montantNet;
      } else if (op.type == OperationType.retrait) {
        totalRetraits += op.montantNet;
      } else if (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant || op.type == OperationType.transfertInternationalEntrant) {
        totalTransferts += op.montantNet;
      }
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
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
                      pw.Text(
                        shop.designation,
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                      ),
                      pw.Text(
                        'Agent: ${agent.nom ?? agent.username}',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey300),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RAPPORT D\'OPÉRATIONS',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // Statistiques
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Dépôts', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${totalDepots.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Retraits', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${totalRetraits.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, color: PdfColors.orange700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.purple50,
                      border: pw.Border.all(color: PdfColors.purple700),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Transferts', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${totalTransferts.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, color: PdfColors.purple700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 16),
            
            // Tableau des opérations
            pw.Text(
              'Liste des opérations (${operations.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', bold: true),
                    _buildTableCell('Destinataire', bold: true),
                    _buildTableCell('Type', bold: true),
                    _buildTableCell('Mode', bold: true),
                    _buildTableCell('Montant', bold: true),
                  ],
                ),
                ...operations.take(30).map((op) => pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('dd/MM HH:mm').format(op.dateOp)),
                    _buildTableCell(op.destinataire ?? op.clientNom ?? '-'),
                    _buildTableCell(_getTypeLabel(op.type)),
                    _buildTableCell(_getModeLabel(op.modePaiement)),
                    _buildTableCell('${op.montantNet.toStringAsFixed(2)} \$'),
                  ],
                )),
              ],
            ),
            
            if (operations.length > 30)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '... et ${operations.length - 30} autre(s) opération(s)',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de journal de caisse
  Future<pw.Document> generateJournalCaisseReportPdf({
    required List<JournalCaisseModel> entries,
    required ShopModel shop,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calculer les totaux
    double totalEntrees = 0;
    double totalSorties = 0;
    
    for (var entry in entries) {
      if (entry.type == TypeMouvement.entree) {
        totalEntrees += entry.montant;
      } else {
        totalSorties += entry.montant;
      }
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
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
                      pw.Text(
                        shop.designation,
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'JOURNAL DE CAISSE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // Statistiques
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green700, width: 2),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('💰 Entrées', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${totalEntrees.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 16, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(color: PdfColors.red700, width: 2),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('📤 Sorties', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${totalSorties.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 16, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue700, width: 2),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('📊 Solde', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${(totalEntrees - totalSorties).toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 16, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 16),
            
            // Tableau du journal
            pw.Text(
              'Mouvements (${entries.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', bold: true),
                    _buildTableCell('Libellé', bold: true),
                    _buildTableCell('Type', bold: true),
                    _buildTableCell('Mode', bold: true),
                    _buildTableCell('Montant', bold: true),
                  ],
                ),
                ...entries.take(35).map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('dd/MM HH:mm').format(entry.dateAction)),
                    _buildTableCell(entry.libelle),
                    _buildTableCell(entry.type == TypeMouvement.entree ? 'Entrée' : 'Sortie'),
                    _buildTableCell(_getModeLabel(entry.mode)),
                    _buildTableCell(
                      '${entry.montant.toStringAsFixed(2)} \$',
                      color: entry.type == TypeMouvement.entree ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                )),
              ],
            ),
            
            if (entries.length > 35)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '... et ${entries.length - 35} autre(s) mouvement(s)',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
    
    return pdf;
  }
}

/// Cellule de tableau
pw.Widget _buildTableCell(String text, {bool bold = false, PdfColor? color}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

/// Obtenir le libellé du type d'opération
String _getTypeLabel(OperationType type) {
  switch (type) {
    case OperationType.depot:
      return 'Dépôt';
    case OperationType.retrait:
      return 'Retrait';
    case OperationType.transfertNational:
      return 'Transfert';
    case OperationType.transfertInternationalSortant:
      return 'Transf. Int. Sortant';
    case OperationType.transfertInternationalEntrant:
      return 'Transf. Int. Entrant';
    case OperationType.virement:
      return 'Virement';
  }
}

/// Obtenir le libellé du mode de paiement
String _getModeLabel(ModePaiement mode) {
  switch (mode) {
    case ModePaiement.cash:
      return 'Cash';
    case ModePaiement.airtelMoney:
      return 'Airtel';
    case ModePaiement.mPesa:
      return 'M-Pesa';
    case ModePaiement.orangeMoney:
      return 'Orange';
  }
}