import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/deletion_request_model.dart';
import '../models/operation_model.dart';
import '../models/operation_corbeille_model.dart';
import '../models/virtual_transaction_deletion_request_model.dart';
import '../models/virtual_transaction_corbeille_model.dart';
import '../models/virtual_transaction_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';
import 'operation_service.dart';
import 'virtual_transaction_service.dart';

/// Service unifié de gestion des suppressions (opérations + transactions virtuelles)
/// avec validation en 2 étapes et filtres par type
/// 
/// Workflow:
/// 1. Admin crée une demande de suppression → en_attente
/// 2. Agent valide ou refuse la demande
/// 3. Si validée: élément déplacé vers corbeille + suppression locale et serveur
/// 4. Possibilité de restauration depuis la corbeille
/// 
/// Types supportés: operations, virtual_transactions
/// Synchronisation automatique toutes les 2 minutes

enum DeletionType {
  operations,
  virtualTransactions,
  all;
  
  String get name {
    switch (this) {
      case DeletionType.operations:
        return 'operations';
      case DeletionType.virtualTransactions:
        return 'virtual_transactions';
      case DeletionType.all:
        return 'all';
    }
  }
}

class DeletionService extends ChangeNotifier {
  static final DeletionService _instance = DeletionService._internal();
  factory DeletionService() => _instance;
  static DeletionService get instance => _instance;
  
  DeletionService._internal();

  // Listes en mémoire - Operations
  List<DeletionRequestModel> _deletionRequests = [];
  List<OperationCorbeilleModel> _corbeille = [];
  
  // Listes en mémoire - Virtual Transactions
  List<VirtualTransactionDeletionRequestModel> _virtualTransactionDeletionRequests = [];
  List<VirtualTransactionCorbeilleModel> _virtualTransactionCorbeille = [];
  
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
  
  // Queues pour les transactions virtuelles en attente de synchronisation
  final List<Map<String, dynamic>> _pendingVirtualValidations = []; // {reference, agentId, agentName, approve}
  final List<Map<String, dynamic>> _pendingVirtualRestores = [];    // {reference, restoredBy}
  final List<VirtualTransactionDeletionRequestModel> _pendingVirtualCreations = [];   // Demandes non synchronisées
  
  // Getters - Operations uniquement
  List<DeletionRequestModel> get deletionRequests => _deletionRequests;
  List<OperationCorbeilleModel> get corbeille => _corbeille;
  
  // Getters - Virtual Transactions uniquement
  List<VirtualTransactionDeletionRequestModel> get virtualTransactionDeletionRequests => _virtualTransactionDeletionRequests;
  List<VirtualTransactionCorbeilleModel> get virtualTransactionCorbeille => _virtualTransactionCorbeille;
  
  // Getters unifiés avec filtres
  /// Obtenir toutes les demandes de suppression (operations + virtual_transactions) avec filtre
  List<dynamic> getAllDeletionRequests({DeletionType type = DeletionType.all}) {
    switch (type) {
      case DeletionType.operations:
        return _deletionRequests;
      case DeletionType.virtualTransactions:
        return _virtualTransactionDeletionRequests;
      case DeletionType.all:
        return [..._deletionRequests, ..._virtualTransactionDeletionRequests];
    }
  }
  
  /// Obtenir tous les éléments de la corbeille avec filtre
  List<dynamic> getAllCorbeille({DeletionType type = DeletionType.all}) {
    switch (type) {
      case DeletionType.operations:
        return _corbeille;
      case DeletionType.virtualTransactions:
        return _virtualTransactionCorbeille;
      case DeletionType.all:
        return [..._corbeille, ..._virtualTransactionCorbeille];
    }
  }
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingValidationsCount => _pendingValidations.length + _pendingVirtualValidations.length;
  int get pendingRestoresCount => _pendingRestores.length + _pendingVirtualRestores.length;
  int get pendingCreationsCount => _pendingCreations.length + _pendingVirtualCreations.length;
  
