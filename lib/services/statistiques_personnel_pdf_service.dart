import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'document_header_service.dart';
import '../models/salaire_model.dart';
import '../models/personnel_model.dart';
import '../models/avance_personnel_model.dart';
import '../services/personnel_service.dart';
import '../services/salaire_service.dart';
import '../services/avance_service.dart';

/// Service pour générer les PDFs de statistiques personnel

Future<pw.Document> generateStatistiquesPersonnelPdf({
  required int reportType,
  required int mois,
  required int annee,
  required String statut,
}) async {
  switch (reportType) {
    case 0:
      return await _generateListePaiePdf(mois, annee, statut);
    case 1:
      return await _generateRapportPaiementsPdf(mois, annee, statut);
    case 2:
      return await _generateRapportAvancesPdf(mois, annee);
    case 3:
      return await _generateRapportArrieresPdf(mois, annee);
    default:
      throw Exception('Type de rapport inconnu');
  }
}

// ============================================================================
// LISTE DE PAIE MENSUELLE
// ============================================================================

Future<pw.Document> _generateListePaiePdf(int mois, int annee, String statut) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  // Charger les données
  var salaires = SalaireService.instance.salaires
      .where((s) => s.mois == mois && s.annee == annee)
      .toList();
  
  if (statut != 'Tous') {
    salaires = salaires.where((s) => s.statut == statut).toList();
  }
  
  salaires.sort((a, b) => (a.personnelNom ?? '').compareTo(b.personnelNom ?? ''));
  
  // Calculer les totaux
  double totalBrut = 0;
  double totalDeductions = 0;
  double totalNet = 0;
  double totalPaye = 0;
  double totalRestant = 0;
  
  for (var s in salaires) {
    totalBrut += s.salaireBrut;
    totalDeductions += s.totalDeductions;
    totalNet += s.salaireNet;
    totalPaye += s.montantPaye;
    totalRestant += s.montantRestant;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // En-tête
        _buildHeader(header, 'LISTE DE PAIE MENSUELLE', _getMonthName(mois), annee),
        pw.SizedBox(height: 16),
        
        // Résumé
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Employés', '${salaires.length}'),
              _buildSummaryItem('Total Brut', '${totalBrut.toStringAsFixed(2)} USD'),
              _buildSummaryItem('Total Déductions', '${totalDeductions.toStringAsFixed(2)} USD'),
              _buildSummaryItem('Total Net', '${totalNet.toStringAsFixed(2)} USD'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
            6: const pw.FlexColumnWidth(1.5),
            7: const pw.FlexColumnWidth(1.5),
            8: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('#'),
                _buildTableHeader('Nom Complet'),
                _buildTableHeader('Poste'),
                _buildTableHeader('Brut'),
                _buildTableHeader('Déductions'),
                _buildTableHeader('Net'),
                _buildTableHeader('Payé'),
                _buildTableHeader('Reste'),
                _buildTableHeader('Statut'),
              ],
            ),
            // Données
            ...salaires.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
                ),
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCell(s.personnelNom ?? 'Personnel ${s.personnelId}'),
                  _buildTableCell(s.statut ?? '-'),
                  _buildTableCell('${s.salaireBrut.toStringAsFixed(2)}'),
                  _buildTableCell('${s.totalDeductions.toStringAsFixed(2)}'),
                  _buildTableCell('${s.salaireNet.toStringAsFixed(2)}'),
                  _buildTableCell('${s.montantPaye.toStringAsFixed(2)}', color: PdfColors.green900),
                  _buildTableCell('${s.montantRestant.toStringAsFixed(2)}', color: s.montantRestant > 0 ? PdfColors.red900 : null),
                  _buildTableCell(_getStatutLabel(s.statut), fontSize: 7),
                ],
              );
            }),
            // Totaux
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableHeader(''),
                _buildTableHeader('TOTAUX'),
                _buildTableHeader(''),
                _buildTableHeader(totalBrut.toStringAsFixed(2)),
                _buildTableHeader(totalDeductions.toStringAsFixed(2)),
                _buildTableHeader(totalNet.toStringAsFixed(2)),
                _buildTableHeader(totalPaye.toStringAsFixed(2)),
                _buildTableHeader(totalRestant.toStringAsFixed(2)),
                _buildTableHeader(''),
              ],
            ),
          ],
        ),
        
        pw.SizedBox(height: 16),
        
        // Pied de page
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Édité le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page 1 sur 1',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// RAPPORT PAIEMENTS MENSUELS (DÉTAILLÉ)
// ============================================================================

