import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/virtual_transaction_model.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'sim_service.dart';
import 'currency_service.dart';
import 'virtual_transaction_sync_service.dart';

/// Service de gestion des transactions virtuelles (Mobile Money)
class VirtualTransactionService extends ChangeNotifier {
  static final VirtualTransactionService _instance = VirtualTransactionService._internal();
  static VirtualTransactionService get instance => _instance;
  
  VirtualTransactionService._internal();

  List<VirtualTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  VirtualTransactionSyncService _syncService = VirtualTransactionSyncService();
  bool _isSyncing = false;
  String? _syncError;

  List<VirtualTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncError => _syncError;
  VirtualTransactionSyncService get syncService => _syncService;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      debugPrint('🔄 Initialisation VirtualTransactionService pour shop: $shopId');
      await _syncService.initialize(shopId);
      
      // Écouter les changements d'état de synchronisation
      _syncService.addListener(_handleSyncStatusChange);
      
      // Charger les transactions initiales
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ VirtualTransactionService initialisé avec succès');
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur initialisation VirtualTransactionService: $e';
      debugPrint('❌ $_errorMessage');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Gérer les changements d'état de synchronisation
  void _handleSyncStatusChange() {
    _isSyncing = _syncService.isSyncing;
    _syncError = _syncService.error;
    notifyListeners();
  }

  /// Charger toutes les transactions (optionnellement filtrées)
  Future<void> loadTransactions({
    int? shopId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    VirtualTransactionStatus? statut,
    bool cleanDuplicates = false, // Nouveau paramètre pour forcer le nettoyage
    bool forceSync = false, // Forcer une synchronisation avec le serveur
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔍 [VirtualTransactionService] Chargement transactions...');
      debugPrint('   Filtre shopId: $shopId');
      debugPrint('   Filtre SIM: $simNumero');
      debugPrint('   Filtre dateDebut: $dateDebut');
      debugPrint('   Filtre dateFin: $dateFin');
      debugPrint('   Filtre statut: $statut');
      debugPrint('   Forcer sync: $forceSync');
      
      // Nettoyer les doublons si demandé
      if (cleanDuplicates) {
        final duplicatesCount = await LocalDB.instance.cleanDuplicateVirtualTransactions();
        if (duplicatesCount > 0) {
          debugPrint('🧹 $duplicatesCount doublons nettoyés');
        }
      }
      
      // Si forceSync est vrai, forcer une synchronisation avant de charger
      if (forceSync) {
        debugPrint('🔄 Forçage de la synchronisation...');
        await _syncService.syncTransactions();
      }
      
      // Charger depuis la base de données locale
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
        debugPrint('📋 Transaction details:');
        for (var i = 0; i < _transactions.length && i < 3; i++) {
          final t = _transactions[i];
          debugPrint('   #$i: ${t.reference} - ${t.montantVirtuel} ${t.devise} - ${t.statut.name}');
        }
        if (_transactions.length > 3) {
          debugPrint('   ... et ${_transactions.length - 3} transactions supplémentaires');
        }
      } else {
        debugPrint('ℹ️ Aucune transaction trouvée avec les filtres actuels');
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
      rethrow;
    }
  }

