import 'package:flutter/foundation.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/journal_caisse_model.dart';
import '../models/operation_model.dart';
import 'local_db.dart';
import 'sync_service.dart';

/// Service pour gérer les FLOTS (approvisionnement de liquidité entre shops)
class FlotService extends ChangeNotifier {
  static final FlotService _instance = FlotService._internal();
  static FlotService get instance => _instance;
  
  FlotService._internal();

  List<flot_model.FlotModel> _flots = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentShopId;
  bool _currentIsAdmin = false;

  List<flot_model.FlotModel> get flots => _flots;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger tous les flots avec filtrage par rôle
  Future<void> loadFlots({int? shopId, bool isAdmin = false}) async {
    _setLoading(true);
    _currentShopId = shopId;
    _currentIsAdmin = isAdmin;
    
    try {
      if (isAdmin) {
        // Admin voit tous les flots
        _flots = await LocalDB.instance.getAllFlots();
        debugPrint('📊 ADMIN - Tous les flots chargés: ${_flots.length}');
      } else if (shopId != null) {
        // Shop voit seulement les flots où il est source ou destination
        _flots = await LocalDB.instance.getFlotsByShop(shopId);
        debugPrint('🏪 SHOP $shopId - Flots chargés: ${_flots.length}');
        
        // Debug: Afficher le détail
        final enCours = _flots.where((f) => f.statut == flot_model.StatutFlot.enRoute).length;
        final servis = _flots.where((f) => f.statut == flot_model.StatutFlot.servi).length;
        final annules = _flots.where((f) => f.statut == flot_model.StatutFlot.annule).length;
        debugPrint('   → En cours: $enCours | Servis: $servis | Annulés: $annules');
      } else {
        // Par défaut, charger tous les flots
        _flots = await LocalDB.instance.getAllFlots();
        debugPrint('📊 Par défaut - Tous les flots chargés: ${_flots.length}');
      }
      
      _errorMessage = null;
      debugPrint('💸 Flots chargés: ${_flots.length}');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des flots: $e';
      debugPrint('❌ $_errorMessage');
    }
    _setLoading(false);
  }

