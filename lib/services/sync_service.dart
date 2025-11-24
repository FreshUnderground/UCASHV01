import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'shop_service.dart';
import 'agent_service.dart';
import 'client_service.dart';
import 'operation_service.dart';
import 'rates_service.dart';
import 'transfer_sync_service.dart';
import 'compte_special_service.dart';
import 'auth_service.dart'; // Add this import
import 'local_db.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';
import '../models/compte_special_model.dart';
import '../models/document_header_model.dart';
import '../models/cloture_caisse_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../config/app_config.dart';

/// Service de synchronisation bidirectionnelle avec gestion des conflits
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  static Future<String> get _baseUrl async => await AppConfig.getSyncBaseUrl();
  static Duration get _syncTimeout => AppConfig.syncTimeout;
  
  // Stream pour notifier les changements de statut de sync
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  // État actuel de la synchronisation
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;
  
  // Listener de connectivité
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isAutoSyncEnabled = true; // Activé par défaut pour synchronisation automatique
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  bool _isSyncing = false;
  bool _isOnline = false;
  
  // Timer pour la synchronisation automatique périodique
  Timer? _autoSyncTimer;
  Timer? _flotsOpsAutoSyncTimer; // Timer spécifique pour flots et opérations
  static Duration get _autoSyncInterval => const Duration(minutes: 2);
  DateTime? _lastSyncTime;
  DateTime? _lastFlotsOpsSyncTime; // Dernière sync flots/ops
  
  // File d'attente pour les données en attente de synchronisation (mode offline)
  final List<Map<String, dynamic>> _pendingOperations = [];
  int _pendingSyncCount = 0;

  /// Initialise le service de synchronisation
  Future<void> initialize() async {
    debugPrint('🔄 Initialisation du service de synchronisation...');

    // Vérifier si le cache des commissions doit être réinitialisé (une seule fois)
    final prefs = await SharedPreferences.getInstance();
    final needsCommissionReset = !prefs.containsKey('commissions_cache_reset_v1');
    
    if (needsCommissionReset) {
      debugPrint('🆕 Première utilisation après mise à jour - reset cache commissions nécessaire');
      try {
        // Marquer comme fait AVANT le reset pour éviter les boucles en cas d'erreur
        await prefs.setBool('commissions_cache_reset_v1', true);
        await resetCommissionsCache();
      } catch (e) {
        debugPrint('⚠️ Erreur lors du reset initial du cache commissions: $e');
        // Continuer quand même l'initialisation
      }
    }
    
    // Écouter les changements de connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Vérifier la connectivité initiale
    final connectivityResult = await Connectivity().checkConnectivity();
    _onConnectivityChanged(connectivityResult);
    
    // Démarrer l'auto-sync si la connexion est disponible
    if (_isAutoSyncEnabled) {
      startAutoSync();
      debugPrint('⏰ Synchronisation automatique activée (intervalle: ${_autoSyncInterval.inSeconds}s)');
      
      // Démarrer aussi la sync spécialisée FLOTS & OPERATIONS
      startFlotsOpsAutoSync();
      debugPrint('🚀⏰ Synchronisation auto FLOTS & OPERATIONS activée (intervalle: ${_autoSyncInterval.inSeconds}s)');
    }
    
    debugPrint('✅ Service de synchronisation initialisé (auto-sync: ${_isAutoSyncEnabled ? "ON" : "OFF"})');
  }

  /// Gère les changements de connectivité
  void _onConnectivityChanged(ConnectivityResult result) async {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    // Réduire les logs en mode développement
    debugPrint('📡 Connectivité changée: $result (${_isOnline ? "Online" : "Offline"})');
    
    if (_isOnline && wasOffline) {
      // Passage de offline à online - synchroniser les données en attente
      debugPrint('🔄 Retour en ligne détecté - synchronisation des données en attente...');
      await _syncPendingData();
      
      // Redémarrer l'auto-sync si activé
      if (_isAutoSyncEnabled && _autoSyncTimer == null) {
        startAutoSync();
        debugPrint('⏰ Redémarrage de la synchronisation automatique');
        
        // Redémarrer aussi la sync FLOTS & OPERATIONS
        if (_flotsOpsAutoSyncTimer == null) {
          startFlotsOpsAutoSync();
          debugPrint('🚀⏰ Redémarrage synchronisation FLOTS & OPERATIONS');
        }
      }
    }
    
    if (_isOnline && _isAutoSyncEnabled && !_isSyncing) {
      // Auto-sync activé uniquement si _isAutoSyncEnabled = true
      final isServerAvailable = await _checkConnectivity();
      if (isServerAvailable) {
        debugPrint('🚀 Déclenchement de la synchronisation automatique...');
        await syncAll();
      }
    } else if (!_isOnline) {
      // Mode offline - arrêter l'auto-sync pour économiser les ressources
      if (_autoSyncTimer != null) {
        stopAutoSync();
        debugPrint('⏸️ Auto-sync arrêté (mode offline)');
      }
      if (_flotsOpsAutoSyncTimer != null) {
        stopFlotsOpsAutoSync();
        debugPrint('⏸️ Auto-sync FLOTS/OPS arrêté (mode offline)');
      }
      _updateStatus(SyncStatus.offline);
    }
  }

  /// Active/désactive la synchronisation automatique
  void setAutoSync(bool enabled) {
    _isAutoSyncEnabled = enabled;
    debugPrint('🔄 Synchronisation automatique: ${enabled ? "activée" : "désactivée"}');
  }

  /// Synchronisation complète bidirectionnelle
  Future<SyncResult> syncAll({String? userId}) async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours...');
      return SyncResult(success: false, message: 'Synchronisation déjà en cours');
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);
    
    // Get user info from AuthService if not provided
    String userIdToUse;
    String userRole = 'admin'; // Default to admin for testing
    
    if (userId != null) {
      userIdToUse = userId;
    } else {
      // Try to get from AuthService
      try {
        final authService = AuthService();
        if (authService.currentUser != null) {
          userIdToUse = authService.currentUser!.username ?? 'unknown';
          userRole = authService.currentUser!.role ?? 'agent';
        } else {
          userIdToUse = 'admin'; // Fallback
        }
      } catch (e) {
        userIdToUse = 'admin'; // Fallback
      }
    }
    
    debugPrint('🚀 === DÉBUT SYNCHRONISATION BIDIRECTIONNELLE (User: $userIdToUse - Role: $userRole) ===');
    
    try {
      // Vérifier la connectivité
      debugPrint('🔍 Vérification de la connectivité...');
      if (!await _checkConnectivity()) {
        final message = 'Aucune connexion Internet disponible';
        debugPrint('❌ $message');
        throw Exception(message);
      }
      
      // Vérifier si c'est la première synchronisation
      final prefs = await SharedPreferences.getInstance();
      final hasEverSynced = prefs.containsKey('last_sync_global');
      
      if (!hasEverSynced) {
        debugPrint('🆕 Première synchronisation détectée - réinitialisation du statut...');
        await resetSyncStatus();
      }

      // Phase 1: Upload des shops (entités maîtres)
      debugPrint('📤 PHASE 1A: Upload Shops → Serveur');
      try {
        await _uploadTableData('shops', userIdToUse);
      } catch (e) {
        debugPrint('❌ Erreur upload shops: $e');
      }
      
      // Phase 1B: Download des shops pour obtenir les IDs serveur
      debugPrint('📥 PHASE 1B: Download Shops ← Serveur (pour obtenir IDs)');
      try {
        await _downloadTableData('shops', userIdToUse, userRole);
        // Recharger les shops en mémoire après le download
        await ShopService.instance.loadShops();
        debugPrint('✅ Shops rechargés en mémoire après synchronisation');
      } catch (e) {
        debugPrint('❌ Erreur download shops: $e');
      }
      
      // Phase 2: Upload des entités dépendantes (avec IDs serveur)
      debugPrint('📤 PHASE 2: Upload Entités Dépendantes → Serveur');
      final dependentTables = ['agents', 'clients', 'operations', 'taux', 'commissions', 'comptes_speciaux', 'document_headers', 'cloture_caisse', 'flots'];
      for (String table in dependentTables) {
        try {
          await _uploadTableDataWithRetry(table, userIdToUse, userRole); // Pass user role
          // Recharger les entités en mémoire après l'upload
          if (table == 'agents') {
            await AgentService.instance.loadAgents();
            debugPrint('✅ Agents rechargés en mémoire après upload');
          } else if (table == 'clients') {
            await ClientService().loadClients();
            debugPrint('✅ Clients rechargés en mémoire après upload');
          } else if (table == 'operations') {
            await OperationService().loadOperations();
            debugPrint('✅ Opérations rechargées en mémoire après upload');
          }
        } catch (e) {
          debugPrint('❌ Erreur upload $table: $e');
        }
      }
      
      // Phase 3: Download des entités mises à jour
      debugPrint('📥 PHASE 3: Download Entités ← Serveur');
      try {
        await _downloadRemoteChanges(userIdToUse, userRole);
      } catch (e) {
        debugPrint('❌ Erreur download entités: $e');
      }
      
      // Marquer la synchronisation comme terminée
      await prefs.setString('last_sync_global', DateTime.now().toIso8601String());
      _lastSyncTime = DateTime.now();
      
      debugPrint('✅ === SYNCHRONISATION TERMINÉE AVEC SUCCÈS ===');
      _updateStatus(SyncStatus.idle);
      return SyncResult(success: true, message: 'Synchronisation terminée avec succès');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur fatale synchronisation: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      _updateStatus(SyncStatus.error);
      return SyncResult(success: false, message: 'Erreur: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Réinitialise le cache local des commissions et force un re-téléchargement complet
  Future<void> resetCommissionsCache() async {
    try {
      debugPrint('🗑️ Réinitialisation du cache des commissions...');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int deletedCount = 0;
      
      // Supprimer toutes les clés commission_*
      for (String key in keys) {
        if (key.startsWith('commission_')) {
          await prefs.remove(key);
          deletedCount++;
        }
      }
      
      debugPrint('🗑️ $deletedCount commissions supprimées du cache local');
      
      // Supprimer le timestamp de dernière sync pour forcer un full download
      await prefs.remove('last_sync_commissions');
      debugPrint('⏱️ Timestamp de sync commissions réinitialisé');
      
      // Forcer le re-téléchargement depuis le serveur
      debugPrint('📥 Téléchargement des commissions depuis MySQL...');
      await _downloadTableData('commissions', 'admin', 'admin');
      
      // Recharger les commissions en mémoire
      await RatesService.instance.loadRatesAndCommissions();
      
      final commissions = RatesService.instance.commissions;
      debugPrint('✅ ${commissions.length} commissions rechargées depuis le serveur');
      
      // Afficher les détails des commissions pour vérification
      for (var c in commissions) {
        debugPrint('   📊 ${c.description}: ${c.taux}% (Source: ${c.shopSourceId}, Dest: ${c.shopDestinationId})');
      }
      
      debugPrint('✅ Cache des commissions réinitialisé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de la réinitialisation du cache des commissions: $e');
      rethrow;
    }
  }

  /// Upload avec retry logic pour échecs temporaires
  Future<void> _uploadTableDataWithRetry(String tableName, String userId, String userRole, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _uploadTableData(tableName, userId, userRole);
        return; // Succès - sortir
      } catch (e) {
        debugPrint('⚠️ Upload $tableName tentative $attempt/$maxRetries échouée: $e');
        
        if (attempt == maxRetries) {
          debugPrint('❌ Upload $tableName échoué après $maxRetries tentatives');
          rethrow; // Dernier essai échoué - propager l'erreur
        }
        
        // Attendre avant de réessayer (backoff exponentiel)
        final delaySeconds = 2 * attempt;
        debugPrint('⏳ Nouvelle tentative dans ${delaySeconds}s...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Upload des changements locaux vers le serveur
  Future<void> _uploadLocalChanges(String userId) async {
    // NOTE: 'operations' est maintenant inclus dans la sync normale
    final tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions', 'document_headers', 'cloture_caisse'];
    int successCount = 0;
    int errorCount = 0;
    
    debugPrint('📤 Début de l\'upload des données locales (${tables.length} tables)');
    
    
    for (String table in tables) {
      try {
        debugPrint('📤 Upload $table...');
        await _uploadTableDataWithRetry(table, userId, 'admin'); // Utiliser version avec retry
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur upload $table: $e');
        errorCount++;
        // Continuer avec les autres tables
      }
    }
    
    debugPrint('📤 Upload terminé: $successCount succès, $errorCount erreurs');
  }

  /// Valide les données d'une entité avant upload
  bool _validateEntityData(String tableName, Map<String, dynamic> data) {
    switch (tableName) {
      case 'agents':
        if (data['username'] == null || data['username'].toString().isEmpty) {
          debugPrint('❌ Validation: username manquant pour agent ${data['id']}');
          return false;
        }
        if (data['shop_id'] == null || data['shop_id'] <= 0) {
          debugPrint('❌ Validation: shop_id manquant pour agent ${data['id']}');
          return false;
        }
        return true;
        
      case 'clients':
        if (data['nom'] == null || data['nom'].toString().isEmpty) {
          debugPrint('❌ Validation: nom manquant pour client ${data['id']}');
          return false;
        }
        if (data['shop_id'] == null || data['shop_id'] <= 0) {
          debugPrint('❌ Validation: shop_id manquant pour client ${data['id']}');
          return false;
        }
        return true;
      
      case 'operations':
        // Validation des champs obligatoires pour les opérations
        if (data['type'] == null) {
          debugPrint('❌ Validation: type manquant pour operation ${data['id']}');
          return false;
        }
        if (data['montant_net'] == null || data['montant_net'] <= 0) {
          debugPrint('❌ Validation: montant_net invalide pour operation ${data['id']}');
          return false;
        }
        if (data['shop_source_id'] == null || data['shop_source_id'] <= 0) {
          debugPrint('❌ Validation: shop_source_id manquant pour operation ${data['id']}');
          return false;
        }
        return true;
        
      case 'shops':
        if (data['designation'] == null || data['designation'].toString().isEmpty) {
          debugPrint('❌ Validation: designation manquant pour shop ${data['id']}');
          return false;
        }
        return true;
      
      case 'flots':
        // Validation des champs obligatoires pour les flots
        if (data['shop_source_id'] == null || data['shop_source_id'] <= 0) {
          debugPrint('❌ Validation: shop_source_id manquant pour flot ${data['id']}');
          return false;
        }
        if (data['shop_destination_id'] == null || data['shop_destination_id'] <= 0) {
          debugPrint('❌ Validation: shop_destination_id manquant pour flot ${data['id']}');
          return false;
        }
        if (data['agent_envoyeur_id'] == null || data['agent_envoyeur_id'] <= 0) {
          debugPrint('❌ Validation: agent_envoyeur_id manquant pour flot ${data['id']}');
          return false;
        }
        if (data['montant'] == null || data['montant'] <= 0) {
          debugPrint('❌ Validation: montant invalide pour flot ${data['id']}');
          return false;
        }
        return true;
        
      default:
        // Autres tables: validation minimale (ID présent)
        return data['id'] != null;
    }
  }

  /// Upload des données d'une table spécifique (version publique pour RobustSyncService)
  Future<void> uploadTableData(String tableName, String userId, [String userRole = 'admin']) async {
    return await _uploadTableData(tableName, userId, userRole);
  }
  
  /// Download des données d'une table spécifique (version publique pour RobustSyncService)
  Future<void> downloadTableData(String tableName, String userId, String userRole) async {
    return await _downloadTableData(tableName, userId, userRole);
  }
  
  /// Upload des données d'une table spécifique
  Future<void> _uploadTableData(String tableName, String userId, [String userRole = 'admin']) async {
    try {
      final lastSync = await _getLastSyncTimestamp(tableName);
      final localData = await _getLocalChanges(tableName, lastSync);
      
      if (localData.isEmpty) {
        debugPrint('📤 $tableName: Aucune donnée locale à uploader');
        return;
      }

      debugPrint('📤 $tableName: ${localData.length} éléments à uploader');
      
      // LOGS DÉTAILLÉS pour commissions
      if (tableName == 'commissions' && localData.isNotEmpty) {
        debugPrint('🔍 Détail des commissions à uploader:');
        for (var comm in localData) {
          debugPrint('   ID: ${comm['id']}, Type: ${comm['type']}, Taux: ${comm['taux']}%, isSynced: ${comm['is_synced']}');
          debugPrint('   ShopId: ${comm['shop_id']}, SourceId: ${comm['shop_source_id']}, DestId: ${comm['shop_destination_id']}');
        }
      }
      
      // VALIDATION: Vérifier les données AVANT upload
      final validatedData = <Map<String, dynamic>>[];
      final invalidData = <Map<String, dynamic>>[];
      
      for (var data in localData) {
        if (_validateEntityData(tableName, data)) {
          validatedData.add(data);
        } else {
          invalidData.add(data);
          debugPrint('⚠️ $tableName: Données invalides pour ID ${data['id']} - ignorées');
        }
      }
      
      if (invalidData.isNotEmpty) {
        debugPrint('⚠️ $tableName: ${invalidData.length} éléments invalides ignorés');
      }
      
      if (validatedData.isEmpty) {
        debugPrint('⚠️ $tableName: Aucune donnée valide à uploader');
        return;
      }
          
      final baseUrl = await _baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/$tableName/upload.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'entities': validatedData,
          'user_id': userId,
          'user_role': userRole, // Add user role parameter
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final uploaded = result['uploaded'] ?? 0;
          final updated = result['updated'] ?? 0;
          final errors = result['errors'] ?? [];
          
          debugPrint('✅ $tableName: $uploaded insérés, $updated mis à jour');
          
          // Afficher les erreurs s'il y en a
          if (errors.isNotEmpty) {
            for (var error in errors) {
              debugPrint('⚠️ Erreur $tableName ID ${error['entity_id']}: ${error['error']}');
            }
          }
          
          // Vérifier les opérations de capital initial dans la réponse
          if (tableName == 'operations' && (uploaded > 0 || updated > 0)) {
            int initialCapitalUploaded = 0;
            for (var data in localData) {
              if (data['destinataire'] == 'CAPITAL INITIAL') {
                initialCapitalUploaded++;
                debugPrint('💰 OP ${data['id']}: Opération de capital initial uploadée avec succès');
              }
            }
            if (initialCapitalUploaded > 0) {
              debugPrint('💰 $tableName: $initialCapitalUploaded opérations de capital initial uploadées');
            }
          }
          
          // Marquer les éléments comme synchronisés uniquement si pas d'erreurs
          if (uploaded > 0 || updated > 0) {
            await _markEntitiesAsSynced(tableName, validatedData);
          }
        } else {
          debugPrint('⚠️ Erreur serveur $tableName: ${result['message']}');
          throw Exception('Erreur serveur: ${result['message']}');
        }
      } else {
        debugPrint('⚠️ Erreur HTTP $tableName: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload $tableName: $e');
      throw Exception('Erreur upload $tableName: $e');
    }
  }

  /// Download des changements du serveur vers l'app
  Future<void> _downloadRemoteChanges(String userId, String userRole) async {
    // NOTE: 'operations' géré par TransferSyncService
    final tables = ['shops', 'agents', 'clients', 'taux', 'commissions', 'document_headers', 'cloture_caisse', 'flots'];
    int successCount = 0;
    int errorCount = 0;
    
    debugPrint('📥 Début du download des données distantes (${tables.length} tables)');
    
    for (String table in tables) {
      try {
        debugPrint('📥 Download $table...');
        await _downloadTableData(table, userId, userRole);
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur download $table: $e');
        errorCount++;
        // Continuer avec les autres tables
      }
    }
    
    debugPrint('📥 Download terminé: $successCount succès, $errorCount erreurs');
  }

  /// Download des données d'une table spécifique
  Future<void> _downloadTableData(String tableName, String userId, String userRole) async {
    try {
      final lastSync = await _getLastSyncTimestamp(tableName);
      
      // Pour les tables standards, utiliser le timestamp de dernière sync
      String sinceParam = lastSync != null 
          ? lastSync.toIso8601String() 
          : '2020-01-01T00:00:00.000';  // Date par défaut très ancienne
      
      final baseUrl = await _baseUrl;
      
      // Récupérer les informations de l'utilisateur connecté pour le filtrage
      final prefs = await SharedPreferences.getInstance();
      final currentShopId = prefs.getInt('current_shop_id');  // Shop de l'utilisateur connecté
      
      // Endpoint standard pour toutes les tables (sauf operations)
      final endpoint = 'changes.php';
      var uri = Uri.parse('$baseUrl/$tableName/$endpoint?since=$sinceParam');
      
      // Ajouter les paramètres de filtrage pour agents
      if (tableName == 'agents') {
        final queryParams = {
          'since': sinceParam,
          'user_id': userId,
          'user_role': userRole, // Add user role parameter
        };
        
        // Ajouter shop_id seulement pour les agents (pas pour admin)
        if (userRole != 'admin' && currentShopId != null) {
          queryParams['shop_id'] = currentShopId.toString();
        }
        
        uri = Uri.parse('$baseUrl/$tableName/$endpoint').replace(queryParameters: queryParams);
        
        if (userRole == 'admin') {
          debugPrint('👑 Mode ADMIN: téléchargement de toutes les données $tableName');
        } else {
          debugPrint('👤 Mode AGENT: filtrage $tableName par shop_id=$currentShopId');
        }
      } else if (tableName == 'operations') {
        // Pour operations, ajouter les paramètres requis
        final queryParams = {
          'since': sinceParam,
          'user_id': userId,
          'user_role': userRole,
        };
        
        if (userRole != 'admin' && currentShopId != null) {
          queryParams['shop_id'] = currentShopId.toString();
        }
        
        uri = Uri.parse('$baseUrl/$tableName/$endpoint').replace(queryParameters: queryParams);
        debugPrint('📥 Requête download operations: $uri');
      }
      
      debugPrint('📥 Requête download: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Gérer le cas où entities est null ou n'est pas une liste
          final remoteData = (result['entities'] as List?) ?? [];
          debugPrint('📥 $tableName: ${remoteData.length} éléments reçus du serveur');
          
          if (remoteData.isNotEmpty) {
            await _processRemoteChanges(tableName, remoteData, userId);
            
            // CRITIQUE: Recharger les données en mémoire après le traitement
            debugPrint('🔄 Rechargement des données $tableName en mémoire après download...');
            switch (tableName) {
              case 'shops':
                await ShopService.instance.loadShops();
                break;
              case 'agents':
                await AgentService.instance.loadAgents();
                break;
              case 'clients':
                await ClientService().loadClients();
                break;
              case 'taux':
              case 'commissions':
                await RatesService.instance.loadRatesAndCommissions();
                break;
              case 'comptes_speciaux':
                await CompteSpecialService.instance.loadTransactions();
                break;
              case 'flots':
                // Recharger les flots dans le service
                debugPrint('🚚 Rechargement des FLOTs en mémoire...');
                // Les FLOTs sont chargés par FlotService si nécessaire
                break;
              case 'document_headers':
              case 'cloture_caisse':
                // Ces données sont chargées à la demande, pas besoin de recharger
                debugPrint('ℹ️ $tableName: Chargement à la demande');
                break;
            }
            debugPrint('✅ Données $tableName rechargées en mémoire');
          }
          
          // Mettre à jour le timestamp de dernière sync pour cette table SEULEMENT
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_sync_$tableName', DateTime.now().toIso8601String());
          debugPrint('📅 Timestamp mis à jour pour $tableName');
        } else {
          debugPrint('⚠️ Erreur serveur $tableName: ${result['message']}');
          throw Exception('Erreur serveur: ${result['message']}');
        }
      } else {
        debugPrint('⚠️ Erreur HTTP $tableName: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur download $tableName: $e');
      throw Exception('Erreur download $tableName: $e');
    }
  }

  /// Traite les changements reçus du serveur
  Future<void> _processRemoteChanges(String tableName, List remoteData, String userId) async {
    int updated = 0, inserted = 0, conflicts = 0, errors = 0;
    
    debugPrint('🔄 Traitement de ${remoteData.length} éléments pour $tableName');
    
   
    // Afficher un aperçu des données pour débogage
    if (tableName == 'clients' && remoteData.isNotEmpty) {
      debugPrint('🔍 Exemple de client reçu du serveur:');
      debugPrint('   ${remoteData.first}');
    }
    
    for (int i = 0; i < remoteData.length; i++) {
      try {
        final remoteEntity = remoteData[i] as Map<String, dynamic>;
        final entityId = remoteEntity['id'];
        
        if (entityId == null) {
          debugPrint('⚠️ Élément ignoré (ID manquant) dans $tableName');
          errors++;
          continue;
        }
        
        debugPrint('🔄 Traitement élément $i/${remoteData.length}: $tableName ID $entityId');
        
        // Vérifier si l'entité existe localement
        final localEntity = await _getLocalEntity(tableName, entityId);
        
        if (localEntity == null) {
          // Nouvelle entité - insérer
          await _insertLocalEntity(tableName, remoteEntity);
          inserted++;
          debugPrint('➕ $tableName ID $entityId inséré');
        } else {
          // Entité existante - vérifier les conflits
          final conflict = await _detectConflict(localEntity, remoteEntity);
          
          if (conflict != null) {
            // Résoudre le conflit
            final resolved = await _resolveConflict(tableName, conflict, userId);
            if (resolved) {
              updated++;
            } else {
              conflicts++;
            }
          } else {
            // Pas de conflit - mettre à jour
            await _updateLocalEntity(tableName, remoteEntity);
            updated++;
            debugPrint('✏️ $tableName ID $entityId mis à jour');
          }
        }
      } catch (e) {
        debugPrint('❌ Erreur traitement entité dans $tableName: $e');
        errors++;
      }
    }
    
    debugPrint('✅ $tableName: $inserted insérés, $updated mis à jour, $conflicts conflits, $errors erreurs');
    
    // CRITIQUE: Recharger les services en mémoire après traitement
    debugPrint('🔄 Rechargement du service $tableName en mémoire après traitement...');
    switch (tableName) {
      case 'shops':
        await ShopService.instance.loadShops();
        break;
      case 'agents':
        await AgentService.instance.loadAgents();
        break;
      case 'clients':
        await ClientService().loadClients();
        break;
      case 'taux':
      case 'commissions':
        await RatesService.instance.loadRatesAndCommissions();
        break;
      case 'comptes_speciaux':
        await CompteSpecialService.instance.loadTransactions();
        break;
      case 'flots':
        // Les FLOTs sont rechargés par FlotService si nécessaire
        debugPrint('🚚 FLOTs: Chargement à la demande par FlotService');
        break;
      case 'document_headers':
      case 'cloture_caisse':
        // Ces données sont chargées à la demande, pas besoin de recharger
        debugPrint('ℹ️ $tableName: Chargement à la demande');
        break;
    }
    debugPrint('✅ Service $tableName rechargé en mémoire');
  }

  /// Détecte un conflit entre données locales et distantes
  Future<ConflictInfo?> _detectConflict(Map<String, dynamic> local, Map<String, dynamic> remote) async {
    final localModified = DateTime.tryParse(local['last_modified_at'] ?? '');
    final remoteModified = DateTime.tryParse(remote['last_modified_at'] ?? '');
    
    if (localModified == null || remoteModified == null) {
      return null; // Pas assez d'informations pour détecter un conflit
    }
    
    // Si les timestamps sont identiques, ce n'est pas un conflit (même version)
    if (localModified.isAtSameMomentAs(remoteModified)) {
      return null;
    }
    
    // Conflit si les deux ont été modifiés et les timestamps sont différents
    return ConflictInfo(
      localData: local,
      remoteData: remote,
      localModified: localModified,
      remoteModified: remoteModified,
    );
  }

  /// Résout un conflit en utilisant la stratégie "last modified wins"
  Future<bool> _resolveConflict(String tableName, ConflictInfo conflict, String userId) async {
    debugPrint('⚠️ Conflit détecté pour ${conflict.localData['id']} dans $tableName');
    debugPrint('   Local: ${conflict.localModified}');
    debugPrint('   Remote: ${conflict.remoteModified}');
    
    // Si les timestamps sont identiques, ne rien faire (même version)
    if (conflict.localModified.isAtSameMomentAs(conflict.remoteModified)) {
      debugPrint('🔄 Résolution: Versions identiques, aucune action requise');
      return false;
    }
    
    // Stratégie: Le plus récent gagne
    final useRemote = conflict.remoteModified.isAfter(conflict.localModified);
    
    if (useRemote) {
      debugPrint('🔄 Résolution: Utiliser la version distante (plus récente)');
      try {
        await _updateLocalEntity(tableName, conflict.remoteData);
        debugPrint('✅ Conflit résolu avec version distante');
        return true;
      } catch (e) {
        debugPrint('❌ Erreur lors de la mise à jour avec version distante: $e');
        return false;
      }
    } else {
      debugPrint('🔄 Résolution: Conserver la version locale (plus récente)');
      try {
        // Re-marquer pour upload lors de la prochaine sync
        await _markEntityForReupload(tableName, conflict.localData['id']);
        debugPrint('✅ Conflit résolu avec version locale (re-upload planifié)');
        return false;
      } catch (e) {
        debugPrint('❌ Erreur lors du marquage pour re-upload: $e');
        return false;
      }
    }
  }
  
  /// Gère la détection de transferts validés (Shop Source)
  /// Détecte quand un transfert EN_ATTENTE local devient VALIDEE sur le serveur
  Future<void> _handleTransfertValidation(
    Map<String, dynamic> localEntity,
    Map<String, dynamic> remoteEntity,
  ) async {
    try {
      // Vérifier si c'est un transfert
      final typeIndex = remoteEntity['type'];
      final isTransfert = typeIndex == 0 || // transfertNational
                          typeIndex == 1 || // transfertInternationalSortant
                          typeIndex == 2;   // transfertInternationalEntrant
      
      if (!isTransfert) return;
      
      // Vérifier le changement de statut
      final localStatut = localEntity['statut'] ?? 0; // 0 = enAttente
      final remoteStatut = remoteEntity['statut'] ?? 0; // 1 = validee
      
      // Détection: Local EN_ATTENTE (0) -> Remote VALIDEE (1)
      if (localStatut == 0 && remoteStatut == 1) {
        final operationId = remoteEntity['id'];
        final destinataire = remoteEntity['destinataire'] ?? 'Inconnu';
        final montant = remoteEntity['montant_net'] ?? 0.0;
        final devise = remoteEntity['devise'] ?? 'USD';
        
        debugPrint('🎉 ===== TRANSFERT VALIDÉ DÉTECTÉ ===== ');
        debugPrint('🎉 Opération ID: $operationId');
        debugPrint('🎉 Destinataire: $destinataire');
        debugPrint('🎉 Montant servi: $montant $devise');
        debugPrint('🎉 Statut: EN_ATTENTE → SERVIE');
        debugPrint('🎉 Le shop destination a validé et servi le transfert!');
        debugPrint('🎉 ================================== ');
        
        // Notifier l'utilisateur (optionnel - peut être ajouté plus tard)
        // _notifyTransfertValidated(operationId, destinataire, montant, devise);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la détection de transfert validé: $e');
    }
  }

  /// Récupère les changements locaux depuis la dernière synchronisation
  /// Utilise is_synced = false pour identifier les données non synchronisées
  Future<List<Map<String, dynamic>>> _getLocalChanges(String tableName, DateTime? since) async {
    try {
      List<Map<String, dynamic>> unsyncedData = [];
      
      switch (tableName) {
        case 'shops':
          final shops = ShopService.instance.shops;
          // Filtrer uniquement les shops non synchronisés OU tous si c'est la première sync
          unsyncedData = shops
              .where((shop) => shop.isSynced != true)
              .map((shop) => _addSyncMetadata(shop.toJson(), 'shop'))
              .toList();
          
          // Si aucun shop non synchronisé mais qu'il y a des shops, forcer l'upload du premier
          if (unsyncedData.isEmpty && shops.isNotEmpty && since == null) {
            debugPrint('🔄 Première synchronisation: envoi de tous les shops');
            unsyncedData = shops.map((shop) => _addSyncMetadata(shop.toJson(), 'shop')).toList();
          }
          break;
          
        case 'agents':
          final agents = AgentService.instance.agents;
          final totalAgents = agents.length;
          debugPrint('👥 AGENTS: Total agents en mémoire: $totalAgents');
          
          // Afficher les shops disponibles pour le débogage
          final shops = ShopService.instance.shops;
          debugPrint('🏪 SHOPS: Total shops en mémoire: ${shops.length}');
          for (var shop in shops) {
            debugPrint('   - Shop ID: ${shop.id}, Designation: "${shop.designation}"');
          }
          
          // Filtrer les agents non synchronisés
          unsyncedData = agents
              .map((agent) {
                final json = _addSyncMetadata(agent.toJson(), 'agent');
                // Si is_synced n'est pas true, inclure cet agent
                if (json['is_synced'] != true) {
                  debugPrint('🔄 Traitement agent ${agent.username} (ID ${json['id']}, Shop ID: ${agent.shopId})');
                  // ✅ Résoudre shop_designation depuis le shopId de l'agent
                  final agentShop = shops.where((s) => s.id == agent.shopId).firstOrNull;
                  if (agentShop != null) {
                    json['shop_designation'] = agentShop.designation;
                    debugPrint('✅ Agent ${agent.username}: shopId=${agent.shopId} → shop_designation "${agentShop.designation}"');
                  } else {
                    debugPrint('⚠️ Agent ${agent.username}: shop ID ${agent.shopId} NON trouvé!');
                  }
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          
          debugPrint('👥 AGENTS: ${unsyncedData.length}/${totalAgents} non synchronisés (TOUS shops confondus)');
          
          // Si aucun agent non synchronisé mais qu'il y a des agents, forcer l'upload du premier
          if (unsyncedData.isEmpty && agents.isNotEmpty && since == null) {
            debugPrint('🔄 Première synchronisation: envoi de tous les agents');
            unsyncedData = agents.map((agent) {
              final json = _addSyncMetadata(agent.toJson(), 'agent');
              // Résoudre shop_designation
              final agentShop = shops.where((s) => s.id == agent.shopId).firstOrNull;
              if (agentShop != null) {
                json['shop_designation'] = agentShop.designation;
                debugPrint('🔄 Agent ${agent.username} (ID ${json['id']}): shopId=${agent.shopId} → shop_designation "${agentShop.designation}"');
              }
              return json;
            }).toList();
          }
          break;
          
        case 'clients':
          final clients = ClientService().clients;
          // Pour l'instant, envoyer tous les clients jusqu'à ce que le modèle soit mis à jour
          unsyncedData = clients
              .map((client) {
                final json = _addSyncMetadata(client.toJson(), 'client');
                if (json['is_synced'] != true) {
                  // ✅ Résoudre shop_designation depuis le shopId du client
                  final shops = ShopService.instance.shops;
                  
                  final clientShop = shops.where((s) => s.id == client.shopId).firstOrNull;
                  if (clientShop != null) {
                    json['shop_designation'] = clientShop.designation;
                  } else {
                    // Shop non trouvé - le serveur résoudra via shop_id
                    // Pas critique car le serveur a la table shops complète
                    debugPrint('ℹ️ Client ${client.nom}: shop_designation sera résolu côté serveur (shopId: ${client.shopId})');
                  }
                  
                  // Note: agent_username sera résolu côté serveur depuis agent_id
                  
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          break;

        case 'operations':
          // Récupérer toutes les opérations depuis LocalDB
          final allOperations = await LocalDB.instance.getAllOperations();
          debugPrint('📦 OPERATIONS: Total opérations en mémoire: ${allOperations.length}');
          
          // Filtrer uniquement les opérations non synchronisées
          unsyncedData = allOperations
              .where((op) => op.isSynced != true)
              .map((op) {
                final json = _addSyncMetadata(op.toJson(), 'operation');
                debugPrint('📤 Opération ID ${op.id} à synchroniser: ${op.type.name} - ${op.montantNet} ${op.devise}');
                return json;
              })
              .toList();
          
          debugPrint('📤 OPERATIONS: ${unsyncedData.length}/${allOperations.length} non synchronisées');
          
          // Si aucune opération non synchronisée mais qu'il y a des opérations, forcer l'upload en première sync
          if (unsyncedData.isEmpty && allOperations.isNotEmpty && since == null) {
            debugPrint('🔄 Première synchronisation: envoi de toutes les opérations');
            unsyncedData = allOperations.map((op) => _addSyncMetadata(op.toJson(), 'operation')).toList();
          }
          break;

        case 'taux':
          final taux = RatesService.instance.taux;
          // Pour l'instant, envoyer tous les taux jusqu'à ce que le modèle soit mis à jour
          unsyncedData = taux
              .map((t) {
                final json = _addSyncMetadata(t.toJson(), 'taux');
                if (json['is_synced'] != true) {
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          break;
          
        case 'commissions':
          final commissions = RatesService.instance.commissions;
          debugPrint('📊 COMMISSIONS: Total en mémoire: ${commissions.length}');
          
          // Filtrer uniquement les commissions non synchronisées
          unsyncedData = commissions
              .map((c) {
                final json = _addSyncMetadata(c.toJson(), 'commission');
                if (json['is_synced'] != true) {
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          
          debugPrint('📤 COMMISSIONS: ${unsyncedData.length}/${commissions.length} non synchronisées');
          break;
          
        case 'comptes_speciaux':
          final transactions = CompteSpecialService.instance.transactions;
          debugPrint('💰 COMPTES_SPECIAUX: Total en mémoire: ${transactions.length}');
          
          // Filtrer uniquement les transactions non synchronisées
          unsyncedData = transactions
              .map((t) {
                final json = _addSyncMetadata(t.toJson(), 'compte_special');
                if (json['is_synced'] != true) {
                  debugPrint('📤 Compte spécial ID ${t.id} à synchroniser: ${t.type.name} - ${t.typeTransaction.name}');
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
          
          debugPrint('📤 COMPTES_SPECIAUX: ${unsyncedData.length}/${transactions.length} non synchronisés');
          break;
          
        case 'document_headers':
          // Les headers sont chargés depuis la clé active
          final prefs = await LocalDB.instance.database;
          const activeKey = 'document_header_active';
          unsyncedData = [];
          
          final headerData = prefs.getString(activeKey);
          if (headerData != null) {
            final json = jsonDecode(headerData);
            if (json['is_synced'] != true) {
              unsyncedData.add(_addSyncMetadata(json, 'document_header'));
            }
          }
          break;
          
        case 'cloture_caisse':
          // Les clôtures sont chargées à la demande depuis LocalDB
          final prefs = await LocalDB.instance.database;
          final clotureKeys = prefs.getKeys().where((key) => key.startsWith('cloture_caisse_'));
          unsyncedData = [];
          for (var key in clotureKeys) {
            final clotureData = prefs.getString(key);
            if (clotureData != null) {
              final json = jsonDecode(clotureData);
              if (json['is_synced'] != true) {
                unsyncedData.add(_addSyncMetadata(json, 'cloture_caisse'));
              }
            }
          }
          break;
        
        case 'flots':
          // Récupérer tous les flots depuis LocalDB
          final allFlots = await LocalDB.instance.getAllFlots();
          debugPrint('🚚 FLOTS: Total flots en mémoire: ${allFlots.length}');
          
          // Filtrer uniquement les flots non synchronisés
          unsyncedData = allFlots
              .where((flot) => flot.isSynced != true)
              .map((flot) {
                final json = _addSyncMetadata(flot.toJson(), 'flot');
                debugPrint('📤 Flot ID ${flot.id} à synchroniser: ${flot.shopSourceDesignation} → ${flot.shopDestinationDesignation} - ${flot.montant} ${flot.devise}');
                return json;
              })
              .toList();
          
          debugPrint('📤 FLOTS: ${unsyncedData.length}/${allFlots.length} non synchronisés');
          
          // Si aucun flot non synchronisé mais qu'il y a des flots, forcer l'upload en première sync
          if (unsyncedData.isEmpty && allFlots.isNotEmpty && since == null) {
            debugPrint('🔄 Première synchronisation: envoi de tous les flots');
            unsyncedData = allFlots.map((flot) => _addSyncMetadata(flot.toJson(), 'flot')).toList();
          }
          break;
          
        default:
          debugPrint('⚠️ Table inconnue pour récupération des changements: $tableName');
          return [];
      }
      
      if (unsyncedData.isNotEmpty) {
        debugPrint('📤 $tableName: ${unsyncedData.length} enregistrement(s) non synchronisé(s) trouvé(s)');
      }
      
      return unsyncedData;
    } catch (e) {
      debugPrint('❌ Erreur récupération changements $tableName: $e');
      return [];
    }
  }

  /// Ajoute les métadonnées de synchronisation
  Map<String, dynamic> _addSyncMetadata(Map<String, dynamic> data, String entityType) {
    final now = DateTime.now();
    return {
      ...data,
      'last_modified_at': data['last_modified_at'] ?? now.toString().split('.')[0].replaceFirst('T', ' '),
      'last_modified_by': data['last_modified_by'] ?? 'local_user',
      'entity_type': entityType,
      'sync_version': 1,
      'is_synced': data['is_synced'] ?? false, // Par défaut non synchronisé
      'synced_at': data['synced_at'] ?? now.toIso8601String(), // Use client's timestamp for timezone consistency
    };
  }

  /// Récupère une entité locale par ID
  Future<Map<String, dynamic>?> _getLocalEntity(String tableName, dynamic entityId) async {
    try {
      final id = entityId is int ? entityId : int.tryParse(entityId.toString()) ?? 0;
      final codeOps = entityId is String ? entityId : entityId.toString();
      if (id <= 0 && (codeOps.isEmpty || codeOps == '0')) return null;
      
      switch (tableName) {
        case 'shops':
          final shop = ShopService.instance.getShopById(id);
          return shop?.toJson();
        
        case 'agents':
          final agent = AgentService.instance.getAgentById(id);
          return agent?.toJson();
          
        case 'clients':
          final client = ClientService().getClientById(id);
          return client?.toJson();         
        case 'taux':
          final taux = RatesService.instance.getTauxById(id);
          return taux?.toJson();
          
        case 'commissions':
          final commission = RatesService.instance.getCommissionById(id);
          return commission?.toJson();
          
        default:
          return null;
      }
    } catch (e) {
      debugPrint('❌ Erreur récupération entité locale $tableName/$entityId: $e');
      return null;
    }
  }

  /// Insère une nouvelle entité locale
  Future<void> _insertLocalEntity(String tableName, Map<String, dynamic> data) async {
    try {
      // Vérifier si l'entité existe déjà pour éviter les doublons
      final entityId = data['id'];
      if (entityId != null) {
        final existing = await _getLocalEntity(tableName, entityId);
        if (existing != null) {
          debugPrint('⚠️ Doublon ignoré: $tableName ID $entityId existe déjà');
          return; // Équivalent de INSERT IGNORE
        }
      }
      
      switch (tableName) {
        case 'shops':
          // Vérifier aussi par designation (clé naturelle)
          final shops = ShopService.instance.shops;
          final designation = data['designation'] ?? '';
          final existingShop = shops.where((s) => s.designation == designation).firstOrNull;
          if (existingShop != null && designation.isNotEmpty) {
            debugPrint('⚠️ Doublon ignoré: shop designation "$designation" existe déjà');
            return;
          }
          
          // Créer le shop directement avec l'ID du serveur
          final shop = ShopModel.fromJson(data);
          await LocalDB.instance.saveShop(shop);
          
          // Recharger la liste des shops en mémoire
          await ShopService.instance.loadShops();
          
          debugPrint('✅ Shop ID ${shop.id} inséré avec ID serveur');
          break;
          
        case 'agents':
          // Vérifier aussi par username (clé naturelle)
          final agents = AgentService.instance.agents;
          final username = data['username'] ?? '';
          final existingAgent = agents.where((a) => a.username == username).firstOrNull;
          if (existingAgent != null && username.isNotEmpty) {
            debugPrint('⚠️ Doublon ignoré: agent username "$username" existe déjà');
            return;
          }
          
          // CRITIQUE: Résoudre shop_id depuis shop_designation
          int? shopId;
          final shopDesignation = data['shop_designation'];
          if (shopDesignation != null && shopDesignation.isNotEmpty) {
            final shops = ShopService.instance.shops;
            final shop = shops.where((s) => s.designation == shopDesignation).firstOrNull;
            if (shop != null) {
              shopId = shop.id!;
              debugPrint('🔍 Agent: shop_designation "$shopDesignation" → shop_id $shopId');
            } else {
              debugPrint('⚠️ Shop "$shopDesignation" NON trouvé pour agent "$username"!');
              debugPrint('❌ Agent ignoré car shop obligatoire');
              return; // Ne PAS créer l'agent sans shop valide
            }
          } else {
            debugPrint('⚠️ shop_designation manquant pour agent "$username"!');
            debugPrint('❌ Agent ignoré car shop obligatoire');
            return;
          }
          
          // IMPORTANT: Créer l'agent avec l'ID MySQL et le shop résolu
          // GARDER le shop_designation qui vient du serveur
          final agentData = {
            ...data,
            'shop_id': shopId,
            'shop_designation': shopDesignation,  // ✅ Préserver le nom du shop
          };
          final agent = AgentModel.fromJson(agentData);
          debugPrint('📥 Insertion agent depuis MySQL: ID=${agent.id}, username=${agent.username}, shopId=$shopId, shopDesignation=$shopDesignation');
          
          // Sauvegarder directement avec l'ID MySQL
          await LocalDB.instance.saveAgent(agent);
          debugPrint('✅ Agent sauvegardé avec ID MySQL: ${agent.id}');
          
          // Recharger les agents en mémoire
          await AgentService.instance.loadAgents();
          break;
          
        case 'clients':
          // Vérifier aussi par téléphone (clé naturelle)
          final clients = ClientService().clients;
          final telephone = data['telephone'] ?? '';
          final existingClient = clients.where((c) => c.telephone == telephone).firstOrNull;
          if (existingClient != null && telephone.isNotEmpty) {
            debugPrint('⚠️ Doublon ignoré: client téléphone "$telephone" existe déjà');
            return;
          }
          
          // Résoudre shop_id depuis shop_designation
          int shopId = 1;
          final shopDesignation = data['shop_designation'];
          if (shopDesignation != null && shopDesignation.isNotEmpty) {
            final shops = ShopService.instance.shops;
            final shop = shops.where((s) => s.designation == shopDesignation).firstOrNull;
            if (shop != null) {
              shopId = shop.id!;
              debugPrint('🔍 Client: shop_designation "$shopDesignation" → shop_id $shopId');
            } else {
              debugPrint('⚠️ Shop "$shopDesignation" non trouvé, utilise shop_id par défaut');
            }
          }
          
          // Résoudre agent_id depuis agent_username
          int agentId = 1;
          final agentUsername = data['agent_username'];
          if (agentUsername != null && agentUsername.isNotEmpty) {
            final agents = AgentService.instance.agents;
            final agent = agents.where((a) => a.username == agentUsername).firstOrNull;
            if (agent != null) {
              agentId = agent.id!;
              debugPrint('🔍 Client: agent_username "$agentUsername" → agent_id $agentId');
            } else {
              debugPrint('⚠️ Agent "$agentUsername" non trouvé, utilise agent_id par défaut');
            }
          }
          
          // IMPORTANT: Créer le client avec l'ID MySQL et les IDs résolus
          final clientData = {
            ...data,
            'shop_id': shopId,
            'agent_id': agentId,
          };
          final client = ClientModel.fromJson(clientData);
          debugPrint('🔍 Client download - ID: ${client.id}, shopId: $shopId, agentId: $agentId, nom: ${data['nom']}');
          
          // Sauvegarder directement avec l'ID MySQL
          await LocalDB.instance.saveClient(client);
          debugPrint('✅ Client sauvegardé avec ID MySQL: ${client.id}');
          
          // Recharger les clients en mémoire
          await ClientService().loadClients();
          break;
        case 'taux':
          final taux = TauxModel.fromJson(data);
          // Vérifier doublon par devise_source + devise_cible + type
          final tauxList = RatesService.instance.taux;
          final existingTaux = tauxList.where((t) => 
            t.deviseSource == taux.deviseSource && 
            t.deviseCible == taux.deviseCible && 
            t.type == taux.type
          ).firstOrNull;
          if (existingTaux != null) {
            debugPrint('⚠️ Doublon ignoré: taux ${taux.deviseSource}->${taux.deviseCible} (${taux.type}) existe déjà');
            return;
          }
          
          await RatesService.instance.createTaux(
            devise: taux.deviseCible,
            taux: taux.taux,
            type: taux.type,
          );
          break;
          
        case 'commissions':
          final commission = CommissionModel.fromJson(data);
          // Vérifier doublon par ID d'abord
          final commissions = RatesService.instance.commissions;
          final existingById = commissions.where((c) => c.id == commission.id).firstOrNull;
          if (existingById != null) {
            debugPrint('⚠️ Doublon ignoré: commission ID ${commission.id} existe déjà');
            return;
          }
          
          // Vérifier doublon par type + shopId + shopSourceId + shopDestinationId
          final existingByRoute = commissions.where((c) => 
            c.type == commission.type &&
            c.shopId == commission.shopId &&
            c.shopSourceId == commission.shopSourceId &&
            c.shopDestinationId == commission.shopDestinationId
          ).firstOrNull;
          if (existingByRoute != null) {
            debugPrint('⚠️ Doublon ignoré: commission similaire existe déjà (route identique)');
            return;
          }
          
          // Sauvegarder DIRECTEMENT avec l'ID du serveur
          await LocalDB.instance.saveCommission(commission);
          await RatesService.instance.loadRatesAndCommissions();
          break;
          
        case 'comptes_speciaux':
          final transaction = CompteSpecialModel.fromJson(data);
          // Vérifier doublon par ID
          final prefs = await SharedPreferences.getInstance();
          final existingKey = 'compte_special_${transaction.id}';
          if (prefs.containsKey(existingKey)) {
            debugPrint('⚠️ Doublon ignoré: compte spécial ID ${transaction.id} existe déjà');
            return;
          }
          
          // Sauvegarder la transaction
          await prefs.setString(existingKey, jsonEncode(transaction.toJson()));
          debugPrint('✅ Compte spécial ID ${transaction.id} sauvegardé: ${transaction.type.name} - \$${transaction.montant}');
          
          // Recharger en mémoire
          await CompteSpecialService.instance.loadTransactions();
          break;
          
        case 'document_headers':
          final header = DocumentHeaderModel.fromJson(data);
          final prefs = await LocalDB.instance.database;
          
          // IMPORTANT: Un seul header actif à la fois
          // Toujours sauvegarder dans la clé 'document_header_active' pour cohérence
          const activeKey = 'document_header_active';
          
          // Supprimer tous les anciens headers (nettoyage)
          final allKeys = prefs.getKeys();
          final oldHeaderKeys = allKeys.where((key) => key.startsWith('document_header_') && key != activeKey);
          for (var key in oldHeaderKeys) {
            await prefs.remove(key);
            debugPrint('🗑️ Ancien header supprimé: $key');
          }
          
          // Sauvegarder le header dans la clé active
          await prefs.setString(activeKey, jsonEncode(header.toJson()));
          debugPrint('✅ Document header ID ${header.id} sauvegardé dans $activeKey');
          
          // Notifier DocumentHeaderService du changement
          // Le service rechargera automatiquement lors du prochain accès
          break;
          
        case 'cloture_caisse':
          final cloture = ClotureCaisseModel.fromJson(data);
          final prefs = await LocalDB.instance.database;
          // Clé unique: shop_id + date_cloture
          final clotureKey = 'cloture_caisse_${cloture.shopId}_${cloture.dateCloture.toIso8601String().split('T')[0]}';
          
          // Vérifier si clôture existe déjà pour ce shop et cette date
          if (prefs.containsKey(clotureKey)) {
            debugPrint('⚠️ Doublon ignoré: clôture pour shop ${cloture.shopId} du ${cloture.dateCloture.toIso8601String().split('T')[0]} existe déjà');
            return;
          }
          
          await prefs.setString(clotureKey, jsonEncode(cloture.toJson()));
          debugPrint('✅ Clôture caisse shop ${cloture.shopId} du ${cloture.dateCloture.toIso8601String().split('T')[0]} sauvegardée');
          break;
        
        case 'flots':
          final flot = flot_model.FlotModel.fromJson(data);
          
          // Vérifier si le flot existe déjà
          final existingFlot = await LocalDB.instance.getFlotById(flot.id!);
          if (existingFlot != null) {
            debugPrint('⚠️ Doublon ignoré: flot ID ${flot.id} existe déjà');
            return;
          }
          
          // Sauvegarder le flot
          await LocalDB.instance.saveFlot(flot);
          debugPrint('✅ Flot ID ${flot.id} sauvegardé: ${flot.shopSourceDesignation} → ${flot.shopDestinationDesignation} - ${flot.montant} ${flot.devise}');
          break;
          
        default:
          debugPrint('⚠️ Table inconnue pour insertion: $tableName');
      }
      
      debugPrint('✅ Insertion locale réussie: $tableName');
    } catch (e) {
      debugPrint('❌ Erreur insertion locale $tableName: $e');
    }
  }

  /// Crée une entrée de journal pour une opération synchronisée
  Future<void> _createJournalEntryForOperation(OperationModel operation) async {
    try {
      String libelle = '';
      TypeMouvement type = TypeMouvement.entree;
      double montant = operation.montantNet;
      
      switch (operation.type) {
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          libelle = 'Transfert ${operation.type.name} - ${operation.destinataire} (Total reçu)';
          montant = operation.montantBrut; // TOTAL = montant à servir + commission
          type = TypeMouvement.entree; // ENTRÉE en caisse
          break;
          
        case OperationType.transfertInternationalEntrant:
          libelle = 'Réception ${operation.type.name} - ${operation.destinataire}';
          montant = operation.montantNet;
          type = TypeMouvement.entree;
          break;
          
        case OperationType.depot:
          libelle = 'Dépôt - ${operation.destinataire ?? "Partenaire"}';
          montant = operation.montantNet;
          type = TypeMouvement.entree; // ENTRÉE en caisse
          break;
          
        case OperationType.retrait:
          libelle = 'Retrait - ${operation.destinataire ?? "Partenaire"}';
          montant = operation.montantNet;
          type = TypeMouvement.sortie; // SORTIE de caisse
          break;
          
        case OperationType.virement:
          libelle = 'Virement - ${operation.destinataire}';
          montant = operation.montantNet;
          type = TypeMouvement.entree; // Neutre pour le shop
          break;
          
        default:
          libelle = 'Opération - ${operation.type.name}';
          montant = operation.montantNet;
          type = TypeMouvement.entree;
      }
      
      // Créer l'entrée journal
      final journalEntry = JournalCaisseModel(
        shopId: operation.shopSourceId ?? 0,
        agentId: operation.agentId,
        libelle: libelle,
        montant: montant,
        type: type,
        mode: operation.modePaiement,
        dateAction: operation.dateOp,
        operationId: operation.id,
        notes: operation.commission > 0 
            ? 'Dont commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}'
            : null,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: operation.lastModifiedBy,
      );
      
      await LocalDB.instance.saveJournalEntry(journalEntry);
      debugPrint('📋 Journal: ${type.name.toUpperCase()} de $montant ${operation.devise} - $libelle');
    } catch (e) {
      debugPrint('⚠️ Erreur création entrée journal: $e');
      // Ne pas bloquer la sync pour une erreur de journal
    }
  }

  /// Met à jour une entité locale
  Future<void> _updateLocalEntity(String tableName, Map<String, dynamic> data) async {
    try {
      switch (tableName) {
        case 'shops':
          final shop = ShopModel.fromJson(data);
          await ShopService.instance.updateShop(shop);
          break;
          
        case 'agents':
          final agent = AgentModel.fromJson(data);
          await AgentService.instance.updateAgent(agent);
          break;
          
        case 'clients':
          final client = ClientModel.fromJson(data);
          await ClientService().updateClient(client);
          break;
          
        case 'taux':
          final taux = TauxModel.fromJson(data);
          await RatesService.instance.updateTaux(taux);
          break;
          
        case 'commissions':
          final commission = CommissionModel.fromJson(data);
          
          // Sauvegarder DIRECTEMENT sans passer par updateCommission
          await LocalDB.instance.saveCommission(commission);
          await RatesService.instance.loadRatesAndCommissions();
          break;
          
        case 'comptes_speciaux':
          final transaction = CompteSpecialModel.fromJson(data);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('compte_special_${transaction.id}', jsonEncode(transaction.toJson()));
          debugPrint('✅ Compte spécial ID ${transaction.id} mis à jour');
          
          // Recharger en mémoire
          await CompteSpecialService.instance.loadTransactions();
          break;
          
        case 'document_headers':
          final header = DocumentHeaderModel.fromJson(data);
          final prefs = await LocalDB.instance.database;
          
          // IMPORTANT: Un seul header actif
          // Toujours utiliser 'document_header_active' pour cohérence
          const activeKey = 'document_header_active';
          await prefs.setString(activeKey, jsonEncode(header.toJson()));
          debugPrint('✅ Document header ID ${header.id} mis à jour dans $activeKey');
          
          // Notifier DocumentHeaderService du changement si nécessaire
          break;
          
        case 'cloture_caisse':
          final cloture = ClotureCaisseModel.fromJson(data);
          final prefs = await LocalDB.instance.database;
          final clotureKey = 'cloture_caisse_${cloture.shopId}_${cloture.dateCloture.toIso8601String().split('T')[0]}';
          await prefs.setString(clotureKey, jsonEncode(cloture.toJson()));
          debugPrint('✅ Clôture caisse shop ${cloture.shopId} mis à jour');
          break;
        
        case 'flots':
          final flot = flot_model.FlotModel.fromJson(data);
          await LocalDB.instance.saveFlot(flot);
          debugPrint('✅ Flot ID ${flot.id} mis à jour');
          break;
          
        default:
          debugPrint('⚠️ Table inconnue pour mise à jour: $tableName');
      }
      
      debugPrint('✅ Mise à jour locale réussie: $tableName ID ${data['id']}');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour locale $tableName ID ${data['id']}: $e');
    }
  }

  /// Marque les entités comme synchronisées après un upload réussi
  Future<void> _markEntitiesAsSynced(String tableName, List<Map<String, dynamic>> entities) async {
    try {
      final now = DateTime.now();
      
      for (var entity in entities) {
        final entityId = entity['id'];
        if (entityId == null) continue;
        
        switch (tableName) {
          case 'shops':
            final shop = ShopService.instance.getShopById(entityId);
            if (shop != null) {
              final updatedShop = shop.copyWith(
                isSynced: true,
                syncedAt: now,
              );
              await ShopService.instance.updateShop(updatedShop);
            }
            break;
            
          case 'agents':
            // Charger l'agent depuis SharedPreferences
            final prefs = await LocalDB.instance.database;
            final agentData = prefs.getString('agent_$entityId');
            if (agentData != null) {
              final agentJson = jsonDecode(agentData);
              agentJson['is_synced'] = true;
              agentJson['synced_at'] = now.toIso8601String();
              await prefs.setString('agent_$entityId', jsonEncode(agentJson));
            }
            // Recharger les agents en mémoire
            await AgentService.instance.loadAgents();
            break;
            
          case 'clients':
            final prefs = await LocalDB.instance.database;
            final clientData = prefs.getString('client_$entityId');
            if (clientData != null) {
              final clientJson = jsonDecode(clientData);
              clientJson['is_synced'] = true;
              clientJson['synced_at'] = now.toIso8601String();
              await prefs.setString('client_$entityId', jsonEncode(clientJson));
            }
            // Recharger les clients en mémoire
            await ClientService().loadClients();
            break;
            
          case 'taux':
            final prefs = await LocalDB.instance.database;
            final tauxData = prefs.getString('taux_$entityId');
            if (tauxData != null) {
              final tauxJson = jsonDecode(tauxData);
              tauxJson['is_synced'] = true;
              tauxJson['synced_at'] = now.toIso8601String();
              await prefs.setString('taux_$entityId', jsonEncode(tauxJson));
            }
            // Recharger les taux en mémoire
            await RatesService.instance.loadRatesAndCommissions();
            break;
            
          case 'commissions':
            final prefs = await LocalDB.instance.database;
            final commissionData = prefs.getString('commission_$entityId');
            if (commissionData != null) {
              final commissionJson = jsonDecode(commissionData);
              commissionJson['is_synced'] = true;
              commissionJson['synced_at'] = now.toIso8601String();
              await prefs.setString('commission_$entityId', jsonEncode(commissionJson));
            }
            // Recharger les commissions en mémoire
            await RatesService.instance.loadRatesAndCommissions();
            break;
            
          case 'comptes_speciaux':
            final prefs = await LocalDB.instance.database;
            final transactionData = prefs.getString('compte_special_$entityId');
            if (transactionData != null) {
              final transactionJson = jsonDecode(transactionData);
              transactionJson['is_synced'] = true;
              transactionJson['synced_at'] = now.toIso8601String();
              await prefs.setString('compte_special_$entityId', jsonEncode(transactionJson));
            }
            // Recharger les transactions en mémoire
            await CompteSpecialService.instance.loadTransactions();
            break;
            
          case 'document_headers':
            final prefs = await LocalDB.instance.database;
            const activeKey = 'document_header_active';
            final headerData = prefs.getString(activeKey);
            if (headerData != null) {
              final headerJson = jsonDecode(headerData);
              headerJson['is_synced'] = true;
              headerJson['synced_at'] = now.toIso8601String();
              await prefs.setString(activeKey, jsonEncode(headerJson));
            }
            break;
            
          case 'cloture_caisse':
            final prefs = await LocalDB.instance.database;
            // Pour les clôtures, l'ID est composé de shop_id + date
            final clotureKeys = prefs.getKeys().where((key) => key.contains('cloture_caisse_') && key.contains('_$entityId'));
            for (var key in clotureKeys) {
              final clotureData = prefs.getString(key);
              if (clotureData != null) {
                final clotureJson = jsonDecode(clotureData);
                clotureJson['is_synced'] = true;
                clotureJson['synced_at'] = now.toIso8601String();
                await prefs.setString(key, jsonEncode(clotureJson));
              }
            }
            break;
          
          case 'flots':
            final prefs = await LocalDB.instance.database;
            final flotData = prefs.getString('flot_$entityId');
            if (flotData != null) {
              final flotJson = jsonDecode(flotData);
              flotJson['is_synced'] = true;
              flotJson['synced_at'] = now.toIso8601String();
              await prefs.setString('flot_$entityId', jsonEncode(flotJson));
            }
            break;
        }
      }
      
      debugPrint('✅ $tableName: ${entities.length} entités marquées comme synchronisées');
    } catch (e) {
      debugPrint('❌ Erreur lors du marquage des entités comme synchronisées: $e');
    }
  }

  /// Marque une entité pour re-upload
  Future<void> _markEntityForReupload(String tableName, dynamic entityId) async {
    // Les entités en mémoire seront re-uploadées lors de la prochaine sync
    debugPrint('🔄 $tableName: Entité $entityId marquée pour re-upload');
  }

  /// Vérifie la connectivité
  Future<bool> _checkConnectivity() async {
    try {
      final baseUrl = await _baseUrl;
      
      // Vérifier d'abord la connectivité réseau
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('❌ Aucune connexion réseau détectée');
        return false;
      }
      
      debugPrint('🌐 Test de connexion au serveur: $baseUrl/ping (essai avec .php)');
      
      // Test de ping vers le serveur avec timeout plus court
      // Essayer d'abord avec .php puis sans (en cas de rewrite rules)
      final pingUrls = [
        '$baseUrl/ping.php',  // URL directe avec extension
        '$baseUrl/ping',      // URL sans extension (si .htaccess)
      ];
      
      http.Response? response;
      String usedUrl = '';
      
      for (String url in pingUrls) {
        try {
          usedUrl = url;
          response = await http.get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));
          
          // Si la requête réussit, sortir de la boucle
          if (response.statusCode == 200) {
            break;
          }
        } catch (e) {
          debugPrint('⚠️ Échec de la requête vers $url: $e');
          // Continuer avec l'URL suivante
        }
      }
      
      if (response == null) {
        throw Exception('Impossible de joindre le serveur ping');
      }
      
      final isConnected = response.statusCode == 200;
      if (isConnected) {
        debugPrint('✅ Serveur accessible (code ${response.statusCode})');
        final data = jsonDecode(response.body);
        debugPrint('📡 Réponse serveur: ${data['message'] ?? 'OK'}');
      } else {
        debugPrint('⚠️ Serveur inaccessible via $usedUrl (code ${response.statusCode}): ${response.body}');
        
        // Fournir des instructions de dépannage
        if (usedUrl.contains('localhost')) {
          debugPrint('💡 Conseil: Vérifiez que Laragon est démarré avec Apache et MySQL');
          debugPrint('💡 Conseil: Vérifiez que le chemin $usedUrl est accessible dans votre navigateur');
        }
      }
      
      return isConnected;
    } catch (e, stackTrace) {
      debugPrint('⚠️ Serveur non disponible: ${e.toString()}');
      
      // Fournir des instructions de dépannage spécifiques
      if (e.toString().contains('XMLHttpRequest error')) {
        debugPrint('💡 Conseil: Problème CORS ou serveur non démarré');
        debugPrint('💡 Solution: Démarrez Laragon (Apache + MySQL)');
        debugPrint('💡 Solution: Vérifiez que le port 80 est disponible');
        debugPrint('💡 Solution: Vérifiez que l\'URL du serveur est correcte dans les paramètres');
        debugPrint('💡 Solution: Vérifiez que les en-têtes CORS sont correctement configurés');
        debugPrint('💡 Solution: Essayez d\'accéder à \$baseUrl/ping.php directement dans votre navigateur');
      } else if (e.toString().contains('SocketException')) {
        debugPrint('💡 Conseil: Impossible de se connecter au serveur');
        debugPrint('💡 Solution: Vérifiez que le serveur est démarré');
        debugPrint('💡 Solution: Vérifiez les paramètres réseau/firewall');
        debugPrint('💡 Solution: Vérifiez que localhost résout correctement');
      } else if (e is TimeoutException) {
        debugPrint('💡 Conseil: La requête a expiré');
        debugPrint('💡 Solution: Vérifiez votre connexion Internet');
        debugPrint('💡 Solution: Vérifiez que le serveur répond dans les temps');
      }
      
      // Afficher la stack trace en mode debug
      if (kDebugMode) {
        debugPrint('🔍 Stack trace: $stackTrace');
      }
      
      return false;
    }
  }

  /// Récupère le timestamp de dernière synchronisation
  /// Récupère le timestamp de dernière synchronisation pour une table
  Future<DateTime?> _getLastSyncTimestamp(String tableName) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString('last_sync_$tableName');
      
    return timestamp != null ? DateTime.tryParse(timestamp) : null;
  }

  /// Met à jour le timestamp de dernière synchronisation
  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    
    // NOTE: 'operations' timestamp géré par TransferSyncService
    final tables = ['shops', 'users', 'agents', 'clients', 'journal_caisse', 'taux', 'commissions', 'document_headers', 'cloture_caisse'];
    for (String table in tables) {
      await prefs.setString('last_sync_$table', now);
    }
    
    await prefs.setString('last_sync_global', now);
  }

  /// Met à jour le statut de synchronisation
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// Test de connexion au serveur de synchronisation
  Future<bool> testConnection() async {
    return await _checkConnectivity();
  }

  /// Récupère le timestamp de dernière synchronisation pour une table
  Future<DateTime?> getLastSyncTimestamp(String tableName) async {
    return await _getLastSyncTimestamp(tableName);
  }

  /// Nettoie les ressources
  void dispose() {
    _autoSyncTimer?.cancel();
    _flotsOpsAutoSyncTimer?.cancel(); // Arrêter aussi le timer flots/ops
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
  
  /// Réinitialise le statut de synchronisation pour forcer une resynchronisation complète
  Future<void> resetSyncStatus() async {
    debugPrint('🔄 Réinitialisation du statut de synchronisation...');
    
    final prefs = await SharedPreferences.getInstance();
    // NOTE: 'operations' timestamp géré par TransferSyncService
    final tables = ['shops', 'users', 'agents', 'clients', 'journal_caisse', 'taux', 'commissions', 'document_headers', 'cloture_caisse'];
    
    for (String table in tables) {
      await prefs.remove('last_sync_$table');
    }
    await prefs.remove('last_sync_global');
    
    // Réinitialiser is_synced pour tous les shops
    final shops = ShopService.instance.shops;
    for (var shop in shops) {
      final updatedShop = shop.copyWith(isSynced: false);
      await ShopService.instance.updateShop(updatedShop);
    }
    
    debugPrint('✅ Statut de synchronisation réinitialisé pour ${tables.length} tables');
  }
  
  /// Démarre la synchronisation automatique périodique (toutes les 2 minutes)
  void startAutoSync() {
    stopAutoSync(); // Arrêter tout timer existant
    
    debugPrint('⏰ Démarrage de la synchronisation automatique (intervalle: ${_autoSyncInterval.inSeconds}s)');
    debugPrint('🔍 État: isAutoSyncEnabled=$_isAutoSyncEnabled, isOnline=$_isOnline, isSyncing=$_isSyncing');
    
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) async {
      debugPrint('⏰ [✓] Timer déclenché - Vérification des conditions...');
      debugPrint('   ➢ isAutoSyncEnabled: $_isAutoSyncEnabled');
      debugPrint('   ➢ isSyncing: $_isSyncing');
      debugPrint('   ➢ isOnline: $_isOnline');
      
      if (_isAutoSyncEnabled && !_isSyncing) {
        debugPrint('🔄 [🕒 ${DateTime.now().toIso8601String()}] Synchronisation automatique - OPERATIONS, FLOTS, CLÔTURES & COMMISSIONS');
        
        int successCount = 0;
        int errorCount = 0;
        
        // 1. Synchroniser les opérations (transferts)
        try {
          final transferSyncService = TransferSyncService();
          await transferSyncService.syncTransfers();
          debugPrint('✅ Opérations synchronisées');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur sync opérations: $e');
          errorCount++;
          // Continuer avec les autres sync
        }
        
        // 2. Upload des flots non synchronisés
        try {
          debugPrint('📤 Upload des flots...');
          await _uploadTableData('flots', 'auto_sync');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur upload flots: $e');
          errorCount++;
        }
        
        // 3. Download des nouveaux flots depuis le serveur
        try {
          debugPrint('📥 Download des flots...');
          await _downloadTableData('flots', 'auto_sync', 'admin');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur download flots: $e');
          errorCount++;
        }
        
        // 4. Upload des clôtures de caisse non synchronisées
        try {
          debugPrint('📤 Upload des clôtures de caisse...');
          await _uploadTableData('cloture_caisse', 'auto_sync');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur upload clôtures: $e');
          errorCount++;
        }
        
        // 5. Download des nouvelles clôtures depuis le serveur
        try {
          debugPrint('📥 Download des clôtures de caisse...');
          await _downloadTableData('cloture_caisse', 'auto_sync', 'admin');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur download clôtures: $e');
          errorCount++;
        }
        
        // 6. Upload des commissions non synchronisées
        try {
          debugPrint('📤 Upload des commissions...');
          await _uploadTableData('commissions', 'auto_sync');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur upload commissions: $e');
          errorCount++;
        }
        
        // 7. Download des nouvelles commissions depuis le serveur
        try {
          debugPrint('📥 Download des commissions...');
          await _downloadTableData('commissions', 'auto_sync', 'admin');
          successCount++;
        } catch (e) {
          debugPrint('⚠️ Erreur download commissions: $e');
          errorCount++;
        }
        
        _lastSyncTime = DateTime.now();
        debugPrint('✅ Synchronisation automatique terminée: $successCount réussies, $errorCount échouées');
      } else {
        debugPrint('⏸️ Synchronisation automatique ignorée (conditions non remplies)');
      }
    });
    
    debugPrint('✅ Timer de synchronisation automatique démarré');
  }
  
  /// Arrête la synchronisation automatique
  void stopAutoSync() {
    if (_autoSyncTimer != null) {
      debugPrint('⏸️ Arrêt de la synchronisation automatique');
      _autoSyncTimer?.cancel();
      _autoSyncTimer = null;
    }
  }
  
  /// ========== SYNCHRONISATION SPÉCIALE FLOTS & OPÉRATIONS ==========
  /// Démarre la synchronisation automatique UNIQUEMENT pour les FLOTS et OPÉRATIONS
  /// Intervalle: toutes les 2 minutes
  /// Plus légère que startAutoSync() qui synchronise TOUT
  void startFlotsOpsAutoSync() {
    stopFlotsOpsAutoSync(); // Arrêter tout timer existant
    
    debugPrint('🚀⏰ Démarrage synchronisation auto FLOTS & OPERATIONS (intervalle: ${_autoSyncInterval.inSeconds}s)');
    debugPrint('🔍 État: isAutoSyncEnabled=$_isAutoSyncEnabled, isOnline=$_isOnline, isSyncing=$_isSyncing');
    
    _flotsOpsAutoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) async {
      debugPrint('⏰ [FLOTS/OPS] Timer déclenché...');
      
      if (_isAutoSyncEnabled && !_isSyncing && _isOnline) {
        debugPrint('🔄 [🕒 ${DateTime.now().toIso8601String()}] Sync auto FLOTS & OPERATIONS');
        
        await syncFlotsAndOperations();
        
        _lastFlotsOpsSyncTime = DateTime.now();
      } else {
        debugPrint('⏸️ Sync FLOTS/OPS ignorée (conditions non remplies)');
      }
    });
    
    debugPrint('✅ Timer synchronisation FLOTS & OPERATIONS démarré');
  }
  
  /// Arrête la synchronisation automatique des flots et opérations
  void stopFlotsOpsAutoSync() {
    if (_flotsOpsAutoSyncTimer != null) {
      debugPrint('⏸️ Arrêt synchronisation auto FLOTS & OPERATIONS');
      _flotsOpsAutoSyncTimer?.cancel();
      _flotsOpsAutoSyncTimer = null;
    }
  }
  
  /// Synchronise UNIQUEMENT les FLOTS et OPÉRATIONS (méthode spécialisée)
  /// Utile pour une sync rapide et ciblée toutes les 2 minutes
  Future<void> syncFlotsAndOperations() async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours, ignoré');
      return;
    }
    
    _isSyncing = true;
    int successCount = 0;
    int errorCount = 0;
    
    try {
      debugPrint('🚀 === SYNC FLOTS & OPERATIONS ===');
      
      // 1. Synchroniser les OPÉRATIONS (via TransferSyncService)
      try {
        debugPrint('📤📥 Sync OPERATIONS...');
        final transferSyncService = TransferSyncService();
        await transferSyncService.syncTransfers();
        debugPrint('✅ Opérations synchronisées');
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur sync opérations: $e');
        errorCount++;
      }
      
      // 2. Upload des FLOTS locaux non synchronisés
      try {
        debugPrint('📤 Upload FLOTS...');
        await _uploadTableData('flots', 'auto_sync_flots_ops');
        debugPrint('✅ Flots uploadés');
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur upload flots: $e');
        errorCount++;
      }
      
      // 3. Download des FLOTS depuis le serveur
      try {
        debugPrint('📥 Download FLOTS...');
        await _downloadTableData('flots', 'auto_sync_flots_ops', 'admin');
        debugPrint('✅ Flots téléchargés');
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur download flots: $e');
        errorCount++;
      }
      
      debugPrint('✅ === SYNC FLOTS & OPERATIONS TERMINÉE: $successCount OK, $errorCount erreurs ===');
      
    } catch (e) {
      debugPrint('❌ Erreur globale sync flots/operations: $e');
    } finally {
      _isSyncing = false;
    }
  }
  /// ========== FIN SYNCHRONISATION SPÉCIALE FLOTS & OPÉRATIONS ==========
  
  /// Synchronise uniquement les opérations (transferts, dépôts, retraits)
  /// DEPRECATED: Utiliser TransferSyncService.syncTransfers() à la place
  @Deprecated('Utiliser TransferSyncService.syncTransfers() pour synchroniser les opérations')
  Future<bool> syncOperations() async {
    debugPrint('⚠️ syncOperations() est obsolète - utilisez TransferSyncService.syncTransfers()');
    // Rediriger vers TransferSyncService
    try {
      final transferSyncService = TransferSyncService();
      await transferSyncService.syncTransfers();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur sync opérations via TransferSyncService: $e');
      return false;
    }
  }
  
  /// Obtient le temps depuis la dernière synchronisation
  Duration? getTimeSinceLastSync() {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }
  
  /// Obtient le temps restant avant la prochaine synchronisation
  Duration? getTimeUntilNextSync() {
    if (_lastSyncTime == null) return null;
    final elapsed = DateTime.now().difference(_lastSyncTime!);
    final remaining = _autoSyncInterval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// Obtient le nombre d'opérations en attente de synchronisation
  int get pendingSyncCount => _pendingSyncCount;
  
  /// Obtient le statut online/offline
  bool get isOnline => _isOnline;
  
  /// Ajoute une opération à la file d'attente (mode offline)
  Future<void> queueOperation(Map<String, dynamic> operation) async {
    _pendingOperations.add(operation);
    _pendingSyncCount = _pendingOperations.length;
    
    // Sauvegarder dans shared_preferences pour persistance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_operations', jsonEncode(_pendingOperations));
    
    debugPrint('📋 Opération mise en file d\'attente (total: $_pendingSyncCount)');
  }
  
  /// Synchronise les données en attente (appelé lors du retour en ligne)
  Future<void> _syncPendingData() async {
    if (_pendingOperations.isEmpty) {
      debugPrint('✅ Aucune donnée en attente à synchroniser');
      return;
    }
    
    debugPrint('🔄 Synchronisation de ${_pendingOperations.length} opérations en attente...');
    
    int synced = 0;
    final List<Map<String, dynamic>> failedOperations = [];
    
    for (final operation in List.from(_pendingOperations)) {
      try {
        // Uploader l'opération
        final response = await http.post(
          Uri.parse('$_baseUrl/operations/upload.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'entities': [operation],
            'user_id': operation['lastModifiedBy'] ?? 'offline_user',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(_syncTimeout);
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            synced++;
            _pendingOperations.remove(operation);
          } else {
            failedOperations.add(operation);
          }
        } else {
          failedOperations.add(operation);
        }
      } catch (e) {
        debugPrint('❌ Erreur sync opération: $e');
        failedOperations.add(operation);
      }
    }
    
    // Mettre à jour le compteur
    _pendingSyncCount = _pendingOperations.length;
    
    // Sauvegarder les opérations non synchronisées
    final prefs = await SharedPreferences.getInstance();
    if (_pendingOperations.isEmpty) {
      await prefs.remove('pending_operations');
    } else {
      await prefs.setString('pending_operations', jsonEncode(_pendingOperations));
    }
    
    debugPrint('✅ Synchronisation terminée: $synced réussies, ${failedOperations.length} échouées');
    
    if (synced > 0) {
      // Synchroniser le reste des données
      await syncAll();
    }
  }
  
  /// Force le téléchargement complet de toutes les opérations (ignore synced_at)
  /// DEPRECATED: Utiliser TransferSyncService.syncTransfers() à la place
  @Deprecated('Utiliser TransferSyncService.syncTransfers() pour télécharger les opérations')
  Future<void> forceFullOperationsDownload({String? userId}) async {
    debugPrint('⚠️ forceFullOperationsDownload() est obsolète - utilisez TransferSyncService.syncTransfers()');
    // Rediriger vers TransferSyncService
    try {
      final transferSyncService = TransferSyncService();
      await transferSyncService.syncTransfers();
      debugPrint('✅ Téléchargement complet via TransferSyncService terminé');
    } catch (e) {
      debugPrint('❌ Erreur téléchargement via TransferSyncService: $e');
      rethrow;
    }
  }
}

/// Statut de la synchronisation
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline, // Mode hors ligne
}

/// Résultat d'une synchronisation
class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? details;

  SyncResult({
    required this.success,
    required this.message,
    this.details,
  });
}

/// Information sur un conflit
class ConflictInfo {
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;

  ConflictInfo({
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
  });
}
