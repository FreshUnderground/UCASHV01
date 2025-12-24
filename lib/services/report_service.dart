import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/triangular_debt_settlement_model.dart';
import 'local_db.dart';
import 'agent_service.dart';

class ReportService extends ChangeNotifier {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Types de rapports disponibles selon le rôle
  static const mouvementsCaisse = 'mouvementsCaisse';
  static const creditsInterShops = 'creditsInterShops';
  static const commissionsEncaissees = 'commissionsEncaissees';
  static const evolutionCapital = 'evolutionCapital';
  static const releveCompteClient = 'releveCompteClient';

  // Données des rapports
  List<OperationModel> _operations = [];
  List<ShopModel> _shops = [];
  Map<String, dynamic> _reportData = {};

  // Getters pour les données
  List<OperationModel> get operations => _operations;
  List<ShopModel> get shops => _shops;
  Map<String, dynamic> get reportData => _reportData;

  // Charger les données de base pour les rapports
  Future<void> loadReportData({
    int? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Charger toutes les opérations
      final allOperations = await LocalDB.instance.getAllOperations();
      
      // Filtrer par shop si spécifié
      // IMPORTANT: Pour les rapports inter-shops, inclure les opérations où ce shop est SOURCE OU DESTINATION
      if (shopId != null) {
        _operations = allOperations.where((op) => 
          op.shopSourceId == shopId || op.shopDestinationId == shopId
        ).toList();
      } else {
        _operations = allOperations;
      }

      // Filtrer par période si spécifiée
      // IMPORTANT: Utiliser comparaison par date seulement (sans heure) pour inclure toute la journée
      if (startDate != null && endDate != null) {
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        
        _operations = _operations.where((op) {
          final opDateOnly = DateTime(op.dateOp.year, op.dateOp.month, op.dateOp.day, op.dateOp.hour, op.dateOp.minute, op.dateOp.second);
          return !opDateOnly.isBefore(startDateOnly) && !opDateOnly.isAfter(endDateOnly);
        }).toList();
      }

      // Charger les shops
      _shops = await LocalDB.instance.getAllShops();

      debugPrint('✅ Données de rapport chargées: ${_operations.length} opérations, ${_shops.length} shops');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des données: $e';
      debugPrint(_errorMessage);
    }

    _setLoading(false);
  }

  // Générer le rapport des mouvements de caisse
  Future<Map<String, dynamic>> generateMouvementsCaisseReport({
    required int shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(shopId: shopId, startDate: startDate, endDate: endDate);

    final shop = _shops.firstWhere(
      (s) => s.id == shopId,
      orElse: () => throw Exception('Shop avec ID $shopId non trouvé'),
    );
    
    // IMPORTANT: Inclure les opérations où ce shop est SOURCE OU DESTINATION
    // - SOURCE: dépôts, retraits, transferts créés par ce shop
    // - DESTINATION: transferts reçus et servis par ce shop
    final shopOperations = _operations.where((op) => 
      op.shopSourceId == shopId || op.shopDestinationId == shopId
    ).toList();

    // Récupérer les FLOT pour ce shop
    final flots = await LocalDB.instance.getFlotsByShop(shopId);

    // Calculer les totaux par type d'opération
    double totalEntrees = 0;
    double totalSorties = 0;
    Map<String, double> totauxParMode = {
      'Cash': 0,
      'AirtelMoney': 0,
      'MPesa': 0,
      'OrangeMoney': 0,
    };

    final mouvements = <Map<String, dynamic>>[];

    // Get the agent service instance to retrieve agent names
    final agentService = AgentService.instance;
    
    // Ajouter les opérations normales
    for (final operation in shopOperations) {
      // Pour les transferts DESTINATION, ne compter que si validé ou terminé
      // Car le shop destination ne sert le montant QUE après validation
      if (operation.shopDestinationId == shopId && 
          operation.shopSourceId != shopId &&
          operation.statut == OperationStatus.enAttente) {
        continue; // Ignorer les transferts en attente côté destination
      }
      
      final isEntree = _isEntreeOperation(operation, shopId);
      
      // CALCUL CORRECT DU MONTANT SELON LE TYPE:
      // - TRANSFERT SOURCE (création): MONTANT TOTAL = brut (montant à servir + commission)
      // - TRANSFERT DESTINATION (validation): MONTANT NET (montant servi)
      // - DEPOT/RETRAIT: MONTANT NET
      double montant;
      if (operation.shopSourceId == shopId && 
          (operation.type == OperationType.transfertNational ||
           operation.type == OperationType.transfertInternationalSortant)) {
        // Shop SOURCE de transfert = ENTREE du TOTAL (client paie brut + commission)
        montant = operation.montantBrut; // Total reçu du client
      } else {
        // Autres cas: montant net
        montant = operation.montantNet;
      }

      if (isEntree) {
        totalEntrees += montant;
      } else {
        totalSorties += montant;
      }

      // Ajouter au total par mode de paiement
      final mode = operation.modePaiement.name;
      totauxParMode[mode] = (totauxParMode[mode] ?? 0) + montant;

      // Get agent name from AgentService
      final agent = agentService.getAgentById(operation.agentId);
      final agentName = agent?.nom ?? agent?.username ?? operation.lastModifiedBy ?? 'Agent inconnu';
      
      // Pour les transferts DESTINATION, ajouter le shop source dans destinataire
      String destinataireAffiche = operation.destinataire ?? 'N/A';
      if (operation.shopDestinationId == shopId && operation.shopSourceId != shopId) {
        final shopSource = _shops.firstWhere(
          (s) => s.id == operation.shopSourceId,
          orElse: () => ShopModel(
            designation: 'Shop ${operation.shopSourceId}',
            localisation: 'Inconnu',
            capitalCash: 0,
            capitalAirtelMoney: 0,
            capitalMPesa: 0,
            capitalOrangeMoney: 0,
          ),
        );
        destinataireAffiche = '${operation.destinataire ?? "Bénéficiaire"} (via ${shopSource.designation})';
      }

      mouvements.add({
        'date': operation.dateOp,
        'type': operation.type.name,
        'typeDirection': isEntree ? 'entree' : 'sortie', // Ajout de la direction
        'agent': agentName,
        'montantBrut': operation.montantBrut,  // AJOUT: Montant brut
        'montantNet': operation.montantNet,    // AJOUT: Montant net (servi)
        'commission': operation.commission,     // AJOUT: Commission
        'montant': montant,                    // Montant utilisé pour le calcul total
        'devise': 'USD', // Pour l'instant, tout en USD
        'mode': mode,
        'soldeAvant': 0.0, // À calculer selon l'historique
        'soldeApres': 0.0, // À calculer selon l'historique
        'statut': operation.statut.name,
        'destinataire': destinataireAffiche,  // Utiliser le destinataire enrichi
      });
    }

    // Ajouter les FLOTs au rapport (NOUVEAU: depuis operations avec type=flotShopToShop)
    // Les FLOTs sont maintenant dans la table operations
    final flotsOperations = operations.where((op) => op.type == OperationType.flotShopToShop).toList();
    
    for (final flot in flotsOperations) {
      final isEntree = flot.shopDestinationId == shopId;
      final isSortie = flot.shopSourceId == shopId;
      
      if ((isEntree || isSortie) && flot.devise == 'USD') {
        // Utiliser dateValidation pour les flots reçus et dateOp pour les flots envoyés
        final dateAction = isEntree 
            ? (flot.dateValidation ?? flot.dateOp)  // Pour les flots reçus, préférer dateValidation
            : (flot.createdAt ?? flot.dateOp);      // Pour les flots envoyés, préférer createdAt
            
        // Vérifier si la date est dans la période demandée
        if ((startDate == null || dateAction.isAfter(startDate.subtract(const Duration(days: 1)))) &&
            (endDate == null || dateAction.isBefore(endDate.add(const Duration(days: 1))))) {
          
          final montant = flot.montantNet;
          final mode = flot.modePaiement.name;
          
          // Mettre à jour les totaux
          if (isEntree) {
            totalEntrees += montant;
          } else if (isSortie) {
            totalSorties += montant;
          }
          
          // Mettre à jour les totaux par mode de paiement
          totauxParMode[mode] = (totauxParMode[mode] ?? 0) + montant;
          
          // Récupérer le nom de l'agent
          final agent = flot.agentId != null 
              ? agentService.getAgentById(flot.agentId!) 
              : null;
          final agentName = agent?.nom ?? agent?.username ?? flot.lastModifiedBy ?? 'Agent inconnu';
          
          // Trouver les noms des shops
          final shopSource = _shops.firstWhere(
            (s) => s.id == flot.shopSourceId,
            orElse: () => ShopModel(designation: 'Shop ${flot.shopSourceId}', localisation: ''),
          );
          final shopDestination = flot.shopDestinationId != null
              ? _shops.firstWhere(
                  (s) => s.id == flot.shopDestinationId,
                  orElse: () => ShopModel(designation: 'Shop ${flot.shopDestinationId}', localisation: ''),
                )
              : null;
          
          mouvements.add({
            'date': dateAction,
            'type': 'FLOT',
            'typeDirection': isEntree ? 'entree' : 'sortie',
            'agent': agentName,
            'montantBrut': montant,
            'montantNet': montant,
            'commission': 0.0,
            'montant': montant,
            'devise': flot.devise,
            'mode': mode,
            'soldeAvant': 0.0,
            'soldeApres': 0.0,
            'statut': flot.statut.name,
            'destinataire': isEntree 
                ? 'Reçu de ${shopSource.designation}'
                : 'Envoyé vers ${shopDestination?.designation ?? "Inconnu"}',
          });
        }
      }
    }

    // Trier les mouvements par date décroissante
    mouvements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return {
      'shop': shop.toJson(),
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'mouvements': mouvements,
      'totaux': {
        'entrees': totalEntrees,
        'sorties': totalSorties,
        'solde': totalEntrees - totalSorties,
        'parMode': totauxParMode,
      },
      'statistiques': {
        'nombreOperations': shopOperations.length + flotsOperations.length,
        'moyenneParOperation': (shopOperations.length + flotsOperations.length) > 0 
            ? (totalEntrees + totalSorties) / (shopOperations.length + flotsOperations.length) 
            : 0,
      },
    };
  }

  // Générer le journal des crédits inter-shops
  Future<Map<String, dynamic>> generateCreditsInterShopsReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(startDate: startDate, endDate: endDate);

    final transferts = _operations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).toList();

