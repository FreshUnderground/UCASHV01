import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'document_header_service.dart';

/// Service pour générer le PDF de la clôture virtuelle
Future<pw.Document> genererClotureVirtuellePDF(
  Map<String, dynamic> rapport,
  String shopDesignation,
  DateTime dateCloture,
) async {
  final pdf = pw.Document();
  
  // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final formattedDate = DateFormat('dd/MM/yyyy').format(dateCloture);
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => [
        // EN-TÊTE
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF48bb78),
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
                    pw.Text(header.companySlogan!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                  if (header.address?.isNotEmpty ?? false)
                    pw.Text(header.address!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  if (header.phone?.isNotEmpty ?? false)
                    pw.Text(header.phone!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  pw.Text(shopDesignation, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'CLÔTURE VIRTUELLE',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    formattedDate,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.yellow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 12),
        
        // === SOLDE ANTÉRIEUR CASH ===
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            border: pw.Border.all(color: PdfColors.green700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'SOLDE ANTÉRIEUR CASH',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
              ),
              pw.SizedBox(height: 8),
              _buildAmountRow('Cash au début de la journée', rapport['soldeAnterieurCash'] ?? 0.0, PdfColors.green700, bold: true, fontSize: 10),
              pw.SizedBox(height: 4),
              pw.Text(
                '(Solde cash de la dernière clôture)',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 12),
        
        // === SOLDE ANTÉRIEUR VIRTUEL ===
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            border: pw.Border.all(color: PdfColors.purple700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'SOLDE ANTÉRIEUR VIRTUEL',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
              ),
              pw.SizedBox(height: 8),
              _buildAmountRow('Solde virtuel au début de la journée', rapport['soldeAnterieurVirtuel'] ?? 0.0, PdfColors.purple, bold: true, fontSize: 10),
              pw.SizedBox(height: 4),
              pw.Text(
                '(Solde total des SIMs à la dernière clôture)',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 12),
        
        // === TRANSACTIONS VIRTUELLES ===
        _buildSection(
          'TRANSACTIONS VIRTUELLES',
          [
            _buildRow('Captures du jour', rapport['nombreCaptures'], rapport['montantTotalCaptures']),
            _buildRow('Servies', rapport['nombreServies'], rapport['montantVirtuelServies']),
            _buildRow('En attente', rapport['nombreEnAttente'], rapport['montantVirtuelEnAttente'], PdfColors.orange),
            _buildRow('Annulées', rapport['nombreAnnulees'], rapport['montantVirtuelAnnulees']),
            pw.Divider(),
            _buildAmountRow('Cash servi aux clients', rapport['cashServi'], PdfColors.green),
            _buildAmountRow('Frais perçus', rapport['fraisPercus'], const PdfColor.fromInt(0xFF48bb78)),
          ],
          PdfColors.blue,
        ),
        
        pw.SizedBox(height: 10),
        
        // Détails par SIM - Transactions
        if ((rapport['transactionsParSim'] as Map<String, Map<String, dynamic>>).isNotEmpty) ...[
          _buildDetailsParSimTransactions(rapport['transactionsParSim'] as Map<String, Map<String, dynamic>>),
          pw.SizedBox(height: 10),
        ],
        
        // === FLOTS ===
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            border: pw.Border.all(color: PdfColors.orange700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FLOTS',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
              ),
              pw.SizedBox(height: 8),
              _buildRow('Flots effectués', rapport['nombreRetraits'], rapport['montantTotalRetraits'], PdfColors.orange700),
              _buildRow('Remboursés', rapport['nombreRetraitsRembourses'], rapport['montantRetraitsRembourses'], PdfColors.green),
              _buildRow('En attente', rapport['nombreRetraitsEnAttente'], rapport['montantRetraitsEnAttente'], PdfColors.orange),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '⚠️ Les flots diminuent le solde virtuel des SIMs',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.orange900),
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // === TRANSFERTS VIRTUELS ===
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            border: pw.Border.all(color: PdfColors.purple700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FLOTS VIRTUELS (DÉPOTS)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
              ),
              pw.SizedBox(height: 8),
              _buildRow('Dépots effectués', rapport['nombreTransferts'] ?? 0, rapport['montantTotalTransferts'] ?? 0.0, PdfColors.purple700),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'ℹ️ Dépot (Virtuel → Cash) - opération interne',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.purple900),
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // === FLOTs PHYSIQUES (entre shops) ===
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FLOTs PHYSIQUES (entre shops)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
              ),
              pw.SizedBox(height: 8),
              _buildRow('FLOTs reçus', rapport['nombreFlotsRecus'] ?? 0, rapport['montantFlotsRecus'] ?? 0.0, PdfColors.green),
              _buildRow('FLOTs envoyés', rapport['nombreFlotsEnvoyes'] ?? 0, rapport['montantFlotsEnvoyes'] ?? 0.0, PdfColors.orange),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'ℹ️ Mouvements de cash physique entre shops',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue900),
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // Détails par SIM - Flots
        if ((rapport['retraitsParSim'] as Map<String, Map<String, dynamic>>).isNotEmpty) ...[
          _buildDetailsParSimFlots(rapport['retraitsParSim'] as Map<String, Map<String, dynamic>>),
          pw.SizedBox(height: 10),
        ],
                
        // Détails par SIM - Dépôts
        if ((rapport['depotsParSim'] as Map<String, Map<String, dynamic>>?)?.isNotEmpty ?? false) ...[
          _buildDetailsParSimDepots(rapport['depotsParSim'] as Map<String, Map<String, dynamic>>),
          pw.SizedBox(height: 10),
        ],
        
        // === SOLDES SIMS ===
        _buildSection(
          'SOLDES SIMS (${rapport['nombreTotalSims']} cartes)',
          [
            ...((rapport['soldesParOperateur'] as Map<String, double>).entries.map((e) {
              final nombre = (rapport['nombreSimsParOperateur'] as Map<String, int>)[e.key] ?? 0;
              return _buildAmountRow('${e.key} ($nombre SIMs)', e.value, null);
            }).toList()),
            pw.Divider(thickness: 1.5),
            _buildAmountRow('TOTAL SOLDE VIRTUEL', rapport['soldeTotalSims'], const PdfColor.fromInt(0xFF48bb78), bold: true, fontSize: 11),
          ],
          const PdfColor.fromInt(0xFF48bb78),
        ),
        
        pw.SizedBox(height: 10),
        
        // Détails par SIM - Soldes
        if ((rapport['detailsParSim'] as Map<String, Map<String, dynamic>>).isNotEmpty) ...[
          _buildDetailsParSimSoldes(rapport['detailsParSim'] as Map<String, Map<String, dynamic>>),
          pw.SizedBox(height: 10),
        ],
        
        // === RÉSUMÉ FINANCIER ===
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            border: pw.Border.all(color: PdfColors.purple700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'RÉSUMÉ FINANCIER',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
              ),
              pw.SizedBox(height: 8),
              _buildAmountRow('Solde total dans les SIMs', rapport['soldeTotalVirtuel'], PdfColors.green),
              _buildAmountRow('Cash dû aux clients (en attente)', rapport['cashDuAuxClients'], PdfColors.orange),
              _buildAmountRow('Frais de la journée', rapport['fraisTotalJournee'], PdfColors.blue),
            ],
          ),
        ),
        
        pw.SizedBox(height: 10),
        
        // === MOUVEMENTS DE CASH ===
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            border: pw.Border.all(color: PdfColors.indigo700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'MOUVEMENTS DE CASH',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700),
              ),
              pw.SizedBox(height: 8),
              _buildAmountRow('Cash sorti (captures)', rapport['cashSortiCaptures'], PdfColors.red),
              _buildAmountRow('Cash entrant (flots remboursés)', rapport['cashEntrantRetraitsRembourses'], PdfColors.green),
              _buildAmountRow('Cash entrant (dépôts)', rapport['montantTotalTransferts'] ?? 0.0, PdfColors.green),
              _buildAmountRow('FLOTs reçus', rapport['montantFlotsRecus'] ?? 0.0, PdfColors.green),
              _buildAmountRow('FLOTs envoyés', rapport['montantFlotsEnvoyes'] ?? 0.0, PdfColors.red),
              pw.Divider(),
              _buildAmountRow('Mouvement net de cash', rapport['mouvementNetCash'], 
                rapport['mouvementNetCash'] >= 0 ? PdfColors.green : PdfColors.red, bold: true, fontSize: 10),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Explication:',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'CASH SORTANT:',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                    pw.Text(
                      '• Capture: Client donne VIRTUEL → Nous donnons CASH',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.red),
                    ),
                    pw.Text(
                      '• FLOT envoyé: Nous envoyons CASH vers autre shop',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.red),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CASH ENTRANT:',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.green),
                    ),
                    pw.Text(
                      '• Flot remboursé: Via FLOT → Nous recevons CASH',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.green),
                    ),
                    pw.Text(
                      '• Dépôt (Virtuel → Cash): Conversion interne',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.green),
                    ),
                    pw.Text(
                      '• FLOT reçu: Nous recevons CASH d\'autre shop',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 12),
        
        // Footer
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Généré automatiquement',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
              pw.Text(
                'Le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  
  return pdf;
}

