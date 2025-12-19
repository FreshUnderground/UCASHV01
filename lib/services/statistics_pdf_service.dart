import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'document_header_service.dart';
import '../models/salaire_model.dart';
import '../models/personnel_model.dart';
import '../models/avance_personnel_model.dart';

/// Service pour générer les PDFs de statistiques du personnel

/// 1. RAPPORT DES PAIEMENTS MENSUELS (Avances & Soldes)
Future<pw.Document> generateRapportPaiementsMensuels({
  required List<SalaireModel> salaires,
  required Map<int, PersonnelModel> personnelMap,
  int? mois,
  int? annee,
  String? filtreStatut,
}) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  // Calculer les totaux
  double totalPaiementsComplets = 0;
  double totalPaiementsPartiels = 0;
  double totalArrieres = 0;
  int nombrePaiementsComplets = 0;
  int nombrePaiementsPartiels = 0;
  
  // Calculer les totaux détaillés
  double totalBase = 0;
  double totalIndemnites = 0;
  double totalAvancesDeduites = 0;
  double totalRetenues = 0;
  double totalNet = 0;
  double totalPaye = 0;
  double totalReste = 0;
  
  for (var salaire in salaires) {
    if (salaire.statut == 'Paye') {
      totalPaiementsComplets += salaire.montantPaye;
      nombrePaiementsComplets++;
    } else if (salaire.statut == 'Paye_Partiellement') {
      totalPaiementsPartiels += salaire.montantPaye;
      totalArrieres += salaire.montantRestant;
      nombrePaiementsPartiels++;
    }
    
    // Calculer les totaux détaillés
    totalBase += salaire.salaireBase;
    final indemnites = salaire.primeTransport +
        salaire.primeLogement +
        salaire.primeFonction +
        salaire.autresPrimes +
        salaire.bonus;
    totalIndemnites += indemnites;
    totalAvancesDeduites += salaire.avancesDeduites;
    final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
    totalRetenues += retenues;
    totalNet += salaire.salaireNet;
    totalPaye += salaire.montantPaye;
    totalReste += salaire.montantRestant;
  }
  
  final periode = mois != null && annee != null 
      ? '${_getMonthName(mois)} $annee'
      : annee != null 
          ? 'Année $annee' 
          : 'Toutes périodes';
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // En-tête
        _buildHeader(header, 'RAPPORT DES PAIEMENTS MENSUELS', periode),
        pw.SizedBox(height: 16),
        
        // Résumé exécutif
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RÉSUMÉ EXÉCUTIF',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Divider(color: PdfColors.blue700),
              _buildSummaryRow('Paiements complets:', '$nombrePaiementsComplets agents', '${totalPaiementsComplets.toStringAsFixed(2)} USD', PdfColors.green900),
              _buildSummaryRow('Paiements partiels:', '$nombrePaiementsPartiels agents', '${totalPaiementsPartiels.toStringAsFixed(2)} USD', PdfColors.orange900),
              _buildSummaryRow('Arrières totaux:', '', '${totalArrieres.toStringAsFixed(2)} USD', PdfColors.red900),
              pw.Divider(color: PdfColors.blue700),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL PAYÉ:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    '${(totalPaiementsComplets + totalPaiementsPartiels).toStringAsFixed(2)} USD',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau détaillé
        pw.Text(
          'DÉTAIL DES PAIEMENTS',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 8),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),    // Agent
            1: const pw.FlexColumnWidth(1.3),  // Période
            2: const pw.FlexColumnWidth(1),    // Base
            3: const pw.FlexColumnWidth(1),    // Indemn.
            4: const pw.FlexColumnWidth(0.8),  // Avance
            5: const pw.FlexColumnWidth(0.8),  // Retenu
            6: const pw.FlexColumnWidth(1.2),  // Net
            7: const pw.FlexColumnWidth(1),    // Payé
            8: const pw.FlexColumnWidth(1),    // Reste
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Agent'),
                _buildTableHeader('Période'),
                _buildTableHeader('Base'),
                _buildTableHeader('Indemn.'),
                _buildTableHeader('Avance'),
                _buildTableHeader('Retenu'),
                _buildTableHeader('Net'),
                _buildTableHeader('Payé'),
                _buildTableHeader('Reste'),
              ],
            ),
            // Données
            ...salaires.map((salaire) {
              final personnel = personnelMap[salaire.personnelId];
              final indemnites = salaire.primeTransport +
                  salaire.primeLogement +
                  salaire.primeFonction +
                  salaire.autresPrimes +
                  salaire.bonus;
              final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
              
              return pw.TableRow(
                children: [
                  _buildTableCell(personnel?.nomComplet ?? 'N/A'),
                  _buildTableCell('${_getMonthName(salaire.mois)} ${salaire.annee}'),
                  _buildTableCell('${salaire.salaireBase.toStringAsFixed(0)}'),
                  _buildTableCell('${indemnites.toStringAsFixed(0)}'),
                  _buildTableCell('${salaire.avancesDeduites.toStringAsFixed(0)}'),
                  _buildTableCell('${retenues.toStringAsFixed(0)}'),
                  _buildTableCell('${salaire.salaireNet.toStringAsFixed(0)}'),
                  _buildTableCell('${salaire.montantPaye.toStringAsFixed(0)}', 
                    color: salaire.montantPaye > 0 ? PdfColors.green900 : null),
                  _buildTableCell('${salaire.montantRestant.toStringAsFixed(0)}',
                    color: salaire.montantRestant > 0 ? PdfColors.red900 : null),
                ],
              );
            }).toList(),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        // Totaux détaillés
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOTAUX DÉTAILLÉS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Base: ${totalBase.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Indemn.: ${totalIndemnites.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Avance: ${totalAvancesDeduites.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange900)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Retenu: ${totalRetenues.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red900)),
                      pw.Text('Net: ${totalNet.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Payé: ${totalPaye.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.green900, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Reste: ${totalReste.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        _buildFooter(),
      ],
    ),
  );
  
  return pdf;
}

