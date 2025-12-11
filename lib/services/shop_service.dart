import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/shop_model.dart';
import '../models/caisse_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/cloture_caisse_model.dart';
import '../config/app_config.dart';
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
      
      // Vérifier les shops supprimés sur le serveur
      await _checkForDeletedShops();
      
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
  
  /// Met à jour un shop directement via l'API serveur (nouveau endpoint dédié)
  /// Utilisé par les admins pour modifier un shop et notifier tous les agents
  Future<Map<String, dynamic>?> updateShopViaAPI(ShopModel shop, {String userId = 'admin'}) async {
    try {
      debugPrint('📤 [ShopService] Mise à jour du shop via API: ${shop.designation}');
      
      final baseUrl = await AppConfig.getSyncBaseUrl();
      final url = Uri.parse('$baseUrl/shops/update.php');
      
      final payload = {
        'shop_id': shop.id,
        'designation': shop.designation,
        'localisation': shop.localisation,
        'capital_initial': shop.capitalInitial,
        'devise_principale': shop.devisePrincipale,
        'devise_secondaire': shop.deviseSecondaire,
        'capital_actuel': shop.capitalActuel,
        'capital_cash': shop.capitalCash,
        'capital_airtel_money': shop.capitalAirtelMoney,
        'capital_mpesa': shop.capitalMPesa,
        'capital_orange_money': shop.capitalOrangeMoney,
        'capital_actuel_devise2': shop.capitalActuelDevise2,
        'capital_cash_devise2': shop.capitalCashDevise2,
        'capital_airtel_money_devise2': shop.capitalAirtelMoneyDevise2,
        'capital_mpesa_devise2': shop.capitalMPesaDevise2,
        'capital_orange_money_devise2': shop.capitalOrangeMoneyDevise2,
        'creances': shop.creances,
        'dettes': shop.dettes,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📤 Envoi vers: $url');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('📊 Réponse HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          debugPrint('✅ Shop mis à jour sur le serveur');
          debugPrint('👥 Agents affectés: ${result['affected_agents']['count']}');
          
          // Mettre à jour localement avec le flag is_synced: true
          final syncedShop = shop.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: userId,
          );
          
          await LocalDB.instance.updateShop(syncedShop);
          
          // Mettre à jour le cache
          final index = _shops.indexWhere((s) => s.id == shop.id);
          if (index != -1) {
            _shops[index] = syncedShop;
            notifyListeners();
          }
          
          return result;
        } else {
          debugPrint('❌ Erreur serveur: ${result['message']}');
          return null;
        }
      } else {
        debugPrint('❌ Erreur HTTP: ${response.statusCode}');
        debugPrint('📄 Réponse: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Erreur updateShopViaAPI: $e');
      return null;
    }
  }

  /// Supprime un shop via l'API serveur avec audit trail
  /// Utilise soft delete par défaut (is_active = 0)
  Future<Map<String, dynamic>?> deleteShopViaAPI(
    int shopId, {
    required String adminId,
    required String adminUsername,
    required String reason,
    String deleteType = 'soft', // 'soft' ou 'hard'
    bool forceDelete = false,
  }) async {
    try {
      debugPrint('📤 [ShopService] Suppression du shop via API: ID $shopId');
      
      final baseUrl = await AppConfig.getSyncBaseUrl();
      final url = Uri.parse('$baseUrl/shops/delete.php');
      
      final payload = {
        'shop_id': shopId,
        'admin_id': adminId,
        'admin_username': adminUsername,
        'reason': reason,
        'delete_type': deleteType,
        'force_delete': forceDelete,
      };
      
      debugPrint('📤 Envoi vers: $url');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('📊 Réponse HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          debugPrint('✅ Shop supprimé sur le serveur');
          debugPrint('👥 Agents affectés: ${result['affected_agents']['count']}');
          
          // Supprimer localement
          await LocalDB.instance.deleteShop(shopId);
          _shops.removeWhere((s) => s.id == shopId);
          notifyListeners();
          
          return result;
        } else {
          debugPrint('❌ Erreur serveur: ${result['message']}');
          return null;
        }
      } else {
        debugPrint('❌ Erreur HTTP: ${response.statusCode}');
        debugPrint('📄 Réponse: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Erreur deleteShopViaAPI: $e');
      return null;
    }
  }

  // Supprimer un shop (ancien code - utilise deleteShopViaAPI pour une suppression complète)
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

  /// Obtenir la désignation d'un shop par son ID
  /// Retourne la désignation du shop, ou un fallback "Shop #ID" si non trouvé
  /// Utiliser cette méthode partout dans l'UI pour afficher le nom d'un shop
  /// 
  /// Exemple d'utilisation:
  /// ```dart
  /// Text(ShopService.instance.getShopDesignation(shopId))
  /// // ou avec Provider:
  /// Text(context.read<ShopService>().getShopDesignation(shopId))
  /// ```
  String getShopDesignation(int? shopId, {String? existingDesignation}) {
    // Si une désignation valide est déjà fournie, l'utiliser
    if (existingDesignation != null && existingDesignation.isNotEmpty) {
      return existingDesignation;
    }
    
    // Si pas d'ID, retourner un placeholder
    if (shopId == null) {
      return 'Shop inconnu';
    }
    
    // Chercher dans la liste des shops
    try {
      final shop = _shops.firstWhere((s) => s.id == shopId);
      if (shop.designation.isNotEmpty) {
        return shop.designation;
      }
    } catch (e) {
      // Shop non trouvé dans le cache
    }
    
    // Fallback: afficher l'ID du shop
    return 'Shop #$shopId';
  }

  /// Obtenir la désignation du shop source d'une opération ou d'un flot
  String getShopSourceDesignation(int? shopSourceId, {String? existingDesignation}) {
    return getShopDesignation(shopSourceId, existingDesignation: existingDesignation);
  }

  /// Obtenir la désignation du shop destination d'une opération ou d'un flot
  String getShopDestinationDesignation(int? shopDestinationId, {String? existingDesignation}) {
    return getShopDesignation(shopDestinationId, existingDesignation: existingDesignation);
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
        debugPrint('🔄 [ShopService] Synchronisation des shops en arrière-plan...');
        final syncService = SyncService();
        // Uploader les shops non synchronisés vers le serveur
        await syncService.uploadTableData('shops', 'admin', 'admin');
        debugPrint('✅ [ShopService] Shops synchronisés avec succès');
      } catch (e) {
        debugPrint('⚠️ [ShopService] Erreur sync shops (non bloquante): $e');
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
  
  /// Met à jour un shop directement dans LocalDB et le cache sans déclencher la synchronisation
  /// Utilisé par SyncService pour marquer les shops comme synchronisés après upload réussi
  Future<void> updateShopDirectly(ShopModel shop) async {
    try {
      // Sauvegarder directement dans LocalDB
      await LocalDB.instance.updateShop(shop);
      
      // Mettre à jour le cache en mémoire
      final index = _shops.indexWhere((s) => s.id == shop.id);
      if (index != -1) {
        _shops[index] = shop;
        debugPrint('✅ [ShopService] Shop ${shop.designation} mis à jour directement (is_synced: ${shop.isSynced})');
      }
    } catch (e) {
      debugPrint('❌ [ShopService] Erreur updateShopDirectly: $e');
      rethrow;
    }
  }
  
  /// Recharge tous les shops depuis LocalDB (utile après une synchronisation)
  Future<void> reloadShopsFromLocalDB() async {
    try {
      debugPrint('🔄 [ShopService] Rechargement des shops depuis LocalDB...');
      final allShops = await LocalDB.instance.getAllShops();
      _shops = allShops;
      notifyListeners();
      debugPrint('✅ [ShopService] ${_shops.length} shops rechargés');
    } catch (e) {
      debugPrint('❌ [ShopService] Erreur reloadShopsFromLocalDB: $e');
    }
  }
  
  // Vérifier les shops supprimés sur le serveur
  Future<void> _checkForDeletedShops() async {
    try {
      if (_shops.isEmpty) {
        return;
      }
      
      debugPrint('🔍 Vérification des shops supprimés sur le serveur...');
      
      // Extraire les IDs des shops locaux
      final shopIds = _shops
          .where((shop) => shop.id != null && shop.id! > 0)
          .map((shop) => shop.id!)
          .toList();
      
      if (shopIds.isEmpty) {
        return;
      }
      
      // Appeler l'API pour vérifier les shops supprimés
      final baseUrl = await AppConfig.getApiBaseUrl();
      final cleanUrl = baseUrl.trim();
      final url = Uri.parse('$cleanUrl/sync/shops/check_deleted.php');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'shop_ids': shopIds,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout lors de la vérification des shops supprimés');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final deletedShops = List<int>.from(data['deleted_shops'] ?? []);
          
          if (deletedShops.isNotEmpty) {
            debugPrint('🗑️ ${deletedShops.length} shop(s) supprimé(s) détecté(s) sur le serveur');
            
            // Supprimer les shops de toutes les sources locales
            await _removeDeletedShopsLocally(deletedShops);
          } else {
            debugPrint('✅ Aucun shop supprimé trouvé sur le serveur');
          }
        } else {
          debugPrint('⚠️ Erreur lors de la vérification des shops supprimés: ${data['error']}');
        }
      } else {
        debugPrint('⚠️ HTTP Error ${response.statusCode} lors de la vérification des shops supprimés');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la vérification des shops supprimés: $e');
      // Ne pas propager l'erreur pour ne pas bloquer le chargement
    }
  }
  
  // Supprimer localement les shops qui ont été supprimés sur le serveur
  Future<void> _removeDeletedShopsLocally(List<int> deletedShopIds) async {
    try {
      debugPrint('🗑️ Suppression locale de ${deletedShopIds.length} shop(s)...');
      
      int removedCount = 0;
      
      for (final shopId in deletedShopIds) {
        // Supprimer de LocalDB
        await LocalDB.instance.deleteShop(shopId);
        
        // Supprimer du cache en mémoire
        _shops.removeWhere((shop) => shop.id == shopId);
        
        removedCount++;
        debugPrint('   ✅ Shop ID $shopId supprimé localement');
      }
      
      if (removedCount > 0) {
        notifyListeners();
      }
      
      debugPrint('✅ Nettoyage local terminé: $removedCount shop(s) supprimé(s)');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage local des shops: $e');
    }
  }
}
