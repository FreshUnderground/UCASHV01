import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/journal_caisse_model.dart';
import '../models/flot_model.dart';
import '../models/shop_model.dart';

/// Service pour générer les PDFs des rapports (Journal Caisse, Commissions, FLOT)

// ============================================================================
// 1. JOURNAL DE CAISSE PDF
// ============================================================================

Future<pw.Document> generateJournalCaisseReportPdf({
  required List<JournalCaisseModel> entries,
  required ShopModel shop,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final pdf = pw.Document();
  
  final formattedStartDate = DateFormat('dd/MM/yyyy').format(startDate);
  final formattedEndDate = DateFormat('dd/MM/yyyy').format(endDate);
  
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
  
  final solde = totalEntrees - totalSorties;
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => [
        // EN-TÊTE
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.red700,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('UCASH', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text(shop.designation, style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('JOURNAL DE CAISSE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('$formattedStartDate - $formattedEndDate', style: pw.TextStyle(fontSize: 10, color: PdfColors.yellow)),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // RÉSUMÉ
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('ENTRÉES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('${totalEntrees.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('SORTIES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text('${totalSorties.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: solde >= 0 ? PdfColors.blue50 : PdfColors.orange50,
                  border: pw.Border.all(color: solde >= 0 ? PdfColors.blue700 : PdfColors.orange700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('SOLDE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: solde >= 0 ? PdfColors.blue800 : PdfColors.orange800)),
                    pw.Text('${solde.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: solde >= 0 ? PdfColors.blue900 : PdfColors.orange900)),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        // TABLEAU DES MOUVEMENTS
        pw.Text('MOUVEMENTS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // En-tête
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeaderCell('Date'),
                _buildTableHeaderCell('Libellé'),
                _buildTableHeaderCell('Mode'),
                _buildTableHeaderCell('Entrée'),
                _buildTableHeaderCell('Sortie'),
              ],
            ),
            // Données
            ...entries.map((entry) => pw.TableRow(
              children: [
                _buildTableCell(DateFormat('dd/MM/yy HH:mm').format(entry.dateAction)),
                _buildTableCell(entry.libelle, maxLines: 2),
                _buildTableCell(entry.modeLabel),
                _buildTableCell(
                  entry.type == TypeMouvement.entree ? '${entry.montant.toStringAsFixed(2)}' : '',
                  color: PdfColors.green700,
                ),
                _buildTableCell(
                  entry.type == TypeMouvement.sortie ? '${entry.montant.toStringAsFixed(2)}' : '',
                  color: PdfColors.red700,
                ),
              ],
            )),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        // PIED DE PAGE
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'Total: ${entries.length} mouvement(s) - Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// 2. RAPPORT COMMISSIONS PDF
// ============================================================================

Future<pw.Document> generateCommissionsReportPdf({
  required Map<String, dynamic> reportData,
  required DateTime? startDate,
  required DateTime? endDate,
}) async {
  final pdf = pw.Document();
  
  final totalCommissions = reportData['totalCommissions'] as double;
  final operations = reportData['operations'] as List<Map<String, dynamic>>;
  final commissionsParType = reportData['commissionsParType'] as Map<String, double>;
  
  final formattedStartDate = startDate != null ? DateFormat('dd/MM/yyyy').format(startDate) : 'Début';
  final formattedEndDate = endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Fin';
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => [
        // EN-TÊTE
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.green700,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('UCASH', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('Rapport Commissions', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('${totalCommissions.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // PÉRIODE
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text('Période: $formattedStartDate - $formattedEndDate', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900)),
        ),
        
        pw.SizedBox(height: 10),
        
        // COMMISSIONS PAR TYPE
        pw.Text('COMMISSIONS PAR TYPE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        
        _buildCommissionTypeRow('Transferts Nationaux', commissionsParType['transfertNational'] ?? 0, PdfColors.blue700),
        _buildCommissionTypeRow('Transferts Int. Sortants', commissionsParType['transfertInternationalSortant'] ?? 0, PdfColors.purple700),
        _buildCommissionTypeRow('Transferts Int. Entrants', commissionsParType['transfertInternationalEntrant'] ?? 0, PdfColors.teal700),
        
        pw.SizedBox(height: 10),
        
        // LISTE DES OPÉRATIONS
        pw.Text('DÉTAIL DES OPÉRATIONS (${operations.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeaderCell('Date'),
                _buildTableHeaderCell('Type'),
                _buildTableHeaderCell('Montant'),
                _buildTableHeaderCell('Commission'),
              ],
            ),
            ...operations.take(50).map((op) => pw.TableRow(
              children: [
                _buildTableCell(DateFormat('dd/MM/yy').format(op['date'] as DateTime)),
                _buildTableCell(_getTypeLabel(op['type'] as String)),
                _buildTableCell('${op['montant'].toStringAsFixed(2)}'),
                _buildTableCell('${op['commission'].toStringAsFixed(2)}', color: PdfColors.green700, bold: true),
              ],
            )),
          ],
        ),
        
        if (operations.length > 50)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            margin: const pw.EdgeInsets.only(top: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('... et ${operations.length - 50} autres opérations', style: pw.TextStyle(fontSize: 8, color: PdfColors.orange800)),
          ),
        
        pw.SizedBox(height: 10),
        
        // PIED DE PAGE
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// 3. RAPPORT FLOT PDF
// ============================================================================

Future<pw.Document> generateFlotReportPdf({
  required List<FlotModel> flots,
  required DateTime? startDate,
  required DateTime? endDate,
}) async {
  final pdf = pw.Document();
  
  final formattedStartDate = startDate != null ? DateFormat('dd/MM/yyyy').format(startDate) : 'Début';
  final formattedEndDate = endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Fin';
  
  // Calculer les totaux
  double totalEnRoute = 0;
  double totalServis = 0;
  double totalAnnules = 0;
  
  for (var flot in flots) {
    switch (flot.statut) {
      case StatutFlot.enRoute:
        totalEnRoute += flot.montant;
        break;
      case StatutFlot.servi:
        totalServis += flot.montant;
        break;
      case StatutFlot.annule:
        totalAnnules += flot.montant;
        break;
    }
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => [
        // EN-TÊTE
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple700,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('UCASH', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('Rapport FLOT', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('TOTAL FLOTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('${flots.length}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // PÉRIODE
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text('Période: $formattedStartDate - $formattedEndDate', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900)),
        ),
        
        pw.SizedBox(height: 10),
        
        // STATISTIQUES
        pw.Text('STATISTIQUES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('EN ROUTE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    pw.Text('${totalEnRoute.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('SERVIS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('${totalServis.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('ANNULÉS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text('${totalAnnules.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        // LISTE DES FLOTS
        pw.Text('DÉTAIL DES FLOTS (${flots.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeaderCell('Date'),
                _buildTableHeaderCell('Source'),
                _buildTableHeaderCell('Destination'),
                _buildTableHeaderCell('Montant'),
                _buildTableHeaderCell('Statut'),
              ],
            ),
            ...flots.map((flot) => pw.TableRow(
              children: [
                _buildTableCell(DateFormat('dd/MM/yy').format(flot.dateEnvoi)),
                _buildTableCell(flot.shopSourceDesignation, maxLines: 2),
                _buildTableCell(flot.shopDestinationDesignation, maxLines: 2),
                _buildTableCell('${flot.montant.toStringAsFixed(2)}', bold: true),
                _buildTableCell(
                  flot.statutLabel,
                  color: flot.statut == StatutFlot.servi ? PdfColors.green700 : 
                         flot.statut == StatutFlot.enRoute ? PdfColors.orange700 : PdfColors.red700,
                ),
              ],
            )),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        // PIED DE PAGE
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

pw.Widget _buildTableHeaderCell(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildTableCell(String text, {PdfColor? color, bool bold = false, int maxLines = 1}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        color: color ?? PdfColors.grey800,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      maxLines: maxLines,
      overflow: pw.TextOverflow.clip,
    ),
  );
}

pw.Widget _buildCommissionTypeRow(String label, double amount, PdfColor color) {
  // Créer une couleur claire pour le fond (pas de withOpacity dans pdf package)
  final backgroundColor = PdfColors.grey50;  // Couleur de fond neutre
  
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    margin: const pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      color: backgroundColor,
      border: pw.Border.all(color: color),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color)),
        pw.Text('${amount.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    ),
  );
}

String _getTypeLabel(String type) {
  switch (type) {
    case 'depot':
      return 'Dépôt';
    case 'retrait':
      return 'Retrait';
    case 'transfertNational':
      return 'Transfert National';
    case 'transfertInternationalSortant':
      return 'Transfert Int. Sortant';
    case 'transfertInternationalEntrant':
      return 'Transfert Int. Entrant';
    default:
      return type;
  }
}
