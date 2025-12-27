import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service de test pour diagnostiquer les problèmes d'upload du personnel
class PersonnelUploadTest {
  
  /// Test complet de l'upload personnel
  static Future<PersonnelUploadTestResult> runFullUploadTest({
    required String userId,
    required String userRole,
    int? shopId,
  }) async {
    debugPrint('👥📤 === TEST UPLOAD PERSONNEL COMPLET ===');
    
    final result = PersonnelUploadTestResult();
    
    try {
      // Test 1: Connectivité de base
      result.connectivityTest = await _testConnectivity();
      debugPrint('👥📤 Test connectivité: ${result.connectivityTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 2: API upload accessible
      result.uploadApiTest = await _testUploadApiAccess();
      debugPrint('👥📤 Test API upload: ${result.uploadApiTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 3: Upload avec données de test
      result.testDataUploadTest = await _testUploadWithTestData(userId, userRole, shopId);
      debugPrint('👥📤 Test upload données: ${result.testDataUploadTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 4: Validation structure de réponse
      result.responseValidationTest = await _testUploadResponseStructure(userId, userRole, shopId);
      debugPrint('👥📤 Test validation réponse: ${result.responseValidationTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      // Test 5: Test upload multiple tables
      result.multiTableUploadTest = await _testMultiTableUpload(userId, userRole, shopId);
      debugPrint('👥📤 Test upload multi-tables: ${result.multiTableUploadTest ? "✅ OK" : "❌ ÉCHEC"}');
      
      result.overallSuccess = result.connectivityTest && 
                             result.uploadApiTest && 
                             result.testDataUploadTest && 
                             result.responseValidationTest &&
                             result.multiTableUploadTest;
      
      debugPrint('👥📤 === RÉSULTAT GLOBAL: ${result.overallSuccess ? "✅ SUCCÈS" : "❌ ÉCHEC"} ===');
      
      return result;
      
    } catch (e) {
      debugPrint('👥📤 ❌ Erreur test upload personnel: $e');
      result.error = e.toString();
      return result;
    }
  }
  
  /// Test de connectivité de base
  static Future<bool> _testConnectivity() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/ping.php';
      
      debugPrint('👥📤 Test connectivité: $url');
      
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
      debugPrint('👥📤 ❌ Erreur connectivité: $e');
      return false;
    }
  }
  
  /// Test d'accès à l'API upload
  static Future<bool> _testUploadApiAccess() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/sync/personnel/upload.php';
      
      debugPrint('👥📤 Test API upload: $url');
      
      // Test avec une requête GET (devrait retourner 405 Method Not Allowed)
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('👥📤 Status code: ${response.statusCode}');
      
      // 405 = Method Not Allowed est attendu pour GET sur une API POST
      if (response.statusCode == 405) {
        final data = json.decode(response.body);
        return data['message']?.toString().contains('non autorisée') == true;
      }
      
      return false;
    } catch (e) {
      debugPrint('👥📤 ❌ Erreur API upload: $e');
      return false;
    }
  }
  
