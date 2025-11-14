import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Service pour l'impression via l'API native Android (imprimantes locales/USB)
class NativePrinterService {
  static const MethodChannel _channel = MethodChannel('com.ucash.ucashv01/printer');
  
  bool _isAvailable = false;
  
  /// Vérifie si l'impression native est disponible
  Future<bool> checkAvailability() async {
    if (kIsWeb) {
      debugPrint('⚠️ Impression native non disponible sur Web');
      return false;
    }
    
    try {
      final bool? available = await _channel.invokeMethod('checkPrinter');
      _isAvailable = available ?? false;
      
      if (_isAvailable) {
        debugPrint('✅ Imprimante locale détectée (Q2i)');
      } else {
        debugPrint('❌ Aucune imprimante locale trouvée');
      }
      
      return _isAvailable;
    } catch (e) {
      debugPrint('❌ Erreur vérification imprimante native: $e');
      _isAvailable = false;
      return false;
    }
  }
  
  /// Imprime un reçu via l'imprimante locale
  Future<bool> printReceipt(List<String> lines) async {
    if (kIsWeb) {
      throw Exception('Impression native non supportée sur Web');
    }
    
    if (!_isAvailable) {
      debugPrint('⚠️ Imprimante locale non disponible');
      return false;
    }
    
    try {
      debugPrint('🖨️ Envoi de ${lines.length} lignes à l\'imprimante locale...');
      
      final bool? success = await _channel.invokeMethod('printReceipt', {
        'lines': lines,
      });
      
      if (success == true) {
        debugPrint('✅ Impression locale réussie');
        return true;
      } else {
        debugPrint('❌ Échec impression locale');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur impression native: $e');
      return false;
    }
  }
  
  /// Test d'impression (imprime une page de test)
  Future<bool> printTest() async {
    if (kIsWeb) {
      throw Exception('Impression native non supportée sur Web');
    }
    
    try {
      debugPrint('🖨️ Test impression locale...');
      
      final List<String> testLines = [
        '================================',
        '          UCASH',
        '     TEST D\'IMPRESSION',
        '================================',
        '',
        'Terminal: Q2i POS',
        'Type: Imprimante locale',
        'Date: ${DateTime.now().toString().substring(0, 19)}',
        '',
        '================================',
        '     TEST REUSSI !',
        '================================',
        '',
        '',
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
