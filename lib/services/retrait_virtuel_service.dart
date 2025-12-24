import 'package:flutter/foundation.dart';
import '../models/retrait_virtuel_model.dart';
import '../services/local_db.dart';
import '../services/retrait_virtuel_sync_service.dart';

/// Service principal pour la gestion des retraits virtuels avec synchronisation
class RetraitVirtuelService extends ChangeNotifier {
  static final RetraitVirtuelService _instance = RetraitVirtuelService._internal();
  static RetraitVirtuelService get instance => _instance;
  
  RetraitVirtuelService._internal();

  List<RetraitVirtuelModel> _retraits = [];
  bool _isLoading = false;
  String? _errorMessage;
  RetraitVirtuelSyncService _syncService = RetraitVirtuelSyncService();
  bool _isSyncing = false;
  String? _syncError;

  List<RetraitVirtuelModel> get retraits => _retraits;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncError => _syncError;
  RetraitVirtuelSyncService get syncService => _syncService;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      debugPrint('🔄 Initialisation RetraitVirtuelService pour shop: $shopId');
      await _syncService.initialize(shopId);
      
      // Écouter les changements d'état de synchronisation
      _syncService.addListener(_handleSyncStatusChange);
      
      // Charger les retraits initiaux
      await loadRetraits(shopId: shopId);
      
      debugPrint('✅ RetraitVirtuelService initialisé avec succès');
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur initialisation RetraitVirtuelService: $e';
      debugPrint('❌ $_errorMessage');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Gérer les changements d'état de synchronisation
  void _handleSyncStatusChange() {
    _isSyncing = _syncService.isSyncing;
    _syncError = _syncService.error;
    notifyListeners();
  }

