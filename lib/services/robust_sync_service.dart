import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'sync_service.dart';
import 'transfer_sync_service.dart';
import 'depot_retrait_sync_service.dart';
import 'flot_service.dart';
import 'compte_special_service.dart';
import 'client_service.dart';
import '../config/app_config.dart';
import '../config/sync_config.dart';

/// Service de synchronisation robuste avec gestion avancée des erreurs
/// 
/// ARCHITECTURE:
/// - FAST SYNC (2 min): operations, flots, comptes_speciaux, clients, sims, virtual_transactions
/// - SLOW SYNC (10 min): commissions, cloture_caisse, shops, agents
/// - Toutes s'exécutent au démarrage puis suivent leur timing
class RobustSyncService {
  static final RobustSyncService _instance = RobustSyncService._internal();
  factory RobustSyncService() => _instance;
  RobustSyncService._internal();

  // Timers séparés
  Timer? _fastSyncTimer;  // 2 minutes
  Timer? _slowSyncTimer;  // 10 minutes
  
  // Durées
  static const Duration _fastSyncInterval = Duration(minutes: 2);
  static const Duration _slowSyncInterval = Duration(minutes: 10);
  static const Duration _retryDelay = Duration(seconds: 30);
  
  // État
  bool _isEnabled = true;
  bool _isFastSyncing = false;
  bool _isSlowSyncing = false;
  bool _isOnline = false;
  
