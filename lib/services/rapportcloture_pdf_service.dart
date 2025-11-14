import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../models/shop_model.dart';

/// Génère un PDF IDENTIQUE au UI - NI PLUS NI MOINS
Future<pw.Document> generateRapportCloturePdf({
  required RapportClotureModel rapport,
  required ShopModel shop,
}) async {
  final pdf = pw.Document();
  
  final formattedDate = DateFormat('dd/MM/yyyy').format(rapport.dateRapport);
  
  print('=== GÉNÉRATION PDF RAPPORT CLOTURE ===');
  print('Date: $formattedDate');
  print('Shop: ${shop.designation}');
  print('Cash Disponible Total: ${rapport.cashDisponibleTotal}');
  print('FLOTs Reçus: ${rapport.flotsRecusDetails.length}');
  print('FLOTs Envoyés: ${rapport.flotsEnvoyes.length}');
  print('FLOTs En Cours: ${rapport.flotsEnCoursDetails.length}');
  print('Clients Nous Doivent: ${rapport.clientsNousDoivent.length}');
  print('Clients Nous Devons: ${rapport.clientsNousDevons.length}');
  print('Shops Nous Doivent: ${rapport.shopsNousDoivent.length}');
  print('Shops Nous Devons: ${rapport.shopsNousDevons.length}');
  print('=====================================');
  
  // Utiliser MultiPage pour permettre le contenu de s'étendre sur plusieurs pages
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
                    pw.Text('RAPPORT DE CLOTURE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(formattedDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          // CASH DISPONIBLE TOTAL
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green700, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text('CASH DISPONIBLE TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                pw.SizedBox(height: 6),
                pw.Text('${rapport.cashDisponibleTotal.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.Divider(color: PdfColors.green700),
                _buildRow('Cash', rapport.cashDisponibleCash),
                _buildRow('Airtel Money', rapport.cashDisponibleAirtelMoney),
                _buildRow('M-Pesa', rapport.cashDisponibleMPesa),
                _buildRow('Orange Money', rapport.cashDisponibleOrangeMoney),
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          // DEUX COLONNES
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // COLONNE GAUCHE
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildSection('1. Solde Anterieur', [
                      _buildRow('Cash', rapport.soldeAnterieurCash),
                      _buildRow('Airtel Money', rapport.soldeAnterieurAirtelMoney),
                      _buildRow('M-Pesa', rapport.soldeAnterieurMPesa),
                      _buildRow('Orange Money', rapport.soldeAnterieurOrangeMoney),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.soldeAnterieurTotal, bold: true),
                    ], PdfColors.grey700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('2. Flots', [
                      _buildRow('Recus', rapport.flotRecu, color: PdfColors.green700),
                      _buildRow('En cours', rapport.flotEnCours, color: PdfColors.orange700),
                      _buildRow('Servis', rapport.flotServi, color: PdfColors.red700, prefix: '-'),
                      if (rapport.flotsRecusDetails.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs Recus Details:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsRecusDetails.map((flot) => _buildDetailRow(flot.shopSourceDesignation, '${DateFormat('dd/MM').format(flot.dateEnvoi)}', flot.montant, PdfColors.green700)),
                      ],
                      if (rapport.flotsEnvoyes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs Envoyes Details:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsEnvoyes.map((flot) => _buildDetailRow(flot.shopDestinationDesignation, '${DateFormat('dd/MM').format(flot.dateEnvoi)}', flot.montant, PdfColors.red700)),
                      ],
                      if (rapport.flotsEnCoursDetails.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs En Cours Details:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsEnCoursDetails.map((flot) => _buildDetailRow(flot.shopDestinationDesignation, '${DateFormat('dd/MM').format(flot.dateEnvoi)}', flot.montant, PdfColors.orange700)),
                      ],
                    ], PdfColors.purple700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('3. Transferts', [
                      _buildRow('Recus', rapport.transfertsRecus, color: PdfColors.green700),
                      _buildRow('Servis', rapport.transfertsServis, color: PdfColors.red700, prefix: '-'),
                    ], PdfColors.blue700),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              
              // COLONNE DROITE
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildSection('4. Operations Clients', [
                      _buildRow('Depots', rapport.depotsClients, color: PdfColors.green700),
                      _buildRow('Retraits', rapport.retraitsClients, color: PdfColors.red700, prefix: '-'),
                    ], PdfColors.orange700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('5. Clients Nous Doivent', [
                      pw.Text('${rapport.clientsNousDoivent.length} client(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      ...rapport.clientsNousDoivent.map((c) => _buildDetailRow(c.nom, '', c.solde, PdfColors.red700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalClientsNousDoivent, color: PdfColors.red700, bold: true),
                    ], PdfColors.red700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('6. Clients Nous Devons', [
                      pw.Text('${rapport.clientsNousDevons.length} client(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      ...rapport.clientsNousDevons.map((c) => _buildDetailRow(c.nom, '', c.solde, PdfColors.green700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalClientsNousDevons, color: PdfColors.green700, bold: true),
                    ], PdfColors.green700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('7. Shops Nous Doivent', [
                      pw.Text('${rapport.shopsNousDoivent.length} shop(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      ...rapport.shopsNousDoivent.map((s) => _buildDetailRow(s.designation, s.localisation, s.montant, PdfColors.orange700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalShopsNousDoivent, color: PdfColors.orange700, bold: true),
                    ], PdfColors.orange700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('8. Shops Nous Devons', [
                      pw.Text('${rapport.shopsNousDevons.length} shop(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      ...rapport.shopsNousDevons.map((s) => _buildDetailRow(s.designation, s.localisation, s.montant, PdfColors.purple700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalShopsNousDevons, color: PdfColors.purple700, bold: true),
                    ], PdfColors.purple700),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 10),
          
          // CAPITAL NET FINAL
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text('CAPITAL NET FINAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('Formule: Cash Disponible + Ceux qui nous doivent - Ceux que nous devons', style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 6),
                pw.Text('${rapport.capitalNet.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: rapport.capitalNet >= 0 ? PdfColors.blue900 : PdfColors.red900)),
                pw.Divider(),
                _buildRow('Cash Disponible', rapport.cashDisponibleTotal, color: PdfColors.green700),
                _buildRow('+ Clients Nous Doivent', rapport.totalClientsNousDoivent, color: PdfColors.red700),
                _buildRow('+ Shops Nous Doivent', rapport.totalShopsNousDoivent, color: PdfColors.orange700),
                _buildRow('- Clients Nous Devons', -rapport.totalClientsNousDevons, color: PdfColors.green700),
                _buildRow('- Shops Nous Devons', -rapport.totalShopsNousDevons, color: PdfColors.purple700),
                pw.Divider(thickness: 2),
                _buildRow('= CAPITAL NET', rapport.capitalNet, color: rapport.capitalNet >= 0 ? PdfColors.blue700 : PdfColors.red700, bold: true),
              ],
            ),
          ),
          
          pw.SizedBox(height: 8),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Genere par: ${rapport.generePar ?? "Systeme"}', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                pw.Text('Le ${DateFormat('dd/MM/yyyy HH:mm').format(rapport.dateGeneration)}', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
    ),
  );

  return pdf;
}

pw.Widget _buildSection(String title, List<pw.Widget> children, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color, width: 1),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 4),
        ...children,
      ],
    ),
  );
}

pw.Widget _buildRow(String label, double montant, {bool bold = false, PdfColor? color, String prefix = ''}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 8 : 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('$prefix${montant.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: bold ? 8 : 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    ),
  );
}

pw.Widget _buildDetailRow(String name, String detail, double montant, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(name, style: pw.TextStyle(fontSize: 6)),
              if (detail.isNotEmpty) pw.Text(detail, style: pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text('${montant.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    ),
  );
}