  /// Charger tous les retraits (optionnellement filtrés)
  Future<void> loadRetraits({
    int? shopId,
    int? shopSourceId,
    int? shopDebiteurId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    RetraitVirtuelStatus? statut,
    bool forceSync = false,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔍 [RetraitVirtuelService] Chargement retraits...');
      debugPrint('   Filtre shopId: $shopId');
      debugPrint('   Filtre shopSourceId: $shopSourceId');
      debugPrint('   Filtre shopDebiteurId: $shopDebiteurId');
      debugPrint('   Filtre SIM: $simNumero');
      debugPrint('   Filtre dateDebut: $dateDebut');
      debugPrint('   Filtre dateFin: $dateFin');
      debugPrint('   Filtre statut: $statut');
      debugPrint('   Forcer sync: $forceSync');
      
      // Si forceSync est vrai, forcer une synchronisation avant de charger
      if (forceSync) {
        debugPrint('🔄 Forçage de la synchronisation...');
        await _syncService.syncRetraits();
      }
      
      // Charger depuis la base de données locale
      _retraits = await LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: shopSourceId,
        shopDebiteurId: shopDebiteurId,
        simNumero: simNumero,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
      );
      
      debugPrint('✅ [RetraitVirtuelService] ${_retraits.length} retraits chargés');
      
      // Log retrait details for debugging
      if (_retraits.isNotEmpty) {
        debugPrint('📋 Retrait details:');
        for (var i = 0; i < _retraits.length && i < 3; i++) {
          final r = _retraits[i];
          debugPrint('   #$i: SIM ${r.simNumero} - ${r.montant} ${r.devise} - ${r.statut.name}');
        }
        if (_retraits.length > 3) {
          debugPrint('   ... et ${_retraits.length - 3} retraits supplémentaires');
        }
      } else {
        debugPrint('ℹ️ Aucun retrait trouvé avec les filtres actuels');
      }
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur chargement retraits: $e';
      debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Créer un nouveau retrait virtuel
  Future<RetraitVirtuelModel?> createRetrait({
    required String simNumero,
    String? simOperateur,
    required int shopSourceId,
    String? shopSourceDesignation,
    required int shopDebiteurId,
    String? shopDebiteurDesignation,
    required double montant,
    String devise = 'USD',
    required double soldeAvant,
    required double soldeApres,
    required int agentId,
    String? agentUsername,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🆕 [RetraitVirtuelService] Création retrait...');
      debugPrint('   SIM: $simNumero');
      debugPrint('   Montant: $montant $devise');
      debugPrint('   Shop source: $shopSourceId');
      debugPrint('   Shop débiteur: $shopDebiteurId');
      
      final newRetrait = RetraitVirtuelModel(
        simNumero: simNumero,
        simOperateur: simOperateur,
        shopSourceId: shopSourceId,
        shopSourceDesignation: shopSourceDesignation,
        shopDebiteurId: shopDebiteurId,
        shopDebiteurDesignation: shopDebiteurDesignation,
        montant: montant,
        devise: devise,
        soldeAvant: soldeAvant,
        soldeApres: soldeApres,
        agentId: agentId,
        agentUsername: agentUsername,
        notes: notes,
        statut: RetraitVirtuelStatus.enAttente,
        dateRetrait: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'agent_$agentId',
      );
      
      debugPrint('📦 [RetraitVirtuelService] Sauvegarde retrait...');
      final savedRetrait = await LocalDB.instance.saveRetraitVirtuel(newRetrait);
      debugPrint('✅ [RetraitVirtuelService] Retrait sauvegardé avec ID #${savedRetrait.id}');
      
      // Recharger les retraits
      await loadRetraits(shopSourceId: shopSourceId);
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(savedRetrait);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return savedRetrait;
    } catch (e) {
      _errorMessage = 'Erreur création retrait: $e';
      debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Valider un remboursement (marquer comme remboursé)
  Future<bool> validateRemboursement({
    required RetraitVirtuelModel retrait,
    int? flotRemboursementId,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('✅ [RetraitVirtuelService] Validation remboursement...');
      debugPrint('   ID: ${retrait.id}');
      debugPrint('   SIM: ${retrait.simNumero}');
      debugPrint('   Montant: ${retrait.montant} ${retrait.devise}');
      
      if (retrait.statut != RetraitVirtuelStatus.enAttente) {
        _errorMessage = 'Ce retrait a déjà été traité';
        debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final updatedRetrait = retrait.copyWith(
        statut: RetraitVirtuelStatus.rembourse,
        dateRemboursement: DateTime.now(),
        flotRemboursementId: flotRemboursementId,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // IMPORTANT: Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.saveRetraitVirtuel(updatedRetrait);
      debugPrint('✅ [RetraitVirtuelService] Remboursement validé');
      
      // Recharger les retraits
      await loadRetraits(shopSourceId: retrait.shopSourceId);
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(updatedRetrait);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur validation remboursement: $e';
      debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Annuler un retrait
  Future<bool> cancelRetrait({
    required RetraitVirtuelModel retrait,
    String? motif,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('❌ [RetraitVirtuelService] Annulation retrait...');
      debugPrint('   ID: ${retrait.id}');
      debugPrint('   SIM: ${retrait.simNumero}');
      debugPrint('   Motif: $motif');
      
      if (retrait.statut != RetraitVirtuelStatus.enAttente) {
        _errorMessage = 'Seuls les retraits en attente peuvent être annulés';
        debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final updatedRetrait = retrait.copyWith(
        statut: RetraitVirtuelStatus.annule,
        notes: motif != null ? '${retrait.notes ?? ""}\nAnnulation: $motif' : retrait.notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // IMPORTANT: Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.saveRetraitVirtuel(updatedRetrait);
      debugPrint('✅ [RetraitVirtuelService] Retrait annulé');
      
      // Recharger les retraits
      await loadRetraits(shopSourceId: retrait.shopSourceId);
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(updatedRetrait);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur annulation retrait: $e';
      debugPrint('❌ [RetraitVirtuelService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Forcer une synchronisation complète
  Future<bool> syncNow() async {
    try {
      _isSyncing = true;
      _syncError = null;
      notifyListeners();
      
      debugPrint('🔄 Démarrage manuel de la synchronisation retraits...');
      final success = await _syncService.syncRetraits();
      
      if (success) {
        // Recharger les données après synchronisation
        await loadRetraits(forceSync: false);
      }
      
      return success;
    } catch (e) {
      _syncError = 'Erreur synchronisation retraits: $e';
      debugPrint('❌ $_syncError');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _syncService.removeListener(_handleSyncStatusChange);
    super.dispose();
  }

  /// Ajouter un retrait à la file de synchronisation
  Future<void> _addToSyncQueue(RetraitVirtuelModel retrait) async {
    try {
      await _syncService.addToSyncQueue(retrait);
      debugPrint('🔄 Retrait ajouté à la file de synchronisation: SIM ${retrait.simNumero}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Erreur ajout retrait à la file de synchronisation: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
