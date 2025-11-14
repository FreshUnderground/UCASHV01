import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../models/shop_model.dart';

/// Génère un PDF de rapport de clôture journalière avec le nom de fichier rapportcloture.pdf
Future<pw.Document> generateRapportCloturePdf({
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