import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

/// Test script pour vérifier la synchronisation automatique des suppressions
/// 
/// Ce script teste:
/// 1. L'endpoint API check_deleted pour les agents
/// 2. L'endpoint API check_deleted pour les shops
/// 3. La détection des agents/shops supprimés
/// 
/// Usage:
/// dart test test_deletion_sync.dart

void main() {
  group('Automatic Deletion Sync Tests', () {
    const String baseUrl = 'http://localhost/UCASHV01/server/api/sync';
    
    test('Test check_deleted agents endpoint', () async {
      final url = Uri.parse('$baseUrl/agents/check_deleted.php');
      
      // Simulate local agent IDs
      final localAgentIds = [1, 2, 3, 999, 1000];
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'agent_ids': localAgentIds,
        }),
      );
      
      print('📥 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');
      
      expect(response.statusCode, 200);
      
      final data = jsonDecode(response.body);
      expect(data['success'], true);
      expect(data['deleted_agents'], isA<List>());
      expect(data['existing_count'], isA<int>());
      expect(data['deleted_count'], isA<int>());
      
      print('✅ Test passed: ${data['message']}');
      print('🗑️ Deleted agents: ${data['deleted_agents']}');
      print('📊 Existing: ${data['existing_count']}, Deleted: ${data['deleted_count']}');
    });
    
    test('Test check_deleted shops endpoint', () async {
      final url = Uri.parse('$baseUrl/shops/check_deleted.php');
      
      // Simulate local shop IDs
      final localShopIds = [1, 2, 3, 999, 1000];
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'shop_ids': localShopIds,
        }),
      );
      
      print('📥 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');
      
      expect(response.statusCode, 200);
      
      final data = jsonDecode(response.body);
      expect(data['success'], true);
      expect(data['deleted_shops'], isA<List>());
      expect(data['existing_count'], isA<int>());
      expect(data['deleted_count'], isA<int>());
      
      print('✅ Test passed: ${data['message']}');
      print('🗑️ Deleted shops: ${data['deleted_shops']}');
      print('📊 Existing: ${data['existing_count']}, Deleted: ${data['deleted_count']}');
    });
    
    test('Test empty agent IDs array', () async {
      final url = Uri.parse('$baseUrl/agents/check_deleted.php');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'agent_ids': [],
        }),
      );
      
      expect(response.statusCode, 200);
      
      final data = jsonDecode(response.body);
      expect(data['success'], true);
      expect(data['deleted_agents'], isEmpty);
      expect(data['message'], 'Aucun agent à vérifier');
      
      print('✅ Empty array test passed');
    });
    
    test('Test invalid request format', () async {
      final url = Uri.parse('$baseUrl/agents/check_deleted.php');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'invalid_key': [1, 2, 3],
        }),
      );
      
      expect(response.statusCode, 500);
      
      final data = jsonDecode(response.body);
      expect(data['success'], false);
      expect(data['error'], isNotNull);
      
      print('✅ Invalid request test passed: ${data['error']}');
    });
    
    test('Test GET request (should fail)', () async {
      final url = Uri.parse('$baseUrl/agents/check_deleted.php');
      
      final response = await http.get(url);
      
      expect(response.statusCode, 405);
      
      final data = jsonDecode(response.body);
      expect(data['success'], false);
      expect(data['error'], contains('Méthode non autorisée'));
      
      print('✅ GET method rejection test passed');
    });
  });
}

/// Manual test function to verify the complete flow
void manualTest() async {
  print('🧪 === TEST MANUEL DE LA SYNCHRONISATION DES SUPPRESSIONS ===\n');
  
  const String baseUrl = 'http://localhost/UCASHV01/server/api/sync';
  
  // Test 1: Check agents
  print('📋 Test 1: Vérification des agents supprimés');
  final agentsUrl = Uri.parse('$baseUrl/agents/check_deleted.php');
  final agentsResponse = await http.post(
    agentsUrl,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'agent_ids': [1, 2, 3, 4, 5, 999, 1000],
    }),
  );
  
  if (agentsResponse.statusCode == 200) {
    final data = jsonDecode(agentsResponse.body);
    print('✅ ${data['message']}');
    print('   Agents existants: ${data['existing_count']}');
    print('   Agents supprimés: ${data['deleted_count']}');
    if (data['deleted_agents'].isNotEmpty) {
      print('   IDs supprimés: ${data['deleted_agents'].join(', ')}');
    }
  } else {
    print('❌ Erreur: ${agentsResponse.statusCode}');
  }
  
  print('');
  
  // Test 2: Check shops
  print('📋 Test 2: Vérification des shops supprimés');
  final shopsUrl = Uri.parse('$baseUrl/shops/check_deleted.php');
  final shopsResponse = await http.post(
    shopsUrl,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'shop_ids': [1, 2, 3, 4, 5, 999, 1000],
    }),
  );
  
  if (shopsResponse.statusCode == 200) {
    final data = jsonDecode(shopsResponse.body);
    print('✅ ${data['message']}');
    print('   Shops existants: ${data['existing_count']}');
    print('   Shops supprimés: ${data['deleted_count']}');
    if (data['deleted_shops'].isNotEmpty) {
      print('   IDs supprimés: ${data['deleted_shops'].join(', ')}');
    }
  } else {
    print('❌ Erreur: ${shopsResponse.statusCode}');
  }
  
  print('\n✅ === TESTS MANUELS TERMINÉS ===');
}

