import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/virtual_transaction_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';
import 'virtual_transaction_service.dart';

/// Service de synchronisation bidirectionnelle des transactions virtuelles
/// Télécharge les transactions "en attente" du serveur et upload les nouvelles transactions locales
class VirtualTransactionSyncService extends ChangeNotifier {
  static final VirtualTransactionSyncService _instance = VirtualTransactionSyncService._internal();
  factory VirtualTransactionSyncService() => _instance;
  VirtualTransactionSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<VirtualTransactionModel> _pendingTransactions = [];
  String? _error;
  int _shopId = 0;

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<VirtualTransactionModel> get pendingTransactions => _pendingTransactions;
  String? get error => _error;
  int get pendingCount => _pendingTransactions.length;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      _shopId = shopId;
      debugPrint('🔄 VirtualTransactionSyncService initialisé pour shop: $_shopId');
      
      // Charger les transactions en attente depuis le cache local
      debugPrint('📂 Chargement cache local...');
      await _loadLocalPendingTransactions();
      debugPrint('✅ Cache local chargé: ${_pendingTransactions.length} transactions');
      
      // Démarrer la synchronisation automatique toutes les 30 secondes
      debugPrint('⏰ Démarrage auto-sync...');
      startAutoSync();
      
      // Première synchronisation immédiate
      debugPrint('🚀 Lancement première synchronisation...');
      await syncTransactions();
      
      // Si après la première sync, on n'a toujours aucune transaction ET une erreur
      if (_pendingTransactions.isEmpty && _error != null) {
        debugPrint('⚠️ Première utilisation: Aucune donnée et erreur détectée');
        debugPrint('   💡 Cela peut être normal si aucune transaction n\'existe pour ce shop');
        debugPrint('   💡 OU un problème de connexion. Vérifiez: $_error');
      }
      
      debugPrint('✅ Initialisation VirtualTransactionSyncService terminée');
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR initialisation VirtualTransactionSyncService: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Charger les transactions en attente depuis le stockage local
  Future<void> _loadLocalPendingTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('pending_virtual_transactions_cache');
      
      if (cachedJson != null) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _pendingTransactions = cachedList
            .map((json) => VirtualTransactionModel.fromJson(json))
            .toList();
        