  /// Test upload avec données de test
  static Future<bool> _testUploadWithTestData(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/sync/personnel/upload.php';
      
      debugPrint('👥📤 Test upload données: $url');
      
      // Créer des données de test pour personnel
      final testData = {
        'entities': [
          {
            '_table': 'personnel',
            'matricule': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
            'nom': 'Test',
            'prenom': 'Upload',
            'telephone': '+243999999999',
            'poste': 'Test Upload',
            'salaire_base': 500.0,
            'devise_salaire': 'USD',
            'statut': 'Actif',
            'last_modified_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          }
        ],
        'user_id': userId,
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(testData),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('👥📤 Upload status: ${response.statusCode}');
      debugPrint('👥📤 Upload response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true && (data['uploaded_count'] > 0 || data['updated_count'] > 0);
      }
      
      return false;
    } catch (e) {
      debugPrint('👥📤 ❌ Erreur upload test: $e');
      return false;
    }
  }
  
  /// Test validation de la structure de réponse
  static Future<bool> _testUploadResponseStructure(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/sync/personnel/upload.php';
      
      debugPrint('👥📤 Test structure réponse upload: $url');
      
      // Données de test minimales
      final testData = {
        'entities': [
          {
            '_table': 'personnel',
            'matricule': 'STRUCT_TEST_${DateTime.now().millisecondsSinceEpoch}',
            'nom': 'Structure',
            'prenom': 'Test',
            'telephone': '+243888888888',
            'poste': 'Test Structure',
            'last_modified_at': DateTime.now().toIso8601String(),
          }
        ],
        'user_id': userId,
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(testData),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Vérifier les champs obligatoires de la réponse
        final requiredFields = ['success', 'uploaded_count', 'updated_count'];
        for (final field in requiredFields) {
          if (!data.containsKey(field)) {
            debugPrint('👥📤 ❌ Champ manquant: $field');
            return false;
          }
        }
        
        // Vérifier les types
        if (data['success'] is! bool) {
          debugPrint('👥📤 ❌ success devrait être un boolean');
          return false;
        }
        
        if (data['uploaded_count'] is! int) {
          debugPrint('👥📤 ❌ uploaded_count devrait être un int');
          return false;
        }
        
        if (data['updated_count'] is! int) {
          debugPrint('👥📤 ❌ updated_count devrait être un int');
          return false;
        }
        
        debugPrint('👥📤 ✅ Structure réponse correcte');
        return true;
      }
      
      debugPrint('👥📤 ❌ Status code: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('👥📤 ❌ Erreur test structure: $e');
      return false;
    }
  }
  
  /// Test upload de plusieurs tables
  static Future<bool> _testMultiTableUpload(String userId, String userRole, int? shopId) async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/sync/personnel/upload.php';
      
      debugPrint('👥📤 Test upload multi-tables: $url');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Données de test pour plusieurs tables
      final testData = {
        'entities': [
          {
            '_table': 'personnel',
            'matricule': 'MULTI_${timestamp}',
            'nom': 'Multi',
            'prenom': 'Test',
            'telephone': '+243777777777',
            'poste': 'Test Multi',
            'last_modified_at': DateTime.now().toIso8601String(),
          },
          {
            '_table': 'avances_personnel',
            'id': timestamp,
            'personnel_id': 1, // ID fictif
            'montant_avance': 100.0,
            'montant_restant': 100.0,
            'date_avance': DateTime.now().toIso8601String().split('T')[0],
            'statut': 'En_Cours',
            'last_modified_at': DateTime.now().toIso8601String(),
          }
        ],
        'user_id': userId,
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(testData),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('👥📤 Multi-table status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('👥📤 Multi-table response: ${data.toString()}');
        
        // Vérifier que l'upload a traité plusieurs entités
        final totalProcessed = (data['uploaded_count'] ?? 0) + (data['updated_count'] ?? 0);
        return data['success'] == true && totalProcessed > 0;
      }
      
      return false;
    } catch (e) {
      debugPrint('👥📤 ❌ Erreur upload multi-tables: $e');
      return false;
    }
  }
  
  /// Diagnostic rapide upload
  static Future<String> quickUploadDiagnosis({
    required String userId,
    required String userRole,
    int? shopId,
  }) async {
    debugPrint('👥📤 === DIAGNOSTIC RAPIDE UPLOAD PERSONNEL ===');
    
    try {
      final result = await runFullUploadTest(
        userId: userId,
        userRole: userRole,
        shopId: shopId,
      );
      
      if (result.overallSuccess) {
        return '✅ Tous les tests d\'upload passent - L\'upload du personnel fonctionne correctement';
      }
      
      final issues = <String>[];
      
      if (!result.connectivityTest) {
        issues.add('❌ Problème de connectivité serveur');
      }
      
      if (!result.uploadApiTest) {
        issues.add('❌ API upload personnel inaccessible');
      }
      
      if (!result.testDataUploadTest) {
        issues.add('❌ Échec upload données de test');
      }
      
      if (!result.responseValidationTest) {
        issues.add('❌ Structure de réponse incorrecte');
      }
      
      if (!result.multiTableUploadTest) {
        issues.add('❌ Problème upload multi-tables');
      }
      
      return issues.join('\n');
      
    } catch (e) {
      return '❌ Erreur diagnostic upload: $e';
    }
  }
}

/// Résultat des tests upload personnel
class PersonnelUploadTestResult {
  bool connectivityTest = false;
  bool uploadApiTest = false;
  bool testDataUploadTest = false;
  bool responseValidationTest = false;
  bool multiTableUploadTest = false;
  bool overallSuccess = false;
  String? error;
  
  @override
  String toString() {
    return '''
👥📤 RÉSULTATS TEST UPLOAD PERSONNEL:
- Connectivité: ${connectivityTest ? "✅" : "❌"}
- API Upload: ${uploadApiTest ? "✅" : "❌"}
- Upload données test: ${testDataUploadTest ? "✅" : "❌"}
- Validation réponse: ${responseValidationTest ? "✅" : "❌"}
- Upload multi-tables: ${multiTableUploadTest ? "✅" : "❌"}
- GLOBAL: ${overallSuccess ? "✅ SUCCÈS" : "❌ ÉCHEC"}
${error != null ? "Erreur: $error" : ""}
    ''';
  }
}
