import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/operation_model.dart';
import '../models/depot_client_model.dart';
import 'local_db.dart';

/// Service de synchronisation spécialisé pour les DÉPÔTS et RETRAITS
/// Gère l'upload automatique vers le serveur
class DepotRetraitSyncService extends ChangeNotifier {
  static final DepotRetraitSyncService _instance = DepotRetraitSyncService._internal();
  factory DepotRetraitSyncService() => _instance;
  DepotRetraitSyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  /// Synchronise les dépôts et retraits non synchronisés
  Future<void> syncDepotsRetraits() async {
    if (_isSyncing) {
      debugPrint('⚠️ [DEPOT/RETRAIT] Synchronisation déjà en cours');
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 [DEPOT/RETRAIT] === DÉBUT SYNCHRONISATION ===');

      // ÉTAPE 1: Télécharger les dépôts clients depuis le serveur
      await _downloadDepotsClients();

      // ÉTAPE 2: Uploader les opérations locales non synchronisées
      // Récupérer toutes les opérations locales
      final allOperations = await LocalDB.instance.getAllOperations();
      
      // Filtrer les dépôts et retraits non synchronisés
      final depotsRetraits = allOperations.where((op) {
        final isDepotRetrait = op.type == OperationType.depot || 
                               op.type == OperationType.retrait ||
                               op.type == OperationType.retraitMobileMoney;
        final notSynced = op.isSynced != true;
        return isDepotRetrait && notSynced;
      }).toList();

      debugPrint('📊 [DEPOT/RETRAIT] Trouvé ${depotsRetraits.length} opérations non synchronisées');
      _pendingCount = depotsRetraits.length;
      notifyListeners();

      if (depotsRetraits.isNotEmpty) {
        // Upload vers le serveur
        await _uploadDepotsRetraits(depotsRetraits);
      } else {
        debugPrint('✅ [DEPOT/RETRAIT] Aucune opération à uploader');
      }

      _lastSyncTime = DateTime.now();
      debugPrint('✅ [DEPOT/RETRAIT] === SYNCHRONISATION TERMINÉE ===');

    } catch (e, stackTrace) {
      debugPrint('❌ [DEPOT/RETRAIT] Erreur synchronisation: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Upload les dépôts et retraits vers le serveur
  Future<void> _uploadDepotsRetraits(List<OperationModel> operations) async {
    int uploaded = 0;
    int failed = 0;

    final baseUrl = await AppConfig.getSyncBaseUrl();
    final timeout = AppConfig.syncTimeout;

    for (final operation in operations) {
      try {
        debugPrint('📤 [DEPOT/RETRAIT] Upload ${operation.type.name} - code_ops=${operation.codeOps}');
        debugPrint('   Montant: ${operation.montantNet} ${operation.devise}');
        debugPrint('   Client: ${operation.clientNom}');
        debugPrint('   Statut: ${operation.statut.name}');
        debugPrint('   Agent ID: ${operation.agentId}, Shop ID: ${operation.shopSourceId}');
        
        // VALIDATION CRITIQUE: Vérifier que les données essentielles sont présentes
        if (operation.agentId == null) {
          debugPrint('❌ [DEPOT/RETRAIT] REJETÉ: agent_id manquant');
          failed++;
          continue;
        }
        
        if (operation.shopSourceId == null) {
          debugPrint('❌ [DEPOT/RETRAIT] REJETÉ: shop_source_id manquant');
          failed++;
          continue;
        }

        // Préparer les données pour l'upload
        final operationData = operation.toJson();
        
        // CRITIQUE: Retirer l'ID local (timestamp) qui pose problème avec MySQL AUTO_INCREMENT
        // Le serveur utilisera code_ops comme clé unique
        operationData.remove('id');
        
        debugPrint('   📦 Payload: entities count=1, user_id=${operation.lastModifiedBy ?? 'depot_retrait_sync'}');
        debugPrint('   🔑 Clés JSON: ${operationData.keys.join(", ")}');
        debugPrint('   📄 Type: ${operationData['type']}, Statut: ${operationData['statut']}');
        debugPrint('   👤 Agent: id=${operationData['agent_id']}, username=${operationData['agent_username']}');
        debugPrint('   🏪 Shop: id=${operationData['shop_source_id']}, designation=${operationData['shop_source_designation']}');
        debugPrint('   🆔 code_ops: ${operationData['code_ops']} (id local retiré)');
        debugPrint('   ⚠️ VERIFICATION: id présent? ${operationData.containsKey('id')}');

        // Upload vers le serveur
        final url = '$baseUrl/operations/upload.php';
        debugPrint('   🌐 URL: $url');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'entities': [operationData],
            'user_id': operation.lastModifiedBy ?? 'depot_retrait_sync',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(timeout);

        if (response.statusCode == 200) {
          debugPrint('   📥 Réponse serveur: ${response.body}');
          final result = jsonDecode(response.body);
          
          debugPrint('   🔍 success=${result['success']}, message=${result['message']}');
          
          if (result['success'] == true) {
            // Marquer comme synchronisé dans LocalDB
            final syncedOp = operation.copyWith(
              isSynced: true,
              syncedAt: DateTime.now(),
            );
            await LocalDB.instance.updateOperation(syncedOp);
            
            uploaded++;
            debugPrint('✅ [DEPOT/RETRAIT] ${operation.type.name} synchronisé: ${operation.codeOps}');
          } else {
            failed++;
            debugPrint('❌ [DEPOT/RETRAIT] Échec serveur: ${result['message']}');
          }
        } else {
          failed++;
          debugPrint('❌ [DEPOT/RETRAIT] Erreur HTTP ${response.statusCode}');
          debugPrint('   Body: ${response.body}');
        }

      } catch (e) {
        failed++;
        debugPrint('❌ [DEPOT/RETRAIT] Erreur upload ${operation.codeOps}: $e');
      }
    }

    _pendingCount = failed;
    notifyListeners();

    debugPrint('📊 [DEPOT/RETRAIT] Résultat: $uploaded réussis, $failed échoués');
  }

  /// Télécharge les dépôts clients depuis le serveur
  Future<void> _downloadDepotsClients() async {
    debugPrint('📥 [DEPOT CLIENT] ========== DÉBUT DOWNLOAD ==========');
    try {
      debugPrint('📥 [DEPOT CLIENT] Étape 1: Récupération config...');
      
      final baseUrl = await AppConfig.getSyncBaseUrl();
      final timeout = AppConfig.syncTimeout;
      debugPrint('📥 [DEPOT CLIENT] Base URL: $baseUrl');
      
      // STRATÉGIE INTELLIGENTE: Utiliser le dernier updated_at local
      debugPrint('📥 [DEPOT CLIENT] Étape 2: Chargement dépôts locaux...');
      final existing = await LocalDB.instance.getAllDepotsClients();
      debugPrint('📥 [DEPOT CLIENT] Dépôts locaux: ${existing.length}');
      String? sinceParam;
      
      if (existing.isEmpty) {
        // PREMIÈRE UTILISATION - Télécharger TOUT
        debugPrint('   🆕 Première synchronisation - téléchargement complet');
        sinceParam = null;
      } else {
        // SYNCHRONISATION INCRÉMENTALE - Chercher le dernier updated_at local
        DateTime? lastUpdated;
        for (var depot in existing) {
          if (depot.updatedAt != null) {
            if (lastUpdated == null || depot.updatedAt!.isAfter(lastUpdated)) {
              lastUpdated = depot.updatedAt;
            }
          }
        }
        
        if (lastUpdated != null) {
          sinceParam = lastUpdated.toIso8601String();
          debugPrint('   🔄 Sync incrémentale depuis: $sinceParam');
        } else {
          debugPrint('   ⚠️ Aucun updated_at trouvé - téléchargement complet');
          sinceParam = null;
        }
      }
      
      // Construire l'URL avec paramètres
      final url = sinceParam != null
          ? '$baseUrl/depot_clients/changes.php?since=$sinceParam&limit=1000'
          : '$baseUrl/depot_clients/changes.php?limit=1000';
      
      debugPrint('   🌐 URL: $url');
      debugPrint('📥 [DEPOT CLIENT] Étape 4: Envoi requête HTTP GET...');
      
      final response = await http.get(Uri.parse(url)).timeout(timeout);
      
      debugPrint('📥 [DEPOT CLIENT] Étape 5: Réponse reçue - Status: ${response.statusCode}');
      debugPrint('📥 [DEPOT CLIENT] Body length: ${response.body.length} chars');
      
      if (response.statusCode == 200) {
        debugPrint('📥 [DEPOT CLIENT] Étape 6: Parsing JSON...');
        final result = jsonDecode(response.body);
        
        debugPrint('📥 [DEPOT CLIENT] Étape 7: Vérification réponse...');
        debugPrint('📥 [DEPOT CLIENT] success=${result['success']}, entities=${result['entities']?.length ?? 0}');
        
        if (result['success'] == true && result['entities'] != null) {
          final List<dynamic> entities = result['entities'];
          debugPrint('   📊 ${entities.length} dépôts clients reçus');
          debugPrint('📥 [DEPOT CLIENT] Étape 8: Traitement de ${entities.length} entités...');
          
          int saved = 0;
          int updated = 0;
          
          for (var depotData in entities) {
            try {
              debugPrint('📥 [DEPOT CLIENT] Traitement dépôt: ${depotData['id']} - SIM: ${depotData['sim_numero']}');
              // Convertir en modèle
              final depot = DepotClientModel.fromMap(depotData);
              
              // Vérifier si existe déjà dans LocalDB
              // IMPORTANT: Comparer par clé métier (SIM + téléphone + montant + date)
              // car les IDs serveur != IDs locaux (timestamp)
              final existing = await LocalDB.instance.getAllDepotsClients();
              final existingDepot = existing.where((d) => 
                d.simNumero == depot.simNumero &&
                d.telephoneClient == depot.telephoneClient &&
                d.montant == depot.montant &&
                d.dateDepot.difference(depot.dateDepot).abs().inSeconds < 5  // Tolérance 5s
              ).firstOrNull;
              
              debugPrint('   🔍 Recherche doublon: SIM=${depot.simNumero}, Tel=${depot.telephoneClient}, Montant=${depot.montant}');
              debugPrint('   🔍 Doublon trouvé: ${existingDepot != null} (ID local: ${existingDepot?.id})');
              
              if (existingDepot == null) {
                // Nouveau dépôt - insérer (sans ID pour que LocalDB génère un timestamp)
                final newDepot = DepotClientModel(
                  shopId: depot.shopId,
                  simNumero: depot.simNumero,
                  montant: depot.montant,
                  telephoneClient: depot.telephoneClient,
                  dateDepot: depot.dateDepot,
                  userId: depot.userId,
                  createdAt: depot.createdAt,
                  updatedAt: depot.updatedAt,
                );
                await LocalDB.instance.insertDepotClient(newDepot);
                saved++;
                debugPrint('   ➕ Nouveau dépôt: ${depot.simNumero} - \$${depot.montant}');
              } else {
                // Existe déjà - mettre à jour avec l'ID local
                final updatedDepot = depot.copyWith(id: existingDepot.id);
                await LocalDB.instance.updateDepotClient(updatedDepot);
                updated++;
                debugPrint('   🔄 Mis à jour: ${depot.simNumero} - \$${depot.montant} (ID local: ${existingDepot.id})');
              }
            } catch (e) {
              debugPrint('   ⚠️ Erreur traitement dépôt: $e');
            }
          }
          
          debugPrint('✅ [DEPOT CLIENT] Download terminé: $saved nouveaux, $updated mis à jour');
          debugPrint('📥 [DEPOT CLIENT] ========== FIN DOWNLOAD (SUCCÈS) ==========');
          
          // Notifier les listeners si des données ont été modifiées
          if (saved > 0 || updated > 0) {
            debugPrint('🔔 [DEPOT CLIENT] Notification des listeners (${saved + updated} changements)');
            notifyListeners();
          }
        } else {
          debugPrint('⚠️ [DEPOT CLIENT] Aucun dépôt dans la réponse');
          debugPrint('📥 [DEPOT CLIENT] ========== FIN DOWNLOAD (PAS DE DONNÉES) ==========');
        }
      } else {
        debugPrint('❌ [DEPOT CLIENT] Erreur HTTP ${response.statusCode}');
        debugPrint('📥 [DEPOT CLIENT] ========== FIN DOWNLOAD (ERREUR HTTP) ==========');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [DEPOT CLIENT] Erreur download: $e');
      debugPrint('📥 [DEPOT CLIENT] Stack trace: $stackTrace');
      debugPrint('📥 [DEPOT CLIENT] ========== FIN DOWNLOAD (EXCEPTION) ==========');
      // Ne pas bloquer la sync - continuer
    }
  }

  /// Ajoute un dépôt/retrait à synchroniser
  Future<void> queueOperation(OperationModel operation) async {
    if (operation.type != OperationType.depot && 
        operation.type != OperationType.retrait &&
        operation.type != OperationType.retraitMobileMoney) {
      debugPrint('⚠️ [DEPOT/RETRAIT] Type non supporté: ${operation.type.name}');
      return;
    }

    debugPrint('📋 [DEPOT/RETRAIT] Ajout à la queue: ${operation.type.name} - ${operation.codeOps}');
    
    // Sauvegarder avec isSynced = false
    final unsyncedOp = operation.copyWith(isSynced: false);
    await LocalDB.instance.saveOperation(unsyncedOp);
    
    _pendingCount++;
    notifyListeners();

    // Déclencher la synchronisation en arrière-plan
    _syncInBackground();
  }

  /// Synchronisation en arrière-plan (non bloquante)
  void _syncInBackground() {
    Future.microtask(() async {
      await Future.delayed(const Duration(seconds: 2)); // Petit délai pour grouper les opérations
      await syncDepotsRetraits();
    });
  }

  /// Vérifie s'il y a des opérations en attente
  Future<int> getPendingCount() async {
    final allOperations = await LocalDB.instance.getAllOperations();
    final pending = allOperations.where((op) {
      final isDepotRetrait = op.type == OperationType.depot || 
                             op.type == OperationType.retrait ||
                             op.type == OperationType.retraitMobileMoney;
      final notSynced = op.isSynced != true;
      return isDepotRetrait && notSynced;
    }).length;
    
    _pendingCount = pending;
    notifyListeners();
    return pending;
  }

  /// Force une synchronisation immédiate
  Future<void> forceSyncNow() async {
    debugPrint('🚀 [DEPOT/RETRAIT] Force synchronisation immédiate');
    await syncDepotsRetraits();
  }
}
