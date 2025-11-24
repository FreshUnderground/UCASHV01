import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'sync_service.dart';
import 'transfer_sync_service.dart';
import 'compte_special_service.dart';
import 'client_service.dart';
import '../config/app_config.dart';

/// Service de synchronisation robuste avec gestion avancée des erreurs
/// 
/// ARCHITECTURE:
/// - FAST SYNC (2 min): operations, flots, comptes_speciaux, clients
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

  /// Initialise le service robuste
  Future<void> initialize() async {
    debugPrint('🚀 ======== ROBUST SYNC SERVICE - INITIALISATION ========');
    
    // Écouter la connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    
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

  /// Exécute FAST SYNC: operations, flots, comptes_speciaux, clients
  Future<void> _performFastSync({bool isInitial = false}) async {
    if (_isFastSyncing) {
      debugPrint('⏸️ FAST SYNC déjà en cours, ignoré');
      return;
    }
    
    _isFastSyncing = true;
    final startTime = DateTime.now();
    
    debugPrint('🚀 ${isInitial ? "[INITIAL]" : ""} FAST SYNC - Début');
    debugPrint('   Tables: operations, flots, comptes_speciaux, clients');
    
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];
    
    try {
      // 1. OPÉRATIONS (via TransferSyncService)
      if (await _syncWithRetry('operations', () async {
        debugPrint('  📤📥 Sync OPERATIONS...');
        await _transferSync.syncTransfers();
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('operations');
      }
      
      // 2. FLOTS
      if (await _syncWithRetry('flots', () async {
        debugPrint('  📤 Upload FLOTS...');
        await _syncService.uploadTableData('flots', 'auto_fast_sync');
        debugPrint('  📥 Download FLOTS...');
        await _syncService.downloadTableData('flots', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('flots');
      }
      
      // 3. COMPTES SPÉCIAUX
      if (await _syncWithRetry('comptes_speciaux', () async {
        debugPrint('  📤 Upload COMPTES SPÉCIAUX...');
        await _syncService.uploadTableData('comptes_speciaux', 'auto_fast_sync');
        debugPrint('  📥 Download COMPTES SPÉCIAUX...');
        await _syncService.downloadTableData('comptes_speciaux', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('comptes_speciaux');
      }
      
      // 4. CLIENTS
      if (await _syncWithRetry('clients', () async {
        debugPrint('  📤 Upload CLIENTS...');
        await _syncService.uploadTableData('clients', 'auto_fast_sync');
        debugPrint('  📥 Download CLIENTS...');
        await _syncService.downloadTableData('clients', 'auto_fast_sync', 'admin');
      })) {
        successCount++;
      } else {
        errorCount++;
        errors.add('clients');
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
        await _syncService.uploadTableData('shops', 'auto_slow_sync');
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
        await _syncService.uploadTableData('agents', 'auto_slow_sync');
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
        await _syncService.uploadTableData('commissions', 'auto_slow_sync');
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
        await _syncService.uploadTableData('cloture_caisse', 'auto_slow_sync');
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
        await _syncService.uploadTableData('document_headers', 'auto_slow_sync');
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

  /// Exécute une sync avec retry automatique
  Future<bool> _syncWithRetry(String tableName, Future<void> Function() syncFunction) async {
    const maxRetries = 2;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        await syncFunction();
        return true; // Succès
      } catch (e) {
        attempt++;
        if (attempt < maxRetries) {
          debugPrint('  ⚠️ $tableName échoué (tentative $attempt/$maxRetries), retry dans 3s...');
          await Future.delayed(const Duration(seconds: 3));
        } else {
          debugPrint('  ❌ $tableName échoué après $maxRetries tentatives: $e');
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
        _performFastSync();
        
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

  /// Synchronisation manuelle immédiate (TOUT)
  Future<void> syncNow() async {
    debugPrint('🔄 Synchronisation manuelle déclenchée');
    await _performSlowSync(isInitial: true);
    await _performFastSync(isInitial: true);
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
    debugPrint('🛑 ROBUST SYNC SERVICE arrêté');
  }
}
