import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/operation_model.dart';
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

      if (depotsRetraits.isEmpty) {
        debugPrint('✅ [DEPOT/RETRAIT] Aucune opération à synchroniser');
        _lastSyncTime = DateTime.now();
        return;
      }

      // Upload vers le serveur
      await _uploadDepotsRetraits(depotsRetraits);

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
            'Content-Type': 'application/json',
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
