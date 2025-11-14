import 'package:flutter/foundation.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/commission_model.dart';
import '../models/shop_model.dart';
import 'local_db.dart';
import 'rates_service.dart';
import 'sync_service.dart';
import 'taux_change_service.dart';
import 'agent_service.dart';
import 'auth_service.dart';

class OperationService extends ChangeNotifier {
  static final OperationService _instance = OperationService._internal();
  factory OperationService() => _instance;
  OperationService._internal();

  List<OperationModel> _operations = [];
  final List<JournalCaisseModel> _journalEntries = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OperationModel> get operations => _operations;
  List<JournalCaisseModel> get journalEntries => _journalEntries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Charger les opérations
  Future<void> loadOperations({int? shopId, int? agentId}) async {
    _setLoading(true);
    try {
      _operations = await LocalDB.instance.getAllOperations();
      
      debugPrint('📊 loadOperations: ${_operations.length} opérations totales chargées depuis LocalDB');
      
      // Pas d'initialisation de données par défaut
      // Les opérations seront créées uniquement par les utilisateurs
      
      if (shopId != null) {
        final beforeFilter = _operations.length;
        _operations = _operations.where((op) => 
          op.shopSourceId == shopId || op.shopDestinationId == shopId).toList();
        debugPrint('📊 Filtre shopId=$shopId: $beforeFilter → ${_operations.length} opérations');
      }
      
      if (agentId != null) {
        final beforeFilter = _operations.length;
        _operations = _operations.where((op) => op.agentId == agentId).toList();
        debugPrint('📊 Filtre agentId=$agentId: $beforeFilter → ${_operations.length} opérations');
      }
      
      _operations.sort((a, b) => b.dateOp.compareTo(a.dateOp));
      _errorMessage = null;
      debugPrint('📊 ✅ Opérations finales: ${_operations.length}');
      if (_operations.isNotEmpty) {
        for (var op in _operations) {
          debugPrint('   - Op #${op.id}: ${op.type.name}, shop_source=${op.shopSourceId}, shop_dest=${op.shopDestinationId}, agent=${op.agentId}');
        }
      }
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Pas d'initialisation de données de test
  // Les opérations sont créées uniquement par les utilisateurs

  Future<OperationModel?> createOperation(OperationModel operation, {AuthService? authService}) async {
    try {
      // RÉSOUDRE et ENRICHIR l'opération avec l'USERNAME de l'agent AVANT sauvegarde
      OperationModel enrichedOperation = operation;
      
      // Obtenir l'username de l'agent connecté depuis AuthService
      if (authService != null && authService.currentUser != null) {
        final agentUsername = authService.currentUser!.username;
        enrichedOperation = operation.copyWith(
          lastModifiedBy: 'agent_$agentUsername', // Stocker username pour sync
        );
        debugPrint('✅ Agent enrichi depuis session: username "$agentUsername"');
      } else {
        // Fallback: chercher l'agent par ID (si disponible localement)
        if (operation.agentId != null) {
          // Vérifier si les agents sont chargés en mémoire
          if (AgentService.instance.agents.isEmpty) {
            debugPrint('⚠️ Liste des agents vide, rechargement depuis LocalDB...');
            await AgentService.instance.loadAgents();
            debugPrint('✅ ${AgentService.instance.agents.length} agents chargés');
          }
          
          final agent = AgentService.instance.getAgentById(operation.agentId!);
          if (agent != null) {
            enrichedOperation = operation.copyWith(
              lastModifiedBy: 'agent_${agent.username}',
            );
            debugPrint('✅ Agent enrichi par ID: username "${agent.username}"');
          } else {
            debugPrint('⚠️ Agent non trouvé pour ID ${operation.agentId}');
            
            // Vérifier si des agents existent APRÈS rechargement
            final agents = AgentService.instance.agents;
            if (agents.isEmpty) {
              debugPrint('❌ CRITIQUE: Aucun agent disponible même après rechargement!');
              debugPrint('💡 Solution: Synchronisez pour télécharger les agents depuis MySQL');
              throw Exception('Aucun agent disponible. Veuillez synchroniser d\'abord.');
            } else {
              debugPrint('📊 Agents disponibles: ${agents.map((a) => "ID=${a.id} username=${a.username}").join(", ")}');
            }
          }
        } else {
          debugPrint('⚠️ Opération créée sans agentId ni AuthService');
        }
      }
      
      // Calculer la commission automatiquement
      final operationWithCommission = await _calculateCommission(enrichedOperation);
      
      // Mettre à jour les soldes selon le type d'opération
      await _updateBalances(operationWithCommission);
      
      // Sauvegarder l'opération
      final savedOperation = await LocalDB.instance.saveOperation(operationWithCommission);
      
      // Créer l'entrée dans le journal de caisse
      await _createJournalEntry(savedOperation);
      
      // Si offline, mettre en file d'attente pour synchronisation
      final syncService = SyncService();
      if (!syncService.isOnline) {
        await syncService.queueOperation(savedOperation.toJson());
        debugPrint('📋 Opération mise en file d\'attente (mode offline)');
      }
      
      // Recharger les opérations
      await loadOperations();
      
      debugPrint('✅ Opération créée avec mise à jour des soldes: ${savedOperation.id}');
      return savedOperation;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création: $e';
      debugPrint(_errorMessage);
      return null;
    }
  }

  // Valider une opération
  Future<bool> validateOperation(int operationId, ModePaiement modePaiement) async {
    try {
      final operation = _operations.firstWhere((op) => op.id == operationId);
      
      final updatedOperation = operation.copyWith(
        statut: OperationStatus.validee,
        modePaiement: modePaiement,
        lastModifiedAt: DateTime.now(),
      );
      
      await LocalDB.instance.updateOperation(updatedOperation);

      
      // Recharger les données
      await loadOperations();
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la validation: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Calculer la commission selon le type d'opération
  Future<OperationModel> _calculateCommission(OperationModel operation) async {
    double commission = 0.0;
    
    switch (operation.type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Récupérer la commission depuis RatesService pour les transferts sortants
        final ratesService = RatesService.instance;
        await ratesService.loadRatesAndCommissions();
        
        final commissionData = ratesService.commissions.firstWhere(
          (c) => c.type == 'SORTANT',
          orElse: () {
            debugPrint('❌ ERREUR: Commission SORTANT non trouvée dans la base de données!');
            throw Exception('Commission SORTANT non configurée. Veuillez configurer les commissions dans le système.');
          },
        );
        
        commission = operation.montantBrut * (commissionData.taux / 100);
        break;
        
      case OperationType.transfertInternationalEntrant:
        // Transferts entrants gratuits
        commission = 0.0;
        break;
        
      case OperationType.depot:
      case OperationType.retrait:
        // Dépôts et retraits dans comptes clients : pas de commission
        commission = 0.0;
        break;
        
      case OperationType.virement:
        // Virements internes gratuits
        commission = 0.0;
        break;
    }
    
    return operation.copyWith(
      commission: commission,
      montantNet: operation.montantBrut - commission,
    );
  }

  // Mettre à jour les soldes selon le type d'opération
  Future<void> _updateBalances(OperationModel operation) async {
    switch (operation.type) {
      case OperationType.depot:
        await _handleDepotBalances(operation);
        break;
      case OperationType.retrait:
        await _handleRetraitBalances(operation);
        break;
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
      case OperationType.transfertInternationalEntrant:
        await _handleTransfertBalances(operation);
        break;
      case OperationType.virement:
        // Les virements internes ne changent pas les soldes globaux
        break;
    }
  }

  // Gérer les soldes pour un dépôt
  Future<void> _handleDepotBalances(OperationModel operation) async {
    try {
      // 1. Augmenter le solde du client
      if (operation.clientId != null) {
        final client = await LocalDB.instance.getClientById(operation.clientId!);
        if (client != null) {
          final updatedClient = client.copyWith(
            solde: client.solde + operation.montantNet,
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: 'operation_${operation.id}',
          );
          await LocalDB.instance.saveClient(updatedClient);
          debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${updatedClient.solde} USD');
        }
      }

      // 2. Augmenter le capital du shop selon le mode de paiement
      if (operation.shopSourceId != null) {
        final shop = await LocalDB.instance.getShopById(operation.shopSourceId!);
        if (shop != null) {
          final updatedShop = _updateShopCapital(shop, operation.modePaiement, operation.montantNet, true, devise: operation.devise);
          await LocalDB.instance.saveShop(updatedShop);
          debugPrint('🏪 Capital shop ${shop.designation} mis a jour (+${operation.montantNet} ${operation.devise})');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes dépôt: $e');
      throw e;
    }
  }

  // Gérer les soldes pour un retrait
  Future<void> _handleRetraitBalances(OperationModel operation) async {
    try {
      // 1. Diminuer le solde du client (DÉCOUVERT AUTORISÉ - solde peut devenir négatif)
      if (operation.clientId != null) {
        final client = await LocalDB.instance.getClientById(operation.clientId!);
        if (client != null) {
          // IMPORTANT: Pas de vérification de solde insuffisant
          // Le client peut avoir un solde négatif (nous devons de l'argent au client)
          // ou retirer plus que son solde (le client nous doit de l'argent)
          
          final nouveauSolde = client.solde - operation.montantNet;
          final updatedClient = client.copyWith(
            solde: nouveauSolde,
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: 'operation_${operation.id}',
          );
          await LocalDB.instance.saveClient(updatedClient);
          
          if (nouveauSolde < 0) {
            debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${nouveauSolde} USD (DÉCOUVERT - client nous doit ${nouveauSolde.abs()} USD)');
          } else {
            debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${nouveauSolde} USD');
          }
        }
      }

      // 2. Diminuer le capital du shop selon le mode de paiement
      if (operation.shopSourceId != null) {
        final shop = await LocalDB.instance.getShopById(operation.shopSourceId!);
        if (shop != null) {
          final updatedShop = _updateShopCapital(shop, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
          await LocalDB.instance.saveShop(updatedShop);
          debugPrint('🏪 Capital shop ${shop.designation} mis a jour (-${operation.montantNet} ${operation.devise})');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes retrait: $e');
      throw e;
    }
  }

  // Gérer les soldes pour un transfert selon la logique métier UCASH
  Future<void> _handleTransfertBalances(OperationModel operation) async {
    try {
      // LOGIQUE MÉTIER UCASH CORRECTE :
      // 1. À la création : Shop source GAGNE l'argent (client paie)
      // 2. À la validation : Shop destination PERD l'argent (sert le bénéficiaire)
      
      if (operation.statut == OperationStatus.enAttente) {
        // CRÉATION DU TRANSFERT : Shop source reçoit l'argent du client
        if (operation.shopSourceId != null) {
          final shopSource = await LocalDB.instance.getShopById(operation.shopSourceId!);
          if (shopSource != null) {
            // Le shop source GAGNE le montant brut (montant + commission)
            final updatedShopSource = _updateShopCapital(shopSource, operation.modePaiement, operation.montantBrut, true, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopSource);
            debugPrint('🏪 Shop source ${shopSource.designation}: +${operation.montantBrut} ${operation.devise} (client paie)');
          }
        }
      } else if (operation.statut == OperationStatus.validee) {
        // VALIDATION DU TRANSFERT : Shop destination sert l'argent
        
        // Transferts nationaux
        if (operation.shopDestinationId != null && operation.type == OperationType.transfertNational) {
          final shopDestination = await LocalDB.instance.getShopById(operation.shopDestinationId!);
          if (shopDestination != null) {
            // Le shop destination PERD le montant net (sert au bénéficiaire)
            final updatedShopDestination = _updateShopCapital(shopDestination, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopDestination);
            debugPrint('🏪 Shop destination ${shopDestination.designation}: -${operation.montantNet} ${operation.devise} (sert beneficiaire)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : SORTIE pour le shop destination
            final journalEntryServie = JournalCaisseModel(
              shopId: operation.shopDestinationId!,
              agentId: operation.agentId,
              libelle: 'Transfert SERVIE - ${operation.destinataire} (Montant servi)',
              montant: operation.montantNet, // Montant servi au bénéficiaire
              type: TypeMouvement.sortie, // SORTIE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date de validation/service
              operationId: operation.id,
              notes: 'Transfert validé depuis ${shopDestination.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryServie);
            debugPrint('📝 Journal caisse: SORTIE de ${operation.montantNet} ${operation.devise} pour shop destination');
          }
        }
        
        // Transferts internationaux ENTRANTS : même logique
        if (operation.shopDestinationId != null && operation.type == OperationType.transfertInternationalEntrant) {
          final shopDestination = await LocalDB.instance.getShopById(operation.shopDestinationId!);
          if (shopDestination != null) {
            // Le shop destination PERD le montant net (sert au bénéficiaire)
            final updatedShopDestination = _updateShopCapital(shopDestination, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopDestination);
            debugPrint('🏪 Shop destination ${shopDestination.designation}: -${operation.montantNet} ${operation.devise} (sert beneficiaire international)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : SORTIE pour le shop destination
            final journalEntryServie = JournalCaisseModel(
              shopId: operation.shopDestinationId!,
              agentId: operation.agentId,
              libelle: 'Transfert International SERVIE - ${operation.destinataire} (Montant servi)',
              montant: operation.montantNet, // Montant servi au bénéficiaire
              type: TypeMouvement.sortie, // SORTIE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date de validation/service
              operationId: operation.id,
              notes: 'Transfert international validé depuis ${shopDestination.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryServie);
            debugPrint('📝 Journal caisse: SORTIE de ${operation.montantNet} ${operation.devise} pour shop destination (international)');
          }
        }
      }

      // 3. Pour les transferts internationaux sortants : shop source gagne à la création
      // 4. Pour les transferts internationaux entrants : shop destination perd à la validation
      
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes transfert: $e');
      throw e;
    }
  }

  // Mettre à jour le capital d'un shop selon le mode de paiement ET la devise
  ShopModel _updateShopCapital(ShopModel shop, ModePaiement modePaiement, double montant, bool isCredit, {String? devise}) {
    final factor = isCredit ? 1.0 : -1.0;
    final deltaAmount = montant * factor;
    
    // Determiner la devise de l'operation (par defaut USD)
    final deviseOp = devise ?? shop.devisePrincipale;
    
    // Si la devise de l'operation est la devise principale
    if (deviseOp == shop.devisePrincipale) {
      switch (modePaiement) {
        case ModePaiement.cash:
          return shop.copyWith(
            capitalCash: shop.capitalCash + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.airtelMoney:
          return shop.copyWith(
            capitalAirtelMoney: shop.capitalAirtelMoney + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.mPesa:
          return shop.copyWith(
            capitalMPesa: shop.capitalMPesa + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.orangeMoney:
          return shop.copyWith(
            capitalOrangeMoney: shop.capitalOrangeMoney + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
      }
    } 
    // Si la devise de l'operation est la devise secondaire
    else if (deviseOp == shop.deviseSecondaire) {
      switch (modePaiement) {
        case ModePaiement.cash:
          return shop.copyWith(
            capitalCashDevise2: (shop.capitalCashDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.airtelMoney:
          return shop.copyWith(
            capitalAirtelMoneyDevise2: (shop.capitalAirtelMoneyDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.mPesa:
          return shop.copyWith(
            capitalMPesaDevise2: (shop.capitalMPesaDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.orangeMoney:
          return shop.copyWith(
            capitalOrangeMoneyDevise2: (shop.capitalOrangeMoneyDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
      }
    }
    
    // Si la devise n'est pas supportee, retourner le shop inchange
    debugPrint('⚠️ Devise $deviseOp non supportee par le shop ${shop.designation}');
    return shop;
  }

  // Créer une ou plusieurs entrées dans le journal de caisse
  Future<void> _createJournalEntry(OperationModel operation) async {
    String libelle = '';
    TypeMouvement type = TypeMouvement.entree;
    double montant = operation.montantNet;
    
    switch (operation.type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Pour les transferts sortants: ENTRÉE du montant TOTAL (brut = à servir + commission)
        libelle = 'Transfert ${operation.typeLabel} - ${operation.destinataire} (Total reçu)';
        montant = operation.montantBrut; // TOTAL = montant à servir + commission
        type = TypeMouvement.entree; // ENTRÉE en caisse
        break;
        
      case OperationType.transfertInternationalEntrant:
        libelle = 'Réception ${operation.typeLabel} - ${operation.destinataire}';
        montant = operation.montantNet;
        type = TypeMouvement.entree;
        break;
        
      case OperationType.depot:
        libelle = 'Dépôt - ${operation.destinataire ?? "Client"}';
        montant = operation.montantNet;
        type = TypeMouvement.entree; // ENTRÉE en caisse
        break;
        
      case OperationType.retrait:
        libelle = 'Retrait - ${operation.destinataire ?? "Client"}';
        montant = operation.montantNet;
        type = TypeMouvement.sortie; // SORTIE de caisse
        break;
        
      case OperationType.virement:
        libelle = 'Virement - ${operation.destinataire}';
        montant = operation.montantNet;
        type = TypeMouvement.entree; // Neutre pour le shop
        break;
        
      default:
        libelle = 'Opération - ${operation.typeLabel}';
        montant = operation.montantNet;
        type = TypeMouvement.entree;
    }
    
    // Créer l'entrée journal
    final journalEntry = JournalCaisseModel(
      shopId: operation.shopSourceId ?? 0,
      agentId: operation.agentId,
      libelle: libelle,
      montant: montant,
      type: type,
      mode: operation.modePaiement,
      dateAction: operation.dateOp,
      operationId: operation.id,
      notes: operation.commission > 0 
          ? 'Dont commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}'
          : null,
      lastModifiedAt: DateTime.now(),
      lastModifiedBy: 'agent_${operation.agentId}',
    );
    
    await LocalDB.instance.saveJournalEntry(journalEntry);
    debugPrint('📝 Journal caisse: ${type.name.toUpperCase()} de $montant ${operation.devise} - $libelle');
  }

  // Obtenir les statistiques du jour AVEC DONNEES LOCALES REELLES
  Map<String, dynamic> getDailyStats(int agentId) {
    final today = DateTime.now();
    final todayOperations = _operations.where((op) => 
      op.agentId == agentId &&
      op.dateOp.year == today.year &&
      op.dateOp.month == today.month &&
      op.dateOp.day == today.day
    ).toList();
    
    final transferts = todayOperations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).length;
    
    final depots = todayOperations.where((op) => op.type == OperationType.depot).length;
    final retraits = todayOperations.where((op) => op.type == OperationType.retrait).length;
    final virements = todayOperations.where((op) => op.type == OperationType.virement).length;
    
    // CALCUL REEL: Commissions par devise
    final commissionsUSD = todayOperations
        .where((op) => op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final commissionsCDF = todayOperations
        .where((op) => op.devise == 'CDF')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final commissionsUGX = todayOperations
        .where((op) => op.devise == 'UGX')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    
    // CALCUL REEL: Montants totaux par devise
    final montantTotalUSD = todayOperations
        .where((op) => op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final montantTotalCDF = todayOperations
        .where((op) => op.devise == 'CDF')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final montantTotalUGX = todayOperations
        .where((op) => op.devise == 'UGX')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    
    return {
      'transferts': transferts,
      'depots': depots,
      'retraits': retraits,
      'virements': virements,
      'totalOperations': todayOperations.length,
      // Commissions par devise
      'commissionsUSD': commissionsUSD,
      'commissionsCDF': commissionsCDF,
      'commissionsUGX': commissionsUGX,
      'commissionsEncaissees': commissionsUSD, // Pour compatibilite (USD par defaut)
      // Montants par devise
      'montantTotalUSD': montantTotalUSD,
      'montantTotalCDF': montantTotalCDF,
      'montantTotalUGX': montantTotalUGX,
      // Operations par statut
      'enAttente': todayOperations.where((op) => op.statut == OperationStatus.enAttente).length,
      'validees': todayOperations.where((op) => op.statut == OperationStatus.validee).length,
      'annulees': todayOperations.where((op) => op.statut == OperationStatus.annulee).length,
    };
  }

  // Filtrer les opérations
  List<OperationModel> filterOperations({
    OperationStatus? statut,
    OperationType? type,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) {
    var filtered = List<OperationModel>.from(_operations);
    
    if (statut != null) {
      filtered = filtered.where((op) => op.statut == statut).toList();
    }
    
    if (type != null) {
      filtered = filtered.where((op) => op.type == type).toList();
    }
    
    if (dateDebut != null) {
      filtered = filtered.where((op) => op.dateOp.isAfter(dateDebut)).toList();
    }
    
    if (dateFin != null) {
      filtered = filtered.where((op) => op.dateOp.isBefore(dateFin)).toList();
    }
    
    return filtered;
  }

  // Mettre à jour une opération
  Future<bool> updateOperation(OperationModel operation) async {
    try {
      // Récupérer l'ancienne opération pour comparer les statuts (si elle existe)
      final oldOperation = _operations.where((op) => op.id == operation.id).firstOrNull;
      
      await LocalDB.instance.updateOperation(operation);
      
      // Si c'est un transfert qui passe de "enAttente" à "validee", gérer les soldes ET le journal
      // IMPORTANT: Seulement si l'opération existait déjà localement en EN_ATTENTE
      if (oldOperation != null &&
          oldOperation.statut == OperationStatus.enAttente && 
          operation.statut == OperationStatus.validee &&
          (operation.type == OperationType.transfertNational ||
           operation.type == OperationType.transfertInternationalSortant ||
           operation.type == OperationType.transfertInternationalEntrant)) {
        
        debugPrint('🔄 Validation du transfert ${operation.id} - Mise à jour des soldes et journal...');
        await _handleTransfertBalances(operation);
      } else if (oldOperation == null && operation.statut == OperationStatus.validee) {
        // Cas: Opération reçue du serveur déjà VALIDEE (Shop source découvre que Shop destination a servi)
        debugPrint('📥 Transfert ${operation.id} reçu du serveur avec statut VALIDEE (déjà servi)');
        debugPrint('   ✅ Pas de mise à jour des soldes (déjà effectuée par Shop destination)');
      }
      
      // Recharger les opérations
      await loadOperations();
      
      debugPrint('✅ Opération ${operation.id} mise à jour avec succès');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Charger les opérations d'un client spécifique
  Future<void> loadClientOperations(int clientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allOperations = await LocalDB.instance.getAllOperations();
      _operations = allOperations.where((op) => op.clientId == clientId).toList();
      
      // Trier par date décroissante
      _operations.sort((a, b) => b.dateOp.compareTo(a.dateOp));
      
      debugPrint('✅ ${_operations.length} opérations chargées pour le client $clientId');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des opérations: $e';
      debugPrint(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Obtenir une opération par ID
  OperationModel? getOperationById(int id) {
    try {
      return _operations.firstWhere((op) => op.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Valider un transfert depuis le serveur (Shop Destination UNIQUEMENT)
  /// Permet de marquer un transfert comme SERVIE et mettre à jour les soldes
  /// SÉCURITÉ: Vérifie que le shop connecté est bien le DESTINATAIRE
  Future<bool> validerTransfertServeur(int operationId, ModePaiement modePaiement, {int? currentShopId}) async {
    try {
      final operation = _operations.where((op) => op.id == operationId).firstOrNull;
      
      if (operation == null) {
        _errorMessage = 'Opération non trouvée';
        debugPrint(_errorMessage);
        return false;
      }
      
      // Vérifier que c'est un transfert
      if (operation.type != OperationType.transfertNational &&
          operation.type != OperationType.transfertInternationalSortant &&
          operation.type != OperationType.transfertInternationalEntrant) {
        _errorMessage = 'Cette opération n\'est pas un transfert';
        debugPrint(_errorMessage);
        return false;
      }
      
      // ❗ SÉCURITÉ CRITIQUE: Vérifier que le shop connecté est le DESTINATAIRE
      if (currentShopId != null && operation.shopDestinationId != currentShopId) {
        _errorMessage = '❌ ERREUR DE SÉCURITÉ: Ce transfert n\'est pas destiné à votre shop!';
        debugPrint('❌ TENTATIVE DE VALIDATION INTERDITE:');
        debugPrint('   Shop connecté: $currentShopId');
        debugPrint('   Shop destination du transfert: ${operation.shopDestinationId}');
        debugPrint('   Shop source du transfert: ${operation.shopSourceId}');
        debugPrint('   ⚠️ Seul le shop DESTINATION peut valider un transfert!');
        return false;
      }
      
      // Vérifier le statut
      if (operation.statut != OperationStatus.enAttente) {
        _errorMessage = 'Le transfert n\'est pas en attente (Statut actuel: ${operation.statut.name})';
        debugPrint(_errorMessage);
        return false;
      }
      
      // Mettre à jour le statut et le mode de paiement
      final updatedOperation = operation.copyWith(
        statut: OperationStatus.validee,
        modePaiement: modePaiement,
        lastModifiedAt: DateTime.now(),
        isSynced: false,  // IMPORTANT: Marquer comme non synchronisé pour forcer l'upload
      );
      
      await LocalDB.instance.updateOperation(updatedOperation);
      
      // Gérer les soldes et créer l'entrée journal (SORTIE)
      await _handleTransfertBalances(updatedOperation);
      
      // Recharger les opérations
      await loadOperations();
      
      // SYNCHRONISATION IMMEDIATE: Upload le changement de statut vers le serveur
      debugPrint('🔄 Synchronisation immédiate du transfert validé...');
      try {
        final syncService = SyncService();
        await syncService.syncAll(); // Sync complète pour garantir la propagation
        debugPrint('✅ Transfert ${operationId} synchronisé avec le serveur');
      } catch (e) {
        debugPrint('⚠️ Erreur de synchronisation (transfert validé localement): $e');
        // L'opération est validée localement, la sync se fera plus tard
      }
      
      debugPrint('✅ Transfert ${operationId} validé et servi avec succès');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la validation: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Récupérer les transferts SERVIS concernant ce shop (Shop Source)
  /// Retourne les transferts que ce shop a envoyés et qui ont été servis par le shop destination
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la SOURCE
  List<OperationModel> getTransfertsServis({int? shopId}) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // Vérifier que c'est SERVIE (validée)
      final isServie = op.statut == OperationStatus.validee;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la SOURCE (a envoyé le transfert)
      final isSource = shopId == null || op.shopSourceId == shopId;
      
      return isTransfert && isServie && isSource;
    }).toList();
  }
  
  /// Récupérer les transferts EN ATTENTE à servir (Shop Destination)
  /// Retourne les transferts que ce shop doit servir
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la DESTINATION
  List<OperationModel> getTransfertsAServir(int shopDestinationId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // Vérifier que c'est EN ATTENTE
      final isEnAttente = op.statut == OperationStatus.enAttente;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la DESTINATION (doit servir)
      final isDestination = op.shopDestinationId == shopDestinationId;
      
      return isTransfert && isEnAttente && isDestination;
    }).toList();
  }
  
  /// Récupérer les transferts ENVOYÉS par ce shop (Shop Source)
  /// Retourne TOUS les transferts créés par ce shop (EN_ATTENTE + SERVIS)
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la SOURCE
  List<OperationModel> getTransfertsEnvoyes(int shopSourceId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la SOURCE
      final isSource = op.shopSourceId == shopSourceId;
      
      return isTransfert && isSource;
    }).toList();
  }
  
  /// Récupérer les transferts REÇUS par ce shop (Shop Destination)
  /// Retourne TOUS les transferts destinés à ce shop (EN_ATTENTE + SERVIS)
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la DESTINATION
  List<OperationModel> getTransfertsRecus(int shopDestinationId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la DESTINATION
      final isDestination = op.shopDestinationId == shopDestinationId;
      
      return isTransfert && isDestination;
    }).toList();
  }
  
  /// Vérifier si un agent/shop peut valider un transfert
  /// Retourne true UNIQUEMENT si le shop est le DESTINATAIRE
  bool peutValiderTransfert(int operationId, int currentShopId) {
    final operation = _operations.where((op) => op.id == operationId).firstOrNull;
    
    if (operation == null) return false;
    
    // Vérifier que c'est un transfert
    final isTransfert = operation.type == OperationType.transfertNational ||
                        operation.type == OperationType.transfertInternationalSortant ||
                        operation.type == OperationType.transfertInternationalEntrant;
    
    if (!isTransfert) return false;
    
    // Vérifier que le statut est EN_ATTENTE
    if (operation.statut != OperationStatus.enAttente) return false;
    
    // ❗ SÉCURITÉ CRITIQUE: Vérifier que le shop est le DESTINATAIRE
    return operation.shopDestinationId == currentShopId;
  }
}
