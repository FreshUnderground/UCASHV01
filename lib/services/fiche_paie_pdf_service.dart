import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'document_header_service.dart';
import 'tableau_paie_service.dart';
import '../models/salaire_model.dart';
import '../models/personnel_model.dart';

/// Service pour générer les PDFs des fiches de paie

/// Génère une fiche de paie PDF pour un employé
Future<pw.Document> generateFichePaiePdf({
  required SalaireModel salaire,
  required PersonnelModel personnel,
}) async {
  final pdf = pw.Document();
  
  // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final formattedMonth = _getMonthName(salaire.mois);
  final formattedDate = DateFormat('dd/MM/yyyy').format(salaire.createdAt ?? DateTime.now());
  
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // EN-TÊTE
          _buildHeader(header, formattedMonth, salaire.annee),
          pw.SizedBox(height: 20),
          
          // INFORMATIONS EMPLOYÉ
          _buildEmployeeInfo(personnel, formattedDate),
          pw.SizedBox(height: 20),
          
          // DÉTAILS SALAIRE
          _buildSalaireDetails(salaire),
          pw.SizedBox(height: 20),
          
          // RÉCAPITULATIF
          _buildRecapitulatif(salaire),
          
          pw.SizedBox(height: 20),
          
          // TABLEAU DE PAIE STANDARDISÉ
          TableauPaieService.buildTableauPaie(
            salaires: [salaire],
            personnel: personnel,
            showTotals: false,  // Pas de totaux pour un seul salaire
            showAgent: false,   // Pas besoin d'afficher le nom de l'agent (déjà dans l'en-tête)
          ),
          
          // HISTORIQUE DES PAIEMENTS (si plusieurs paiements)
          if (salaire.historiquePaiements.isNotEmpty) ...[
            _buildHistoriquePaiements(salaire),
          ],
          
          pw.Spacer(),
          
          // SIGNATURES
          _buildSignatures(),
        ],
      ),
    ),
  );
  
  return pdf;
}

/// Génère un bulletin de paie collectif (tous les employés du mois)
Future<pw.Document> generateBulletinCollectifPdf({
  required List<SalaireModel> salaires,
  required Map<int, PersonnelModel> personnelMap,
  required int mois,
  required int annee,
}) async {
  final pdf = pw.Document();
  
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final formattedMonth = _getMonthName(mois);
  
  // Calculer les totaux
  double totalBrut = 0;
  double totalDeductions = 0;
  double totalNet = 0;
  
  for (var salaire in salaires) {
    totalBrut += salaire.salaireBrut;
    totalDeductions += salaire.totalDeductions;
    totalNet += salaire.salaireNet;
  }
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        // EN-TÊTE
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.red700,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                header.companyName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (header.address?.isNotEmpty ?? false)
                pw.Text(
                  header.address!,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'BULLETIN DE PAIE COLLECTIF',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.yellow,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '$formattedMonth $annee',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // TABLEAU DES SALAIRES
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // En-tête tableau
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Matricule'),
                _buildTableHeader('Nom Complet'),
                _buildTableHeader('Salaire Brut'),
                _buildTableHeader('Déductions'),
                _buildTableHeader('Salaire Net'),
                _buildTableHeader('Statut'),
              ],
            ),
            // Lignes de données
            ...salaires.map((salaire) {
              // Chercher le personnel par matricule au lieu de l'ID
              final person = personnelMap.values.firstWhere(
                (p) => p.matricule == salaire.personnelMatricule,
                orElse: () => PersonnelModel(
                  matricule: salaire.personnelMatricule,
                  nom: 'Agent',
                  prenom: 'Inconnu',
                  telephone: '',
                  poste: '',
                  dateEmbauche: DateTime.now(),
                ),
              );
              return pw.TableRow(
                children: [
                  _buildTableCell(person.matricule),
                  _buildTableCell(person.nomComplet),
                  _buildTableCell('${salaire.salaireBrut.toStringAsFixed(2)} \$'),
                  _buildTableCell('${salaire.totalDeductions.toStringAsFixed(2)} \$'),
                  _buildTableCell('${salaire.salaireNet.toStringAsFixed(2)} \$'),
                  _buildTableCell(salaire.statut, isStatus: true),
                ],
              );
            }),
            // Ligne totaux
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeader('TOTAUX'),
                _buildTableHeader('${salaires.length} employés'),
                _buildTableHeader('${totalBrut.toStringAsFixed(2)} \$'),
                _buildTableHeader('${totalDeductions.toStringAsFixed(2)} \$'),
                _buildTableHeader('${totalNet.toStringAsFixed(2)} \$'),
                _buildTableCell(''),
              ],
            ),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        // RÉCAPITULATIF GLOBAL
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
                'RÉCAPITULATIF GLOBAL',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildRecapLine('Nombre d\'employés:', '${salaires.length}'),
              _buildRecapLine('Total Salaire Brut:', '${totalBrut.toStringAsFixed(2)} USD'),
              _buildRecapLine('Total Déductions:', '${totalDeductions.toStringAsFixed(2)} USD'),
              pw.Divider(color: PdfColors.blue700),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL SALAIRE NET:',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    '${totalNet.toStringAsFixed(2)} USD',
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
        
        pw.SizedBox(height: 20),
        
        // Pied de page
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Date d\'édition: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    ),
  );
  
  return pdf;
}

