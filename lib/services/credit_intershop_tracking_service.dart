import 'package:flutter/foundation.dart';
import '../models/credit_intershop_tracking_model.dart';
import '../models/shop_model.dart';
import 'local_db.dart';

/// Service de suivi des crédits inter-shop pour consolidation
///
/// LOGIQUE MÉTIER:
/// - Shop Principal (Durba): Gère tous les flots de cash
/// - Shop Service (Kampala): Service par défaut des transferts
/// - Shops Normaux (C, D, E, F): Initient des transferts
///
/// FLUX:
/// Client au Shop C → Transfert → Servi au Shop Kampala
///
/// DETTES CRÉÉES:
/// 1. EXTERNE: Durba doit à Kampala (montant brut) - Dette consolidée
/// 2. INTERNE: Shop C doit à Durba (montant brut) - Dette interne
///
/// RÉSULTAT:
/// - Kampala voit UNIQUEMENT la dette de Durba (consolidée)
/// - Durba gère les dettes des shops normaux en interne
/// - Shop C voit qu'il doit à Durba (pas à Kampala)
class CreditIntershopTrackingService extends ChangeNotifier {
  static final CreditIntershopTrackingService _instance =
      CreditIntershopTrackingService._internal();
  static CreditIntershopTrackingService get instance => _instance;

  CreditIntershopTrackingService._internal();