  /// Obtenir les demandes en attente de validation admin (pour les admins) - Operations uniquement
  List<DeletionRequestModel> get adminPendingRequests {
    // Filtrer SEULEMENT les demandes en attente de validation inter-admin
    // Exclure celles déjà validées (admin_validee, agent_validee, refusee)
    final result = _deletionRequests.where((r) => 
      r.statut == DeletionRequestStatus.enAttente && 
      r.validatedByAdminId == null
    ).toList();
    debugPrint('\n========== DEMANDES ADMIN EN ATTENTE (OPERATIONS) ==========');
    debugPrint('📋 Total demandes admin en attente: ${result.length}');
    for (var r in result) {
      debugPrint('   📄 CodeOps: ${r.codeOps}');
      debugPrint('      Demandé par: ${r.requestedByAdminName}');
      debugPrint('      Statut: ${r.statut.name}');
      debugPrint('      Validé par admin: ${r.validatedByAdminName ?? "Non validé"}');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir les demandes en attente de validation admin pour virtual transactions
  List<VirtualTransactionDeletionRequestModel> get adminPendingVirtualRequests {
    final result = _virtualTransactionDeletionRequests.where((r) => 
      r.statut == VirtualTransactionDeletionRequestStatus.enAttente && 
      r.validatedByAdminId == null
    ).toList();
    debugPrint('\n========== DEMANDES ADMIN EN ATTENTE (VIRTUAL TRANSACTIONS) ==========');
    debugPrint('📋 Total demandes admin en attente: ${result.length}');
    for (var r in result) {
      debugPrint('   📄 Reference: ${r.reference}');
      debugPrint('      Demandé par: ${r.requestedByAdminName}');
      debugPrint('      Statut: ${r.statut.name}');
      debugPrint('      Validé par admin: ${r.validatedByAdminName ?? "Non validé"}');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir TOUTES les demandes admin en attente (operations + virtual transactions) avec filtre
  List<dynamic> getAllAdminPendingRequests({DeletionType type = DeletionType.all}) {
    switch (type) {
      case DeletionType.operations:
        return adminPendingRequests;
      case DeletionType.virtualTransactions:
        return adminPendingVirtualRequests;
      case DeletionType.all:
        return [...adminPendingRequests, ...adminPendingVirtualRequests];
    }
  }
  
  /// Obtenir les demandes en attente (pour l'agent) - Operations uniquement
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
    // L'agent doit voir: admin_validee OU (en_attente + validé par admin + pas encore validé par agent)
    final result = _deletionRequests.where((r) => 
      r.statut == DeletionRequestStatus.adminValidee ||
      (r.statut == DeletionRequestStatus.enAttente && 
       r.validatedByAdminId != null && 
       r.validatedByAgentId == null)
    ).toList();
    debugPrint('\n========== DEMANDES DE SUPPRESSION AGENT (OPERATIONS) ==========');
    debugPrint('📋 Total demandes en mémoire: ${_deletionRequests.length}');
    debugPrint('📋 Demandes VISIBLES AGENT: ${result.length}');
    debugPrint('🔍 Recherche demandes avec statut admin_validee OU (en_attente + admin validé)...');
    for (var r in _deletionRequests) {
      final matchesAdminValidee = r.statut == DeletionRequestStatus.adminValidee;
      final matchesEnAttenteWithAdmin = (r.statut == DeletionRequestStatus.enAttente && 
                                        r.validatedByAdminId != null && 
                                        r.validatedByAgentId == null);
      final shouldShow = matchesAdminValidee || matchesEnAttenteWithAdmin;
      
      debugPrint('   📄 CodeOps: ${r.codeOps}');
      debugPrint('      Statut: ${r.statut.name}');
      debugPrint('      Validé par admin: ${r.validatedByAdminName ?? "Non validé"} (ID: ${r.validatedByAdminId})');
      debugPrint('      Validé par agent: ${r.validatedByAgentName ?? "Non validé"} (ID: ${r.validatedByAgentId})');
      debugPrint('      isSynced: ${r.isSynced}');
      debugPrint('      Match admin_validee? $matchesAdminValidee');
      debugPrint('      Match en_attente+admin? $matchesEnAttenteWithAdmin');
      debugPrint('      DOIT APPARAÎTRE? $shouldShow');
      debugPrint('      ---');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir les demandes VT en attente de validation agent
  List<VirtualTransactionDeletionRequestModel> get pendingVirtualRequests {
    // Corriger les demandes incohérentes (validées mais avec statut enAttente)
    for (var i = 0; i < _virtualTransactionDeletionRequests.length; i++) {
      final r = _virtualTransactionDeletionRequests[i];
      // Si la demande a un validateur mais statut = enAttente, corriger
      if (r.validatedByAgentId != null && r.statut == VirtualTransactionDeletionRequestStatus.enAttente) {
        debugPrint('⚠️ Correction demande VT incohérente: ${r.reference} (validée par ${r.validatedByAgentName} mais statut=enAttente)');
        _virtualTransactionDeletionRequests[i] = r.copyWith(statut: VirtualTransactionDeletionRequestStatus.agentValidee);
        // Sauvegarder la correction
        _saveVirtualTransactionDeletionRequestLocal(_virtualTransactionDeletionRequests[i]);
      }
    }
    
    // Filtrer les demandes validées par un admin et en attente de validation agent
    final result = _virtualTransactionDeletionRequests.where((r) => 
      r.statut == VirtualTransactionDeletionRequestStatus.adminValidee ||
      (r.statut == VirtualTransactionDeletionRequestStatus.enAttente && 
       r.validatedByAdminId != null && 
       r.validatedByAgentId == null)
    ).toList();
    debugPrint('\n========== DEMANDES DE SUPPRESSION AGENT (VIRTUAL TRANSACTIONS) ==========');
    debugPrint('📋 Total demandes VT en mémoire: ${_virtualTransactionDeletionRequests.length}');
    debugPrint('📋 Demandes VT VISIBLES AGENT: ${result.length}');
    for (var r in result) {
      debugPrint('   📄 Reference: ${r.reference}');
      debugPrint('      Statut: ${r.statut.name}');
      debugPrint('      Validé par admin: ${r.validatedByAdminName ?? "Non validé"} (ID: ${r.validatedByAdminId})');
      debugPrint('      Validé par agent: ${r.validatedByAgentName ?? "Non validé"} (ID: ${r.validatedByAgentId})');
    }
    debugPrint('=============================================\n');
    return result;
  }
  
  /// Obtenir TOUTES les demandes agent en attente (operations + virtual transactions) avec filtre
  List<dynamic> getAllAgentPendingRequests({DeletionType type = DeletionType.all}) {
    switch (type) {
      case DeletionType.operations:
        return pendingRequests;
      case DeletionType.virtualTransactions:
        return pendingVirtualRequests;
      case DeletionType.all:
        return [...pendingRequests, ...pendingVirtualRequests];
    }
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
        syncVirtualTransactionDeletionRequests(), // Ajouter sync VT
        syncVirtualTransactionCorbeille(), // Ajouter sync corbeille VT
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
      debugPrint('🔄 [ADMIN] Déclenchement sync admin validation pour $codeOps...');
      _syncAdminValidationInBackground(codeOps, validatorAdminId, validatorAdminName);
      
      debugPrint('✅ Demande admin-validée pour $codeOps (sync en arrière-plan)');
      
      // Force refresh from server after admin validation
      debugPrint('🔄 [ADMIN] Force refresh après validation admin...');
      await loadDeletionRequests();
      
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
  
  /// Refuser une demande de suppression par un admin (inter-admin validation)
  Future<bool> refuseAdminDeletionRequest({
    required String codeOps,
    required int validatorAdminId,
    required String validatorAdminName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 Refus inter-admin demande: $codeOps...');
      
      // 1. Mettre à jour la demande localement (immediate)
      await _updateDeletionRequestLocal(
        codeOps: codeOps,
        validatedByAdminId: validatorAdminId,
        validatedByAdminName: validatorAdminName,
        statut: DeletionRequestStatus.refusee,
      );
      debugPrint('✅ Demande mise à jour en LOCAL (admin refusée)');
      
      // 2. Mettre à jour dans la liste en mémoire pour affichage immédiat
      final index = _deletionRequests.indexWhere((r) => r.codeOps == codeOps);
      if (index != -1) {
        _deletionRequests[index] = _deletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: DeletionRequestStatus.refusee,
        );
        debugPrint('✅ Demande mise à jour en MÉMOIRE (statut=${_deletionRequests[index].statut.name})');
      }
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      _syncAdminValidationInBackground(codeOps, validatorAdminId, validatorAdminName);
      
      debugPrint('✅ Demande admin-refusée pour $codeOps (sync en arrière-plan)');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur refus admin: $e';
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
  
  /// Créer une demande de suppression de transaction virtuelle
  Future<bool> createVirtualTransactionDeletionRequest({
    required VirtualTransactionModel virtualTransaction,
    required int adminId,
    required String adminName,
    String? reason,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 Création demande suppression VT: ${virtualTransaction.reference}...');
      
      // Créer le modèle de demande
      final request = VirtualTransactionDeletionRequestModel(
        reference: virtualTransaction.reference,
        virtualTransactionId: virtualTransaction.id,
        transactionType: 'VT',
        montant: virtualTransaction.montantVirtuel,
        devise: virtualTransaction.devise,
        destinataire: virtualTransaction.clientNom,
        expediteur: virtualTransaction.agentUsername,
        clientNom: virtualTransaction.clientNom,
        requestedByAdminId: adminId,
        requestedByAdminName: adminName,
        requestDate: DateTime.now(),
        reason: reason,
        statut: VirtualTransactionDeletionRequestStatus.enAttente,
        createdAt: DateTime.now(),
        isSynced: false,
      );
      
      // Ajouter à la liste locale
      _virtualTransactionDeletionRequests.add(request);
      
      // Sauvegarder localement
      await _saveVirtualTransactionDeletionRequestLocal(request);
      
      debugPrint('✅ Demande VT créée localement: ${virtualTransaction.reference}');
      
      // Synchroniser en arrière-plan
      _syncVirtualTransactionDeletionRequestInBackground(request);
      
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur création demande VT: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sauvegarder une demande de suppression VT localement
  Future<void> _saveVirtualTransactionDeletionRequestLocal(VirtualTransactionDeletionRequestModel request) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'vt_deletion_request_${request.reference}';
      await prefs.setString(key, jsonEncode(request.toJson()));
      debugPrint('💾 Demande VT sauvegardée localement: ${request.reference}');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde locale demande VT: $e');
    }
  }
  
  /// Synchroniser une demande de suppression VT en arrière-plan
  void _syncVirtualTransactionDeletionRequestInBackground(VirtualTransactionDeletionRequestModel request) async {
    debugPrint('🚀 [VT_SYNC] DÉBUT sync demande VT: ${request.reference}');
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/virtual_transaction_deletion_requests/upload.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation demande VT: ${request.reference}...');
      debugPrint('🔗 [BACKGROUND] URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'entities': [request.toJson()]
        }),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      debugPrint('📦 [BACKGROUND] Réponse body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Demande VT ${request.reference} synchronisée sur le serveur');
          
          // Marquer comme synchronisé localement
          final updatedRequest = request.copyWith(isSynced: true, syncedAt: DateTime.now());
          await _updateVirtualTransactionDeletionRequestLocal(updatedRequest);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur VT: ${result["message"]}');
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP VT ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur sync demande VT: $e');
    }
  }

  /// Mettre à jour une demande de suppression VT localement
  Future<void> _updateVirtualTransactionDeletionRequestLocal(VirtualTransactionDeletionRequestModel request) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'vt_deletion_request_${request.reference}';
      await prefs.setString(key, jsonEncode(request.toJson()));
      debugPrint('💾 Demande VT mise à jour localement: ${request.reference}');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour locale demande VT: $e');
    }
  }

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
        expediteur: operation.observation,
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
      
      debugPrint('🔄 [AGENT] Validation demande de suppression: $codeOps (approve: $approve)...');
      
      // 1. Si approuvé, supprimer l'opération localement FIRST (immediate)
      if (approve) {
        await _deleteOperationLocally(codeOps);
        debugPrint('✅ [AGENT] Opération supprimée en LOCAL: $codeOps');
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
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/deletion_requests/download.php';
      debugPrint('🔄 [LOAD] Chargement demandes depuis: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          _deletionRequests = data.map((json) => DeletionRequestModel.fromJson(json)).toList();
          
          debugPrint('📥 [LOAD] ${_deletionRequests.length} demandes chargées depuis le serveur');
          debugPrint('🔍 [LOAD] Détail des demandes chargées:');
          if (_deletionRequests.isEmpty) {
            debugPrint('   ❌ Aucune demande chargée');
          } else {
            for (var i = 0; i < _deletionRequests.length; i++) {
              final r = _deletionRequests[i];
              debugPrint('   📄 [$i] ${r.codeOps} | Statut: ${r.statut.name} | Admin: ${r.validatedByAdminName ?? "null"} | Agent: ${r.validatedByAgentName ?? "null"}');
            }
          }
          
          // NETTOYAGE: Supprimer du stockage local SEULEMENT les demandes complètement terminées
          // Garder en_attente ET admin_validee pour l'affichage admin/agent
          final prefs = await LocalDB.instance.database;
          final localKeys = prefs.getKeys().where((k) => k.startsWith('deletion_request_')).toList();
          
          for (final key in localKeys) {
            final data = prefs.getString(key);
            if (data != null) {
              final localRequest = DeletionRequestModel.fromJson(jsonDecode(data));
              // Supprimer SEULEMENT les demandes complètement terminées (agent_validee, refusee)
              if (localRequest.statut == DeletionRequestStatus.agentValidee || 
                  localRequest.statut == DeletionRequestStatus.refusee) {
                await prefs.remove(key);
                debugPrint('🧹 Nettoyage local: ${localRequest.codeOps} (statut=${localRequest.statut.name})');
              }
            }
          }
          
          // Sauvegarder localement les demandes en_attente ET admin_validee
          // (Pour permettre l'affichage admin et agent)
          for (final request in _deletionRequests) {
            if (request.statut == DeletionRequestStatus.enAttente || 
                request.statut == DeletionRequestStatus.adminValidee) {
              await _saveDeletionRequestLocal(request);
            } else {
              // Supprimer les demandes complètement terminées
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
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/corbeille/download.php?is_restored=0';
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
    debugPrint('🚀 [ADMIN_SYNC] DÉBUT sync validation admin: $codeOps (adminId: $adminId, adminName: $adminName)');
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/deletion_requests/admin_validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation admin: $codeOps...');
      debugPrint('🔗 [BACKGROUND] URL: $url');
      
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
      debugPrint('📦 [BACKGROUND] Réponse body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Validation admin $codeOps synchronisée sur le serveur');
          // Marquer comme synchronisé localement
          await _markDeletionRequestSynced(codeOps);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry admin');
          _addToPendingAdminValidations(codeOps, adminId, adminName);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry admin');
        debugPrint('⚠️ [BACKGROUND] Body erreur: ${response.body}');
        _addToPendingAdminValidations(codeOps, adminId, adminName);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT validation admin: $e - Ajout à la queue de retry admin');
      _addToPendingAdminValidations(codeOps, adminId, adminName);
    } on http.ClientException catch (e) {
      debugPrint("⚠️ [BACKGROUND] Pas d'internet: $e - Ajout à la queue de retry admin");
      _addToPendingAdminValidations(codeOps, adminId, adminName);
    } catch (e, stackTrace) {
      debugPrint('⚠️ [BACKGROUND] Erreur sync validation admin: $e');
      debugPrint('Stack trace: $stackTrace');
      _addToPendingAdminValidations(codeOps, adminId, adminName);
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
    debugPrint('🚀 [AGENT_SYNC] DÉBUT sync validation agent: $codeOps (agentId: $agentId, agentName: $agentName, approve: $approve)');
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/deletion_requests/validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation serveur: $codeOps...');
      debugPrint('🔗 [BACKGROUND] URL: $url');
      
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
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      debugPrint('📦 [BACKGROUND] Réponse body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Validation $codeOps synchronisée sur le serveur');
          // Remove from pending queue if it was there
          _pendingValidations.removeWhere((v) => v['codeOps'] == codeOps);
          // Mark as synced
          await _markDeletionRequestSynced(codeOps);
          
          // If approved, also upload the corbeille item AND delete operation from server
          if (approve) {
            await _uploadSingleCorbeilleItem(codeOps);
            await _deleteOperationFromServer(codeOps);
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

  /// Add admin validation to pending queue
  void _addToPendingAdminValidations(String codeOps, int adminId, String adminName) {
    // Check if already in queue
    final exists = _pendingValidations.any((v) => v['codeOps'] == codeOps && v['isAdmin'] == true);
    if (!exists) {
      _pendingValidations.add({
        'codeOps': codeOps,
        'adminId': adminId,
        'adminName': adminName,
        'isAdmin': true,
      });
      debugPrint('📋 Validation admin ajoutée à la queue de retry: $codeOps (Total: ${_pendingValidations.length})');
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
        final isAdmin = validation['isAdmin'] as bool? ?? false;
        
        if (isAdmin) {
          // Admin validation retry
          final adminId = validation['adminId'] as int;
          final adminName = validation['adminName'] as String;
          
          final apiBaseUrl = await AppConfig.getApiBaseUrl();
          final url = '$apiBaseUrl/sync/deletion_requests/admin_validate.php';
          debugPrint('🔄 [RETRY] Admin validation: $codeOps...');
          
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code_ops': codeOps,
              'validated_by_admin_id': adminId,
              'validated_by_admin_name': adminName,
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result['success'] == true) {
              debugPrint('✅ [RETRY] Admin validation $codeOps réussie sur le serveur');
              _pendingValidations.removeWhere((v) => v['codeOps'] == codeOps && v['isAdmin'] == true);
              await _markDeletionRequestSynced(codeOps);
            } else {
              debugPrint('⚠️ [RETRY] Erreur serveur admin: ${result["message"]} - Restera en queue');
            }
          } else {
            debugPrint('⚠️ [RETRY] HTTP admin ${response.statusCode} - Restera en queue');
          }
        } else {
          // Agent validation retry
          final agentId = validation['agentId'] as int;
          final agentName = validation['agentName'] as String;
          final approve = validation['approve'] as bool;
          
          final apiBaseUrl = await AppConfig.getApiBaseUrl();
          final url = '$apiBaseUrl/sync/deletion_requests/validate.php';
          debugPrint('🔄 [RETRY] Agent validation: $codeOps...');
          
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
              debugPrint('✅ [RETRY] Agent validation $codeOps réussie sur le serveur');
              _pendingValidations.removeWhere((v) => v['codeOps'] == codeOps && v['isAdmin'] != true);
              await _markDeletionRequestSynced(codeOps);
              
              // If approved, also upload corbeille and delete operation
              if (approve) {
                await _uploadSingleCorbeilleItem(codeOps);
                await _deleteOperationFromServer(codeOps);
              }
            } else {
              debugPrint('⚠️ [RETRY] Erreur serveur agent: ${result["message"]} - Restera en queue');
            }
          } else {
            debugPrint('⚠️ [RETRY] HTTP agent ${response.statusCode} - Restera en queue');
          }
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
  
  // =========================================================================
  // SYNCHRONISATION VIRTUAL TRANSACTIONS
  // =========================================================================
  
  /// Synchroniser les demandes de suppression de transactions virtuelles depuis le serveur
  Future<void> syncVirtualTransactionDeletionRequests() async {
    try {
      debugPrint('🔄 [VT_SYNC] Synchronisation demandes suppression VT...');
      
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/virtual_transaction_deletion_requests/download.php';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final List<dynamic> data = result['data'];
          
          debugPrint('📥 [VT_SYNC] ${data.length} demandes VT reçues du serveur');
          
          // Convertir en modèles
          final requests = data.map((json) => VirtualTransactionDeletionRequestModel.fromJson(json)).toList();
          
          // Sauvegarder localement
          for (final request in requests) {
            await _saveVirtualTransactionDeletionRequestLocal(request);
          }
          
          // Mettre à jour la liste en mémoire
          _virtualTransactionDeletionRequests = requests;
          
          debugPrint('✅ [VT_SYNC] ${requests.length} demandes VT synchronisées');
          notifyListeners();
        }
      } else {
        debugPrint('⚠️ [VT_SYNC] Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [VT_SYNC] Erreur sync demandes VT: $e');
    }
  }
  
  /// Synchroniser la corbeille des transactions virtuelles depuis le serveur
  Future<void> syncVirtualTransactionCorbeille() async {
    try {
      debugPrint('🔄 [VT_CORBEILLE_SYNC] Synchronisation corbeille VT...');
      
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/virtual_transactions_corbeille/download.php';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final List<dynamic> data = result['data'];
          
          debugPrint('📥 [VT_CORBEILLE_SYNC] ${data.length} éléments corbeille VT reçus');
          
          // Convertir en modèles
          final corbeilleItems = data.map((json) => VirtualTransactionCorbeilleModel.fromJson(json)).toList();
          
          // Sauvegarder localement
          for (final item in corbeilleItems) {
            await _saveVirtualTransactionCorbeilleLocal(item);
          }
          
          // Mettre à jour la liste en mémoire
          _virtualTransactionCorbeille = corbeilleItems;
          
          debugPrint('✅ [VT_CORBEILLE_SYNC] ${corbeilleItems.length} éléments corbeille VT synchronisés');
          notifyListeners();
        }
      } else {
        debugPrint('⚠️ [VT_CORBEILLE_SYNC] Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [VT_CORBEILLE_SYNC] Erreur sync corbeille VT: $e');
    }
  }
  
  
  /// Sauvegarder un élément de corbeille VT localement
  Future<void> _saveVirtualTransactionCorbeilleLocal(VirtualTransactionCorbeilleModel item) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'vt_corbeille_${item.reference}';
      await prefs.setString(key, jsonEncode(item.toJson()));
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde locale corbeille VT: $e');
    }
  }

  /// Valider une demande de suppression VT par un admin (inter-admin validation)
  Future<bool> validateAdminVirtualTransactionDeletionRequest({
    required String reference,
    required int validatorAdminId,
    required String validatorAdminName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 Validation inter-admin demande VT: $reference...');
      
      // 1. Mettre à jour la demande localement (immediate)
      final index = _virtualTransactionDeletionRequests.indexWhere((r) => r.reference == reference);
      if (index != -1) {
        final updatedRequest = _virtualTransactionDeletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: VirtualTransactionDeletionRequestStatus.adminValidee,
        );
        await _updateVirtualTransactionDeletionRequestLocal(updatedRequest);
      }
      debugPrint('✅ Demande VT mise à jour en LOCAL (admin validée)');
      
      // 2. Mettre à jour dans la liste en mémoire pour affichage immédiat
      if (index != -1) {
        _virtualTransactionDeletionRequests[index] = _virtualTransactionDeletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: VirtualTransactionDeletionRequestStatus.adminValidee,
        );
        debugPrint('✅ Demande VT mise à jour en MÉMOIRE (statut=${_virtualTransactionDeletionRequests[index].statut.name})');
      }
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      debugPrint('🔄 [ADMIN] Déclenchement sync admin validation VT pour $reference...');
      _syncAdminVirtualTransactionValidationInBackground(reference, validatorAdminId, validatorAdminName);
      
      debugPrint('✅ Demande VT admin-validée pour $reference (sync en arrière-plan)');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur validation admin VT: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refuser une demande de suppression VT par un admin (inter-admin validation)
  Future<bool> refuseAdminVirtualTransactionDeletionRequest({
    required String reference,
    required int validatorAdminId,
    required String validatorAdminName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 Refus inter-admin demande VT: $reference...');
      
      // 1. Mettre à jour la demande localement (immediate)
      final index = _virtualTransactionDeletionRequests.indexWhere((r) => r.reference == reference);
      if (index != -1) {
        final updatedRequest = _virtualTransactionDeletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: VirtualTransactionDeletionRequestStatus.refusee,
        );
        await _updateVirtualTransactionDeletionRequestLocal(updatedRequest);
      }
      debugPrint('✅ Demande VT mise à jour en LOCAL (admin refusée)');
      
      // 2. Mettre à jour dans la liste en mémoire pour affichage immédiat
      if (index != -1) {
        _virtualTransactionDeletionRequests[index] = _virtualTransactionDeletionRequests[index].copyWith(
          validatedByAdminId: validatorAdminId,
          validatedByAdminName: validatorAdminName,
          validationAdminDate: DateTime.now(),
          statut: VirtualTransactionDeletionRequestStatus.refusee,
        );
        debugPrint('✅ Demande VT mise à jour en MÉMOIRE (statut=${_virtualTransactionDeletionRequests[index].statut.name})');
      }
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      _syncAdminVirtualTransactionValidationInBackground(reference, validatorAdminId, validatorAdminName);
      
      debugPrint('✅ Demande VT admin-refusée pour $reference (sync en arrière-plan)');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur refus admin VT: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  
  /// Sync validation admin VT en arrière-plan
  void _syncAdminVirtualTransactionValidationInBackground(String reference, int adminId, String adminName) async {
    debugPrint('🚀 [ADMIN_VT_SYNC] DÉBUT sync validation admin VT: $reference (adminId: $adminId, adminName: $adminName)');
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/virtual_transaction_deletion_requests/admin_validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation admin VT: $reference...');
      debugPrint('🔗 [BACKGROUND] URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reference': reference,
          'validated_by_admin_id': adminId,
          'validated_by_admin_name': adminName,
          'validation_admin_date': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      debugPrint('📦 [BACKGROUND] Réponse body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Validation admin VT $reference synchronisée sur le serveur');
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur VT: ${result["message"]}');
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP VT ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur sync admin VT: $e');
    }
  }

  /// Valider une demande de suppression VT (Agent)
  Future<bool> validateVirtualTransactionDeletionRequest({
    required String reference,
    required int agentId,
    required String agentName,
    required bool approve, // true = approuver, false = refuser
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('🔄 [AGENT] Validation demande suppression VT: $reference (approve: $approve)...');
      
      // 1. Si approuvé, supprimer la transaction virtuelle localement FIRST (immediate)
      if (approve) {
        await _deleteVirtualTransactionLocally(reference);
        debugPrint('✅ [AGENT] Transaction virtuelle supprimée en LOCAL: $reference');
      }
      
      // 2. SUPPRIMER la demande du stockage local (immediate)
      // Une fois validée, elle ne doit plus apparaître chez l'agent
      await _deleteVirtualTransactionDeletionRequestLocal(reference);
      debugPrint('✅ Demande VT supprimée du LOCAL (ne réapparaîtra plus)');
      
      // 3. RETIRER de la liste en mémoire pour disparition immédiate de l'UI
      final index = _virtualTransactionDeletionRequests.indexWhere((r) => r.reference == reference);
      if (index != -1) {
        // Mettre à jour le statut avant de retirer (pour la synchro serveur)
        final updated = _virtualTransactionDeletionRequests[index].copyWith(
          validatedByAgentId: agentId,
          validatedByAgentName: agentName,
          validationDate: DateTime.now(),
          statut: approve ? VirtualTransactionDeletionRequestStatus.agentValidee : VirtualTransactionDeletionRequestStatus.refusee,
        );
        
        // Retirer de la liste (disparaît immédiatement de l'UI)
        _virtualTransactionDeletionRequests.removeAt(index);
        debugPrint('✅ Demande VT retirée de la MÉMOIRE (disparue de la liste)');
      }
      
      // 4. Recharger seulement la corbeille VT (pas les demandes pour ne pas écraser)
      await syncVirtualTransactionCorbeille();
      
      // 5. Sync to server in BACKGROUND (non-blocking)
      _syncVirtualTransactionValidationInBackground(reference, agentId, agentName, approve);
      
      debugPrint('✅ Demande VT ${approve ? "approuvée" : "refusée"} pour $reference (sync en arrière-plan)');
      return true;
      
    } catch (e) {
      _errorMessage = 'Erreur validation VT: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Supprimer une transaction virtuelle localement
  Future<void> _deleteVirtualTransactionLocally(String reference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((k) => k.startsWith('virtual_transaction_')).toList();
      
      for (final key in keys) {
        final data = prefs.getString(key);
        if (data != null) {
          final vt = VirtualTransactionModel.fromJson(jsonDecode(data));
          if (vt.reference == reference) {
            await prefs.remove(key);
            debugPrint('🗑️ Transaction virtuelle supprimée localement: $reference');
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression locale VT: $e');
    }
  }
  
  /// Supprimer une demande de suppression VT localement
  Future<void> _deleteVirtualTransactionDeletionRequestLocal(String reference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'vt_deletion_request_$reference';
      await prefs.remove(key);
      debugPrint('🗑️ Demande suppression VT supprimée localement: $reference');
    } catch (e) {
      debugPrint('❌ Erreur suppression locale demande VT: $e');
    }
  }
  
  /// Sync validation VT agent en arrière-plan
  void _syncVirtualTransactionValidationInBackground(String reference, int agentId, String agentName, bool approve) async {
    debugPrint('🚀 [AGENT_VT_SYNC] DÉBUT sync validation agent VT: $reference (agentId: $agentId, agentName: $agentName, approve: $approve)');
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/virtual_transaction_deletion_requests/validate.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation validation agent VT: $reference...');
      debugPrint('🔗 [BACKGROUND] URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reference': reference,
          'validated_by_agent_id': agentId,
          'validated_by_agent_name': agentName,
          'validation_date': DateTime.now().toIso8601String(),
          'approve': approve,
        }),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      debugPrint('📦 [BACKGROUND] Réponse body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Validation agent VT $reference synchronisée sur le serveur');
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur VT: ${result["message"]}');
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP VT ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur sync agent VT: $e');
    }
  }

  /// Delete operation from server
  Future<void> _deleteOperationFromServer(String codeOps) async {
    try {
      final apiBaseUrl = await AppConfig.getApiBaseUrl();
      final url = '$apiBaseUrl/sync/operations/delete.php';
      debugPrint('🗑️ [SERVER] Suppression opération serveur: $codeOps...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'codeOps': codeOps,
        }),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [SERVER] Réponse suppression HTTP ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [SERVER] Opération $codeOps supprimée du serveur');
        } else {
          debugPrint('⚠️ [SERVER] Erreur suppression serveur: ${result["message"]}');
        }
      } else {
        debugPrint('⚠️ [SERVER] Erreur HTTP ${response.statusCode} lors suppression');
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [SERVER] TIMEOUT suppression opération: $e');
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [SERVER] Pas d\'internet suppression: $e');
    } catch (e) {
      debugPrint('⚠️ [SERVER] Erreur suppression opération: $e');
    }
  }

  /// Dispose (arrêter le timer)
  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