/// 2. RAPPORT DES AVANCES SUR SALAIRES
Future<pw.Document> generateRapportAvances({
  required List<AvancePersonnelModel> avances,
  required Map<int, PersonnelModel> personnelMap,
  int? mois,
  int? annee,
}) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  // Calculer totaux
  double totalAvances = 0;
  double totalRembourse = 0;
  double totalRestant = 0;
  
  for (var avance in avances) {
    totalAvances += avance.montant;
    totalRembourse += avance.montantRembourse;
    totalRestant += avance.montantRestant;
  }
  
  final periode = mois != null && annee != null 
      ? '${_getMonthName(mois)} $annee'
      : annee != null 
          ? 'Année $annee' 
          : 'Toutes périodes';
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        _buildHeader(header, 'RAPPORT DES AVANCES SUR SALAIRES', periode),
        pw.SizedBox(height: 16),
        
        // Résumé
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            border: pw.Border.all(color: PdfColors.orange700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'RÉSUMÉ DES AVANCES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange900,
                ),
              ),
              pw.Divider(color: PdfColors.orange700),
              _buildSummaryRow('Nombre d\'avances:', '${avances.length}', '', null),
              _buildSummaryRow('Total avancé:', '', '${totalAvances.toStringAsFixed(2)} USD', PdfColors.orange900),
              _buildSummaryRow('Total remboursé:', '', '${totalRembourse.toStringAsFixed(2)} USD', PdfColors.green900),
              _buildSummaryRow('Reste à rembourser:', '', '${totalRestant.toStringAsFixed(2)} USD', PdfColors.red900),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Agent'),
                _buildTableHeader('Date'),
                _buildTableHeader('Période'),
                _buildTableHeader('Montant'),
                _buildTableHeader('Remboursé'),
                _buildTableHeader('Restant'),
              ],
            ),
            ...avances.map((avance) {
              final personnel = personnelMap[avance.personnelId];
              return pw.TableRow(
                children: [
                  _buildTableCell(personnel?.nomComplet ?? 'N/A'),
                  _buildTableCell(DateFormat('dd/MM/yyyy').format(avance.dateAvance)),
                  _buildTableCell('${_getMonthName(avance.moisAvance)} ${avance.anneeAvance}'),
                  _buildTableCell('${avance.montant.toStringAsFixed(2)} USD'),
                  _buildTableCell('${avance.montantRembourse.toStringAsFixed(2)} USD'),
                  _buildTableCell('${avance.montantRestant.toStringAsFixed(2)} USD',
                    color: avance.montantRestant > 0 ? PdfColors.red900 : PdfColors.green900),
                ],
              );
            }).toList(),
          ],
        ),
        
        pw.SizedBox(height: 20),
        _buildFooter(),
      ],
    ),
  );
  
  return pdf;
}