// Helper functions
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
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

pw.Widget _buildRow(String label, int count, double amount, [PdfColor? color]) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          width: 30,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '$count',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(
          width: 60,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildAmountRow(String label, double amount, PdfColor? color, {bool bold = false, double? fontSize}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize ?? 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '\$${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: fontSize ?? 8,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildDetailsParSimTransactions(Map<String, Map<String, dynamic>> transactionsParSim) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Détails par SIM - Transactions',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
        ),
        pw.SizedBox(height: 4),
        ...transactionsParSim.entries.map((entry) {
          final data = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue200),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SIM ${data['simNumero']}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _buildMiniRow('Captures', data['nombreCaptures'], data['montantCaptures']),
                _buildMiniRow('Servies', data['nombreServies'], data['montantServies']),
                if (data['nombreEnAttente'] > 0)
                  _buildMiniRow('En attente', data['nombreEnAttente'], data['montantEnAttente']),
                pw.Divider(height: 4),
                _buildMiniRow('Cash servi', null, data['cashServi']),
                _buildMiniRow('Frais', null, data['fraisServies']),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

pw.Widget _buildDetailsParSimFlots(Map<String, Map<String, dynamic>> retraitsParSim) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: PdfColors.orange50,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Détails par SIM - Flots',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
        ),
        pw.SizedBox(height: 4),
        ...retraitsParSim.entries.map((entry) {
          final data = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.orange200),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SIM ${data['simNumero']}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _buildMiniRow('Flots', data['nombreRetraits'], data['montantRetraits']),
                if (data['nombreRembourses'] > 0)
                  _buildMiniRow('Remboursés', data['nombreRembourses'], data['montantRembourses']),
                if (data['nombreEnAttente'] > 0)
                  _buildMiniRow('En attente', data['nombreEnAttente'], data['montantEnAttente']),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

pw.Widget _buildDetailsParSimDepots(Map<String, Map<String, dynamic>> depotsParSim) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: PdfColors.purple50,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Détails par SIM - Dépôts (Virtuel → Cash)',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
        ),
        pw.SizedBox(height: 4),
        ...depotsParSim.entries.map((entry) {
          final data = entry.value;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple200),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SIM ${data['simNumero']}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _buildMiniRow('Dépôts', data['nombreDepots'], data['montantDepots']),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

pw.Widget _buildDetailsParSimSoldes(Map<String, Map<String, dynamic>> detailsParSim) {
  // Grouper par opérateur
  final Map<String, List<Map<String, dynamic>>> parOperateur = {};
  for (var entry in detailsParSim.entries) {
    final operateur = entry.value['operateur'] as String;
    if (!parOperateur.containsKey(operateur)) {
      parOperateur[operateur] = [];
    }
    parOperateur[operateur]!.add(entry.value);
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFEBF8F2),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Détails par SIM - Soldes',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF48bb78)),
        ),
        pw.SizedBox(height: 4),
        ...parOperateur.entries.map((operateurEntry) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${operateurEntry.key} (${operateurEntry.value.length} SIMs)',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              ...operateurEntry.value.map((data) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SIM ${data['simNumero']}', style: const pw.TextStyle(fontSize: 6)),
                      pw.Text(
                        '\$${(data['soldeActuel'] as double).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        }).toList(),
      ],
    ),
  );
}

pw.Widget _buildMiniRow(String label, int? count, double amount) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 6))),
        if (count != null) pw.Text('$count', style: const pw.TextStyle(fontSize: 6)),
        pw.SizedBox(width: 4),
        pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}
