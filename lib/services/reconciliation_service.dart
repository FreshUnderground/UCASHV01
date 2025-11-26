import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reconciliation_model.dart';
import 'agent_auth_service.dart';
import 'local_db.dart';

/// Service de réconciliation bancaire
/// Compare capital système vs capital réel (compté physiquement)
class ReconciliationService extends ChangeNotifier {
  static final ReconciliationService _instance = ReconciliationService._internal();
  static ReconciliationService get instance => _instance;
  ReconciliationService._internal();

  List<ReconciliationModel> _reconciliations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReconciliationModel> get reconciliations => _reconciliations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Crée une nouvelle réconciliation
  Future<ReconciliationModel?> createReconciliation({
    required int shopId,
    required DateTime date,
    required Map<String, double> capitalReel,
    String? notes,
    String? deviseSecondaire,
    double? capitalReelDevise2,
  }) async {
    _setLoading(true);
    try {
      // Récupérer le shop pour obtenir le capital système
      final shop = await LocalDB.instance.getShopById(shopId);
      if (shop == null) {
        throw Exception('Shop introuvable');
      }

      // Capital système (depuis la BD)
      final capitalSystemeCash = shop.capitalCash;
      final capitalSystemeAirtel = shop.capitalAirtelMoney;
      final capitalSystemeMpesa = shop.capitalMPesa;
      final capitalSystemeOrange = shop.capitalOrangeMoney;
      final capitalSystemeTotal = capitalSystemeCash + capitalSystemeAirtel + 
                                   capitalSystemeMpesa + capitalSystemeOrange;

      // Capital réel (compté)
      final capitalReelCash = capitalReel['cash'] ?? 0;
      final capitalReelAirtel = capitalReel['airtel'] ?? 0;
      final capitalReelMpesa = capitalReel['mpesa'] ?? 0;
      final capitalReelOrange = capitalReel['orange'] ?? 0;
      final capitalReelTotal = capitalReelCash + capitalReelAirtel + 
                               capitalReelMpesa + capitalReelOrange;

      // Calculer les écarts
      final ecartCash = capitalReelCash - capitalSystemeCash;
      final ecartAirtel = capitalReelAirtel - capitalSystemeAirtel;
      final ecartMpesa = capitalReelMpesa - capitalSystemeMpesa;
      final ecartOrange = capitalReelOrange - capitalSystemeOrange;
      final ecartTotal = capitalReelTotal - capitalSystemeTotal;
      final ecartPourcentage = capitalSystemeTotal > 0 
          ? (ecartTotal / capitalSystemeTotal * 100) 
          : 0.0;

      // Déterminer le statut
      ReconciliationStatut statut;
      final ecartPct = ecartPourcentage.abs();
      if (ecartPct == 0) {
        statut = ReconciliationStatut.VALIDE;
      } else if (ecartPct <= 1) {
        statut = ReconciliationStatut.ECART_ACCEPTABLE;
      } else if (ecartPct <= 5) {
        statut = ReconciliationStatut.ECART_ALERTE;
      } else {
        statut = ReconciliationStatut.INVESTIGATION;
      }

      final authService = AgentAuthService();
      final reconciliation = ReconciliationModel(
        shopId: shopId,
        dateReconciliation: date,
        capitalSystemeCash: capitalSystemeCash,
        capitalSystemeAirtel: capitalSystemeAirtel,
        capitalSystemeMpesa: capitalSystemeMpesa,
        capitalSystemeOrange: capitalSystemeOrange,
        capitalSystemeTotal: capitalSystemeTotal,
        capitalReelCash: capitalReelCash,
        capitalReelAirtel: capitalReelAirtel,
        capitalReelMpesa: capitalReelMpesa,
        capitalReelOrange: capitalReelOrange,
        capitalReelTotal: capitalReelTotal,
        ecartCash: ecartCash,
        ecartAirtel: ecartAirtel,
        ecartMpesa: ecartMpesa,
        ecartOrange: ecartOrange,
        ecartTotal: ecartTotal,
        ecartPourcentage: ecartPourcentage,
        statut: statut,
        notes: notes,
        deviseSecondaire: deviseSecondaire,
        capitalReelDevise2: capitalReelDevise2,
        capitalSystemeDevise2: shop.capitalActuelDevise2,
        ecartDevise2: capitalReelDevise2 != null && shop.capitalActuelDevise2 != null
            ? capitalReelDevise2 - (shop.capitalActuelDevise2 ?? 0)
            : null,
        actionCorrectiveRequise: ecartPct > 2,
        createdBy: authService.currentAgent?.id,
        createdAt: DateTime.now(),
      );

      // Sauvegarder localement
      await _saveReconciliationLocally(reconciliation);

      debugPrint('✅ Réconciliation créée pour shop $shopId');
      debugPrint('   Écart total: ${ecartTotal.toStringAsFixed(2)} USD (${ecartPourcentage.toStringAsFixed(2)}%)');
      debugPrint('   Statut: ${statut.name}');

      _errorMessage = null;
      _setLoading(false);
      return reconciliation;
    } catch (e) {
      _errorMessage = 'Erreur création réconciliation: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return null;
    }
  }