  /// Créer une nouvelle transaction virtuelle (capture client)
  Future<VirtualTransactionModel?> createTransaction({
    required String reference,
    required double montantVirtuel,
    required double frais,
    String devise = 'USD', // Support USD et CDF
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
        devise: devise, // Utiliser la devise sélectionnée
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
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(savedTransaction);
      
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
  /// NOUVEAU: Conversion automatique CDF → USD pour le cash
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
      debugPrint('   Devise: ${transaction.devise}');
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
      
      // NOUVEAU: Calcul du cash selon la devise
      double montantCashUsd;
      
      if (transaction.devise == 'CDF') {
        // Conversion CDF → USD pour le cash
        final montantVirtuelApresCommission = transaction.montantVirtuel - commission;
        montantCashUsd = CurrencyService.instance.convertCdfToUsd(montantVirtuelApresCommission);
        debugPrint('   Calcul CDF: Virtuel ${transaction.montantVirtuel} CDF - Commission $commission CDF = ${montantVirtuelApresCommission} CDF');
        debugPrint('   Conversion: ${montantVirtuelApresCommission} CDF → \$${montantCashUsd.toStringAsFixed(2)} USD (taux: ${CurrencyService.instance.tauxCdfToUsd})');
      } else {
        // Transaction déjà en USD
        montantCashUsd = transaction.montantVirtuel - commission;
        debugPrint('   Calcul USD: Virtuel \$${transaction.montantVirtuel} - Commission \$$commission = Cash \$${montantCashUsd.toStringAsFixed(2)}');
      }

      final updatedTransaction = transaction.copyWith(
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        frais: commission, // Mettre à jour avec la commission saisie
        montantCash: montantCashUsd, // TOUJOURS en USD pour le cash
        statut: VirtualTransactionStatus.validee,
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // IMPORTANT: Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.updateVirtualTransaction(updatedTransaction);
      debugPrint('✅ [VirtualTransactionService] Transaction validée - Cash à donner: \$${montantCashUsd.toStringAsFixed(2)} USD');
      
      // Mettre à jour le solde de la SIM (augmenter virtuel)
      await _updateSimBalance(updatedTransaction);
      
      // Recharger les transactions
      await loadTransactions(shopId: transaction.shopId);
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(updatedTransaction);
      
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
      
      // Ajouter à la file de synchronisation
      await _addToSyncQueue(updatedTransaction);
      
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
  /// IMPORTANT: Sépare les captures (dateEnregistrement) du cash servi (dateValidation)
  Future<Map<String, dynamic>> getDailyStats({
    required int shopId,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
      
      // Récupérer TOUTES les transactions du shop (pas de filtre de date ici)
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
      );
      
      // CAPTURES DU JOUR: Basées sur la DATE D'ENREGISTREMENT
      final capturesDuJour = allTransactions.where((t) => 
        t.dateEnregistrement.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        t.dateEnregistrement.isBefore(endOfDay.add(const Duration(seconds: 1)))
      ).toList();
      
      // SERVICES DU JOUR: Basées sur la DATE DE VALIDATION
      final servicesDuJour = allTransactions.where((t) => 
        t.statut == VirtualTransactionStatus.validee &&
        t.dateValidation != null &&
        t.dateValidation!.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        t.dateValidation!.isBefore(endOfDay.add(const Duration(seconds: 1)))
      ).toList();
      
      final enAttente = capturesDuJour.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
      final validees = capturesDuJour.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
      
      // Statistiques des CAPTURES (dateEnregistrement)
      final totalVirtuelEncaisse = validees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      final totalFrais = validees.fold<double>(0, (sum, t) => sum + t.frais);
      
      // CASH SERVI: Basé sur les services du jour (dateValidation)
      final totalCashServi = servicesDuJour.fold<double>(0, (sum, t) => sum + t.montantCash);
      
      debugPrint('📊 [VirtualTransactionService] Stats quotidiennes pour ${targetDate.toIso8601String().split('T')[0]}:');
      debugPrint('   Captures du jour (dateEnregistrement): ${capturesDuJour.length}');
      debugPrint('   Services du jour (dateValidation): ${servicesDuJour.length}');
      debugPrint('   Cash servi (validation): ${totalCashServi.toStringAsFixed(2)} USD');
      
      return {
        'total_transactions': capturesDuJour.length,
        'transactions_en_attente': enAttente.length,
        'transactions_validees': validees.length,
        'total_virtuel_encaisse': totalVirtuelEncaisse,
        'total_frais': totalFrais,
        'total_cash_servi': totalCashServi, // Basé sur dateValidation
        'services_du_jour': servicesDuJour.length, // NOUVEAU: Nombre de services
        'captures_du_jour': capturesDuJour.length, // NOUVEAU: Nombre de captures
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

  /// Forcer une synchronisation complète
  Future<bool> syncNow() async {
    try {
      _isSyncing = true;
      _syncError = null;
      notifyListeners();
      
      debugPrint('🔄 Démarrage manuel de la synchronisation...');
      final success = await _syncService.syncTransactions();
      
      if (success) {
        // Recharger les données après synchronisation
        await loadTransactions(forceSync: false);
      }
      
      return success;
    } catch (e) {
      _syncError = 'Erreur synchronisation: $e';
      debugPrint('❌ $_syncError');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _syncService.removeListener(_handleSyncStatusChange);
    super.dispose();
  }

  /// Ajouter une transaction à la file de synchronisation
  Future<void> _addToSyncQueue(VirtualTransactionModel transaction) async {
    try {
      await _syncService.addToSyncQueue(transaction);
      debugPrint('🔄 Transaction ajoutée à la file de synchronisation: ${transaction.reference}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Erreur ajout à la file de synchronisation: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
