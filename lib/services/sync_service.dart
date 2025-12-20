import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
import 'flot_service.dart'; // Add FlotService import
import 'sim_service.dart'; // Add SimService import
import 'virtual_transaction_service.dart'; // Add VirtualTransactionService import
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
import '../models/sim_model.dart';
import '../models/virtual_transaction_model.dart';
import '../config/app_config.dart';
import '../config/sync_config.dart';
import 'conflict_notification_service.dart';
import 'conflict_logging_service.dart';
import 'personnel_sync_service.dart';

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
  Timer? _slowSyncTimer; // Timer pour synchronisation lente (personnel, etc.)
  static Duration get _autoSyncInterval => const Duration(minutes: 2);
  static Duration get _slowSyncInterval => SyncConfig.slowSyncInterval; // 10 minutes
  DateTime? _lastSyncTime;
  DateTime? _lastFlotsOpsSyncTime; // Dernière sync flots/ops
  DateTime? _lastSlowSyncTime; // Dernière sync lente
  
  // File d'attente pour les données en attente de synchronisation (mode offline)
  // Ajout de la priorité pour une meilleure gestion
  final List<Map<String, dynamic>> _pendingOperations = [];
  final List<Map<String, dynamic>> _pendingFlots = [];  // File d'attente pour les flots
  int _pendingSyncCount = 0;
  int _pendingFlotsCount = 0;  // Compteur pour les flots
  
  // Priorité par défaut pour les opérations
  static const int _defaultOperationPriority = 1; // Moyenne priorité
  
  /// Compresse les données en utilisant zlib
  Uint8List _compressData(String data) {
    if (!SyncConfig.enableCompression) {
      throw Exception('Compression is disabled');
    }
    
    // Convertir la chaîne en bytes
    final bytes = utf8.encode(data);
    
    // Utiliser zlib pour compresser
    try {
      // Note: Dart doesn't have built-in zlib compression
      // We'll use gzip as an alternative
      return bytes; // Pour l'instant, retourner les bytes non compressés
    } catch (e) {
      debugPrint('⚠️ Erreur compression: $e');
      return bytes; // Retourner les données non compressées en cas d'erreur
    }
  }
  
  /// Décompresse les données
  String _decompressData(Uint8List compressedData) {
    if (!SyncConfig.enableCompression) {
      throw Exception('Compression is disabled');
    }
    
    try {
      // Note: Dart doesn't have built-in zlib decompression
      // We'll assume the data is UTF-8 encoded
      return utf8.decode(compressedData);
    } catch (e) {
      debugPrint('⚠️ Erreur décompression: $e');
      return utf8.decode(compressedData); // Tenter de décoder directement
    }
  }
  
  /// Crée un objet delta contenant uniquement les champs modifiés
  Map<String, dynamic> _createDelta(Object original, Object updated) {
    if (!SyncConfig.enableDeltaSync) {
      // Si la sync delta est désactivée, retourner l'objet complet
      if (updated is Map<String, dynamic>) {
        return updated;
      }
      return {};
    }
    
    // Pour l'instant, nous retournons l'objet complet
    // Dans une implémentation plus avancée, nous comparerions les champs
    if (updated is Map<String, dynamic>) {
      return updated;
    }
    return {};
  }
  
  /// Applique un delta à un objet existant
  Map<String, dynamic> _applyDelta(Map<String, dynamic> original, Map<String, dynamic> delta) {
    if (!SyncConfig.enableDeltaSync) {
      // Si la sync delta est désactivée, retourner le delta tel quel
      return delta;
    }
    
    // Fusionner les données
    final result = Map<String, dynamic>.from(original);
    delta.forEach((key, value) {
      result[key] = value;
    });
    
    return result;
  }
  
  /// Récupère les changements locaux avec support delta
  Future<List<Map<String, dynamic>>> _getLocalChangesWithDelta(String tableName, DateTime? since) async {
    if (!SyncConfig.enableDeltaSync) {
      // Si la sync delta est désactivée, utiliser la méthode normale
      return await _getLocalChanges(tableName, since);
    }
    
    // Pour l'instant, retourner les données complètes
    // Dans une implémentation avancée, nous comparerions avec les versions précédentes
    return await _getLocalChanges(tableName, since);
  }
  
  /// Ajoute une opération à la file d'attente avec priorité
  /// priority: 0 = haute, 1 = moyenne, 2 = basse
  void _addOperationToQueue(Map<String, dynamic> operation, {int priority = 1}) {
    // Ajouter la priorité à l'opération
    final operationWithPriority = Map<String, dynamic>.from(operation);
    operationWithPriority['_priority'] = priority;
    operationWithPriority['_queuedAt'] = DateTime.now().toIso8601String();
    
    _pendingOperations.add(operationWithPriority);
    _pendingSyncCount = _pendingOperations.length;
    debugPrint('📋 Opération ajoutée à la queue (priorité: $priority): code_ops=${operation['code_ops']}');
  }
  
  /// Trie les opérations en attente par priorité
  void _sortPendingOperationsByPriority() {
    _pendingOperations.sort((a, b) {
      final priorityA = a['_priority'] as int? ?? _defaultOperationPriority;
      final priorityB = b['_priority'] as int? ?? _defaultOperationPriority;
      
      // Priorité plus petite = plus haute priorité
      return priorityA.compareTo(priorityB);
    });
  }
  
  /// Nettoie les anciennes opérations de la file d'attente
  void _cleanupOldPendingOperations() {
    final retentionPeriod = SyncConfig.pendingDataRetention;
    final cutoffDate = DateTime.now().subtract(retentionPeriod);
    
    _pendingOperations.removeWhere((operation) {
      final queuedAtStr = operation['_queuedAt'] as String?;
      if (queuedAtStr == null) return false;
      
      try {
        final queuedAt = DateTime.parse(queuedAtStr);
        return queuedAt.isBefore(cutoffDate);
      } catch (e) {
        return false; // Ne pas supprimer si le format de date est invalide
      }
    });
    
    _pendingSyncCount = _pendingOperations.length;
    debugPrint('🧹 Nettoyage des anciennes opérations: ${_pendingOperations.length} restantes');
  }
  
  /// Trie les flots en attente par priorité
  void _sortPendingFlotsByPriority() {
    _pendingFlots.sort((a, b) {
      final priorityA = a['_priority'] as int? ?? _defaultOperationPriority;
      final priorityB = b['_priority'] as int? ?? _defaultOperationPriority;
      
      // Priorité plus petite = plus haute priorité
      return priorityA.compareTo(priorityB);
    });
  }
  
  /// Nettoie les anciens flots de la file d'attente
  void _cleanupOldPendingFlots() {
    final retentionPeriod = SyncConfig.pendingDataRetention;
    final cutoffDate = DateTime.now().subtract(retentionPeriod);
    
    _pendingFlots.removeWhere((flot) {
      final queuedAtStr = flot['_queuedAt'] as String?;
      if (queuedAtStr == null) return false;
      
      try {
        final queuedAt = DateTime.parse(queuedAtStr);
        return queuedAt.isBefore(cutoffDate);
      } catch (e) {
        return false; // Ne pas supprimer si le format de date est invalide
      }
    });
    
    _pendingFlotsCount = _pendingFlots.length;
    debugPrint('🧹 Nettoyage des anciens flots: ${_pendingFlots.length} restants');
  }

  /// Initialise le service de synchronisation
  Future<void> initialize() async {
    debugPrint('🔄 Initialisation du service de synchronisation...');

    // Charger les opérations en attente depuis le stockage persistant
    await _loadPendingOperations();
    
    // Charger les flots en attente depuis le stockage persistant
    await _loadPendingFlots();

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
      
      // Démarrer la sync lente PERSONNEL (toutes les 10 minutes)
      startSlowSync();
      debugPrint('🐢⏰ Synchronisation lente PERSONNEL activée (intervalle: ${_slowSyncInterval.inMinutes} min)');
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
      await syncPendingData();
      
      // Redémarrer l'auto-sync si activé
      if (_isAutoSyncEnabled && _autoSyncTimer == null) {
        startAutoSync();
        debugPrint('⏰ Redémarrage de la synchronisation automatique');
        
        // Redémarrer aussi la sync FLOTS & OPERATIONS
        if (_flotsOpsAutoSyncTimer == null) {
          startFlotsOpsAutoSync();
          debugPrint('🚀⏰ Redémarrage synchronisation FLOTS & OPERATIONS');
        }
        
        // Redémarrer aussi la sync lente PERSONNEL
        if (_slowSyncTimer == null) {
          startSlowSync();
          debugPrint('🐢⏰ Redémarrage synchronisation lente PERSONNEL');
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
      if (_slowSyncTimer != null) {
        stopSlowSync();
        debugPrint('⏸️ Auto-sync PERSONNEL (lent) arrêté (mode offline)');
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
        debugPrint('🆕 Première synchronisation détectée');
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
      
      // IMPORTANT: Synchroniser d'abord les opérations en attente depuis la queue
      debugPrint('🔄 Synchronisation des opérations en file d\'attente...');
      await syncPendingData();
      debugPrint('🔄 Synchronisation des flots en file d\'attente...');
      await syncPendingFlots();
      
      final dependentTables = ['agents', 'clients', 'operations', 'taux', 'commissions', 'comptes_speciaux', 'document_headers', 'cloture_caisse', 'flots', 'sims', 'sim_movements', 'virtual_transactions', 'depot_clients'];
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
      
      // Phase 4: Synchronisation des ADMINS (table users séparée)
      if (userRole == 'admin') {
        debugPrint('👑 PHASE 4: Synchronisation des ADMINS...');
        try {
          await syncAdmins();
          debugPrint('✅ Admins synchronisés avec succès');
        } catch (e) {
          debugPrint('⚠️ Erreur sync admins: $e');
          // Continuer même si les admins ne se synchronisent pas
        }
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
    final tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions', 'comptes_speciaux', 'document_headers', 'cloture_caisse', 'sims', 'sim_movements', 'virtual_transactions', 'depot_clients'];
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
  Future<bool> _validateEntityData(String tableName, Map<String, dynamic> data) async {
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
        // Permettre les clients globaux (shop_id = null) créés par les admins
        // Si shop_id est null ou 0, c'est un client global - valide pour les admins
        final shopId = data['shop_id'];
        if (shopId == null) {
          // Client global (admin) - valide
          debugPrint('ℹ️ Client ${data['nom']} (ID: ${data['id']}): client global sans shop (shop_id = null)');
          return true;
        }
        
        // Si shop_id est fourni, il doit être > 0
        if (shopId <= 0) {
          debugPrint('❌ Validation: shop_id invalide ($shopId) pour client ${data['id']}');
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
        
      case 'taux':
        // Validation des champs obligatoires pour les taux
        if (data['devise_source'] == null || data['devise_source'].toString().isEmpty) {
          debugPrint('❌ Validation: devise_source manquante pour taux ${data['id']}');
          return false;
        }
        if (data['devise_cible'] == null || data['devise_cible'].toString().isEmpty) {
          debugPrint('❌ Validation: devise_cible manquante pour taux ${data['id']}');
          return false;
        }
        if (data['taux'] == null || data['taux'] <= 0) {
          debugPrint('❌ Validation: taux invalide pour taux ${data['id']}');
          return false;
        }
        return true;
        
      case 'commissions':
        // Validation des champs obligatoires pour les commissions
        if (data['type'] == null) {
          debugPrint('❌ Validation: type manquant pour commission ${data['id']}');
          return false;
        }
        if (data['taux'] == null || data['taux'] < 0) {
          debugPrint('❌ Validation: taux invalide pour commission ${data['id']}');
          return false;
        }
        return true;
        
      case 'document_headers':
        // Validation des champs obligatoires pour les headers de document
        if (data['entreprise_nom'] == null || data['entreprise_nom'].toString().isEmpty) {
          debugPrint('❌ Validation: entreprise_nom manquant pour document_header ${data['id']}');
          return false;
        }
        return true;
        
      case 'cloture_caisse':
        // Validation des champs obligatoires pour les clôtures de caisse
        if (data['shop_id'] == null || data['shop_id'] <= 0) {
          debugPrint('❌ Validation: shop_id manquant pour cloture_caisse ${data['id']}');
          return false;
        }
        if (data['date_cloture'] == null) {
          debugPrint('❌ Validation: date_cloture manquante pour cloture_caisse ${data['id']}');
          return false;
        }
        return true;
        
      case 'sims':
        // Validation des champs obligatoires pour les SIMs
        if (data['numero'] == null || data['numero'].toString().isEmpty) {
          debugPrint('❌ Validation: numero manquant pour sim ${data['id']}');
          return false;
        }
        if (data['operateur'] == null || data['operateur'].toString().isEmpty) {
          debugPrint('❌ Validation: operateur manquant pour sim ${data['id']}');
          return false;
        }
        if (data['shop_id'] == null || data['shop_id'] <= 0) {
          debugPrint('❌ Validation: shop_id manquant ou invalide pour sim ${data['id']} (valeur: ${data['shop_id']})');
          return false;
        }
        // Additional validation for shop_id type
        if (data['shop_id'] is! int) {
          debugPrint('❌ Validation: shop_id doit être un entier pour sim ${data['id']} (valeur: ${data['shop_id']}, type: ${data['shop_id'].runtimeType})');
          return false;
        }
        return true;
        
      case 'virtual_transactions':
        // Validation des champs obligatoires pour les transactions virtuelles
        if (data['reference'] == null || data['reference'].toString().isEmpty) {
          debugPrint('❌ Validation: reference manquante pour virtual_transaction ${data['id']}');
          return false;
        }
        if (data['montant_virtuel'] == null || data['montant_virtuel'] <= 0) {
          debugPrint('❌ Validation: montant_virtuel invalide pour virtual_transaction ${data['id']}');
          return false;
        }
        if (data['montant_cash'] == null || data['montant_cash'] < 0) {
          debugPrint('❌ Validation: montant_cash invalide pour virtual_transaction ${data['id']}');
          return false;
        }
        if (data['sim_numero'] == null || data['sim_numero'].toString().isEmpty) {
          debugPrint('❌ Validation: sim_numero manquant pour virtual_transaction ${data['id']}');
          return false;
        }
        if (data['shop_id'] == null || data['shop_id'] <= 0) {
          debugPrint('❌ Validation: shop_id manquant ou invalide pour virtual_transaction ${data['id']}');
          return false;
        }
        if (data['agent_id'] == null || data['agent_id'] <= 0) {
          debugPrint('❌ Validation: agent_id manquant ou invalide pour virtual_transaction ${data['id']}');
          return false;
        }
        return true;
        
      case 'sim_movements':
        // Validation des champs obligatoires pour les mouvements de SIM
        if (data['sim_id'] == null || data['sim_id'] <= 0) {
          debugPrint('❌ Validation: sim_id manquant ou invalide pour sim_movement ${data['id']}');
          return false;
        }
        if (data['sim_numero'] == null || data['sim_numero'].toString().isEmpty) {
          debugPrint('❌ Validation: sim_numero manquant pour sim_movement ${data['id']}');
          return false;
        }
        if (data['nouveau_shop_id'] == null || data['nouveau_shop_id'] <= 0) {
          debugPrint('❌ Validation: nouveau_shop_id manquant ou invalide pour sim_movement ${data['id']}');
          return false;
        }
        if (data['nouveau_shop_designation'] == null || data['nouveau_shop_designation'].toString().isEmpty) {
          debugPrint('❌ Validation: nouveau_shop_designation manquant pour sim_movement ${data['id']}');
          return false;
        }
        if (data['admin_responsable'] == null || data['admin_responsable'].toString().isEmpty) {
          debugPrint('❌ Validation: admin_responsable manquant pour sim_movement ${data['id']}');
          return false;
        }
        return true;
        
      case 'comptes_speciaux':
        // Validation des champs obligatoires pour les comptes spéciaux
        if (data['type'] == null || data['type'].toString().isEmpty) {
          debugPrint('❌ Validation: type manquant pour compte_special ${data['id']}');
          return false;
        }
        if (data['type_transaction'] == null || data['type_transaction'].toString().isEmpty) {
          debugPrint('❌ Validation: type_transaction manquant pour compte_special ${data['id']}');
          return false;
        }
        
        // Vérifier les valeurs valides pour type et type_transaction
        final validTypes = ['FRAIS', 'DEPENSE'];  // CORRIGÉ: DEPENSE (sans S)
        final validTransactionTypes = ['DEPOT', 'DEPOT_FRAIS', 'RETRAIT', 'SORTIE', 'COMMISSION_AUTO'];  // CORRIGÉ: valeurs de l'enum
        
        if (!validTypes.contains(data['type'])) {
          debugPrint('❌ Validation: type invalide "${data['type']}" pour compte_special ${data['id']} (valeurs acceptées: ${validTypes.join(", ")})');
          return false;
        }
        if (!validTransactionTypes.contains(data['type_transaction'])) {
          debugPrint('❌ Validation: type_transaction invalide "${data['type_transaction']}" pour compte_special ${data['id']} (valeurs acceptées: ${validTransactionTypes.join(", ")})');
          return false;
        }
        
        // Validation du montant selon le type de transaction:
        // - DEPOT, DEPOT_FRAIS, COMMISSION_AUTO: montant doit être > 0 (positif)
        // - RETRAIT, SORTIE: montant peut être négatif (représente une sortie d'argent)
        final montant = data['montant'];
        final typeTransaction = data['type_transaction'].toString();
        
        if (montant == null) {
          debugPrint('❌ Validation: montant null pour compte_special ${data['id']}');
          return false;
        }
        
        // Convertir en num pour la comparaison
        final montantNum = montant is num ? montant : num.tryParse(montant.toString());
        if (montantNum == null) {
          debugPrint('❌ Validation: montant non numérique pour compte_special ${data['id']} (valeur: $montant)');
          return false;
        }
        
        // Pour RETRAIT et SORTIE, on accepte les montants négatifs (représente une sortie)
        // Pour les autres types, le montant doit être positif
        if (typeTransaction == 'RETRAIT' || typeTransaction == 'SORTIE') {
          // Pour les retraits/sorties, montant peut être négatif ou positif (on accepte les deux)
          if (montantNum == 0) {
            debugPrint('❌ Validation: montant zéro pour compte_special ${data['id']} (type: $typeTransaction)');
            return false;
          }
        } else {
          // Pour DEPOT, DEPOT_FRAIS, COMMISSION_AUTO: montant doit être positif
          if (montantNum <= 0) {
            debugPrint('❌ Validation: montant invalide ($montantNum) pour compte_special ${data['id']} (type: $typeTransaction, doit être > 0)');
            return false;
          }
        }
        
        return true;
        
      default:
        debugPrint('⚠️ Validation non implémentée pour $tableName');
        return true; // Par défaut, accepter les données non validées
    }
  }

  /// Upload des données d'une table spécifique vers le serveur
  Future<void> _uploadTableData(String tableName, String userId, [String userRole = 'admin']) async {
    try {
      // Obtenir les données locales à uploader avec support delta
      final localData = await _getLocalChangesWithDelta(tableName, null);
      debugPrint('📤 $tableName: ${localData.length} éléments à uploader');
      
      if (localData.isEmpty) {
        debugPrint('📭 $tableName: Aucune donnée à uploader');
        return;
      }
      
      // VALIDATION: Vérifier les données AVANT upload
      final validatedData = <Map<String, dynamic>>[];
      final invalidData = <Map<String, dynamic>>[];
      
      for (var data in localData) {
        final isValid = await _validateEntityData(tableName, data);
        if (isValid) {
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
          
      final baseUrl = (await _baseUrl).trim();
      
      // Log the data being sent for debugging
      if (validatedData.isNotEmpty) {
        debugPrint('📤 $tableName: Sending ${validatedData.length} entities');
        for (int i = 0; i < validatedData.length && i < 3; i++) {
          debugPrint('   Entity $i: ${validatedData[i]}');
        }
        if (validatedData.length > 3) {
          debugPrint('   ... and ${validatedData.length - 3} more entities');
        }
      }
      
      // Préparer les données à envoyer
      final payload = {
        'entities': validatedData,
        'user_id': userId,
        'user_role': userRole,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonData = jsonEncode(payload);
      
      // Préparer les headers
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      
      // Ajouter l'en-tête de compression si activée
      if (SyncConfig.enableCompression) {
        headers['Content-Encoding'] = 'gzip';
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/$tableName/upload.php'),
        headers: headers,
        body: jsonData,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        // Vérifier que la réponse est bien du JSON avant de parser
        final responseBody = response.body.trim();
        
        // Log pour déboguer les erreurs de parsing
        if (responseBody.isEmpty) {
          debugPrint('❌ $tableName: Réponse vide du serveur');
          throw Exception('Réponse vide du serveur pour $tableName');
        }
        
        // Vérifier que la réponse commence par { ou [ (JSON valide)
        if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
          debugPrint('❌ $tableName: Réponse non-JSON reçue lors de l\'upload');
          debugPrint('📄 Contenu brut (premiers 1000 caractères): ${responseBody.substring(0, responseBody.length > 1000 ? 1000 : responseBody.length)}');
          throw FormatException('La réponse du serveur n\'est pas du JSON valide pour $tableName: ${responseBody.substring(0, responseBody.length > 100 ? 100 : responseBody.length)}');
        }
        
        final result = jsonDecode(responseBody);
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
        debugPrint('⚠️ Erreur HTTP $tableName: ${response.statusCode}');
        debugPrint('📄 Réponse du serveur: ${response.body}');
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur upload $tableName: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      throw Exception('Erreur upload $tableName: $e');
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
  
  /// Synchronise les administrateurs locaux vers le serveur (table users)
  /// Les admins sont stockés localement dans admin_X keys et doivent être sync vers /sync/admins/upload.php
  Future<void> syncAdmins() async {
    try {
      debugPrint('👑 Début synchronisation des ADMINS...');
      
      // Récupérer tous les admins locaux
      final allAdmins = await LocalDB.instance.getAllAdmins();
      
      if (allAdmins.isEmpty) {
        debugPrint('⚠️ Aucun admin à synchroniser');
        return;
      }
      
      debugPrint('👑 ${allAdmins.length} admins à synchroniser');
      
      // Préparer les données pour l'upload
      final adminsData = allAdmins.map((admin) => {
        'id': admin.id,
        'username': admin.username,
        'password': admin.password,
        'role': 'ADMIN',
        'nom': admin.nom,
        'telephone': admin.telephone,
        'email': null,
        'is_active': true,
      }).toList();
      
      final baseUrl = (await _baseUrl).trim();
      
      final payload = {
        'admins': adminsData,
        'user_id': 'admin',
      };
      
      debugPrint('📤 Upload admins vers: $baseUrl/admins/upload.php');
      
      final response = await http.post(
        Uri.parse('$baseUrl/admins/upload.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(_syncTimeout);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          final stats = result['stats'] ?? {};
          debugPrint('✅ Admins synchronisés: ${stats['created']} créés, ${stats['updated']} mis à jour');
          debugPrint('   Total sur serveur: ${stats['total']}/2 max');
          
          // Afficher les erreurs s'il y en a
          final errors = result['errors'] as List? ?? [];
          if (errors.isNotEmpty) {
            for (var error in errors) {
              debugPrint('⚠️ Erreur admin ${error['username']}: ${error['error']}');
            }
          }
        } else {
          debugPrint('⚠️ Erreur sync admins: ${result['error'] ?? result['message']}');
        }
      } else {
        debugPrint('❌ Erreur HTTP sync admins: ${response.statusCode}');
        debugPrint('📄 Réponse: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur sync admins: $e');
      // Ne pas propager l'erreur pour ne pas bloquer la sync principale
    }
  }
  
  /// Télécharge les admins depuis le serveur
  Future<void> downloadAdmins() async {
    try {
      debugPrint('📥 Téléchargement des ADMINS depuis le serveur...');
      
      final baseUrl = (await _baseUrl).trim();
      
      final response = await http.post(
        Uri.parse('$baseUrl/admins/download.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'last_sync_timestamp': null}),
      ).timeout(_syncTimeout);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          final admins = result['admins'] as List? ?? [];
          debugPrint('👑 ${admins.length} admins reçus du serveur');
          
          // Sauvegarder les admins téléchargés localement
          final prefs = await SharedPreferences.getInstance();
          
          for (var adminData in admins) {
            final adminId = adminData['id'];
            if (adminId != null && adminId > 0) {
              // Vérifier si cet admin existe déjà localement
              final existingAdminData = prefs.getString('admin_$adminId');
              
              // Convertir les données du serveur au format local
              final serverAdmin = {
                'id': adminId,
                'username': adminData['username'],
                'password': adminData['password'],
                'role': 'ADMIN',
                'nom': adminData['nom'],
                'telephone': adminData['telephone'],
                'shop_id': null,
                'created_at': adminData['created_at'],
              };
              
              if (existingAdminData == null) {
                // Nouvel admin du serveur - créer localement
                await prefs.setString('admin_$adminId', jsonEncode(serverAdmin));
                debugPrint('✅ Admin $adminId (${adminData['username']}) téléchargé et sauvegardé');
              } else {
                // Admin existant - fusionner si nécessaire (version serveur a priorité pour les updates)
                final localAdmin = jsonDecode(existingAdminData);
                final serverUpdatedAt = adminData['updated_at'] ?? adminData['created_at'];
                final localCreatedAt = localAdmin['created_at'];
                
                // Si le serveur a une version plus récente, mettre à jour
                if (serverUpdatedAt != null && localCreatedAt != null) {
                  try {
                    final serverDate = DateTime.parse(serverUpdatedAt.toString());
                    final localDate = DateTime.parse(localCreatedAt.toString());
                    
                    if (serverDate.isAfter(localDate)) {
                      await prefs.setString('admin_$adminId', jsonEncode(serverAdmin));
                      debugPrint('🔄 Admin $adminId mis à jour depuis le serveur');
                    }
                  } catch (e) {
                    debugPrint('⚠️ Erreur comparaison dates admin $adminId: $e');
                  }
                }
              }
            }
          }
          
          debugPrint('✅ Synchronisation admins depuis serveur terminée');
          
        } else {
          debugPrint('⚠️ Erreur download admins: ${result['message']}');
        }
      } else {
        debugPrint('❌ Erreur HTTP download admins: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur download admins: $e');
    }
  }
  
  /// Télécharge TOUS les comptes spéciaux (FRAIS et DÉPENSES) depuis le serveur
  /// Cette méthode est utilisée par l'admin pour obtenir une copie complète
  /// Paramètres:
  /// - type: 'FRAIS' ou 'DEPENSE' pour filtrer par type (optionnel)
  /// - shopId: ID du shop pour filtrer (optionnel, ignoré pour admin)
  /// Retourne: Map avec les statistiques et les données téléchargées
  Future<Map<String, dynamic>> downloadAllComptesSpeciaux({
    String? type,
    int? shopId,
    int limit = 10000,
    int offset = 0,
  }) async {
    try {
      final baseUrl = (await _baseUrl).trim();
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role') ?? 'admin';
      final userId = prefs.getString('current_username') ?? 'admin';
      
      // Construire les paramètres de requête
      final queryParams = <String, String>{
        'user_id': userId,
        'user_role': userRole,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      // Ajouter le type si spécifié
      if (type != null && (type == 'FRAIS' || type == 'DEPENSE')) {
        queryParams['type'] = type;
      }
      
      // Ajouter shop_id si l'utilisateur n'est pas admin
      if (userRole != 'admin' && shopId != null) {
        queryParams['shop_id'] = shopId.toString();
        debugPrint('💰 Mode AGENT: filtrage COMPTES SPÉCIAUX par shop_id=$shopId');
      } else {
        debugPrint('👑 Mode ADMIN: téléchargement de TOUS les comptes spéciaux');
      }
      
      // Utiliser le nouvel endpoint download.php
      final uri = Uri.parse('$baseUrl/comptes_speciaux/download.php')
          .replace(queryParameters: queryParams);
      
      debugPrint('📥 Téléchargement complet comptes_speciaux: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
      ).timeout(_syncTimeout);
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          final entities = (result['entities'] as List?) ?? [];
          final totalCount = result['total_count'] ?? entities.length;
          final stats = result['stats'] ?? {};
          final summary = result['summary'] ?? {};
          
          debugPrint('✅ Comptes spéciaux téléchargés: ${entities.length} / $totalCount');
          debugPrint('   📊 FRAIS: ${summary['nombre_frais']} transactions, total: \$${summary['total_frais']}');
          debugPrint('   📊 DÉPENSE: ${summary['nombre_depense']} transactions, total: \$${summary['total_depense']}');
          
          // Sauvegarder les données localement si des entités sont reçues
          if (entities.isNotEmpty) {
            await _processRemoteChanges('comptes_speciaux', entities, userId);
            
            // Recharger les données en mémoire
            await CompteSpecialService.instance.loadTransactions();
            debugPrint('✅ Comptes spéciaux rechargés en mémoire');
          }
          
          return {
            'success': true,
            'count': entities.length,
            'total_count': totalCount,
            'has_more': result['has_more'] ?? false,
            'stats': stats,
            'summary': summary,
            'message': 'Téléchargement réussi: ${entities.length} comptes spéciaux',
          };
        } else {
          throw Exception('Erreur serveur: ${result['message']}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur téléchargement comptes_speciaux: $e');
      return {
        'success': false,
        'count': 0,
        'message': 'Erreur: $e',
      };
    }
  }
  
  /// Télécharge tous les FRAIS depuis le serveur (raccourci pour l'admin)
  Future<Map<String, dynamic>> downloadAllFrais({int? shopId}) async {
    return await downloadAllComptesSpeciaux(type: 'FRAIS', shopId: shopId);
  }
  
  /// Télécharge toutes les DÉPENSES depuis le serveur (raccourci pour l'admin)
  Future<Map<String, dynamic>> downloadAllDepenses({int? shopId}) async {
    return await downloadAllComptesSpeciaux(type: 'DEPENSE', shopId: shopId);
  }
  
  /// Download des changements du serveur vers l'app
  Future<void> _downloadRemoteChanges(String userId, String userRole) async {
    // NOTE: 'operations' est maintenant inclus pour permettre à l'admin de télécharger toutes les opérations
    // TransferSyncService gère la synchronisation en temps réel pour les agents
    // DepotRetraitSyncService gère la synchronisation des depot_clients
    final tables = ['operations', 'shops', 'agents', 'clients', 'taux', 'commissions', 'comptes_speciaux', 'document_headers', 'cloture_caisse', 'flots', 'sims', 'sim_movements', 'virtual_transactions'];
    int successCount = 0;
    int errorCount = 0;
    
    debugPrint('📥 Début du download des données distantes (${tables.length} tables)');
    debugPrint('⚠️ depot_clients synchronisé par DepotRetraitSyncService (ignoré ici)');
    
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
      
      // STRATÉGIE SPÉCIALE POUR virtual_transactions
      // Utilise date_enregistrement de la dernière transaction locale au lieu de last_sync
      String sinceParam;
      
      if (tableName == 'virtual_transactions') {
        // Récupérer la dernière transaction locale
        final allLocalVt = await LocalDB.instance.getAllVirtualTransactions();
        
        if (allLocalVt.isEmpty) {
          // PREMIÈRE UTILISATION: Télécharger TOUT
          sinceParam = '2020-01-01T00:00:00.000';
          debugPrint('🆕 VIRTUAL_TRANSACTIONS: Première utilisation - Téléchargement COMPLET');
        } else {
          // Trouver la transaction avec la date_enregistrement la plus récente
          final latestTransaction = allLocalVt.reduce((a, b) => 
            a.dateEnregistrement.isAfter(b.dateEnregistrement) ? a : b
          );
          
          // Télécharger depuis cette date (avec 60s overlap pour sécurité)
          final sinceDate = latestTransaction.dateEnregistrement.subtract(const Duration(seconds: 60));
          sinceParam = sinceDate.toIso8601String();
          
          debugPrint('💰 VIRTUAL_TRANSACTIONS: Dernière transaction locale: ${latestTransaction.reference}');
          debugPrint('   Date enregistrement: ${latestTransaction.dateEnregistrement}');
          debugPrint('   Téléchargement depuis: $sinceParam (avec 60s overlap)');
        }
      } else {
        // OPTIMIZATION: Add 60-second overlap window to prevent missing data
        // This ensures we catch any concurrent modifications that happened
        // during the previous sync window
        DateTime? adjustedSince;
        if (lastSync != null) {
          adjustedSince = lastSync.subtract(const Duration(seconds: 60));
          debugPrint('🔄 $tableName: Overlap window applied (60s before $lastSync)');
        }
        
        // Pour les tables standards, utiliser le timestamp de dernière sync avec overlap
        sinceParam = adjustedSince != null 
            ? adjustedSince.toIso8601String() 
            : '2020-01-01T00:00:00.000';  // Date par défaut très ancienne
      }
      
      debugPrint('📥 $tableName: Downloading since $sinceParam ${lastSync != null ? '(with 60s overlap)' : '(initial sync)'}');
      
      final baseUrl = (await _baseUrl).trim();
      
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
      } else if (tableName == 'flots') {
        // Pour flots, filtrer par shop (source OU destination)
        final queryParams = {
          'since': sinceParam,
        };
        
        if (userRole != 'admin' && currentShopId != null) {
          queryParams['shop_id'] = currentShopId.toString();
          debugPrint('🚚 Mode AGENT: filtrage FLOTs par shop_id=$currentShopId (source OU destination)');
        } else {
          debugPrint('👑 Mode ADMIN: téléchargement de tous les FLOTs');
        }
        
        uri = Uri.parse('$baseUrl/$tableName/$endpoint').replace(queryParameters: queryParams);
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
      } else if (tableName == 'comptes_speciaux') {
        // Pour comptes_speciaux, l'admin télécharge TOUT, les agents filtrent par shop
        final queryParams = {
          'since': sinceParam,
        };
        
        if (userRole != 'admin' && currentShopId != null) {
          queryParams['shop_id'] = currentShopId.toString();
          debugPrint('💰 Mode AGENT: filtrage COMPTES SPÉCIAUX par shop_id=$currentShopId');
        } else {
          debugPrint('👑 Mode ADMIN: téléchargement de TOUS les comptes spéciaux');
        }
        
        uri = Uri.parse('$baseUrl/$tableName/$endpoint').replace(queryParameters: queryParams);
      }
      
      debugPrint('📥 Requête download: $uri');
      
      // Préparer les headers
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      
      // Indiquer que nous pouvons accepter des réponses compressées
      if (SyncConfig.enableCompression) {
        headers['Accept-Encoding'] = 'gzip, deflate';
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(_syncTimeout);

      if (response.statusCode == 200) {
        // Vérifier que la réponse est bien du JSON avant de parser
        final responseBody = response.body.trim();
        
        // Log pour déboguer les erreurs de parsing
        if (responseBody.isEmpty) {
          debugPrint('❌ $tableName: Réponse vide du serveur');
          throw Exception('Réponse vide du serveur pour $tableName');
        }
        
        // Vérifier que la réponse commence par { ou [ (JSON valide)
        if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
          debugPrint('❌ $tableName: Réponse non-JSON reçue');
          debugPrint('📄 Contenu brut (premiers 500 caractères): ${responseBody.substring(0, responseBody.length > 500 ? 500 : responseBody.length)}');
          throw FormatException('La réponse du serveur n\'est pas du JSON valide pour $tableName');
        }
        
        final result = jsonDecode(responseBody);
        if (result['success'] == true) {
          // Gérer le cas où entities est null ou n'est pas une liste
          final remoteData = (result['entities'] as List?) ?? [];
          debugPrint('📥 $tableName: ${remoteData.length} éléments reçus du serveur');
          
          // DIAGNOSTIC POUR SIMS
          if (tableName == 'sims') {
            if (remoteData.isEmpty) {
              debugPrint('⚠️ AUCUNE SIM REÇUE DU SERVEUR !');
              debugPrint('   Vérifiez si des SIMs existent dans la base de données serveur');
              debugPrint('   URL requête: $uri');
            } else {
              debugPrint('📱 SIMs reçues du serveur:');
              for (var simData in remoteData) {
                debugPrint('   - ID: ${simData['id']}, Numéro: ${simData['numero']}, Opérateur: ${simData['operateur']}, Shop: ${simData['shop_id']}');
              }
            }
          }
          
          if (remoteData.isNotEmpty) {
            await _processRemoteChanges(tableName, remoteData, userId);
            
            // CRITIQUE: Recharger les données en mémoire après le traitement
            // NOTE: NE PAS utiliser clearBeforeLoad ici car les données sont déjà insérées dans LocalDB
            // On veut juste recharger en mémoire ce qui est déjà en base locale
            debugPrint('🔄 Rechargement des données $tableName en mémoire après download...');
            switch (tableName) {
              case 'shops':
                await ShopService.instance.loadShops(forceRefresh: true);
                break;
              case 'agents':
                await AgentService.instance.loadAgents(forceRefresh: true);
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
                await FlotService.instance.loadFlots(
                  shopId: currentShopId,
                  isAdmin: userRole == 'admin',
                );
                break;
              case 'operations':
                // Recharger les opérations dans le service
                debugPrint('📋 Rechargement des OPÉRATIONS en mémoire...');
                // IMPORTANT: Utiliser l'instance existante via le contexte si disponible
                // Sinon créer une instance temporaire pour le rechargement
                final operationService = OperationService();
                if (userRole == 'admin') {
                  // Admin: charger TOUTES les opérations
                  await operationService.loadOperations();
                  debugPrint('👑 Admin: ${operationService.operations.length} opérations chargées (TOUTES)');
                } else if (currentShopId != null) {
                  // Agent: charger seulement les opérations du shop
                  await operationService.loadOperations(shopId: currentShopId);
                  debugPrint('👤 Agent: ${operationService.operations.length} opérations chargées (shop $currentShopId)');
                } else {
                  debugPrint('⚠️ Impossible de recharger les opérations: pas de contexte utilisateur');
                }
                break;
              case 'sims':
                // Recharger les SIMs dans le service
                debugPrint('📱 Rechargement des SIMs en mémoire...');
                await SimService.instance.loadSims();
                break;
              case 'sim_movements':
                // Recharger les mouvements de SIM dans le service
                debugPrint('📝 Rechargement des mouvements de SIM en mémoire...');
                await SimService.instance.loadMovements();
                break;
              case 'virtual_transactions':
                // Recharger les transactions virtuelles dans le service
                debugPrint('💰 Rechargement des transactions virtuelles en mémoire...');
                await VirtualTransactionService.instance.loadTransactions();
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
    
    // STRATÉGIE SPÉCIALE POUR LES SIMs: Écraser complètement
    if (tableName == 'sims') {
      debugPrint('📱 STRATÉGIE SIMs: Téléchargement complet et écrasement');
      
      // ÉTAPE 1: Supprimer TOUTES les SIMs locales
      final allLocalSims = await LocalDB.instance.getAllSims();
      debugPrint('🗑️ Suppression de ${allLocalSims.length} SIMs locales existantes');
      
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('sim_')) {
          await prefs.remove(key);
        }
      }
      debugPrint('✅ Toutes les SIMs locales supprimées');
      
      // ÉTAPE 2: Insérer toutes les SIMs du serveur
      debugPrint('📥 Insertion de ${remoteData.length} SIMs depuis le serveur');
      
      for (var simData in remoteData) {
        try {
          final sim = SimModel.fromJson(simData);
          await LocalDB.instance.saveSim(sim);
          inserted++;
          debugPrint('  ✅ SIM ${sim.numero} insérée (Opérateur: ${sim.operateur}, Solde: ${sim.soldeActuel})');
        } catch (e) {
          errors++;
          debugPrint('  ❌ Erreur insertion SIM: $e');
        }
      }
      
      debugPrint('✅ $tableName: $inserted insérés, $errors erreurs');
      
      // ÉTAPE 3: Recharger les SIMs en mémoire
      debugPrint('🔄 Rechargement des SIMs en mémoire...');
      await SimService.instance.loadSims();
      debugPrint('✅ SIMs rechargées: ${SimService.instance.sims.length} SIMs disponibles');
      
      return; // Sortir de la fonction - traitement terminé pour les SIMs
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
          final conflict = await _detectConflict(localEntity, remoteEntity, tableName, userId);
          
          if (conflict != null) {
            // Résoudre le conflit
            final resolved = await _resolveConflict(tableName, conflict, userId);
            if (resolved) {
              updated++;
            } else {
              conflicts++;
            }
          } else {
            // Pas de conflit - mettre à jour avec les données distantes
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
    // NOTE: NE PAS utiliser clearBeforeLoad ici car les données sont déjà insérées dans LocalDB
    // On veut juste recharger en mémoire ce qui est déjà en base locale
    debugPrint('🔄 Rechargement du service $tableName en mémoire après traitement...');
    switch (tableName) {
      case 'shops':
        await ShopService.instance.loadShops(forceRefresh: true);
        break;
      case 'agents':
        await AgentService.instance.loadAgents(forceRefresh: true);
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
        // Recharger les FLOTs automatiquement après traitement
        debugPrint('🚚 Rechargement des FLOTs après traitement...');
        final prefs = await SharedPreferences.getInstance();
        final currentShopId = prefs.getInt('current_shop_id');
        final currentUserRole = prefs.getString('current_user_role') ?? 'agent';
        await FlotService.instance.loadFlots(
          shopId: currentShopId,
          isAdmin: currentUserRole == 'admin',
        );
        break;
      case 'operations':
        // Recharger les opérations automatiquement après traitement
        debugPrint('📋 Rechargement des OPÉRATIONS après traitement...');
        final prefsOps = await SharedPreferences.getInstance();
        final shopIdOps = prefsOps.getInt('current_shop_id');
        final userRoleOps = prefsOps.getString('current_user_role') ?? 'agent';
        final operationServiceProcess = OperationService();
        if (userRoleOps == 'admin') {
          // Admin: charger TOUTES les opérations
          await operationServiceProcess.loadOperations();
          debugPrint('👑 Admin: ${operationServiceProcess.operations.length} opérations rechargées (TOUTES)');
        } else if (shopIdOps != null) {
          // Agent: charger seulement les opérations du shop
          await operationServiceProcess.loadOperations(shopId: shopIdOps);
          debugPrint('👤 Agent: ${operationServiceProcess.operations.length} opérations rechargées (shop $shopIdOps)');
        }
        break;
      case 'sims':
        // Déjà rechargé dans la stratégie spéciale ci-dessus
        debugPrint('ℹ️ SIMs déjà rechargées dans la stratégie d\'effacement');
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
  Future<ConflictInfo?> _detectConflict(Map<String, dynamic> local, Map<String, dynamic> remote, String tableName, String userId) async {
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
      tableName: tableName,
      userId: userId,
    );
  }

  /// Résout un conflit en utilisant des stratégies avancées
  Future<bool> _resolveConflict(String tableName, ConflictInfo conflict, String userId) async {
    debugPrint('⚠️ Conflit détecté pour ${conflict.localData['id']} dans $tableName');
    debugPrint('   Local: ${conflict.localModified}');
    debugPrint('   Remote: ${conflict.remoteModified}');
    
    // Si les timestamps sont identiques, ne rien faire (même version)
    if (conflict.localModified.isAtSameMomentAs(conflict.remoteModified)) {
      debugPrint('🔄 Résolution: Versions identiques, aucune action requise');
      
      // Logger le conflit résolu
      final conflictLoggingService = ConflictLoggingService();
      await conflictLoggingService.logConflict(
        tableName: tableName,
        entityId: conflict.localData['id'],
        localModified: conflict.localModified,
        remoteModified: conflict.remoteModified,
        resolutionStrategy: 'identical_versions',
        resolvedSuccessfully: true,
        localData: conflict.localData,
        remoteData: conflict.remoteData,
      );
      
      return false;
    }
    
    // Notifier l'utilisateur du conflit
    final conflictNotificationService = ConflictNotificationService();
    await conflictNotificationService.notifyConflict(
      tableName: tableName,
      entityId: conflict.localData['id'],
      localModified: conflict.localModified,
      remoteModified: conflict.remoteModified,
      localDataPreview: _getDataPreview(conflict.localData),
      remoteDataPreview: _getDataPreview(conflict.remoteData),
    );
    
    // Appliquer la stratégie de résolution selon le type de données
    final resolutionStrategy = _getResolutionStrategy(tableName);
    
    bool resolvedSuccessfully = false;
    String resolutionMethod = '';
    
    switch (resolutionStrategy) {
      case ConflictResolutionStrategy.lastModifiedWins:
        resolvedSuccessfully = await _resolveWithLastModifiedWins(tableName, conflict);
        resolutionMethod = 'lastModifiedWins';
        break;
        
      case ConflictResolutionStrategy.mergeFields:
        resolvedSuccessfully = await _resolveWithFieldMerge(tableName, conflict);
        resolutionMethod = 'mergeFields';
        break;
        
      case ConflictResolutionStrategy.userChoice:
        // Pour les conflits critiques nécessitant une décision utilisateur
        resolvedSuccessfully = await _resolveWithUserChoice(tableName, conflict);
        resolutionMethod = 'userChoice';
        break;
        
      default:
        // Stratégie par défaut: Le plus récent gagne
        resolvedSuccessfully = await _resolveWithLastModifiedWins(tableName, conflict);
        resolutionMethod = 'default_lastModifiedWins';
        break;
    }
    
    // Logger le conflit résolu
    final conflictLoggingService = ConflictLoggingService();
    await conflictLoggingService.logConflict(
      tableName: tableName,
      entityId: conflict.localData['id'],
      localModified: conflict.localModified,
      remoteModified: conflict.remoteModified,
      resolutionStrategy: resolutionMethod,
      resolvedSuccessfully: resolvedSuccessfully,
      localData: conflict.localData,
      remoteData: conflict.remoteData,
    );
    
    return resolvedSuccessfully;
  }
  
  /// Obtient la stratégie de résolution pour un type de données
  ConflictResolutionStrategy _getResolutionStrategy(String tableName) {
    switch (tableName) {
      case 'clients':
      case 'agents':
        // Pour les données personnelles, fusionner les champs quand possible
        return ConflictResolutionStrategy.mergeFields;
        
      case 'operations':
      case 'flots':
        // Pour les opérations financières, le plus récent gagne
        return ConflictResolutionStrategy.lastModifiedWins;
        
      case 'shops':
      case 'commissions':
        // Pour les données critiques, nécessiter une décision utilisateur
        return ConflictResolutionStrategy.userChoice;
        
      default:
        // Par défaut, le plus récent gagne
        return ConflictResolutionStrategy.lastModifiedWins;
    }
  }
  
  /// Résout un conflit avec la stratégie "last modified wins"
  Future<bool> _resolveWithLastModifiedWins(String tableName, ConflictInfo conflict) async {
    try {
      // Stratégie: Le plus récent gagne
      final useRemote = conflict.remoteModified.isAfter(conflict.localModified);
      
      if (useRemote) {
        debugPrint('🔄 Résolution: Utiliser la version distante (plus récente)');
        await _updateLocalEntity(tableName, conflict.remoteData);
        debugPrint('✅ Conflit résolu avec version distante');
        return true;
      } else {
        debugPrint('🔄 Résolution: Conserver la version locale (plus récente)');
        // Re-marquer pour upload lors de la prochaine sync
        await _markEntityForReupload(tableName, conflict.localData['id']);
        debugPrint('✅ Conflit résolu avec version locale (re-upload planifié)');
        return true; // Résolu avec succès, même si on conserve la version locale
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la résolution avec lastModifiedWins: $e');
      return false;
    }
  }
  
  /// Résout un conflit avec fusion de champs
  Future<bool> _resolveWithFieldMerge(String tableName, ConflictInfo conflict) async {
    try {
      debugPrint('🔄 Résolution: Fusion des champs modifiés');
      
      // Créer une version fusionnée
      final mergedData = _mergeEntityData(conflict.localData, conflict.remoteData);
      
      // Mettre à jour avec les données fusionnées
      await _updateLocalEntity(tableName, mergedData);
      debugPrint('✅ Conflit résolu avec fusion de champs');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la fusion des données: $e');
      return false;
    }
  }
  
  /// Résout un conflit avec choix utilisateur (simulation)
  Future<bool> _resolveWithUserChoice(String tableName, ConflictInfo conflict) async {
    debugPrint('🔄 Résolution: Nécessite une décision utilisateur');
    
    // Dans une implémentation réelle, cela déclencherait une interface utilisateur
    // Pour l'instant, on utilise la stratégie par défaut
    
    // Log le conflit pour analyse future
    debugPrint('📝 Conflit nécessitant décision utilisateur enregistré');
    
    // Pour l'instant, retourner false pour indiquer que la décision utilisateur est nécessaire
    // Dans une vraie implémentation, cela pourrait retourner true après interaction utilisateur
    return false;
  }
  
  /// Fusionne les données de deux versions d'une entité
  Map<String, dynamic> _mergeEntityData(
    Map<String, dynamic> localData, 
    Map<String, dynamic> remoteData
  ) {
    final merged = Map<String, dynamic>.from(localData);
    
    // Fusionner les champs modifiés
    remoteData.forEach((key, remoteValue) {
      final localValue = localData[key];
      
      // Si le champ distant est différent et plus récent, l'utiliser
      if (remoteValue != localValue) {
        // Pour les champs de date, utiliser le plus récent
        if (key.endsWith('_at') || key.endsWith('_date')) {
          try {
            final localDate = DateTime.tryParse(localValue.toString());
            final remoteDate = DateTime.tryParse(remoteValue.toString());
            
            if (localDate != null && remoteDate != null && remoteDate.isAfter(localDate)) {
              merged[key] = remoteValue;
            }
          } catch (e) {
            // En cas d'erreur de parsing, utiliser la valeur distante
            merged[key] = remoteValue;
          }
        } else {
          // Pour les autres champs, utiliser la valeur distante
          merged[key] = remoteValue;
        }
      }
    });
    
    return merged;
  }
  
  /// Obtient un aperçu des données pour les notifications
  String _getDataPreview(Map<String, dynamic> data) {
    // Extraire les champs importants pour l'aperçu
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
          final totalShops = shops.length;
          debugPrint('🏪 SHOPS: Total shops en mémoire: $totalShops');
          
          unsyncedData = shops
              .where((shop) {
                final isNotSynced = shop.isSynced != true;
                if (isNotSynced) {
                  debugPrint('📤 Shop "${shop.designation}" (ID ${shop.id}) à synchroniser (is_synced: ${shop.isSynced})');
                }
                return isNotSynced;
              })
              .map((shop) => _addSyncMetadata(shop.toJson(), 'shop'))
              .toList();
          
          debugPrint('📤 SHOPS: ${unsyncedData.length}/$totalShops non synchronisés');
          
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
        
        case 'sims':
          // Récupérer toutes les SIMs depuis LocalDB
          final allSims = await LocalDB.instance.getAllSims();
          debugPrint('📱 SIMS: Total SIMs en mémoire: ${allSims.length}');
          
          // DIAGNOSTIC DÉTAILLÉ
          if (allSims.isEmpty) {
            debugPrint('⚠️ AUCUNE SIM TROUVÉE EN LOCAL !');
            debugPrint('   Vérifiez si des SIMs ont été créées dans l\'application');
          } else {
            debugPrint('📋 Liste des SIMs trouvées:');
            for (var sim in allSims) {
              debugPrint('   - SIM ID: ${sim.id}, Numéro: ${sim.numero}, Opérateur: ${sim.operateur}, isSynced: ${sim.isSynced}, Shop: ${sim.shopId}');
            }
          }
          
          // Filtrer uniquement les SIMs non synchronisées
          final simsToSync = allSims.where((sim) => sim.isSynced != true).toList();
          
          debugPrint('📤 SIMS: ${simsToSync.length}/${allSims.length} non synchronisées');
          
          if (simsToSync.isEmpty && allSims.isNotEmpty) {
            debugPrint('ℹ️ Toutes les SIMs sont déjà synchronisées');
          } else if (simsToSync.isNotEmpty) {
            debugPrint('🔍 SIMs à synchroniser:');
            for (var sim in simsToSync) {
              debugPrint('   → ${sim.numero} (${sim.operateur}) - Solde: ${sim.soldeActuel}');
            }
          }
          
          unsyncedData = simsToSync
              .map((sim) {
                final json = _addSyncMetadata(sim.toJson(), 'sim');
                return json;
              })
              .toList();
          break;
        
        case 'virtual_transactions':
          // Récupérer toutes les transactions virtuelles depuis LocalDB
          final allVirtualTransactions = await LocalDB.instance.getAllVirtualTransactions();
          debugPrint('💰 VIRTUAL_TRANSACTIONS: Total en mémoire: ${allVirtualTransactions.length}');
          
          // Filtrer uniquement les transactions non synchronisées
          unsyncedData = allVirtualTransactions
              .where((transaction) => transaction.isSynced != true)
              .map((transaction) {
                final json = _addSyncMetadata(transaction.toJson(), 'virtual_transaction');
                debugPrint('📤 Virtual Transaction ${transaction.reference} à synchroniser: ${transaction.simNumero} - ${transaction.montantVirtuel} ${transaction.devise}');
                return json;
              })
              .toList();
          
          debugPrint('📤 VIRTUAL_TRANSACTIONS: ${unsyncedData.length}/${allVirtualTransactions.length} non synchronisées');
          break;
        
        case 'depot_clients':
          // Récupérer tous les dépôts clients depuis LocalDB
          final allDepots = await LocalDB.instance.getAllDepotsClients();
          debugPrint('📦 DEPOT_CLIENTS: Total en mémoire: ${allDepots.length}');
          
          // Filtrer uniquement les dépôts non synchronisés
          unsyncedData = allDepots
              .where((depot) => depot.isSynced != true)
              .map((depot) {
                final json = _addSyncMetadata(depot.toMap(), 'depot_client');
                debugPrint('📤 Dépôt Client ID ${depot.id} à synchroniser: SIM ${depot.simNumero} - ${depot.montant} pour ${depot.telephoneClient}');
                return json;
              })
              .toList();
          
          debugPrint('📤 DEPOT_CLIENTS: ${unsyncedData.length}/${allDepots.length} non synchronisés');
          break;
          
        case 'audit_log':
          // Récupérer les audits depuis SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final auditKeys = prefs.getKeys().where((key) => key.startsWith('audit_'));
          unsyncedData = [];
          for (var key in auditKeys) {
            final auditData = prefs.getString(key);
            if (auditData != null) {
              final json = jsonDecode(auditData);
              // Les audits sont toujours envoyés (pas de flag is_synced)
              unsyncedData.add(_addSyncMetadata(json, 'audit_log'));
            }
          }
          debugPrint('📤 AUDIT_LOG: ${unsyncedData.length} audits à synchroniser');
          break;
          
        case 'reconciliations':
          // Récupérer les réconciliations depuis SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final reconKeys = prefs.getKeys().where((key) => key.startsWith('reconciliation_'));
          unsyncedData = [];
          for (var key in reconKeys) {
            final reconData = prefs.getString(key);
            if (reconData != null) {
              final json = jsonDecode(reconData);
              if (json['is_synced'] != true) {
                unsyncedData.add(_addSyncMetadata(json, 'reconciliation'));
              }
            }
          }
          debugPrint('📤 RECONCILIATIONS: ${unsyncedData.length} réconciliations à synchroniser');
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
          // IMPORTANT: Pour les clients admin, shop_id peut être NULL
          int? shopId;
          final shopDesignation = data['shop_designation'];
          if (shopDesignation != null && shopDesignation.isNotEmpty) {
            final shops = ShopService.instance.shops;
            final shop = shops.where((s) => s.designation == shopDesignation).firstOrNull;
            if (shop != null) {
              shopId = shop.id!;
              debugPrint('🔍 Client: shop_designation "$shopDesignation" → shop_id $shopId');
            } else {
              debugPrint('⚠️ Shop "$shopDesignation" non trouvé');
            }
          } else if (data['shop_id'] != null && data['shop_id'] > 0) {
            // Utiliser shop_id directement si fourni et valide
            shopId = data['shop_id'];
          }
          // Si shopId est toujours null, c'est un client admin global (OK)
          
          // Résoudre agent_id depuis agent_username
          int? agentId;
          final agentUsername = data['agent_username'];
          if (agentUsername != null && agentUsername.isNotEmpty) {
            final agents = AgentService.instance.agents;
            final agent = agents.where((a) => a.username == agentUsername).firstOrNull;
            if (agent != null) {
              agentId = agent.id!;
              debugPrint('🔍 Client: agent_username "$agentUsername" → agent_id $agentId');
            } else {
              debugPrint('⚠️ Agent "$agentUsername" non trouvé');
            }
          } else if (data['agent_id'] != null && data['agent_id'] > 0) {
            // Utiliser agent_id directement si fourni et valide
            agentId = data['agent_id'];
          }
          
          // IMPORTANT: Créer le client avec l'ID MySQL et les IDs résolus
          final clientData = {
            ...data,
            'shop_id': shopId,  // Peut être null pour clients admin
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
          // Vérifier si la clôture existe déjà par shop_id + date_cloture
          final shopId = data['shop_id'];
          final dateCloture = data['date_cloture'];
          
          if (shopId != null && dateCloture != null) {
            final dateClotureObj = DateTime.parse(dateCloture);
            final existingCloture = await LocalDB.instance.getClotureCaisseByDate(shopId, dateClotureObj);
            
            if (existingCloture != null) {
              debugPrint('⚠️ Doublon ignoré: clôture pour shop $shopId du ${dateClotureObj.toIso8601String().split('T')[0]} existe déjà (ID: ${existingCloture.id})');
              return;
            }
          }
          
          final cloture = ClotureCaisseModel.fromJson(data);
          await LocalDB.instance.saveClotureCaisse(cloture);
          debugPrint('✅ Clôture caisse shop ${cloture.shopId} du ${cloture.dateCloture.toIso8601String().split('T')[0]} sauvegardée (ID: ${cloture.id})');
          break;
        
        case 'flots':
          // Vérifier si le flot existe déjà
          final flotId = data['id'];
          if (flotId != null) {
            final existingFlot = await LocalDB.instance.getFlotById(flotId);
            if (existingFlot != null) {
              debugPrint('⚠️ Doublon ignoré: flot ID $flotId existe déjà');
              return;
            }
          }
          
          // CRITIQUE: Résoudre shop_source_designation et shop_destination_designation si manquantes
          String? shopSourceDesignation = data['shop_source_designation'];
          String? shopDestinationDesignation = data['shop_destination_designation'];
          
          if (shopSourceDesignation == null || shopSourceDesignation.isEmpty) {
            final shopSourceId = data['shop_source_id'];
            if (shopSourceId != null) {
              final shops = ShopService.instance.shops;
              final shop = shops.where((s) => s.id == shopSourceId).firstOrNull;
              if (shop != null) {
                shopSourceDesignation = shop.designation;
                debugPrint('🔍 Flot: shop_source_id $shopSourceId → shop_source_designation "$shopSourceDesignation"');
              } else {
                debugPrint('⚠️ Shop source ID $shopSourceId non trouvé');
              }
            }
          }
          
          if (shopDestinationDesignation == null || shopDestinationDesignation.isEmpty) {
            final shopDestinationId = data['shop_destination_id'];
            if (shopDestinationId != null) {
              final shops = ShopService.instance.shops;
              final shop = shops.where((s) => s.id == shopDestinationId).firstOrNull;
              if (shop != null) {
                shopDestinationDesignation = shop.designation;
                debugPrint('🔍 Flot: shop_destination_id $shopDestinationId → shop_destination_designation "$shopDestinationDesignation"');
              } else {
                debugPrint('⚠️ Shop destination ID $shopDestinationId non trouvé');
              }
            }
          }
          
          // Créer le flot avec les désignations résolues
          final flotData = {
            ...data,
            'shop_source_designation': shopSourceDesignation,
            'shop_destination_designation': shopDestinationDesignation,
          };
          final flot = flot_model.FlotModel.fromJson(flotData);
          
          // Sauvegarder le flot
          // DEPRECATED: Les FLOTs sont maintenant des OperationModel avec type=flotShopToShop
          // Ils sont synchronisés via la table 'operations', donc on ignore cette entrée
          debugPrint('⚠️ Flot ID ${flot.id} ignoré - Les FLOTs sont maintenant synchronisés via table operations');
          // await LocalDB.instance.saveFlot(flot); // <-- COMMENTÉ pour éviter les doublons
          // debugPrint('✅ Flot ID ${flot.id} sauvegardé: ${flot.shopSourceDesignation} → ${flot.shopDestinationDesignation} - ${flot.montant} ${flot.devise}');
          break;
        
        case 'operations':
          // Vérifier si l'opération existe déjà
          final opId = data['id'];
          if (opId != null) {
            final existingOp = await LocalDB.instance.getOperationById(opId);
            if (existingOp != null) {
              debugPrint('⚠️ Doublon ignoré: operation ID $opId existe déjà');
              return;
            }
          }
          
          // Créer et sauvegarder l'opération
          final operation = OperationModel.fromJson(data);
          await LocalDB.instance.saveOperation(operation);
          debugPrint('✅ Opération ID ${operation.id} sauvegardée: ${operation.type.name} - ${operation.montantNet} ${operation.devise}');
          break;
          
        case 'sims':
          // Créer et sauvegarder la SIM (appelé depuis _processRemoteChanges)
          final sim = SimModel.fromJson(data);
          await LocalDB.instance.saveSim(sim);
          debugPrint('✅ SIM ID ${sim.id} sauvegardée: ${sim.numero} - ${sim.operateur} - Solde: ${sim.soldeActuel}');
          break;
          
        case 'virtual_transactions':
          // Vérifier si la transaction existe déjà
          final vtId = data['id'];
          if (vtId != null) {
            final existingVt = await LocalDB.instance.getVirtualTransactionById(vtId);
            if (existingVt != null) {
              debugPrint('⚠️ Doublon ignoré: Transaction virtuelle ID $vtId existe déjà');
              return;
            }
          }
          
          // Créer et sauvegarder la transaction virtuelle
          final vt = VirtualTransactionModel.fromJson(data);
          await LocalDB.instance.saveVirtualTransaction(vt);
          debugPrint('✅ Transaction virtuelle ID ${vt.id} sauvegardée: ${vt.reference} - ${vt.simNumero} - ${vt.montantVirtuel} ${vt.devise}');
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
          // CRITIQUE: Résoudre shop_source_designation et shop_destination_designation si manquantes
          String? shopSourceDesignation = data['shop_source_designation'];
          String? shopDestinationDesignation = data['shop_destination_designation'];
          
          if (shopSourceDesignation == null || shopSourceDesignation.isEmpty) {
            final shopSourceId = data['shop_source_id'];
            if (shopSourceId != null) {
              final shops = ShopService.instance.shops;
              final shop = shops.where((s) => s.id == shopSourceId).firstOrNull;
              if (shop != null) {
                shopSourceDesignation = shop.designation;
                debugPrint('🔍 Flot UPDATE: shop_source_id $shopSourceId → shop_source_designation "$shopSourceDesignation"');
              } else {
                debugPrint('⚠️ Shop source ID $shopSourceId non trouvé');
              }
            }
          }
          
          if (shopDestinationDesignation == null || shopDestinationDesignation.isEmpty) {
            final shopDestinationId = data['shop_destination_id'];
            if (shopDestinationId != null) {
              final shops = ShopService.instance.shops;
              final shop = shops.where((s) => s.id == shopDestinationId).firstOrNull;
              if (shop != null) {
                shopDestinationDesignation = shop.designation;
                debugPrint('🔍 Flot UPDATE: shop_destination_id $shopDestinationId → shop_destination_designation "$shopDestinationDesignation"');
              } else {
                debugPrint('⚠️ Shop destination ID $shopDestinationId non trouvé');
              }
            }
          }
          
          // Créer le flot avec les désignations résolues
          final flotData = {
            ...data,
            'shop_source_designation': shopSourceDesignation,
            'shop_destination_designation': shopDestinationDesignation,
          };
          final flot = flot_model.FlotModel.fromJson(flotData);
          // DEPRECATED: Les FLOTs sont maintenant des OperationModel avec type=flotShopToShop
          // Ils sont synchronisés via la table 'operations', donc on ignore cette mise à jour
          debugPrint('⚠️ Flot ID ${flot.id} ignoré - Les FLOTs sont maintenant synchronisés via table operations');
          // await LocalDB.instance.saveFlot(flot); // <-- COMMENTÉ pour éviter les doublons
          // debugPrint('✅ Flot ID ${flot.id} mis à jour');
          break;
          
        case 'sims':
          // Mettre à jour la SIM
          final sim = SimModel.fromJson(data);
          await LocalDB.instance.updateSim(sim);
          debugPrint('✅ SIM ID ${sim.id} mise à jour: ${sim.numero} - ${sim.operateur} - Solde: ${sim.soldeActuel}');
          break;
          
        case 'virtual_transactions':
          // Mettre à jour la transaction virtuelle
          final vt = VirtualTransactionModel.fromJson(data);
          await LocalDB.instance.updateVirtualTransaction(vt);
          debugPrint('✅ Transaction virtuelle ID ${vt.id} mise à jour: ${vt.reference} - ${vt.simNumero}');
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
            // ⚠️ IMPORTANT: Ne PAS utiliser ShopService.updateShop() ici car cela redéclenche la sync!
            // Mettre à jour directement dans LocalDB sans passer par ShopService
            final prefs = await LocalDB.instance.database;
            final shopData = prefs.getString('shop_$entityId');
            if (shopData != null) {
              final shopJson = jsonDecode(shopData);
              shopJson['is_synced'] = true;
              shopJson['synced_at'] = now.toIso8601String();
              await prefs.setString('shop_$entityId', jsonEncode(shopJson));
              debugPrint('✅ Shop ID $entityId marqué comme synchronisé dans LocalDB');
              
              // Mettre à jour également le cache en mémoire de ShopService
              final shop = ShopService.instance.getShopById(entityId);
              if (shop != null) {
                final index = ShopService.instance.shops.indexWhere((s) => s.id == entityId);
                if (index != -1) {
                  final updatedShop = shop.copyWith(
                    isSynced: true,
                    syncedAt: now,
                  );
                  ShopService.instance.shops[index] = updatedShop;
                  debugPrint('✅ Shop ID $entityId mis à jour dans le cache mémoire');
                }
              }
            } else {
              debugPrint('⚠️ Shop ID $entityId non trouvé dans LocalDB pour marquage sync');
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
            // Utiliser directement la clé avec l'ID de la clôture
            final clotureKey = 'cloture_caisse_$entityId';
            final clotureData = prefs.getString(clotureKey);
            
            if (clotureData != null) {
              final clotureJson = jsonDecode(clotureData);
              clotureJson['is_synced'] = true;
              clotureJson['synced_at'] = now.toIso8601String();
              await prefs.setString(clotureKey, jsonEncode(clotureJson));
              debugPrint('✅ Clôture ID $entityId marquée comme synchronisée');
            } else {
              debugPrint('⚠️ Clôture ID $entityId non trouvée pour marquage sync (clé: $clotureKey)');
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
          
          case 'sims':
            final prefs = await LocalDB.instance.database;
            final simData = prefs.getString('sim_$entityId');
            if (simData != null) {
              final simJson = jsonDecode(simData);
              simJson['is_synced'] = true;
              simJson['synced_at'] = now.toIso8601String();
              await prefs.setString('sim_$entityId', jsonEncode(simJson));
            }
            break;
          
          case 'virtual_transactions':
            final prefs = await LocalDB.instance.database;
            final vtData = prefs.getString('virtual_transaction_$entityId');
            if (vtData != null) {
              final vtJson = jsonDecode(vtData);
              vtJson['is_synced'] = true;
              vtJson['synced_at'] = now.toIso8601String();
              await prefs.setString('virtual_transaction_$entityId', jsonEncode(vtJson));
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
      final baseUrl = (await _baseUrl).trim();
      
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
  
  /// ========== SYNCHRONISATION LENTE (PERSONNEL) ==========
  /// Démarre la synchronisation automatique pour les données de personnel
  /// Intervalle: toutes les 10 minutes (plus lent car moins critique)
  void startSlowSync() {
    stopSlowSync(); // Arrêter tout timer existant
    
    debugPrint('🐢⏰ Démarrage synchronisation lente PERSONNEL (intervalle: ${_slowSyncInterval.inMinutes} min)');
    debugPrint('🔍 État: isAutoSyncEnabled=$_isAutoSyncEnabled, isOnline=$_isOnline, isSyncing=$_isSyncing');
    
    _slowSyncTimer = Timer.periodic(_slowSyncInterval, (timer) async {
      debugPrint('⏰ [SLOW SYNC] Timer déclenché...');
      
      if (_isAutoSyncEnabled && !_isSyncing && _isOnline) {
        debugPrint('🔄 [🕒 ${DateTime.now().toIso8601String()}] Sync lente PERSONNEL');
        
        await syncPersonnelData();
        
        _lastSlowSyncTime = DateTime.now();
      } else {
        debugPrint('⏸️ Sync lente ignorée (conditions non remplies)');
      }
    });
  }
  
  /// Arrête la synchronisation lente
  void stopSlowSync() {
    if (_slowSyncTimer != null) {
      debugPrint('⏸️ Arrêt synchronisation lente PERSONNEL');
      _slowSyncTimer?.cancel();
      _slowSyncTimer = null;
    }
  }
  
  /// Synchronise les données de personnel (méthode spécialisée)
  /// Utile pour une sync lente toutes les 10 minutes
  Future<void> syncPersonnelData() async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours, ignoré');
      return;
    }
    
    try {
      debugPrint('🐢 Début sync lente PERSONNEL...');
      
      final result = await PersonnelSyncService.instance.syncPersonnelData();
      
      if (result) {
        debugPrint('✅ Sync PERSONNEL terminée avec succès');
      } else {
        debugPrint('⚠️ Sync PERSONNEL terminée avec erreurs');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la sync PERSONNEL: $e');
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
      
      // 0. SYNC QUEUE: Synchroniser les opérations en file d'attente (transferts, etc.)
      try {
        debugPrint('📋 Sync QUEUE OPERATIONS (transferts, etc.)...');
        await syncPendingData();
        debugPrint('✅ Queue opérations synchronisée');
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur sync queue opérations: $e');
        errorCount++;
      }
      
      // 0b. SYNC QUEUE FLOTS: Synchroniser les flots en file d'attente
      try {
        debugPrint('📋 Sync QUEUE FLOTS...');
        await syncPendingFlots();
        debugPrint('✅ Queue flots synchronisée');
        successCount++;
      } catch (e) {
        debugPrint('❌ Erreur sync queue flots: $e');
        errorCount++;
      }
      
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
  /// priority: 0 = haute, 1 = moyenne, 2 = basse
  Future<void> queueOperation(Map<String, dynamic> operation, {int priority = 1}) async {
    _addOperationToQueue(operation, priority: priority);
    
    // Sauvegarder dans shared_preferences pour persistance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_operations', jsonEncode(_pendingOperations));
    
    debugPrint('📋 Opération mise en file d\'attente (total: $_pendingSyncCount, priorité: $priority)');
  }
  
  /// Ajoute un flot à la file d'attente (mode offline)
  Future<void> queueFlot(Map<String, dynamic> flot) async {
    _pendingFlots.add(flot);
    _pendingFlotsCount = _pendingFlots.length;
    
    // Sauvegarder dans shared_preferences pour persistance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_flots', jsonEncode(_pendingFlots));
    
    debugPrint('📪 Flot mis en file d\'attente (total: $_pendingFlotsCount)');
  }
  
  /// Charge les opérations en attente depuis le stockage persistant
  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_operations');
      
      if (pendingData != null && pendingData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(pendingData);
        _pendingOperations.clear();
        _pendingOperations.addAll(decoded.cast<Map<String, dynamic>>());
        _pendingSyncCount = _pendingOperations.length;
        
        debugPrint('📋 ${_pendingOperations.length} opération(s) en attente chargée(s) depuis le stockage');
      } else {
        debugPrint('✅ Aucune opération en attente dans le stockage');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement opérations en attente: $e');
      _pendingOperations.clear();
      _pendingSyncCount = 0;
    }
  }
  
  /// Charge les flots en attente depuis le stockage persistant
  Future<void> _loadPendingFlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_flots');
      
      if (pendingData != null && pendingData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(pendingData);
        _pendingFlots.clear();
        _pendingFlots.addAll(decoded.cast<Map<String, dynamic>>());
        _pendingFlotsCount = _pendingFlots.length;
        
        debugPrint('📪 ${_pendingFlots.length} flot(s) en attente chargé(s) depuis le stockage');
      } else {
        debugPrint('✅ Aucun flot en attente dans le stockage');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement flots en attente: $e');
      _pendingFlots.clear();
      _pendingFlotsCount = 0;
    }
  }
  
  /// Synchronise les opérations en attente (appelé lors du retour en ligne ou manuellement depuis RobustSyncService)
  Future<void> syncPendingData() async {
    if (_pendingOperations.isEmpty) {
      debugPrint('✅ Aucune donnée en attente à synchroniser');
      return;
    }
    
    // Nettoyer les anciennes opérations
    _cleanupOldPendingOperations();
    
    // Trier par priorité
    _sortPendingOperationsByPriority();
    
    debugPrint('🔄 Synchronisation de ${_pendingOperations.length} opérations en attente (triées par priorité)...');
    
    int synced = 0;
    final List<Map<String, dynamic>> failedOperations = [];
    
    // Créer une copie des opérations à synchroniser
    final operationsToSync = List<Map<String, dynamic>>.from(_pendingOperations);
    
    for (final operation in operationsToSync) {
      try {
        // Log détaillé de l'opération avant upload
        debugPrint('📤 Upload opération: code_ops=${operation['code_ops']}, type=${operation['type']}, montant=${operation['montant_brut']}');
        debugPrint('   Détails: agent_id=${operation['agent_id']}, shop_source_id=${operation['shop_source_id']}, client_id=${operation['client_id']}');
        debugPrint('   Statut: ${operation['statut']}, Mode: ${operation['mode_paiement']}');
        
        // Récupérer l'URL de base (IMPORTANT: _baseUrl est async)
        final baseUrl = (await _baseUrl).trim();
        
        // Préparer les données à envoyer
        final payload = {
          'entities': [operation],
          'user_id': operation['lastModifiedBy'] ?? operation['last_modified_by'] ?? 'offline_user',
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        final jsonData = jsonEncode(payload);
        
        // Préparer les headers
        final headers = {
          'Content-Type': 'application/json',
        };
        
        // Ajouter l'en-tête de compression si activée
        if (SyncConfig.enableCompression) {
          headers['Content-Encoding'] = 'gzip';
        }
        
        // Uploader l'opération
        final response = await http.post(
          Uri.parse('$baseUrl/operations/upload.php'),
          headers: headers,
          body: jsonData,
        ).timeout(_syncTimeout);
        
        debugPrint('📡 Réponse serveur: HTTP ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          debugPrint('📄 Contenu réponse: $result');
          
          if (result['success'] == true) {
            synced++;
            _pendingOperations.remove(operation);
            debugPrint('✅ Opération ${operation['code_ops']} synchronisée avec succès');
            
            // IMPORTANT: Marquer l'opération comme synchronisée dans LocalDB
            // CLÉ UNIQUE: code_ops
            try {
              final codeOps = operation['code_ops'];
              if (codeOps != null && codeOps.isNotEmpty) {
                final localOp = await LocalDB.instance.getOperationByCodeOps(codeOps);
                if (localOp != null) {
                  final syncedOp = localOp.copyWith(
                    isSynced: true,
                    syncedAt: DateTime.now(),
                  );
                  await LocalDB.instance.updateOperation(syncedOp);
                  debugPrint('💾 Opération code_ops=$codeOps marquée comme synchronisée dans LocalDB');
                } else {
                  debugPrint('⚠️ Opération code_ops=$codeOps non trouvée dans LocalDB');
                }
              }
            } catch (e) {
              debugPrint('⚠️ Erreur marquage sync LocalDB: $e');
            }
          } else {
            debugPrint('❌ Échec sync opération ${operation['code_ops']}: ${result['message']}');
            failedOperations.add(operation);
          }
        } else {
          debugPrint('❌ Erreur HTTP ${response.statusCode} pour opération ${operation['code_ops']}');
          debugPrint('   Body: ${response.body}');
          failedOperations.add(operation);
        }
      } catch (e) {
        debugPrint('❌ Erreur sync opération ${operation['code_ops']}: $e');
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
    
    // IMPORTANT: NE PAS appeler syncAll() ici pour éviter les boucles infinies
    // La synchronisation complète sera gérée par RobustSyncService ou manuellement
  }
  
  /// Synchronise les flots en attente (appelé lors du retour en ligne ou manuellement depuis RobustSyncService)
  Future<void> syncPendingFlots() async {
    if (_pendingFlots.isEmpty) {
      debugPrint('✅ Aucun flot en attente à synchroniser');
      return;
    }
    
    // Nettoyer les anciens flots
    _cleanupOldPendingFlots();
    
    // Trier par priorité
    _sortPendingFlotsByPriority();
    
    debugPrint('🔄 Synchronisation de ${_pendingFlots.length} flots en attente (triés par priorité)...');
    
    int synced = 0;
    final List<Map<String, dynamic>> failedFlots = [];
    
    // Créer une copie des flots à synchroniser
    final flotsToSync = List<Map<String, dynamic>>.from(_pendingFlots);
    
    for (final flot in flotsToSync) {
      try {
        // Récupérer l'URL de base (IMPORTANT: _baseUrl est async)
        final baseUrl = (await _baseUrl).trim();
        
        // Préparer les données à envoyer
        final payload = {
          'entities': [flot],
          'user_id': flot['lastModifiedBy'] ?? 'offline_user',
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        final jsonData = jsonEncode(payload);
        
        // Préparer les headers
        final headers = {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        };
        
        // Ajouter l'en-tête de compression si activée
        if (SyncConfig.enableCompression) {
          headers['Content-Encoding'] = 'gzip';
        }
        
        // Uploader le flot
        final response = await http.post(
          Uri.parse('$baseUrl/flots/upload.php'),
          headers: headers,
          body: jsonData,
        ).timeout(_syncTimeout);
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            synced++;
            _pendingFlots.remove(flot);
            debugPrint('✅ Flot ${flot['id']} synchronisé avec succès');
            
            // IMPORTANT: Marquer le flot comme synchronisé dans LocalDB
            // CLÉ UNIQUE: reference
            try {
              final reference = flot['reference'];
              if (reference != null && reference.isNotEmpty) {
                final localFlot = await LocalDB.instance.getFlotByReference(reference);
                if (localFlot != null) {
                  final syncedFlot = localFlot.copyWith(
                    isSynced: true,
                    syncedAt: DateTime.now(),
                  );
                  // DEPRECATED: Les FLOTs sont maintenant des OperationModel avec type=flotShopToShop
                  // Ils sont synchronisés via la table 'operations', donc on ignore ce marquage
                  debugPrint('⚠️ Flot reference=$reference ignoré - Les FLOTs sont maintenant synchronisés via table operations');
                  // await LocalDB.instance.saveFlot(syncedFlot); // <-- COMMENTÉ pour éviter les doublons
                  // debugPrint('💾 Flot reference=$reference marqué comme synchronisé dans LocalDB');
                } else {
                  debugPrint('⚠️ Flot reference=$reference non trouvé dans LocalDB');
                }
              }
            } catch (e) {
              debugPrint('⚠️ Erreur marquage sync flot LocalDB: $e');
            }
          } else {
            failedFlots.add(flot);
          }
        } else {
          failedFlots.add(flot);
        }
      } catch (e) {
        debugPrint('❌ Erreur sync flot: $e');
        failedFlots.add(flot);
      }
    }
    
    // Mettre à jour le compteur
    _pendingFlotsCount = _pendingFlots.length;
    
    // Sauvegarder les flots non synchronisés
    final prefs = await SharedPreferences.getInstance();
    if (_pendingFlots.isEmpty) {
      await prefs.remove('pending_flots');
    } else {
      await prefs.setString('pending_flots', jsonEncode(_pendingFlots));
    }
    
    debugPrint('✅ Synchronisation flots terminée: $synced réussies, ${failedFlots.length} échouées');
    
    // IMPORTANT: NE PAS appeler syncAll() ici pour éviter les boucles infinies
    // La synchronisation complète sera gérée par RobustSyncService ou manuellement
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

/// Stratégies de résolution de conflits
enum ConflictResolutionStrategy {
  /// La version la plus récente gagne
  lastModifiedWins,
  
  /// Fusionner les champs modifiés
  mergeFields,
  
  /// Nécessite une décision utilisateur
  userChoice,
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
  final String tableName;
  final String userId;

  ConflictInfo({
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
    required this.tableName,
    required this.userId,
  });
}
