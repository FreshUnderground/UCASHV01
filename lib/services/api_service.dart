import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../config/app_config.dart';

class ApiService {
  // Configuration API (utilise AppConfig pour auto-détection)
  static Future<String> get baseUrl async => await AppConfig.getApiBaseUrl();
  static Duration get timeout => AppConfig.httpTimeout;

  // Headers par défaut
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  // Méthode privée pour obtenir les headers avec authentification
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      // TODO: Ajouter le token d'authentification si nécessaire
      // 'Authorization': 'Bearer $token',
    };
  }

  // Authentification
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('Pas de connexion internet');
    } on HttpException {
      throw Exception('Erreur HTTP - Vérifiez l\'URL du serveur');
    } on FormatException {
      throw Exception('Réponse serveur invalide');
    } catch (e) {
      if (e.toString().contains('CORS')) {
        throw Exception('Erreur CORS - Contactez l\'administrateur');
      }
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupérer les agents
  static Future<List<UserModel>> getAgents() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/agents'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des agents');
      }
    } on SocketException {
      throw Exception('Pas de connexion internet');
    } on HttpException {
      throw Exception('Erreur HTTP - Vérifiez l\'URL du serveur');
    } on FormatException {
      throw Exception('Réponse serveur invalide');
    } catch (e) {
      if (e.toString().contains('CORS')) {
        throw Exception('Erreur CORS - Contactez l\'administrateur');
      }
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupérer les comptes
  static Future<List<UserModel>> getComptes() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/comptes'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          final userData = Map<String, dynamic>.from(json);
          userData['role'] = 'COMPTE';
          return UserModel.fromJson(userData);
        }).toList();
      } else {
        throw Exception('Erreur lors de la récupération des comptes');
      }
    } on SocketException {
      throw Exception('Pas de connexion internet');
    } on HttpException {
      throw Exception('Erreur HTTP - Vérifiez l\'URL du serveur');
    } on FormatException {
      throw Exception('Réponse serveur invalide');
    } catch (e) {
      if (e.toString().contains('CORS')) {
        throw Exception('Erreur CORS - Contactez l\'administrateur');
      }
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupérer les shops
  static Future<List<ShopModel>> getShops() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shops.php'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          return data.map((json) => ShopModel.fromJson(json)).toList();
        } else {
          throw Exception('Réponse API invalide: ${responseData['error'] ?? 'Erreur inconnue'}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ========== MÉTHODES DE SYNCHRONISATION ==========

  // Récupérer les données de synchronisation
  static Future<Map<String, dynamic>?> getSyncData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Erreur getSyncData: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur getSyncData: $e');
    }
    return null;
  }

  // Upload d'une entité vers le serveur
  static Future<Map<String, dynamic>?> uploadEntity(String tableName, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/$tableName/upload.php'),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Erreur uploadEntity: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur uploadEntity: $e');
    }
    return null;
  }

  // Récupération des entités modifiées depuis une date
  static Future<List<Map<String, dynamic>>> getModifiedEntities(String tableName, DateTime? since) async {
    try {
      String url = '$baseUrl/sync/$tableName/modified.php';
      if (since != null) {
        url += '?since=${since.toIso8601String()}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Gérer la nouvelle structure de réponse du serveur
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData.containsKey('entities')) {
            final List<dynamic> entities = responseData['entities'] ?? [];
            return entities.cast<Map<String, dynamic>>();
          } else {
            debugPrint('Réponse serveur sans succès: $responseData');
            return [];
          }
        } else if (responseData is List) {
          // Compatibilité avec l'ancien format
          return responseData.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Format de réponse inattendu: $responseData');
          return [];
        }
      } else {
        debugPrint('Erreur getModifiedEntities: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Erreur getModifiedEntities: $e, uri=$baseUrl/sync/$tableName/modified');
    }
    return [];
  }

  // Upload en lot d'entités
  static Future<Map<String, dynamic>?> uploadBatch(String tableName, List<Map<String, dynamic>> entities) async {
    try {
      String url = '$baseUrl/sync/$tableName/batch.php';
      
      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(),
        body: jsonEncode({'entities': entities}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Erreur uploadBatch: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur uploadBatch: $e');
    }
    return null;
  }

  // Vérification de la connectivité serveur
  static Future<bool> checkServerConnectivity() async {
    try {
      // Utiliser l'URL de l'API configurée dans app_config.dart
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      
      // Extraire l'URL de base (protocole + domaine) sans le path
      // Ex: https://mahanaim.investee-group.com/server/api -> https://mahanaim.investee-group.com
      final uri = Uri.parse(apiBaseUrl);
      final baseServerUrl = '${uri.scheme}://${uri.host}';
      
      debugPrint('📡 Test de connectivité: $baseServerUrl');
      
      final response = await http.get(
        Uri.parse(baseServerUrl),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      // Si le serveur répond (même 404), il est accessible
      final isAccessible = response.statusCode >= 200 && response.statusCode < 500;
      debugPrint('📡 Serveur API ${isAccessible ? "✅ ACCESSIBLE" : "❌ INACCESSIBLE"} ($baseServerUrl - ${response.statusCode})');
      return isAccessible;
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('📡 Serveur API non accessible: $errorStr');
      return false; // Retourner false si le serveur n'est pas accessible
    }
  }

  // Récupération des métadonnées de synchronisation
  static Future<Map<String, dynamic>?> getSyncMetadata() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/metadata'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Erreur getSyncMetadata: $e');
    }
    return null;
  }

  // Résolution de conflit
  static Future<Map<String, dynamic>?> resolveConflict(
    String tableName,
    dynamic entityId,
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    String resolution,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/$tableName/$entityId/resolve'),
        headers: _getHeaders(),
        body: jsonEncode({
          'local_data': localData,
          'remote_data': remoteData,
          'resolution': resolution,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Erreur resolveConflict: $e');
    }
    return null;
  }

  // ========== MÉTHODES CRUD CLASSIQUES ==========

  // Créer un compte
  static Future<UserModel> createCompte(Map<String, dynamic> compteData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comptes'),
        headers: defaultHeaders,
        body: jsonEncode(compteData),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        final userData = Map<String, dynamic>.from(jsonDecode(response.body));
        userData['role'] = 'COMPTE';
        return UserModel.fromJson(userData);
      } else {
        throw Exception('Erreur lors de la création du compte');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Mettre à jour un utilisateur
  static Future<bool> updateUser(int userId, Map<String, dynamic> userData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: defaultHeaders,
        body: jsonEncode(userData),
      ).timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Supprimer un utilisateur
  static Future<bool> deleteUser(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: defaultHeaders,
      ).timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========== MÉTHODES POUR AUTRES ENTITÉS ==========

  // Récupérer les clients
  static Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/clients/modified'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getClients: $e');
      return [];
    }
  }

  // Récupérer les opérations
  static Future<List<Map<String, dynamic>>> getOperations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/operations/modified'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getOperations: $e');
      return [];
    }
  }

  // Récupérer les taux de change
  static Future<List<Map<String, dynamic>>> getTaux() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/taux_change/modified'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTaux: $e');
      return [];
    }
  }

  // Récupérer les commissions
  static Future<List<Map<String, dynamic>>> getCommissions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/commissions/modified'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getCommissions: $e');
      return [];
    }
  }

  // Récupérer les caisses
  static Future<List<Map<String, dynamic>>> getCaisses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/caisses/modified'),
        headers: defaultHeaders,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getCaisses: $e');
      return [];
    }
  }
}