/// 3. RAPPORT DES ARRIÈRES
Future<pw.Document> generateRapportArrieres({
  required List<SalaireModel> salaires,
  required Map<int, PersonnelModel> personnelMap,
}) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  // Filtrer seulement les salaires avec arrières
  final salairesAvecArrieres = salaires.where((s) => s.montantRestant > 0).toList();
  
  double totalArrieres = 0;
  for (var salaire in salairesAvecArrieres) {
    totalArrieres += salaire.montantRestant;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        _buildHeader(header, 'RAPPORT DES ARRIÈRES DE PAIE', 'Situation actuelle'),
        pw.SizedBox(height: 16),
        
        // Résumé
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            border: pw.Border.all(color: PdfColors.red700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                '⚠️ SITUATION DES ARRIÈRES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
              pw.Divider(color: PdfColors.red700),
              _buildSummaryRow('Nombre de salaires impayés:', '${salairesAvecArrieres.length}', '', null),
              _buildSummaryRow('TOTAL ARRIÈRES:', '', '${totalArrieres.toStringAsFixed(2)} USD', PdfColors.red900),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Agent'),
                _buildTableHeader('Période'),
                _buildTableHeader('Net à Payer'),
                _buildTableHeader('Payé'),
                _buildTableHeader('Arrière'),
              ],
            ),
            ...salairesAvecArrieres.map((salaire) {
              final personnel = personnelMap[salaire.personnelId];
              return pw.TableRow(
                decoration: salaire.montantRestant > salaire.salaireNet * 0.5 
                    ? pw.BoxDecoration(color: PdfColors.red50)
                    : null,
                children: [
                  _buildTableCell(personnel?.nomComplet ?? 'N/A'),
                  _buildTableCell('${_getMonthName(salaire.mois)} ${salaire.annee}'),
                  _buildTableCell('${salaire.salaireNet.toStringAsFixed(2)} USD'),
                  _buildTableCell('${salaire.montantPaye.toStringAsFixed(2)} USD'),
                  _buildTableCell('${salaire.montantRestant.toStringAsFixed(2)} USD',
                    color: PdfColors.red900),
                ],
              );
            }).toList(),
          ],
        ),
        
        pw.SizedBox(height: 20),
        _buildFooter(),
      ],
    ),
  );
  
  return pdf;
}

// Continued in next message due to length limit...