  /// Créer un nouveau flot
  Future<bool> createFlot({
    required int shopSourceId,
    required String shopSourceDesignation,
    required int shopDestinationId,
    required String shopDestinationDesignation,
    required double montant,
    required String devise,
    required flot_model.ModePaiement modePaiement,
    required int agentEnvoyeurId,
    String? agentEnvoyeurUsername,
    String? notes,
  }) async {
    try {
      final newFlot = flot_model.FlotModel(
        shopSourceId: shopSourceId,
        shopSourceDesignation: shopSourceDesignation,
        shopDestinationId: shopDestinationId,
        shopDestinationDesignation: shopDestinationDesignation,
        montant: montant,
        devise: devise,
        modePaiement: modePaiement,
        statut: flot_model.StatutFlot.enRoute,
        agentEnvoyeurId: agentEnvoyeurId,
        agentEnvoyeurUsername: agentEnvoyeurUsername,
        dateEnvoi: DateTime.now(),
        notes: notes,
        reference: _generateReference(shopSourceId, shopDestinationId),
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentEnvoyeurUsername',
      );

      // Sauvegarder dans LocalDB
      await LocalDB.instance.saveFlot(newFlot);
      
      // IMPORTANT: Réduire le capital du shop source immédiatement
      final shop = await LocalDB.instance.getShopById(shopSourceId);
      if (shop != null) {
        final updatedShop = shop.copyWith(
          capitalCash: modePaiement == flot_model.ModePaiement.cash 
              ? shop.capitalCash - montant 
              : shop.capitalCash,
          capitalAirtelMoney: modePaiement == flot_model.ModePaiement.airtelMoney 
              ? shop.capitalAirtelMoney - montant 
              : shop.capitalAirtelMoney,
          capitalMPesa: modePaiement == flot_model.ModePaiement.mPesa 
              ? shop.capitalMPesa - montant 
              : shop.capitalMPesa,
          capitalOrangeMoney: modePaiement == flot_model.ModePaiement.orangeMoney 
              ? shop.capitalOrangeMoney - montant 
              : shop.capitalOrangeMoney,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_$agentEnvoyeurUsername',
        );
        
        await LocalDB.instance.updateShop(updatedShop);
        debugPrint('✅ Capital réduit de $montant ${modePaiement.name} pour le shop $shopSourceDesignation');
      }
      
      // Créer une entrée journal de caisse pour tracer la sortie
      try {
        final journalEntry = JournalCaisseModel(
          shopId: shopSourceId,
          agentId: agentEnvoyeurId,
          libelle: 'FLOT envoyé à $shopDestinationDesignation',
          montant: montant,
          type: TypeMouvement.sortie,
          mode: _convertModePaiementToOperation(modePaiement),
          dateAction: DateTime.now(),
          notes: 'Réf: ${newFlot.reference}${notes != null ? ' - $notes' : ''}',
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_$agentEnvoyeurUsername',
        );
        
        // Sauvegarder via LocalDB (la table journal_caisse doit exister)
        final prefs = await LocalDB.instance.database;
        final journalList = prefs.getStringList('journal_caisse_${shopSourceId}') ?? [];
        journalList.add(journalEntry.toJson().toString());
        await prefs.setStringList('journal_caisse_${shopSourceId}', journalList);
        debugPrint('✅ Journal: FLOT envoyé - SORTIE de $montant ${modePaiement.name}');
      } catch (e) {
        debugPrint('⚠️ Erreur enregistrement journal: $e (non bloquant)');
      }
      
      // Recharger avec les paramètres actuels
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      // IMPORTANT: Synchroniser en arrière-plan avec retry automatique
      _syncFlotInBackground(newFlot);
      
      debugPrint('✅ Flot créé: $montant $devise de $shopSourceDesignation vers $shopDestinationDesignation');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }
  
  /// Convertir ModePaiement de FLOT vers ModePaiement d'Opération
  ModePaiement _convertModePaiementToOperation(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return ModePaiement.cash;
      case flot_model.ModePaiement.airtelMoney:
        return ModePaiement.airtelMoney;
      case flot_model.ModePaiement.mPesa:
        return ModePaiement.mPesa;
      case flot_model.ModePaiement.orangeMoney:
        return ModePaiement.orangeMoney;
    }
  }

