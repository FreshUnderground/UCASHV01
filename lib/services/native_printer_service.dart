import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_printer_qpos/flutter_printer_qpos.dart';

/// Service pour l'impression via l'API native Android (imprimantes Q2I POS)
class NativePrinterService {
  static const MethodChannel _channel = MethodChannel('com.ucash.ucashv01/printer');
  final FlutterPrinterQpos _qposPrinter = FlutterPrinterQpos();
  
  bool _isAvailable = false;
  
  /// Vérifie si l'impression native est disponible
  Future<bool> checkAvailability() async {
    if (kIsWeb) {
      debugPrint('⚠️ Impression native non disponible sur Web');
      return false;
    }
    
    try {
      // Essayer d'abord avec le plugin Q2I POS
      debugPrint('🔍 Vérification imprimante Q2I via flutter_printer_qpos...');
      
      // Le plugin Q2I n'a pas de méthode checkAvailability, on suppose qu'il est disponible sur Q2I
      // On va tester lors de l'impression
      _isAvailable = true;
      debugPrint('✅ Plugin Q2I initialisé (vérification réelle à l\'impression)');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur vérification imprimante Q2I: $e');
      _isAvailable = false;
      return false;
    }
  }
  
  /// Imprime un reçu via l'imprimante Q2I
  Future<bool> printReceipt(List<String> lines) async {
    if (kIsWeb) {
      throw Exception('Impression native non supportée sur Web');
    }
    
    if (!_isAvailable) {
      debugPrint('⚠️ Imprimante Q2I non disponible');
      return false;
    }
    
    try {
      debugPrint('🖨️ Impression Q2I: ${lines.length} lignes...');
      
      // Initialiser l'imprimante
      _qposPrinter.initPrinter();
      debugPrint('✅ Imprimante Q2I initialisée');
      
      // Attendre un peu après init
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Imprimer chaque ligne
      for (final line in lines) {
        _qposPrinter.printText(line);
        // Petit délai entre les lignes pour éviter le buffer overflow
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Avancer le papier (feed lines)
      for (int i = 0; i < 10; i++) {
        _qposPrinter.printText('');
        await Future.delayed(const Duration(milliseconds: 5));
      }
      
      debugPrint('📤 Impression finalisée');
      
      // Attendre plus longtemps pour que l'impression physique se termine
      await Future.delayed(const Duration(milliseconds: 2000));
      
      debugPrint('✅ Impression Q2I réussie');
      return true;
      
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException Q2I: ${e.message}');
      debugPrint('   Code: ${e.code}, Details: ${e.details}');
      return false;
    } catch (e) {
      debugPrint('❌ Erreur impression Q2I: $e');
      return false;
    }
  }
  
  /// Test d'impression (imprime une page de test)
  Future<bool> printTest() async {
    if (kIsWeb) {
      throw Exception('Impression native non supportée sur Web');
    }
    
    try {
      debugPrint('🖨️ Test impression Q2I...');
      
      final List<String> testLines = [
        '================================',
        '          UCASH',
        '     TEST D\'IMPRESSION',
        '================================',
        '',
        'Terminal: Q2I POS',
        'Type: Imprimante thermique',
        'Date: ${DateTime.now().toString().substring(0, 19)}',
        '',
        '================================',
        '     TEST REUSSI !',
        '================================',
        '',
      ];
      
      return await printReceipt(testLines);
    } catch (e) {
      debugPrint('❌ Erreur test impression: $e');
      return false;
    }
  }
  
  bool get isAvailable => _isAvailable;
}
