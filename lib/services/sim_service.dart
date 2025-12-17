import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
import '../models/sim_model.dart';
import '../models/sim_movement_model.dart';
import '../models/operation_model.dart';
import '../models/virtual_transaction_model.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'operation_service.dart';

class SimService extends ChangeNotifier {
  static final SimService _instance = SimService._internal();
  static SimService get instance => _instance;
  
  SimService._internal();

  List<SimModel> _sims = [];
  List<SimMovementModel> _movements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SimModel> get sims => _sims;
  List<SimMovementModel> get movements => _movements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger toutes les SIMs
  Future<void> loadSims({int? shopId}) async {
    _setLoading(true);
    try {
      foundation.debugPrint('🔍 [SimService.loadSims] Début chargement...');
      foundation.debugPrint('   Paramètre shopId: $shopId');
      
      final allSims = await LocalDB.instance.getAllSims(shopId: shopId);
      
      // CRITICAL: Remove duplicates by ID to prevent dropdown assertion errors
      // AND validate SIM data to prevent invalid SIMs from causing sync errors
      final simsMap = <int, SimModel>{};
      int invalidSimCount = 0;
      for (var sim in allSims) {
        // Validation: Check that SIM has valid data
        if (sim.id != null && sim.numero.isNotEmpty && sim.shopId > 0) {
          simsMap[sim.id!] = sim; // Keep the last occurrence if duplicates
        } else {
          invalidSimCount++;
          foundation.debugPrint('⚠️ SIM ignorée: ID=${sim.id}, Numéro="${sim.numero}", Shop=${sim.shopId}');
        }
      }
      _sims = simsMap.values.toList();
      
      if (invalidSimCount > 0) {
        foundation.debugPrint('⚠️ $invalidSimCount SIMs invalides ignorées');
      }
      
      foundation.debugPrint('📊 [SimService.loadSims] Résultats:');
      foundation.debugPrint('   Total SIMs brutes: ${allSims.length}');
      foundation.debugPrint('   Total SIMs uniques: ${_sims.length}');
      if (allSims.length != _sims.length) {
        foundation.debugPrint('   ⚠️ ${allSims.length - _sims.length} doublons supprimés!');
      }
      
      if (_sims.isNotEmpty) {
        foundation.debugPrint('   Liste des SIMs:');
        for (var sim in _sims) {
          foundation.debugPrint('     - ID: ${sim.id}, Numéro: ${sim.numero}, Shop: ${sim.shopId}, Statut: ${sim.statut.name}');
        }
      } else {
        foundation.debugPrint('   ⚠️ AUCUNE SIM TROUVÉE !');
        foundation.debugPrint('   Vérification dans SharedPreferences...');
        
        // Vérifier directement dans SharedPreferences
        final prefs = await LocalDB.instance.database;
        final allKeys = prefs.getKeys();
        final simKeys = allKeys.where((k) => k.startsWith('sim_')).toList();
        foundation.debugPrint('   Clés "sim_" trouvées: ${simKeys.length}');
        for (var key in simKeys.take(5)) {
          final data = prefs.getString(key);
          foundation.debugPrint('     - $key: ${data?.substring(0, data.length > 100 ? 100 : data.length)}...');
        }
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des SIMs: $e';
      foundation.debugPrint('❌ [SimService.loadSims] Erreur: $_errorMessage');
      foundation.debugPrint('Stack trace: $e');
    }
    _setLoading(false);
    notifyListeners(); // Notify explicitly after loading
  }

  /// Charger l'historique des mouvements
  /// Si shopId est fourni, filtre les mouvements concernés par ce shop (ancien ou nouveau)
  Future<void> loadMovements({int? simId, int? shopId}) async {
    try {
      foundation.debugPrint('📝 [SimService.loadMovements] Chargement mouvements...');
      foundation.debugPrint('   Filtre simId: $simId');
      foundation.debugPrint('   Filtre shopId: $shopId');
      
      _movements = await LocalDB.instance.getAllSimMovements(simId: simId);
      
      // Si shopId est fourni, filtrer les mouvements concernés par ce shop
      if (shopId != null) {
        _movements = _movements.where((m) => 
          (m.ancienShopId == shopId) || (m.nouveauShopId == shopId)
        ).toList();
        foundation.debugPrint('   Mouvements filtrés pour shop $shopId: ${_movements.length}');
      }
      
      foundation.debugPrint('📋 ${_movements.length} mouvements chargés');
      if (_movements.isNotEmpty) {
        foundation.debugPrint('   Mouvements: ${_movements.map((m) => m.simNumero).take(5).join(", ")}...');
      }
      notifyListeners();
    } catch (e) {
      foundation.debugPrint('Erreur chargement mouvements: $e');
    }
  }

  /// Créer une nouvelle SIM
  Future<SimModel?> createSim({
    required String numero,
    required String operateur,
    required int shopId,
    String? shopDesignation,
    double soldeInitial = 0.0,
    required String creePar,
  }) async {
    _setLoading(true);
    try {
      foundation.debugPrint('🆕 [SimService.createSim] Début création SIM...');
      foundation.debugPrint('   Numéro: $numero');
      foundation.debugPrint('   Opérateur: $operateur');
      foundation.debugPrint('   Shop ID: $shopId');
      foundation.debugPrint('   Shop Désignation: $shopDesignation');
      foundation.debugPrint('   Solde Initial: $soldeInitial');
      foundation.debugPrint('   Créé par: $creePar');
      
      // Vérifier si le numéro existe déjà
      if (await _numeroExists(numero)) {
        _errorMessage = 'Ce numéro de SIM existe déjà';
        foundation.debugPrint('❌ [SimService.createSim] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return null;
      }

      final newSim = SimModel(
        numero: numero,
        operateur: operateur,
        shopId: shopId,
        shopDesignation: shopDesignation,
        soldeInitial: soldeInitial,
        soldeActuel: soldeInitial,
        statut: SimStatus.active,
        dateCreation: DateTime.now(),
        creePar: creePar,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: creePar,
      );
      
      foundation.debugPrint('📦 [SimService.createSim] Modèle SIM créé, sauvegarde dans LocalDB...');

      final savedSim = await LocalDB.instance.saveSim(newSim);
      foundation.debugPrint('✅ [SimService.createSim] SIM sauvegardée avec ID #${savedSim.id}');
      
      // VÉRIFICATION IMMÉDIATE: La SIM est-elle dans SharedPreferences?
      final prefs = await LocalDB.instance.database;
      final simKey = 'sim_${savedSim.id}';
      final simDataInPrefs = prefs.getString(simKey);
      if (simDataInPrefs != null) {
        foundation.debugPrint('✅ [SimService.createSim] VÉRIFICATION: SIM trouvée dans SharedPreferences!');
        foundation.debugPrint('   Clé: $simKey');
        foundation.debugPrint('   Données: ${simDataInPrefs.substring(0, simDataInPrefs.length > 150 ? 150 : simDataInPrefs.length)}...');
      } else {
        foundation.debugPrint('❌ [SimService.createSim] ERREUR: SIM NON trouvée dans SharedPreferences!');
      }

      // Enregistrer le mouvement initial (affectation)
      foundation.debugPrint('📝 [SimService.createSim] Création du mouvement initial...');
      await _createMovement(
        sim: savedSim,
        ancienShopId: null,
        nouveauShopId: shopId,
        nouveauShopDesignation: shopDesignation ?? 'Shop #$shopId',
        adminResponsable: creePar,
        motif: 'Affectation initiale',
      );
      foundation.debugPrint('✅ [SimService.createSim] Mouvement initial créé');

      // IMPORTANT: Recharger les SIMs ET les mouvements pour afficher partout
      foundation.debugPrint('🔄 [SimService.createSim] Rechargement des SIMs et mouvements...');
      await loadSims();
      await loadMovements();
      foundation.debugPrint('✅ [SimService.createSim] Rechargement terminé:');
      foundation.debugPrint('   SIMs en mémoire: ${_sims.length}');
      foundation.debugPrint('   Mouvements en mémoire: ${_movements.length}');
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners(); // ✅ Notifier explicitement après tout
      
      foundation.debugPrint('🎉 [SimService.createSim] CRÉATION TERMINÉE AVEC SUCCÈS !');
      return savedSim;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création de la SIM: $e';
      foundation.debugPrint('❌ [SimService.createSim] Erreur: $_errorMessage');
      foundation.debugPrint('Stack trace: $e');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Modifier l'affectation d'une SIM (déplacer vers un autre shop)
  Future<bool> moveSimToShop({
    required SimModel sim,
    required int nouveauShopId,
    required String nouveauShopDesignation,
    required String adminResponsable,
    String? motif,
  }) async {
    _setLoading(true);
    try {
      final updatedSim = sim.copyWith(
        shopId: nouveauShopId,
        shopDesignation: nouveauShopDesignation,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: adminResponsable,
      );

      await LocalDB.instance.updateSim(updatedSim);
      foundation.debugPrint('✅ SIM ${sim.numero} déplacée vers $nouveauShopDesignation');

      // Enregistrer le mouvement
      await _createMovement(
        sim: updatedSim,
        ancienShopId: sim.shopId,
        nouveauShopId: nouveauShopId,
        nouveauShopDesignation: nouveauShopDesignation,
        adminResponsable: adminResponsable,
        motif: motif ?? 'Déplacement de SIM',
      );

      // IMPORTANT: Recharger les SIMs ET les mouvements
      foundation.debugPrint('🔄 Rechargement des SIMs et mouvements après déplacement...');
      await loadSims();
      await loadMovements();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners(); // ✅ Notifier explicitement
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors du déplacement de la SIM: $e';
      foundation.debugPrint(_errorMessage);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Suspendre une SIM
  Future<bool> suspendSim({
    required SimModel sim,
    required String motif,
    required String suspendPar,
  }) async {
    _setLoading(true);
    try {
      final updatedSim = sim.copyWith(
        statut: SimStatus.suspendue,
        motifSuspension: motif,
        dateSuspension: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: suspendPar,
      );

      await LocalDB.instance.updateSim(updatedSim);
      foundation.debugPrint('⚠️ SIM ${sim.numero} suspendue: $motif');

      // IMPORTANT: Recharger pour afficher partout
      await loadSims();
      await loadMovements();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners(); // ✅ Notifier explicitement
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suspension de la SIM: $e';
      foundation.debugPrint(_errorMessage);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Réactiver une SIM
  Future<bool> reactivateSim({
    required SimModel sim,
    required String reactivePar,
  }) async {
    _setLoading(true);
    try {
      final updatedSim = sim.copyWith(
        statut: SimStatus.active,
        motifSuspension: null,
        dateSuspension: null,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: reactivePar,
      );

      await LocalDB.instance.updateSim(updatedSim);
      foundation.debugPrint('✅ SIM ${sim.numero} réactivée');

      // IMPORTANT: Recharger pour afficher partout
      await loadSims();
      await loadMovements();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners(); // ✅ Notifier explicitement
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la réactivation de la SIM: $e';
      foundation.debugPrint(_errorMessage);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour le solde d'une SIM
  Future<bool> updateSimSolde({
    required SimModel sim,
    required double nouveauSolde,
    required String modifiePar,
  }) async {
    try {
      final updatedSim = sim.copyWith(
        soldeActuel: nouveauSolde,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiePar,
      );

      await LocalDB.instance.updateSim(updatedSim);
      foundation.debugPrint('💰 Solde SIM ${sim.numero} mis à jour: $nouveauSolde');

      // IMPORTANT: Recharger pour afficher partout
      await loadSims();
      await loadMovements();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      notifyListeners(); // ✅ Notifier explicitement
      return true;
    } catch (e) {
      foundation.debugPrint('Erreur mise à jour solde: $e');
      notifyListeners();
      return false;
    }
  }

  /// Obtenir une SIM par numéro
  SimModel? getSimByNumero(String numero) {
    try {
      return _sims.firstWhere((sim) => sim.numero == numero);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir toutes les SIMs actives d'un shop
  List<SimModel> getActiveSimsByShop(int shopId) {
    return _sims.where((sim) => 
      sim.shopId == shopId && sim.statut == SimStatus.active
    ).toList();
  }

  /// Obtenir toutes les SIMs d'un opérateur
  List<SimModel> getSimsByOperateur(String operateur) {
    return _sims.where((sim) => sim.operateur == operateur).toList();
  }

  /// Calculer automatiquement les soldes d'une SIM par devise (CDF et USD)
  /// FORMULE: Solde = Solde Initial + TOUTES les Captures (même en attente) - Flots - Transferts
  /// NOTE: On compte les captures dès leur enregistrement, car l'argent est déjà reçu sur la SIM
  Future<Map<String, double>> calculateAutomaticSoldesByDevise(SimModel sim) async {
    try {
      // 1. Obtenir TOUTES les captures pour cette SIM (en attente + validées, sauf annulées)
      final toutesCaptures = await LocalDB.instance.getAllVirtualTransactions(
        simNumero: sim.numero,
      );
      
      // Filtrer: Exclure uniquement les captures annulées
      final capturesActives = toutesCaptures
          .where((t) => t.statut != VirtualTransactionStatus.annulee)
          .toList();
      
      // Séparer les captures par devise
      final capturesCdf = capturesActives.where((t) => t.devise == 'CDF').toList();
      final capturesUsd = capturesActives.where((t) => t.devise == 'USD').toList();
      
      // Calculer la somme des captures par devise
      final totalCapturesCdf = capturesCdf.fold<double>(0, (sum, trans) => sum + trans.montantVirtuel);
      final totalCapturesUsd = capturesUsd.fold<double>(0, (sum, trans) => sum + trans.montantVirtuel);
      
      // 2. Obtenir les retraits virtuels pour cette SIM
      final retraitsVirtuels = await LocalDB.instance.getAllRetraitsVirtuels(
        simNumero: sim.numero
      );
      
      // Séparer les retraits par devise
      final retraitsCdf = retraitsVirtuels.where((r) => r.devise == 'CDF').toList();
      final retraitsUsd = retraitsVirtuels.where((r) => r.devise == 'USD').toList();
      
      final totalRetraitsCdf = retraitsCdf.fold<double>(0, (sum, retrait) => sum + retrait.montant);
      final totalRetraitsUsd = retraitsUsd.fold<double>(0, (sum, retrait) => sum + retrait.montant);
      
      // FORMULE CORRECTE par devise: Solde = Initial + Captures - Retraits
      final soldeCdf = sim.soldeInitialCdf + totalCapturesCdf - totalRetraitsCdf;
      final soldeUsd = sim.soldeInitialUsd + totalCapturesUsd - totalRetraitsUsd;
      
      foundation.debugPrint('💰 [SIM Solde Auto] ${sim.numero}:');
      foundation.debugPrint('   CDF: Initial=${sim.soldeInitialCdf} + Captures=$totalCapturesCdf - Retraits=$totalRetraitsCdf = $soldeCdf');
      foundation.debugPrint('   USD: Initial=${sim.soldeInitialUsd} + Captures=$totalCapturesUsd - Retraits=$totalRetraitsUsd = $soldeUsd');
      
      return {
        'CDF': soldeCdf,
        'USD': soldeUsd,
      };
    } catch (e) {
      foundation.debugPrint('❌ Erreur calcul solde auto pour SIM ${sim.numero}: $e');
      return {
        'CDF': sim.soldeActuelCdf,
        'USD': sim.soldeActuelUsd,
      };
    }
  }

  /// Mettre à jour automatiquement les soldes d'une SIM basé sur les opérations (double devise)
  Future<bool> updateSoldeAutomatiquement(SimModel sim) async {
    try {
      final nouveauxSoldes = await calculateAutomaticSoldesByDevise(sim);
      final nouveauSoldeCdf = nouveauxSoldes['CDF'] ?? 0.0;
      final nouveauSoldeUsd = nouveauxSoldes['USD'] ?? 0.0;
      
      // Vérifier si les soldes ont changé significativement
      final cdfChanged = (nouveauSoldeCdf - sim.soldeActuelCdf).abs() > 0.01;
      final usdChanged = (nouveauSoldeUsd - sim.soldeActuelUsd).abs() > 0.01;
      
      if (cdfChanged || usdChanged) {
        final updatedSim = sim.copyWith(
          soldeActuelCdf: nouveauSoldeCdf,
          soldeActuelUsd: nouveauSoldeUsd,
          // Maintenir la compatibilité avec l'ancien système (solde USD comme référence)
          soldeActuel: nouveauSoldeUsd,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'auto_calculation',
        );

        await LocalDB.instance.updateSim(updatedSim);
        foundation.debugPrint('💰 Soldes SIM ${sim.numero} mis à jour automatiquement:');
        foundation.debugPrint('   CDF: ${sim.soldeActuelCdf} → $nouveauSoldeCdf');
        foundation.debugPrint('   USD: ${sim.soldeActuelUsd} → $nouveauSoldeUsd');

        // Recharger pour afficher partout
        await loadSims();
        await loadMovements();
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      foundation.debugPrint('❌ Erreur mise à jour solde auto pour SIM ${sim.numero}: $e');
      return false;
    }
  }

  /// Mettre à jour automatiquement les soldes de toutes les SIMs
  /// Utile après une synchronisation ou un changement important d'opérations
  Future<void> updateAllSimsSoldesAutomatiquement() async {
    try {
      foundation.debugPrint('🔄 Mise à jour automatique des soldes de toutes les SIMs...');
      
      // Recharger les opérations pour s'assurer d'avoir les dernières données
      final operationService = OperationService();
      await operationService.loadOperations();
      
      // Pour chaque SIM, recalculer le solde
      int updatedCount = 0;
      for (var sim in _sims) {
        final wasUpdated = await updateSoldeAutomatiquement(sim);
        if (wasUpdated) {
          updatedCount++;
        }
      }
      
      foundation.debugPrint('✅ Mise à jour automatique des soldes terminée pour ${_sims.length} SIMs ($updatedCount mises à jour)');
    } catch (e) {
      foundation.debugPrint('❌ Erreur mise à jour soldes auto pour toutes les SIMs: $e');
    }
  }

  /// Créer un mouvement dans l'historique
  Future<void> _createMovement({
    required SimModel sim,
    required int? ancienShopId,
    required int nouveauShopId,
    required String nouveauShopDesignation,
    required String adminResponsable,
    String? motif,
  }) async {
    try {
      final movement = SimMovementModel(
        simId: sim.id!,
        simNumero: sim.numero,
        ancienShopId: ancienShopId,
        ancienShopDesignation: ancienShopId != null ? sim.shopDesignation : null,
        nouveauShopId: nouveauShopId,
        nouveauShopDesignation: nouveauShopDesignation,
        adminResponsable: adminResponsable,
        motif: motif,
        dateMovement: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: adminResponsable,
      );

      await LocalDB.instance.saveSimMovement(movement);
      foundation.debugPrint('📝 Mouvement enregistré: ${movement.movementDescription}');
    } catch (e) {
      foundation.debugPrint('Erreur enregistrement mouvement: $e');
    }
  }

  /// Vérifier si un numéro de SIM existe déjà
  Future<bool> _numeroExists(String numero) async {
    final existingSims = await LocalDB.instance.getAllSims();
    return existingSims.any((sim) => sim.numero == numero);
  }

  /// Obtenir les statistiques des SIMs
  Map<String, dynamic> getSimsStats({int? shopId}) {
    final filteredSims = shopId != null 
        ? _sims.where((sim) => sim.shopId == shopId).toList()
        : _sims;

    final actives = filteredSims.where((s) => s.statut == SimStatus.active).length;
    final suspendues = filteredSims.where((s) => s.statut == SimStatus.suspendue).length;
    final perdues = filteredSims.where((s) => s.statut == SimStatus.perdue).length;

    final simsByOperateur = <String, int>{};
    for (var sim in filteredSims) {
      simsByOperateur[sim.operateur] = (simsByOperateur[sim.operateur] ?? 0) + 1;
    }

    final totalSolde = filteredSims.fold<double>(0, (sum, sim) => sum + sim.soldeActuel);

    return {
      'total': filteredSims.length,
      'actives': actives,
      'suspendues': suspendues,
      'perdues': perdues,
      'par_operateur': simsByOperateur,
      'solde_total': totalSolde,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Synchronisation en arrière-plan (non bloquante)
  void _syncInBackground() {
    Future.delayed(Duration.zero, () async {
      try {
        foundation.debugPrint('🔄 [SimService] Synchronisation en arrière-plan...');
        final syncService = SyncService();
        await syncService.syncAll();
        foundation.debugPrint('✅ [SimService] Synchronisation terminée');
      } catch (e) {
        foundation.debugPrint('⚠️ [SimService] Erreur sync (non bloquante): $e');
      }
    });
  }
}
