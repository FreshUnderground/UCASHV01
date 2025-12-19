import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';

/// Service pour générer le PDF de l'historique des paiements
class HistoriquePaiementsPdfService {
  /// Génère un PDF complet de l'historique des paiements d'un agent
  static Future<pw.Document> generateHistoriquePaiementsPdf({
    required PersonnelModel personnel,
    required List<SalaireModel> salaires,
  }) async {
    final pdf = pw.Document();
    
    // Calculer les totaux
    double totalBrut = 0;
    double totalNet = 0;
    double totalPaye = 0;
    double totalReste = 0;
    int nombrePaiements = 0;
    
    for (var salaire in salaires) {
      totalBrut += salaire.salaireBrut;
      totalNet += salaire.salaireNet;
      totalPaye += salaire.montantPaye;
      totalReste += salaire.montantRestant;
      nombrePaiements += salaire.historiquePaiements.length;
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // En-tête
          _buildHeader(personnel),
          pw.SizedBox(height: 20),
          
          // Résumé
          _buildSummary(
            totalSalaires: salaires.length,
            nombrePaiements: nombrePaiements,
            totalBrut: totalBrut,
            totalNet: totalNet,
            totalPaye: totalPaye,
            totalReste: totalReste,
            devise: salaires.isNotEmpty ? salaires.first.devise : 'USD',
          ),
          pw.SizedBox(height: 20),
          
          // Historique détaillé par mois
          ...salaires.map((salaire) => _buildSalaireSection(salaire)).toList(),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );
    
    return pdf;
  }
  
  /// Construit l'en-tête du document
  static pw.Widget _buildHeader(PersonnelModel personnel) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo700,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HISTORIQUE DES PAIEMENTS',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                personnel.nomComplet,
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Matricule: ${personnel.matricule} | ${personnel.poste}',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Édité le:',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                ),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Construit le résumé global
  static pw.Widget _buildSummary({
    required int totalSalaires,
    required int nombrePaiements,
    required double totalBrut,
    required double totalNet,
    required double totalPaye,
    required double totalReste,
    required String devise,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RÉSUMÉ',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Nombre de salaires', '$totalSalaires'),
              _buildSummaryItem('Nombre de paiements', '$nombrePaiements'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Brut', '${totalBrut.toStringAsFixed(2)} $devise'),
              _buildSummaryItem('Total Net', '${totalNet.toStringAsFixed(2)} $devise'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Payé', '${totalPaye.toStringAsFixed(2)} $devise', valueColor: PdfColors.green900),
              _buildSummaryItem('Total Reste', '${totalReste.toStringAsFixed(2)} $devise', valueColor: totalReste > 0 ? PdfColors.red900 : PdfColors.grey),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildSummaryItem(String label, String value, {PdfColor? valueColor}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit la section d'un salaire avec son historique
  static pw.Widget _buildSalaireSection(SalaireModel salaire) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tête du mois
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${_getMonthName(salaire.mois)} ${salaire.annee}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _getStatusColor(salaire.statut),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    salaire.statut,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          
          // Détails du salaire
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow('Salaire Brut', '${salaire.salaireBrut.toStringAsFixed(2)} ${salaire.devise}'),
              ),
              pw.Expanded(
                child: _buildInfoRow('Avances', '${salaire.avancesDeduites.toStringAsFixed(2)} ${salaire.devise}', valueColor: PdfColors.orange900),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow('Retenu', '${(salaire.retenueDisciplinaire + salaire.retenueAbsences).toStringAsFixed(2)} ${salaire.devise}', valueColor: PdfColors.red900),
              ),
              pw.Expanded(
                child: _buildInfoRow('Salaire Net', '${salaire.salaireNet.toStringAsFixed(2)} ${salaire.devise}', isBold: true),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow('Montant Payé', '${salaire.montantPaye.toStringAsFixed(2)} ${salaire.devise}', valueColor: PdfColors.green900),
              ),
              pw.Expanded(
                child: _buildInfoRow('Reste', '${salaire.montantRestant.toStringAsFixed(2)} ${salaire.devise}', valueColor: salaire.montantRestant > 0 ? PdfColors.red900 : PdfColors.grey),
              ),
            ],
          ),
          
          // Historique des paiements
          if (salaire.historiquePaiements.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Détail des ${salaire.historiquePaiements.length} paiement(s):',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...salaire.historiquePaiements.map((paiement) => _buildPaiementRow(paiement)).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  static pw.Widget _buildInfoRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildPaiementRow(PaiementSalaireModel paiement) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(paiement.datePaiement),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              if (paiement.notes != null && paiement.notes!.isNotEmpty)
                pw.Text(
                  paiement.notes!,
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
          pw.Text(
            '${paiement.montant.toStringAsFixed(2)} USD',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'UCASH - Historique des Paiements',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
  
  static String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return month >= 1 && month <= 12 ? months[month - 1] : 'Mois $month';
  }
  
  static PdfColor _getStatusColor(String statut) {
    switch (statut) {
      case 'Paye':
        return PdfColors.green700;
      case 'Paye_Partiellement':
        return PdfColors.orange700;
      case 'En_Attente':
        return PdfColors.blue700;
      default:
        return PdfColors.grey700;
    }
  }
}
