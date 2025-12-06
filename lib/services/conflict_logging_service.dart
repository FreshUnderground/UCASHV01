import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de journalisation des conflits de synchronisation
/// Enregistre et rapporte les conflits détectés pour analyse et amélioration
class ConflictLoggingService extends ChangeNotifier {
  static final ConflictLoggingService _instance = ConflictLoggingService._internal();
  factory ConflictLoggingService() => _instance;
  ConflictLoggingService._internal();

  static const String _conflictsKey = 'sync_conflicts_log';
  static const int _maxLogEntries = 100;

  /// Enregistre un conflit détecté
  Future<void> logConflict({
    required String tableName,
    required dynamic entityId,
    required DateTime localModified,
    required DateTime remoteModified,
    required String resolutionStrategy,
    required bool resolvedSuccessfully,
    String? errorMessage,
    Map<String, dynamic>? localData,
    Map<String, dynamic>? remoteData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les conflits existants
      final existingConflicts = await _getStoredConflicts();
      
      // Créer un nouvel enregistrement de conflit
      final conflictRecord = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'timestamp': DateTime.now().toIso8601String(),
        'tableName': tableName,
        'entityId': entityId.toString(),
        'localModified': localModified.toIso8601String(),
        'remoteModified': remoteModified.toIso8601String(),
        'resolutionStrategy': resolutionStrategy,
        'resolvedSuccessfully': resolvedSuccessfully,
        'errorMessage': errorMessage,
        // Ne pas stocker les données complètes pour des raisons de taille
        'localDataPreview': _getDataPreview(localData),
        'remoteDataPreview': _getDataPreview(remoteData),
      };
      
      // Ajouter le nouveau conflit à la liste
      existingConflicts.add(conflictRecord);
      
      // Limiter le nombre d'entrées
      if (existingConflicts.length > _maxLogEntries) {
        existingConflicts.removeRange(0, existingConflicts.length - _maxLogEntries);
      }
      
      // Sauvegarder dans SharedPreferences
      final jsonString = jsonEncode(existingConflicts);
      await prefs.setString(_conflictsKey, jsonString);
      
      debugPrint('📝 Conflit enregistré: $tableName ID $entityId - Résolu: $resolvedSuccessfully');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement du conflit: $e');
    }
  }
  
  /// Récupère les conflits enregistrés
  Future<List<Map<String, dynamic>>> _getStoredConflicts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_conflictsKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la lecture des conflits enregistrés: $e');
    }
    
    return [];
  }
  
  /// Obtient un aperçu des données pour le journal
  String _getDataPreview(Map<String, dynamic>? data) {
    if (data == null) return 'null';
    
    final buffer = StringBuffer();
    
    // Nom ou désignation
    if (data.containsKey('nom')) {
      buffer.write('${data['nom']}');
    } else if (data.containsKey('designation')) {
      buffer.write('${data['designation']}');
    } else if (data.containsKey('username')) {
      buffer.write('${data['username']}');
    } else if (data.containsKey('telephone')) {
      buffer.write('${data['telephone']}');
    }
    
    // Montant pour les opérations
    if (data.containsKey('montant_net')) {
      if (buffer.isNotEmpty) buffer.write(' - ');
      buffer.write('${data['montant_net']} ${data['devise'] ?? 'USD'}');
    }
    
    // Type
    if (data.containsKey('type')) {
      if (buffer.isNotEmpty) buffer.write(' (${data['type']})');
    }
    
    return buffer.isEmpty ? 'Données' : buffer.toString();
  }
  
  /// Génère un rapport de santé des synchronisations
  Future<SyncHealthReport> generateHealthReport() async {
    try {
      final conflicts = await _getStoredConflicts();
      
      // Calculer les statistiques
      final totalConflicts = conflicts.length;
      final resolvedSuccessfully = conflicts.where((c) => c['resolvedSuccessfully'] == true).length;
      final resolutionRate = totalConflicts > 0 ? (resolvedSuccessfully / totalConflicts) * 100 : 100.0;
      
      // Compter les conflits par type de données
      final conflictsByTable = <String, int>{};
      for (var conflict in conflicts) {
        final table = conflict['tableName'] as String;
        conflictsByTable[table] = (conflictsByTable[table] ?? 0) + 1;
      }
      
      // Compter les conflits par stratégie de résolution
      final conflictsByStrategy = <String, int>{};
      for (var conflict in conflicts) {
        final strategy = conflict['resolutionStrategy'] as String;
        conflictsByStrategy[strategy] = (conflictsByStrategy[strategy] ?? 0) + 1;
      }
      
      // Identifier les erreurs fréquentes
      final errorMessages = <String, int>{};
      for (var conflict in conflicts) {
        final error = conflict['errorMessage'] as String?;
        if (error != null && error.isNotEmpty) {
          errorMessages[error] = (errorMessages[error] ?? 0) + 1;
        }
      }
      
      return SyncHealthReport(
        totalConflicts: totalConflicts,
        resolvedSuccessfully: resolvedSuccessfully,
        resolutionRate: resolutionRate,
        conflictsByTable: conflictsByTable,
        conflictsByStrategy: conflictsByStrategy,
        frequentErrors: errorMessages,
        lastConflictTimestamp: conflicts.isNotEmpty 
            ? DateTime.tryParse(conflicts.last['timestamp'] as String) 
            : null,
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la génération du rapport de santé: $e');
      return SyncHealthReport.empty();
    }
  }
  
  /// Efface le journal des conflits
  Future<void> clearConflictLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conflictsKey);
      debugPrint('🗑️ Journal des conflits effacé');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'effacement du journal des conflits: $e');
    }
  }
  
  /// Exporte le journal des conflits au format JSON
  Future<String> exportConflictLog() async {
    try {
      final conflicts = await _getStoredConflicts();
      return jsonEncode(conflicts);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'export du journal des conflits: $e');
      return '[]';
    }
  }
}

/// Rapport de santé des synchronisations
class SyncHealthReport {
  final int totalConflicts;
  final int resolvedSuccessfully;
  final double resolutionRate;
  final Map<String, int> conflictsByTable;
  final Map<String, int> conflictsByStrategy;
  final Map<String, int> frequentErrors;
  final DateTime? lastConflictTimestamp;
  
  SyncHealthReport({
    required this.totalConflicts,
    required this.resolvedSuccessfully,
    required this.resolutionRate,
    required this.conflictsByTable,
    required this.conflictsByStrategy,
    required this.frequentErrors,
    this.lastConflictTimestamp,
  });
  
  /// Crée un rapport vide
  static SyncHealthReport empty() {
    return SyncHealthReport(
      totalConflicts: 0,
      resolvedSuccessfully: 0,
      resolutionRate: 100.0,
      conflictsByTable: {},
      conflictsByStrategy: {},
      frequentErrors: {},
    );
  }
  
  /// Vérifie si la santé est bonne (taux de résolution > 95%)
  bool get isHealthy => resolutionRate >= 95.0;
  
  /// Obtient un message de statut
  String get statusMessage {
    if (totalConflicts == 0) return 'Aucun conflit détecté';
    if (isHealthy) return 'Bon état de synchronisation';
    return 'Problèmes de synchronisation détectés';
  }
  
  @override
  String toString() {
    return 'SyncHealthReport(totalConflicts: $totalConflicts, '
        'resolvedSuccessfully: $resolvedSuccessfully, '
        'resolutionRate: ${resolutionRate.toStringAsFixed(2)}%, '
        'isHealthy: $isHealthy)';
  }
}