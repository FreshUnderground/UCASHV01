import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Types de synchronisation disponibles
enum SyncMode {
  delta,      // Nouvelles + mises à jour
  updatesOnly, // Seulement les mises à jour
  full        // Synchronisation complète
}

/// Filtres de statut pour optimiser les requêtes
enum StatusFilter {
  pending,    // Seulement en attente
  recent,     // Servis/annulés récents
  critical,   // En attente + modifications récentes
  all         // Tous les statuts
}

/// Gestionnaire de synchronisation delta intelligente
/// Évite le retéléchargement des opérations déjà synchronisées
class DeltaSyncManager {
  static const String _knownOperationsKey = 'known_operations_ids';
  static const String _lastSyncHashKey = 'last_sync_hash';
  static const String _lastSyncTimestampKey = 'last_sync_timestamp';
  
  /// Effectue une synchronisation delta intelligente
  static Future<DeltaSyncResult> performDeltaSync({
    required String userId,
    required String userRole,
    int? shopId,
    SyncMode mode = SyncMode.delta,
    StatusFilter statusFilter = StatusFilter.critical,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔄 DELTA SYNC - Mode: $mode, Filter: $statusFilter');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les IDs déjà synchronisés
      final knownIds = await _getKnownOperationIds();
      final lastSyncHash = prefs.getString(_lastSyncHashKey);
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);
      
      // Construire l'URL avec les paramètres optimisés
      final url = _buildDeltaSyncUrl(
        userId: userId,
        userRole: userRole,
        shopId: shopId,
        knownIds: knownIds,
        mode: mode,
        statusFilter: statusFilter,
        lastSyncHash: lastSyncHash,
        lastSyncTimestamp: lastSyncTimestamp,
        limit: limit,
        offset: offset,
      );
      
      debugPrint('📡 Delta Sync URL: $url');
      
      // Effectuer la requête
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final result = DeltaSyncResult.fromJson(data);
          
          // Mettre à jour le cache local
          await _updateLocalCache(result);
          
          debugPrint('✅ Delta Sync réussie: ${result.syncStats.totalOperations} opérations');
          debugPrint('   - Nouvelles: ${result.syncStats.newOperations}');
          debugPrint('   - Mises à jour: ${result.syncStats.updatedOperations}');
          
          return result;
        } else {
          throw Exception('Erreur API: ${data['message']}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur Delta Sync: $e');
      rethrow;
    }
  }
  
  /// Construit l'URL pour la synchronisation delta
  static String _buildDeltaSyncUrl({
    required String userId,
    required String userRole,
    int? shopId,
    required List<int> knownIds,
    required SyncMode mode,
    required StatusFilter statusFilter,
    String? lastSyncHash,
    String? lastSyncTimestamp,
    required int limit,
    required int offset,
  }) {
    final baseUrl = '${AppConfig.apiBaseUrl}/sync/operations/delta_sync.php';
    final params = <String, String>{
      'user_id': userId,
      'user_role': userRole,
      'sync_mode': mode.name,
      'limit': limit.toString(),
      'offset': offset.toString(),
      'compress': 'true',
    };
    
    if (shopId != null) {
      params['shop_id'] = shopId.toString();
    }
    
    if (knownIds.isNotEmpty) {
      params['known_ids'] = knownIds.join(',');
    }
    
    if (lastSyncHash != null) {
      params['last_sync_hash'] = lastSyncHash;
    }
    
    if (lastSyncTimestamp != null) {
      params['since'] = lastSyncTimestamp;
    }
    
    // Filtrage par statut intelligent
    switch (statusFilter) {
      case StatusFilter.pending:
        params['status_filter'] = 'en_attente';
        break;
      case StatusFilter.recent:
        params['status_filter'] = 'servi,annule';
        params['served_days'] = '2';
        params['cancelled_days'] = '1';
        break;
      case StatusFilter.critical:
        params['filter_mode'] = 'smart';
        params['pending_all'] = 'true';
        params['served_days'] = '2';
        params['cancelled_days'] = '1';
        break;
      case StatusFilter.all:
        // Pas de filtre spécifique
        break;
    }
    
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '$baseUrl?$queryString';
  }
  
  /// Récupère les IDs des opérations déjà synchronisées
  static Future<List<int>> _getKnownOperationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final knownIdsString = prefs.getString(_knownOperationsKey);
      
      if (knownIdsString != null && knownIdsString.isNotEmpty) {
        return knownIdsString
            .split(',')
            .map((id) => int.tryParse(id))
            .where((id) => id != null)
            .cast<int>()
            .toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('⚠️ Erreur lecture known IDs: $e');
      return [];
    }
  }
  
  /// Met à jour le cache local avec les nouvelles données
  static Future<void> _updateLocalCache(DeltaSyncResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les IDs existants
      final existingIds = await _getKnownOperationIds();
      
      // Ajouter les nouveaux IDs
      final newIds = result.entities.map((op) => op['id'] as int).toList();
      final allIds = {...existingIds, ...newIds}.toList();
      
      // Limiter le cache à 5000 IDs max (pour éviter la surcharge)
      if (allIds.length > 5000) {
        allIds.sort((a, b) => b.compareTo(a)); // Trier par ID décroissant
        allIds.removeRange(5000, allIds.length); // Garder les 5000 plus récents
      }
      
      // Sauvegarder
      await prefs.setString(_knownOperationsKey, allIds.join(','));
      await prefs.setString(_lastSyncHashKey, result.syncStats.syncHash);
      await prefs.setString(_lastSyncTimestampKey, DateTime.now().toIso8601String());
      
      debugPrint('💾 Cache mis à jour: ${allIds.length} IDs connus');
      
    } catch (e) {
      debugPrint('⚠️ Erreur mise à jour cache: $e');
    }
  }
  
  /// Réinitialise le cache de synchronisation (force full sync)
  static Future<void> resetSyncCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_knownOperationsKey);
      await prefs.remove(_lastSyncHashKey);
      await prefs.remove(_lastSyncTimestampKey);
      
      debugPrint('🗑️ Cache de synchronisation réinitialisé');
    } catch (e) {
      debugPrint('⚠️ Erreur reset cache: $e');
    }
  }
  
  /// Obtient les statistiques du cache local
  static Future<CacheStats> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final knownIds = await _getKnownOperationIds();
      final lastSyncHash = prefs.getString(_lastSyncHashKey);
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);
      
      return CacheStats(
        knownOperationsCount: knownIds.length,
        lastSyncHash: lastSyncHash,
        lastSyncTimestamp: lastSyncTimestamp,
        cacheSize: knownIds.join(',').length,
      );
    } catch (e) {
      debugPrint('⚠️ Erreur stats cache: $e');
      return CacheStats(
        knownOperationsCount: 0,
        lastSyncHash: null,
        lastSyncTimestamp: null,
        cacheSize: 0,
      );
    }
  }
}

