import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/cloture_caisse_model.dart';
import '../models/shop_model.dart';
import 'document_header_service.dart';

/// Service pour générer le PDF de la clôture de caisse
/// Ce PDF doit être IDENTIQUE à l'UI de cloture_agent_widget.dart
Future<pw.Document> genererClotureCaissePDF(ClotureCaisseModel cloture, ShopModel shop) async {
  final pdf = pw.Document();
  
  // Charger le header depuis DocumentHeaderService
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final formattedDate = DateFormat('dd/MM/yyyy').format(cloture.dateCloture);
  final formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(cloture.dateEnregistrement);
  
  // Calculer les écarts et déterminer les couleurs
  final hasEcart = cloture.ecartTotal.abs() > 0.01;
  final ecartColor = cloture.ecartTotal > 0 ? PdfColors.green : (cloture.ecartTotal < 0 ? PdfColors.red : PdfColors.grey);
  
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                    pw.Text(header.companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    if (header.companySlogan?.isNotEmpty ?? false)
                      pw.Text(header.companySlogan!, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                    if (header.address?.isNotEmpty ?? false)
                      pw.Text(header.address!, style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    if (header.phone?.isNotEmpty ?? false)
                      pw.Text(header.phone!, style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text(shop.designation, style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('🔒 CLÔTURE DE CAISSE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(formattedDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // INFORMATIONS GÉNÉRALES
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Icon(const pw.IconData(0xe7fd), size: 14, color: PdfColors.grey700),
                    pw.SizedBox(width: 6),
                    pw.Text('Clôturé par: ${cloture.cloturePar}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Text('Enregistré le: $formattedDateTime', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // TOTAUX (Saisi, Calculé, Écart) - Style moderne comme dans l'UI
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: hasEcart
                  ? [ecartColor.shade(0.9), ecartColor.shade(0.95)]
                  : [PdfColors.grey200, PdfColors.grey50],
              ),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildModernStatPDF('Saisi', cloture.soldeSaisiTotal, PdfColors.blue),
                pw.Container(width: 1, height: 40, color: PdfColors.grey400),
                _buildModernStatPDF('Calculé', cloture.soldeCalculeTotal, PdfColors.purple),
                pw.Container(width: 1, height: 40, color: PdfColors.grey400),
                _buildModernStatPDF('Écart', cloture.ecartTotal, ecartColor),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // DÉTAILS PAR MODE DE PAIEMENT
          pw.Text('DÉTAILS PAR MODE DE PAIEMENT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 10),
          
          // USD (Cash)
          _buildDetailCardPDF(
            'USD',
            cloture.soldeSaisiCash,
            cloture.soldeCalculeCash,
            cloture.ecartCash,
            PdfColors.green,
          ),
          pw.SizedBox(height: 10),
          
          // Airtel Money
          _buildDetailCardPDF(
            'Airtel Money',
            cloture.soldeSaisiAirtelMoney,
            cloture.soldeCalculeAirtelMoney,
            cloture.ecartAirtelMoney,
            PdfColors.red,
          ),
          pw.SizedBox(height: 10),
          
          // MPESA/VODACASH
          _buildDetailCardPDF(
            'MPESA/VODACASH',
            cloture.soldeSaisiMPesa,
            cloture.soldeCalculeMPesa,
            cloture.ecartMPesa,
            PdfColors.blue,
          ),
          pw.SizedBox(height: 10),
          
          // Orange Money
          _buildDetailCardPDF(
            'Orange Money',
            cloture.soldeSaisiOrangeMoney,
            cloture.soldeCalculeOrangeMoney,
            cloture.ecartOrangeMoney,
            PdfColors.orange,
          ),
          
          // NOTES (si présentes)
          if (cloture.notes != null && cloture.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.amber300, width: 1),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Icon(const pw.IconData(0xef42), size: 16, color: PdfColors.amber800),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Notes:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                        pw.SizedBox(height: 4),
                        pw.Text(cloture.notes!, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          pw.Spacer(),
          
          // FOOTER
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                pw.Text('UCASH - ${shop.designation}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  return pdf;
}

/// Widget pour afficher une statistique moderne (Style identique à l'UI)
pw.Widget _buildModernStatPDF(String label, double value, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value.toStringAsFixed(2),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          'USD',
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey600,
          ),
        ),
      ],
    ),
  );
}

/// Widget pour afficher les détails par mode de paiement (Style identique à l'UI)
pw.Widget _buildDetailCardPDF(String label, double saisi, double calcule, double ecart, PdfColor color) {
  final hasEcart = ecart.abs() > 0.01;
  final ecartColor = ecart > 0 ? PdfColors.green : (ecart < 0 ? PdfColors.red : PdfColors.grey);
  
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: color.shade(0.95),
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: color.shade(0.8), width: 1),
    ),
    child: pw.Row(
      children: [
        // Icône
        pw.Container(
          width: 35,
          height: 35,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [color, color.shade(0.7)],
            ),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Icon(const pw.IconData(0xe0b0), color: PdfColors.white, size: 18),
          ),
        ),
        pw.SizedBox(width: 12),
        
        // Contenu
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  _buildAmountChipPDF('Saisi', saisi, PdfColors.blue),
                  pw.SizedBox(width: 6),
                  _buildAmountChipPDF('Calculé', calcule, PdfColors.purple),
                  if (hasEcart) ...[
                    pw.SizedBox(width: 6),
                    _buildAmountChipPDF('Écart', ecart, ecartColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Widget pour afficher une petite puce de montant (Style identique à l'UI)
pw.Widget _buildAmountChipPDF(String label, double value, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: pw.BoxDecoration(
      color: color.shade(0.9),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 6,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          value.toStringAsFixed(2),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
