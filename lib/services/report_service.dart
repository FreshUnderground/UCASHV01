import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/flot_model.dart' as flot_model;
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
      if (shopId != null) {
        _operations = allOperations.where((op) => op.shopSourceId == shopId).toList();
      } else {
        _operations = allOperations;
      }

      // Filtrer par période si spécifiée
      if (startDate != null && endDate != null) {
        _operations = _operations.where((op) {
          return op.dateOp.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 op.dateOp.isBefore(endDate.add(const Duration(days: 1)));
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

    final shop = _shops.firstWhere((s) => s.id == shopId);
    
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

    // Ajouter les FLOTs au rapport avec les dates appropriées
    for (final flot in flots) {
      final isEntree = flot.shopDestinationId == shopId;
      final isSortie = flot.shopSourceId == shopId;
      
      if ((isEntree || isSortie) && flot.devise == 'USD') {
        // Utiliser date_reception pour les flots reçus et created_at pour les flots envoyés
        final dateAction = isEntree 
            ? (flot.dateReception ?? flot.dateEnvoi)  // Pour les flots reçus, préférer date_reception
            : (flot.createdAt ?? flot.dateEnvoi);     // Pour les flots envoyés, préférer created_at
            
        // Vérifier si la date est dans la période demandée
        if ((startDate == null || dateAction.isAfter(startDate.subtract(const Duration(days: 1)))) &&
            (endDate == null || dateAction.isBefore(endDate.add(const Duration(days: 1))))) {
          
          final montant = flot.montant;
          final mode = flot.modePaiement.name;
          
          // Mettre à jour les totaux
          if (isEntree) {
            totalEntrees += montant;
          } else if (isSortie) {
            totalSorties += montant;
          }
          
          // Mettre à jour les totaux par mode de paiement
          totauxParMode[mode] = (totauxParMode[mode] ?? 0) + montant;
          
          // Récupérer les noms des agents
          final agentEnvoyeur = flot.agentEnvoyeurId != null 
              ? agentService.getAgentById(flot.agentEnvoyeurId!) 
              : null;
          final agentRecepteur = flot.agentRecepteurId != null 
              ? agentService.getAgentById(flot.agentRecepteurId!) 
              : null;
          
          final agentName = isEntree 
              ? (agentRecepteur?.nom ?? agentRecepteur?.username ?? 'Agent inconnu')
              : (agentEnvoyeur?.nom ?? agentEnvoyeur?.username ?? 'Agent inconnu');
          
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
                ? 'Reçu de ${flot.getShopSourceDesignation(_shops)}'
                : 'Envoyé vers ${flot.getShopDestinationDesignation(_shops)}',
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
        'nombreOperations': shopOperations.length + flots.length,
        'moyenneParOperation': (shopOperations.length + flots.length) > 0 
            ? (totalEntrees + totalSorties) / (shopOperations.length + flots.length) 
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
        final shopSource = _shops.firstWhere((s) => s.id == transfert.shopSourceId);
        final shopDestination = _shops.firstWhere((s) => s.id == transfert.shopDestinationId);
        
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
        'shopSource': _shops.firstWhere((s) => s.id == t.shopSourceId).designation,
        'shopDestination': t.shopDestinationId != null 
          ? _shops.firstWhere((s) => s.id == t.shopDestinationId).designation 
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
        _shops.firstWhere((s) => s.id == shopId).designation,
        montant,
      )),
      'commissionsParAgent': commissionsParAgent,
      'operations': operationsAvecCommission.map((op) => {
        'date': op.dateOp,
        'type': op.type.name,
        'montant': op.montantNet,
        'commission': op.commission,
        'shop': _shops.firstWhere((s) => s.id == op.shopSourceId).designation,
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

    final shop = _shops.firstWhere((s) => s.id == shopId);
    
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

    // Transferts entrants : les autres shops (SOURCE) nous doivent de l'argent (car nous sommes DESTINATION)
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
        // = L'AUTRE SHOP a donné de l'argent, donc NOUS DEVONS à L'AUTRE SHOP
        final sourceId = flot.shopSourceId;
        dettesParShop[sourceId] = (dettesParShop[sourceId] ?? 0) + flot.montant;
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
    // Capital Net = Capital Total + Créances - Dettes
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
        'date': op.dateOp,
        'type': op.type.name,
        'montant': op.montantNet,
        'commission': op.commission,
        'statut': op.statut.name,
        'notes': op.notes,
        'observation': op.observation, // Add this line
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
