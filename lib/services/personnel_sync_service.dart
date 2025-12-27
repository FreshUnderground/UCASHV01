import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/sync_config.dart';
import 'local_db.dart';
import 'personnel_service.dart';
import 'auth_service.dart';

/// Service de synchronisation pour les données de gestion du personnel
/// 
/// Ce service synchronise les tables suivantes (SLOW SYNC):
/// - personnel
/// - salaires
/// - avances_personnel
/// - credits_personnel
/// - retenues_personnel
class PersonnelSyncService {
  static final PersonnelSyncService _instance = PersonnelSyncService._internal();
  factory PersonnelSyncService() => _instance;
  PersonnelSyncService._internal();

  static PersonnelSyncService get instance => _instance;

  /// Tables de personnel (synchronisation lente)
  static const List<String> personnelTables = [
    'personnel',
    'salaires',
    'avances_personnel',
    'credits_personnel',
    'retenues_personnel',
  ];

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Synchronise toutes les données de personnel (upload + download)
  Future<bool> syncPersonnelData({bool forceFullSync = false}) async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation personnel déjà en cours');
      return false;
    }

    _isSyncing = true;
    debugPrint('🔄 ========== DÉBUT SYNC PERSONNEL (SLOW) ==========');

    try {
      // 1. Upload des données locales non synchronisées
      await _uploadPersonnelData();

      // 2. Download des données du serveur
      await _downloadPersonnelData(forceFullSync: forceFullSync);

      _lastSyncTime = DateTime.now();
      debugPrint('✅ Synchronisation personnel terminée avec succès');
      debugPrint('🔄 ========== FIN SYNC PERSONNEL ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la sync personnel: $e');
      if (kDebugMode) {
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload des données locales vers le serveur
  Future<void> _uploadPersonnelData() async {
    debugPrint('📤 Upload données personnel...');

    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      
      // 1. D'abord, traiter les suppressions
      await _uploadDeletions(baseUrl);
      
      // 2. Ensuite, collecter toutes les données non synchronisées de toutes les tables
      final List<Map<String, dynamic>> allEntities = [];
      
      // Personnel
      final personnelData = await _getUnsyncedPersonnel();
      for (var p in personnelData) {
        p['_table'] = 'personnel';
        allEntities.add(p);
      }
      
      // Salaires
      final salairesData = await _getUnsyncedSalaires();
      for (var s in salairesData) {
        s['_table'] = 'salaires';
        allEntities.add(s);
      }
      
      // Avances
      final avancesData = await _getUnsyncedAvances();
      for (var a in avancesData) {
        a['_table'] = 'avances_personnel';
        allEntities.add(a);
      }
      
      // Crédits
      final creditsData = await _getUnsyncedCredits();
      for (var c in creditsData) {
        c['_table'] = 'credits_personnel';
        allEntities.add(c);
      }
      
      // Retenues
      final retenuesData = await _getUnsyncedRetenues();
      for (var r in retenuesData) {
        r['_table'] = 'retenues_personnel';
        allEntities.add(r);
      }
      
      if (allEntities.isEmpty) {
        debugPrint('  ℹ️ Aucune donnée à uploader');
        return;
      }

      debugPrint('  📤 Upload de ${allEntities.length} enregistrements (Personnel: ${personnelData.length}, Salaires: ${salairesData.length}, Avances: ${avancesData.length}, Crédits: ${creditsData.length}, Retenues: ${retenuesData.length})');

      // Envoyer au serveur
      final response = await http.post(
        Uri.parse('$baseUrl/api/sync/personnel/upload.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'entities': allEntities}),
      ).timeout(SyncConfig.syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('  ✅ Upload terminé: ${result['uploaded_count']} insérés, ${result['updated_count']} mis à jour');
          // Les données sont marquées comme synchronisées côté serveur
        } else {
          debugPrint('  ⚠️ Erreur upload: ${result['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        debugPrint('  ❌ Upload failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Erreur upload: $e');
      rethrow;
    }
  }

  /// Download des données du serveur
  Future<void> _downloadPersonnelData({bool forceFullSync = false}) async {
    debugPrint('📥 Download données personnel...');

    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      
      // Récupérer les informations d'authentification
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        debugPrint('  ❌ Aucun utilisateur connecté pour la sync personnel');
        return;
      }
      
      // Construire l'URL avec les paramètres requis
      String url = '$baseUrl/api/sync/personnel/changes.php';
      final queryParams = <String, String>{
        'user_id': currentUser.username ?? 'unknown',
        'user_role': currentUser.role ?? 'agent',
      };
      
      if (currentUser.shopId != null) {
        queryParams['shop_id'] = currentUser.shopId.toString();
      }
      
      if (!forceFullSync) {
        final lastSync = await _getLastSyncTimestamp('personnel');
        if (lastSync != null) {
          queryParams['since'] = lastSync.toIso8601String();
        }
      }
      
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      debugPrint('  📥 Download depuis $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(SyncConfig.syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final changes = result['entities'] as List? ?? [];
          
          if (changes.isEmpty) {
            debugPrint('  ℹ️ Aucune nouvelle donnée');
            await _updateLastSyncTimestamp('personnel');
            return;
          }

          debugPrint('  📥 ${changes.length} enregistrements reçus');
          if (result['breakdown'] != null) {
            final breakdown = result['breakdown'];
            debugPrint('     Personnel: ${breakdown['personnel'] ?? 0}, Salaires: ${breakdown['salaires'] ?? 0}, Avances: ${breakdown['avances'] ?? 0}, Crédits: ${breakdown['credits'] ?? 0}, Retenues: ${breakdown['retenues'] ?? 0}');
          }

          // Insérer/Mettre à jour les données locales par table
          for (var change in changes) {
            final tableName = change['_table'] as String?;
            if (tableName != null) {
              // Vérifier si c'est une suppression
              if (change['_deleted'] == true) {
                await _handleDeletionFromServer(tableName, change);
              } else {
                await _updateLocalData(tableName, [change]);
              }
            }
          }
          
          // Mettre à jour le timestamp
          await _updateLastSyncTimestamp('personnel');
          
          debugPrint('  ✅ Download terminé');
        } else {
          debugPrint('  ⚠️ Erreur download: ${result['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        debugPrint('  ❌ Download failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Erreur download: $e');
      rethrow;
    }
  }

  /// Récupère les données non synchronisées
  Future<List<Map<String, dynamic>>> _getUnsyncedPersonnel() async {
    final prefs = await LocalDB.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('personnel_')) {
        try {
          final personnelData = prefs.getString(key);
          if (personnelData != null) {
            final personnelJson = jsonDecode(personnelData);
            // Vérifier si non synchronisé (is_synced = false ou absent)
            if (personnelJson['is_synced'] != true && personnelJson['is_synced'] != 1) {
              results.add(personnelJson);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing personnel $key: $e');
        }
      }
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> _getUnsyncedSalaires() async {
    final prefs = await LocalDB.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('salaire_')) {
        try {
          final salaireData = prefs.getString(key);
          if (salaireData != null) {
            final salaireJson = jsonDecode(salaireData);
            // Vérifier si non synchronisé (is_synced = false ou absent)
            if (salaireJson['is_synced'] != true && salaireJson['is_synced'] != 1) {
              results.add(salaireJson);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing salaire $key: $e');
        }
      }
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> _getUnsyncedAvances() async {
    final prefs = await LocalDB.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('avance_personnel_')) {
        try {
          final avanceData = prefs.getString(key);
          if (avanceData != null) {
            final avanceJson = jsonDecode(avanceData);
            // Vérifier si non synchronisé (is_synced = false ou absent)
            if (avanceJson['is_synced'] != true && avanceJson['is_synced'] != 1) {
              results.add(avanceJson);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing avance $key: $e');
        }
      }
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> _getUnsyncedCredits() async {
    final prefs = await LocalDB.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('credit_personnel_')) {
        try {
          final creditData = prefs.getString(key);
          if (creditData != null) {
            final creditJson = jsonDecode(creditData);
            // Vérifier si non synchronisé (is_synced = false ou absent)
            if (creditJson['is_synced'] != true && creditJson['is_synced'] != 1) {
              results.add(creditJson);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing credit $key: $e');
        }
      }
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> _getUnsyncedRetenues() async {
    final prefs = await LocalDB.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('retenue_personnel_')) {
        try {
          final retenueData = prefs.getString(key);
          if (retenueData != null) {
            final retenueJson = jsonDecode(retenueData);
            // Vérifier si non synchronisé (is_synced = false ou absent)
            if (retenueJson['is_synced'] != true && retenueJson['is_synced'] != 1) {
              results.add(retenueJson);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing retenue $key: $e');
        }
      }
    }
    
    return results;
  }

  /// Met à jour les données locales avec les données du serveur
  Future<void> _updateLocalData(String tableName, List data) async {
    final prefs = await LocalDB.instance.database;
    
    for (var record in data) {
      final Map<String, dynamic> recordMap = Map<String, dynamic>.from(record);
      
      // Déterminer le préfixe de clé basé sur le nom de la table
      String keyPrefix;
      switch (tableName) {
        case 'personnel':
          keyPrefix = 'personnel_';
          break;
        case 'salaires':
          keyPrefix = 'salaire_';
          break;
        case 'avances_personnel':
          keyPrefix = 'avance_personnel_';
          break;
        case 'credits_personnel':
          keyPrefix = 'credit_personnel_';
          break;
        case 'retenues_personnel':
          keyPrefix = 'retenue_personnel_';
          break;
        default:
          keyPrefix = '${tableName}_';
      }
      
      // Utiliser l'ID pour créer la clé
      final id = recordMap['id'];
      if (id != null) {
        final key = '$keyPrefix$id';
        
        // Marquer comme synchronisé
        recordMap['is_synced'] = true;
        recordMap['synced_at'] = DateTime.now().toIso8601String();
        
        // Sauvegarder dans SharedPreferences
        await prefs.setString(key, jsonEncode(recordMap));
        debugPrint('✅ Données $tableName ID $id mises à jour localement');
      }
    }
  }

  /// Récupère le timestamp de dernière synchronisation pour une table
  Future<DateTime?> _getLastSyncTimestamp(String tableName) async {
    final prefs = await LocalDB.instance.database;
    final timestampStr = prefs.getString('${tableName}_last_sync');
    if (timestampStr != null) {
      try {
        return DateTime.parse(timestampStr);
      } catch (e) {
        debugPrint('⚠️ Erreur parsing timestamp sync $tableName: $e');
        return null;
      }
    }
    return null;
  }

  /// Met à jour le timestamp de dernière synchronisation
  Future<void> _updateLastSyncTimestamp(String tableName) async {
    final prefs = await LocalDB.instance.database;
    await prefs.setString('${tableName}_last_sync', DateTime.now().toIso8601String());
    debugPrint('✅ Timestamp de sync mis à jour pour $tableName');
  }

  /// Upload des suppressions vers le serveur
  Future<void> _uploadDeletions(String baseUrl) async {
    try {
      // Récupérer les suppressions en attente
      final deletions = await _getPendingDeletions();
      
      if (deletions.isEmpty) {
        debugPrint('  ℹ️ Aucune suppression à uploader');
        return;
      }
      
      debugPrint('  🗑️ Upload de ${deletions.length} suppressions');
      
      // Envoyer au serveur
      final response = await http.post(
        Uri.parse('$baseUrl/api/sync/personnel/delete.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deletions': deletions}),
      ).timeout(SyncConfig.syncTimeout);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('  ✅ Suppressions uploadées: ${result['processed_count']} traitées');
          
          // Marquer les suppressions comme synchronisées
          for (var deletion in deletions) {
            await _markDeletionAsSynced(deletion['matricule'], deletion['type']);
          }
        } else {
          debugPrint('  ⚠️ Erreur upload suppressions: ${result['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        debugPrint('  ❌ Upload suppressions failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Erreur upload suppressions: $e');
    }
  }
  
  /// Récupérer les suppressions en attente
  Future<List<Map<String, dynamic>>> _getPendingDeletions() async {
    final prefs = await LocalDB.instance.database;
    final keys = prefs.getKeys();
    final deletions = <Map<String, dynamic>>[];
    
    for (String key in keys) {
      if (key.startsWith('deletion_')) {
        try {
          final data = prefs.getString(key);
          if (data != null) {
            final deletion = jsonDecode(data);
            if (deletion['synced'] != true) {
              // S'assurer que les bons identifiants sont présents
              if (deletion['type'] == 'personnel') {
                // Pour personnel, utiliser matricule
                if (!deletion.containsKey('matricule')) {
                  debugPrint('⚠️ Suppression personnel sans matricule: $key');
                  continue;
                }
              } else {
                // Pour autres (salaires, avances, retenues), utiliser reference
                if (!deletion.containsKey('reference')) {
                  debugPrint('⚠️ Suppression ${deletion['type']} sans reference: $key');
                  continue;
                }
              }
              deletions.add(deletion);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lecture suppression $key: $e');
        }
      }
    }
    
    return deletions;
  }
  
  /// Marquer une suppression comme synchronisée
  Future<void> _markDeletionAsSynced(String matricule, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'deletion_${type}_$matricule';
      
      final data = prefs.getString(key);
      if (data != null) {
        final deletion = jsonDecode(data);
        deletion['synced'] = true;
        deletion['synced_at'] = DateTime.now().toIso8601String();
        
        await prefs.setString(key, jsonEncode(deletion));
        debugPrint('✅ Suppression marquée comme synchronisée: $type Matricule $matricule');
        
        // Notifier le PersonnelService pour la suppression définitive
        await _notifyDeletionSynced(matricule, type);
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage sync suppression: $e');
    }
  }
  
  /// Notifier qu'une suppression a été synchronisée
  Future<void> _notifyDeletionSynced(String matricule, String type) async {
    try {
      // Importer le PersonnelService de manière sécurisée
      final personnelService = PersonnelService.instance;
      await personnelService.markDeletionAsSynced(matricule, type);
    } catch (e) {
      debugPrint('⚠️ Erreur notification suppression: $e');
    }
  }

  /// Gérer une suppression reçue du serveur
  Future<void> _handleDeletionFromServer(String tableName, Map<String, dynamic> deletedRecord) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Pour le personnel, utiliser le matricule, pour les autres utiliser la référence
      String identifier;
      String keyPrefix;
      
      switch (tableName) {
        case 'personnel':
          identifier = deletedRecord['matricule'];
          keyPrefix = 'personnel_';
          break;
        case 'salaires':
          identifier = deletedRecord['reference'];
          keyPrefix = 'salaire_';
          break;
        case 'avances_personnel':
          identifier = deletedRecord['reference'];
          keyPrefix = 'avance_personnel_';
          break;
        case 'credits_personnel':
          identifier = deletedRecord['reference'];
          keyPrefix = 'credit_personnel_';
          break;
        case 'retenues_personnel':
          identifier = deletedRecord['reference'];
          keyPrefix = 'retenue_personnel_';
          break;
        default:
          identifier = deletedRecord['id']?.toString() ?? '';
          keyPrefix = '${tableName}_';
      }
      
      if (identifier.isEmpty) {
        debugPrint('⚠️ Identifiant manquant pour suppression $tableName');
        return;
      }
      
      final key = '$keyPrefix$identifier';
      
      // Vérifier si l'enregistrement existe localement
      final existingData = prefs.getString(key);
      if (existingData != null) {
        // Supprimer l'enregistrement local
        await prefs.remove(key);
        debugPrint('🗑️ Suppression propagée: $tableName Identifiant $identifier');
        
        // Si c'est un personnel, supprimer aussi les données liées
        if (tableName == 'personnel') {
          await _deleteRelatedDataFromSync(identifier);
        }
      } else {
        debugPrint('ℹ️ Enregistrement $tableName Identifiant $identifier déjà supprimé localement');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur gestion suppression $tableName: $e');
    }
  }
  
  /// Supprimer les données liées lors d'une suppression de personnel via sync
  Future<void> _deleteRelatedDataFromSync(String personnelMatricule) async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys();
      
      // Supprimer salaires
      for (String key in keys) {
        if (key.startsWith('salaire_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_matricule'] == personnelMatricule) {
                await prefs.remove(key);
                debugPrint('🗑️ Salaire supprimé via sync: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression salaire sync $key: $e');
          }
        }
      }
      
      // Supprimer avances
      for (String key in keys) {
        if (key.startsWith('avance_personnel_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_matricule'] == personnelMatricule) {
                await prefs.remove(key);
                debugPrint('🗑️ Avance supprimée via sync: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression avance sync $key: $e');
          }
        }
      }
      
      // Supprimer retenues
      for (String key in keys) {
        if (key.startsWith('retenue_personnel_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_matricule'] == personnelMatricule) {
                await prefs.remove(key);
                debugPrint('🗑️ Retenue supprimée via sync: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression retenue sync $key: $e');
          }
        }
      }
      
      debugPrint('✅ Données liées supprimées via sync pour personnel Matricule $personnelMatricule');
    } catch (e) {
      debugPrint('❌ Erreur suppression données liées sync: $e');
    }
  }

  /// Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
}
