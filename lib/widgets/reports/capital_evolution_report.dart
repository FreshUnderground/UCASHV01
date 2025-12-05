import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/shop_service.dart';
import '../../services/local_db.dart';
import '../../services/rapport_cloture_service.dart';
import '../../services/document_header_service.dart';
import '../../models/shop_model.dart';
import '../../models/cloture_caisse_model.dart';

/// Rapport d'evolution du capital pour tous les shops
class CapitalEvolutionReport extends StatefulWidget {
  const CapitalEvolutionReport({super.key});

  @override
  State<CapitalEvolutionReport> createState() => _CapitalEvolutionReportState();
}

class _CapitalEvolutionReportState extends State<CapitalEvolutionReport> {
  bool _isLoading = true;
  List<ShopCapitalEvolution> _shopEvolutions = [];
  double _totalCapitalInitial = 0.0;
  double _totalCapitalFinal = 0.0;
  double _totalEvolution = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      await shopService.loadShops();
      
      final shops = shopService.shops;
      final List<ShopCapitalEvolution> evolutions = [];
      
      double totalInitial = 0.0;
      double totalFinal = 0.0;

      for (final shop in shops) {
        // Recuperer toutes les clotures du shop
        final clotures = await LocalDB.instance.getCloturesCaisseByShop(shop.id!);
        
        debugPrint('📊 [CapitalEvolution] Analyse ${shop.designation}:');
        debugPrint('   Nombre de clôtures: ${clotures.length}');
        if (clotures.isNotEmpty) {
          debugPrint('   Première clôture: ${clotures.last.dateCloture}');
          debugPrint('   Dernière clôture: ${clotures.first.dateCloture}');
        }
        
        if (clotures.isEmpty) {
          // Si pas de cloture, utiliser le capital actuel comme capital initial ET final
          debugPrint('📊 [CapitalEvolution] ${shop.designation}: Aucune clôture trouvée');
          debugPrint('   Capital Initial: \$${shop.capitalInitial.toStringAsFixed(2)}');
          debugPrint('   Capital Actuel (final): \$${shop.capitalActuel.toStringAsFixed(2)}');
          
          evolutions.add(ShopCapitalEvolution(
            shopId: shop.id!,
            shopDesignation: shop.designation,
            capitalInitial: shop.capitalInitial,
            capitalFinal: shop.capitalActuel,
            dateFirstCloture: shop.createdAt ?? DateTime.now(),
            dateLastCloture: shop.createdAt ?? DateTime.now(),
            nbClotures: 0,
          ));
          totalInitial += shop.capitalInitial;
          totalFinal += shop.capitalActuel;
        } else {
          // Trier les clotures par date
          clotures.sort((a, b) => a.dateCloture.compareTo(b.dateCloture));
          
          final firstCloture = clotures.first;
          final lastCloture = clotures.last;
          
          // IMPORTANT: 
          // - Capital INITIAL = Capital de départ du shop (shop.capitalInitial)
          // - Capital FINAL = Capital Net Final calculé à partir de la dernière clôture + opérations suivantes
          final capitalInitial = shop.capitalInitial;
          
          // Générer un rapport pour aujourd'hui pour obtenir le capital net final actuel
          // Cela inclut: Solde Antérieur (dernière clôture) + Activités (opérations suivantes)
          double capitalFinal;
          try {
            final rapport = await RapportClotureService.instance.genererRapport(
              shopId: shop.id!,
              date: DateTime.now(), // Générer pour aujourd'hui au lieu de la dernière clôture
            );
            // Le capital net final est le capital net du rapport
            capitalFinal = rapport.capitalNet;
            debugPrint('✅ Capital Net Final pour ${shop.designation}: \$${capitalFinal.toStringAsFixed(2)}');
          } catch (e) {
            debugPrint('⚠️ Erreur génération rapport pour ${shop.designation}: $e');
            // Fallback: utiliser le solde calculé total de la dernière clôture
            capitalFinal = lastCloture.soldeCalculeTotal;
          }
          
          debugPrint('📊 [CapitalEvolution] Calcul pour ${shop.designation}:');
          debugPrint('   Capital Initial: \$${capitalInitial.toStringAsFixed(2)}');
          debugPrint('   Dernière clôture: ${lastCloture.dateCloture}');
          debugPrint('   Capital Net Final (Solde Antérieur + Activités): \$${capitalFinal.toStringAsFixed(2)}');
          debugPrint('   Évolution: \$${(capitalFinal - capitalInitial).toStringAsFixed(2)}');
          
          evolutions.add(ShopCapitalEvolution(
            shopId: shop.id!,
            shopDesignation: shop.designation,
            capitalInitial: capitalInitial,
            capitalFinal: capitalFinal,
            dateFirstCloture: firstCloture.dateCloture,
            dateLastCloture: lastCloture.dateCloture,
            nbClotures: clotures.length,
            firstCloture: firstCloture,
            lastCloture: lastCloture,
          ));
          
          totalInitial += capitalInitial;
          totalFinal += capitalFinal;
        }
      }

