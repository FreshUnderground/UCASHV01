import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/local_db.dart';
import '../../services/auth_service.dart';
import '../../services/document_header_service.dart';
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

  /// Supprimer une clôture (réservé aux admins)
  Future<void> _supprimerCloture(ClotureCaisseModel cloture) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Supprimer la clôture'),
        content: Text(
          'Voulez-vous vraiment supprimer la clôture du ${DateFormat('dd/MM/yyyy').format(cloture.dateCloture)} ?\n'
          'Shop: ${cloture.shopId}\n'
          'Clôturé par: ${cloture.cloturePar}\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await LocalDB.instance.deleteClotureCaisse(cloture.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Clôture supprimée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadClotures();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    
    // Charger le header depuis DocumentHeaderService (synchronisé avec MySQL)
    final headerService = DocumentHeaderService();
    await headerService.initialize();
    final header = headerService.getHeaderOrDefault();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          // EN-TÊTE (Style identique au rapport de clôture agent)
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
                        pw.Text('Historique des Clôtures', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('RAPPORT HISTORIQUE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // Résumé global
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Total Clôtures', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('${_clotures.length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                  ],
                ),
                pw.Container(width: 1, height: 30, color: PdfColors.blue300),
                pw.Column(
                  children: [
                    pw.Text('Validées', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('${_clotures.where((c) => (c.soldeSaisiTotal - c.soldeCalculeTotal).abs() < 0.01).length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ],
                ),
                pw.Container(width: 1, height: 30, color: PdfColors.blue300),
                pw.Column(
                  children: [
                    pw.Text('Avec Écart', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('${_clotures.where((c) => (c.soldeSaisiTotal - c.soldeCalculeTotal).abs() > 0.01).length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),
          
          // Tableau des clôtures (style amélioré)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red700),
                children: [
                  _buildPdfCell('Date', isHeader: true),
                  _buildPdfCell('Shop', isHeader: true),
                  _buildPdfCell('Solde Saisi', isHeader: true),
                  _buildPdfCell('Solde Calculé', isHeader: true),
                  _buildPdfCell('Écart', isHeader: true),
                  _buildPdfCell('Statut', isHeader: true),
                  _buildPdfCell('Agent', isHeader: true),
                ],
              ),
              // Rows
              ..._clotures.map((cloture) {
                final ecart = cloture.soldeSaisiTotal - cloture.soldeCalculeTotal;
                final isValid = ecart.abs() < 0.01;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isValid ? PdfColors.green50 : PdfColors.red50,
                  ),
                  children: [
                    _buildPdfCell(DateFormat('dd/MM/yyyy').format(cloture.dateCloture)),
                    _buildPdfCell('${cloture.shopId}'),
                    _buildPdfCell('${cloture.soldeSaisiTotal.toStringAsFixed(2)} \$'),
                    _buildPdfCell('${cloture.soldeCalculeTotal.toStringAsFixed(2)} \$'),
                    _buildPdfCell(
                      '${ecart.toStringAsFixed(2)} \$',
                      color: isValid ? PdfColors.green700 : PdfColors.red700,
                    ),
                    _buildPdfCell(
                      isValid ? '✓ OK' : '⚠ Écart',
                      color: isValid ? PdfColors.green700 : PdfColors.orange700,
                    ),
                    _buildPdfCell(cloture.cloturePar),
                  ],
                );
              }).toList(),
            ],
          ),
          
          pw.SizedBox(height: 16),
          
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
                pw.Text('Généré par: Système', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                pw.Text('Le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
              ],
            ),
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
          fontSize: isHeader ? 9 : 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
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
    final validClotures = _clotures.where((c) => (c.soldeSaisiTotal - c.soldeCalculeTotal).abs() < 0.01).length;
    final ecartClotures = _clotures.length - validClotures;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.list_alt, color: Color(0xFFDC2626), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historique des Clôtures Journalières',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suivi de toutes les clôtures effectuées',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportPDF,
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Exporter PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Statistiques
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Clôtures',
                    '${_clotures.length}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Validées',
                    '$validClotures',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avec Écart',
                    '$ecartClotures',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCloturesTable() {
    if (_clotures.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Aucune clôture trouvée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les clôtures effectuées apparaîtront ici',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Vérifier si l'utilisateur est admin
    final authService = Provider.of<AuthService>(context);
    final isAdmin = authService.currentUser?.role.toLowerCase() == 'admin';

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFDC2626)),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 13,
          ),
          dataRowHeight: 60,
          columns: [
            const DataColumn(label: Text('📅 Date')),
            const DataColumn(label: Text('🏪 Shop')),
            const DataColumn(label: Text('💰 Solde Saisi')),
            const DataColumn(label: Text('📊 Solde Calculé')),
            const DataColumn(label: Text('⚖️ Écart')),
            const DataColumn(label: Text('✓ Statut')),
            const DataColumn(label: Text('👤 Agent')),
            if (isAdmin) const DataColumn(label: Text('⚙️ Actions')),
          ],
          rows: _clotures.map((cloture) {
            final ecart = cloture.soldeSaisiTotal - cloture.soldeCalculeTotal;
            final hasEcart = ecart.abs() > 0.01;
            
            return DataRow(
              color: MaterialStateProperty.all(
                hasEcart ? Colors.red[50] : Colors.green[50],
              ),
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(cloture.dateCloture),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        DateFormat('HH:mm').format(cloture.dateCloture),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Shop ${cloture.shopId}',
                      style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${cloture.soldeSaisiTotal.toStringAsFixed(2)} \$',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text(
                    '${cloture.soldeCalculeTotal.toStringAsFixed(2)} \$',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasEcart ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasEcart ? Colors.red[300]! : Colors.green[300]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${ecart >= 0 ? '+' : ''}${ecart.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        color: hasEcart ? Colors.red[900] : Colors.green[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ecart.abs() < 0.01 ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ecart.abs() < 0.01 ? Icons.check_circle : Icons.warning_amber,
                          color: ecart.abs() < 0.01 ? Colors.green[700] : Colors.orange[700],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ecart.abs() < 0.01 ? 'Validé' : 'Écart',
                          style: TextStyle(
                            color: ecart.abs() < 0.01 ? Colors.green[900] : Colors.orange[900],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        cloture.cloturePar,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      tooltip: 'Supprimer la clôture',
                      onPressed: () => _supprimerCloture(cloture),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
