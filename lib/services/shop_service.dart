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
  Future<void> loadShops({bool forceRefresh = false}) async {
    _setLoading(true);
    try {
      // Si forceRefresh, vider d'abord le cache
      if (forceRefresh) {
        _shops.clear();
        debugPrint('🗑️ [ShopService] Cache vidé - Rechargement forcé');
      }
      
      _shops = await LocalDB.instance.getAllShops();
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
      
      // Recharger la liste
      await loadShops();
      
      // Attendre un peu pour s'assurer que l'opération est bien enregistrée
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
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
      await loadShops(forceRefresh: true);
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
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
      await loadShops();
      _errorMessage = null;
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
      
      debugPrint('✅ Clôture initiale créée pour la veille (${dateVeilleNormalisee.toIso8601String().split('T')[0]})');
      debugPrint('   Solde Total: ${totalCapital.toStringAsFixed(2)} USD');
      debugPrint('   - Cash: ${capitalCash.toStringAsFixed(2)} USD');
      debugPrint('   - Airtel Money: ${capitalAirtel.toStringAsFixed(2)} USD');
      debugPrint('   - M-Pesa: ${capitalMPesa.toStringAsFixed(2)} USD');
      debugPrint('   - Orange Money: ${capitalOrange.toStringAsFixed(2)} USD');
      debugPrint("   Cette clôture servira de solde antérieur pour commencer les transactions aujourd'hui");
      
      // Synchronisation de la clôture vers le serveur
      try {
        final syncService = SyncService();
        if (syncService.isOnline) {
          debugPrint('📤 Synchronisation clôture initiale vers le serveur...');
          await syncService.syncAll(userId: 'system');
          debugPrint('✅ Clôture initiale synchronisée');
        } else {
          debugPrint('📋 Clôture initiale sera synchronisée plus tard (offline)');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur sync clôture initiale: $e (sera retentée plus tard)');
      }
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