Future<pw.Document> _generateRapportPaiementsPdf(int mois, int annee, String statut) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  var salaires = SalaireService.instance.salaires
      .where((s) => s.mois == mois && s.annee == annee)
      .toList();
  
  if (statut != 'Tous') {
    salaires = salaires.where((s) => s.statut == statut).toList();
  }
  
  salaires.sort((a, b) => (a.personnelNom ?? '').compareTo(b.personnelNom ?? ''));
  
  // Statistiques
  double totalAvances = 0;
  double totalPaiements = 0;
  double totalArrieres = 0;
  int nombrePaiementsComplets = 0;
  int nombrePaiementsPartiels = 0;
  
  for (var s in salaires) {
    totalAvances += s.avancesDeduites;
    totalPaiements += s.montantPaye;
    totalArrieres += s.montantRestant;
    
    if (s.statut == 'Paye') nombrePaiementsComplets++;
    if (s.statut == 'Paye_Partiellement') nombrePaiementsPartiels++;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // En-tête
        _buildHeader(header, 'RAPPORT DES PAIEMENTS MENSUELS', _getMonthName(mois), annee),
        pw.SizedBox(height: 16),
        
        // Statistiques globales
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            border: pw.Border.all(color: PdfColors.green700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RÉSUMÉ GLOBAL',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildStatLine('Total Avances Déduites:', '${totalAvances.toStringAsFixed(2)} USD'),
                      _buildStatLine('Total Paiements Effectués:', '${totalPaiements.toStringAsFixed(2)} USD'),
                      _buildStatLine('Total Arriérés:', '${totalArrieres.toStringAsFixed(2)} USD'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildStatLine('Paiements Complets:', '$nombrePaiementsComplets employés'),
                      _buildStatLine('Paiements Partiels:', '$nombrePaiementsPartiels employés'),
                      _buildStatLine('Total Employés:', '${salaires.length}'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Détail par employé
        pw.Text(
          'DÉTAIL PAR EMPLOYÉ',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 8),
        
        ...salaires.map((s) => _buildEmployeePaiementDetail(s)),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// RAPPORT AVANCES SUR SALAIRES
// ============================================================================

Future<pw.Document> _generateRapportAvancesPdf(int mois, int annee) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final avances = AvanceService.instance.avances
      .where((a) => a.moisAvance == mois && a.anneeAvance == annee)
      .toList();
  
  avances.sort((a, b) => (a.personnelNom ?? '').compareTo(b.personnelNom ?? ''));
  
  double totalAvances = 0;
  double totalRembourse = 0;
  double totalRestant = 0;
  
  for (var a in avances) {
    totalAvances += a.montant;
    totalRembourse += a.montantRembourse;
    totalRestant += a.montantRestant;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // En-tête
        _buildHeader(header, 'RAPPORT DES AVANCES SUR SALAIRES', _getMonthName(mois), annee),
        pw.SizedBox(height: 16),
        
        // Résumé
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            border: pw.Border.all(color: PdfColors.orange700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Avances', '${avances.length}'),
              _buildSummaryItem('Total Avances', '${totalAvances.toStringAsFixed(2)} USD'),
              _buildSummaryItem('Remboursé', '${totalRembourse.toStringAsFixed(2)} USD'),
              _buildSummaryItem('Restant', '${totalRestant.toStringAsFixed(2)} USD'),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Employé'),
                _buildTableHeader('Date'),
                _buildTableHeader('Montant'),
                _buildTableHeader('Remboursé'),
                _buildTableHeader('Restant'),
                _buildTableHeader('Statut'),
              ],
            ),
            ...avances.map((a) => pw.TableRow(
              children: [
                _buildTableCell(a.personnelNom ?? 'Personnel ${a.personnelId}'),
                _buildTableCell(DateFormat('dd/MM/yyyy').format(a.dateAvance)),
                _buildTableCell('${a.montant.toStringAsFixed(2)}'),
                _buildTableCell('${a.montantRembourse.toStringAsFixed(2)}', color: PdfColors.green900),
                _buildTableCell('${a.montantRestant.toStringAsFixed(2)}', color: PdfColors.red900),
                _buildTableCell(a.statut, fontSize: 8),
              ],
            )),
            // Totaux
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.orange100),
              children: [
                _buildTableHeader('TOTAUX'),
                _buildTableHeader(''),
                _buildTableHeader(totalAvances.toStringAsFixed(2)),
                _buildTableHeader(totalRembourse.toStringAsFixed(2)),
                _buildTableHeader(totalRestant.toStringAsFixed(2)),
                _buildTableHeader(''),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// RAPPORT DES ARRIÉRÉS
// ============================================================================

Future<pw.Document> _generateRapportArrieresPdf(int mois, int annee) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final salairesAvecArrieres = SalaireService.instance.salaires
      .where((s) => s.mois == mois && s.annee == annee && s.montantRestant > 0)
      .toList();
  
  salairesAvecArrieres.sort((a, b) => b.montantRestant.compareTo(a.montantRestant));
  
  double totalArrieres = 0;
  for (var s in salairesAvecArrieres) {
    totalArrieres += s.montantRestant;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // En-tête
        _buildHeader(header, 'RAPPORT DES ARRIÉRÉS', _getMonthName(mois), annee),
        pw.SizedBox(height: 16),
        
        // Alerte
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            border: pw.Border.all(color: PdfColors.red700, width: 2),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            children: [
              pw.Icon(
                const pw.IconData(0xe002),
                color: PdfColors.red900,
                size: 32,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ATTENTION: ${salairesAvecArrieres.length} employé(s) avec arriérés',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red900,
                      ),
                    ),
                    pw.Text(
                      'Total des arriérés: ${totalArrieres.toStringAsFixed(2)} USD',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('#'),
                _buildTableHeader('Employé'),
                _buildTableHeader('Salaire Net'),
                _buildTableHeader('Payé'),
                _buildTableHeader('Arriéré'),
                _buildTableHeader('% Payé'),
              ],
            ),
            ...salairesAvecArrieres.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              final pourcentage = (s.montantPaye / s.salaireNet * 100);
              
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? PdfColors.white : PdfColors.red50,
                ),
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCell(s.personnelNom ?? 'Personnel ${s.personnelId}'),
                  _buildTableCell('${s.salaireNet.toStringAsFixed(2)}'),
                  _buildTableCell('${s.montantPaye.toStringAsFixed(2)}', color: PdfColors.green900),
                  _buildTableCell('${s.montantRestant.toStringAsFixed(2)}', color: PdfColors.red900),
                  _buildTableCell('${pourcentage.toStringAsFixed(1)}%', fontSize: 9),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// FONCTIONS HELPER
// ============================================================================

pw.Widget _buildHeader(dynamic header, String title, String month, int year) {
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
              header.companyName,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            if (header.address?.isNotEmpty ?? false)
              pw.Text(
                header.address!,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.yellow,
              ),
            ),
            pw.Text(
              '$month $year',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildSummaryItem(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo900,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    ],
  );
}

pw.Widget _buildTableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildTableCell(String text, {PdfColor? color, double? fontSize}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize ?? 8,
        color: color ?? PdfColors.black,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildStatLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _buildEmployeePaiementDetail(SalaireModel salaire) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              salaire.personnelNom ?? 'Personnel ${salaire.personnelId}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: _getStatutColor(salaire.statut),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                _getStatutLabel(salaire.statut),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailItem('Avances Déduites', '${salaire.avancesDeduites.toStringAsFixed(2)} USD'),
            _buildDetailItem('Montant Payé', '${salaire.montantPaye.toStringAsFixed(2)} USD'),
            _buildDetailItem('Arriéré', '${salaire.montantRestant.toStringAsFixed(2)} USD'),
          ],
        ),
        if (salaire.historiquePaiements.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Historique des paiements (${salaire.historiquePaiements.length}):',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          ...salaire.historiquePaiements.take(3).map((p) => pw.Text(
            '• ${p.montant.toStringAsFixed(2)} USD le ${DateFormat('dd/MM').format(p.datePaiement)}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          )),
        ],
      ],
    ),
  );
}

pw.Widget _buildDetailItem(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

PdfColor _getStatutColor(String statut) {
  switch (statut) {
    case 'Paye':
      return PdfColors.green700;
    case 'Paye_Partiellement':
      return PdfColors.orange700;
    case 'En_Attente':
      return PdfColors.grey700;
    default:
      return PdfColors.grey500;
  }
}

String _getStatutLabel(String statut) {
  switch (statut) {
    case 'Paye':
      return 'Payé';
    case 'Paye_Partiellement':
      return 'Partiel';
    case 'En_Attente':
      return 'En Attente';
    default:
      return statut;
  }
}

String _getMonthName(int month) {
  const months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  return months[month - 1];
}
