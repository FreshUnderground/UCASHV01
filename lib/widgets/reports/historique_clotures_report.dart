import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../services/local_db.dart';
import '../../models/cloture_caisse_model.dart';

class HistoriqueCloturesReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;

  const HistoriqueCloturesReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
  });

  @override
  State<HistoriqueCloturesReport> createState() => _HistoriqueCloturesReportState();
}

class _HistoriqueCloturesReportState extends State<HistoriqueCloturesReport> {
  List<ClotureCaisseModel> _clotures = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClotures();
  }

  @override
  void didUpdateWidget(HistoriqueCloturesReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadClotures();
    }
  }

  Future<void> _loadClotures() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<ClotureCaisseModel> clotures;
      
      if (widget.shopId != null) {
        clotures = await LocalDB.instance.getCloturesCaisseByShop(widget.shopId!);
      } else {
        // Récupérer toutes les clôtures de tous les shops
        clotures = [];
        // TODO: Ajouter une méthode getAllClotures dans LocalDB si nécessaire
        // Pour l'instant, on utilise getCloturesCaisseByShop pour chaque shop
      }

      // Filtrer par date
      if (widget.startDate != null) {
        clotures = clotures.where((c) => 
          c.dateCloture.isAfter(widget.startDate!) || 
          c.dateCloture.isAtSameMomentAs(widget.startDate!)
        ).toList();
      }
      if (widget.endDate != null) {
        final endOfDay = DateTime(widget.endDate!.year, widget.endDate!.month, widget.endDate!.day, 23, 59, 59);
        clotures = clotures.where((c) => 
          c.dateCloture.isBefore(endOfDay) || 
          c.dateCloture.isAtSameMomentAs(endOfDay)
        ).toList();
      }

      // Trier par date décroissante
      clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));

      if (mounted) {
        setState(() {
          _clotures = clotures;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPDF() async {
    try {
      final pdf = await _generatePDF();
      final pdfBytes = await pdf.save();
      
      await Printing.sharePdf(
        bytes: pdfBytes, 
        filename: 'historique_clotures_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF généré avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Historique des Clôtures Journalières',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildPdfCell('Date', isHeader: true),
                  _buildPdfCell('Shop', isHeader: true),
                  _buildPdfCell('Solde Saisi', isHeader: true),
                  _buildPdfCell('Solde Calculé', isHeader: true),
                  _buildPdfCell('Écart', isHeader: true),
                  _buildPdfCell('Validé', isHeader: true),
                ],
              ),
              // Rows
              ..._clotures.map((cloture) {
                final ecart = cloture.soldeSaisiTotal - cloture.soldeCalculeTotal;
                return pw.TableRow(
                  children: [
                    _buildPdfCell(DateFormat('dd/MM/yyyy').format(cloture.dateCloture)),
                    _buildPdfCell('Shop ${cloture.shopId}'),
                    _buildPdfCell('${cloture.soldeSaisiTotal.toStringAsFixed(2)} \$'),
                    _buildPdfCell('${cloture.soldeCalculeTotal.toStringAsFixed(2)} \$'),
                    _buildPdfCell(
                      '${ecart.toStringAsFixed(2)} \$',
                      color: ecart.abs() > 0.01 ? PdfColors.red : PdfColors.green,
                    ),
                    _buildPdfCell(ecart.abs() < 0.01 ? 'Validé' : 'Écart'),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des clôtures...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Erreur lors du chargement', style: TextStyle(fontSize: 18, color: Colors.red[600])),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadClotures,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildCloturesTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            const Icon(Icons.list_alt, color: Color(0xFF0891B2), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historique',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_clotures.length} clôture(s)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _exportPDF,
              icon: const Icon(Icons.picture_as_pdf, size: 13),
              label: const Text('Exporter PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloturesTable() {
    if (_clotures.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Aucune clôture trouvée', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Shop', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Solde Saisi', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Solde Calculé', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Écart', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Validé', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Agent', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _clotures.map((cloture) {
            final ecart = cloture.soldeSaisiTotal - cloture.soldeCalculeTotal;
            final hasEcart = ecart.abs() > 0.01;
            
            return DataRow(
              cells: [
                DataCell(Text(DateFormat('dd/MM/yyyy').format(cloture.dateCloture))),
                DataCell(Text('Shop ${cloture.shopId}')),
                DataCell(Text('${cloture.soldeSaisiTotal.toStringAsFixed(2)} \$')),
                DataCell(Text('${cloture.soldeCalculeTotal.toStringAsFixed(2)} \$')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasEcart ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${ecart.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        color: hasEcart ? Colors.red[700] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Icon(
                    ecart.abs() < 0.01 ? Icons.check_circle : Icons.warning,
                    color: ecart.abs() < 0.01 ? Colors.green : Colors.orange,
                  ),
                ),
                DataCell(Text(cloture.cloturePar)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
