import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operation_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';
import 'operation_service.dart';

/// Service de synchronisation bidirectionnelle des transferts
/// Télécharge les transferts "en attente" du serveur et upload les nouveaux transferts locaux
class TransferSyncService extends ChangeNotifier {
  static final TransferSyncService _instance = TransferSyncService._internal();
  factory TransferSyncService() => _instance;
  TransferSyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<OperationModel> _pendingTransfers = [];
  String? _error;
  int _shopId = 0;

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<OperationModel> get pendingTransfers => _pendingTransfers;
  String? get error => _error;
  int get pendingCount => _pendingTransfers.length;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      _shopId = shopId;
      debugPrint('🔄 TransferSyncService initialisé pour shop: $_shopId');
      
      // Charger les transferts en attente depuis le cache local
      debugPrint('📂 Chargement cache local...');
      await _loadLocalPendingTransfers();
      debugPrint('✅ Cache local chargé: ${_pendingTransfers.length} transferts');
      
      // Vérifier les opérations supprimées
      await _checkForDeletedOperations();
      
      // Démarrer la synchronisation automatique toutes les 30 secondes
      debugPrint('⏰ Démarrage auto-sync...');
      startAutoSync();
      
      // Première synchronisation immédiate
      debugPrint('🚀 Lancement première synchronisation...');
      await syncTransfers();
      
      // IMPORTANT: Si après la première sync, on n'a toujours aucun transfert ET une erreur,
      // cela signifie probablement un problème de connexion à la première utilisation
      if (_pendingTransfers.isEmpty && _error != null) {
        debugPrint('⚠️ Première utilisation: Aucune donnée et erreur détectée');
        debugPrint('   💡 Cela peut être normal si aucun transfert n\'existe pour ce shop');
        debugPrint('   💡 OU un problème de connexion. Vérifiez: $_error');
      }
      
