import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/credit_virtuel_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';

/// Service de synchronisation bidirectionnelle des crédits virtuels
/// Télécharge les crédits du serveur et upload les nouveaux crédits locaux
class CreditVirtuelSyncService extends ChangeNotifier {
  static final CreditVirtuelSyncService _instance = CreditVirtuelSyncService._internal();
  factory CreditVirtuelSyncService() => _instance;
  CreditVirtuelSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<CreditVirtuelModel> _pendingCredits = [];
  String? _error;
  int _shopId = 0;

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<CreditVirtuelModel> get pendingCredits => _pendingCredits;
  String? get error => _error;
  int get pendingCount => _pendingCredits.length;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      _shopId = shopId;
      debugPrint('🔄 CreditVirtuelSyncService initialisé pour shop: $_shopId');
      
      // Charger les crédits en attente depuis le cache local
      debugPrint('📂 Chargement cache local...');
      await _loadLocalPendingCredits();
      debugPrint('✅ Cache local chargé: ${_pendingCredits.length} crédits');
      
      // Démarrer la synchronisation automatique toutes les 30 secondes
      debugPrint('⏰ Démarrage auto-sync...');
      startAutoSync();
      
      // Première synchronisation immédiate
      debugPrint('🚀 Lancement première synchronisation...');
      await syncCredits();
      
      debugPrint('✅ Initialisation CreditVirtuelSyncService terminée');
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR initialisation CreditVirtuelSyncService: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Charger les crédits en attente depuis le stockage local
  Future<void> _loadLocalPendingCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('pending_credits_virtuels_cache');
      
      if (cachedJson != null) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _pendingCredits = cachedList
            .map((json) => CreditVirtuelModel.fromJson(json))
            .toList();
        