      setState(() {
        _shopEvolutions = evolutions;
        _totalCapitalInitial = totalInitial;
        _totalCapitalFinal = totalFinal;
        _totalEvolution = totalFinal - totalInitial;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement evolution capital: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolution du Capital'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Partager',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printReport,
            tooltip: 'Imprimer',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadPDF,
            tooltip: 'Telecharger PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReportContent(),
    );
  }

  Widget _buildReportContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildShopsTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFFDC2626),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RAPPORT D\'EVOLUTION DU CAPITAL',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        'Analyse de la croissance du capital par shop',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildInfoChip(Icons.store, '${_shopEvolutions.length} Shops'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.calendar_today, DateFormat('dd/MM/yyyy').format(DateTime.now())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final tauxEvolution = _totalCapitalInitial > 0
        ? ((_totalEvolution / _totalCapitalInitial) * 100)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Capital Initial',
            _totalCapitalInitial,
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Capital Final',
            _totalCapitalFinal,
            Icons.account_balance,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEvolutionCard(
            'Evolution',
            _totalEvolution,
            tauxEvolution,
            _totalEvolution >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '\$${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionCard(String title, double amount, double percentage, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  amount >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${amount >= 0 ? '+' : ''}\$${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${amount >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail par Shop',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Shop', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Capital Initial', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Capital Final', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Evolution', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Taux', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Periode', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Clotures', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _shopEvolutions.map((evolution) {
                  final evolutionAmount = evolution.capitalFinal - evolution.capitalInitial;
                  final tauxEvolution = evolution.capitalInitial > 0
                      ? ((evolutionAmount / evolution.capitalInitial) * 100)
                      : 0.0;
                  final color = evolutionAmount >= 0 ? Colors.green : Colors.red;

                  return DataRow(
                    cells: [
                      DataCell(Text(evolution.shopDesignation)),
                      DataCell(Text('\$${NumberFormat('#,##0.00').format(evolution.capitalInitial)}')),
                      DataCell(Text('\$${NumberFormat('#,##0.00').format(evolution.capitalFinal)}')),
                      DataCell(
                        Text(
                          '${evolutionAmount >= 0 ? '+' : ''}\$${NumberFormat('#,##0.00').format(evolutionAmount)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${evolutionAmount >= 0 ? '+' : ''}${tauxEvolution.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${DateFormat('dd/MM/yy').format(evolution.dateFirstCloture)} -> ${DateFormat('dd/MM/yy').format(evolution.dateLastCloture)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(Text(evolution.nbClotures.toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReport() async {
    try {
      final pdfBytes = await _generatePDF();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/evolution_capital_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF genere: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () => Printing.sharePdf(bytes: Uint8List.fromList(pdfBytes), filename: file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur partage: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printReport() async {
    try {
      final pdfBytes = await _generatePDF();
      await Printing.layoutPdf(onLayout: (format) async => Uint8List.fromList(pdfBytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur impression: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final pdfBytes = await _generatePDF();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/evolution_capital_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF telecharge: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () => Printing.sharePdf(bytes: Uint8List.fromList(pdfBytes), filename: file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur telechargement: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<List<int>> _generatePDF() async {
    final pdf = pw.Document();
    
    // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
    final headerService = DocumentHeaderService();
    await headerService.initialize();
    final header = headerService.getHeaderOrDefault();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
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
                            color: PdfColors.red700,
                          ),
                        ),
                        if (header.companySlogan?.isNotEmpty ?? false)
                          pw.Text(
                            header.companySlogan!,
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                        if (header.address?.isNotEmpty ?? false)
                          pw.Text(
                            header.address!,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        if (header.phone?.isNotEmpty ?? false)
                          pw.Text(
                            header.phone!,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'RAPPORT D\'EVOLUTION DU CAPITAL',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                        pw.Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('Analyse - ${_shopEvolutions.length} Shops', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Divider(thickness: 2),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfSummaryItem('Capital Initial', _totalCapitalInitial),
                _buildPdfSummaryItem('Capital Final', _totalCapitalFinal),
                _buildPdfSummaryItem('Evolution', _totalEvolution),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Detail par Shop', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildPdfTableCell('Shop', isHeader: true),
                  _buildPdfTableCell('Capital Initial', isHeader: true),
                  _buildPdfTableCell('Capital Final', isHeader: true),
                  _buildPdfTableCell('Evolution', isHeader: true),
                  _buildPdfTableCell('Taux', isHeader: true),
                ],
              ),
              ..._shopEvolutions.map((evolution) {
                final evolutionAmount = evolution.capitalFinal - evolution.capitalInitial;
                final tauxEvolution = evolution.capitalInitial > 0 ? ((evolutionAmount / evolution.capitalInitial) * 100) : 0.0;
                return pw.TableRow(
                  children: [
                    _buildPdfTableCell(evolution.shopDesignation),
                    _buildPdfTableCell('\$${NumberFormat('#,##0.00').format(evolution.capitalInitial)}'),
                    _buildPdfTableCell('\$${NumberFormat('#,##0.00').format(evolution.capitalFinal)}'),
                    _buildPdfTableCell('${evolutionAmount >= 0 ? '+' : ''}\$${NumberFormat('#,##0.00').format(evolutionAmount)}'),
                    _buildPdfTableCell('${evolutionAmount >= 0 ? '+' : ''}${tauxEvolution.toStringAsFixed(1)}%'),
                  ],
                );
              }).toList(),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildPdfTableCell('TOTAL', isHeader: true),
                  _buildPdfTableCell('\$${NumberFormat('#,##0.00').format(_totalCapitalInitial)}', isHeader: true),
                  _buildPdfTableCell('\$${NumberFormat('#,##0.00').format(_totalCapitalFinal)}', isHeader: true),
                  _buildPdfTableCell('${_totalEvolution >= 0 ? '+' : ''}\$${NumberFormat('#,##0.00').format(_totalEvolution)}', isHeader: true),
                  _buildPdfTableCell('${_totalEvolution >= 0 ? '+' : ''}${(_totalCapitalInitial > 0 ? ((_totalEvolution / _totalCapitalInitial) * 100) : 0.0).toStringAsFixed(1)}%', isHeader: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Genere le ${DateFormat('dd/MM/yyyy a HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );
    
    return pdf.save();
  }

  pw.Widget _buildPdfSummaryItem(String label, double amount) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text('\$${NumberFormat('#,##0.00').format(amount)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: isHeader ? 10 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}

class ShopCapitalEvolution {
  final int shopId;
  final String shopDesignation;
  final double capitalInitial;
  final double capitalFinal;
  final DateTime dateFirstCloture;
  final DateTime dateLastCloture;
  final int nbClotures;
  final ClotureCaisseModel? firstCloture;
  final ClotureCaisseModel? lastCloture;

  ShopCapitalEvolution({
    required this.shopId,
    required this.shopDesignation,
    required this.capitalInitial,
    required this.capitalFinal,
    required this.dateFirstCloture,
    required this.dateLastCloture,
    required this.nbClotures,
    this.firstCloture,
    this.lastCloture,
  });

  double get evolution => capitalFinal - capitalInitial;
  double get tauxEvolution => capitalInitial > 0 ? ((evolution / capitalInitial) * 100) : 0.0;
}
