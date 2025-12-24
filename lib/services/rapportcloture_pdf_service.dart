import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/rapport_cloture_model.dart';
import '../models/shop_model.dart';
import 'document_header_service.dart';

/// Service pour générer le PDF du rapport de clôture
Future<pw.Document> genererRapportCloturePDF(RapportClotureModel rapport, ShopModel shop) async {
  final pdf = pw.Document();
  
  // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
  final headerService = DocumentHeaderService();
  await headerService.initialize();
  final header = headerService.getHeaderOrDefault();
  
  final formattedDate = DateFormat('dd/MM/yyyy').format(rapport.dateRapport);
  
  debugPrint('=== GÉNÉRATION PDF RAPPORT CLOTURE ===');
  debugPrint('Date: $formattedDate');
  debugPrint('Shop: ${shop.designation}');
  debugPrint('Cash Disponible Total: ${rapport.cashDisponibleTotal}');
  debugPrint('FLOTs Reçus: ${rapport.flotsRecusDetails.length}');
  debugPrint('FLOTs Envoyés: ${rapport.flotsEnvoyes.length}');
  debugPrint('Partenaires Servis: ${rapport.clientsNousDoivent.length}');
  debugPrint('Dépôts Partenaires: ${rapport.clientsNousDevons.length}');
  debugPrint('Shops Nous qui Doivent: ${rapport.shopsNousDoivent.length}');
  debugPrint('Shops Nous que Devons: ${rapport.shopsNousDevons.length}');
  debugPrint('=====================================');
  
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
            child: pw.Column(
              children: [
                pw.Row(
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
                        pw.Text('RAPPORT DE CLOTURE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.Text(formattedDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                      ],
                    ),
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
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.soldeAnterieurTotal, bold: true),
                    ], PdfColors.grey700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('2. Flots', [
                      _buildRow('FLOTs Reçus', rapport.flotRecu, color: PdfColors.green700),
                     _buildRow('FLOTs Envoyés', rapport.flotEnvoye, color: PdfColors.red700, prefix: '-'),
                      pw.SizedBox(height: 4),
                      _buildRow('= TOTAL FLOTs', rapport.flotRecu + rapport.flotsEnAttente - rapport.flotEnvoye, color: PdfColors.purple700, bold: true),
                      
                      // FLOTs Reçus Groupés par Shop Source
                      if (rapport.flotsRecusGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs Reçus:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsRecusGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.green700)),
                      ],

                      // FLOTs Reçus Groupés par Shop Source
                      if (rapport.flotsEnAttenteGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs En Attente:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsRecusGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.green700)),
                      ],
                     
                      // FLOTs Envoyés Groupés par Shop Destination
                      if (rapport.flotsEnvoyesGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('FLOTs Envoyés Détails (Groupé par Shop):', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.flotsEnvoyesGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.red700)),
                      ],
                    ], PdfColors.purple700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('4. Transferts', [
                      _buildRow('Recus', rapport.transfertsRecus, color: PdfColors.green700),
                      _buildRow('Servis', rapport.transfertsServis, color: PdfColors.red700, prefix: '-'),
                      _buildRow('Non Servi', rapport.transfertsEnAttente, color: PdfColors.orange700),
                      
                      // Transferts Reçus Groupés
                      if (rapport.transfertsRecusGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Transferts Reçus:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.transfertsRecusGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.green700)),
                      ],
                      
                      // Transferts Servis Groupés
                      if (rapport.transfertsServisGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Transferts Servis Détails:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.transfertsServisGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.red700)),
                      ],
                     
                      // Transferts En Attente Groupés par Shop
                      if (rapport.transfertsEnAttenteGroupes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(':', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.transfertsEnAttenteGroupes.entries.map((entry) => _buildDetailRow(entry.key, 'Total du jour', entry.value, PdfColors.orange700)),
                      ],
                    ], PdfColors.blue700),
                    pw.SizedBox(height: 8),
                    
                    // NOUVEAU: Compte FRAIS
                    _buildSection('5. Compte FRAIS', [
                      _buildRow('Frais Antérieur', rapport.soldeFraisAnterieur, color: PdfColors.grey700),
                      _buildRow('+ Frais encaissés', rapport.commissionsFraisDuJour, color: PdfColors.green700),
                       pw.SizedBox(height: 4),
                      _buildRow('- Sortie Frais du jour', rapport.retraitsFraisDuJour, color: PdfColors.red700, prefix: '-'),
                      // Détail des frais par shop
                      if (rapport.fraisGroupesParShop.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Détail par Shop:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.fraisGroupesParShop.entries.map((entry) => _buildDetailRow(
                          entry.key, // Nom du shop source
                          'Frais',
                          entry.value, // Montant des frais
                          PdfColors.green700,
                        )),
                      ],
                     pw.Divider(),
                      _buildRow('= Solde Frais du jour', rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour, color: PdfColors.green700, bold: true),
                    ], PdfColors.green700),

                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              
              // COLONNE DROITE
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildSection('6. Partenaires Servis', [
                      ...rapport.clientsNousDoivent.map((c) => _buildDetailRow(c.nom, '', c.solde, PdfColors.red700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalClientsNousDoivent, color: PdfColors.red700, bold: true),
                    ], PdfColors.red700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('7. Dépôts Partenaires', [
                      ...rapport.clientsNousDevons.map((c) => _buildDetailRow(c.nom, '', c.solde, PdfColors.green700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalClientsNousDevons, color: PdfColors.green700, bold: true),
                    ], PdfColors.green700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('8. Shops Qui Nous Doivent (DIFF. DETTES)', [
                      _buildRow('TOTAL', rapport.totalShopsNousDoivent, color: PdfColors.orange700, bold: true),
                    ], PdfColors.orange700),
                    pw.SizedBox(height: 8),
                    
                    _buildSection('9. Shop Que Nous Devons', [
                      pw.Text('${rapport.shopsNousDevons.length} shop(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      ...rapport.shopsNousDevons.map((s) => _buildDetailRow(s.designation, s.localisation, s.montant, PdfColors.purple700)),
                      pw.Divider(),
                      _buildRow('TOTAL', rapport.totalShopsNousDevons, color: PdfColors.purple700, bold: true),
                    ], PdfColors.purple700),
                    pw.SizedBox(height: 8),
                    
                    // NOUVEAU: Règlements Triangulaires de Dettes
                    if (rapport.triangularSettlements.isNotEmpty)
                      _buildSection('10. REGULARISATION', [
                        pw.Text('${rapport.triangularSettlements.length} règlement(s)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        ...rapport.triangularSettlements.map((s) {
                          // Déterminer le texte selon le rôle
                          String roleText;
                          switch (s.roleDuShopCourant) {
                            case 'debtor':
                              roleText = 'Débiteur';
                              break;
                            case 'intermediary':
                              roleText = 'Intermédiaire';
                              break;
                            case 'creditor':
                              roleText = 'Créancier';
                              break;
                            default:
                              roleText = 'Inconnu';
                          }
                          
                          // Déterminer le texte selon l'impact
                          String impactText;
                          switch (s.impactSurDette) {
                            case 'diminue':
                              impactText = 'Dette diminue';
                              break;
                            case 'augmente':
                              impactText = 'Dette augmente';
                              break;
                            case 'aucun':
                              impactText = 'Pas d\'impact';
                              break;
                            default:
                              impactText = 'Inconnu';
                          }
                          
                          return pw.Column(
                            children: [
                              pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex: 2,
                                    child: pw.Text('${s.reference}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                  ),
                                  pw.Expanded(
                                    flex: 1,
                                    child: pw.Text('${NumberFormat('#,##0.00').format(s.montant)} ${s.devise}', style: pw.TextStyle(fontSize: 8)),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex: 3,
                                    child: pw.Text('${s.shopDebtorDesignation} → ${s.shopIntermediaryDesignation} → ${s.shopCreditorDesignation}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex: 1,
                                    child: pw.Text('Rôle: $roleText', style: pw.TextStyle(fontSize: 7)),
                                  ),
                                  pw.Expanded(
                                    flex: 1,
                                    child: pw.Text('Impact: $impactText', style: pw.TextStyle(fontSize: 7)),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Divider(),
                            ],
                          );
                        }),
                      ], PdfColors.blue700),
                    pw.SizedBox(height: 8),
                    
                    // NOUVEAU: Section AUTRES SHOP (opérations où nous sommes destinataires)
                    if (rapport.autresShopServis > 0 || rapport.autresShopDepots > 0)
                      _buildSection('10. AUTRES SHOP', [
                        // SERVIS - Retraits où nous sommes destinataires
                        if (rapport.autresShopServis > 0) ...[
                          _buildRow('SERVIS ', rapport.autresShopServis, color: PdfColors.orange700),
                          
                          // Détails SERVIS groupés par client
                          if (rapport.autresShopServisGroupes.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Détail SERVIS par Client:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Divider(),
                            ...rapport.autresShopServisGroupes.entries.map((entry) => _buildDetailRow(
                              entry.key, // Nom du client (via shop)
                              'Retrait servi',
                              entry.value, // Montant servi
                              PdfColors.orange700,
                            )),
                          ],
                          pw.SizedBox(height: 4),
                        ],
                        
                        // DEPOT - Dépôts où nous sommes destinataires
                        if (rapport.autresShopDepots > 0) ...[
                          _buildRow('DEPOT', rapport.autresShopDepots, color: PdfColors.green700),
                          
                          // Détails DEPOT groupés par client
                          if (rapport.autresShopDepotsGroupes.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Détail DEPOT par Client:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Divider(),
                            ...rapport.autresShopDepotsGroupes.entries.map((entry) => _buildDetailRow(
                              entry.key, // Nom du client (via shop)
                              'Dépôt reçu',
                              entry.value, // Montant reçu
                              PdfColors.green700,
                            )),
                          ],
                        ],
                        
                        pw.Divider(),
                        _buildRow('TOTAL', rapport.autresShopServis + rapport.autresShopDepots, color: PdfColors.blue700, bold: true),
                      ], PdfColors.blue700),
                    pw.SizedBox(height: 8),
                    
                    // NOUVEAU: Section SOLDE PAR PARTENAIRE (depot - retrait où nous sommes destination)
                    _buildSection('11. SOLDE PAR PARTENAIRE', [
                        // Afficher chaque partenaire avec son solde
                        if (rapport.soldeParPartenaire.isEmpty)
                          pw.Text('Aucune opération partenaire trouvée', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic))
                        else
                          ...rapport.soldeParPartenaire.entries.map((entry) {
                            final solde = entry.value;
                            final color = solde > 0 ? PdfColors.red700 : solde < 0 ? PdfColors.green700 : PdfColors.grey700;
                            
                            return _buildDetailRowWithSign(
                              entry.key, // Nom du partenaire
                              '',
                              solde, // Afficher avec le signe
                              color,
                            );
                          }),
                        
                        pw.Divider(),
                        (() {
                          final totalSolde = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                          final color = totalSolde > 0 ? PdfColors.red700 : totalSolde < 0 ? PdfColors.green700 : PdfColors.grey700;
                          return _buildRowWithSign('SOLDE NET PARTENAIRES', totalSolde, color: color, bold: true);
                        }()),
                      ], PdfColors.blue700),
                    pw.SizedBox(height: 8),
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
                pw.Text(
                  '${rapport.capitalNet.toStringAsFixed(2)} USD', 
                  style: pw.TextStyle(
                    fontSize: 20, 
                    fontWeight: pw.FontWeight.bold, 
                    color: rapport.capitalNet >= 0 ? PdfColors.blue900 : PdfColors.red900
                  )
                ),
                pw.Divider(),
                _buildRow('Cash Disponible', rapport.cashDisponibleTotal, color: PdfColors.green700),
                _buildRow('+ DIFF. DETTES', rapport.totalShopsNousDoivent, color: PdfColors.orange700),
                _buildRow('- Shops Que Nous Devons', rapport.totalShopsNousDevons, color: PdfColors.purple700),
                _buildRow('- Solde Frais du jour', rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour, color: PdfColors.grey700),
                _buildRow('- Non Servis', rapport.transfertsEnAttente, color: PdfColors.orange700),
                (() {
                  final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                  return _buildRowWithSign('+/- Solde Net Partenaires', totalSoldePartenaire, color: totalSoldePartenaire >= 0 ? PdfColors.blue700 : PdfColors.red700);
                }()),
                pw.Divider(thickness: 2, color: PdfColors.blue700),
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
              pw.Text(name, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.normal)),
              if (detail.isNotEmpty)
                pw.Text(detail, style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text('${montant.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 7, color: color, fontWeight: pw.FontWeight.normal)),
      ],
    ),
  );
}

pw.Widget _buildOperationDetailRow(String observation, String details, double montant, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(observation, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.normal)),
              pw.Text(details, style: pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text('${montant.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 6, color: color, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _buildTransfertRouteRowPDF(TransfertRouteResume route) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                '${route.shopSourceDesignation} → ${route.shopDestinationDesignation}',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Transferts: ${route.transfertsCount}', style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700)),
            pw.Text('${route.transfertsTotal.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Servis: ${route.servisCount}', style: pw.TextStyle(fontSize: 6, color: PdfColors.green700)),
            pw.Text('${route.servisTotal.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 6, color: PdfColors.green700)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Non Servis : ${route.enAttenteCount}', style: pw.TextStyle(fontSize: 6, color: PdfColors.orange700)),
            pw.Text('${route.enAttenteTotal.toStringAsFixed(2)} USD', style: pw.TextStyle(fontSize: 6, color: PdfColors.orange700)),
          ],
        ),
        pw.Divider(height: 4, thickness: 0.5),
      ],
    ),
  );
}

// Nouvelle méthode pour afficher les montants avec signe
pw.Widget _buildDetailRowWithSign(String observation, String details, double montant, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(observation, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.normal)),
              if (details.isNotEmpty) pw.Text(details, style: pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text(
          montant < 0 ? '-${montant.abs().toStringAsFixed(2)} USD' : '${montant.toStringAsFixed(2)} USD', 
          style: pw.TextStyle(fontSize: 6, color: color, fontWeight: pw.FontWeight.bold)
        ),
      ],
    ),
  );
}

// Nouvelle méthode pour afficher les totaux avec signe
pw.Widget _buildRowWithSign(String label, double montant, {PdfColor? color, bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(
          montant < 0 ? '-${montant.abs().toStringAsFixed(2)} USD' : '${montant.toStringAsFixed(2)} USD',
          style: pw.TextStyle(fontSize: 7, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)
        ),
      ],
    ),
  );
}
