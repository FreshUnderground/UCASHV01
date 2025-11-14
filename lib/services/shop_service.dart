import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/shop_model.dart';
import '../models/caisse_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import 'local_db.dart';

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
  Future<void> loadShops() async {
    _setLoading(true);
    try {
      _shops = await LocalDB.instance.getAllShops();
      _errorMessage = null;
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
      );

      // Sauvegarder localement
      await LocalDB.instance.saveShop(newShop);
      
      // Créer les caisses par défaut pour ce shop avec les capitaux spécifiés
      await _createDefaultCaisses(shopId, capitalCash, capitalAirtelMoney, capitalMPesa, capitalOrangeMoney);
      
      // Créer une opération de dépôt pour le cash initial (entrée en caisse)
      if (capitalCash > 0) {
        await _createInitialCashDeposit(shopId, capitalCash, designation);
      }
      
      // Recharger la liste
      await loadShops();     
      _errorMessage = null;
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
      await LocalDB.instance.updateShop(shop);
      await loadShops();
      _errorMessage = null;
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

  // Créer une opération de dépôt pour le cash initial
  Future<void> _createInitialCashDeposit(int shopId, double montant, String shopName) async {
    final operation = OperationModel(
      id: DateTime.now().millisecondsSinceEpoch,
      type: OperationType.depot,
      montantBrut: montant,
      montantNet: montant,
      commission: 0.0, // Pas de commission pour le dépôt initial
      shopSourceId: shopId,
      shopSourceDesignation: shopName,
      clientId: null, // Pas de client pour le dépôt initial
      agentId: 1, // Agent système pour le dépôt initial
      agentUsername: 'system',
      modePaiement: ModePaiement.cash,
      statut: OperationStatus.terminee, // Directement terminé
      dateOp: DateTime.now(),
      destinataire: 'CAPITAL INITIAL',
      notes: 'Dépôt initial du capital cash lors de la création du shop $shopName',
      lastModifiedBy: 'SYSTEM',
    );

    await LocalDB.instance.saveOperation(operation);
    
    // Créer également une entrée dans le journal de caisse
    final journalEntry = JournalCaisseModel(
      shopId: shopId,
      agentId: 1, // Agent système
      libelle: 'Dépôt initial - Capital Cash',
      montant: montant,
      type: TypeMouvement.entree,
      mode: ModePaiement.cash,
      dateAction: DateTime.now(),
      operationId: operation.id,
      notes: 'Capital initial lors de la création du shop $shopName',
      lastModifiedBy: 'SYSTEM',
    );
    
    await LocalDB.instance.saveJournalEntry(journalEntry);
    debugPrint('✅ Dépôt initial créé: opération + journal de caisse');
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

  // Méthode utilitaire pour créer les opérations de dépôt initial pour les shops existants
  Future<void> createMissingInitialDeposits() async {
    for (final shop in _shops) {
      if (shop.capitalCash > 0) {
        // Vérifier si une opération de dépôt initial existe déjà
        final existingOperations = await LocalDB.instance.getOperationsByShop(shop.id!);
        final hasInitialDeposit = existingOperations.any((op) => 
          op.type == OperationType.depot && 
          op.destinataire == 'CAPITAL INITIAL'
        );
        
        if (!hasInitialDeposit) {
          await _createInitialCashDeposit(shop.id!, shop.capitalCash, shop.designation);
          debugPrint('Dépôt initial créé pour le shop ${shop.designation}: ${shop.capitalCash} USD');
        }
      }
    }
  }
}
