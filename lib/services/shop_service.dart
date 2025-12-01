import 'package:flutter/widgets.dart';
import '../models/shop_model.dart';
import '../models/caisse_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/cloture_caisse_model.dart';
import 'local_db.dart';
import 'sync_service.dart';
import '../utils/sync_diagnostics.dart';

class ShopService extends ChangeNotifier {
  static final ShopService _instance = ShopService._internal();
  static ShopService get instance => _instance;
  
  ShopService._internal();

  List<ShopModel> _shops = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ShopModel> get shops => _shops;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Charger tous les shops
  Future<void> loadShops({bool forceRefresh = false, bool clearBeforeLoad = false, int? excludeShopId}) async {
    // ✅ OPTIMISATION: Si les shops sont déjà chargés et pas de forceRefresh, ne rien faire
    if (!forceRefresh && !clearBeforeLoad && _shops.isNotEmpty) {
      debugPrint('✅ [ShopService] Utilisation du cache (${_shops.length} shops)');
      return;
    }
    
    _setLoading(true);
    try {
      // Si clearBeforeLoad, supprimer toutes les données locales pour forcer le rechargement depuis le serveur
      // NOTE: Ceci est utilisé uniquement pendant la synchronisation pour garantir des données fraîches
      if (clearBeforeLoad) {
        debugPrint('🗑️ [ShopService] Suppression des shops en local avant rechargement...');
        await LocalDB.instance.clearAllShops();
        _shops.clear();
      }
      
      // Si forceRefresh, vider le cache SAUF le shop à exclure
      if (forceRefresh && excludeShopId != null) {
        // Préserver le shop de l'utilisateur actuel
        final currentShop = _shops.firstWhere(
          (s) => s.id == excludeShopId,
          orElse: () => _shops.first,
        );
        _shops.clear();
        _shops.add(currentShop); // Garder le shop actuel en cache
        debugPrint('✅ [ShopService] Shop ID $excludeShopId préservé dans le cache');
      } else if (forceRefresh) {
        _shops.clear();
      }
      
      // Charger depuis la base locale
      final allShops = await LocalDB.instance.getAllShops();
      
      // Si on a exclu un shop, fusionner sans doublon
      if (forceRefresh && excludeShopId != null) {
        for (final shop in allShops) {
          if (shop.id != excludeShopId) {
            _shops.add(shop);
          }
        }
      } else {
        _shops = allShops;
      }
      
      // Si clearBeforeLoad a été utilisé mais qu'il n'y a pas de données, log un avertissement
      if (clearBeforeLoad && _shops.isEmpty) {
        debugPrint('⚠️ [ShopService] Aucun shop chargé après clearBeforeLoad - Vérifiez la synchronisation');
      }
      
      _errorMessage = null;
      notifyListeners(); // Notifier les widgets après le chargement
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des shops: $e';
      debugPrint(_errorMessage);
    }
    _setLoading(false);
  }