        debugPrint('📥 ${_pendingCredits.length} crédits virtuels chargés depuis le cache');
      } else {
        _pendingCredits = [];
        debugPrint('ℹ️ Aucun crédit virtuel en cache');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement cache crédits virtuels: $e');
      _pendingCredits = [];
    }
  }

  /// Sauvegarder les crédits en attente dans le stockage local
  Future<void> _savePendingCreditsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _pendingCredits.map((credit) => credit.toJson()).toList();
      await prefs.setString('pending_credits_virtuels_cache', jsonEncode(jsonList));
      debugPrint('💾 Cache crédits virtuels sauvegardé (${_pendingCredits.length} crédits)');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde cache crédits virtuels: $e');
    }
  }

  /// Démarrer la synchronisation automatique périodique
  void startAutoSync() {
    // Arrêter le timer existant si nécessaire
    _syncTimer?.cancel();
    
    // Démarrer un nouveau timer pour la synchronisation périodique
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isSyncing) {
        await syncCredits();
      } else {
        debugPrint('⏳ Synchronisation crédits déjà en cours, nouvelle tentative différée...');
      }
    });
    
    debugPrint('🔄 Synchronisation automatique crédits démarrée (toutes les 30 secondes)');
  }

  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Synchronisation automatique crédits arrêtée');
  }

  /// Synchroniser les crédits virtuels avec le serveur
  Future<bool> syncCredits() async {
    if (_isSyncing) {
      debugPrint('⏳ Synchronisation crédits déjà en cours, nouvelle tentative ignorée');
      return false;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Début synchronisation crédits virtuels...');
      
      // 1. Télécharger les nouveaux crédits du serveur
      await _downloadServerCredits();
      
      // 2. Envoyer les crédits locaux non synchronisés
      await _uploadLocalCredits();
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ Synchronisation crédits virtuels terminée avec succès');
      
      return true;
    } catch (e, stackTrace) {
      _error = 'Erreur synchronisation crédits virtuels: $e';
      debugPrint('❌ $_error');
      debugPrint('Stack trace: $stackTrace');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Télécharger les crédits virtuels depuis le serveur
  Future<void> _downloadServerCredits() async {
    try {
      debugPrint('📥 Téléchargement des crédits virtuels depuis le serveur...');
      
      final lastSync = _lastSyncTime?.toIso8601String() ?? '2020-01-01T00:00:00.000';
      final url = '${await AppConfig.getApiBaseUrl()}/api/credit-virtuels/download.php?shop_id=$_shopId&since=$lastSync';
      
      debugPrint('   📡 Requête GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('   📥 ${data.length} crédits virtuels reçus du serveur');
        
        int newCount = 0;
        int updatedCount = 0;
        
        // Traiter chaque crédit reçu
        for (var item in data) {
          try {
            final serverCredit = CreditVirtuelModel.fromJson(item);
            
            // Vérifier si le crédit existe déjà localement
            final existingCredit = serverCredit.id != null 
                ? await LocalDB.instance.getCreditVirtuelById(serverCredit.id!)
                : null;
            
            if (existingCredit == null) {
              // Nouveau crédit à ajouter
              debugPrint('   ➕ Insertion nouveau crédit: ${serverCredit.reference}');
              final insertedCredit = await LocalDB.instance.insertCreditVirtuel(serverCredit);
              if (insertedCredit != null) {
                newCount++;
                debugPrint('   ✅ Crédit inséré avec ID: ${insertedCredit.id}');
              } else {
                debugPrint('   ❌ Échec insertion crédit: ${serverCredit.reference}');
              }
            } else if (existingCredit.lastModifiedAt == null || 
                      (serverCredit.lastModifiedAt != null && 
                       serverCredit.lastModifiedAt!.isAfter(existingCredit.lastModifiedAt!))) {
              // Mettre à jour si la version du serveur est plus récente
              debugPrint('   🔄 Mise à jour crédit existant: ${serverCredit.reference}');
              final success = await LocalDB.instance.updateCreditVirtuel(serverCredit);
              if (success) {
                updatedCount++;
                debugPrint('   ✅ Crédit mis à jour: ${serverCredit.reference}');
              } else {
                debugPrint('   ❌ Échec mise à jour crédit: ${serverCredit.reference}');
              }
            } else {
              debugPrint('   ⏭️ Crédit ignoré (version locale plus récente): ${serverCredit.reference}');
            }
          } catch (e) {
            debugPrint('⚠️ Erreur traitement crédit virtuel: $e');
          }
        }
        
        debugPrint('   ➕ $newCount nouveaux crédits');
        debugPrint('   🔄 $updatedCount crédits mis à jour');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur téléchargement crédits virtuels: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Envoyer les crédits locaux non synchronisés au serveur
  Future<void> _uploadLocalCredits() async {
    try {
      debugPrint('📤 Envoi des crédits virtuels non synchronisés...');
      
      // Récupérer les crédits non synchronisés
      final unsyncedCredits = await _getUnsyncedCredits();
      debugPrint('   📦 ${unsyncedCredits.length} crédits à synchroniser');
      
      if (unsyncedCredits.isEmpty) {
        debugPrint('   ℹ️ Aucun crédit à synchroniser');
        return;
      }
      
      // Préparer les données pour l'envoi
      final creditsToSync = unsyncedCredits.map((credit) => credit.toJson()).toList();
      
      // Envoyer les données au serveur
      final url = '${await AppConfig.getApiBaseUrl()}/api/credit-virtuels/batch.php';
      debugPrint('   📡 Requête POST: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'credits': creditsToSync,
          'shop_id': _shopId,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> syncedCredits = responseData['synced_credits'] ?? [];
        
        // Mettre à jour le statut des crédits synchronisés
        for (var creditData in syncedCredits) {
          try {
            final creditId = creditData['id'];
            final serverId = creditData['server_id'];
            
            if (creditId != null && serverId != null) {
              final credit = unsyncedCredits.firstWhere(
                (c) => c.id == creditId,
                orElse: () => throw Exception('Crédit non trouvé: $creditId'),
              );
              
              // Mettre à jour avec l'ID du serveur et marquer comme synchronisé
              final updatedCredit = credit.copyWith(
                id: serverId,
                isSynced: true,
                syncedAt: DateTime.now(),
                lastModifiedAt: DateTime.now(),
                lastModifiedBy: 'sync_service',
              );
              
              await LocalDB.instance.updateCreditVirtuel(updatedCredit);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur mise à jour crédit virtuel: $e');
          }
        }
        
        debugPrint('   ✅ ${syncedCredits.length} crédits synchronisés avec succès');
        
        // Mettre à jour la liste des crédits en attente
        await _updatePendingCredits();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur envoi crédits virtuels: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupérer les crédits non synchronisés
  Future<List<CreditVirtuelModel>> _getUnsyncedCredits() async {
    try {
      final allCredits = await LocalDB.instance.getAllCreditsVirtuels();
      return allCredits.where((credit) => credit.isSynced != true).toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération crédits non synchronisés: $e');
      return [];
    }
  }

  /// Mettre à jour la liste des crédits en attente
  Future<void> _updatePendingCredits() async {
    try {
      _pendingCredits = await _getUnsyncedCredits();
      await _savePendingCreditsToCache();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur mise à jour crédits en attente: $e');
    }
  }

  /// Ajouter un crédit à la file d'attente de synchronisation
  Future<void> addToSyncQueue(CreditVirtuelModel credit) async {
    try {
      // Vérifier si le crédit existe déjà dans la file d'attente
      final exists = _pendingCredits.any((c) => c.id == credit.id || 
          (c.reference.isNotEmpty && c.reference == credit.reference));
      
      if (!exists) {
        _pendingCredits.add(credit);
        await _savePendingCreditsToCache();
        notifyListeners();
        
        // Démarrer une synchronisation immédiate si possible
        if (!_isSyncing) {
          await syncCredits();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur ajout crédit à la file d\'attente: $e');
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
