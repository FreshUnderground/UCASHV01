import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service de test pour diagnostiquer les problèmes de synchronisation du personnel
class PersonnelSyncTest {
  
  /// Test complet de la synchronisation personnel
  static Future<PersonnelTestResult> runFullTest({
    required String userId,
    required String userRole,
    int? shopId,
  }) async {
    debugPrint('👥 === TEST PERSONNEL SYNC COMPLET ===');
    
    final result = PersonnelTestResult();
    
    try {
      // Test 1: Connectivité de base
      result.connectivityTest = await _testConnectivity();
      debugPrint('👥 Test connectivité: ${result.connectivityTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 2: API personnel sans paramètres
      result.basicApiTest = await _testBasicApi();
      debugPrint('👥 Test API basique: ${result.basicApiTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 3: API personnel avec paramètres utilisateur
      result.userApiTest = await _testUserApi(userId, userRole, shopId);
      debugPrint('👥 Test API utilisateur: ${result.userApiTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 4: Test avec différents paramètres 'since'
      result.sinceParameterTest = await _testSinceParameter(userId, userRole, shopId);
      debugPrint('👥 Test paramètre since: ${result.sinceParameterTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 5: Vérifier la structure de la réponse
      result.responseStructureTest = await _testResponseStructure(userId, userRole, shopId);
      debugPrint('👥 Test structure réponse: ${result.responseStructureTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      result.overallSuccess = result.connectivityTest && 
                             result.basicApiTest && 
                             result.userApiTest && 
                             result.sinceParameterTest && 
                             result.responseStructureTest;
      
      debugPrint('👥 === RÉSULTAT GLOBAL: ${result.overallSuccess ? "✅ SUCCÈS" : "❌ ÉCHEC"} ===');
      
      return result;
      
    } catch (e) {
      debugPrint('👥 ❌ Erreur test personnel: $e');
      result.error = e.toString();
      return result;
    }
  }
  
  /// Test de connectivité de base
  static Future<bool> _testConnectivity() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/ping.php';
      
      debugPrint('👥 Test connectivité: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      debugPrint('👥 ❌ Erreur connectivité: $e');
      return false;
    }
  }
  
  /// Test API basique sans paramètres
  static Future<bool> _testBasicApi() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/personnel/changes.php';
      
      debugPrint('👥 Test API basique: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('👥 Status code: ${response.statusCode}');
      debugPrint('👥 Response body (100 chars): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
      
      if (response.statusCode == 400) {
        // 400 est attendu car pas de paramètres requis
        final data = json.decode(response.body);
        return data['message']?.toString().contains('requis') == true;
      }
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('👥 ❌ Erreur API basique: $e');
      return false;
    }
  }
  
  /// Test API avec paramètres utilisateur
  static Future<bool> _testUserApi(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      var url = '$baseUrl/personnel/changes.php?user_id=$userId&user_role=$userRole';
      
      if (shopId != null) {
        url += '&shop_id=$shopId';
      }
      
      debugPrint('👥 Test API utilisateur: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('👥 Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('👥 Success: ${data['success']}');
        debugPrint('👥 Count: ${data['count']}');
        debugPrint('👥 Entities length: ${data['entities']?.length ?? 0}');
        
        // Vérifier la structure breakdown
        if (data['breakdown'] != null) {
          final breakdown = data['breakdown'] as Map<String, dynamic>;
          debugPrint('👥 Breakdown - Personnel: ${breakdown['personnel']}, Salaires: ${breakdown['salaires']}');
        }
        
        return data['success'] == true;
      }
      
      debugPrint('👥 ❌ Response body: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('👥 ❌ Erreur API utilisateur: $e');
      return false;
    }
  }
  
  /// Test avec différents paramètres 'since'
  static Future<bool> _testSinceParameter(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      
      // Test 1: Sans 'since'
      var url = '$baseUrl/personnel/changes.php?user_id=$userId&user_role=$userRole';
      if (shopId != null) url += '&shop_id=$shopId';
      
      debugPrint('👥 Test sans since: $url');
      
      var response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        debugPrint('👥 ❌ Échec sans since: ${response.statusCode}');
        return false;
      }
      
      var data = json.decode(response.body);
      final countWithoutSince = data['count'] ?? 0;
      debugPrint('👥 Count sans since: $countWithoutSince');
      
      // Test 2: Avec 'since' récent (1 jour)
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      url += '&since=$yesterday';
      
      debugPrint('👥 Test avec since (1j): $url');
      
      response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        debugPrint('👥 ❌ Échec avec since: ${response.statusCode}');
        return false;
      }
      
      data = json.decode(response.body);
      final countWithSince = data['count'] ?? 0;
      debugPrint('👥 Count avec since: $countWithSince');
      
      // Test 3: Avec 'since' très ancien (30 jours)
      final monthAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      url = url.replaceAll('since=$yesterday', 'since=$monthAgo');
      
      debugPrint('👥 Test avec since (30j): $url');
      
      response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        debugPrint('👥 ❌ Échec avec since ancien: ${response.statusCode}');
        return false;
      }
      
      data = json.decode(response.body);
      final countWithOldSince = data['count'] ?? 0;
      debugPrint('👥 Count avec since ancien: $countWithOldSince');
      
      // Logique: plus le 'since' est ancien, plus on devrait avoir de résultats
      return countWithOldSince >= countWithSince;
      
    } catch (e) {
      debugPrint('👥 ❌ Erreur test since: $e');
      return false;
    }
  }
  