    Map<String, Map<String, double>> creditsMatrix = {};
    
    // Initialiser la matrice des crédits
    for (final shop in _shops) {
      creditsMatrix[shop.designation] = {};
      for (final otherShop in _shops) {
        if (shop.id != otherShop.id) {
          creditsMatrix[shop.designation]![otherShop.designation] = 0.0;
        }
      }
    }

    // Calculer les dettes et créances avec compensation automatique
    for (final transfert in transferts) {
      if (transfert.shopDestinationId != null) {
        final shopSource = _shops.firstWhere(
          (s) => s.id == transfert.shopSourceId,
          orElse: () => ShopModel(id: transfert.shopSourceId ?? 0, designation: 'Shop ${transfert.shopSourceId}', localisation: ''),
        );
        final shopDestination = _shops.firstWhere(
          (s) => s.id == transfert.shopDestinationId,
          orElse: () => ShopModel(id: transfert.shopDestinationId ?? 0, designation: 'Shop ${transfert.shopDestinationId}', localisation: ''),
        );
        
        // LOGIQUE CORRECTE UCASH : Shop émetteur (SOURCE) qui reçoit le cash DOIT au shop récepteur (DESTINATION) qui servira
        // Le shop source DOIT le MONTANT BRUT (total payé par le client incluant commission)
        final montantBrut = transfert.montantBrut;
        
        // Ajouter la dette (shop source DOIT le montant BRUT au shop destination)
        creditsMatrix[shopSource.designation]![shopDestination.designation] = 
          (creditsMatrix[shopSource.designation]![shopDestination.designation] ?? 0) + montantBrut;
        
        // Vérifier et appliquer compensation automatique
        final detteInverse = creditsMatrix[shopDestination.designation]![shopSource.designation] ?? 0;
        if (detteInverse > 0) {
          final compensation = montantBrut < detteInverse ? montantBrut : detteInverse;
          
          // Réduire les dettes mutuelles
          creditsMatrix[shopSource.designation]![shopDestination.designation] = 
            (creditsMatrix[shopSource.designation]![shopDestination.designation]! - compensation);
          creditsMatrix[shopDestination.designation]![shopSource.designation] = 
            (creditsMatrix[shopDestination.designation]![shopSource.designation]! - compensation);
        }
      }
    }

    // Calculer les soldes nets
    Map<String, double> soldesNets = {};
    for (final shop in _shops) {
      double dettes = 0;
      double creances = 0;
      
      // Calculer les dettes (ce que ce shop doit aux autres)
      creditsMatrix[shop.designation]?.forEach((autreShop, montant) {
        dettes += montant;
      });
      
      // Calculer les créances (ce que les autres doivent à ce shop)
      for (final entry in creditsMatrix.entries) {
        if (entry.key != shop.designation) {
          creances += entry.value[shop.designation] ?? 0;
        }
      }
      
      soldesNets[shop.designation] = creances - dettes;
    }

