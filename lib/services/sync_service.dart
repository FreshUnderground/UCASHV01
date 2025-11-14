import 'dart:convert';
import 'dart:async';
// import 'dart:io'; // Unused
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
import 'local_db.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';
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
  static Duration get _autoSyncInterval => AppConfig.autoSyncInterval;
  DateTime? _lastSyncTime;
  
  // File d'attente pour les données en attente de synchronisation (mode offline)
  final List<Map<String, dynamic>> _pendingOperations = [];
  int _pendingSyncCount = 0;

  /// Initialise le service de synchronisation
  Future<void> initialize() async {
    debugPrint('🔄 Initialisation du service de synchronisation...');
    
    // Charger les opérations en attente
    await _loadPendingOperations();
    
    // Écouter les changements de connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Vérifier la connectivité initiale
    final connectivityResult = await Connectivity().checkConnectivity();
    _onConnectivityChanged(connectivityResult);
    
    // Démarrer l'auto-sync si la connexion est disponible
    if (_isAutoSyncEnabled) {
      startAutoSync();
      debugPrint('⏰ Synchronisation automatique activée (intervalle: ${_autoSyncInterval.inSeconds}s)');
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
    
    final userIdToUse = userId ?? 'unknown';
    debugPrint('🚀 === DÉBUT SYNCHRONISATION BIDIRECTIONNELLE (User: $userIdToUse) ===');
    
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
        await _downloadTableData('shops', userIdToUse);
      } catch (e) {
        debugPrint('❌ Erreur download shops: $e');
      }
      
      // Phase 2: Upload des entités dépendantes (avec IDs serveur)
      debugPrint('📤 PHASE 2: Upload Entités Dépendantes → Serveur');
      final dependentTables = ['agents', 'clients', 'operations', 'taux', 'commissions'];
      for (String table in dependentTables) {
        try {
          await _uploadTableData(table, userIdToUse);
        } catch (e) {
          debugPrint('❌ Erreur upload $table: $e');
        }
      }
      
      // Phase 3: Download des autres entités
      debugPrint('📥 PHASE 3: Download Autres Entités ← Serveur');
      for (String table in dependentTables) {
        try {
          await _downloadTableData(table, userIdToUse);
        } catch (e) {
          debugPrint('❌ Erreur download $table: $e');
        }
      }
      
      // Marquer la dernière synchronisation
      debugPrint('💾 Mise à jour du timestamp de synchronisation...');
      await _updateLastSyncTimestamp();
      
      debugPrint('✅ === SYNCHRONISATION TERMINÉE AVEC SUCCÈS ===');
      _updateStatus(SyncStatus.success);
      
      return SyncResult(success: true, message: 'Synchronisation réussie');
      
    } catch (e) {
      final errorMessage = e.toString();
      debugPrint('❌ Erreur de synchronisation: $errorMessage');
      
      // Fournir des instructions de dépannage spécifiques
      if (errorMessage.contains('XMLHttpRequest error') || 
          errorMessage.contains('SocketException') || 
          errorMessage.contains('Aucune connexion Internet')) {
        debugPrint('💡 Conseil: Vérifiez que Laragon est démarré avec Apache et MySQL');
        debugPrint('💡 Conseil: Vérifiez que le serveur est accessible à l\'URL configurée');
        debugPrint('💡 Conseil: Vérifiez votre connexion Internet et les paramètres du pare-feu');
      }
      
      _updateStatus(SyncStatus.error);
      return SyncResult(success: false, message: errorMessage);
    } finally {
      _isSyncing = false;
      debugPrint('🏁 Fin de la synchronisation');
    }
  }

  /// Upload des changements locaux vers le serveur
  Future<void> _uploadLocalChanges(String userId) async {
    final tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
    int successCount = 0;
    int errorCount = 0;
    
    debugPrint('📤 Début de l\'upload des données locales (${tables.length} tables)');
    
    // DIAGNOSTIC: Vérifier que des agents existent avant de synchroniser les opérations
    if (tables.contains('operations')) {
      final agents = AgentService.instance.agents;
      if (agents.isEmpty) {
        debugPrint('⚠️⚠️⚠️ ATTENTION: Aucun agent disponible localement!');
        debugPrint('🚫 Les opérations ne pourront pas être synchronisées car agent_username sera vide.');
        debugPrint('💡 SOLUTION 1: Créez un agent dans MySQL via:');
        debugPrint('   http://localhost/UCASHV01/server/database/create_agent.html');
        debugPrint('💡 SOLUTION 2: Synchronisez d\'abord pour télécharger les agents depuis MySQL');
        debugPrint('💡 SOLUTION 3: Créez un agent depuis l\'interface Admin Flutter');
      } else {
        debugPrint('✅ ${agents.length} agent(s) disponible(s) pour résolution');
      }
    }
    
    for (String table in tables) {
      try {
        debugPrint('📤 Upload $table...');
        await _uploadTableData(table, userId);
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur upload $table: $e');
        errorCount++;
        // Continuer avec les autres tables
      }
    }
    
    debugPrint('📤 Upload terminé: $successCount succès, $errorCount erreurs');
  }

  /// Upload des données d'une table spécifique
  Future<void> _uploadTableData(String tableName, String userId) async {
    try {
      final lastSync = await _getLastSyncTimestamp(tableName);
      final localData = await _getLocalChanges(tableName, lastSync);
      
      if (localData.isEmpty) {
        debugPrint('📤 $tableName: Aucune donnée locale à uploader');
        return;
      }

      debugPrint('📤 $tableName: ${localData.length} éléments à uploader');
      
      final baseUrl = await _baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/$tableName/upload.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'entities': localData,
          'user_id': userId,
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
          
          // Marquer les éléments comme synchronisés uniquement si pas d'erreurs
          if (uploaded > 0 || updated > 0) {
            await _markEntitiesAsSynced(tableName, localData);
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
  Future<void> _downloadRemoteChanges(String userId) async {
    final tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
    int successCount = 0;
    int errorCount = 0;
    
    debugPrint('📥 Début du download des données distantes (${tables.length} tables)');
    
    for (String table in tables) {
      try {
        debugPrint('📥 Download $table...');
        await _downloadTableData(table, userId);
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
  Future<void> _downloadTableData(String tableName, String userId) async {
    try {
      final lastSync = await _getLastSyncTimestamp(tableName);
      
      // IMPORTANT: Pour la première sync, utiliser une date très ancienne pour tout télécharger
      final sinceParam = lastSync != null 
          ? lastSync.toIso8601String() 
          : '2020-01-01T00:00:00.000';  // Date par défaut très ancienne
      
      final baseUrl = await _baseUrl;
      // Remove user_id parameter since we want all data to sync regardless of user
      final uri = Uri.parse('$baseUrl/$tableName/changes.php?since=$sinceParam');
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
          final remoteData = result['entities'] as List;
          debugPrint('📥 $tableName: ${remoteData.length} éléments reçus du serveur');
          
          if (remoteData.isNotEmpty) {
            await _processRemoteChanges(tableName, remoteData, userId);
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
      debugPrint('❌ Erreur download $tableName: $e');
      throw Exception('Erreur download $tableName: $e');
    }
  }

  /// Traite les changements reçus du serveur
  Future<void> _processRemoteChanges(String tableName, List remoteData, String userId) async {
    int updated = 0, inserted = 0, conflicts = 0, errors = 0;
    
    debugPrint('🔄 Traitement de ${remoteData.length} éléments pour $tableName');
    
    // CRITIQUE: Avant de traiter les opérations, recharger agents/clients/shops en mémoire
    if (tableName == 'operations') {
      debugPrint('🔄 Rechargement des entités de référence avant traitement des opérations...');
      await ShopService.instance.loadShops();
      await AgentService.instance.loadAgents();
      await ClientService().loadClients();
      
      final shops = ShopService.instance.shops;
      final agents = AgentService.instance.agents;
      final clients = ClientService().clients;
      
      debugPrint('✅ Entités en mémoire: ${shops.length} shops, ${agents.length} agents, ${clients.length} clients');
      
      if (agents.isEmpty) {
        debugPrint('❌❌❌ ERREUR CRITIQUE: Aucun agent en mémoire!');
        debugPrint('🚨 Les opérations ne pourront pas être traitées correctement.');
        debugPrint('💡 Synchronisez d\'abord les agents avant les opérations.');
      }
    }
    
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
          
          // DÉTECTION SPÉCIALE: Transfert validé (pour Shop Source)
          if (tableName == 'operations') {
            await _handleTransfertValidation(localEntity, remoteEntity);
          }
          
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
          // Filtrer les agents non synchronisés
          unsyncedData = agents
              .map((agent) {
                final json = _addSyncMetadata(agent.toJson(), 'agent');
                // Si is_synced n'est pas true, inclure cet agent
                if (json['is_synced'] != true) {
                  // ✅ Résoudre shop_designation depuis le shopId de l'agent
                  final shops = ShopService.instance.shops;
                  final agentShop = shops.where((s) => s.id == agent.shopId).firstOrNull;
                  if (agentShop != null) {
                    json['shop_designation'] = agentShop.designation;
                    debugPrint('🔄 Agent ${agent.username} (ID ${json['id']}): shopId=${agent.shopId} → shop_designation "${agentShop.designation}"');
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
          
          // Si aucun agent non synchronisé mais qu'il y a des agents, forcer l'upload du premier
          if (unsyncedData.isEmpty && agents.isNotEmpty && since == null) {
            debugPrint('🔄 Première synchronisation: envoi de tous les agents');
            unsyncedData = agents.map((agent) {
              final json = _addSyncMetadata(agent.toJson(), 'agent');
              // Résoudre shop_designation
              final shops = ShopService.instance.shops;
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
                    debugPrint('⚠️ Client ${client.nom}: shop ID ${client.shopId} NON trouvé!');
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
          final operations = OperationService().operations;
          // Pour l'instant, envoyer toutes les opérations jusqu'à ce que le modèle soit mis à jour
          unsyncedData = operations
              .map((op) {
                final json = _addSyncMetadata(op.toJson(), 'operation');
                if (json['is_synced'] != true) {
                  // CRITIQUE: Logger le statut de l'opération AVANT upload
                  debugPrint('🚨 UPLOAD OP ${json['id']}: type=${op.type.name}, statut=${op.statut.name} (index=${json['statut']})');
                  
                  // Logger les données AVANT résolution
                  debugPrint('🔍 [OP ID ${json['id']}] AVANT résolution: agent_id=${json['agent_id']}, shop_source_id=${json['shop_source_id']}, client_id=${json['client_id']}');
                  
                  // Utiliser shop_designation et agent_username au lieu des IDs
                  final shops = ShopService.instance.shops;
                  final agents = AgentService.instance.agents;
                  final clients = ClientService().clients;
                  
                  debugPrint('   Total agents disponibles: ${agents.length}');
                  debugPrint('   Total shops disponibles: ${shops.length}');
                  debugPrint('   Total clients disponibles: ${clients.length}');
                  
                  // Résoudre shop_source_designation depuis shop_source_id
                  if (json['shop_source_id'] != null) {
                    final shopSource = shops.where((s) => s.id == json['shop_source_id']).firstOrNull;
                    if (shopSource != null) {
                      json['shop_source_designation'] = shopSource.designation;
                      debugPrint('✅ Shop source résolu: ID ${json['shop_source_id']} -> "${shopSource.designation}"');
                    } else {
                      debugPrint('⚠️ Shop source NON trouvé pour ID ${json['shop_source_id']}');
                    }
                  }
                  
                  // Résoudre shop_destination_designation depuis shop_destination_id
                  if (json['shop_destination_id'] != null) {
                    final shopDest = shops.where((s) => s.id == json['shop_destination_id']).firstOrNull;
                    if (shopDest != null) {
                      json['shop_destination_designation'] = shopDest.designation;
                      debugPrint('✅ Shop destination résolu: ID ${json['shop_destination_id']} -> "${shopDest.designation}"');
                    } else {
                      debugPrint('⚠️ Shop destination NON trouvé pour ID ${json['shop_destination_id']}');
                    }
                  }
                  
                  // Résoudre agent_username depuis agent_id OU lastModifiedBy
                  if (json['agent_id'] != null) {
                    final agent = agents.where((a) => a.id == json['agent_id']).firstOrNull;
                    if (agent != null) {
                      json['agent_username'] = agent.username;
                      debugPrint('✅ Agent résolu: ID ${json['agent_id']} -> username "${agent.username}"');
                    } else {
                      // FALLBACK: Extraire username depuis lastModifiedBy
                      final lastModifiedBy = json['last_modified_by'];
                      if (lastModifiedBy != null && lastModifiedBy.toString().startsWith('agent_')) {
                        final username = lastModifiedBy.toString().replaceFirst('agent_', '');
                        json['agent_username'] = username;
                        debugPrint('✅ Agent résolu depuis lastModifiedBy: username "$username"');
                      } else {
                        debugPrint('⚠️ Agent NON trouvé pour ID ${json['agent_id']} (total agents: ${agents.length})');
                        // Logger tous les agents disponibles
                        debugPrint('   Agents disponibles: ${agents.map((a) => "ID=${a.id} username=${a.username}").join(", ")}');
                        
                        // Si aucun agent n'est disponible localement, envoyer une clé vide pour déclencher l'erreur côté serveur
                        if (agents.isEmpty) {
                          debugPrint('❌ CRITIQUE: Aucun agent disponible localement!');
                          debugPrint('   📥 Solution: Synchronisez d\'abord pour télécharger les agents depuis le serveur');
                          debugPrint('   📥 OU créez un agent dans MySQL via: http://localhost/UCASHV01/server/database/create_agent.html');
                        }
                        json['agent_username'] = ''; // Envoyer vide pour déclencher erreur explicite côté serveur
                      }
                    }
                  } else {
                    debugPrint('⚠️ Opération sans agent_id!');
                    json['agent_username'] = ''; // Envoyer vide pour déclencher erreur
                  }
                  
                  // Résoudre client_nom depuis client_id
                  if (json['client_id'] != null) {
                    final client = clients.where((c) => c.id == json['client_id']).firstOrNull;
                    if (client != null) {
                      json['client_nom'] = client.nom;
                      debugPrint('✅ Client résolu: ID ${json['client_id']} -> nom "${client.nom}"');
                    } else {
                      debugPrint('⚠️ Client NON trouvé pour ID ${json['client_id']}');
                    }
                  }
                  
                  return json;
                }
                return null;
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();
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
          // Pour l'instant, envoyer toutes les commissions jusqu'à ce que le modèle soit mis à jour
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
      'synced_at': data['synced_at'],
    };
  }

  /// Récupère une entité locale par ID
  Future<Map<String, dynamic>?> _getLocalEntity(String tableName, dynamic entityId) async {
    try {
      final id = entityId is int ? entityId : int.tryParse(entityId.toString()) ?? 0;
      if (id <= 0) return null;
      
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
          
        case 'operations':
          final operation = await LocalDB.instance.getOperationById(id);
          return operation?.toJson();
          
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
          final agentData = {
            ...data,
            'shop_id': shopId,
          };
          final agent = AgentModel.fromJson(agentData);
          debugPrint('📥 Insertion agent depuis MySQL: ID=${agent.id}, username=${agent.username}, shopId=$shopId');
          
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
          
        case 'operations':
          // Vérifier doublon par montant + agent + date + type (doublon logique)
          final operations = OperationService().operations;
          final montantBrut = data['montant_brut'] is String 
              ? double.tryParse(data['montant_brut']) ?? 0.0 
              : (data['montant_brut'] ?? 0.0).toDouble();
          final typeIndex = data['type'] is String ? int.tryParse(data['type']) ?? 0 : data['type'] ?? 0;
          final agentUsername = data['agent_username'];
          final dateOp = data['date_op'] != null ? DateTime.parse(data['date_op']) : data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now();
          
          // Vérifier si une opération similaire existe (même jour, même montant, même type)
          final existingOp = operations.where((o) {
            final sameDate = o.dateOp.year == dateOp.year && 
                             o.dateOp.month == dateOp.month && 
                             o.dateOp.day == dateOp.day;
            final sameMontant = (o.montantBrut - montantBrut).abs() < 0.01; // Tolérance de 1 centime
            final sameType = o.type.index == typeIndex;
            return sameDate && sameMontant && sameType;
          }).firstOrNull;
          
          if (existingOp != null) {
            debugPrint('⚠️ Doublon ignoré: opération montant $montantBrut du ${dateOp.toIso8601String().split('T')[0]} existe déjà');
            return;
          }
          
          // Résoudre les IDs depuis les clés naturelles
          final shops = ShopService.instance.shops;
          final agents = AgentService.instance.agents;
          
          // Résoudre shop_source_id depuis shop_source_designation
          int? shopSourceId;
          final shopSourceDesignation = data['shop_source_designation'];
          if (shopSourceDesignation != null && shopSourceDesignation.isNotEmpty) {
            final shop = shops.where((s) => s.designation == shopSourceDesignation).firstOrNull;
            if (shop != null) {
              shopSourceId = shop.id!;
              debugPrint('🔍 Operation: shop_source_designation "$shopSourceDesignation" → shop_source_id $shopSourceId');
            } else {
              debugPrint('⚠️ Shop source "$shopSourceDesignation" non trouvé');
            }
          }
          
          // Résoudre shop_destination_id depuis shop_destination_designation
          int? shopDestinationId;
          final shopDestDesignation = data['shop_destination_designation'];
          if (shopDestDesignation != null && shopDestDesignation.isNotEmpty) {
            final shop = shops.where((s) => s.designation == shopDestDesignation).firstOrNull;
            if (shop != null) {
              shopDestinationId = shop.id!;
              debugPrint('🔍 Operation: shop_destination_designation "$shopDestDesignation" → shop_destination_id $shopDestinationId');
            } else {
              debugPrint('⚠️ Shop destination "$shopDestDesignation" non trouvé');
            }
          }
          
          // Résoudre agent_id depuis agent_username
          int agentId = 1;
          // agentUsername déjà défini ligne 827 pour vérification doublon
          if (agentUsername != null && agentUsername.isNotEmpty) {
            final agent = agents.where((a) => a.username == agentUsername).firstOrNull;
            if (agent != null) {
              agentId = agent.id!;
              debugPrint('🔍 Operation: agent_username "$agentUsername" → agent_id $agentId');
            } else {
              debugPrint('⚠️ Agent "$agentUsername" non trouvé');
            }
          }
          
          // Créer l'opération avec les IDs résolus
          final operationData = {
            ...data,
            'shop_source_id': shopSourceId,
            'shop_destination_id': shopDestinationId,
            'agent_id': agentId,
          };
          
          final operation = OperationModel.fromJson(operationData);
          
          // CRITIQUE: Logger le statut pour débogage
          debugPrint('🚨 STATUT DEBUG OP ${operation.id}:');
          debugPrint('   type: ${operation.type.name}');
          debugPrint('   statut depuis JSON: ${operationData['statut']}');
          debugPrint('   statut après parsing: ${operation.statut.name} (index=${operation.statut.index})');
          debugPrint('   destinataire: ${operation.destinataire}');
          
          // IMPORTANT: Utiliser saveOperation DIRECT pour éviter la logique métier
          // (calcul commission, mise à jour soldes, journal)
          // Car les opérations reçues du serveur sont déjà complètes
          // preserveTimestamp=true pour conserver le timestamp du serveur
          await LocalDB.instance.saveOperation(operation, preserveTimestamp: true);
          debugPrint('📥 Opération ${operation.id} insérée depuis serveur (statut: ${operation.statut.name})');
          
          // IMPORTANT: Créer l'entrée de journal pour l'opération synchronisée
          await _createJournalEntryForOperation(operation);
          
          // Recharger les opérations dans le service pour affichage SANS FILTRE
          // Ne pas filtrer par agent pour voir TOUTES les opérations synchronisées
          await OperationService().loadOperations();  // Pas de shopId ni agentId
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
          // Vérifier doublon par type
          final commissions = RatesService.instance.commissions;
          final existingCommission = commissions.where((c) => c.type == commission.type).firstOrNull;
          if (existingCommission != null) {
            debugPrint('⚠️ Doublon ignoré: commission type "${commission.type}" existe déjà');
            return;
          }
          
          await RatesService.instance.createCommission(
            type: commission.type,
            taux: commission.taux,
            description: commission.description,
          );
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
          libelle = 'Dépôt - ${operation.destinataire ?? "Client"}';
          montant = operation.montantNet;
          type = TypeMouvement.entree; // ENTRÉE en caisse
          break;
          
        case OperationType.retrait:
          libelle = 'Retrait - ${operation.destinataire ?? "Client"}';
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
          
        case 'operations':
          final operation = OperationModel.fromJson(data);
          await OperationService().updateOperation(operation);
          break;
          
        case 'taux':
          final taux = TauxModel.fromJson(data);
          await RatesService.instance.updateTaux(taux);
          break;
          
        case 'commissions':
          final commission = CommissionModel.fromJson(data);
          await RatesService.instance.updateCommission(commission);
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
            
          case 'operations':
            final prefs = await LocalDB.instance.database;
            final operationData = prefs.getString('operation_$entityId');
            if (operationData != null) {
              final operationJson = jsonDecode(operationData);
              operationJson['is_synced'] = true;
              operationJson['synced_at'] = now.toIso8601String();
              await prefs.setString('operation_$entityId', jsonEncode(operationJson));
            }
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
    
    // Pour les opérations: si première sync, retourner une date très ancienne
    // pour télécharger TOUTES les opérations (dépôts initiaux, etc.)
    if (tableName == 'operations' && timestamp == null) {
      debugPrint('🔄 Première sync operations - téléchargement de TOUTES les opérations');
      return DateTime(2020, 1, 1); // Date très ancienne pour tout télécharger
    }
    
    return timestamp != null ? DateTime.tryParse(timestamp) : null;
  }

  /// Met à jour le timestamp de dernière synchronisation
  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    
    final tables = ['shops', 'users', 'agents', 'clients', 'operations', 'journal_caisse', 'taux', 'commissions'];
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
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
  
  /// Réinitialise le statut de synchronisation pour forcer une resynchronisation complète
  Future<void> resetSyncStatus() async {
    debugPrint('🔄 Réinitialisation du statut de synchronisation...');
    
    final prefs = await SharedPreferences.getInstance();
    final tables = ['shops', 'users', 'agents', 'clients', 'operations', 'journal_caisse', 'taux', 'commissions'];
    
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
  
  /// Démarre la synchronisation automatique périodique (toutes les 30 secondes)
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
        debugPrint('🔄 [🕒 ${DateTime.now().toIso8601String()}] Synchronisation automatique - TOUTES LES DONNÉES');
        
        // Utiliser la MÊME fonction que la synchronisation manuelle
        final result = await syncAll(userId: 'auto_sync');
        
        if (result.success) {
          _lastSyncTime = DateTime.now();
          debugPrint('✅ Synchronisation automatique terminée avec succès');
        } else {
          debugPrint('⚠️ Synchronisation automatique échouée: ${result.message}');
        }
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
  
  /// Synchronise uniquement les opérations (transferts, dépôts, retraits)
  Future<bool> syncOperations() async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours...');
      return false;
    }
    
    try {
      // Vérifier la connectivité
      if (!await _checkConnectivity()) {
        debugPrint('⚠️ Mode offline - synchronisation reportée');
        return false;
      }
      
      _isSyncing = true;
      debugPrint('📤 Upload des opérations locales...');
      // Use 'auto_sync' as userId for automatic operations
      await _uploadTableData('operations', 'auto_sync');
      
      debugPrint('📥 Download des opérations distantes...');
      // Use 'auto_sync' as userId for automatic operations
      await _downloadTableData('operations', 'auto_sync');
      
      // Mettre à jour le timestamp de sync pour les opérations
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_operations', DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      debugPrint('❌ Erreur sync opérations: $e');
      return false;
    } finally {
      _isSyncing = false;
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
  
  /// Charge les opérations en attente depuis shared_preferences
  Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString('pending_operations');
    
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final List<dynamic> pending = jsonDecode(pendingJson);
        _pendingOperations.clear();
        _pendingOperations.addAll(pending.cast<Map<String, dynamic>>());
        _pendingSyncCount = _pendingOperations.length;
        
        debugPrint('📋 ${_pendingSyncCount} opérations en attente chargées');
      } catch (e) {
        debugPrint('❌ Erreur chargement opérations en attente: $e');
      }
    }
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