  /// Test de la structure de la réponse
  static Future<bool> _testResponseStructure(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      var url = '$baseUrl/personnel/changes.php?user_id=$userId&user_role=$userRole';
      if (shopId != null) url += '&shop_id=$shopId';
      
      debugPrint('👥 Test structure réponse: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        return false;
      }
      
      final data = json.decode(response.body);
      
      // Vérifier les champs obligatoires
      final requiredFields = ['success', 'entities', 'count', 'timestamp'];
      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          debugPrint('👥 ❌ Champ manquant: $field');
          return false;
        }
      }
      
      // Vérifier la structure breakdown
      if (data.containsKey('breakdown')) {
        final breakdown = data['breakdown'] as Map<String, dynamic>;
        final expectedTables = ['personnel', 'salaires', 'avances', 'credits', 'remboursements', 'retenues', 'fiches_paie'];
        
        for (final table in expectedTables) {
          if (!breakdown.containsKey(table)) {
            debugPrint('👥 ❌ Table manquante dans breakdown: $table');
            return false;
          }
        }
        
        debugPrint('👥 ✅ Breakdown complet trouvé');
      }
      
      // Vérifier la structure des entités si présentes
      final entities = data['entities'] as List?;
      if (entities != null && entities.isNotEmpty) {
        final firstEntity = entities.first as Map<String, dynamic>;
        
        // Vérifier le champ _table
        if (!firstEntity.containsKey('_table')) {
          debugPrint('👥 ❌ Champ _table manquant dans les entités');
          return false;
        }
        
        debugPrint('👥 ✅ Structure entité correcte - Table: ${firstEntity['_table']}');
      }
      
      debugPrint('👥 ✅ Structure réponse correcte');
      return true;
      
    } catch (e) {
      debugPrint('👥 ❌ Erreur test structure: $e');
      return false;
    }
  }
  
  /// Test rapide pour diagnostiquer le problème
  static Future<String> quickDiagnosis({
    required String userId,
    required String userRole,
    int? shopId,
  }) async {
    debugPrint('👥 === DIAGNOSTIC RAPIDE PERSONNEL ===');
    
    try {
      final result = await runFullTest(
        userId: userId,
        userRole: userRole,
        shopId: shopId,
      );
      
      if (result.overallSuccess) {
        return '✅ Tous les tests passent - La synchronisation du personnel devrait fonctionner';
      }
      
      final issues = <String>[];
      
      if (!result.connectivityTest) {
        issues.add('❌ Problème de connectivité serveur');
      }
      
      if (!result.basicApiTest) {
        issues.add('❌ API personnel inaccessible');
      }
      
      if (!result.userApiTest) {
        issues.add('❌ Problème avec les paramètres utilisateur');
      }
      
      if (!result.sinceParameterTest) {
        issues.add('❌ Problème avec le filtrage temporel');
      }
      
      if (!result.responseStructureTest) {
        issues.add('❌ Structure de réponse incorrecte');
      }
      
      return issues.join('\n');
      
    } catch (e) {
      return '❌ Erreur diagnostic: $e';
    }
  }
}

/// Résultat des tests personnel
class PersonnelTestResult {
  bool connectivityTest = false;
  bool basicApiTest = false;
  bool userApiTest = false;
  bool sinceParameterTest = false;
  bool responseStructureTest = false;
  bool overallSuccess = false;
  String? error;
  
  @override
  String toString() {
    return '''
👥 RÉSULTATS TEST PERSONNEL:
- Connectivité: ${connectivityTest ? "✅" : "❌"}
- API basique: ${basicApiTest ? "✅" : "❌"}
- API utilisateur: ${userApiTest ? "✅" : "❌"}
- Paramètre since: ${sinceParameterTest ? "✅" : "❌"}
- Structure réponse: ${responseStructureTest ? "✅" : "❌"}
- GLOBAL: ${overallSuccess ? "✅ SUCCÈS" : "❌ ÉCHEC"}
${error != null ? "Erreur: $error" : ""}
    ''';
  }
}
