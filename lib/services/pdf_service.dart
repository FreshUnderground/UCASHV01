import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operation_model.dart';
import '../models/client_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../models/document_header_model.dart';
import 'pdf_config_service.dart';

/// Service PDF pour générer des reçus et rapports d'opérations
class PdfService {
  /// Charger l'en-tête depuis SharedPreferences
  Future<DocumentHeaderModel> _loadHeaderFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('document_header_active');
      
      if (cachedData != null) {
        final json = jsonDecode(cachedData);
        return DocumentHeaderModel.fromJson(json);
      }
    } catch (e) {
      // Retourner en-tête par défaut si erreur
    }
    
    // En-tête par défaut si rien n'est trouvé
    return DocumentHeaderModel(
      id: 0,
      companyName: 'UCASH',
      companySlogan: 'Merci pour votre confiance',
      address: '',
      phone: '',
      email: '',
      website: '',
      createdAt: DateTime.now(),
    );
  }
  
  /// Génère un PDF de reçu pour une opération (format ticket 58mm)
  Future<pw.Document> generateReceiptPdf({
    required OperationModel operation,
    ShopModel? shop,
    dynamic agent,  // AgentModel optionnel
    String? clientName,
  }) async {
    // Charger l'en-tête personnalisé depuis le cache local
    final headerModel = await _loadHeaderFromCache();
    
    // Utiliser les données de l'en-tête
    final companyName = headerModel.companyName;
    final companyAddress = headerModel.address ?? '';
    final companyPhone = headerModel.phone ?? '';
    final rccm = headerModel.registrationNumber ?? '';
    final idnat = headerModel.email ?? ''; // IDNAT stocké dans email
    final taxNumber = headerModel.taxNumber ?? '';
    final footerMessage = headerModel.companySlogan ?? 'Merci pour votre confiance';
    
    final pdf = pw.Document();
    
    // Format ticket thermique 58mm de largeur (Q2I)
    const double mmToPt = 2.83465;  // Conversion mm vers points
    final ticketFormat = PdfPageFormat(
      58 * mmToPt,  // Largeur: 58mm pour Q2I
      double.infinity,  // Hauteur: auto (s'adapte au contenu)
      marginAll: 4 * mmToPt,  // Marges réduites: 4mm
    );
    
    pdf.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // En-tête centrée
              pw.Text(
                companyName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (rccm.isNotEmpty)
                pw.Text(
                  'RCCM: $rccm',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              if (idnat.isNotEmpty)
                pw.Text(
                  'IDNAT: $idnat',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              if (taxNumber.isNotEmpty)
                pw.Text(
                  'N° Impôt: $taxNumber',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              // Adresse après le numéro d'impôt (taille réduite)
              if (companyAddress.isNotEmpty)
                pw.Text(
                  companyAddress,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              if (companyPhone.isNotEmpty)
                pw.Text(
                  companyPhone,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              
              pw.SizedBox(height: 6),
              
              // Titre du bordereau selon le type d'opération
              if (operation.type == OperationType.transfertNational ||
                  operation.type == OperationType.transfertInternationalSortant ||
                  operation.type == OperationType.transfertInternationalEntrant)
                pw.Text(
                  'BORDEREAU DE VERSEMENT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                )
              else if (operation.type == OperationType.depot)
                pw.Text(
                  'BORDEREAU DE VERSEMENT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                )
              else if (operation.type == OperationType.retrait)
                pw.Text(
                  'BORDEREAU DE RETRAIT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              
              pw.SizedBox(height: 6),
              
              // Informations opération (alignées à gauche)
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Pour Dépôt/Retrait: nouveau format simplifié
                    if (operation.type == OperationType.depot || operation.type == OperationType.retrait) ...[
                      // Ligne de séparation
                      pw.Container(
                        width: double.infinity,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 6),
                      
                      // Code (seulement le code en gras, sans label)
                      if (operation.codeOps != null && operation.codeOps!.isNotEmpty)
                        pw.Center(
                          child: pw.Text(
                            operation.codeOps!,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      pw.SizedBox(height: 6),
                      
                      // EXP.: Nom du client
                      if (clientName != null && clientName.isNotEmpty)
                        _buildTicketRow('EXP.:', clientName, fontSize: 9),
                      if (clientName == null && operation.clientNom != null && operation.clientNom!.isNotEmpty)
                        _buildTicketRow('EXP.:', operation.clientNom!, fontSize: 9),
                      
                      // DEST: Numéro du compte
                      if (operation.clientId != null)
                        _buildTicketRow('DEST:', operation.clientId.toString().padLeft(6, '0'), fontSize: 9),
                      
                      // Montant
                      pw.SizedBox(height: 4),
                      _buildTicketRow('MONTANT:', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}', fontSize: 11, bold: true),
                      
                      pw.SizedBox(height: 6),
                    ],
                    
                    // Pour Transfert: afficher expéditeur et destinataire
                    if (operation.type == OperationType.transfertNational || 
                        operation.type == OperationType.transfertInternationalSortant ||
                        operation.type == OperationType.transfertInternationalEntrant) ...[
                      
                      // Shop Source - Shop Destination (centré avec tiret, taille réduite)
                      if (operation.shopSourceDesignation != null && operation.shopDestinationDesignation != null)
                        pw.Center(
                          child: pw.Text(
                            '${operation.shopSourceDesignation}  -  ${operation.shopDestinationDesignation}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: double.infinity,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 6),
                      
                      // Code (seulement le code en gras, sans label)
                      if (operation.codeOps != null && operation.codeOps!.isNotEmpty)
                        pw.Center(
                          child: pw.Text(
                            operation.codeOps!,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      pw.SizedBox(height: 6),
                      
                      // Expéditeur et Destinataire (aligné à gauche)
                      if (clientName != null && clientName.isNotEmpty)
                        _buildTicketRow('EXP.:', clientName, fontSize: 9),
                      // DEST: affiche l'observation (nom du destinataire)
                      if (operation.observation != null && operation.observation!.isNotEmpty)
                        _buildTicketRow('DEST:', operation.observation!, fontSize: 9),
                      
                      // Montant (sans "TOTAL")
                      pw.SizedBox(height: 4),
                      _buildTicketRow('MONTANT:', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}', fontSize: 11, bold: true),
                      
                      pw.SizedBox(height: 6),
                    ],
                    
                    // Montants (uniquement pour non-transferts)
                    if (operation.type != OperationType.transfertNational && 
                        operation.type != OperationType.transfertInternationalSortant &&
                        operation.type != OperationType.transfertInternationalEntrant) ...[
                      pw.Text(
                        'DÉTAILS FINANCIERS',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      
                      _buildTicketRow('Montant:', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}', fontSize: 10),
                      if (operation.commission > 0)
                        _buildTicketRow('Frais/Commission:', '${operation.commission.toStringAsFixed(2)} ${operation.devise}'),
                      
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: double.infinity,
                        height: 0.5,
                        color: PdfColors.grey700,
                      ),
                      pw.SizedBox(height: 6),
                      
                      // Observation si elle existe
                      if (operation.observation != null && operation.observation!.isNotEmpty) ...[
                        pw.Text(
                          'OBSERVATION',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          operation.observation!,
                          style: const pw.TextStyle(
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.black,
              ),
              pw.SizedBox(height: 6),
              
              // Pied de page (taille réduite)
              pw.Text(
                footerMessage,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Imprimé le: ${DateFormat('dd/MM/yyyy à HH:mm:ss').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de rapport d'opérations pour un agent
  Future<pw.Document> generateOperationsReportPdf({
    required List<OperationModel> operations,
    required ShopModel shop,
    dynamic agent,  // AgentModel optionnel
    String? filterType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calculs
    final totalBrut = operations.fold<double>(0, (sum, op) => sum + op.montantBrut);
    final totalCommissions = operations.fold<double>(0, (sum, op) => sum + op.commission);
    final totalNet = operations.fold<double>(0, (sum, op) => sum + op.montantNet);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // En-tête
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UCASH', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(shop.designation, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('RAPPORT OPÉRATIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    if (startDate != null && endDate != null)
                      pw.Text(
                        '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Résumé
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Opérations', '${operations.length}'),
                _buildSummaryItem('Total Brut', '${totalBrut.toStringAsFixed(2)} USD'),
                _buildSummaryItem('Commissions', '${totalCommissions.toStringAsFixed(2)} USD'),
                _buildSummaryItem('Total Net', '${totalNet.toStringAsFixed(2)} USD'),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Tableau des opérations
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Destinataire'),
                  _buildTableHeader('Montant'),
                  _buildTableHeader('Statut'),
                ],
              ),
              // Données
              ...operations.map((op) => pw.TableRow(
                children: [
                  _buildTableCell(DateFormat('dd/MM HH:mm').format(op.dateOp)),
                  _buildTableCell(op.typeLabel),
                  _buildTableCell(op.destinataire ?? op.clientNom ?? '-'),
                  _buildTableCell('${op.montantNet.toStringAsFixed(2)} ${op.devise}'),
                  _buildTableCell(op.statutLabel),
                ],
              )),
            ],
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  /// Génère un PDF de relevé de compte client
  Future<pw.Document> generateClientStatementPdf({
    required ClientModel client,
    required List<OperationModel> operations,
    required ShopModel shop,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Calculer les totaux
    final depotsUSD = operations.where((op) => op.type == OperationType.depot && op.devise == 'USD').fold<double>(0, (sum, op) => sum + op.montantNet);
    final retraitsUSD = operations.where((op) => op.type == OperationType.retrait && op.devise == 'USD').fold<double>(0, (sum, op) => sum + op.montantNet);
    final depotsCDF = operations.where((op) => op.type == OperationType.depot && op.devise == 'CDF').fold<double>(0, (sum, op) => sum + op.montantNet);
    final retraitsCDF = operations.where((op) => op.type == OperationType.retrait && op.devise == 'CDF').fold<double>(0, (sum, op) => sum + op.montantNet);
    
    // Trier les opérations par date
    final sortedOps = List<OperationModel>.from(operations);
    sortedOps.sort((a, b) => a.dateOp.compareTo(b.dateOp));
    
    // Calculer le solde cumulé
    double soldeUSD = 0;
    double soldeCDF = 0;
    final opsWithBalance = sortedOps.map((op) {
      if (op.devise == 'USD') {
        if (op.type == OperationType.depot) {
          soldeUSD += op.montantNet;
        } else if (op.type == OperationType.retrait) {
          soldeUSD -= op.montantNet;
        }
        return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
      } else if (op.devise == 'CDF') {
        if (op.type == OperationType.depot) {
          soldeCDF += op.montantNet;
        } else if (op.type == OperationType.retrait) {
          soldeCDF -= op.montantNet;
        }
        return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
      }
      return {'op': op, 'soldeUSD': soldeUSD, 'soldeCDF': soldeCDF};
    }).toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // En-tête UCASH
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UCASH', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(shop.designation, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                  ],
                ),
                pw.Text(
                  'RELEVÉ DE COMPTE',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Informations client
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  client.nom.toUpperCase(),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('N° Compte: ${client.numeroCompte}', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text('Téléphone: ${client.telephone}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    if (startDate != null && endDate != null)
                      pw.Text(
                        'Période: Du ${DateFormat('dd/MM/yyyy').format(startDate)} au ${DateFormat('dd/MM/yyyy').format(endDate)}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // RÉSUMÉ DES MOUVEMENTS
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RÉSUMÉ DES MOUVEMENTS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    if (depotsUSD > 0 || retraitsUSD > 0)
                      pw.Column(
                        children: [
                          pw.Text('Dépôts USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${depotsUSD.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsUSD > 0 || retraitsUSD >0)
                      pw.Column(
                        children: [
                          pw.Text('Retraits USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${retraitsUSD.toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsUSD > 0 || retraitsUSD > 0)
                      pw.Column(
                        children: [
                          pw.Text('Solde USD', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${(depotsUSD - retraitsUSD).toStringAsFixed(2)} \$', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Dépôts CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${depotsCDF.toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Retraits CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${retraitsCDF.toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    if (depotsCDF > 0 || retraitsCDF > 0)
                      pw.Column(
                        children: [
                          pw.Text('Solde CDF', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                          pw.SizedBox(height: 4),
                          pw.Text('${(depotsCDF - retraitsCDF).toStringAsFixed(2)} FC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // HISTORIQUE DES TRANSACTIONS
          pw.Text(
            'HISTORIQUE DES TRANSACTIONS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),  // Date
              1: const pw.FlexColumnWidth(1.5),  // Type
              2: const pw.FlexColumnWidth(2.5),  // Observation
              3: const pw.FlexColumnWidth(1.5),  // Reçu
              4: const pw.FlexColumnWidth(1.5),  // Payé
              5: const pw.FlexColumnWidth(1.5),  // Solde
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Type'),
                  _buildTableHeader('Observation'),
                  _buildTableHeader('Reçu'),
                  _buildTableHeader('Payé'),
                  _buildTableHeader('Solde'),
                ],
              ),
              // Données
              ...opsWithBalance.map((item) {
                final op = item['op'] as OperationModel;
                final soldeU = item['soldeUSD'] as double;
                final soldeC = item['soldeCDF'] as double;
                final isDepo = op.type == OperationType.depot;
                final devise = op.devise == 'USD' ? '\$' : 'FC';
                final soldeActuel = op.devise == 'USD' ? soldeU : soldeC;
                
                return pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('dd/MM/yyyy').format(op.dateOp)),
                    _buildTableCell(op.type == OperationType.depot ? 'Dépôt' : 'Retrait'),
                    _buildTableCell(op.observation ?? op.notes ?? op.destinataire ?? '-'),
                    _buildTableCell(isDepo ? '${op.montantNet.toStringAsFixed(2)} $devise' : '--'),
                    _buildTableCell(!isDepo ? '${op.montantNet.toStringAsFixed(2)} $devise' : '--'),
                    _buildTableCell('${soldeActuel.toStringAsFixed(2)} $devise'),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Pied de page
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Édité le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'UCASH - ${shop.designation}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  // Helpers
  pw.Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
  
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
  
  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }
  
  // Helper pour les lignes de ticket thermique
  pw.Widget _buildTicketRow(String label, String value, {bool bold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize - 1,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper pour obtenir le label de statut
  String _getStatusLabel(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return 'EN ATTENTE';
      case OperationStatus.validee:
        return 'VALIDÉE';
      case OperationStatus.terminee:
        return 'TERMINÉE';
      case OperationStatus.annulee:
        return 'ANNULÉE';
      default:
        return statut.toString().toUpperCase();
    }
  }
  
  /// Génère un rapport de clôture agent (format A4 - similaire au rapport shop)
  Future<pw.Document> generateAgentClosureReport({
    required AgentModel agent,
    required ShopModel shop,
    required Map<String, double> soldesDisponibles, // {'USD': 1000.0, 'CDF': 50000.0}
    required List<Map<String, dynamic>> partenairesServis, // Clients qui nous doivent
    required List<Map<String, dynamic>> partenairesRecus, // Clients que nous devons
    DateTime? dateRapport,
  }) async {
    // Charger l'en-tête personnalisé
    final headerModel = await _loadHeaderFromCache();
    
    final companyName = headerModel.companyName;
    final companyAddress = headerModel.address ?? '';
    final companyPhone = headerModel.phone ?? '';
    
    final pdf = pw.Document();
    final dateNow = dateRapport ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(dateNow);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          // EN-TÊTE (même style que rapport shop)
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
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        if (companyAddress.isNotEmpty)
                          pw.Text(
                            companyAddress,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                          ),
                        if (companyPhone.isNotEmpty)
                          pw.Text(
                            companyPhone,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                          ),
                        pw.Text(
                          shop.designation,
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                        ),
                        pw.Text(
                          'Agent: ${agent.username}',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.yellow),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'RAPPORT CLÔTURE AGENT',
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
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          // SOLDES DISPONIBLES (même style que Cash Disponible Total)
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
                  'SOLDES DISPONIBLES',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...soldesDisponibles.entries.map((entry) {
                  return _buildPdfRow(
                    entry.key,
                    entry.value.toStringAsFixed(2),
                    bold: true,
                  );
                }).toList(),
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          // DEUX COLONNES (même layout que rapport shop)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // COLONNE GAUCHE - Partenaires Servis
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildPdfSection(
                      'PARTENAIRES SERVIS',
                      [
                        pw.Text(
                          '(Clients qui nous doivent)',
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Divider(),
                        if (partenairesServis.isEmpty)
                          pw.Text(
                            'Aucun',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          )
                        else
                          ...partenairesServis.map((p) {
                            return _buildPartenaireDetail(
                              p['nom'] ?? 'Inconnu',
                              p['reference'] ?? '',
                              p['montant'] ?? 0.0,
                              p['devise'] ?? 'USD',
                              PdfColors.red700,
                            );
                          }),
                        if (partenairesServis.isNotEmpty) ...[
                          pw.Divider(),
                          _buildPdfRow(
                            'TOTAL',
                            partenairesServis.fold<double>(
                              0.0,
                              (sum, p) => sum + (p['montant'] ?? 0.0),
                            ).toStringAsFixed(2),
                            bold: true,
                            color: PdfColors.red700,
                          ),
                        ],
                      ],
                      PdfColors.red700,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(width: 10),
              
              // COLONNE DROITE - Partenaires Reçus
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildPdfSection(
                      'PARTENAIRES REÇUS',
                      [
                        pw.Text(
                          '(Clients que nous devons)',
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Divider(),
                        if (partenairesRecus.isEmpty)
                          pw.Text(
                            'Aucun',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          )
                        else
                          ...partenairesRecus.map((p) {
                            return _buildPartenaireDetail(
                              p['nom'] ?? 'Inconnu',
                              p['reference'] ?? '',
                              p['montant'] ?? 0.0,
                              p['devise'] ?? 'USD',
                              PdfColors.green700,
                            );
                          }),
                        if (partenairesRecus.isNotEmpty) ...[
                          pw.Divider(),
                          _buildPdfRow(
                            'TOTAL',
                            partenairesRecus.fold<double>(
                              0.0,
                              (sum, p) => sum + (p['montant'] ?? 0.0),
                            ).toStringAsFixed(2),
                            bold: true,
                            color: PdfColors.green700,
                          ),
                        ],
                      ],
                      PdfColors.green700,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    return pdf;
  }
  
  // Helpers pour le rapport agent (style similaire au rapport shop)
  pw.Widget _buildPdfSection(String title, List<pw.Widget> children, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
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
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfRow(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPartenaireDetail(
    String nom,
    String reference,
    double montant,
    String devise,
    PdfColor color,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            nom,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (reference.isNotEmpty)
            pw.Text(
              'Réf: $reference',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '${montant.toStringAsFixed(2)} $devise',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: color,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Divider(color: PdfColors.grey300),
        ],
      ),
    );
  }
}
