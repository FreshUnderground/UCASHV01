import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../models/taux_model.dart';
import 'local_db.dart';
import 'rates_service.dart';

class TransactionService extends ChangeNotifier {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Charger toutes les transactions
  Future<void> loadTransactions({int? shopId, int? agentId}) async {
    _setLoading(true);
    try {
      if (shopId != null) {
        _transactions = await LocalDB.instance.getTransactionsByShop(shopId);
      } else if (agentId != null) {
        _transactions = await LocalDB.instance.getTransactionsByAgent(agentId);
      } else {
        _transactions = await LocalDB.instance.getAllTransactions();
      }
      
      // Trier par date de création (plus récent en premier)
      _transactions.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      
      _errorMessage = null;
      debugPrint('📋 Transactions chargées: ${_transactions.length}');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des transactions: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Créer une nouvelle transaction
  Future<bool> createTransaction({
    required String type,
    required double montant,
    required String deviseSource,
    required String deviseDestination,
    required int expediteurId,
    int? destinataireId,
    String? nomDestinataire,
    String? telephoneDestinataire,
    String? adresseDestinataire,
    required int agentId,
    required int shopId,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      // Calculer le taux de change
      final taux = await _getTauxChange(deviseSource, deviseDestination, type);
      if (taux == null) {
        _errorMessage = 'Taux de change non disponible pour $deviseSource/$deviseDestination';
        _setLoading(false);
        return false;
      }

      // Calculer le montant converti
      final montantConverti = montant * taux.taux;

      // Calculer la commission
      final commission = await _calculateCommission(montant, type);

      // Calculer le montant total
      final montantTotal = type == 'ENVOI' ? montant + commission : montant;

      // Générer une référence unique
      final reference = TransactionModel.generateReference();

      final newTransaction = TransactionModel(
        type: type,
        montant: montant,
        deviseSource: deviseSource,
        deviseDestination: deviseDestination,
        montantConverti: montantConverti,
        tauxChange: taux.taux,
        commission: commission,
        montantTotal: montantTotal,
        expediteurId: expediteurId,
        destinataireId: destinataireId,
        nomDestinataire: nomDestinataire,
        telephoneDestinataire: telephoneDestinataire,
        adresseDestinataire: adresseDestinataire,
        agentId: agentId,
        shopId: shopId,
        statut: 'CONFIRMEE',
        reference: reference,
        notes: notes,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentId',
      );

      // Sauvegarder localement
      await LocalDB.instance.saveTransaction(newTransaction);
      
      // Recharger la liste
      await loadTransactions(shopId: shopId);
 
      
      _errorMessage = null;
      _setLoading(false);
      debugPrint('✅ Transaction créée avec succès: $reference');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création de la transaction: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Mettre à jour une transaction
  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      final updatedTransaction = transaction.copyWith(
        lastModifiedAt: DateTime.now(),
      );
      
      await LocalDB.instance.updateTransaction(updatedTransaction);
      await loadTransactions(shopId: transaction.shopId);
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour de la transaction: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Annuler une transaction
  Future<bool> cancelTransaction(int transactionId, int shopId) async {
    try {
      final transaction = _transactions.firstWhere((t) => t.id == transactionId);
      final updatedTransaction = transaction.copyWith(
        statut: 'ANNULEE',
        lastModifiedAt: DateTime.now(),
      );
      
      await LocalDB.instance.updateTransaction(updatedTransaction);
      await loadTransactions(shopId: shopId);
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'annulation de la transaction: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Obtenir une transaction par ID
  TransactionModel? getTransactionById(int id) {
    try {
      return _transactions.firstWhere((transaction) => transaction.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtenir les transactions d'un agent
  List<TransactionModel> getTransactionsByAgent(int agentId) {
    return _transactions.where((t) => t.agentId == agentId).toList();
  }

  // Obtenir les transactions d'un shop
  List<TransactionModel> getTransactionsByShop(int shopId) {
    return _transactions.where((t) => t.shopId == shopId).toList();
  }

  // Obtenir les transactions par période
  List<TransactionModel> getTransactionsByPeriod(DateTime debut, DateTime fin) {
    return _transactions.where((t) {
      final date = t.createdAt ?? DateTime.now();
      return date.isAfter(debut) && date.isBefore(fin);
    }).toList();
  }

  // Rechercher des transactions
  List<TransactionModel> searchTransactions(String query) {
    final lowerQuery = query.toLowerCase();
    return _transactions.where((t) =>
      (t.reference?.toLowerCase().contains(lowerQuery) ?? false) ||
      (t.nomDestinataire?.toLowerCase().contains(lowerQuery) ?? false) ||
      (t.telephoneDestinataire?.contains(query) ?? false)
    ).toList();
  }

  // Calculer les statistiques des transactions
  Map<String, dynamic> getTransactionStats({int? shopId, int? agentId}) {
    List<TransactionModel> filteredTransactions = _transactions;
    
    if (shopId != null) {
      filteredTransactions = filteredTransactions.where((t) => t.shopId == shopId).toList();
    }
    if (agentId != null) {
      filteredTransactions = filteredTransactions.where((t) => t.agentId == agentId).toList();
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final transactionsToday = filteredTransactions.where((t) {
      final date = t.createdAt ?? DateTime.now();
      return date.isAfter(startOfDay);
    }).toList();

    final totalMontant = filteredTransactions.fold<double>(0, (sum, t) => sum + t.montant);
    final totalCommissions = filteredTransactions.fold<double>(0, (sum, t) => sum + t.commission);
    
    final envois = filteredTransactions.where((t) => t.type == 'ENVOI').length;
    final receptions = filteredTransactions.where((t) => t.type == 'RECEPTION').length;
    final depots = filteredTransactions.where((t) => t.type == 'DEPOT').length;
    final retraits = filteredTransactions.where((t) => t.type == 'RETRAIT').length;

    return {
      'totalTransactions': filteredTransactions.length,
      'transactionsToday': transactionsToday.length,
      'totalMontant': totalMontant,
      'totalCommissions': totalCommissions,
      'envois': envois,
      'receptions': receptions,
      'depots': depots,
      'retraits': retraits,
      'montantMoyenTransaction': filteredTransactions.isEmpty ? 0 : totalMontant / filteredTransactions.length,
    };
  }

  // Obtenir le taux de change approprié
  Future<TauxModel?> _getTauxChange(String deviseSource, String deviseDestination, String typeTransaction) async {
    final ratesService = RatesService.instance;
    await ratesService.loadRatesAndCommissions();
    
    // Déterminer le type de taux selon le type de transaction
    String typeTaux = 'NATIONAL';
    if (deviseSource != deviseDestination) {
      if (typeTransaction == 'ENVOI') {
        typeTaux = 'INTERNATIONAL_SORTANT';
      } else if (typeTransaction == 'RECEPTION') {
        typeTaux = 'INTERNATIONAL_ENTRANT';
      }
    }
    
    return ratesService.getTauxByDeviseAndType(deviseDestination, typeTaux);
  }

  // Calculer la commission
  Future<double> _calculateCommission(double montant, String typeTransaction) async {
    final ratesService = RatesService.instance;
    await ratesService.loadRatesAndCommissions();
    
    // Déterminer le type de commission
    String typeCommission = 'ENTRANT';
    if (typeTransaction == 'ENVOI') {
      typeCommission = 'SORTANT';
    }
    
    final commission = ratesService.getCommissionByType(typeCommission);
    if (commission != null) {
      return montant * (commission.taux / 100);
    }
    
    // PAS DE FALLBACK - Lancer une erreur
    debugPrint('❌ ERREUR: Commission $typeCommission non trouvée dans la base de données!');
    throw Exception('Commission $typeCommission non configurée. Veuillez configurer les commissions dans le système.');
  }

  // Valider les données de transaction
  String? validateTransactionData({
    required String type,
    required double montant,
    required String deviseSource,
    required String deviseDestination,
    required int expediteurId,
    String? nomDestinataire,
    String? telephoneDestinataire,
  }) {
    if (montant <= 0) {
      return 'Le montant doit être supérieur à zéro';
    }
    
    if (deviseSource.isEmpty || deviseDestination.isEmpty) {
      return 'Les devises source et destination sont requises';
    }
    
    if (type == 'ENVOI' && nomDestinataire?.isEmpty == true) {
      return 'Le nom du destinataire est requis pour un envoi';
    }
    
    if (type == 'ENVOI' && telephoneDestinataire?.isEmpty == true) {
      return 'Le téléphone du destinataire est requis pour un envoi';
    }
    
    return null;
  }

  // Nettoyer les erreurs
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