  /// Sauvegarde une réconciliation localement
  Future<void> _saveReconciliationLocally(ReconciliationModel reconciliation) async {
    final prefs = await SharedPreferences.getInstance();
    final reconciliationId = reconciliation.id ?? DateTime.now().millisecondsSinceEpoch;
    final key = 'reconciliation_$reconciliationId';
    await prefs.setString(key, jsonEncode(reconciliation.toJson()));
    _reconciliations.insert(0, reconciliation);
    notifyListeners();
  }

  /// Charge les réconciliations
  Future<void> loadReconciliations({
    int? shopId,
    DateTime? startDate,
    DateTime? endDate,
    ReconciliationStatut? statut,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('reconciliation_')).toList();

      _reconciliations.clear();
      for (final key in keys) {
        final reconciliationJson = prefs.getString(key);
        if (reconciliationJson != null) {
          try {
            final reconciliation = ReconciliationModel.fromJson(jsonDecode(reconciliationJson));

            // Appliquer les filtres
            bool matches = true;
            if (shopId != null && reconciliation.shopId != shopId) matches = false;
            if (startDate != null && reconciliation.dateReconciliation.isBefore(startDate)) matches = false;
            if (endDate != null && reconciliation.dateReconciliation.isAfter(endDate)) matches = false;
            if (statut != null && reconciliation.statut != statut) matches = false;

            if (matches) {
              _reconciliations.add(reconciliation);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur parsing reconciliation $key: $e');
          }
        }
      }

      // Trier par date décroissante
      _reconciliations.sort((a, b) => b.dateReconciliation.compareTo(a.dateReconciliation));

      debugPrint('📋 ${_reconciliations.length} réconciliations chargées');
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur chargement réconciliations: $e';
      debugPrint(_errorMessage);
    }
    _setLoading(false);
  }

  /// Récupère les réconciliations avec écarts
  Future<List<ReconciliationModel>> getReconciliationsWithGaps() async {
    await loadReconciliations();
    return _reconciliations.where((r) => (r.ecartPourcentage?.abs() ?? 0) > 0).toList();
  }

  /// Récupère les réconciliations nécessitant une action corrective
  Future<List<ReconciliationModel>> getReconciliationsNeedingAction() async {
    await loadReconciliations();
    return _reconciliations.where((r) => r.actionCorrectiveRequise).toList();
  }

  /// Valide une réconciliation (admin uniquement)
  Future<bool> validateReconciliation(int reconciliationId, String? justification) async {
    try {
      final reconciliation = _reconciliations.firstWhere((r) => r.id == reconciliationId);
      final authService = AgentAuthService();

      final updated = reconciliation.copyWith(
        statut: ReconciliationStatut.VALIDE,
        justification: justification,
        verifiedBy: authService.currentAgent?.id,
        verifiedAt: DateTime.now(),
      );

      // Mettre à jour localement
      await _updateReconciliationLocally(updated);

      debugPrint('✅ Réconciliation validée par ${authService.currentAgent?.username}');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur validation: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// Met à jour une réconciliation localement
  Future<void> _updateReconciliationLocally(ReconciliationModel reconciliation) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'reconciliation_${reconciliation.id}';
    await prefs.setString(key, jsonEncode(reconciliation.toJson()));

    final index = _reconciliations.indexWhere((r) => r.id == reconciliation.id);
    if (index != -1) {
      _reconciliations[index] = reconciliation;
      notifyListeners();
    }
  }

  /// Obtient la dernière réconciliation d'un shop
  Future<ReconciliationModel?> getLastReconciliation(int shopId) async {
    await loadReconciliations(shopId: shopId);
    if (_reconciliations.isEmpty) return null;
    return _reconciliations.first; // Déjà trié par date décroissante
  }

  /// Statistiques des réconciliations
  Map<String, dynamic> getReconciliationStats() {
    final statusCounts = <ReconciliationStatut, int>{};
    final shopCounts = <int, int>{};
    double totalEcartPourcentage = 0;
    int reconciliationsWithGaps = 0;

    for (final reconciliation in _reconciliations) {
      statusCounts[reconciliation.statut] = (statusCounts[reconciliation.statut] ?? 0) + 1;
      shopCounts[reconciliation.shopId] = (shopCounts[reconciliation.shopId] ?? 0) + 1;

      final ecartPct = reconciliation.ecartPourcentage?.abs() ?? 0;
      if (ecartPct > 0) {
        totalEcartPourcentage += ecartPct;
        reconciliationsWithGaps++;
      }
    }

    final avgEcartPourcentage = reconciliationsWithGaps > 0 
        ? totalEcartPourcentage / reconciliationsWithGaps 
        : 0.0;

    return {
      'totalReconciliations': _reconciliations.length,
      'statusCounts': statusCounts,
      'shopCounts': shopCounts,
      'reconciliationsWithGaps': reconciliationsWithGaps,
      'avgEcartPourcentage': avgEcartPourcentage,
      'actionCorrectiveRequired': _reconciliations.where((r) => r.actionCorrectiveRequise).length,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
