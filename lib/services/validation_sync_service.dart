import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service pour détecter les validations d'opérations par d'autres agents
class ValidationSyncService {
  static const String _lastValidationCheckKey = 'last_validation_check';
  
  /// Vérifie les validations d'opérations
  static Future<ValidationSyncResult> checkValidations({
    required String userId,
    required String userRole,
    int? shopId,
    bool myOperationsOnly = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastValidationCheckKey);
      
      final baseUrl = AppConfig.apiBaseUrl;
      final url = '$baseUrl/sync/operations/validation_sync.php?'
          'user_id=$userId&user_role=$userRole&'
          'my_operations_only=$myOperationsOnly&'
          '${shopId != null ? 'shop_id=$shopId&' : ''}'
          '${lastCheck != null ? 'last_validation_check=$lastCheck&' : ''}'
          'limit=50&compress=true';
      
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await prefs.setString(_lastValidationCheckKey, DateTime.now().toIso8601String());
          return ValidationSyncResult.fromJson(data);
        }
      }
      throw Exception('Erreur validation sync');
    } catch (e) {
      debugPrint('❌ Erreur Validation Check: $e');
      rethrow;
    }
  }
}

/// Résultat de synchronisation des validations
class ValidationSyncResult {
  final List<Map<String, dynamic>> validations;
  final ValidationStats stats;
  
  ValidationSyncResult({required this.validations, required this.stats});
  
  factory ValidationSyncResult.fromJson(Map<String, dynamic> json) {
    return ValidationSyncResult(
      validations: List<Map<String, dynamic>>.from(json['validations'] ?? []),
      stats: ValidationStats.fromJson(json['validation_stats'] ?? {}),
    );
  }
}

/// Statistiques des validations
class ValidationStats {
  final int mesOperationsValidees;
  final int validationsRecentes;
  
  ValidationStats({required this.mesOperationsValidees, required this.validationsRecentes});
  
  factory ValidationStats.fromJson(Map<String, dynamic> json) {
    return ValidationStats(
      mesOperationsValidees: json['mes_operations_validees'] ?? 0,
      validationsRecentes: json['validations_recentes'] ?? 0,
    );
  }
}
