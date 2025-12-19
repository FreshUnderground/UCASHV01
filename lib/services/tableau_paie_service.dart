import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/salaire_model.dart';
import '../models/personnel_model.dart';

/// Service pour générer des tableaux de paie standardisés
class TableauPaieService {
  /// Génère un tableau de paie avec les colonnes standards
  /// Colonnes: Agent | Période | Salaire de Base | Indemn ité | Avance S/Salaire | Retenu | Salaire Net | Montant Payé | Reste
  static pw.Widget buildTableauPaie({
    required List<SalaireModel> salaires,
    required PersonnelModel personnel,
    bool showTotals = true,
    bool showAgent = false, // Afficher la colonne Agent (pour rapports multi-agents)
  }) {
    // Calculer les totaux
    double totalSalaireBase = 0;
    double totalIndemnites = 0;
    double totalAvances = 0;
    double totalRetenues = 0;
    double totalNet = 0;
    double totalPaye = 0;
    double totalReste = 0;

    for (var salaire in salaires) {
      totalSalaireBase += salaire.salaireBase;
      // Indemnités = toutes les primes et bonus
      final indemnites = salaire.primeTransport +
          salaire.primeLogement +
          salaire.primeFonction +
          salaire.autresPrimes +
          salaire.bonus;
      totalIndemnites += indemnites;
      totalAvances += salaire.avancesDeduites;
      final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
      totalRetenues += retenues;
      totalNet += salaire.salaireNet;
      totalPaye += salaire.montantPaye;
      totalReste += salaire.montantRestant;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Titre
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
                'TABLEAU DES PAIEMENTS - ${personnel.nomComplet}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Matricule: ${personnel.matricule}',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: showAgent ? {
            0: const pw.FlexColumnWidth(1.8), // Agent
            1: const pw.FlexColumnWidth(1.3), // Période
            2: const pw.FlexColumnWidth(1.2), // Salaire de Base
            3: const pw.FlexColumnWidth(1.2), // Indemnité
            4: const pw.FlexColumnWidth(1.2), // Avance
            5: const pw.FlexColumnWidth(1.2), // Retenu
            6: const pw.FlexColumnWidth(1.2), // Salaire Net
            7: const pw.FlexColumnWidth(1.2), // Montant Payé
            8: const pw.FlexColumnWidth(1.2), // Reste
          } : {
            0: const pw.FlexColumnWidth(1.5), // Période
            1: const pw.FlexColumnWidth(1.5), // Salaire de Base
            2: const pw.FlexColumnWidth(1.5), // Indemnité
            3: const pw.FlexColumnWidth(1.5), // Avance
            4: const pw.FlexColumnWidth(1.5), // Retenu
            5: const pw.FlexColumnWidth(1.5), // Salaire Net
            6: const pw.FlexColumnWidth(1.5), // Montant Payé
            7: const pw.FlexColumnWidth(1.5), // Reste
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: showAgent ? [
                _buildHeaderCell('Agent'),
                _buildHeaderCell('Période'),
                _buildHeaderCell('Salaire de Base'),
                _buildHeaderCell('Indemnité'),
                _buildHeaderCell('Avance\nS/Salaire'),
                _buildHeaderCell('Retenu'),
                _buildHeaderCell('Salaire Net'),
                _buildHeaderCell('Montant\nPayé'),
                _buildHeaderCell('Reste'),
              ] : [
                _buildHeaderCell('Période'),
                _buildHeaderCell('Salaire de Base'),
                _buildHeaderCell('Indemnité'),
                _buildHeaderCell('Avance\nS/Salaire'),
                _buildHeaderCell('Retenu'),
                _buildHeaderCell('Salaire Net'),
                _buildHeaderCell('Montant\nPayé'),
                _buildHeaderCell('Reste'),
              ],
            ),

            // Données
            ...salaires.map((salaire) {
              final periode = '${_getMonthName(salaire.mois)} ${salaire.annee}';
              
              // Indemnités = Performance (primes + bonus)
              final indemnites = salaire.primeTransport +
                  salaire.primeLogement +
                  salaire.primeFonction +
                  salaire.autresPrimes +
                  salaire.bonus;
              
              final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;

              return pw.TableRow(
                children: showAgent ? [
                  _buildDataCell(personnel.nomComplet),
                  _buildDataCell(periode),
                  _buildDataCell('${salaire.salaireBase.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${indemnites.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${salaire.avancesDeduites.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${retenues.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${salaire.salaireNet.toStringAsFixed(2)} ${salaire.devise}', bold: true, color: PdfColors.green900),
                  _buildDataCell('${salaire.montantPaye.toStringAsFixed(2)} ${salaire.devise}', color: PdfColors.blue900),
                  _buildDataCell('${salaire.montantRestant.toStringAsFixed(2)} ${salaire.devise}', color: salaire.montantRestant > 0 ? PdfColors.red900 : PdfColors.grey),
                ] : [
                  _buildDataCell(periode),
                  _buildDataCell('${salaire.salaireBase.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${indemnites.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${salaire.avancesDeduites.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${retenues.toStringAsFixed(2)} ${salaire.devise}'),
                  _buildDataCell('${salaire.salaireNet.toStringAsFixed(2)} ${salaire.devise}', bold: true, color: PdfColors.green900),
                  _buildDataCell('${salaire.montantPaye.toStringAsFixed(2)} ${salaire.devise}', color: PdfColors.blue900),
                  _buildDataCell('${salaire.montantRestant.toStringAsFixed(2)} ${salaire.devise}', color: salaire.montantRestant > 0 ? PdfColors.red900 : PdfColors.grey),
                ],
              );
            }).toList(),

            // Ligne de totaux
            if (showTotals && salaires.isNotEmpty)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                ),
                children: showAgent ? [
                  _buildDataCell('TOTAL', bold: true, alignment: pw.Alignment.centerRight),
                  _buildDataCell('', bold: true),
                  _buildDataCell('${totalSalaireBase.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalIndemnites.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalAvances.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalRetenues.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalNet.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: PdfColors.green900),
                  _buildDataCell('${totalPaye.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: PdfColors.blue900),
                  _buildDataCell('${totalReste.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: totalReste > 0 ? PdfColors.red900 : PdfColors.grey),
                ] : [
                  _buildDataCell('TOTAL', bold: true, alignment: pw.Alignment.centerRight),
                  _buildDataCell('${totalSalaireBase.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalIndemnites.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalAvances.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalRetenues.toStringAsFixed(2)} ${salaires.first.devise}', bold: true),
                  _buildDataCell('${totalNet.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: PdfColors.green900),
                  _buildDataCell('${totalPaye.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: PdfColors.blue900),
                  _buildDataCell('${totalReste.toStringAsFixed(2)} ${salaires.first.devise}', bold: true, color: totalReste > 0 ? PdfColors.red900 : PdfColors.grey),
                ],
              ),
          ],
        ),

        // Note explicative
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Icon(
                pw.IconData(0xe88e), // info icon
                size: 12,
                color: PdfColors.blue700,
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  'Indemnité comprend: Prime Transport, Prime Logement, Prime Fonction, Autres Primes et Bonus. Retenu comprend: Retenues Disciplinaires et Retenues Absences.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construit une cellule d'en-tête
  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  /// Construit une cellule de données
  static pw.Widget _buildDataCell(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.Alignment? alignment,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: alignment != null ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  /// Retourne le nom du mois en français
  static String _getMonthName(int month) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return month >= 1 && month <= 12 ? months[month - 1] : 'Mois $month';
  }

  /// Génère un PDF avec uniquement le tableau de paie
  static Future<pw.Document> generateTableauPaiePdf({
    required List<SalaireModel> salaires,
    required PersonnelModel personnel,
    bool showAgent = false,
  }) async {
    final pdf = pw.Document();
    
    // Déterminer l'année à afficher
    final annee = salaires.isNotEmpty ? salaires.first.annee : DateTime.now().year;
    
    // Créer un Map des salaires par mois pour un accès rapide
    final Map<int, SalaireModel> salairesByMois = {};
    for (var salaire in salaires) {
      salairesByMois[salaire.mois] = salaire;
    }
    
    // Générer les lignes pour TOUS les 12 mois
    final List<SalaireModel?> salairesComplets = [];
    for (int mois = 1; mois <= 12; mois++) {
      salairesComplets.add(salairesByMois[mois]); // null si pas de salaire pour ce mois
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête du document
            pw.Container(
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
                        'UCASH FINANCIAL SERVICES',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'TABLEAU RÉCAPITULATIF DES PAIEMENTS',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
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
            ),

            pw.SizedBox(height: 20),

            // Informations agent
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Agent: ${personnel.nomComplet}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Poste: ${personnel.poste}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Matricule: ${personnel.matricule}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Téléphone: ${personnel.telephone}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Tableau avec TOUS les 12 mois
            TableauPaieService._buildTableauPaieComplet(
              salairesComplets: salairesComplets,
              annee: annee,
              personnel: personnel,
              showAgent: showAgent,
            ),

            pw.Spacer(),

            // Pied de page
            pw.Container(
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
                    'Document généré automatiquement',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page 1',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
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
  
  /// Construit un tableau de paie complet avec tous les 12 mois de l'année
  static pw.Widget _buildTableauPaieComplet({
    required List<SalaireModel?> salairesComplets,
    required int annee,
    required PersonnelModel personnel,
    required bool showAgent,
  }) {
    // Calculer les totaux
    double totalSalaireBase = 0;
    double totalIndemnites = 0;
    double totalAvances = 0;
    double totalRetenues = 0;
    double totalNet = 0;
    double totalPaye = 0;
    double totalReste = 0;

    for (var salaire in salairesComplets) {
      if (salaire != null) {
        totalSalaireBase += salaire.salaireBase;
        final indemnites = salaire.primeTransport +
            salaire.primeLogement +
            salaire.primeFonction +
            salaire.autresPrimes +
            salaire.bonus;
        totalIndemnites += indemnites;
        totalAvances += salaire.avancesDeduites;
        final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
        totalRetenues += retenues;
        totalNet += salaire.salaireNet;
        totalPaye += salaire.montantPaye;
        totalReste += salaire.montantRestant;
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Titre
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
                'TABLEAU DES PAIEMENTS - Année $annee',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Tableau
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5), // Période
            1: const pw.FlexColumnWidth(1.2), // Base
            2: const pw.FlexColumnWidth(1.2), // Indemn.
            3: const pw.FlexColumnWidth(1.0), // Avance
            4: const pw.FlexColumnWidth(1.0), // Retenu
            5: const pw.FlexColumnWidth(1.3), // Net
            6: const pw.FlexColumnWidth(1.2), // Payé
            7: const pw.FlexColumnWidth(1.0), // Reste
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildHeaderCell('Période'),
                _buildHeaderCell('Base'),
                _buildHeaderCell('Indemn.'),
                _buildHeaderCell('Avance'),
                _buildHeaderCell('Retenu'),
                _buildHeaderCell('Net'),
                _buildHeaderCell('Payé'),
                _buildHeaderCell('Reste'),
              ],
            ),

            // Lignes de données pour TOUS les 12 mois
            ...List.generate(12, (index) {
              final mois = index + 1;
              final salaire = salairesComplets[index];
              final periode = '${_getMonthName(mois)} $annee';

              if (salaire == null) {
                // Ligne vide pour les mois sans salaire
                return pw.TableRow(
                  children: [
                    _buildDataCell(periode),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                    _buildDataCell('-'),
                  ],
                );
              } else {
                // Ligne avec données
                final indemnites = salaire.primeTransport +
                    salaire.primeLogement +
                    salaire.primeFonction +
                    salaire.autresPrimes +
                    salaire.bonus;
                final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;

                return pw.TableRow(
                  children: [
                    _buildDataCell(periode),
                    _buildDataCell('${salaire.salaireBase.toStringAsFixed(2)}'),
                    _buildDataCell('${indemnites.toStringAsFixed(2)}'),
                    _buildDataCell('${salaire.avancesDeduites.toStringAsFixed(2)}'),
                    _buildDataCell('${retenues.toStringAsFixed(2)}'),
                    _buildDataCell('${salaire.salaireNet.toStringAsFixed(2)}', bold: true, color: PdfColors.green900),
                    _buildDataCell('${salaire.montantPaye.toStringAsFixed(2)}', color: PdfColors.blue900),
                    _buildDataCell('${salaire.montantRestant.toStringAsFixed(2)}', color: salaire.montantRestant > 0 ? PdfColors.red900 : PdfColors.grey),
                  ],
                );
              }
            }),

            // Ligne totaux
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                _buildDataCell('TOTAUX', bold: true),
                _buildDataCell('${totalSalaireBase.toStringAsFixed(2)}', bold: true),
                _buildDataCell('${totalIndemnites.toStringAsFixed(2)}', bold: true),
                _buildDataCell('${totalAvances.toStringAsFixed(2)}', bold: true),
                _buildDataCell('${totalRetenues.toStringAsFixed(2)}', bold: true),
                _buildDataCell('${totalNet.toStringAsFixed(2)}', bold: true, color: PdfColors.green900),
                _buildDataCell('${totalPaye.toStringAsFixed(2)}', bold: true, color: PdfColors.blue900),
                _buildDataCell('${totalReste.toStringAsFixed(2)}', bold: true, color: totalReste > 0 ? PdfColors.red900 : PdfColors.green900),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
