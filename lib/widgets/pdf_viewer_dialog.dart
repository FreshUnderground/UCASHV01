import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

/// Dialog pour visualiser, imprimer et télécharger un PDF
class PdfViewerDialog extends StatefulWidget {
  final pw.Document pdfDocument;
  final String title;
  final String fileName;

  const PdfViewerDialog({
    super.key,
    required this.pdfDocument,
    required this.title,
    required this.fileName,
  });

  @override
  State<PdfViewerDialog> createState() => _PdfViewerDialogState();
}

class _PdfViewerDialogState extends State<PdfViewerDialog> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final bytes = await widget.pdfDocument.save();
      
      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement du PDF: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _printPdf() async {
    if (_pdfBytes == null) return;

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
        name: widget.fileName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Impression lancée'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur d\'impression: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;

    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: '${widget.fileName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur de partage: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Container(
        width: isMobile ? size.width - 32 : (isTablet ? size.width * 0.85 : size.width * 0.75),
        height: isMobile ? size.height * 0.9 : size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // En-tête
            _buildHeader(isMobile),
            
            // Contenu PDF
            Expanded(
              child: _buildContent(isMobile),
            ),
            
            // Actions
            _buildActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Génération du PDF...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
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

    if (_pdfBytes == null) {
      return const Center(
        child: Text(
          'Aucun contenu à afficher',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PdfPreview(
        build: (format) => _pdfBytes!,
        allowSharing: false,
        allowPrinting: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: widget.fileName,
        scrollViewDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildActions(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: isMobile 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPrintButton(isMobile),
                const SizedBox(height: 8),
                _buildDownloadButton(isMobile),
                const SizedBox(height: 12),
                _buildCloseButton(isMobile),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCloseButton(isMobile),
                const Spacer(),
                _buildDownloadButton(isMobile),
                const SizedBox(width: 12),
                _buildPrintButton(isMobile),
              ],
            ),
    );
  }

  Widget _buildPrintButton(bool isMobile) {
    return ElevatedButton.icon(
      onPressed: _pdfBytes != null ? _printPdf : null,
      icon: Icon(Icons.print, size: isMobile ? 20 : 22),
      label: Text(
        'Imprimer',
        style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 24,
          vertical: isMobile ? 14 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildDownloadButton(bool isMobile) {
    return OutlinedButton.icon(
      onPressed: _pdfBytes != null ? _sharePdf : null,
      icon: Icon(Icons.download, size: isMobile ? 20 : 22),
      label: Text(
        'Télécharger',
        style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDC2626),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 24,
          vertical: isMobile ? 14 : 16,
        ),
        side: const BorderSide(color: Color(0xFFDC2626), width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildCloseButton(bool isMobile) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(Icons.close, size: isMobile ? 18 : 20),
      label: Text(
        'Fermer',
        style: TextStyle(fontSize: isMobile ? 14 : 15),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 12 : 14,
        ),
      ),
    );
  }
}

/// Fonction helper pour afficher le dialog PDF
Future<void> showPdfViewer({
  required BuildContext context,
  required pw.Document pdfDocument,
  required String title,
  required String fileName,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PdfViewerDialog(
      pdfDocument: pdfDocument,
      title: title,
      fileName: fileName,
    ),
  );
}