  // Circuit breaker pattern for preventing continuous retries when server is down
  bool _circuitBreakerOpen = false;
  int _failureCount = 0;
  static const int _maxFailureThreshold = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 5);
  DateTime? _lastFailureTime;
  
  // Statistiques
  DateTime? _lastFastSync;
  DateTime? _lastSlowSync;
  int _fastSyncSuccessCount = 0;
  int _fastSyncErrorCount = 0;
  int _slowSyncSuccessCount = 0;
  int _slowSyncErrorCount = 0;
  
  // File d'attente pour retry
  final List<String> _failedFastTables = [];
  final List<String> _failedSlowTables = [];
  
  // Listener de connectivité
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Services
  final SyncService _syncService = SyncService();
  final TransferSyncService _transferSync = TransferSyncService();
  final DepotRetraitSyncService _depotRetraitSync = DepotRetraitSyncService();
  final FlotService _flotService = FlotService.instance;
  
  // Timer de vérification de connectivité
  Timer? _connectivityCheckTimer;

  /// Initialise le service robuste
  Future<void> initialize() async {
    debugPrint('🚀 ======== ROBUST SYNC SERVICE - INITIALISATION ========');
    
    // Écouter la connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Démarrer le timer de vérification périodique de connectivité
    _startConnectivityCheckTimer();
    
    // Vérifier connectivité initiale
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
    debugPrint('📡 Connectivité initiale: ${_isOnline ? "Online" : "Offline"}');
    
    if (_isEnabled && _isOnline) {
      // Synchronisation initiale COMPLÈTE au démarrage
      await _performInitialSync();
      
      // Démarrer les timers
      _startFastSyncTimer();
      _startSlowSyncTimer();
      
      debugPrint('✅ ROBUST SYNC SERVICE initialisé avec succès');
    } else {
      debugPrint('⏸️ ROBUST SYNC SERVICE en attente de connexion');
    }
  }

  /// Synchronisation complète initiale au démarrage
  Future<void> _performInitialSync() async {
    debugPrint('🔄 === SYNCHRONISATION INITIALE COMPLÈTE ===');
    
    try {
      // D'abord les données de base (SLOW)
      await _performSlowSync(isInitial: true);
      
      // Puis les données opérationnelles (FAST)
      await _performFastSync(isInitial: true);
      
      debugPrint('✅ Synchronisation initiale terminée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur synchronisation initiale: $e');
      // Continuer quand même - les timers réessaieront
    }
  }

  /// Démarre le timer FAST (2 min)
  void _startFastSyncTimer() {
    _fastSyncTimer?.cancel();
    
    _fastSyncTimer = Timer.periodic(_fastSyncInterval, (timer) async {
      if (_isEnabled && _isOnline && !_isFastSyncing) {
        await _performFastSync();
      }
    });
    
    debugPrint('⏰ Timer FAST SYNC démarré (${_fastSyncInterval.inMinutes} min)');
  }

  /// Démarre le timer SLOW (10 min)
  void _startSlowSyncTimer() {
    _slowSyncTimer?.cancel();
    
    _slowSyncTimer = Timer.periodic(_slowSyncInterval, (timer) async {
      if (_isEnabled && _isOnline && !_isSlowSyncing) {
        await _performSlowSync();
      }
    });
    
    debugPrint('⏰ Timer SLOW SYNC démarré (${_slowSyncInterval.inMinutes} min)');
  }

  /// Exécute FAST SYNC: operations, flots, comptes_speciaux, clients, audit_log, reconciliations
  Future<void> _performFastSync({bool isInitial = false}) async {
    if (_isFastSyncing) {
      debugPrint('⏸️ FAST SYNC déjà en cours, ignoré');
      return;
    }
    
    _isFastSyncing = true;
    final startTime = DateTime.now();
    
    debugPrint('🚀 ${isInitial ? "[INITIAL]" : ""} FAST SYNC - Début');
    debugPrint('   Tables critiques: operations, flots, clients, comptes_speciaux, sims, virtual_transactions, retrait_virtuels, credit_virtuels, audit_log, reconciliations, triangular_debt_settlements');
    
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];
    
    try {
      // ========== ÉTAPE 1: SYNCHRONISER LES QUEUES (PRIORITÉ ABSOLUE) ==========
      // Les opérations et flots créés localement DOIVENT être envoyés en premier
      
      // 1.1 Queue Dépôts/Retraits (Service spécialisé)
      if (await _syncWithRetry('queue_depots_retraits', () async {
        debugPrint('  💰 [PRIORITÉ 1] Sync dépôts/retraits via service spécialisé...');
        await _depotRetraitSync.syncDepotsRetraits();
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('queue_depots_retraits');
      }

            // ========== ÉTAPE 10: SYNC RÈGLEMENTS TRIANGULAIRES DE DETTES ==========
      if (await _syncWithRetry('triangular_debt_settlements', () async {
        debugPrint('  🔺 Upload RÈGLEMENTS TRIANGULAIRES...');
        await _syncService.uploadTableData('triangular_debt_settlements', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download RÈGLEMENTS TRIANGULAIRES...');
        await _syncService.downloadTableData('triangular_debt_settlements', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('triangular_debt_settlements');
      }
      
      // 1.2 Queue Transferts (Autres opérations)
      if (await _syncWithRetry('queue_transferts', () async {
        debugPrint('  📎 [PRIORITÉ 1] Sync queue transferts...');
        await _syncService.syncPendingData();
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('queue_transferts');
      }
      
      // 1.3 Queue Flots (Transferts entre shops)
      if (await _syncWithRetry('queue_flots', () async {
        debugPrint('  📪 [PRIORITÉ 1] Sync queue flots...');
        await _syncService.syncPendingFlots();
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('queue_flots');
      }
      
      // ========== ÉTAPE 2: SYNC BIDIRECTIONNELLE DES FLOTS (via operations) ==========
      // Les FLOTs utilisent maintenant la table operations avec type=flotShopToShop
      if (await _syncWithRetry('flots', () async {
        debugPrint('  🚚 [ÉTAPE 2] Sync FLOTS (via operations)...');
        // Les FLOTs sont maintenant synchronisés via le endpoint operations
        // Pas besoin de sync séparé car ils font partie des opérations
        debugPrint('  ✅ FLOTs synchronisés via operations (type=flotShopToShop)');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('flots');
      }
      
      // ========== ÉTAPE 3: SYNC BIDIRECTIONNELLE DES OPÉRATIONS ==========
      // Download les nouvelles opérations depuis le serveur
      if (await _syncWithRetry('operations', () async {
        debugPrint('  📤📥 [ÉTAPE 3] Sync opérations bidirectionnelle...');
        await _transferSync.syncTransfers();
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('operations');
      }
      
      // ========== ÉTAPE 4: SYNC COMPTES SPÉCIAUX (Clients) ==========
      if (await _syncWithRetry('comptes_speciaux', () async {
        debugPrint('  📤 Upload COMPTES SPÉCIAUX...');
        await _syncService.uploadTableData('comptes_speciaux', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download COMPTES SPÉCIAUX...');
        await _syncService.downloadTableData('comptes_speciaux', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('comptes_speciaux');
      }
      
      // ========== ÉTAPE 5: SYNC CLIENTS ==========
      if (await _syncWithRetry('clients', () async {
        debugPrint('  📤 Upload CLIENTS...');
        await _syncService.uploadTableData('clients', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download CLIENTS...');
        await _syncService.downloadTableData('clients', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('clients');
      }
      
      // ========== ÉTAPE 6: SYNC SIMS ==========
      if (await _syncWithRetry('sims', () async {
        debugPrint('  📱 Upload SIMS...');
        await _syncService.uploadTableData('sims', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download SIMS...');
        await _syncService.downloadTableData('sims', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('sims');
      }
      
      // ========== ÉTAPE 7: SYNC TRANSACTIONS VIRTUELLES ==========
      if (await _syncWithRetry('virtual_transactions', () async {
        debugPrint('  💰 Upload VIRTUAL_TRANSACTIONS...');
        await _syncService.uploadTableData('virtual_transactions', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download VIRTUAL_TRANSACTIONS...');
        await _syncService.downloadTableData('virtual_transactions', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('virtual_transactions');
      }
      
      // ========== ÉTAPE 7.1: SYNC RETRAITS VIRTUELS ==========
      if (await _syncWithRetry('retrait_virtuels', () async {
        debugPrint('  🔄 Upload RETRAIT_VIRTUELS...');
        await _syncService.uploadTableData('retrait_virtuels', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download RETRAIT_VIRTUELS...');
        await _syncService.downloadTableData('retrait_virtuels', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('retrait_virtuels');
      }
      
      // ========== ÉTAPE 8: SYNC AUDIT LOG ==========
      if (await _syncWithRetry('audit_log', () async {
        debugPrint('  📤 Upload AUDIT LOG...');
        await _syncService.uploadTableData('audit_log', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download AUDIT LOG...');
        await _syncService.downloadTableData('audit_log', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('audit_log');
      }
      
      // ========== ÉTAPE 9: SYNC RECONCILIATIONS ==========
      if (await _syncWithRetry('reconciliations', () async {
        debugPrint('  📤 Upload RECONCILIATIONS...');
        await _syncService.uploadTableData('reconciliations', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download RECONCILIATIONS...');
        await _syncService.downloadTableData('reconciliations', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('reconciliations');
      }
      
      // ========== ÉTAPE 9.1: SYNC CRÉDITS VIRTUELS ==========
      if (await _syncWithRetry('credit_virtuels', () async {
        debugPrint('  💳 Upload CREDIT_VIRTUELS...');
        await _syncService.uploadTableData('credit_virtuels', 'auto_fast_sync', 'admin');
        debugPrint('  📥 Download CREDIT_VIRTUELS...');
        await _syncService.downloadTableData('credit_virtuels', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('credit_virtuels');
      }
    
      
      _lastFastSync = DateTime.now();
      _fastSyncSuccessCount += successCount;
      _fastSyncErrorCount += errorCount;
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ FAST SYNC terminé en ${duration.inSeconds}s: $successCount OK, $errorCount erreurs');
      
      if (errors.isNotEmpty) {
        debugPrint('⚠️ Tables échouées: ${errors.join(", ")}');
        _failedFastTables.clear();
        _failedFastTables.addAll(errors);
        // Programmer un retry dans 30 secondes
        _scheduleRetry(true);
      } else {
        debugPrint('🎉 FAST SYNC 100% réussi - Toutes les données critiques synchronisées !');
      }
      
    } catch (e, stack) {
      debugPrint('❌ Erreur globale FAST SYNC: $e');
      debugPrint('Stack: $stack');
      _fastSyncErrorCount++;
    } finally {
      _isFastSyncing = false;
    }
  }

  /// Exécute SLOW SYNC: commissions, cloture_caisse, shops, agents, document_headers
  Future<void> _performSlowSync({bool isInitial = false}) async {
    if (_isSlowSyncing) {
      debugPrint('⏸️ SLOW SYNC déjà en cours, ignoré');
      return;
    }
    
    _isSlowSyncing = true;
    final startTime = DateTime.now();
    
    debugPrint('🐢 ${isInitial ? "[INITIAL]" : ""} SLOW SYNC - Début');
    debugPrint('   Tables: commissions, cloture_caisse, shops, agents, document_headers');
    
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];
    
    try {
      // 1. SHOPS (prioritaire)
      if (await _syncWithRetry('shops', () async {
        debugPrint('  📤 Upload SHOPS...');
        await _syncService.uploadTableData('shops', 'auto_slow_sync', 'admin');
        debugPrint('  📥 Download SHOPS...');
        await _syncService.downloadTableData('shops', 'auto_slow_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('shops');
      }
      
      // 2. AGENTS (dépend de shops)
      if (await _syncWithRetry('agents', () async {
        debugPrint('  📤 Upload AGENTS...');
        await _syncService.uploadTableData('agents', 'auto_slow_sync', 'admin');
        debugPrint('  📥 Download AGENTS...');
        await _syncService.downloadTableData('agents', 'auto_slow_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('agents');
      }
      
      // 3. COMMISSIONS
      if (await _syncWithRetry('commissions', () async {
        debugPrint('  📤 Upload COMMISSIONS...');
        await _syncService.uploadTableData('commissions', 'auto_slow_sync', 'admin');
        debugPrint('  📥 Download COMMISSIONS...');
        await _syncService.downloadTableData('commissions', 'auto_slow_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('commissions');
      }
      
      // 4. CLÔTURE CAISSE
      if (await _syncWithRetry('cloture_caisse', () async {
        debugPrint('  📤 Upload CLÔTURES...');
        await _syncService.uploadTableData('cloture_caisse', 'auto_slow_sync', 'admin');
        debugPrint('  📥 Download CLÔTURES...');
        await _syncService.downloadTableData('cloture_caisse', 'auto_slow_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('cloture_caisse');
      }
      
      // 5. DOCUMENT HEADERS (EN-TÊTES)
      if (await _syncWithRetry('document_headers', () async {
        debugPrint('  📤 Upload DOCUMENT HEADERS...');
        await _syncService.uploadTableData('document_headers', 'auto_slow_sync', 'admin');
        debugPrint('  📥 Download DOCUMENT HEADERS...');
        await _syncService.downloadTableData('document_headers', 'auto_slow_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('document_headers');
      }
      
      _lastSlowSync = DateTime.now();
      _slowSyncSuccessCount += successCount;
      _slowSyncErrorCount += errorCount;
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ SLOW SYNC terminé en ${duration.inSeconds}s: $successCount OK, $errorCount erreurs');
      
      if (errors.isNotEmpty) {
        debugPrint('⚠️ Tables échouées: ${errors.join(", ")}');
        _failedSlowTables.clear();
        _failedSlowTables.addAll(errors);
        // Programmer un retry dans 30 secondes
        _scheduleRetry(false);
      }
      
    } catch (e, stack) {
      debugPrint('❌ Erreur globale SLOW SYNC: $e');
      debugPrint('Stack: $stack');
      _slowSyncErrorCount++;
    } finally {
      _isSlowSyncing = false;
    }
  }

  /// Checks if the circuit breaker is open (server appears to be down)
  bool _isCircuitBreakerOpen() {
    if (!_circuitBreakerOpen) return false;
    
    // Check if enough time has passed to try again
    if (_lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed > _circuitBreakerTimeout) {
        debugPrint('⚡ Circuit breaker timeout expired, closing circuit');
        _resetCircuitBreaker();
        return false;
      }
    }
    
    return true;
  }
  
  /// Opens the circuit breaker when too many failures occur
  void _openCircuitBreaker() {
    _circuitBreakerOpen = true;
    _lastFailureTime = DateTime.now();
    debugPrint('🚨 Circuit breaker OPENED due to repeated failures');
  }
  
  /// Resets the circuit breaker after successful operations
  void _resetCircuitBreaker() {
    _circuitBreakerOpen = false;
    _failureCount = 0;
    _lastFailureTime = null;
    debugPrint('✅ Circuit breaker RESET after successful operation');
  }
  
  /// Manually reset circuit breaker (public method for UI)
  void resetCircuitBreaker() {
    _resetCircuitBreaker();
    debugPrint('🔧 Circuit breaker manually RESET by user');
  }
  
  /// Get circuit breaker state (public method for UI)
  Map<String, dynamic> getCircuitBreakerState() {
    return {
      'isOpen': _circuitBreakerOpen,
      'failureCount': _failureCount,
      'maxThreshold': _maxFailureThreshold,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'timeoutMinutes': _circuitBreakerTimeout.inMinutes,
      'canRetry': !_isCircuitBreakerOpen(),
    };
  }
  
  /// Records a failure and opens circuit breaker if threshold exceeded
  void _recordFailure() {
    _failureCount++;
    debugPrint('⚠️ Failure recorded ($_failureCount/$_maxFailureThreshold)');
    
    if (_failureCount >= _maxFailureThreshold) {
      _openCircuitBreaker();
    }
  }
  
  /// Records a successful operation and resets failure count
  void _recordSuccess() {
    _resetCircuitBreaker();
  }

  /// Exécute une sync avec retry automatique amélioré
  /// Implémentation avec backoff exponentiel et jitter
  Future<bool> _syncWithRetry(String tableName, Future<void> Function() syncFunction) async {
    // Check circuit breaker before attempting sync
    if (_isCircuitBreakerOpen()) {
      debugPrint('🚫 $tableName sync skipped - circuit breaker is OPEN');
      return false;
    }
    
    const maxRetries = 5; // Utiliser la configuration améliorée
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        await syncFunction();
        _recordSuccess(); // Record success and reset circuit breaker
        return true; // Succès
      } catch (e) {
        _recordFailure(); // Record failure for circuit breaker
        attempt++;
        if (attempt < maxRetries) {
          // Utiliser la configuration améliorée avec jitter
          final delay = SyncConfig.getRetryDelay(attempt - 1);
          debugPrint('  ⚠️ $tableName échoué (tentative $attempt/$maxRetries), retry dans ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          debugPrint('  ❌ $tableName échoué après $maxRetries tentatives: $e');
          // Log détaillé pour le suivi des problèmes
          debugPrint('  📊 Détails de l\'erreur: ${e.toString()}');
          return false; // Échec définitif
        }
      }
    }
    
    return false;
  }

  /// Programme un retry pour les tables échouées
  void _scheduleRetry(bool isFast) {
    final tables = isFast ? _failedFastTables : _failedSlowTables;
    if (tables.isEmpty) return;
    
    debugPrint('🔄 Retry programmé dans ${_retryDelay.inSeconds}s pour: ${tables.join(", ")}');
    
    Timer(_retryDelay, () async {
      if (_isOnline && _isEnabled) {
        debugPrint('🔄 Retry des tables échouées: ${tables.join(", ")}');
        // Réessayer seulement les tables échouées
        // TODO: Implémenter retry sélectif si nécessaire
        if (isFast) {
          await _performFastSync();
        } else {
          await _performSlowSync();
        }
      }
    });
  }

  /// Gère les changements de connectivité
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    debugPrint('📡 Connectivité: ${_isOnline ? "Online" : "Offline"}');
    
    if (_isOnline && wasOffline) {
      // Retour en ligne
      debugPrint('🌐 Retour en ligne - redémarrage sync');
      
      if (_isEnabled) {
        // Sync immédiate des données critiques
        _performFastSync(); // Cette fonction est async mais nous ne voulons pas bloquer ici
        
        // Redémarrer les timers
        _startFastSyncTimer();
        _startSlowSyncTimer();
      }
    } else if (!_isOnline) {
      // Passage offline
      debugPrint('📵 Mode offline - arrêt des timers');
      _fastSyncTimer?.cancel();
      _slowSyncTimer?.cancel();
    }
  }
  
  /// Vérifie périodiquement la connectivité et tente de se reconnecter
  void _startConnectivityCheckTimer() {
    // Annuler le timer précédent s'il existe
    _connectivityCheckTimer?.cancel();
    
    // Timer périodique pour vérifier la connectivité toutes les 30 secondes
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isOnline && _isEnabled) {
        try {
          final connectivityResult = await Connectivity().checkConnectivity();
          final isNowOnline = connectivityResult != ConnectivityResult.none;
          
          if (isNowOnline && !_isOnline) {
            // Nous sommes maintenant en ligne
            _isOnline = true;
            debugPrint('🌐 Connectivité retrouvée - redémarrage sync');
            
            // Sync immédiate des données critiques
            _performFastSync(); // Cette fonction est async mais nous ne voulons pas bloquer ici
            
            // Redémarrer les timers
            _startFastSyncTimer();
            _startSlowSyncTimer();
          }
        } catch (e) {
          debugPrint('⚠️ Erreur vérification connectivité: $e');
        }
      }
    });
  }

  /// Vérifie la connectivité et tente une synchronisation si en ligne
  Future<void> checkConnectivityAndSync() async {
    // Check circuit breaker before attempting sync
    if (_isCircuitBreakerOpen()) {
      debugPrint('🚫 Connectivity check skipped - circuit breaker is OPEN');
      return;
    }
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isNowOnline = connectivityResult != ConnectivityResult.none;
      
      if (isNowOnline && !_isOnline) {
        // Nous sommes maintenant en ligne
        _isOnline = true;
        debugPrint('🌐 Connectivité retrouvée - déclenchement sync');
        
        // Sync immédiate des données critiques
        await _performFastSync();
        
        // Redémarrer les timers
        _startFastSyncTimer();
        _startSlowSyncTimer();
        
        return;
      }
      
      if (isNowOnline && _isOnline) {
        // Déjà en ligne, déclencher une sync manuelle
        debugPrint('🌐 Déclenchement sync manuelle');
        await syncNow();
      }
    } catch (e) {
      _recordFailure();
      debugPrint('⚠️ Erreur vérification connectivité et sync: $e');
    }
  }

  /// Synchronisation manuelle immédiate (TOUT)
  Future<void> syncNow() async {
    debugPrint('🔄 Synchronisation manuelle déclenchée');
    await _performSlowSync(isInitial: true);
    await _performFastSync(isInitial: true);
  }
  
  /// Force synchronisation even if circuit breaker is open (resets it first)
  Future<void> forceSyncNow() async {
    debugPrint('⚡ FORCE synchronisation - resetting circuit breaker first');
    resetCircuitBreaker();
    await syncNow();
  }

  /// Force reset circuit breaker and clear failed tables
  void forceResetCircuitBreaker() {
    debugPrint('🔧 FORCE RESET circuit breaker and clearing failed tables');
    _resetCircuitBreaker();
    _failedFastTables.clear();
    _failedSlowTables.clear();
    debugPrint('✅ Circuit breaker reset and failed tables cleared');
  }

  /// Active/désactive la synchronisation
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('🔄 Synchronisation: ${enabled ? "activée" : "désactivée"}');
    
    if (enabled && _isOnline) {
      _startFastSyncTimer();
      _startSlowSyncTimer();
    } else {
      _fastSyncTimer?.cancel();
      _slowSyncTimer?.cancel();
    }
  }

  /// Obtient les statistiques
  Map<String, dynamic> getStats() {
    return {
      'isEnabled': _isEnabled,
      'isOnline': _isOnline,
      'isFastSyncing': _isFastSyncing,
      'isSlowSyncing': _isSlowSyncing,
      'isCircuitBreakerOpen': _circuitBreakerOpen,
      'failureCount': _failureCount,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'lastFastSync': _lastFastSync?.toIso8601String(),
      'lastSlowSync': _lastSlowSync?.toIso8601String(),
      'fastSyncSuccess': _fastSyncSuccessCount,
      'fastSyncErrors': _fastSyncErrorCount,
      'slowSyncSuccess': _slowSyncSuccessCount,
      'slowSyncErrors': _slowSyncErrorCount,
      'failedFastTables': _failedFastTables,
      'failedSlowTables': _failedSlowTables,
    };
  }

  /// Nettoie les ressources
  void dispose() {
    _fastSyncTimer?.cancel();
    _slowSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivityCheckTimer?.cancel();
    debugPrint('🛑 ROBUST SYNC SERVICE arrêté');
  }
}
