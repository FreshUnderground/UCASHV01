import 'package:flutter/foundation.dart';
import '../models/credit_virtuel_model.dart';
import '../models/virtual_transaction_model.dart';
import 'local_db.dart';
import 'sim_service.dart';
import 'currency_service.dart';
import 'credit_virtuel_sync_service.dart';

/// Service de gestion des crédits virtuels entre shops/partenaires
class CreditVirtuelService extends ChangeNotifier {
  static final CreditVirtuelService _instance = CreditVirtuelService._internal();
  static CreditVirtuelService get instance => _instance;
  
  CreditVirtuelService._internal();

  List<CreditVirtuelModel> _credits = [];
  bool _isLoading = false;
  String? _errorMessage;
  CreditVirtuelSyncService _syncService = CreditVirtuelSyncService();
  bool _isSyncing = false;
  String? _syncError;

  List<CreditVirtuelModel> get credits => _credits;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncError => _syncError;
  CreditVirtuelSyncService get syncService => _syncService;

  /// Initialiser le service avec l'ID du shop
  Future<void> initialize(int shopId) async {
    try {
      debugPrint('💳 Initialisation CreditVirtuelService pour shop: $shopId');
      await _syncService.initialize(shopId);
      
      // Écouter les changements d'état de synchronisation
      _syncService.addListener(_handleSyncStatusChange);
      
      // Charger les crédits initiaux
      await loadCredits(shopId: shopId);
      
      debugPrint('✅ CreditVirtuelService initialisé avec succès');
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur initialisation CreditVirtuelService: $e';
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

  /// Charger tous les crédits (optionnellement filtrés)
  Future<void> loadCredits({
    int? shopId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    CreditVirtuelStatus? statut,
    String? beneficiaire,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔍 [CreditVirtuelService] Chargement crédits...');
      debugPrint('   Filtre shopId: $shopId');
      debugPrint('   Filtre SIM: $simNumero');
      debugPrint('   Filtre dateDebut: $dateDebut');
      debugPrint('   Filtre dateFin: $dateFin');
      debugPrint('   Filtre statut: $statut');
      debugPrint('   Filtre bénéficiaire: $beneficiaire');
      
      _credits = await LocalDB.instance.getAllCreditsVirtuels(
        shopId: shopId,
        simNumero: simNumero,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        beneficiaire: beneficiaire,
      );
      
      debugPrint('✅ [CreditVirtuelService] ${_credits.length} crédits chargés');
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur chargement crédits: $e';
      debugPrint('❌ [CreditVirtuelService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Accorder un nouveau crédit (sortie virtuelle)
  Future<CreditVirtuelModel?> accorderCredit({
    required String reference,
    required double montantCredit,
    String devise = 'USD',
    required String beneficiaireNom,
    String? beneficiaireTelephone,
    String? beneficiaireAdresse,
    String typeBeneficiaire = 'shop',
    required String simNumero,
    required int shopId,
    String? shopDesignation,
    required int agentId,
    String? agentUsername,
    DateTime? dateEcheance,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🆕 [CreditVirtuelService] Accord crédit...');
      debugPrint('   Référence: $reference');
      debugPrint('   Montant: $montantCredit $devise');
      debugPrint('   Bénéficiaire: $beneficiaireNom');
      debugPrint('   SIM: $simNumero');

      // Vérifier que la référence n'existe pas déjà
      final existingCredit = await LocalDB.instance.getCreditVirtuelByReference(reference);
      if (existingCredit != null) {
        throw Exception('Un crédit avec cette référence existe déjà: $reference');
      }

      // Vérifier le solde virtuel disponible sur la SIM
      final simService = SimService.instance;
      // Vérifier que la SIM existe
      final sim = simService.sims.firstWhere(
        (s) => s.numero == simNumero,
        orElse: () => throw Exception('SIM non trouvée: $simNumero'),
      );
      debugPrint('✅ SIM trouvée: ${sim.numero}');

      // Calculer le solde virtuel disponible
      final soldeVirtuelDisponible = await calculateSoldeVirtuelDisponible(simNumero);
      if (soldeVirtuelDisponible < montantCredit) {
        final currencyService = CurrencyService.instance;
        throw Exception('Solde virtuel insuffisant. Disponible: ${currencyService.formatMontant(soldeVirtuelDisponible, devise)}, Demandé: ${currencyService.formatMontant(montantCredit, devise)}');
      }

      final credit = CreditVirtuelModel(
        reference: reference,
        montantCredit: montantCredit,
        devise: devise,
        beneficiaireNom: beneficiaireNom,
        beneficiaireTelephone: beneficiaireTelephone,
        beneficiaireAdresse: beneficiaireAdresse,
        typeBeneficiaire: typeBeneficiaire,
        simNumero: simNumero,
        shopId: shopId,
        shopDesignation: shopDesignation,
        agentId: agentId,
        agentUsername: agentUsername,
        dateSortie: DateTime.now(),
        dateEcheance: dateEcheance,
        notes: notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'Agent $agentId',
      );

      final savedCredit = await LocalDB.instance.insertCreditVirtuel(credit);
      
      if (savedCredit != null) {
        debugPrint('✅ [CreditVirtuelService] Crédit accordé: ${savedCredit.reference}');
        
        // Ajouter à la file de synchronisation
        await _addToSyncQueue(savedCredit);
        
        // Recharger la liste
        await loadCredits();
        
        _setLoading(false);
        return savedCredit;
      } else {
        throw Exception('Erreur lors de la sauvegarde du crédit');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur accord crédit: $e';
      debugPrint('❌ [CreditVirtuelService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Enregistrer un paiement de crédit (cash augmente)
  Future<bool> enregistrerPaiement({
    required int creditId,
    required double montantPaiement,
    String modePaiement = 'cash',
    String? referencePaiement,
    required int agentId,
    String? agentUsername,
  }) async {
    _setLoading(true);
    try {
      debugPrint('💰 [CreditVirtuelService] Enregistrement paiement...');
      debugPrint('   Crédit ID: $creditId');
      debugPrint('   Montant: $montantPaiement');
      debugPrint('   Mode: $modePaiement');

      final credit = await LocalDB.instance.getCreditVirtuelById(creditId);
      if (credit == null) {
        throw Exception('Crédit non trouvé: $creditId');
      }

      if (credit.statut == CreditVirtuelStatus.paye) {
        throw Exception('Ce crédit est déjà entièrement payé');
      }

      if (credit.statut == CreditVirtuelStatus.annule) {
        throw Exception('Ce crédit est annulé');
      }

      final nouveauMontantPaye = (credit.montantPaye ?? 0.0) + montantPaiement;
      if (nouveauMontantPaye > credit.montantCredit) {
        throw Exception('Le montant total des paiements dépasse le montant du crédit');
      }

      // Déterminer le nouveau statut
      CreditVirtuelStatus nouveauStatut;
      if (nouveauMontantPaye >= credit.montantCredit) {
        nouveauStatut = CreditVirtuelStatus.paye;
      } else {
        nouveauStatut = CreditVirtuelStatus.partiellementPaye;
      }

      final creditMisAJour = credit.copyWith(
        montantPaye: nouveauMontantPaye,
        modePaiement: modePaiement,
        referencePaiement: referencePaiement,
        datePaiement: nouveauStatut == CreditVirtuelStatus.paye ? DateTime.now() : credit.datePaiement,
        statut: nouveauStatut,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'Agent $agentId',
        isSynced: false,
      );

      final success = await LocalDB.instance.updateCreditVirtuel(creditMisAJour);
      
      if (success) {
        debugPrint('✅ [CreditVirtuelService] Paiement enregistré: ${creditMisAJour.reference}');
        
        // Ajouter à la file de synchronisation
        await _addToSyncQueue(creditMisAJour);
        
        // Recharger la liste
        await loadCredits();
        
        _setLoading(false);
        return true;
      } else {
        throw Exception('Erreur lors de la mise à jour du crédit');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur enregistrement paiement: $e';
      debugPrint('❌ [CreditVirtuelService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Annuler un crédit
  Future<bool> annulerCredit({
    required int creditId,
    required int agentId,
    String? agentUsername,
    String? motifAnnulation,
  }) async {
    _setLoading(true);
    try {
      debugPrint('❌ [CreditVirtuelService] Annulation crédit...');
      debugPrint('   Crédit ID: $creditId');
      debugPrint('   Motif: $motifAnnulation');

      final credit = await LocalDB.instance.getCreditVirtuelById(creditId);
      if (credit == null) {
        throw Exception('Crédit non trouvé: $creditId');
      }

      if (credit.statut == CreditVirtuelStatus.paye) {
        throw Exception('Impossible d\'annuler un crédit déjà payé');
      }

      if (credit.statut == CreditVirtuelStatus.annule) {
        throw Exception('Ce crédit est déjà annulé');
      }

      final creditAnnule = credit.copyWith(
        statut: CreditVirtuelStatus.annule,
        notes: motifAnnulation != null 
          ? '${credit.notes ?? ''}\nANNULÉ: $motifAnnulation'.trim()
          : credit.notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'Agent $agentId',
        isSynced: false,
      );

      final success = await LocalDB.instance.updateCreditVirtuel(creditAnnule);
      
      if (success) {
        debugPrint('✅ [CreditVirtuelService] Crédit annulé: ${creditAnnule.reference}');
        
        // Ajouter à la file de synchronisation
        await _addToSyncQueue(creditAnnule);
        
        // Recharger la liste
        await loadCredits();
        
        _setLoading(false);
        return true;
      } else {
        throw Exception('Erreur lors de l\'annulation du crédit');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur annulation crédit: $e';
      debugPrint('❌ [CreditVirtuelService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Calculer le solde virtuel disponible sur une SIM
  Future<double> calculateSoldeVirtuelDisponible(String simNumero) async {
    try {
      // Récupérer toutes les transactions virtuelles de cette SIM
      final transactions = await LocalDB.instance.getAllVirtualTransactions(
        simNumero: simNumero,
      );

      // Récupérer tous les crédits accordés de cette SIM
      final credits = await LocalDB.instance.getAllCreditsVirtuels(
        simNumero: simNumero,
      );

      double soldeVirtuel = 0.0;

      // Ajouter les captures validées (argent reçu virtuellement)
      for (final transaction in transactions) {
        if (transaction.statut == VirtualTransactionStatus.validee && !transaction.isAdministrative) {
          soldeVirtuel += transaction.montantVirtuel;
        }
      }

      // Soustraire les crédits accordés (non annulés)
      for (final credit in credits) {
        if (credit.statut != CreditVirtuelStatus.annule) {
          soldeVirtuel -= credit.montantCredit;
        }
      }

      return soldeVirtuel;
    } catch (e) {
      debugPrint('❌ [CreditVirtuelService] Erreur calcul solde virtuel: $e');
      return 0.0;
    }
  }

  /// Obtenir les statistiques des crédits
  Future<Map<String, dynamic>> getStatistiques({
    int? shopId,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    try {
      final credits = await LocalDB.instance.getAllCreditsVirtuels(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );

      double totalAccorde = 0.0;
      double totalPaye = 0.0;
      double totalEnAttente = 0.0;
      double totalEnRetard = 0.0;
      int nombreCredits = credits.length;
      int nombrePayes = 0;
      int nombreEnAttente = 0;
      int nombreEnRetard = 0;

      for (final credit in credits) {
        if (credit.statut != CreditVirtuelStatus.annule) {
          totalAccorde += credit.montantCredit;
          totalPaye += credit.montantPaye ?? 0.0;

          if (credit.statut == CreditVirtuelStatus.paye) {
            nombrePayes++;
          } else {
            final montantRestant = credit.montantRestant;
            if (credit.estEnRetard) {
              totalEnRetard += montantRestant;
              nombreEnRetard++;
            } else {
              totalEnAttente += montantRestant;
              nombreEnAttente++;
            }
          }
        }
      }

      return {
        'nombre_credits': nombreCredits,
        'total_accorde': totalAccorde,
        'total_paye': totalPaye,
        'total_en_attente': totalEnAttente,
        'total_en_retard': totalEnRetard,
        'nombre_payes': nombrePayes,
        'nombre_en_attente': nombreEnAttente,
        'nombre_en_retard': nombreEnRetard,
        'taux_recouvrement': totalAccorde > 0 ? (totalPaye / totalAccorde) * 100 : 0.0,
      };
    } catch (e) {
      debugPrint('❌ [CreditVirtuelService] Erreur calcul statistiques: $e');
      return {};
    }
  }

  /// Rechercher des crédits par référence ou bénéficiaire
  List<CreditVirtuelModel> searchCredits(String query) {
    if (query.isEmpty) return _credits;
    
    final queryLower = query.toLowerCase();
    return _credits.where((credit) {
      return credit.reference.toLowerCase().contains(queryLower) ||
             credit.beneficiaireNom.toLowerCase().contains(queryLower) ||
             (credit.beneficiaireTelephone?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  /// Obtenir les crédits en retard
  List<CreditVirtuelModel> getCreditsEnRetard() {
    return _credits.where((credit) => credit.estEnRetard).toList();
  }

  /// Forcer une synchronisation complète
  Future<bool> syncNow() async {
    try {
      _isSyncing = true;
      _syncError = null;
      notifyListeners();
      
      debugPrint('🔄 Démarrage manuel de la synchronisation crédits...');
      final success = await _syncService.syncCredits();
      
      if (success) {
        // Recharger les données après synchronisation
        await loadCredits();
      }
      
      return success;
    } catch (e) {
      _syncError = 'Erreur synchronisation crédits: $e';
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

  /// Ajouter un crédit à la file de synchronisation
  Future<void> _addToSyncQueue(CreditVirtuelModel credit) async {
    try {
      await _syncService.addToSyncQueue(credit);
      debugPrint('🔄 Crédit ajouté à la file de synchronisation: ${credit.reference}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Erreur ajout crédit à la file de synchronisation: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (!loading) notifyListeners();
  }

  /// Nettoyer les données en mémoire
  void clear() {
    _credits.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
