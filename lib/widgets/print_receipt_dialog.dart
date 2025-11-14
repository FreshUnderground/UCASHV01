import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../services/printer_service.dart';
import '../services/pdf_service.dart';
import 'pdf_viewer_dialog.dart';

/// Dialog pour l'impression de reçus sur imprimante thermique 54mm
/// L'impression est OPTIONNELLE - l'opération peut être finalisée sans imprimante
/// 
/// UTILISATION:
/// ```dart
/// await showDialog(
///   context: context,
///   barrierDismissible: true,
///   builder: (context) => PrintReceiptDialog(
///     operation: operation,
///     shop: shop,
///     agent: agent,
///     clientName: clientName,
///     onPrintSuccess: () {
///       Navigator.of(context).pop();
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('✓ Reçu imprimé')),
///       );
///     },
///     onSkipPrint: () {
///       Navigator.of(context).pop();
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('✓ Opération enregistrée (sans impression)')),
///       );
///     },
///   ),
/// );
/// ```

class PrintReceiptDialog extends StatefulWidget {
  final OperationModel operation;
  final ShopModel shop;
  final AgentModel agent;
  final String? clientName;
  final VoidCallback onPrintSuccess;
  final VoidCallback onSkipPrint;

  const PrintReceiptDialog({
    super.key,
    required this.operation,
    required this.shop,
    required this.agent,
    this.clientName,
    required this.onPrintSuccess,
    required this.onSkipPrint,
  });

  @override
  State<PrintReceiptDialog> createState() => _PrintReceiptDialogState();
}

class _PrintReceiptDialogState extends State<PrintReceiptDialog> {
  final PrinterService _printerService = PrinterService();
  final PdfService _pdfService = PdfService();
  bool _isChecking = true;
  bool _isPrinterAvailable = false;
  bool _isPrinting = false;
  String _statusMessage = 'Vérification de l\'imprimante...';

  @override
  void initState() {
    super.initState();
    _checkPrinter();
  }

  Future<void> _checkPrinter() async {
    // Sur Web, pas d'impression disponible
    if (kIsWeb) {
      setState(() {
        _isChecking = false;
        _isPrinterAvailable = false;
        _statusMessage = 'Impression non disponible sur navigateur Web';
      });
      return;
    }
    
    setState(() {
      _isChecking = true;
      _statusMessage = 'Recherche d\'imprimante...';
    });

    try {
      final isAvailable = await _printerService.checkPrinterAvailability();
      
      setState(() {
        _isPrinterAvailable = isAvailable;
        _isChecking = false;
        _statusMessage = isAvailable
            ? 'Imprimante trouvée: ${_printerService.connectedDevice?.name ?? "Inconnue"}'
            : 'Aucune imprimante disponible';
      });

      // Si imprimante disponible, imprimer automatiquement
      if (isAvailable) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _printReceipt();
      }
      // Si pas d'imprimante, ne pas bloquer - l'utilisateur peut continuer
    } catch (e) {
      setState(() {
        _isChecking = false;
        _isPrinterAvailable = false;
        _statusMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _printReceipt() async {
    setState(() {
      _isPrinting = true;
      _statusMessage = 'Impression en cours...';
    });

    try {
      await _printerService.printReceipt(
        operation: widget.operation,
        shop: widget.shop,
        agent: widget.agent,
        clientName: widget.clientName,
      );

      setState(() {
        _isPrinting = false;
        _statusMessage = 'Reçu imprimé avec succès!';
      });

      // Attendre un peu puis fermer et valider
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop();
        widget.onPrintSuccess();
      }
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _statusMessage = 'Erreur d\'impression: $e';
      });
    }
  }

  Future<void> _viewPdf() async {
    try {
      // TODO: Implement generateReceiptPdf method in PdfService
      // final pdfDoc = await _pdfService.generateReceiptPdf(
      //   operation: widget.operation,
      //   shop: widget.shop,
      //   agent: widget.agent,
      //   clientName: widget.clientName,
      // );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚧 Fonctionnalité PDF en cours de développement'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // await showPdfViewer(
        //   context: context,
        //   pdfDocument: pdfDoc,
        //   title: 'Reçu - ${widget.operation.typeLabel}',
        //   fileName: 'recu_${widget.operation.id ?? DateTime.now().millisecondsSinceEpoch}',
        // );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = MediaQuery.of(context).size.width <= 480;
    
    return PopScope(
      canPop: !_isPrinting,
      onPopInvoked: (didPop) {
        // Permettre de continuer sans impression
        if (!didPop && !_isPrinterAvailable && !_isChecking) {
          widget.onSkipPrint();
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _isPrinterAvailable ? Icons.print : Icons.print_disabled,
              color: _isPrinterAvailable ? Colors.green : Colors.orange,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Impression du reçu',
                style: TextStyle(fontSize: isMobile ? 16 : 18),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.6, // Maximum 60% de l'écran
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isChecking || _isPrinting)
                  const CircularProgressIndicator(),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: _isPrinterAvailable ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!_isPrinterAvailable && !_isChecking) ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: isMobile ? 40 : 48),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          'Imprimante non disponible',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          isMobile
                              ? 'Continuer sans imprimer ou réessayer.'
                              : 'Vous pouvez continuer sans imprimer le reçu ou réessayer la connexion.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!_isChecking && !_isPrinting) ...[
            // Bouton Voir PDF (toujours disponible)
            OutlinedButton.icon(
              onPressed: _viewPdf,
              icon: Icon(Icons.picture_as_pdf, size: isMobile ? 18 : 20),
              label: Text(
                'Voir PDF',
                style: TextStyle(fontSize: isMobile ? 13 : 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                minimumSize: Size(isMobile ? 90 : 110, isMobile ? 40 : 44),
              ),
            ),
            if (!_isPrinterAvailable)
              TextButton.icon(
                onPressed: _checkPrinter,
                icon: Icon(Icons.refresh, size: isMobile ? 18 : 20),
                label: Text(
                  'Réessayer',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSkipPrint();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: Text(
                _isPrinterAvailable ? 'Ignorer' : 'Continuer',
                style: TextStyle(fontSize: isMobile ? 13 : 14),
              ),
            ),
            if (_isPrinterAvailable)
              ElevatedButton.icon(
                onPressed: _printReceipt,
                icon: Icon(Icons.print, size: isMobile ? 18 : 20),
                label: Text(
                  'Imprimer',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(isMobile ? 100 : 120, isMobile ? 40 : 44),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
