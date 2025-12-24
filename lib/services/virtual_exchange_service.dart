import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sim_model.dart';
import '../models/virtual_exchange_model.dart';
import 'local_db.dart';
import 'sim_service.dart';
import 'shop_service.dart';

/// Service de gestion des échanges de crédit virtuel entre SIMs
class VirtualExchangeService extends ChangeNotifier {
  static final VirtualExchangeService _instance = VirtualExchangeService._internal();
  static VirtualExchangeService get instance => _instance;
  
  VirtualExchangeService._internal();

  List<VirtualExchangeModel> _exchanges = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<VirtualExchangeModel> get exchanges => _exchanges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger tous les échanges virtuels
  Future<void> loadExchanges({
    int? shopId,
    String? simSource,
    String? simDestination,
    DateTime? dateDebut,
    DateTime? dateFin,
    VirtualExchangeStatus? statut,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [VirtualExchangeService] Chargement des échanges...');
      
      _exchanges = await LocalDB.instance.getAllVirtualExchanges(
        shopId: shopId,
        simSource: simSource,
        simDestination: simDestination,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
      );
      
      debugPrint('✅ [VirtualExchangeService] ${_exchanges.length} échanges chargés');
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur chargement échanges: $e';
      debugPrint('❌ [VirtualExchangeService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Créer un nouvel échange virtuel entre deux SIMs
  Future<VirtualExchangeModel?> createExchange({
    required String simSource,
    required String simDestination,
    required double montant,
    required String devise,
    String? notes,
    int? agentId,
    String? agentUsername,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [VirtualExchangeService] Création échange...');
      debugPrint('   SIM Source: $simSource');
      debugPrint('   SIM Destination: $simDestination');
      debugPrint('   Montant: $montant $devise');

      // Vérifications préliminaires
      if (simSource == simDestination) {
        _errorMessage = 'Impossible d\'échanger avec la même SIM';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      if (montant <= 0) {
        _errorMessage = 'Le montant doit être supérieur à zéro';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Récupérer les informations des SIMs
      final simSourceModel = await LocalDB.instance.getSimByNumero(simSource);
      final simDestinationModel = await LocalDB.instance.getSimByNumero(simDestination);

      if (simSourceModel == null) {
        _errorMessage = 'SIM source $simSource introuvable';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      if (simDestinationModel == null) {
        _errorMessage = 'SIM destination $simDestination introuvable';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Vérifier que les SIMs appartiennent au même shop
      if (simSourceModel.shopId != simDestinationModel.shopId) {
        _errorMessage = 'Les SIMs doivent appartenir au même shop';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Calculer les soldes actuels par devise
      final soldesSource = await SimService.instance.calculateAutomaticSoldesByDevise(simSourceModel);
      final soldesDestination = await SimService.instance.calculateAutomaticSoldesByDevise(simDestinationModel);

      final soldeSourceActuel = soldesSource[devise] ?? 0.0;
      final soldeDestinationActuel = soldesDestination[devise] ?? 0.0;

      // Vérifier que la SIM source a suffisamment de crédit
      if (soldeSourceActuel < montant) {
        _errorMessage = 'Solde insuffisant sur SIM $simSource (${soldeSourceActuel.toStringAsFixed(2)} $devise disponible)';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Récupérer les informations du shop
      final shopService = ShopService.instance;
      final shop = shopService.getShopById(simSourceModel.shopId);

      if (agentId == null) {
        _errorMessage = 'Informations agent requises';
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Créer l'échange
      final newExchange = VirtualExchangeModel(
        simSource: simSource,
        simDestination: simDestination,
        simSourceOperateur: simSourceModel.operateur,
        simDestinationOperateur: simDestinationModel.operateur,
        montant: montant,
        devise: devise,
        soldeSourceAvant: soldeSourceActuel,
        soldeSourceApres: soldeSourceActuel - montant,
        soldeDestinationAvant: soldeDestinationActuel,
        soldeDestinationApres: soldeDestinationActuel + montant,
        shopId: simSourceModel.shopId,
        shopDesignation: shop?.designation,
        agentId: agentId,
        agentUsername: agentUsername,
        notes: notes,
        statut: VirtualExchangeStatus.enAttente,
        dateEchange: DateTime.now(),
        reference: VirtualExchangeModel.generateReference(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername,
      );

      debugPrint('💾 [VirtualExchangeService] Sauvegarde échange...');
      final savedExchange = await LocalDB.instance.saveVirtualExchange(newExchange);
      debugPrint('✅ [VirtualExchangeService] Échange sauvegardé avec ID #${savedExchange.id}');

      // Recharger les échanges
      await loadExchanges(shopId: simSourceModel.shopId);

      _errorMessage = null;
      _setLoading(false);
      notifyListeners();

      return savedExchange;
    } catch (e) {
      _errorMessage = 'Erreur création échange: $e';
      debugPrint('❌ [VirtualExchangeService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Valider un échange virtuel (effectuer le transfert)
  Future<bool> validateExchange(VirtualExchangeModel exchange, {String? agentUsername}) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [VirtualExchangeService] Validation échange ${exchange.reference}...');

      if (exchange.statut != VirtualExchangeStatus.enAttente) {
        _errorMessage = 'Seuls les échanges en attente peuvent être validés';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Récupérer les SIMs actuelles
      final simSourceModel = await LocalDB.instance.getSimByNumero(exchange.simSource);
      final simDestinationModel = await LocalDB.instance.getSimByNumero(exchange.simDestination);

      if (simSourceModel == null || simDestinationModel == null) {
        _errorMessage = 'Une des SIMs est introuvable';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Vérifier à nouveau le solde de la SIM source
      final soldesSource = await SimService.instance.calculateAutomaticSoldesByDevise(simSourceModel);
      final soldeSourceActuel = soldesSource[exchange.devise] ?? 0.0;

      if (soldeSourceActuel < exchange.montant) {
        _errorMessage = 'Solde insuffisant sur SIM ${exchange.simSource}';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Mettre à jour l'échange
      final updatedExchange = exchange.copyWith(
        statut: VirtualExchangeStatus.valide,
        dateValidation: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername,
      );

      await LocalDB.instance.updateVirtualExchange(updatedExchange);

      // Recalculer les soldes des SIMs
      await SimService.instance.updateSoldeAutomatiquement(simSourceModel);
      await SimService.instance.updateSoldeAutomatiquement(simDestinationModel);

      debugPrint('✅ [VirtualExchangeService] Échange ${exchange.reference} validé');
      debugPrint('   ${exchange.simSource}: -${exchange.montant} ${exchange.devise}');
      debugPrint('   ${exchange.simDestination}: +${exchange.montant} ${exchange.devise}');

      // Recharger les échanges
      await loadExchanges(shopId: exchange.shopId);

      _errorMessage = null;
      _setLoading(false);
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Erreur validation échange: $e';
      debugPrint('❌ [VirtualExchangeService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Annuler un échange virtuel
  Future<bool> cancelExchange(VirtualExchangeModel exchange, {String? agentUsername}) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [VirtualExchangeService] Annulation échange ${exchange.reference}...');

      if (exchange.statut != VirtualExchangeStatus.enAttente) {
        _errorMessage = 'Seuls les échanges en attente peuvent être annulés';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Mettre à jour l'échange
      final updatedExchange = exchange.copyWith(
        statut: VirtualExchangeStatus.annule,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername,
      );

      await LocalDB.instance.updateVirtualExchange(updatedExchange);

      debugPrint('✅ [VirtualExchangeService] Échange ${exchange.reference} annulé');

      // Recharger les échanges
      await loadExchanges(shopId: exchange.shopId);

      _errorMessage = null;
      _setLoading(false);
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Erreur annulation échange: $e';
      debugPrint('❌ [VirtualExchangeService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Obtenir les statistiques des échanges pour un shop
  Future<Map<String, dynamic>> getExchangeStats(int shopId, {DateTime? date}) async {
    try {
      final dateDebut = date != null 
          ? DateTime(date.year, date.month, date.day, 0, 0, 0)
          : DateTime.now().subtract(const Duration(days: 30));
      final dateFin = date != null 
          ? DateTime(date.year, date.month, date.day, 23, 59, 59)
          : DateTime.now();

      final exchanges = await LocalDB.instance.getAllVirtualExchanges(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );

      final stats = {
        'total_exchanges': exchanges.length,
        'exchanges_en_attente': exchanges.where((e) => e.statut == VirtualExchangeStatus.enAttente).length,
        'exchanges_valides': exchanges.where((e) => e.statut == VirtualExchangeStatus.valide).length,
        'exchanges_annules': exchanges.where((e) => e.statut == VirtualExchangeStatus.annule).length,
        'montant_total_usd': exchanges.where((e) => e.devise == 'USD' && e.statut == VirtualExchangeStatus.valide).fold<double>(0, (sum, e) => sum + e.montant),
        'montant_total_cdf': exchanges.where((e) => e.devise == 'CDF' && e.statut == VirtualExchangeStatus.valide).fold<double>(0, (sum, e) => sum + e.montant),
      };

      return stats;
    } catch (e) {
      debugPrint('❌ Erreur calcul statistiques échanges: $e');
      return {};
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
  }
}
