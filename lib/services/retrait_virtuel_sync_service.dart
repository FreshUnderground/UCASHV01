import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/retrait_virtuel_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';

/// Service de synchronisation bidirectionnelle des retraits virtuels
/// Télécharge les retraits du serveur et upload les nouveaux retraits locaux
class RetraitVirtuelSyncService extends ChangeNotifier {
  static final RetraitVirtuelSyncService _instance = RetraitVirtuelSyncService._internal();
  factory RetraitVirtuelSyncService() => _instance;
  RetraitVirtuelSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<RetraitVirtuelModel> _pendingRetraits = [];
  String? _error;
  int _shopId = 0;

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<RetraitVirtuelModel> get pendingRetraits => _pendingRetraits;
  String? get error => _error;
  int get pendingCount => _pendingRetraits.length;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      _shopId = shopId;
      debugPrint('🔄 RetraitVirtuelSyncService initialisé pour shop: $_shopId');
      
      // Charger les retraits en attente depuis le cache local
      debugPrint('📂 Chargement cache local...');
      await _loadLocalPendingRetraits();
      debugPrint('✅ Cache local chargé: ${_pendingRetraits.length} retraits');
      
      // Démarrer la synchronisation automatique toutes les 30 secondes
      debugPrint('⏰ Démarrage auto-sync...');
      startAutoSync();
      
      // Première synchronisation immédiate
      debugPrint('🚀 Lancement première synchronisation...');
      await syncRetraits();
      
      debugPrint('✅ Initialisation RetraitVirtuelSyncService terminée');
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR initialisation RetraitVirtuelSyncService: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Charger les retraits en attente depuis le stockage local
  Future<void> _loadLocalPendingRetraits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('pending_retraits_virtuels_cache');
      
      if (cachedJson != null) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _pendingRetraits = cachedList
            .map((json) => RetraitVirtuelModel.fromJson(json))
            .toList();
        
