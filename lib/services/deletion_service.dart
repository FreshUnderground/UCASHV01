import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/deletion_request_model.dart';
import '../models/operation_model.dart';
import '../models/operation_corbeille_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';

/// Service de gestion des suppressions d'opérations avec validation en 2 étapes
/// 
/// Workflow:
/// 1. Admin crée une demande de suppression → en_attente
/// 2. Agent valide ou refuse la demande
/// 3. Si validée: opération déplacée vers corbeille + suppression locale et serveur
/// 4. Possibilité de restauration depuis la corbeille
/// 
/// Synchronisation automatique toutes les 2 minutes
class DeletionService extends ChangeNotifier {
  static final DeletionService _instance = DeletionService._internal();
  factory DeletionService() => _instance;
  static DeletionService get instance => _instance;
  
  DeletionService._internal();

  // Listes en mémoire
  List<DeletionRequestModel> _deletionRequests = [];
  List<OperationCorbeilleModel> _corbeille = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Timer pour synchronisation automatique toutes les 2 minutes
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = false;
  DateTime? _lastSyncTime;
  
  // Getters
  List<DeletionRequestModel> get deletionRequests => _deletionRequests;
  List<OperationCorbeilleModel> get corbeille => _corbeille;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  /// Obtenir les demandes en attente (pour l'agent)
  List<DeletionRequestModel> get pendingRequests =>
      _deletionRequests.where((r) => r.statut == DeletionRequestStatus.enAttente).toList();
  
  /// Obtenir les opérations non restaurées de la corbeille
  List<OperationCorbeilleModel> get activeTrash =>
      _corbeille.where((c) => !c.isRestored).toList();

  // =========================================================================
  // AUTO-SYNC TIMER (Synchronisation automatique toutes les 2 minutes)
  // =========================================================================
  
