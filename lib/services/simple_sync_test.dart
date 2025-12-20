import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SimpleSyncTest {
  static const String testUrl = 'https://mahanaimeservice.investee-group.com/server/api/test_final.php';
  
  static Future<bool> testCORS() async {
    try {
      debugPrint('🧪 Test CORS simple...');
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 Status: ${response.statusCode}');
      debugPrint('📡 Headers: ${response.headers}');
      debugPrint('📡 Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ CORS Test OK: ${data['message']}');
        return true;
      }
      
      debugPrint('❌ Status Code: ${response.statusCode}');
      return false;
      
    } catch (e) {
      debugPrint('❌ Erreur CORS Test: $e');
      return false;
    }
  }
  
  static Future<void> showTestResult() async {
    debugPrint('🚀 DÉMARRAGE TEST CORS SIMPLE');
    final success = await testCORS();
    
    if (success) {
      debugPrint('🎉 CORS FONCTIONNE PARFAITEMENT !');
      debugPrint('✅ Vous pouvez maintenant utiliser la synchronisation');
    } else {
      debugPrint('❌ CORS ne fonctionne toujours pas');
      debugPrint('💡 Vérifiez que Laragon est démarré');
    }
  }
}