        debugPrint('📥 ${_pendingRetraits.length} retraits virtuels chargés depuis le cache');
      } else {
        _pendingRetraits = [];
        debugPrint('ℹ️ Aucun retrait virtuel en cache');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement cache retraits virtuels: $e');
      _pendingRetraits = [];
    }
  }

  /// Sauvegarder les retraits en attente dans le stockage local
  Future<void> _savePendingRetraitsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _pendingRetraits.map((retrait) => retrait.toJson()).toList();
      await prefs.setString('pending_retraits_virtuels_cache', jsonEncode(jsonList));
      debugPrint('💾 Cache retraits virtuels sauvegardé (${_pendingRetraits.length} retraits)');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde cache retraits virtuels: $e');
    }
  }

  /// Démarrer la synchronisation automatique périodique
  void startAutoSync() {
    // Arrêter le timer existant si nécessaire
    _syncTimer?.cancel();
    
    // Démarrer un nouveau timer pour la synchronisation périodique
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isSyncing) {
        await syncRetraits();
      } else {
        debugPrint('⏳ Synchronisation retraits déjà en cours, nouvelle tentative différée...');
      }
    });
    
    debugPrint('🔄 Synchronisation automatique retraits démarrée (toutes les 30 secondes)');
  }

  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Synchronisation automatique retraits arrêtée');
  }

  /// Synchroniser les retraits virtuels avec le serveur
  Future<bool> syncRetraits() async {
    if (_isSyncing) {
      debugPrint('⏳ Synchronisation retraits déjà en cours, nouvelle tentative ignorée');
      return false;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Début synchronisation retraits virtuels...');
      
      // 1. Télécharger les nouveaux retraits du serveur
      await _downloadServerRetraits();
      
      // 2. Envoyer les retraits locaux non synchronisés
      await _uploadLocalRetraits();
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ Synchronisation retraits virtuels terminée avec succès');
      
      return true;
    } catch (e, stackTrace) {
      _error = 'Erreur synchronisation retraits virtuels: $e';
      debugPrint('❌ $_error');
      debugPrint('Stack trace: $stackTrace');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Télécharger les retraits virtuels depuis le serveur
  Future<void> _downloadServerRetraits() async {
    try {
      debugPrint('📥 Téléchargement des retraits virtuels depuis le serveur...');
      
      final lastSync = _lastSyncTime?.toIso8601String() ?? '2020-01-01T00:00:00.000';
      final url = '${await AppConfig.getApiBaseUrl()}/api/retrait-virtuels?shop_id=$_shopId&since=$lastSync';
      
      debugPrint('   📡 Requête GET: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('   📥 ${data.length} retraits virtuels reçus du serveur');
        
        int newCount = 0;
        int updatedCount = 0;
        
        // Traiter chaque retrait reçu
        for (var item in data) {
          try {
            final serverRetrait = RetraitVirtuelModel.fromJson(item);
            
            // Vérifier si le retrait existe déjà localement
            final existingRetraits = await LocalDB.instance.getAllRetraitsVirtuels();
            final existingRetrait = existingRetraits.firstWhere(
              (r) => r.id == serverRetrait.id,
              orElse: () => RetraitVirtuelModel(
                simNumero: '',
                shopSourceId: 0,
                shopDebiteurId: 0,
                montant: 0,
                soldeAvant: 0,
                soldeApres: 0,
                agentId: 0,
                dateRetrait: DateTime.now(),
              ),
            );
            
            if (existingRetrait.simNumero.isEmpty) {
              // Nouveau retrait à ajouter
              await LocalDB.instance.saveRetraitVirtuel(serverRetrait);
              newCount++;
            } else if (existingRetrait.lastModifiedAt == null || 
                      (serverRetrait.lastModifiedAt != null && 
                       serverRetrait.lastModifiedAt!.isAfter(existingRetrait.lastModifiedAt!))) {
              // Mettre à jour si la version du serveur est plus récente
              await LocalDB.instance.saveRetraitVirtuel(serverRetrait);
              updatedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Erreur traitement retrait virtuel: $e');
          }
        }
        
        debugPrint('   ➕ $newCount nouveaux retraits');
        debugPrint('   🔄 $updatedCount retraits mis à jour');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur téléchargement retraits virtuels: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Envoyer les retraits locaux non synchronisés au serveur
  Future<void> _uploadLocalRetraits() async {
    try {
      debugPrint('📤 Envoi des retraits virtuels non synchronisés...');
      
      // Récupérer les retraits non synchronisés
      final unsyncedRetraits = await _getUnsyncedRetraits();
      debugPrint('   📦 ${unsyncedRetraits.length} retraits à synchroniser');
      
      if (unsyncedRetraits.isEmpty) {
        debugPrint('   ℹ️ Aucun retrait à synchroniser');
        return;
      }
      
      // Préparer les données pour l'envoi
      final retraitsToSync = unsyncedRetraits.map((retrait) => retrait.toJson()).toList();
      
      // Envoyer les données au serveur
      final url = '${await AppConfig.getApiBaseUrl()}/api/retrait-virtuels/batch';
      debugPrint('   📡 Requête POST: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'retraits': retraitsToSync,
          'shop_id': _shopId,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> syncedRetraits = responseData['synced_retraits'] ?? [];
        
        // Mettre à jour le statut des retraits synchronisés
        for (var retraitData in syncedRetraits) {
          try {
            final retraitId = retraitData['id'];
            final serverId = retraitData['server_id'];
            
            if (retraitId != null && serverId != null) {
              final retrait = unsyncedRetraits.firstWhere(
                (r) => r.id == retraitId,
                orElse: () => throw Exception('Retrait non trouvé: $retraitId'),
              );
              
              // Mettre à jour avec l'ID du serveur et marquer comme synchronisé
              final updatedRetrait = retrait.copyWith(
                id: serverId,
                isSynced: true,
                syncedAt: DateTime.now(),
                lastModifiedAt: DateTime.now(),
                lastModifiedBy: 'sync_service',
              );
              
              await LocalDB.instance.saveRetraitVirtuel(updatedRetrait);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur mise à jour retrait virtuel: $e');
          }
        }
        
        debugPrint('   ✅ ${syncedRetraits.length} retraits synchronisés avec succès');
        
        // Mettre à jour la liste des retraits en attente
        await _updatePendingRetraits();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur envoi retraits virtuels: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupérer les retraits non synchronisés
  Future<List<RetraitVirtuelModel>> _getUnsyncedRetraits() async {
    try {
      final allRetraits = await LocalDB.instance.getAllRetraitsVirtuels();
      return allRetraits.where((retrait) => retrait.isSynced != true).toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération retraits non synchronisés: $e');
      return [];
    }
  }

  /// Mettre à jour la liste des retraits en attente
  Future<void> _updatePendingRetraits() async {
    try {
      _pendingRetraits = await _getUnsyncedRetraits();
      await _savePendingRetraitsToCache();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur mise à jour retraits en attente: $e');
    }
  }

  /// Ajouter un retrait à la file d'attente de synchronisation
  Future<void> addToSyncQueue(RetraitVirtuelModel retrait) async {
    try {
      // Vérifier si le retrait existe déjà dans la file d'attente
      final exists = _pendingRetraits.any((r) => r.id == retrait.id);
      
      if (!exists) {
        _pendingRetraits.add(retrait);
        await _savePendingRetraitsToCache();
        notifyListeners();
        
        // Démarrer une synchronisation immédiate si possible
        if (!_isSyncing) {
          await syncRetraits();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur ajout retrait à la file d\'attente: $e');
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
