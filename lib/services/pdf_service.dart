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
          // EN-TÊTE - Style UCASH avec identification du shop
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
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '🏪 SHOP: ${shop.designation}',
                      style: pw.TextStyle(
                        fontSize: 16, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.yellow,
                      ),
                    ),
                    pw.Text(
                      '📍 ${shop.localisation ?? "Localisation non spécifiée"}',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
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
                      '🚢 Flots (Liquidités Inter-Shops)',
                      [
                        _buildRow('Reçus (Servis)', rapport.flotRecu, color: PdfColors.green700),
                        _buildRow('🔶 En cours', rapport.flotEnCours, color: PdfColors.orange700),
                        _buildRow('Envoyés (Servis)', rapport.flotServi, color: PdfColors.red700, prefix: '-'),
                        if (rapport.flotEnCours > 0) pw.Divider(color: PdfColors.orange700),
                        if (rapport.flotEnCours > 0)
                          pw.Text('⚠️ FLOT EN COURS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
                        ...rapport.flotsEnvoyes.where((f) => f.statut == 'enRoute').map((flot) => 
                          _buildFlotRow(flot, isEnCours: true)
                        ),
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
                      '⚠️ Clients Nous Doivent (Débiteurs)',
                      [
                        pw.Text('${rapport.clientsNousDoivent.length} client(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        ...rapport.clientsNousDoivent.take(5).map((client) => 
                          _buildDetailRow(client.nom, client.solde.abs(), subtitle: client.numeroCompte)
                        ),
                        if (rapport.clientsNousDoivent.length > 5)
                          pw.Text('... et ${rapport.clientsNousDoivent.length - 5} autre(s)', 
                            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        if (rapport.clientsNousDoivent.isEmpty)
                          pw.Text('Aucun client ne nous doit', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        pw.Divider(),
                        _buildRow('TOTAL DETTES CLIENT', rapport.totalClientsNousDoivent, color: PdfColors.red700, bold: true),
                      ],
                      PdfColors.red700,
                    ),
                    pw.SizedBox(height: 12),
                    // Clients Nous Devons
                    _buildSection(
                      '✅ Clients Nous Devons (Créditeurs)',
                      [
                        pw.Text('${rapport.clientsNousDevons.length} client(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        ...rapport.clientsNousDevons.take(5).map((client) => 
                          _buildDetailRow(client.nom, client.solde, subtitle: client.numeroCompte)
                        ),
                        if (rapport.clientsNousDevons.length > 5)
                          pw.Text('... et ${rapport.clientsNousDevons.length - 5} autre(s)', 
                            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        if (rapport.clientsNousDevons.isEmpty)
                          pw.Text('Nous ne devons aucun client', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        pw.Divider(),
                        _buildRow('TOTAL CRÉANCES CLIENT', rapport.totalClientsNousDevons, color: PdfColors.green700, bold: true),
                      ],
                      PdfColors.green700,
                    ),
                    pw.SizedBox(height: 12),
                    // Shops Nous Doivent
                    _buildSection(
                      '❗ Shops Nous Doivent (Créances)',
                      [
                        pw.Text('${rapport.shopsNousDoivent.length} shop(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        ...rapport.shopsNousDoivent.map((shop) => 
                          _buildDetailRow(shop.designation, shop.montant, subtitle: shop.localisation)
                        ),
                        if (rapport.shopsNousDoivent.isEmpty)
                          pw.Text('Aucun shop ne nous doit', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        pw.Divider(),
                        _buildRow('TOTAL CRÉANCES', rapport.totalShopsNousDoivent, color: PdfColors.orange700, bold: true),
                      ],
                      PdfColors.orange700,
                    ),
                    pw.SizedBox(height: 12),
                    // Shops Nous Devons
                    _buildSection(
                      '❗ Shops Nous Devons (Dettes)',
                      [
                        pw.Text('${rapport.shopsNousDevons.length} shop(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(),
                        ...rapport.shopsNousDevons.map((shop) => 
                          _buildDetailRow(shop.designation, shop.montant, subtitle: shop.localisation)
                        ),
                        if (rapport.shopsNousDevons.isEmpty)
                          pw.Text('Nous ne devons aucun shop', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        pw.Divider(),
                        _buildRow('TOTAL DETTES', rapport.totalShopsNousDevons, color: PdfColors.purple700, bold: true),
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

/// Ligne de détail avec sous-titre (pour clients et shops)
pw.Widget _buildDetailRow(String nom, double montant, {String? subtitle}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                nom,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              '${montant.toStringAsFixed(2)} USD',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        if (subtitle != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4),
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ),
      ],
    ),
  );
}

/// Ligne FLOT avec détails
pw.Widget _buildFlotRow(FlotResume flot, {bool isEnCours = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    margin: const pw.EdgeInsets.only(top: 2),
    decoration: pw.BoxDecoration(
      color: isEnCours ? PdfColors.orange50 : PdfColors.grey50,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '→ ${flot.shopDestinationDesignation}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: isEnCours ? PdfColors.orange800 : PdfColors.grey800,
              ),
            ),
            pw.Text(
              '${flot.montant.toStringAsFixed(2)} ${flot.devise}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: isEnCours ? PdfColors.orange800 : PdfColors.grey800,
              ),
            ),
          ],
        ),
        pw.Text(
          '${flot.modePaiement} | Envoyé: ${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)}',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

/// Classe PdfService pour compatibilité avec le code existant
class PdfService {
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

/// Générer un PDF de relevé de compte client
Future<pw.Document> generateClientStatementPdf({
  required ClientModel client,
  required List<OperationModel> operations,
  required ShopModel shop,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final pdf = pw.Document();
  
  final formattedStart = DateFormat('dd/MM/yyyy').format(startDate);
  final formattedEnd = DateFormat('dd/MM/yyyy').format(endDate);
  
  // Calculer solde initial et final
  double soldeInitial = 0.0;
  double totalDebit = 0.0;
  double totalCredit = 0.0;
  
  for (var op in operations) {
    if (op.type == OperationType.depot) {
      totalCredit += op.montantNet;
    } else if (op.type == OperationType.retrait) {
      totalDebit += op.montantNet;
    }
  }
  
  final soldeFinal = soldeInitial + totalCredit - totalDebit;
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // EN-TÊTE
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
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '🏪 ${shop.designation}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    '📍 ${shop.localisation ?? ""}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'RELEVÉ DE COMPTE',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Période: $formattedStart - $formattedEnd',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.yellow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // INFORMATIONS CLIENT
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue700),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '👤 ${client.nom}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '📞 ${client.telephone}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  if (client.numeroCompte != null)
                    pw.Text(
                      'N° Compte: ${client.numeroCompte}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Solde Actuel',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    '${client.solde.toStringAsFixed(2)} USD',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: client.solde >= 0 ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // RÉSUMÉ FINANCIER
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryBox('Dépôts', totalCredit, PdfColors.green700),
              _buildSummaryBox('Retraits', totalDebit, PdfColors.red700),
              _buildSummaryBox('Transactions', operations.length.toDouble(), PdfColors.blue700),
            ],
          ),
        ),
        
        pw.SizedBox(height: 20),
        
        // TITRE TABLEAU
        pw.Text(
          'HISTORIQUE DES TRANSACTIONS',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        
        pw.SizedBox(height: 8),
        
        // TABLEAU DES TRANSACTIONS
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableHeader('Date'),
                _buildTableHeader('Type'),
                _buildTableHeader('Débit'),
                _buildTableHeader('Crédit'),
                _buildTableHeader('Solde'),
              ],
            ),
            // Lignes de données
            ...operations.map((op) {
              final isCredit = op.type == OperationType.depot;
              final montant = op.montantNet;
              
              return pw.TableRow(
                children: [
                  _buildTableCell(DateFormat('dd/MM/yy HH:mm').format(op.dateOp)),
                  _buildTableCell(_getTypeLabel(op.type)),
                  _buildTableCellPdf(isCredit ? '' : montant.toStringAsFixed(2), align: pw.TextAlign.right, color: PdfColors.red700),
                  _buildTableCellPdf(isCredit ? montant.toStringAsFixed(2) : '', align: pw.TextAlign.right, color: PdfColors.green700),
                  _buildTableCellPdf('', align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),
        
        pw.SizedBox(height: 16),
        
        // TOTAUX
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue700, width: 2),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Débits:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Total Crédits:', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('${totalDebit.toStringAsFixed(2)} USD', 
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                  pw.Text('${totalCredit.toStringAsFixed(2)} USD', 
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                ],
              ),
            ],
          ),
        ),
        
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
              pw.Text(
                'Document généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'UCASH - Relevé de compte',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  
  return pdf;
}

/// Widget pour les cases de résumé
pw.Widget _buildSummaryBox(String label, double value, PdfColor color) {
  return pw.Column(
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        value.toStringAsFixed(2),
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}

/// Widget pour l'en-tête du tableau
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

/// Widget pour une cellule du tableau de relevé client
pw.Widget _buildTableCellPdf(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        color: color,
      ),
      textAlign: align,
    ),
  );
}