        debugPrint('📥 ${_pendingTransactions.length} transactions virtuelles chargées depuis le cache');
      } else {
        _pendingTransactions = [];
        debugPrint('ℹ️ Aucune transaction virtuelle en cache');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement cache transactions virtuelles: $e');
      _pendingTransactions = [];
    }
  }

  /// Sauvegarder les transactions en attente dans le stockage local
  Future<void> _savePendingTransactionsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _pendingTransactions.map((tx) => tx.toJson()).toList();
      await prefs.setString('pending_virtual_transactions_cache', jsonEncode(jsonList));
      debugPrint('💾 Cache transactions virtuelles sauvegardé (${_pendingTransactions.length} transactions)');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde cache transactions virtuelles: $e');
    }
  }

  /// Démarrer la synchronisation automatique périodique
  void startAutoSync() {
    // Arrêter le timer existant si nécessaire
    _syncTimer?.cancel();
    
    // Démarrer un nouveau timer pour la synchronisation périodique
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isSyncing) {
        await syncTransactions();
      } else {
        debugPrint('⏳ Synchronisation déjà en cours, nouvelle tentative différée...');
      }
    });
    
    debugPrint('🔄 Synchronisation automatique démarrée (toutes les 30 secondes)');
  }

  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Synchronisation automatique arrêtée');
  }

  /// Synchroniser les transactions virtuelles avec le serveur
  Future<bool> syncTransactions() async {
    if (_isSyncing) {
      debugPrint('⏳ Synchronisation déjà en cours, nouvelle tentative ignorée');
      return false;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Début synchronisation transactions virtuelles...');
      
      // 1. Télécharger les nouvelles transactions du serveur
      await _downloadServerTransactions();
      
      // 2. Envoyer les transactions locales non synchronisées
      await _uploadLocalTransactions();
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ Synchronisation transactions virtuelles terminée avec succès');
      
      // Mettre à jour le service de transactions virtuelles
      await VirtualTransactionService.instance.loadTransactions(shopId: _shopId);
      
      return true;
    } catch (e, stackTrace) {
      _error = 'Erreur synchronisation transactions virtuelles: $e';
      debugPrint('❌ $_error');
      debugPrint('Stack trace: $stackTrace');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Télécharger les transactions virtuelles depuis le serveur
  Future<void> _downloadServerTransactions() async {
    try {
      debugPrint('📥 Téléchargement des transactions virtuelles depuis le serveur...');
      
      final lastSync = _lastSyncTime?.toIso8601String() ?? '2020-01-01T00:00:00.000';
      final url = '${await AppConfig.getApiBaseUrl()}/api/virtual-transactions?shop_id=$_shopId&since=$lastSync';
      
      debugPrint('   📡 Requête GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('   📥 ${data.length} transactions virtuelles reçues du serveur');
        
        int newCount = 0;
        int updatedCount = 0;
        
        // Traiter chaque transaction reçue
        for (var item in data) {
          try {
            final serverTransaction = VirtualTransactionModel.fromJson(item);
            
            // Vérifier si la transaction existe déjà localement
            final existingTransaction = serverTransaction.id != null 
                ? await LocalDB.instance.getVirtualTransactionById(serverTransaction.id!)
                : null;
            
            if (existingTransaction == null) {
              // Nouvelle transaction à ajouter
              await LocalDB.instance.saveVirtualTransaction(serverTransaction);
              newCount++;
            } else if (existingTransaction.lastModifiedAt == null || 
                      (serverTransaction.lastModifiedAt != null && 
                       serverTransaction.lastModifiedAt!.isAfter(existingTransaction.lastModifiedAt!))) {
              // Mettre à jour si la version du serveur est plus récente
              await LocalDB.instance.saveVirtualTransaction(serverTransaction);
              updatedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Erreur traitement transaction virtuelle: $e');
          }
        }
        
        debugPrint('   ➕ $newCount nouvelles transactions');
        debugPrint('   🔄 $updatedCount transactions mises à jour');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur téléchargement transactions virtuelles: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Envoyer les transactions locales non synchronisées au serveur
  Future<void> _uploadLocalTransactions() async {
    try {
      debugPrint('📤 Envoi des transactions virtuelles non synchronisées...');
      
      // Récupérer les transactions non synchronisées
      final unsyncedTransactions = await _getUnsyncedTransactions();
      debugPrint('   📦 ${unsyncedTransactions.length} transactions à synchroniser');
      
      if (unsyncedTransactions.isEmpty) {
        debugPrint('   ℹ️ Aucune transaction à synchroniser');
        return;
      }
      
      // Préparer les données pour l'envoi
      final transactionsToSync = unsyncedTransactions.map((tx) => tx.toJson()).toList();
      
      // Envoyer les données au serveur
      final url = '${await AppConfig.getApiBaseUrl()}/api/virtual-transactions/batch';
      debugPrint('   📡 Requête POST: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'transactions': transactionsToSync,
          'shop_id': _shopId,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> syncedTransactions = responseData['synced_transactions'] ?? [];
        
        // Mettre à jour le statut des transactions synchronisées
        for (var txData in syncedTransactions) {
          try {
            final txId = txData['id'];
            final serverId = txData['server_id'];
            
            if (txId != null && serverId != null) {
              final tx = unsyncedTransactions.firstWhere(
                (t) => t.id == txId,
                orElse: () => throw Exception('Transaction non trouvée: $txId'),
              );
              
              // Mettre à jour avec l'ID du serveur et marquer comme synchronisée
              final updatedTx = tx.copyWith(
                id: serverId,
                isSynced: true,
                syncedAt: DateTime.now(),
                lastModifiedAt: DateTime.now(),
                lastModifiedBy: 'sync_service',
              );
              
              await LocalDB.instance.saveVirtualTransaction(updatedTx);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur mise à jour transaction virtuelle: $e');
          }
        }
        
        debugPrint('   ✅ ${syncedTransactions.length} transactions synchronisées avec succès');
        
        // Mettre à jour la liste des transactions en attente
        await _updatePendingTransactions();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur envoi transactions virtuelles: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupérer les transactions non synchronisées
  Future<List<VirtualTransactionModel>> _getUnsyncedTransactions() async {
    try {
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions();
      return allTransactions.where((tx) => tx.isSynced != true).toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération transactions non synchronisées: $e');
      return [];
    }
  }

  /// Mettre à jour la liste des transactions en attente
  Future<void> _updatePendingTransactions() async {
    try {
      _pendingTransactions = await _getUnsyncedTransactions();
      await _savePendingTransactionsToCache();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur mise à jour transactions en attente: $e');
    }
  }

  /// Ajouter une transaction à la file d'attente de synchronisation
  Future<void> addToSyncQueue(VirtualTransactionModel transaction) async {
    try {
      // Vérifier si la transaction existe déjà dans la file d'attente
      final exists = _pendingTransactions.any((tx) => tx.id == transaction.id || 
          (tx.reference.isNotEmpty && tx.reference == transaction.reference));
      
      if (!exists) {
        _pendingTransactions.add(transaction);
        await _savePendingTransactionsToCache();
        notifyListeners();
        
        // Démarrer une synchronisation immédiate si possible
        if (!_isSyncing) {
          await syncTransactions();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur ajout à la file d\'attente: $e');
    }
  }

  /// Obtenir les en-têtes d'authentification
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

/// Extension pour la gestion des erreurs de réseau
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  
  NetworkException(this.message, {this.statusCode});
  
  @override
  String toString() => 'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