/// 4. LISTE DE PAIE DÉTAILLÉE
Future<pw.Document> generateListePaie({
  required List<SalaireModel> salaires,
  required List<AvancePersonnelModel> avances,
  required Map<int, PersonnelModel> personnelMap,
  int? mois,
  int? annee,
}) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  // Grouper par personnel
  final Map<int, List<SalaireModel>> salairesByPersonnel = {};
  for (var salaire in salaires) {
    salairesByPersonnel.putIfAbsent(salaire.personnelId, () => []).add(salaire);
  }
  
  // Grouper avances par personnel
  final Map<int, List<AvancePersonnelModel>> avancesByPersonnel = {};
  for (var avance in avances) {
    avancesByPersonnel.putIfAbsent(avance.personnelId, () => []).add(avance);
  }
  
  // Calculer totaux globaux
  double grandTotalBase = 0;
  double grandTotalIndemnites = 0;
  double grandTotalAvancesDeduites = 0;
  double grandTotalRetenues = 0;
  double grandTotalNet = 0;
  double grandTotalPaiements = 0;
  double grandTotalArrieres = 0;
  double grandTotalAvances = 0;
  
  final periode = mois != null && annee != null 
      ? '${_getMonthName(mois)} $annee'
      : annee != null 
          ? 'Année $annee' 
          : 'Toutes périodes';
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        final widgets = <pw.Widget>[
          _buildHeader(header, 'LISTE DE PAIE DÉTAILLÉE', periode),
          pw.SizedBox(height: 16),
        ];
        
        // Pour chaque personnel
        for (var personnelId in salairesByPersonnel.keys) {
          final personnel = personnelMap[personnelId];
          final salairesPers = salairesByPersonnel[personnelId]!;
          final avancesPers = avancesByPersonnel[personnelId] ?? [];
          
          // Calculer totaux pour cet agent
          double totalBase = 0;
          double totalIndemnites = 0;
          double totalAvancesDeduites = 0;
          double totalRetenues = 0;
          double totalNet = 0;
          double totalPaiements = 0;
          double totalArrieres = 0;
          double totalAvances = 0;
          
          for (var salaire in salairesPers) {
            totalBase += salaire.salaireBase;
            final indemnites = salaire.primeTransport +
                salaire.primeLogement +
                salaire.primeFonction +
                salaire.autresPrimes +
                salaire.bonus;
            totalIndemnites += indemnites;
            totalAvancesDeduites += salaire.avancesDeduites;
            final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
            totalRetenues += retenues;
            totalNet += salaire.salaireNet;
            totalPaiements += salaire.montantPaye;
            totalArrieres += salaire.montantRestant;
          }
          
          for (var avance in avancesPers) {
            totalAvances += avance.montant;
          }
          
          // Mise à jour des totaux globaux
          grandTotalBase += totalBase;
          grandTotalIndemnites += totalIndemnites;
          grandTotalAvancesDeduites += totalAvancesDeduites;
          grandTotalRetenues += totalRetenues;
          grandTotalNet += totalNet;
          grandTotalPaiements += totalPaiements;
          grandTotalArrieres += totalArrieres;
          grandTotalAvances += totalAvances;
          
          // Section pour cet agent
          widgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue700),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // En-tête agent
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue700,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          personnel?.nomComplet ?? 'Agent $personnelId',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          personnel?.poste ?? '',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  
                  // Tableau des salaires
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.5),  // Période
                      1: const pw.FlexColumnWidth(0.8),  // Base
                      2: const pw.FlexColumnWidth(0.8),  // Indemn.
                      3: const pw.FlexColumnWidth(0.7),  // Avance
                      4: const pw.FlexColumnWidth(0.7),  // Retenu
                      5: const pw.FlexColumnWidth(1),    // Net
                      6: const pw.FlexColumnWidth(0.8),  // Payé
                      7: const pw.FlexColumnWidth(0.7),  // Reste
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableHeader('Période', fontSize: 8),
                          _buildTableHeader('Base', fontSize: 8),
                          _buildTableHeader('Indemn.', fontSize: 8),
                          _buildTableHeader('Avance', fontSize: 8),
                          _buildTableHeader('Retenu', fontSize: 8),
                          _buildTableHeader('Net', fontSize: 8),
                          _buildTableHeader('Payé', fontSize: 8),
                          _buildTableHeader('Reste', fontSize: 8),
                        ],
                      ),
                      ...salairesPers.map((s) {
                        final indemnites = s.primeTransport +
                            s.primeLogement +
                            s.primeFonction +
                            s.autresPrimes +
                            s.bonus;
                        final retenues = s.retenueDisciplinaire + s.retenueAbsences;
                        
                        return pw.TableRow(
                          children: [
                            _buildTableCell('${_getMonthName(s.mois)} ${s.annee}', fontSize: 8),
                            _buildTableCell('${s.salaireBase.toStringAsFixed(0)}', fontSize: 8),
                            _buildTableCell('${indemnites.toStringAsFixed(0)}', fontSize: 8),
                            _buildTableCell('${s.avancesDeduites.toStringAsFixed(0)}', fontSize: 8),
                            _buildTableCell('${retenues.toStringAsFixed(0)}', fontSize: 8),
                            _buildTableCell('${s.salaireNet.toStringAsFixed(0)}', fontSize: 8),
                            _buildTableCell('${s.montantPaye.toStringAsFixed(0)}', fontSize: 8, color: PdfColors.green900),
                            _buildTableCell('${s.montantRestant.toStringAsFixed(0)}', fontSize: 8, color: s.montantRestant > 0 ? PdfColors.red900 : null),
                          ],
                        );
                      }),
                    ],
                  ),
                  
                  pw.SizedBox(height: 8),
                  
                  // Totaux agent
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAUX:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Base: ${totalBase.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text('Indemn.: ${totalIndemnites.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 7)),
                            pw.Text('Avance: ${totalAvancesDeduites.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.orange900)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.SizedBox(width: 50),
                            pw.Text('Retenu: ${totalRetenues.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red900)),
                            pw.Text('Net: ${totalNet.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Payé: ${totalPaiements.toStringAsFixed(0)}', 
                              style: pw.TextStyle(fontSize: 8, color: PdfColors.green900, fontWeight: pw.FontWeight.bold)),
                            if (totalArrieres > 0)
                              pw.Text('Reste: ${totalArrieres.toStringAsFixed(0)}',
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Totaux globaux
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'TOTAUX GÉNÉRAUX',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalBox('Base', grandTotalBase, PdfColors.blue),
                    _buildTotalBox('Indemn.', grandTotalIndemnites, PdfColors.purple),
                    _buildTotalBox('Avance', grandTotalAvancesDeduites, PdfColors.orange),
                    _buildTotalBox('Retenu', grandTotalRetenues, PdfColors.red),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalBox('Net', grandTotalNet, PdfColors.green),
                    _buildTotalBox('Payé', grandTotalPaiements, PdfColors.teal),
                    _buildTotalBox('Reste', grandTotalArrieres, PdfColors.red),
                  ],
                ),
              ],
            ),
          ),
        );
        
        widgets.add(pw.SizedBox(height: 20));
        widgets.add(_buildFooter());
        
        return widgets;
      },
    ),
  );
  
  return pdf;
}