/// Résultat d'une synchronisation delta
class DeltaSyncResult {
  final bool success;
  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> newOperations;
  final List<Map<String, dynamic>> updatedOperations;
  final SyncStats syncStats;
  final PaginationInfo pagination;
  
  DeltaSyncResult({
    required this.success,
    required this.entities,
    required this.newOperations,
    required this.updatedOperations,
    required this.syncStats,
    required this.pagination,
  });
  
  factory DeltaSyncResult.fromJson(Map<String, dynamic> json) {
    return DeltaSyncResult(
      success: json['success'] ?? false,
      entities: List<Map<String, dynamic>>.from(json['entities'] ?? []),
      newOperations: List<Map<String, dynamic>>.from(json['new_operations'] ?? []),
      updatedOperations: List<Map<String, dynamic>>.from(json['updated_operations'] ?? []),
      syncStats: SyncStats.fromJson(json['sync_stats'] ?? {}),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }
}

/// Statistiques de synchronisation
class SyncStats {
  final int totalOperations;
  final int newOperations;
  final int updatedOperations;
  final String syncMode;
  final int knownIdsCount;
  final String syncHash;
  final String timestamp;
  
  SyncStats({
    required this.totalOperations,
    required this.newOperations,
    required this.updatedOperations,
    required this.syncMode,
    required this.knownIdsCount,
    required this.syncHash,
    required this.timestamp,
  });
  
  factory SyncStats.fromJson(Map<String, dynamic> json) {
    return SyncStats(
      totalOperations: json['total_operations'] ?? 0,
      newOperations: json['new_operations'] ?? 0,
      updatedOperations: json['updated_operations'] ?? 0,
      syncMode: json['sync_mode'] ?? 'unknown',
      knownIdsCount: json['known_ids_count'] ?? 0,
      syncHash: json['sync_hash'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

/// Informations de pagination
class PaginationInfo {
  final int limit;
  final int offset;
  final bool hasMore;
  
  PaginationInfo({
    required this.limit,
    required this.offset,
    required this.hasMore,
  });
  
  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      limit: json['limit'] ?? 0,
      offset: json['offset'] ?? 0,
      hasMore: json['has_more'] ?? false,
    );
  }
}

/// Statistiques du cache local
class CacheStats {
  final int knownOperationsCount;
  final String? lastSyncHash;
  final String? lastSyncTimestamp;
  final int cacheSize;
  
  CacheStats({
    required this.knownOperationsCount,
    required this.lastSyncHash,
    required this.lastSyncTimestamp,
    required this.cacheSize,
  });
}
