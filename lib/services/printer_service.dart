import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import 'native_printer_service.dart';
import 'document_header_service.dart';
import 'pdf_service.dart';

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
      try {
        _hasNativePrinter = await _nativePrinter.checkAvailability().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⏱️ Timeout vérification imprimante locale');
            return false;
          },
        );
        
        if (_hasNativePrinter) {
          debugPrint('✅ Imprimante locale Q2i détectée');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Erreur vérification imprimante locale: $e');
        _hasNativePrinter = false;
      }
      
      // ⚠️ DÉSACTIVATION TEMPORAIRE DU BLUETOOTH POUR Q2I
      // Le scan Bluetooth cause des crashes sur Q2I
      // Retourner false si l'imprimante native n'est pas disponible
      debugPrint('ℹ️ Bluetooth désactivé pour Q2I - imprimante native requise');
      return false;
      
      /* BLUETOOTH CODE DÉSACTIVÉ TEMPORAIREMENT
      // 2. FALLBACK: Vérifier si déjà connecté en Bluetooth
      if (_isConnected && _connectedDevice != null) {
        debugPrint('✅ Déjà connecté en Bluetooth: ${_connectedDevice!.name}');
        return true;
      }

      // 3. Scanner les imprimantes Bluetooth externes avec timeout
      debugPrint('🔍 Scan Bluetooth pour imprimante externe (3 secondes)...');
      
      try {
        final List<BluetoothDevice> devices = [];
        
        // Démarrer le scan
        _bluetoothPrint.startScan(timeout: const Duration(seconds: 3));
        
        // Écouter les résultats avec timeout
        await _bluetoothPrint.scanResults.first.timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            debugPrint('⏱️ Timeout scan Bluetooth');
            return <BluetoothDevice>[];
          },
        ).then((results) {
          devices.addAll(results);
        });
        
        // Arrêter le scan
        _bluetoothPrint.stopScan();
        
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
        debugPrint('⚠️ Erreur scan Bluetooth: $e');
        _bluetoothPrint.stopScan();
        return false;
      }
      */
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur vérification imprimante: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Connexion à un appareil Bluetooth
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('🔗 Connexion à: ${device.name ?? "Appareil inconnu"}...');
      
      // Ajouter un timeout de 5 secondes pour éviter les blocages
      await _bluetoothPrint.connect(device).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏱️ Timeout connexion à ${device.name ?? "Appareil"} (5s)');
          throw Exception('Connexion timeout');
        },
      );
      
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


  /// Impression du reçu d'opération (PDF avec sélecteur d'imprimante)
  /// Utilise Printing.layoutPdf() pour ouvrir le sélecteur d'imprimante système
  Future<bool> printReceipt({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    try {
      debugPrint('🖨️ [PrinterService] Début printReceipt pour opération #${operation.id}');
      
      // Sur Web, suggérer le PDF au lieu de lancer une exception
      if (kIsWeb) {
        debugPrint('⚠️ [PrinterService] Impression non disponible sur Web - Utilisez le PDF à la place');
        throw Exception('Impression non disponible sur navigateur Web. Veuillez utiliser l\'option de téléchargement PDF.');
      }
      
      // Générer le PDF du reçu avec le service PDF amélioré
      debugPrint('📄 [PrinterService] Génération PDF du reçu...');
      final pdfService = PdfService();
      final doc = await pdfService.generateReceiptPdf(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );
      
      // Ouvrir le sélecteur d'imprimante avec le PDF (format 58mm pour Q2I)
      debugPrint('🖨️ [PrinterService] Ouverture du sélecteur d\'imprimante...');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        format: PdfPageFormat(
          58 * PdfPageFormat.mm, // Largeur 58mm pour imprimante thermique Q2I
          double.infinity, // Hauteur auto
          marginAll: 2 * PdfPageFormat.mm,
        ),
        name: 'recu_${operation.codeOps ?? operation.id ?? "operation"}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
      debugPrint('✅ [PrinterService] Sélecteur d\'imprimante ouvert avec succès');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [PrinterService] ERREUR impression reçu: $e');
      debugPrint('📍 [PrinterService] Stack trace: $stackTrace');
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
      debugPrint('🔍 [PrinterService] Vérification disponibilité imprimante Bluetooth...');
      
      // Vérifier la disponibilité de l'imprimante Bluetooth
      if (!await checkPrinterAvailability()) {
        debugPrint('❌ [PrinterService] Aucune imprimante Bluetooth disponible');
        throw Exception('Aucune imprimante Bluetooth disponible');
      }

      debugPrint('📄 [PrinterService] Génération contenu du reçu...');
      
      // Générer le contenu du reçu
      final List<LineText> lines = await _generateReceiptLines(
        operation: operation,
        shop: shop,
        agent: agent,
        clientName: clientName,
      );
      
      if (lines.isEmpty) {
        debugPrint('⚠️ [PrinterService] Aucune ligne générée pour l\'impression');
        throw Exception('Contenu du reçu vide');
      }
      
      debugPrint('📤 [PrinterService] Envoi de ${lines.length} lignes à l\'imprimante Bluetooth...');

      // Vérifier la connexion avant l'impression
      final isConnected = await _bluetoothPrint.isConnected;
      if (isConnected != true) {
        debugPrint('❌ [PrinterService] Perte de connexion Bluetooth avant impression');
        throw Exception('Connexion Bluetooth perdue');
      }

      // Envoyer à l'imprimante via printReceipt avec timeout
      final Map<String, dynamic> config = {};
      await _bluetoothPrint.printReceipt(config, lines).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏱️ [PrinterService] Timeout impression Bluetooth (15s)');
          throw Exception('Timeout impression');
        },
      );
      
      debugPrint('✅ [PrinterService] Reçu imprimé via Bluetooth');
      return true;
    } on AssertionError catch (e, stackTrace) {
      debugPrint('❌ [PrinterService] AssertionError Bluetooth (plugin): $e');
      debugPrint('📍 [PrinterService] Stack trace: $stackTrace');
      // Déconnecter et réinitialiser l'état
      try {
        await disconnect();
      } catch (_) {}
      throw Exception('Erreur plugin Bluetooth: Vérifiez que l\'imprimante est allumée et accessible');
    } catch (e, stackTrace) {
      debugPrint('❌ [PrinterService] ERREUR impression Bluetooth: $e');
      debugPrint('📍 [PrinterService] Stack trace: $stackTrace');
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
    
    // Charger l'en-tête personnalisé depuis DocumentHeaderService (synchronisé avec MySQL)
    final headerService = DocumentHeaderService();
    await headerService.initialize();
    final headerModel = headerService.getHeaderOrDefault();
    
    // Utiliser les données de l'en-tête
    final companyName = headerModel.companyName;
    final companyAddress = headerModel.address ?? '';
    final companyPhone = headerModel.phone ?? '';
    final footerMessage = headerModel.companySlogan ?? 'Merci pour votre confiance';
    
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
                companyName,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              
              if (companyAddress.isNotEmpty)
                pw.Text(companyAddress, style: pw.TextStyle(fontSize: 8)),
              if (companyPhone.isNotEmpty)
                pw.Text(companyPhone, style: pw.TextStyle(fontSize: 8)),
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
                    pw.Text('Code: ${operation.codeOps ?? operation.id ?? "N/A"}', style: pw.TextStyle(fontSize: 7)),
                    // Add reference if available
                    if (operation.reference != null && operation.reference!.isNotEmpty)
                      pw.Text('Réf: ${operation.reference}', style: pw.TextStyle(fontSize: 7)),
                    // Afficher le nom de l'agent s'il existe
                    if (agent.nom != null && agent.nom!.isNotEmpty)
                      pw.Text('Agent: ${agent.nom}', style: pw.TextStyle(fontSize: 7))
                    else if (agent.username.isNotEmpty)
                      pw.Text('Agent: ${agent.username}', style: pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('-' * 32, style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              
              // Informations spécifiques selon le type d'opération
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Pour Dépôt/Retrait: Nom titulaire + N° compte
                    if (isDepotOrRetrait && clientName != null && clientName.isNotEmpty) ...[
                      pw.Text(
                        'TITULAIRE:',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        clientName,
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      if (operation.clientId != null)
                        pw.Text(
                          'N° Compte: ${operation.clientId.toString().padLeft(6, '0')}',
                          style: pw.TextStyle(fontSize: 7),
                        ),
                    ],
                    // Pour Transfert: Expéditeur et Destinataire
                    if (!isDepotOrRetrait) ...[
                      if (operation.shopSourceDesignation != null)
                        pw.Text('De: ${operation.shopSourceDesignation}', style: pw.TextStyle(fontSize: 7)),
                      if (operation.shopDestinationDesignation != null)
                        pw.Text('À: ${operation.shopDestinationDesignation}', style: pw.TextStyle(fontSize: 7)),
                      if (operation.destinataire != null) ...[
                        pw.Text(
                          'Destinataire:',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(operation.destinataire!, style: pw.TextStyle(fontSize: 8)),
                      ],
                      if (operation.telephoneDestinataire != null)
                        pw.Text('Tél: ${operation.telephoneDestinataire}', style: pw.TextStyle(fontSize: 7)),
                    ],
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
                        'Frais : ${operation.commission.toStringAsFixed(2)} ${operation.devise}',
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
                footerMessage,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(companyName, style: pw.TextStyle(fontSize: 6)),
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
  Future<List<LineText>> _generateReceiptLines({
    required OperationModel operation,
    required ShopModel shop,
    required AgentModel agent,
    String? clientName,
  }) async {
    final List<LineText> lines = [];
    
    // Charger l'en-tête personnalisé depuis DocumentHeaderService (synchronisé avec MySQL)
    final headerService = DocumentHeaderService();
    await headerService.initialize();
    final headerModel = headerService.getHeaderOrDefault();
    
    // Utiliser les données de l'en-tête
    final companyName = headerModel.companyName;
    final companyAddress = headerModel.address ?? '';
    final companyPhone = headerModel.phone ?? '';
    final footerMessage = headerModel.companySlogan ?? 'Merci pour votre confiance';
    
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
      content: companyName,
      weight: 1,
      height: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    if (companyAddress.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: companyAddress,
        weight: 0,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }
    
    if (companyPhone.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: companyPhone,
        weight: 0,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }
    
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

    // Type d'opération - Titre du bordereau
    if (isDepotOrRetrait) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: operation.type == OperationType.depot ? 'BORDEREAU DE VERSEMENT' : 'BORDEREAU DE RETRAIT',
        weight: 1,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '--------------------------------',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      // Code (seulement le code en gras, sans label)
      if (operation.codeOps != null && operation.codeOps!.isNotEmpty) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: operation.codeOps!,
          weight: 1,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
        ));
      }
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
      
      // Shop Source (agence)
      if (operation.shopSourceDesignation != null && operation.shopSourceDesignation!.isNotEmpty) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: operation.shopSourceDesignation!,
          weight: 1,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
        ));
      }
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
      
      // PARTENAIRES: Nom du client
      if (clientName != null && clientName.isNotEmpty) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'PARTENAIRES: $clientName',
          linefeed: 1,
        ));
      }
      
      // No Compte: Numéro du compte
      if (operation.clientId != null) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'No Compte: ${operation.clientId.toString().padLeft(6, '0')}',
          linefeed: 1,
        ));
      }
      
      // Montant
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'MONTANT: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        weight: 1,
        height: 1,
        linefeed: 1,
      ));
    }
    // Pour Transfert: Expéditeur et Destinataire
    else if (!isDepotOrRetrait) {
      
      // Shop Source - Shop Destination (avec tiret, taille réduite)
      if (operation.shopSourceDesignation != null && operation.shopDestinationDesignation != null) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: '${operation.shopSourceDesignation} - ${operation.shopDestinationDesignation}',
          weight: 0,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
        ));
      }
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '--------------------------------',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      
      // Code (seulement le code en gras, sans label)
      if (operation.codeOps != null) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: operation.codeOps!,
          weight: 1,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
        ));
      }
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
      
      // Expéditeur
      if (clientName != null && clientName.isNotEmpty) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'DEST.: $clientName',
          linefeed: 1,
        ));
      }
      
      // DEST: affiche l'observation (nom du destinataire)
      if (operation.observation != null && operation.observation!.isNotEmpty) {
        lines.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'EXP. : ${operation.observation}',
          linefeed: 1,
        ));
      }
      
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '',
        linefeed: 1,
      ));
      
      // Détails financiers pour transfert
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Montant Brut: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
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
      
      // Montant Net (ce que le destinataire reçoit)
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'NET: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        weight: 1,
        height: 1,
        linefeed: 1,
      ));
      
      // Ligne de séparation supprimée
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

    // Détails financiers (uniquement pour les transferts, pas pour dépôt/retrait)
    if (!isDepotOrRetrait) {
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
    }

    // Mode de paiement uniquement (pas de statut)
    final String modePaiement = _getModePaiement(operation.modePaiement);
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Mode: $modePaiement',
      weight: 0,
      linefeed: 1,
    ));

    // Billetage information for withdrawal and transfer receipts
    final shouldShowBilletage = (operation.type == OperationType.retrait || 
                                 operation.type == OperationType.transfertNational ||
                                 operation.type == OperationType.transfertInternationalEntrant ||
                                 operation.type == OperationType.transfertInternationalSortant) &&
                                operation.billetage != null && 
                                operation.billetage!.isNotEmpty;
    
    if (shouldShowBilletage) {
      try {
        final Map<String, dynamic> billetageData = jsonDecode(operation.billetage!);
        final Map<String, dynamic> denominations = billetageData['denominations'];
        
        if (denominations.isNotEmpty) {
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '--------------------------------',
            linefeed: 1,
          ));
          
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: 'BILLETAGE:',
            weight: 1,
            linefeed: 1,
          ));
          
          // Sort denominations in descending order
          final sortedKeys = denominations.keys.toList()
            ..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
          
          for (var key in sortedKeys) {
            final denom = double.parse(key);
            final quantity = denominations[key] as int;
            if (quantity > 0) {
              lines.add(LineText(
                type: LineText.TYPE_TEXT,
                content: '${denom.toStringAsFixed(denom < 1 ? 2 : 0)} x $quantity = ${(denom * quantity).toStringAsFixed(2)} \$',
                linefeed: 1,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing billetage for thermal receipt: $e');
      }
    }

    // Message de remerciement
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: footerMessage,
      weight: 0,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: companyName,
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

    // Type d'opération - Titre du bordereau
    final isDepotOrRetrait = operation.type == OperationType.depot || operation.type == OperationType.retrait;
    if (isDepotOrRetrait) {
      bytes += generator.text(
        operation.type == OperationType.depot ? 'BORDEREAU DE VERSEMENT' : 'BORDEREAU DE RETRAIT',
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

      // Code (seulement le code en gras, sans label)
      if (operation.codeOps != null && operation.codeOps!.isNotEmpty) {
        bytes += generator.text(
          operation.codeOps!,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      
      bytes += generator.emptyLines(1);
      
      // Shop Source (agence)
      if (operation.shopSourceDesignation != null && operation.shopSourceDesignation!.isNotEmpty) {
        bytes += generator.text(
          operation.shopSourceDesignation!,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      
      bytes += generator.emptyLines(1);
      
      // PARTENAIRES: Nom du client
      if (clientName != null && clientName.isNotEmpty) {
        bytes += generator.text('PARTENAIRES: $clientName', styles: const PosStyles());
      }
      
      // No Compte: Numéro du compte
      if (operation.clientId != null) {
        bytes += generator.text(
          'No Compte: ${operation.clientId.toString().padLeft(6, '0')}',
          styles: const PosStyles(),
        );
      }
      
      // Montant
      bytes += generator.text(
        'MONTANT: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        styles: const PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
    }
    // Pour Transfert: Expéditeur et Destinataire
    else if (!isDepotOrRetrait) {
      
      // Shop Source - Shop Destination (avec tiret, centré, taille réduite)
      if (operation.shopSourceDesignation != null && operation.shopDestinationDesignation != null) {
        bytes += generator.text(
          '${operation.shopSourceDesignation} - ${operation.shopDestinationDesignation}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      
      // Code (seulement le code en gras, sans label)
      if (operation.codeOps != null) {
        bytes += generator.text(operation.codeOps!, styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      
      bytes += generator.emptyLines(1);
      
      // Expéditeur
      if (clientName != null && clientName.isNotEmpty) {
        bytes += generator.text('EXP.: $clientName', styles: const PosStyles());
      }
      
      // DEST: affiche l'observation (nom du destinataire)
      if (operation.observation != null && operation.observation!.isNotEmpty) {
        bytes += generator.text('DEST: ${operation.observation}', styles: const PosStyles());
      }
      
      bytes += generator.emptyLines(1);
      
      // Détails financiers pour transfert
      bytes += generator.text(
        'Montant Brut: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
        styles: const PosStyles(),
      );
      
      if (operation.commission > 0) {
        bytes += generator.text(
          'Commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}',
          styles: const PosStyles(),
        );
      }
      
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(),
      );
      
      // Montant Net (ce que le destinataire reçoit)
      bytes += generator.text(
        ': ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        styles: const PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
      
      // Ligne de séparation supprimée
    }

    bytes += generator.emptyLines(1);

    // Détails financiers (uniquement pour les transferts, pas pour dépôt/retrait)
    if (!isDepotOrRetrait) {
      bytes += generator.text(
        'Montant: ${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
        styles: const PosStyles(),
      );
      
      if (operation.commission > 0) {
        bytes += generator.text(
          'Commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}',
          styles: const PosStyles(),
        );
      }
      
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(),
      );
      
      bytes += generator.text(
        'TOTAL: ${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
        styles: const PosStyles(
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
      
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(),
      );
    }
    
    // Mode de paiement uniquement (pas de statut)
    final String modePaiement = _getModePaiement(operation.modePaiement);
    bytes += generator.text('Mode: $modePaiement', styles: const PosStyles());
    
    bytes += generator.emptyLines(1);
    
    // Billetage information for withdrawal and transfer receipts (ESC/POS version)
    final shouldShowBilletage = (operation.type == OperationType.retrait || 
                                 operation.type == OperationType.transfertNational ||
                                 operation.type == OperationType.transfertInternationalEntrant ||
                                 operation.type == OperationType.transfertInternationalSortant) &&
                                operation.billetage != null && 
                                operation.billetage!.isNotEmpty;
    
    if (shouldShowBilletage) {
      try {
        final Map<String, dynamic> billetageData = jsonDecode(operation.billetage!);
        final Map<String, dynamic> denominations = billetageData['denominations'];
        
        if (denominations.isNotEmpty) {
          bytes += generator.text(
            '--------------------------------',
            styles: const PosStyles(align: PosAlign.center),
          );
          
          bytes += generator.text(
            'BILLETAGE:',
            styles: const PosStyles(bold: true),
          );
          
          // Sort denominations in descending order
          final sortedKeys = denominations.keys.toList()
            ..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
          
          for (var key in sortedKeys) {
            final denom = double.parse(key);
            final quantity = denominations[key] as int;
            if (quantity > 0) {
              bytes += generator.text(
                '${denom.toStringAsFixed(denom < 1 ? 2 : 0)} x $quantity = ${(denom * quantity).toStringAsFixed(2)} \$',
                styles: const PosStyles(),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing billetage for ESC/POS receipt: $e');
      }
    }
    
    // Message de remerciement
    bytes += generator.text(
      '================================',
      styles: const PosStyles(align: PosAlign.center, ),
    );
    
    bytes += generator.text(
      'MAHANAIM votre remercie!',
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
    
    // Ajouter des lignes vides pour couper le papier
    bytes += generator.feed(3);
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
        return '📱 MPESA/VODACASH';
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