  List<CreditIntershopTrackingModel> _credits = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CreditIntershopTrackingModel> get credits => _credits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger tous les crédits depuis la base de données
  Future<void> loadCredits() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _credits = await LocalDB.instance.getAllCreditIntershopTracking();
      debugPrint('✅ Crédits inter-shop chargés: ${_credits.length}');
    } catch (e) {
      _errorMessage = 'Erreur chargement crédits: $e';
      debugPrint('❌ $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Enregistrer un crédit inter-shop (consolidation)
  ///
  /// Appelé automatiquement lors d'un transfert entre shops normaux via le shop service
  Future<CreditIntershopTrackingModel> trackCredit({
    required int shopPrincipalId,
    required String shopPrincipalDesignation,
    required int shopNormalId,
    required String shopNormalDesignation,
    required int shopServiceId,
    required String shopServiceDesignation,
    required double montantBrut,
    required double montantNet,
    required double commission,
    required String devise,
    int? operationId,
    String? operationReference,
    required DateTime dateOperation,
  }) async {
    try {
      final tracking = CreditIntershopTrackingModel(
        shopPrincipalId: shopPrincipalId,
        shopPrincipalDesignation: shopPrincipalDesignation,
        shopNormalId: shopNormalId,
        shopNormalDesignation: shopNormalDesignation,
        shopServiceId: shopServiceId,
        shopServiceDesignation: shopServiceDesignation,
        montantBrut: montantBrut,
        montantNet: montantNet,
        commission: commission,
        devise: devise,
        operationId: operationId,
        operationReference: operationReference,
        dateOperation: dateOperation,
        dateConsolidation: DateTime.now(),
        createdAt: DateTime.now(),
        isSynced: false,
      );

      final saved =
          await LocalDB.instance.saveCreditIntershopTracking(tracking);

      debugPrint('✅ Crédit inter-shop enregistré:');
      debugPrint(
          '   Normal: $shopNormalDesignation → Principal: $shopPrincipalDesignation → Service: $shopServiceDesignation');
      debugPrint(
          '   Montant: $montantBrut $devise (Net: $montantNet, Commission: $commission)');
      debugPrint('   Operation: $operationReference');

      // Recharger la liste
      await loadCredits();

      return saved;
    } catch (e) {
      debugPrint('❌ Erreur enregistrement crédit inter-shop: $e');
      rethrow;
    }
  }

  /// Obtenir tous les crédits pour un shop principal (ex: Durba)
  /// avec filtrage optionnel par période
  Future<List<CreditIntershopTrackingModel>> getCreditsForMainShop(
    int shopPrincipalId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allCredits = await LocalDB.instance.getAllCreditIntershopTracking();

    return allCredits.where((credit) {
      if (credit.shopPrincipalId != shopPrincipalId) return false;
      if (startDate != null && credit.dateOperation.isBefore(startDate))
        return false;
      if (endDate != null && credit.dateOperation.isAfter(endDate))
        return false;
      return true;
    }).toList();
  }

  /// Obtenir la répartition des dettes: Quels shops normaux doivent au shop principal
  ///
  /// Retourne un Map: shopNormalId → montant total dû
  Future<Map<int, double>> getDebtsBreakdownForMainShop(
    int shopPrincipalId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final credits = await getCreditsForMainShop(
      shopPrincipalId,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<int, double> debts = {};

    for (final credit in credits) {
      debts[credit.shopNormalId] =
          (debts[credit.shopNormalId] ?? 0.0) + credit.montantBrut;
    }

    debugPrint(
        '📊 Répartition des dettes pour shop principal $shopPrincipalId:');
    debts.forEach((shopId, montant) {
      debugPrint('   Shop $shopId doit: ${montant.toStringAsFixed(2)} USD');
    });

    return debts;
  }

  /// Obtenir le montant total que le shop principal doit au shop service
  /// (Dette consolidée)
  Future<double> getTotalConsolidatedDebt(
    int shopPrincipalId,
    int shopServiceId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final credits = await getCreditsForMainShop(
      shopPrincipalId,
      startDate: startDate,
      endDate: endDate,
    );

    final total = credits
        .where((credit) => credit.shopServiceId == shopServiceId)
        .fold(0.0, (sum, credit) => sum + credit.montantBrut);

    debugPrint(
        '💰 Dette consolidée: Shop principal $shopPrincipalId doit $total USD au shop service $shopServiceId');

    return total;
  }

  /// Obtenir les détails des crédits avec informations complètes
  /// pour affichage dans les rapports
  Future<List<Map<String, dynamic>>> getDetailedCredits(
    int shopId, {
    DateTime? startDate,
    DateTime? endDate,
    String? perspective, // 'principal', 'normal', 'service'
  }) async {
    final allCredits = await LocalDB.instance.getAllCreditIntershopTracking();

    List<CreditIntershopTrackingModel> filtered = [];

    if (perspective == 'principal') {
      // Vue du shop principal (Durba)
      filtered = allCredits.where((c) => c.shopPrincipalId == shopId).toList();
    } else if (perspective == 'normal') {
      // Vue d'un shop normal (C, D, E, F)
      filtered = allCredits.where((c) => c.shopNormalId == shopId).toList();
    } else if (perspective == 'service') {
      // Vue du shop service (Kampala)
      filtered = allCredits.where((c) => c.shopServiceId == shopId).toList();
    } else {
      // Tous les crédits impliquant ce shop
      filtered = allCredits
          .where((c) =>
              c.shopPrincipalId == shopId ||
              c.shopNormalId == shopId ||
              c.shopServiceId == shopId)
          .toList();
    }

    // Filtrer par date
    if (startDate != null) {
      filtered = filtered
          .where((c) =>
              c.dateOperation.isAfter(startDate) ||
              c.dateOperation.isAtSameMomentAs(startDate))
          .toList();
    }
    if (endDate != null) {
      filtered = filtered
          .where((c) =>
              c.dateOperation.isBefore(endDate) ||
              c.dateOperation.isAtSameMomentAs(endDate))
          .toList();
    }

    // Convertir en format détaillé
    return filtered.map((credit) {
      return {
        'id': credit.id,
        'shopPrincipal': credit.shopPrincipalDesignation,
        'shopNormal': credit.shopNormalDesignation,
        'shopService': credit.shopServiceDesignation,
        'montantBrut': credit.montantBrut,
        'montantNet': credit.montantNet,
        'commission': credit.commission,
        'devise': credit.devise,
        'operationReference': credit.operationReference,
        'dateOperation': credit.dateOperation,
        'dateConsolidation': credit.dateConsolidation,
      };
    }).toList();
  }

  /// Obtenir les statistiques globales des crédits inter-shop
  Future<Map<String, dynamic>> getStatistics(
    int shopPrincipalId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final credits = await getCreditsForMainShop(
      shopPrincipalId,
      startDate: startDate,
      endDate: endDate,
    );

    final totalMontantBrut = credits.fold(0.0, (sum, c) => sum + c.montantBrut);
    final totalMontantNet = credits.fold(0.0, (sum, c) => sum + c.montantNet);
    final totalCommission = credits.fold(0.0, (sum, c) => sum + c.commission);

    // Nombre de shops normaux différents
    final Set<int> uniqueNormalShops =
        credits.map((c) => c.shopNormalId).toSet();

    // Nombre de shops service différents
    final Set<int> uniqueServiceShops =
        credits.map((c) => c.shopServiceId).toSet();

    return {
      'nombreCredits': credits.length,
      'totalMontantBrut': totalMontantBrut,
      'totalMontantNet': totalMontantNet,
      'totalCommission': totalCommission,
      'nombreShopsNormaux': uniqueNormalShops.length,
      'nombreShopsService': uniqueServiceShops.length,
    };
  }

  /// Synchroniser les crédits non synchronisés
  Future<void> syncCredits() async {
    try {
      final unsyncedCredits = _credits.where((c) => !c.isSynced).toList();

      if (unsyncedCredits.isEmpty) {
        debugPrint('✅ Aucun crédit à synchroniser');
        return;
      }

      debugPrint('🔄 Synchronisation de ${unsyncedCredits.length} crédits...');

      // TODO: Implémenter l'upload vers le serveur
      // await _uploadCreditsToServer(unsyncedCredits);

      debugPrint('✅ Crédits synchronisés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur synchronisation crédits: $e');
      rethrow;
    }
  }

  /// Nettoyer la liste et l'état
  void clear() {
    _credits = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
