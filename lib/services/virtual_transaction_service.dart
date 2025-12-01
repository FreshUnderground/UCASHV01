import 'package:flutter/foundation.dart';
import '../models/virtual_transaction_model.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'sim_service.dart';

/// Service de gestion des transactions virtuelles (Mobile Money)
class VirtualTransactionService extends ChangeNotifier {
  static final VirtualTransactionService _instance = VirtualTransactionService._internal();
  static VirtualTransactionService get instance => _instance;
  
  VirtualTransactionService._internal();

  List<VirtualTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<VirtualTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger toutes les transactions (optionnellement filtrées)
  Future<void> loadTransactions({
    int? shopId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    VirtualTransactionStatus? statut,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔍 [VirtualTransactionService] Chargement transactions...');
      debugPrint('   Filtre shopId: $shopId (${shopId?.runtimeType})');
      debugPrint('   Filtre SIM: $simNumero');
      debugPrint('   Filtre dateDebut: $dateDebut');
      debugPrint('   Filtre dateFin: $dateFin');
      debugPrint('   Filtre statut: $statut');
      
      _transactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
        simNumero: simNumero,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
      );
      
      debugPrint('✅ [VirtualTransactionService] ${_transactions.length} transactions chargées');
      
      // Log transaction details for debugging
      if (_transactions.isNotEmpty) {
        debugPrint('📋 [VirtualTransactionService] Transaction details:');
        for (var i = 0; i < _transactions.length && i < 5; i++) {
          final t = _transactions[i];
          debugPrint('   #$i: ${t.reference} - Shop: ${t.shopId} (${t.shopId.runtimeType}) - Status: ${t.statut.name} - SIM: ${t.simNumero}');
        }
        if (_transactions.length > 5) {
          debugPrint('   ... and ${_transactions.length - 5} more transactions');
        }
      }
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur chargement transactions: $e';
      debugPrint('❌ [VirtualTransactionService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Créer une nouvelle transaction virtuelle (capture client)
  Future<VirtualTransactionModel?> createTransaction({
    required String reference,
    required double montantVirtuel,
    required double frais,
    required String simNumero,
    required int shopId,
    String? shopDesignation,
    required int agentId,
    String? agentUsername,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🆕 [VirtualTransactionService] Création transaction...');
      debugPrint('   Référence: $reference');
      debugPrint('   Montant virtuel: $montantVirtuel');
      debugPrint('   Frais: $frais');
      debugPrint('   SIM: $simNumero');
      
      // Vérifier si la référence existe déjà
      if (await _referenceExists(reference)) {
        _errorMessage = 'Cette référence existe déjà';
        debugPrint('❌ [VirtualTransactionService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return null;
      }

      final montantCash = montantVirtuel - frais;
      
      final newTransaction = VirtualTransactionModel(
        reference: reference,
        montantVirtuel: montantVirtuel,
        frais: frais,
        montantCash: montantCash,
        simNumero: simNumero,
        shopId: shopId,
        shopDesignation: shopDesignation,
        agentId: agentId,
        agentUsername: agentUsername,
        statut: VirtualTransactionStatus.enAttente,
        dateEnregistrement: DateTime.now(),
        notes: notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'agent_$agentId',
      );
      
      debugPrint('📦 [VirtualTransactionService] Sauvegarde transaction...');
      final savedTransaction = await LocalDB.instance.saveVirtualTransaction(newTransaction);
      debugPrint('✅ [VirtualTransactionService] Transaction sauvegardée avec ID #${savedTransaction.id}');
      
      // IMPORTANT: Recalculer le solde de la SIM dès l'enregistrement de la capture
      final sim = await LocalDB.instance.getSimByNumero(simNumero);
      if (sim != null) {
        await SimService.instance.updateSoldeAutomatiquement(sim);
        debugPrint('💰 Solde SIM $simNumero recalculé après enregistrement capture');
      }
      
      // Recharger les transactions
      await loadTransactions(shopId: shopId);
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return savedTransaction;
    } catch (e) {
      _errorMessage = 'Erreur création transaction: $e';
      debugPrint('❌ [VirtualTransactionService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Valider une transaction (servir le client)
  Future<bool> validateTransaction({
    required VirtualTransactionModel transaction,
    required String clientNom,
    required String clientTelephone,
    required double commission,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('✅ [VirtualTransactionService] Validation transaction...');
      debugPrint('   ID: ${transaction.id}');
      debugPrint('   Référence: ${transaction.reference}');
      debugPrint('   Client: $clientNom');
      debugPrint('   Commission saisie: $commission (Frais initiaux: ${transaction.frais})');
      
      if (transaction.statut != VirtualTransactionStatus.enAttente) {
        _errorMessage = 'Cette transaction a déjà été traitée';
        debugPrint('❌ [VirtualTransactionService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }
      
      // PROTECTION: Ne pas permettre de revalider une transaction déjà validée
      if (transaction.dateValidation != null) {
        _errorMessage = 'Cette transaction a déjà été validée le ${transaction.dateValidation}';
        debugPrint('⚠️ [VirtualTransactionService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }
      
      // Calculer le montant cash avec la commission saisie
      final montantCash = transaction.montantVirtuel - commission;
      debugPrint('   Calcul: Virtuel ${transaction.montantVirtuel} - Commission $commission = Cash $montantCash');

      final updatedTransaction = transaction.copyWith(
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        frais: commission, // Mettre à jour avec la commission saisie
        montantCash: montantCash, // Mettre à jour le montant cash
        statut: VirtualTransactionStatus.validee,
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // IMPORTANT: Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.updateVirtualTransaction(updatedTransaction);
      debugPrint('✅ [VirtualTransactionService] Transaction validée avec commission $commission');
      
      // Mettre à jour le solde de la SIM (augmenter virtuel)
      await _updateSimBalance(updatedTransaction);
      
      // Recharger les transactions
      await loadTransactions(shopId: transaction.shopId);
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur validation transaction: $e';
      debugPrint('❌ [VirtualTransactionService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Annuler une transaction
  Future<bool> cancelTransaction({
    required VirtualTransactionModel transaction,
    String? motif,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('❌ [VirtualTransactionService] Annulation transaction...');
      debugPrint('   ID: ${transaction.id}');
      debugPrint('   Référence: ${transaction.reference}');
      debugPrint('   Motif: $motif');
      
      if (transaction.statut != VirtualTransactionStatus.enAttente) {
        _errorMessage = 'Seules les transactions en attente peuvent être annulées';
        debugPrint('❌ [VirtualTransactionService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final updatedTransaction = transaction.copyWith(
        statut: VirtualTransactionStatus.annulee,
        notes: motif != null ? '${transaction.notes ?? ""}\nAnnulation: $motif' : transaction.notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // IMPORTANT: Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.updateVirtualTransaction(updatedTransaction);
      debugPrint('✅ [VirtualTransactionService] Transaction annulée');
      
      // IMPORTANT: Recalculer le solde de la SIM car une capture annulée ne compte plus
      final sim = await LocalDB.instance.getSimByNumero(transaction.simNumero);
      if (sim != null) {
        await SimService.instance.updateSoldeAutomatiquement(sim);
        debugPrint('💰 Solde SIM ${transaction.simNumero} recalculé après annulation');
      }
      
      // Recharger les transactions
      await loadTransactions(shopId: transaction.shopId);
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur annulation transaction: $e';
      debugPrint('❌ [VirtualTransactionService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Rechercher une transaction par référence
  Future<VirtualTransactionModel?> findByReference(String reference) async {
    try {
      debugPrint('🔍 [VirtualTransactionService] Recherche par référence: $reference');
      return await LocalDB.instance.getVirtualTransactionByReference(reference);
    } catch (e) {
      debugPrint('❌ [VirtualTransactionService] Erreur recherche: $e');
      return null;
    }
  }

  /// Obtenir les statistiques quotidiennes
  Future<Map<String, dynamic>> getDailyStats({
    required int shopId,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
      
      final dayTransactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
        dateDebut: startOfDay,
        dateFin: endOfDay,
      );
      
      final enAttente = dayTransactions.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
      final validees = dayTransactions.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
      
      final totalVirtuelEncaisse = validees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      final totalFrais = validees.fold<double>(0, (sum, t) => sum + t.frais);
      final totalCashServi = validees.fold<double>(0, (sum, t) => sum + t.montantCash);
      
      return {
        'total_transactions': dayTransactions.length,
        'transactions_en_attente': enAttente.length,
        'transactions_validees': validees.length,
        'total_virtuel_encaisse': totalVirtuelEncaisse,
        'total_frais': totalFrais,
        'total_cash_servi': totalCashServi,
      };
    } catch (e) {
      debugPrint('❌ [VirtualTransactionService] Erreur stats: $e');
      return {};
    }
  }

  /// Vérifier si une référence existe déjà (insensible à la casse et aux espaces)
  Future<bool> _referenceExists(String reference) async {
    // Normaliser la référence : trim + lowercase
    final normalizedReference = reference.trim().toLowerCase();
    final existing = await LocalDB.instance.getVirtualTransactionByReference(normalizedReference);
    return existing != null;
  }

  /// Recalculer automatiquement le solde de la SIM après une opération
  Future<void> _updateSimBalance(VirtualTransactionModel transaction) async {
    try {
      final sim = await LocalDB.instance.getSimByNumero(transaction.simNumero);
      if (sim != null) {
        // IMPORTANT: Ne PAS mettre à jour manuellement le solde!
        // Au lieu de cela, recalculer automatiquement basé sur les captures et retraits
        final wasUpdated = await SimService.instance.updateSoldeAutomatiquement(sim);
        if (wasUpdated) {
          debugPrint('☺️ Solde SIM ${sim.numero} recalculé automatiquement');
        } else {
          debugPrint('ℹ️ Solde SIM ${sim.numero} déjà à jour');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur recalcul solde SIM: $e');
    }
  }

  /// Synchronisation en arrière-plan
  void _syncInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        SyncService().syncAll();
        debugPrint('🔄 Synchronisation en arrière-plan déclenchée');
      } catch (e) {
        debugPrint('⚠️ Erreur sync en arrière-plan: $e');
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
