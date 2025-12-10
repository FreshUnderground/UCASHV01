import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../services/printer_service.dart';
import '../services/pdf_service.dart';
import '../widgets/pdf_viewer_dialog.dart';

/// Helper pour impression automatique des reçus après opération
/// Imprime directement sur POS sans prévisualisation PDF
/// Sur Web: Affiche un PDF téléchargeable
/// Sur Mobile: Imprime sur imprimante thermique (Q2i ou Bluetooth)
class AutoPrintHelper {
  static final PrinterService _printerService = PrinterService();

  /// Méthode principale - Détecte automatiquement la plateforme
  /// Utiliser cette méthode pour une expérience unifiée
  /// Utilise Printing.layoutPdf() sur toutes les plateformes pour le sélecteur d'imprimante
  static Future<bool> autoPrint({
    required BuildContext context,
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
    bool showSuccessMessage = true,
    bool isWithdrawalReceipt = false,  // Pour bon de retrait lors de validation transfert
  }) async {
    // Sur Web et Mobile: utiliser le même système PDF avec sélecteur d'imprimante
    return await _printWithPdfSelector(
      context: context,
      operation: operation,
      shop: shop,
      agent: agent,
      clientName: clientName,
      showSuccessMessage: showSuccessMessage,
      isWithdrawalReceipt: isWithdrawalReceipt,
    );
  }

  /// Gère l'impression via PDF avec sélecteur d'imprimante (Web et Mobile)
  static Future<bool> _printWithPdfSelector({
    required BuildContext context,
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
    bool showSuccessMessage = true,
    bool isWithdrawalReceipt = false,
  }) async {
    try {
      debugPrint('🖨️ [AutoPrintHelper] Génération PDF pour opération #${operation.id}');
      
      // Générer le PDF
      final pdfService = PdfService();
      final pdfDoc = isWithdrawalReceipt
          ? await pdfService.generateWithdrawalReceipt(
              operation: operation,
              shop: shop,
              agent: agent,
              destinataireName: clientName ?? operation.destinataire ?? operation.observation,
            )
          : await pdfService.generateReceiptPdf(
              operation: operation,
              shop: shop,
              agent: agent,
              clientName: clientName,
            );
      
      final pdfBytes = await pdfDoc.save();
      
      // Ouvrir le sélecteur d'imprimante avec Printing.layoutPdf()
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'recu-${operation.codeOps ?? operation.id ?? "operation"}-${DateTime.now().millisecondsSinceEpoch}',
        format: const PdfPageFormat(
          58 * PdfPageFormat.mm, // Largeur 58mm pour imprimante thermique Q2I
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
      );
      
      debugPrint('✅ [AutoPrintHelper] Sélecteur d\'imprimante ouvert');
      
      if (context.mounted && showSuccessMessage) {
        _showSnackBar(
          context,
          '✅ Reçu prêt à imprimer',
          backgroundColor: Colors.green,
        );
      }
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [AutoPrintHelper] ERREUR impression PDF: $e');
      debugPrint('📍 [AutoPrintHelper] Stack trace: $stackTrace');
      
      if (context.mounted) {
        _showSnackBar(
          context,
          '❌ Erreur impression: $e',
          backgroundColor: Colors.red,
        );
      }
      
      return false;
    }
  }

  /// Imprime automatiquement un reçu d'opération
  /// Retourne true si l'impression a réussi, false sinon
  /// Utilise Printing.layoutPdf() pour ouvrir le sélecteur d'imprimante
  static Future<bool> autoPrintReceipt({
    required BuildContext context,
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
    bool showSuccessMessage = true,
    bool isWithdrawalReceipt = false,
  }) async {
    // Utiliser le même système que autoPrint
    return await _printWithPdfSelector(
      context: context,
      operation: operation,
      shop: shop,
      agent: agent,
      clientName: clientName,
      showSuccessMessage: showSuccessMessage,
      isWithdrawalReceipt: isWithdrawalReceipt,
    );
  }