// ============================================================================
// FONCTIONS HELPER POUR LA CONSTRUCTION DU PDF
// ============================================================================

pw.Widget _buildHeader(dynamic header, String month, int year) {
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
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            if (header.companySlogan?.isNotEmpty ?? false)
              pw.Text(
                header.companySlogan!,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
            if (header.address?.isNotEmpty ?? false)
              pw.Text(
                header.address!,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            if (header.phone?.isNotEmpty ?? false)
              pw.Text(
                header.phone!,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'FICHE DE PAIE',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.yellow,
              ),
            ),
            pw.Text(
              '$month $year',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildEmployeeInfo(PersonnelModel personnel, String date) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INFORMATIONS EMPLOYÉ',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoLine('Matricule:', personnel.matricule),
                  _buildInfoLine('Nom Complet:', personnel.nomComplet),
                  _buildInfoLine('Poste:', personnel.poste),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoLine('Téléphone:', personnel.telephone),
                  _buildInfoLine('Type Contrat:', personnel.typeContrat),
                  _buildInfoLine('Date Édition:', date),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildSalaireDetails(SalaireModel salaire) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'DÉTAILS DE RÉMUNÉRATION',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 8),
      
      // Tableau des gains
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.green50,
          border: pw.Border.all(color: PdfColors.green700),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              'GAINS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.Divider(color: PdfColors.green700),
            _buildDetailLine('Salaire de Base', salaire.salaireBase),
            _buildDetailLine('Prime Transport', salaire.primeTransport),
            _buildDetailLine('Prime Logement', salaire.primeLogement),
            _buildDetailLine('Prime de Fonction', salaire.primeFonction),
            _buildDetailLine('Autres Primes', salaire.autresPrimes),
            _buildDetailLine('Heures Supplémentaires', salaire.heuresSupplementaires),
            _buildDetailLine('Bonus', salaire.bonus),
            pw.Divider(color: PdfColors.green700),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL BRUT:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.Text(
                  '${salaire.salaireBrut.toStringAsFixed(2)} ${salaire.devise}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      
      pw.SizedBox(height: 10),
      
      // Tableau des déductions
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.red50,
          border: pw.Border.all(color: PdfColors.red700),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              'DÉDUCTIONS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
            pw.Divider(color: PdfColors.red700),
            _buildDetailLine('Avances Déduites', salaire.avancesDeduites),
            _buildDetailLine('Crédits Déduits', salaire.creditsDeduits),
            _buildDetailLine('Impôts', salaire.impots),
            _buildDetailLine('Cotisation CNSS', salaire.cotisationCnss),
            _buildDetailLine('Retenu', salaire.retenueDisciplinaire + salaire.retenueAbsences),
            _buildDetailLine('Autres Déductions', salaire.autresDeductions),
            pw.Divider(color: PdfColors.red700),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL DÉDUCTIONS:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
                pw.Text(
                  '${salaire.totalDeductions.toStringAsFixed(2)} ${salaire.devise}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildRecapitulatif(SalaireModel salaire) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue900,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'SALAIRE NET À PAYER:',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
        pw.Text(
          '${salaire.salaireNet.toStringAsFixed(2)} ${salaire.devise}',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.yellow,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildHistoriquePaiements(SalaireModel salaire) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      border: pw.Border.all(color: PdfColors.blue700),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                'HISTORIQUE DES PAIEMENTS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        ...salaire.historiquePaiements.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final paiement = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '$index',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${paiement.montant.toStringAsFixed(2)} ${salaire.devise}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          pw.Text(
                            DateFormat('dd/MM/yyyy').format(paiement.datePaiement),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
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
                ),
              ],
            ),
          );
        }).toList(),
        pw.Divider(color: PdfColors.blue700),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total Payé:',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              '${salaire.montantPaye.toStringAsFixed(2)} ${salaire.devise}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
          ],
        ),
        if (salaire.montantRestant > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Reste à Payer:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                '${salaire.montantRestant.toStringAsFixed(2)} ${salaire.devise}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

pw.Widget _buildSignatures() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('L\'Employeur', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 30),
          pw.Container(
            width: 150,
            height: 1,
            color: PdfColors.black,
          ),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('L\'Employé', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 30),
          pw.Container(
            width: 150,
            height: 1,
            color: PdfColors.black,
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildInfoLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 4),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}

pw.Widget _buildDetailLine(String label, double amount) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          amount.toStringAsFixed(2),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
}

pw.Widget _buildRecapLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _buildTableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _buildTableCell(String text, {bool isStatus = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        color: isStatus && text == 'Paye' ? PdfColors.green900 : PdfColors.black,
      ),
      textAlign: pw.TextAlign.center,
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