      debugPrint('✅ Initialisation TransferSyncService terminée');
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR initialisation TransferSyncService: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Supprimer complètement les opérations supprimées de toutes les sources de stockage locales
  Future<void> _removeDeletedOperationsLocally(List<String> deletedCodeOpsList) async {
    try {
      if (deletedCodeOpsList.isEmpty) {
        return;
      }
      
      debugPrint('🗑️ Suppression locale de ${deletedCodeOpsList.length} opérations supprimées');
      
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Supprimer des transferts en attente en mémoire
      final initialPendingCount = _pendingTransfers.length;
      _pendingTransfers.removeWhere((op) => 
          op.codeOps != null && deletedCodeOpsList.contains(op.codeOps));
      final removedFromPending = initialPendingCount - _pendingTransfers.length;
      
      // 2. Supprimer du cache des transferts en attente
      int removedFromCache = 0;
      final cachedJson = prefs.getString('pending_transfers_cache');
      if (cachedJson != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedJson);
          final cachedTransfers = cachedList
              .map((json) => OperationModel.fromJson(json))
              .toList();
          
          final initialCachedCount = cachedTransfers.length;
          cachedTransfers.removeWhere((op) => 
              op.codeOps != null && deletedCodeOpsList.contains(op.codeOps));
          removedFromCache = initialCachedCount - cachedTransfers.length;
          
          if (removedFromCache > 0) {
            await prefs.setString(
              'pending_transfers_cache',
              jsonEncode(cachedTransfers.map((op) => op.toJson()).toList()),
            );
            debugPrint('💾 $removedFromCache opérations supprimées du cache');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la suppression du cache: $e');
        }
      }
      
      // 3. Supprimer des transferts locaux (local_transfers)
      int removedFromLocal = 0;
      final localTransfersJson = prefs.getString('local_transfers');
      if (localTransfersJson != null) {
        try {
          final List<dynamic> localList = jsonDecode(localTransfersJson);
          final localTransfers = localList
              .map((json) => OperationModel.fromJson(json))
              .toList();
          
          final initialLocalCount = localTransfers.length;
          localTransfers.removeWhere((op) => 
              op.codeOps != null && deletedCodeOpsList.contains(op.codeOps));
          removedFromLocal = initialLocalCount - localTransfers.length;
          
          if (removedFromLocal > 0) {
            await prefs.setString(
              'local_transfers',
              jsonEncode(localTransfers.map((op) => op.toJson()).toList()),
            );
            debugPrint('💾 $removedFromLocal opérations supprimées de local_transfers');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la suppression de local_transfers: $e');
        }
      }
      
      // 4. Supprimer des validations en attente
      int removedFromValidations = 0;
      final validationsJson = prefs.getString('pending_validations');
      if (validationsJson != null) {
        try {
          final List<dynamic> validationsList = jsonDecode(validationsJson);
          final initialValidationsCount = validationsList.length;
          validationsList.removeWhere((validation) => 
              deletedCodeOpsList.contains(validation['code_ops']));
          removedFromValidations = initialValidationsCount - validationsList.length;
          
          if (removedFromValidations > 0) {
            await prefs.setString('pending_validations', jsonEncode(validationsList));
            debugPrint('💾 $removedFromValidations validations supprimées');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la suppression des validations: $e');
        }
      }
      
      // 5. Supprimer des opérations dans LocalDB (using code_ops directly)
      int removedFromLocalDB = 0;
      try {
        // Supprimer directement les opérations par code_ops
        await LocalDB.instance.deleteOperationsByCodeOpsList(deletedCodeOpsList);
        removedFromLocalDB = deletedCodeOpsList.length;
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la suppression des opérations de LocalDB: $e');
      }
      
      // 6. Notifier les listeners si des opérations ont été supprimées
      if (removedFromPending > 0) {
        await _savePendingTransfersToCache(); // Sauvegarder le cache mis à jour
        debugPrint('✅ $removedFromPending opérations supprimées du cache en attente');
      }
      
      final totalRemoved = removedFromPending + removedFromCache + removedFromLocal + 
                          removedFromValidations + removedFromLocalDB;
      debugPrint('✅ Nettoyage local terminé: $totalRemoved opérations supprimées au total ' +
                 '($removedFromPending mémoire, $removedFromCache cache, $removedFromLocal local_transfers, ' +
                 '$removedFromValidations validations, $removedFromLocalDB LocalDB)');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage local: $e');
    }
  }

  /// Vérifier les opérations supprimées sur le serveur
  Future<void> _checkForDeletedOperations() async {
    try {
      if (_pendingTransfers.isEmpty) {
        return;
      }
      
      debugPrint('🔍 Vérification des opérations supprimées sur le serveur...');
      
      // Extraire les code_ops des transferts en attente
      final codeOpsList = _pendingTransfers
          .where((op) => op.codeOps != null && op.codeOps!.isNotEmpty)
          .map((op) => op.codeOps!)
          .toList();
      
      if (codeOpsList.isEmpty) {
        return;
      }
      
      // Appeler l'API pour vérifier les opérations supprimées
      final baseUrl = await AppConfig.getApiBaseUrl();
      final cleanUrl = baseUrl.trim();
      final url = Uri.parse('$cleanUrl/sync/operations/check_deleted.php');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code_ops_list': codeOpsList,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la vérification des opérations supprimées');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final deletedOperations = List<String>.from(data['deleted_operations']);
          
          if (deletedOperations.isNotEmpty) {
            debugPrint('🗑️ ${deletedOperations.length} opérations supprimées trouvées sur le serveur');
            
            // Supprimer les opérations locales de toutes les sources de stockage
            await _removeDeletedOperationsLocally(deletedOperations);
          } else {
            debugPrint('✅ Aucune opération supprimée trouvée sur le serveur');
          }
        } else {
          debugPrint('⚠️ Erreur lors de la vérification des opérations supprimées: ${data['error']}');
        }
      } else {
        debugPrint('⚠️ Erreur HTTP ${response.statusCode} lors de la vérification des opérations supprimées');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la vérification des opérations supprimées: $e');
      // Ne pas bloquer le processus en cas d'erreur
    }
  }
  
  /// Démarrer la synchronisation automatique
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isSyncing && _shopId > 0) {
        debugPrint('⏰ [🕒 ${DateTime.now().toIso8601String()}] Synchronisation auto des transferts (shop: $_shopId)...');
        syncTransfers();
      } else if (_shopId == 0) {
        debugPrint('⚠️ Synchronisation ignorée: shop_id non initialisé');
      } else {
        debugPrint('⏸️ Synchronisation ignorée: synchronisation déjà en cours');
      }
    });
    debugPrint('✅ Synchronisation automatique démarrée (interval: 1 minute, shop: $_shopId)');
  }

  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Synchronisation automatique arrêtée');
  }

  /// Forcer un rafraîchissement immédiat depuis l'API (sans cache)
  /// Utilisé par le widget de validation pour obtenir les données les plus fraîches
  Future<void> forceRefreshFromAPI() async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours, ignoré');
      return;
    }

    debugPrint('🔄 [FORCE-REFRESH] Rafraîchissement forcé depuis l\'API (bypass cache)...');
    
    // Marquer comme en cours de synchronisation
    _isSyncing = true;
    _error = null;
    notifyListeners();
    
    try {
      // Télécharger directement depuis l'API sans fallback sur cache
      await _downloadPendingTransfers(bypassCacheOnError: true);
      
      debugPrint('✅ [FORCE-REFRESH] Terminé: ${_pendingTransfers.length} transferts en attente');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Valider un transfert (server-first puis refresh depuis API)
  /// Retourne true si la validation a réussi
  Future<bool> validateTransfer(String codeOps, String newStatus) async {
    try {
      debugPrint('🔄 [VALIDATE] Validation: $codeOps → $newStatus');
      
      final statut = newStatus == 'PAYE' ? 'validee' : 'terminee';
      
      // 1️⃣ Mettre à jour le serveur
      final baseUrl = await AppConfig.getApiBaseUrl();
      final cleanUrl = baseUrl.trim();
      final url = Uri.parse('$cleanUrl/sync/operations/update-status.php');
      
      debugPrint('🌐 [VALIDATE] Envoi vers serveur: $codeOps → $statut');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code_ops': codeOps,
          'statut': statut,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la connexion au serveur');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ [VALIDATE] Mise à jour serveur réussie');
          
          // 2️⃣ Mettre à jour IMMÉDIATEMENT la liste locale (optimistic update)
          debugPrint('💾 [VALIDATE] Mise à jour locale immédiate...');
          _pendingTransfers.removeWhere((op) => op.codeOps == codeOps);
          await _savePendingTransfersToCache();
          notifyListeners();
          debugPrint('✅ [VALIDATE] Transfert $codeOps retiré de la liste locale');
          
          // 3️⃣ Rafraîchir les données depuis l'API (pour synchroniser)
          debugPrint('🔄 [VALIDATE] Rafraîchissement depuis l\'API...');
          await forceRefreshFromAPI();
          
          return true;
        } else {
          debugPrint('❌ [VALIDATE] Erreur serveur: ${data['message']}');
          return false;
        }
      } else if (response.statusCode == 404) {
        // Cas spécial: transfert non trouvé sur le serveur
        debugPrint('❌ [VALIDATE] Erreur HTTP 404 - Transfert non trouvé sur le serveur');
        debugPrint('📝 Réponse du serveur: ${response.body}');
        
        // Supprimer complètement le transfert de toutes les sources de stockage locales
        await _removeDeletedOperationsLocally([codeOps]);
        
        // Rafraîchir depuis l'API pour s'assurer de l'état actuel
        await forceRefreshFromAPI();
        
        // Signaler l'erreur spécifique
        throw Exception('Transfert non trouvé sur le serveur. Il a peut-être déjà été traité ou supprimé.');
      } else {
        debugPrint('❌ [VALIDATE] Erreur HTTP ${response.statusCode}');
        debugPrint('📝 Réponse du serveur: ${response.body}');
        return false;
      }
    } catch (e) {
      // Ne pas attraper les exceptions spécifiques que nous voulons faire remonter
      if (e is Exception && e.toString().contains('Transfert non trouvé sur le serveur')) {
        // Laisser passer cette exception spécifique
        rethrow;
      }
      
      debugPrint('❌ [VALIDATE] Erreur: $e');
      return false;
    }
  }

  /// Marquer un FLOT comme servi localement et le retirer immédiatement de la liste des FLOTs en attente
  /// Cette méthode fournit une mise à jour optimiste immédiate de l'interface utilisateur
  void markFlotAsServedLocally(String codeOps) {
    debugPrint('💾 [FLOT-SERVED] Retrait immédiat du FLOT $codeOps de la liste locale...');
    _pendingTransfers.removeWhere((op) => op.codeOps == codeOps && op.type == OperationType.flotShopToShop);
    notifyListeners();
    debugPrint('✅ [FLOT-SERVED] FLOT $codeOps retiré de la liste locale');
  }

  /// Synchronisation bidirectionnelle des opérations
  /// TÂCHE 1: Télécharger TOUTES les opérations (serveur → local)
  /// TÂCHE 2: Uploader nos validations locales (local → serveur)
  /// TÂCHE 3: Mettre à jour les statuts locaux depuis le serveur
  Future<void> syncTransfers() async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation déjà en cours, ignoré');
      return;
    }

    if (_shopId == 0) {
      debugPrint('❌ Shop ID non initialisé, impossible de synchroniser');
      return;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();
    
    final startTime = DateTime.now();

    try {
      debugPrint('🔄 Début synchronisation pour shop: $_shopId');
      debugPrint('   🎯 4 tâches: 1) Check deleted ops, 2) Download TOUTES les ops, 3) Upload validations, 4) Update statuts');

      // TÂCHE 0: Vérifier les opérations supprimées
      debugPrint('🔍 [TÂCHE 0/4] Vérification des opérations supprimées...');
      await _checkForDeletedOperations();

      // TÂCHE 1: Télécharger TOUTES les opérations du shop (serveur → local)
      debugPrint('📥 [TÂCHE 1/4] Download TOUTES les opérations du shop $_shopId...');
      await _downloadPendingTransfers();

      // TÂCHE 2: Uploader nos validations locales (PAYÉ/ANNULÉ) vers le serveur (local → serveur)
      debugPrint('📤 [TÂCHE 2/4] Upload de nos validations locales vers le serveur...');
      await _uploadLocalValidations();

      // TÂCHE 3: Mettre à jour les statuts locaux si changés sur le serveur
      debugPrint('🔄 [TÂCHE 3/4] Update des statuts locaux depuis le serveur...');
      await _updateTransferStatuses();

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ Synchronisation terminée avec succès (durée: ${duration.inSeconds}s)');
      debugPrint('📊 Transferts en attente: ${_pendingTransfers.length}');

    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erreur synchronisation: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Télécharger TOUTES les opérations du shop depuis le serveur
  /// Remplace l'ancien système qui ne chargeait que les transferts "en attente"
  /// ANCIEN ENDPOINT (obsolète): pending-transfers.php?shop_id=X - Ne chargeait que statut="enAttente"
  /// NOUVEAU ENDPOINT: all-operations.php?shop_id=X - Charge TOUTES les opérations (4 derniers jours)
  /// 
  /// [bypassCacheOnError] Si true, ne charge PAS le cache local en cas d'erreur (pour forceRefresh)
  Future<void> _downloadPendingTransfers({bool bypassCacheOnError = false}) async {
    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      final cleanUrl = baseUrl.trim(); // Nettoyer l'URL
      
      // Nouveau endpoint unifié qui récupère TOUTES les opérations
      // Pour agent: filtré par shop_id
      // Pour admin: toutes les opérations (shop_id=null)
      // ANCIEN: '$cleanUrl/sync/operations/pending-transfers.php' (OBSOLÈTE)
      final url = Uri.parse('$cleanUrl/sync/operations/all-operations.php').replace(
        queryParameters: _shopId > 0 ? {'shop_id': _shopId.toString()} : {},
      );
      
      debugPrint('📥 Téléchargement TOUTES opérations depuis: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout téléchargement opérations');
        },
      );

      debugPrint('📥 Réponse HTTP: ${response.statusCode}');
      debugPrint('📥 Corps réponse: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('📥 Réponse serveur succès: ${data['message']}');
          debugPrint('📥 Mode: ${data['mode']}');
          if (data['days'] != null) {
            debugPrint('📅 Période: ${data['days']} derniers jours (depuis ${data['date_limit']})');
          }
          
          if (data['operations'] != null) {
            final List<dynamic> operationsJson = data['operations'];
            
            debugPrint('📥 Nombre d\'opérations reçues: ${operationsJson.length}');
            
            // Parser TOUTES les opérations
            final serverOperations = operationsJson
                .map((json) => OperationModel.fromJson(json))
                .toList();

            debugPrint('📥 Opérations converties: ${serverOperations.length}');
            
            // Afficher un résumé par type et statut (OPTIMISÉ: résumé condensé)
            final flotCount = serverOperations.where((op) => op.type == OperationType.flotShopToShop).length;
            final transferCount = serverOperations.where((op) => 
                op.type == OperationType.transfertNational ||
                op.type == OperationType.transfertInternationalEntrant ||
                op.type == OperationType.transfertInternationalSortant
            ).length;
            debugPrint('📥 Reçu: ${serverOperations.length} ops (Transferts: $transferCount, FLOTs: $flotCount)');

            debugPrint('📥 Sauvegarde ou mise à jour en local...');
            // Sauvegarder ou mettre à jour TOUTES les opérations en local (SharedPreferences + LocalDB)
            final mergedOperations = await _saveOrUpdateLocalTransfers(serverOperations);
            
            // IMPORTANT: Sauvegarder TOUTES les opérations dans LocalDB (SQLite) aussi
            debugPrint('💾 [SYNC] Sauvegarde de ${mergedOperations.length} opérations dans LocalDB (SQLite)...');
            for (var op in mergedOperations) {
              await LocalDB.instance.saveOperation(op);
            }
            debugPrint('✅ [SYNC] Toutes les opérations sauvegardées dans LocalDB');

            // IMPORTANT: NE PAS recharger OperationService() ici car cela peut causer des boucles
            // Les opérations sont déjà sauvegardées dans LocalDB et seront chargées quand nécessaire
            // L'appel à loadOperations() sera fait par le widget qui en a besoin

            // Mettre à jour la liste des transferts en attente (pour validation)
            // CRITIQUE: Filtrer uniquement les transferts EN ATTENTE pour ce shop
            // IMPORTANT: Utiliser les données FUSIONNÉES (local + serveur) pas juste serveur
            
            _pendingTransfers = mergedOperations
                .where((op) {
                  // 1. Doit être un transfert OU un depot/retrait OU un FLOT
                  final isTransfer = op.type == OperationType.transfertNational ||
                     op.type == OperationType.transfertInternationalEntrant ||
                     op.type == OperationType.transfertInternationalSortant;
                     
                  final isDepotOrRetrait = op.type == OperationType.depot ||
                     op.type == OperationType.retrait;
                     
                  final isFlot = op.type == OperationType.flotShopToShop;
                  
                  // 2. Pour les transferts: doit être EN ATTENTE
                  // Pour les depot/retrait: peut être VALIDE ou TERMINE (pas d'attente)
                  // Pour les FLOTs: doit être EN ATTENTE
                  bool isPending;
                  if (isTransfer || isFlot) {
                    // Transferts et FLOTs doivent être en attente
                    isPending = op.statut == OperationStatus.enAttente;
                  } else if (isDepotOrRetrait) {
                    // Depot/Retrait peuvent être validés ou terminés
                    isPending = (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee);
                  } else {
                    // Autres types, par défaut en attente
                    isPending = op.statut == OperationStatus.enAttente;
                  }
                  
                  // 3. Pour les transferts: ce shop doit être la DESTINATION (pour validation)
                  // Pour les depot/retrait: ce shop doit être la SOURCE
                  // Pour les FLOTs: ce shop doit être la DESTINATION (pour validation)
                  bool isForThisShop;
                  if (isTransfer || isFlot) {
                    // Pour les transferts et FLOTs: ce shop doit être la DESTINATION
                    isForThisShop = op.shopDestinationId == _shopId;
                  } else if (isDepotOrRetrait) {
                    // Pour les depot/retrait: ce shop doit être la SOURCE
                    isForThisShop = op.shopSourceId == _shopId;
                  } else {
                    // Par défaut, utiliser la destination
                    isForThisShop = op.shopDestinationId == _shopId;
                  }
                  
                  // Debug logging uniquement pour les FLOTs en mode verbose
                  // if (isFlot) debugPrint('   📦 FLOT: ${op.codeOps} pending=$isPending forShop=$isForThisShop');
                  
                  final shouldInclude = (isTransfer || isDepotOrRetrait || isFlot) && isPending && isForThisShop;
                  
                  return shouldInclude;
                })
                .toList();

            // Log uniquement le résumé (optimisé pour performance)
            final pendingFlots = _pendingTransfers.where((op) => op.type == OperationType.flotShopToShop).length;
            debugPrint('✅ Sync: ${_pendingTransfers.length} en attente (dont $pendingFlots FLOTs)');

            // Sauvegarder dans le cache
            await _savePendingTransfersToCache();
            notifyListeners();
            debugPrint('✅ Téléchargement terminé: ${serverOperations.length} opérations synchronisées');
          } else {
            debugPrint('⚠️ Aucune opération dans la réponse');
            _pendingTransfers = [];
            notifyListeners();
          }
        } else {
          debugPrint('❌ Erreur serveur: ${data['message']}');
          _pendingTransfers = [];
          notifyListeners();
        }
      } else {
        debugPrint('❌ Erreur HTTP: ${response.statusCode} - ${response.body}');
        _pendingTransfers = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Erreur téléchargement opérations: $e');
      
      // En cas d'erreur, charger depuis le cache local SEULEMENT si autorisé
      if (!bypassCacheOnError) {
        debugPrint('💾 Chargement depuis cache local (mode fallback)...');
        await _loadLocalPendingTransfers();
        
        // Si le cache est également vide, cela signifie une première utilisation avec erreur réseau
        if (_pendingTransfers.isEmpty) {
          debugPrint('⚠️ PREMIÈRE UTILISATION: Cache vide + Erreur API');
          debugPrint('   → Aucune donnée à afficher. Veuillez:');
          debugPrint('   1. Vérifier votre connexion réseau');
          debugPrint('   2. Vérifier que le serveur API est accessible');
          debugPrint('   3. Réessayer la synchronisation manuellement');
        }
      } else {
        debugPrint('⚠️ Cache bypassé - liste vidée en cas d\'erreur');
        _pendingTransfers = [];
      }
      
      // Important: remonter l'erreur pour affichage dans l'UI
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Uploader nos validations locales (PAYÉ/ANNULÉ) vers le serveur
  Future<void> _uploadLocalValidations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final validationsJson = prefs.getString('pending_validations');
      
      if (validationsJson == null || validationsJson.isEmpty) {
        debugPrint('📤 Aucune validation locale à uploader');
        return;
      }

      final List<dynamic> validationsList = jsonDecode(validationsJson);
      if (validationsList.isEmpty) {
        debugPrint('📤 Aucune validation locale à uploader');
        return;
      }

      int uploadedCount = 0;
      List<Map<String, dynamic>> failedValidations = [];

      debugPrint('📤 Upload de ${validationsList.length} validation(s) locale(s)...');

      for (var validationData in validationsList) {
        try {
          final codeOps = validationData['code_ops'];
          final newStatus = validationData['statut']; // PAYE ou ANNULE
          
          final baseUrl = await AppConfig.getApiBaseUrl();
          final cleanUrl = baseUrl.trim();
          final url = Uri.parse('$cleanUrl/sync/operations/update-status');
          
          debugPrint('📤 Upload validation: $codeOps → $newStatus');
          
          // Uploader la validation vers le serveur
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'code_ops': codeOps,
              'statut': newStatus,
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Timeout upload validation');
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              uploadedCount++;
              debugPrint('✅ Validation uploadée: $codeOps → $newStatus');
            } else {
              debugPrint('⚠️ Échec validation $codeOps: ${data['message']}');
              failedValidations.add(validationData);
            }
          } else {
            debugPrint('⚠️ Erreur HTTP ${response.statusCode} pour $codeOps');
            failedValidations.add(validationData);
          }
        } catch (e) {
          debugPrint('⚠️ Erreur upload validation: $e');
          failedValidations.add(validationData);
        }
      }

      // Supprimer les validations uploadées avec succès
      if (uploadedCount > 0) {
        if (failedValidations.isEmpty) {
          await prefs.remove('pending_validations');
          debugPrint('✅ Toutes les validations uploadées, cache vidé');
        } else {
          await prefs.setString('pending_validations', jsonEncode(failedValidations));
          debugPrint('📤 ${uploadedCount} validations uploadées, ${failedValidations.length} en attente');
        }
      } else {
        debugPrint('⚠️ Aucune validation uploadée');
      }

    } catch (e) {
      debugPrint('⚠️ Erreur upload validations locales: $e');
    }
  }

  /// Mettre à jour les statuts des transferts locaux depuis le serveur
  /// Vérifie les transferts que NOUS avons initiés et qui sont encore en attente
  Future<void> _updateTransferStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localTransfersJson = prefs.getString('local_transfers');
      
      if (localTransfersJson == null) {
        debugPrint('🔄 Aucun transfert local à mettre à jour');
        return;
      }

      final List<dynamic> localList = jsonDecode(localTransfersJson);
      final List<OperationModel> localTransfers = localList
          .map((json) => OperationModel.fromJson(json))
          .toList();

      bool hasUpdates = false;
      int updatedCount = 0;

      debugPrint('🔄 [TÂCHE 3] Vérification des transferts initiés par nous (en attente)...');

      // Vérifier uniquement les transferts que NOUS avons initiés et qui sont en attente
      for (int i = 0; i < localTransfers.length; i++) {
        final localOp = localTransfers[i];
        
        // Filtrer: transferts initiés par nous ET en attente
        if (localOp.codeOps == null) continue;
        if (localOp.shopSourceId != _shopId) continue;  // Initiés par nous
        if (localOp.statut != OperationStatus.enAttente) continue;    // En attente

        try {
          final baseUrl = await AppConfig.getApiBaseUrl();
          final cleanUrl = baseUrl.trim();
          final url = Uri.parse('$cleanUrl/sync/operations/status').replace(
            queryParameters: {'code_ops': localOp.codeOps ?? ''},
          );
          
          debugPrint('🔍 Vérification statut: ${localOp.codeOps}');
          
          // Vérifier le statut sur le serveur
          final response = await http.get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Timeout vérification statut');
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            
            if (data['success'] == true && data['data'] != null) {
              final serverStatus = data['data']['statut'] as String;
              
              // Si le statut a changé sur le serveur
              if (serverStatus != localOp.statut) {
                debugPrint('🔄 Mise à jour statut: ${localOp.codeOps} ${localOp.statut} → $serverStatus');
                
                // Mettre à jour l'opération locale avec les données du serveur
                localTransfers[i] = OperationModel.fromJson(data['data']);
                hasUpdates = true;
                updatedCount++;
              }
            }
          } else if (response.statusCode == 404) {
            debugPrint('⚠️ Transfert ${localOp.codeOps} non trouvé sur le serveur');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur vérification statut ${localOp.codeOps}: $e');
        }
      }

      // Sauvegarder les mises à jour
      if (hasUpdates) {
        await prefs.setString(
          'local_transfers',
          jsonEncode(localTransfers.map((op) => op.toJson()).toList()),
        );
        debugPrint('✅ $updatedCount statut(s) mis à jour en local');
        
        // Recharger les transferts en attente dans _pendingTransfers
        _pendingTransfers = localTransfers
            .where((op) => op.statut == OperationStatus.enAttente)
            .toList();
        await _savePendingTransfersToCache();
        notifyListeners();
      } else {
        debugPrint('✅ Aucun statut à mettre à jour');
      }

    } catch (e) {
      debugPrint('❌ Erreur mise à jour statuts: $e');
    }
  }

  /// Sauvegarder ou mettre à jour les transferts dans le stockage local
  /// Retourne la liste des opérations après fusion (local + serveur)
  Future<List<OperationModel>> _saveOrUpdateLocalTransfers(List<OperationModel> serverTransfers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('local_transfers');
      
      Map<String, OperationModel> transfersMap = {};

      // Charger les transferts locaux existants
      if (localJson != null) {
        final List<dynamic> localList = jsonDecode(localJson);
        for (var json in localList) {
          final op = OperationModel.fromJson(json);
          if (op.codeOps != null) {
            transfersMap[op.codeOps!] = op;
          }
        }
      }

      // Enrichir les opérations du serveur avec les désignations de shop manquantes
      final enrichedServerTransfers = await _enrichTransfersWithShopNames(serverTransfers);

      // Ajouter ou mettre à jour avec les transferts du serveur
      int added = 0;
      int updated = 0;
      
      for (var serverOp in enrichedServerTransfers) {
        if (serverOp.codeOps == null) continue;
        
        if (transfersMap.containsKey(serverOp.codeOps!)) {
          // Mettre à jour si le serveur a une version plus récente
          final localOp = transfersMap[serverOp.codeOps!]!;
          if (_isServerNewer(serverOp, localOp)) {
            transfersMap[serverOp.codeOps!] = serverOp;
            updated++;
          }
          // Sinon, on garde la version locale déjà dans transfersMap
        } else {
          // Nouveau transfert
          transfersMap[serverOp.codeOps!] = serverOp;
          added++;
        }
      }

      // Sauvegarder
      final mergedList = transfersMap.values.toList();
      await prefs.setString(
        'local_transfers',
        jsonEncode(mergedList.map((op) => op.toJson()).toList()),
      );

      debugPrint('💾 Transferts sauvegardés: $added nouveaux, $updated mis à jour');
      
      // Retourner la liste fusionnée
      return mergedList;

    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde locale: $e');
      // En cas d'erreur, retourner les données du serveur
      return serverTransfers;
    }
  }

  /// Enrichir les transferts avec les noms de shops si manquants
  Future<List<OperationModel>> _enrichTransfersWithShopNames(List<OperationModel> transfers) async {
    try {
      // Charger tous les shops depuis LocalDB
      final shops = await LocalDB.instance.getAllShops();
      if (shops.isEmpty) {
        debugPrint('⚠️ Aucun shop trouvé pour enrichir les transferts');
        return transfers;
      }

      // Créer un map shop_id -> designation pour recherche rapide
      final shopMap = {for (var shop in shops) shop.id: shop.designation};

      // Enrichir chaque transfert si les désignations manquent
      final enrichedTransfers = transfers.map((op) {
        String? sourceDesignation = op.shopSourceDesignation;
        String? destDesignation = op.shopDestinationDesignation;

        // Si shop_source_designation manquante, la récupérer depuis le map
        if ((sourceDesignation == null || sourceDesignation.isEmpty) && op.shopSourceId != null) {
          sourceDesignation = shopMap[op.shopSourceId];
          if (sourceDesignation != null) {
            debugPrint('🔧 Enrichissement: shop_source_id=${op.shopSourceId} → $sourceDesignation');
          }
        }

        // Si shop_destination_designation manquante, la récupérer depuis le map
        if ((destDesignation == null || destDesignation.isEmpty) && op.shopDestinationId != null) {
          destDesignation = shopMap[op.shopDestinationId];
          if (destDesignation != null) {
            debugPrint('🔧 Enrichissement: shop_dest_id=${op.shopDestinationId} → $destDesignation');
          }
        }

        // Si au moins une désignation a été trouvée, retourner une copie avec les désignations
        if (sourceDesignation != op.shopSourceDesignation || destDesignation != op.shopDestinationDesignation) {
          return op.copyWith(
            shopSourceDesignation: sourceDesignation,
            shopDestinationDesignation: destDesignation,
          );
        }

        // Sinon retourner l'opération telle quelle
        return op;
      }).toList();

      debugPrint('✅ Enrichissement terminé: ${enrichedTransfers.length} opérations traitées');
      return enrichedTransfers;

    } catch (e) {
      debugPrint('⚠️ Erreur enrichissement transfers: $e');
      return transfers; // Retourner les transferts non enrichis en cas d'erreur
    }
  }

  /// Vérifier si le transfert du serveur est plus récent
  bool _isServerNewer(OperationModel serverOp, OperationModel localOp) {
    // CRITIQUE: Ne PAS écraser les validations locales!
    // Si l'opération est validée/terminée localement mais en attente sur le serveur,
    // GARDER la version locale (elle sera uploadée lors de la prochaine sync)
    
    final localIsValidated = localOp.statut == OperationStatus.validee || 
                             localOp.statut == OperationStatus.terminee ||
                             localOp.statut == OperationStatus.annulee;
    final serverIsPending = serverOp.statut == OperationStatus.enAttente;
    
    if (localIsValidated && serverIsPending) {
      debugPrint('⚠️ ${localOp.codeOps}: Garder version locale (validée) vs serveur (en attente)');
      return false; // Garder la version locale
    }
    
    // Si le serveur est validé/terminé et local en attente, prendre le serveur
    final serverIsValidated = serverOp.statut == OperationStatus.validee || 
                               serverOp.statut == OperationStatus.terminee ||
                               serverOp.statut == OperationStatus.annulee;
    final localIsPending = localOp.statut == OperationStatus.enAttente;
    
    if (serverIsValidated && localIsPending) {
      debugPrint('✅ ${localOp.codeOps}: Prendre version serveur (validée) vs local (en attente)');
      return true; // Prendre la version serveur
    }
    
    // Comparer les dates de mise à jour (lastModifiedAt)
    if (serverOp.lastModifiedAt != null && localOp.lastModifiedAt != null) {
      if (serverOp.lastModifiedAt!.isAfter(localOp.lastModifiedAt!)) {
        debugPrint('🔄 ${localOp.codeOps}: Serveur plus récent (${serverOp.lastModifiedAt} vs ${localOp.lastModifiedAt})');
        return true;
      }
      debugPrint('🔒 ${localOp.codeOps}: Local plus récent, garder version locale');
      return false;
    }
    
    // Fallback: comparer dateOp
    if (serverOp.dateOp.isAfter(localOp.dateOp)) {
      return true;
    }
    
    return false;
  }

  /// Charger les transferts en attente depuis le cache local
  Future<void> _loadLocalPendingTransfers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('pending_transfers_cache');
      
      if (cachedJson != null) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        _pendingTransfers = cachedList
            .map((json) => OperationModel.fromJson(json))
            .toList();
        
        debugPrint('📂 Chargé ${_pendingTransfers.length} transferts en attente depuis le cache');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement cache: $e');
      _pendingTransfers = [];
      notifyListeners();
    }
  }

  /// Sauvegarder les transferts en attente dans le cache
  Future<void> _savePendingTransfersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_transfers_cache',
        jsonEncode(_pendingTransfers.map((op) => op.toJson()).toList()),
      );
      debugPrint('💾 Cache mis à jour: ${_pendingTransfers.length} transferts');
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde cache: $e');
    }
  }

  /// Sauvegarder l'heure de dernière synchronisation
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_transfer_sync', _lastSyncTime!.toIso8601String());
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde last sync time: $e');
    }
  }

  /// Ajouter une validation locale à uploader (lorsqu'un agent valide un transfert)
  Future<void> addLocalValidation(String codeOps, String newStatus) async {
    try {
      // Valider le statut - utiliser les valeurs ENUM de la table MySQL
      if (newStatus != 'validee' && newStatus != 'terminee') {
        debugPrint('❌ Statut invalide: $newStatus (doit être validee ou terminee)');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final validationsJson = prefs.getString('pending_validations') ?? '[]';
      final List<dynamic> validationsList = jsonDecode(validationsJson);
      
      // Vérifier si cette validation existe déjà
      final existingIndex = validationsList.indexWhere(
        (v) => v['code_ops'] == codeOps
      );
      
      final validation = {
        'code_ops': codeOps,
        'statut': newStatus,
        'validated_at': DateTime.now().toIso8601String(),
      };
      
      if (existingIndex >= 0) {
        // Mettre à jour la validation existante
        validationsList[existingIndex] = validation;
        debugPrint('🔄 Validation mise à jour: $codeOps → $newStatus');
      } else {
        // Ajouter la nouvelle validation
        validationsList.add(validation);
        debugPrint('➕ Validation ajoutée: $codeOps → $newStatus');
      }
      
      await prefs.setString('pending_validations', jsonEncode(validationsList));
      debugPrint('💾 ${validationsList.length} validation(s) en attente d\'upload');
      
      // Déclencher une synchronisation immédiate
      syncTransfers();
    } catch (e) {
      debugPrint('❌ Erreur ajout validation locale: $e');
    }
  }

  /// Retirer un transfert de la liste des transferts en attente (après validation)
  void removePendingTransfer(OperationModel transfer) {
    _pendingTransfers.removeWhere((t) => t.id == transfer.id || t.codeOps == transfer.codeOps);
    debugPrint('❌ Transfert retiré de la liste: ${transfer.codeOps} (reste: ${_pendingTransfers.length})');
    notifyListeners();
  }

  /// Obtenir les transferts en attente pour un shop spécifique
  /// Retourne uniquement les transferts ENTRANTS (où le shop est destination)
  /// EXCLUT les FLOTs (flotShopToShop) qui ont leur propre section de gestion
  List<OperationModel> getPendingTransfersForShop(int shopId) {
    // Logs simplifiés - éviter de logger tous les transferts à chaque appel
    final filtered = _pendingTransfers.where((op) {
      // EXCLURE les FLOTs (ont leur propre section)
      if (op.type == OperationType.flotShopToShop) return false;
      
      // Uniquement les transferts où notre shop est la destination (transferts entrants)
      final shopDest = op.shopDestinationId;
      final statut = op.statut;
      final shopMatch = shopDest == shopId;
      final statutMatch = statut == OperationStatus.enAttente;
      return shopMatch && statutMatch;
    }).toList();
    
    // Log uniquement le résultat final (évite spam de logs)
    debugPrint('📊 getPendingTransfersForShop($shopId): ${filtered.length} transferts (sur ${_pendingTransfers.length} total)');
    return filtered;
  }
  
  /// Retourne uniquement les FLOTs ENTRANTS (où le shop est destination)
  List<OperationModel> getPendingFlotsForShop(int shopId) {
    debugPrint('🔍 getPendingFlotsForShop called with shopId: $shopId');
    debugPrint('   Total pending transfers in service: ${_pendingTransfers.length}');
    
    final filtered = _pendingTransfers.where((op) {
      // UNIQUEMENT les FLOTs
      if (op.type != OperationType.flotShopToShop) {
        debugPrint('   ❌ Rejected (not flotShopToShop): codeOps=${op.codeOps}, type=${op.type?.name}');
        return false;
      }
      
      // FLOTs où notre shop est la destination (FLOTs entrants)
      final shopDest = op.shopDestinationId;
      final statut = op.statut;
      final shopMatch = shopDest == shopId;
      final statutMatch = statut == OperationStatus.enAttente;
      
      debugPrint('   🔍 Checking: codeOps=${op.codeOps}, shopDest=$shopDest, statut=${statut?.name}, shopMatch=$shopMatch, statutMatch=$statutMatch');
      
      // Additional debug info
      if (!shopMatch) {
        debugPrint('   ℹ️  Shop mismatch: expected $shopId, got $shopDest');
      }
      if (!statutMatch) {
        debugPrint('   ℹ️  Status mismatch: expected enAttente, got ${statut?.name}');
      }
      
      return shopMatch && statutMatch;
    }).toList();
    
    debugPrint('📊 getPendingFlotsForShop($shopId): ${filtered.length} FLOTs en attente (sur ${_pendingTransfers.length} total)');
    
    // Log details of filtered FLOTs
    if (filtered.isNotEmpty) {
      debugPrint('   🔍 Filtered FLOTs details:');
      for (var flot in filtered) {
        debugPrint('     - ${flot.codeOps}: ${flot.montantNet} ${flot.devise}, shop_src=${flot.shopSourceId}, shop_dst=${flot.shopDestinationId}, statut=${flot.statut?.name}');
      }
    }
    
    // Also log ALL FLOTs in _pendingTransfers for debugging
    final allFlots = _pendingTransfers.where((op) => op.type == OperationType.flotShopToShop).toList();
    if (allFlots.isNotEmpty) {
      debugPrint('   📦 ALL FLOTs in _pendingTransfers:');
      for (var flot in allFlots) {
        debugPrint('     - ${flot.codeOps}: shop_dst=${flot.shopDestinationId}, statut=${flot.statut?.name}, type=${flot.type?.name}');
      }
    } else {
      debugPrint('   📦 No FLOTs found in _pendingTransfers');
    }
    
    return filtered;
  }

  /// Nettoyer le cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_transfers_cache');
      await prefs.remove('local_transfers');
      await prefs.remove('unsynced_transfers');
      await prefs.remove('last_transfer_sync');
      
      _pendingTransfers = [];
      _lastSyncTime = null;
      notifyListeners();
      
      debugPrint('🗑️ Cache nettoyé');
    } catch (e) {
      debugPrint('⚠️ Erreur nettoyage cache: $e');
    }
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