  /// Mettre à jour un flot
  Future<bool> updateFlot(flot_model.FlotModel flot) async {
    try {
      // Mettre à jour dans LocalDB
      await LocalDB.instance.updateFlot(flot);
      
      // Recharger avec les paramètres actuels
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      debugPrint('✅ Flot mis à jour: ${flot.reference}');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// Marquer un flot comme servi (reçu)
  Future<bool> marquerFlotServi({
    required int flotId,
    required int agentRecepteurId,
    String? agentRecepteurUsername,
  }) async {
    try {
      final flot = _flots.firstWhere((f) => f.id == flotId);
      final updatedFlot = flot.copyWith(
        statut: flot_model.StatutFlot.servi,
        agentRecepteurId: agentRecepteurId,
        agentRecepteurUsername: agentRecepteurUsername,
        dateReception: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentRecepteurUsername',
      );

      // Mettre à jour dans LocalDB
      await LocalDB.instance.updateFlot(updatedFlot);
      
      // Recharger avec les paramètres actuels
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      // IMPORTANT: Synchroniser en arrière-plan avec retry automatique
      _syncFlotInBackground(updatedFlot);
      
      debugPrint('✅ Flot marqué servi: ${updatedFlot.reference}');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// Obtenir les flots en cours pour un shop
  List<flot_model.FlotModel> getFlotsEnCours(int shopId) {
    return _flots.where((f) => 
      f.statut == flot_model.StatutFlot.enRoute && 
      (f.shopSourceId == shopId || f.shopDestinationId == shopId)
    ).toList();
  }

  /// Obtenir les flots reçus pour un shop
  List<flot_model.FlotModel> getFlotsRecus(int shopId, {DateTime? date}) {
    return _flots.where((f) => 
      f.statut == flot_model.StatutFlot.servi && 
      f.shopDestinationId == shopId &&
      (date == null || _isSameDay(f.dateReception!, date))
    ).toList();
  }

  /// Générer une référence unique pour le flot
  String _generateReference(int shopSourceId, int shopDestinationId) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'FLOT-$shopSourceId-$shopDestinationId-$dateStr-$timeStr';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Synchronise un flot en arrière-plan sans bloquer l'interface
  /// Avec système de retry automatique (3 tentatives)
  Future<void> _syncFlotInBackground(flot_model.FlotModel flot) async {
    Future.microtask(() async {
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 5);
      
      while (retryCount < maxRetries) {
        try {
          debugPrint('🔄 [BACKGROUND] Synchronisation flot ${flot.reference} (tentative ${retryCount + 1}/$maxRetries)...');
          
          final syncService = SyncService();
          
          // Uploader le flot
          await syncService.uploadTableData('flots', 'background_sync');
          
          // Attendre un peu puis downloader pour vérifier
          await Future.delayed(const Duration(milliseconds: 500));
          await syncService.downloadTableData('flots', 'background_sync', 'system');
          
          debugPrint('✅ [BACKGROUND] Flot ${flot.reference} synchronisé avec succès');
          await _markFlotAsSynced(flot.id!);
          return; // Succès, sortir de la boucle
        } catch (e) {
          retryCount++;
          debugPrint('⚠️ [BACKGROUND] Échec synchronisation flot ${flot.reference} (tentative $retryCount/$maxRetries): $e');
          
          if (retryCount < maxRetries) {
            debugPrint('   ⏳ Nouvelle tentative dans ${retryDelay.inSeconds}s...');
            await Future.delayed(retryDelay);
          } else {
            debugPrint('❌ [BACKGROUND] Échec définitif après $maxRetries tentatives');
            debugPrint('   💡 Le flot restera en file d\'attente et sera retenté lors de la prochaine synchronisation');
            await _addToPendingSyncQueue(flot);
          }
        }
      }
    });
  }

  /// Marque un flot comme synchronisé
  Future<void> _markFlotAsSynced(int flotId) async {
    try {
      final flot = await LocalDB.instance.getFlotById(flotId);
      if (flot != null) {
        final updatedFlot = flot.copyWith(
          isSynced: true,
          syncedAt: DateTime.now(),
        );
        await LocalDB.instance.updateFlot(updatedFlot);
        debugPrint('✅ Flot $flotId marqué comme synchronisé');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du marquage du flot comme synchronisé: $e');
    }
  }

  /// Ajoute un flot à la file d'attente de synchronisation
  Future<void> _addToPendingSyncQueue(flot_model.FlotModel flot) async {
    try {
      // Marquer comme non synchronisé
      final updatedFlot = flot.copyWith(
        isSynced: false,
        syncedAt: null,
      );
      await LocalDB.instance.updateFlot(updatedFlot);
      debugPrint('📝 Flot ${flot.reference} ajouté à la file d\'attente de sync');
    } catch (e) {
      debugPrint('❌ Erreur ajout file d\'attente: $e');
    }
  }

  /// Retente la synchronisation de tous les flots en attente
  Future<void> retrySyncPendingFlots() async {
    try {
      final allFlots = await LocalDB.instance.getAllFlots();
      final unsyncedFlots = allFlots.where((f) => !(f.isSynced ?? false)).toList();
      
      if (unsyncedFlots.isEmpty) {
        debugPrint('✅ Aucun flot en attente de synchronisation');
        return;
      }
      
      debugPrint('🔄 Retry de ${unsyncedFlots.length} flot(s) en attente...');
      
      for (var flot in unsyncedFlots) {
        await _syncFlotInBackground(flot);
      }
    } catch (e) {
      debugPrint('❌ Erreur retry sync flots: $e');
    }
  }
}