    return {
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'matrixCredits': creditsMatrix,
      'soldesNets': soldesNets,
      'transferts': transferts.map((t) => {
        'date': t.dateOp,
        'shopSource': _shops.firstWhere(
          (s) => s.id == t.shopSourceId,
          orElse: () => ShopModel(id: t.shopSourceId ?? 0, designation: 'Shop ${t.shopSourceId}', localisation: ''),
        ).designation,
        'shopDestination': t.shopDestinationId != null 
          ? _shops.firstWhere(
              (s) => s.id == t.shopDestinationId,
              orElse: () => ShopModel(id: t.shopDestinationId ?? 0, designation: 'Shop ${t.shopDestinationId}', localisation: ''),
            ).designation 
          : 'Externe',
        'montant': t.montantNet,
        'type': t.type.name,
      }).toList(),
    };
  }

  // Générer le rapport des commissions encaissées
  Future<Map<String, dynamic>> generateCommissionsReport({
    int? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(shopId: shopId, startDate: startDate, endDate: endDate);

    // Filtrer les opérations avec commission selon la logique métier UCASH
    // Note : Les commissions sont encaissées dès la création du transfert,
    // même si la validation n'a pas encore eu lieu (validation ≠ finalisation)
    final operationsAvecCommission = _operations.where((op) => 
      op.commission > 0 && 
      (op.type == OperationType.transfertNational ||
       op.type == OperationType.transfertInternationalSortant)
    ).toList();

    Map<String, double> commissionsParType = {
      'transfertNational': 0,
      'transfertInternationalSortant': 0,
      'transfertInternationalEntrant': 0,
    };

    Map<int, double> commissionsParShop = {};
    Map<String, double> commissionsParAgent = {};

    double totalCommissions = 0;
    
    // Get the agent service instance to retrieve agent names
    final agentService = AgentService.instance;

    for (final operation in operationsAvecCommission) {
      final commission = operation.commission;
      totalCommissions += commission;

      // Par type
      final type = operation.type.name;
      if (commissionsParType.containsKey(type)) {
        commissionsParType[type] = commissionsParType[type]! + commission;
      }

      // Par shop - IMPORTANT: La commission appartient au SHOP DESTINATION
      // Car c'est le shop destination qui garde la commission et sert le montantNet
      if (operation.shopDestinationId != null) {
        commissionsParShop[operation.shopDestinationId!] = 
          (commissionsParShop[operation.shopDestinationId!] ?? 0) + commission;
      } else {
        // Fallback: si pas de shop destination (cas très rare), compter pour le shop source
        commissionsParShop[operation.shopSourceId!] = 
          (commissionsParShop[operation.shopSourceId!] ?? 0) + commission;
      }

      // Par agent - L'agent qui a créé l'opération (shop source)
      final agent = agentService.getAgentById(operation.agentId);
      final agentName = agent?.nom ?? agent?.username ?? operation.lastModifiedBy ?? 'Agent inconnu';
      commissionsParAgent[agentName] = 
        (commissionsParAgent[agentName] ?? 0) + commission;
    }

    return {
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'totalCommissions': totalCommissions,
      'commissionsParType': commissionsParType,
      'commissionsParShop': commissionsParShop.map((shopId, montant) => MapEntry(
        _shops.firstWhere(
          (s) => s.id == shopId,
          orElse: () => ShopModel(id: shopId, designation: 'Shop $shopId', localisation: ''),
        ).designation,
        montant,
      )),
      'commissionsParAgent': commissionsParAgent,
      'operations': operationsAvecCommission.map((op) => {
        'date': op.dateOp,
        'type': op.type.name,
        'montant': op.montantNet,
        'commission': op.commission,
        'shop': _shops.firstWhere(
          (s) => s.id == op.shopSourceId,
          orElse: () => ShopModel(id: op.shopSourceId ?? 0, designation: 'Shop ${op.shopSourceId}', localisation: ''),
        ).designation,
        'agent': agentService.getAgentById(op.agentId)?.nom ?? agentService.getAgentById(op.agentId)?.username ?? op.lastModifiedBy ?? 'Inconnu',
      }).toList(),
    };
  }

  // Générer le rapport d'évolution du capital
  Future<Map<String, dynamic>> generateEvolutionCapitalReport({
    required int shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(shopId: shopId, startDate: startDate, endDate: endDate);

    final shop = _shops.firstWhere(
      (s) => s.id == shopId,
      orElse: () => throw Exception('Shop avec ID $shopId non trouvé'),
    );
    
    // Calculer le capital selon la logique métier UCASH :
    // Capital de base = Cash + E-Money (saisis à la création)
    double capitalBase = shop.capitalCash + shop.capitalAirtelMoney + 
                        shop.capitalMPesa + shop.capitalOrangeMoney;

    // Calculer l'impact des dépôts, retraits ET TRANSFERTS sur le capital
    double impactDepots = 0;
    double impactRetraits = 0;
    double impactTransfertsSortants = 0;  // Transferts ENVOYÉS (ce shop a REÇU le cash)
    double impactTransfertsEntrants = 0;  // Transferts REÇUS (ce shop a SERVI le cash)
    double impactFlotsRecus = 0;          // FLOT reçus (ENTRÉE)
    double impactFlotsServis = 0;         // FLOT servis (SORTIE)

    // Filtrer les opérations de dépôt et retrait pour ce shop
    // NOTE: Le dépôt initial (CAPITAL INITIAL) est EXCLU du calcul d'impact
    // car il est déjà comptabilisé dans le capital de base (capitalCash)
    // Sinon, on compterait deux fois le même montant!
    // MAIS il reste VISIBLE dans les listes d'opérations et le journal de caisse.
    final depots = _operations.where((op) => 
      op.shopSourceId == shopId && 
      op.type == OperationType.depot &&
      (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee) &&
      op.destinataire != 'CAPITAL INITIAL' // Exclu du calcul uniquement (déjà dans capitalCash)
    ).toList();

    final retraits = _operations.where((op) => 
      op.shopSourceId == shopId && 
      (op.type == OperationType.retrait || op.type == OperationType.retraitMobileMoney) &&
      (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee)
    ).toList();

    // Calculer l'impact total
    for (final depot in depots) {
      impactDepots += depot.montantNet;
    }

    for (final retrait in retraits) {
      impactRetraits += retrait.montantNet;
    }

    // Calculer les créances et dettes selon la logique métier UCASH
    double creances = 0;
    double dettes = 0;

    // LOGIQUE CORRECTE : Shop SOURCE (qui reçoit le cash du client) DOIT au shop DESTINATION (qui servira le bénéficiaire)
    // Transferts sortants : ce shop (SOURCE) doit de l'argent aux shops de destination
    final transfertsSortants = _operations.where((op) => 
      op.shopSourceId == shopId && 
      op.shopDestinationId != null &&
      (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee) && // Validés ou terminés
      (op.type == OperationType.transfertNational ||
       op.type == OperationType.transfertInternationalSortant)
    ).toList();

    // Transferts entrants : les autres shops (SOURCE) Nous qui Doivent de l'argent (car nous sommes DESTINATION)
    final transfertsEntrants = _operations.where((op) => 
      op.shopDestinationId == shopId && 
      (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee) && // Validés ou terminés
      (op.type == OperationType.transfertNational ||
       op.type == OperationType.transfertInternationalEntrant)
    ).toList();
    
    // Récupérer les FLOT pour ce shop
    final flots = await LocalDB.instance.getFlotsByShop(shopId);
    
    // FLOT reçus (ce shop est DESTINATION): ENTRÉE de cash
    final flotsRecus = flots.where((f) => 
      f.statut == flot_model.StatutFlot.servi && f.shopDestinationId == shopId
    ).toList();
    
    // FLOT servis (ce shop est SOURCE): SORTIE de cash
    final flotsServis = flots.where((f) => 
      f.statut == flot_model.StatutFlot.enRoute && f.shopSourceId == shopId
    ).toList();
    
    // FLOT EN COURS pour calcul des dettes (enRoute + servi)
    // IMPORTANT: FLOT EN COURS sont considérés comme PAIEMENT IMMÉDIAT
    final flotsPourDettes = flots.where((f) => 
      (f.statut == flot_model.StatutFlot.enRoute || f.statut == flot_model.StatutFlot.servi)
    ).toList();
    
    // Calculer l'impact des FLOT
    for (final flot in flotsRecus) {
      impactFlotsRecus += flot.montant;
    }
    
    for (final flot in flotsServis) {
      impactFlotsServis += flot.montant;
    }
    
    // IMPORTANT: Calculer l'impact des TRANSFERTS sur la caisse
    // Transferts SORTANTS (ce shop est SOURCE): ENTRÉE de cash (client paie montantBrut)
    for (final transfert in transfertsSortants) {
      impactTransfertsSortants += transfert.montantBrut; // Total reçu du client (net + commission)
    }
    
    // Transferts ENTRANTS (ce shop est DESTINATION): SORTIE de cash (shop sert montantNet)
    for (final transfert in transfertsEntrants) {
      impactTransfertsEntrants += transfert.montantNet; // Montant servi au bénéficiaire
    }

    // Capital total = Capital de base + Dépôts - Retraits + Transferts Reçus - Transferts Servis + FLOT Reçus - FLOT Servis
    final capitalTotal = capitalBase + impactDepots - impactRetraits + 
                        impactTransfertsSortants - impactTransfertsEntrants + 
                        impactFlotsRecus - impactFlotsServis;
    
    // Debug logs pour vérifier les calculs
    debugPrint('📊 Shop ${shop.designation}:');
    debugPrint('   Capital de base: ${capitalBase.toStringAsFixed(2)} USD (inclut cash initial)');
    debugPrint('   Dépôts clients: ${impactDepots.toStringAsFixed(2)} USD (${depots.length} opérations - EXCLUT dépôt initial)');
    debugPrint('   Retraits clients: ${impactRetraits.toStringAsFixed(2)} USD (${retraits.length} opérations)');
    debugPrint('   Transferts sortants (reçus): ${impactTransfertsSortants.toStringAsFixed(2)} USD (${transfertsSortants.length} opérations)');
    debugPrint('   Transferts entrants (servis): ${impactTransfertsEntrants.toStringAsFixed(2)} USD (${transfertsEntrants.length} opérations)');
    debugPrint('   FLOT reçus: ${impactFlotsRecus.toStringAsFixed(2)} USD (${flotsRecus.length} opérations)');
    debugPrint('   FLOT servis: ${impactFlotsServis.toStringAsFixed(2)} USD (${flotsServis.length} opérations)');
    debugPrint('   Capital total: ${capitalTotal.toStringAsFixed(2)} USD');

    /// Calculer les dettes nettes avec compensation automatique
    Map<int, double> dettesParShop = {};
    Map<int, double> creancesParShop = {};

    // Calculer les dettes (ce que ce shop doit)
    // IMPORTANT: Le shop source doit le MONTANT BRUT (total payé par le client)
    for (final transfert in transfertsSortants) {
      final destinationId = transfert.shopDestinationId!;
      dettesParShop[destinationId] = (dettesParShop[destinationId] ?? 0) + transfert.montantBrut; // MONTANT BRUT incluant commission
    }
    
    // Calculer les créances (ce qui est dû à ce shop)
    // Le shop destination doit recevoir le MONTANT BRUT
    for (final transfert in transfertsEntrants) {
      final sourceId = transfert.shopSourceId!;
      creancesParShop[sourceId] = (creancesParShop[sourceId] ?? 0) + transfert.montantBrut; // MONTANT BRUT incluant commission
    }
    
    // FLOATS: LOGIQUE CORRECTE - Quand Shop A envoie FLOT vers Shop B, Shop B DOIT à Shop A
    for (final flot in flotsPourDettes) {
      if (flot.shopSourceId == shopId) {
        // FLOT envoyé par nous vers un autre shop
        // = NOUS avons donné de l'argent, donc L'AUTRE SHOP NOUS DOIT
        final destinationId = flot.shopDestinationId;
        creancesParShop[destinationId] = (creancesParShop[destinationId] ?? 0) + flot.montant;
      } else if (flot.shopDestinationId == shopId) {
        // FLOT reçu par nous depuis un autre shop
        // = L'AUTRE SHOP a donné de l'argent, donc Nous que Devons à L'AUTRE SHOP
        final sourceId = flot.shopSourceId;
        dettesParShop[sourceId] = (dettesParShop[sourceId] ?? 0) + flot.montant;
      }
    }
    
    // TRAITEMENT DES RÈGLEMENTS TRIANGULAIRES DE DETTES
    // Logique: Shop A doit à Shop C, Shop A paie Shop B pour le compte de Shop C
    // Impact: Dette de Shop A à Shop C diminue, Dette de Shop B à Shop C augmente
    
    // IMPORTANT: Filtrer les règlements selon la période du rapport
    final allTriangularSettlements = await LocalDB.instance.getAllTriangularDebtSettlements();
    final triangularSettlements = allTriangularSettlements.where((settlement) {
      // Si startDate est null, inclure tous les règlements jusqu'à endDate
      // Si endDate est null, inclure tous les règlements depuis startDate
      final afterStart = startDate == null || settlement.dateReglement.isAfter(startDate.subtract(const Duration(seconds: 1)));
      final beforeEnd = endDate == null || settlement.dateReglement.isBefore(endDate.add(const Duration(days: 1)));
      return afterStart && beforeEnd;
    }).toList();
    
    for (final settlement in triangularSettlements) {
      final debtorId = settlement.shopDebtorId;
      final intermediaryId = settlement.shopIntermediaryId;
      final creditorId = settlement.shopCreditorId;
      final amount = settlement.montant;
      
      // Appliquer les impacts seulement si le shop courant est impliqué
      if (shopId == creditorId) {
        // Pour le créancier (Shop C): 
        // - La dette de Shop A diminue (moins d'argent qu'on nous doit)
        // - La dette de Shop B augmente (plus d'argent qu'on nous doit)
        dettesParShop[debtorId] = (dettesParShop[debtorId] ?? 0) - amount; // Dette diminue
        dettesParShop[intermediaryId] = (dettesParShop[intermediaryId] ?? 0) + amount; // Dette augmente
      } else if (shopId == debtorId) {
        // Pour le débiteur (Shop A / KAMPALA):
        // - Notre dette envers le créancier (DURBA) diminue
        // - L'intermédiaire (DWEMBE) nous doit moins (a payé pour nous)
        // IMPACT NET = 0 (échange dette contre créance)
        dettesParShop[creditorId] = (dettesParShop[creditorId] ?? 0) - amount; // Notre dette envers DURBA diminue
        creancesParShop[intermediaryId] = (creancesParShop[intermediaryId] ?? 0) - amount; // DWEMBE nous doit moins
      } else if (shopId == intermediaryId) {
        // Pour l'intermédiaire (Shop B / DWEMBE):
        // - Notre dette envers KAMPALA (débiteur) diminue
        // - Notre dette envers DURBA (créancier) augmente
        dettesParShop[debtorId] = (dettesParShop[debtorId] ?? 0) - amount; // Notre dette envers le débiteur diminue
        dettesParShop[creditorId] = (dettesParShop[creditorId] ?? 0) + amount; // Notre dette envers le créancier augmente
      }
    }
    
    // Appliquer la compensation automatique selon la logique métier
    for (final otherShopId in {...dettesParShop.keys, ...creancesParShop.keys}) {
      final dette = dettesParShop[otherShopId] ?? 0;
      final creance = creancesParShop[otherShopId] ?? 0;
      
      if (dette > creance) {
        dettes += (dette - creance); // Dette nette après compensation
      } else if (creance > dette) {
        creances += (creance - dette); // Créance nette après compensation
      }
      // Si dette == créance, compensation totale = 0
    }

    // Appliquer la formule finale du capital selon la logique métier UCASH :
    // BUSINESS LOGIC: Capital Net = Capital Total + Créances - Dettes
    // This represents the true financial position of the shop:
    // - Starting capital position (capitalTotal)
    // - Add amounts owed to this shop by clients and other shops (creances)
    // - Subtract amounts this shop owes to clients and other shops (dettes)
    final capitalNet = capitalTotal + creances - dettes;

    return {
      'shop': shop.toJson(),
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'capital': {
        'base': capitalBase,
        'cash': shop.capitalCash,
        'airtelMoney': shop.capitalAirtelMoney,
        'mPesa': shop.capitalMPesa,
        'orangeMoney': shop.capitalOrangeMoney,
        'impactDepots': impactDepots,
        'impactRetraits': impactRetraits,
        'impactTransfertsSortants': impactTransfertsSortants,  // AJOUT: Transferts reçus (entrée)
        'impactTransfertsEntrants': impactTransfertsEntrants,  // AJOUT: Transferts servis (sortie)
        'impactFlotsRecus': impactFlotsRecus,                  // AJOUT: FLOT reçus (entrée)
        'impactFlotsServis': impactFlotsServis,                // AJOUT: FLOT servis (sortie)
        'total': capitalTotal,
      },
      'creancesEtDettes': {
        'creances': creances,
        'dettes': dettes,
        'net': creances - dettes,
      },
      'capitalNet': capitalNet,
      'evolution': [], // À implémenter avec l'historique
      // AJOUT: Liste complète des opérations (dépôts + retraits + transferts + FLOT)
      'operations': [
        // AJOUT: Dépôts
        ...depots.map((op) => {
          'dateOp': op.dateOp.toIso8601String(),
          'type': op.type.name,
          'destinataire': op.destinataire ?? 'N/A',
          'montantBrut': op.montantBrut,
          'commission': op.commission,
          'montantNet': op.montantNet,
          'modePaiement': op.modePaiement.name,
          'statut': op.statut.name,
          'observation': op.observation, // Add this line
        }),
        // AJOUT: Retraits
        ...retraits.map((op) => {
          'dateOp': op.dateOp.toIso8601String(),
          'type': op.type.name,
          'destinataire': op.destinataire ?? 'N/A',
          'montantBrut': op.montantBrut,
          'commission': op.commission,
          'montantNet': op.montantNet,
          'modePaiement': op.modePaiement.name,
          'statut': op.statut.name,
          'observation': op.observation, // Add this line
        }),
        // AJOUT: Transferts sortants (ce shop a envoyé)
        ...transfertsSortants.map((op) => {
          'dateOp': op.createdAt?.toIso8601String() ?? op.dateOp.toIso8601String(),
          'type': op.type.name,
          'destinataire': op.destinataire ?? 'Shop ${op.shopDestinationId}',
          'montantBrut': op.montantBrut,
          'commission': op.commission,
          'montantNet': op.montantNet,
          'modePaiement': op.modePaiement.name,
          'statut': op.statut.name,
          'observation': op.observation, // Add this line
        }),
        // AJOUT: Transferts entrants (ce shop a reçu)
        ...transfertsEntrants.map((op) => {
          'dateOp': op.dateValidation?.toIso8601String() ?? op.createdAt?.toIso8601String() ?? op.dateOp.toIso8601String(),
          'type': op.type.name,
          'destinataire': op.destinataire ?? 'Shop ${op.shopSourceId}',
          'montantBrut': op.montantBrut,
          'commission': op.commission,
          'montantNet': op.montantNet,
          'modePaiement': op.modePaiement.name,
          'statut': op.statut.name,
          'observation': op.observation, // Add this line
        }),
        // AJOUT: FLOT reçus
        ...flotsRecus.map((flot) => {
          'dateOp': flot.dateReception?.toIso8601String() ?? flot.createdAt?.toIso8601String() ?? flot.dateEnvoi.toIso8601String(),
          'type': 'FLOT_RECU',
          'destinataire': 'Reçu de ${flot.shopSourceDesignation}',
          'montantBrut': flot.montant,
          'commission': 0.0,
          'montantNet': flot.montant,
          'modePaiement': flot.modePaiement.name,
          'statut': flot.statut.name,
        }),
        // AJOUT: FLOT servis
        ...flotsServis.map((flot) => {
          'dateOp': flot.createdAt?.toIso8601String() ?? flot.dateEnvoi.toIso8601String(),
          'type': 'FLOT_SERVI',
          'destinataire': 'Envoyé vers ${flot.shopDestinationDesignation}',
          'montantBrut': flot.montant,
          'commission': 0.0,
          'montantNet': flot.montant,
          'modePaiement': flot.modePaiement.name,
          'statut': flot.statut.name,
        }),

      ]..sort((a, b) => DateTime.parse(b['dateOp'] as String).compareTo(DateTime.parse(a['dateOp'] as String))),
    };
  }

  // Générer le relevé de compte client
  Future<Map<String, dynamic>> generateReleveCompteClient({
    required int clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(startDate: startDate, endDate: endDate);

    final client = await LocalDB.instance.getClientById(clientId);
    if (client == null) {
      throw Exception('Client non trouvé');
    }

    final clientOperations = _operations.where((op) => op.clientId == clientId).toList();
    clientOperations.sort((a, b) => b.dateOp.compareTo(a.dateOp));

    double totalDepots = 0;
    double totalRetraits = 0;
    double totalEnvoyes = 0;
    double totalRecus = 0;

    for (final operation in clientOperations) {
      switch (operation.type) {
        case OperationType.depot:
          totalDepots += operation.montantNet;
          break;
        case OperationType.retrait:
        case OperationType.retraitMobileMoney:
          totalRetraits += operation.montantNet;
          break;
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          totalEnvoyes += operation.montantNet;
          break;
        case OperationType.transfertInternationalEntrant:
          totalRecus += operation.montantNet;
          break;
        case OperationType.virement:
          // Traiter les virements selon le contexte
          break;
        case OperationType.flotShopToShop:
          // FLOTs ne font pas partie des opérations clients
          break;
      }
    }

    // Calculer le solde réel à partir des opérations
    double soldeActuel = 0;
    for (final operation in clientOperations) {
      switch (operation.type) {
        case OperationType.depot:
        case OperationType.transfertInternationalEntrant:
          soldeActuel += operation.montantNet;
          break;
        case OperationType.retrait:
        case OperationType.retraitMobileMoney:
          soldeActuel -= operation.montantNet;
          break;
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          // Pour les transferts sortants, le client paie le montant brut
          soldeActuel -= operation.montantBrut;
          break;
        case OperationType.virement:
          // Traiter les virements selon le contexte
          break;
        case OperationType.flotShopToShop:
          // FLOTs ne font pas partie des opérations clients
          break;
      }
    }

    return {
      'client': client.toJson(),
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'soldeActuel': soldeActuel,  // Utiliser le solde calculé
      'totaux': {
        'depots': totalDepots,
        'retraits': totalRetraits,
        'envoyes': totalEnvoyes,
        'recus': totalRecus,
      },
      'transactions': clientOperations.map((op) => {
        'id': op.id,
        'code_ops': op.codeOps, // IMPORTANT: Unique identifier
        'date': op.dateOp,
        'type': op.type.name,
        'montant': op.montantNet,
        'commission': op.commission,
        'statut': op.statut.name,
        'notes': op.notes,
        'observation': op.observation,
        'destinataire': op.destinataire,
      }).toList(),
    };
  }

  // Méthodes utilitaires
  bool _isEntreeOperation(OperationModel operation, int shopId) {
    switch (operation.type) {
      case OperationType.depot:
        // Dépôt = ENTREE en caisse (client apporte de l'argent)
        return true;
        
      case OperationType.retrait:
      case OperationType.retraitMobileMoney:
        // Retrait = SORTIE de caisse (client prend de l'argent)
        return false;
        
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Shop SOURCE = ENTREE (client apporte brut + commission)
        // Shop DESTINATION = SORTIE (shop sert le montant net au bénéficiaire)
        if (operation.shopSourceId == shopId) {
          return true; // SOURCE = ENTREE
        } else if (operation.shopDestinationId == shopId) {
          return false; // DESTINATION = SORTIE
        }
        return false;
        
      case OperationType.transfertInternationalEntrant:
        // Transfert entrant = ENTREE (reçoit de l'étranger)
        return true;
        
      case OperationType.virement:
        // Virement interne = généralement SORTIE
        return false;
        
      case OperationType.flotShopToShop:
        // FLOT = dépend de la direction (source vs destination)
        if (operation.shopSourceId == shopId) {
          return false; // SOURCE = SORTIE (envoi de liquidité)
        } else if (operation.shopDestinationId == shopId) {
          return true; // DESTINATION = ENTREE (réception de liquidité)
        }
        return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Defer notifyListeners to avoid calling during build phase
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _clearError() {
    _errorMessage = null;
    // Defer notifyListeners to avoid calling during build phase
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Méthode de diagnostic pour vérifier l'impact des dépôts/retraits
  Future<void> diagnosticDepotsRetraits() async {
    debugPrint('🔍 DIAGNOSTIC DÉPÔTS/RETRAITS:');
    
    await loadReportData();
    
    final depots = _operations.where((op) => op.type == OperationType.depot).toList();
    final depotsClients = _operations.where((op) => 
      op.type == OperationType.depot && 
      op.destinataire != 'CAPITAL INITIAL'
    ).toList();
    final depotsInitiaux = _operations.where((op) => 
      op.type == OperationType.depot && 
      op.destinataire == 'CAPITAL INITIAL'
    ).toList();
    final retraits = _operations.where((op) => op.type == OperationType.retrait).toList();
    
    debugPrint('📥 DÉPÔTS TROUVÉS: ${depots.length} total');
    debugPrint('   - Dépôts clients: ${depotsClients.length} (comptés dans impact capital)');
    debugPrint('   - Dépôts initiaux: ${depotsInitiaux.length} (VISIBLES partout, déjà dans capitalCash)');
    debugPrint('');
    debugPrint('✅ CAPITAL INITIAL - Liste complète:');
    
    for (final depot in depotsInitiaux) {
      debugPrint('   🏦 Shop ${depot.shopSourceId}: +${depot.montantNet} ${depot.devise} (${depot.statut.name})');
      debugPrint('      Date: ${depot.dateOp}');
      debugPrint('      Visible dans: Journal Caisse, Liste Opérations, Rapport Mouvements');
      debugPrint('      EXCLU de: Calcul impact (déjà dans capital de base)');
    }
    
    debugPrint('');
    debugPrint('📥 DÉPÔTS CLIENTS:');
    for (final depot in depotsClients) {
      debugPrint('   👤 Shop ${depot.shopSourceId}: +${depot.montantNet} ${depot.devise} - ${depot.destinataire}');
    }
    
    debugPrint('');
    debugPrint('📤 RETRAITS TROUVÉS: ${retraits.length}');
    for (final retrait in retraits) {
      debugPrint('   👤 Shop ${retrait.shopSourceId}: -${retrait.montantNet} ${retrait.devise} - ${retrait.destinataire}');
    }
    
    debugPrint('🔍 DIAGNOSTIC TERMINÉ');
  }

  // Générer le rapport des mouvements de dettes intershop journalier
  Future<Map<String, dynamic>> generateDettesIntershopReport({
    int? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await loadReportData(shopId: shopId, startDate: startDate, endDate: endDate);

    // Filtrer les opérations pertinentes (transferts et flots)
    final transferts = _operations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).toList();

    final flots = _operations.where((op) => 
      op.type == OperationType.flotShopToShop
    ).toList();

    // Préparer les structures de données
    final List<Map<String, dynamic>> mouvements = [];
    final Map<String, Map<String, dynamic>> mouvementsParJour = {};
    final Map<int, double> soldesParShop = {}; // Soldes par shop (positive = créance, negative = dette)
    final Map<int, ShopModel> shopsMap = {};
    
    // Créer un map des shops pour accès rapide
    for (final shop in _shops) {
      if (shop.id != null) {
        shopsMap[shop.id!] = shop;
      }
    }
    
    double totalCreances = 0.0;
    double totalDettes = 0.0;

    // Traiter les transferts avec la logique du rapport de clôture
    for (final transfert in transferts) {
      if (transfert.shopDestinationId == null || transfert.devise != 'USD') continue;

      final shopSource = _shops.firstWhere(
        (s) => s.id == transfert.shopSourceId,
        orElse: () => ShopModel(id: transfert.shopSourceId ?? 0, designation: 'Shop ${transfert.shopSourceId}', localisation: ''),
      );
      final shopDestination = _shops.firstWhere(
        (s) => s.id == transfert.shopDestinationId,
        orElse: () => ShopModel(id: transfert.shopDestinationId ?? 0, designation: 'Shop ${transfert.shopDestinationId}', localisation: ''),
      );
      
      // Si un shop spécifique est sélectionné, filtrer les mouvements
      if (shopId != null && 
          transfert.shopSourceId != shopId && 
          transfert.shopDestinationId != shopId) {
        continue;
      }

      String typeMouvement;
      String description;
      bool isCreance = false;

      // Déterminer le type de mouvement selon la perspective du shop
      if (shopId == null) {
        // Vue globale: shop source doit au shop destination
        typeMouvement = 'transfert_initie';
        description = 'Transfert ${transfert.type.name} - ${shopSource.designation} doit ${transfert.montantBrut.toStringAsFixed(2)} USD à ${shopDestination.designation}';
      } else if (transfert.shopDestinationId == shopId) {
        // Ce shop a servi le transfert → créance
        typeMouvement = 'transfert_servi';
        description = 'Transfert servi - ${shopSource.designation} nous doit ${transfert.montantBrut.toStringAsFixed(2)} USD';
        isCreance = true;
        totalCreances += transfert.montantBrut;
        
        // Le shop source nous doit le MONTANT BRUT (montantNet + commission)
        final autreShopId = transfert.shopSourceId!;
        soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + transfert.montantBrut;
      } else if (transfert.shopSourceId == shopId) {
        // Ce shop a initié le transfert → dette
        typeMouvement = 'transfert_initie';
        description = 'Transfert initié - Nous que Devons ${transfert.montantBrut.toStringAsFixed(2)} USD à ${shopDestination.designation}';
        totalDettes += transfert.montantBrut;
        
        // On doit le MONTANT BRUT au shop destination
        final autreShopId = transfert.shopDestinationId!;
        soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - transfert.montantBrut;
      } else {
        continue; // Not relevant for the selected shop
      }

      final mouvement = {
        'date': transfert.dateOp,
        'shopSource': shopSource.designation,
        'shopDestination': shopDestination.designation,
        'montant': transfert.montantBrut,
        'commission': transfert.commission, // Frais/commission du transfert
        'typeMouvement': typeMouvement,
        'description': description,
        'isCreance': isCreance,
      };

      mouvements.add(mouvement);

      // Agréger par jour
      final dateKey = transfert.dateOp.toIso8601String().split('T')[0];
      if (!mouvementsParJour.containsKey(dateKey)) {
        mouvementsParJour[dateKey] = {
          'date': dateKey,
          'creances': 0.0,
          'dettes': 0.0,
          'solde': 0.0,
          'nombreOperations': 0,
        };
      }

      if (isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['creances'] += transfert.montantBrut;
      }
      if (!isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['dettes'] += transfert.montantBrut;
      }
      mouvementsParJour[dateKey]!['nombreOperations']++;
    }

    // NOUVEAU: Traiter les opérations AUTRES SHOP (dépôts et retraits intershop)
    final autresShopOps = _operations.where((op) => 
      (op.type == OperationType.depot || op.type == OperationType.retrait) &&
      op.shopSourceId != null && op.shopDestinationId != null &&
      op.shopSourceId != op.shopDestinationId && // Opérations intershop uniquement
      op.devise == 'USD'
    ).toList();
    
    print('🔍 DEBUG DETTES INTERSHOP:');
    print('📊 Total opérations: ${_operations.length}');
    print('🏪 Opérations AUTRES SHOP trouvées: ${autresShopOps.length}');
    for (final op in autresShopOps.take(3)) {
      print('   - ${op.type.name} ${op.montantNet} USD: Shop ${op.shopSourceId} → Shop ${op.shopDestinationId}');
    }

    // Traiter les opérations AUTRES SHOP
    for (final op in autresShopOps) {
      final shopSource = _shops.firstWhere(
        (s) => s.id == op.shopSourceId,
        orElse: () => ShopModel(id: op.shopSourceId ?? 0, designation: 'Shop ${op.shopSourceId}', localisation: ''),
      );
      final shopDestination = _shops.firstWhere(
        (s) => s.id == op.shopDestinationId,
        orElse: () => ShopModel(id: op.shopDestinationId ?? 0, designation: 'Shop ${op.shopDestinationId}', localisation: ''),
      );
      
      // Si un shop spécifique est sélectionné, filtrer les mouvements
      if (shopId != null && 
          op.shopSourceId != shopId && 
          op.shopDestinationId != shopId) {
        continue;
      }

      String typeMouvement;
      String description;
      bool isCreance = false;

      // Déterminer le type de mouvement selon la perspective du shop
      if (shopId == null) {
        // Vue globale
        typeMouvement = op.type == OperationType.depot ? 'depot_intershop' : 'retrait_intershop';
        description = '${op.type.name.toUpperCase()} intershop - ${shopSource.designation} → ${shopDestination.designation}';
      } else if (op.shopDestinationId == shopId) {
        // Ce shop a reçu l'opération
        if (op.type == OperationType.depot) {
          // Dépôt reçu → CRÉANCE (shop source nous doit)
          // Car le shop source a fait un dépôt pour son client chez nous
          typeMouvement = 'depot_recu';
          description = 'Dépôt reçu - ${shopSource.designation} nous doit ${op.montantNet.toStringAsFixed(2)} USD';
          isCreance = true;
          totalCreances += op.montantNet;
          
          final autreShopId = op.shopSourceId!;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + op.montantNet;
        } else {
          // Retrait servi → DETTE (on doit au shop source)
          // Car on a servi un retrait pour un client du shop source
          typeMouvement = 'retrait_servi';
          description = 'Retrait servi - Nous devons ${op.montantNet.toStringAsFixed(2)} USD à ${shopSource.designation}';
          totalDettes += op.montantNet;
          
          final autreShopId = op.shopSourceId!;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - op.montantNet;
        }
      } else if (op.shopSourceId == shopId) {
        // Ce shop a initié l'opération
        if (op.type == OperationType.depot) {
          // Dépôt fait → DETTE (on doit au shop destination)
          // Car on a fait un dépôt pour notre client chez le shop destination
          typeMouvement = 'depot_fait';
          description = 'Dépôt fait  ${op.montantNet.toStringAsFixed(2)} USD à ${shopDestination.designation}';
          totalDettes += op.montantNet;
          
          final autreShopId = op.shopDestinationId!;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - op.montantNet;
        } else {
          // Retrait fait → CRÉANCE (shop destination nous doit)
          // Car on a fait un retrait pour notre client depuis le shop destination
          typeMouvement = 'retrait_fait';
          description = 'Retrait fait - ${shopDestination.designation} nous doit ${op.montantNet.toStringAsFixed(2)} USD';
          isCreance = true;
          totalCreances += op.montantNet;
          
          final autreShopId = op.shopDestinationId!;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + op.montantNet;
        }
      } else {
        continue; // Not relevant for the selected shop
      }

      final mouvement = {
        'date': op.dateOp,
        'shopSource': shopSource.designation,
        'shopDestination': shopDestination.designation,
        'montant': op.montantNet,
        'commission': op.commission,
        'typeMouvement': typeMouvement,
        'description': description,
        'isCreance': isCreance,
        'clientNom': op.clientNom ?? op.destinataire ?? 'Client inconnu',
      };

      mouvements.add(mouvement);

      // Agréger par jour
      final dateKey = op.dateOp.toIso8601String().split('T')[0];
      if (!mouvementsParJour.containsKey(dateKey)) {
        mouvementsParJour[dateKey] = {
          'date': dateKey,
          'creances': 0.0,
          'dettes': 0.0,
          'solde': 0.0,
          'nombreOperations': 0,
        };
      }

      if (isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['creances'] += op.montantNet;
      }
      if (!isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['dettes'] += op.montantNet;
      }
      mouvementsParJour[dateKey]!['nombreOperations']++;
    }

    // NOUVEAU: Traiter les opérations administratives (solde par partenaire)
    final operationsAdministratives = _operations.where((op) => 
      op.isAdministrative &&
      (op.type == OperationType.depot || op.type == OperationType.retrait) &&
      op.devise == 'USD'
    ).toList();
    
    print('🔧 Opérations administratives trouvées: ${operationsAdministratives.length}');
    for (final op in operationsAdministratives.take(3)) {
      print('   - ${op.type.name} ${op.montantNet} USD: ${op.clientNom ?? op.destinataire} (Shop ${op.shopSourceId})');
    }

    // Traiter les opérations administratives (initialisations de soldes)
    for (final op in operationsAdministratives) {
      // Pour les opérations administratives, shopSourceId contient l'ID du shop concerné
      final shopConcerne = _shops.firstWhere(
        (s) => s.id == op.shopSourceId,
        orElse: () => ShopModel(id: op.shopSourceId ?? 0, designation: 'Shop ${op.shopSourceId}', localisation: ''),
      );
      
      // Si un shop spécifique est sélectionné, filtrer les mouvements
      if (shopId != null && op.shopSourceId != shopId) {
        continue;
      }

      String typeMouvement;
      String description;
      bool isCreance = false;

      // Les opérations administratives représentent des soldes initialisés
      if (shopId == null) {
        // Vue globale
        typeMouvement = op.type == OperationType.depot ? 'solde_credit_initialise' : 'solde_dette_initialise';
        description = 'Solde ${op.type == OperationType.depot ? 'crédit' : 'dette'} initialisé - ${op.clientNom ?? op.destinataire ?? 'Client inconnu'} (${shopConcerne.designation})';
      } else {
        // Vue spécifique au shop
        if (op.type == OperationType.depot) {
          // Dépôt administratif → créance (client nous doit)
          typeMouvement = 'solde_credit_initialise';
          description = 'Solde crédit initialisé - ${op.clientNom ?? op.destinataire ?? 'Client inconnu'} nous doit ${op.montantNet.toStringAsFixed(2)} USD';
          isCreance = true;
          totalCreances += op.montantNet;
        } else {
          // Retrait administratif → dette (on doit au client)
          typeMouvement = 'solde_dette_initialise';
          description = 'Solde dette initialisé - Nous devons ${op.montantNet.toStringAsFixed(2)} USD à ${op.clientNom ?? op.destinataire ?? 'Client inconnu'}';
          totalDettes += op.montantNet;
        }
      }

      final mouvement = {
        'date': op.dateOp,
        'shopSource': shopConcerne.designation,
        'shopDestination': shopConcerne.designation, // Même shop pour les initialisations
        'montant': op.montantNet,
        'commission': 0.0, // Pas de commission pour les initialisations
        'typeMouvement': typeMouvement,
        'description': description,
        'isCreance': isCreance,
        'clientNom': op.clientNom ?? op.destinataire ?? 'Client inconnu',
        'isAdministrative': true,
      };

      mouvements.add(mouvement);

      // Agréger par jour
      final dateKey = op.dateOp.toIso8601String().split('T')[0];
      if (!mouvementsParJour.containsKey(dateKey)) {
        mouvementsParJour[dateKey] = {
          'date': dateKey,
          'creances': 0.0,
          'dettes': 0.0,
          'solde': 0.0,
          'nombreOperations': 0,
        };
      }

      if (isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['creances'] += op.montantNet;
      }
      if (!isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['dettes'] += op.montantNet;
      }
      mouvementsParJour[dateKey]!['nombreOperations']++;
    }

    // Traiter les flots avec la logique du rapport de clôture
    for (final flot in flots) {
      if (flot.shopDestinationId == null || flot.devise != 'USD') continue;

      final shopSource = _shops.firstWhere(
        (s) => s.id == flot.shopSourceId,
        orElse: () => ShopModel(id: flot.shopSourceId ?? 0, designation: 'Shop ${flot.shopSourceId}', localisation: ''),
      );
      final shopDestination = _shops.firstWhere(
        (s) => s.id == flot.shopDestinationId,
        orElse: () => ShopModel(id: flot.shopDestinationId ?? 0, designation: 'Shop ${flot.shopDestinationId}', localisation: ''),
      );
      
      // Si un shop spécifique est sélectionné, filtrer les mouvements
      if (shopId != null && 
          flot.shopSourceId != shopId && 
          flot.shopDestinationId != shopId) {
        continue;
      }

      String typeMouvement;
      String description;
      bool isCreance = false;

      // Déterminer le type de mouvement selon la perspective du shop
      if (shopId == null) {
        // Vue globale
        typeMouvement = flot.statut == OperationStatus.validee ? 'flot_recu' : 'flot_envoye';
        description = 'Flot ${flot.statut.name} - ${shopSource.designation} → ${shopDestination.designation}';
      } else if (flot.shopSourceId == shopId) {
        // Ce shop a envoyé le flot → créance (ils Nous qui Doivent)
        typeMouvement = 'flot_envoye';
        description = 'Flot envoyé - ${shopDestination.designation} nous doit ${flot.montantNet.toStringAsFixed(2)} USD';
        isCreance = true;
        totalCreances += flot.montantNet;
        
        // NOUS avons envoyé → Ils Nous qui Doivent rembourser
        final autreShopId = flot.shopDestinationId!;
        soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
      } else if (flot.shopDestinationId == shopId) {
        // Ce shop a reçu le flot → dette (on leur doit)
        typeMouvement = 'flot_recu';
        description = 'Flot reçu - Nous que Devons ${flot.montantNet.toStringAsFixed(2)} USD à ${shopSource.designation}';
        totalDettes += flot.montantNet;
        
        // NOUS avons reçu → On leur doit rembourser
        final autreShopId = flot.shopSourceId!;
        soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
      } else {
        continue; // Not relevant for the selected shop
      }

      final mouvement = {
        'date': flot.dateOp,
        'shopSource': shopSource.designation,
        'shopDestination': shopDestination.designation,
        'montant': flot.montantNet,
        'commission': flot.commission, // Frais/commission du flot
        'typeMouvement': typeMouvement,
        'description': description,
        'isCreance': isCreance,
      };

      mouvements.add(mouvement);

      // Agréger par jour
      final dateKey = flot.dateOp.toIso8601String().split('T')[0];
      if (!mouvementsParJour.containsKey(dateKey)) {
        mouvementsParJour[dateKey] = {
          'date': dateKey,
          'creances': 0.0,
          'dettes': 0.0,
          'solde': 0.0,
          'nombreOperations': 0,
        };
      }

      if (isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['creances'] += flot.montantNet;
      }
      if (!isCreance || shopId == null) {
        mouvementsParJour[dateKey]!['dettes'] += flot.montantNet;
      }
      mouvementsParJour[dateKey]!['nombreOperations']++;
    }

    // Calculer le solde pour chaque jour
    for (final jour in mouvementsParJour.values) {
      jour['solde'] = (jour['creances'] as double) - (jour['dettes'] as double);
    }

    // IMPORTANT: Inclure TOUS les jours de la période (même sans opérations)
    // Ceci permet d'afficher la journée en cours même si non cloturée
    if (startDate != null && endDate != null) {
      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final lastDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (!currentDate.isAfter(lastDate)) {
        final dateKey = currentDate.toIso8601String().split('T')[0];
        
        // Ajouter le jour s'il n'existe pas encore
        if (!mouvementsParJour.containsKey(dateKey)) {
          mouvementsParJour[dateKey] = {
            'date': dateKey,
            'creances': 0.0,
            'dettes': 0.0,
            'solde': 0.0,
            'nombreOperations': 0,
          };
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    // Calculer l'évolution quotidienne avec solde cumulé
    final joursListe = mouvementsParJour.values.toList();
    joursListe.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String)); // Tri croissant pour calcul

    double soldeAnterieur = 0.0;
    for (final jour in joursListe) {
      jour['detteAnterieure'] = soldeAnterieur;
      final soldeJour = (jour['creances'] as double) - (jour['dettes'] as double);
      final soldeCumule = soldeAnterieur + soldeJour;
      jour['soldeCumule'] = soldeCumule;
      soldeAnterieur = soldeCumule; // Le solde devient la dette antérieure du jour suivant
    }

    // Trier les jours par date décroissante pour l'affichage
    joursListe.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    
    print('📈 Total mouvements générés: ${mouvements.length}');
    print('📅 Jours avec activité: ${joursListe.length}');
    if (mouvements.isNotEmpty) {
      print('🔍 Premiers mouvements:');
      for (final m in mouvements.take(5)) {
        print('   - ${m['typeMouvement']}: ${m['description']}');
      }
    }

    // Convertir les soldes par shop en format compatible avec l'interface
    final Map<int, Map<String, dynamic>> soldesParShopFormatted = {};
    for (final entry in soldesParShop.entries) {
      final shopId = entry.key;
      final solde = entry.value;
      final shop = shopsMap[shopId];
      
      if (shop != null) {
        soldesParShopFormatted[shopId] = {
          'shopId': shopId,
          'shopName': shop.designation,
          'creances': solde > 0 ? solde : 0.0,
          'dettes': solde < 0 ? solde.abs() : 0.0,
          'solde': solde,
        };
      }
    }

    // Séparer les shops en créanciers et débiteurs
    final shopsNousDoivent = soldesParShopFormatted.values
        .where((s) => (s['solde'] as double) > 0)
        .toList()
      ..sort((a, b) => (b['solde'] as double).compareTo(a['solde'] as double));
    
    final shopsNousDevons = soldesParShopFormatted.values
        .where((s) => (s['solde'] as double) < 0)
        .toList()
      ..sort((a, b) => (a['solde'] as double).compareTo(b['solde'] as double));

    // Trier les mouvements par date décroissante
    mouvements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return {
      'periode': {
        'debut': startDate?.toIso8601String(),
        'fin': endDate?.toIso8601String(),
      },
      'shopName': shopId != null 
          ? _shops.firstWhere((s) => s.id == shopId, orElse: () => _shops.first).designation 
          : 'Tous les shops',
      'summary': {
        'totalCreances': totalCreances,
        'totalDettes': totalDettes,
        'soldeNet': totalCreances - totalDettes,
        'nombreMouvements': mouvements.length,
      },
      'shopsNousDoivent': shopsNousDoivent,
      'shopsNousDevons': shopsNousDevons,
      'mouvements': mouvements,
      'mouvementsParJour': joursListe,
    };
  }

  // Créer des opérations de test pour vérifier la logique
  Future<void> createTestOperations() async {
    debugPrint('🧪 CRÉATION OPÉRATIONS DE TEST...');
    
    // Créer un dépôt de test pour le premier shop
    if (_shops.isNotEmpty) {
      final testShop = _shops.first;
      
      final depotTest = OperationModel(
        codeOps: '', // Sera généré automatiquement
        id: DateTime.now().millisecondsSinceEpoch,
        type: OperationType.depot,
        montantBrut: 5000.0,
        montantNet: 5000.0,
        commission: 0.0,
        shopSourceId: testShop.id!,
        agentId: 1,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.validee,
        dateOp: DateTime.now(),
        destinataire: 'TEST CLIENT',
        notes: 'Dépôt de test pour vérifier la logique',
      );
      
      await LocalDB.instance.saveOperation(depotTest);
      
      final retraitTest = OperationModel(
        codeOps: '', // Sera généré automatiquement
        id: DateTime.now().millisecondsSinceEpoch + 1,
        type: OperationType.retrait,
        montantBrut: 2000.0,
        montantNet: 2000.0,
        commission: 0.0,
        shopSourceId: testShop.id!,
        agentId: 1,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.validee,
        dateOp: DateTime.now(),
        destinataire: 'TEST CLIENT',
        notes: 'Retrait de test pour vérifier la logique',
      );
      
      await LocalDB.instance.saveOperation(retraitTest);
      
      debugPrint('✅ Opérations de test créées:');
      debugPrint('   - Dépôt: +5000 USD');
      debugPrint('   - Retrait: -2000 USD');
      debugPrint('   - Impact net: +3000 USD');
    }
    
    debugPrint('🧪 CRÉATION TERMINÉE');
  }
}
