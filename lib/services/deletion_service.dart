import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/deletion_request_model.dart';
import '../models/operation_model.dart';
import '../models/operation_corbeille_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';
import 'operation_service.dart';

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
  
  // Queues pour les opérations en attente de synchronisation
  final List<Map<String, dynamic>> _pendingValidations = []; // {codeOps, agentId, agentName, approve}
  final List<Map<String, dynamic>> _pendingRestores = [];    // {codeOps, restoredBy}
  final List<DeletionRequestModel> _pendingCreations = [];   // Demandes non synchronisées
  
  // Getters
  List<DeletionRequestModel> get deletionRequests => _deletionRequests;
  List<OperationCorbeilleModel> get corbeille => _corbeille;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingValidationsCount => _pendingValidations.length;
  int get pendingRestoresCount => _pendingRestores.length;
  int get pendingCreationsCount => _pendingCreations.length;
  
  /// Obtenir les demandes en attente de validation admin (pour les admins)
  List<DeletionRequestModel> get adminPendingRequests {
    // Filtrer les demandes en attente de validation inter-admin
    final result = _deletionRequests.where((r) => r.statut == DeletionRequestStatus.enAttente).toList();
    debugPrint('\n========== DEMANDES ADMIN EN ATTENTE ==========');
    debugPrint('📋 Total demandes admin en attente: ${result.length}');
    for (var r in result) {
      debugPrint('   📄 CodeOps: ${r.codeOps}');
      debugPrint('      Demandé par: ${r.requestedByAdminName}');
      debugPrint('      Statut: ${r.statut.name}');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir les demandes en attente (pour l'agent)
  List<DeletionRequestModel> get pendingRequests {
    // Corriger les demandes incohérentes (validées mais avec statut enAttente)
    for (var i = 0; i < _deletionRequests.length; i++) {
      final r = _deletionRequests[i];
      // Si la demande a un validateur mais statut = enAttente, corriger
      if (r.validatedByAgentId != null && r.statut == DeletionRequestStatus.enAttente) {
        debugPrint('⚠️ Correction demande incohérente: ${r.codeOps} (validée par ${r.validatedByAgentName} mais statut=enAttente)');
        _deletionRequests[i] = r.copyWith(statut: DeletionRequestStatus.agentValidee);
        // Sauvegarder la correction
        _saveDeletionRequestLocal(_deletionRequests[i]);
      }
    }
    
    // Filtrer les demandes validées par un admin et en attente de validation agent
    final result = _deletionRequests.where((r) => r.statut == DeletionRequestStatus.adminValidee).toList();
    debugPrint('\n========== DEMANDES DE SUPPRESSION ==========');
    debugPrint('📋 Total demandes en mémoire: ${_deletionRequests.length}');
    debugPrint('📋 Demandes ADMIN_VALIDÉES (visibles agent): ${result.length}');
    for (var r in _deletionRequests) {
      debugPrint('   📄 CodeOps: ${r.codeOps}');
      debugPrint('      Statut: ${r.statut.name}');
      debugPrint('      Validé par admin: ${r.validatedByAdminName ?? "Non validé"}');
      debugPrint('      Validé par agent: ${r.validatedByAgentName ?? "Non validé"}');
      debugPrint('      isSynced: ${r.isSynced}');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir les opérations non restaurées et non synchronisées de la corbeille
  /// (Éléments en attente de sync - affichés seulement localement)
  List<OperationCorbeilleModel> get activeTrash {
    final result = _corbeille.where((c) => !c.isRestored && !c.isSynced).toList();
    debugPrint('🗑️ [activeTrash] ${result.length} éléments NON synchronisés');
    return result;
  }
  
  /// Obtenir TOUTES les opérations non restaurées de la corbeille (pour l'admin)
  /// (Inclut les éléments synchronisés - pour permettre la restauration)
  List<OperationCorbeilleModel> get allTrash {
    final result = _corbeille.where((c) => !c.isRestored).toList();
    debugPrint('🗑️ [allTrash] ${result.length} éléments au total (synced + non-synced)');
    return result;
  }

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
  
  /// Synchroniser toutes les données (demandes + corbeille + retry queue)
  Future<void> syncAll() async {
    try {
      await Future.wait([
        syncDeletionRequests(),
        syncCorbeille(),
      ]);
      
      // Upload corbeille items to server
      await _uploadCorbeilleItems();
      
      // Also retry pending operations
      await _retryPendingCreations();
      await _retryPendingValidations();
      await _retryPendingRestores();
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ [Auto-Sync] Synchronisation complète à $_lastSyncTime');
    } catch (e) {
      debugPrint('❌ [Auto-Sync] Erreur: $e');
    }
  }

  /// Valider une demande de suppression par un admin (inter-admin validation)
  Future<bool> validateAdminDeletionRequest({
    required String codeOps,
    required int validatorAdminId,
    required String validatorAdminName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 Validation inter-admin demande: $codeOps...');
      
      // 1. Mettre à jour la demande localement (immediate)
      await _updateDeletionRequestLocal(
        codeOps: codeOps,
        validatedByAdminId: validatorAdminId,
        validatedByAdminName: validatorAdminName,
        statut: DeletionRequestStatus.adminValidee,
      );
      debugPrint('✅ Demande mise à jour en LOCAL (admin validée)');
      
      // 2. Mettre à jour dans la liste en mémoire pour affichage immédiat
      final index = _deletionRequests.indexWhere((r) => r.codeOps == codeOps);
      if (index != -1) {
        _deletionRequests[index] = _deletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: DeletionRequestStatus.adminValidee,
        );
        debugPrint('✅ Demande mise à jour en MÉMOIRE (statut=${_deletionRequests[index].statut.name})');
      }
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      _syncAdminValidationInBackground(codeOps, validatorAdminId, validatorAdminName);
      
      debugPrint('✅ Demande admin-validée pour $codeOps (sync en arrière-plan)');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur validation admin: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
        isSynced: false,
      );
      
      debugPrint('🔄 Création demande pour ${operation.codeOps}...');
      
      // 1. Sauvegarder localement FIRST (immediate)
      await _saveDeletionRequestLocal(request);
      debugPrint('✅ Demande sauvegardée en LOCAL');
      
      // 2. Ajouter à la liste en mémoire pour affichage immédiat
      _deletionRequests.add(request);
      debugPrint('✅ Demande ajoutée à la liste (${_deletionRequests.length} total)');
      
      // 3. Notifier pour mettre à jour l'UI immédiatement
      notifyListeners();
      
      // 4. Synchroniser avec le serveur en BACKGROUND (non-blocking)
      _uploadDeletionRequestInBackground(request);
      
      debugPrint('✅ Demande de suppression créée pour ${operation.codeOps} (sync en arrière-plan)');
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
      
      debugPrint('🔄 Validation demande de suppression: $codeOps...');
      
      // 1. Si approuvé, supprimer l'opération localement FIRST (immediate)
      if (approve) {
        await _deleteOperationLocally(codeOps);
        debugPrint('✅ Opération supprimée en LOCAL: $codeOps');
      }
      
      // 2. SUPPRIMER la demande du stockage local (immediate)
      // Une fois validée, elle ne doit plus apparaître chez l'agent
      await _deleteDeletionRequestLocal(codeOps);
      debugPrint('✅ Demande supprimée du LOCAL (ne réapparaîtra plus)');
      
      // 3. RETIRER de la liste en mémoire pour disparition immédiate de l'UI
      final index = _deletionRequests.indexWhere((r) => r.codeOps == codeOps);
      if (index != -1) {
        // Mettre à jour le statut avant de retirer (pour la synchro serveur)
        final updated = _deletionRequests[index].copyWith(
          validatedByAgentId: agentId,
          validatedByAgentName: agentName,
          validationDate: DateTime.now(),
          statut: approve ? DeletionRequestStatus.agentValidee : DeletionRequestStatus.refusee,
        );
        
        // Retirer de la liste (disparaît immédiatement de l'UI)
        _deletionRequests.removeAt(index);
        debugPrint('✅ Demande retirée de la MÉMOIRE (disparue de la liste)');
      }
      // 4. Recharger seulement la corbeille (pas les demandes pour ne pas écraser)
      await loadCorbeille();
      
      // 4. Sync to server in BACKGROUND (non-blocking)
      _syncValidationInBackground(codeOps, agentId, agentName, approve);
      
      debugPrint('✅ Demande ${approve ? "approuvée" : "refusée"} pour $codeOps (sync en arrière-plan)');
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
      
      debugPrint('🔄 Restauration opération: $codeOps...');
      
      // 1. Marquer comme restauré localement FIRST (immediate)
      await _markRestoredLocal(codeOps, restoredBy);
      debugPrint('✅ Opération marquée comme restaurée en LOCAL');
      
      // 2. Recharger pour afficher les changements immédiatement
      await loadCorbeille();
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      _syncRestoreInBackground(codeOps, restoredBy);
      
      debugPrint('✅ Opération restaurée: $codeOps (sync en arrière-plan)');
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
          
          // NETTOYAGE: Supprimer du stockage local toutes les demandes validées/refusées
          // Cela garantit qu'elles disparaissent de la liste chez tous les agents
          final prefs = await LocalDB.instance.database;
          final localKeys = prefs.getKeys().where((k) => k.startsWith('deletion_request_')).toList();
          
          for (final key in localKeys) {
            final data = prefs.getString(key);
            if (data != null) {
              final localRequest = DeletionRequestModel.fromJson(jsonDecode(data));
              // Si la demande n'est plus en attente, la supprimer du local
              if (localRequest.statut != DeletionRequestStatus.enAttente) {
                await prefs.remove(key);
                debugPrint('🧹 Nettoyage local: ${localRequest.codeOps} (statut=${localRequest.statut.name})');
              }
            }
          }
          
          // Sauvegarder localement SEULEMENT les demandes en attente
          // (Les demandes validées/refusées ne doivent pas réapparaître chez l'agent)
          for (final request in _deletionRequests) {
            if (request.statut == DeletionRequestStatus.enAttente) {
              await _saveDeletionRequestLocal(request);
            } else {
              // Si une demande validée/refusée existe encore en local, la supprimer
              await _deleteDeletionRequestLocal(request.codeOps);
            }
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
          
          // Sauvegarder localement SEULEMENT les éléments non synchronisés
          // (Les éléments déjà synchronisés restent uniquement sur le serveur)
          for (final item in _corbeille) {
            if (!item.isSynced) {
              await _saveCorbeilleLocal(item);
            }
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
  
  /// Upload une demande vers le serveur en arrière-plan
  void _uploadDeletionRequestInBackground(DeletionRequestModel request) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/upload.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation demande serveur: ${request.codeOps}...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([request.toJson()]),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Demande ${request.codeOps} synchronisée sur le serveur');
          // Marquer comme synchronisé localement
          await _markDeletionRequestSynced(request.codeOps);
          
          // Mettre à jour dans la liste en mémoire
          final index = _deletionRequests.indexWhere((r) => r.codeOps == request.codeOps);
          if (index != -1) {
            _deletionRequests[index] = request.copyWith(isSynced: true, syncedAt: DateTime.now());
            notifyListeners();
          }
          
          // Remove from pending creations if it was there
          _pendingCreations.removeWhere((r) => r.codeOps == request.codeOps);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry');
          _addToPendingCreations(request);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry');
        _addToPendingCreations(request);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT demande: $e - Ajout à la queue de retry');
      _addToPendingCreations(request);
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [BACKGROUND] Pas d\'internet: $e - Ajout à la queue de retry');
      _addToPendingCreations(request);
    } catch (e, stackTrace) {
      debugPrint('⚠️ [BACKGROUND] Erreur upload demande: $e');
      debugPrint('Stack trace: $stackTrace');
      _addToPendingCreations(request);
    }
  }
  
  /// Sync validation admin en arrière-plan
  void _syncAdminValidationInBackground(String codeOps, int adminId, String adminName) async {
    try {
      final request = _deletionRequests.firstWhere((r) => r.codeOps == codeOps);
      
      final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/admin_validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation admin: $codeOps...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code_ops': codeOps,
          'validated_by_admin_id': adminId,
          'validated_by_admin_name': adminName,
          'validation_admin_date': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Validation admin $codeOps synchronisée sur le serveur');
          // Marquer comme synchronisé localement
          await _markDeletionRequestSynced(codeOps);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry');
          _addToPendingValidations(codeOps, adminId, adminName, true);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry');
        _addToPendingValidations(codeOps, adminId, adminName, true);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT validation admin: $e - Ajout à la queue de retry');
      _addToPendingValidations(codeOps, adminId, adminName, true);
    } on http.ClientException catch (e) {
      debugPrint("⚠️ [BACKGROUND] Pas d'internet: $e - Ajout à la queue de retry");
      _addToPendingValidations(codeOps, adminId, adminName, true);
    } catch (e, stackTrace) {
      debugPrint('⚠️ [BACKGROUND] Erreur sync validation admin: $e');
      debugPrint('Stack trace: $stackTrace');
      _addToPendingValidations(codeOps, adminId, adminName, true);
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
    int? validatedByAgentId,
    String? validatedByAgentName,
    int? validatedByAdminId,
    String? validatedByAdminName,
    DeletionRequestStatus? statut,
  }) async {
    final prefs = await LocalDB.instance.database;
    final key = 'deletion_request_$codeOps';
    final existing = prefs.getString(key);
    
    if (existing != null) {
      final request = DeletionRequestModel.fromJson(jsonDecode(existing));
      final updated = request.copyWith(
        validatedByAgentId: validatedByAgentId,
        validatedByAgentName: validatedByAgentName,
        validatedByAdminId: validatedByAdminId,
        validatedByAdminName: validatedByAdminName,
        validationDate: validatedByAgentId != null ? DateTime.now() : request.validationDate,
        validationAdminDate: validatedByAdminId != null ? DateTime.now() : request.validationAdminDate,
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
  
  /// Supprimer une demande du stockage local
  Future<void> _deleteDeletionRequestLocal(String codeOps) async {
    final prefs = await LocalDB.instance.database;
    final key = 'deletion_request_$codeOps';
    await prefs.remove(key);
    debugPrint('🗑️ Demande $codeOps supprimée du stockage local');
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
      
      // Supprimer de la table operations (LocalDB)
      await LocalDB.instance.deleteOperation(operation.id!);
      debugPrint('🗑️ Opération supprimée de LocalDB: $codeOps');
      
      // ✅ CRITICAL: Supprimer de OperationService pour mise à jour UI immédiate
      // Cela garantit que l'opération disparaît chez tous les utilisateurs (Agent A, B, Admin)
      try {
        final operationService = OperationService();
        operationService.removeOperationFromMemory(codeOps);
        debugPrint('📝 Opération retirée de OperationService (UI mise à jour)');
      } catch (e) {
        debugPrint('⚠️ Erreur suppression de OperationService: $e');
      }
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
  
  /// Upload corbeille items to server
  Future<void> _uploadCorbeilleItems() async {
    try {
      // Get unsynced corbeille items from local storage
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((k) => k.startsWith('corbeille_'));
      final unsyncedItems = <OperationCorbeilleModel>[];
      int totalItems = 0;
      int syncedCount = 0;
      
      debugPrint('🔍 [CORBEILLE] Vérification des éléments...');
      
      for (final key in keys) {
        totalItems++;
        final data = prefs.getString(key);
        if (data != null) {
          final item = OperationCorbeilleModel.fromJson(jsonDecode(data));
          if (!item.isSynced) {
            unsyncedItems.add(item);
            debugPrint('  📦 ${item.codeOps} - NON SYNC');
          } else {
            syncedCount++;
            debugPrint('  ✅ ${item.codeOps} - DÉJÀ SYNC');
          }
        }
      }
      
      debugPrint('📊 [CORBEILLE] Total: $totalItems | Synced: $syncedCount | À uploader: ${unsyncedItems.length}');
      
      if (unsyncedItems.isEmpty) {
        debugPrint('✅ [CORBEILLE] Tous les éléments sont synchronisés');
        return;
      }
      
      debugPrint('📤 [CORBEILLE] Upload de ${unsyncedItems.length} éléments...');
      
      final url = '${AppConfig.apiBaseUrl}/sync/corbeille/upload.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(unsyncedItems.map((item) => item.toJson()).toList()),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [CORBEILLE] ${result['inserted']} insérés, ${result['updated']} mis à jour');
          
          // Mark as synced locally
          for (final item in unsyncedItems) {
            final key = 'corbeille_${item.codeOps}';
            final updated = item.copyWith(isSynced: true, syncedAt: DateTime.now());
            await prefs.setString(key, jsonEncode(updated.toJson()));
          }
        } else {
          debugPrint('⚠️ [CORBEILLE] Erreur upload: ${result['message']}');
        }
      } else {
        debugPrint('⚠️ [CORBEILLE] Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [CORBEILLE] Erreur upload: $e');
    }
  }
  
  /// Upload a single corbeille item to server
  Future<void> _uploadSingleCorbeilleItem(String codeOps) async {
    try {
      debugPrint('🔍 [CORBEILLE] Recherche élément $codeOps dans le local storage...');
      
      // Get the corbeille item from local storage
      final prefs = await LocalDB.instance.database;
      final key = 'corbeille_$codeOps';
      final data = prefs.getString(key);
      
      if (data == null) {
        debugPrint('⚠️ [CORBEILLE] Élément $codeOps non trouvé en local');
        return;
      }
      
      final item = OperationCorbeilleModel.fromJson(jsonDecode(data));
      
      // Check if already synced
      if (item.isSynced) {
        debugPrint('✅ [CORBEILLE] Élément $codeOps déjà synchronisé - Skip upload');
        return;
      }
      
      debugPrint('📤 [CORBEILLE] Upload élément $codeOps... (isSynced: ${item.isSynced})');
      
      
      final url = '${AppConfig.apiBaseUrl}/sync/corbeille/upload.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode([item.toJson()]),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [CORBEILLE] Élément $codeOps uploadé (${result['inserted']} insérés)');
          
          // Mark as synced locally
          final updated = item.copyWith(isSynced: true, syncedAt: DateTime.now());
          await prefs.setString(key, jsonEncode(updated.toJson()));
        } else {
          debugPrint('⚠️ [CORBEILLE] Erreur upload $codeOps: ${result['message']}');
        }
      } else {
        debugPrint('⚠️ [CORBEILLE] Erreur HTTP ${response.statusCode} pour $codeOps');
      }
    } catch (e) {
      debugPrint('⚠️ [CORBEILLE] Erreur upload $codeOps: $e');
    }
  }
  
  // =========================================================================
  // SYNCHRONISATION EN ARRIÈRE-PLAN AVEC RETRY QUEUE
  // =========================================================================
  
  /// Sync validation to server in background
  void _syncValidationInBackground(String codeOps, int agentId, String agentName, bool approve) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation serveur: $codeOps...');
      
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
          debugPrint('✅ [BACKGROUND] Validation $codeOps synchronisée sur le serveur');
          // Remove from pending queue if it was there
          _pendingValidations.removeWhere((v) => v['codeOps'] == codeOps);
          // Mark as synced
          await _markDeletionRequestSynced(codeOps);
          
          // If approved, also upload the corbeille item
          if (approve) {
            await _uploadSingleCorbeilleItem(codeOps);
          }
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry');
          _addToPendingValidations(codeOps, agentId, agentName, approve);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry');
        _addToPendingValidations(codeOps, agentId, agentName, approve);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT validation: $e - Ajout à la queue de retry');
      _addToPendingValidations(codeOps, agentId, agentName, approve);
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [BACKGROUND] Pas d\'internet (ClientException): $e - Ajout à la queue de retry');
      _addToPendingValidations(codeOps, agentId, agentName, approve);
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur validation: $e - Ajout à la queue de retry');
      _addToPendingValidations(codeOps, agentId, agentName, approve);
    }
  }
  
  /// Sync restore to server in background
  void _syncRestoreInBackground(String codeOps, String restoredBy) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/corbeille/restore.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation restauration serveur: $codeOps...');
      
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
          debugPrint('✅ [BACKGROUND] Restauration $codeOps synchronisée sur le serveur');
          // Remove from pending queue if it was there
          _pendingRestores.removeWhere((r) => r['codeOps'] == codeOps);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry');
          _addToPendingRestores(codeOps, restoredBy);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry');
        _addToPendingRestores(codeOps, restoredBy);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT restauration: $e - Ajout à la queue de retry');
      _addToPendingRestores(codeOps, restoredBy);
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [BACKGROUND] Pas d\'internet (ClientException): $e - Ajout à la queue de retry');
      _addToPendingRestores(codeOps, restoredBy);
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur restauration: $e - Ajout à la queue de retry');
      _addToPendingRestores(codeOps, restoredBy);
    }
  }
  
  /// Add validation to pending queue
  void _addToPendingValidations(String codeOps, int agentId, String agentName, bool approve) {
    // Check if already in queue
    final exists = _pendingValidations.any((v) => v['codeOps'] == codeOps);
    if (!exists) {
      _pendingValidations.add({
        'codeOps': codeOps,
        'agentId': agentId,
        'agentName': agentName,
        'approve': approve,
      });
      debugPrint('📋 Validation ajoutée à la queue de retry: $codeOps (Total: ${_pendingValidations.length})');
    }
  }
  
  /// Add restore to pending queue
  void _addToPendingRestores(String codeOps, String restoredBy) {
    // Check if already in queue
    final exists = _pendingRestores.any((r) => r['codeOps'] == codeOps);
    if (!exists) {
      _pendingRestores.add({
        'codeOps': codeOps,
        'restoredBy': restoredBy,
      });
      debugPrint('📋 Restauration ajoutée à la queue de retry: $codeOps (Total: ${_pendingRestores.length})');
    }
  }
  
  /// Add creation to pending queue
  void _addToPendingCreations(DeletionRequestModel request) {
    // Check if already in queue
    final exists = _pendingCreations.any((r) => r.codeOps == request.codeOps);
    if (!exists) {
      _pendingCreations.add(request);
      debugPrint('📋 Création demande ajoutée à la queue de retry: ${request.codeOps} (Total: ${_pendingCreations.length})');
    }
  }
  
  /// Retry all pending creations
  Future<void> _retryPendingCreations() async {
    if (_pendingCreations.isEmpty) {
      return;
    }
    
    debugPrint('🔄 [RETRY] Tentative de synchronisation de ${_pendingCreations.length} demandes créations en attente...');
    
    final creationsToRetry = List<DeletionRequestModel>.from(_pendingCreations);
    
    for (final request in creationsToRetry) {
      try {
        final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/upload.php';
        debugPrint('🔄 [RETRY] Création demande: ${request.codeOps}...');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([request.toJson()]),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            debugPrint('✅ [RETRY] Demande ${request.codeOps} réussie sur le serveur');
            _pendingCreations.removeWhere((r) => r.codeOps == request.codeOps);
            await _markDeletionRequestSynced(request.codeOps);
            
            // Update in memory list
            final index = _deletionRequests.indexWhere((r) => r.codeOps == request.codeOps);
            if (index != -1) {
              _deletionRequests[index] = request.copyWith(isSynced: true, syncedAt: DateTime.now());
            }
          } else {
            debugPrint('⚠️ [RETRY] Erreur serveur: ${result["message"]} - Restera en queue');
          }
        } else {
          debugPrint('⚠️ [RETRY] HTTP ${response.statusCode} - Restera en queue');
        }
      } catch (e) {
        debugPrint('⚠️ [RETRY] Erreur: $e - Restera en queue');
        break; // Stop retrying on network error
      }
    }
    
    if (_pendingCreations.isEmpty) {
      debugPrint('✅ [RETRY] Toutes les demandes créations en attente ont été synchronisées!');
      notifyListeners();
    } else {
      debugPrint('📋 [RETRY] ${_pendingCreations.length} demandes créations restent en attente');
    }
  }
  
  /// Retry all pending validations
  Future<void> _retryPendingValidations() async {
    if (_pendingValidations.isEmpty) {
      return;
    }
    
    debugPrint('🔄 [RETRY] Tentative de synchronisation de ${_pendingValidations.length} validations en attente...');
    
    final validationsToRetry = List<Map<String, dynamic>>.from(_pendingValidations);
    
    for (final validation in validationsToRetry) {
      try {
        final codeOps = validation['codeOps'] as String;
        final agentId = validation['agentId'] as int;
        final agentName = validation['agentName'] as String;
        final approve = validation['approve'] as bool;
        
        final url = '${AppConfig.apiBaseUrl}/sync/deletion_requests/validate.php';
        debugPrint('🔄 [RETRY] Validation: $codeOps...');
        
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
            debugPrint('✅ [RETRY] Validation $codeOps réussie sur le serveur');
            _pendingValidations.removeWhere((v) => v['codeOps'] == codeOps);
            await _markDeletionRequestSynced(codeOps);
          } else {
            debugPrint('⚠️ [RETRY] Erreur serveur: ${result["message"]} - Restera en queue');
          }
        } else {
          debugPrint('⚠️ [RETRY] HTTP ${response.statusCode} - Restera en queue');
        }
      } catch (e) {
        debugPrint('⚠️ [RETRY] Erreur: $e - Restera en queue');
        break;
      }
    }
    
    if (_pendingValidations.isEmpty) {
      debugPrint('✅ [RETRY] Toutes les validations en attente ont été synchronisées!');
    } else {
      debugPrint('📋 [RETRY] ${_pendingValidations.length} validations restent en attente');
    }
  }
  
  /// Retry all pending restores
  Future<void> _retryPendingRestores() async {
    if (_pendingRestores.isEmpty) {
      return;
    }
    
    debugPrint('🔄 [RETRY] Tentative de synchronisation de ${_pendingRestores.length} restaurations en attente...');
    
    final restoresToRetry = List<Map<String, dynamic>>.from(_pendingRestores);
    
    for (final restore in restoresToRetry) {
      try {
        final codeOps = restore['codeOps'] as String;
        final restoredBy = restore['restoredBy'] as String;
        
        final url = '${AppConfig.apiBaseUrl}/sync/corbeille/restore.php';
        debugPrint('🔄 [RETRY] Restauration: $codeOps...');
        
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
            debugPrint('✅ [RETRY] Restauration $codeOps réussie sur le serveur');
            _pendingRestores.removeWhere((r) => r['codeOps'] == codeOps);
          } else {
            debugPrint('⚠️ [RETRY] Erreur serveur: ${result["message"]} - Restera en queue');
          }
        } else {
          debugPrint('⚠️ [RETRY] HTTP ${response.statusCode} - Restera en queue');
        }
      } catch (e) {
        debugPrint('⚠️ [RETRY] Erreur: $e - Restera en queue');
        break;
      }
    }
    
    if (_pendingRestores.isEmpty) {
      debugPrint('✅ [RETRY] Toutes les restaurations en attente ont été synchronisées!');
    } else {
      debugPrint('📋 [RETRY] ${_pendingRestores.length} restaurations restent en attente');
    }
  }
  
  /// Dispose (arrêter le timer)
  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