// ============================================================================
// FONCTIONS HELPER
// ============================================================================

pw.Widget _buildHeader(dynamic header, String title, String periode) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
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
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.yellow,
              ),
            ),
            pw.Text(
              periode,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildSummaryRow(String label, String count, String amount, PdfColor? color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Row(
          children: [
            if (count.isNotEmpty)
              pw.Text(count, style: const pw.TextStyle(fontSize: 10)),
            if (count.isNotEmpty && amount.isNotEmpty)
              pw.SizedBox(width: 20),
            if (amount.isNotEmpty)
              pw.Text(
                amount,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildTableHeader(String text, {double fontSize = 9}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildTableCell(String text, {double fontSize = 8, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        color: color ?? PdfColors.black,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildFooter() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'Date d\'édition: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      pw.Text(
        'UCASH V01 - Gestion du Personnel',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ],
  );
}

pw.Widget _buildTotalBox(String label, double amount, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${amount.toStringAsFixed(2)} USD',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

String _getMonthName(int month) {
  const months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  return months[month - 1];
}

String _getStatutLabel(String statut) {
  switch (statut) {
    case 'Paye':
      return 'Payé';
    case 'Paye_Partiellement':
      return 'Partiel';
    case 'En_Attente':
      return 'En attente';
    default:
      return statut;
  }
}