  /// Démarrer la synchronisation automatique toutes les 2 minutes
  void startAutoSync() {
    if (_isAutoSyncEnabled) {
      debugPrint('🔄 Auto-sync déjà activé');
      return;
    }
    
    _isAutoSyncEnabled = true;
    debugPrint('🔄 Démarrage auto-sync (toutes les 2 minutes)');
    
    // Sync immédiat au démarrage
    syncAll();
    
    // Timer répétitif toutes les 2 minutes (120 secondes)
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      debugPrint('🔄 [Auto-Sync] Synchronisation automatique...');
      syncAll();
    });
    
    notifyListeners();
  }
  
  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _isAutoSyncEnabled = false;
    debugPrint('⏹️ Auto-sync arrêté');
    notifyListeners();
  }
  
  /// Synchroniser toutes les données (demandes + corbeille)
  Future<void> syncAll() async {
    try {
      await Future.wait([
        syncDeletionRequests(),
        syncCorbeille(),
      ]);
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ [Auto-Sync] Synchronisation complète à $_lastSyncTime');
    } catch (e) {
      debugPrint('❌ [Auto-Sync] Erreur: $e');
    }
  }

  // =========================================================================
  // ADMIN: Créer une demande de suppression
  // =========================================================================
  
  /// Créer une demande de suppression (Admin uniquement)
  Future<bool> createDeletionRequest({
    required OperationModel operation,
    required int adminId,
    required String adminName,
    String? reason,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final request = DeletionRequestModel(
        codeOps: operation.codeOps,
        operationId: operation.id,
        operationType: operation.typeLabel,
        montant: operation.montantNet,
        devise: operation.devise,
        destinataire: operation.destinataire,
        expediteur: operation.clientNom,
        clientNom: operation.clientNom,
        requestedByAdminId: adminId,
        requestedByAdminName: adminName,
        requestDate: DateTime.now(),
        reason: reason,
        statut: DeletionRequestStatus.enAttente,
        lastModifiedBy: 'admin_$adminName',
      );
      
      // Sauvegarder localement
      await _saveDeletionRequestLocal(request);
      
      // Synchroniser immédiatement avec le serveur
      await _uploadDeletionRequest(request);
      
      // Recharger
      await loadDeletionRequests();
      
      debugPrint('✅ Demande de suppression créée pour ${operation.codeOps}');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur création demande: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // AGENT: Valider ou refuser une demande de suppression
  // =========================================================================
  
  /// Valider une demande de suppression (Agent)
  Future<bool> validateDeletionRequest({
    required String codeOps,
    required int agentId,
    required String agentName,
    required bool approve, // true = approuver, false = refuser
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // ✅ NOUVEAU: Détecter si en ligne ou hors ligne
      bool syncedToServer = false;
      
      try {
        // Tenter l'appel API serveur
        final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/validate.php';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code_ops': codeOps,
            'validated_by_agent_id': agentId,
            'validated_by_agent_name': agentName,
            'action': approve ? 'approve' : 'reject',
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            syncedToServer = true;
            debugPrint('✅ Validation synchronisée avec le serveur');
          }
        }
      } catch (e) {
        // 💾 FALLBACK OFFLINE: Continuer en mode local
        debugPrint('⚠️ Serveur non accessible, mode offline activé: $e');
        syncedToServer = false;
      }
      
      // ✅ TOUJOURS exécuter localement (online ou offline)
      
      // Si approuvé, supprimer l'opération localement
      if (approve) {
        await _deleteOperationLocally(codeOps);
        debugPrint('🗑️ Opération supprimée localement: $codeOps');
      }
      
      // Mettre à jour la demande localement
      await _updateDeletionRequestLocal(
        codeOps: codeOps,
        validatedByAgentId: agentId,
        validatedByAgentName: agentName,
        statut: approve ? DeletionRequestStatus.validee : DeletionRequestStatus.refusee,
      );
      
      // Si synchronisé avec serveur, marquer comme tel
      if (syncedToServer) {
        await _markDeletionRequestSynced(codeOps);
      }
      
      // Recharger
      await loadDeletionRequests();
      await loadCorbeille();
      
      if (syncedToServer) {
        debugPrint('✅ Demande ${approve ? "approuvée" : "refusée"} pour $codeOps (ONLINE)');
      } else {
        debugPrint('💾 Demande ${approve ? "approuvée" : "refusée"} pour $codeOps (OFFLINE - sera sync plus tard)');
      }
      
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur validation: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // CORBEILLE: Restaurer une opération supprimée
  // =========================================================================
  
  /// Restaurer une opération depuis la corbeille
  Future<bool> restoreOperation({
    required String codeOps,
    required String restoredBy,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // ✅ NOUVEAU: Détecter si en ligne ou hors ligne
      bool syncedToServer = false;
      
      try {
        // Tenter l'appel API serveur
        final url = '${AppConfig.apiBaseUrl}/sync/corbeille/restore.php';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code_ops': codeOps,
            'restored_by': restoredBy,
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            syncedToServer = true;
            debugPrint('✅ Restauration synchronisée avec le serveur');
          }
        }
      } catch (e) {
        // 💾 FALLBACK OFFLINE: Continuer en mode local
        debugPrint('⚠️ Serveur non accessible, mode offline activé: $e');
        syncedToServer = false;
      }
      
      // ✅ TOUJOURS exécuter localement (online ou offline)
      
      // Marquer comme restauré localement
      await _markRestoredLocal(codeOps, restoredBy);
      
      // Recharger
      await loadCorbeille();
      
      if (syncedToServer) {
        debugPrint('✅ Opération restaurée: $codeOps (ONLINE)');
      } else {
        debugPrint('💾 Opération restaurée: $codeOps (OFFLINE - sera sync plus tard)');
      }
      
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur restauration: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // SYNCHRONISATION
  // =========================================================================
  
  /// Charger les demandes de suppression depuis le serveur
  Future<void> syncDeletionRequests() async {
    try {
      await loadDeletionRequests();
      
      // Upload les demandes non synchronisées
      final unsyncedRequests = await _getUnsyncedDeletionRequests();
      for (final request in unsyncedRequests) {
        await _uploadDeletionRequest(request);
      }
      
    } catch (e) {
      debugPrint('❌ Erreur sync demandes: $e');
    }
  }
  
  /// Charger la corbeille depuis le serveur
  Future<void> syncCorbeille() async {
    try {
      await loadCorbeille();
    } catch (e) {
      debugPrint('❌ Erreur sync corbeille: $e');
    }
  }
  
  /// Charger les demandes de suppression
  Future<void> loadDeletionRequests() async {
    try {
      // Télécharger depuis le serveur
      final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/download.php';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          _deletionRequests = data.map((json) => DeletionRequestModel.fromJson(json)).toList();
          
          // Sauvegarder localement
          for (final request in _deletionRequests) {
            await _saveDeletionRequestLocal(request);
          }
          
          debugPrint('✅ ${_deletionRequests.length} demandes chargées');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement demandes: $e');
    }
  }
  
  /// Charger la corbeille
  Future<void> loadCorbeille() async {
    try {
      // Télécharger depuis le serveur (seulement non restaurées)
      final url = '${AppConfig.apiBaseUrl}/sync/corbeille/download.php?is_restored=0';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          _corbeille = data.map((json) => OperationCorbeilleModel.fromJson(json)).toList();
          
          // Sauvegarder localement
          for (final item in _corbeille) {
            await _saveCorbeilleLocal(item);
          }
          
          debugPrint('✅ ${_corbeille.length} éléments dans la corbeille');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement corbeille: $e');
    }
  }

  // =========================================================================
  // MÉTHODES PRIVÉES
  // =========================================================================
  
  /// Upload une demande vers le serveur
  Future<void> _uploadDeletionRequest(DeletionRequestModel request) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/upload.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([request.toJson()]),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Marquer comme synchronisé localement
          await _markDeletionRequestSynced(request.codeOps);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur upload demande: $e');
    }
  }
  
  /// Sauvegarder une demande localement
  Future<void> _saveDeletionRequestLocal(DeletionRequestModel request) async {
    final prefs = await LocalDB.instance.database;
    final key = 'deletion_request_${request.codeOps}';
    await prefs.setString(key, jsonEncode(request.toJson()));
  }
  
  /// Mettre à jour une demande localement
  Future<void> _updateDeletionRequestLocal({
    required String codeOps,
    required int validatedByAgentId,
    required String validatedByAgentName,
    required DeletionRequestStatus statut,
  }) async {
    final prefs = await LocalDB.instance.database;
    final key = 'deletion_request_$codeOps';
    final existing = prefs.getString(key);
    
    if (existing != null) {
      final request = DeletionRequestModel.fromJson(jsonDecode(existing));
      final updated = request.copyWith(
        validatedByAgentId: validatedByAgentId,
        validatedByAgentName: validatedByAgentName,
        validationDate: DateTime.now(),
        statut: statut,
        lastModifiedAt: DateTime.now(),
      );
      await prefs.setString(key, jsonEncode(updated.toJson()));
    }
  }
  
  /// Marquer une demande comme synchronisée
  Future<void> _markDeletionRequestSynced(String codeOps) async {
    final prefs = await LocalDB.instance.database;
    final key = 'deletion_request_$codeOps';
    final existing = prefs.getString(key);
    
    if (existing != null) {
      final request = DeletionRequestModel.fromJson(jsonDecode(existing));
      final updated = request.copyWith(isSynced: true, syncedAt: DateTime.now());
      await prefs.setString(key, jsonEncode(updated.toJson()));
    }
  }
  
  /// Obtenir les demandes non synchronisées
  Future<List<DeletionRequestModel>> _getUnsyncedDeletionRequests() async {
    final prefs = await LocalDB.instance.database;
    final keys = prefs.getKeys().where((k) => k.startsWith('deletion_request_'));
    final unsynced = <DeletionRequestModel>[];
    
    for (final key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        final request = DeletionRequestModel.fromJson(jsonDecode(data));
        if (!request.isSynced) {
          unsynced.add(request);
        }
      }
    }
    
    return unsynced;
  }
  
  /// Supprimer une opération localement ET la sauvegarder dans la corbeille
  Future<void> _deleteOperationLocally(String codeOps) async {
    final operation = await LocalDB.instance.getOperationByCodeOps(codeOps);
    if (operation != null && operation.id != null) {
      // ✅ IMPORTANT: Sauvegarder dans la corbeille AVANT de supprimer
      final corbeilleItem = OperationCorbeilleModel(
        originalOperationId: operation.id,
        codeOps: operation.codeOps,
        type: operation.type.name,  // Type de l'opération
        shopSourceId: operation.shopSourceId,
        shopSourceDesignation: operation.shopSourceDesignation,
        shopDestinationId: operation.shopDestinationId,
        shopDestinationDesignation: operation.shopDestinationDesignation,
        agentId: operation.agentId ?? 0,
        agentUsername: operation.agentUsername,
        clientId: operation.clientId,
        clientNom: operation.clientNom,
        montantBrut: operation.montantBrut,
        commission: operation.commission,
        montantNet: operation.montantNet,
        devise: operation.devise,
        modePaiement: operation.modePaiement.name,  // Convertir enum en string
        destinataire: operation.destinataire,
        telephoneDestinataire: operation.telephoneDestinataire,
        reference: operation.reference,
        simNumero: operation.simNumero,
        statut: operation.statut.name,
        notes: operation.notes,
        observation: operation.observation,
        dateOp: operation.dateOp,
        dateValidation: operation.dateValidation,
        createdAtOriginal: operation.createdAt,
        lastModifiedAtOriginal: operation.lastModifiedAt,
        lastModifiedByOriginal: operation.lastModifiedBy,
        deletedAt: DateTime.now(),
        isRestored: false,
        isSynced: false,  // Sera synchronisé plus tard
      );
      
      await _saveCorbeilleLocal(corbeilleItem);
      debugPrint('💾 Opération sauvegardée dans la corbeille locale: $codeOps');
      
      // Maintenant supprimer de la table operations
      await LocalDB.instance.deleteOperation(operation.id!);
      debugPrint('🗑️ Opération supprimée de LocalDB: $codeOps');
    }
  }
  
  /// Sauvegarder un élément de la corbeille localement
  Future<void> _saveCorbeilleLocal(OperationCorbeilleModel item) async {
    final prefs = await LocalDB.instance.database;
    final key = 'corbeille_${item.codeOps}';
    await prefs.setString(key, jsonEncode(item.toJson()));
  }
  
  /// Marquer comme restauré localement
  Future<void> _markRestoredLocal(String codeOps, String restoredBy) async {
    final prefs = await LocalDB.instance.database;
    final key = 'corbeille_$codeOps';
    final existing = prefs.getString(key);
    
    if (existing != null) {
      final item = OperationCorbeilleModel.fromJson(jsonDecode(existing));
      final updated = item.copyWith(
        isRestored: true,
        restoredAt: DateTime.now(),
        restoredBy: restoredBy,
      );
      await prefs.setString(key, jsonEncode(updated.toJson()));
    }
  }
  
  /// Dispose (arrêter le timer)
  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