  // Créer un nouveau shop
  Future<bool> createShop({
    required String designation,
    required String localisation,
    required double capitalInitial,
    required double capitalCash,
    required double capitalAirtelMoney,
    required double capitalMPesa,
    required double capitalOrangeMoney,
  }) async {
    _setLoading(true);
    try {
      // Générer un ID unique
      final shopId = DateTime.now().millisecondsSinceEpoch;
      
      final newShop = ShopModel(
        id: shopId,
        designation: designation,
        localisation: localisation,
        capitalInitial: capitalInitial,
        capitalActuel: capitalInitial,
        capitalCash: capitalCash,
        capitalAirtelMoney: capitalAirtelMoney,
        capitalMPesa: capitalMPesa,
        capitalOrangeMoney: capitalOrangeMoney,
        createdAt: DateTime.now(),
        // Marquer comme non synchronisé pour forcer l'upload
        isSynced: false,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'local_user',
      );

      // Sauvegarder localement
      await LocalDB.instance.saveShop(newShop);
      
      // Créer les caisses par défaut pour ce shop avec les capitaux spécifiés
      await _createDefaultCaisses(shopId, capitalCash, capitalAirtelMoney, capitalMPesa, capitalOrangeMoney);
      
      // Créer une clôture de la veille comme solde antérieur au lieu d'une opération de dépôt
      await _createInitialClosureAsAnterieur(shopId, capitalCash, capitalAirtelMoney, capitalMPesa, capitalOrangeMoney, designation);
      
      // ✅ OPTIMISATION: Ajouter directement au cache au lieu de recharger tout
      _shops.add(newShop);
      notifyListeners();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      debugPrint('✅ Shop créé localement: $designation');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du shop: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Mettre à jour un shop
  Future<bool> updateShop(ShopModel shop) async {
    _setLoading(true);
    try {
      // Marquer comme non synchronisé pour forcer l'upload
      final updatedShop = shop.copyWith(
        isSynced: false,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'local_user',
      );
      
      await LocalDB.instance.updateShop(updatedShop);
      
      // ✅ OPTIMISATION: Mettre à jour directement dans le cache
      final index = _shops.indexWhere((s) => s.id == updatedShop.id);
      if (index != -1) {
        _shops[index] = updatedShop;
        notifyListeners();
      }
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      debugPrint('✅ Shop mis à jour localement: ${updatedShop.designation}');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du shop: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Supprimer un shop
  Future<bool> deleteShop(int shopId) async {
    _setLoading(true);
    try {
      await LocalDB.instance.deleteShop(shopId);
      
      // ✅ OPTIMISATION: Supprimer directement du cache
      _shops.removeWhere((s) => s.id == shopId);
      notifyListeners();
      
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression du shop: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Obtenir un shop par ID
  ShopModel? getShopById(int id) {
    try {
      return _shops.firstWhere((shop) => shop.id == id);
    } catch (e) {
      return null;
    }
  }

  // Créer les caisses par défaut pour un nouveau shop
  Future<void> _createDefaultCaisses(int shopId, double capitalCash, double capitalAirtel, double capitalMPesa, double capitalOrange) async {
    final caisseData = {
      'CASH': capitalCash,
      'AIRTEL': capitalAirtel,
      'MPESA': capitalMPesa,
      'ORANGE': capitalOrange,
    };
    
    for (String type in caisseData.keys) {
      final caisse = CaisseModel(
        shopId: shopId,
        type: type,
        solde: caisseData[type]!,
      );
      await LocalDB.instance.saveCaisse(caisse);
    }
  }

  // Calculer le capital total de tous les shops
  double getTotalCapital() {
    return _shops.fold(0.0, (sum, shop) => sum + shop.capitalActuel);
  }

  // Obtenir les statistiques des shops
  Map<String, dynamic> getShopsStats() {
    return {
      'totalShops': _shops.length,
      'totalCapital': getTotalCapital(),
      'averageCapital': _shops.isEmpty ? 0.0 : getTotalCapital() / _shops.length,
      'activeShops': _shops.where((shop) => shop.capitalActuel > 0).length,
    };
  }

  // Créer une clôture de la veille comme solde antérieur
  Future<void> _createInitialClosureAsAnterieur(int shopId, double capitalCash, double capitalAirtel, double capitalMPesa, double capitalOrange, String shopName) async {
    try {
      final totalCapital = capitalCash + capitalAirtel + capitalMPesa + capitalOrange;
      
      // Date de la veille (hier)
      final dateVeille = DateTime.now().subtract(const Duration(days: 1));
      final dateVeilleNormalisee = DateTime(dateVeille.year, dateVeille.month, dateVeille.day);
      
      // Générer un ID unique pour la clôture (timestamp)
      final clotureId = DateTime.now().millisecondsSinceEpoch;
      
      // Créer une clôture de caisse pour la veille
      final cloture = ClotureCaisseModel(
        id: clotureId,  // Ajouter l'ID généré
        shopId: shopId,
        dateCloture: dateVeilleNormalisee,
        
        // Montants saisis (ce que l'agent a "compté")
        soldeSaisiCash: capitalCash,
        soldeSaisiAirtelMoney: capitalAirtel,
        soldeSaisiMPesa: capitalMPesa,
        soldeSaisiOrangeMoney: capitalOrange,
        soldeSaisiTotal: totalCapital,
        
        // Montants calculés (identiques car c'est le capital initial)
        soldeCalculeCash: capitalCash,
        soldeCalculeAirtelMoney: capitalAirtel,
        soldeCalculeMPesa: capitalMPesa,
        soldeCalculeOrangeMoney: capitalOrange,
        soldeCalculeTotal: totalCapital,
        
        // Écarts (zéro car saisi = calculé)
        ecartCash: 0.0,
        ecartAirtelMoney: 0.0,
        ecartMPesa: 0.0,
        ecartOrangeMoney: 0.0,
        ecartTotal: 0.0,
        
        cloturePar: 'SYSTEM',
        dateEnregistrement: DateTime.now(),
        notes: 'Clôture initiale automatique lors de la création du shop $shopName - Servira de solde antérieur pour aujourd\'hui',
      );
      
      await LocalDB.instance.saveClotureCaisse(cloture);
      
      debugPrint('✅ Clôture initiale créée pour $shopName - ${totalCapital.toStringAsFixed(2)} USD');
    } catch (e) {
      debugPrint('❌ Erreur création clôture initiale: $e');
      rethrow;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Méthode utilitaire pour créer les clôtures initiales pour les shops existants sans clôture
  Future<void> createMissingInitialClosures() async {
    for (final shop in _shops) {
      if (shop.id != null) {
        // Vérifier si une clôture existe déjà pour la veille
        final dateVeille = DateTime.now().subtract(const Duration(days: 1));
        final clotureExistante = await LocalDB.instance.getClotureCaisseByDate(shop.id!, dateVeille);
        
        if (clotureExistante == null) {
          await _createInitialClosureAsAnterieur(
            shop.id!, 
            shop.capitalCash, 
            shop.capitalAirtelMoney, 
            shop.capitalMPesa, 
            shop.capitalOrangeMoney, 
            shop.designation
          );
          debugPrint('Clôture initiale créée pour le shop ${shop.designation}');
        }
      }
    }
  }

  // Synchronisation en arrière-plan (non bloquante)
  void _syncInBackground() {
    Future.delayed(Duration.zero, () async {
      try {
        debugPrint('🔄 [ShopService] Synchronisation en arrière-plan...');
        final syncService = SyncService();
        await syncService.syncAll();
        debugPrint('✅ [ShopService] Synchronisation terminée');
      } catch (e) {
        debugPrint('⚠️ [ShopService] Erreur sync (non bloquante): $e');
      }
    });
  }
  
  /// Diagnostique et corrige les problèmes de synchronisation des opérations de capital initial
  Future<void> diagnoseAndFixInitialCapitalSync() async {
    await SyncDiagnostics.checkInitialCapitalOperations();
    await SyncDiagnostics.forceSyncInitialCapitalOperations();
    
    // Déclencher une synchronisation
    _syncInBackground();
  }
}