  /// Affiche un dialog de sélection d'imprimante puis imprime
  /// Utilise Printing.layoutPdf() pour ouvrir le sélecteur d'imprimante
  static Future<bool> autoPrintWithDialog({
    required BuildContext context,
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
    bool isWithdrawalReceipt = false,  // Pour bon de retrait lors de validation transfert
  }) async {
    try {

      // Afficher le dialog de confirmation
      final shouldPrint = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print, color: Colors.blue),
              SizedBox(width: 12),
              Text('Imprimer le reçu'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voulez-vous imprimer le reçu ?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Add operation details including CodeOps
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opération: ${operation.typeLabel}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (operation.codeOps != null)
                      Text(
                        'Code: ${operation.codeOps}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Montant: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (operation.destinataire != null)
                      Text(
                        'Destinataire: ${operation.destinataire}',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),

            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ignorer'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                               
                // Générer et afficher le PDF avec l'aperçu d'impression
                try {
                  debugPrint('🖨️ [AutoPrintHelper] Génération PDF pour impression directe');
                  
                  // Générer le PDF via PdfService
                  final pdfService = PdfService();
                  final pdfDoc = isWithdrawalReceipt
                      ? await pdfService.generateWithdrawalReceipt(
                          operation: operation,
                          shop: shop,
                          agent: agent,
                          destinataireName: clientName ?? operation.destinataire ?? operation.observation,
                        )
                      : await pdfService.generateReceiptPdf(
                          operation: operation,
                          shop: shop,
                          agent: agent,
                          clientName: clientName,
                        );
                  
                  final pdfBytes = await pdfDoc.save();
                  
                  // Utiliser Printing.layoutPdf pour afficher l'aperçu et permettre l'impression
                  await Printing.layoutPdf(
                    onLayout: (format) async => pdfBytes,
                    name: 'recu_${operation.codeOps ?? operation.id ?? "operation"}.pdf',
                    format: const PdfPageFormat(
                      58 * PdfPageFormat.mm, // Largeur 58mm pour imprimante thermique Q2I
                      double.infinity,
                      marginAll: 2 * PdfPageFormat.mm,
                    ),
                  );
                  
                  debugPrint('✅ [AutoPrintHelper] Impression lancée avec succès');
                  
                  if (context.mounted) {
                    _showSnackBar(
                      context,
                      '✅ Reçu prêt à imprimer',
                      backgroundColor: Colors.green,
                    );
                  }
                } catch (e) {
                  debugPrint('❌ [AutoPrintHelper] Erreur lors de l\'impression: $e');
                  if (context.mounted) {
                    _showSnackBar(
                      context,
                      '❌ Erreur impression: $e',
                      backgroundColor: Colors.red,
                    );
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    // Si l'utilisateur annule
    if (shouldPrint != true) {
      debugPrint('ℹ️ [AutoPrintHelper] Utilisateur a ignoré l\'impression');
      _showSnackBar(
        context,
        'ℹ️ Impression ignorée',
        backgroundColor: Colors.blue,
      );
      return false;
    }

    debugPrint('✅ [AutoPrintHelper] Utilisateur a confirmé l\'impression');
    
    if (!context.mounted) {
      debugPrint('⚠️ [AutoPrintHelper] Contexte non monté après dialog');
      return false;
    }

    // Utiliser le sélecteur d'imprimante PDF
    return await _printWithPdfSelector(
      context: context,
      operation: operation,
      shop: shop,
      agent: agent,
      clientName: clientName,
      showSuccessMessage: true,
      isWithdrawalReceipt: isWithdrawalReceipt,
    );
    } catch (e, stackTrace) {
      debugPrint('❌ [AutoPrintHelper] ERREUR CRITIQUE: $e');
      debugPrint('📍 [AutoPrintHelper] Stack trace: $stackTrace');
      
      if (context.mounted) {
        _showSnackBar(
          context,
          '❌ Erreur impression: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
      
      return false;
    }
  }

  /// Imprime en mode silencieux (sans message)
  static Future<bool> silentPrint({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    try {
      final isAvailable = await _printerService.checkPrinterAvailability();
      if (!isAvailable) return false;

      await _printerService.printReceipt(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );

      return true;
    } catch (e) {
      debugPrint('❌ Erreur impression silencieuse: $e');
      return false;
    }
  }

  /// Afficher un SnackBar
  static void _showSnackBar(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.green,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
