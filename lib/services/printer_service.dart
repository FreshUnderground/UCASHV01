import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import 'native_printer_service.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  final NativePrinterService _nativePrinter = NativePrinterService();
  
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;
  bool _hasNativePrinter = false;

  bool get isConnected => _isConnected || _hasNativePrinter;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get hasNativePrinter => _hasNativePrinter;

  /// Vérifie si une imprimante est disponible (native Q2i en priorité, puis Bluetooth)
  Future<bool> checkPrinterAvailability() async {
    try {
      // Sur Web, pas d'imprimante disponible
      if (kIsWeb) {
        debugPrint('⚠️ Impression non disponible sur Web');
        return false;
      }
      
      // 1. PRIORITÉ: Vérifier imprimante locale/native (Q2i)
      debugPrint('📱 Recherche imprimante locale Q2i...');
      _hasNativePrinter = await _nativePrinter.checkAvailability();
      
      if (_hasNativePrinter) {
        debugPrint('✅ Imprimante locale Q2i détectée');
        return true;
      }
      
      // 2. FALLBACK: Vérifier si déjà connecté en Bluetooth
      if (_isConnected && _connectedDevice != null) {
        debugPrint('✅ Déjà connecté en Bluetooth: ${_connectedDevice!.name}');
        return true;
      }

      // 3. Scanner les imprimantes Bluetooth externes
      debugPrint('🔍 Scan Bluetooth pour imprimante externe (4 secondes)...');
      _bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
      
      final List<BluetoothDevice> devices = [];
      await Future.delayed(const Duration(seconds: 4));
      _bluetoothPrint.stopScan();
      
      await for (final results in _bluetoothPrint.scanResults.take(1)) {
        devices.addAll(results);
        break;
      }
      
      if (devices.isEmpty) {
        debugPrint('❌ Aucune imprimante Bluetooth externe trouvée');
        return false;
      }
      
      debugPrint('📱 ${devices.length} appareil(s) Bluetooth trouvé(s)');

      // Se connecter à la première imprimante Bluetooth trouvée
      for (final device in devices) {
        final name = device.name?.toLowerCase() ?? '';
        debugPrint('🔍 Appareil trouvé: ${device.name ?? "Inconnu"} (${device.address})');
        
        if (name.contains('printer') || 
            name.contains('pos') || 
            name.contains('thermal') ||
            name.contains('inner') ||
            name.contains('built') ||
            name.contains('internal')) {
          debugPrint('🎯 Tentative connexion à: ${device.name}');
          await _connectToDevice(device);
          if (_isConnected) {
            return true;
          }
        }
      }

      // Si aucune imprimante trouvée par nom, essayer le premier appareil
      if (!_isConnected && devices.isNotEmpty) {
        debugPrint('⚠️ Aucun nom d\'imprimante détecté, essai du premier appareil...');
        await _connectToDevice(devices.first);
      }
      
      if (_isConnected) {
        debugPrint('✅ Connecté à l\'imprimante Bluetooth');
      } else {
        debugPrint('❌ Échec connexion Bluetooth');
      }

      return _isConnected;
    } catch (e) {
      debugPrint('Erreur vérification imprimante: $e');
      return false;
    }
  }

  /// Connexion à un appareil Bluetooth
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('🔗 Connexion à: ${device.name ?? "Appareil inconnu"}...');
      await _bluetoothPrint.connect(device);
      _connectedDevice = device;
      _isConnected = true;
      debugPrint('✅ Connecté à: ${device.name ?? "Appareil inconnu"}');
    } catch (e) {
      debugPrint('❌ Erreur connexion à ${device.name ?? "Appareil"}: $e');
      _isConnected = false;
    }
  }

  /// Déconnexion de l'imprimante
  Future<void> disconnect() async {
    if (_isConnected) {
      await _bluetoothPrint.disconnect();
      _isConnected = false;
      _connectedDevice = null;
    }
  }

  /// Génère les lignes texte pour l'imprimante native (Q2i)
  List<String> _generateReceiptTextLines({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) {
    final List<String> lines = [];
    final isDepotOrRetrait = operation.type == OperationType.depot || operation.type == OperationType.retrait;
    final String dateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(operation.dateOp);
    final String typeOp = _getOperationType(operation.type);
    final String modePaiement = _getModePaiement(operation.modePaiement);

    // En-tête
    lines.add('================================');
    lines.add('          UCASH');
    lines.add('   SERVICE DE TRANSFERT');
    lines.add('================================');
    lines.add('');
    
    // Shop
    lines.add('  ${shop.designation.toUpperCase()}');
    lines.add('      ${shop.localisation}');
    lines.add('');
    
    // Type opération
    lines.add('    ${typeOp.toUpperCase()}');
    lines.add('--------------------------------');
    lines.add('');
    
    // Détails
    lines.add('Date: $dateTime');
    lines.add('ID: ${operation.id ?? "N/A"}');
    // Afficher le nom de l'agent s'il existe
    if (agent.nom != null && agent.nom!.isNotEmpty) {
      lines.add('Agent: ${agent.nom}');
    } else if (agent.username.isNotEmpty) {
      lines.add('Agent: ${agent.username}');
    }
    
    // Pour Dépôt/Retrait: Nom titulaire + N° compte
    if (isDepotOrRetrait && clientName != null && clientName.isNotEmpty) {
      lines.add('');
      lines.add('Titulaire: $clientName');
      if (operation.clientId != null) {
        lines.add('N° Compte: ${operation.clientId.toString().padLeft(6, '0')}');
      }
      lines.add('');
    }
    // Pour Transfert: Destinataire
    else if (!isDepotOrRetrait && operation.destinataire != null) {
      lines.add('Destinataire: ${operation.destinataire}');
      lines.add('');
    }
    
    lines.add('--------------------------------');
    lines.add('');
    
    // Détails financiers
    lines.add('Montant: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}');
    if (operation.commission > 0) {
      lines.add('Commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}');
    }
    lines.add('--------------------------------');
    lines.add('TOTAL: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}');
    lines.add('');
    lines.add('--------------------------------');
    lines.add('');
    
    // Mode de paiement uniquement (pas de statut)
    lines.add('Mode: $modePaiement');
    lines.add('');
    lines.add('================================');
    lines.add('  Merci pour votre confiance!');
    lines.add('UCASH - Transfert rapide et sûr');
    lines.add('================================');
    lines.add('');
    lines.add('');
    lines.add('');
    
    return lines;
  }

  /// Impression du reçu d'opération (Native Q2i en priorité, puis Bluetooth)
  Future<bool> printReceipt({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    try {
      // Sur Web, pas d'impression disponible
      if (kIsWeb) {
        debugPrint('⚠️ Impression non disponible sur Web');
        throw Exception('Impression non supportée sur navigateur Web');
      }
      
      // 1. PRIORITÉ: Essayer l'imprimante native (Q2i)
      if (_hasNativePrinter) {
        debugPrint('🖨️ Impression via imprimante locale Q2i...');
        final lines = _generateReceiptTextLines(
          operation: operation,
          shop: shop,
          agent: agent,
          clientName: clientName,
        );
        
        final success = await _nativePrinter.printReceipt(lines);
        if (success) {
          debugPrint('✅ Impression locale Q2i réussie');
          return true;
        } else {
          debugPrint('⚠️ Échec impression locale, tentative Bluetooth...');
        }
      }
      
      // 2. FALLBACK: Impression via Bluetooth
      debugPrint('🖨️ Impression via Bluetooth...');
      return await _printViaBluetooth(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );
    } catch (e) {
      debugPrint('Erreur impression reçu: $e');
      rethrow;
    }
  }

  /// Impression via imprimante système (Android POS intégré)
  Future<bool> _printViaSystemPrinter({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    try {
      final doc = await _generateReceiptPDF(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );
      
      // Imprimer directement sur l'imprimante par défaut (54mm)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        format: PdfPageFormat(
          54 * PdfPageFormat.mm, // Largeur 54mm
          double.infinity, // Hauteur auto
          marginAll: 2 * PdfPageFormat.mm,
        ),
      );
      
      debugPrint('✅ Reçu imprimé via imprimante système');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur impression système: $e');
      rethrow;
    }
  }

  /// Impression via Bluetooth
  Future<bool> _printViaBluetooth({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    try {
      // Vérifier la disponibilité de l'imprimante Bluetooth
      if (!await checkPrinterAvailability()) {
        throw Exception('Aucune imprimante Bluetooth disponible');
      }

      // Générer le contenu du reçu
      final List<LineText> lines = _generateReceiptLines(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );

      // Envoyer à l'imprimante via printReceipt
      final Map<String, dynamic> config = {};
      await _bluetoothPrint.printReceipt(config, lines);
      
      debugPrint('✅ Reçu imprimé via Bluetooth');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur impression Bluetooth: $e');
      rethrow;
    }
  }

  /// Génère un PDF de reçu (pour imprimante système)
  Future<pw.Document> _generateReceiptPDF({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    final pdf = pw.Document();
    final dateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(operation.dateOp);
    final typeOp = _getOperationType(operation.type);
    final modePaiement = _getModePaiement(operation.modePaiement);
    final isDepotOrRetrait = operation.type == OperationType.depot || operation.type == OperationType.retrait;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          54 * PdfPageFormat.mm, // Format 54mm pour imprimante thermique
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // En-tête optimisée pour 54mm
              pw.Text('=' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text(
                'UCASH',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('SERVICE DE TRANSFERT', style: pw.TextStyle(fontSize: 8)),
              pw.Text('=' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              
              // Shop
              pw.Text(
                shop.designation.toUpperCase(),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(shop.localisation, style: pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 6),
              
              // Type opération
              pw.Text(
                typeOp,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('-' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              
              // Détails
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date: $dateTime', style: pw.TextStyle(fontSize: 7)),
                    pw.Text('ID: ${operation.id ?? "N/A"}', style: pw.TextStyle(fontSize: 7)),
                    // Afficher le nom de l'agent s'il existe
                    if (agent.nom != null && agent.nom!.isNotEmpty)
                      pw.Text('Agent: ${agent.nom}', style: pw.TextStyle(fontSize: 7))
                    else if (agent.username.isNotEmpty)
                      pw.Text('Agent: ${agent.username}', style: pw.TextStyle(fontSize: 7)),
                    
                    // Pour Dépôt/Retrait: Nom titulaire + N° compte
                    if (isDepotOrRetrait && clientName != null && clientName.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Titulaire: $clientName',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      if (operation.clientId != null)
                        pw.Text(
                          'N° Compte: ${operation.clientId.toString().padLeft(6, '0')}',
                          style: pw.TextStyle(fontSize: 7),
                        ),
                    ]
                    // Pour Transfert: Destinataire
                    else if (!isDepotOrRetrait && operation.destinataire != null)
                      pw.Text('Destinataire: ${operation.destinataire}', style: pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('-' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              
              // Montants
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Montant: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    if (operation.commission > 0)
                      pw.Text(
                        'Commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                  ],
                ),
              ),
              pw.Text('-' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 3),
              pw.Text(
                'TOTAL: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('-' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              
              // Mode de paiement uniquement (pas de statut)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Mode: $modePaiement', style: pw.TextStyle(fontSize: 7)),
              ),
              pw.SizedBox(height: 6),
              
              // Footer optimisé pour 54mm
              pw.Text('=' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.Text(
                'Merci pour votre confiance!',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('UCASH - Transfert rapide et sûr', style: pw.TextStyle(fontSize: 6)),
              pw.Text('=' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Génère les lignes du reçu pour bluetooth_print (format 54mm)
  List<LineText> _generateReceiptLines({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) {
    final List<LineText> lines = [];
    final isDepotOrRetrait = operation.type == OperationType.depot || operation.type == OperationType.retrait;

    // En-tête optimisée pour 54mm
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'UCASH',
      weight: 1,
      height: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'SERVICE DE TRANSFERT',
      weight: 0,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Informations du shop
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: shop.designation.toUpperCase(),
      weight: 0,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: shop.localisation,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Type d'opération
    final String typeOp = _getOperationType(operation.type);
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: typeOp.toUpperCase(),
      weight: 1,
      height: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Date et heure
    final String dateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(operation.dateOp);
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Date: $dateTime',
      weight: 0,
      linefeed: 1,
    ));
    
    // ID Opération
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'ID: ${operation.id ?? "N/A"}',
      linefeed: 1,
    ));
    
    // Agent
    // Afficher le nom de l'agent s'il existe
    if (agent.nom != null && agent.nom!.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Agent: ${agent.nom}',
        linefeed: 1,
      ));
    } else if (agent.username.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Agent: ${agent.username}',
        linefeed: 1,
      ));
    }
    
    // Pour Dépôt/Retrait: Nom titulaire + N° compte
    if (isDepotOrRetrait && clientName != null && clientName.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Titulaire: $clientName',
        weight: 0,
        linefeed: 1,
      ));
      
      if (operation.clientId != null) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'N° Compte: ${operation.clientId.toString().padLeft(6, '0')}',
          linefeed: 1,
        ));
      } else {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '',
          linefeed: 1,
        ));
      }
    }
    // Pour Transfert: Destinataire
    else if (!isDepotOrRetrait && operation.destinataire != null) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Destinataire: ${operation.destinataire}',
        linefeed: 1,
      ));
    } else {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      linefeed: 1,
    ));

    // Détails financiers
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Montant: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
      weight: 0,
      linefeed: 1,
    ));

    if (operation.commission > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}',
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
      weight: 1,
      height: 1,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      linefeed: 1,
    ));

    // Mode de paiement uniquement (pas de statut)
    final String modePaiement = _getModePaiement(operation.modePaiement);
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Mode: $modePaiement',
      weight: 0,
      linefeed: 1,
    ));

    // Message de remerciement
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Merci pour votre confiance!',
      weight: 0,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'UCASH - Transfert rapide et sûr',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 2,
    ));

    return lines;
  }

  /// Génère le contenu du reçu en format ESC/POS (legacy) - Optimisé pour 54mm
  Future<List<int>> _generateReceipt({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile); // Format 58mm (standard for 54mm receipts)
    List<int> bytes = [];

    // En-tête optimisée pour 54mm
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.text(
      'UCASH',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        bold: true,
      ),
    );
    bytes += generator.text(
      'SERVICE DE TRANSFERT',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.emptyLines(1);

    // Informations du shop
    bytes += generator.text(
      shop.designation.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, ),
    );
    bytes += generator.text(
      shop.localisation,
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.emptyLines(1);

    // Type d'opération
    final String typeOp = _getOperationType(operation.type);
    bytes += generator.text(
      typeOp.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
        bold: true,
      ),
    );
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.emptyLines(1);

    // Date et heure
    final String dateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(operation.dateOp);
    bytes += generator.text(
      'Date: $dateTime',
      styles: const PosStyles(),
    );
    
    // ID Opération
    bytes += generator.text('ID: ${operation.id ?? "N/A"}', styles: const PosStyles());
    
    // Agent
    // Afficher le nom de l'agent s'il existe
    if (agent.nom != null && agent.nom!.isNotEmpty) {
      bytes += generator.text('Agent: ${agent.nom}', styles: const PosStyles());
    } else if (agent.username.isNotEmpty) {
      bytes += generator.text('Agent: ${agent.username}', styles: const PosStyles());
    }
    
    // Client si disponible
    if (clientName != null && clientName.isNotEmpty) {
      bytes += generator.text('Client: $clientName', styles: const PosStyles());
    } else if (operation.destinataire != null) {
      bytes += generator.text('Destinataire: ${operation.destinataire}', styles: const PosStyles());
    }

    bytes += generator.emptyLines(1);
    bytes += generator.text('--------------------------------', styles: const PosStyles());
    bytes += generator.emptyLines(1);

    // Détails financiers
    bytes += generator.row([
      PosColumn(
        text: 'Montant:',
        width: 6,
        styles: const PosStyles()
      ),
      PosColumn(
        text: '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right)
      ),
    ]);

    if (operation.commission > 0) {
      bytes += generator.row([
        PosColumn(text: 'Commission:', width: 6, styles: const PosStyles()),
        PosColumn(
          text: '${operation.commission.toStringAsFixed(2)} ${operation.devise}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right)
        ),
      ]);
    }

    bytes += generator.text('--------------------------------', styles: const PosStyles());
    
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL:',
        width: 6,
        styles: const PosStyles(bold: true)
      ),
      PosColumn(
        text: '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true)
      ),
    ]);

    bytes += generator.emptyLines(1);
    bytes += generator.text('--------------------------------', styles: const PosStyles());
    bytes += generator.emptyLines(1);

    // Mode de paiement uniquement (pas de statut)
    String modePaiement = _getModePaiement(operation.modePaiement);
    bytes += generator.text(
      'Mode: $modePaiement',
      styles: const PosStyles(),
    );

    bytes += generator.emptyLines(1);

    // Message de remerciement
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.text(
      'Merci pour votre confiance!',
      styles: const PosStyles(align: PosAlign.center, bold: true, ),
    );
    bytes += generator.text(
      'UCASH - Transfert rapide et sûr',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center, ),
    );

    bytes += generator.emptyLines(1);
    bytes += generator.cut();

    return bytes;
  }

  String _getOperationType(OperationType type) {
    switch (type) {
      case OperationType.depot:
        return '📥 DÉPÔT';
      case OperationType.retrait:
        return '📤 RETRAIT';
      case OperationType.transfertNational:
        return '💸 TRANSFERT NATIONAL';
      case OperationType.transfertInternationalSortant:
        return '🌍 TRANSFERT INT. SORTANT';
      case OperationType.transfertInternationalEntrant:
        return '🌍 TRANSFERT INT. ENTRANT';
      default:
        return 'OPÉRATION';
    }
  }

  String _getModePaiement(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return '💵 Cash';
      case ModePaiement.airtelMoney:
        return '📱 Airtel Money';
      case ModePaiement.mPesa:
        return '📱 M-Pesa';
      case ModePaiement.orangeMoney:
        return '📱 Orange Money';
    }
  }

  String _getStatut(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return '⏳ En attente';
      case OperationStatus.validee:
        return '✅ Validée';
      case OperationStatus.terminee:
        return '✅ Terminée';
      case OperationStatus.annulee:
        return '❌ Annulée';
    }
  }

  /// Scanner les imprimantes disponibles
  Future<List<BluetoothDevice>> scanPrinters() async {
    try {
      _bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
      
      final List<BluetoothDevice> devices = [];
      await Future.delayed(const Duration(seconds: 4));
      _bluetoothPrint.stopScan();
      
      await for (final results in _bluetoothPrint.scanResults.take(1)) {
        devices.addAll(results);
        break;
      }
      
      return devices;
    } catch (e) {
      debugPrint('Erreur scan: $e');
      return [];
    }
  }

  /// Impression de test (Bluetooth pour imprimante intégrée)
  Future<bool> printTest() async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Test impression non disponible sur Web');
        return false;
      }
      
      // Pour imprimante POS intégrée, utiliser Bluetooth
      debugPrint('🖨️ Test via Bluetooth (POS intégrée)');
      return await _printTestBluetooth();
    } catch (e) {
      debugPrint('Erreur test impression: $e');
      return false;
    }
  }

  /// Test impression système
  Future<bool> _printTestSystem() async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Test impression non disponible sur Web');
        return false;
      }
      
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            54 * PdfPageFormat.mm,
            100 * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'TEST IMPRESSION',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text('UCASH - Android POS', style: pw.TextStyle(fontSize: 10)),
                pw.Text('Imprimante thermique 54mm', style: pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 8),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        format: PdfPageFormat(
          54 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
      );
      
      return true;
    } catch (e) {
      debugPrint('Erreur test système: $e');
      return false;
    }
  }

  /// Test impression Bluetooth
  Future<bool> _printTestBluetooth() async {
    try {
      if (!await checkPrinterAvailability()) {
        throw Exception('Aucune imprimante Bluetooth disponible');
      }

      final List<LineText> lines = [];
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'TEST IMPRESSION',
        weight: 2,
        height: 2,
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
      ));
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'UCASH - Android POS',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Imprimante thermique 54mm',
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
      ));
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        align: LineText.ALIGN_CENTER,
        linefeed: 3,
      ));

      final Map<String, dynamic> config = {};
      await _bluetoothPrint.printReceipt(config, lines);
      return true;
    } catch (e) {
      debugPrint('Erreur test Bluetooth: $e');
      return false;
    }
  }
}
